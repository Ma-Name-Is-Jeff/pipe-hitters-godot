extends SceneTree
## Renders the Tuning Arena from the real game scene (needs a display; use xvfb-run + opengl3).
##   godot --path . --rendering-driver opengl3 --script res://tools/shot_arena.gd -- out.png [game | cx cy cz tx ty tz [fov [w h]]]
## "game" = the phone camera on the player; with numbers = a free camera (for the closer props shot).
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else "res://shots/arena.png"
	var free := a.size() >= 7
	var w := int(a[8]) if a.size() > 8 else 844
	var h := int(a[9]) if a.size() > 9 else 390
	DisplayServer.window_set_size(Vector2i(w, h))
	root.size = Vector2i(w, h)
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	main._begin(true)
	for i in 50:
		await process_frame
	if free:
		main.set_process(false)
		var cam: Camera3D = main.camera
		cam.fov = float(a[7]) if a.size() > 7 else 50.0
		cam.look_at_from_position(Vector3(float(a[1]), float(a[2]), float(a[3])), Vector3(float(a[4]), float(a[5]), float(a[6])))
		main.ui.hud.visible = false
		for i in 3:
			await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
