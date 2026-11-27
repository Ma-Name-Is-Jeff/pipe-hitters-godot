extends SceneTree
## Targeted v1g test: turret twist clamp, distance-driven foot-plant phase, gait blend,
## fire kick spring, Anim tab, locked movement values, and a live game run (no script errors).
##   godot --headless --path . --script res://tools/test_v1g.gd

var main: Node
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print(("OK   " if cond else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not cond:
		fails += 1


func wait(sec: float) -> void:
	await create_timer(sec).timeout


func _initialize() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	run()


func _rig() -> Soldier:
	var s := Soldier.new()
	root.add_child(s)
	s.setup(Color.GRAY, Color.GRAY, Color.GRAY, Color.GRAY, Color.GRAY, Color.GRAY, Color.GRAY)
	s.position = Vector3(500, 0, 500)
	s.pose(1.0 / 60.0, 0.0, 0.0, 0.0, 0.0, false, -1.0, false, false, -1.0)
	return s


## Move a rig along world direction `dir` at speed v for `sec` seconds, step dt.
## Returns the max |twist| seen (deg) after the first 0.3s.
func _drive(s: Soldier, dir: Vector3, v: float, sec: float, dt: float, aiming := true) -> float:
	var mx := 0.0
	var t := 0.0
	while t < sec:
		s.position += dir.normalized() * v * dt
		s.pose(dt, v, 0.0, 0.0, 0.0, false, -1.0, aiming, false, -1.0)
		t += dt
		if t > 0.3:
			mx = maxf(mx, absf(rad_to_deg(s.last_twist)))
	return mx


func run() -> void:
	await process_frame
	await process_frame
	main.reset_tuning()
	main._save_settings()
	ok("version v1g or later", ["v1g", "v1h", "v1i"].has(TuneDefs.VERSION))
	var locked := [["move_speed", 6.3], ["accel", 300.0], ["decel", 300.0], ["sprint_speed", 9.5], ["aim_slow", 1.0], ["slide_speed", 11.2], ["slide_dur", 1.74]]
	var bad := []
	for kv in locked:
		if not is_equal_approx(main._t(kv[0]), kv[1]):
			bad.append("%s=%s" % [kv[0], main._t(kv[0])])
	ok("locked movement values unchanged", bad.is_empty(), ", ".join(bad))
	var anim_keys := ["anim_bob", "anim_lean", "anim_twist", "anim_cadence", "anim_knee", "anim_sway", "anim_kick"]
	var have := true
	for k in anim_keys:
		have = have and main.ui.tune_sliders.has(k)
	var anim_tab := false
	for g in TuneDefs.groups():
		if g["name"] == "Anim":
			anim_tab = g["items"].size() >= 7
	ok("Anim tab with 7 sliders", have and anim_tab)
	Soldier.set_anim(main.settings)

	# --- Twist clamp ---
	var s := _rig()
	s.rotation.y = 0.0
	var worst := 0.0
	var strafe_side := 0.0
	for i in 16:
		var ang := TAU * float(i) / 16.0
		var d := Vector3(sin(ang), 0, cos(ang))
		worst = maxf(worst, _drive(s, d, 6.3, 0.8, 1.0 / 60.0))
		if i == 4:
			strafe_side = absf(s.gait_dir.x)
	ok("twist stays within 90 deg clamp (16 move dirs)", worst <= 90.5, "max=%.1f" % worst)
	ok("pure strafe blends a sideways leg cycle", strafe_side > 0.4, "gait side=%.2f" % strafe_side)
	_drive(s, Vector3(0, 0, -1), 6.3, 1.0, 1.0 / 60.0)
	ok("backpedal: pelvis faces aim, legs cycle backward", absf(rad_to_deg(s.hip_yaw)) < 10.0 and s.gait_dir.y < -0.8, "hip=%.1f gait=%s" % [rad_to_deg(s.hip_yaw), s.gait_dir])
	_drive(s, Vector3(0, 0, 1), 6.3, 1.0, 1.0 / 60.0)
	ok("forward: pelvis faces velocity", absf(rad_to_deg(s.hip_yaw)) < 3.0 and s.gait_dir.y > 0.95)
	Soldier.anim["twist"] = 30.0
	worst = 0.0
	for i in 16:
		var ang2 := TAU * float(i) / 16.0
		worst = maxf(worst, _drive(s, Vector3(sin(ang2), 0, cos(ang2)), 6.3, 0.6, 1.0 / 60.0))
	ok("twist clamp slider (30 deg) respected", worst <= 30.5, "max=%.1f" % worst)
	Soldier.set_anim(main.settings)
	# Idle: whip the aim around; lower body lags but never past the clamp, then catches up.
	var mx := 0.0
	for i in 30:
		s.rotation.y += 0.25
		s.pose(1.0 / 60.0, 0.0, 0.0, 0.0, 0.0, false, -1.0, true, false, -1.0)
		mx = maxf(mx, absf(rad_to_deg(s.last_twist)))
	ok("fast aim turn: twist clamped", mx <= 90.5, "max=%.1f" % mx)
	for i in 90:
		s.pose(1.0 / 60.0, 0.0, 0.0, 0.0, 0.0, false, -1.0, true, false, -1.0)
	ok("idle: lower body faces aim", absf(rad_to_deg(s.last_twist)) < 2.0, "twist=%.2f" % rad_to_deg(s.last_twist))

	# --- Foot-plant phase vs distance ---
	var a := _rig()
	var b := _rig()
	var p0a := a.gait_phase
	var p0b := b.gait_phase
	_drive(a, Vector3(0, 0, 1), 6.3, 2.0, 1.0 / 60.0)
	_drive(b, Vector3(0, 0, 1), 6.3, 2.0, 1.0 / 20.0)
	var da := a.gait_phase - p0a
	var db := b.gait_phase - p0b
	var expect := PI * a.dist_total / a.step_len
	ok("phase advance = PI * distance / step length", absf(da - expect) < 0.02, "phase=%.3f expect=%.3f dist=%.2f step=%.2f" % [da, expect, a.dist_total, a.step_len])
	ok("phase independent of frame rate (60 vs 20 fps)", absf(da - db) / da < 0.03, "%.3f vs %.3f" % [da, db])
	var cad := 6.3 / a.step_len
	ok("cadence 4-5 steps/s at run speed", cad >= 4.0 and cad <= 5.0, "%.2f steps/s, step %.2f m" % [cad, a.step_len])
	var pz := a.gait_phase
	for i in 30:
		a.pose(1.0 / 60.0, 6.3, 0.0, 0.0, 0.0, false, -1.0, true, false, -1.0)
	ok("no distance -> no phase change (no running in place)", is_equal_approx(a.gait_phase, pz))
	# Planted foot slip: the lower foot's world speed should be far below body speed.
	var c := _rig()
	_drive(c, Vector3(0, 0, 1), 6.3, 0.5, 1.0 / 60.0)
	var slip := 0.0
	var n := 0
	var prev := [c.feet[0].global_position, c.feet[1].global_position]
	for i in 90:
		c.position += Vector3(0, 0, 6.3 / 60.0)
		c.pose(1.0 / 60.0, 6.3, 0.0, 0.0, 0.0, false, -1.0, true, false, -1.0)
		var f0: Vector3 = c.feet[0].global_position
		var f1: Vector3 = c.feet[1].global_position
		# Stance leg from the gait phase (left: first half of the cycle); skip lift-off/touch-down.
		var u := fposmod(c.gait_phase / TAU, 1.0)
		var low := 0 if u < 0.5 else 1
		var us := fposmod(u, 0.5) / 0.5
		var cur: Vector3 = f0 if low == 0 else f1
		var pv: Vector3 = prev[low]
		if us > 0.1 and us < 0.85:
			slip += Vector2(cur.x - pv.x, cur.z - pv.z).length() * 60.0
			n += 1
		prev = [f0, f1]
	slip /= float(n)
	ok("planted foot: stance foot nearly still (no ice-skating)", slip < 6.3 * 0.15, "avg stance-foot speed %.2f m/s vs body 6.3" % slip)
	var hips_y := []
	for i in 40:
		c.position += Vector3(0, 0, 6.3 / 60.0)
		c.pose(1.0 / 60.0, 6.3, 0.0, 0.0, 0.0, false, -1.0, true, false, -1.0)
		hips_y.append(c.hips.position.y)
	var bob: float = hips_y.max() - hips_y.min()
	ok("root bob ~5-8% of height", bob >= 0.05 * 1.9 * 0.8 and bob <= 0.08 * 1.9 * 1.1, "bob=%.3f m" % bob)
	ok("leans into velocity (10-15 deg)", rad_to_deg(c.body.rotation.x) > 6.0 and rad_to_deg(c.body.rotation.x) < 16.0, "lean=%.1f" % rad_to_deg(c.body.rotation.x))

	# --- Kick spring ---
	var k := _rig()
	for i in 20:
		k.pose(1.0 / 60.0, 0.0, 0.0, 0.0, 0.0, false, -1.0, true, false, -1.0)
	var g0: Vector3 = k.gun.position
	k.kick(1.0)
	var back := 0.0
	for i in 4:
		k.pose(1.0 / 60.0, 0.0, 0.0, 0.0, 0.0, false, -1.0, true, false, -1.0)
		back = maxf(back, -(k.gun.basis.inverse() * (k.gun.position - g0)).z)
	for i in 40:
		k.pose(1.0 / 60.0, 0.0, 0.0, 0.0, 0.0, false, -1.0, true, false, -1.0)
	var rest: float = (k.gun.position - g0).length()
	ok("fire kick pushes rifle back, then springs back", back > 0.02 and rest < 0.01, "back=%.3f rest=%.4f" % [back, rest])
	var hand_err: float = (k.hands[0].position - k.gun.transform * k.grip_l.position).length()
	ok("support hand stays on rifle (IK)", hand_err < 0.06, "%.3f" % hand_err)

	# --- Live game: strafe while locked on (twist), rig keeps working ---
	main._start_arena()
	main._set_touch_mode(true)
	await wait(0.3)
	main.pos = Vector3(-6, 0, 4)
	main.vel = Vector3.ZERO
	var d0: float = main.soldier.dist_total
	main.move_id = 7
	main.move_v = Vector2(1, 0)
	var tw := 0.0
	for i in 50:
		await process_frame
		tw = maxf(tw, absf(rad_to_deg(main.soldier.hip_yaw)))
	main.move_id = -1
	main.move_v = Vector2.ZERO
	var moved: float = main.soldier.dist_total - d0
	ok("in game: player rig gait advances while moving", moved > 0.5, "dist=%.2f" % moved)
	ok("in game: hips twist off aim while strafing", tw > 15.0 and tw <= 90.5, "max twist=%.1f yaw=%.2f" % [tw, main.yaw])
	print("V1G TEST DONE fails=", fails)
	quit()
