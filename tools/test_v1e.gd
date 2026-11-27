extends SceneTree
## Targeted v1e test: button sizes (FIRE ~2x, others 1.6x), overlap/safe area at 844x390,
## idle opacity, and a tighter right-side cluster.
##   godot --headless --path . --script res://tools/test_v1e.gd

var main: Node
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print(("OK   " if cond else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not cond:
		fails += 1


func wait(sec: float) -> void:
	await create_timer(sec).timeout


func _circ(c: Vector2, r: float, o: Vector2, orad: float, pad: float) -> bool:
	return c.distance_to(o) + 0.05 < r + orad + pad


func _initialize() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	run()


func run() -> void:
	await process_frame
	await process_frame
	main.reset_tuning()
	main._start_arena()
	main._set_touch_mode(true)
	await wait(0.2)
	var ui: GameUI = main.ui
	ok("version v1e", TuneDefs.VERSION == "v1e")

	ui.test_size = Vector2(720.0 * 844.0 / 390.0, 720.0)
	ui._layout()
	await process_frame
	var s: Vector2 = ui.screen_size()
	var H: float = s.y
	var k := 1.6
	var fire: Control = ui.tbtns["fire"]
	var fire_s: float = fire.size.x
	ok("FIRE about 2x v1c (288–300, slight trim OK)", fire_s >= 0.22 * H and fire_s >= 270.0 and fire_s <= 300.5, "FIRE=%.1f  2x=300  22%%=%.1f" % [fire_s, 0.22 * H])

	var expect := {
		"sprint": 70.0 * k, "reload": 64.0 * k, "grenade": 70.0 * k,
		"slide": 92.0 * k, "vault": 92.0 * k,
		"pause": 56.0 * k, "view": 56.0 * k, "tune": 56.0 * k,
	}
	var min_s := maxf(0.12 * H, 48.0 * H / 390.0)
	var size_ok := true
	var detail := []
	for kname in expect.keys():
		var c: Control = ui.tbtns[kname]
		var sz: float = c.size.x
		var want: float = maxf(float(expect[kname]), min_s)
		if absf(sz - want) > 2.0 or sz + 0.5 < min_s:
			size_ok = false
		detail.append("%s=%.0f(want %.0f)" % [kname, sz, want])
	ok("other buttons ~1.6x v1c and at least 12%/48dp", size_ok, ", ".join(detail) + "  min=%.0f" % min_s)
	var sr: float = ui.stick_radius()
	ok("left stick ~1.6x (v1c 66 -> ~106)", absf(sr - 66.0 * 1.6) < 2.0, "r=%.1f" % sr)

	var margin := 20.0
	var fire_right: float = fire.position.x + fire.size.x
	var fire_bottom: float = fire.position.y + fire.size.y
	ok("FIRE cluster tucked toward the corner", fire_right >= s.x - margin - 8.0 and fire_bottom >= s.y - margin - 8.0, "right=%.0f/%.0f  bottom=%.0f/%.0f" % [fire_right, s.x, fire_bottom, s.y])

	var names: Array = ["fire", "sprint", "reload", "grenade", "slide", "vault", "pause", "view", "tune"]
	var overlap := []
	for i in names.size():
		var a: Control = ui.tbtns[names[i]]
		if not a.visible:
			continue
		var ca := a.position + a.size * 0.5
		var ra := a.size.x * 0.5
		if ca.x - ra < -0.5 or ca.y - ra < -0.5 or ca.x + ra > s.x + 0.5 or ca.y + ra > s.y + 0.5:
			overlap.append("%s off-screen" % names[i])
		if _circ(ca, ra, ui.stick_center(0), ui.stick_radius(), 1.0):
			overlap.append("%s vs stick" % names[i])
		var hud: Rect2 = ui._hud_block()
		if hud.size.x > 1.0 and Rect2(a.position, a.size).grow(-2.0).intersects(hud):
			overlap.append("%s vs HUD" % names[i])
		for j in range(i + 1, names.size()):
			var b: Control = ui.tbtns[names[j]]
			if not b.visible:
				continue
			var cb := b.position + b.size * 0.5
			if _circ(ca, ra, cb, b.size.x * 0.5, 1.0):
				overlap.append("%s vs %s" % [names[i], names[j]])
	ok("no overlaps, all inside safe area at 844x390", overlap.is_empty(), ", ".join(overlap))

	ok("idle opacity about 50%", fire.modulate.a >= 0.45 and fire.modulate.a <= 0.55, "a=%.2f" % fire.modulate.a)
	ui.set_btn_pressed("fire", true)
	ok("full opacity on press", is_equal_approx(fire.modulate.a, 1.0), "a=%.2f" % fire.modulate.a)
	ui.set_btn_pressed("fire", false)
	ok("returns to idle opacity", fire.modulate.a >= 0.45 and fire.modulate.a <= 0.55, "a=%.2f" % fire.modulate.a)
	ok("pause top-left, HUD bottom-center", (ui.tbtns["pause"] as Control).position.x < 80 and ui.hp_back.position.y > s.y * 0.7)

	ui.test_size = Vector2.ZERO
	ui._layout()
	print("V1E TEST DONE fails=", fails)
	quit()
