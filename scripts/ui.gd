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
const BTN_IDLE_A := 0.50

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
var test_size := Vector2.ZERO
var btn_held := {}
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
	if test_size != Vector2.ZERO:
		return test_size
	return get_viewport().get_visible_rect().size


func stick_center(i: int) -> Vector2:
	return sticks.centers[i]


func stick_radius() -> float:
	return sticks.r if sticks else STICK_R


func stick_hit_radius() -> float:
	return stick_radius() * (120.0 / 66.0)


## Convert CSS/dp to current stretch (viewport) units.
func _dp(dp: float) -> float:
	var vis := screen_size()
	# v1d phone target is 844x390 CSS; when test_size is set, treat height as 390 CSS px.
	if test_size != Vector2.ZERO:
		return dp * vis.y / 390.0
	var win := Vector2(get_viewport().get_window().size)
	# Headless / odd window sizes: fall back to the 720-tall design scale.
	if win.y < 200.0:
		return dp * vis.y / 720.0
	return dp * vis.y / win.y


## FIRE ~2x v1c (slightly trimmed), other touch controls and the stick 1.6x, with thumb-size floors.
func touch_metrics() -> Dictionary:
	var s := screen_size()
	var h := maxf(s.y, 1.0)
	var k_fire := (h / 720.0) * 1.92  # ~2x, trimmed a little so the cluster can sit in the corner
	var k := (h / 720.0) * 1.6
	var min_fire := maxf(0.22 * h, _dp(48.0))
	var min_small := maxf(0.12 * h, _dp(48.0))
	var d := {
		"fire": maxf(150.0 * k_fire, min_fire),
		"vault": maxf(92.0 * k, min_small),
		"slide": maxf(92.0 * k, min_small),
		"swap": maxf(78.0 * k, min_small),
		"reload": maxf(64.0 * k, min_small),
		"sprint": maxf(70.0 * k, min_small),
		"grenade": maxf(70.0 * k, min_small),
		"pause": maxf(56.0 * k, min_small),
		"view": maxf(56.0 * k, min_small),
		"tune": maxf(56.0 * k, min_small),
		"stick": maxf(66.0 * k, min_small * 0.5),
		"margin": maxf(_dp(8.0), 0.016 * h),
		"gap": maxf(_dp(8.0), 0.02 * h),
	}
	return d


func _set_btn_size(k: String, size: float) -> void:
	var p: Control = tbtns[k]
	p.size = Vector2(size, size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.08, 0.45)
	sb.border_color = Color(1, 1, 1, 0.45)
	sb.set_border_width_all(maxi(2, int(round(size / 70.0 * 2.0))))
	sb.set_corner_radius_all(int(size * 0.5))
	p.add_theme_stylebox_override("panel", sb)
	if p.get_child_count() > 0:
		var l := p.get_child(0) as Label
		if l:
			l.add_theme_font_size_override("font_size", int(clampf(size * 0.22, 16.0, 42.0)))
	_apply_btn_mod(k)


func _btn_center(k: String) -> Vector2:
	var p: Control = tbtns[k]
	return p.position + p.size * 0.5


func _hud_block() -> Rect2:
	if not hud_bottom or slot_back == null or not slot_back.visible:
		return Rect2()
	var r := Rect2(slot_back.position, slot_back.size).merge(Rect2(hp_back.position, hp_back.size))
	return r.grow(8.0)


func _clamp_btn(k: String, s: Vector2, margin: float, hud: Rect2) -> void:
	var p: Control = tbtns[k]
	var r := p.size.x * 0.5
	var c := p.position + p.size * 0.5
	c.x = clampf(c.x, margin + r, s.x - margin - r)
	c.y = clampf(c.y, margin + r, s.y - margin - r)
	var br := Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
	if hud.size.x > 1.0 and br.intersects(hud):
		# Push up so the button sits above the HUD.
		c.y = hud.position.y - r - 6.0
		c.y = clampf(c.y, margin + r, s.y - margin - r)
	p.position = c - p.size * 0.5


func _separate_controls(keys: Array, stick: Vector2, stick_r: float, gap: float) -> void:
	for _i in 20:
		# Push satellites off the stick.
		for k in keys:
			var p: Control = tbtns[k]
			if not p.visible:
				continue
			var c := p.position + p.size * 0.5
			var need := p.size.x * 0.5 + stick_r + gap
			var d := c - stick
			if d.length() < 0.01:
				d = Vector2(-1, 0)
			if d.length() < need:
				c = stick + d.normalized() * need
				p.position = c - p.size * 0.5
		# Push pairs apart, preferring to move the later (smaller) control.
		for a in keys.size():
			var ka: String = keys[a]
			var pa: Control = tbtns[ka]
			if not pa.visible:
				continue
			var ca := pa.position + pa.size * 0.5
			var ra := pa.size.x * 0.5
			for b in range(a + 1, keys.size()):
				var kb: String = keys[b]
				var pb: Control = tbtns[kb]
				if not pb.visible:
					continue
				var cb := pb.position + pb.size * 0.5
				var need2 := ra + pb.size.x * 0.5 + gap
				var d2 := cb - ca
				if d2.length() < 0.01:
					d2 = Vector2(-1, -1)
				if d2.length() < need2:
					var push := (need2 - d2.length())
					# Keep FIRE planted; move the other.
					if ka == "fire":
						cb += d2.normalized() * push
						pb.position = cb - pb.size * 0.5
					elif kb == "fire":
						ca -= d2.normalized() * push
						pa.position = ca - pa.size * 0.5
					else:
						var half := d2.normalized() * (push * 0.5)
						ca -= half
						cb += half
						pa.position = ca - pa.size * 0.5
						pb.position = cb - pb.size * 0.5


func _layout() -> void:
	if hud == null:
		return
	var s := screen_size()
	var m: Dictionary = touch_metrics()
	var margin: float = m["margin"]
	var gap: float = m["gap"]
	for k in tbtns.keys():
		if m.has(k):
			_set_btn_size(k, float(m[k]))
	# Bottom-center HUD first so the button placer can avoid it.
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
	var hud := _hud_block()

	# Top buttons: pause left, VIEW and TUNE right.
	var top: float = float(m["pause"])
	if hud_bottom:
		_place_btn("pause", Vector2(margin + top * 0.5, margin + top * 0.5))
		_place_btn("view", Vector2(s.x - margin - top * 0.5, margin + top * 0.5))
		_place_btn("tune", Vector2(s.x - margin - top * 1.5 - gap, margin + top * 0.5))
	else:
		_place_btn("pause", Vector2(s.x - margin - top * 0.5, margin + top * 0.5))
		_place_btn("view", Vector2(s.x - margin - top * 1.5 - gap, margin + top * 0.5))
		_place_btn("tune", Vector2(s.x - margin - top * 2.5 - gap * 2.0, margin + top * 0.5))

	# Left move stick, clear of the HUD and the top-left pause button.
	var sr: float = float(m["stick"])
	var sc := Vector2(margin + sr, s.y - margin - sr)
	if hud.size.x > 1.0:
		var stick_rect := Rect2(sc - Vector2(sr, sr), Vector2(sr, sr) * 2.0)
		if stick_rect.intersects(hud):
			sc.x = minf(sc.x, hud.position.x - sr - gap)
			sc.x = maxf(sc.x, margin + sr)
	# Keep off the pause button.
	var pc := _btn_center("pause")
	var pr: float = (tbtns["pause"] as Control).size.x * 0.5
	if sc.distance_to(pc) < sr + pr + gap:
		sc.y = maxf(sc.y, pc.y + pr + sr + gap)
		sc.y = minf(sc.y, s.y - margin - sr)
	sticks.r = sr
	sticks.centers[0] = sc
	sticks.centers[1] = Vector2(s.x - margin - sr, s.y - margin - sr)
	sticks.visible = touch_mode
	sticks.show_right = not btn_mode

	if btn_mode:
		var fire: float = float(m["fire"])
		var fr := fire * 0.5
		# Tuck FIRE into the bottom-right corner so more of the playfield stays visible.
		var fc := Vector2(s.x - margin - fr, s.y - margin - fr)
		# Stay to the right of the bottom HUD.
		if hud.size.x > 1.0:
			fc.x = maxf(fc.x, hud.position.x + hud.size.x + fr + gap)
			fc.x = minf(fc.x, s.x - margin - fr)
		_place_btn("fire", fc)
		# Compact arc hugging FIRE, biased toward the corner.
		var arc := [
			["sprint", deg_to_rad(210.0)],
			["slide", deg_to_rad(168.0)],
			["vault", deg_to_rad(128.0)],
			["reload", deg_to_rad(95.0)],
			["grenade", deg_to_rad(62.0)],
			["swap", deg_to_rad(246.0)],
		]
		for item in arc:
			var kk: String = item[0]
			var ang: float = item[1]
			var rr: float = (tbtns[kk] as Control).size.x * 0.5
			var orbit := fr + rr + gap
			if kk == "swap":
				orbit *= 1.28
			var pos := fc + Vector2(cos(ang), -sin(ang)) * orbit
			_place_btn(kk, pos)
	else:
		var rc: Vector2 = sticks.centers[1]
		_place_btn("slide", rc + Vector2(-sr * 2.15, 8))
		_place_btn("vault", rc + Vector2(-sr * 1.55, -sr * 1.55))
		_place_btn("swap", rc + Vector2(8, -sr * 2.15))
		_place_btn("reload", rc + Vector2(-sr * 2.9, -sr * 0.7))

	var cluster: Array = ["fire", "sprint", "slide", "vault", "reload", "grenade", "swap", "pause", "view", "tune"]
	_separate_controls(cluster, sticks.centers[0], sr, gap)
	for k2 in cluster:
		_clamp_btn(k2, s, margin, hud)
	_separate_controls(cluster, sticks.centers[0], sr, gap)
	for k3 in cluster:
		_clamp_btn(k3, s, margin, hud)

	(tbtns["swap"] as Control).visible = touch_mode and not arena_mode
	var tw := minf(900.0, s.x * 0.68)
	tune_panel.position = Vector2(s.x - tw, 0)
	tune_panel.size = Vector2(tw, s.y)
	for k4 in ["slide", "vault", "reload"]:
		(tbtns[k4] as Control).visible = touch_mode
	for k5 in ["fire", "sprint", "grenade"]:
		(tbtns[k5] as Control).visible = touch_mode and btn_mode
	var pause_r: float = (tbtns["pause"] as Control).size.x
	obj_label.position = Vector2((tbtns["pause"] as Control).position.x + pause_r + 10.0, 16) if hud_bottom else Vector2(16, 12)
	cover_label.position = Vector2(s.x * 0.5 - 36, float(m["pause"]) + 8.0)
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


func set_btn_pressed(k: String, on: bool) -> void:
	btn_held[k] = on
	_apply_btn_mod(k)


func _apply_btn_mod(k: String) -> void:
	var c: Control = tbtns.get(k)
	if c == null:
		return
	var a := 1.0 if bool(btn_held.get(k, false)) else BTN_IDLE_A
	c.modulate = Color(1, 1, 1, a)


func flash_button(k: String) -> void:
	var c: Control = tbtns.get(k)
	if c == null:
		return
	if bool(btn_held.get(k, false)):
		_apply_btn_mod(k)
		return
	c.modulate = Color(1, 1, 1, 1)
	var tw := create_tween()
	tw.tween_property(c, "modulate", Color(1, 1, 1, BTN_IDLE_A), 0.2)


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
	th.default_font_size = 30
	var g := _circle(32, Color(1.0, 0.82, 0.38))
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
	l.custom_minimum_size = Vector2(250, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var toggle: bool = d.get("toggle", false)
	var minus := Button.new()
	minus.text = "-"
	minus.custom_minimum_size = Vector2(70, 70)
	if not toggle:
		row.add_child(minus)
	var sl := HSlider.new()
	sl.min_value = d["min"]
	sl.max_value = d["max"]
	sl.step = step
	sl.value = d["def"]
	sl.custom_minimum_size = Vector2(200, 70)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sl)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(70, 70)
	if not toggle:
		row.add_child(plus)
	var tbtn: Button = null
	if toggle:
		sl.visible = false
		tbtn = Button.new()
		tbtn.custom_minimum_size = Vector2(200, 70)
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
	b.custom_minimum_size = Vector2(0, 70)
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
	t.add_theme_font_size_override("font_size", 36)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	for pn in ["snappy", "classic"]:
		var pb := Button.new()
		pb.text = pn.capitalize()
		pb.toggle_mode = true
		pb.custom_minimum_size = Vector2(140, 64)
		var pname: String = pn
		pb.pressed.connect(func() -> void: tune_preset.emit(pname))
		head.add_child(pb)
		preset_btns[pn] = pb
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(160, 64)
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
	tune_status.add_theme_font_size_override("font_size", 24)
	data.add_child(tune_status)
	tune_text = TextEdit.new()
	tune_text.custom_minimum_size = Vector2(0, 220)
	tune_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	tune_text.placeholder_text = "Tuning JSON appears here. Paste or edit it, then tap Paste values."
	tune_text.add_theme_font_size_override("font_size", 22)
	data.add_child(tune_text)
	for i in names.size():
		var tb := Button.new()
		tb.text = names[i]
		tb.toggle_mode = true
		tb.custom_minimum_size = Vector2(0, 62)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.add_theme_font_size_override("font_size", 26)
		tb.pressed.connect(func() -> void: show_tune_tab(i))
		tabs.add_child(tb)
		tune_tabs.append(tb)
	show_tune_tab(0)


func show_tune_tab(i: int) -> void:
	for j in tune_pages.size():
		tune_pages[j].visible = (j == i)
		tune_tabs[j].button_pressed = (j == i)
