# Changelog

All notable changes to starcommand are documented here.

## [1.3.1] — 2026-05-27

- Widen palette generator from HSL to full 24-bit RGB color space (16.7M → 16.8M colors) — all four shells, dark/light theme awareness with brightness clamping ([60..200] luminance range)
- Deduplicate palettes within `star explore` runs — identical six-hex codes are regenerated on the spot, guaranteed unique across all `N` rolls
- Deprecate HSL generator (`_rkt_gen_rocket_palette_hsl` / `Invoke-GenRocketPaletteHsl`) kept as reference for color-theme previews
- Update README to document deduplication guarantee

## [1.3.0] — 2026-05-23

- Lower rocket threshold from N>=300 to N>=250
- Guard rocket launches against truncated flights ((N - i) >= 72)
- Move first-launch iteration from 150 to 125

## [1.2.5] — 2026-05-23

- Fix rocket color bleed: add ANSI reset before rocket overlay
- Fix fish trailing-backslash parse error in rocket body row
- Change rocket body from /\ to /_\ (3-char rows with underscore)
- Remove sleeps during rocket flight
- Change line-number padding from %3d to %4d
- Switch cooldown from one-shot flag to ~200-iteration counter
- Lower threshold from N>=800 to N>=300
- Move first launch from iteration 500 to 150

## [1.2.4] — 2026-05-23

- Fix doubled cantaloupe suffix in version display

## [1.2.3] — 2026-05-23

- Fix update URL construction when no existing installation

## [1.2.2] — 2026-05-23

- Added visual effect to star explore

## [1.2.1] — 2026-05-23

- Added star supernova command

## [1.2.0] — 2026-05-23

- Internal refactor of star update

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
