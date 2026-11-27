class_name GameUI
extends CanvasLayer
## HUD, touch sticks/buttons, start, pause, win and downed screens. Built in code.

signal deploy
signal deploy_arena
signal open_tune
signal switch_mode
signal tune_close
signal tune_copy
signal tune_paste
signal tune_reset
signal tune_enemy_toggle
signal tune_preset(name: String)
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
var tune_panel: PanelContainer
var tune_sliders := {}
var tune_vals := {}
var tune_pages: Array[Control] = []
var tune_tabs: Array[Button] = []
var tune_text: TextEdit
var tune_status: Label
var tune_enemy_btn: Button
var preset_btns := {}
var fx: FxLayer
var slot_back: ColorRect
var mag_bar: MagBar
var toast_label: Label
var toast_t := 0.0
var btn_mode := true
var hud_bottom := true
var pause_mode_btn: Button
var arena_mode := false
var opt_val := {}
var touch_mode := false
var _syncing := false


class MagBar extends Control:
	var total := 30
	var cur := 30

	func _draw() -> void:
		var n := maxi(total, 1)
		var gap := 2.0
		var w := (size.x - gap * (n - 1)) / n
		for i in n:
			var on := i < cur
			draw_rect(Rect2(i * (w + gap), 0, w, size.y), Color(1.0, 0.82, 0.38, 0.95) if on else Color(1, 1, 1, 0.14))


class StickPad extends Control:
	var show_right := true
	var centers: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
	var knobs: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
	var active: Array[bool] = [false, false]
	var r := 66.0

	func _draw() -> void:
		for i in 2:
			if i == 1 and not show_right:
				continue
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
	_build_tune()
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
	fx = FxLayer.new()
	hud.add_child(fx)
	obj_label = _label(hud, "Reach the north extract", 20, Color(1, 0.9, 0.6))
	hp_back = ColorRect.new()
	hp_back.color = Color(0, 0, 0, 0.5)
	hp_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hp_back)
	hp_fill = ColorRect.new()
	hp_fill.color = Color(0.49, 0.73, 0.35)
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hp_fill)
	slot_back = ColorRect.new()
	slot_back.color = Color(0.04, 0.05, 0.05, 0.55)
	slot_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(slot_back)
	mag_bar = MagBar.new()
	mag_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(mag_bar)
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
	toast_label = _label(hud, "", 24, Color(1, 0.9, 0.55))
	toast_label.visible = false
	for spec in [["fire", "FIRE", 150], ["vault", "VAULT", 92], ["slide", "SLIDE", 92], ["swap", "SWAP", 78], ["reload", "RLD", 64], ["sprint", "RUN", 70], ["grenade", "GRN", 70], ["pause", "II", 56], ["view", "VIEW", 56], ["tune", "TUNE", 56]]:
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
	var r := _screen("PIPE HITTERS  " + TuneDefs.VERSION, "Left stick moves. Auto-lock picks the nearest enemy; hold FIRE to shoot. RUN sprints. TUNE opens the tuning panel (Snappy / Classic presets).")
	start_panel = r[0]
	var a := _button(r[1], "Tuning Arena", func() -> void: deploy_arena.emit())
	a.custom_minimum_size = Vector2(300, 64)
	_button(r[1], "Mission: Compound", func() -> void: deploy.emit())


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
	_button(list, "Tuning panel", func() -> void: open_tune.emit())
	pause_mode_btn = _button(list, "Switch to Mission", func() -> void: switch_mode.emit())
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
	for k in tune_sliders.keys():
		var sl: HSlider = tune_sliders[k]
		sl.value = float(settings[k])
		(tune_vals[k] as Label).text = fmt_value(sl.value, sl.step)
	for k in preset_btns.keys():
		(preset_btns[k] as Button).button_pressed = (settings.get("preset", "snappy") == k)
	var nb: bool = float(settings.get("twin_stick", 0.0)) < 0.5
	var hb: bool = float(settings.get("hud_bottom", 1.0)) > 0.5
	if nb != btn_mode or hb != hud_bottom:
		btn_mode = nb
		hud_bottom = hb
		_layout()
	fx.show_numbers = float(settings.get("dmg_nums", 1.0)) > 0.5
	fx.show_tags = float(settings.get("tags", 1.0)) > 0.5
	fx.show_arrows = float(settings.get("arrows", 1.0)) > 0.5
	fx.show_brackets = float(settings.get("brackets", 1.0)) > 0.5
	if tune_enemy_btn != null:
		tune_enemy_btn.text = "Enemy: " + ("Active AI (tap for Static)" if settings["enemy_active"] else "Static (tap for Active AI)")
	_syncing = false


func set_zoom_display(z: float) -> void:
	_syncing = true
	(opt["zoom"] as HSlider).value = z
	(opt_val["zoom"] as Label).text = str(int(round(z)))
	if tune_sliders.has("zoom"):
		(tune_sliders["zoom"] as HSlider).value = z
		(tune_vals["zoom"] as Label).text = str(int(round(z)))
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
	sticks.show_right = not btn_mode
	var rc := sticks.centers[1]
	if btn_mode:
		var f := Vector2(s.x - 150, s.y - 170)
		_place_btn("fire", f)
		_place_btn("sprint", f + Vector2(-127, 46))
		_place_btn("slide", f + Vector2(-127, -46))
		_place_btn("vault", f + Vector2(-67, -117))
		_place_btn("reload", f + Vector2(23, -133))
		_place_btn("grenade", f + Vector2(103, -87))
		_place_btn("swap", f + Vector2(-190, -125))
	else:
		_place_btn("slide", rc + Vector2(-150, 10))
		_place_btn("vault", rc + Vector2(-112, -112))
		_place_btn("swap", rc + Vector2(8, -150))
		_place_btn("reload", rc + Vector2(-210, -60))
	_place_btn("pause", Vector2(40, 40) if hud_bottom else Vector2(s.x - 40, 40))
	_place_btn("view", Vector2(s.x - 40, 40) if hud_bottom else Vector2(s.x - 106, 40))
	_place_btn("tune", Vector2(s.x - 106, 40) if hud_bottom else Vector2(s.x - 172, 40))
	(tbtns["swap"] as Control).visible = touch_mode and not arena_mode
	var tw := minf(820.0, s.x * 0.64)
	tune_panel.position = Vector2(s.x - tw, 0)
	tune_panel.size = Vector2(tw, s.y)
	for k in ["slide", "vault", "reload"]:
		(tbtns[k] as Control).visible = touch_mode
	for k in ["fire", "sprint", "grenade"]:
		(tbtns[k] as Control).visible = touch_mode and btn_mode
	obj_label.position = Vector2(84, 12) if hud_bottom else Vector2(16, 12)
	if hud_bottom:
		var cx := s.x * 0.5
		hp_back.position = Vector2(cx - 170, s.y - 112)
		hp_back.size = Vector2(340, 16)
		slot_back.position = Vector2(cx - 170, s.y - 88)
		slot_back.size = Vector2(340, 74)
		slot_back.visible = true
		mag_bar.position = Vector2(cx - 160, s.y - 30)
		mag_bar.size = Vector2(320, 10)
		mag_bar.visible = true
		wep_label.position = Vector2(cx - 160, s.y - 86)
		ammo_label.position = Vector2(cx + 160 - 130, s.y - 84)
		ammo_label.size = Vector2(130, 40)
		ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		low_label.position = Vector2(cx - 52, s.y - 146)
	else:
		hp_back.position = Vector2(s.x * 0.5 - 130, 16)
		hp_back.size = Vector2(260, 14)
		slot_back.visible = false
		mag_bar.visible = false
		ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		ammo_label.position = Vector2(s.x * 0.5 - 70, s.y - 74) if not touch_mode else Vector2(s.x * 0.5 - 70, s.y - 70)
		wep_label.position = ammo_label.position + Vector2(4, -20)
		low_label.position = Vector2(s.x * 0.5 - 52, s.y - 112)
	hp_fill.position = hp_back.position + Vector2(2, 2)
	cover_label.position = Vector2(s.x * 0.5 - 36, 40)
	reload_label.position = Vector2(s.x * 0.5 - 62, s.y * 0.5 + 50)
	toast_label.position = Vector2(s.x * 0.5 - 150, s.y * 0.5 - 80)
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
	hp_fill.size = Vector2((hp_back.size.x - 4.0) * clampf(frac, 0.0, 1.0), hp_back.size.y - 4.0)
	hp_fill.color = Color(0.49, 0.73, 0.35) if frac > 0.35 else Color(0.85, 0.36, 0.29)


func set_mag(cur: int, total: int) -> void:
	if mag_bar.cur != cur or mag_bar.total != total:
		mag_bar.cur = cur
		mag_bar.total = total
		mag_bar.queue_redraw()


func toast(text: String) -> void:
	toast_label.text = text
	toast_label.visible = true
	toast_t = 1.2


func tick(dt: float) -> void:
	if toast_t > 0.0:
		toast_t -= dt
		toast_label.modulate.a = clampf(toast_t / 0.4, 0.0, 1.0)
		if toast_t <= 0.0:
			toast_label.visible = false


func set_arena(on: bool) -> void:
	arena_mode = on
	if pause_mode_btn != null:
		pause_mode_btn.text = "Switch to Mission" if on else "Switch to Tuning Arena"
	_layout()


# ---------- tuning panel ----------

static func fmt_value(v: float, step: float) -> String:
	if step >= 1.0:
		return str(int(round(v)))
	var dec := int(ceil(-log(step) / log(10.0) - 0.001))
	return ("%." + str(dec) + "f") % v


static func _circle(r: int, col: Color) -> ImageTexture:
	var d := r * 2
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - dist, 0.0, 1.0)
			var edge := 1.0 if dist < r - 4.0 else 0.82
			img.set_pixel(x, y, Color(col.r * edge, col.g * edge, col.b * edge, a))
	return ImageTexture.create_from_image(img)


func _tune_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 24
	var g := _circle(24, Color(1.0, 0.82, 0.38))
	th.set_icon("grabber", "HSlider", g)
	th.set_icon("grabber_highlight", "HSlider", g)
	th.set_icon("grabber_disabled", "HSlider", g)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.16)
	track.set_corner_radius_all(6)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	th.set_stylebox("slider", "HSlider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.9, 0.7, 0.3, 0.8)
	fill.set_corner_radius_all(6)
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	th.set_stylebox("grabber_area", "HSlider", fill)
	th.set_stylebox("grabber_area_highlight", "HSlider", fill)
	return th


func _tune_row(parent: Control, d: Dictionary) -> void:
	var key: String = d["key"]
	var step: float = d["step"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var l := Label.new()
	l.text = d["label"]
	l.custom_minimum_size = Vector2(230, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var toggle: bool = d.get("toggle", false)
	var minus := Button.new()
	minus.text = "-"
	minus.custom_minimum_size = Vector2(58, 58)
	if not toggle:
		row.add_child(minus)
	var sl := HSlider.new()
	sl.min_value = d["min"]
	sl.max_value = d["max"]
	sl.step = step
	sl.value = d["def"]
	sl.custom_minimum_size = Vector2(200, 58)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sl)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(58, 58)
	if not toggle:
		row.add_child(plus)
	var tbtn: Button = null
	if toggle:
		sl.visible = false
		tbtn = Button.new()
		tbtn.custom_minimum_size = Vector2(200, 58)
		tbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tbtn.pressed.connect(func() -> void: sl.value = 0.0 if sl.value > 0.5 else 1.0)
		row.add_child(tbtn)
	var v := Label.new()
	v.custom_minimum_size = Vector2(92, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_theme_color_override("font_color", Color(1, 0.86, 0.5))
	v.text = fmt_value(sl.value, step)
	row.add_child(v)
	if toggle:
		v.text = "On" if sl.value > 0.5 else "Off"
		tbtn.text = "Tap to turn " + ("off" if sl.value > 0.5 else "on")
	sl.value_changed.connect(func(val: float) -> void:
		v.text = fmt_value(val, step)
		if toggle:
			v.text = "On" if val > 0.5 else "Off"
			tbtn.text = "Tap to turn " + ("off" if val > 0.5 else "on")
		if not _syncing:
			setting_changed.emit(key, val))
	minus.pressed.connect(func() -> void: sl.value = sl.value - step)
	plus.pressed.connect(func() -> void: sl.value = sl.value + step)
	tune_sliders[key] = sl
	tune_vals[key] = v


func _tune_btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 60)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_tune() -> void:
	tune_panel = PanelContainer.new()
	tune_panel.theme = _tune_theme()
	tune_panel.visible = false
	tune_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.1, 0.93)
	sb.border_color = Color(0.9, 0.75, 0.35, 0.7)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(14)
	tune_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(tune_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	tune_panel.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	var t := Label.new()
	t.text = "TUNE " + TuneDefs.VERSION
	t.add_theme_color_override("font_color", Color(0.95, 0.82, 0.42))
	t.add_theme_font_size_override("font_size", 30)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	for pn in ["snappy", "classic"]:
		var pb := Button.new()
		pb.text = pn.capitalize()
		pb.toggle_mode = true
		pb.custom_minimum_size = Vector2(124, 56)
		var pname: String = pn
		pb.pressed.connect(func() -> void: tune_preset.emit(pname))
		head.add_child(pb)
		preset_btns[pn] = pb
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(150, 56)
	close.pressed.connect(func() -> void: tune_close.emit())
	head.add_child(close)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	vb.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stack)
	var names: Array[String] = []
	for g in TuneDefs.groups():
		names.append(g["name"])
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 10)
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_child(page)
		tune_pages.append(page)
		for it in g["items"]:
			_tune_row(page, it)
		if g["name"] == "Enemy":
			tune_enemy_btn = _tune_btn(page, "Enemy: Static", func() -> void: tune_enemy_toggle.emit())
	names.append("Data")
	var data := VBoxContainer.new()
	data.add_theme_constant_override("separation", 10)
	data.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(data)
	tune_pages.append(data)
	var br := HBoxContainer.new()
	br.add_theme_constant_override("separation", 8)
	data.add_child(br)
	_tune_btn(br, "Copy values", func() -> void: tune_copy.emit())
	_tune_btn(br, "Paste values", func() -> void: tune_paste.emit())
	_tune_btn(br, "Reset defaults", func() -> void: tune_reset.emit())
	tune_status = Label.new()
	tune_status.text = "Copy puts JSON on the clipboard and in the box."
	tune_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tune_status.add_theme_font_size_override("font_size", 20)
	data.add_child(tune_status)
	tune_text = TextEdit.new()
	tune_text.custom_minimum_size = Vector2(0, 220)
	tune_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	tune_text.placeholder_text = "Tuning JSON appears here. Paste or edit it, then tap Paste values."
	tune_text.add_theme_font_size_override("font_size", 18)
	data.add_child(tune_text)
	for i in names.size():
		var tb := Button.new()
		tb.text = names[i]
		tb.toggle_mode = true
		tb.custom_minimum_size = Vector2(0, 54)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.add_theme_font_size_override("font_size", 21)
		tb.pressed.connect(func() -> void: show_tune_tab(i))
		tabs.add_child(tb)
		tune_tabs.append(tb)
	show_tune_tab(0)


func show_tune_tab(i: int) -> void:
	for j in tune_pages.size():
		tune_pages[j].visible = (j == i)
		tune_tabs[j].button_pressed = (j == i)
