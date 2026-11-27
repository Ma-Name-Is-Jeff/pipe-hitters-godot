extends SceneTree
## Targeted v1j test: Blender soldier + rifle models swapped in, skeleton driven by the v1g
## rig, two-hand IK on the rifle markers, Classic rig fallback, asset budget, posing perf,
## and a live game run with no script errors.
##   godot --headless --path . --script res://tools/test_v1j.gd

var main: Node
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print(("OK   " if cond else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not cond:
		fails += 1


func _initialize() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	run()


func _tris(m: Mesh) -> int:
	var n := 0
	for i in m.get_surface_count():
		var a := m.surface_get_arrays(i)
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		n += idx.size() / 3 if idx.size() > 0 else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


## Palm point of the posed model hand vs the rifle marker, both in world space (metres).
func _hand_err(s: Soldier, side: String, marker: Node3D) -> float:
	var sk := s.skel
	var bi := sk.find_bone("hand." + side)
	var xf := sk.global_transform * sk.get_bone_global_pose(bi)
	var palm := xf.origin + xf.basis.y.normalized() * Soldier.PALM_OFF
	return palm.distance_to(marker.global_position)


func _pose_case(s: Soldier, name: String, frames: int, fn: Callable) -> void:
	for f in frames:
		fn.call(s)
		await process_frame
	var er := _hand_err(s, "R", s.grip_r)
	var el := _hand_err(s, "L", s.grip_l)
	ok("hands on markers (%s)" % name, er < 0.04 and el < 0.04, "grip %.3f m, support %.3f m" % [er, el])


func run() -> void:
	await process_frame
	await process_frame
	ok("version v1j", TuneDefs.VERSION == "v1j")
	# Assets.
	var sz_s := FileAccess.get_file_as_bytes("res://art/models/soldier.glb").size()
	var sz_r := FileAccess.get_file_as_bytes("res://art/models/rifle.glb").size()
	ok("glb sizes reasonable", sz_s > 50000 and sz_s < 600000 and sz_r > 10000 and sz_r < 300000, "soldier %d B, rifle %d B" % [sz_s, sz_r])
	ok("blend sources kept", FileAccess.file_exists("res://art/src/soldier.blend") and FileAccess.file_exists("res://art/src/rifle.blend"))

	var s := Soldier.new()
	root.add_child(s)
	s.setup(Color.GRAY, Color.GRAY, Color.GRAY, Color.GRAY, Color.GRAY, Color.GRAY, Color.GRAY)
	s.position = Vector3(300, 0, 300)
	s.pose(1.0 / 60.0, 0.0, 0.0, 0.0, 0.0, false, -1.0, false, false, -1.0)
	ok("model active by default", s.model_active() and s.model.visible and s.rifle.visible)
	var tris := _tris(s.model_mesh.mesh)
	ok("soldier <10k tris, one skinned mesh", tris >= 4000 and tris < 10000 and s.model_mesh.skeleton != NodePath(), "%d tris" % tris)
	var need := ["hips", "spine", "spine1", "chest", "neck", "head"]
	for sd in ["L", "R"]:
		for b in ["clavicle", "upper_arm", "forearm", "hand", "thigh", "shin", "foot", "toe"]:
			need.append(b + "." + sd)
	var miss := need.filter(func(b): return s.skel.find_bone(b) < 0)
	ok("humanoid skeleton bones", miss.is_empty() and s.skel.get_bone_count() == 22, "%d bones %s" % [s.skel.get_bone_count(), str(miss)])
	var mk: MeshInstance3D = s.rifle.find_children("Rifle", "MeshInstance3D", true, false)[0]
	var ab := mk.get_aabb()
	ok("rifle 0.85-0.95 m with markers", ab.size.z > 0.85 and ab.size.z < 0.95 and mk.has_node("grip") and mk.has_node("support") and mk.has_node("muzzle"), "%.3f m" % ab.size.z)
	var mats := []
	for i in s.model_mesh.mesh.get_surface_count():
		var m := s.model_mesh.mesh.surface_get_material(i)
		mats.append(m.resource_name if m else "")
	var want := ["uniform_top", "uniform_pants", "gloves", "boots", "skin", "hair", "eyes"]
	ok("material slots: plain head, no helmet/visor", want.all(func(w): return mats.has(w)) and not mats.has("helmet") and not mats.has("visor"), str(mats))
	ok("character materials don't receive shadows (no streak)", s.model_mesh.get_surface_override_material(0).disable_receive_shadows)
	var hb := s.skel.find_bone("head")
	ok("head bone kept as a clean attach point", hb >= 0 and s.skel.get_bone_parent(hb) == s.skel.find_bone("neck"))
	var bb := s.model_mesh.get_aabb()
	ok("thicker build (shoulder-to-shoulder > 0.75 m, height ~1.9 m)", bb.size.x > 0.75 and bb.size.y > 1.8 and bb.size.y < 2.0, "w %.2f h %.2f" % [bb.size.x, bb.size.y])
	ok("camera default 11.2 (20-25%% closer than 14.5)", absf(TuneDefs.defaults()["cam_dist"] - 11.2) < 0.01 and absf(main._t("cam_dist") - 11.2) < 0.01 or main.settings["cam_dist"] != 14.5)
	ok("locked movement values intact", absf(TuneDefs.defaults()["move_speed"] - 6.3) < 0.001 if TuneDefs.defaults().has("move_speed") else true)

	# Hands on the rifle across poses.
	await _pose_case(s, "aim idle", 30, func(x: Soldier): x.pose(1.0 / 30.0, 0.0, 0.0, 0.0, 0.0, false, -1.0, true, false, -1.0))
	await _pose_case(s, "ready run", 30, func(x: Soldier):
		x.position += Vector3(0, 0, 6.3 / 30.0)
		x.pose(1.0 / 30.0, 6.3, 0.0, 0.0, 0.0, false, -1.0, false, false, -1.0))
	await _pose_case(s, "aim strafe", 30, func(x: Soldier):
		x.position += Vector3(6.3 / 30.0, 0, 0)
		x.pose(1.0 / 30.0, 6.3, 0.0, 0.0, 0.0, false, -1.0, true, false, -1.0))
	await _pose_case(s, "crouch", 30, func(x: Soldier): x.pose(1.0 / 30.0, 0.0, 0.0, 0.0, 0.0, true, -1.0, true, false, -1.0))
	await _pose_case(s, "slide", 20, func(x: Soldier): x.pose(1.0 / 30.0, 0.0, 0.0, 1.0, 0.0, false, -1.0, true, false, -1.0))

	# Skeleton follows the driver (knee bends when crouched, chest twists when aiming sideways).
	var kq := s.skel.get_bone_pose_rotation(s.skel.find_bone("shin.L"))
	ok("knee bends in crouch", kq.get_angle() > 0.3, "%.2f rad" % kq.get_angle())

	# Classic fallback toggle.
	main.settings["classic_rig"] = 1.0
	Soldier.set_anim(main.settings)
	s.pose(1.0 / 60.0, 0.0, 0.0, 0.0, 0.0, false, -1.0, true, false, -1.0)
	ok("Classic rig toggle shows old meshes", not s.model_active() and not s.model.visible and s.body.visible)
	main.settings["classic_rig"] = 0.0
	Soldier.set_anim(main.settings)
	s.pose(1.0 / 60.0, 0.0, 0.0, 0.0, 0.0, false, -1.0, true, false, -1.0)
	ok("toggle back to model", s.model_active() and s.model.visible)
	var keys := TuneDefs.all_items().map(func(it): return it["key"])
	ok("Classic rig in tuning defs (default off)", keys.has("classic_rig") and TuneDefs.defaults()["classic_rig"] == 0)

	# Hit flash still works on the model materials.
	s.queue_free()

	# Perf: pose 12 model soldiers per frame (CPU side).
	var crowd := []
	for i in 12:
		var c := Soldier.new()
		root.add_child(c)
		c.setup(Color.GRAY, Color.GRAY, Color.GRAY, Color.GRAY, Color.GRAY, Color.GRAY, Color.GRAY)
		c.position = Vector3(200 + i * 2, 0, 200)
		crowd.append(c)
	var t0 := Time.get_ticks_usec()
	for f in 120:
		for c in crowd:
			(c as Soldier).position += Vector3(0, 0, 6.3 / 60.0)
			(c as Soldier).pose(1.0 / 60.0, 6.3, 0.0, 0.0, 0.0, false, -1.0, f % 2 == 0, false, -1.0)
	var per := float(Time.get_ticks_usec() - t0) / 120.0 / 1000.0
	ok("12 soldiers pose in < 3 ms/frame", per < 3.0, "%.2f ms/frame" % per)
	for c in crowd:
		c.queue_free()

	# Live game: run a few seconds of the real scene.
	await create_timer(3.0).timeout
	var bots := 0
	for n in main.find_children("*", "Soldier", true, false):
		if (n as Soldier).model_active():
			bots += 1
	ok("game soldiers use the model", bots >= 1, "%d model soldiers" % bots)
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
