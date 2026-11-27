# Pipe Hitters (Godot) — Roadmap

Status key: **live** = pushed + deployed · **local** = committed locally only · **in progress** · **todo**
The live site is pinned at `fad44ed`. Nothing is pushed until Bran says "push".
Every priority below is a must-have. Only the order is fixed.

## Priorities (in order)

| # | Priority | Status |
|---|----------|--------|
| 1 | **Arena feel.** Tuning Arena, tuning panel, "Snappy" default preset and "Classic" preset | in progress (v1a local, v1b building) |
| 2 | **Mission loop with loot and upgrades.** Weapon classes and weapon parts, plus gear: vests, rigs, helmets | todo |
| 3 | **Stealth with alerts, and bosses** | todo |
| 4 | **Home base** | todo |
| 5 | **The gym.** Train stats with a punching bag, sparring, weights and running | todo |
| 6 | **Skin sets.** Face or helmet, top, bottom | todo |

None of items 2–6 are started. This is a docs-only note.

## Done so far

| Step | What | Status |
|------|------|--------|
| Port | Godot 4 port, parity with the Three.js prototype | live |
| Mood | Night-op mood, squadmates, soldier rig, synth audio | live (fad44ed) |
| v1a | Tuning Arena (40x40, cover, hurdle, slide wall), Line Carbine, respawning dummy enemy, static/active AI toggle, on-phone tuning panel (22 sliders, persist, copy/paste/reset) | local |
| v1b | Snappy preset (default) + Classic preset: north-up rigid camera, hard auto-lock + laser, FIRE button, 8 rounds/s, hit feedback, edge arrows, bottom-center HUD. Every piece has a tuning slider or toggle | in progress |
| v1c | Bake Bran's tuned values in as the defaults (once he sends them from the Copy values button) | todo |

## Workflow

- Small versions, with a `pre-<ver>` git tag and a `backup-pre-<ver>/` folder before each.
- One targeted test and 2–3 screenshots per version (screenshots in `shots/`).
- Local commits only, until Bran says "push".
- Everything stays fully original: no copyrighted assets, brands or copied names.
