extends SceneTree
## Renders a close-up lineup (player, enemy, squad) to shots/v1h-soldier.png. Needs a display.
##   godot --path . --script res://tools/shot_soldier.gd
func _initialize() -> void:
	var win := root
	win.size = Vector2i(1100, 560)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.07, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.42, 0.55)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.72, 1.0)
	moon.light_energy = 1.0
	moon.rotation_degrees = Vector3(-55, 30, 0)
	root.add_child(moon)
	var flood := OmniLight3D.new()
	flood.light_color = Color(0.9, 0.95, 1.0)
	flood.light_energy = 1.4
	flood.omni_range = 9.0
	flood.position = Vector3(0, 4, 2.5)
	root.add_child(flood)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.12, 0.15, 0.17)
	floor.material_override = fm
	root.add_child(floor)
	var specs := [
		[Color8(46, 48, 52), Color8(40, 42, 46), Color8(34, 36, 38), Color8(44, 46, 48), Color8(30, 32, 34), Color8(196, 160, 132), Color8(30, 31, 33), Color8(20, 20, 22), Color8(70, 230, 210), Color(0.02, 0.05, 0.07)],
		[Color8(128, 104, 78), Color8(96, 80, 62), Color8(110, 70, 46), Color8(92, 72, 52), Color8(70, 52, 38), Color8(214, 186, 156), Color8(40, 34, 30), Color8(70, 56, 44), Color8(255, 60, 40), Color(0.11, 0.05, 0.02)],
		[Color8(60, 90, 96), Color8(44, 62, 70), Color8(34, 36, 38), Color8(46, 50, 50), Color8(30, 32, 34), Color8(186, 150, 122), Color8(30, 31, 33), Color8(22, 22, 24), Color8(70, 230, 210), Color(0.02, 0.05, 0.07)],
	]
	var sol: Array[Soldier] = []
	for i in 3:
		var s := Soldier.new()
		var a: Array = specs[i]
		s.setup(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9])
		s.position = Vector3(-1.6 + 1.6 * i, 0, 0)
		s.rotation.y = 0.5 - 0.5 * i
		root.add_child(s)
		sol.append(s)
	var cam := Camera3D.new()
	cam.fov = 40
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0, 6.2, 5.2), Vector3(0, 0.7, 0.1))
	for f in 6:
		for s in sol:
			s.pose(1.0 / 30.0, 0.0, 0.0, 0.0, 0.0, false, -1.0, true, false, -1.0)
		await process_frame
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://shots/v1h-top.png")
	# Low 3/4 view to check the silhouette.
	cam.look_at_from_position(Vector3(0, 1.6, 5.4), Vector3(0, 1.0, 0.0))
	cam.fov = 38
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://shots/v1h-front.png")
	quit()
