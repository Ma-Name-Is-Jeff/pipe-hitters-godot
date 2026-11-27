extends SceneTree
## Screenshot of a v1n bot peeking out of cover and firing (needs a display: xvfb-run + opengl3).
##   godot --path . --rendering-driver opengl3 --script res://tools/shot_v1n.gd -- out.png
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else "res://shots/v1n-game.png"
	DisplayServer.window_set_size(Vector2i(844, 390))
	root.size = Vector2i(844, 390)
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	main._begin(true)
	main.settings["enemy_active"] = true
	main.pos = Vector3(3, 0, 2)
	main.cam_pos = main._camera_target(0.0)
	var bot = main.arena_bots[0]
	main._respawn_bot(bot, Vector2(0, -10))
	var got := 0
	for i in 1800:
		main.hp = 100.0
		await process_frame
		if bot.phase == "fire" and bot.burst_left < 3 and bot.see >= 0.0:
			got += 1
			if got > 2:
				break
	print("phase=", bot.phase, " frames=", got)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
