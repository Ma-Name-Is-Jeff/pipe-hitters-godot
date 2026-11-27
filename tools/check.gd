extends SceneTree
## Headless smoke check: load main scene, run frames, play a mission, verify key numbers.

var frames := 0
var main: Node
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print(("OK   " if cond else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not cond:
		fails += 1


func _initialize() -> void:
	var ps: PackedScene = load("res://main.tscn")
	main = ps.instantiate()
	root.add_child(main)


func _process(_dt: float) -> bool:
	frames += 1
	if frames == 5:
		main._start_play()
		ok("playing", main.playing)
		ok("obstacles", main.obstacles.size() > 100, str(main.obstacles.size()))
		ok("bots", main.bots.size() == 9)
		# Camera-relative mapping: stick up = away from camera.
		var w: Vector2 = main.screen_to_world(0, 1, 0.0)
		ok("stick up at yaw0 -> -Z", w.distance_to(Vector2(0, -1)) < 1e-5, str(w))
		w = main.screen_to_world(1, 0, 0.0)
		ok("stick right at yaw0 -> +X", w.distance_to(Vector2(1, 0)) < 1e-5, str(w))
		# Facing PI (north, -Z): moving +X (screen right) is the soldier's right.
		var side: float = main.slide_side_from_dir(1, 0, PI)
		ok("slide right side>0", side > 0.9, str(side))
		side = main.slide_side_from_dir(-1, 0, PI)
		ok("slide left side<0", side < -0.9, str(side))
		# Zoom curve.
		ok("zoom ends", main.zoom_t(0) == 0.0 and main.zoom_t(100) == 1.0)
	if frames == 6:
		# Side slide to the right: head must lean to the soldier's right.
		var s: Soldier = main.soldier
		main.yaw = PI
		for i in 60:
			s.pose(0.016, 0.0, 0.0, 1.0, 1.0, false, -1.0, false, false, -1.0)
		s.rotation.y = PI
		var head_x: float = s.head.global_position.x - s.global_position.x
		ok("right slide leans right (+X when facing -Z)", head_x > 0.15, "%.3f" % head_x)
		for i in 60:
			s.pose(0.016, 0.0, 0.0, 1.0, -1.0, false, -1.0, false, false, -1.0)
		head_x = s.head.global_position.x - s.global_position.x
		ok("left slide leans left", head_x < -0.15, "%.3f" % head_x)
		# Two-handed grip: hands at their grip targets.
		for i in 30:
			s.pose(0.016, 0.0, 0.0, 0.0, 0.0, false, -1.0, true, false, -1.0)
		var dr := s.hands[1].global_position.distance_to(s.grip_r.global_position)
		var dl := s.hands[0].global_position.distance_to(s.grip_l.global_position)
		ok("trigger hand on grip", dr < 0.03, "%.3f" % dr)
		ok("support hand on handguard", dl < 0.06, "%.3f" % dl)
		var gun_fwd := -s.gun.global_basis.z
		ok("rifle points forward when aiming", (s.gun.global_basis.z).dot(Vector3(0, 0, -1)) > 0.9, str(s.gun.global_basis.z))
	if frames == 8:
		# Slide into a wall stops.
		main.pos = Vector3(0, 0, 45.0)
		main.yaw = PI
		main.stance = "stand"
		main.vel = Vector3.ZERO
		main.view_yaw = 0.0
		main.stance = "slide"
		main.slide_t = main._slide_dur()
		main.vel = Vector3(0, 0, -main._slide_boost())
	if frames == 60:
		ok("slide stopped at low wall or vaulted", main.stance != "slide", main.stance + " z=%.2f" % main.pos.z)
	if frames == 70:
		main.settings["zoom"] = 100.0
	if frames == 140:
		var cam: Camera3D = main.camera
		var pitch := -cam.rotation.x
		ok("full zoom near eye level", pitch < 0.3 and cam.position.y < 2.4, "pitch=%.3f y=%.2f" % [pitch, cam.position.y])
		main.settings["zoom"] = 0.0
	if frames == 220:
		var cam2: Camera3D = main.camera
		ok("zoom out to preset pitch", absf(-cam2.rotation.x - deg_to_rad(float(main.settings["cam_pitch"]))) < 0.08, "pitch=%.3f" % -cam2.rotation.x)
		print("CHECK DONE fails=%d" % fails)
		quit(1 if fails > 0 else 0)
	return false
