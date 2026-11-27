extends SceneTree
## Targeted v1m test: original Blender arena props (crates, boxes, pallets, tire piles, barrels, one car) load,
## collision matches the visuals, low props stay vaultable, tall props and the car are full cover that block
## bullets, the slide lane still works, and the whole prop set is cheap (one MultiMesh per prop type).
##   godot --headless --path . --script res://tools/test_v1m.gd

var main: Node
var lv: Level
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print(("OK   " if cond else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not cond:
		fails += 1


func _initialize() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	run()


func _mesh_tris(m: Mesh) -> int:
	var n := 0
	for i in m.get_surface_count():
		var a := m.surface_get_arrays(i)
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		n += idx.size() / 3 if idx.size() > 0 else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


func _overlap(a: Obstacle, b: Obstacle) -> bool:
	return a.min_x < b.max_x - 0.01 and a.max_x > b.min_x + 0.01 and a.min_z < b.max_z - 0.01 and a.max_z > b.min_z + 0.01


func _inside_any(x: float, z: float, rad: float, skip: Obstacle = null) -> bool:
	for o in lv.obstacles:
		if o == skip:
			continue
		var cx := clampf(x, o.min_x, o.max_x)
		var cz := clampf(z, o.min_z, o.max_z)
		if (x - cx) * (x - cx) + (z - cz) * (z - cz) < rad * rad:
			return true
	return false


func _step(frames: int) -> void:
	for i in frames:
		main._update_move(1.0 / 60.0)


func run() -> void:
	await process_frame
	await process_frame
	ok("version v1m", TuneDefs.VERSION in ["v1m", "v1n", "v1o"])
	lv = main.arena_level

	# ---- assets ----
	ok("props.glb + blend source", FileAccess.file_exists("res://art/models/props.glb") and FileAccess.file_exists("res://art/src/props.blend") and FileAccess.file_exists("res://art/src/build_props.py"))
	var scn := (load("res://art/models/props.glb") as PackedScene).instantiate()
	var tris := 0
	var all_found := true
	var has_color := true
	var size_ok := true
	var size_bad := ""
	for n in Level.PROP_DEFS:
		var mi := scn.find_child(n, true, false) as MeshInstance3D
		if mi == null:
			all_found = false
			continue
		tris += _mesh_tris(mi.mesh)
		var arr := mi.mesh.surface_get_arrays(0)
		if (arr[Mesh.ARRAY_COLOR] as PackedColorArray).size() == 0:
			has_color = false
		var bb := mi.mesh.get_aabb()
		var want: Vector3 = Level.PROP_DEFS[n]
		if absf(bb.size.x - want.x) > 0.02 or absf(bb.size.y - want.y) > 0.02 or absf(bb.size.z - want.z) > 0.02 or absf(bb.position.y) > 0.01 or absf(bb.get_center().x) > 0.02 or absf(bb.get_center().z) > 0.02:
			size_ok = false
			size_bad += " %s %s" % [n, bb.size]
	scn.free()
	ok("all %d prop meshes load by name" % Level.PROP_DEFS.size(), all_found)
	ok("props carry vertex colours (one shared material)", has_color)
	ok("mesh bounds match the footprint table (base at y=0, centred)", size_ok, size_bad)
	ok("prop mesh set is cheap (< 6k tris total, each type stored once)", tris < 6000, "%d tris" % tris)

	# ---- arena build ----
	var mmis: Array = []
	for c in main.arena_root.get_children():
		if c is MultiMeshInstance3D:
			mmis.append(c)
	var inst := 0
	var shared := true
	var drawn_tris := 0
	for m in mmis:
		inst += (m as MultiMeshInstance3D).multimesh.instance_count
		drawn_tris += (m as MultiMeshInstance3D).multimesh.instance_count * _mesh_tris((m as MultiMeshInstance3D).multimesh.mesh)
		if (m as MultiMeshInstance3D).material_override != (mmis[0] as MultiMeshInstance3D).material_override:
			shared = false
	ok("props drawn as MultiMeshes (<= 10 draw calls, one material)", mmis.size() >= 8 and mmis.size() <= 10 and shared, "%d multimeshes, %d instances, %d tris drawn" % [mmis.size(), inst, drawn_tris])
	ok("prop instances placed", inst >= 40, "%d" % inst)
	var kinds := {}
	for n in lv.prop_xf:
		kinds[n] = (lv.prop_xf[n] as Array).size()
	var need := ["crate", "box", "pallet", "pallet_stack", "tire_stack3", "tire_stack4", "tire_tower", "barrel_a", "barrel_b", "car"]
	var missing := need.filter(func(n): return not kinds.has(n))
	ok("every requested prop type is used (crates, boxes, single + stacked pallets, tire piles, barrels, car)", missing.is_empty(), str(kinds))
	ok("exactly one car", kinds.get("car", 0) == 1)
	ok("pallets: single (walk-over) and stacked both present", kinds.get("pallet", 0) >= 3 and kinds.get("pallet_stack", 0) >= 3)

	# ---- collision matches visuals ----
	var meshes := {}
	var s2 := (load("res://art/models/props.glb") as PackedScene).instantiate()
	for n in Level.PROP_DEFS:
		meshes[n] = (s2.find_child(n, true, false) as MeshInstance3D).mesh.get_aabb()
	var match_ok := true
	var bad := ""
	for o in lv.prop_obstacles:
		var x0 := 1e9
		var x1 := -1e9
		var z0 := 1e9
		var z1 := -1e9
		var y1 := 0.0
		var n_in := 0
		for n in lv.prop_xf:
			for tr in lv.prop_xf[n]:
				var t: Transform3D = tr
				if t.origin.x < o.min_x - 0.01 or t.origin.x > o.max_x + 0.01 or t.origin.z < o.min_z - 0.01 or t.origin.z > o.max_z + 0.01:
					continue
				var bb: AABB = t * (meshes[n] as AABB)
				x0 = minf(x0, bb.position.x)
				x1 = maxf(x1, bb.end.x)
				z0 = minf(z0, bb.position.z)
				z1 = maxf(z1, bb.end.z)
				y1 = maxf(y1, bb.end.y)
				n_in += 1
		var d := maxf(maxf(absf(x0 - o.min_x), absf(x1 - o.max_x)), maxf(maxf(absf(z0 - o.min_z), absf(z1 - o.max_z)), absf(y1 - o.h)))
		if n_in == 0 or d > 0.04:
			match_ok = false
			bad += " (%.1f,%.1f d=%.2f)" % [(o.min_x + o.max_x) * 0.5, (o.min_z + o.max_z) * 0.5, d]
	ok("every prop obstacle box == its drawn mesh bounds (+-4 cm)", match_ok and lv.prop_obstacles.size() >= 25, "%d solid props%s" % [lv.prop_obstacles.size(), bad])
	var no_ov := true
	for i in lv.prop_obstacles.size():
		for j in range(i + 1, lv.prop_obstacles.size()):
			if _overlap(lv.prop_obstacles[i], lv.prop_obstacles[j]):
				no_ov = false
	ok("solid props do not overlap each other", no_ov)

	# ---- roles: low = vaultable low cover, tall + car = full cover ----
	var low_n := 0
	var tall_n := 0
	var roles_ok := true
	var car_o: Obstacle = null
	for o in lv.prop_obstacles:
		if o.h <= 1.15:
			low_n += 1
			roles_ok = roles_ok and o.vaultable and o.h >= 0.32 and o.h <= main.VAULT_MAX
		else:
			tall_n += 1
			roles_ok = roles_ok and (not o.vaultable) and o.h >= 1.2 and o.blocks_ray
		if absf(o.max_x - o.min_x - 4.42) < 0.05 or absf(o.max_z - o.min_z - 4.42) < 0.05:
			car_o = o
	ok("low props vaultable, tall props not (>= 1.2 m, block rays)", roles_ok, "%d low, %d tall" % [low_n, tall_n])
	ok("car is full cover and not vaultable", car_o != null and not car_o.vaultable and car_o.h >= 1.4 and car_o.blocks_ray, "h %.2f" % (car_o.h if car_o else 0.0))
	var old_walls := 0
	for o in lv.obstacles:
		if not lv.prop_obstacles.has(o) and o.vaultable and absf(minf(o.max_x - o.min_x, o.max_z - o.min_z) - 0.42) < 0.02:
			old_walls += 1
	ok("plain 0.42 m low walls were replaced by props", old_walls == 0, "%d left" % old_walls)

	# ---- lanes and spawns ----
	var lane_ok := true
	for o in lv.obstacles:
		if o.max_x > -8.2 and o.min_x < 13.9 and o.max_z > -1.2 and o.min_z < 1.2:
			lane_ok = false
	ok("slide lane (x -8..13.9, z -1.2..1.2) is clear", lane_ok)
	var spawn_ok := true
	for p in [Vector2(0, 15), Vector2(0, -10), Vector2(-9, -11), Vector2(9, -9), Vector2(3, -9), Vector2(-3, -12)]:
		if _inside_any(p.x, p.y, 1.0):
			spawn_ok = false
			print("     blocked point ", p)
	ok("start, enemy spawns and patrol points are clear of props", spawn_ok)

	# ---- switch the live game to the arena and drive the real movement code ----
	main._begin(true)
	main.set_process(false)
	await process_frame
	ok("arena uses these obstacles", main.obstacles == lv.obstacles)
	main.crouch = false
	main.stance = "stand"

	# Vault: every low prop must be vaultable from at least one side, and land clear of every obstacle.
	var vaultable_total := 0
	var vault_works := 0
	var fail_list := ""
	var dirs := [Vector2(0, -1), Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0)]
	for o in lv.prop_obstacles:
		if not o.vaultable:
			continue
		vaultable_total += 1
		var cx := (o.min_x + o.max_x) * 0.5
		var cz := (o.min_z + o.max_z) * 0.5
		var success := false
		for d in dirs:
			var dd: Vector2 = d
			# start 0.75 m from the near face, facing the prop
			var ex := (o.max_x - o.min_x) * 0.5
			var ez := (o.max_z - o.min_z) * 0.5
			var sx: float = cx - dd.x * (ex + 0.75)
			var sz: float = cz - dd.y * (ez + 0.75)
			if _inside_any(sx, sz, main.RADIUS * 0.95):
				continue
			main.vault = {}
			main.stance = "stand"
			main.pos = Vector3(sx, 0, sz)
			main.vel = Vector3.ZERO
			var hit: Dictionary = main._find_vault(dd.x, dd.y)
			if hit.is_empty():
				continue
			main._try_vault(hit)
			if main.vault.is_empty():
				continue
			_step(40)
			var cleared: bool = main.vault.is_empty() and ((dd.x > 0 and main.pos.x > o.max_x) or (dd.x < 0 and main.pos.x < o.min_x) or (dd.y > 0 and main.pos.z > o.max_z) or (dd.y < 0 and main.pos.z < o.min_z))
			if cleared and not _inside_any(main.pos.x, main.pos.z, main.RADIUS * 0.9):
				success = true
				break
		if success:
			vault_works += 1
		else:
			fail_list += " (%.1f,%.1f h%.2f)" % [cx, cz, o.h]
	ok("vault works over every low prop from at least one side", vaultable_total > 0 and vault_works == vaultable_total, "%d/%d%s" % [vault_works, vaultable_total, fail_list])

	# Tall props and the car cannot be vaulted, and the player cannot walk through them.
	var no_vault_tall := true
	var blocked_tall := true
	for o in lv.prop_obstacles:
		if o.vaultable:
			continue
		var cx := (o.min_x + o.max_x) * 0.5
		var cz := (o.min_z + o.max_z) * 0.5
		main.vault = {}
		main.stance = "stand"
		main.pos = Vector3(cx, 0, o.max_z + 0.8)
		if not (main._find_vault(0, -1) as Dictionary).is_empty():
			no_vault_tall = false
		var r: Vector2 = main._collide_xz(cx, cz, main.RADIUS)
		if r.x > o.min_x and r.x < o.max_x and r.y > o.min_z and r.y < o.max_z:
			blocked_tall = false
	ok("tall props + car: no vault offered", no_vault_tall)
	ok("tall props + car: player is pushed out (collision)", blocked_tall)

	# Slide lane: a real slide runs the length of the lane without hitting anything, then stops on its own.
	main.vault = {}
	main.stance = "stand"
	main.pos = Vector3(-7.5, 0, 0)
	main.vel = Vector3.ZERO
	main.yaw = PI * 0.5
	main._try_slide()
	var x0: float = main.pos.x
	var was_slide: bool = main.stance == "slide"
	_step(30)
	var moved: float = main.pos.x - x0
	var still_slide: bool = main.stance == "slide" or main.stance == "stand"
	ok("slide starts in the lane and travels clear (> 4 m in 0.5 s)", was_slide and moved > 4.0 and absf(main.pos.z) < 0.05 and still_slide, "%.2f m" % moved)
	_step(130)
	ok("slide ends on its own inside the lane (at the latest at the end wall)", main.stance == "stand" and main.pos.x < 14.0, "x %.2f stance %s" % [main.pos.x, main.stance])
	# Running a slide into the end wall still stops the player (the slide wall is unchanged).
	main.stance = "stand"
	main.pos = Vector3(8.0, 0, 0)
	main.vel = Vector3.ZERO
	main.yaw = PI * 0.5
	main._try_slide()
	_step(60)
	ok("slide wall at the lane end still stops a slide", main.pos.x < 14.5 - 0.3 + 0.05, "x %.2f" % main.pos.x)

	# ---- bullets ----
	var cc := Vector2((car_o.min_x + car_o.max_x) * 0.5, (car_o.min_z + car_o.max_z) * 0.5)
	var from := Vector3(cc.x - 6.0, 1.15, cc.y)
	var want_d := (car_o.min_x - from.x)
	var dist: float = main._world_hit(from, Vector3.RIGHT, 28.0)
	ok("standing shot (1.15 m) is blocked by the car", absf(dist - want_d) < 0.05, "hit at %.2f m, car face at %.2f" % [dist, want_d])
	var dist2: float = main._world_hit(Vector3(from.x, 0.72, from.z), Vector3.RIGHT, 28.0)
	ok("crouched shot (0.72 m) is blocked by the car", absf(dist2 - want_d) < 0.05)
	var dist3: float = main._world_hit(Vector3(from.x, 1.15, cc.y + 0.5), Vector3(1, -0.02, 0).normalized(), 28.0)
	ok("shot through the car's long side also blocked", dist3 < 28.0)
	ok("line of sight through the car is blocked", main._los_blocked(from.x, from.z, cc.x + 6.0, cc.y))
	# Tall crate stack blocks, a low box lets a standing shot pass (same as the old 0.8 m walls).
	var tall_hit := 0
	for o in lv.prop_obstacles:
		if o.h > 1.8:
			var f := Vector3((o.min_x + o.max_x) * 0.5, 1.15, o.min_z - 4.0)
			if main._world_hit(f, Vector3.BACK, 28.0) < 28.0:
				tall_hit += 1
	ok("tall crate/pallet stacks block standing shots", tall_hit >= 1)
	var box_o: Obstacle = null
	for o in lv.prop_obstacles:
		if absf(o.h - 0.645) < 0.01:
			box_o = o
	var bf := Vector3((box_o.min_x + box_o.max_x) * 0.5, 1.15, box_o.min_z - 3.0)
	var span := 3.0 + (box_o.max_z - box_o.min_z) + 0.4
	ok("low box: standing shot passes over, low shot (0.4 m) is blocked", main._world_hit(bf, Vector3.BACK, span) >= span - 0.001 and main._world_hit(Vector3(bf.x, 0.4, bf.z), Vector3.BACK, span) < 3.2)

	# ---- enemies untouched and not stuck inside props ----
	var bots_ok := true
	for b in main.arena_bots:
		if _inside_any(b.node.position.x, b.node.position.z, 0.4):
			bots_ok = false
	ok("arena enemies stand clear of props", bots_ok and main.arena_bots.size() >= 1, "%d bots" % main.arena_bots.size())

	# ---- live: let the real game run with the new arena (no script errors) ----
	main.set_process(true)
	await create_timer(2.0).timeout
	ok("arena runs live with props", main.arena_mode and main.playing)
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
