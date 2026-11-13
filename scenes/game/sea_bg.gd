extends Control
# Discard-window backdrop: the deep sea. Light rays from above, glowing currents swirling
# through the water, bubbles, a few fish swimming by, coral and seaweed swaying on a sandy
# bottom. Drawn procedurally every frame; it never takes the mouse.

var _t : float = 0.0
var _fish : Array = []
var _bubbles : Array = []
var _weeds : Array = []
var _corals : Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 7171
	var fish_cols := [Color(1.0, 0.55, 0.15), Color(1.0, 0.85, 0.2), Color(0.3, 0.9, 0.85),
			Color(0.95, 0.4, 0.6), Color(0.55, 0.75, 1.0)]
	for i in range(6):
		_fish.append({"y": rng.randf_range(0.18, 0.72), "sp": rng.randf_range(0.035, 0.07) * (1.0 if i % 2 == 0 else -1.0),
				"x": rng.randf(), "s": rng.randf_range(0.7, 1.25), "c": fish_cols[i % fish_cols.size()],
				"ph": rng.randf() * TAU, "bob": rng.randf_range(0.01, 0.025)})
	for i in range(26):
		_bubbles.append({"x": rng.randf(), "y": rng.randf(), "r": rng.randf_range(1.2, 3.6), "sp": rng.randf_range(0.04, 0.1), "ph": rng.randf() * TAU})
	for i in range(11):
		_weeds.append({"x": rng.randf_range(0.02, 0.98), "h": rng.randf_range(0.14, 0.3), "ph": rng.randf() * TAU,
				"c": Color(0.12, rng.randf_range(0.45, 0.7), 0.25)})
	var coral_cols := [Color(1.0, 0.45, 0.45), Color(1.0, 0.62, 0.3), Color(0.9, 0.4, 0.85)]
	for i in range(4):
		var branches := []
		for b in range(rng.randi_range(3, 5)):
			branches.append({"a": rng.randf_range(-1.0, 1.0), "l": rng.randf_range(0.5, 1.0)})
		_corals.append({"x": rng.randf_range(0.08, 0.92), "s": rng.randf_range(18.0, 30.0),
				"c": coral_cols[i % coral_cols.size()], "b": branches})

func _process(delta : float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 4.0 or h < 4.0:
		return
	# Water: lighter near the surface, near-black in the depths.
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([Color(0.03, 0.27, 0.45), Color(0.03, 0.27, 0.45), Color(0.0, 0.05, 0.13), Color(0.0, 0.05, 0.13)]))
	# Light rays from the surface, slowly swaying.
	for i in range(5):
		var x0 : float = w * (0.1 + 0.2 * i) + sin(_t * 0.4 + i) * 18.0
		var spread : float = 30.0 + 12.0 * i
		var a : float = 0.07 + 0.03 * sin(_t * 0.7 + i * 1.7)
		draw_polygon(PackedVector2Array([Vector2(x0 - 10, 0), Vector2(x0 + 14, 0), Vector2(x0 + spread + 60, h * 0.85), Vector2(x0 + spread - 30, h * 0.85)]),
				PackedColorArray([Color(0.7, 0.95, 1.0, a), Color(0.7, 0.95, 1.0, a), Color(0.7, 0.95, 1.0, 0.0), Color(0.7, 0.95, 1.0, 0.0)]))
	# Glowing currents: wide faint ribbons with a bright core, drifting along.
	for k in range(4):
		var pts := PackedVector2Array()
		var base_y : float = h * (0.2 + 0.18 * k)
		for i in range(41):
			var f : float = i / 40.0
			var x : float = f * w
			var y : float = base_y + sin(f * 7.0 + _t * (0.6 + 0.15 * k) + k * 2.0) * 16.0 + sin(f * 13.0 - _t * 0.9) * 6.0
			pts.append(Vector2(x, y))
		var glow := 0.5 + 0.5 * sin(_t * 1.1 + k)
		draw_polyline(pts, Color(0.2, 0.95, 1.0, 0.06 + 0.04 * glow), 14.0, true)
		draw_polyline(pts, Color(0.5, 1.0, 1.0, 0.16 + 0.12 * glow), 3.0, true)
		# A swirl along each current.
		var cx : float = fmod(_t * 18.0 * (k + 1) + k * 140.0, w + 80.0) - 40.0
		var sw := PackedVector2Array()
		for i in range(30):
			var ang : float = i * 0.35 + _t * 1.5
			var r : float = 3.0 + i * 0.7
			sw.append(Vector2(cx, base_y) + Vector2(cos(ang), sin(ang)) * r)
		draw_polyline(sw, Color(0.6, 1.0, 1.0, 0.22), 2.0, true)
	# Sandy bottom.
	var sand_y := h * 0.9
	var sand := PackedVector2Array([Vector2(0, h)])
	for i in range(13):
		var f : float = i / 12.0
		sand.append(Vector2(f * w, sand_y + sin(f * 9.0) * 5.0))
	sand.append(Vector2(w, h))
	draw_colored_polygon(sand, Color(0.32, 0.27, 0.18))
	# Coral.
	for c in _corals:
		var base := Vector2(float(c["x"]) * w, sand_y + 2.0)
		var col : Color = c["c"]
		for b in c["b"]:
			var a : float = float(b["a"]) + sin(_t * 0.8 + float(c["x"]) * 10.0) * 0.05
			var tip : Vector2 = base + Vector2(sin(a), -cos(a)) * float(c["s"]) * float(b["l"]) * 1.6
			draw_line(base, tip, col.darkened(0.15), 5.0, true)
			draw_circle(tip, 4.0, col)
			var mid : Vector2 = base.lerp(tip, 0.6)
			draw_line(mid, mid + Vector2(sin(a + 0.6), -cos(a + 0.6)) * float(c["s"]) * 0.45, col.darkened(0.1), 3.0, true)
	# Seaweed waving in the current.
	for wd in _weeds:
		var bx : float = float(wd["x"]) * w
		var pts := PackedVector2Array()
		var segs := 12
		for i in range(segs + 1):
			var f : float = float(i) / segs
			var sway : float = sin(_t * 1.3 + float(wd["ph"]) + f * 3.0) * 10.0 * f
			pts.append(Vector2(bx + sway, sand_y + 4.0 - f * float(wd["h"]) * h))
		draw_polyline(pts, wd["c"], 5.0, true)
		draw_polyline(pts, (wd["c"] as Color).lightened(0.3), 1.5, true)
	# Fish.
	for f in _fish:
		var x : float = fposmod(float(f["x"]) + _t * float(f["sp"]), 1.2) - 0.1
		var dir : float = 1.0 if float(f["sp"]) > 0.0 else -1.0
		var p := Vector2(x * w, (float(f["y"]) + sin(_t * 1.7 + float(f["ph"])) * float(f["bob"])) * h)
		var s : float = 9.0 * float(f["s"])
		var col : Color = f["c"]
		var wag : float = sin(_t * 9.0 + float(f["ph"])) * 0.35
		var tail := p - Vector2(dir * s * 1.3, 0)
		draw_colored_polygon(PackedVector2Array([tail, tail - Vector2(dir * s * 0.9, s * (0.7 + wag)), tail - Vector2(dir * s * 0.9, -s * (0.7 - wag))]), col.darkened(0.2))
		var body := PackedVector2Array()
		for i in range(16):
			var ang : float = i * TAU / 16.0
			body.append(p + Vector2(cos(ang) * s * 1.5, sin(ang) * s * 0.75))
		draw_colored_polygon(body, col)
		draw_circle(p + Vector2(dir * s * 0.8, -s * 0.15), s * 0.18, Color(0.05, 0.05, 0.1))
	# Bubbles rising.
	for b in _bubbles:
		var y : float = fposmod(float(b["y"]) - _t * float(b["sp"]), 1.0)
		var x : float = float(b["x"]) + sin(_t * 2.0 + float(b["ph"])) * 0.01
		draw_arc(Vector2(x * w, y * h), float(b["r"]), 0.0, TAU, 12, Color(0.8, 1.0, 1.0, 0.45), 1.0, true)
	# Border.
	draw_rect(Rect2(1, 1, w - 2, h - 2), Color(0.4, 0.9, 1.0, 0.55), false, 2.0)
