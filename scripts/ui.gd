class_name GameUI
extends CanvasLayer
## HUD, touch sticks/buttons, start, pause, win and downed screens. Built in code.

signal deploy
signal resume
signal retry
signal restart
signal reset_view
signal setting_changed(key: String, value: Variant)

const STICK_R := 66.0

var root: Control
var hud: Control
var ammo_label: Label
var wep_label: Label
var hp_back: ColorRect
var hp_fill: ColorRect
var obj_label: Label
var low_label: Label
var cover_label: Label
var reload_label: Label
var hint_label: Label
var sticks: StickPad
var tbtns := {}
var start_panel: Control
var pause_panel: Control
var done_panel: Control
var fail_panel: Control
var done_stats: Label
var opt := {}
var opt_val := {}
var touch_mode := false
var _syncing := false


class StickPad extends Control:
	var centers: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
	var knobs: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
	var active: Array[bool] = [false, false]
	var r := 66.0

	func _draw() -> void:
		for i in 2:
			draw_circle(centers[i], r, Color(0, 0, 0, 0.16))
			draw_arc(centers[i], r, 0, TAU, 48, Color(1, 1, 1, 0.38), 2.5, true)
			if i == 1:
				draw_arc(centers[i], r * 0.4, 0, TAU, 32, Color(1, 0.78, 0.35, 0.35), 2.0, true)
			var a := 0.5 if active[i] else 0.3
			draw_circle(centers[i] + knobs[i] * r, r * 0.42, Color(1, 1, 1, a))


func _ready() -> void:
	layer = 5
	var theme := Theme.new()
	theme.default_font_size = 22
	root = Control.new()
	root.theme = theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_hud()
	_build_start()
	_build_pause()
	_build_done()
	_build_fail()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _label(parent: Control, text: String, size: int, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	obj_label = _label(hud, "Reach the north extract", 20, Color(1, 0.9, 0.6))
	hp_back = ColorRect.new()
	hp_back.color = Color(0, 0, 0, 0.5)
	hp_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hp_back)
	hp_fill = ColorRect.new()
	hp_fill.color = Color(0.49, 0.73, 0.35)
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hp_fill)
	ammo_label = _label(hud, "30 / 180", 34)
	wep_label = _label(hud, "CARBINE", 18, Color(0.85, 0.85, 0.8))
	low_label = _label(hud, "LOW AMMO", 22, Color(1, 0.45, 0.35))
	cover_label = _label(hud, "COVER", 20, Color(0.6, 0.9, 1))
	reload_label = _label(hud, "RELOADING", 22, Color(1, 0.85, 0.4))
	hint_label = _label(hud, "WASD move · Mouse aim · Click shoot · Shift sprint · Space vault · C/Ctrl slide\nR reload · Q or 1/2 swap · Right-drag orbit · Wheel zoom · Esc or P pause", 15, Color(1, 1, 1, 0.8))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sticks = StickPad.new()
	sticks.set_anchors_preset(Control.PRESET_FULL_RECT)
	sticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sticks.r = STICK_R
	hud.add_child(sticks)
	for spec in [["vault", "VAULT", 92], ["slide", "SLIDE", 92], ["swap", "SWAP", 78], ["reload", "RLD", 64], ["pause", "II", 56], ["view", "VIEW", 56]]:
		tbtns[spec[0]] = _tbtn(spec[1], spec[2])


func _tbtn(text: String, size: float) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.08, 0.45)
	sb.border_color = Color(1, 1, 1, 0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(size * 0.5))
	p.add_theme_stylebox_override("panel", sb)
	p.size = Vector2(size, size)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16 if size > 60 else 15)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	hud.add_child(p)
	return p


func _screen(title: String, body: String) -> Array:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.03, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	root.add_child(cc)
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.1, 0.94)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(22)
	sb.border_color = Color(0.9, 0.75, 0.35, 0.6)
	sb.set_border_width_all(2)
	pc.add_theme_stylebox_override("panel", sb)
	cc.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pc.add_child(vb)
	var t := _label(vb, title, 40, Color(0.95, 0.82, 0.42))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if body != "":
		var b := _label(vb, body, 19, Color(0.9, 0.92, 0.88))
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(420, 0)
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.remove_child(bg)
	root.remove_child(cc)
	holder.add_child(bg)
	holder.add_child(cc)
	root.add_child(holder)
	return [holder, vb]


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 52)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_start() -> void:
	var r := _screen("PIPE HITTERS", "Push through the compound and reach the north extract.\nLeft stick moves (camera-relative). Right stick aims; push past the ring to fire. Swipe empty space to orbit, pinch to zoom.")
	start_panel = r[0]
	_button(r[1], "Deploy", func() -> void: deploy.emit())


func _build_done() -> void:
	var r := _screen("EXTRACTED", "")
	done_panel = r[0]
	done_stats = _label(r[1], "", 22)
	done_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(r[1], "Play again", func() -> void: retry.emit())
	done_panel.visible = false


func _build_fail() -> void:
	var r := _screen("DOWNED", "You went down. Regroup and try again.")
	fail_panel = r[0]
	_button(r[1], "Try again", func() -> void: retry.emit())
	fail_panel.visible = false


func _build_pause() -> void:
	var r := _screen("PAUSED", "")
	pause_panel = r[0]
	var vb: VBoxContainer = r[1]
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(440, 420)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	sc.add_child(list)
	_button(list, "Resume", func() -> void: resume.emit())
	opt["landscape"] = _button(list, "Landscape: Off", func() -> void: setting_changed.emit("landscape", null))
	opt["fullscreen"] = _button(list, "Fullscreen: Off", func() -> void: setting_changed.emit("fullscreen", null))
	opt["invert_move"] = _button(list, "Invert move stick: Off", func() -> void: setting_changed.emit("invert_move", null))
	opt["facing"] = _button(list, "Facing: Follow view", func() -> void: setting_changed.emit("facing", null))
	_button(list, "Reset view", func() -> void: reset_view.emit())
	_slider(list, "aim_sens", "Aim sensitivity", 20, 200)
	_slider(list, "zoom", "Zoom", 0, 100)
	_slider(list, "assist", "Aim assist strength", 0, 100)
	_slider(list, "volume", "Volume", 0, 100)
	_button(list, "Restart mission", func() -> void: restart.emit())
	pause_panel.visible = false


func _slider(parent: Control, key: String, text: String, lo: float, hi: float) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := _label(row, text, 19)
	l.custom_minimum_size = Vector2(200, 0)
	var v := _label(row, "0", 19, Color(1, 0.86, 0.5))
	v.custom_minimum_size = Vector2(46, 0)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1
	s.custom_minimum_size = Vector2(170, 40)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(val: float) -> void:
		v.text = str(int(val))
		if not _syncing:
			setting_changed.emit(key, val))
	row.add_child(s)
	opt[key] = s
	opt_val[key] = v


func sync(settings: Dictionary) -> void:
	_syncing = true
	(opt["landscape"] as Button).text = "Landscape: " + ("On" if settings["landscape"] else "Off")
	(opt["fullscreen"] as Button).text = "Fullscreen: " + ("On" if settings["fullscreen"] else "Off")
	(opt["invert_move"] as Button).text = "Invert move stick: " + ("On" if settings["invert_move"] else "Off")
	(opt["facing"] as Button).text = "Facing: " + ("Follow view" if settings["facing"] == "follow" else "Free aim")
	for k in ["aim_sens", "zoom", "assist", "volume"]:
		(opt[k] as HSlider).value = float(settings[k])
		(opt_val[k] as Label).text = str(int(settings[k]))
	_syncing = false


func set_zoom_display(z: float) -> void:
	_syncing = true
	(opt["zoom"] as HSlider).value = z
	(opt_val["zoom"] as Label).text = str(int(round(z)))
	_syncing = false


func set_touch_mode(on: bool) -> void:
	touch_mode = on
	_layout()


func screen_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func stick_center(i: int) -> Vector2:
	return sticks.centers[i]


func _layout() -> void:
	if hud == null:
		return
	var s := screen_size()
	var lx := maxf(118.0, s.x * 0.12)
	var ly := s.y - maxf(118.0, s.y * 0.2)
	sticks.centers[0] = Vector2(lx, ly)
	sticks.centers[1] = Vector2(s.x - lx, ly)
	sticks.visible = touch_mode
	var rc := sticks.centers[1]
	_place_btn("slide", rc + Vector2(-150, 10))
	_place_btn("vault", rc + Vector2(-112, -112))
	_place_btn("swap", rc + Vector2(8, -150))
	_place_btn("reload", rc + Vector2(-210, -60))
	_place_btn("pause", Vector2(s.x - 40, 40))
	_place_btn("view", Vector2(s.x - 106, 40))
	for k in ["slide", "vault", "swap", "reload"]:
		(tbtns[k] as Control).visible = touch_mode
	obj_label.position = Vector2(16, 12)
	hp_back.position = Vector2(s.x * 0.5 - 130, 16)
	hp_back.size = Vector2(260, 14)
	hp_fill.position = hp_back.position + Vector2(2, 2)
	ammo_label.position = Vector2(s.x * 0.5 - 70, s.y - 74) if not touch_mode else Vector2(s.x * 0.5 - 70, s.y - 70)
	wep_label.position = ammo_label.position + Vector2(4, -20)
	low_label.position = Vector2(s.x * 0.5 - 52, s.y - 112)
	cover_label.position = Vector2(s.x * 0.5 - 36, 40)
	reload_label.position = Vector2(s.x * 0.5 - 62, s.y * 0.5 + 50)
	hint_label.size = Vector2(s.x, 40)
	hint_label.position = Vector2(0, s.y - 150)
	hint_label.visible = not touch_mode
	sticks.queue_redraw()


func _place_btn(k: String, center: Vector2) -> void:
	var p: Control = tbtns[k]
	p.position = center - p.size * 0.5


func touch_button_at(p: Vector2) -> String:
	if not hud.visible:
		return ""
	for k in tbtns:
		var c: Control = tbtns[k]
		if not c.visible:
			continue
		var center := c.position + c.size * 0.5
		if p.distance_to(center) <= c.size.x * 0.5 + 8.0:
			return k
	return ""


func flash_button(k: String) -> void:
	var c: Control = tbtns.get(k)
	if c == null:
		return
	c.modulate = Color(1.6, 1.4, 0.9)
	var tw := create_tween()
	tw.tween_property(c, "modulate", Color.WHITE, 0.18)


func set_hp(frac: float) -> void:
	hp_fill.size = Vector2(256.0 * clampf(frac, 0.0, 1.0), 10)
	hp_fill.color = Color(0.49, 0.73, 0.35) if frac > 0.35 else Color(0.85, 0.36, 0.29)
