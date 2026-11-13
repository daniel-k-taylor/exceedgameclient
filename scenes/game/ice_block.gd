extends Control
# Backdrop for the bonus-effect popup (phone layout): a deep, dark block of glacier ice, cracked,
# with a bevelled, frosty edge, so white text reads clearly on it. It sits behind the text and ignores the mouse.

var _cracks : Array = []
var _frost : Array = []
var _glints : Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	# Cracks: jagged lines wandering in from the edges, with a branch or two.
	for i in range(4):
		var pts := []
		var p := Vector2(rng.randf_range(0.1, 0.9), 0.0 if i % 2 == 0 else 1.0)
		var dir := 1.0 if i % 2 == 0 else -1.0
		pts.append(p)
		for s in range(rng.randi_range(3, 5)):
			p += Vector2(rng.randf_range(-0.18, 0.18), dir * rng.randf_range(0.1, 0.22))
			p.x = clampf(p.x, 0.02, 0.98)
			p.y = clampf(p.y, 0.0, 1.0)
			pts.append(p)
		_cracks.append(pts)
		# A short branch off the middle of the crack.
		var mid : Vector2 = pts[pts.size() / 2]
		_cracks.append([mid, mid + Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.12, 0.12)),
				mid + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.2, 0.2))])
	for i in range(7):
		_frost.append({"c": Vector2(rng.randf(), rng.randf()), "r": rng.randf_range(0.10, 0.24), "a": rng.randf_range(0.06, 0.16)})
	for i in range(3):
		_glints.append({"c": Vector2(rng.randf_range(0.1, 0.9), rng.randf_range(0.1, 0.9)), "s": rng.randf_range(4.0, 7.0)})
	resized.connect(queue_redraw)

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 8.0 or h <= 8.0:
		return
	var c := minf(10.0, minf(w, h) * 0.18) # chamfered corners
	var outline := PackedVector2Array([
		Vector2(c, 0), Vector2(w - c, 0), Vector2(w, c), Vector2(w, h - c),
		Vector2(w - c, h), Vector2(c, h), Vector2(0, h - c), Vector2(0, c)])
	var top := Color(0.11, 0.31, 0.5, 0.97)
	var bot := Color(0.03, 0.11, 0.24, 0.97)
	var cols := PackedColorArray()
	for p in outline:
		cols.append(top.lerp(bot, p.y / h))
	draw_polygon(outline, cols)
	# Cloudy frost patches (clipped to the block by keeping them inside the rect).
	for f in _frost:
		var fc : Vector2 = Vector2(f["c"].x * w, f["c"].y * h)
		var r : float = f["r"] * w
		var rr := minf(r, minf(fc.x, w - fc.x))
		rr = minf(rr, minf(fc.y, h - fc.y))
		if rr > 3.0:
			draw_circle(fc, rr, Color(0.7, 0.9, 1.0, f["a"] * 0.6))
	# Cracks: a soft blue shadow under a thin white line.
	for pts in _cracks:
		var line := PackedVector2Array()
		for q in pts:
			line.append(Vector2(q.x * w, q.y * h))
		draw_polyline(line, Color(0.0, 0.04, 0.12, 0.6), 2.6)
		draw_polyline(line, Color(0.62, 0.86, 1.0, 0.55), 1.1)
	# Bevel: bright on the top / left, deeper blue on the bottom / right.
	draw_polyline(PackedVector2Array([Vector2(0, h - c), Vector2(0, c), Vector2(c, 0), Vector2(w - c, 0)]),
			Color(0.7, 0.92, 1.0, 0.9), 3.0)
	draw_polyline(PackedVector2Array([Vector2(w - c, 0), Vector2(w, c), Vector2(w, h - c), Vector2(w - c, h), Vector2(c, h)]),
			Color(0.01, 0.05, 0.14, 0.95), 3.0)
