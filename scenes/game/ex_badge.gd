extends "res://scenes/game/status_gem_badge.gd"
# "EX" badge (phone layout), shown for the rest of a strike made as an EX strike. It looks like
# the EX tag on the STRIKE banner (amber fill, thick white border, white lettering with a black
# outline), but its fill is a swirling galaxy: a glowing core, two spiral arms of stars turning
# slowly around it, dust lanes between them and a scatter of twinkling background stars.

var _arm_stars : Array = []
var _bg_stars : Array = []

func _setup() -> void:
	if text == "":
		text = "EX"
	outline_color = Color(0, 0, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	# Stars along two logarithmic spiral arms (u: 0 = core, 1 = arm tip).
	for arm in range(2):
		for i in range(70):
			var u := rng.randf()
			_arm_stars.append({"arm": arm, "u": u, "jit": rng.randf_range(-0.22, 0.22) * (0.4 + u),
					"r": rng.randf_range(0.8, 1.9), "tw": rng.randf_range(0.0, TAU), "warm": rng.randf()})
	for i in range(26):
		_bg_stars.append({"x": rng.randf(), "y": rng.randf(), "r": rng.randf_range(0.4, 1.1),
				"tw": rng.randf_range(0.0, TAU), "sp": rng.randf_range(1.5, 3.5)})

# Bigger lettering than the other badges: just two letters, as bold as the tag's.
func _fit_label() -> void:
	super._fit_label()
	if _label != null:
		_label.add_theme_font_size_override("font_size", maxi(14, int(size.y * 0.66)))
		_label.add_theme_constant_override("outline_size", maxi(5, int(size.y * 0.18)))

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

# A point on arm `arm` at `u` along it, the whole galaxy turned by `rot`.
func _spiral(c : Vector2, rx : float, ry : float, arm : int, u : float, jit : float, rot : float) -> Vector2:
	var a := rot + arm * PI + u * 3.4 + jit
	var r := 0.12 + 0.88 * u
	return c + Vector2(cos(a) * rx * r, sin(a) * ry * r)

func _draw_fill(inner : Rect2, poly : PackedVector2Array) -> void:
	var h := size.y
	var c := inner.get_center()
	# The tag's amber, deepening toward the edges like space around the galaxy.
	draw_colored_polygon(poly, Color(0.36, 0.15, 0.02))
	for i in range(7):
		var u := float(i + 1) / 7.0
		var ell := PackedVector2Array()
		var rx := inner.size.x * 0.62 * (1.0 - u * 0.85)
		var ry := inner.size.y * 0.75 * (1.0 - u * 0.8)
		for k in range(28):
			var a := TAU * k / 28.0
			ell.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		_draw_clipped(ell, poly, Color(0.85, 0.55, 0.05).lerp(Color(1.0, 0.8, 0.35), u * 0.6) * Color(1, 1, 1, 0.28 + 0.08 * u))
	# The galaxy, seen at a tilt (stretched wide to fill the pill), turning slowly.
	var rot := _t * 0.6
	var rx := inner.size.x * 0.48
	var ry := inner.size.y * 0.62
	# Soft glowing arms and darker dust lanes just behind them.
	for arm in range(2):
		for s in range(24):
			var u := float(s) / 23.0
			var p := _spiral(c, rx, ry, arm, u, 0.0, rot)
			var dust := _spiral(c, rx, ry, arm, u, -0.35, rot)
			var rad := h * lerpf(0.16, 0.08, u)
			if Geometry2D.is_point_in_polygon(dust, poly):
				draw_circle(dust, rad * 0.8, Color(0.18, 0.05, 0.0, 0.3 * sin(u * PI)))
			if Geometry2D.is_point_in_polygon(p, poly):
				draw_circle(p, rad, Color(1.0, 0.8, 0.4, 0.3 * (1.0 - u * 0.6)))
	# Faint background stars twinkling.
	for s in _bg_stars:
		var p := inner.position + Vector2(s["x"] * inner.size.x, s["y"] * inner.size.y)
		if Geometry2D.is_point_in_polygon(p, poly):
			var a := 0.35 + 0.35 * sin(_t * s["sp"] + s["tw"])
			draw_circle(p, s["r"] * h / 40.0, Color(1.0, 0.95, 0.85, a))
	# The arms' stars: blue-white and warm gold.
	for s in _arm_stars:
		var p := _spiral(c, rx, ry, s["arm"], s["u"], s["jit"], rot)
		if not Geometry2D.is_point_in_polygon(p, poly):
			continue
		var tw := 0.7 + 0.3 * sin(_t * 3.0 + s["tw"])
		var col := Color(0.8, 0.9, 1.0) if s["warm"] < 0.35 else Color(1.0, 0.88, 0.55)
		col.a = tw * lerpf(1.0, 0.55, s["u"])
		draw_circle(p, s["r"] * h / 40.0, col)
	# The bright core.
	var pulse := 0.85 + 0.15 * sin(_t * 1.8)
	for i in range(6):
		var u := float(i) / 5.0
		draw_circle(c, h * lerpf(0.34, 0.06, u) * pulse, Color(1.0, lerpf(0.75, 1.0, u), lerpf(0.3, 0.95, u), 0.12 + 0.12 * u))
	_draw_sparkle(c, h * 0.18 * pulse, Color(1, 1, 0.9, 0.6))
	_draw_glint(inner, poly, 4.0, 0.18)
