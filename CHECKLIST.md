# 📋 Launch Checklist

Everything needed for this one project across GitHub, X, LinkedIn, and TikTok/Reels.

---

## 🎥 Recording setup (do once, helps every shot)

- [ ] Terminal: **iTerm2** (better recording behavior than Terminal.app)
- [ ] Font size: **16pt minimum** so it's readable on phones
- [ ] **Dark** color scheme (most social UIs are dark)
- [ ] Window size: **~120 cols × 40 rows**
- [ ] Hide menu bar + dock (`⌘⌥D` for dock)
- [ ] `cd ~` before recording so the prompt path is short
- [ ] Pre-save **5–10 favorites** so `star list` looks populated
- [ ] Close other apps that might fire notifications mid-recording

---

## 🐙 GitHub assets (in `docs/`)

Referenced inline in the README.

### Required

- [ ] **`docs/hero.png`** — fresh terminal, one beautiful rocket. The OG/Twitter preview when shared.
- [ ] **`docs/launches.gif`** — 4–6 tabs opening in rapid succession, each rocket different. 6–10 sec, looping, under 5MB.
- [ ] **`docs/vscode.png`** — same theme inside VSCode's integrated terminal. Editor pane visible so it's clearly VSCode.

### Recommended

- [ ] **`docs/star-list.png`** — `star list` with 5–10 favorites saved. Crop tight.
- [ ] **`docs/gold.png`** — favorite rolling up with bright yellow star field.
- [ ] **`docs/neon.png`** — neon mode active, multi-color star field. Prettiest shot.

### Optional

- [ ] **`docs/determinism.png`** — same favorite captured twice, stacked vertically, with caption "Same palette → same stars → same flame."

---

## 🐦 X / Twitter

Copy lives in `x_posts.md`.

- [ ] Attach `launches.gif` directly to the tweet (not a link)
- [ ] Drop the GitHub URL as a **reply** to your own tweet (X buries posts with outbound links)
- [ ] Post Tue/Wed/Thu, 10–11am ET
- [ ] Stay near phone for 2 hours after — engagement compounds

For thread version, also have ready:
- [ ] `determinism.png` or `neon.png` for tweet 2
- [ ] `star-list.png` for tweet 4

---

## 💼 LinkedIn

Copy lives in `linkedin_post.md`.

- [ ] Attach `launches.gif` to the post
- [ ] Drop GitHub link as the **first comment** (LinkedIn buries posts with outbound links)
- [ ] Post Tue/Wed/Thu, 8–10am ET
- [ ] Reply to every comment in the first 12 hours

---

## 📱 TikTok / Instagram Reels

Michael Reeves / Anthpo energy. 30–50 sec, dense edit, deadpan delivery, the technical detail loops back to absurd.

### Script

**Cold open (0–2s)** — straight to chaos
> Rapid-fire cuts: 5 different rockets, one per beat. No talking. Single drum hit per cut.

**Premise (2–8s)** — flat
> "I open a terminal like a hundred times a day. They all look exactly the same."
> *(cut to default boring `bash` prompt)*
> "So I fixed it."

**Spiral (8–20s)** — where the comedy is
> "I made my terminal launch a different rocket every time I open a new tab."
> *(rockets cycling)*
> "That part was easy. The annoying part was when I realized—"
> *(jump cut, lean in)*
> "—I wanted the stars to be mathematically derived from the colors."
> "I have 2 to the 24th power colors. Across 6 roles. That's 10 to the 43rd possible rockets."
> *(text overlay: 10⁴³)*
> "I'm not going to see most of them. I'm going to see zero of them. I made it anyway."

**Feature dump (20–35s)** — fast
> "Favorites system. *(gold rocket)* They glow yellow so you know they're yours. Neon mode. *(neon rocket)* Every star is a different color. *(types `star weight 100`)* You can set it to 100 percent and only see your saved ones."
> *(rapid favorite rolls)*

**Turn (35–45s)** — deadpan
> "I named it [NAME]."
> *(beat)*
> "It's for fish and zsh. If you use bash... I respect the commitment."
> *(beat)*
> "If you use Windows... I'm sorry."

**Outro (45–50s)**
> "Link's in my bio."
> *(final rocket renders, hold 1s, end)*

### Footage to record

- [ ] **5–8 rocket reveals** for the cold-open rapid cuts (screen-record fresh tabs, chop later)
- [ ] **Default `bash` prompt** for the boring-terminal contrast shot
- [ ] **Gold favorite roll** — close-up of yellow star field
- [ ] **Neon roll** — multi-color star field
- [ ] **`star weight 100` typed live**, then 5 favorite rolls in a row
- [ ] **Talking-head shots** of you delivering each scripted beat (record more than you need)

### Edit notes

- **Editor**: CapCut (fastest for this style) or DaVinci Resolve
- **Cuts on beats**: align with audio waveform; even rough alignment makes pacing pop
- **Zoom punches**: 1.1x scale keyframe on important lines, 0.2s ease-out
- **Music**: 130–140bpm instrumental. Free options: YouTube Audio Library, Pixabay Music. Avoid trending sounds — they date tech content fast.
- **No watermarks**: turn off CapCut's default export stamp
- **Glitch transition** on "I made it anyway" sells the manic energy

### Caption

**TikTok:**
```
spent two weeks on this. zero (0) practical applications. proud of it.

#coding #developer #programmer #fishshell #zsh #terminal #cli #devtools #techtok #generative
```

**Instagram Reels** (slightly more grounded):
```
i made my terminal launch a different rocket every time i open a new tab. there are 10^43 possible rockets. i will never see most of them. anyway, link in bio.

#softwareengineering #generativeart #coding #developer #terminal
```

---

## 📊 Posting sequence

1. **Day 1 (Tue or Wed), 10am ET** — X first
2. **Day 1, 8pm ET** — LinkedIn version
3. **Day 2, morning** — TikTok/Reels. Can reference traction from day 1: "got X stars on GitHub overnight, here's what it does"
4. **Days 2–7** — reply to every comment across all platforms

---

## ✅ Pre-launch final check

- [x] Name locked in (find/replace `spaceport` across all files)
- [ ] GitHub username filled in across all files
- [ ] Repo created, files pushed, `docs/` populated
- [ ] README renders correctly on GitHub (all images load, GIF plays)
- [ ] `LICENSE` present
- [ ] One-line `curl` install tested on clean fish and zsh installs
- [ ] X copy and LinkedIn copy read out loud — sound like you?
- [ ] TikTok script rehearsed twice
- [ ] Phone charged (you'll be checking notifications constantly)
