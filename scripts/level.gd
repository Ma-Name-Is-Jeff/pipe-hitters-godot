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


func add_solid(x: float, y: float, z: float, w: float, h: float, d: float, col: Color, vaultable := false, deco := false, blocks_ray := true) -> void:
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
	o.blocks_ray = blocks_ray
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
	gm.albedo_color = Color8(120, 138, 128)
	gm.roughness = 0.55
	gm.metallic_specular = 0.7
	var tiles := 6
	var ts := ground_size / tiles
	gm.uv1_scale = Vector3(ts / 4.5, ts / 4.5, 1)
	gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for gx in tiles:
		for gz in tiles:
			_ground_plane(-ground_size * 0.5 + ts * (gx + 0.5), -ground_size * 0.5 + ts * (gz + 0.5), ts, ts, 0, gm, 0)

	var dirt := dirt_texture()
	var paths := [[0.0, 0.0, 11.0, WORLD * 2.0 - 8.0, 0.0], [0.0, 8.0, 86.0, 8.0, 0.0], [-22.0, -30.0, 36.0, 7.0, 0.15], [20.0, -40.0, 32.0, 7.0, -0.2]]
	var i := 0
	for p in paths:
		var dm := StandardMaterial3D.new()
		dm.albedo_texture = dirt
		dm.albedo_color = Color8(92, 88, 84)
		dm.roughness = 0.2
		dm.metallic_specular = 0.9
		var w: float = p[2]
		var d: float = p[3]
		dm.uv1_scale = Vector3(w / 4.0, d / 4.0, 1)
		dm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_ground_plane(p[0], p[1], w, d, p[4], dm, 0.012 + i * 0.002)
		i += 1
	var pad := StandardMaterial3D.new()
	pad.albedo_texture = dirt
	pad.albedo_color = Color8(84, 82, 78)
	pad.roughness = 0.3
	_ground_plane(start.x, start.z, 6, 5.5, 0, pad, 0.024)
	var ex := StandardMaterial3D.new()
	ex.albedo_texture = dirt
	ex.albedo_color = Color8(70, 84, 72)
	ex.roughness = 0.3
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

	_build_mood()
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


# ---------- night mood: fences, catwalks, floodlights, practical lights, puddles ----------

var _beam_mat: StandardMaterial3D
var _pool_cold: StandardMaterial3D
var _pool_warm: StandardMaterial3D
var _fence_mat: StandardMaterial3D


static func _grad(radial: bool, a: Color, b: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 64
	if radial:
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
	else:
		t.fill_from = Vector2(0, 0)
		t.fill_to = Vector2(0, 1)
	return t


static func _additive(tex: Texture2D, col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = tex
	m.albedo_color = col
	m.disable_receive_shadows = true
	return m


func _fx(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


func _pool(x: float, z: float, r: float, mat: Material) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(r * 2.0, r * 2.0)
	_fx(q, mat, Vector3(x, 0.035, z), Vector3(-PI * 0.5, 0, 0))


## Floodlight tower: pole, lamp head, fake volumetric beam and a light pool.
func flood(x: float, z: float, tx: float, tz: float) -> void:
	var h := 6.2
	add_solid(x, 0, z, 0.22, h, 0.22, Color8(58, 62, 66))
	add_solid(x, h - 0.15, z, 0.7, 0.3, 0.5, Color8(40, 42, 46), false, true)
	var lamp := BoxMesh.new()
	lamp.size = Vector3(0.6, 0.12, 0.4)
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.85, 0.93, 1.0)
	_fx(lamp, lm, Vector3(x, h - 0.24, z))
	var top := Vector3(x, h - 0.3, z)
	var bot := Vector3(tx, 0.0, tz)
	var d := bot - top
	var l := d.length()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.3
	cone.bottom_radius = 2.8
	cone.height = l
	cone.radial_segments = 16
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	var mi := _fx(cone, _beam_mat, (top + bot) * 0.5)
	var yax := -d / l
	var xax := yax.cross(Vector3.FORWARD)
	if xax.length() < 0.05:
		xax = yax.cross(Vector3.RIGHT)
	xax = xax.normalized()
	mi.basis = Basis(xax, yax, xax.cross(yax))
	_pool(tx, tz, 5.2, _pool_cold)


## Warm practical light: small lamp box + warm pool.
func practical(x: float, z: float, y := 2.5) -> void:
	var b := BoxMesh.new()
	b.size = Vector3(0.28, 0.16, 0.28)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.72, 0.38)
	_fx(b, m, Vector3(x, y, z))
	var g := QuadMesh.new()
	g.size = Vector2(1.6, 1.6)
	var gm := _additive(_grad(true, Color(1, 0.7, 0.35, 0.55), Color(1, 0.6, 0.3, 0.0)), Color.WHITE)
	gm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_fx(g, gm, Vector3(x, y, z))
	_pool(x, z, 3.6, _pool_warm)


## Chain-link fence run along X or Z. Blocks movement, not bullets or sight.
func fence(x0: float, z0: float, x1: float, z1: float) -> void:
	var len := Vector2(x1 - x0, z1 - z0).length()
	var along_x := absf(x1 - x0) > absf(z1 - z0)
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	var h := 2.3
	var post := Color8(70, 74, 78)
	var n := int(ceil(len / 3.0))
	for i in n + 1:
		var u := float(i) / n
		add_solid(lerpf(x0, x1, u), 0, lerpf(z0, z1, u), 0.1, h, 0.1, post, false, true)
	add_solid(cx, h - 0.05, cz, len if along_x else 0.06, 0.06, 0.06 if along_x else len, post, false, true)
	var o := Obstacle.new()
	o.min_x = minf(x0, x1) - 0.06
	o.max_x = maxf(x0, x1) + 0.06
	o.min_z = minf(z0, z1) - 0.06
	o.max_z = maxf(z0, z1) + 0.06
	o.h = h
	o.blocks_ray = false
	obstacles.append(o)
	var q := QuadMesh.new()
	q.size = Vector2(len, h)
	var mi := _fx(q, _fence_mat, Vector3(cx, h * 0.5, cz), Vector3(0, 0.0 if along_x else PI * 0.5, 0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


static func chain_texture() -> ImageTexture:
	var s := 32
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in s:
		for w in 2:
			img.set_pixel((i + w) % s, i, Color(0.62, 0.66, 0.7, 1))
			img.set_pixel((s - 1 - i + w) % s, i, Color(0.62, 0.66, 0.7, 1))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Overhead catwalk between two points (deco, no collision except end posts).
func catwalk(x0: float, x1: float, z: float, y := 3.1) -> void:
	var len := absf(x1 - x0)
	var cx := (x0 + x1) * 0.5
	var steel := Color8(64, 68, 72)
	add_solid(cx, y, z, len, 0.12, 1.4, Color8(52, 55, 58), false, true)
	add_solid(cx, y + 1.0, z - 0.68, len, 0.05, 0.05, steel, false, true)
	add_solid(cx, y + 1.0, z + 0.68, len, 0.05, 0.05, steel, false, true)
	add_solid(cx, y + 0.5, z - 0.68, len, 0.04, 0.04, steel, false, true)
	add_solid(cx, y + 0.5, z + 0.68, len, 0.04, 0.04, steel, false, true)
	var n := int(ceil(len / 2.5))
	for i in n + 1:
		var px := lerpf(x0, x1, float(i) / n)
		add_solid(px, y, z - 0.68, 0.05, 1.0, 0.05, steel, false, true)
		add_solid(px, y, z + 0.68, 0.05, 1.0, 0.05, steel, false, true)
	for px in [x0 + 0.4, x1 - 0.4]:
		add_solid(px, 0, z, 0.26, y, 0.26, steel)


func puddle(x: float, z: float, w: float, d: float) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(w, d)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.03, 0.04, 0.05)
	m.roughness = 0.04
	m.metallic = 0.6
	m.metallic_specular = 1.0
	_fx(q, m, Vector3(x, 0.03, z), Vector3(-PI * 0.5, 0, 0))


func _build_mood() -> void:
	_mood_mats()
	_mood_objects()


func _mood_mats() -> void:
	_beam_mat = _additive(_grad(false, Color(0.75, 0.86, 1.0, 0.085), Color(0.6, 0.75, 1.0, 0.0)), Color.WHITE)
	_pool_cold = _additive(_grad(true, Color(0.62, 0.74, 0.95, 0.42), Color(0.5, 0.6, 0.9, 0.0)), Color.WHITE)
	_pool_warm = _additive(_grad(true, Color(1.0, 0.62, 0.3, 0.38), Color(1.0, 0.5, 0.2, 0.0)), Color.WHITE)
	_fence_mat = StandardMaterial3D.new()
	_fence_mat.albedo_texture = chain_texture()
	_fence_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_fence_mat.alpha_scissor_threshold = 0.5
	_fence_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_fence_mat.metallic = 0.5
	_fence_mat.roughness = 0.4
	_fence_mat.uv1_scale = Vector3(8, 2, 1)
	_fence_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS



func _mood_objects() -> void:
	for f in [[7.5, 80, 1.5, 74], [-7.5, 57, -1.5, 52], [7.5, 36, 1.5, 32], [-7.5, 14, -1.5, 10],
			[7.5, -6, 1.5, -10], [-7.5, -27, -1.5, -32], [7.5, -46, 1.5, -50], [-7.5, -66, -1.5, -72], [7.5, -84, 1.5, -86]]:
		flood(f[0], f[1], f[2], f[3])
	for pr in [[-10.8, 72.5], [10.8, 71.5], [-24.6, 22.0], [23.6, 15.0], [-22.6, -51.0], [25.6, -58.0], [-5.2, -98.9], [5.2, -98.9]]:
		practical(pr[0], pr[1])

	fence(20, 40, 60, 40)
	fence(-60, -20, -20, -20)
	fence(-30, -76, -12, -76)
	fence(12, -76, 30, -76)
	fence(60, 36, 60, 2)
	catwalk(-10.8, 10.8, 64.0)
	catwalk(-22.6, 25.6, -55.0)
	catwalk(-24.6, 23.6, 12.0, 3.0)

	for pd in [[2, 66, 3.2, 1.6], [-3, 41, 2.4, 1.4], [3, 2, 3.6, 1.8], [-2, -36, 2.8, 1.3], [1, -58, 3.0, 2.0], [-2, -80, 2.6, 1.4], [14, 20, 2.2, 1.2], [-26, -26, 3.0, 1.5]]:
		puddle(pd[0], pd[1], pd[2], pd[3])


# ---------- arena props (v1m): original low-poly Blender props, one MultiMesh per type ----------

## Footprint / height of each prop in metres (w = x, h = y, d = z at yaw 0). Must match art/models/props.glb;
## test_v1m.gd checks every obstacle against the real mesh bounds.
const PROP_DEFS := {
	"crate": Vector3(1.0, 1.0, 1.0),
	"box": Vector3(0.9, 0.645, 0.64),
	"pallet": Vector3(1.2, 0.144, 0.98),
	"pallet_stack": Vector3(1.2, 0.72, 0.98),
	"tire_stack3": Vector3(0.76, 0.66, 0.76),
	"tire_stack4": Vector3(0.76, 0.88, 0.76),
	"tire_tower": Vector3(0.76, 1.32, 0.76),
	"barrel_a": Vector3(0.624, 0.92, 0.624),
	"barrel_b": Vector3(0.624, 0.92, 0.624),
	"car": Vector3(4.42, 1.45, 1.79),
}
const PROP_GAP := 0.06
const PROP_VAULT_MAX := 1.15  # same as Main.VAULT_MAX: at or below this a prop is a vaultable low cover

var prop_xf := {}  # name -> Array[Transform3D], committed into MultiMeshes by commit_props()
var prop_obstacles: Array[Obstacle] = []


## Place a prop (or a stack of props, bottom first). Solid props add ONE axis-aligned obstacle that covers the
## whole stack, so collision, vaulting and bullets match what is drawn. quarters = yaw in 90 degree steps.
func prop(names: Variant, x: float, z: float, quarters := 0, solid := true) -> void:
	var list: Array = names if names is Array else [names]
	var y := 0.0
	var w := 0.0
	var d := 0.0
	for n in list:
		var s: Vector3 = PROP_DEFS[n]
		if not prop_xf.has(n):
			prop_xf[n] = []
		var tr := Transform3D(Basis(Vector3.UP, quarters * PI * 0.5), Vector3(x, y, z))
		(prop_xf[n] as Array).append(tr)
		y += s.y
		w = maxf(w, s.x)
		d = maxf(d, s.z)
	if not solid:
		return
	if quarters % 2 != 0:
		var tmp := w
		w = d
		d = tmp
	var o := Obstacle.new()
	o.min_x = x - w * 0.5
	o.max_x = x + w * 0.5
	o.min_z = z - d * 0.5
	o.max_z = z + d * 0.5
	o.h = y
	o.vaultable = y <= PROP_VAULT_MAX
	o.blocks_ray = true
	obstacles.append(o)
	prop_obstacles.append(o)


## A tight row of props centred on (cx, cz), running along x or z, each rotated so its long side lies along the row.
func prop_row(names: Array, cx: float, cz: float, along_x := true) -> void:
	var q := 0 if along_x else 1
	var lens: Array[float] = []
	var total := PROP_GAP * (names.size() - 1)
	for n in names:
		var s: Vector3 = PROP_DEFS[(n as Array)[0] if n is Array else n]
		lens.append(s.x)  # the prop's x side lies along the row (yaw 0 for x rows, 90 degrees for z rows)
		total += s.x
	var cur := -total * 0.5
	for i in names.size():
		var c := cur + lens[i] * 0.5
		if along_x:
			prop(names[i], cx + c, cz, 0)
		else:
			prop(names[i], cx, cz + c, 1)
		cur += lens[i] + PROP_GAP


func commit_props() -> void:
	var mats := StandardMaterial3D.new()
	mats.vertex_color_use_as_albedo = true
	mats.roughness = 0.92
	mats.albedo_color = Color(0.86, 0.86, 0.86)
	var scn := (load("res://art/models/props.glb") as PackedScene).instantiate()
	for n in prop_xf:
		var src := scn.find_child(n, true, false) as MeshInstance3D
		var xs: Array = prop_xf[n]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = src.mesh
		mm.instance_count = xs.size()
		for i in xs.size():
			mm.set_instance_transform(i, xs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Props_" + n
		mmi.multimesh = mm
		mmi.material_override = mats
		root.add_child(mmi)
	scn.free()


# ---------- tuning arena (about 40 x 40) ----------

const ARENA_HALF := 20.0
const ARENA_START := Vector3(0, 0, 15)
const ARENA_SPAWNS := [Vector2(0, -10), Vector2(-9, -11), Vector2(9, -9)]


func build_arena() -> void:
	var gsz := ARENA_HALF * 2.0 + 20.0
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = grass_texture()
	gm.albedo_color = Color8(120, 138, 128)
	gm.roughness = 0.55
	gm.metallic_specular = 0.7
	gm.uv1_scale = Vector3(gsz / 4.5, gsz / 4.5, 1)
	gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_ground_plane(0, 0, gsz, gsz, 0, gm, 0)
	var dm := StandardMaterial3D.new()
	dm.albedo_texture = dirt_texture()
	dm.albedo_color = Color8(92, 88, 84)
	dm.roughness = 0.2
	dm.metallic_specular = 0.9
	dm.uv1_scale = Vector3(3, 10, 1)
	_ground_plane(0, 0, 6, 40, 0, dm, 0.012)
	var peri: Color = COL["peri"]
	var e := ARENA_HALF + 0.5
	wall_x(-e, 0, 42, null, 3.0, peri, 1.0)
	wall_x(e, 0, 42, null, 3.0, peri, 1.0)
	wall_z(-e, 0, 42, null, 3.0, peri, 1.0)
	wall_z(e, 0, 42, null, 3.0, peri, 1.0)
	# Props replace the plain low walls and crate clusters (same places, same roles). Low props (<= 1.15 m) stay
	# vaultable low cover; tall props and the car are full cover (not vaultable, block bullets and sight).
	# The slide lane (z = -1.2..1.2, x = -8..13) stays clear.
	prop_row([["pallet_stack"], ["pallet_stack"], ["pallet_stack"]], -7.0, 6.0, true)          # was low(-7, 6, 4.0 x 0.42)
	prop_row(["tire_stack4", "tire_stack3", "tire_stack4", "tire_stack3", "tire_stack4"], 6.0, 7.0, false)  # was low(6, 7)
	prop_row(["box", "box", "crate", "box", "box"], -3.0, -4.0, true)                            # was low(-3, -4)
	prop_row(["barrel_a", "barrel_b", "barrel_a", "barrel_a", "barrel_b", "barrel_a"], 12.6, -10.0, true)  # was low(12, -10)
	prop_row(["crate", "crate", "box", "box"], -12.0, -12.0, false)                              # was low(-12, -12)
	# Tall cover: crates on a pallet (was cluster(-14, 2)), tire tower + tall pallet stack (was cluster(9, -4)).
	prop(["pallet", "crate", "crate"], -14.0, 2.0)
	prop("crate", -12.85, 2.75)
	prop("box", -11.4, 1.6)
	prop("tire_tower", 9.0, -4.0)
	prop(["pallet_stack", "pallet_stack"], 10.5, -3.5)
	prop("barrel_b", 7.5, -3.6)
	prop(["pallet_stack", "pallet_stack"], 2.0, -16.0, 1)
	prop("barrel_a", 3.2, -15.2)
	# The one stationary generic car: full cover, long side along x.
	prop("car", 9.5, 12.5)
	# v1o: four more tall stacks (reused meshes) so bots have hide spots in every quarter.
	# Slide lane (z -1.2..1.2, x -8..13.9), start, spawns and patrols stay clear.
	prop(["pallet", "crate", "crate"], -14.0, 11.5)          # NW crate stack
	prop(["pallet_stack", "pallet_stack"], 13.0, 7.5)        # NE pallet tower
	prop("tire_tower", -10.0, -16.0)                         # SW tire tower
	prop(["pallet", "crate", "crate"], 11.0, -15.0)          # SE crate stack
	# Loose pallets lying on the ground (walk-over decoration, no collision).
	prop("pallet", -5.0, 7.6, 0, false)
	prop("pallet", -10.4, 4.6, 1, false)
	prop("pallet", 7.6, -7.4, 0, false)
	prop("pallet", -2.0, 14.0, 1, false)
	prop("pallet", 5.0, 12.4, 0, false)
	# Hurdles to vault.
	hurdle(0, 8, false)
	hurdle(-14, -6, true)
	# Slide wall at the end of a clear lane along z = 0 (x from -8 to 13).
	wall_z(14.5, 0, 9, null, 3.0, COL["wall"], 0.6)
	var mark: Color = COL["mark"]
	add_solid(2.5, 0.03, 0, 21.0, 0.02, 0.18, mark, false, true)
	add_solid(-8.0, 0.03, 0, 0.18, 0.02, 1.4, mark, false, true)
	add_solid(13.9, 0.03, 0, 0.18, 0.02, 1.4, mark, false, true)
	add_solid(0, 0.03, ARENA_START.z - 1.2, 0.35, 0.02, 1.4, mark, false, true)
	_mood_mats()
	for c in [[-17.0, 17.0, -8.0, 8.0], [17.0, 17.0, 8.0, 8.0], [-17.0, -17.0, -8.0, -8.0], [17.0, -17.0, 8.0, -8.0]]:
		flood(c[0], c[1], c[2], c[3])
	practical(-19.2, 0.0)
	practical(14.0, 4.9)
	for pd in [[-2.0, 11.0, 3.0, 1.5], [3.0, -1.0, 2.6, 1.3], [-6.0, -8.0, 3.2, 1.6]]:
		puddle(pd[0], pd[1], pd[2], pd[3])
	var lbl := Label3D.new()
	lbl.text = "SLIDE LANE  >>>"
	lbl.font_size = 64
	lbl.pixel_size = 0.01
	lbl.modulate = Color(1, 0.88, 0.45)
	lbl.outline_size = 12
	lbl.rotation = Vector3(-PI * 0.5, 0, 0)
	lbl.position = Vector3(2.5, 0.05, 1.3)
	root.add_child(lbl)
	var mesh := _st.commit()
	var lm := StandardMaterial3D.new()
	lm.vertex_color_use_as_albedo = true
	lm.roughness = 0.92
	lm.albedo_color = Color(0.86, 0.86, 0.86)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = lm
	root.add_child(mi)
	commit_props()
