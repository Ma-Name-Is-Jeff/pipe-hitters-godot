# Art licenses

## Soldier base mesh (v1k+) — MakeHuman assets, CC0 1.0

- **Source:** MakeHuman project, `makehuman/data/3dobjs/base.obj` and the body targets in `makehuman/data/targets/`
  (https://github.com/makehumancommunity/makehuman, master branch, fetched 2026-11-26).
- **License:** Creative Commons CC0 1.0 Universal (public domain dedication).
  - Repo license, section C: "The assets are defined as any data contributing to the graphical output of MakeHuman.
    This includes: The base mesh and proxies, Targets and modifiers, ... These assets have been released under CC0 1.0 Universal."
    (https://github.com/makehumancommunity/makehuman/blob/master/LICENSE.md)
  - Each target file carries the header "This asset was explicitly released as CC0 in september 2020."
  - Full legal text: `art/src/makehuman/LICENSE.ASSETS.md` (copy of the repo's LICENSE.ASSETS.md),
    https://creativecommons.org/publicdomain/zero/1.0/
- **Files kept:** `art/src/makehuman/base.obj`, `art/src/makehuman/targets/*.target` (only the ones we use).
- **What we changed (our own work, `art/src/build_soldier.py`):** our own target mix (balanced chunky young male, no V-taper),
  straightened legs, longer arms, larger gloved hands with fingers curled into a grip, cartoony radial thickening of
  limbs/torso, slightly larger head, buzz-cut hair, fatigue volume (shirt, trousers, gloves), our own boots (replacing
  the bare feet), our own 22-bone rig and weights, original palette/materials, decimated to <10k tris.
- No MakeHuman program code (AGPL) is used or shipped — only CC0 asset data, parsed by our own script.

## Rejected candidates (2026-11-26)

- Quaternius "Universal Base Characters": the pack page still says CC0, but quaternius.com/license.html now shows the
  "Quaternius Asset License (QAL) v1.0" (updated 8/28/2026), which governs assets obtained now and forbids
  redistributing the asset files. That is not CC0 (and our repo is public), so rejected.
- Kenney "Animated Characters" (CC0): license is fine, but it is a chibi low-poly figure, far from the thick
  stylized-realistic look we want, so not used.

## Rifle, environment, everything else

Original, made procedurally in this repo (`art/src/build_rifle.py`, scripts). No third-party assets.
