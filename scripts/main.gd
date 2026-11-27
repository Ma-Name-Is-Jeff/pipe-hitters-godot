extends Node3D
## Pipe Hitters: twin-stick compound run. Everything is built in code.

const RADIUS := 0.36
const VAULT_MAX := 1.15
const VAULT_MIN := 0.32
const AIM_DEAD := 0.16
const AIM_RANGE := 22.0
const START := Vector3(0, 0, 87.5)
const START_YAW := PI
const ARENA_START := Vector3(0, 0, 15)
const RESPAWN_S := 2.5
const VERSION := TuneDefs.VERSION
const EXTRACT := Vector3(0, 0, -88)
const EXTRACT_R := 4.6
const BOT_NAMES := ["Pike", "Rook", "Vance", "Moss", "Dray", "Tull", "Kerr", "Voss", "Hale", "Brandt"]
const BODY_LEN := 1.8
const TRACER_LEN := 2.6
const VIEW_PITCH_MIN := -0.3141593
const VIEW_PITCH_MAX := 0.2094395
const STICK_HIT := 120.0
const SETTINGS_PATH := "user://settings.cfg"
const WEAPONS := [
	{"name": "Line Carbine", "short": "CARBINE", "mag": 30, "reserve": 180, "max_reserve": 240, "fire_ms": 95, "reload": 1.45, "pellets": 1, "spread": 0.005, "range": 80.0, "burst": 3, "burst_gap": 0.34},
	{"name": "Hall Sweeper", "short": "SWEEPER", "mag": 6, "reserve": 36, "max_reserve": 60, "fire_ms": 520, "reload": 1.85, "pellets": 6, "spread": 0.09, "range": 11.0, "burst": 1, "burst_gap": 0.0},
]


class Bot:
	var node: Soldier
	var home := Vector2.ZERO
	var facing := 0.0
	var hp := 4
	var max_hp := 4
	var state := "patrol"
	var t := 0.0
	var flash := 0.0
	var shoot_cd := 0.0
	var crouch := false
	var alert := 0.0
	var last_seen := Vector2.ZERO
	var waypoints: Array[Vector2] = []
	var wp := 0
	var spd := 0.0
	var bob := 0.0
	var prev := Vector2.ZERO
	var bar_bg: MeshInstance3D
	var bar_fill: MeshInstance3D
	var label := "Rook"


class Mate:
	var node: Soldier
	var offset := Vector2.ZERO
	var shoot_cd := 0.0
	var scan := 0.0
	var target: Bot = null
	var crouch := false
	var spd := 0.0
	var bob := 0.0
	var prev := Vector2.ZERO


class Pickup:
	var node: Node3D
	var pos := Vector2.ZERO
	var carbine := 0
	var sweeper := 0
	var respawn := 0.0
	var wait := 0.0
	var live := true
	var drop := false
	var bob := 0.0


var settings := {"invert_move": false, "landscape": false, "fullscreen": false, "aim_sens": 70.0, "assist": 70.0, "volume": 70.0, "facing": "follow", "zoom": 0.0, "preset": "snappy", "tune_ver": "v1b"}

var level: Level
var arena_level: Level
var compound_root: Node3D
var arena_root: Node3D
var arena_mode := false
var compound_bots: Array[Bot] = []
var arena_bots: Array[Bot] = []
var tune_open := false
var _save_wait := -1.0
var obstacles: Array[Obstacle] = []
var bots: Array[Bot] = []
var pickups: Array[Pickup] = []
var soldier: Soldier
var camera: Camera3D
var sun: DirectionalLight3D
var fill_light: OmniLight3D
var mates: Array[Mate] = []
var ui: GameUI
var synth: Synth

# Player state.
var pos := START
var vel := Vector3.ZERO
var yaw := START_YAW
var prev_yaw := START_YAW
var stance := "stand"
var slide_t := 0.0
var slide_side := 0.0
var slide_mix := 0.0
var vault := {}
var crouch := false
var in_cover := false
var cover_dr := 1.0
var hp := 100.0
var max_hp := 100.0
var last_hit := -99.0
var wep := 0
var mag := 30
var reserve := 180
var guns: Array = []
var reload_t := 0.0
var last_shot := -9999.0
var burst_count := 0
var burst_wait := 0.0
var recently_shot := 0.0
var bob := 0.0
var aim_bloom := 0.0
var assist_target: Bot = null
var sticky_assist: Bot = null
var aim_point := Vector3.ZERO

# Game flow.
var playing := false
var paused := false
var mission_over := false
var stats := {"kills": 0, "shots": 0, "hits": 0, "start": 0.0}

# Camera.
var view_yaw := 0.0
var view_pitch := 0.0
var zoom_show := 0.0
var cam_pos := Vector3.ZERO
var kick_p := 0.0

# Input.
var touch_mode := false
var mouse_pos := Vector2.ZERO
var mouse_down := false
var mouse_seen := false
var move_id := -1
var move_v := Vector2.ZERO
var aim_id := -1
var aim_v := Vector2.ZERO
var aim_mag := 0.0
var look_id := -1
var look_btn := -1
var look_held := false
var look_last := Vector2.ZERO
var look_t0 := 0.0
var look_moved := 0.0
var last_tap := 0.0
var last_was_tap := false
var pinch_a := -1
var pinch_b := -1
var pinch_pa := Vector2.ZERO
var pinch_pb := Vector2.ZERO
var pinch_dist := 0.0

# FX.
var tracers: Array = []
var sparks: Array = []
var muzzle_flash: Node3D
var laser: MeshInstance3D
var decals: Array[MeshInstance3D] = []
var decal_i := 0
var twitch := 0.0
var lock_target: Bot = null
var fire_held := false
var fire_id := -1
var sprint_held := false
var sprint_id := -1
var vig_hit := 0.0
var muzzle_t := 0.0
var aim_line: MeshInstance3D
var aim_line_mat: StandardMaterial3D
var aim_mark: MeshInstance3D


func _ready() -> void:
	settings.merge(TuneDefs.defaults(), false)
	_load_settings()
	zoom_show = settings["zoom"]
	_build_env()
	compound_root = Node3D.new()
	add_child(compound_root)
	level = Level.new(compound_root)
	level.build(START, EXTRACT)
	arena_root = Node3D.new()
	arena_root.visible = false
	add_child(arena_root)
	arena_level = Level.new(arena_root)
	arena_level.build_arena()
	obstacles = level.obstacles
	soldier = Soldier.new()
	soldier.setup(Color8(46, 48, 52), Color8(40, 42, 46), Color8(34, 36, 38), Color8(44, 46, 48), Color8(30, 32, 34), Color8(196, 160, 132), Color8(30, 31, 33), Color8(20, 20, 22), Color8(70, 230, 210), Color(0.02, 0.05, 0.07))
	add_child(soldier)
	_build_bots(COMPOUND_SPECS, compound_bots)
	_build_bots(ARENA_SPECS, arena_bots)
	bots = compound_bots
	_build_mates()
	_build_pickups()
	_build_fx()
	synth = Synth.new()
	add_child(synth)
	ui = GameUI.new()
	add_child(ui)
	ui.deploy.connect(_start_play)
	ui.deploy_arena.connect(_start_arena)
	ui.open_tune.connect(func() -> void: _open_tune(true))
	ui.tune_close.connect(func() -> void: _open_tune(false))
	ui.switch_mode.connect(_switch_mode)
	ui.tune_copy.connect(_tune_copy)
	ui.tune_paste.connect(_tune_paste)
	ui.tune_reset.connect(_tune_reset)
	ui.tune_enemy_toggle.connect(_tune_enemy_toggle)
	ui.tune_preset.connect(func(n: String) -> void:
		apply_preset(n)
		ui.tune_status.text = "%s preset applied." % n.capitalize())
	ui.resume.connect(func() -> void: _set_paused(false))
	ui.retry.connect(_retry)
	ui.restart.connect(_retry)
	ui.reset_view.connect(_reset_view)
	ui.setting_changed.connect(_on_setting)
	ui.hud.visible = false
	ui.fx.camera = camera
	ui.sync(settings)
	_apply_bars()
	_apply_volume()
	_set_mode(false)
	_reset_mission()
	cam_pos = _camera_target(0.0)
	if OS.has_feature("web_android") or OS.has_feature("web_ios") or DisplayServer.is_touchscreen_available():
		_set_touch_mode(true)


# ---------- setup ----------

func _build_env() -> void:
	# Night op mood: cold moonlight, blue haze, glow on lamps, mild grade.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color8(18, 24, 34)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color8(92, 112, 140)
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color8(40, 52, 70)
	env.fog_light_energy = 1.0
	env.fog_density = 0.016
	env.fog_sky_affect = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.85
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-48), deg_to_rad(28), 0)
	sun.light_energy = 0.55
	sun.light_specular = 1.0
	sun.light_color = Color8(170, 196, 255)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 42.0
	add_child(sun)
	# Cool fill light that rides with the player for readability.
	fill_light = OmniLight3D.new()
	fill_light.light_color = Color8(190, 210, 255)
	fill_light.light_energy = 0.9
	fill_light.omni_range = 9.0
	fill_light.omni_attenuation = 1.4
	fill_light.shadow_enabled = false
	add_child(fill_light)
	camera = Camera3D.new()
	camera.fov = 52
	camera.near = 0.1
	camera.far = 260
	add_child(camera)
	camera.make_current()


const COMPOUND_SPECS := [
	[-5, 79, 0.2, [-3, 77, -8, 82]], [6, 75, -0.3, [8, 73, 3, 78]],
	[0, 20, 0.2, [3, 18, -3, 23]], [8, 9, -0.4, [10, 7, 5, 12]], [-11, 4, 2.2, [-9, 2, -14, 7]],
	[-18, -29, 1.0, [-16, -26, -22, -32]], [-35, -44, 0.4, [-32, -41, -38, -48]],
	[-6, -84, 0.1, [-4, -81, -9, -87]], [7, -86, -0.2, [9, -83, 4, -88]],
]
const ARENA_SPECS := [[0, -10, 0.0, [3, -9, -3, -12]]]


func _build_bots(specs: Array, out: Array) -> void:
	var bar_bg_mat := _flat_mat(Color(0.16, 0.13, 0.11))
	bar_bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bar_bg_mat.billboard_keep_scale = true
	for s in specs:
		var b := Bot.new()
		b.label = BOT_NAMES[out.size() % BOT_NAMES.size()]
		b.node = Soldier.new()
		b.node.setup(Color8(128, 104, 78), Color8(96, 80, 62), Color8(110, 70, 46), Color8(92, 72, 52), Color8(70, 52, 38), Color8(214, 186, 156), Color8(40, 34, 30), Color8(70, 56, 44), Color8(255, 60, 40), Color(0.11, 0.05, 0.02))
		add_child(b.node)
		b.home = Vector2(s[0], s[1])
		b.facing = s[2]
		var w: Array = s[3]
		b.waypoints = [Vector2(w[0], w[1]), Vector2(w[2], w[3])]
		var qm := QuadMesh.new()
		qm.size = Vector2(0.72, 0.09)
		b.bar_bg = MeshInstance3D.new()
		b.bar_bg.mesh = qm
		b.bar_bg.material_override = bar_bg_mat
		b.bar_bg.position = Vector3(0, 2.15, 0)
		b.bar_bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.node.add_child(b.bar_bg)
		var fm := _flat_mat(Color(0.49, 0.73, 0.35))
		fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		fm.billboard_keep_scale = true
		fm.render_priority = 1
		var qf := QuadMesh.new()
		qf.size = Vector2(0.68, 0.06)
		b.bar_fill = MeshInstance3D.new()
		b.bar_fill.mesh = qf
		b.bar_fill.material_override = fm
		b.bar_fill.position = Vector3(0, 2.15, 0.01)
		b.bar_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.node.add_child(b.bar_fill)
		out.append(b)


func _build_mates() -> void:
	var looks := [[Color8(52, 54, 58), Color8(44, 46, 50)], [Color8(40, 44, 42), Color8(36, 38, 36)]]
	var offs := [Vector2(-1.6, 1.9), Vector2(1.7, 2.6)]
	for i in 2:
		var m := Mate.new()
		m.node = Soldier.new()
		var lk: Array = looks[i]
		m.node.setup(lk[0], lk[1], Color8(34, 36, 38), Color8(46, 48, 50), Color8(30, 32, 34), Color8(186, 150, 122), Color8(30, 31, 33), Color8(22, 22, 24), Color8(70, 230, 210), Color(0.02, 0.05, 0.07))
		add_child(m.node)
		m.offset = offs[i]
		mates.append(m)


func _place_mates() -> void:
	var f := Vector2(sin(yaw), cos(yaw))
	var r := Vector2(-cos(yaw), sin(yaw))
	for m in mates:
		var w := Vector2(pos.x, pos.z) + r * m.offset.x - f * m.offset.y
		m.node.position = Vector3(w.x, 0, w.y)
		m.node.rotation.y = yaw
		m.prev = w
		m.target = null
		m.shoot_cd = 1.0


## Two AI teammates hold a loose wedge behind you and engage what they can see.
func _update_mates(dt: float) -> void:
	var f := Vector2(sin(yaw), cos(yaw))
	var r := Vector2(-cos(yaw), sin(yaw))
	for m in mates:
		var cur := Vector2(m.node.position.x, m.node.position.z)
		var want := Vector2(pos.x, pos.z) + r * m.offset.x - f * m.offset.y
		var d := want - cur
		var dist := d.length()
		if dist > 24.0 and not _blocked_at(want.x, want.y, 0.4):
			m.node.position = Vector3(want.x, 0, want.y)
		elif dist > 0.35:
			var sp := clampf(dist * 2.4, 0.0, _sprint() * 1.05)
			var st := d / dist * minf(sp * dt, dist)
			var c := _collide_xz(cur.x + st.x, cur.y + st.y, 0.34)
			m.node.position.x = c.x
			m.node.position.z = c.y
		m.scan -= dt
		if m.scan <= 0.0:
			m.scan = 0.25
			m.target = null
			var bd := 18.0
			for b in bots:
				if b.state == "down":
					continue
				var bdist := Vector2(b.node.position.x - m.node.position.x, b.node.position.z - m.node.position.z).length()
				if bdist < bd and not _los_blocked(m.node.position.x, m.node.position.z, b.node.position.x, b.node.position.z):
					bd = bdist
					m.target = b
		if m.target != null and m.target.state == "down":
			m.target = null
		var face := yaw
		if m.target != null:
			face = atan2(m.target.node.position.x - m.node.position.x, m.target.node.position.z - m.node.position.z)
		elif dist > 1.0:
			face = atan2(d.x, d.y)
		m.node.rotation.y = _damp_angle(m.node.rotation.y, face, 9.0, dt)
		m.crouch = dist < 0.8 and _near_low_cover(m.node.position.x, m.node.position.z, 0.95) != null
		m.shoot_cd -= dt
		if m.target != null and m.shoot_cd <= 0.0 and absf(_wrap(m.node.rotation.y - face)) < 0.25:
			m.shoot_cd = randf_range(0.55, 0.95)
			var tb := m.target
			var aim := Vector3(tb.node.position.x, 0.6 if tb.crouch else 1.1, tb.node.position.z)
			var hit := randf() < 0.4
			if not hit:
				aim += Vector3(randf_range(-0.8, 0.8), randf_range(-0.3, 0.5), randf_range(-0.8, 0.8))
			_spawn_tracer(m.node.muzzle.global_position, aim)
			_spawn_spark(aim)
			var pd := Vector2(m.node.position.x - pos.x, m.node.position.z - pos.z).length()
			synth.play("carbine", 0.45 / (1.0 + pd * 0.1))
			if hit:
				_hurt_bot(tb)


func _pose_mates(dt: float) -> void:
	for m in mates:
		var p2 := Vector2(m.node.position.x, m.node.position.z)
		m.spd = (p2 - m.prev).length() / maxf(dt, 1e-4)
		m.prev = p2
		m.bob += m.spd * dt * 1.7
		m.node.pose(dt, m.spd, m.bob, 0.0, 0.0, m.crouch, -1.0, m.target != null, false, -1.0)


func _flat_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


func _ammo_mesh(scale_k: float, col: Color) -> Node3D:
	var g := Node3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.48, 0.28, 0.48) * scale_k
	var box := MeshInstance3D.new()
	box.mesh = bm
	var mm := StandardMaterial3D.new()
	mm.albedo_color = col
	box.material_override = mm
	box.position.y = 0.16 * scale_k
	g.add_child(box)
	var ym := _flat_mat(Color(0.95, 0.76, 0.29))
	for sz in [Vector3(0.18, 0.08, 0.34), Vector3(0.34, 0.08, 0.18)]:
		var pm := BoxMesh.new()
		pm.size = sz * scale_k
		var p := MeshInstance3D.new()
		p.mesh = pm
		p.material_override = ym
		p.position.y = 0.36 * scale_k
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(p)
	return g


func _spawn_pickup(x: float, z: float, carbine: int, sweeper: int, respawn: float, drop: bool) -> Pickup:
	var p := Pickup.new()
	p.node = _ammo_mesh(0.72 if drop else 1.0, Color8(196, 164, 90) if drop else Color8(110, 90, 50))
	p.node.position = Vector3(x, 0, z)
	add_child(p.node)
	p.pos = Vector2(x, z)
	p.carbine = carbine
	p.sweeper = sweeper
	p.respawn = respawn
	p.drop = drop
	p.bob = randf() * 6.0
	pickups.append(p)
	return p


func _build_pickups() -> void:
	_spawn_pickup(2, 84, 40, 8, 18, false)
	_spawn_pickup(5, 25, 40, 8, 18, false)
	_spawn_pickup(-24, -29, 40, 8, 20, false)
	_spawn_pickup(24, -45, 40, 8, 20, false)
	_spawn_pickup(4, -80, 40, 8, 22, false)


func _build_fx() -> void:
	var tm := _flat_mat(Color(1.0, 0.96, 0.7))
	var tb := BoxMesh.new()
	tb.size = Vector3(0.07, 0.07, 1.0)
	for i in 32:
		var m := MeshInstance3D.new()
		m.mesh = tb
		m.material_override = tm
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
		tracers.append({"node": m, "life": 0.0, "a": Vector3.ZERO, "dir": Vector3.FORWARD, "dist": 0.0, "t": 0.0, "speed": 160.0})
	var sm := _flat_mat(Color(1.0, 0.9, 0.6))
	var sb := BoxMesh.new()
	sb.size = Vector3(0.09, 0.09, 0.09)
	for i in 60:
		var m := MeshInstance3D.new()
		m.mesh = sb
		m.material_override = sm
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
		sparks.append({"node": m, "life": 0.0, "v": Vector3.ZERO})
	muzzle_flash = Node3D.new()
	var fmat := _flat_mat(Color(1.0, 0.93, 0.6))
	var arm := BoxMesh.new()
	arm.size = Vector3(1.0, 0.03, 0.09)
	for i in 4:
		var m := MeshInstance3D.new()
		m.mesh = arm
		m.material_override = fmat
		m.rotation.y = i * PI / 4.0
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		muzzle_flash.add_child(m)
	var core := MeshInstance3D.new()
	var fs := SphereMesh.new()
	fs.radius = 0.12
	fs.height = 0.24
	core.mesh = fs
	core.material_override = _flat_mat(Color(1.0, 1.0, 0.9))
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle_flash.add_child(core)
	muzzle_flash.visible = false
	add_child(muzzle_flash)
	var lm := _flat_mat(Color(1.0, 0.22, 0.16, 0.8))
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var lb := BoxMesh.new()
	lb.size = Vector3(0.022, 0.022, 1.0)
	laser = MeshInstance3D.new()
	laser.mesh = lb
	laser.material_override = lm
	laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	laser.visible = false
	add_child(laser)
	var dm := _flat_mat(Color(0.02, 0.02, 0.025, 0.8))
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var dc := CylinderMesh.new()
	dc.top_radius = 0.85
	dc.bottom_radius = 0.85
	dc.height = 0.01
	dc.radial_segments = 16
	for i in 8:
		var m := MeshInstance3D.new()
		m.mesh = dc
		m.material_override = dm
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
		decals.append(m)
	aim_line_mat = _flat_mat(Color(1.0, 0.88, 0.54, 0.6))
	aim_line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aim_line_mat.no_depth_test = false
	var al := BoxMesh.new()
	al.size = Vector3(1, 0.01, 1)
	aim_line = MeshInstance3D.new()
	aim_line.mesh = al
	aim_line.material_override = aim_line_mat
	aim_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(aim_line)
	var tm2 := TorusMesh.new()
	tm2.inner_radius = 0.42
	tm2.outer_radius = 0.55
	tm2.rings = 24
	tm2.ring_segments = 4
	aim_mark = MeshInstance3D.new()
	aim_mark.mesh = tm2
	aim_mark.material_override = _flat_mat(Color(1.0, 0.76, 0.29))
	aim_mark.scale = Vector3(1, 0.1, 1)
	aim_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aim_mark.visible = false
	add_child(aim_mark)


func _add_decal(x: float, z: float) -> void:
	var d := decals[decal_i % decals.size()]
	decal_i += 1
	d.position = Vector3(x, 0.03, z)
	d.rotation.y = randf() * TAU
	d.scale = Vector3(randf_range(0.9, 1.25), 1, randf_range(0.65, 0.95))
	d.visible = true


func _clear_decals() -> void:
	for d in decals:
		d.visible = false


# ---------- tuning accessors ----------

func _t(k: String) -> float:
	return float(settings[k])


func _tb(k: String) -> bool:
	return float(settings[k]) > 0.5


func _btn_mode() -> bool:
	return not _tb("twin_stick")


func _north_up() -> bool:
	return _tb("cam_northup")


func _range() -> float:
	return _t("lock_range") if _btn_mode() else AIM_RANGE


func _walk() -> float: return _t("move_speed")
func _sprint() -> float: return _t("sprint_speed")
func _slide_boost() -> float: return _t("slide_speed")
func _slide_dur() -> float: return _t("slide_dur")
func _accel() -> float: return _t("accel")
func _friction() -> float: return _t("decel")
func _fire_stick() -> float: return _t("fire_thresh")
func _aim_cone() -> float: return deg_to_rad(_t("assist_cone"))
func _cam_dist() -> float: return _t("cam_dist")
func _cam_tilt() -> float: return deg_to_rad(_t("cam_pitch"))


func _fire_ms(w: Dictionary) -> float:
	return _t("fire_ms") if w["short"] == "CARBINE" else float(w["fire_ms"])


func _spread(w: Dictionary) -> float:
	return _t("spread") if w["short"] == "CARBINE" else float(w["spread"])


func _enemy_hp() -> int:
	return int(round(_t("enemy_hp")))


# ---------- settings ----------

func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		var fresh: bool = cf.get_value("s", "tune_ver", "") == TuneDefs.VERSION
		var tune_keys := TuneDefs.defaults()
		for k in settings.keys():
			if not fresh and tune_keys.has(k):
				continue  # older saved tuning (v1a) -> start from the Snappy defaults
			settings[k] = cf.get_value("s", k, settings[k])
		settings["tune_ver"] = TuneDefs.VERSION
	for it in TuneDefs.all_items():
		settings[it["key"]] = TuneDefs.clamp_value(it["key"], float(settings[it["key"]]))
	settings["enemy_active"] = bool(settings["enemy_active"])
	settings["fullscreen"] = false
	settings["landscape"] = false


func _save_settings() -> void:
	var cf := ConfigFile.new()
	for k in settings.keys():
		cf.set_value("s", k, settings[k])
	cf.save(SETTINGS_PATH)


func _on_setting(key: String, value: Variant) -> void:
	match key:
		"invert_move":
			settings["invert_move"] = not settings["invert_move"]
		"facing":
			settings["facing"] = "free" if settings["facing"] == "follow" else "follow"
		"fullscreen":
			settings["fullscreen"] = not settings["fullscreen"]
			_apply_fullscreen(settings["fullscreen"])
		"landscape":
			settings["landscape"] = not settings["landscape"]
			_apply_landscape(settings["landscape"])
		"volume":
			settings["volume"] = float(value)
			_apply_volume()
		_:
			settings[key] = TuneDefs.clamp_value(key, float(value))
			settings["preset"] = "custom"
			if key == "enemy_hp":
				_apply_enemy_hp()
			elif key == "bars":
				_apply_bars()
			elif key == "cam_northup" and _north_up():
				view_yaw = 0.0
			elif key == "twin_stick":
				_clear_touches()
				fire_held = false
				sprint_held = false
	_queue_save()
	ui.sync(settings)


func _queue_save() -> void:
	_save_wait = 0.6


func _apply_enemy_hp() -> void:
	for b in bots:
		if b.state == "down":
			continue
		b.max_hp = _enemy_hp()
		b.hp = b.max_hp
		b.bar_fill.scale = Vector3.ONE
		(b.bar_fill.material_override as StandardMaterial3D).albedo_color = Color(0.49, 0.73, 0.35)


func _apply_bars() -> void:
	var on := _tb("bars")
	for b in compound_bots + arena_bots:
		var show := on and b.state != "down"
		b.bar_bg.visible = show
		b.bar_fill.visible = show


## Apply a named preset ("snappy" or "classic") to every tuning value.
func apply_preset(name: String) -> void:
	var vals := TuneDefs.preset_values(name)
	for k in vals.keys():
		settings[k] = vals[k]
	settings["preset"] = name
	zoom_show = float(settings["zoom"])
	if _north_up():
		view_yaw = 0.0
	_clear_touches()
	fire_held = false
	sprint_held = false
	_apply_bars()
	_save_settings()
	ui.sync(settings)


# ---------- tuning panel actions ----------

func tuning_values() -> Dictionary:
	var d := {"version": VERSION}
	var defs := TuneDefs.defaults()
	for k in defs.keys():
		d[k] = settings[k]
	return d


func _tune_copy() -> void:
	var json := JSON.stringify(tuning_values(), "  ")
	DisplayServer.clipboard_set(json)
	ui.tune_text.text = json
	ui.tune_status.text = "Copied. JSON is also in the box below."


## Applies a JSON string of tuning values. Returns how many keys were applied (-1 = invalid JSON).
func apply_tuning_json(text: String) -> int:
	var jp := JSON.new()
	if jp.parse(text) != OK:
		return -1
	var parsed: Variant = jp.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return -1
	var defs := TuneDefs.defaults()
	var n := 0
	for k in (parsed as Dictionary).keys():
		if not defs.has(k):
			continue
		var v: Variant = parsed[k]
		if k == "enemy_active":
			settings[k] = bool(v)
		elif typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
			settings[k] = TuneDefs.clamp_value(k, float(v))
		else:
			continue
		n += 1
	settings["preset"] = "custom"
	_apply_enemy_hp()
	_apply_bars()
	_apply_volume()
	zoom_show = float(settings["zoom"])
	_save_settings()
	ui.sync(settings)
	return n


func _tune_paste() -> void:
	var text := ui.tune_text.text.strip_edges()
	if text == "":
		text = DisplayServer.clipboard_get().strip_edges()
		ui.tune_text.text = text
	var n := apply_tuning_json(text)
	ui.tune_status.text = "Pasted %d values." % n if n >= 0 else "Could not read that JSON. Tap Copy first, or paste into the box."


func reset_tuning() -> void:
	settings["enemy_active"] = false
	apply_preset("snappy")
	_apply_enemy_hp()


func _tune_reset() -> void:
	reset_tuning()
	ui.tune_status.text = "Defaults restored."


func _tune_enemy_toggle() -> void:
	settings["enemy_active"] = not bool(settings["enemy_active"])
	_save_settings()
	ui.sync(settings)


func _apply_volume() -> void:
	var v := clampf(float(settings["volume"]) / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(0, v <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))


func _apply_fullscreen(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


func _apply_landscape(on: bool) -> void:
	if OS.has_feature("web"):
		if on:
			JavaScriptBridge.eval("(async()=>{try{if(!document.fullscreenElement){await document.documentElement.requestFullscreen();}}catch(e){} try{await screen.orientation.lock('landscape');}catch(e){}})()", true)
			settings["fullscreen"] = true
		else:
			JavaScriptBridge.eval("(()=>{try{screen.orientation.unlock();}catch(e){}})()", true)
	else:
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE if on else DisplayServer.SCREEN_SENSOR)


func _set_zoom(v: float, persist: bool) -> void:
	settings["zoom"] = clampf(v, 0.0, 100.0)
	ui.set_zoom_display(settings["zoom"])
	if persist:
		_save_settings()


func _aim_mul() -> float:
	return float(settings["aim_sens"]) / 100.0


func _assist_mul() -> float:
	return clampf(float(settings["assist"]) / 100.0, 0.0, 1.0)


func _follow_view() -> bool:
	return settings["facing"] != "free"


func _vol_gain(g: float) -> float:
	return g


# ---------- flow ----------

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _game_active() -> bool:
	return playing and not paused and not mission_over


func _start_play() -> void:
	_begin(false)


func _start_arena() -> void:
	_begin(true)


func _begin(arena: bool) -> void:
	_set_mode(arena)
	_reset_mission()
	playing = true
	paused = false
	tune_open = false
	ui.tune_panel.visible = false
	ui.pause_panel.visible = false
	ui.start_panel.visible = false
	ui.hud.visible = true


func _switch_mode() -> void:
	_begin(not arena_mode)


func _set_mode(arena: bool) -> void:
	arena_mode = arena
	compound_root.visible = not arena
	arena_root.visible = arena
	obstacles = arena_level.obstacles if arena else level.obstacles
	bots = arena_bots if arena else compound_bots
	for b in compound_bots:
		b.node.visible = not arena
	for b in arena_bots:
		b.node.visible = arena
	for m in mates:
		m.node.visible = not arena
	for p in pickups:
		p.node.visible = not arena and p.live
	ui.set_arena(arena)
	_clear_decals()


func _retry() -> void:
	ui.done_panel.visible = false
	ui.fail_panel.visible = false
	ui.pause_panel.visible = false
	_reset_mission()
	playing = true
	paused = false
	ui.hud.visible = true


func _set_paused(on: bool) -> void:
	if not playing or mission_over:
		return
	paused = on
	tune_open = false
	ui.tune_panel.visible = false
	ui.pause_panel.visible = on
	mouse_down = false
	_clear_touches()
	if on:
		ui.sync(settings)


func _open_tune(on: bool) -> void:
	if not playing or mission_over:
		return
	tune_open = on
	paused = on
	ui.tune_panel.visible = on
	ui.pause_panel.visible = false
	mouse_down = false
	_clear_touches()
	if on:
		ui.sync(settings)


func _clear_touches() -> void:
	move_id = -1
	move_v = Vector2.ZERO
	aim_id = -1
	aim_v = Vector2.ZERO
	aim_mag = 0.0
	look_id = -1
	look_btn = -1
	look_held = false
	pinch_a = -1
	pinch_b = -1
	fire_id = -1
	fire_held = false
	sprint_id = -1
	sprint_held = false
	_update_stick_draw()


func _reset_mission() -> void:
	_clear_touches()
	_clear_decals()
	fire_held = false
	sprint_held = false
	lock_target = null
	twitch = 0.0
	vig_hit = 0.0
	ui.fx.clear_all()
	view_yaw = 0.0
	view_pitch = 0.0
	pos = ARENA_START if arena_mode else START
	vel = Vector3.ZERO
	yaw = START_YAW
	prev_yaw = yaw
	stance = "stand"
	vault = {}
	slide_t = 0.0
	slide_mix = 0.0
	slide_side = 0.0
	crouch = false
	in_cover = false
	cover_dr = 1.0
	hp = max_hp
	last_hit = -99.0
	guns = []
	for w in WEAPONS:
		guns.append({"mag": w["mag"], "reserve": w["reserve"], "reload_t": 0.0})
	wep = 0
	mag = WEAPONS[0]["mag"]
	reserve = WEAPONS[0]["reserve"]
	reload_t = 0.0
	burst_count = 0
	burst_wait = 0.0
	recently_shot = 0.0
	aim_bloom = 0.0
	sticky_assist = null
	assist_target = null
	mission_over = false
	stats = {"kills": 0, "shots": 0, "hits": 0, "start": _now()}
	for b in bots:
		_respawn_bot(b, b.home)
	for i in range(pickups.size() - 1, -1, -1):
		var p: Pickup = pickups[i]
		if p.drop:
			p.node.queue_free()
			pickups.remove_at(i)
		else:
			p.live = true
			p.wait = 0.0
			p.node.visible = not arena_mode
	soldier.k_down = 0.0
	if not arena_mode:
		_place_mates()
	cam_pos = _camera_target(0.0)


func _respawn_bot(b: Bot, at: Vector2) -> void:
	b.max_hp = _enemy_hp()
	b.hp = b.max_hp
	b.state = "patrol"
	b.t = 0.0
	b.flash = 0.0
	b.crouch = false
	b.alert = 0.0
	b.wp = 0
	b.shoot_cd = 0.6 + randf() * 0.8
	b.node.position = Vector3(at.x, 0, at.y)
	b.node.rotation = Vector3(0, b.facing, 0)
	b.prev = at
	b.spd = 0.0
	b.node.set_flash(0.0)
	b.bar_bg.visible = _tb("bars")
	b.bar_fill.visible = _tb("bars")
	b.bar_fill.scale = Vector3.ONE
	(b.bar_fill.material_override as StandardMaterial3D).albedo_color = Color(0.49, 0.73, 0.35)
	b.node.k_down = 0.0


func _arena_respawn(b: Bot) -> void:
	var best := Level.ARENA_SPAWNS[0] as Vector2
	var tries := 0
	while tries < 6:
		var c := Level.ARENA_SPAWNS[randi() % Level.ARENA_SPAWNS.size()] as Vector2
		best = c
		if Vector2(pos.x - c.x, pos.z - c.y).length() > 8.0:
			break
		tries += 1
	b.home = best
	_respawn_bot(b, best)


func _complete() -> void:
	if mission_over:
		return
	mission_over = true
	mouse_down = false
	_clear_touches()
	var elapsed := maxf(0.0, _now() - float(stats["start"]))
	var acc := 0
	if stats["shots"] > 0:
		acc = int(round(100.0 * stats["hits"] / stats["shots"]))
	ui.done_stats.text = "Kills: %d    Accuracy: %d%%    Time: %.1fs" % [stats["kills"], acc, elapsed]
	ui.done_panel.visible = true
	synth.play("win", 0.9)


func _fail() -> void:
	if mission_over:
		return
	mission_over = true
	hp = 0.0
	mouse_down = false
	_clear_touches()
	ui.fail_panel.visible = true


# ---------- input ----------

func _set_touch_mode(on: bool) -> void:
	if touch_mode == on:
		return
	touch_mode = on
	ui.set_touch_mode(on)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.device == InputEvent.DEVICE_ID_EMULATION:
			return
		_on_mouse_button(mb)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.device == InputEvent.DEVICE_ID_EMULATION:
			return
		mouse_pos = mm.position
		if touch_mode and mm.relative.length() > 3.0 and move_id < 0 and aim_id < 0:
			_set_touch_mode(false)
		mouse_seen = true
		if look_held and look_btn >= 0:
			_apply_orbit(mm.relative)
	elif event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo:
			_on_key(ke)


func _on_key(e: InputEventKey) -> void:
	var k := e.physical_keycode
	if not playing and ui.start_panel.visible:
		if k == KEY_1 or k == KEY_ENTER or k == KEY_KP_ENTER:
			_start_arena()
		elif k == KEY_2:
			_start_play()
		return
	if k == KEY_ESCAPE or k == KEY_P:
		if tune_open:
			_open_tune(false)
		elif playing and not mission_over:
			_set_paused(not paused)
		return
	if tune_open and ui.tune_text.has_focus():
		return
	if k == KEY_T and playing:
		_open_tune(not tune_open)
		return
	if not _game_active():
		return
	match k:
		KEY_SPACE:
			_try_vault({})
		KEY_C, KEY_CTRL:
			_try_slide()
		KEY_R:
			_start_reload()
		KEY_Q:
			_swap_weapon(1 - wep)
		KEY_1:
			_swap_weapon(0)
		KEY_2:
			_swap_weapon(1)


func _on_mouse_button(e: InputEventMouseButton) -> void:
	mouse_pos = e.position
	if e.pressed and e.button_index == MOUSE_BUTTON_LEFT and _game_active():
		var b := ui.touch_button_at(e.position)
		if b == "fire" or b == "sprint":
			if b == "fire":
				fire_held = true
				fire_id = -2
			else:
				sprint_held = true
				sprint_id = -2
			get_viewport().set_input_as_handled()
			return
		if b != "":
			_touch_button(b)
			get_viewport().set_input_as_handled()
			return
	if not _game_active():
		if not e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			mouse_down = false
			if fire_id == -2:
				fire_held = false
				fire_id = -1
			if sprint_id == -2:
				sprint_held = false
				sprint_id = -1
		return
	match e.button_index:
		MOUSE_BUTTON_LEFT:
			mouse_down = e.pressed
			if not e.pressed:
				if fire_id == -2:
					fire_held = false
					fire_id = -1
				if sprint_id == -2:
					sprint_held = false
					sprint_id = -1
		MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
			if e.pressed:
				look_held = true
				look_btn = e.button_index
				look_moved = 0.0
			elif look_btn == e.button_index:
				look_held = false
				look_btn = -1
		MOUSE_BUTTON_WHEEL_UP:
			if e.pressed:
				_set_zoom(float(settings["zoom"]) + 6.0 * maxf(e.factor, 1.0), true)
		MOUSE_BUTTON_WHEEL_DOWN:
			if e.pressed:
				_set_zoom(float(settings["zoom"]) - 6.0 * maxf(e.factor, 1.0), true)


func _touch_button(b: String) -> void:
	ui.flash_button(b)
	match b:
		"tune":
			_open_tune(true)
		"vault":
			_try_vault({})
		"slide":
			_try_slide()
		"swap":
			_swap_weapon(1 - wep)
		"reload":
			_start_reload()
		"pause":
			_set_paused(true)
		"view":
			_reset_view()
		"grenade":
			ui.toast("Grenade: coming soon")
			synth.play("empty", 0.5)


func _on_touch(e: InputEventScreenTouch) -> void:
	_set_touch_mode(true)
	var p := e.position
	if e.pressed:
		if not _game_active():
			return
		var b := ui.touch_button_at(p)
		if b == "fire":
			fire_id = e.index
			fire_held = true
			ui.flash_button("fire")
			return
		if b == "sprint":
			sprint_id = e.index
			sprint_held = true
			ui.flash_button("sprint")
			return
		if b != "":
			_touch_button(b)
			return
		if move_id < 0 and p.distance_to(ui.stick_center(0)) < STICK_HIT:
			move_id = e.index
			_set_stick(0, p)
			return
		if aim_id < 0 and not _btn_mode() and p.distance_to(ui.stick_center(1)) < STICK_HIT:
			aim_id = e.index
			_set_stick(1, p)
			return
		if pinch_a >= 0:
			return
		if look_id >= 0 and look_id != e.index:
			_begin_pinch(look_id, look_last, e.index, p)
		elif look_id < 0:
			_start_look(p, e.index)
	else:
		_end_touch(e.index)


func _on_drag(e: InputEventScreenDrag) -> void:
	var p := e.position
	if e.index == move_id:
		_set_stick(0, p)
	elif e.index == aim_id:
		_set_stick(1, p)
	elif pinch_a >= 0 and (e.index == pinch_a or e.index == pinch_b):
		if e.index == pinch_a:
			pinch_pa = p
		else:
			pinch_pb = p
		var d := maxf(1.0, pinch_pa.distance_to(pinch_pb))
		_set_zoom(float(settings["zoom"]) + (d - pinch_dist) * 0.28, false)
		pinch_dist = d
	elif e.index == look_id:
		_apply_orbit(p - look_last)
		look_last = p


func _set_stick(i: int, p: Vector2) -> void:
	var c := ui.stick_center(i)
	var d := (p - c) / GameUI.STICK_R
	if d.length() > 1.0:
		d = d.normalized()
	if i == 0:
		move_v = d
	else:
		aim_v = d
		aim_mag = d.length()
	_update_stick_draw()


func _update_stick_draw() -> void:
	if ui == null:
		return
	ui.sticks.knobs[0] = move_v
	ui.sticks.knobs[1] = aim_v
	ui.sticks.active[0] = move_id >= 0
	ui.sticks.active[1] = aim_id >= 0
	ui.sticks.queue_redraw()


func _end_touch(idx: int) -> void:
	if idx == fire_id:
		fire_id = -1
		fire_held = false
	if idx == sprint_id:
		sprint_id = -1
		sprint_held = false
	if idx == move_id:
		move_id = -1
		move_v = Vector2.ZERO
	if idx == aim_id:
		aim_id = -1
		aim_v = Vector2.ZERO
		aim_mag = 0.0
	if pinch_a >= 0 and (idx == pinch_a or idx == pinch_b):
		var remain := pinch_b if idx == pinch_a else pinch_a
		var rp := pinch_pb if idx == pinch_a else pinch_pa
		pinch_a = -1
		pinch_b = -1
		_save_settings()
		look_id = -1
		look_held = false
		if _game_active():
			_start_look(rp, remain)
			last_was_tap = false
		_update_stick_draw()
		return
	if idx == look_id:
		var now := _now()
		var was_tap := (now - look_t0) < 0.28 and look_moved < 18.0
		look_id = -1
		look_held = false
		last_was_tap = was_tap
		last_tap = now if was_tap else 0.0
	_update_stick_draw()


func _start_look(p: Vector2, idx: int) -> void:
	var now := _now()
	if last_was_tap and now - last_tap < 0.32:
		_reset_view()
		last_was_tap = false
		return
	look_id = idx
	look_held = true
	look_last = p
	look_t0 = now
	look_moved = 0.0


func _begin_pinch(a: int, pa: Vector2, b: int, pb: Vector2) -> void:
	look_id = -1
	look_held = false
	last_was_tap = false
	pinch_a = a
	pinch_b = b
	pinch_pa = pa
	pinch_pb = pb
	pinch_dist = maxf(1.0, pa.distance_to(pb))


func _apply_orbit(d: Vector2) -> void:
	if _north_up():
		return
	var w := maxf(ui.screen_size().x, 1.0)
	view_yaw -= d.x * 1.35 * PI / w
	view_pitch = clampf(view_pitch + d.y * 0.7 / w, VIEW_PITCH_MIN, VIEW_PITCH_MAX)
	look_moved += d.length()


func _reset_view() -> void:
	if _north_up():
		view_yaw = 0.0
		view_pitch = 0.0
		return
	view_yaw = yaw + PI
	view_pitch = 0.0


# ---------- helpers ----------

static func _damp(cur: float, target: float, lam: float, dt: float) -> float:
	return lerpf(cur, target, 1.0 - exp(-lam * dt))


static func _wrap(a: float) -> float:
	return wrapf(a, -PI, PI)


static func _damp_angle(cur: float, target: float, lam: float, dt: float) -> float:
	return cur + _wrap(target - cur) * (1.0 - exp(-lam * dt))


static func _move_toward_angle(cur: float, target: float, step: float) -> float:
	var d := _wrap(target - cur)
	if absf(d) <= step:
		return cur + d
	return cur + signf(d) * step


## Screen axes (x right, y up) -> world XZ for the given camera yaw.
static func screen_to_world(sx: float, sy: float, cam_yaw: float) -> Vector2:
	var c := cos(cam_yaw)
	var s := sin(cam_yaw)
	return Vector2(sx * c - sy * s, -sx * s - sy * c)


func _wish() -> Vector3:
	var sx := 0.0
	var sy := 0.0
	if touch_mode and move_id >= 0:
		sx = move_v.x
		sy = -move_v.y
	else:
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			sy += 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			sy -= 1.0
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			sx -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			sx += 1.0
	if settings["invert_move"]:
		sx = -sx
		sy = -sy
	var l := Vector2(sx, sy).length()
	if l > 1.0:
		sx /= l
		sy /= l
	var w := screen_to_world(sx, sy, view_yaw)
	return Vector3(w.x, minf(1.0, l), w.y)


## +1 = the move direction points to the soldier's right, -1 = left.
static func slide_side_from_dir(vx: float, vz: float, face: float) -> float:
	var n := Vector2(vx, vz).length()
	if n < 0.08:
		return 0.0
	var fwd := (vx * sin(face) + vz * cos(face)) / n
	var right := (vx * -cos(face) + vz * sin(face)) / n
	var denom := absf(right) + maxf(fwd, 0.05)
	return clampf(right / denom, -1.0, 1.0)


func _sprinting(w: Vector3) -> bool:
	if stance != "stand":
		return false
	var key := Input.is_physical_key_pressed(KEY_SHIFT)
	if _btn_mode():
		return (key or sprint_held) and w.y > 0.15
	var mob := touch_mode and w.y > 0.85
	return (key or mob) and w.y > 0.15


func _collide_xz(x: float, z: float, rad: float) -> Vector2:
	for it in 3:
		for o in obstacles:
			var cx := clampf(x, o.min_x, o.max_x)
			var cz := clampf(z, o.min_z, o.max_z)
			var dx := x - cx
			var dz := z - cz
			var d2 := dx * dx + dz * dz
			if d2 >= rad * rad:
				continue
			if d2 < 1e-8:
				var left := x - o.min_x + rad
				var right := o.max_x - x + rad
				var down := z - o.min_z + rad
				var up := o.max_z - z + rad
				var m := minf(minf(left, right), minf(down, up))
				if m == left:
					x = o.min_x - rad
				elif m == right:
					x = o.max_x + rad
				elif m == down:
					z = o.min_z - rad
				else:
					z = o.max_z + rad
			else:
				var f := rad / sqrt(d2)
				x = cx + dx * f
				z = cz + dz * f
	return Vector2(x, z)


func _collide_chars(x: float, z: float, rad: float) -> Array:
	var hit := false
	for b in bots:
		if b.state == "down":
			continue
		var ox := b.node.position.x
		var oz := b.node.position.z
		var dx := x - ox
		var dz := z - oz
		var dist := sqrt(dx * dx + dz * dz)
		var mn := rad + 0.36
		if dist >= mn:
			continue
		hit = true
		if dist < 1e-6:
			x += mn
			continue
		x = ox + dx * mn / dist
		z = oz + dz * mn / dist
	return [x, z, hit]


func _blocked_at(x: float, z: float, rad: float) -> bool:
	for o in obstacles:
		if o.h < 0.35:
			continue
		var cx := clampf(x, o.min_x, o.max_x)
		var cz := clampf(z, o.min_z, o.max_z)
		if (x - cx) * (x - cx) + (z - cz) * (z - cz) < rad * rad * 0.85:
			return true
	return false


## Ray vs obstacle boxes. Returns hit distance or max_d.
func _world_hit(o: Vector3, d: Vector3, max_d: float, tall_only := false, min_t := 0.05) -> float:
	var best := max_d
	var ix := 1.0 / (d.x if absf(d.x) > 1e-8 else 1e-8)
	var iy := 1.0 / (d.y if absf(d.y) > 1e-8 else 1e-8)
	var iz := 1.0 / (d.z if absf(d.z) > 1e-8 else 1e-8)
	for ob in obstacles:
		if not ob.blocks_ray or (tall_only and ob.h < 1.2):
			continue
		var t1 := (ob.min_x - o.x) * ix
		var t2 := (ob.max_x - o.x) * ix
		var tmin := minf(t1, t2)
		var tmax := maxf(t1, t2)
		t1 = (0.0 - o.y) * iy
		t2 = (ob.h - o.y) * iy
		tmin = maxf(tmin, minf(t1, t2))
		tmax = minf(tmax, maxf(t1, t2))
		t1 = (ob.min_z - o.z) * iz
		t2 = (ob.max_z - o.z) * iz
		tmin = maxf(tmin, minf(t1, t2))
		tmax = minf(tmax, maxf(t1, t2))
		if tmax >= tmin and tmin > min_t and tmin < best:
			best = tmin
	return best


func _los_blocked(ax: float, az: float, bx: float, bz: float) -> bool:
	var d := Vector3(bx - ax, 0, bz - az)
	var l := d.length()
	if l < 0.08:
		return false
	return _world_hit(Vector3(ax, 1.35, az), d / l, l - 0.15, true, 0.08) < l - 0.15


func _low_cover(o: Obstacle) -> bool:
	return o.h >= 0.45 and o.h <= 1.2


func _near_low_cover(x: float, z: float, within: float) -> Obstacle:
	var best: Obstacle = null
	var bd := within
	for o in obstacles:
		if not _low_cover(o):
			continue
		var cx := clampf(x, o.min_x, o.max_x)
		var cz := clampf(z, o.min_z, o.max_z)
		var d := Vector2(x - cx, z - cz).length()
		if d < bd:
			bd = d
			best = o
	return best


# ---------- player ----------

func _is_aiming() -> bool:
	if _btn_mode():
		return lock_target != null or fire_held or mouse_down
	if touch_mode:
		return aim_mag > AIM_DEAD
	return mouse_down or assist_target != null


func _stick_world_yaw() -> float:
	var w := screen_to_world(aim_v.x, -aim_v.y, view_yaw)
	return atan2(w.x, w.y)


func _stick_curve(m: float) -> float:
	var t := clampf((m - AIM_DEAD) / (1.0 - AIM_DEAD), 0.0, 1.0)
	return pow(t, _t("aim_curve"))


func _mouse_ground_yaw() -> float:
	if not mouse_seen:
		return NAN
	var o := camera.project_ray_origin(mouse_pos)
	var n := camera.project_ray_normal(mouse_pos)
	if absf(n.y) < 1e-4:
		return NAN
	var t := -o.y / n.y
	if t < 0.0:
		return NAN
	var hit := o + n * t
	var dx := hit.x - pos.x
	var dz := hit.z - pos.z
	if dx * dx + dz * dz < 0.05:
		return NAN
	return atan2(dx, dz)


func _target_off(b: Bot) -> Array:
	var dx := b.node.position.x - pos.x
	var dz := b.node.position.z - pos.z
	return [_wrap(atan2(dx, dz) - yaw), sqrt(dx * dx + dz * dz), dx, dz]


func _assist_valid(b: Bot, break_cone: float) -> bool:
	if b == null or b.state == "down":
		return false
	var off := _target_off(b)
	if off[1] < 0.5 or off[1] > AIM_RANGE * 1.08:
		return false
	if absf(off[0]) > break_cone:
		return false
	if _los_blocked(pos.x, pos.z, b.node.position.x, b.node.position.z):
		return false
	if touch_mode and aim_mag > 0.72:
		if absf(_wrap(_stick_world_yaw() - atan2(off[2], off[3]))) > _aim_cone() * 1.6:
			return false
	return true


func _find_assist() -> Bot:
	var strength := _assist_mul()
	if strength <= 0.01:
		sticky_assist = null
		return null
	if touch_mode and aim_mag <= AIM_DEAD:
		sticky_assist = null
		return null
	var cone := _aim_cone() * (0.75 + 0.35 * strength)
	if _assist_valid(sticky_assist, cone * _t("assist_stick")):
		return sticky_assist
	var best: Bot = null
	var best_score := 1e9
	for b in bots:
		if b.state == "down":
			continue
		var off := _target_off(b)
		var dist: float = off[1]
		if dist < 0.5 or dist > AIM_RANGE:
			continue
		if absf(off[0]) > cone:
			continue
		if _los_blocked(pos.x, pos.z, b.node.position.x, b.node.position.z):
			continue
		var close := 1.0 - clampf(dist / AIM_RANGE, 0.0, 1.0)
		var score := absf(off[0]) * 3.2 + dist * 0.05 - close * 0.35
		if score < best_score:
			best_score = score
			best = b
	sticky_assist = best
	return best


## Nearest living enemy in range with a clear line, or null.
func _find_lock() -> Bot:
	var best: Bot = null
	var bd := 1e9
	var rng := _range()
	for b in bots:
		if b.state == "down":
			continue
		var dx := b.node.position.x - pos.x
		var dz := b.node.position.z - pos.z
		var d := sqrt(dx * dx + dz * dz)
		if d > rng or d < 0.4:
			continue
		if d >= bd:
			continue
		if _los_blocked(pos.x, pos.z, b.node.position.x, b.node.position.z):
			continue
		bd = d
		best = b
	return best


func _update_look_snappy(dt: float) -> void:
	lock_target = _find_lock()
	assist_target = lock_target
	if lock_target != null:
		var want := atan2(lock_target.node.position.x - pos.x, lock_target.node.position.z - pos.z)
		var rate := _t("lock_turn")
		if rate >= 99.5:
			yaw = want
		else:
			yaw = _move_toward_angle(yaw, want, rate * 0.2 * dt)
		aim_point = Vector3(lock_target.node.position.x, 0.03, lock_target.node.position.z)
	else:
		var w := _wish()
		if w.y > 0.1 and stance == "stand":
			yaw = _damp_angle(yaw, atan2(w.x, w.z), 18.0, dt)
		aim_point = pos + Vector3(sin(yaw), 0, cos(yaw)) * 10.0
	_update_bloom(dt)


func _update_look(dt: float) -> void:
	if _btn_mode():
		_update_look_snappy(dt)
		return
	lock_target = null
	var turn := 10.0 * _aim_mul()
	if touch_mode:
		var stick_on := aim_mag > AIM_DEAD
		if _follow_view():
			var target := view_yaw + PI
			var rate := 16.0
			if stick_on:
				target = _stick_world_yaw()
				rate = (0.7 + 6.8 * _stick_curve(aim_mag)) * _aim_mul() * 1.6
			yaw = _move_toward_angle(yaw, target, rate * dt)
		elif stick_on:
			var rate2 := (0.7 + 6.8 * _stick_curve(aim_mag)) * _aim_mul() * 1.6
			yaw = _move_toward_angle(yaw, _stick_world_yaw(), rate2 * dt)
	else:
		var my := _mouse_ground_yaw()
		if not is_nan(my):
			yaw = _damp_angle(yaw, my, turn, dt)
		elif _follow_view():
			yaw = _damp_angle(yaw, view_yaw + PI, 10.0, dt)
	assist_target = _find_assist()
	if assist_target != null and _is_aiming():
		var off := _target_off(assist_target)
		var close := 1.0 - clampf(float(off[1]) / AIM_RANGE, 0.0, 1.0)
		var snap := (6.0 + 10.0 * close) * _assist_mul() * (0.55 + 0.45 * _aim_mul())
		yaw = _damp_angle(yaw, atan2(off[2], off[3]), snap, dt)
		aim_point = Vector3(assist_target.node.position.x, 0.03, assist_target.node.position.z)
	else:
		aim_point = pos + Vector3(sin(yaw), 0, cos(yaw)) * 10.0
	_update_bloom(dt)


func _update_bloom(dt: float) -> void:
	var spd := Vector2(vel.x, vel.z).length()
	var turning := absf(_wrap(yaw - prev_yaw)) > 0.35 * dt
	var busy := spd > 1.15 or turning or recently_shot > 0.0 or stance == "slide" or not vault.is_empty()
	if busy:
		aim_bloom = minf(1.0, aim_bloom + dt * (2.4 if recently_shot > 0.0 else 1.7))
	else:
		aim_bloom = maxf(0.0, aim_bloom - dt / 0.4)
	prev_yaw = yaw


func _apply_friction(dt: float, amount: float) -> void:
	var s := Vector2(vel.x, vel.z).length()
	if s < 0.02:
		vel.x = 0.0
		vel.z = 0.0
		return
	var drop := maxf(s * amount * dt, amount * 0.25 * dt)
	var ns := maxf(s - drop, 0.0)
	vel.x *= ns / s
	vel.z *= ns / s


func _accelerate(wx: float, wz: float, speed: float, dt: float) -> void:
	var cur := vel.x * wx + vel.z * wz
	var add := speed - cur
	if add <= 0.0:
		return
	var acc := minf(add, _accel() * dt * (speed / _walk()))
	vel.x += wx * acc
	vel.z += wz * acc


func _find_vault(dx_in: float, dz_in: float) -> Dictionary:
	var best := {}
	for o in obstacles:
		if not o.vaultable or o.h < VAULT_MIN or o.h > VAULT_MAX:
			continue
		var cx := clampf(pos.x, o.min_x, o.max_x)
		var cz := clampf(pos.z, o.min_z, o.max_z)
		var dx := cx - pos.x
		var dz := cz - pos.z
		var dist := sqrt(dx * dx + dz * dz)
		if dist > 1.25 or dist < 0.15:
			continue
		var toward := (dx * dx_in + dz * dz_in) / maxf(dist, 1e-4)
		if toward < 0.25:
			continue
		var reach := dist + maxf(o.max_x - o.min_x, o.max_z - o.min_z) * 0.55 + RADIUS + 0.18
		var lx := pos.x + dx_in * reach
		var lz := pos.z + dz_in * reach
		if _blocked_at(lx, lz, RADIUS * 0.9):
			continue
		if best.is_empty() or dist < float(best["dist"]):
			best = {"dist": dist, "lx": lx, "lz": lz, "h": o.h}
	return best


func _try_vault(hit: Dictionary) -> void:
	if not _game_active() or not vault.is_empty():
		return
	if hit.is_empty():
		hit = _find_vault(sin(yaw), cos(yaw))
		if hit.is_empty():
			var w := _wish()
			if w.y > 0.15:
				var n := Vector2(w.x, w.z).normalized()
				hit = _find_vault(n.x, n.y)
	if hit.is_empty():
		return
	if stance == "slide":
		slide_t = 0.0
	stance = "vault"
	vault = {"t": 0.0, "dur": 0.38, "sx": pos.x, "sz": pos.z, "ex": hit["lx"], "ez": hit["lz"], "h": hit["h"]}
	vel = Vector3.ZERO


func _slide_dir() -> Vector3:
	var w := _wish()
	if w.y > 0.15:
		var n := Vector2(w.x, w.z).normalized()
		return Vector3(n.x, slide_side_from_dir(n.x, n.y, yaw), n.y)
	var spd := Vector2(vel.x, vel.z).length()
	if spd > 0.4:
		return Vector3(vel.x / spd, slide_side_from_dir(vel.x, vel.z, yaw), vel.z / spd)
	return Vector3(sin(yaw), 0, cos(yaw))


func _try_slide() -> void:
	if not _game_active() or not vault.is_empty():
		return
	if stance == "slide":
		stance = "stand"
		slide_t = 0.0
		return
	if stance != "stand":
		return
	var d := _slide_dir()
	vel.x = d.x * _slide_boost()
	vel.z = d.z * _slide_boost()
	slide_side = d.y
	stance = "slide"
	slide_t = _slide_dur()
	synth.play("thud", 0.35)


func _slide_speed(t_left: float) -> float:
	var u := 1.0 - clampf(t_left / _slide_dur(), 0.0, 1.0)
	return _slide_boost() * (1.0 - 0.38 * u * u)


func _end_slide_impact() -> void:
	if stance != "slide":
		return
	stance = "stand"
	slide_t = 0.0
	vel = Vector3.ZERO
	kick_p += 0.055
	synth.play("thud", 0.6)


func _update_move(dt: float) -> void:
	if not vault.is_empty():
		vault["t"] = float(vault["t"]) + dt
		var u := clampf(float(vault["t"]) / float(vault["dur"]), 0.0, 1.0)
		var e := u * u * (3.0 - 2.0 * u)
		pos.x = lerpf(vault["sx"], vault["ex"], e)
		pos.z = lerpf(vault["sz"], vault["ez"], e)
		pos.y = (float(vault["h"]) + 0.28) * sin(u * PI)
		if u >= 1.0:
			pos.y = 0.0
			var land := _collide_xz(pos.x, pos.z, RADIUS)
			pos.x = land.x
			pos.z = land.y
			vault = {}
			stance = "stand"
			vel = Vector3(sin(yaw), 0, cos(yaw)) * 5.2
		return

	var w := _wish()
	var aiming := _is_aiming() or recently_shot > 0.0
	var sprint := (not aiming or _t("aim_slow") >= 0.99) and _sprinting(w)
	var speed := _slide_boost() if stance == "slide" else (_sprint() if sprint else _walk())
	if aiming and stance != "slide":
		speed *= _t("aim_slow")
	if crouch and stance == "stand":
		speed *= 0.7

	if stance != "slide" and w.y > 0.45:
		var spd := Vector2(vel.x, vel.z).length()
		if spd > 3.0 or w.y > 0.7:
			var n := Vector2(w.x, w.z).normalized()
			var hit := _find_vault(n.x, n.y)
			if not hit.is_empty() and float(hit["dist"]) < 0.95:
				_try_vault(hit)
				return

	var slid := false
	if stance == "slide":
		slide_t -= dt
		var n := maxf(Vector2(vel.x, vel.z).length(), 1e-4)
		var sp := _slide_speed(slide_t)
		vel.x = vel.x / n * sp
		vel.z = vel.z / n * sp
		var vx := vel.x / sp
		var vz := vel.z / sp
		var vh := _find_vault(vx, vz)
		if not vh.is_empty() and float(vh["dist"]) < 0.95:
			_try_vault(vh)
			return
		var step_len := Vector2(vel.x, vel.z).length() * dt
		var steps := maxi(1, int(ceil(step_len / 0.1)))
		var sdt := dt / steps
		for i in steps:
			var ix := pos.x + vel.x * sdt
			var iz := pos.z + vel.z * sdt
			var wv := _collide_xz(ix, iz, RADIUS)
			var cr := _collide_chars(wv.x, wv.y, RADIUS)
			var rx: float = cr[0]
			var rz: float = cr[1]
			pos.x = rx
			pos.z = rz
			if cr[2] or Vector2(rx - ix, rz - iz).length() > 0.008:
				_end_slide_impact()
				break
		slid = true
		if stance == "slide" and slide_t <= 0.0:
			stance = "stand"
	elif w.y > 0.04:
		_apply_friction(dt, minf(_friction() * 0.45, 5.4))
		_accelerate(w.x, w.z, speed * w.y, dt)
		var kill := clampf((_friction() - 30.0) * dt * 0.1, 0.0, 1.0)
		if kill > 0.0:
			# snappy steering: bleed off sideways velocity so direction changes are immediate
			var wd := Vector2(w.x, w.z).normalized()
			var along := vel.x * wd.x + vel.z * wd.y
			var lx := vel.x - wd.x * along
			var lz := vel.z - wd.y * along
			vel.x -= lx * kill
			vel.z -= lz * kill
	else:
		_apply_friction(dt, _friction() * 1.35)

	if not slid:
		pos.x += vel.x * dt
		pos.z += vel.z * dt
	var hit2 := _collide_xz(pos.x, pos.z, RADIUS)
	if hit2.x != pos.x:
		vel.x = 0.0
	if hit2.y != pos.z:
		vel.z = 0.0
	var cr2 := _collide_chars(hit2.x, hit2.y, RADIUS)
	pos.x = cr2[0]
	pos.z = cr2[1]
	pos.y = 0.0
	bob += Vector2(vel.x, vel.z).length() * dt * 1.7


func _update_cover() -> void:
	if stance == "slide" or not vault.is_empty():
		crouch = false
		in_cover = false
		cover_dr = 1.0
		return
	var c := _near_low_cover(pos.x, pos.z, 0.95)
	var spd := Vector2(vel.x, vel.z).length()
	crouch = c != null and spd < 4.2
	in_cover = crouch
	cover_dr = 0.45 if in_cover else 1.0


# ---------- weapons ----------

func _cur_wep() -> Dictionary:
	return WEAPONS[wep]


func _swap_weapon(i: int) -> void:
	if arena_mode or not _game_active() or i == wep or i < 0 or i >= WEAPONS.size():
		return
	guns[wep] = {"mag": mag, "reserve": reserve, "reload_t": reload_t}
	wep = i
	mag = guns[i]["mag"]
	reserve = guns[i]["reserve"]
	reload_t = guns[i]["reload_t"]
	burst_count = 0
	burst_wait = 0.0
	synth.play("empty", 0.5)


func _start_reload() -> void:
	var w := _cur_wep()
	if not _game_active() or reload_t > 0.0 or mag >= int(w["mag"]) or reserve <= 0:
		return
	reload_t = w["reload"]
	synth.play("reload", 0.8)


func _add_reserve(i: int, amount: int) -> void:
	var cap: int = WEAPONS[i]["max_reserve"]
	if i == wep:
		reserve = mini(cap, reserve + amount)
	else:
		guns[i]["reserve"] = mini(cap, int(guns[i]["reserve"]) + amount)


func _ammo_full() -> bool:
	var c: int = reserve if wep == 0 else int(guns[0]["reserve"])
	var s: int = reserve if wep == 1 else int(guns[1]["reserve"])
	return c >= int(WEAPONS[0]["max_reserve"]) and s >= int(WEAPONS[1]["max_reserve"])


func _bot_hit_test(o: Vector3, d: Vector3, max_d: float) -> Array:
	var best: Bot = null
	var bd := max_d
	for b in bots:
		if b.state == "down":
			continue
		var c := Vector3(b.node.position.x, 0.55 if b.crouch else 0.9, b.node.position.z)
		var t := (c - o).dot(d)
		if t < 0.0 or t > bd:
			continue
		var q := o + d * t - c
		var rad := 0.5 if b.crouch else 0.55
		if q.x * q.x + q.z * q.z < rad * rad and absf(q.y) < (0.7 if b.crouch else 1.05):
			best = b
			bd = t
	return [best, bd]


func _player_hit_test(o: Vector3, d: Vector3, max_d: float) -> float:
	var c := Vector3(pos.x, 0.55 if (crouch or stance == "slide") else 0.9, pos.z)
	var t := (c - o).dot(d)
	if t < 0.0 or t > max_d:
		return -1.0
	var q := o + d * t - c
	var rad := 0.42 if crouch else 0.5
	if q.x * q.x + q.z * q.z < rad * rad and absf(q.y) < (0.7 if crouch else 1.05):
		return t
	return -1.0


func _hurt_bot(b: Bot) -> void:
	if b.state == "down":
		return
	b.hp -= 1
	b.flash = maxf(_t("hit_flash") / 1000.0, 0.0)
	if _tb("dmg_nums"):
		ui.fx.add_number(b.node.position + Vector3(0, 2.7, 0), int(round(100.0 / maxf(b.max_hp, 1))))
	synth.play("hit", 0.7)
	b.alert = maxf(b.alert, 3.0)
	b.last_seen = Vector2(pos.x, pos.z)
	if b.hp <= 0:
		b.state = "down"
		b.t = 0.0
		b.hp = 0
		b.crouch = false
		stats["kills"] += 1
		b.bar_bg.visible = false
		b.bar_fill.visible = false
		_add_decal(b.node.position.x, b.node.position.z)
		if not arena_mode:
			_spawn_pickup(b.node.position.x, b.node.position.z, 24, 4, 0.0, true)
	else:
		var u := float(b.hp) / b.max_hp
		b.bar_fill.scale = Vector3(maxf(0.05, u), 1, 1)
		(b.bar_fill.material_override as StandardMaterial3D).albedo_color = Color(0.77, 0.36, 0.29) if u < 0.35 else Color(0.49, 0.73, 0.35)


func _hurt_player(amount: float) -> void:
	if mission_over:
		return
	hp -= amount * cover_dr
	last_hit = _now()
	vig_hit = 1.0
	synth.play("hurt", 0.5)
	if hp <= 0.0:
		_fail()


func _fire() -> void:
	if not _game_active() or stance == "vault" or reload_t > 0.0:
		return
	var w := _cur_wep()
	if mag <= 0:
		if reserve <= 0:
			synth.play("empty", 0.6)
		else:
			_start_reload()
		return
	if burst_wait > 0.0:
		return
	var now := Time.get_ticks_msec()
	if now - last_shot < _fire_ms(w):
		return
	var first := now - last_shot > 350 or burst_count == 0
	last_shot = now
	mag -= 1
	stats["shots"] += 1
	burst_count += 1
	if int(w["burst"]) > 1 and burst_count >= int(w["burst"]) and (_tb("burst") or w["short"] != "CARBINE"):
		burst_wait = w["burst_gap"]
		burst_count = 0
	var pellets: int = w["pellets"]
	var heavy := pellets > 1
	kick_p += (0.014 if heavy else 0.006) * _t("recoil")
	twitch = 1.0
	muzzle_t = 0.06
	muzzle_flash.rotation.y = randf() * TAU
	muzzle_flash.scale = Vector3.ONE * _t("flash_size")
	synth.play("sweeper" if heavy else "carbine", 0.9)
	var origin := Vector3(pos.x, 0.72 if crouch else 1.15, pos.z)
	var base_dir := Vector3(sin(yaw), -0.02, cos(yaw)).normalized()
	var muz := soldier.muzzle.global_position
	var still := aim_bloom < 0.22 and Vector2(vel.x, vel.z).length() < 0.8
	var spr := _spread(w) * (0.28 + aim_bloom * _t("bloom"))
	if still:
		spr *= 0.32
	if first and not heavy:
		spr *= 0.22
	var rng: float = w["range"]
	var any_hit := false
	for i in pellets:
		var d := base_dir
		if spr > 0.0:
			d.x += randf_range(-1, 1) * spr
			d.y += randf_range(-0.5, 0.5) * spr * 0.4
			d.z += randf_range(-1, 1) * spr
			d = d.normalized()
		var wd := _world_hit(origin, d, rng)
		var bh := _bot_hit_test(origin, d, minf(wd, rng))
		var end: Vector3
		if bh[0] != null:
			end = origin + d * float(bh[1])
			_hurt_bot(bh[0])
			any_hit = true
		else:
			end = origin + d * wd
		_spawn_tracer(muz, end)
		if bh[0] == null:
			_spawn_spark(end)
	if any_hit:
		stats["hits"] += 1
	if mag <= 0:
		_start_reload()


func _update_shoot(dt: float) -> void:
	if recently_shot > 0.0:
		recently_shot -= dt
	if burst_wait > 0.0:
		burst_wait -= dt
	var manual := aim_mag >= _fire_stick() if touch_mode else mouse_down
	var auto := _is_aiming() and assist_target != null
	if _btn_mode():
		manual = fire_held or mouse_down
		auto = _tb("autofire") and lock_target != null
	if manual or auto:
		_fire()
		if last_shot > 0:
			recently_shot = 0.22
	elif recently_shot <= 0.0:
		burst_count = 0
	if reload_t > 0.0:
		reload_t -= dt
		if reload_t <= 0.0:
			var need := int(_cur_wep()["mag"]) - mag
			var take := mini(need, reserve)
			mag += take
			reserve -= take
			if arena_mode:
				reserve = int(WEAPONS[0]["reserve"])
			reload_t = 0.0


# ---------- pickups ----------

func _update_pickups(dt: float) -> void:
	if arena_mode:
		return
	for i in range(pickups.size() - 1, -1, -1):
		var p: Pickup = pickups[i]
		if not p.live:
			if p.respawn > 0.0:
				p.wait -= dt
				if p.wait <= 0.0:
					p.live = true
					p.node.visible = true
			continue
		p.bob += dt * 2.4
		p.node.position.y = 0.02 + sin(p.bob) * 0.06
		p.node.rotation.y += dt * 0.9
		if not _game_active() or _ammo_full():
			continue
		if Vector2(pos.x - p.pos.x, pos.z - p.pos.y).length() > 1.05:
			continue
		_add_reserve(0, p.carbine)
		_add_reserve(1, p.sweeper)
		synth.play("pickup", 0.8)
		p.live = false
		p.node.visible = false
		if p.drop:
			p.node.queue_free()
			pickups.remove_at(i)
		else:
			p.wait = p.respawn


# ---------- bots ----------

func _bot_see(b: Bot) -> float:
	var dx := pos.x - b.node.position.x
	var dz := pos.z - b.node.position.z
	var dist := sqrt(dx * dx + dz * dz)
	if dist > 26.0 or hp <= 0.0:
		return -1.0
	if _los_blocked(b.node.position.x, b.node.position.z, pos.x, pos.z):
		return -1.0
	return dist


func _move_bot(b: Bot, tx: float, tz: float, speed: float, dt: float) -> bool:
	var dx := tx - b.node.position.x
	var dz := tz - b.node.position.z
	var dist := sqrt(dx * dx + dz * dz)
	if dist < 0.22:
		return true
	var h := _collide_xz(b.node.position.x + dx / dist * speed * dt, b.node.position.z + dz / dist * speed * dt, 0.36)
	b.node.position.x = h.x
	b.node.position.z = h.y
	b.node.rotation.y = _damp_angle(b.node.rotation.y, atan2(dx, dz), 7.0, dt)
	return false


func _cover_point(b: Bot) -> Variant:
	var best: Variant = null
	var bd := 12.0
	for o in obstacles:
		if not _low_cover(o):
			continue
		var mx := (o.min_x + o.max_x) * 0.5
		var mz := (o.min_z + o.max_z) * 0.5
		var dist := Vector2(b.node.position.x - mx, b.node.position.z - mz).length()
		if dist > 9.0 or dist < 0.2:
			continue
		var away := Vector2(mx - pos.x, mz - pos.z)
		var n := maxf(away.length(), 1e-4)
		var px := mx + away.x / n * ((o.max_x - o.min_x) * 0.5 + 0.6)
		var pz := mz + away.y / n * ((o.max_z - o.min_z) * 0.5 + 0.6)
		if _blocked_at(px, pz, 0.35):
			continue
		if dist < bd:
			bd = dist
			best = Vector2(px, pz)
	return best


func _enemy_fire(b: Bot) -> void:
	var err := (1.0 - _t("enemy_acc") / 100.0) * 0.2
	var y := b.node.rotation.y + randf_range(-err, err)
	var origin := Vector3(b.node.position.x, 0.72 if b.crouch else 1.15, b.node.position.z)
	var d := Vector3(sin(y), -0.02, cos(y)).normalized()
	var wd := _world_hit(origin, d, 28.0)
	var ph := _player_hit_test(origin, d, wd)
	var end: Vector3
	if ph >= 0.0:
		end = origin + d * ph
		_hurt_player(6.0)
	else:
		end = origin + d * minf(wd, 20.0)
	_spawn_tracer(b.node.muzzle.global_position, end)
	_spawn_spark(end)
	var dist := Vector2(b.node.position.x - pos.x, b.node.position.z - pos.z).length()
	synth.play("enemy", 1.0 / (1.0 + dist * 0.14))


func _update_bots(dt: float) -> void:
	var hear := recently_shot > 0.0 or (Time.get_ticks_msec() - last_shot < 400)
	var cands: Array = []
	for b in bots:
		if b.flash > 0.0:
			b.flash -= dt
			var dur := maxf(_t("hit_flash") / 1000.0, 0.001)
			b.node.set_flash(0.12 * clampf(b.flash / dur, 0.0, 1.0), 1.0)
		if b.state == "down":
			b.t += dt
			b.crouch = false
			if arena_mode and b.t > RESPAWN_S:
				_arena_respawn(b)
			continue
		if arena_mode and not settings["enemy_active"]:
			b.state = "idle"
			b.alert = 0.0
			b.crouch = false
			b.node.rotation.y = _damp_angle(b.node.rotation.y, atan2(pos.x - b.node.position.x, pos.z - b.node.position.z), 4.0, dt)
			continue
		b.shoot_cd = maxf(0.0, b.shoot_cd - dt)
		var see := _bot_see(b)
		var dist := Vector2(pos.x - b.node.position.x, pos.z - b.node.position.z).length()
		if see >= 0.0 or (hear and dist < 32.0):
			b.alert = 3.5
			b.last_seen = Vector2(pos.x, pos.z)
		else:
			b.alert = maxf(0.0, b.alert - dt)
		if b.alert > 0.0 and see >= 0.0 and see < 15.0:
			cands.append([b, see])
		if b.alert <= 0.0:
			b.state = "patrol"
		elif see >= 0.0 and see < 15.0:
			b.state = "shoot"
		else:
			b.state = "cover"
	cands.sort_custom(func(a: Array, c: Array) -> bool: return float(a[1]) < float(c[1]))
	var allowed: Array = []
	for i in mini(2, cands.size()):
		allowed.append(cands[i][0])

	for b in bots:
		if b.state == "down" or b.state == "idle":
			continue
		if b.state == "patrol":
			b.crouch = false
			var wp: Vector2 = b.waypoints[b.wp]
			if _move_bot(b, wp.x, wp.y, 2.1, dt):
				b.wp = (b.wp + 1) % b.waypoints.size()
			continue
		var want := atan2(pos.x - b.node.position.x, pos.z - b.node.position.z)
		if b.state == "cover":
			var pt: Variant = _cover_point(b)
			if pt == null:
				pt = b.last_seen
			var v: Vector2 = pt
			_move_bot(b, v.x, v.y, 3.6, dt)
			b.crouch = _near_low_cover(b.node.position.x, b.node.position.z, 0.95) != null
			if b.crouch:
				b.node.rotation.y = _damp_angle(b.node.rotation.y, want, 6.0, dt)
			continue
		var cover: Variant = _cover_point(b)
		var d2 := Vector2(pos.x - b.node.position.x, pos.z - b.node.position.z).length()
		if cover != null and d2 > 7.0:
			var cv: Vector2 = cover
			b.crouch = _move_bot(b, cv.x, cv.y, 3.8, dt)
		else:
			b.crouch = _near_low_cover(b.node.position.x, b.node.position.z, 0.95) != null
		b.node.rotation.y = _damp_angle(b.node.rotation.y, want, 8.0, dt)
		if _game_active() and allowed.has(b) and b.shoot_cd <= 0.0 and _bot_see(b) >= 0.0:
			_enemy_fire(b)
			b.shoot_cd = 0.85 + randf() * 0.35


func _pose_bots(dt: float) -> void:
	for b in bots:
		var p2 := Vector2(b.node.position.x, b.node.position.z)
		b.spd = (p2 - b.prev).length() / maxf(dt, 1e-4)
		b.prev = p2
		b.bob += b.spd * dt * 1.7
		b.node.pose(dt, 0.0 if b.state == "down" else b.spd, b.bob, 0.0, 0.0, b.crouch, -1.0, b.state == "shoot", b.state == "down", -1.0)


# ---------- fx ----------

func _spawn_tracer(a: Vector3, b: Vector3) -> void:
	for t in tracers:
		if float(t["life"]) > 0.0:
			continue
		var d := b - a
		var l := d.length()
		if l < 0.05:
			return
		t["a"] = a
		t["dir"] = d / l
		t["dist"] = l
		t["t"] = 0.0
		t["speed"] = _t("tracer_speed")
		t["life"] = l / _t("tracer_speed") + TRACER_LEN / _t("tracer_speed") + 0.01
		_place_tracer(t)
		return


func _place_tracer(t: Dictionary) -> void:
	var n: MeshInstance3D = t["node"]
	var dist: float = t["dist"]
	var head := minf(float(t["t"]) * float(t["speed"]), dist)
	var tail := maxf(0.0, float(t["t"]) * float(t["speed"]) - TRACER_LEN)
	var seg := head - tail
	if seg < 0.02:
		n.visible = false
		return
	var dir: Vector3 = t["dir"]
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	var a: Vector3 = t["a"]
	n.transform = Transform3D(Basis.looking_at(dir, up) * Basis.from_scale(Vector3(1, 1, seg)), a + dir * ((head + tail) * 0.5))
	n.visible = true


func _spawn_spark(p: Vector3) -> void:
	var want := int(round(_t("spark_n")))
	for s in sparks:
		if want <= 0:
			return
		if float(s["life"]) > 0.0:
			continue
		var n: MeshInstance3D = s["node"]
		n.position = p
		n.visible = true
		s["life"] = 0.18 + randf() * 0.12
		s["v"] = Vector3(randf_range(-3, 3), randf_range(1.5, 4), randf_range(-3, 3))
		want -= 1


func _update_fx(dt: float) -> void:
	for t in tracers:
		if float(t["life"]) <= 0.0:
			continue
		t["life"] = float(t["life"]) - dt
		t["t"] = float(t["t"]) + dt
		if float(t["life"]) <= 0.0:
			(t["node"] as Node3D).visible = false
		else:
			_place_tracer(t)
	for s in sparks:
		if float(s["life"]) <= 0.0:
			continue
		s["life"] = float(s["life"]) - dt
		var n: Node3D = s["node"]
		var v: Vector3 = s["v"]
		v.y -= 9.0 * dt
		s["v"] = v
		n.position += v * dt
		if float(s["life"]) <= 0.0:
			n.visible = false
	if muzzle_t > 0.0:
		muzzle_t -= dt
		muzzle_flash.global_position = soldier.muzzle.global_position
		muzzle_flash.visible = muzzle_t > 0.0 and _t("flash_size") > 0.01
	else:
		muzzle_flash.visible = false


# ---------- camera ----------

static func zoom_t(z: float) -> float:
	var t := clampf(z / 100.0, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _look_y(s: float) -> float:
	return 1.48 * s + (0.8 * (1.0 - s) if _north_up() else 0.0)


func _cam_ahead(s: float) -> float:
	var base := _t("cam_ahead")
	return lerpf(base if (_follow_view() or _north_up()) else base * 0.68, 2.05, s)


func _camera_target(s: float) -> Vector3:
	if _north_up():
		view_yaw = 0.0
		view_pitch = 0.0
	var rigid := _north_up()
	var dist := lerpf(_cam_dist() if (_follow_view() or rigid) else _cam_dist() * 1.21, 4.9, s)
	var ahead := _cam_ahead(s)
	var tilt := lerpf(_cam_tilt(), 0.2792527, s) + view_pitch * (1.0 - 0.6 * s)
	var look_y := _look_y(s)
	var fwd := Vector3(-sin(view_yaw), 0, -cos(view_yaw))
	var right := Vector3(cos(view_yaw), 0, -sin(view_yaw))
	var look := Vector3(pos.x, look_y, pos.z) + fwd * ahead
	var want := look - fwd * (dist * cos(tilt)) + right * (0.42 * s)
	want.y = look_y + dist * sin(tilt) * (1.0 - s) + (1.88 - look_y) * s
	var dv := want - look
	var l := dv.length()
	if l > 0.2 and not rigid:
		var dn := dv / l
		var hd := _world_hit(look, dn, l)
		if hd < l - 0.12:
			want = look + dn * maxf(0.9, hd - 0.28)
	return want


func _update_camera(dt: float) -> void:
	zoom_show = _damp(zoom_show, float(settings["zoom"]), 10.0, dt)
	var s := zoom_t(zoom_show)
	var want := _camera_target(s)
	var lag := _t("cam_lag")
	if lag <= 0.001:
		cam_pos = want
	else:
		cam_pos = cam_pos.lerp(want, 1.0 - exp(-(16.0 if (look_held or s > 0.35) else 1.0 / lag) * dt))
	kick_p = _damp(kick_p, 0.0, 10.0, dt)
	var fwd := Vector3(-sin(view_yaw), 0, -cos(view_yaw))
	var look := Vector3(pos.x, _look_y(s), pos.z) + fwd * _cam_ahead(s)
	var d := cam_pos - look
	var hy := Vector2(d.x, d.z).length()
	camera.position = cam_pos
	camera.rotation = Vector3(-atan2(d.y, maxf(0.15, hy)) + kick_p * 0.25, atan2(d.x, d.z), 0)
	var fov := _t("cam_fov") + (3.0 if (_sprinting(_wish()) and not _north_up()) else 0.0) + 4.0 * s
	camera.fov = fov if _north_up() else _damp(camera.fov, fov, 6.0, dt)
	fill_light.position = Vector3(pos.x, 3.2, pos.z)


# ---------- frame ----------

func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	if _save_wait >= 0.0:
		_save_wait -= delta
		if _save_wait < 0.0:
			_save_settings()
	if _game_active():
		_update_look(dt)
		_update_move(dt)
		_update_cover()
		_update_shoot(dt)
		_update_bots(dt)
		if not arena_mode:
			_update_mates(dt)
		_update_pickups(dt)
		var ex := Vector2(pos.x - EXTRACT.x, pos.z - EXTRACT.z)
		if not arena_mode and hp > 0.0 and ex.length() <= EXTRACT_R:
			_complete()
		if hp < max_hp and _now() - last_hit > 4.0:
			hp = minf(max_hp, hp + 12.0 * dt)
	elif playing and not paused:
		_update_bots(dt)
	_pose_bots(dt)
	if not arena_mode:
		_pose_mates(dt)
	_update_player_visual(dt)
	_update_camera(dt)
	_update_fx(dt)
	_update_hud()
	_update_fx_layer(dt)
	ui.tick(dt)


func _update_player_visual(dt: float) -> void:
	slide_mix = _damp(slide_mix, 1.0 if stance == "slide" else 0.0, 12.0, dt)
	twitch = _damp(twitch, 0.0, 20.0, dt)
	var fdir := Vector3(sin(yaw), 0, cos(yaw))
	var tw := twitch * _t("twitch")
	soldier.position = pos - fdir * (0.16 * tw)
	soldier.rotation.y = yaw + sin(Time.get_ticks_msec() * 0.09) * 0.05 * tw
	var vu := -1.0
	if not vault.is_empty():
		vu = float(vault["t"]) / float(vault["dur"])
	var ru := -1.0
	if reload_t > 0.0:
		ru = 1.0 - reload_t / float(_cur_wep()["reload"])
	var aiming := _is_aiming() or recently_shot > 0.0
	soldier.pose(dt, Vector2(vel.x, vel.z).length(), bob, slide_mix, slide_side, crouch, vu, aiming, hp <= 0.0, ru)
	var btn := _btn_mode()
	var show_aim := playing and not paused and not mission_over and (aiming or not touch_mode) and not btn
	var show_laser := btn and _tb("laser") and lock_target != null and playing and not mission_over and hp > 0.0
	laser.visible = show_laser
	if show_laser:
		var from := soldier.muzzle.global_position
		var to := Vector3(lock_target.node.position.x, 1.0, lock_target.node.position.z)
		var dv := to - from
		var ln := dv.length()
		if ln > 0.1:
			laser.transform = Transform3D(Basis.looking_at(dv / ln, Vector3.UP) * Basis.from_scale(Vector3(1, 1, ln)), (from + to) * 0.5)
	aim_line.visible = show_aim
	if show_aim:
		var len := 7.0
		var w := 0.05 + aim_bloom * 0.3
		var f := Vector3(sin(yaw), 0, cos(yaw))
		aim_line.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(w, 1, len)), pos + f * (len * 0.5 + 0.6) + Vector3(0, 0.03, 0))
		var locked := assist_target != null and _is_aiming()
		aim_line_mat.albedo_color = Color(1.0, 0.76, 0.29, 0.75) if locked else Color(1.0, 0.88, 0.54, 0.45 + (1.0 - aim_bloom) * 0.25)
	aim_mark.visible = show_aim and assist_target != null and _is_aiming() and not btn
	if aim_mark.visible:
		aim_mark.position = Vector3(aim_point.x, 0.05, aim_point.z)


func _update_fx_layer(dt: float) -> void:
	if not ui.hud.visible:
		return
	vig_hit = maxf(0.0, vig_hit - dt / 0.5)
	var base := _t("vignette") / 100.0
	var low := clampf((0.4 - hp / max_hp) / 0.4, 0.0, 1.0) * 0.5 * (0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.008))
	var va := base * clampf(vig_hit + low, 0.0, 1.0)
	var list: Array = []
	for b in bots:
		list.append({"world": b.node.position, "name": b.label, "alive": b.state != "down"})
	var lk: Variant = null
	if lock_target != null and _btn_mode() and lock_target.state != "down" and playing:
		lk = lock_target.node.position
	ui.fx.refresh(dt, list, lk, va)


func _update_hud() -> void:
	if not ui.hud.visible:
		return
	var w := _cur_wep()
	ui.ammo_label.text = "%d / %d" % [mag, reserve]
	ui.set_mag(mag, int(w["mag"]))
	ui.wep_label.text = String(w["short"])
	ui.low_label.visible = mag <= int(w["mag"]) / 4 and reload_t <= 0.0
	ui.cover_label.visible = in_cover
	ui.reload_label.visible = reload_t > 0.0
	ui.set_hp(hp / max_hp)
	var kills: int = stats["kills"]
	var dist := int(Vector2(pos.x - EXTRACT.x, pos.z - EXTRACT.z).length())
	ui.hint_label.modulate.a = clampf(1.0 - (_now() - float(stats["start"]) - 12.0) / 2.0, 0.0, 1.0)
	if arena_mode:
		ui.obj_label.text = "TUNING ARENA %s · Enemy: %s · Downs %d" % [VERSION, "Active AI" if settings["enemy_active"] else "Static", kills]
	else:
		ui.obj_label.text = "Reach the north extract · %dm · Downs %d" % [dist, kills]
