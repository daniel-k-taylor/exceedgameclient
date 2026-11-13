extends Control
# Gauge-reference backdrop (racetrack theme): a small racetrack seen from straight above. Four
# race cars lap a rounded asphalt circuit with red-and-white kerbs at the corners and a
# chequered start / finish line, swapping places as they go. Everything around the track is
# cement: slab joints, oil stains, painted arrows and parking lines, traffic cones, stacked
# tyres, striped barriers and a manhole cover, with a plain street along the top (under the
# window's title). Drawn procedurally every frame; it never takes the mouse.

var _t : float = 0.0
var _specks : Array = []
var _cars : Array = []

const CAR_COLORS := [Color(0.88, 0.12, 0.12), Color(0.12, 0.42, 0.95), Color(1.0, 0.78, 0.1), Color(0.1, 0.7, 0.3)]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in range(420):
		_specks.append({"p": Vector2(rng.randf(), rng.randf()), "r": rng.randf_range(0.6, 1.6),
				"c": rng.randf_range(-0.08, 0.06)})
	for i in range(4):
		_cars.append({"u": 0.07 * i + rng.randf_range(0.0, 0.03), "sp": rng.randf_range(0.052, 0.062),
				"lane_ph": rng.randf() * TAU, "lane_sp": rng.randf_range(0.25, 0.45), "col": CAR_COLORS[i], "num": i + 1,
				"wob": rng.randf() * TAU})

func _process(delta : float) -> void:
	_t += delta
	queue_redraw()

# ---- geometry -------------------------------------------------------------------------------

func _layout() -> Dictionary:
	var w := size.x
	var h := size.y
	var strip := clampf(h * 0.2, 70.0, 150.0) # buildings along the top
	var track_w := clampf(minf(w, h) * 0.13, 40.0, 70.0)
	var outer := Rect2(Vector2(w * 0.05, strip + 10.0), Vector2(w * 0.9, h - strip - 10.0 - h * 0.04))
	# The racing line runs down the middle of the asphalt.
	var line := outer.grow(-track_w / 2.0)
	var r := minf(line.size.x, line.size.y) * 0.42
	return {"strip": strip, "tw": track_w, "outer": outer, "line": line, "r": r}

# Point and heading at fraction u (0..1) round a rounded rectangle, clockwise from the top-left.
func _path(rect : Rect2, r : float, u : float) -> Array:
	var sx := rect.size.x - 2.0 * r
	var sy := rect.size.y - 2.0 * r
	var arc := PI / 2.0 * r
	var total := 2.0 * sx + 2.0 * sy + 4.0 * arc
	var d := fposmod(u, 1.0) * total
	var p := rect.position
	var segs := [
		["s", Vector2(p.x + r, p.y), Vector2(1, 0), sx],
		["a", Vector2(p.x + rect.size.x - r, p.y + r), -PI / 2.0, arc],
		["s", Vector2(p.x + rect.size.x, p.y + r), Vector2(0, 1), sy],
		["a", Vector2(p.x + rect.size.x - r, p.y + rect.size.y - r), 0.0, arc],
		["s", Vector2(p.x + rect.size.x - r, p.y + rect.size.y), Vector2(-1, 0), sx],
		["a", Vector2(p.x + r, p.y + rect.size.y - r), PI / 2.0, arc],
		["s", Vector2(p.x, p.y + rect.size.y - r), Vector2(0, -1), sy],
		["a", Vector2(p.x + r, p.y + r), PI, arc],
	]
	for sg in segs:
		if d <= sg[3] or sg == segs[-1]:
			if sg[0] == "s":
				return [sg[1] + sg[2] * d, sg[2].angle(), false]
			var a : float = sg[2] + d / r
			var c : Vector2 = sg[1]
			return [c + Vector2(cos(a), sin(a)) * r, a + PI / 2.0, true]
		d -= sg[3]
	return [rect.position, 0.0, false]

func _loop(rect : Rect2, r : float, n : int = 120) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in range(n + 1):
		pts.append(_path(rect, r, float(k) / n)[0])
	return pts

# ---- drawing --------------------------------------------------------------------------------

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 40.0 or h < 40.0:
		return
	var L := _layout()
	var tw : float = L["tw"]
	var line : Rect2 = L["line"]
	var r : float = L["r"]
	# Cement everywhere, in slabs.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.62, 0.62, 0.6))
	for s in _specks:
		var c := 0.62 + float(s["c"])
		draw_circle(s["p"] * size, s["r"], Color(c, c, c * 0.98, 0.7))
	var slab := 90.0
	var x := slab
	while x < w:
		draw_line(Vector2(x, 0), Vector2(x, h), Color(0.48, 0.48, 0.47, 0.6), 1.5)
		x += slab
	var y := slab
	while y < h:
		draw_line(Vector2(0, y), Vector2(w, y), Color(0.48, 0.48, 0.47, 0.6), 1.5)
		y += slab
	_draw_buildings(L)
	# The track: kerbs, asphalt, edge lines.
	var loop := _loop(line, r)
	draw_polyline(loop, Color(0.95, 0.95, 0.95), tw + 10.0, true)
	_draw_kerbs(line, r, tw)
	draw_polyline(loop, Color(0.2, 0.2, 0.22), tw, true)
	var inner_edge := _loop(line.grow(-tw / 2.0 + 3.0), maxf(2.0, r - tw / 2.0 + 3.0))
	var outer_edge := _loop(line.grow(tw / 2.0 - 3.0), r + tw / 2.0 - 3.0)
	draw_polyline(inner_edge, Color(1, 1, 1, 0.85), 1.5, true)
	draw_polyline(outer_edge, Color(1, 1, 1, 0.85), 1.5, true)
	# Rubber laid down along the racing line.
	draw_polyline(loop, Color(0.12, 0.12, 0.13, 0.5), tw * 0.35, true)
	_draw_start_line(line, tw)
	_draw_props(L)
	# The cars, the leader drawn last.
	for i in range(_cars.size()):
		_draw_car(i, line, r, tw)

func _draw_kerbs(line : Rect2, r : float, tw : float) -> void:
	# Red / white blocks round each corner, on both edges of the asphalt.
	var n := 240
	for k in range(n):
		var u0 := float(k) / n
		var a := _path(line, r, u0)
		if not a[2]:
			continue
		var b := _path(line, r, u0 + 1.0 / n)
		var col := Color(0.9, 0.12, 0.12) if (k / 3) % 2 == 0 else Color(0.98, 0.98, 0.98)
		var nrm := Vector2(cos(a[1] - PI / 2.0), sin(a[1] - PI / 2.0)) # points outwards
		for side in [-1.0, 1.0]:
			var off : Vector2 = nrm * side * (tw / 2.0 + 2.0)
			draw_line(a[0] + off, b[0] + off, col, 5.0)

func _draw_start_line(line : Rect2, tw : float) -> void:
	# Chequered line across the bottom straight.
	var cx := line.get_center().x
	var y0 := line.end.y - tw / 2.0
	var cells := 6
	var cs := tw / cells
	for row in range(2):
		for c in range(cells):
			var col := Color(1, 1, 1) if (row + c) % 2 == 0 else Color(0.05, 0.05, 0.05)
			draw_rect(Rect2(Vector2(cx - cs + row * cs, y0 + c * cs), Vector2(cs, cs)), col)

func _draw_car(i : int, line : Rect2, r : float, tw : float) -> void:
	var car : Dictionary = _cars[i]
	var u : float = car["u"] + _t * float(car["sp"]) + 0.012 * sin(_t * 0.31 + float(car["wob"]))
	var pr := _path(line, r, u)
	var lane := sin(_t * float(car["lane_sp"]) + float(car["lane_ph"])) * tw * 0.22
	var heading : float = pr[1]
	var nrm := Vector2(cos(heading + PI / 2.0), sin(heading + PI / 2.0))
	var pos : Vector2 = pr[0] + nrm * lane
	var len := tw * 0.46
	var wid := len * 0.46
	draw_set_transform(pos, heading, Vector2.ONE)
	# Shadow, tyres, body, cockpit, wing, number.
	draw_rect(Rect2(Vector2(-len / 2.0 + 2.0, -wid / 2.0 + 2.0), Vector2(len, wid)), Color(0, 0, 0, 0.3))
	var tyre := Vector2(len * 0.2, wid * 0.24)
	for fx in [-0.3, 0.28]:
		for fy in [-1.0, 1.0]:
			draw_rect(Rect2(Vector2(len * fx - tyre.x / 2.0, fy * (wid / 2.0 + tyre.y * 0.15) - tyre.y / 2.0), tyre), Color(0.05, 0.05, 0.05))
	var body := PackedVector2Array([Vector2(-len / 2.0, -wid * 0.36), Vector2(len * 0.2, -wid * 0.42),
			Vector2(len / 2.0, -wid * 0.18), Vector2(len / 2.0, wid * 0.18), Vector2(len * 0.2, wid * 0.42),
			Vector2(-len / 2.0, wid * 0.36)])
	var col : Color = car["col"]
	draw_colored_polygon(body, col)
	draw_line(Vector2(-len / 2.0, 0), Vector2(len / 2.0, 0), col.lightened(0.45), wid * 0.12)
	draw_rect(Rect2(Vector2(-len * 0.12, -wid * 0.17), Vector2(len * 0.22, wid * 0.34)), Color(0.1, 0.12, 0.16))
	draw_rect(Rect2(Vector2(-len / 2.0 - 1.0, -wid * 0.5), Vector2(len * 0.1, wid)), col.darkened(0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _cone(p : Vector2, s : float) -> void:
	draw_rect(Rect2(p - Vector2(s, s), Vector2(s, s) * 2.0), Color(0.15, 0.15, 0.15, 0.6))
	draw_circle(p, s * 0.9, Color(1.0, 0.45, 0.05))
	draw_arc(p, s * 0.55, 0.0, TAU, 16, Color(1, 1, 1), s * 0.25)
	draw_circle(p, s * 0.22, Color(1.0, 0.6, 0.2))

func _tyre_stack(p : Vector2, s : float) -> void:
	draw_circle(p + Vector2(2, 2), s, Color(0, 0, 0, 0.25))
	draw_circle(p, s, Color(0.08, 0.08, 0.08))
	draw_arc(p, s * 0.72, 0.0, TAU, 20, Color(0.25, 0.25, 0.25), s * 0.12)
	draw_circle(p, s * 0.42, Color(0.55, 0.55, 0.53))

func _barrier(a : Vector2, b : Vector2, th : float) -> void:
	var n := int(a.distance_to(b) / (th * 1.6))
	for k in range(maxi(1, n)):
		var p0 := a.lerp(b, float(k) / maxi(1, n))
		var p1 := a.lerp(b, float(k + 1) / maxi(1, n))
		draw_line(p0, p1, Color(0.9, 0.12, 0.12) if k % 2 == 0 else Color(0.97, 0.97, 0.97), th)

func _arrow(p : Vector2, s : float, ang : float) -> void:
	draw_set_transform(p, ang, Vector2.ONE)
	draw_rect(Rect2(Vector2(-s, -s * 0.18), Vector2(s * 1.1, s * 0.36)), Color(1, 1, 1, 0.75))
	draw_colored_polygon(PackedVector2Array([Vector2(s * 0.1, -s * 0.5), Vector2(s, 0), Vector2(s * 0.1, s * 0.5)]), Color(1, 1, 1, 0.75))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_props(L : Dictionary) -> void:
	var w := size.x
	var h := size.y
	var outer : Rect2 = L["outer"]
	var tw : float = L["tw"]
	var inner : Rect2 = outer.grow(-tw - 14.0)
	# Oil stains.
	for p in [Vector2(0.2, 0.55), Vector2(0.72, 0.68), Vector2(0.5, 0.42)]:
		var c := Vector2(inner.position.x + inner.size.x * p.x, inner.position.y + inner.size.y * p.y)
		draw_circle(c, 14.0, Color(0.3, 0.3, 0.3, 0.25))
		draw_circle(c + Vector2(8, 4), 8.0, Color(0.25, 0.25, 0.25, 0.25))
	if inner.size.x > 60.0 and inner.size.y > 60.0:
		# Infield: painted arrows, a parking row, a manhole, tyre stacks at the corners.
		_arrow(inner.position + Vector2(inner.size.x * 0.25, inner.size.y * 0.2), 18.0, 0.0)
		_arrow(inner.position + Vector2(inner.size.x * 0.75, inner.size.y * 0.8), 18.0, PI)
		var py := inner.position.y + inner.size.y * 0.5
		for k in range(6):
			var px := inner.position.x + inner.size.x * (0.3 + 0.08 * k)
			draw_line(Vector2(px, py - 22.0), Vector2(px, py + 22.0), Color(1.0, 0.85, 0.2, 0.7), 2.0)
		var mh := inner.position + Vector2(inner.size.x * 0.12, inner.size.y * 0.75)
		draw_circle(mh, 11.0, Color(0.3, 0.3, 0.32))
		for k in range(4):
			draw_line(mh + Vector2(-8, -6 + k * 4), mh + Vector2(8, -6 + k * 4), Color(0.2, 0.2, 0.22), 1.5)
		for c in [inner.position + Vector2(10, 10), Vector2(inner.end.x - 10, inner.position.y + 10),
				Vector2(inner.position.x + 10, inner.end.y - 10), inner.end - Vector2(10, 10)]:
			_tyre_stack(c, 8.0)
	# Outside the track: barriers down the sides, cones, tyre walls.
	_barrier(Vector2(4, outer.position.y + 20.0), Vector2(4, outer.end.y - 20.0), 5.0)
	_barrier(Vector2(w - 4, outer.position.y + 20.0), Vector2(w - 4, outer.end.y - 20.0), 5.0)
	for k in range(5):
		_cone(Vector2(w * (0.3 + 0.1 * k), h - 6.0), 4.5)
	for k in range(3):
		_tyre_stack(Vector2(14.0, outer.position.y + 6.0 + k * 15.0), 7.0)
		_tyre_stack(Vector2(w - 14.0, outer.end.y - 6.0 - k * 15.0), 7.0)

func _draw_buildings(L : Dictionary) -> void:
	# A plain street along the top (where the window's title sits): dark asphalt with a faint
	# dashed centre line, a kerb and a strip of pavement below it.
	var w := size.x
	var strip : float = L["strip"]
	var road_h := strip * 0.78
	draw_rect(Rect2(Vector2.ZERO, Vector2(w, road_h)), Color(0.17, 0.17, 0.19))
	# A little texture in the asphalt.
	for s in _specks:
		var p : Vector2 = s["p"] * size
		if p.y < road_h:
			draw_circle(p, s["r"] * 0.8, Color(0.24, 0.24, 0.26, 0.6))
	# Faint lane lines, low enough not to cross the title much.
	var dash_y := road_h * 0.72
	var x := 10.0
	while x < w:
		draw_line(Vector2(x, dash_y), Vector2(x + 22.0, dash_y), Color(0.95, 0.8, 0.25, 0.35), 3.0)
		x += 44.0
	# Kerb (alternating light and dark) and the pavement.
	var kerb_y := road_h
	draw_rect(Rect2(Vector2(0, kerb_y), Vector2(w, 5.0)), Color(0.82, 0.82, 0.8))
	var k := 0
	x = 0.0
	while x < w:
		if k % 2 == 1:
			draw_rect(Rect2(Vector2(x, kerb_y), Vector2(24.0, 5.0)), Color(0.55, 0.55, 0.55))
		x += 24.0
		k += 1
	draw_rect(Rect2(Vector2(0, kerb_y + 5.0), Vector2(w, strip - road_h - 5.0)), Color(0.7, 0.7, 0.68))
	x = 0.0
	while x < w:
		draw_line(Vector2(x, kerb_y + 5.0), Vector2(x, strip), Color(0.58, 0.58, 0.56), 1.0)
		x += 40.0
