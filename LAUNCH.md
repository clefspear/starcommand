# spaceport Launch Checklist

## What's done ✅

- [x] `fish_greeting.fish` — the theme itself, fully featured (fish)
- [x] `zsh_greeting.zsh` — full zsh port, feature-parity with the fish version
- [x] `README.md` — install, command reference, determinism explainer, credits
- [x] `LICENSE` — MIT
- [x] X / Twitter post drafts (single + thread variants)
- [x] LinkedIn post draft

## What's needed before launch ❌

### Repo setup (15 min)

- [ ] Create GitHub repo: `github.com/clefspear/spaceport`
- [ ] Push these files to `main` branch:
  - `fish_greeting.fish`
  - `zsh_greeting.zsh`
  - `README.md`
  - `LICENSE`
  - `docs/` (folder for screenshots — see below)
- [ ] Replace `clefspear` in the README with your actual GitHub handle
- [ ] Replace `clefspear` in the post drafts with your actual GitHub handle

### Media assets (1-2 hours, the bulk of the work)

These all go in `docs/` in the repo:

#### docs/hero.png — the thumbnail (highest priority)
- Open a fresh terminal tab — let a beautiful palette roll
- If the first one isn't pretty, open more tabs until one is
- Take 5+ screenshots, pick the best
- Dark terminal background, full rocket + system info visible
- Crop just slightly outside the content area, don't crowd it
- This image appears at the top of the README and is the OG/Twitter preview

#### docs/launches.gif — the hero GIF (highest priority)
- 6-10 seconds, ideally looping
- Open 4-6 new tabs in quick succession (cmd+T on macOS in iTerm2)
- Each greeting should be visibly different — rocket colors, star patterns, flames
- Tools that work well:
  - **QuickTime** screen recording → convert to GIF at ezgif.com (simplest)
  - **ttygif** — terminal-specific, very clean output
  - **asciinema** + **agg** — best quality, slight learning curve
- Keep under 5MB so GitHub renders it inline
- Make sure the first frame is a fully-rendered rocket (cold opens hit harder)

#### docs/star-list.png — favorites view
- First, save 5-10 favorites by opening tabs and running `star` on the ones you like
- Run `star list`
- Screenshot
- Crop horizontally tight so the colored stars + hex codes are readable

#### docs/star-explore.gif — discovery loop
- Run `star explore 5` (browse 5 random palettes)
- Pick one that looks good
- Run `star show <those 6 hex codes>` (full preview)
- Run `star add <same 6 hex codes>` (saves to favorites)
- 10-12 seconds total
- Tells the discovery → preview → save story

#### docs/determinism.png — the "wait what?" moment (optional but recommended)
- Save a favorite first
- Then keep opening tabs until that same favorite rolls again (might take a few tries — 20% by default)
- Screenshot both occurrences
- Stack them vertically in any image editor (Preview on macOS works)
- Add a caption underneath: "Same palette → same stars → same flame."
- This is your shareable detail for X — the moment people get it

#### docs/neon.png — show off neon mode (optional)
- Run `star color favorite neon`
- Keep opening tabs until a favorite rolls
- Screenshot the multi-color star field
- This is the prettiest variant — great for engagement on X

### Recording tips

- Use **iTerm2** if you're on macOS — better for screen recording than Terminal.app
- Set your terminal to **at least 16pt font** so the screenshots are readable on phones
- Use a **dark color scheme** — most viewers will see your post on a dark UI
- **Hide the menu bar** during recording (macOS: System Settings → Control Center → Menu Bar)
- **Hide your dock**: ⌘⌥D toggles it
- **Clean prompt** during demo: `cd ~` so the prompt path is just `~`

## Launch day sequence

1. **Push the repo** with all files + screenshots
2. **Verify the README renders correctly** on GitHub (image paths work, GIFs play)
3. **Pin your repo** on your GitHub profile
4. **Post on X first** (faster engagement, lower stakes)
5. **Wait 2-3 hours**, gauge reaction
6. **Post on LinkedIn second** (slower, more professional framing)
7. **Reply to every comment** within the first 12 hours — engagement compounds
8. **Cross-post to /r/fishshell on Reddit** if X performs well

## If it goes viral

Common things people will ask for:

- [ ] Custom rocket ASCII (refuse politely — the determinism math depends on the specific grid)
- [ ] More themes (consider adding a `star scheme` command for built-in palette presets)
- [ ] PR contributions (set up CONTRIBUTING.md if traction warrants it)

## If it doesn't go viral

Totally fine. Post it to /r/fishshell and /r/commandline, drop it in your dotfiles repo, and use it yourself every day. It's a good piece of work regardless of reception.
