# Performance runs — legend & experiment log

Every `.txt` here is raw `core_bench` output. This file explains the
acronyms so a run is readable months later. **Time/Run lower = better;
mWd/Run = minor words allocated per run (GC pressure).**

Shorthand used throughout: **P** = number of price levels, **k** = orders
per level, **N = P·k** = total resting orders.

## Order-book representations — `order_book_nested_vs_flat.txt`

One side of a book (bids: best = highest price, ties broken by earliest
`order_id`). k = 16 fixed; run at **P = 128** (realistic) and **P = 8192**
(stress) so a change in `best`/`bbo` is attributable to P alone.

| tag    | outer index                                   | per-level structure          | `best`/`bbo` cost                         |
|--------|-----------------------------------------------|------------------------------|-------------------------------------------|
| `flat` | one `Core.Map` keyed by `(-price, order_id)`  | — (single flat map)          | O(log N + k): reach best price, scan its k |
| `nmap` | `Key_aug_table` price →                        | persistent `Map` id → order  | O(log P) walk + O(k) fold                 |
| `nhq`  | `Key_aug_table` price →                        | mutable sized hash queue     | O(log P) `max_elt` right-spine walk       |
| `nhqm` | `Core.Map` price →                             | mutable sized hash queue     | O(log P) `Map.max_elt` walk               |
| `aug`  | `Aug_table` price →, measure `(best_price, queue)` | mutable sized hash queue | **O(1)** — read root measure              |
| `nhqt` | `Core.Map` price → **+ cached `(best_price, queue)` field** | mutable sized hash queue | **O(1)** — read cached field         |

`nhqt` is `nhqm` plus the exact pair `aug` caches as its measure, but
maintained by hand beside a stock `Core.Map` — the test of whether we can
get `aug`'s O(1) top-of-book without paying its hand-rolled tree on writes.

Operations benched (each net-zero on state):

| op           | what it does                                             |
|--------------|----------------------------------------------------------|
| `build`      | construct the whole book from the order array            |
| `find`       | look up the order at a known `(price, order_id)`         |
| `best`       | the price-time-priority best resting order               |
| `bbo`        | the best price and total resting size at it              |
| `update`     | replace the value at an already-present `(price, id)`    |
| `add+remove` | add a transient order at the top level, then remove it   |
| `churn`      | drop the best price level off the index and re-insert it — the worst case for a cached/measured top of book |

## "Which tree" microbench — `aug_table_vs_map.txt`, `old_key_aug_map.txt`

`int` keys → `Order.t` values, measure = max-key (`combine` = max,
`identity` = 0), n = 1000. Isolates the *tree*, not the book. Ops:
`creation`, `add`, `remove`, `find`.

| tag             | structure                                                        |
|-----------------|------------------------------------------------------------------|
| `aug`           | generic `Aug_table` — measure via first-class `Arg` module (closures) |
| `kpoly`         | `Key_monoid_table` — generic over the key type, measure monomorphized |
| `kmono` / `key` | `Key_aug_table` — fully monomorphized to the key type, inlined compare |
| `map`           | `Core.Map` — no measure (the baseline to beat)                   |

`old_key_aug_map.txt` is the earlier 3-way (`aug` / `key` / `map`);
`aug_table_vs_map.txt` supersedes it by splitting `key` into `kpoly` vs
`kmono`.

## Earlier order-book experiments (pre aug-table)

| file                                | what it measures                                                        |
|-------------------------------------|-------------------------------------------------------------------------|
| `basic_functions_map_only.txt`      | baseline ops (find, …) on the Map-backed order book, varying n          |
| `existing_before_with_snapshot.txt` | `find_match` + `snapshot` timings before the snapshot change            |
| `snapshot_{before,after,default}.txt` | cost of one book `snapshot` under three configs                       |
| `symbol_int_{before,after}.txt`     | `book_lookup` with `Symbol` as string (before) vs int (after); `_after` flags a bad-hash quirk inline |
