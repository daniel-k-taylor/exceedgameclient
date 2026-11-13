extends "res://scenes/game/status_gem_badge.gd"
# "WILD SWING" badge (phone layout). It looks like the WILD SWING tag on the STRIKE banner
# (purple fill, thick white border, white lettering with a black outline), but its fill fizzes:
# bubbles of every size rise from the bottom, wobbling as they go, and pop near the top in a
# little ring, over a soft purple glow.

var _bubbles : Array = []

func _setup() -> void:
	if text == "":
		text = "WILD SWING"
	outline_color = Color(0, 0, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7717
	for i in range(34):
		_bubbles.append({"x": rng.randf(), "ph": rng.randf(), "sp": rng.randf_range(0.45, 1.1),
				"r": rng.randf_range(0.8, 3.2), "wob": rng.randf_range(0.0, TAU),
				"top": rng.randf_range(0.05, 0.3)})

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 10.0 or h < 10.0:
		return
	# Like the tag: a thick white border straight around the coloured fill.
	var rim := maxf(3.0, h * 0.1)
	draw_colored_polygon(_pill(Rect2(Vector2.ZERO, size)), Color(1, 1, 1))
	var inner := Rect2(Vector2(rim, rim), size - Vector2(rim, rim) * 2.0)
	_draw_fill(inner, _pill(inner))

func _draw_fill(inner : Rect2, poly : PackedVector2Array) -> void:
	var h := size.y
	var c := inner.get_center()
	# The tag's purple, darker at the bottom and glowing a little lighter toward the top.
	draw_colored_polygon(poly, Color(0.3, 0.07, 0.46))
	var top := PackedVector2Array([inner.position - Vector2(2, 2), Vector2(inner.end.x + 2, inner.position.y - 2),
			Vector2(inner.end.x + 2, c.y), Vector2(inner.position.x - 2, c.y)])
	_draw_clipped(top, poly, Color(0.55, 0.2, 0.78, 0.55))
	for i in range(4):
		var u := float(i + 1) / 4.0
		var ell := PackedVector2Array()
		for k in range(24):
			var a := TAU * k / 24.0
			ell.append(c + Vector2(cos(a) * inner.size.x * 0.5 * (1.1 - u * 0.5), sin(a) * inner.size.y * 0.6 * (1.1 - u * 0.5)))
		_draw_clipped(ell, poly, Color(0.62, 0.3, 0.85, 0.12))
	# Fizzing bubbles: rising, wobbling, popping near the top.
	var s := h / 40.0
	for b in _bubbles:
		var v : float = fposmod(b["ph"] + _t * b["sp"] * 0.55, 1.0) # 0 = bottom, 1 = popped
		var y : float = lerpf(inner.end.y + b["r"] * s, inner.position.y + inner.size.y * b["top"], v)
		var x : float = inner.position.x + b["x"] * inner.size.x + sin(_t * 4.0 + b["wob"]) * 1.6 * s
		var p := Vector2(x, y)
		var r : float = b["r"] * s * (0.7 + 0.5 * v)
		if v > 0.9:
			# Pop: a quick thin ring that spreads and fades.
			var k := (v - 0.9) / 0.1
			if Geometry2D.is_point_in_polygon(p, poly):
				draw_arc(p, r * (1.0 + k * 1.2), 0.0, TAU, 12, Color(1, 0.9, 1, 0.6 * (1.0 - k)), 1.0, true)
			continue
		if not Geometry2D.is_point_in_polygon(p, poly):
			continue
		draw_circle(p, r, Color(0.85, 0.65, 1.0, 0.18))
		draw_arc(p, r, 0.0, TAU, 14, Color(0.95, 0.85, 1.0, 0.75), maxf(1.0, s), true)
		draw_circle(p + Vector2(-r * 0.35, -r * 0.35), maxf(0.6, r * 0.28), Color(1, 1, 1, 0.9))
	_draw_glint(inner, poly, 3.8, 0.16)
