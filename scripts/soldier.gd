class_name Soldier
extends Node3D
## Original low-poly tactical soldier built from primitives.
## Faces +Z. Index 0 = left side (+X), index 1 = right side (-X, trigger hand).

const HIP_Y := 0.97
const LEN_THIGH := 0.44
const LEN_SHIN := 0.40
const LEN_UPPER := 0.30
const LEN_FORE := 0.28
const SHOULDER_L := Vector3(0.19, 0.44, 0.02)
const SHOULDER_R := Vector3(-0.19, 0.44, -0.02)
const GUN_AIM_POS := Vector3(-0.12, 0.41, 0.30)
const GUN_READY_POS := Vector3(-0.07, 0.27, 0.27)
const GUN_READY_ROT := Vector3(0.5, 0.42, 0.18)
const AIM_TWIST := -0.3

static var _meshes := {}

var body: Node3D
var hips: Node3D
var spine: Node3D
var neck: Node3D
var head: Node3D
var thighs: Array[Node3D] = []
var knees: Array[Node3D] = []
var feet: Array[Node3D] = []
var upper_arms: Array[Node3D] = []
var fore_arms: Array[Node3D] = []
var hands: Array[Node3D] = []
var gun: Node3D
var grip_r: Node3D
var grip_l: Node3D
var mag_pt: Node3D
var muzzle: Node3D
## Swappable outfit groups.
var part_helmet: Node3D
var part_top: Node3D
var part_bottom: Node3D
var mats: Array[StandardMaterial3D] = []

var k_crouch := 0.0
var k_aim := 0.0
var k_slide := 0.0
var k_side := 0.0
var k_down := 0.0
var k_run := 0.0


static func _cap(r: float, h: float) -> Mesh:
	var key := "cap%.3f_%.3f" % [r, h]
	if not _meshes.has(key):
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = maxf(h, r * 2.0 + 0.002)
		m.radial_segments = 10
		m.rings = 2
		_meshes[key] = m
	return _meshes[key]


static func _box(w: float, h: float, d: float) -> Mesh:
	var key := "box%.3f_%.3f_%.3f" % [w, h, d]
	if not _meshes.has(key):
		var m := BoxMesh.new()
		m.size = Vector3(w, h, d)
		_meshes[key] = m
	return _meshes[key]


static func _sph(r: float) -> Mesh:
	var key := "sph%.3f" % r
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = 12
		m.rings = 6
		_meshes[key] = m
	return _meshes[key]


static func _cyl(r: float, h: float) -> Mesh:
	var key := "cyl%.3f_%.3f" % [r, h]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = r
		m.bottom_radius = r
		m.height = h
		m.radial_segments = 8
		m.rings = 1
		_meshes[key] = m
	return _meshes[key]


func _mat(c: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	m.emission_enabled = true
	m.emission = Color(0, 0, 0)
	mats.append(m)
	return m


func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func setup(top: Color, bottom: Color, vest: Color, helmet: Color, gear: Color, skin: Color, gun_col: Color) -> void:
	var m_top := _mat(top)
	var m_bot := _mat(bottom)
	var m_vest := _mat(vest, 0.9)
	var m_helm := _mat(helmet, 0.6)
	var m_gear := _mat(gear, 0.9)
	var m_skin := _mat(skin, 0.65)
	var m_boot := _mat(Color(0.13, 0.12, 0.11), 0.7)
	var m_glove := _mat(Color(0.17, 0.16, 0.14), 0.75)
	var m_gun := _mat(gun_col, 0.45, 0.35)
	var m_dark := _mat(Color(0.07, 0.07, 0.08), 0.35, 0.25)

	body = Node3D.new()
	add_child(body)
	hips = Node3D.new()
	hips.position = Vector3(0, HIP_Y, 0)
	body.add_child(hips)

	part_bottom = Node3D.new()
	hips.add_child(part_bottom)
	_mi(part_bottom, _box(0.31, 0.2, 0.2), m_bot, Vector3.ZERO)
	_mi(part_bottom, _box(0.33, 0.05, 0.22), m_gear, Vector3(0, 0.09, 0), Vector3.ZERO, Vector3.ONE, false)
	for i in 2:
		var sx := 0.095 if i == 0 else -0.095
		var th := Node3D.new()
		th.position = Vector3(sx, -0.05, 0)
		hips.add_child(th)
		_mi(th, _cap(0.082, LEN_THIGH + 0.12), m_bot, Vector3(0, -LEN_THIGH * 0.5, 0))
		if i == 1:
			_mi(th, _box(0.05, 0.13, 0.11), m_gear, Vector3(-0.085, -0.15, 0), Vector3.ZERO, Vector3.ONE, false)
		var kn := Node3D.new()
		kn.position = Vector3(0, -LEN_THIGH, 0)
		th.add_child(kn)
		_mi(kn, _box(0.1, 0.1, 0.05), m_gear, Vector3(0, -0.01, 0.07), Vector3.ZERO, Vector3.ONE, false)
		_mi(kn, _cap(0.068, LEN_SHIN + 0.08), m_bot, Vector3(0, -LEN_SHIN * 0.5, 0))
		var ft := Node3D.new()
		ft.position = Vector3(0, -LEN_SHIN, 0)
		kn.add_child(ft)
		_mi(ft, _box(0.11, 0.1, 0.27), m_boot, Vector3(0, -0.035, 0.05))
		thighs.append(th)
		knees.append(kn)
		feet.append(ft)

	spine = Node3D.new()
	spine.position = Vector3(0, 0.07, 0)
	hips.add_child(spine)
	part_top = Node3D.new()
	spine.add_child(part_top)
	_mi(part_top, _cap(0.13, 0.5), m_top, Vector3(0, 0.24, 0), Vector3.ZERO, Vector3(1.3, 1.0, 0.85))
	_mi(part_top, _box(0.37, 0.3, 0.27), m_vest, Vector3(0, 0.3, 0.005))
	for px in [-0.11, 0.0, 0.11]:
		_mi(part_top, _box(0.085, 0.11, 0.06), m_gear, Vector3(px, 0.22, 0.165), Vector3.ZERO, Vector3.ONE, false)
	_mi(part_top, _box(0.27, 0.24, 0.09), m_gear, Vector3(0, 0.31, -0.175), Vector3.ZERO, Vector3.ONE, false)
	_mi(part_top, _sph(0.07), m_top, SHOULDER_L)
	_mi(part_top, _sph(0.07), m_top, SHOULDER_R)

	neck = Node3D.new()
	neck.position = Vector3(0, 0.47, 0)
	spine.add_child(neck)
	_mi(neck, _cap(0.048, 0.13), m_skin, Vector3(0, 0.03, 0))
	head = Node3D.new()
	head.position = Vector3(0, 0.09, 0)
	neck.add_child(head)
	_mi(head, _sph(0.1), m_skin, Vector3(0, 0.1, 0.012), Vector3.ZERO, Vector3(0.9, 1.1, 1.0))
	part_helmet = Node3D.new()
	head.add_child(part_helmet)
	_mi(part_helmet, _sph(0.122), m_helm, Vector3(0, 0.15, -0.005), Vector3.ZERO, Vector3(1.0, 0.8, 1.06))
	_mi(part_helmet, _box(0.21, 0.025, 0.05), m_helm, Vector3(0, 0.135, 0.1), Vector3.ZERO, Vector3.ONE, false)
	_mi(part_helmet, _box(0.15, 0.036, 0.02), m_dark, Vector3(0, 0.1, 0.112), Vector3.ZERO, Vector3.ONE, false)
	_mi(part_helmet, _box(0.2, 0.1, 0.06), m_helm, Vector3(0, 0.085, -0.085), Vector3(0.25, 0, 0), Vector3.ONE, false)
	_mi(part_helmet, _box(0.17, 0.08, 0.05), m_gear, Vector3(0, 0.02, -0.07), Vector3.ZERO, Vector3.ONE, false)
	_mi(part_helmet, _box(0.04, 0.07, 0.075), m_gear, Vector3(0.112, 0.09, 0), Vector3.ZERO, Vector3.ONE, false)
	_mi(part_helmet, _box(0.04, 0.07, 0.075), m_gear, Vector3(-0.112, 0.09, 0), Vector3.ZERO, Vector3.ONE, false)

	for i in 2:
		var ua := Node3D.new()
		spine.add_child(ua)
		_mi(ua, _cap(0.056, LEN_UPPER + 0.1), m_top, Vector3.ZERO)
		var fa := Node3D.new()
		spine.add_child(fa)
		_mi(fa, _cap(0.047, LEN_FORE + 0.08), m_top, Vector3.ZERO)
		var hd := Node3D.new()
		spine.add_child(hd)
		_mi(hd, _box(0.065, 0.095, 0.09), m_glove, Vector3(0, -0.01, 0.0))
		upper_arms.append(ua)
		fore_arms.append(fa)
		hands.append(hd)

	gun = Node3D.new()
	spine.add_child(gun)
	_mi(gun, _box(0.06, 0.09, 0.4), m_gun, Vector3(0, 0.045, 0.07))
	_mi(gun, _box(0.066, 0.07, 0.22), m_gun, Vector3(0, 0.04, 0.33))
	_mi(gun, _cyl(0.014, 0.2), m_dark, Vector3(0, 0.045, 0.53), Vector3(PI * 0.5, 0, 0), Vector3.ONE, false)
	_mi(gun, _box(0.05, 0.1, 0.2), m_gun, Vector3(0, 0.02, -0.19))
	_mi(gun, _box(0.048, 0.15, 0.07), m_dark, Vector3(0, -0.07, 0.13), Vector3(-0.2, 0, 0), Vector3.ONE, false)
	_mi(gun, _box(0.04, 0.11, 0.05), m_dark, Vector3(0, -0.05, -0.005), Vector3(0.35, 0, 0), Vector3.ONE, false)
	_mi(gun, _box(0.045, 0.05, 0.12), m_dark, Vector3(0, 0.12, 0.05), Vector3.ZERO, Vector3.ONE, false)
	grip_r = _marker(gun, Vector3(0, -0.04, 0.0))
	grip_l = _marker(gun, Vector3(0, 0.0, 0.31))
	mag_pt = _marker(gun, Vector3(0, -0.13, 0.13))
	muzzle = _marker(gun, Vector3(0, 0.045, 0.64))
	pose(1.0, 0.0, 0.0, 0.0, 0.0, false, -1.0, false, false, -1.0)


func _marker(parent: Node3D, p: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = p
	parent.add_child(n)
	return n


func set_flash(f: float) -> void:
	var c := Color(0.45, 0.32, 0.16) * clampf(f / 0.12, 0.0, 1.0)
	for m in mats:
		m.emission = c


static func _ease(cur: float, target: float, lam: float, dt: float) -> float:
	return lerpf(cur, target, 1.0 - exp(-lam * dt))


## Procedural pose. slide_side: +1 = slide toward the soldier's right, -1 = left.
func pose(dt: float, spd: float, bob: float, slide_mix: float, slide_side: float, crouch: bool, vault_u: float, aiming: bool, down: bool, reload_u: float) -> void:
	k_crouch = _ease(k_crouch, 1.0 if crouch else 0.0, 10.0, dt)
	k_aim = _ease(k_aim, 1.0 if aiming else 0.0, 14.0, dt)
	k_slide = _ease(k_slide, slide_mix, 16.0, dt)
	k_side = _ease(k_side, slide_side, 12.0, dt)
	k_down = _ease(k_down, 1.0 if down else 0.0, 5.0, dt)
	k_run = _ease(k_run, clampf(spd / 6.0, 0.0, 1.0), 10.0, dt)

	var stand := (1.0 - k_slide) * (1.0 - k_down)
	var run := k_run * stand
	var ph := bob
	var s := sin(ph)
	var c := cos(ph)
	var stride := 0.8 - 0.35 * k_crouch
	var tl := -s * stride * run
	var tr := s * stride * run
	var kl := run * (0.18 + 1.05 * maxf(0.0, c))
	var kr := run * (0.18 + 1.05 * maxf(0.0, -c))
	var hy := HIP_Y - absf(c) * 0.045 * run
	var spx := 0.13 * run
	var body_rz := 0.0
	var spz := 0.0

	# Crouch.
	var kc := k_crouch * stand
	tl += -1.1 * kc
	tr += -1.1 * kc
	kl += 1.75 * kc
	kr += 1.75 * kc
	hy -= 0.39 * kc
	spx += 0.2 * kc

	# Slides: knee slide (forward) blended with side/hip slide.
	if k_slide > 0.001:
		var m := clampf(absf(k_side), 0.0, 1.0)
		var sg := signf(k_side) if absf(k_side) > 0.001 else 0.0
		var knee := [0.35, 1.22, -1.5, 0.9, 0.43, -0.3, 0.0]
		var side := [-1.25, 0.25, -1.05, 0.45, 0.34, -0.12, sg * 1.0]
		var sp: Array[float] = []
		for i in 7:
			sp.append(lerpf(float(knee[i]), float(side[i]), m))
		var k := k_slide
		tl = lerpf(tl, sp[0], k)
		kl = lerpf(kl, sp[1], k)
		tr = lerpf(tr, sp[2], k)
		kr = lerpf(kr, sp[3], k)
		hy = lerpf(hy, sp[4], k)
		spx = lerpf(spx, sp[5], k)
		body_rz = sp[6] * k
		spz = -body_rz * 0.45

	# Vault tuck.
	if vault_u >= 0.0:
		var vu := sin(clampf(vault_u, 0.0, 1.0) * PI)
		tl -= 1.2 * vu
		tr -= 0.9 * vu
		kl += 1.6 * vu
		kr += 1.3 * vu
		body_rz += 0.32 * vu
		spx += 0.25 * vu

	# Downed.
	tl = lerpf(tl, -0.15, k_down)
	tr = lerpf(tr, 0.1, k_down)
	kl = lerpf(kl, 0.3, k_down)
	kr = lerpf(kr, 0.15, k_down)
	body.rotation = Vector3(-1.45 * k_down, 0, body_rz)
	body.position = Vector3(0, 0.1 * k_down, 0)

	hips.position.y = hy
	thighs[0].rotation = Vector3(tl, 0, 0.03)
	thighs[1].rotation = Vector3(tr, 0, -0.03)
	knees[0].rotation = Vector3(kl, 0, 0)
	knees[1].rotation = Vector3(kr, 0, 0)
	feet[0].rotation = Vector3(-tl - kl, 0, 0) * 0.6
	feet[1].rotation = Vector3(-tr - kr, 0, 0) * 0.6

	var twist := AIM_TWIST * k_aim
	spine.rotation = Vector3(spx, twist, spz)
	head.rotation = Vector3(-spx * 0.7, -twist * 0.9, -spz * 0.5)

	# Gun: low ready <-> shouldered.
	var gp := GUN_READY_POS.lerp(GUN_AIM_POS, k_aim)
	var gr := GUN_READY_ROT.lerp(Vector3(-spx, -twist, 0), k_aim)
	gp.y += sin(ph * 2.0) * 0.012 * run
	var reload_k := 0.0
	if reload_u >= 0.0:
		reload_k = sin(clampf(reload_u, 0.0, 1.0) * PI)
		gr += Vector3(0.25, 0.2, 0.55) * reload_k
		gp += Vector3(0.03, -0.04, -0.02) * reload_k
	gun.position = gp
	gun.rotation = gr

	var gt := gun.transform
	var tgt_r := gt * grip_r.position
	var tgt_l := gt * grip_l.position
	if reload_u >= 0.0:
		var mag := gt * mag_pt.position
		var u := clampf(reload_u, 0.0, 1.0)
		var away := mag + Vector3(0.06, -0.16, -0.02)
		if u < 0.3:
			tgt_l = tgt_l.lerp(mag, u / 0.3)
		elif u < 0.55:
			tgt_l = mag.lerp(away, (u - 0.3) / 0.25)
		elif u < 0.8:
			tgt_l = away.lerp(mag, (u - 0.55) / 0.25)
		else:
			tgt_l = mag.lerp(tgt_l, (u - 0.8) / 0.2)
	_ik(1, SHOULDER_R, tgt_r, SHOULDER_R + Vector3(-0.32, -0.34, -0.12), gt.basis)
	_ik(0, SHOULDER_L, tgt_l, SHOULDER_L + Vector3(0.22, -0.4, 0.02), gt.basis)


## Two-bone IK in spine space. Places the segment nodes between joints.
func _ik(i: int, s: Vector3, target: Vector3, pole: Vector3, hand_basis: Basis) -> void:
	var lu := LEN_UPPER
	var ll := LEN_FORE
	var d := target - s
	var dist := clampf(d.length(), 0.06, lu + ll - 0.002)
	var dir := d.normalized() if d.length() > 0.0001 else Vector3.FORWARD
	var ca := clampf((lu * lu + dist * dist - ll * ll) / (2.0 * lu * dist), -1.0, 1.0)
	var pd := pole - s
	pd = pd - dir * pd.dot(dir)
	if pd.length() < 0.0001:
		pd = Vector3.DOWN
	pd = pd.normalized()
	var elbow := s + dir * (lu * ca) + pd * (lu * sqrt(maxf(0.0, 1.0 - ca * ca)))
	var hand_pos := s + dir * dist
	_place(upper_arms[i], s, elbow)
	_place(fore_arms[i], elbow, hand_pos)
	hands[i].transform = Transform3D(hand_basis, hand_pos)


static func _place(n: Node3D, a: Vector3, b: Vector3) -> void:
	var y := b - a
	var l := y.length()
	if l < 0.0001:
		return
	y /= l
	var x := y.cross(Vector3.BACK)
	if x.length() < 0.05:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y)
	n.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
