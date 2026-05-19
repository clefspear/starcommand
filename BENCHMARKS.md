# Benchmarks

Testing environment: macOS (Apple Silicon), `bash 3.2`, `zsh 5.9`, `fish 3.7`, `pwsh 7.4`.

Measurements: 10 iterations cold (caches cleared before each run) + 10 iterations warm (caches intact), using `/usr/bin/time -p`. Medians reported in seconds.

## Baseline (before any perf tasks)

| Shell | Cold median | Warm median |
|-------|------------|-------------|
| bash  | 0.70       | 0.32        |
| zsh   | 0.71       | 0.28        |
| fish  | 1.35       | 0.98        |
| pwsh  | 2.27       | 1.53        |

Fish is the slowest due to perl subprocess on every PRNG draw (~20-50ms per fork × 5-23 draws per render). pwsh startup is dominated by .NET runtime init.

## Task 1 — Fish PRNG: drop perl subprocess

| Shell | Cold median (before) | Cold median (after) | Warm median (before) | Warm median (after) |
|-------|---------------------|--------------------|---------------------|--------------------|
| fish  | 1.35                | 1.30               | 0.98                | 0.94               |

Replaced perl subprocess with fish 4.x `math` built-in using `bitxor`, `floor`, and arithmetic shifts. Each PRNG draw now stays in-process instead of forking perl (~20-50ms per fork eliminated).

## Task 2 — Bash PRNG: inline like zsh

| Shell | Cold median (before) | Cold median (after) | Warm median (before) | Warm median (after) |
|-------|---------------------|--------------------|---------------------|--------------------|
| bash  | 0.70                | 0.75               | 0.32                | 0.33               |

Inlined xorshift32 directly in `rkt_prng_range` instead of calling via `$(rkt_xorshift32 ...)` subshell. Eliminates fork per PRNG draw.

## Task 3 — Star-color subshell forks (bash)

| Shell | Cold median (before) | Cold median (after) | Warm median (before) | Warm median (after) |
|-------|---------------------|--------------------|---------------------|--------------------|
| bash  | 0.70                | 0.72               | 0.32                | 0.31               |

Changed `rkt_star_color_for_mode` to set `_RKT_PRNG_RET` global instead of `echo`. Updated caller in `rkt_render_row` to read global directly instead of `$(...)` subshell. Benefit amplifies under neon mode (18 stars × PRNG draws).
