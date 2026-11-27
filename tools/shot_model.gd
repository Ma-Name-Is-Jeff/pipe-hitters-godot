extends SceneTree
## Renders the v1i model: close front 3/4 of the player soldier holding the rifle.
##   godot --path . --script res://tools/shot_model.gd -- out.png [pose]
## pose: aim (default) | run | grid (aim/run/strafe/crouch/slide lineup)
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "res://shots/v1i-model.png"
	var mode: String = args[1] if args.size() > 1 else "aim"
	DisplayServer.window_set_size(Vector2i(900, 1000) if mode != "grid" else Vector2i(1500, 700))
	root.size = DisplayServer.window_get_size()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.08, 0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.46, 0.58)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color(0.95, 0.95, 1.0)
	key.light_energy = 1.6
	key.shadow_enabled = true
	key.rotation_degrees = Vector3(-40, 35, 0)
	root.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.5, 0.8, 1.0)
	rim.light_energy = 0.9
	rim.rotation_degrees = Vector3(-20, 200, 0)
	root.add_child(rim)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.13, 0.15, 0.17)
	floor.material_override = fm
	root.add_child(floor)
	var specs := [
		[Color8(46, 48, 52), Color8(40, 42, 46), Color8(34, 36, 38), Color8(44, 46, 48), Color8(30, 32, 34), Color8(196, 160, 132), Color8(30, 31, 33), Color8(20, 20, 22), Color8(70, 230, 210), Color(0.02, 0.05, 0.07)],
		[Color8(86, 68, 48), Color8(68, 55, 41), Color8(80, 52, 35), Color8(66, 52, 38), Color8(52, 40, 30), Color8(214, 186, 156), Color8(40, 34, 30), Color8(70, 56, 44), Color8(255, 60, 40), Color(0.11, 0.05, 0.02)],
	]
	var cam := Camera3D.new()
	root.add_child(cam)
	var sol: Array = []
	if mode == "grid":
		var poses := ["aim", "run", "strafe", "crouch", "slide", "down"]
		for i in poses.size():
			var a: Array = specs[i % 2]
			var s := Soldier.new()
			s.setup(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9])
			root.add_child(s)
			s.position = Vector3(-3.75 + 1.5 * i, 0, 0)
			s.rotation.y = 0.6
			sol.append([s, poses[i]])
		cam.fov = 46
		cam.look_at_from_position(Vector3(0, 3.0, 7.5), Vector3(0, 0.8, 0))
	else:
		var a: Array = specs[0]
		var s := Soldier.new()
		s.setup(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9])
		root.add_child(s)
		s.rotation.y = 0.0
		sol.append([s, mode])
		cam.fov = 32
		var cp := Vector3(1.6, 1.55, 3.2)
		if args.size() > 2 and args[2] == "side":
			cp = Vector3(4.0, 1.3, 0.3)
		elif args.size() > 2 and args[2] == "head":
			cp = Vector3(0.7, 1.82, 1.1)
			cam.fov = 22
		elif args.size() > 2 and args[2] == "headside":
			cp = Vector3(1.4, 1.75, 0.0)
			cam.fov = 22
		elif args.size() > 2 and args[2] == "shoulder":
			cp = Vector3(-1.2, 1.9, 1.3)
			cam.fov = 28
		elif args.size() > 2 and args[2] == "back":
			cp = Vector3(-1.5, 1.6, -3.0)
		elif args.size() > 2 and args[2] == "top":
			cp = Vector3(0.01, 4.5, 0.6)
		cam.look_at_from_position(cp, Vector3(0.0, 1.75 if args.size() > 2 and (args[2].begins_with("head") or args[2] == "shoulder") else 1.0, 0.0))
	for f in 40:
		for e in sol:
			var s: Soldier = e[0]
			var pz: String = e[1]
			var dt := 1.0 / 30.0
			match pz:
				"aim":
					s.pose(dt, 0.0, 0.0, 0.0, 0.0, false, -1.0, true, false, -1.0)
				"run":
					s.position += Vector3(sin(s.rotation.y), 0, cos(s.rotation.y)) * 6.3 * dt
					s.pose(dt, 6.3, 0.0, 0.0, 0.0, false, -1.0, false, false, -1.0)
				"strafe":
					s.position += Vector3(cos(s.rotation.y), 0, -sin(s.rotation.y)) * 6.3 * dt
					s.pose(dt, 6.3, 0.0, 0.0, 0.0, false, -1.0, true, false, -1.0)
				"crouch":
					s.pose(dt, 0.0, 0.0, 0.0, 0.0, true, -1.0, true, false, -1.0)
				"slide":
					s.pose(dt, 0.0, 0.0, 1.0, 0.0, false, -1.0, true, false, -1.0)
				"down":
					s.pose(dt, 0.0, 0.0, 0.0, 0.0, false, -1.0, false, true, -1.0)
		await process_frame
	# Moving soldiers travelled; put everyone back on their lineup spot for the frame.
	for i in sol.size():
		if mode == "grid":
			(sol[i][0] as Soldier).position = Vector3(-3.75 + 1.5 * i, 0, 0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
