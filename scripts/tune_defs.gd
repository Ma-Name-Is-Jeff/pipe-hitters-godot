class_name TuneDefs
extends RefCounted
## Tunable gameplay values shown in the phone tuning panel. Single source of truth for
## keys, defaults, ranges and labels. Values live in main.gd's `settings` dictionary.
## Each item has a Snappy default ("def", the shipping default) and a Classic value ("cls",
## the pre-v1b feel). Toggles are 0/1 sliders flagged "toggle".

const VERSION := "v1e"

static var _groups: Array = []


static func _s(key: String, label: String, snappy: float, classic: float, lo: float, hi: float, step: float) -> Dictionary:
	return {"key": key, "label": label, "def": snappy, "cls": classic, "min": lo, "max": hi, "step": step}


static func _t(key: String, label: String, snappy: int, classic: int) -> Dictionary:
	return {"key": key, "label": label, "def": float(snappy), "cls": float(classic), "min": 0.0, "max": 1.0, "step": 1.0, "toggle": true}


static func groups() -> Array:
	if not _groups.is_empty():
		return _groups
	_groups = [
		{"name": "Move", "items": [
			_s("move_speed", "Move speed (m/s)", 6.3, 5.6, 2.0, 12.0, 0.1),
			_s("accel", "Acceleration", 300.0, 32.0, 5.0, 400.0, 5.0),
			_s("decel", "Deceleration", 300.0, 12.0, 2.0, 400.0, 1.0),
			_s("sprint_speed", "Sprint speed", 9.5, 8.6, 4.0, 16.0, 0.1),
			_s("aim_slow", "Speed while shooting", 1.0, 0.5, 0.2, 1.0, 0.05),
			_s("slide_speed", "Slide speed", 11.2, 11.2, 4.0, 20.0, 0.1),
			_s("slide_dur", "Slide duration", 1.74, 1.74, 0.4, 4.0, 0.05),
		]},
		{"name": "Aim", "items": [
			_t("twin_stick", "Twin-stick mode", 0, 1),
			_s("lock_range", "Lock range (m)", 22.0, 22.0, 8.0, 40.0, 1.0),
			_s("lock_turn", "Lock turn (100 = instant)", 100.0, 100.0, 5.0, 100.0, 5.0),
			_t("autofire", "Auto-fire when locked", 0, 0),
			_s("settle_time", "Lock settle (s)", 0.3, 0.0, 0.0, 1.5, 0.05),
			_s("settle_spread", "Settle start spread", 0.06, 0.0, 0.0, 0.2, 0.005),
			_s("lock_grace", "Break-lock grace (s)", 0.15, 0.0, 0.0, 1.0, 0.05),
			_s("spread_still", "Spread still/crouch (x)", 1.0, 1.0, 0.5, 4.0, 0.1),
			_s("spread_walk", "Spread walking (x)", 1.8, 1.0, 0.5, 8.0, 0.1),
			_s("spread_sprint", "Spread sprinting (x)", 3.0, 1.0, 0.5, 10.0, 0.1),
			_s("spread_slide", "Spread sliding (x)", 4.0, 1.0, 0.5, 12.0, 0.1),
			_s("spread_blend", "Spread blend (s)", 0.15, 0.05, 0.0, 0.6, 0.01),
			_s("aim_sens", "Aim sensitivity (twin)", 70.0, 70.0, 20.0, 200.0, 1.0),
			_s("aim_curve", "Response curve (twin)", 2.0, 2.0, 0.5, 4.0, 0.1),
			_s("assist", "Assist strength (twin)", 70.0, 70.0, 0.0, 100.0, 1.0),
			_s("assist_cone", "Assist cone deg (twin)", 14.0, 14.0, 0.0, 40.0, 0.5),
			_s("assist_stick", "Assist stickiness (twin)", 1.85, 1.85, 1.0, 4.0, 0.05),
			_s("fire_thresh", "Auto-fire at stick (twin)", 0.4, 0.4, 0.2, 1.0, 0.01),
		]},
		{"name": "Fire", "items": [
			_s("fire_ms", "Fire interval (ms)", 125.0, 95.0, 40.0, 400.0, 5.0),
			_t("burst", "3-round bursts", 0, 1),
			_s("recoil", "Camera recoil kick", 0.0, 1.0, 0.0, 5.0, 0.1),
			_s("twitch", "Body twitch", 1.0, 0.0, 0.0, 3.0, 0.1),
			_s("bloom", "Bloom gain", 0.0, 1.35, 0.0, 4.0, 0.05),
			_s("spread", "Bullet spread", 0.002, 0.005, 0.0, 0.05, 0.001),
			_s("tracer_speed", "Tracer speed (m/s)", 160.0, 600.0, 40.0, 600.0, 10.0),
			_s("flash_size", "Muzzle star size", 0.6, 1.0, 0.0, 3.0, 0.1),
			_s("spark_n", "Wall sparks", 4.0, 1.0, 0.0, 10.0, 1.0),
		]},
		{"name": "Camera", "items": [
			_t("cam_northup", "North-up fixed camera", 1, 0),
			_s("cam_dist", "Camera distance", 14.5, 13.6, 6.0, 30.0, 0.2),
			_s("cam_pitch", "Camera pitch (deg)", 53.0, 60.0, 30.0, 85.0, 1.0),
			_s("cam_fov", "Field of view", 52.0, 52.0, 35.0, 90.0, 1.0),
			_s("cam_lag", "Follow lag (s, 0 = rigid)", 0.0, 0.12, 0.0, 0.5, 0.01),
			_s("cam_ahead", "Look-ahead (m)", 0.0, 3.15, 0.0, 6.0, 0.05),
			_s("zoom", "Zoom", 0.0, 0.0, 0.0, 100.0, 1.0),
		]},
		{"name": "FX/HUD", "items": [
			_t("laser", "Laser line to target", 1, 0),
			_t("brackets", "Target brackets", 1, 0),
			_t("dmg_nums", "Damage numbers", 1, 0),
			_t("tags", "Enemy name tags", 1, 0),
			_t("bars", "Enemy health bars", 0, 1),
			_t("arrows", "Off-screen enemy arrows", 1, 0),
			_s("vignette", "Damage vignette", 70.0, 0.0, 0.0, 100.0, 1.0),
			_s("hit_flash", "Enemy hit flash (ms)", 140.0, 120.0, 0.0, 400.0, 10.0),
			_t("hud_bottom", "Bottom-center HUD", 1, 0),
		]},
		{"name": "Enemy", "items": [
			_s("enemy_hp", "Enemy health (hits)", 8.0, 4.0, 1.0, 20.0, 1.0),
			_s("enemy_acc", "Enemy accuracy", 50.0, 50.0, 0.0, 100.0, 1.0),
		]},
	]
	return _groups


static func all_items() -> Array:
	var out := []
	for g in groups():
		for it in g["items"]:
			out.append(it)
	return out


## Every persisted tuning key and its default (includes the enemy mode flag). Snappy = default.
static func defaults() -> Dictionary:
	var d := {}
	for it in all_items():
		d[it["key"]] = it["def"]
	d["enemy_active"] = false
	return d


## Values for a named preset ("snappy" or "classic").
static func preset_values(name: String) -> Dictionary:
	var d := {}
	for it in all_items():
		d[it["key"]] = it["cls"] if name == "classic" else it["def"]
	return d


static func clamp_value(key: String, v: float) -> float:
	for it in all_items():
		if it["key"] == key:
			return clampf(v, it["min"], it["max"])
	return v
