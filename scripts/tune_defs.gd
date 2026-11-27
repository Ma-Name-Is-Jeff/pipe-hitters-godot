class_name TuneDefs
extends RefCounted
## Tunable gameplay values shown in the phone tuning panel. Single source of truth for
## keys, defaults, ranges and labels. Values live in main.gd's `settings` dictionary.

const VERSION := "v1a"

# Each item: key, label, default, min, max, step
const GROUPS := [
	{"name": "Move", "items": [
		{"key": "move_speed", "label": "Move speed", "def": 5.6, "min": 2.0, "max": 12.0, "step": 0.1},
		{"key": "accel", "label": "Acceleration", "def": 32.0, "min": 5.0, "max": 100.0, "step": 1.0},
		{"key": "decel", "label": "Deceleration", "def": 12.0, "min": 2.0, "max": 40.0, "step": 0.5},
		{"key": "sprint_speed", "label": "Sprint speed", "def": 8.6, "min": 4.0, "max": 16.0, "step": 0.1},
		{"key": "slide_speed", "label": "Slide speed", "def": 11.2, "min": 4.0, "max": 20.0, "step": 0.1},
		{"key": "slide_dur", "label": "Slide duration", "def": 1.74, "min": 0.4, "max": 4.0, "step": 0.05},
	]},
	{"name": "Aim", "items": [
		{"key": "aim_sens", "label": "Aim sensitivity", "def": 70.0, "min": 20.0, "max": 200.0, "step": 1.0},
		{"key": "aim_curve", "label": "Response curve", "def": 2.0, "min": 0.5, "max": 4.0, "step": 0.1},
		{"key": "assist", "label": "Assist strength", "def": 70.0, "min": 0.0, "max": 100.0, "step": 1.0},
		{"key": "assist_cone", "label": "Assist cone (deg)", "def": 14.0, "min": 0.0, "max": 40.0, "step": 0.5},
		{"key": "assist_stick", "label": "Assist stickiness", "def": 1.85, "min": 1.0, "max": 4.0, "step": 0.05},
	]},
	{"name": "Fire", "items": [
		{"key": "fire_thresh", "label": "Auto-fire at stick", "def": 0.4, "min": 0.2, "max": 1.0, "step": 0.01},
		{"key": "fire_ms", "label": "Fire interval (ms)", "def": 95.0, "min": 40.0, "max": 400.0, "step": 5.0},
		{"key": "recoil", "label": "Recoil kick", "def": 1.0, "min": 0.0, "max": 5.0, "step": 0.1},
		{"key": "bloom", "label": "Bloom gain", "def": 1.35, "min": 0.0, "max": 4.0, "step": 0.05},
		{"key": "spread", "label": "Bullet spread", "def": 0.005, "min": 0.0, "max": 0.05, "step": 0.001},
	]},
	{"name": "Camera", "items": [
		{"key": "cam_dist", "label": "Camera distance", "def": 13.6, "min": 6.0, "max": 30.0, "step": 0.2},
		{"key": "cam_pitch", "label": "Camera pitch (deg)", "def": 60.0, "min": 30.0, "max": 85.0, "step": 1.0},
		{"key": "cam_fov", "label": "Field of view", "def": 52.0, "min": 35.0, "max": 90.0, "step": 1.0},
		{"key": "zoom", "label": "Zoom", "def": 0.0, "min": 0.0, "max": 100.0, "step": 1.0},
	]},
	{"name": "Enemy", "items": [
		{"key": "enemy_hp", "label": "Enemy health", "def": 4.0, "min": 1.0, "max": 20.0, "step": 1.0},
		{"key": "enemy_acc", "label": "Enemy accuracy", "def": 50.0, "min": 0.0, "max": 100.0, "step": 1.0},
	]},
]


static func all_items() -> Array:
	var out := []
	for g in GROUPS:
		for it in g["items"]:
			out.append(it)
	return out


## Every persisted tuning key and its default (includes the enemy mode flag).
static func defaults() -> Dictionary:
	var d := {}
	for it in all_items():
		d[it["key"]] = it["def"]
	d["enemy_active"] = false
	return d


static func clamp_value(key: String, v: float) -> float:
	for it in all_items():
		if it["key"] == key:
			return clampf(v, it["min"], it["max"])
	return v
