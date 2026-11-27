extends SceneTree
## Targeted v1n test: tougher enemies. Bots pick tall cover that really hides them, peek/burst/duck, strafe
## while firing, reposition; fire rate / accuracy / reaction / cover values from TUNE are applied; accuracy is
## worse against a moving or sliding player; saved tuning carries over.
##   godot --headless --path . --script res://tools/test_v1n.gd

var main: Node
var fails := 0
var open_old_ref := {}


func ok(name: String, cond: bool, detail := "") -> void:
	print(("OK   " if cond else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not cond:
		fails += 1


func _initialize() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	run()


func _bot() -> Variant:
	return main.arena_bots[0]


func _reset_bot(at: Vector2) -> void:
	var b: Variant = _bot()
	main._respawn_bot(b, at)
	b.state = "patrol"
	b.alert = 0.0


func _hit_rate(player_vel: Vector3, n: int, stance := "stand") -> float:
	var b: Variant = _bot()
	main.stance = stance
	main.vel = player_vel
	b.strafing = false
	b.node.rotation.y = 0.0
	var hits := 0
	for i in n:
		main.hp = 100000.0
		main._enemy_fire(b)
		if main.hp < 100000.0 - 0.1:
			hits += 1
	main.stance = "stand"
	main.vel = Vector3.ZERO
	return float(hits) / n


## Runs the bot AI; returns stats about what it did.
func _sim(secs: float, cover: bool, player: Vector3, start: Vector2, pvel := Vector3.ZERO) -> Dictionary:
	main.settings["enemy_cover"] = 1.0 if cover else 0.0
	main.pos = player
	main.vel = pvel
	main.stance = "stand"
	_reset_bot(start)
	var b: Variant = _bot()
	var dt := 1.0 / 60.0
	var s := {"phases": {}, "covers": {}, "hide_n": 0, "hide_ok": 0, "hide_crouch": 0, "fire_n": 0, "strafe_speed": 0.0,
		"strafe_n": 0, "stuck_in_wall": 0, "lost": 0.0, "shots": 0, "fire_frames": 0, "shots_in_fire": 0, "peek_seen": 0, "peek_n": 0}
	var shots0: int = main.enemy_shots
	var prev := Vector2(b.node.position.x, b.node.position.z)
	for i in int(secs / dt):
		s["lost"] += 100000.0 - main.hp
		main.hp = 100000.0
		main._update_bots(dt)
		var p := Vector2(b.node.position.x, b.node.position.z)
		s["phases"][b.phase] = int(s["phases"].get(b.phase, 0)) + 1
		if b.cover_ob != null and b.phase in ["go", "hide", "peek", "fire", "back"]:
			s["covers"][str(Vector2(roundf(b.cover_pt.x), roundf(b.cover_pt.y)))] = true
		if b.phase == "hide":
			s["hide_n"] += 1
			if main._los_blocked(p.x, p.y, main.pos.x, main.pos.z):
				s["hide_ok"] += 1
			if b.crouch:
				s["hide_crouch"] += 1
		if b.phase == "peek":
			s["peek_n"] += 1
		if b.phase == "fire":
			s["fire_frames"] += 1
			if b.see >= 0.0:
				s["peek_seen"] += 1
		if b.strafing:
			s["strafe_n"] += 1
			var dp := (p - prev) / dt
			var to_pl := Vector2(main.pos.x - p.x, main.pos.z - p.y).normalized()
			s["strafe_speed"] += absf(dp.dot(Vector2(-to_pl.y, to_pl.x)))
		if main._blocked_at(p.x, p.y, 0.2):
			s["stuck_in_wall"] += 1
		prev = p
	s["shots"] = main.enemy_shots - shots0
	return s


func run() -> void:
	await process_frame
	await process_frame
	ok("version v1n", TuneDefs.VERSION == "v1n" and TuneDefs.COMPAT.has("v1n") and TuneDefs.COMPAT.has("v1m"))

	# ---- TUNE panel values ----
	var keys := ["enemy_acc", "enemy_move_pen", "enemy_fire_ms", "enemy_burst", "enemy_react", "enemy_cover"]
	var listed := {}
	for it in TuneDefs.all_items():
		listed[it["key"]] = it
	var all_listed := true
	for k in keys:
		if not listed.has(k) or not main.settings.has(k):
			all_listed = false
	ok("new enemy values in TUNE panel + settings", all_listed)
	ok("enemy_hp default still 8 hits", int(TuneDefs.defaults()["enemy_hp"]) == 8 or float(main._t("enemy_hp")) >= 1.0)
	print("  defaults: acc=%s pen=%s fire_ms=%s burst=%s react=%s cover=%s hp=%s" % [main._t("enemy_acc"), main._t("enemy_move_pen"), main._t("enemy_fire_ms"), main._t("enemy_burst"), main._t("enemy_react"), main._t("enemy_cover"), main._t("enemy_hp")])
	ok("defaults sane", main._t("enemy_acc") > 50.0 and main._t("enemy_acc") <= 70.0 and main._t("enemy_burst") >= 2.0 and main._t("enemy_fire_ms") < 500.0 and main._t("enemy_react") >= 200.0 and main._tb("enemy_cover"))
	var cls := TuneDefs.defaults()
	ok("classic preset reproduces the old enemy", float(listed["enemy_burst"]["cls"]) == 1.0 and float(listed["enemy_fire_ms"]["cls"]) >= 1000.0 and float(listed["enemy_acc"]["cls"]) == 50.0 and float(listed["enemy_move_pen"]["cls"]) == 0.0)

	# ---- saved tuning carry-over ----
	var path: String = main.SETTINGS_PATH
	var had := FileAccess.file_exists(path)
	var backup := FileAccess.get_file_as_bytes(path) if had else PackedByteArray()
	var cf := ConfigFile.new()
	cf.set_value("s", "tune_ver", "v1m")
	cf.set_value("s", "enemy_acc", 50.0)
	cf.set_value("s", "enemy_hp", 5.0)
	cf.set_value("s", "move_speed", 5.5)
	cf.save(path)
	main._load_settings()
	ok("old default accuracy follows the new default", is_equal_approx(main._t("enemy_acc"), float(cls["enemy_acc"])), str(main._t("enemy_acc")))
	ok("custom values kept (hp, speed) + new keys at defaults", is_equal_approx(main._t("enemy_hp"), 5.0) and is_equal_approx(main._t("move_speed"), 5.5) and is_equal_approx(main._t("enemy_burst"), float(cls["enemy_burst"])))
	cf.set_value("s", "enemy_acc", 73.0)
	cf.save(path)
	main._load_settings()
	ok("custom accuracy kept", is_equal_approx(main._t("enemy_acc"), 73.0))
	cf.set_value("s", "tune_ver", "v1n")
	cf.set_value("s", "enemy_acc", 50.0)
	cf.set_value("s", "enemy_burst", 5.0)
	cf.save(path)
	main._load_settings()
	ok("v1n saves load as-is", is_equal_approx(main._t("enemy_acc"), 50.0) and is_equal_approx(main._t("enemy_burst"), 5.0))
	if had:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	main.apply_preset("snappy")
	ok("snappy preset restores new defaults", is_equal_approx(main._t("enemy_burst"), float(cls["enemy_burst"])) and is_equal_approx(main._t("enemy_acc"), float(cls["enemy_acc"])))

	# ---- arena ----
	main._begin(true)
	main.set_process(false)
	await process_frame
	main.settings["enemy_active"] = true
	main._apply_enemy_hp()
	ok("arena bot, health 8 hits", main.arena_bots.size() >= 1 and _bot().max_hp == 8)

	# ---- accuracy vs a moving / sliding player (10 m, open ground) ----
	main.pos = Vector3(0, 0, 0)
	_reset_bot(Vector2(0, -10))
	main.pos = Vector3(0, 0, 0)
	var n := 1500
	var h_still := _hit_rate(Vector3.ZERO, n)
	var h_walk := _hit_rate(Vector3(main._walk(), 0, 0), n)
	var h_slide := _hit_rate(Vector3(11.2, 0, 0), n, "slide")
	print("  hit chance @10 m: standing %.0f%%, walking %.0f%%, sliding %.0f%%" % [h_still * 100, h_walk * 100, h_slide * 100])
	ok("harder to hit a moving player, hardest sliding", h_still > h_walk + 0.15 and h_walk > h_slide + 0.04)
	ok("standing player is hit often, a moving one is not trivial", h_still > 0.45 and h_still < 0.85 and h_walk > 0.12)
	main.settings["enemy_acc"] = 100.0
	var h_perfect := _hit_rate(Vector3.ZERO, 200)
	main.settings["enemy_acc"] = 20.0
	var h_bad := _hit_rate(Vector3.ZERO, n)
	ok("accuracy value is applied (100 -> near perfect, 20 -> poor)", h_perfect > 0.9 and h_bad < h_still - 0.2, "100: %.2f  20: %.2f" % [h_perfect, h_bad])
	main.settings["enemy_acc"] = float(cls["enemy_acc"])
	main.settings["enemy_move_pen"] = 0.0
	var h_walk0 := _hit_rate(Vector3(main._walk(), 0, 0), n)
	ok("move penalty value is applied (0 = no penalty)", absf(h_walk0 - h_still) < 0.08, "walk@pen0 %.2f vs still %.2f" % [h_walk0, h_still])
	main.settings["enemy_move_pen"] = float(cls["enemy_move_pen"])

	# ---- fire rate: open ground, no cover ----
	var open_new := _sim(20.0, false, Vector3(0, 0, 0), Vector2(0, -10))
	var rate_new := float(open_new["shots"]) / 20.0
	var b: Variant = _bot()
	var strafe_avg := float(open_new["strafe_speed"]) / maxf(1.0, float(open_new["strafe_n"]))
	print("  open ground (no cover): %.2f shots/s, strafe %.0f%% of the time at %.2f m/s sideways" % [rate_new, 100.0 * float(open_new["strafe_n"]) / (20.0 * 60.0), strafe_avg])
	ok("bot strafes while it fires", float(open_new["strafe_n"]) > 20.0 * 60.0 * 0.6 and strafe_avg > 1.5)
	ok("no bot inside a wall (open)", int(open_new["stuck_in_wall"]) == 0)
	var saved := {}
	for k in ["enemy_acc", "enemy_fire_ms", "enemy_burst", "enemy_react", "enemy_move_pen"]:
		saved[k] = main.settings[k]
		main.settings[k] = float(listed[k]["cls"])
	var open_old := _sim(20.0, false, Vector3(0, 0, 0), Vector2(0, -10))
	open_old_ref = open_old
	var rate_old := float(open_old["shots"]) / 20.0
	for k in saved.keys():
		main.settings[k] = saved[k]
	print("  classic values: %.2f shots/s" % rate_old)
	ok("fire rate value applied: new defaults shoot far more than classic", rate_new > rate_old * 1.8 and rate_new > 1.5, "%.2f vs %.2f" % [rate_new, rate_old])
	main.settings["enemy_fire_ms"] = 120.0
	main.settings["enemy_burst"] = 6.0
	var open_fast := _sim(12.0, false, Vector3(0, 0, 0), Vector2(0, -10))
	ok("burst length / interval values are applied (faster tune -> more shots)", float(open_fast["shots"]) / 12.0 > rate_new * 1.2, "%.2f/s" % (float(open_fast["shots"]) / 12.0))
	main.settings["enemy_fire_ms"] = float(cls["enemy_fire_ms"])
	main.settings["enemy_burst"] = float(cls["enemy_burst"])

	# reaction delay: first shot comes after enemy_react
	main.settings["enemy_react"] = 600.0
	main.pos = Vector3(0, 0, 0)
	_reset_bot(Vector2(0, -10))
	main.settings["enemy_cover"] = 0.0
	var t_first := -1.0
	var shots0: int = main.enemy_shots
	for i in 240:
		main.hp = 100000.0
		main._update_bots(1.0 / 60.0)
		if main.enemy_shots > shots0:
			t_first = i / 60.0
			break
	ok("reaction delay is applied before the first shot", t_first >= 0.45 and t_first < 1.2, "first shot at %.2f s with react 600 ms" % t_first)
	main.settings["enemy_react"] = float(cls["enemy_react"])

	# ---- cover: player at (0,0); tall props nearby ----
	var cov := _sim(40.0, true, Vector3(0, 0, 0), Vector2(0, -10))
	var cov_walk := _sim(40.0, true, Vector3(0, 0, 0), Vector2(0, -10), Vector3(main._walk(), 0, 0))
	var open_walk := _sim(20.0, false, Vector3(0, 0, 0), Vector2(0, -10), Vector3(main._walk(), 0, 0))
	print("  DAMAGE per second from ONE bot (player hp 100, regen 12/s after 4 s):")
	print("    open ground: standing %.1f, walking %.1f   |   cover bot: standing %.1f, walking %.1f" % [float(open_new["lost"]) / 20.0, float(open_walk["lost"]) / 20.0, float(cov["lost"]) / 40.0, float(cov_walk["lost"]) / 40.0])
	print("    classic (old) bot: %.1f" % (float(open_old_ref["lost"]) / 20.0))
	var ph: Dictionary = cov["phases"]
	print("  cover run (40 s): phases=%s, distinct covers=%d, hide frames hidden %d/%d, crouched %d, shots=%d, strafe frames=%d" % [str(ph), cov["covers"].size(), cov["hide_ok"], cov["hide_n"], cov["hide_crouch"], cov["shots"], cov["strafe_n"]])
	ok("bot goes to cover, hides, peeks and fires", ph.has("go") and ph.has("hide") and ph.has("peek") and ph.has("fire") and ph.has("back"))
	ok("hide spots really block the player's sight", int(cov["hide_n"]) > 60 and int(cov["hide_ok"]) >= int(cov["hide_n"]) * 0.97)
	ok("bot ducks while hiding", int(cov["hide_crouch"]) >= int(cov["hide_n"]) * 0.95)
	ok("bot sees the player while it peeks and fires", int(cov["fire_frames"]) > 30 and int(cov["peek_seen"]) >= int(cov["fire_frames"]) * 0.9)
	ok("bot shoots from cover", int(cov["shots"]) >= 8, str(cov["shots"]))
	ok("bot strafes while peeking", int(cov["strafe_n"]) > 40)
	ok("bot repositions to another hiding spot", cov["covers"].size() >= 2, str(cov["covers"].size()))
	ok("no bot inside a wall (cover)", int(cov["stuck_in_wall"]) == 0)

	# cover toggle off -> never enters cover phases
	var nocov := _sim(15.0, false, Vector3(0, 0, 3), Vector2(0, -10))
	ok("cover off: open-ground fighting only", not nocov["phases"].has("hide") and not nocov["phases"].has("go") and int(nocov["shots"]) > 5)

	# start from a few other spots / player positions: cover found, nobody stuck in walls
	var all_ok := true
	for case in [[Vector3(-6, 0, 8), Vector2(-9, -11)], [Vector3(8, 0, 2), Vector2(9, -9)], [Vector3(0, 0, 14), Vector2(0, -10)]]:
		var r := _sim(25.0, true, case[0], case[1])
		print("  case player %s bot %s: phases %s shots %d covers %d" % [str(case[0]), str(case[1]), str(r["phases"]), r["shots"], r["covers"].size()])
		if int(r["stuck_in_wall"]) > 0 or int(r["shots"]) < 3:
			all_ok = false
	ok("other layouts: bot fights, no wall clipping", all_ok)

	# static mode untouched
	main.settings["enemy_active"] = false
	main.pos = Vector3(0, 0, 0)
	_reset_bot(Vector2(0, -10))
	var s0: int = main.enemy_shots
	for i in 300:
		main._update_bots(1.0 / 60.0)
	ok("Static enemy mode still never shoots", main.enemy_shots == s0)

	print("RESULT fails=%d" % fails)
	quit(fails)
