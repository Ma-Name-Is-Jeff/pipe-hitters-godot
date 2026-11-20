class_name Level
extends RefCounted
## Builds the compound: grass, dirt paths, buildings, cover, hurdles, perimeter, extract.
## All static boxes go into one vertex-colored mesh (one draw call).

const WORLD := 101.25
const COL := {
	"floor": Color8(85, 86, 79),
	"peri": Color8(74, 78, 72),
	"wall": Color8(138, 132, 120),
	"crate": Color8(107, 90, 67),
	"crate2": Color8(90, 76, 56),
	"low": Color8(122, 109, 78),
	"cover": Color8(90, 99, 92),
	"mark": Color8(196, 162, 74),
}

var obstacles: Array[Obstacle] = []
var root: Node3D
var _st := SurfaceTool.new()
var _rng := RandomNumberGenerator.new()


func _init(parent: Node3D) -> void:
	root = parent
	_rng.seed = 4242
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)


func _quad(c: Vector3, u: Vector3, v: Vector3, n: Vector3, col: Color) -> void:
	var p0 := c - u - v
	var p1 := c + u - v
	var p2 := c + u + v
	var p3 := c - u + v
	# Godot front faces are clockwise.
	for p in [p0, p2, p1, p0, p3, p2]:
		_st.set_color(col)
		_st.set_normal(n)
		_st.add_vertex(p)


func _box_geo(x: float, y: float, z: float, w: float, h: float, d: float, base: Color) -> void:
	var t := 1.0 + _rng.randf_range(-0.05, 0.05)
	var col := Color(base.r * t, base.g * t, base.b * t)
	var top := Color(minf(col.r * 1.08, 1.0), minf(col.g * 1.08, 1.0), minf(col.b * 1.08, 1.0))
	var c := Vector3(x, y + h * 0.5, z)
	var hx := w * 0.5
	var hy := h * 0.5
	var hz := d * 0.5
	_quad(c + Vector3(hx, 0, 0), Vector3(0, 0, -hz), Vector3(0, hy, 0), Vector3.RIGHT, col)
	_quad(c - Vector3(hx, 0, 0), Vector3(0, 0, hz), Vector3(0, hy, 0), Vector3.LEFT, col)
	_quad(c + Vector3(0, hy, 0), Vector3(hx, 0, 0), Vector3(0, 0, -hz), Vector3.UP, top)
	_quad(c + Vector3(0, 0, hz), Vector3(hx, 0, 0), Vector3(0, hy, 0), Vector3.BACK, col)
	_quad(c - Vector3(0, 0, hz), Vector3(-hx, 0, 0), Vector3(0, hy, 0), Vector3.FORWARD, col)


func add_solid(x: float, y: float, z: float, w: float, h: float, d: float, col: Color, vaultable := false, deco := false) -> void:
	_box_geo(x, y, z, w, h, d, col)
	if deco:
		return
	var o := Obstacle.new()
	o.min_x = x - w * 0.5
	o.max_x = x + w * 0.5
	o.min_z = z - d * 0.5
	o.max_z = z + d * 0.5
	o.h = h
	o.vaultable = vaultable
	obstacles.append(o)


func _segs(center: float, length: float, door: Variant) -> Array:
	var a := center - length * 0.5
	var b := center + length * 0.5
	if door == null:
		return [[a, b]]
	var dc := center + float(door)
	var hw := 1.3
	var out := []
	if dc - hw - a > 0.45:
		out.append([a, dc - hw])
	if b - (dc + hw) > 0.45:
		out.append([dc + hw, b])
	return out


func wall_x(z: float, xc: float, length: float, door: Variant, h: float, col: Color, t := 0.48) -> void:
	for s in _segs(xc, length, door):
		var a: float = s[0]
		var b: float = s[1]
		add_solid((a + b) * 0.5, 0, z, b - a, h, t, col)


func wall_z(x: float, zc: float, length: float, door: Variant, h: float, col: Color, t := 0.48) -> void:
	for s in _segs(zc, length, door):
		var a: float = s[0]
		var b: float = s[1]
		add_solid(x, 0, (a + b) * 0.5, t, h, b - a, col)


func building(cx: float, cz: float, w: float, d: float, doors: Dictionary, div: String, div_door: float) -> void:
	var h := 2.9
	var col: Color = COL["wall"]
	var x0 := cx - w * 0.5
	var z0 := cz - d * 0.5
	var z1 := cz + d * 0.5
	wall_x(z0, cx, w, doors.get("n"), h, col)
	wall_x(z1, cx, w, doors.get("s"), h, col)
	wall_z(x0, cz, d, doors.get("w"), h, col)
	wall_z(x0 + w, cz, d, doors.get("e"), h, col)
	add_solid(cx, 0.02, cz, w - 0.6, 0.03, d - 0.6, COL["floor"], false, true)
	if div == "z":
		wall_x(cz, cx, w - 0.96, div_door, h, col)
	elif div == "x":
		wall_z(cx, cz, d - 0.96, div_door, h, col)


func crate(x: float, z: float, s: float, col: Color, h := -1.0) -> void:
	var hh := s if h < 0.0 else h
	add_solid(x, 0, z, s, hh, s, col, hh <= 1.15)


func cluster(x: float, z: float) -> void:
	crate(x, z, 1.15, COL["crate"], 1.05)
	crate(x + 1.15, z + 0.7, 1.0, COL["crate2"], 0.95)
	crate(x + 0.2, z + 1.25, 0.9, COL["crate"], 0.7)


func hurdle(x: float, z: float, rot: bool) -> void:
	if rot:
		add_solid(x, 0, z, 0.28, 0.72, 2.5, COL["low"], true)
	else:
		add_solid(x, 0, z, 2.5, 0.72, 0.28, COL["low"], true)


func low(x: float, z: float, w: float, d: float, h := 0.82) -> void:
	add_solid(x, 0, z, w, h, d, COL["cover"], true)


static func _blend(img: Image, x: int, y: int, c: Color, a: float) -> void:
	var s := img.get_width()
	var px := posmod(x, s)
	var py := posmod(y, s)
	img.set_pixel(px, py, img.get_pixel(px, py).lerp(c, a))


static func grass_texture() -> ImageTexture:
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	img.fill(Color8(60, 90, 51))
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 3200:
		var x := rng.randi_range(0, s - 1)
		var y := rng.randi_range(0, s - 1)
		var c := Color8(28 + rng.randi_range(0, 28), 52 + rng.randi_range(0, 55), 18 + rng.randi_range(0, 22))
		var a := rng.randf_range(0.3, 0.75)
		var w := rng.randi_range(1, 3)
		var h := rng.randi_range(1, 3)
		for yy in h:
			for xx in w:
				_blend(img, x + xx, y + yy, c, a)
	for i in 1100:
		var x := rng.randf_range(0, s)
		var y := rng.randf_range(0, s)
		var h := rng.randf_range(3, 11)
		var lean := rng.randf_range(-1.6, 1.6)
		var c := Color8(24 + rng.randi_range(0, 32), 72 + rng.randi_range(0, 72), 18 + rng.randi_range(0, 28))
		var a := rng.randf_range(0.4, 0.85)
		var steps := int(h)
		for t in steps:
			var u := float(t) / h
			_blend(img, int(x + lean * u * u), int(y - t), c, a)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func dirt_texture() -> ImageTexture:
	var s := 128
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	img.fill(Color8(106, 88, 64))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 1100:
		var x := rng.randi_range(0, s - 1)
		var y := rng.randi_range(0, s - 1)
		var c := Color8(88 + rng.randi_range(0, 55), 68 + rng.randi_range(0, 42), 36 + rng.randi_range(0, 28))
		var a := rng.randf_range(0.28, 0.7)
		var r := rng.randi_range(0, 2)
		for yy in range(-r, r + 1):
			for xx in range(-r, r + 1):
				if xx * xx + yy * yy <= r * r:
					_blend(img, x + xx, y + yy, c, a)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _ground_plane(x: float, z: float, w: float, d: float, rot: float, mat: Material, y: float) -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(w, d)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = mat
	mi.position = Vector3(x, y, z)
	mi.rotation.y = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


func build(start: Vector3, extract: Vector3) -> void:
	var ground_size := WORLD * 2.0 + 16.0
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = grass_texture()
	gm.albedo_color = Color8(180, 192, 168)
	gm.roughness = 1.0
	gm.uv1_scale = Vector3(ground_size / 4.5, ground_size / 4.5, 1)
	gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_ground_plane(0, 0, ground_size, ground_size, 0, gm, 0)

	var dirt := dirt_texture()
	var paths := [[0.0, 0.0, 11.0, WORLD * 2.0 - 8.0, 0.0], [0.0, 8.0, 86.0, 8.0, 0.0], [-22.0, -30.0, 36.0, 7.0, 0.15], [20.0, -40.0, 32.0, 7.0, -0.2]]
	var i := 0
	for p in paths:
		var dm := StandardMaterial3D.new()
		dm.albedo_texture = dirt
		dm.albedo_color = Color8(216, 200, 168)
		dm.roughness = 1.0
		var w: float = p[2]
		var d: float = p[3]
		dm.uv1_scale = Vector3(w / 4.0, d / 4.0, 1)
		dm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_ground_plane(p[0], p[1], w, d, p[4], dm, 0.012 + i * 0.002)
		i += 1
	var pad := StandardMaterial3D.new()
	pad.albedo_texture = dirt
	pad.albedo_color = Color8(200, 192, 168)
	_ground_plane(start.x, start.z, 6, 5.5, 0, pad, 0.024)
	var ex := StandardMaterial3D.new()
	ex.albedo_texture = dirt
	ex.albedo_color = Color8(154, 170, 136)
	_ground_plane(extract.x, extract.z, 8, 7, 0, ex, 0.024)

	var W := WORLD
	var peri: Color = COL["peri"]
	var gap := 7.0
	wall_x(-W, (-W - gap) * 0.5, W - gap, null, 3.4, peri, 1.4)
	wall_x(-W, (W + gap) * 0.5, W - gap, null, 3.4, peri, 1.4)
	wall_x(W, 0, W * 2 + 1.4, null, 3.4, peri, 1.4)
	wall_z(-W, 0, W * 2 + 1.4, null, 3.4, peri, 1.4)
	wall_z(W, 0, W * 2 + 1.4, null, 3.4, peri, 1.4)

	building(-28, 70, 34, 22, {"e": 0.0, "n": 5.0}, "x", 2)
	building(28, 69, 34, 22, {"w": 0.0, "n": -4.0}, "x", -2)
	building(-40, 20, 30, 24, {"e": 0.0, "s": 4.0}, "z", 0)
	building(41, 17, 34, 26, {"w": 1.0, "n": -5.0}, "z", 3)
	building(-44, -48, 42, 30, {"e": -4.0, "s": 5.0}, "x", 0)
	building(40, -56, 28, 26, {"w": 0.0, "s": -3.0}, "z", 0)

	for c in [[-5, 80], [7, 77], [-12, 58], [11, 56], [5, 38], [-8, 24], [10, 8], [-14, -6], [-20, -30], [18, -40], [-8, -74], [7, -80]]:
		cluster(c[0], c[1])
	crate(-4, 73, 1.0, COL["crate2"], 1.5)
	crate(13, -50, 1.2, COL["crate"], 1.5)
	crate(-84, 10, 1.2, COL["crate"], 1.1)
	crate(84, -14, 1.2, COL["crate2"], 1.1)

	low(-6, 73, 3.4, 0.42, 0.85)
	low(5, 62, 0.42, 4.0, 0.88)
	low(0, 44, 4.4, 0.42, 0.8)
	low(-13, 32, 0.45, 4.2, 0.9)
	low(8, 26, 4.0, 0.42, 0.82)
	low(-4, 4, 0.42, 4.6, 0.88)
	low(10, -8, 3.6, 0.42, 0.8)
	low(-10, -20, 4.0, 0.42, 0.85)
	low(5, -44, 0.42, 4.0, 0.9)
	low(-8, -72, 3.6, 0.42, 0.85)
	low(8, -82, 0.42, 3.6, 0.88)

	hurdle(0, 50, false)
	hurdle(4, 22, false)
	hurdle(-3, -4, false)
	hurdle(6, -62, true)

	var mark: Color = COL["mark"]
	add_solid(0, 0.03, start.z - 1.4, 0.35, 0.02, 1.4, mark, false, true)
	add_solid(-0.35, 0.03, start.z - 2.0, 0.3, 0.02, 0.3, mark, false, true)
	add_solid(0.35, 0.03, start.z - 2.0, 0.3, 0.02, 0.3, mark, false, true)
	add_solid(0, 0.03, extract.z + 0.6, 3.2, 0.02, 0.4, mark, false, true)
	add_solid(0, 0.03, extract.z - 0.6, 2.2, 0.02, 0.35, mark, false, true)
	add_solid(-5.2, 0, -100.2, 1.2, 3.6, 1.2, peri)
	add_solid(5.2, 0, -100.2, 1.2, 3.6, 1.2, peri)
	add_solid(0, 3.3, -100.2, 11, 0.32, 0.65, mark, false, true)

	var mesh := _st.commit()
	var lm := StandardMaterial3D.new()
	lm.vertex_color_use_as_albedo = true
	lm.roughness = 0.92
	lm.albedo_color = Color(0.86, 0.86, 0.86)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = lm
	root.add_child(mi)

	# Extract beacon: ring + pole + label.
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 4.3
	tm.outer_radius = 4.6
	tm.rings = 48
	tm.ring_segments = 6
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(0.95, 0.8, 0.3)
	ring.material_override = rm
	ring.position = Vector3(extract.x, 0.06, extract.z)
	ring.scale = Vector3(1, 0.15, 1)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.06
	pm.bottom_radius = 0.06
	pm.height = 4.0
	pole.mesh = pm
	pole.material_override = rm
	pole.position = Vector3(extract.x + 3.4, 2.0, extract.z)
	root.add_child(pole)
	var flag := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(1.2, 0.6, 0.04)
	flag.mesh = fm
	var flm := StandardMaterial3D.new()
	flm.albedo_color = Color(0.86, 0.42, 0.18)
	flag.material_override = flm
	flag.position = Vector3(extract.x + 2.8, 3.65, extract.z)
	root.add_child(flag)
	var lbl := Label3D.new()
	lbl.text = "EXTRACT"
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 96
	lbl.pixel_size = 0.01
	lbl.modulate = Color(1, 0.88, 0.45)
	lbl.outline_size = 18
	lbl.position = Vector3(extract.x, 4.6, extract.z)
	root.add_child(lbl)
