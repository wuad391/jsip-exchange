# Order-book data-structure investigation

This folder holds the `core_bench` runs behind one decision: **what should the
production `Order_book` be?** The starter used a flat `Core.Map` keyed by
`(neg_price_rank, order_id)`, whose `best_bid_offer` scanned the whole side —
O(n) — and the matching engine recomputes BBO *twice per write*. This is the
record of what we measured, what we rejected, and why the book is now a nested
`Core.Map` from price to a per-level hash queue.

Every `.txt` is raw `core_bench` output. **Time/Run lower = better; mWd/Run =
minor words allocated per run (GC pressure).** Shorthand: **P** = price levels,
**k** = orders per level, **n = P·k** = total resting orders.

> ⚠️ Compare **within a single `.txt`**, not across files — absolute numbers
> drift with machine load between runs.

## The candidates

The question was whether an *augmented tree* — a weight-balanced BST caching a
monoid `measure` per subtree, so the top-of-book aggregate is an O(1) root read
— could beat a plain `Core.Map`. We built one (`Aug_table`) and raced it three
ways, from the tree in isolation up to the live exchange.

## Experiment 1 — "which tree?" (`aug_table_vs_map.txt`, `old_key_aug_map.txt`)

Isolates the *tree itself*: `int` keys → `Order.t` values, no book around it.
`aug` = generic `Aug_table` (measure via a first-class module = closures);
`kpoly`/`kmono` = progressively monomorphized hand-rolled variants
(`Key_monoid_table`, `Key_aug_table`); `map` = plain `Core.Map`.

**n = 1000, ns/op:**

| op | aug | kpoly | kmono | map |
|--------------------|-----:|------:|------:|-----:|
| add | 420 | 403 | 288 | **155** |
| remove | 300 | 295 | 196 | **124** |
| find | 75 | 52 | 42 | 47 |
| O(1) measure read | 10 | 10 | 10 | — |
| best via `max_elt` | — | — | — | 18 |

**Verdict:** even *fully monomorphized*, the hand-rolled tree is ~2× slower than
`Core.Map` on add/remove (closures gone, so the gap is structural: fatter nodes,
weight-balance running taller than `Core.Map`'s AVL). Its one advantage — the
O(1) measure read at 10 ns — beats `Core.Map.max_elt` (18 ns) by a mere **8 ns**,
nowhere near enough to pay back **+130 ns per add**. We can't out-tune
`Core.Map` with our own tree.

## Experiment 2 — order-book contenders (`order_book_nested_vs_flat.txt`)

Six representations of one book side, across `build / find / best / bbo /
update / add+remove / churn`, at P=128 and P=8192. Tags: `flat` (single map by
`(-price,id)`), `nmap`/`nhq` (price tree → map / hash queue), `nhqm`
(`Core.Map` price → hash queue), `aug` (`Aug_table` price → hash queue, measure
carries the best level), `nhqt` (`nhqm` + a cached best field).

**P = 8192, ns/op (lower = better):**

| op | flat | **nhqm** | aug |
|-------------|------:|------:|------:|
| bbo | 249 | **29** | 16 |
| best | 33 | **32** | 17 |
| add+remove | 781 | **326** | 457 |
| churn | 12211 | **629** | 2839 |
| find | 123 | **105** | 163 |

**Verdict:** `Aug_table` buys the fastest *raw* BBO read (16 ns, straight off the
measure) — but loses decisively on **churn** (2839 vs 629 ns). Churn = drop the
best level and re-insert it, the common top-of-book case; each structural write
recomputes the measure up the spine of the slower tree. The "free" measure is
really a **write-tax amortized into every structural write**, and churn is
nothing but structural writes. `Aug_table` loses the very case it was built for.
**Eliminated.** The nested `Core.Map` + hash queue (`nhqm`) wins the writes and
ties the reads.

## Experiment 3 — production before / after (`existing_before_with_snapshot.txt` → `existing_after_with_snapshot.txt`)

The real `Order_book` + `Matching_engine`, flat vs the shipped nested rep, same
benchmark.

**ns/op:**

| op | before (flat) | after (nested) | change |
|------------------------------|-------:|------:|-------------|
| `best_bid_offer` (n=100) | 3090 | 76 | **40× faster** |
| `best_bid_offer` (n=500) | 12979 | 115 | **113× faster** |
| `submit_ioc_cross` (n=500) | 61346 | 5051 | **12× faster** |
| `submit_ioc_miss` (n=500) | 30907 | 852 | **36× faster** |
| `find_match` (n=100) | 57 | 59 | ~flat (+2) |
| `add+remove` (n=100) | 437 | 978 | **2.2× slower** |

`best_bid_offer` collapses from O(n) (the 373→1581→3090→12979 ladder across
n=10→500) to essentially flat. Because the engine recomputes BBO twice per
write, that propagates all the way to end-to-end `submit`: up to ~36× at depth.

**Two honest regressions**, both expected and both dwarfed:

- `find_match` ~+13 ns — the nested `max/min_elt` returns `(price, queue)` and
  then peeks the queue front, one indirection the flat map didn't need (it
  returned the order directly). Real constant-factor, *not* noise — it sits at
  the same offset across all n.
- `add+remove` ~2× — opening a *new* price level now allocates a per-level hash
  queue. Adds at *existing* levels stay O(1) in place; this is the fresh-level
  worst case.

Both are tens to hundreds of ns on paths that aren't the bottleneck; the BBO
sits on the hot path (2×/write) and dominates.

## Final choice

**A nested `Core.Map` from `Price.t` to a per-level FIFO `Hash_queue`, plus an
id→order table** (the `nhqm` design). Justification:

1. **Reuse `Core.Map`.** Experiment 1 shows a hand-rolled tree can't beat it;
   the augmentation's O(1) measure saves 8 ns and costs 130 ns/add.
2. **Nest by price.** The best level is `max`/`min_elt` (O(log P)) and its depth
   is a reduce over one small queue (O(k)) — no full-side scan. BBO drops
   O(n) → O(log P + k).
3. **Hash queue per level.** O(1) enqueue/cancel, and FIFO front = arrival order
   = price-time priority for free.
4. **Reject `Aug_table`.** Its O(1)-measure BBO can't pay for its write-tax
   (Experiment 2 churn); it loses its own worst case.

Net shipped result: BBO 40–113× faster, `submit` up to ~36× faster at depth, for
small constant-factor regressions on `find_match` and new-level `add`.

## File index

| file | what it holds |
|------|----------------|
| `existing_before_with_snapshot.txt` / `existing_after_with_snapshot.txt` | production `Order_book`, flat vs nested (Experiment 3) |
| `order_book_nested_vs_flat.txt` | the six-way contenders (Experiment 2) |
| `aug_table_vs_map.txt` | the five-way tree microbench (Experiment 1) |
| `old_key_aug_map.txt` | earlier 3-way tree microbench, superseded by the above |
| `basic_functions_map_only.txt` | baseline ops on the original map-backed book, varying n |
| `snapshot_{before,after,default}.txt` | cost of one book `snapshot` under three configs |
