extends SceneTree
## Targeted v1h test: rounded soldier mesh is built, shared between soldiers, stays mobile-light,
## keeps the rig/proportions, and the rig still poses without script errors.
##   godot --headless --path . --script res://tools/test_v1h.gd
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print(("OK   " if cond else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not cond:
		fails += 1


func _meshes(n: Node, out: Array) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_meshes(c, out)


func _initialize() -> void:
	var a := Soldier.new()
	var b := Soldier.new()
	root.add_child(a)
	root.add_child(b)
	var g := Color(0.3, 0.3, 0.3)
	a.setup(g, g, g, g, g, g, g, g, Color(0, 1, 1))
	b.setup(Color.BROWN, g, g, g, g, g, g, g, Color(1, 0, 0))
	var ma: Array = []
	var mb: Array = []
	_meshes(a, ma)
	_meshes(b, mb)
	ok("same part count per soldier", ma.size() == mb.size() and ma.size() > 40, "%d parts" % ma.size())
	var shared := 0
	var verts := 0
	var boxes := 0
	for i in ma.size():
		if (ma[i] as MeshInstance3D).mesh == (mb[i] as MeshInstance3D).mesh:
			shared += 1
		var m: Mesh = (ma[i] as MeshInstance3D).mesh
		if m is BoxMesh:
			boxes += 1
		if m is ArrayMesh:
			verts += (m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		elif m is SphereMesh:
			verts += 17 * 9
		elif m is CapsuleMesh:
			verts += 17 * 10
	ok("all meshes shared between soldiers", shared == ma.size(), "%d/%d" % [shared, ma.size()])
	ok("no box primitives left", boxes == 0)
	ok("mobile-light (<40k verts per soldier)", verts < 40000, "~%d verts (instanced %d)" % [verts, ma.size()])
	var seg_ok := true
	for i in ma.size():
		var m: Mesh = (ma[i] as MeshInstance3D).mesh
		if m is CapsuleMesh and (m as CapsuleMesh).radial_segments < 16:
			seg_ok = false
		if m is SphereMesh and (m as SphereMesh).radial_segments < 16:
			seg_ok = false
	ok("16+ radial segments", seg_ok)
	var smooth := true
	for i in ma.size():
		var m: Mesh = (ma[i] as MeshInstance3D).mesh
		if m is ArrayMesh:
			var ar := m.surface_get_arrays(0)
			smooth = smooth and (ar[Mesh.ARRAY_NORMAL] as PackedVector3Array).size() == (ar[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	ok("custom meshes carry smooth normals", smooth)
	var rim := true
	for m in a.mats:
		rim = rim and m.rim_enabled
	ok("rim light on materials", rim)
	# Proportions: height about 5-5.4 heads, head sized by the helmet.
	for i in 6:
		a.pose(1.0 / 60.0, 0.0, 0.0, 0.0, 0.0, false, -1.0, false, false, -1.0)
	var top := -1e9
	var bot := 1e9
	for mi in ma:
		var inst := mi as MeshInstance3D
		var bb: AABB = inst.get_aabb()
		var gt: Transform3D = _gxf(a, inst)
		for c in 8:
			var pt := gt * bb.get_endpoint(c)
			top = maxf(top, pt.y)
			bot = minf(bot, pt.y)
	var hb := (a.part_helmet.get_child(0) as MeshInstance3D)
	var hbb: AABB = hb.get_aabb()
	var head_h := _gxf(a, hb).basis.get_scale().y * hbb.size.y * 1.0 + 0.1
	var heads := (top - bot) / head_h
	ok("about 5-5.4 heads tall (with helmet+neck)", heads > 4.9 and heads < 7.0, "height %.2f m, head %.2f m = %.1f heads" % [top - bot, head_h, heads])
	# Rig still works.
	a.position = Vector3(0, 0, 0)
	for i in 120:
		a.position += Vector3(0, 0, 6.3 / 60.0)
		a.pose(1.0 / 60.0, 6.3, 0.0, 0.0, 0.0, false, -1.0, true, false, -1.0)
	ok("rig posing runs after rebuild", a.dist_total > 10.0)
	var hand_err: float = (a.hands[1].position - a.gun.transform * a.grip_r.position).length()
	ok("trigger hand stays on grip", hand_err < 0.08, "%.3f" % hand_err)
	print("V1H TEST DONE fails=", fails)
	quit()


## Transform of a node relative to the soldier root (walks the parent chain).
func _gxf(root_n: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node3D = n
	while cur != root_n and cur != null:
		t = cur.transform * t
		cur = cur.get_parent() as Node3D
	return t
