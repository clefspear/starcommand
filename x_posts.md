# X / Twitter Posts

## Setup notes for the post

- **Attach the launches.gif directly to the tweet** (not a link to GitHub). X autoplay rewards native video.
- **Put the GitHub link in the first reply, not the main tweet.** X deprioritizes posts with external links.
- **First 2 seconds of the GIF should hit hardest** — open with a rocket appearing fully formed, not a typing animation.
- Best post times for tech audience: Tuesday-Thursday, 10am-12pm ET or 7-9pm ET.

---

## Single-tweet variants (pick one)

### A. The determinism flex (tech-heavy audience)

```
I built a fish and zsh shell theme where the rocket's star field is mathematically derived from its color palette.

Same six hex codes → same 18 stars → same flame pattern. Every. Single. Time.

No RNG. The colors carry the visual identity.

🚀 spaceport
```

### B. The aesthetic (let the GIF do the work)

```
made my fish/zsh shell launch a different rocket every time you open a new tab

each one is generative but reproducible — same palette = same stars

it's called spaceport 🚀
```

### C. The story (narrative hook)

```
forked an abandoned 10-year-old fish shell theme (now ported to zsh too)

instead of just rebooting it, gave the rocket palette-deterministic constellations, a 28-color neon mode, and a favorites system

it's silly. it's beautiful. it's called spaceport 🚀
```

### D. The joke (creative/comedy audience)

```
my terminal now has main character energy 🚀

(28-color generative rocket on every shell, fish and zsh, link in replies)
```

---

## Thread version (recommended for tech audience)

### Tweet 1 (with launches.gif attached)

```
I built a fish and zsh shell theme where every new tab launches a different rocket.

But here's the trick: the star field is mathematically derived from the color palette.

Same palette → same stars → same flame. Every time. No RNG.

🧵
```

### Tweet 2 (with determinism.png attached)

```
Each of the 6 hex codes splits into 3 bytes. 18 bytes total.

Those bytes index into 148 candidate star cells around the rocket.

Save a favorite, and you've saved the constellation too. The palette IS the spec.
```

### Tweet 3 (with neon.png or neon.gif attached)

```
Saved favorites announce themselves with bright Mario-star yellow.

Or switch to neon mode — every star independently rolls from a 28-color rainbow palette.

(yes you can tune the favorites-to-random ratio. no I will not be normal about this.)
```

### Tweet 4 (with star-list.png attached)

```
The `star` command suite handles everything:

star            save current
star list       show favorites
star explore    browse fresh ones
star color      preview your active palette
star weight     tune the ratio

Settings persist. Everything's plain text.
```

### Tweet 5 (link reveal)

```
Originally a fork of fishbone (long-abandoned OMF theme). MIT licensed.

One curl command to install:

curl -o ~/.config/fish/functions/fish_greeting.fish https://raw.githubusercontent.com/clefspear/spaceport/cantaloupe/fish_greeting.fish

or for zsh:

curl -o ~/.config/zsh/zsh_greeting.zsh https://raw.githubusercontent.com/clefspear/spaceport/cantaloupe/zsh_greeting.zsh && echo "source ~/.config/zsh/zsh_greeting.zsh" >> ~/.zshrc

Repo: github.com/clefspear/spaceport
```

---

## Replies / engagement tactics

If the post hits, expect questions like these. Pre-write responses:

**"Does it work with zsh?"**
> Yes — the full theme was ported to zsh syntax. Same determinism, same command suite, same everything. Install with:
> `curl -o ~/.config/zsh/zsh_greeting.zsh https://raw.githubusercontent.com/clefspear/spaceport/cantaloupe/zsh_greeting.zsh && echo "source ~/.config/zsh/zsh_greeting.zsh" >> ~/.zshrc`

**"Why fish?"**
> Fish 4.0's Rust rewrite (Feb 2025) made it fast as bare zsh. Plus the syntax is clean enough that the whole theme fits in one file.

**"How is the star pattern actually deterministic?"**
> Each palette hex code splits into R/G/B bytes (18 total). Each byte indexes into a precomputed list of 148 candidate cells around the rocket. Two stars per byte at (idx) and (idx+73 mod 148). Fully reproducible.

**"Can I change the colors?"**
> Yeah — the neon palettes are arrays of hex codes at the top of the file. Swap freely. The hue distribution schemes for fresh palettes are also tunable.

**"It's too random / too few favorites / too many favorites"**
> `star weight <0-100>` — sets the % of new shells that roll a saved favorite vs generate fresh. Default 20.
