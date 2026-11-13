extends Control
# Phone layout: the shiny silver "TURN" badge shown in the inner top corner of whose turn it is
# (next to their last-action box). Polished silver bands, a dark edge, and a light glint that
# sweeps across it every few seconds. Everything is clipped to one rounded outline, so no light
# fringe shows round it. It ignores the mouse.

var _t : float = 0.0
var _font : Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load("res://scenes/game/badge_font.gd").make_font()

func _process(delta : float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var rad := minf(8.0, r.size.y * 0.3)
	var shape := _round_poly(r, rad)
	# Silver body: light at the top, a darker band through the middle, light again at the
	# bottom (like polished metal catching light).
	var stops := [Color(0.97, 0.98, 1.0), Color(0.78, 0.8, 0.85), Color(0.55, 0.57, 0.62),
			Color(0.72, 0.74, 0.79), Color(0.9, 0.91, 0.95)]
	draw_colored_polygon(shape, stops[2])
	var bands := 12
	for i in range(bands):
		var f := (float(i) + 0.5) / bands
		var seg := f * (stops.size() - 1)
		var k := int(floor(seg))
		var col : Color = stops[k].lerp(stops[mini(k + 1, stops.size() - 1)], seg - k)
		var y0 := r.size.y * float(i) / bands
		var y1 := minf(r.size.y, y0 + r.size.y / bands + 0.6)
		var band := PackedVector2Array([Vector2(0, y0), Vector2(r.size.x, y0), Vector2(r.size.x, y1), Vector2(0, y1)])
		for poly in Geometry2D.intersect_polygons(band, shape):
			_fill(poly, col)
	# A glint sweeping across every few seconds.
	var cycle := fmod(_t, 3.2) / 0.9
	if cycle < 1.0:
		var gx := lerpf(-r.size.y, r.size.x + r.size.y, cycle)
		var pts := PackedVector2Array([Vector2(gx, 0), Vector2(gx + 14.0, 0),
				Vector2(gx + 14.0 - r.size.y * 0.6, r.size.y), Vector2(gx - r.size.y * 0.6, r.size.y)])
		for poly in Geometry2D.intersect_polygons(pts, shape):
			_fill(poly, Color(1, 1, 1, 0.55))
	# A dark edge exactly on the outline (inset by half its width, so it stays inside).
	var edge := _round_poly(r.grow(-0.75), maxf(rad - 0.75, 1.0))
	edge.append(edge[0])
	draw_polyline(edge, Color(0.3, 0.32, 0.37), 1.5, true)
	# The word, engraved: dark with a light lip below.
	var fs := int(r.size.y * 0.58)
	var txt := "TURN"
	var tw := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := Vector2((r.size.x - tw) / 2.0, r.size.y / 2.0 + (_font.get_ascent(fs) - _font.get_descent(fs)) / 2.0)
	draw_string(_font, base + Vector2(0, 1.2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.75))
	draw_string(_font, base, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.16, 0.17, 0.2))

# Fills a clipped piece, skipping slivers (a glint just entering or leaving the badge clips to a
# near-zero sliver that can't be triangulated).
func _fill(poly : PackedVector2Array, col : Color) -> void:
	if poly.size() < 3:
		return
	var area := 0.0
	for i in range(poly.size()):
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		area += a.x * b.y - b.x * a.y
	if absf(area) < 2.0:
		return
	draw_colored_polygon(poly, col)

# A rounded rectangle as a polygon (the body, and the clip for the bands and the glint).
func _round_poly(r : Rect2, rad : float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [[r.position + Vector2(rad, rad), PI], [Vector2(r.end.x - rad, r.position.y + rad), PI * 1.5],
			[r.end - Vector2(rad, rad), 0.0], [Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5]]
	for cr in corners:
		for i in range(7):
			pts.append(cr[0] + Vector2.RIGHT.rotated(cr[1] + PI * 0.5 * i / 6.0) * rad)
	return pts
