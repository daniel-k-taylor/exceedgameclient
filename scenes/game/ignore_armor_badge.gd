extends "res://scenes/game/status_gem_badge.gd"
# "IGNORE ARMOR" badge (phone layout): a shiny faceted amethyst that has been cracked in two.
# The facets catch the light in different shades of violet, a jagged fracture runs through
# the stone (the right-hand piece knocked slightly out of line), stars twinkle on the facets
# and a glint sweeps across now and then. Same white-and-black rim as the other badges.

var _facets : Array = []   # each: {"pts": PackedVector2Array, "shade": float, "right": bool}
var _crack : PackedVector2Array
var _branch : PackedVector2Array
var _built_for : Vector2 = Vector2.ZERO
const SPARKLES := [Vector2(0.2, 0.3), Vector2(0.72, 0.25), Vector2(0.86, 0.7), Vector2(0.33, 0.78)]

func _setup() -> void:
	if text == "":
		text = "IGNORE ARMOR"
	outline_color = Color(0.17, 0.02, 0.27)

func _crack_x(inner : Rect2, y : float) -> float:
	# x of the fracture line at height y (pixels).
	for i in range(_crack.size() - 1):
		var a := _crack[i]
		var b := _crack[i + 1]
		if y >= a.y and y <= b.y:
			return lerpf(a.x, b.x, (y - a.y) / maxf(0.001, b.y - a.y))
	return inner.position.x + inner.size.x * 0.5

func _build(inner : Rect2, poly : PackedVector2Array) -> void:
	_built_for = inner.size
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var pts := PackedVector2Array(poly)
	# Extra points along the flat top and bottom edges, and a row of interior points, so the
	# stone breaks up into facets.
	var r := inner.size.y / 2.0
	var flat := inner.size.x - 2.0 * r
	for k in range(1, 5):
		var x := inner.position.x + r + flat * k / 5.0
		pts.append(Vector2(x + rng.randf_range(-3, 3), inner.position.y + 0.5))
		pts.append(Vector2(x + rng.randf_range(-3, 3), inner.end.y - 0.5))
	for k in range(6):
		var u := (k + 0.5) / 6.0
		pts.append(inner.position + Vector2(inner.size.x * u + rng.randf_range(-4, 4),
				inner.size.y * (0.5 + rng.randf_range(-0.22, 0.22))))
	# The fracture, top to bottom, slightly left of centre.
	_crack = PackedVector2Array()
	var steps := 6
	for k in range(steps + 1):
		var v := float(k) / steps
		var x := inner.position.x + inner.size.x * (0.44 + 0.08 * v) + (rng.randf_range(-5, 5) if k > 0 and k < steps else 0.0)
		_crack.append(Vector2(x, lerpf(inner.position.y - 1.0, inner.end.y + 1.0, v)))
	_branch = PackedVector2Array([_crack[2], _crack[2] + Vector2(-inner.size.y * 0.35, inner.size.y * 0.12),
			_crack[2] + Vector2(-inner.size.y * 0.55, inner.size.y * 0.32)])
	var tris := Geometry2D.triangulate_delaunay(pts)
	_facets.clear()
	for i in range(0, tris.size(), 3):
		var a := pts[tris[i]]
		var b := pts[tris[i + 1]]
		var c := pts[tris[i + 2]]
		if absf((b - a).cross(c - a)) < 1.0:
			continue
		var cen := (a + b + c) / 3.0
		# Light from the top left: upper-left facets brighter, plus some facet-to-facet variety.
		var lit := 1.0 - (cen.y - inner.position.y) / inner.size.y * 0.6 - (cen.x - inner.position.x) / inner.size.x * 0.25
		_facets.append({"pts": PackedVector2Array([a, b, c]), "shade": clampf(lit + rng.randf_range(-0.35, 0.35), 0.0, 1.0),
				"right": cen.x > _crack_x(inner, cen.y)})

func _facet_color(shade : float) -> Color:
	var deep := Color(0.24, 0.05, 0.38)
	var mid := Color(0.55, 0.22, 0.8)
	var light := Color(0.86, 0.66, 1.0)
	return deep.lerp(mid, shade * 2.0) if shade < 0.5 else mid.lerp(light, (shade - 0.5) * 2.0)

func _draw_fill(inner : Rect2, poly : PackedVector2Array) -> void:
	if _built_for != inner.size:
		_build(inner, poly)
	var h := size.y
	draw_colored_polygon(poly, Color(0.08, 0.0, 0.12)) # the dark gap shows through the crack
	# The right-hand piece is knocked a little down and out of line.
	var shift := Vector2(maxf(1.0, h * 0.03), maxf(1.0, h * 0.035))
	for f in _facets:
		var pts : PackedVector2Array = f["pts"]
		if f["right"]:
			var moved := PackedVector2Array()
			for p in pts:
				moved.append(p + shift)
			pts = moved
		# Each facet shimmers a little as the light moves.
		var s : float = f["shade"] + 0.08 * sin(_t * 1.7 + pts[0].x * 0.15)
		_draw_clipped(pts, poly, _facet_color(clampf(s, 0.0, 1.0)))
	# Facet edges: thin pale lines.
	for f in _facets:
		var pts : PackedVector2Array = f["pts"]
		var off : Vector2 = shift if f["right"] else Vector2.ZERO
		var loop := PackedVector2Array([pts[0] + off, pts[1] + off, pts[2] + off, pts[0] + off])
		for seg in Geometry2D.intersect_polyline_with_polygon(loop, poly):
			if seg.size() >= 2:
				draw_polyline(seg, Color(0.95, 0.85, 1.0, 0.18), 1.0, true)
	# The fracture: a dark split with a bright freshly-broken edge along it, plus a branch.
	var cw := maxf(2.0, h * 0.07)
	for line in [_crack, _branch]:
		for seg in Geometry2D.intersect_polyline_with_polygon(line, poly):
			if seg.size() >= 2:
				draw_polyline(seg, Color(0.06, 0.0, 0.1, 0.95), cw, true)
				var edge := PackedVector2Array()
				for p in seg:
					edge.append(p + Vector2(-cw * 0.55, 0))
				draw_polyline(edge, Color(0.97, 0.88, 1.0, 0.75), maxf(1.0, cw * 0.3), true)
	# Little chips knocked out along the fracture.
	for i in [1, 3, 5]:
		var c := _crack[i]
		var cs := h * 0.08
		_draw_clipped(PackedVector2Array([c + Vector2(-cs, -cs * 0.4), c + Vector2(cs * 0.3, -cs * 0.2), c + Vector2(-cs * 0.2, cs * 0.6)]),
				poly, Color(0.1, 0.0, 0.16))
	# Gloss and a sweeping glint, then twinkling stars on the facets.
	var gloss := _pill(Rect2(inner.position + Vector2(inner.size.y * 0.35, inner.size.y * 0.07),
			Vector2(inner.size.x - inner.size.y * 0.7, inner.size.y * 0.28)), 8)
	draw_colored_polygon(gloss, Color(1, 1, 1, 0.16))
	_draw_glint(inner, poly, 2.6, 0.3)
	for i in range(SPARKLES.size()):
		var tw := sin(_t * 2.3 + i * 1.9)
		if tw > 0.3:
			var p : Vector2 = inner.position + Vector2(SPARKLES[i].x * inner.size.x, SPARKLES[i].y * inner.size.y)
			_draw_sparkle(p, h * 0.16 * (tw - 0.3) / 0.7, Color(1, 0.95, 1, 0.9))
