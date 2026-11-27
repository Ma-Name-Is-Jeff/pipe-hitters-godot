extends SceneTree
## Headless self-test for the tuning panel + arena. Run:
##   godot --headless --path . --script res://tools/test_panel.gd

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


func run() -> void:
	await process_frame
	await process_frame
	main.reset_tuning()
	main._start_arena()
	await process_frame
	await process_frame
	var ui: GameUI = main.ui
	ok("arena mode on", main.arena_mode)
	ok("arena obstacles", main.obstacles == main.arena_level.obstacles and main.obstacles.size() > 15, str(main.obstacles.size()))
	ok("one enemy", main.bots.size() == 1)
	ok("arena ~40x40", absf(Level.ARENA_HALF * 2.0 - 40.0) < 0.01)
	ok("one gun in arena", main.wep == 0)
	main._swap_weapon(1)
	ok("swap blocked in arena", main.wep == 0)

	# Every slider drives its settings key.
	var all_ok := true
	for it in TuneDefs.all_items():
		var sl: HSlider = ui.tune_sliders[it["key"]]
		var target: float = it["min"] + (it["max"] - it["min"]) * 0.5
		sl.value = target
		if absf(float(main.settings[it["key"]]) - sl.value) > 1e-4:
			all_ok = false
			print("   mismatch ", it["key"], " ", main.settings[it["key"]], " vs ", sl.value)
	ok("all %d sliders change settings" % TuneDefs.all_items().size(), all_ok)

	# Settings reach gameplay variables.
	main.reset_tuning()
	ui.tune_sliders["move_speed"].value = 9.0
	ui.tune_sliders["sprint_speed"].value = 13.0
	ui.tune_sliders["accel"].value = 60.0
	ui.tune_sliders["decel"].value = 20.0
	ok("move_speed -> _walk()", is_equal_approx(main._walk(), 9.0))
	ok("sprint/accel/decel", is_equal_approx(main._sprint(), 13.0) and is_equal_approx(main._accel(), 60.0) and is_equal_approx(main._friction(), 20.0))
	ui.tune_sliders["assist"].value = 0.0  # keep auto-fire/slow-aim out of the movement check
	# Keyboard walk (no sprint): terminal speed must follow move_speed.
	main.touch_mode = false
	main.pos = Vector3(0, 0, 15)
	main.vel = Vector3.ZERO
	await wait(0.3)
	var kev := InputEventKey.new()
	kev.physical_keycode = KEY_W
	kev.pressed = true
	Input.parse_input_event(kev)
	main.pos = Vector3(-17, 0, 17)
	await wait(1.0)
	var sp_fast: float = Vector2(main.vel.x, main.vel.z).length()
	main.pos = Vector3(-17, 0, 17)
	ui.tune_sliders["move_speed"].value = 4.0
	await wait(1.0)
	var sp_slow: float = Vector2(main.vel.x, main.vel.z).length()
	kev.pressed = false
	Input.parse_input_event(kev)
	ok("player speed follows move_speed", sp_fast > 6.0 and sp_fast > sp_slow * 1.4 and absf(sp_slow - 4.0) < 1.0, "9.0->%.2f  4.0->%.2f" % [sp_fast, sp_slow])
	await wait(0.8)
	ui.tune_sliders["slide_speed"].value = 15.0
	ui.tune_sliders["slide_dur"].value = 3.0
	main.vel = Vector3.ZERO
	main.pos = Vector3(-6, 0, 0)
	main.yaw = PI * 0.5
	main._try_slide()
	var v: float = Vector2(main.vel.x, main.vel.z).length()
	ok("slide speed tuned", absf(v - 15.0) < 0.01, "%.2f" % v)
	ok("slide duration tuned", is_equal_approx(main.slide_t, 3.0))
	main.stance = "stand"
	main.vel = Vector3.ZERO

	ui.tune_sliders["enemy_hp"].value = 7.0
	ok("enemy health tuned", main.bots[0].max_hp == 7 and main.bots[0].hp == 7)
	ui.tune_sliders["fire_ms"].value = 200.0
	ui.tune_sliders["spread"].value = 0.02
	ok("fire rate / spread read by gun", is_equal_approx(main._fire_ms(main.WEAPONS[0]), 200.0) and is_equal_approx(main._spread(main.WEAPONS[0]), 0.02))
	ui.tune_sliders["assist_cone"].value = 30.0
	ui.tune_sliders["aim_curve"].value = 1.0
	ok("assist cone + curve", absf(main._aim_cone() - deg_to_rad(30.0)) < 1e-5 and is_equal_approx(main._stick_curve(0.58), 0.5))
	ui.tune_sliders["cam_fov"].value = 80.0
	ui.tune_sliders["cam_pitch"].value = 45.0
	ui.tune_sliders["zoom"].value = 0.0
	await wait(1.5)
	ok("camera fov follows slider", absf(main.camera.fov - 80.0) < 1.0, "%.1f" % main.camera.fov)
	ok("camera pitch follows slider", absf(-main.camera.rotation.x - deg_to_rad(45.0)) < 0.08, "%.3f" % -main.camera.rotation.x)

	# Enemy: static vs active, respawn.
	main.reset_tuning()
	main._reset_mission()
	await process_frame
	await process_frame
	var b = main.bots[0]
	ok("static enemy idles", b.state == "idle", b.state)
	var home: Vector3 = b.node.position
	await wait(0.6)
	ok("static enemy stays put", b.node.position.distance_to(home) < 0.01)
	ui.tune_enemy_toggle.emit()
	ok("toggle -> active AI flag", main.settings["enemy_active"] == true)
	await wait(0.4)
	ok("active enemy leaves idle", b.state != "idle", b.state)
	ui.tune_enemy_toggle.emit()
	b.hp = 1
	main._hurt_bot(b)
	ok("enemy downed", b.state == "down")
	b.t = 3.0
	await process_frame
	await process_frame
	ok("enemy respawns", b.state != "down" and b.hp == b.max_hp, b.state)

	# Copy / paste / reset round trip.
	main.reset_tuning()
	ui.tune_sliders["move_speed"].value = 7.3
	ui.tune_sliders["enemy_acc"].value = 33.0
	main.settings["enemy_active"] = true
	ui.tune_copy.emit()
	var json: String = ui.tune_text.text
	var snap: Dictionary = main.tuning_values().duplicate()
	ok("copy fills text box with JSON", json.length() > 50 and typeof(JSON.parse_string(json)) == TYPE_DICTIONARY)
	main.reset_tuning()
	ok("reset restores defaults", is_equal_approx(main._walk(), 5.6) and main.settings["enemy_active"] == false)
	ui.tune_text.text = json
	ui.tune_paste.emit()
	var back: Dictionary = main.tuning_values()
	var same := true
	for k in snap.keys():
		if typeof(snap[k]) == TYPE_STRING:
			continue
		if typeof(snap[k]) == TYPE_BOOL:
			same = same and snap[k] == back[k]
		elif absf(float(snap[k]) - float(back[k])) > 1e-6:
			same = false
			print("   diff ", k, snap[k], back[k])
	ok("paste round-trips every value", same)
	ok("panel slider reflects pasted value", is_equal_approx(ui.tune_sliders["move_speed"].value, 7.3))
	ui.tune_text.text = "not json"
	ok("bad JSON rejected", main.apply_tuning_json("not json") == -1)

	# Persistence.
	main._save_settings()
	var cf := ConfigFile.new()
	ok("settings saved to disk", cf.load(main.SETTINGS_PATH) == OK and is_equal_approx(float(cf.get_value("s", "move_speed", 0.0)), 7.3))
	main.reset_tuning()
	main._save_settings()

	# Panel open pauses sim, close resumes.
	main._open_tune(true)
	ok("panel open pauses", main.paused and ui.tune_panel.visible)
	main._open_tune(false)
	ok("panel close resumes", not main.paused and not ui.tune_panel.visible)
	# Mission still reachable.
	main._start_play()
	ok("compound mission reachable", not main.arena_mode and main.obstacles == main.level.obstacles and main.bots.size() == 9)
	print("PANEL TEST DONE fails=%d" % fails)
	quit(1 if fails > 0 else 0)
