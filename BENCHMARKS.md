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
