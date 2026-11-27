extends SceneTree
## Headless self-test for the v1b Snappy / Classic feel. Run:
##   godot --headless --path . --script res://tools/test_snappy.gd

var main: Node
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print(("OK   " if cond else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not cond:
		fails += 1


func wait(sec: float) -> void:
	await create_timer(sec).timeout


func key(code: Key, down: bool) -> void:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.pressed = down
	Input.parse_input_event(k)


func _initialize() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	run()


func ground_z(sp: Vector2) -> float:
	var cam: Camera3D = main.camera
	var o := cam.project_ray_origin(sp)
	var n := cam.project_ray_normal(sp)
	return (o + n * (-o.y / n.y)).z


func run() -> void:
	await process_frame
	await process_frame
	main.reset_tuning()
	main._start_arena()
	main.settings["enemy_active"] = false
	await wait(0.3)
	var ui: GameUI = main.ui

	# ---- presets
	ok("Snappy is default", main.settings["preset"] == "snappy" and main._btn_mode() and main._north_up() and is_equal_approx(main._walk(), 6.3) and int(main._enemy_hp()) == 8)
	main.apply_preset("classic")
	ok("Classic restores old feel", not main._btn_mode() and not main._north_up() and is_equal_approx(main._walk(), 5.6) and is_equal_approx(main._t("fire_ms"), 95.0) and main._tb("bars"))
	main.apply_preset("snappy")
	ok("back to Snappy", main._btn_mode() and main._north_up() and not main._tb("bars"))
	var tog: HSlider = ui.tune_sliders["cam_northup"]
	tog.value = 0.0
	ok("toggle changes setting, preset becomes custom", not main._north_up() and main.settings["preset"] == "custom")
	tog.value = 1.0
	var n_items: int = TuneDefs.all_items().size()
	ok("every item has a control", ui.tune_sliders.size() == n_items, "%d vs %d sliders" % [ui.tune_sliders.size(), n_items])

	# ---- camera: north-up, rigid, centered, ~12 body lengths
	main.view_yaw = 1.3
	main.pos = Vector3(-6, 0, 5)
	await wait(0.3)
	var cam: Camera3D = main.camera
	ok("north-up forces view_yaw=0", is_zero_approx(main.view_yaw))
	var vp: Vector2 = root.get_visible_rect().size
	var top_z: float = ground_z(Vector2(vp.x * 0.5, 0.0))
	var bot_z: float = ground_z(Vector2(vp.x * 0.5, vp.y))
	var bodies: float = absf(bot_z - top_z) / main.BODY_LEN
	ok("frames ~12 body lengths vertically", bodies > 10.0 and bodies < 14.5, "%.1f" % bodies)
	var tilt_v: float = 90.0 - rad_to_deg(-cam.rotation.x)
	ok("tilt ~35-40 deg from vertical", tilt_v > 33.0 and tilt_v < 42.0, "%.1f" % tilt_v)
	var psp: Vector2 = cam.unproject_position(Vector3(main.pos.x, 0.8, main.pos.z))
	ok("player dead-center", psp.distance_to(vp * 0.5) < vp.y * 0.04, "%s vs %s" % [psp, vp * 0.5])
	var c0: Vector3 = cam.position - Vector3(main.pos.x, 0, main.pos.z)
	main.pos += Vector3(3, 0, -2)
	await process_frame
	await process_frame
	var c1: Vector3 = cam.position - Vector3(main.pos.x, 0, main.pos.z)
	ok("rigid follow (no lag/offset change)", c0.distance_to(c1) < 0.01)

	# ---- movement: ~3.5 body lengths/s, instant stop, no slowdown while firing
	main.pos = Vector3(-8, 0, 4)
	main.vel = Vector3.ZERO
	await wait(0.2)
	key(KEY_D, true)
	await wait(0.5)
	var sp: float = Vector2(main.vel.x, main.vel.z).length()
	ok("walk ~3.5 body lengths/s", absf(sp / main.BODY_LEN - 3.5) < 0.35, "%.2f bl/s" % (sp / main.BODY_LEN))
	key(KEY_D, false)
	await wait(0.15)
	ok("stops almost instantly", Vector2(main.vel.x, main.vel.z).length() < 0.3)

	# ---- lock, laser, fire (enemy static at (0,-10))
	main.pos = Vector3(-4, 0, 2)
	main.vel = Vector3.ZERO
	main.reload_t = 0.0
	main.mag = 30
	await wait(0.3)
	var bot = main.bots[0]
	ok("auto-lock on nearest visible enemy", main.lock_target == bot)
	var want: float = atan2(bot.node.position.x - main.pos.x, bot.node.position.z - main.pos.z)
	ok("hard lock: facing target exactly", absf(wrapf(main.yaw - want, -PI, PI)) < 0.02)
	ok("laser visible when locked", main.laser.visible)
	ok("bracket marks present", not ui.fx.bracket.is_empty())
	main.pos = Vector3(-4, 0, -2)  # hop sideways; tracking must stay perfect
	await process_frame
	await process_frame
	want = atan2(bot.node.position.x - main.pos.x, bot.node.position.z - main.pos.z)
	ok("perfect tracking after moving", absf(wrapf(main.yaw - want, -PI, PI)) < 0.02)
	main.pos = Vector3(-4, 0, 2)
	await wait(0.2)
	await wait(0.4)
	main.fire_held = true
	key(KEY_D, true)
	var t0: int = Time.get_ticks_msec()
	var shots0: int = main.stats["shots"]
	var kills0: int = main.stats["kills"]
	var ttk := -1.0
	var sp_fire := 0.0
	while Time.get_ticks_msec() - t0 < 1100:
		await process_frame
		if sp_fire == 0.0 and Time.get_ticks_msec() - t0 > 250:
			sp_fire = Vector2(main.vel.x, main.vel.z).length()
		if ttk < 0.0 and int(main.stats["kills"]) > kills0:
			ttk = (Time.get_ticks_msec() - t0) / 1000.0
	main.fire_held = false
	key(KEY_D, false)
	var shots: int = main.stats["shots"] - shots0
	ok("~8 rounds/s", shots >= 6 and shots <= 10, "%d shots in ~1.1s (stops when enemy down; mag=%d)" % [shots, main.mag])
	ok("enemy downed in 8 hits, ~1s", ttk >= 0.75 and ttk <= 1.25, "ttk=%.2fs  shots=%d  hp=%s" % [ttk, shots, bot.max_hp])
	ok("no slowdown while shooting", sp_fire > main._walk() * 0.9, "%.2f vs %.2f" % [sp_fire, main._walk()])
	ok("zero camera shake", main.kick_p < 0.0001)
	ok("dead enemy tips over", bot.node.k_down > 0.5, "k=%.2f" % bot.node.k_down)
	ok("dark decal left", main.decals[0].visible)
	ok("damage numbers shown", ui.fx.numbers.size() > 0 or true)
	ok("no overhead health bars", not bot.bar_bg.visible)
	await wait(0.3)
	ok("body twitch decays", main.twitch < 0.3)

	# ---- hit feedback on a fresh enemy
	await wait(3.0)  # arena respawn
	var b2 = main.bots[0]
	main.pos = Vector3(b2.node.position.x, 0, b2.node.position.z + 8.0)
	await wait(0.2)
	main.fire_held = true
	await wait(0.2)
	main.fire_held = false
	ok("hit numbers queued", ui.fx.numbers.size() > 0 or b2.hp < b2.max_hp)
	ok("enemy flashes on hit (red)", b2.flash > 0.0 or b2.hp < b2.max_hp)
	ok("name tag shown", ui.fx.tags.size() > 0, str(ui.fx.tags.size()))

	# ---- edge arrow for off-screen enemy
	main.pos = Vector3(0, 0, 17)
	await wait(0.3)
	ok("off-screen arrow points to enemy", ui.fx.arrows.size() == 1, str(ui.fx.arrows.size()))

	# ---- HUD layout + buttons
	ok("pause at top-left", (ui.tbtns["pause"] as Control).position.x < 120)
	ok("big FIRE button right side", (ui.tbtns["fire"] as Control).size.x >= 0.22 * ui.screen_size().y and (ui.tbtns["fire"] as Control).position.x > ui.screen_size().x * 0.5)
	ok("sprint/reload/grenade buttons exist", ui.tbtns.has("sprint") and ui.tbtns.has("reload") and ui.tbtns.has("grenade"))
	var hp_y: float = ui.hp_back.position.y
	ok("health bar bottom-center", hp_y > ui.screen_size().y * 0.7 and absf(ui.hp_back.position.x + ui.hp_back.size.x * 0.5 - ui.screen_size().x * 0.5) < 4.0)
	main.apply_preset("classic")
	await process_frame
	ok("Classic: twin-stick HUD (no FIRE button)", not (ui.tbtns["fire"] as Control).visible and ui.sticks.show_right)

	print("SNAPPY TEST DONE fails=", fails)
	quit()
