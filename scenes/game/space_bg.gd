extends Control
# Deck-reference backdrop: outer space. Dark navy / black swirls, twinkling white and coloured
# stars, a small ringed planet and a tiny spiral galaxy. Never takes the mouse.

var _t : float = 0.0
var _tex : ImageTexture
var _stars : Array = []
var _galaxy : Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	# Swirling nebula: warped fractal noise mapped from black through navy to a hint of violet.
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.011
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.domain_warp_enabled = true
	noise.domain_warp_type = FastNoiseLite.DOMAIN_WARP_SIMPLEX
	noise.domain_warp_amplitude = 55.0
	noise.domain_warp_frequency = 0.012
	noise.seed = 11
	var iw := 192
	var ih := 192
	var img := Image.create(iw, ih, false, Image.FORMAT_RGB8)
	for y in range(ih):
		for x in range(iw):
			var v : float = noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			v = clampf((v - 0.3) / 0.5, 0.0, 1.0)
			var c := Color(0.0, 0.0, 0.015).lerp(Color(0.04, 0.07, 0.26), v)
			c = c.lerp(Color(0.16, 0.08, 0.3), clampf((v - 0.75) * 2.2, 0.0, 0.5))
			img.set_pixel(x, y, c)
	_tex = ImageTexture.create_from_image(img)
	var palette := [Color(1, 1, 1), Color(1, 1, 1), Color(1, 1, 1), Color(0.7, 0.85, 1.0),
			Color(1.0, 0.92, 0.65), Color(1.0, 0.65, 0.8), Color(0.6, 1.0, 0.95), Color(0.85, 0.7, 1.0)]
	for i in range(170):
		_stars.append({"p": Vector2(rng.randf(), rng.randf()), "r": rng.randf_range(0.6, 1.6) * (1.7 if rng.randf() < 0.08 else 1.0),
				"c": palette[rng.randi() % palette.size()], "ph": rng.randf() * TAU, "sp": rng.randf_range(0.6, 2.4)})
	# A small spiral galaxy: two arms of dots.
	for arm in range(2):
		for i in range(46):
			var f : float = i / 45.0
			var ang : float = arm * PI + f * 4.2
			var rad : float = 3.0 + f * 30.0
			_galaxy.append({"o": Vector2(cos(ang) * rad, sin(ang) * rad * 0.42), "f": f, "j": rng.randf_range(-2.0, 2.0)})

func _process(delta : float) -> void:
	_t += delta
	queue_redraw()

func _ellipse(center : Vector2, rx : float, ry : float, rot : float, a0 : float, a1 : float, steps : int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		var a : float = lerpf(a0, a1, float(i) / steps)
		var p := Vector2(cos(a) * rx, sin(a) * ry).rotated(rot)
		pts.append(center + p)
	return pts

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 4.0 or h < 4.0:
		return
	draw_texture_rect(_tex, Rect2(0, 0, w, h), false)
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.18))
	# Galaxy (lower left).
	var gc := Vector2(w * 0.12, h * 0.86)
	draw_circle(gc, 9.0, Color(1.0, 0.95, 0.8, 0.5))
	draw_circle(gc, 5.0, Color(1.0, 0.97, 0.9, 0.9))
	for d in _galaxy:
		var o : Vector2 = d["o"]
		o = o.rotated(-0.5)
		var col := Color(0.7, 0.8, 1.0).lerp(Color(1.0, 0.7, 0.9), float(d["f"]))
		draw_circle(gc + o + Vector2(0, float(d["j"])), 1.3, Color(col.r, col.g, col.b, 0.85 - 0.5 * float(d["f"])))
	# Stars.
	for s in _stars:
		var p : Vector2 = Vector2(s["p"].x * w, s["p"].y * h)
		var tw : float = 0.65 + 0.35 * sin(_t * float(s["sp"]) + float(s["ph"]))
		var c : Color = s["c"]
		var r : float = s["r"]
		draw_circle(p, r, Color(c.r, c.g, c.b, tw))
		if r > 1.9:
			draw_line(p - Vector2(r * 3.0, 0), p + Vector2(r * 3.0, 0), Color(c.r, c.g, c.b, tw * 0.5), 1.0)
			draw_line(p - Vector2(0, r * 3.0), p + Vector2(0, r * 3.0), Color(c.r, c.g, c.b, tw * 0.5), 1.0)
	# Ringed planet (upper right): back of the ring, the planet, then the front of the ring.
	var pc := Vector2(w * 0.84, h * 0.82)
	var pr := 20.0
	var tilt := -0.38
	draw_polyline(_ellipse(pc, pr * 2.1, pr * 0.62, tilt, PI, TAU, 40), Color(0.85, 0.75, 0.55, 0.55), 3.0)
	var base_c := Color(0.09, 0.13, 0.36)
	draw_circle(pc, pr, base_c)
	for i in range(1, 6):
		var f : float = i / 5.0
		draw_circle(pc + Vector2(-5, -5) * f * 0.8, pr * (1.0 - 0.15 * i), base_c.lerp(Color(0.5, 0.75, 1.0), f))
	draw_polyline(_ellipse(pc, pr * 2.1, pr * 0.62, tilt, 0.0, PI, 40), Color(0.95, 0.85, 0.6, 0.85), 3.0)
	# Border.
	draw_rect(Rect2(1, 1, w - 2, h - 2), Color(0.55, 0.65, 1.0, 0.55), false, 2.0)
