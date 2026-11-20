class_name Synth
extends Node
## Procedural sound effects rendered to PCM at startup (no audio files).

const RATE := 22050

var streams := {}
var players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	streams["carbine"] = _render([
		{"k": "noise", "d": 0.07, "g": 0.55, "hp": 500.0, "lp": 3200.0},
		{"k": "tone", "f0": 140.0, "f1": 70.0, "d": 0.1, "g": 0.42},
		{"k": "tone", "f0": 380.0, "f1": 160.0, "d": 0.035, "g": 0.09, "w": "square"},
	])
	streams["sweeper"] = _render([
		{"k": "noise", "d": 0.15, "g": 0.75, "hp": 180.0, "lp": 1800.0},
		{"k": "tone", "f0": 92.0, "f1": 48.0, "d": 0.17, "g": 0.6},
		{"k": "tone", "f0": 210.0, "f1": 90.0, "d": 0.05, "g": 0.12, "w": "square"},
	])
	streams["enemy"] = _render([
		{"k": "noise", "d": 0.06, "g": 0.4, "hp": 400.0, "lp": 2200.0},
		{"k": "tone", "f0": 130.0, "f1": 60.0, "d": 0.08, "g": 0.3},
	])
	streams["reload"] = _render([
		{"k": "tone", "f0": 420.0, "f1": 280.0, "d": 0.04, "g": 0.12, "w": "square"},
		{"k": "tone", "f0": 240.0, "f1": 140.0, "d": 0.06, "g": 0.1, "w": "square", "at": 0.18},
		{"k": "noise", "d": 0.05, "g": 0.18, "hp": 200.0, "lp": 1200.0, "at": 0.18},
	])
	streams["empty"] = _render([{"k": "tone", "f0": 190.0, "f1": 120.0, "d": 0.045, "g": 0.12, "w": "square"}])
	streams["hit"] = _render([
		{"k": "noise", "d": 0.04, "g": 0.3, "hp": 300.0, "lp": 1600.0},
		{"k": "tone", "f0": 220.0, "f1": 80.0, "d": 0.05, "g": 0.16},
	])
	streams["hurt"] = _render([
		{"k": "noise", "d": 0.08, "g": 0.3, "hp": 120.0, "lp": 900.0},
		{"k": "tone", "f0": 160.0, "f1": 70.0, "d": 0.09, "g": 0.2},
	])
	streams["pickup"] = _render([
		{"k": "tone", "f0": 520.0, "f1": 780.0, "d": 0.05, "g": 0.16},
		{"k": "tone", "f0": 780.0, "f1": 980.0, "d": 0.08, "g": 0.12, "at": 0.05},
	])
	streams["thud"] = _render([
		{"k": "noise", "d": 0.09, "g": 0.4, "hp": 60.0, "lp": 600.0},
		{"k": "tone", "f0": 90.0, "f1": 45.0, "d": 0.1, "g": 0.3},
	])
	streams["win"] = _render([
		{"k": "tone", "f0": 440.0, "f1": 440.0, "d": 0.14, "g": 0.18},
		{"k": "tone", "f0": 554.0, "f1": 554.0, "d": 0.14, "g": 0.18, "at": 0.13},
		{"k": "tone", "f0": 659.0, "f1": 659.0, "d": 0.3, "g": 0.18, "at": 0.26},
	])


func play(name: String, gain := 1.0) -> void:
	if not streams.has(name) or gain <= 0.001:
		return
	var p := players[_next]
	_next = (_next + 1) % players.size()
	p.stream = streams[name]
	p.volume_db = linear_to_db(clampf(gain, 0.0001, 2.0))
	p.play()


func _render(parts: Array) -> AudioStreamWAV:
	var total := 0.0
	for part in parts:
		var at: float = part.get("at", 0.0)
		var d: float = part["d"]
		total = maxf(total, at + d)
	var n := int((total + 0.02) * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for part in parts:
		var at: float = part.get("at", 0.0)
		var d: float = part["d"]
		var g: float = part["g"]
		var off := int(at * RATE)
		var m := int(d * RATE)
		if part["k"] == "noise":
			var hp: float = part["hp"]
			var lp: float = part["lp"]
			var a_lp := 1.0 - exp(-TAU * lp / RATE)
			var a_hp := exp(-TAU * hp / RATE)
			var lpv := 0.0
			var hpv := 0.0
			var prev := 0.0
			for i in m:
				var x := rng.randf() * 2.0 - 1.0
				lpv += (x - lpv) * a_lp
				hpv = a_hp * (hpv + lpv - prev)
				prev = lpv
				var env := pow(1.0 - float(i) / m, 2.0)
				if off + i < n:
					buf[off + i] += hpv * g * env * 2.2
		else:
			var f0: float = part["f0"]
			var f1: float = part["f1"]
			var square: bool = part.get("w", "sine") == "square"
			var phase := 0.0
			for i in m:
				var u := float(i) / m
				var f := f0 * pow(f1 / f0, u)
				phase += TAU * f / RATE
				var v := sin(phase)
				if square:
					v = 1.0 if v >= 0.0 else -1.0
				var env := exp(-4.0 * u) * (1.0 - u) * minf(1.0, float(i) / 40.0)
				if off + i < n:
					buf[off + i] += v * g * env
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w
