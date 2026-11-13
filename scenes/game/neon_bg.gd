extends Control
# Extra-cards backdrop: a cyberpunk night. A dark wall with a faint magenta perspective grid
# rolling toward the horizon, a little drifting haze, and a neon-sign frame (a cyan tube with a
# pink tube inside it) that glows with a gentle pulse. Labels listed in `glow_labels` get their
# outline pulsed along with it. Drawn procedurally every frame; it never takes the mouse.

var glow_labels : Array = []
var _t : float = 0.0
var _specks : Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for i in range(26):
		_specks.append({"x": rng.randf(), "y": rng.randf(), "sp": rng.randf_range(0.01, 0.035),
				"r": rng.randf_range(0.8, 2.0), "ph": rng.randf() * TAU,
				"c": Color(0.3, 1.0, 1.0) if rng.randf() < 0.5 else Color(1.0, 0.3, 0.85)})

func _process(delta : float) -> void:
	_t += delta
	var pulse := _pulse()
	for l in glow_labels:
		if is_instance_valid(l):
			l.add_theme_color_override("font_outline_color", Color(1.0, 0.18, 0.8, lerpf(0.55, 1.0, pulse)))
			l.add_theme_constant_override("outline_size", int(lerpf(7.0, 11.0, pulse)))
	queue_redraw()

func _pulse() -> float:
	return 0.5 + 0.5 * sin(_t * 2.2)

func _tube(rect : Rect2, col : Color, pulse : float, radius : float) -> void:
	# Soft glow: wide faint strokes under a bright thin core.
	for i in range(6, 0, -1):
		var a := (0.05 + 0.05 * pulse) * (7 - i) / 6.0
		_round_rect(rect, Color(col.r, col.g, col.b, a), 2.0 + i * 3.0, radius)
	_round_rect(rect, col, 3.0, radius)
	_round_rect(rect, Color(1, 1, 1, 0.55 + 0.3 * pulse), 1.0, radius)

func _round_rect(rect : Rect2, col : Color, width : float, radius : float) -> void:
	var pts := PackedVector2Array()
	var corners := [
		[rect.position + Vector2(rect.size.x - radius, radius), -PI / 2.0],
		[rect.position + rect.size - Vector2(radius, radius), 0.0],
		[rect.position + Vector2(radius, rect.size.y - radius), PI / 2.0],
		[rect.position + Vector2(radius, radius), PI],
	]
	for c in corners:
		for k in range(7):
			var ang : float = c[1] + (PI / 2.0) * k / 6.0
			pts.append(c[0] + Vector2(cos(ang), sin(ang)) * radius)
	pts.append(pts[0])
	draw_polyline(pts, col, width, true)

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 4.0 or h < 4.0:
		return
	var pulse := _pulse()
	# Night wall: deep indigo fading to near black.
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([Color(0.07, 0.03, 0.14), Color(0.05, 0.03, 0.12), Color(0.02, 0.01, 0.05), Color(0.03, 0.01, 0.06)]))
	# Perspective grid in the lower half, scrolling slowly toward the viewer.
	var horizon := h * 0.55
	var grid_col := Color(1.0, 0.2, 0.8, 0.16 + 0.06 * pulse)
	draw_rect(Rect2(0, horizon - 1.0, w, 2.0), Color(1.0, 0.3, 0.85, 0.35 + 0.15 * pulse))
	var vp := Vector2(w / 2.0, horizon)
	for i in range(-10, 11):
		var bx := w / 2.0 + i * w * 0.16
		draw_line(vp, Vector2(bx, h), grid_col, 1.0, true)
	var scroll := fmod(_t * 0.15, 1.0)
	for i in range(8):
		var f := (float(i) + scroll) / 8.0
		var y := horizon + (h - horizon) * f * f
		draw_line(Vector2(0, y), Vector2(w, y), grid_col, 1.0)
	# Faint drifting neon specks (rain-lit haze).
	for s in _specks:
		var x : float = fmod(s["x"] + _t * s["sp"], 1.0) * w
		var y : float = s["y"] * h
		var a : float = 0.25 + 0.25 * sin(_t * 1.7 + s["ph"])
		var c : Color = s["c"]
		draw_circle(Vector2(x, y), s["r"] * 2.5, Color(c.r, c.g, c.b, a * 0.25))
		draw_circle(Vector2(x, y), s["r"], Color(c.r, c.g, c.b, a))
	# The neon sign frame: a cyan outer tube with a pink tube inside it.
	_tube(Rect2(Vector2(7, 7), Vector2(w - 14, h - 14)), Color(0.25, 1.0, 1.0), pulse, 16.0)
	_tube(Rect2(Vector2(17, 17), Vector2(w - 34, h - 34)), Color(1.0, 0.25, 0.85), 1.0 - pulse * 0.6, 10.0)
