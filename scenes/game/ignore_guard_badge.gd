extends "res://scenes/game/status_gem_badge.gd"
# "IGNORE GUARD" badge (phone layout): an emerald-cut emerald, its stepped facets in shades of
# green, with a golden light glowing deep inside it: a warm core that slowly pulses, rays
# turning behind the table facet and motes of gold drifting up through the stone. Same
# white-and-black rim as the other badges.

var _motes : Array = []

func _setup() -> void:
	if text == "":
		text = "IGNORE GUARD"
	outline_color = Color(0.0, 0.17, 0.08)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9091
	for i in range(10):
		_motes.append({"x": rng.randf_range(0.15, 0.85), "ph": rng.randf(), "sp": rng.randf_range(0.25, 0.5),
				"r": rng.randf_range(0.8, 1.8), "wob": rng.randf_range(0.0, TAU)})

# The pill shrunk toward its centre by `k` (0 = full size).
func _ring(inner : Rect2, k : float) -> Rect2:
	var d := inner.size.y * 0.5 * k
	return Rect2(inner.position + Vector2(d, d), inner.size - Vector2(d, d) * 2.0)

func _draw_fill(inner : Rect2, poly : PackedVector2Array) -> void:
	var h := size.y
	var c := inner.get_center()
	# Emerald cut: concentric steps, each split into a lit upper half and a shaded lower half.
	var steps := [[0.0, Color(0.05, 0.5, 0.25), Color(0.0, 0.24, 0.1)],
			[0.28, Color(0.1, 0.62, 0.32), Color(0.02, 0.32, 0.15)],
			[0.52, Color(0.18, 0.72, 0.4), Color(0.04, 0.4, 0.2)]]
	for s in steps:
		var ring := _pill(_ring(inner, s[0]))
		draw_colored_polygon(ring, s[2])
		var top_half := PackedVector2Array([Vector2(inner.position.x - 2, inner.position.y - 2), Vector2(inner.end.x + 2, inner.position.y - 2),
				Vector2(inner.end.x + 2, c.y - h * 0.05), Vector2(inner.position.x - 2, c.y + h * 0.05)])
		_draw_clipped(top_half, ring, s[1])
		draw_polyline(_close(ring), Color(0.7, 1.0, 0.8, 0.35), 1.0, true)
	# The table (flat top facet), where the golden light shows through most strongly.
	var table := _pill(_ring(inner, 0.72))
	draw_colored_polygon(table, Color(0.12, 0.6, 0.3))
	# Corner bevel lines from the outer pill to the table, as on a step cut.
	var ti := _ring(inner, 0.72)
	for p in [[inner.position + Vector2(inner.size.y * 0.15, inner.size.y * 0.15), ti.position + Vector2(ti.size.y * 0.15, ti.size.y * 0.15)],
			[Vector2(inner.end.x - inner.size.y * 0.15, inner.position.y + inner.size.y * 0.15), Vector2(ti.end.x - ti.size.y * 0.15, ti.position.y + ti.size.y * 0.15)],
			[Vector2(inner.position.x + inner.size.y * 0.15, inner.end.y - inner.size.y * 0.15), Vector2(ti.position.x + ti.size.y * 0.15, ti.end.y - ti.size.y * 0.15)],
			[inner.end - Vector2(inner.size.y * 0.15, inner.size.y * 0.15), ti.end - Vector2(ti.size.y * 0.15, ti.size.y * 0.15)]]:
		draw_line(p[0], p[1], Color(0.75, 1.0, 0.85, 0.3), 1.0, true)
	# The golden light inside: soft layered glow, pulsing.
	var pulse := 0.75 + 0.25 * sin(_t * 2.2)
	var gr := inner.size.x * 0.32
	for i in range(8):
		var u := float(i) / 7.0
		var ell := PackedVector2Array()
		var rx := gr * lerpf(1.0, 0.12, u) * (0.9 + 0.1 * pulse)
		var ry := inner.size.y * 0.42 * lerpf(1.0, 0.25, u)
		for k in range(24):
			var a := TAU * k / 24.0
			ell.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		_draw_clipped(ell, poly, Color(1.0, lerpf(0.72, 0.95, u), lerpf(0.15, 0.6, u), 0.1 + 0.07 * u * pulse))
	# Rays of gold turning slowly behind the table.
	for k in range(6):
		var a := _t * 0.35 + TAU * k / 6.0
		var d := Vector2(cos(a), sin(a) * 0.45)
		var side := Vector2(-d.y, d.x) * h * 0.06
		var tip := c + d * gr * 1.1
		_draw_clipped(PackedVector2Array([c + side, tip, c - side]), table, Color(1.0, 0.85, 0.35, 0.16 * pulse))
	# Motes of gold drifting up through the stone.
	for m in _motes:
		var v := fposmod(m["ph"] - _t * m["sp"], 1.0) # 1 = bottom, 0 = top
		var p := inner.position + Vector2((m["x"] + 0.03 * sin(_t * 2.0 + m["wob"])) * inner.size.x, (0.12 + 0.76 * v) * inner.size.y)
		var a := sin(v * PI)
		draw_circle(p, m["r"] * 2.2 * h / 40.0, Color(1.0, 0.8, 0.3, 0.18 * a))
		draw_circle(p, m["r"] * h / 40.0, Color(1.0, 0.95, 0.6, 0.85 * a))
	# Gloss and a slow glint.
	var gloss := _pill(Rect2(inner.position + Vector2(inner.size.y * 0.35, inner.size.y * 0.06),
			Vector2(inner.size.x - inner.size.y * 0.7, inner.size.y * 0.24)), 8)
	draw_colored_polygon(gloss, Color(1, 1, 1, 0.14))
	_draw_glint(inner, poly, 3.4, 0.22)

func _close(p : PackedVector2Array) -> PackedVector2Array:
	var q := p.duplicate()
	q.append(p[0])
	return q
