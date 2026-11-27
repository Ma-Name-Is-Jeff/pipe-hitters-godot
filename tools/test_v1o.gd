extends SceneTree
## Targeted v1o test: crouched fighters are protected by low props (short boxes included);
## standing exposes you; the rule is symmetric for player and bots; bots also use low props
## as cover while keeping tall-cover peeking; four new tall stacks are in the arena; vault,
## slide lane, spawns and tuning values are unchanged.
##   godot --headless --path . --script res://tools/test_v1o.gd

var main: Node
var lv: Level
var fails := 0

const NEW_TALL := [Vector2(-14.0, 11.5), Vector2(13.0, 7.5), Vector2(-10.0, -16.0), Vector2(11.0, -15.0)]


func ok(name: String, cond: bool, detail := "") -> void:
	print(("OK   " if cond else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not cond:
		fails += 1


func _initialize() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	run()


func _inside_any(x: float, z: float, rad: float) -> bool:
	for o in lv.obstacles:
		var cx := clampf(x, o.min_x, o.max_x)
		var cz := clampf(z, o.min_z, o.max_z)
		if (x - cx) * (x - cx) + (z - cz) * (z - cz) < rad * rad:
			return true
	return false


func _step(frames: int) -> void:
	for i in frames:
		main._update_move(1.0 / 60.0)


func _box_of_height(h: float, tol := 0.03) -> Obstacle:
	var best: Obstacle = null
	var bd := 1e9
	for o in lv.prop_obstacles:
		if absf(o.h - h) < tol:
			var c := Vector2((o.min_x + o.max_x) * 0.5, (o.min_z + o.max_z) * 0.5)
			if c.length() < bd:
				bd = c.length()
				best = o
	return best


func _prop_at(p: Vector2, within := 0.4) -> Obstacle:
	for o in lv.prop_obstacles:
		var c := Vector2((o.min_x + o.max_x) * 0.5, (o.min_z + o.max_z) * 0.5)
		if c.distance_to(p) < within:
			return o
	return null


func _bot() -> Variant:
	return main.arena_bots[0]


func _place_across(o: Obstacle, gap := 5.0) -> Dictionary:
	# Shooter south of the prop, target north of it, line through the middle.
	var cx := (o.min_x + o.max_x) * 0.5
	var south := o.min_z - gap
	var north := o.max_z + 0.85
	return {"cx": cx, "south": south, "north": north}


func run() -> void:
	await process_frame
	await process_frame
	ok("version v1o", TuneDefs.VERSION == "v1o" and TuneDefs.COMPAT.has("v1o") and TuneDefs.COMPAT.has("v1n"))
	var d := TuneDefs.defaults()
	ok("tuning values unchanged", is_equal_approx(float(d["enemy_acc"]), 58.0) and is_equal_approx(float(d["enemy_fire_ms"]), 240.0) and is_equal_approx(float(d["enemy_burst"]), 3.0) and is_equal_approx(float(d["enemy_react"]), 350.0) and is_equal_approx(float(d["enemy_move_pen"]), 1.2) and is_equal_approx(float(d["enemy_cover"]), 1.0) and is_equal_approx(float(d["enemy_hp"]), 8.0))

	lv = main.arena_level

	# ---- new tall props ----
	var new_ok := true
	var new_found := 0
	for p in NEW_TALL:
		var o := _prop_at(p)
		if o == null or o.h < 1.2 or o.vaultable or not o.blocks_ray:
			new_ok = false
			print("     missing/bad tall prop at ", p, " ", o)
		else:
			new_found += 1
	ok("4 new tall stacks (crate / pallet / tire) are full cover", new_ok and new_found == 4, "%d/4" % new_found)
	var tall_n := 0
	for o in lv.prop_obstacles:
		if o.h >= 1.2:
			tall_n += 1
	ok("arena has more tall hide spots than v1n (was 5 props + car + wall)", tall_n >= 9, "%d tall props" % tall_n)

	var lane_ok := true
	for o in lv.obstacles:
		if o.max_x > -8.2 and o.min_x < 13.9 and o.max_z > -1.2 and o.min_z < 1.2:
			lane_ok = false
	ok("slide lane still clear", lane_ok)
	var spawn_ok := true
	for p in [Vector2(0, 15), Vector2(0, -10), Vector2(-9, -11), Vector2(9, -9), Vector2(3, -9), Vector2(-3, -12)]:
		if _inside_any(p.x, p.y, 1.0):
			spawn_ok = false
			print("     blocked point ", p)
	ok("start, spawns and patrols still clear", spawn_ok)
	var no_ov := true
	for i in lv.prop_obstacles.size():
		for j in range(i + 1, lv.prop_obstacles.size()):
			var a: Obstacle = lv.prop_obstacles[i]
			var b: Obstacle = lv.prop_obstacles[j]
			if a.min_x < b.max_x - 0.01 and a.max_x > b.min_x + 0.01 and a.min_z < b.max_z - 0.01 and a.max_z > b.min_z + 0.01:
				no_ov = false
	ok("solid props do not overlap", no_ov)

	# ---- switch to the live arena ----
	main._begin(true)
	main.set_process(false)
	await process_frame
	main.settings["enemy_active"] = true
	main.settings["enemy_acc"] = 100.0
	main.settings["enemy_move_pen"] = 0.0
	ok("arena live", main.arena_mode and main.playing and main.arena_bots.size() >= 1)

	# ---- crouch cover: short box (< 0.72 m) ----
	var box := _box_of_height(0.645)
	ok("found a short box (< 0.72 m)", box != null, "h %.3f" % (box.h if box else 0.0))
	if box == null:
		print("RESULT fails=%d" % fails)
		quit(1)
		return
	var g := _place_across(box)
	var bot: Variant = _bot()

	# Helpers: line through the box
	ok("crouched target: line through a short box is blocked", main._shot_blocked(g["cx"], g["south"], g["cx"], g["north"], true))
	ok("standing target: line through a short box is clear", not main._shot_blocked(g["cx"], g["south"], g["cx"], g["north"], false))
	# Standing physical ray still passes over the short box (v1m behaviour).
	var over := Vector3(g["cx"], 1.15, g["south"])
	var span: float = g["north"] - g["south"]
	ok("standing _world_hit still passes over the short box", main._world_hit(over, Vector3.BACK, span) >= span - 0.01)
	ok("_bullet_hit blocks only when the target is crouched", main._bullet_hit(over, Vector3.BACK, span, true) < (box.min_z - g["south"] + 0.2) and main._bullet_hit(over, Vector3.BACK, span, false) >= span - 0.01)

	# Live enemy fire at the player, both stances, same positions.
	main._respawn_bot(bot, Vector2(g["cx"], g["south"]))
	bot.node.rotation.y = 0.0  # face +Z (north)
	bot.crouch = false
	bot.strafing = false
	main.pos = Vector3(g["cx"], 0, g["north"])
	main.vel = Vector3.ZERO
	main.stance = "stand"
	main.crouch = true
	main.hp = 100.0
	var hp0: float = main.hp
	for i in 8:
		main._enemy_fire(bot)
	ok("enemy fire: crouched player behind a short box is not hit", main.hp == hp0, "hp %.1f after 8 shots" % main.hp)
	main.crouch = false
	main.hp = 100.0
	for i in 8:
		main._enemy_fire(bot)
	ok("enemy fire: standing player at the same spot is hit", main.hp < 100.0 - 5.0, "hp %.1f" % main.hp)

	# A crate (1.0 m, still low cover) behaves the same — treated consistently.
	var crate: Obstacle = _box_of_height(1.0)
	ok("found a vaultable crate to treat as crouch cover", crate != null and crate.vaultable)
	if crate != null:
		var gc := _place_across(crate)
		ok("crouched behind a crate is blocked, standing is not", main._shot_blocked(gc["cx"], gc["south"], gc["cx"], gc["north"], true) and not main._shot_blocked(gc["cx"], gc["south"], gc["cx"], gc["north"], false))

	# Symmetric: the player shooting a crouched bot behind the same box.
	main.pos = Vector3(g["cx"], 0, g["south"])
	main.yaw = 0.0
	main.crouch = false
	main.stance = "stand"
	main.vel = Vector3.ZERO
	main._respawn_bot(bot, Vector2(g["cx"], g["north"]))
	bot.crouch = true
	bot.state = "cover"
	main.last_shot = 0
	main.mag = 30
	main.reload_t = 0.0
	main.burst_wait = 0.0
	var bot_hp: int = bot.hp
	# Direct fire path: several shots with no spread (aim dead on).
	for i in 6:
		main.last_shot = 0
		main.burst_wait = 0.0
		main._fire()
	ok("player fire: crouched bot behind a short box is not hit", bot.hp == bot_hp, "hp %s -> %s" % [bot_hp, bot.hp])
	bot.crouch = false
	bot_hp = bot.hp
	for i in 6:
		main.last_shot = 0
		main.burst_wait = 0.0
		main._fire()
	ok("player fire: standing bot at the same spot is hit", bot.hp < bot_hp, "hp %s -> %s" % [bot_hp, bot.hp])

	# A crouched shooter can still hit a standing target over the low prop (one-way cover, both sides).
	main.crouch = true
	main._respawn_bot(bot, Vector2(g["cx"], g["north"]))
	bot.crouch = false
	bot_hp = bot.hp
	for i in 6:
		main.last_shot = 0
		main.burst_wait = 0.0
		main._fire()
	ok("crouched player can shoot a standing bot over a low prop", bot.hp < bot_hp, "hp %s -> %s" % [bot_hp, bot.hp])

	# ---- vault still works at a low prop ----
	main._respawn_bot(bot, Vector2(0, -10))  # clear the landing side
	var vault_o: Obstacle = box
	var vcx := (vault_o.min_x + vault_o.max_x) * 0.5
	var vcz := (vault_o.min_z + vault_o.max_z) * 0.5
	var vault_ok := false
	var vault_detail := ""
	for vd in [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]:
		var ex := (vault_o.max_x - vault_o.min_x) * 0.5
		var ez := (vault_o.max_z - vault_o.min_z) * 0.5
		var sx: float = vcx - vd.x * (ex + 0.75)
		var sz: float = vcz - vd.y * (ez + 0.75)
		if _inside_any(sx, sz, main.RADIUS * 0.95):
			continue
		main.vault = {}
		main.stance = "stand"
		main.crouch = false
		main.pos = Vector3(sx, 0, sz)
		main.vel = Vector3.ZERO
		var hit: Dictionary = main._find_vault(vd.x, vd.y)
		if hit.is_empty():
			continue
		main._try_vault(hit)
		_step(40)
		var cleared: bool = main.vault.is_empty() and ((vd.x > 0 and main.pos.x > vault_o.max_x) or (vd.x < 0 and main.pos.x < vault_o.min_x) or (vd.y > 0 and main.pos.z > vault_o.max_z) or (vd.y < 0 and main.pos.z < vault_o.min_z))
		if cleared and not _inside_any(main.pos.x, main.pos.z, main.RADIUS * 0.9):
			vault_ok = true
			vault_detail = "landed %.2f,%.2f" % [main.pos.x, main.pos.z]
			break
		vault_detail = "z %.2f" % main.pos.z
	ok("vault still works over a short box", vault_ok, vault_detail)

	# ---- bots use the new tall cover and also low props ----
	main.settings["enemy_acc"] = float(d["enemy_acc"])
	main.settings["enemy_move_pen"] = float(d["enemy_move_pen"])
	main.settings["enemy_cover"] = 1.0
	main.settings["enemy_active"] = true
	main.crouch = false
	main.stance = "stand"
	main.vel = Vector3.ZERO

	# From a start near each new stack, _find_cover should be able to pick that stack
	# (or another nearby tall/low hide) and at least one pick must be the new prop itself.
	var used_new := {}
	var used_low := 0
	var used_tall := 0
	var picks := 0
	for case in [
		[Vector3(0, 0, 15), Vector2(-9, -11)],
		[Vector3(0, 0, 0), Vector2(0, -10)],
		[Vector3(8, 0, 14), Vector2(9, -9)],
		[Vector3(-6, 0, -6), Vector2(-9, -11)],
		[Vector3(6, 0, -8), Vector2(9, -9)],
		[Vector3(-8, 0, 10), Vector2(0, -10)],
		[Vector3(10, 0, 4), Vector2(0, -10)],
		[Vector3(0, 0, -12), Vector2(0, -10)],
	]:
		main.pos = case[0]
		main._respawn_bot(bot, case[1])
		bot.alert = 3.5
		bot.state = "cover"
		bot.phase = ""
		bot.cover_ob = null
		bot.bad = {}
		var c: Dictionary = main._find_cover(bot, null)
		if c.is_empty():
			continue
		picks += 1
		var ob: Obstacle = c["ob"]
		var oc := Vector2((ob.min_x + ob.max_x) * 0.5, (ob.min_z + ob.max_z) * 0.5)
		if main._low_cover(ob):
			used_low += 1
		else:
			used_tall += 1
		for p in NEW_TALL:
			if oc.distance_to(p) < 0.6:
				used_new[p] = true
	ok("bots find cover from several starts", picks >= 6, "%d picks, low %d tall %d, new %d" % [picks, used_low, used_tall, used_new.size()])
	ok("bots also consider low props as cover", used_low >= 1, "low picks %d" % used_low)
	# Stand the bot near each new stack with the player on the far side: the stack itself should win.
	var near_ok := 0
	for p in NEW_TALL:
		var away: Vector2 = p.normalized() if p.length() > 0.1 else Vector2(1, 0)
		main.pos = Vector3(p.x - away.x * 8.0, 0, p.y - away.y * 8.0)
		# Keep the player in bounds.
		main.pos.x = clampf(main.pos.x, -16.0, 16.0)
		main.pos.z = clampf(main.pos.z, -16.0, 16.0)
		var start := Vector2(p.x + away.x * 4.0, p.y + away.y * 4.0)
		start.x = clampf(start.x, -16.0, 16.0)
		start.y = clampf(start.y, -16.0, 16.0)
		if _inside_any(start.x, start.y, 0.6):
			start = Vector2(p.x, p.y + (4.0 if away.y >= 0.0 else -4.0))
		main._respawn_bot(bot, start)
		bot.alert = 3.5
		bot.phase = ""
		bot.cover_ob = null
		bot.bad = {}
		var c2: Dictionary = main._find_cover(bot, null)
		if not c2.is_empty():
			var ob2: Obstacle = c2["ob"]
			var oc2 := Vector2((ob2.min_x + ob2.max_x) * 0.5, (ob2.min_z + ob2.max_z) * 0.5)
			if oc2.distance_to(p) < 0.6:
				near_ok += 1
				used_new[p] = true
			else:
				print("     near %s picked %s instead" % [str(p), str(oc2)])
		else:
			print("     near %s picked nothing" % str(p))
	ok("bots will hide behind the new tall stacks", used_new.size() >= 3, "%d unique new stacks (near-picks %d/4)" % [used_new.size(), near_ok])

	# Live sim: player at the north end, bot at south-west spawn — should go to cover and hide.
	main.pos = Vector3(0, 0, 12)
	main._respawn_bot(bot, Vector2(-9, -11))
	bot.alert = 3.5
	var saw_hide := 0
	var saw_low_hide := 0
	var saw_new := 0
	var saw_peek_fire := 0
	var stuck := 0
	var covers := {}
	for i in 60 * 25:
		main.hp = 100000.0
		main._update_bots(1.0 / 60.0)
		var p := Vector2(bot.node.position.x, bot.node.position.z)
		if bot.phase == "hide" and bot.crouch:
			saw_hide += 1
			if bot.cover_ob != null and main._low_cover(bot.cover_ob):
				saw_low_hide += 1
			if bot.cover_ob != null:
				var oc := Vector2((bot.cover_ob.min_x + bot.cover_ob.max_x) * 0.5, (bot.cover_ob.min_z + bot.cover_ob.max_z) * 0.5)
				covers[str(oc.round())] = true
				for np in NEW_TALL:
					if oc.distance_to(np) < 0.6:
						saw_new += 1
		if bot.phase in ["peek", "fire"]:
			saw_peek_fire += 1
		if main._blocked_at(p.x, p.y, 0.2):
			stuck += 1
	print("  sim: hide=%d (low %d, new-prop frames %d) peek/fire=%d covers=%s stuck=%d" % [saw_hide, saw_low_hide, saw_new, saw_peek_fire, str(covers.keys()), stuck])
	ok("live: bot reaches cover, ducks, then peeks or fires", saw_hide > 30 and saw_peek_fire > 20)
	ok("live: no bot inside a wall", stuck == 0)

	# A second sim near the box row should let the bot use low cover and stay crouched while firing.
	main.pos = Vector3(0, 0, 0)
	main.crouch = false
	main._respawn_bot(bot, Vector2(0, -10))
	bot.alert = 3.5
	var low_fire := 0
	var low_hide2 := 0
	for i in 60 * 20:
		main.hp = 100000.0
		main._update_bots(1.0 / 60.0)
		if bot.cover_ob != null and main._low_cover(bot.cover_ob):
			if bot.phase == "hide" and bot.crouch:
				low_hide2 += 1
			if bot.phase == "fire" and bot.crouch:
				low_fire += 1
	print("  low-cover sim: hide=%d crouched-fire=%d" % [low_hide2, low_fire])
	ok("bots crouch-fire from low props (and still peek tall cover)", low_hide2 > 10 or low_fire > 10, "hide %d fire %d" % [low_hide2, low_fire])

	print("RESULT fails=%d" % fails)
	quit(fails)
