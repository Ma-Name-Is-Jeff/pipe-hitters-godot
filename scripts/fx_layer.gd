class_name FxLayer
extends Control
## 2D feedback over the 3D view: target brackets, damage numbers, enemy name tags,
## off-screen enemy arrows and the red damage vignette. main.gd feeds it via refresh().

var camera: Camera3D
var numbers: Array = []   # {p: Vector3, v: int, t: float}
var tags: Array = []      # {pos: Vector2, name: String}
var arrows: Array = []    # {pos: Vector2, dir: Vector2}
var bracket := {}         # {pos: Vector2, size: float} or empty
var vignette_a := 0.0
var show_numbers := true
var show_tags := true
var show_arrows := true
var show_brackets := true
var vig_tex: GradientTexture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0.8, 0.0, 0.0, 0.0), Color(0.8, 0.0, 0.0, 0.0), Color(0.85, 0.02, 0.02, 0.9)])
	vig_tex = GradientTexture2D.new()
	vig_tex.gradient = g
	vig_tex.fill = GradientTexture2D.FILL_RADIAL
	vig_tex.fill_from = Vector2(0.5, 0.5)
	vig_tex.fill_to = Vector2(1.0, 0.5)
	vig_tex.width = 128
	vig_tex.height = 72


func add_number(p: Vector3, v: int) -> void:
	numbers.append({"p": p, "v": v, "t": 0.0})
	if numbers.size() > 24:
		numbers.pop_front()


func clear_all() -> void:
	numbers.clear()
	tags.clear()
	arrows.clear()
	bracket = {}
	vignette_a = 0.0


## bots: Array of {world: Vector3, name: String, alive: bool}; locked: world pos or null.
func refresh(dt: float, bots: Array, locked: Variant, vig: float) -> void:
	vignette_a = vig
	for n in numbers:
		n["t"] = float(n["t"]) + dt
	numbers = numbers.filter(func(n: Dictionary) -> bool: return float(n["t"]) < 0.8)
	tags = []
	arrows = []
	bracket = {}
	if camera == null:
		queue_redraw()
		return
	var r := get_viewport_rect()
	var c := r.size * 0.5
	for b in bots:
		if not b["alive"]:
			continue
		var w: Vector3 = b["world"]
		var sp := camera.unproject_position(w + Vector3(0, 0.9, 0))
		var inside := r.grow(-18.0).has_point(sp) and not camera.is_position_behind(w)
		if inside:
			tags.append({"pos": camera.unproject_position(w + Vector3(0, 2.15, 0)), "name": b["name"]})
		else:
			var d := (sp - c)
			if camera.is_position_behind(w):
				d = -d
			if d.length() < 1.0:
				d = Vector2.UP
			d = d.normalized()
			var half := r.size * 0.5 - Vector2(34, 34)
			var k := minf(half.x / maxf(absf(d.x), 0.001), half.y / maxf(absf(d.y), 0.001))
			arrows.append({"pos": c + d * k, "dir": d})
	if locked != null:
		var lw: Vector3 = locked
		var top := camera.unproject_position(lw + Vector3(0, 1.9, 0))
		var bot := camera.unproject_position(lw)
		var mid := (top + bot) * 0.5
		bracket = {"pos": mid, "size": clampf(absf(bot.y - top.y) * 0.62, 26.0, 120.0)}
	queue_redraw()


func _draw() -> void:
	var r := get_viewport_rect()
	if vignette_a > 0.01 and vig_tex != null:
		draw_texture_rect(vig_tex, Rect2(Vector2.ZERO, r.size), false, Color(1, 1, 1, clampf(vignette_a, 0.0, 1.0)))
	var font := ThemeDB.fallback_font
	if show_tags:
		for t in tags:
			var p: Vector2 = t["pos"]
			var s: String = t["name"]
			var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			draw_string_outline(font, p + Vector2(-w * 0.5, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(0, 0, 0, 0.8))
			draw_string(font, p + Vector2(-w * 0.5, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.92, 0.94, 0.9, 0.9))
	if show_brackets and not bracket.is_empty():
		var bp: Vector2 = bracket["pos"]
		var h: float = float(bracket["size"])
		var l := h * 0.36
		var col := Color(1.0, 0.25, 0.2, 0.95)
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var c := bp + Vector2(sx * h, sy * h)
				draw_line(c, c + Vector2(-sx * l, 0), col, 3.0)
				draw_line(c, c + Vector2(0, -sy * l), col, 3.0)
	if show_arrows:
		for a in arrows:
			var p: Vector2 = a["pos"]
			var d: Vector2 = a["dir"]
			var n := Vector2(-d.y, d.x)
			draw_colored_polygon(PackedVector2Array([p + d * 16, p - d * 10 + n * 12, p - d * 10 - n * 12]), Color(1.0, 0.3, 0.25, 0.9))
	if show_numbers and camera != null:
		for n in numbers:
			var t := float(n["t"])
			var sp := camera.unproject_position(n["p"]) + Vector2(0, -52.0 * t / 0.8)
			var s := str(n["v"])
			var a := clampf(1.0 - (t - 0.45) / 0.35, 0.0, 1.0)
			var fs := 30
			var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string_outline(font, sp + Vector2(-w * 0.5, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.85 * a))
			draw_string(font, sp + Vector2(-w * 0.5, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, a))
