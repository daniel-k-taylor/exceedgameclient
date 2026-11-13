extends Control
# Sealed-cards backdrop: a graveyard at night. A pale moon behind thin clouds, a crooked dead
# tree, rows of leaning tombstones on a hill, a lantern that flickers softly, ghostly wisps
# floating upward, and smoke swirling slowly across the ground. Drawn procedurally every
# frame; it never takes the mouse.

var _t : float = 0.0
var _smoke : Array = []
var _wisps : Array = []
var _stones : Array = []
var _stars : Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 1031
	for i in range(40):
		_stars.append({"x": rng.randf(), "y": rng.randf_range(0.0, 0.45), "r": rng.randf_range(0.6, 1.4), "ph": rng.randf() * TAU})
	# Tombstones: x position, base height (0..1 of the hill line), size, shape, lean.
	for i in range(9):
		_stones.append({"x": (i + 0.5) / 9.0 + rng.randf_range(-0.03, 0.03), "row": i % 2,
				"w": rng.randf_range(18.0, 28.0), "h": rng.randf_range(26.0, 40.0),
				"shape": rng.randi_range(0, 2), "lean": rng.randf_range(-0.12, 0.12)})
	# Smoke puffs: each orbits slowly around a drifting center, so the haze swirls.
	for i in range(18):
		_smoke.append({"cx": rng.randf(), "cy": rng.randf_range(0.62, 0.98), "orb": rng.randf_range(10.0, 34.0),
				"sp": rng.randf_range(0.15, 0.35) * (1.0 if rng.randf() < 0.5 else -1.0),
				"drift": rng.randf_range(0.004, 0.012), "r": rng.randf_range(26.0, 60.0), "ph": rng.randf() * TAU})
	for i in range(7):
		_wisps.append({"x": rng.randf(), "sp": rng.randf_range(0.02, 0.045), "ph": rng.randf() * TAU,
				"off": rng.randf(), "r": rng.randf_range(2.0, 3.5)})

func _process(delta : float) -> void:
	_t += delta
	queue_redraw()

func _hill_y(x : float, w : float, h : float) -> float:
	return h * 0.66 - sin(x / w * PI) * h * 0.08

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 4.0 or h < 4.0:
		return
	# Night sky: deep blue-violet down to a murky green near the ground.
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([Color(0.05, 0.05, 0.13), Color(0.07, 0.05, 0.14), Color(0.07, 0.11, 0.1), Color(0.06, 0.1, 0.09)]))
	for s in _stars:
		var a : float = 0.35 + 0.3 * sin(_t * 1.3 + s["ph"])
		draw_circle(Vector2(s["x"] * w, s["y"] * h), s["r"], Color(0.85, 0.9, 1.0, a))
	# Moon with a soft halo, and a thin cloud sliding across it.
	var moon := Vector2(w * 0.8, h * 0.17)
	for i in range(6, 0, -1):
		draw_circle(moon, 22.0 + i * 8.0, Color(0.8, 0.85, 0.7, 0.035))
	draw_circle(moon, 24.0, Color(0.92, 0.93, 0.8))
	draw_circle(moon + Vector2(-7, -5), 5.0, Color(0.82, 0.83, 0.7))
	draw_circle(moon + Vector2(8, 6), 3.5, Color(0.84, 0.85, 0.72))
	var cloud_x := fmod(_t * 6.0, w + 240.0) - 120.0
	for k in range(5):
		draw_circle(Vector2(cloud_x + k * 22.0, moon.y + 10.0 + sin(k * 1.7) * 4.0), 16.0, Color(0.4, 0.42, 0.5, 0.18))
	# Hill.
	var hill := PackedVector2Array()
	var steps := 24
	for i in range(steps + 1):
		var x := w * i / steps
		hill.append(Vector2(x, _hill_y(x, w, h)))
	hill.append(Vector2(w, h))
	hill.append(Vector2(0, h))
	draw_colored_polygon(hill, Color(0.05, 0.08, 0.07))
	# Dead tree on the left, gently swaying.
	var sway := sin(_t * 0.7) * 0.03
	var base := Vector2(w * 0.12, _hill_y(w * 0.12, w, h) + 4.0)
	_branch(base, -PI / 2.0 + sway, h * 0.17, 8.0, 5, sway)
	# Tombstones.
	for st in _stones:
		var x : float = st["x"] * w
		var gy := _hill_y(x, w, h) + (14.0 if st["row"] == 1 else 2.0)
		var sw : float = st["w"]
		var sh : float = st["h"]
		var col := Color(0.32, 0.34, 0.36) if st["row"] == 1 else Color(0.24, 0.26, 0.28)
		draw_set_transform(Vector2(x, gy), st["lean"], Vector2.ONE)
		match int(st["shape"]):
			0: # rounded top
				draw_rect(Rect2(-sw / 2.0, -sh + sw / 2.0, sw, sh - sw / 2.0), col)
				draw_circle(Vector2(0, -sh + sw / 2.0), sw / 2.0, col)
			1: # cross
				draw_rect(Rect2(-sw * 0.15, -sh, sw * 0.3, sh), col)
				draw_rect(Rect2(-sw * 0.45, -sh * 0.78, sw * 0.9, sw * 0.28), col)
			_: # slab
				draw_rect(Rect2(-sw / 2.0, -sh, sw, sh), col)
		# "RIP" scratch marks.
		draw_line(Vector2(-sw * 0.22, -sh * 0.55), Vector2(sw * 0.22, -sh * 0.55), Color(0, 0, 0, 0.35), 1.5)
		draw_line(Vector2(-sw * 0.16, -sh * 0.42), Vector2(sw * 0.16, -sh * 0.42), Color(0, 0, 0, 0.3), 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# A lantern on a post with a soft flicker.
	var lp := Vector2(w * 0.9, _hill_y(w * 0.9, w, h) + 10.0)
	draw_line(lp, lp - Vector2(0, 46), Color(0.1, 0.1, 0.1), 3.0)
	var flick := 0.75 + 0.15 * sin(_t * 9.0) + 0.1 * sin(_t * 23.0 + 1.3)
	var lc := lp - Vector2(0, 52)
	for i in range(5, 0, -1):
		draw_circle(lc, 6.0 + i * 7.0, Color(1.0, 0.75, 0.35, 0.05 * flick))
	draw_rect(Rect2(lc - Vector2(5, 7), Vector2(10, 14)), Color(1.0, 0.82, 0.45, flick))
	draw_rect(Rect2(lc - Vector2(6, 8), Vector2(12, 16)), Color(0.08, 0.08, 0.08), false, 1.5)
	# Ghostly wisps drifting upward, swaying side to side.
	for wsp in _wisps:
		var life : float = fmod(_t * wsp["sp"] + wsp["off"], 1.0)
		var y : float = h * (0.9 - life * 0.75)
		var x : float = wsp["x"] * w + sin(_t * 1.2 + wsp["ph"]) * 12.0
		var a : float = sin(life * PI) * 0.7
		draw_circle(Vector2(x, y), wsp["r"] * 4.0, Color(0.6, 1.0, 0.85, a * 0.12))
		draw_circle(Vector2(x, y), wsp["r"], Color(0.75, 1.0, 0.9, a))
	# Swirling ground smoke: translucent puffs circling slowly as they drift.
	for sm in _smoke:
		var cx : float = fmod(sm["cx"] + _t * sm["drift"], 1.2) - 0.1
		var ang : float = _t * sm["sp"] + sm["ph"]
		var p : Vector2 = Vector2(cx * w, sm["cy"] * h) + Vector2(cos(ang), sin(ang) * 0.45) * sm["orb"]
		var r : float = sm["r"] * (0.9 + 0.1 * sin(_t * 0.8 + sm["ph"]))
		_soft_puff(p, r, Color(0.62, 0.68, 0.72), 0.022)
		_soft_puff(p + Vector2(r * 0.35, -r * 0.12), r * 0.6, Color(0.72, 0.77, 0.82), 0.02)
	# Curling smoke ribbons that slowly twist over the graves.
	for rb in range(3):
		var base_y := h * (0.7 + rb * 0.08)
		var pts := PackedVector2Array()
		for i in range(41):
			var u := float(i) / 40.0
			var x := u * w
			var y := base_y + sin(u * TAU * 1.3 + _t * (0.35 + rb * 0.1) + rb * 2.0) * (10.0 + rb * 4.0) \
					+ sin(u * TAU * 3.1 - _t * 0.5 + rb) * 4.0
			pts.append(Vector2(x, y))
		for k in range(4):
			draw_polyline(pts, Color(0.75, 0.8, 0.85, 0.03), 14.0 - k * 3.0, true)

# A puff of smoke with soft edges: stacked circles, each a little smaller and fainter.
func _soft_puff(c : Vector2, r : float, col : Color, a : float) -> void:
	for k in range(5):
		draw_circle(c, r * (1.0 - k * 0.17), Color(col.r, col.g, col.b, a))

func _branch(from : Vector2, ang : float, length : float, width : float, depth : int, sway : float) -> void:
	var to := from + Vector2(cos(ang), sin(ang)) * length
	draw_line(from, to, Color(0.03, 0.04, 0.04), width, true)
	if depth <= 0:
		return
	_branch(to, ang - 0.5 + sway, length * 0.68, width * 0.65, depth - 1, sway)
	_branch(to, ang + 0.42 + sway, length * 0.6, width * 0.6, depth - 1, sway)
