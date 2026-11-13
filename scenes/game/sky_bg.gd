extends Control
# Revealed-cards backdrop: a daytime sky. A warm sun, soft clouds drifting by, a few birds
# flapping across, a hot-air balloon bobbing in the distance and rolling hills below.
# Drawn procedurally every frame; it never takes the mouse.

var _t : float = 0.0
var _clouds : Array = []
var _birds : Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 2468
	for i in range(6):
		var puffs := []
		for p in range(rng.randi_range(4, 6)):
			puffs.append({"o": Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.35, 0.25)), "r": rng.randf_range(0.45, 0.8)})
		_clouds.append({"x": rng.randf(), "y": rng.randf_range(0.08, 0.6), "s": rng.randf_range(26.0, 44.0),
				"sp": rng.randf_range(0.008, 0.02), "puffs": puffs})
	for i in range(5):
		_birds.append({"x": rng.randf(), "y": rng.randf_range(0.12, 0.5), "sp": rng.randf_range(0.03, 0.05),
				"s": rng.randf_range(6.0, 10.0), "ph": rng.randf() * TAU})

func _process(delta : float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 4.0 or h < 4.0:
		return
	# Sky gradient.
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([Color(0.26, 0.52, 0.9), Color(0.26, 0.52, 0.9), Color(0.72, 0.87, 1.0), Color(0.72, 0.87, 1.0)]))
	# Sun with a soft glow.
	var sun := Vector2(w * 0.86, h * 0.16)
	for i in range(6, 0, -1):
		draw_circle(sun, 18.0 + i * 9.0, Color(1.0, 0.95, 0.6, 0.05))
	draw_circle(sun, 20.0, Color(1.0, 0.93, 0.55))
	# Distant hot-air balloon.
	var bp := Vector2(w * 0.18, h * 0.28 + sin(_t * 0.6) * 8.0)
	draw_line(bp + Vector2(-6, 13), bp + Vector2(-3, 24), Color(0.35, 0.25, 0.15), 1.0, true)
	draw_line(bp + Vector2(6, 13), bp + Vector2(3, 24), Color(0.35, 0.25, 0.15), 1.0, true)
	draw_rect(Rect2(bp + Vector2(-4, 24), Vector2(8, 6)), Color(0.5, 0.33, 0.18))
	draw_circle(bp, 15.0, Color(0.95, 0.35, 0.3))
	draw_colored_polygon(PackedVector2Array([bp + Vector2(-13, 6), bp + Vector2(13, 6), bp + Vector2(5, 15), bp + Vector2(-5, 15)]), Color(0.95, 0.35, 0.3))
	draw_line(bp + Vector2(0, -15), bp + Vector2(0, 15), Color(1.0, 0.85, 0.3), 3.0, true)
	draw_arc(bp, 9.0, -PI / 2.0 - 0.9, -PI / 2.0 + 0.9, 10, Color(1.0, 0.85, 0.3, 0.8), 2.0, true)
	# Rolling hills.
	for layer in range(2):
		var pts := PackedVector2Array([Vector2(0, h)])
		var base : float = h * (0.86 + 0.06 * layer)
		for i in range(25):
			var f : float = i / 24.0
			pts.append(Vector2(f * w, base - (sin(f * (5.0 + layer * 2.0) + layer) * 0.5 + 0.5) * h * (0.08 - 0.03 * layer)))
		pts.append(Vector2(w, h))
		draw_colored_polygon(pts, Color(0.35, 0.68, 0.38) if layer == 0 else Color(0.27, 0.58, 0.3))
	# Clouds drifting by (a shadow puff under each).
	for c in _clouds:
		var x : float = (fposmod(float(c["x"]) + _t * float(c["sp"]), 1.3) - 0.15) * w
		var center := Vector2(x, float(c["y"]) * h)
		var s : float = c["s"]
		for p in c["puffs"]:
			draw_circle(center + (p["o"] as Vector2) * s + Vector2(0, 4), float(p["r"]) * s, Color(0.55, 0.65, 0.8, 0.35))
		for p in c["puffs"]:
			draw_circle(center + (p["o"] as Vector2) * s, float(p["r"]) * s, Color(1, 1, 1, 0.92))
	# Birds flapping across.
	for b in _birds:
		var x : float = (fposmod(float(b["x"]) + _t * float(b["sp"]), 1.2) - 0.1) * w
		var p := Vector2(x, float(b["y"]) * h + sin(_t * 1.5 + float(b["ph"])) * 6.0)
		var s : float = b["s"]
		var flap : float = sin(_t * 7.0 + float(b["ph"])) * 0.6
		var lw := p + Vector2(-s, -s * (0.3 + flap))
		var rw := p + Vector2(s, -s * (0.3 + flap))
		draw_polyline(PackedVector2Array([lw, p + Vector2(-s * 0.4, -s * 0.05), p]), Color(0.15, 0.17, 0.25), 2.0, true)
		draw_polyline(PackedVector2Array([p, p + Vector2(s * 0.4, -s * 0.05), rw]), Color(0.15, 0.17, 0.25), 2.0, true)
	# Border.
	draw_rect(Rect2(1, 1, w - 2, h - 2), Color(1, 1, 1, 0.65), false, 2.0)
