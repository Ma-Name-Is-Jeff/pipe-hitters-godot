extends SceneTree
## Targeted v1d test: TTK (standing ~1s at 8 hits; running longer; settle less accurate)
## plus 2x touch-control sizes and overlap at a simulated 844x390 phone viewport.
##   godot --headless --path . --script res://tools/test_v1d.gd

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


func _circ(c: Vector2, r: float, o: Vector2, orad: float, pad: float) -> bool:
	return c.distance_to(o) + 0.05 < r + orad + pad


func run() -> void:
	await process_frame
	await process_frame
	main.reset_tuning()
	main._start_arena()
	main.settings["enemy_active"] = false
	main._set_touch_mode(true)
	await wait(0.25)
	var ui: GameUI = main.ui

	ok("version v1d", TuneDefs.VERSION == "v1d")
	ok("Snappy default is 8 hits", int(main._enemy_hp()) == 8)
	ok("settle default 0.3s", is_equal_approx(main._t("settle_time"), 0.3))
	ok("flash default cut ~60%", is_equal_approx(main._t("flash_size"), 0.6))
	main.apply_preset("classic")
	ok("Classic: no settle, 1x movement spread, 4 hp", is_equal_approx(main._t("settle_time"), 0.0) and is_equal_approx(main._t("spread_walk"), 1.0) and int(main._enemy_hp()) == 4)
	main.apply_preset("snappy")
	ok("Aim sliders present", ui.tune_sliders.has("settle_time") and ui.tune_sliders.has("settle_spread") and ui.tune_sliders.has("lock_grace") and ui.tune_sliders.has("spread_walk") and ui.tune_sliders.has("spread_sprint") and ui.tune_sliders.has("spread_slide") and ui.tune_sliders.has("spread_blend"))

	# ---- 844x390 button size / overlap
	ui.test_size = Vector2(720.0 * 844.0 / 390.0, 720.0)
	ui._layout()
	await process_frame
	var s: Vector2 = ui.screen_size()
	var H: float = s.y
	var fire: Control = ui.tbtns["fire"]
	var fire_s: float = fire.size.x
	ok("FIRE at least 22% of height (2x v1c)", fire_s >= 0.22 * H - 0.5 and fire_s >= 299.0, "FIRE=%.1f  22%%=%.1f  screen=%s" % [fire_s, 0.22 * H, s])
	var smalls := ["sprint", "reload", "grenade", "slide", "vault", "pause", "view", "tune"]
	var small_ok := true
	var small_detail := []
	for k in smalls:
		var c: Control = ui.tbtns[k]
		var sz: float = c.size.x
		var min_s := maxf(0.12 * H, 48.0 * H / 390.0)  # 12% or 48dp at 844x390
		if sz + 0.5 < min_s:
			small_ok = false
		small_detail.append("%s=%.0f" % [k, sz])
	ok("small buttons at least 12% / 48dp and 2x v1c", small_ok, ", ".join(small_detail) + "  min=%.0f" % maxf(0.12 * H, 48.0 * H / 390.0))
	ok("left stick 2x (radius >= 132)", ui.stick_radius() >= 131.5, "r=%.1f" % ui.stick_radius())

	var pad := 1.0
	var names: Array = ["fire", "sprint", "reload", "grenade", "slide", "vault", "pause", "view", "tune"]
	var overlap := []
	for i in names.size():
		var a: Control = ui.tbtns[names[i]]
		if not a.visible:
			continue
		var ca := a.position + a.size * 0.5
		var ra := a.size.x * 0.5
		# Off screen / safe area (8px margin)
		if ca.x - ra < -0.5 or ca.y - ra < -0.5 or ca.x + ra > s.x + 0.5 or ca.y + ra > s.y + 0.5:
			overlap.append("%s off-screen" % names[i])
		# Stick
		if _circ(ca, ra, ui.stick_center(0), ui.stick_radius(), pad):
			overlap.append("%s vs stick" % names[i])
		# HUD
		var hud: Rect2 = ui._hud_block()
		var br := Rect2(a.position, a.size)
		if hud.size.x > 1.0 and br.grow(-2.0).intersects(hud):
			overlap.append("%s vs HUD" % names[i])
		for j in range(i + 1, names.size()):
			var b: Control = ui.tbtns[names[j]]
			if not b.visible:
				continue
			var cb := b.position + b.size * 0.5
			if _circ(ca, ra, cb, b.size.x * 0.5, pad):
				overlap.append("%s vs %s" % [names[i], names[j]])
	ok("no overlaps, all inside safe area at 844x390", overlap.is_empty(), ", ".join(overlap))
	ok("FIRE on the right, pause top-left, HUD bottom-center", fire.position.x > s.x * 0.55 and (ui.tbtns["pause"] as Control).position.x < 80 and ui.hp_back.position.y > s.y * 0.7)
	ui.test_size = Vector2.ZERO
	ui._layout()

	# ---- standing TTK after settle, ~1s for 8 hits
	main.pos = Vector3(-4, 0, 2)
	main.vel = Vector3.ZERO
	main.reload_t = 0.0
	main.mag = 200
	main.reserve = 200
	await wait(0.45)  # lock + settle 0.3s
	ok("lock settled before standing TTK", main.lock_target == main.bots[0] and main._settle_u() >= 0.99, "u=%.2f" % main._settle_u())
	var bot = main.bots[0]
	var hp0: int = bot.hp
	ok("bot at 8 hp", hp0 == 8)
	main.fire_held = true
	var t0: int = Time.get_ticks_msec()
	var ttk_stand := -1.0
	var shots_stand := 0
	var hits0: int = main.stats["hits"]
	while Time.get_ticks_msec() - t0 < 2500:
		await process_frame
		if ttk_stand < 0.0 and bot.state == "down":
			ttk_stand = (Time.get_ticks_msec() - t0) / 1000.0
			shots_stand = int(main.stats["shots"])
			break
	main.fire_held = false
	ok("standing TTK about 1s at 8 hits", ttk_stand >= 0.75 and ttk_stand <= 1.25, "ttk=%.2fs  shots_after_start  hits=%d  hp0=%d" % [ttk_stand, int(main.stats["hits"]) - hits0, hp0])

	# ---- running TTK (wait for respawn, start sprint, then fire)
	await wait(3.2)
	bot = main.bots[0]
	main.pos = Vector3(-6, 0, 4)
	main.vel = Vector3.ZERO
	main.mag = 200
	main.reserve = 200
	main.reload_t = 0.0
	main.spread_mul = 1.0
	await wait(0.45)
	key(KEY_SHIFT, true)
	key(KEY_D, true)
	await wait(0.25)
	ok("sprint spread mul near 3x", main.spread_mul > 2.2, "mul=%.2f  state=%.1f" % [main.spread_mul, main._spread_state_mul()])
	main.fire_held = true
	var t1: int = Time.get_ticks_msec()
	var ttk_run := -1.0
	var hits_run := 0
	var shots_run := 0
	var h0: int = main.stats["hits"]
	var s0: int = main.stats["shots"]
	while Time.get_ticks_msec() - t1 < 4000:
		await process_frame
		if ttk_run < 0.0 and bot.state == "down":
			ttk_run = (Time.get_ticks_msec() - t1) / 1000.0
			break
	hits_run = int(main.stats["hits"]) - h0
	shots_run = int(main.stats["shots"]) - s0
	main.fire_held = false
	key(KEY_SHIFT, false)
	key(KEY_D, false)
	var run_longer := ttk_run < 0.0 or (ttk_stand > 0.0 and ttk_run > ttk_stand + 0.25)
	ok("running TTK noticeably longer", run_longer, "run=%.2fs  stand=%.2fs  run_hits=%d/%d" % [ttk_run, ttk_stand, hits_run, shots_run])

	# ---- settle window is less accurate (stretch settle to 1.2s, stand farther)
	await wait(3.2)
	bot = main.bots[0]
	if bot.state == "down":
		main._arena_respawn(bot)
		await wait(0.2)
	# Farther away so the 0.06 rad settle cone is a clear miss chance.
	main.pos = Vector3(0, 0, 8)
	main.vel = Vector3.ZERO
	main.mag = 200
	main.reserve = 200
	main.reload_t = 0.0
	main.spread_mul = 1.0
	main.settings["settle_time"] = 1.2
	main.settings["settle_spread"] = 0.06
	main.lock_target = null
	main.settle_t = 0.0
	await process_frame
	await process_frame
	ok("re-acquire starts settle over", main.lock_target == bot and main._settle_u() < 0.2, "u=%.2f" % main._settle_u())
	var wep: Dictionary = main._cur_wep()
	var wide: float = main._shot_spread(wep)
	ok("settle cone starts wide", wide >= 0.05, "spr=%.3f" % wide)
	var saved_t: float = main.settle_t
	main.settle_t = 10.0
	var tight: float = main._shot_spread(wep)
	main.settle_t = saved_t
	ok("settled cone is tight standing", tight < 0.01 and tight < wide * 0.3, "settled=%.4f  settle=%.3f" % [tight, wide])
	main.settings["settle_spread"] = 0.12
	seed(7)
	main.fire_held = true
	var sh0: int = main.stats["shots"]
	var hi0: int = main.stats["hits"]
	var t_s: int = Time.get_ticks_msec()
	while int(main.stats["shots"]) - sh0 < 8 and Time.get_ticks_msec() - t_s < 1100:
		await process_frame
		if main._settle_u() >= 0.9:
			break
	main.fire_held = false
	var settle_shots: int = int(main.stats["shots"]) - sh0
	var settle_hits: int = int(main.stats["hits"]) - hi0
	# Fresh standing target, fully settled.
	if bot.state == "down" or bot.hp < bot.max_hp:
		if bot.state != "down":
			bot.hp = 0
			bot.state = "down"
		await wait(2.8)
		bot = main.bots[0]
	main.pos = Vector3(0, 0, 8)
	main.vel = Vector3.ZERO
	main.mag = 200
	main.reserve = 200
	main.reload_t = 0.0
	main.spread_mul = 1.0
	main.lock_target = bot
	main.settle_t = 10.0
	await wait(0.2)
	seed(11)
	main.fire_held = true
	sh0 = main.stats["shots"]
	hi0 = main.stats["hits"]
	var want := maxi(settle_shots, 6)
	var t2: int = Time.get_ticks_msec()
	# Stop when the bot drops so leftover shots don't count as "misses" on a corpse.
	while int(main.stats["shots"]) - sh0 < want and Time.get_ticks_msec() - t2 < 2000 and bot.state != "down":
		await process_frame
	main.fire_held = false
	var acc_shots: int = int(main.stats["shots"]) - sh0
	var acc_hits: int = int(main.stats["hits"]) - hi0
	var settle_rate := 0.0 if settle_shots == 0 else float(settle_hits) / float(settle_shots)
	var acc_rate := 0.0 if acc_shots == 0 else float(acc_hits) / float(acc_shots)
	ok("hits during settle less likely than settled standing", settle_rate < acc_rate - 0.15 or (settle_rate < 0.75 and acc_rate >= 0.8), "settle %d/%d (%.0f%%)  settled %d/%d (%.0f%%)" % [settle_hits, settle_shots, settle_rate * 100.0, acc_hits, acc_shots, acc_rate * 100.0])

	# LOS break + grace
	main.settings["settle_time"] = 0.3
	main.settings["lock_grace"] = 0.15
	main.pos = Vector3(-4, 0, 2)
	await wait(0.2)
	var held = main.lock_target
	# Teleport far out of range
	main.pos = Vector3(0, 0, 30)
	await wait(0.05)
	ok("grace keeps lock briefly after leaving range", main.lock_target == held)
	await wait(0.25)
	ok("lock breaks after grace when out of range", main.lock_target != held or main.lock_target == null or not main._lock_valid(main.lock_target))

	print("V1D TEST DONE fails=", fails)
	quit()
