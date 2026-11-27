# Pipe Hitters (Godot) — Roadmap

Status key: **live** = pushed + deployed · **local** = committed locally only · **in progress** · **todo**
The live site is at v1f. This release pushes v1d–v1f (the site was previously at v1c, `27493fa`).
Every priority below is a must-have. Only the order is fixed.

## Priorities (in order)

| # | Priority | Status |
|---|----------|--------|
| 1 | **Arena feel.** Tuning Arena, tuning panel, "Snappy" default preset and "Classic" preset | in progress (v1f live) |
| 2 | **Mission loop with loot and upgrades.** Weapon classes and weapon parts, plus gear: vests, rigs, helmets | todo |
| 3 | **Stealth with alerts, and bosses** | todo |
| 4 | **Home base** | todo |
| 5 | **The gym.** Train stats with a punching bag, sparring, weights and running | todo |
| 6 | **Skin sets.** Face or helmet, top, bottom. Fun onesie skins (banana, monkey, dino, etc.) as rare unlocks | todo |

None of items 2–6 are started. This is a docs-only note.

## Done so far

| Step | What | Status |
|------|------|--------|
| Port | Godot 4 port, parity with the Three.js prototype | live |
| Mood | Night-op mood, squadmates, soldier rig, synth audio | live (fad44ed) |
| v1a | Tuning Arena (40x40, cover, hurdle, slide wall), Line Carbine, respawning dummy enemy, static/active AI toggle, on-phone tuning panel (22 sliders, persist, copy/paste/reset) | live |
| v1b | Snappy preset (default) + Classic preset: north-up rigid camera, hard auto-lock + laser, FIRE button, 8 rounds/s, hit feedback, edge arrows, bottom-center HUD. Every piece has a tuning slider or toggle | live |
| v1c | Default enemy takes 5 hits (~0.6s TTK). Arena slightly brighter (moonlight/ambient/exposure bump), still clearly night | live |
| v1d | 8-hit default (~1s TTK), subtler muzzle flash, 2x touch controls, lock settle + movement accuracy (Aim tab) | live |
| v1e | Touch controls: FIRE stays ~2x v1c, other buttons and the stick 1.6x, semi-transparent, tighter right cluster | live |
| v1f | Pause/TUNE sliders for button size (50–150%, default 100%) and opacity (20–100%, default 50%), persisted, live preview | live |
| v1g | Fluid soldier rig: thicker action-figure build, turret spine twist (pelvis follows velocity, chest/rifle follow aim, clamp ~90°), forward/backpedal/strafe gait blend driven by distance (no foot skate), bob, weight shift, lean spring, idle breathing, rifle bob lag + fire kick. Anim tuning tab | live |
| v1h | Soldier look: rounded, smooth chunky rebuild (tapered bulging limbs, round joints, beveled plate carrier, dome helmet + ear-pro, face mask, gloves, boots), rim light, shared meshes. Visual only, rig/animation unchanged | local |
| v1i | Real 3D model: original Blender-built soldier (one skinned ~7k-tri mesh, 22-bone humanoid rig, auto weights, PBR slots, team colors set in Godot) and original 0.9 m rifle with grip/support/muzzle markers, exported as .glb. Skeleton driven by the v1g animation logic, two-hand IK on the markers, Classic rig fallback toggle in the Anim tab. Sources in `art/src/` (Blender 5.2.5 LTS) | local |
| later | Bake Bran's tuned values in as the defaults (once he sends them from the Copy values button) | todo |
| later | Hard mode: enemies take ~1s or 10 hits to down (whichever is longer) | todo |

## Workflow

- Small versions, with a `pre-<ver>` git tag and a `backup-pre-<ver>/` folder before each.
- One targeted test and 2–3 screenshots per version (screenshots in `shots/`).
- Local commits only, until Bran says "push".
- Everything stays fully original: no copyrighted assets, brands or copied names.
