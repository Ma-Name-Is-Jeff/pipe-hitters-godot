class_name Soldier
extends Node3D
## Original low-poly tactical soldier built from primitives.
## Faces +Z. Index 0 = left side (+X), index 1 = right side (-X, trigger hand).

const HIP_Y := 0.97
const LEN_THIGH := 0.44
const LEN_SHIN := 0.40
const LEN_UPPER := 0.33
const LEN_FORE := 0.31
const SHOULDER_L := Vector3(0.25, 0.46, 0.02)
const SHOULDER_R := Vector3(-0.25, 0.46, -0.02)
const GUN_AIM_POS := Vector3(-0.13, 0.43, 0.34)
const GUN_READY_POS := Vector3(-0.08, 0.29, 0.31)
const GUN_READY_ROT := Vector3(0.5, 0.42, 0.18)
const AIM_TWIST := -0.3

static var _meshes := {}
## Shared procedural-animation tuning (Anim tab). Set from main.gd via set_anim().
static var anim := {"bob": 6.0, "lean": 12.0, "twist": 90.0, "cadence": 4.5, "knee": 1.5, "sway": 1.0, "kick": 1.0}
const LEG_LEN := 0.92
const BODY_H := 1.9
## Run speed that the cadence slider refers to (locked walk speed).
const RUN_REF := 6.3


static func set_anim(d: Dictionary) -> void:
	for k in anim.keys():
		var sk: String = "anim_" + k
		if d.has(sk):
			anim[k] = float(d[sk])

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
var base_emission := Color(0, 0, 0)
var glow_mats: Array[StandardMaterial3D] = []

var k_crouch := 0.0
var k_aim := 0.0
var k_slide := 0.0
var k_side := 0.0
var k_down := 0.0
var k_run := 0.0
## v1g locomotion state.
var gait_phase := 0.0       ## radians; one step = PI, advanced by distance traveled
var dist_total := 0.0
var hip_yaw := 0.0          ## pelvis yaw relative to aim (root), clamped to the twist limit
var hip_world := 0.0
var _prev_pos := Vector3.ZERO
var _have_prev := false
var vel_s := Vector3.ZERO   ## smoothed world velocity
var acc_s := Vector3.ZERO
var lean_v := Vector2.ZERO  ## spring state (x = forward, y = side)
var lean_d := Vector2.ZERO
var gait_dir := Vector2(0, 1)  ## leg swing direction in pelvis space (x = side, y = fwd)
var breath_t := 0.0
var gun_bob_lag := 0.0
var kick_x := 0.0
var kick_v := 0.0
var last_twist := 0.0       ## spine-vs-pelvis twist (for tests)
var step_len := LEG_LEN


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
	m.emission = base_emission
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


## face: balaclava color. visor: eye-protection glow color (black = no glow).
func setup(top: Color, bottom: Color, vest: Color, helmet: Color, gear: Color, skin: Color, gun_col: Color, face := Color(0.09, 0.09, 0.1), visor := Color(0, 0, 0), emission := Color(0, 0, 0)) -> void:
	base_emission = emission
	var m_top := _mat(top)
	m_top.albedo_color = Color.WHITE
	m_top.albedo_texture = camo_texture(top)
	m_top.uv1_scale = Vector3(2, 2, 1)
	var m_bot := _mat(bottom)
	m_bot.albedo_color = Color.WHITE
	m_bot.albedo_texture = camo_texture(bottom)
	m_bot.uv1_scale = Vector3(2, 3, 1)
	var m_face := _mat(face, 0.95)
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
	_mi(part_bottom, _box(0.42, 0.24, 0.27), m_bot, Vector3.ZERO)
	_mi(part_bottom, _box(0.45, 0.06, 0.29), m_gear, Vector3(0, 0.11, 0), Vector3.ZERO, Vector3.ONE, false)
	_mi(part_bottom, _box(0.12, 0.1, 0.08), m_gear, Vector3(0.17, 0.02, -0.14), Vector3.ZERO, Vector3.ONE, false)
	for i in 2:
		var sx := 0.125 if i == 0 else -0.125
		var th := Node3D.new()
		th.position = Vector3(sx, -0.05, 0)
		hips.add_child(th)
		_mi(th, _cap(0.118, LEN_THIGH + 0.14), m_bot, Vector3(0, -LEN_THIGH * 0.5, 0))
		var hs := 1.0 if i == 0 else -1.0
		_mi(th, _box(0.07, 0.15, 0.14), m_gear, Vector3(hs * 0.12, -0.16, 0), Vector3.ZERO, Vector3.ONE, false)
		var kn := Node3D.new()
		kn.position = Vector3(0, -LEN_THIGH, 0)
		th.add_child(kn)
		_mi(kn, _box(0.15, 0.14, 0.07), m_gear, Vector3(0, -0.01, 0.1), Vector3.ZERO, Vector3.ONE, false)
		_mi(kn, _cap(0.1, LEN_SHIN + 0.08), m_bot, Vector3(0, -LEN_SHIN * 0.5, 0))
		var ft := Node3D.new()
		ft.position = Vector3(0, -LEN_SHIN, 0)
		kn.add_child(ft)
		_mi(ft, _box(0.16, 0.13, 0.32), m_boot, Vector3(0, -0.035, 0.06))
		thighs.append(th)
		knees.append(kn)
		feet.append(ft)

	spine = Node3D.new()
	spine.position = Vector3(0, 0.07, 0)
	hips.add_child(spine)
	part_top = Node3D.new()
	spine.add_child(part_top)
	# Chunky action-figure torso: boxy plate carrier with pouches and broad shoulders.
	_mi(part_top, _cap(0.17, 0.54), m_top, Vector3(0, 0.25, 0), Vector3.ZERO, Vector3(1.45, 1.0, 0.95))
	_mi(part_top, _box(0.54, 0.36, 0.36), m_vest, Vector3(0, 0.31, 0.005))
	_mi(part_top, _box(0.56, 0.07, 0.38), m_gear, Vector3(0, 0.14, 0.005), Vector3.ZERO, Vector3.ONE, false)
	for px in [-0.16, 0.0, 0.16]:
		_mi(part_top, _box(0.11, 0.17, 0.08), m_gear, Vector3(px, 0.25, 0.215), Vector3.ZERO, Vector3.ONE, false)
		_mi(part_top, _box(0.113, 0.035, 0.085), m_dark, Vector3(px, 0.345, 0.215), Vector3.ZERO, Vector3.ONE, false)
	for sx2 in [-0.29, 0.29]:
		_mi(part_top, _box(0.06, 0.18, 0.2), m_gear, Vector3(sx2, 0.27, 0.0), Vector3.ZERO, Vector3.ONE, false)
	_mi(part_top, _box(0.4, 0.3, 0.13), m_gear, Vector3(0, 0.32, -0.24), Vector3.ZERO, Vector3.ONE, false)
	_mi(part_top, _sph(0.115), m_top, SHOULDER_L, Vector3.ZERO, Vector3(1.15, 0.9, 1.0))
	_mi(part_top, _sph(0.115), m_top, SHOULDER_R, Vector3.ZERO, Vector3(1.15, 0.9, 1.0))
	_mi(part_top, _box(0.16, 0.05, 0.2), m_vest, SHOULDER_L + Vector3(0, 0.08, 0), Vector3.ZERO, Vector3.ONE, false)
	_mi(part_top, _box(0.16, 0.05, 0.2), m_vest, SHOULDER_R + Vector3(0, 0.08, 0), Vector3.ZERO, Vector3.ONE, false)

	neck = Node3D.new()
	neck.position = Vector3(0, 0.49, 0)
	spine.add_child(neck)
	_mi(neck, _cap(0.07, 0.13), m_face, Vector3(0, 0.03, 0))
	head = Node3D.new()
	head.position = Vector3(0, 0.07, 0)
	neck.add_child(head)
	_mi(head, _sph(0.13), m_face, Vector3(0, 0.11, 0.015), Vector3.ZERO, Vector3(0.92, 1.08, 1.0))
	_mi(head, _box(0.16, 0.04, 0.04), m_skin, Vector3(0, 0.15, 0.13), Vector3.ZERO, Vector3.ONE, false)
	part_helmet = Node3D.new()
	# Larger helmet: scale the whole helmet group up around the head.
	part_helmet.scale = Vector3.ONE * 1.32
	part_helmet.position = Vector3(0, -0.035, 0.0)
	head.add_child(part_helmet)
	_mi(part_helmet, _sph(0.122), m_helm, Vector3(0, 0.15, -0.005), Vector3.ZERO, Vector3(1.0, 0.8, 1.06))
	_mi(part_helmet, _box(0.21, 0.025, 0.05), m_helm, Vector3(0, 0.135, 0.1), Vector3.ZERO, Vector3.ONE, false)
	var m_visor := m_dark
	if visor.v > 0.01:
		m_visor = _mat(Color(0.05, 0.05, 0.05), 0.3)
		m_visor.emission = visor
		m_visor.emission_energy_multiplier = 2.2
		glow_mats.append(m_visor)
	_mi(part_helmet, _box(0.15, 0.036, 0.02), m_visor, Vector3(0, 0.122, 0.118), Vector3.ZERO, Vector3.ONE, false)
	# High-cut shroud + flipped-up night-vision tubes.
	_mi(part_helmet, _box(0.06, 0.04, 0.03), m_dark, Vector3(0, 0.19, 0.115), Vector3.ZERO, Vector3.ONE, false)
	_mi(part_helmet, _cyl(0.017, 0.07), m_dark, Vector3(0.026, 0.225, 0.118), Vector3(-0.5, 0, 0), Vector3.ONE, false)
	_mi(part_helmet, _cyl(0.017, 0.07), m_dark, Vector3(-0.026, 0.225, 0.118), Vector3(-0.5, 0, 0), Vector3.ONE, false)
	_mi(part_helmet, _box(0.05, 0.012, 0.16), m_gear, Vector3(0.09, 0.2, 0), Vector3(0, 0, -0.5), Vector3.ONE, false)
	_mi(part_helmet, _box(0.05, 0.012, 0.16), m_gear, Vector3(-0.09, 0.2, 0), Vector3(0, 0, 0.5), Vector3.ONE, false)
	_mi(part_helmet, _box(0.2, 0.1, 0.06), m_helm, Vector3(0, 0.085, -0.085), Vector3(0.25, 0, 0), Vector3.ONE, false)
	_mi(part_helmet, _box(0.17, 0.08, 0.05), m_gear, Vector3(0, 0.02, -0.07), Vector3.ZERO, Vector3.ONE, false)
	_mi(part_helmet, _box(0.04, 0.07, 0.075), m_gear, Vector3(0.112, 0.09, 0), Vector3.ZERO, Vector3.ONE, false)
	_mi(part_helmet, _box(0.04, 0.07, 0.075), m_gear, Vector3(-0.112, 0.09, 0), Vector3.ZERO, Vector3.ONE, false)

	for i in 2:
		var ua := Node3D.new()
		spine.add_child(ua)
		_mi(ua, _cap(0.085, LEN_UPPER + 0.12), m_top, Vector3.ZERO)
		var fa := Node3D.new()
		spine.add_child(fa)
		_mi(fa, _cap(0.072, LEN_FORE + 0.09), m_top, Vector3.ZERO)
		_mi(fa, _box(0.1, 0.12, 0.1), m_gear, Vector3(0, -0.04, 0), Vector3.ZERO, Vector3.ONE, false)
		var hd := Node3D.new()
		spine.add_child(hd)
		_mi(hd, _box(0.09, 0.12, 0.11), m_glove, Vector3(0, -0.01, 0.0))
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


func set_flash(f: float, red: float = 0.0) -> void:
	var k := clampf(f / 0.12, 0.0, 1.0)
	var c := base_emission + Color(0.45, 0.32, 0.16) * k * (1.0 - red) + Color(1.5, 0.06, 0.04) * k * red
	for m in mats:
		if not glow_mats.has(m):
			m.emission = c


static var _camo := {}


## Procedural blotch camo in shades of the base color (cached per color).
static func camo_texture(base: Color) -> ImageTexture:
	var key := base.to_html()
	if _camo.has(key):
		return _camo[key]
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	img.fill(base)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var shades := [base.darkened(0.35), base.lightened(0.12), base.darkened(0.15)]
	for i in 46:
		var c: Color = shades[i % 3]
		var cx := rng.randi_range(0, s - 1)
		var cy := rng.randi_range(0, s - 1)
		var rx := rng.randi_range(3, 8)
		var ry := rng.randi_range(2, 5)
		for y in range(-ry, ry + 1):
			for x in range(-rx, rx + 1):
				if float(x * x) / (rx * rx) + float(y * y) / (ry * ry) <= 1.0:
					img.set_pixel(posmod(cx + x, s), posmod(cy + y, s), c)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_camo[key] = t
	return t


static func _ease(cur: float, target: float, lam: float, dt: float) -> float:
	return lerpf(cur, target, 1.0 - exp(-lam * dt))


## Fire kick: sharp push back along the rifle's local axis that springs back.
func kick(amount := 1.0) -> void:
	kick_v -= 1.7 * amount * float(anim["kick"])


func _root_pos() -> Vector3:
	return global_position if is_inside_tree() else position


func _root_yaw() -> float:
	return global_rotation.y if is_inside_tree() else rotation.y


## Step length (m) for a flat speed. Cadence (steps/s) is the slider value at RUN_REF
## and rises gently with speed; below that steps shorten toward a leg length.
func step_length_for(v: float) -> float:
	var cad: float = maxf(0.5, float(anim["cadence"]))
	var cad_v := cad * sqrt(clampf(v, 0.05, 30.0) / RUN_REF)
	var floor_l := LEG_LEN * (0.75 - 0.3 * k_crouch)
	return maxf(floor_l, v / cad_v)


## Velocity-driven locomotion: distance-driven gait phase, pelvis yaw vs aim, lean spring.
func _locomotion(dt: float, spd: float, stand: float) -> void:
	var now := _root_pos()
	var dpos := Vector3.ZERO
	if _have_prev:
		dpos = now - _prev_pos
		dpos.y = 0.0
		if dpos.length() > 3.0:
			dpos = Vector3.ZERO  # teleport / respawn
	_prev_pos = now
	_have_prev = true
	var vel := Vector3.ZERO
	if spd > 0.05 and dpos.length() > 1e-5 and k_down < 0.5:
		vel = dpos.normalized() * spd
	var dist := 0.0 if vel == Vector3.ZERO else dpos.length()
	var v := vel.length()
	step_len = step_length_for(maxf(v, 0.01))
	# One step = PI. Phase advances only with distance -> feet stay planted.
	gait_phase = fmod(gait_phase + PI * dist / step_len, TAU * 64.0)
	dist_total += dist

	var root_yaw := _root_yaw()
	var to_local := Basis(Vector3.UP, -root_yaw)
	var lv := to_local * vel
	var prev_v := vel_s
	vel_s = vel_s.lerp(vel, 1.0 - exp(-25.0 * dt))
	if dt > 1e-4:
		acc_s = acc_s.lerp((vel_s - prev_v) / dt, 1.0 - exp(-12.0 * dt))
	var la := to_local * acc_s

	# Gait choice from velocity-vs-aim dot (fwd) and cross (side).
	var clampr := deg_to_rad(float(anim["twist"]))
	var target_rel := 0.0
	var a := 0.0
	if v > 0.3:
		var vd := Vector2(lv.x, lv.z).normalized()
		var fwd := vd.y
		var side := vd.x
		a = atan2(side, fwd)
		if fwd < -0.25:
			_back = true
		elif fwd > 0.05:
			_back = false
		var rel := _wrap(a - PI) if _back else a
		# Strafe zone: the pelvis turns part-way; a sideways leg cycle covers the rest.
		target_rel = rel * lerpf(1.0, 0.55, absf(side))
	target_rel = clampf(target_rel, -clampr, clampr)
	var lam := 12.0 if v > 0.3 else 7.0
	hip_world = root_yaw + _wrap(hip_world - root_yaw)
	hip_world = lerpf(hip_world, root_yaw + target_rel, 1.0 - exp(-lam * dt))
	var r2 := clampf(_wrap(hip_world - root_yaw), -clampr, clampr)
	hip_world = root_yaw + r2
	hip_yaw = r2 * stand
	if v > 0.3:
		var g := a - hip_yaw
		var gd := Vector2(sin(g), cos(g))
		gait_dir = gait_dir.lerp(gd, 1.0 - exp(-14.0 * dt))

	# Lean spring toward velocity + acceleration (eases in/out).
	var lmax := deg_to_rad(float(anim["lean"]))
	var lt := Vector2(lv.z, lv.x) / RUN_REF * 0.85 + Vector2(la.z, la.x) / 60.0
	if lt.length() > 1.0:
		lt = lt.normalized()
	lt *= lmax
	var steps := maxi(1, int(ceil(dt / 0.008)))
	var h := dt / float(steps)
	for _i in steps:
		lean_d += (120.0 * (lt - lean_v) - 15.0 * lean_d) * h
		lean_v += lean_d * h
		kick_v += (-420.0 * kick_x - 26.0 * kick_v) * h
		kick_x += kick_v * h


## One leg's cycle at normalized phase u (0..1, stance first half).
## Returns Vector3(foot fore-aft offset, knee bend, extra thigh lift).
static func _leg_cycle(u: float, sweep: float, leg_l: float, knee_k: float) -> Vector3:
	u = fposmod(u, 1.0)
	var half := sweep * 0.5
	if u < 0.5:
		var w := u / 0.5
		return Vector3(lerpf(half, -half, w), 0.0, 0.0)
	var t := (u - 0.5) / 0.5
	var t2 := t * t
	var t3 := t2 * t
	var m := -sweep  # match stance foot speed at lift-off / touch-down
	var x := (2.0 * t3 - 3.0 * t2 + 1.0) * -half + (t3 - 2.0 * t2 + t) * m + (-2.0 * t3 + 3.0 * t2) * half + (t3 - t2) * m
	var lift := sin(t * PI)
	return Vector3(x, 0.9 * knee_k * lift, 0.3 * knee_k * lift)


static func _wrap(x: float) -> float:
	return wrapf(x, -PI, PI)


var _back := false


## Procedural pose. slide_side: +1 = slide toward the soldier's right, -1 = left.
## `bob` is ignored since v1g (gait phase comes from distance traveled).
func pose(dt: float, spd: float, bob: float, slide_mix: float, slide_side: float, crouch: bool, vault_u: float, aiming: bool, down: bool, reload_u: float) -> void:
	k_crouch = _ease(k_crouch, 1.0 if crouch else 0.0, 10.0, dt)
	k_aim = _ease(k_aim, 1.0 if aiming else 0.0, 14.0, dt)
	k_slide = _ease(k_slide, slide_mix, 16.0, dt)
	k_side = _ease(k_side, slide_side, 12.0, dt)
	k_down = _ease(k_down, 1.0 if down else 0.0, 5.0, dt)
	# Start/stop blend ~0.12s.
	k_run = _ease(k_run, clampf(spd / 4.0, 0.0, 1.0) if spd > 0.05 else 0.0, 22.0, dt)

	var vk := sin(clampf(vault_u, 0.0, 1.0) * PI) if vault_u >= 0.0 else 0.0
	var stand := (1.0 - k_slide) * (1.0 - k_down) * (1.0 - vk)
	_locomotion(dt, 0.0 if down else spd, stand)
	breath_t += dt
	var run := k_run * stand
	var ph := gait_phase
	var s := sin(ph)
	var c := cos(ph)
	var knee_k: float = float(anim["knee"])
	# Per-leg cycle: stance sweeps the foot back linearly (exact plant: one step of body
	# travel per stance), swing brings it forward on a Hermite curve with a high knee.
	var sweep := step_len * (1.0 - 0.4 * k_crouch)
	var leg_l := LEN_THIGH + LEN_SHIN
	var ll := _leg_cycle(ph / TAU, sweep, leg_l, knee_k)
	var lr := _leg_cycle(ph / TAU + 0.5, sweep, leg_l, knee_k)
	var gd := gait_dir
	var tl: float = -asin(clampf(ll.x * gd.y / leg_l, -0.95, 0.95)) * run - ll.z * run
	var tr: float = -asin(clampf(lr.x * gd.y / leg_l, -0.95, 0.95)) * run - lr.z * run
	var zl := maxf(asin(clampf(ll.x * gd.x / leg_l, -0.95, 0.95)) * run, -0.12) + 0.03
	var zr := minf(asin(clampf(lr.x * gd.x / leg_l, -0.95, 0.95)) * run, 0.12) - 0.03
	var kl: float = run * 0.12 + ll.y * run
	var kr: float = run * 0.12 + lr.y * run
	var bob_amp := float(anim["bob"]) / 100.0 * BODY_H * run
	var bob_off := -bob_amp * c * c   # low twice per cycle (legs spread), high at passing
	var hy := HIP_Y + bob_off
	var shift_x := 0.04 * s * run
	var spx := 0.1 * run
	var body_rz := 0.0
	var spz := 0.0

	# Crouch.
	var kc := k_crouch * (1.0 - k_slide) * (1.0 - k_down)
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
		zl = lerpf(zl, 0.03, k)
		zr = lerpf(zr, -0.03, k)
		body_rz = sp[6] * k
		spz = -body_rz * 0.45

	# Vault tuck.
	if vault_u >= 0.0:
		tl -= 1.2 * vk
		tr -= 0.9 * vk
		kl += 1.6 * vk
		kr += 1.3 * vk
		body_rz += 0.32 * vk
		spx += 0.25 * vk

	# Downed.
	tl = lerpf(tl, -0.15, k_down)
	tr = lerpf(tr, 0.1, k_down)
	kl = lerpf(kl, 0.3, k_down)
	kr = lerpf(kr, 0.15, k_down)
	var lean_k := (1.0 - k_slide) * (1.0 - k_down)
	body.rotation = Vector3(-1.45 * k_down + lean_v.x * lean_k, 0, body_rz - lean_v.y * lean_k)
	body.position = Vector3(0, 0.1 * k_down, 0)

	hips.position = Vector3(shift_x, hy, 0)
	hips.rotation = Vector3(0, hip_yaw, 0.05 * s * run)
	thighs[0].rotation = Vector3(tl, 0, zl)
	thighs[1].rotation = Vector3(tr, 0, zr)
	knees[0].rotation = Vector3(kl, 0, 0)
	knees[1].rotation = Vector3(kr, 0, 0)
	feet[0].rotation = Vector3(-tl - kl, 0, 0) * 0.6
	feet[1].rotation = Vector3(-tr - kr, 0, 0) * 0.6

	# Turret spine: pelvis follows velocity, chest/head/rifle follow aim.
	var twist := AIM_TWIST * k_aim
	last_twist = hip_yaw
	var idle := (1.0 - k_run) * stand
	var br := sin(breath_t * 1.6) * idle
	spine.position = Vector3(-shift_x * 0.5, 0.07 + 0.007 * br, 0)
	spine.rotation = Vector3(spx, twist - hip_yaw, spz - 0.05 * s * run)
	part_top.scale = Vector3(1.0 + 0.012 * br, 1.0 + 0.01 * br, 1.0 + 0.018 * br)
	head.rotation = Vector3(-spx * 0.7, -twist * 0.9, -spz * 0.5)

	# Gun: low ready <-> shouldered, lagged bob + kick spring.
	var gp := GUN_READY_POS.lerp(GUN_AIM_POS, k_aim)
	var gr := GUN_READY_ROT.lerp(Vector3(-spx, -twist, 0), k_aim)
	var sway: float = float(anim["sway"])
	gun_bob_lag = _ease(gun_bob_lag, bob_off, 10.0, dt)
	gp.y += (gun_bob_lag - bob_off) * sway
	gp.x += -shift_x * 0.3 * sway
	gp.y += 0.004 * br
	var reload_k := 0.0
	if reload_u >= 0.0:
		reload_k = sin(clampf(reload_u, 0.0, 1.0) * PI)
		gr += Vector3(0.25, 0.2, 0.55) * reload_k
		gp += Vector3(0.03, -0.04, -0.02) * reload_k
	gr.x += kick_x * 2.2
	gun.rotation = gr
	gun.position = gp + gun.basis.z * kick_x

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
	# Elbows flare out a little when aiming (chunky T from above).
	_ik(1, SHOULDER_R, tgt_r, SHOULDER_R + Vector3(-0.32, -0.34, -0.12).lerp(Vector3(-0.55, -0.12, -0.08), k_aim), gt.basis)
	_ik(0, SHOULDER_L, tgt_l, SHOULDER_L + Vector3(0.22, -0.4, 0.02).lerp(Vector3(0.5, -0.18, 0.06), k_aim), gt.basis)


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
