extends "res://scenes/game/status_gem_badge.gd"
# "STUN IMMUNE" badge (phone layout): a glowing yellow pill charged with electricity. Every
# so often a burst of crackling arcs jumps across the badge. Same white-and-black rim as the other badges.

var _arcs : Array = []        # current crackle: Array of PackedVector2Array in 0..1 units
var _arc_seed : int = 0
var _rng := RandomNumberGenerator.new()

func _setup() -> void:
	if text == "":
		text = "STUN IMMUNE"
	outline_color = Color(0.32, 0.14, 0.0)
	_rng.randomize()

func _make_arcs() -> void:
	_arcs.clear()
	for i in range(_rng.randi_range(1, 3)):
		var pts := PackedVector2Array()
		var x := _rng.randf_range(0.02, 0.3)
		var y := _rng.randf_range(0.15, 0.85)
		var x_end := _rng.randf_range(0.7, 0.98)
		var n := 10
		for k in range(n + 1):
			var u := float(k) / n
			pts.append(Vector2(lerpf(x, x_end, u), clampf(y + _rng.randf_range(-0.28, 0.28) * sin(u * PI), 0.05, 0.95)))
		_arcs.append(pts)

func _draw_fill(inner : Rect2, poly : PackedVector2Array) -> void:
	var h := size.y
	# Yellow, bright at the top, deepening to amber at the bottom.
	var cols := PackedColorArray()
	for p in poly:
		var v := clampf((p.y - inner.position.y) / inner.size.y, 0.0, 1.0)
		cols.append(Color(1.0, 0.93, 0.3).lerp(Color(0.96, 0.6, 0.04), v))
	draw_polygon(poly, cols)
	# Faint diagonal hazard-style banding, drifting slowly.
	var step := h * 0.6
	var off := fposmod(_t * h * 0.3, step)
	var x := inner.position.x - h + off
	while x < inner.end.x + h:
		var band := PackedVector2Array([Vector2(x, inner.position.y), Vector2(x + step * 0.35, inner.position.y),
				Vector2(x + step * 0.35 - h * 0.6, inner.end.y), Vector2(x - h * 0.6, inner.end.y)])
		_draw_clipped(band, poly, Color(1, 1, 1, 0.08))
		x += step
	# A burst of crackling arcs every couple of seconds, re-jagged every few frames.
	var cyc := fposmod(_t, 2.2)
	var bursting := cyc < 0.5
	if bursting:
		var seed_now := int(_t * 14.0)
		if seed_now != _arc_seed:
			_arc_seed = seed_now
			_make_arcs()
		for a in _arcs:
			var pts := PackedVector2Array()
			for q in a:
				pts.append(inner.position + Vector2(q.x * inner.size.x, q.y * inner.size.y))
			for seg in Geometry2D.intersect_polyline_with_polygon(pts, poly):
				if seg.size() >= 2:
					draw_polyline(seg, Color(1.0, 1.0, 0.75, 0.45), maxf(2.0, h * 0.11), true)
					draw_polyline(seg, Color(1, 1, 1, 0.95), maxf(1.0, h * 0.035), true)
	# Glossy top highlight.
	var gloss := _pill(Rect2(inner.position + Vector2(inner.size.y * 0.35, inner.size.y * 0.07),
			Vector2(inner.size.x - inner.size.y * 0.7, inner.size.y * 0.3)), 8)
	draw_colored_polygon(gloss, Color(1, 1, 1, 0.22))
	if bursting:
		draw_colored_polygon(poly, Color(1, 1, 0.9, 0.12 * (1.0 - cyc / 0.5)))
