extends Node3D
## Pipe Hitters: twin-stick compound run. Everything is built in code.

const WALK := 5.6
const SPRINT := 8.6
const SLIDE_BOOST := 11.2
const SLIDE_DUR := 1.74
const ACCEL := 32.0
const FRICTION := 12.0
const RADIUS := 0.36
const VAULT_MAX := 1.15
const VAULT_MIN := 0.32
const CAM_TILT := 1.0471976
const CAM_DIST := 16.5
const AIM_DEAD := 0.16
const FIRE_STICK := 0.4
const AIM_RANGE := 22.0
const START := Vector3(0, 0, 87.5)
const START_YAW := PI
const EXTRACT := Vector3(0, 0, -88)
const EXTRACT_R := 4.6
const AIM_CONE := 0.2443461
const AIM_SPEED := 0.5
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


var settings := {"invert_move": false, "landscape": false, "fullscreen": false, "aim_sens": 70.0, "assist": 70.0, "volume": 70.0, "facing": "follow", "zoom": 0.0}

var level: Level
var obstacles: Array[Obstacle] = []
var bots: Array[Bot] = []
var pickups: Array[Pickup] = []
var soldier: Soldier
var camera: Camera3D
var sun: DirectionalLight3D
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
var muzzle_flash: MeshInstance3D
var muzzle_t := 0.0
var aim_line: MeshInstance3D
var aim_line_mat: StandardMaterial3D
var aim_mark: MeshInstance3D


func _ready() -> void:
	_load_settings()
	zoom_show = settings["zoom"]
	_build_env()
	level = Level.new(self)
	level.build(START, EXTRACT)
	obstacles = level.obstacles
	soldier = Soldier.new()
	soldier.setup(Color8(86, 96, 74), Color8(70, 74, 60), Color8(64, 72, 54), Color8(78, 86, 66), Color8(52, 56, 44), Color8(214, 178, 146), Color8(38, 40, 42))
	add_child(soldier)
	_build_bots()
	_build_pickups()
	_build_fx()
	synth = Synth.new()
	add_child(synth)
	ui = GameUI.new()
	add_child(ui)
	ui.deploy.connect(_start_play)
	ui.resume.connect(func() -> void: _set_paused(false))
	ui.retry.connect(_retry)
	ui.restart.connect(_retry)
	ui.reset_view.connect(_reset_view)
	ui.setting_changed.connect(_on_setting)
	ui.hud.visible = false
	ui.sync(settings)
	_apply_volume()
	_reset_mission()
	cam_pos = _camera_target(0.0)
	if OS.has_feature("web_android") or OS.has_feature("web_ios") or DisplayServer.is_touchscreen_available():
		_set_touch_mode(true)


# ---------- setup ----------

func _build_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color8(138, 148, 140)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color8(176, 190, 196)
	env.ambient_light_energy = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color8(138, 148, 140)
	env.fog_density = 0.0085
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-52), deg_to_rad(32), 0)
	sun.light_energy = 0.95
	sun.light_color = Color8(255, 244, 222)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 42.0
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = 52
	camera.near = 0.1
	camera.far = 260
	add_child(camera)
	camera.make_current()


func _build_bots() -> void:
	var specs := [
		[-5, 79, 0.2, [-3, 77, -8, 82]], [6, 75, -0.3, [8, 73, 3, 78]],
		[0, 20, 0.2, [3, 18, -3, 23]], [8, 9, -0.4, [10, 7, 5, 12]], [-11, 4, 2.2, [-9, 2, -14, 7]],
		[-18, -29, 1.0, [-16, -26, -22, -32]], [-35, -44, 0.4, [-32, -41, -38, -48]],
		[-6, -84, 0.1, [-4, -81, -9, -87]], [7, -86, -0.2, [9, -83, 4, -88]],
	]
	var bar_bg_mat := _flat_mat(Color(0.16, 0.13, 0.11))
	bar_bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bar_bg_mat.billboard_keep_scale = true
	for s in specs:
		var b := Bot.new()
		b.node = Soldier.new()
		b.node.setup(Color8(150, 82, 52), Color8(106, 58, 40), Color8(120, 66, 44), Color8(90, 52, 36), Color8(60, 40, 30), Color8(226, 201, 168), Color8(42, 36, 32))
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
		bots.append(b)


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
	var tm := _flat_mat(Color(1.0, 0.85, 0.5))
	var tb := BoxMesh.new()
	tb.size = Vector3(0.035, 0.035, 1.0)
	for i in 24:
		var m := MeshInstance3D.new()
		m.mesh = tb
		m.material_override = tm
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
		tracers.append({"node": m, "life": 0.0})
	var sm := _flat_mat(Color(0.95, 0.82, 0.55))
	var sb := BoxMesh.new()
	sb.size = Vector3(0.09, 0.09, 0.09)
	for i in 18:
		var m := MeshInstance3D.new()
		m.mesh = sb
		m.material_override = sm
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
		sparks.append({"node": m, "life": 0.0, "v": Vector3.ZERO})
	muzzle_flash = MeshInstance3D.new()
	var fs := SphereMesh.new()
	fs.radius = 0.1
	fs.height = 0.2
	muzzle_flash.mesh = fs
	muzzle_flash.material_override = _flat_mat(Color(1.0, 0.86, 0.45))
	muzzle_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle_flash.visible = false
	add_child(muzzle_flash)
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


# ---------- settings ----------

func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		for k in settings.keys():
			settings[k] = cf.get_value("s", k, settings[k])
	settings["zoom"] = clampf(float(settings["zoom"]), 0.0, 100.0)
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
			settings[key] = float(value)
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
	_reset_mission()
	playing = true
	paused = false
	ui.start_panel.visible = false
	ui.hud.visible = true


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
	ui.pause_panel.visible = on
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
	_update_stick_draw()


func _reset_mission() -> void:
	_clear_touches()
	view_yaw = 0.0
	view_pitch = 0.0
	pos = START
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
		b.hp = b.max_hp
		b.state = "patrol"
		b.t = 0.0
		b.flash = 0.0
		b.crouch = false
		b.alert = 0.0
		b.wp = 0
		b.shoot_cd = randf() * 0.8
		b.node.position = Vector3(b.home.x, 0, b.home.y)
		b.node.rotation = Vector3(0, b.facing, 0)
		b.prev = b.home
		b.spd = 0.0
		b.node.set_flash(0.0)
		b.bar_bg.visible = true
		b.bar_fill.visible = true
		b.bar_fill.scale = Vector3.ONE
		b.node.k_down = 0.0
	for i in range(pickups.size() - 1, -1, -1):
		var p: Pickup = pickups[i]
		if p.drop:
			p.node.queue_free()
			pickups.remove_at(i)
		else:
			p.live = true
			p.wait = 0.0
			p.node.visible = true
	soldier.k_down = 0.0
	cam_pos = _camera_target(0.0)


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
	if k == KEY_ESCAPE or k == KEY_P:
		if playing and not mission_over:
			_set_paused(not paused)
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
		if b != "":
			_touch_button(b)
			get_viewport().set_input_as_handled()
			return
	if not _game_active():
		if not e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			mouse_down = false
		return
	match e.button_index:
		MOUSE_BUTTON_LEFT:
			mouse_down = e.pressed
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


func _on_touch(e: InputEventScreenTouch) -> void:
	_set_touch_mode(true)
	var p := e.position
	if e.pressed:
		if not _game_active():
			return
		var b := ui.touch_button_at(p)
		if b != "":
			_touch_button(b)
			return
		if move_id < 0 and p.distance_to(ui.stick_center(0)) < STICK_HIT:
			move_id = e.index
			_set_stick(0, p)
			return
		if aim_id < 0 and p.distance_to(ui.stick_center(1)) < STICK_HIT:
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
	var w := maxf(ui.screen_size().x, 1.0)
	view_yaw -= d.x * 1.35 * PI / w
	view_pitch = clampf(view_pitch + d.y * 0.7 / w, VIEW_PITCH_MIN, VIEW_PITCH_MAX)
	look_moved += d.length()


func _reset_view() -> void:
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
		if tall_only and ob.h < 1.2:
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
	if touch_mode:
		return aim_mag > AIM_DEAD
	return mouse_down or assist_target != null


func _stick_world_yaw() -> float:
	var w := screen_to_world(aim_v.x, -aim_v.y, view_yaw)
	return atan2(w.x, w.y)


func _stick_curve(m: float) -> float:
	var t := clampf((m - AIM_DEAD) / (1.0 - AIM_DEAD), 0.0, 1.0)
	return t * t


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
		if absf(_wrap(_stick_world_yaw() - atan2(off[2], off[3]))) > AIM_CONE * 1.6:
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
	var cone := AIM_CONE * (0.75 + 0.35 * strength)
	if _assist_valid(sticky_assist, cone * 1.85):
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


func _update_look(dt: float) -> void:
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
	var acc := minf(add, ACCEL * dt * (speed / WALK))
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
	vel.x = d.x * SLIDE_BOOST
	vel.z = d.z * SLIDE_BOOST
	slide_side = d.y
	stance = "slide"
	slide_t = SLIDE_DUR
	synth.play("thud", 0.35)


func _slide_speed(t_left: float) -> float:
	var u := 1.0 - clampf(t_left / SLIDE_DUR, 0.0, 1.0)
	return SLIDE_BOOST * (1.0 - 0.38 * u * u)


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
	var sprint := not aiming and _sprinting(w)
	var speed := SLIDE_BOOST if stance == "slide" else (SPRINT if sprint else WALK)
	if aiming and stance != "slide":
		speed *= AIM_SPEED
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
		_apply_friction(dt, FRICTION * 0.45)
		_accelerate(w.x, w.z, speed * w.y, dt)
	else:
		_apply_friction(dt, FRICTION * 1.35)

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
	if not _game_active() or i == wep or i < 0 or i >= WEAPONS.size():
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
	b.flash = 0.12
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
	if now - last_shot < float(w["fire_ms"]):
		return
	var first := now - last_shot > 350 or burst_count == 0
	last_shot = now
	mag -= 1
	stats["shots"] += 1
	burst_count += 1
	if int(w["burst"]) > 1 and burst_count >= int(w["burst"]):
		burst_wait = w["burst_gap"]
		burst_count = 0
	var pellets: int = w["pellets"]
	var heavy := pellets > 1
	kick_p += 0.014 if heavy else 0.006
	muzzle_t = 0.045
	synth.play("sweeper" if heavy else "carbine", 0.9)
	var origin := Vector3(pos.x, 0.72 if crouch else 1.15, pos.z)
	var base_dir := Vector3(sin(yaw), -0.02, cos(yaw)).normalized()
	var muz := soldier.muzzle.global_position
	var still := aim_bloom < 0.22 and Vector2(vel.x, vel.z).length() < 0.8
	var spr := float(w["spread"]) * (0.28 + aim_bloom * 1.35)
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
	var manual := aim_mag >= FIRE_STICK if touch_mode else mouse_down
	var auto := _is_aiming() and assist_target != null
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
			reload_t = 0.0


# ---------- pickups ----------

func _update_pickups(dt: float) -> void:
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
	var y := b.node.rotation.y + randf_range(-0.1, 0.1)
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
			b.node.set_flash(maxf(b.flash, 0.0))
		if b.state == "down":
			b.t += dt
			b.crouch = false
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
		if b.state == "down":
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
		var n: MeshInstance3D = t["node"]
		var d := b - a
		var l := d.length()
		if l < 0.05:
			return
		var up := Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT
		n.transform = Transform3D(Basis.looking_at(d / l, up) * Basis.from_scale(Vector3(1, 1, l)), (a + b) * 0.5)
		n.visible = true
		t["life"] = 0.07
		return


func _spawn_spark(p: Vector3) -> void:
	for s in sparks:
		if float(s["life"]) > 0.0:
			continue
		var n: MeshInstance3D = s["node"]
		n.position = p
		n.visible = true
		s["life"] = 0.18
		s["v"] = Vector3(randf_range(-2, 2), randf_range(1, 3), randf_range(-2, 2))
		return


func _update_fx(dt: float) -> void:
	for t in tracers:
		if float(t["life"]) <= 0.0:
			continue
		t["life"] = float(t["life"]) - dt
		if float(t["life"]) <= 0.0:
			(t["node"] as Node3D).visible = false
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
		muzzle_flash.visible = muzzle_t > 0.0
	else:
		muzzle_flash.visible = false


# ---------- camera ----------

static func zoom_t(z: float) -> float:
	var t := clampf(z / 100.0, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _camera_target(s: float) -> Vector3:
	var follow := _follow_view()
	var dist := lerpf(13.6 if follow else CAM_DIST, 4.9, s)
	var ahead := lerpf(3.15 if follow else 2.15, 2.05, s)
	var tilt := lerpf(CAM_TILT, 0.2792527, s) + view_pitch * (1.0 - 0.6 * s)
	var look_y := 1.48 * s
	var fwd := Vector3(-sin(view_yaw), 0, -cos(view_yaw))
	var right := Vector3(cos(view_yaw), 0, -sin(view_yaw))
	var look := Vector3(pos.x, look_y, pos.z) + fwd * ahead
	var want := look - fwd * (dist * cos(tilt)) + right * (0.42 * s)
	want.y = look_y + dist * sin(tilt) * (1.0 - s) + (1.88 - look_y) * s
	var dv := want - look
	var l := dv.length()
	if l > 0.2:
		var dn := dv / l
		var hd := _world_hit(look, dn, l)
		if hd < l - 0.12:
			want = look + dn * maxf(0.9, hd - 0.28)
	return want


func _update_camera(dt: float) -> void:
	zoom_show = _damp(zoom_show, float(settings["zoom"]), 10.0, dt)
	var s := zoom_t(zoom_show)
	var want := _camera_target(s)
	cam_pos = cam_pos.lerp(want, 1.0 - exp(-(16.0 if (look_held or s > 0.35) else 8.5) * dt))
	kick_p = _damp(kick_p, 0.0, 10.0, dt)
	var fwd := Vector3(-sin(view_yaw), 0, -cos(view_yaw))
	var ahead := lerpf(3.15 if _follow_view() else 2.15, 2.05, s)
	var look := Vector3(pos.x, 1.48 * s, pos.z) + fwd * ahead
	var d := cam_pos - look
	var hy := Vector2(d.x, d.z).length()
	camera.position = cam_pos
	camera.rotation = Vector3(-atan2(d.y, maxf(0.15, hy)) + kick_p * 0.25, atan2(d.x, d.z), 0)
	var fov := (55.0 if _sprinting(_wish()) else 52.0) + 4.0 * s
	camera.fov = _damp(camera.fov, fov, 6.0, dt)
	sun.global_position = Vector3(pos.x, 0, pos.z)


# ---------- frame ----------

func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	if _game_active():
		_update_look(dt)
		_update_move(dt)
		_update_cover()
		_update_shoot(dt)
		_update_bots(dt)
		_update_pickups(dt)
		var ex := Vector2(pos.x - EXTRACT.x, pos.z - EXTRACT.z)
		if hp > 0.0 and ex.length() <= EXTRACT_R:
			_complete()
		if hp < max_hp and _now() - last_hit > 4.0:
			hp = minf(max_hp, hp + 12.0 * dt)
	elif playing and not paused:
		_update_bots(dt)
	_pose_bots(dt)
	_update_player_visual(dt)
	_update_camera(dt)
	_update_fx(dt)
	_update_hud()


func _update_player_visual(dt: float) -> void:
	slide_mix = _damp(slide_mix, 1.0 if stance == "slide" else 0.0, 12.0, dt)
	soldier.position = pos
	soldier.rotation.y = yaw
	var vu := -1.0
	if not vault.is_empty():
		vu = float(vault["t"]) / float(vault["dur"])
	var ru := -1.0
	if reload_t > 0.0:
		ru = 1.0 - reload_t / float(_cur_wep()["reload"])
	var aiming := _is_aiming() or recently_shot > 0.0
	soldier.pose(dt, Vector2(vel.x, vel.z).length(), bob, slide_mix, slide_side, crouch, vu, aiming, hp <= 0.0, ru)
	var show_aim := playing and not paused and not mission_over and (aiming or not touch_mode)
	aim_line.visible = show_aim
	if show_aim:
		var len := 7.0
		var w := 0.05 + aim_bloom * 0.3
		var f := Vector3(sin(yaw), 0, cos(yaw))
		aim_line.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(w, 1, len)), pos + f * (len * 0.5 + 0.6) + Vector3(0, 0.03, 0))
		var locked := assist_target != null and _is_aiming()
		aim_line_mat.albedo_color = Color(1.0, 0.76, 0.29, 0.75) if locked else Color(1.0, 0.88, 0.54, 0.45 + (1.0 - aim_bloom) * 0.25)
	aim_mark.visible = show_aim and assist_target != null and _is_aiming()
	if aim_mark.visible:
		aim_mark.position = Vector3(aim_point.x, 0.05, aim_point.z)


func _update_hud() -> void:
	if not ui.hud.visible:
		return
	var w := _cur_wep()
	ui.ammo_label.text = "%d / %d" % [mag, reserve]
	ui.wep_label.text = String(w["short"])
	ui.low_label.visible = mag <= int(w["mag"]) / 4 and reload_t <= 0.0
	ui.cover_label.visible = in_cover
	ui.reload_label.visible = reload_t > 0.0
	ui.set_hp(hp / max_hp)
	var kills: int = stats["kills"]
	var dist := int(Vector2(pos.x - EXTRACT.x, pos.z - EXTRACT.z).length())
	ui.hint_label.modulate.a = clampf(1.0 - (_now() - float(stats["start"]) - 12.0) / 2.0, 0.0, 1.0)
	ui.obj_label.text = "Reach the north extract · %dm · Downs %d" % [dist, kills]
