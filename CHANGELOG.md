# Changelog

All notable changes to starcommand are documented here.

## [1.1.0] — 2026-05-23

- Extended `star add` to accept any positive multiple of 6 hex codes,
  adding each group of 6 as a separate favorite. Atomic validation:
  if any hex code is invalid the entire batch is rejected. Batched
  output uses the same `Added favorite #N:` colored-star format as
  `star list` / `star history`. Applies to all four shells.

## [1.0.10] — 2026-05-23

- Fixed `star update` broken on Windows PowerShell 5.1: `curl` is a built-in
  alias for `Invoke-WebRequest` in PS 5.1, so `& curl -fsSL ...` resolved to
  the cmdlet and rejected POSIX flags. Changed to `& curl.exe` which bypasses
  alias resolution and invokes the real binary shipped with Windows 10 1803+.
  Falls back to `Invoke-WebRequest` if `curl.exe` is absent.

## [1.0.9] — 2026-05-23

- Fixed `star explore` returning identical palettes on Ubuntu (bash & zsh):
  palette generation used the global `_RKT_PRNG_STATE` via `rkt_prng_range`,
  but `$()` subshells inherited the same state on each call. Now reseeds the
  PRNG from `/dev/urandom` before each iteration in the explore loop.

## [1.0.8] — 2026-05-22

- Fixed `star update` download by switching from release assets to raw content
  URLs (`raw.githubusercontent.com`) with debug output and redirect following

## [1.0.7] — 2026-05-22

- Improved network adapter detection: `_rkt_net_info` now automatically skips
  loopback, Docker/bridge, VM, VPN tunnel, and Apple internal interfaces,
  selecting the first real active interface with a valid IP address — no
  configuration required

## [1.0.6] — 2026-05-20

- `star update` now pulls from tagged GitHub Releases for immutability
- Added y/N confirmation before overwriting on update
- Background update check is now opt-in on first run instead of opt-out
- Update cache cleared after successful update in zsh and PowerShell

## [1.0.5] — 2026-05-20

- Update nudge now detects when the installed version matches the cached remote version and clears the cache, so it immediately reflects the latest available version after an update

## [1.0.4] — 2026-05-20

- `star update` now clears the stale nudge cache on successful update so the update prompt disappears immediately

## [1.0.3] — 2026-05-20

- Bash: Fixed Memory blank on Linux due to trailing whitespace/newline in /proc/meminfo parsing
- Bash: Fixed OS showing generic "Linux x86_64" instead of full distro string from /etc/os-release

## [1.0.2] — 2026-05-19

- Self-update via `star update` with weekly background nudge when new versions are available
- `star help` now displays the installed version

## [1.0.1] — 2026-05-19

- Fixed Linux memory display returning blank on Debian (now reads /proc/meminfo directly)
- OS line on Linux now shows distro name and version from /etc/os-release instead of generic "Linux x86_64"
- PowerShell on Windows now forces UTF-8 output encoding so star characters render correctly

## [1.0.0] — 2026-05-19

Initial release.

- Generative rocket greeting for bash, zsh, fish, and PowerShell
- Cross-shell byte-identical palette generation via shared PRNG
- Sysinfo display with terminal-width truncation
- `star` command for favorites, history, and palette management
