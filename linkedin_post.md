# LinkedIn Post

## Setup notes

- **Lead with the GIF.** LinkedIn's algorithm favors native media over external links.
- **Repo link goes in the first comment**, not the post itself — LinkedIn buries posts with outbound links.
- **Add 3-5 relevant hashtags at the end**, not sprinkled through. Pick from the suggested list below.
- Best post times: Tuesday-Thursday, 8-10am ET.

---

## The post

```
Spent the weekend reviving an abandoned 10-year-old shell theme — and ended up building something I'm genuinely proud of.

spaceport launches a different rocket every time you open a shell. It's a fish and zsh greeting that turns every new terminal into a unique generative artifact. But here's what makes it interesting: the rocket's star field and flame pattern are mathematically derived from its color palette.

Same six hex codes → same 18 stars → same flame. Every time. No RNG involved after color generation.

This means saving a favorite palette saves the entire visual identity. The colors ARE the spec.

A few details I'm happy with:

→ Generative palettes use HSL distribution across 5 hue schemes so no two roles ever clash visually
→ Saved favorites announce themselves with a bright yellow star field instead of white
→ Optional neon mode renders each star independently from a 28-color rainbow palette
→ Light/dark theme support with palette-specific brightness tuning
→ A `star` command suite for saving, browsing, previewing, and tuning everything

The original theme (fishbone, by @maxnordlund) handled the rocket ASCII and system info. The deterministic star math, neon mode, favorites system, and command suite are new in this fork.

It's a tiny thing. But every time I open a new terminal tab and a unique rocket appears, it makes me smile — and occasionally a saved favorite rolls up like an old friend.

Repo + install instructions in the comments. MIT licensed, single file, one curl command to install (fish or zsh).

🚀 spaceport

#OpenSource #SoftwareDevelopment #FishShell #Zsh #DeveloperTools #GenerativeArt
```

---

## First comment (the link)

```
GitHub: github.com/clefspear/spaceport

fish:
curl -o ~/.config/fish/functions/fish_greeting.fish https://raw.githubusercontent.com/clefspear/spaceport/cantaloupe/fish_greeting.fish

zsh:
curl -o ~/.config/zsh/zsh_greeting.zsh https://raw.githubusercontent.com/clefspear/spaceport/cantaloupe/zsh_greeting.zsh && echo "source ~/.config/zsh/zsh_greeting.zsh" >> ~/.zshrc

Then open a new tab. That's it.
```

---

## Hashtag options (pick 3-5)

**Most likely to perform on LinkedIn:**
- #OpenSource
- #SoftwareDevelopment
- #DeveloperTools
- #SoftwareEngineering

**Niche but relevant:**
- #FishShell
- #GenerativeArt
- #CLI
- #TerminalCustomization
- #DotFiles

**Avoid:**
- #Tech (too broad, low CTR)
- #Coding (too generic)
- #Programming (oversaturated)
