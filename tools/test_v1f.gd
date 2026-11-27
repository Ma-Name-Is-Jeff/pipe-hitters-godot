extends SceneTree
## Targeted v1f test: button size/opacity sliders, persistence, and no overlaps
## at 50%, 100% and 150% on a simulated 844x390 phone viewport.
##   godot --headless --path . --script res://tools/test_v1f.gd

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


func _overlaps(ui: GameUI) -> Array:
	var s: Vector2 = ui.screen_size()
	var names: Array = ["fire", "sprint", "reload", "grenade", "slide", "vault", "pause", "view", "tune"]
	var overlap: Array = []
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
	return overlap


func run() -> void:
	await process_frame
	await process_frame
	main.reset_tuning()
	main.settings["btn_scale"] = 100.0
	main.settings["btn_opacity"] = 50.0
	main._save_settings()
	main.ui.sync(main.settings)
	main._start_arena()
	main._set_touch_mode(true)
	await wait(0.2)
	var ui: GameUI = main.ui
	ok("version v1f", TuneDefs.VERSION == "v1f")
	ok("defaults 100% size, 50% opacity", is_equal_approx(main._t("btn_scale"), 100.0) and is_equal_approx(main._t("btn_opacity"), 50.0))
	ok("pause Controls sliders exist", ui.opt.has("btn_scale") and ui.opt.has("btn_opacity"))
	ok("TUNE FX/HUD sliders exist", ui.tune_sliders.has("btn_scale") and ui.tune_sliders.has("btn_opacity"))

	ui.test_size = Vector2(720.0 * 844.0 / 390.0, 720.0)
	ui._layout()
	await process_frame
	var fire100: float = (ui.tbtns["fire"] as Control).size.x
	var stick100: float = ui.stick_radius()
	ok("100% matches v1e FIRE (~288) and stick (~106)", absf(fire100 - 288.0) < 2.0 and absf(stick100 - 105.6) < 2.0, "FIRE=%.1f stick=%.1f" % [fire100, stick100])
	ok("idle opacity 50% at default", is_equal_approx((ui.tbtns["fire"] as Control).modulate.a, 0.5), "a=%.2f" % (ui.tbtns["fire"] as Control).modulate.a)
	var ov := _overlaps(ui)
	ok("no overlaps at 100% (844x390)", ov.is_empty(), ", ".join(ov))

	# Live size change via the same path as the menu sliders
	ui.setting_changed.emit("btn_scale", 50.0)
	await process_frame
	ok("50% size is live (half of 100%)", absf((ui.tbtns["fire"] as Control).size.x - fire100 * 0.5) < 2.0 and absf(ui.stick_radius() - stick100 * 0.5) < 2.0, "FIRE=%.1f stick=%.1f" % [(ui.tbtns["fire"] as Control).size.x, ui.stick_radius()])
	ov = _overlaps(ui)
	ok("no overlaps at 50% (844x390)", ov.is_empty(), ", ".join(ov))
	ok("setting persisted in settings", is_equal_approx(main._t("btn_scale"), 50.0))

	ui.setting_changed.emit("btn_scale", 150.0)
	await process_frame
	ok("150% size is live (1.5x of 100%)", absf((ui.tbtns["fire"] as Control).size.x - fire100 * 1.5) < 2.0 and absf(ui.stick_radius() - stick100 * 1.5) < 2.0, "FIRE=%.1f stick=%.1f" % [(ui.tbtns["fire"] as Control).size.x, ui.stick_radius()])
	ov = _overlaps(ui)
	ok("no overlaps at 150% (844x390)", ov.is_empty(), ", ".join(ov))

	ui.setting_changed.emit("btn_opacity", 20.0)
	await process_frame
	ok("opacity 20% applied", is_equal_approx((ui.tbtns["fire"] as Control).modulate.a, 0.2), "a=%.2f" % (ui.tbtns["fire"] as Control).modulate.a)
	ui.setting_changed.emit("btn_opacity", 100.0)
	await process_frame
	ok("opacity 100% applied", is_equal_approx((ui.tbtns["fire"] as Control).modulate.a, 1.0), "a=%.2f" % (ui.tbtns["fire"] as Control).modulate.a)

	# Presets must not wipe control prefs
	var sc: float = main._t("btn_scale")
	var op: float = main._t("btn_opacity")
	main.apply_preset("classic")
	ok("Classic leaves button prefs alone", is_equal_approx(main._t("btn_scale"), sc) and is_equal_approx(main._t("btn_opacity"), op))
	main.apply_preset("snappy")
	ok("Snappy leaves button prefs alone", is_equal_approx(main._t("btn_scale"), sc) and is_equal_approx(main._t("btn_opacity"), op))

	# Restore defaults and confirm 100% layout still clean
	ui.setting_changed.emit("btn_scale", 100.0)
	ui.setting_changed.emit("btn_opacity", 50.0)
	main._save_settings()
	await process_frame
	ov = _overlaps(ui)
	ok("no overlaps after restore 100%", ov.is_empty(), ", ".join(ov))

	ui.test_size = Vector2.ZERO
	ui._layout()
	print("V1F TEST DONE fails=", fails)
	quit()
