extends SceneTree
## Screenshot of v1o crouch-cover + the new tall stacks (needs xvfb-run + opengl3).
##   godot --path . --rendering-driver opengl3 --script res://tools/shot_v1o.gd -- out.png
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else "res://shots/v1o-game.png"
	DisplayServer.window_set_size(Vector2i(844, 390))
	root.size = Vector2i(844, 390)
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	main._begin(true)
	main.settings["enemy_active"] = true
	var bot = main.arena_bots[0]
	main._respawn_bot(bot, Vector2(0, -10))
	bot.alert = 3.5
	# Tight against the north face of the box row so auto-crouch stays on.
	main.pos = Vector3(-1.5, 0, -3.1)
	main.yaw = PI
	main.vel = Vector3.ZERO
	main.cam_pos = main._camera_target(0.0)
	var n := 0
	for i in 300:
		main.hp = 100.0
		main.pos = Vector3(-1.5, 0, -3.1)
		main.vel = Vector3.ZERO
		main.yaw = PI
		await process_frame
		n = i
		if bot.phase == "fire":
			break
	print("frames=", n, " phase=", bot.phase, " bot_crouch=", bot.crouch, " player_crouch=", main.crouch)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
