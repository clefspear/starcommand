# Changelog

All notable changes to starcommand are documented here.

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
