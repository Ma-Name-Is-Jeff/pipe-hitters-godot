# Pipe Hitters (Godot) — Roadmap

Status key: **live** = pushed + deployed · **local** = committed locally only · **in progress** · **todo**
The live site is at v1c (`27493fa`). Nothing newer is pushed until Bran says "push".
Every priority below is a must-have. Only the order is fixed.

## Priorities (in order)

| # | Priority | Status |
|---|----------|--------|
| 1 | **Arena feel.** Tuning Arena, tuning panel, "Snappy" default preset and "Classic" preset | in progress (v1c live; v1d local) |
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
| v1b | Snappy preset (default) + Classic preset: north-up rigid camera, hard auto-lock + laser, FIRE button, 8 rounds/s, hit feedback, edge arrows, bottom-center HUD. Every piece has a tuning slider or toggle | local |
| v1c | Default enemy takes 5 hits (~0.6s TTK). Arena slightly brighter (moonlight/ambient/exposure bump), still clearly night | live |
| v1d | 8-hit default (~1s TTK), subtler muzzle flash, 2x touch controls, lock settle + movement accuracy (Aim tab) | local |
| later | Bake Bran's tuned values in as the defaults (once he sends them from the Copy values button) | todo |
| later | Hard mode: enemies take ~1s or 10 hits to down (whichever is longer) | todo |

## Workflow

- Small versions, with a `pre-<ver>` git tag and a `backup-pre-<ver>/` folder before each.
- One targeted test and 2–3 screenshots per version (screenshots in `shots/`).
- Local commits only, until Bran says "push".
- Everything stays fully original: no copyrighted assets, brands or copied names.
