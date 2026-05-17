# 🚀 spaceport

*Created By [Peter Azmy](https://github.com/clefspear)*

spaceport launches a different rocket every time you open a shell — a fish and zsh greeting that turns every new terminal into a unique generative artifact. Each rocket's colors, stars, and flame are mathematically linked — change the palette, and the entire constellation changes with it.

![hero](docs/hero.png)

---

## How many rockets are possible?

A lot.

- **~2 × 10⁴³ unique rockets possible** — every palette deterministically reproducible
- **148 candidate star cells** around the rocket
- **18 stars per rocket**, deterministically placed from the palette's bytes
- **8 flame patterns**, mapped from the first palette byte
- **28-color neon mode** that re-rolls every star color independently
- **6 color roles** (porthole, window, body, top, window-sides, flame), each drawn from a full 24-bit color space

In practice, two identical rockets appearing twice in a lifetime is statistically impossible. Every shell you open is — visually — the first time anyone has ever seen that exact rocket.

But the kicker: it's all reproducible. Save a palette to favorites and you've saved the *entire visual identity*. Same six hex codes always produce the same 18 stars in the same 18 positions with the same flame. The palette is the spec.

---

## See it

**In your terminal:**
![launches](docs/launches.gif)

**In the VSCode integrated terminal:**
![vscode](docs/vscode.png)

Works anywhere fish or zsh runs — iTerm2, Terminal.app, Alacritty, Kitty, Warp, VSCode, JetBrains terminals, tmux panes, SSH sessions, all of it.

---

## Install

Requires zsh ≥ 5.0 or fish ≥ 3.0.

**fish:**
```fish
curl -o ~/.config/fish/functions/fish_greeting.fish \
  https://raw.githubusercontent.com/clefspear/spaceport/main/fish_greeting.fish
```

Open a new tab. Done.

**zsh:**
```zsh
curl -o ~/.config/zsh/zsh_greeting.zsh \
  https://raw.githubusercontent.com/clefspear/spaceport/main/zsh_greeting.zsh
echo "source ~/.config/zsh/zsh_greeting.zsh" >> ~/.zshrc
source ~/.config/zsh/zsh_greeting.zsh
```

Open a new tab. Done.

Light-mode terminal? Run this once so stars stay readable:

```sh
star color theme light
```

---

## The `star` command

```
$ star help
```

### Save and explore

| | |
|---|---|
| `star` | Save the current palette to favorites |
| `star list` | Show all favorites |
| `star remove N` | Delete favorite `#N` |
| `star history` | Last 20 palettes (most recent first) |
| `star history N` | Save palette `#N` from history to favorites |
| `star show H1..H6` | Preview a custom palette as a mini rocket |
| `star add H1..H6` | Add a custom palette to favorites |
| `star explore [N]` | Browse `N` random palettes (default 5) |

![star-list](docs/star-list.png)

### Settings

| | |
|---|---|
| `star color` | Show current palette + rocket preview |
| `star color theme <dark\|light>` | Match your terminal background |
| `star color random <white\|neon>` | Star color on random rockets |
| `star color favorite <gold\|neon>` | Star color on favorite rockets |
| `star color reset` | Restore defaults |
| `star weight <0-100>` | Ratio of favorites to random rockets (default 20) |

`star help` displays the current value of every setting inline, in **bold italics**, so you can see the active state at a glance.

---

## Color modes

**Gold (default for favorites)** — when a saved favorite rolls up, the star field renders in bright Mario-star yellow. Instant "oh, that one's mine" recognition.

![gold](docs/gold.png)

**Neon** — every star independently rolls from a 28-color palette spanning the full hue wheel at 15° increments. Maximum chromatic chaos.

![neon](docs/neon.png)

Use neon on favorites to make them pop, or on random rolls to make every shell feel like a party.

---

## The math

Each palette hex code splits into 3 bytes (R, G, B), giving 18 bytes per rocket. Those bytes index into a precomputed list of 148 candidate cells around the rocket. Each byte contributes two stars (`byte % 148` and `(byte + 73) % 148`, deduplicated). The flame is simpler: `bytes[0] % 8` picks from 8 ASCII patterns.

No RNG after color generation. Reproducible from the palette alone.

Verified deterministic across fish and zsh — run `bash tests/determinism_check.sh` to reproduce.

---

## Files

```
~/.config/fish/
├── functions/fish_greeting.fish    # the theme (fish)
├── rocket_favorites.txt            # saved palettes (plain text)*
├── rocket_history.txt              # last 100 launches*
└── rocket_settings.fish            # theme, modes, weight

~/.config/zsh/
├── zsh_greeting.zsh                # the theme (zsh)
├── rocket_favorites.txt            # saved palettes (plain text)*
├── rocket_history.txt              # last 100 launches*
└── rocket_settings.zsh             # theme, modes, weight

*Shareable between shells — same format.
```

Plain text. Easy to back up, sync via dotfiles, or share.

---

## Credits

Rocket ASCII art adapted from the [fishbone](https://github.com/oh-my-fish/theme-fishbone) theme by [@maxnordlund](https://github.com/maxnordlund).

## License

MIT — see [LICENSE](LICENSE).
