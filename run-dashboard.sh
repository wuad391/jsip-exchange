#!/usr/bin/env bash
# Build the JSIP monitoring dashboard with a small browser bundle, then run it.
#
# Why this script exists
# ----------------------
# The browser half (app/dashboard/client) is a js_of_ocaml executable. In
# dune's default (dev) profile it is built with SEPARATE compilation -- no
# cross-unit dead-code elimination -- producing a ~64 MB bundle the browser
# then spends seconds parsing (that is the "Connecting..." lag). The `release`
# profile uses WHOLE-PROGRAM compilation, which strips it down to a ~1.9 MB
# bundle. So the dashboard should always be built with `--profile release`.
#
# The trap this removes: you must pass `--profile release` to BOTH the build
# and the run. `dune build --profile release` followed by a plain `dune exec`
# re-evaluates the client in the dev profile and clobbers the small bundle with
# the 64 MB one. This script builds the server exe in release (which pulls the
# release client bundle in via app/dashboard/server/dune's copy rule), then
# runs the built binary directly -- there is no second dune evaluation to undo
# the small bundle.
#
# Memory note: the whole-program js_of_ocaml link is memory-heavy (a few GB).
# Build parallelism is capped at -j 2 by default; override with
# JSIP_BUILD_JOBS=N. Do not run this alongside another heavy build.
#
# Usage
# -----
#   ./run-dashboard.sh                          # localhost, exchange :12345, http :8080
#   ./run-dashboard.sh -http-port 9000          # any app/dashboard/server flag passes through
#   ./run-dashboard.sh -exchange-port 12346 -http-port 8080
#
# Prerequisite: an exchange must already be running on -exchange-port. To also
# generate sustained traffic to watch, pass -trade-back-and-forth (two market
# makers trading in a loop):
#   dune exec app/server/bin/main.exe -- -port 12345 -trade-back-and-forth

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$repo_root"

jobs="${JSIP_BUILD_JOBS:-2}"
server_exe="$repo_root/_build/default/app/dashboard/server/main.exe"

echo "Building dashboard (--profile release, whole-program js_of_ocaml -> ~1.9 MB bundle; -j ${jobs})..."
# Build the server exe AND the client bundle target. The server serves
# main.bc.js by reading it at runtime (see app/dashboard/server/dune's copy
# rule + Asset.What_to_serve.file in main.ml); nothing links it, so building
# main.exe alone does NOT produce it -- it must be requested explicitly.
# --root pins the project to this script's directory so dune's root-finding
# never walks up into an enclosing repo (e.g. when run from a git worktree).
dune build --root "$repo_root" --profile release -j "$jobs" \
  app/dashboard/server/main.exe \
  app/dashboard/server/main.bc.js

echo "Starting dashboard server (Ctrl-C to stop)..."
exec "$server_exe" "$@"
