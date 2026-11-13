extends Control
# Gauge-reference backdrop (meditative theme): a dark, softly shaded night-violet field with a
# Flower of Life centered in it. The symbol glows gently, its glow slowly cycling through the
# colors of the rainbow and breathing in brightness. Small mandalas fade in and out like stars at
# random spots, each glowing its own color, with 2 to 4 of them showing at any time. Drawn
# procedurally every frame; it never takes the mouse.

const MIN_STARS := 2
const MAX_STARS := 4
const FLOWER_SIZE := 0.39 # the flower's outer ring radius, as a fraction of the window's shorter side
const HUE_CYCLE := 12.0 # seconds for the glow to go once round the rainbow

var _t : float = 0.0
var _rng := RandomNumberGenerator.new()
var _stars : Array = []  # {p (0..1), r, hue, born, life, spin, petals}
var _next_star : float = 0.0
var _dust : Array = []   # faint static specks for depth
var _seeded : bool = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_rng.randomize()
	for i in range(90):
		_dust.append({"p": Vector2(_rng.randf(), _rng.randf()), "a": _rng.randf_range(0.04, 0.14),
				"r": _rng.randf_range(0.6, 1.4)})
	_seeded = false # (the first stars are added once the size is known)

# The Flower of Life's outer edge (its outer ring, glow included), in pixels from the center.
func _flower_radius() -> float:
	# (outer ring at 3r, its double line 4 px further out, and the widest glow pass half of 9 px)
	return minf(size.x, size.y) * FLOWER_SIZE + 4.0 + 4.5

func _add_star(age : float = 0.0) -> void:
	# Somewhere fully clear of the big flower (glow and all) and of the other mandalas, and not
	# off the edges. Measured in pixels, so it holds for any window shape.
	var m := minf(size.x, size.y)
	if m <= 0.0:
		return
	var rad := _rng.randf_range(0.022, 0.085) # (as a fraction of the shorter side)
	var reach := rad * m * 1.6 # the mandala's own glow
	var c := size / 2.0
	var found := false
	var p := Vector2.ZERO
	for attempt in range(30):
		p = Vector2(_rng.randf_range(0.06, 0.94), _rng.randf_range(0.1, 0.94))
		var px := Vector2(p.x * size.x, p.y * size.y)
		if px.distance_to(c) < _flower_radius() + reach + 6.0:
			continue
		if px.x < reach or px.x > size.x - reach or px.y < reach or px.y > size.y - reach:
			continue
		var clear := true
		for s in _stars:
			var sp := Vector2(s["p"].x * size.x, s["p"].y * size.y)
			if px.distance_to(sp) < reach + s["r"] * m * 1.6 + 8.0:
				clear = false
				break
		if clear:
			found = true
			break
	if not found:
		return # (no room right now: try again shortly)
	var life := _rng.randf_range(8.0, 14.0) # (fade in, show, fade out: twice the old pace)
	_stars.append({"p": p, "r": rad, "hue": _rng.randf(),
			"born": _t - minf(age, life * 0.8), "life": life, "spin": _rng.randf_range(-0.25, 0.25),
			"petals": [6, 8, 8, 10, 12][_rng.randi() % 5]})

func _process(delta : float) -> void:
	_t += delta
	if not _seeded and minf(size.x, size.y) > 0.0:
		_seeded = true
		for i in range(MIN_STARS):
			_add_star(_rng.randf_range(0.0, 6.0)) # some already part-way through their life
	_stars = _stars.filter(func(s): return _t - s["born"] < s["life"])
	_next_star -= delta
	if _stars.size() < MIN_STARS or (_stars.size() < MAX_STARS and _next_star <= 0.0):
		_add_star()
		_next_star = _rng.randf_range(2.0, 5.0) if _stars.size() >= MIN_STARS else 0.2
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	# A deep indigo field, lighter toward the middle (drawn as soft concentric bands).
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.02, 0.06))
	var c := size / 2.0
	var far := c.length()
	for i in range(14, 0, -1):
		var f := float(i) / 14.0
		draw_circle(c, far * f, Color(0.09, 0.06, 0.17, 0.10 * (1.0 - f) + 0.02))
	for d in _dust:
		draw_circle(Vector2(d["p"].x * w, d["p"].y * h), d["r"], Color(0.8, 0.8, 1.0, d["a"]))

	# Small mandalas twinkling in and out.
	for s in _stars:
		var age : float = (_t - s["born"]) / s["life"]
		var a := sin(clampf(age, 0.0, 1.0) * PI) # fade in, then out
		a = a * a * (3.0 - 2.0 * a)
		var col := Color.from_hsv(s["hue"], 0.6, 1.0)
		_mandala(Vector2(s["p"].x * w, s["p"].y * h), s["r"] * minf(w, h), col, a, _t * s["spin"], s["petals"])

	# The Flower of Life: 19 circles (one, then rings of 6 and 12) inside a bounding circle.
	var r := minf(w, h) * FLOWER_SIZE / 3.0
	var hue := fmod(_t / HUE_CYCLE, 1.0)
	var breathe := 0.5 + 0.5 * sin(_t * 0.9)
	var glow := Color.from_hsv(hue, 0.7, 1.0)
	var centers := _flower_centers(c, r)
	# Soft halo behind it.
	for i in range(8, 0, -1):
		draw_circle(c, r * 3.0 + i * r * 0.12, Color(glow, 0.012 + 0.008 * breathe))
	# Glow passes (wide and faint), then the bright line.
	for pass_i in range(3):
		var wdt : float = [9.0, 5.0, 2.6][pass_i]
		var al : float = [0.07, 0.14, 0.32][pass_i] * (0.7 + 0.3 * breathe)
		for p in centers:
			draw_arc(p, r, 0.0, TAU, 64, Color(glow, al), wdt, true)
		draw_arc(c, r * 3.0, 0.0, TAU, 128, Color(glow, al), wdt, true)
	var line := glow.lerp(Color.WHITE, 0.55)
	for p in centers:
		draw_arc(p, r, 0.0, TAU, 64, Color(line, 0.85), 1.2, true)
	draw_arc(c, r * 3.0, 0.0, TAU, 128, Color(line, 0.9), 1.4, true)
	draw_arc(c, r * 3.0 + 4.0, 0.0, TAU, 128, Color(line, 0.45), 1.0, true)

# The 19 circle centers of the Flower of Life (hexagonal grid, spacing r, within 2r of center).
func _flower_centers(c : Vector2, r : float) -> Array:
	var out := []
	for q in range(-2, 3):
		for s in range(-2, 3):
			var t := -q - s
			if absi(t) > 2:
				continue
			var p := c + Vector2(r * (q + s * 0.5), r * s * sqrt(3.0) / 2.0)
			out.append(p)
	return out

# A small glowing mandala: rings, a ring of petal circles and a dotted rim, slowly turning.
func _mandala(p : Vector2, rad : float, col : Color, a : float, rot : float, petals : int) -> void:
	if a <= 0.01:
		return
	draw_circle(p, rad * 1.6, Color(col, 0.05 * a))
	draw_circle(p, rad * 0.9, Color(col, 0.05 * a))
	for pass_i in range(2):
		var wdt : float = [4.0, 1.2][pass_i]
		var al : float = [0.18, 0.8][pass_i] * a
		var cc := col if pass_i == 0 else col.lerp(Color.WHITE, 0.4)
		draw_arc(p, rad, 0.0, TAU, 48, Color(cc, al), wdt, true)
		draw_arc(p, rad * 0.35, 0.0, TAU, 32, Color(cc, al), wdt, true)
		for i in range(petals):
			var ang := rot + TAU * i / petals
			draw_arc(p + Vector2.RIGHT.rotated(ang) * rad * 0.5, rad * 0.32, 0.0, TAU, 24, Color(cc, al * 0.8), wdt * 0.8, true)
	for i in range(petals * 2):
		var ang := -rot + TAU * (i + 0.5) / (petals * 2)
		draw_circle(p + Vector2.RIGHT.rotated(ang) * rad * 1.18, maxf(1.0, rad * 0.05), Color(col.lerp(Color.WHITE, 0.5), 0.8 * a))
