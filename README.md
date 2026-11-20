# Pipe Hitters (Godot 4)

Original twin-stick run-and-gun prototype, rebuilt in Godot 4.7 (Compatibility renderer) entirely from code: procedural soldier rig, compound level, synth sounds. No external assets.

Play: https://ma-name-is-jeff.github.io/pipe-hitters-godot/

- Touch: left stick moves (camera-relative), right stick aims and fires past the ring, swipe to orbit, pinch to zoom, double-tap to recenter.
- Desktop: WASD, mouse aim, click to shoot, Shift sprint, Space vault, C/Ctrl slide, R reload, Q or 1/2 swap, right-drag orbit, wheel zoom, Esc or P pause.

Build: `tools/build_web.sh` (single-threaded web export into `docs/`). Smoke check: `godot --headless --path . --script res://tools/check.gd`.
