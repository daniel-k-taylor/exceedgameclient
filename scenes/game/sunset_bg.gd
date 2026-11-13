extends Control
# Revealed-cards backdrop (sunset theme): a late-stage sunset. The sky runs from dusky violet
# overhead through pink, red and orange down to a glowing gold horizon, with a half-sunk sun.
# Long, flat, wispy clouds drift slowly across, lit pink and orange from below; a few birds
# glide by, and now and then a small plane crosses overhead with blinking lights and a fading
# contrail. Dark hills sit in silhouette at the bottom. Drawn procedurally every frame; it
# never takes the mouse. (The daytime sky theme, sky_bg.gd, is kept as an alternative.)

var _t : float = 0.0
var _wisps : Array = []
var _birds : Array = []

const PLANE_PERIOD := 26.0 # seconds between plane crossings
const PLANE_CROSS := 14.0  # seconds a crossing takes

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 7731
	# Each wisp is a long thin streak built from a few stretched, overlapping strokes.
	for i in range(9):
		var strands := []
		for k in range(rng.randi_range(3, 5)):
			strands.append({"dx": rng.randf_range(-0.25, 0.25), "dy": rng.randf_range(-5.0, 5.0),
					"len": rng.randf_range(0.5, 1.0), "th": rng.randf_range(3.0, 7.0)})
		_wisps.append({"x": rng.randf(), "y": rng.randf_range(0.12, 0.62), "w": rng.randf_range(90.0, 200.0),
				"sp": rng.randf_range(0.004, 0.012), "strands": strands, "a": rng.randf_range(0.5, 0.8)})
	for i in range(4):
		_birds.append({"x": rng.randf(), "y": rng.randf_range(0.25, 0.5), "sp": rng.randf_range(0.02, 0.035),
				"s": rng.randf_range(5.0, 8.0), "ph": rng.randf() * TAU})

func _process(delta : float) -> void:
	_t += delta
	queue_redraw()

func _band(y0 : float, y1 : float, c0 : Color, c1 : Color, w : float) -> void:
	draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(w, y0), Vector2(w, y1), Vector2(0, y1)]),
			PackedColorArray([c0, c0, c1, c1]))

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 4.0 or h < 4.0:
		return
	var horizon := h * 0.8
	# Sky: violet -> magenta pink -> red -> orange -> gold at the horizon.
	var stops := [
		[0.0, Color(0.16, 0.08, 0.24)],
		[0.22, Color(0.42, 0.12, 0.34)],
		[0.45, Color(0.74, 0.18, 0.3)],
		[0.65, Color(0.9, 0.32, 0.16)],
		[0.85, Color(0.98, 0.56, 0.16)],
		[1.0, Color(1.0, 0.78, 0.3)],
	]
	for i in range(stops.size() - 1):
		_band(horizon * stops[i][0], horizon * stops[i + 1][0], stops[i][1], stops[i + 1][1], w)
	# Sun: half sunk into the horizon, with a broad warm glow.
	var sun := Vector2(w * 0.38, horizon + 6.0)
	for i in range(10, 0, -1):
		draw_circle(sun, 30.0 + i * 16.0, Color(1.0, 0.55, 0.2, 0.045))
	draw_circle(sun, 34.0, Color(1.0, 0.72, 0.32))
	draw_circle(sun, 28.0, Color(1.0, 0.84, 0.48))
	# Long flat wispy clouds, lit from below: a pale top streak over a darker underside.
	for c in _wisps:
		var cx : float = fmod(c["x"] + _t * c["sp"], 1.4) - 0.2
		var cy : float = c["y"] * horizon
		var cw : float = c["w"]
		var low : float = clampf((cy / horizon - 0.1) / 0.6, 0.0, 1.0) # lower clouds glow warmer
		var lit := Color(1.0, 0.62 + 0.2 * low, 0.5 + 0.1 * low).lerp(Color(1.0, 0.45, 0.6), 1.0 - low)
		var shade := Color(0.35, 0.12, 0.28)
		for st in c["strands"]:
			var sx : float = cx * w + st["dx"] * cw
			var sl : float = cw * st["len"]
			var y : float = cy + st["dy"]
			var a : float = c["a"]
			draw_line(Vector2(sx - sl / 2.0, y + 2.0), Vector2(sx + sl / 2.0, y + 2.0), Color(shade.r, shade.g, shade.b, a * 0.45), st["th"] + 1.5, true)
			draw_line(Vector2(sx - sl / 2.0, y), Vector2(sx + sl / 2.0, y), Color(lit.r, lit.g, lit.b, a), st["th"], true)
			# Feathered, thinner ends.
			draw_line(Vector2(sx - sl / 2.0 - sl * 0.25, y + 1.0), Vector2(sx - sl / 2.0, y), Color(lit.r, lit.g, lit.b, a * 0.4), st["th"] * 0.5, true)
			draw_line(Vector2(sx + sl / 2.0, y), Vector2(sx + sl / 2.0 + sl * 0.25, y - 1.0), Color(lit.r, lit.g, lit.b, a * 0.4), st["th"] * 0.5, true)
	# A plane crossing high overhead now and then, leaving a contrail that fades.
	var pt : float = fmod(_t + 4.0, PLANE_PERIOD)
	if pt < PLANE_CROSS + 4.0:
		var u : float = pt / PLANE_CROSS
		var start := Vector2(-30.0, h * 0.2)
		var end := Vector2(w + 30.0, h * 0.08)
		var pos := start.lerp(end, minf(u, 1.0))
		var dir := (end - start).normalized()
		# Contrail: from the plane back toward where it entered, fading out behind it.
		var trail_len := w * 0.55
		for k in range(12):
			var f0 := float(k) / 12.0
			var f1 := float(k + 1) / 12.0
			var p0 := pos - dir * trail_len * f0
			var p1 := pos - dir * trail_len * f1
			var fade := (1.0 - f0) * clampf(1.0 - (u - 1.0) * 0.5, 0.0, 1.0)
			draw_line(p0, p1, Color(1.0, 0.85, 0.8, 0.35 * fade), 2.0 + f0 * 3.0, true)
		if u <= 1.0:
			# The plane: a small dark silhouette with wings and tail.
			var n := Vector2(-dir.y, dir.x)
			var body := PackedVector2Array([pos + dir * 9.0, pos - dir * 8.0 + n * 1.6, pos - dir * 8.0 - n * 1.6])
			draw_colored_polygon(body, Color(0.12, 0.06, 0.12))
			draw_line(pos + n * 7.0 - dir * 1.0, pos - n * 7.0 - dir * 1.0, Color(0.12, 0.06, 0.12), 2.0, true)
			draw_line(pos - dir * 7.0 + n * 3.0, pos - dir * 7.0 - n * 3.0, Color(0.12, 0.06, 0.12), 1.5, true)
			# Blinking navigation lights.
			if fmod(_t, 1.0) < 0.25:
				draw_circle(pos + n * 7.0, 1.6, Color(1.0, 0.2, 0.2))
				draw_circle(pos - n * 7.0, 1.6, Color(0.3, 1.0, 0.4))
			if fmod(_t + 0.5, 1.2) < 0.15:
				draw_circle(pos, 1.8, Color(1, 1, 1))
	# Birds gliding home, as dark silhouettes.
	for b in _birds:
		var bx : float = fmod(b["x"] + _t * b["sp"], 1.2) * w - 0.1 * w
		var by : float = b["y"] * horizon + sin(_t * 0.8 + b["ph"]) * 3.0
		var flap : float = sin(_t * 5.0 + b["ph"]) * 0.5 + 0.5
		var s : float = b["s"]
		var wing := Vector2(s, -s * 0.5 * flap - 1.0)
		draw_polyline(PackedVector2Array([Vector2(bx, by) + Vector2(-wing.x, wing.y), Vector2(bx, by), Vector2(bx, by) + wing]),
				Color(0.18, 0.06, 0.14, 0.9), 1.6, true)
	# Silhouetted hills in front of the sun.
	var back := PackedVector2Array()
	var front := PackedVector2Array()
	var steps := 30
	for i in range(steps + 1):
		var x := w * i / steps
		back.append(Vector2(x, horizon - 10.0 - sin(x / w * PI * 2.2 + 0.6) * 12.0 - sin(x / w * PI * 5.0) * 4.0))
		front.append(Vector2(x, horizon + 14.0 - sin(x / w * PI * 1.4 + 2.0) * 16.0))
	back.append(Vector2(w, h))
	back.append(Vector2(0, h))
	front.append(Vector2(w, h))
	front.append(Vector2(0, h))
	draw_colored_polygon(back, Color(0.32, 0.1, 0.18))
	draw_colored_polygon(front, Color(0.14, 0.04, 0.1))
