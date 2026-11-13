extends Control
# Decoration for a boost window (phone layout): a procedural wood texture that gains
# glowing embers with one boost, sparks and small flames with two, and is fully ablaze
# with three or more. It is drawn *behind* the window's text, under a dark scrim, so the
# text stays readable. It ignores the mouse.

const TEX_W := 192
const TEX_H := 64
const TEX_SCALE := 2.0

static var _wood : ImageTexture

var target_level : float = 0.0
var level : float = 0.0
var _t : float = 0.0
var _spark_acc : float = 0.0
var _sparks : Array = []
var _embers : Array = []
var _cracks : Array = []
var _dirty : bool = true
var _last_size : Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _wood == null:
		_wood = _make_wood()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + get_instance_id() % 1000
	for i in range(28):
		_embers.append({"x": rng.randf_range(0.04, 0.96), "y": rng.randf_range(0.06, 0.94),
				"r": rng.randf_range(2.0, 4.5), "ph": rng.randf() * TAU, "sp": rng.randf_range(1.5, 4.0)})
	for i in range(5):
		var pts := []
		var y0 := rng.randf_range(0.12, 0.88)
		var x := rng.randf_range(0.0, 0.25)
		while x < 1.0:
			pts.append(Vector2(x, clampf(y0 + rng.randf_range(-0.06, 0.06), 0.03, 0.97)))
			x += rng.randf_range(0.08, 0.2)
		_cracks.append({"pts": pts, "ph": rng.randf() * TAU})
	resized.connect(func(): _dirty = true)

static func _make_wood() -> ImageTexture:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 1.0
	var img := Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGB8)
	var dark := Color(0.20, 0.10, 0.05)
	var light := Color(0.47, 0.28, 0.14)
	for y in range(TEX_H):
		for x in range(TEX_W):
			var warp := n.get_noise_2d(x * 0.012, y * 0.05) * 14.0
			var g := n.get_noise_2d(x * 0.010 + 50.0, (y + warp) * 0.30)
			var fine := n.get_noise_2d(x * 0.25, y * 0.8)
			var v := clampf(0.5 + g * 0.5 + fine * 0.12, 0.0, 1.0)
			var col := dark.lerp(light, v)
			var py := y % 32 # a plank seam every 32 texels
			if py < 1:
				col = col * 0.35
			elif py < 3:
				col = col * 0.8
			col.a = 1.0
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)

func set_level(n : int) -> void:
	target_level = float(clampi(n, 0, 3))

func _process(delta : float) -> void:
	if not is_visible_in_tree():
		return
	if size != _last_size:
		_last_size = size
		_dirty = true
	var active := target_level > 0.0 or level > 0.01 or _sparks.size() > 0
	if not active:
		if _dirty:
			_dirty = false
			queue_redraw()
		return
	_t += delta
	level = move_toward(level, target_level, delta * 2.5)
	var f := clampf(level - 1.0, 0.0, 1.0)
	var b := clampf(level - 2.0, 0.0, 1.0)
	# Spawn sparks.
	_spark_acc += delta * (f * 26.0 + b * 100.0)
	while _spark_acc >= 1.0:
		_spark_acc -= 1.0
		if size.x > 4.0 and _sparks.size() < 260:
			var life := randf_range(0.6, 1.4)
			_sparks.append({"p": Vector2(randf_range(0.0, size.x), randf_range(size.y * 0.1, size.y * 0.6)),
					"v": Vector2(randf_range(-18.0, 18.0), -randf_range(40.0, 120.0)), "life": life, "max": life})
	var i := _sparks.size() - 1
	while i >= 0:
		var s : Dictionary = _sparks[i]
		s["life"] -= delta
		var v : Vector2 = s["v"]
		v.x += sin(_t * 8.0 + i) * 20.0 * delta
		s["v"] = v
		s["p"] = (s["p"] as Vector2) + v * delta
		if s["life"] <= 0.0:
			_sparks.remove_at(i)
		i -= 1
	queue_redraw()

func _flame(base : Vector2, w : float, h : float, ph : float, alpha : float) -> void:
	var flick := h * (0.75 + 0.25 * sin(_t * 9.0 + ph) + 0.10 * sin(_t * 23.0 + ph * 2.0))
	var sway := sin(_t * 5.0 + ph) * w * 0.25
	var hot := Color(1.0, 0.35, 0.05, 0.9 * alpha)
	var tipc := Color(1.0, 0.15, 0.0, 0.0)
	var bl := base + Vector2(-w * 0.5, 0)
	var br := base + Vector2(w * 0.5, 0)
	var tip := base + Vector2(sway, -flick)
	draw_polygon(PackedVector2Array([bl, bl + Vector2(-w * 0.08, -flick * 0.45), tip, br + Vector2(w * 0.08, -flick * 0.45), br]),
			PackedColorArray([hot, hot, tipc, hot, hot]))
	# Brighter inner core.
	var core := Color(1.0, 0.85, 0.25, 0.85 * alpha)
	var cb := base + Vector2(-w * 0.22, 0)
	var cr := base + Vector2(w * 0.22, 0)
	var ctip := base + Vector2(sway * 0.6, -flick * 0.6)
	draw_polygon(PackedVector2Array([cb, ctip, cr]), PackedColorArray([core, Color(1.0, 0.6, 0.1, 0.0), core]))

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 4.0 or h <= 4.0:
		return
	var e := clampf(level, 0.0, 1.0)
	var f := clampf(level - 1.0, 0.0, 1.0)
	var b := clampf(level - 2.0, 0.0, 1.0)
	# Outer glow.
	var glow := e * 0.45 + f * 0.25 + b * 0.5
	if glow > 0.01:
		var pulse := 0.85 + 0.15 * sin(_t * 6.0)
		for k in range(1, 5):
			var d := k * 4.0
			draw_rect(Rect2(-d, -d, w + 2.0 * d, h + 2.0 * d), Color(1.0, 0.4, 0.08, glow * pulse * 0.16 / k), true)
	# Wood, tiled in plank-pairs down the window.
	var ty := 0.0
	var tile_h := TEX_H * TEX_SCALE
	while ty < h:
		var rh := minf(tile_h, h - ty)
		draw_texture_rect_region(_wood, Rect2(0, ty, w, rh), Rect2(0, 0, minf(float(TEX_W), w / TEX_SCALE), rh / TEX_SCALE))
		ty += tile_h
	# Glowing cracks and embers.
	if e > 0.01:
		for c in _cracks:
			var pts := PackedVector2Array()
			for p in c["pts"]:
				pts.append(Vector2(p.x * w, p.y * h))
			if pts.size() >= 2:
				var ca := e * (0.45 + 0.35 * sin(_t * 2.5 + c["ph"]))
				draw_polyline(pts, Color(1.0, 0.35, 0.05, ca * 0.5), 5.0)
				draw_polyline(pts, Color(1.0, 0.7, 0.2, ca), 1.8)
		var n := clampi(int(w * h / 1800.0), 6, 28)
		for i in range(n):
			var em : Dictionary = _embers[i]
			var pos := Vector2(em["x"] * w, em["y"] * h)
			var pl := 0.5 + 0.5 * sin(_t * em["sp"] + em["ph"])
			var ea := e * (0.35 + 0.65 * pl)
			draw_circle(pos, em["r"] * 2.6, Color(1.0, 0.3, 0.05, ea * 0.22))
			draw_circle(pos, em["r"] * 1.5, Color(1.0, 0.5, 0.1, ea * 0.55))
			draw_circle(pos, em["r"] * 0.8, Color(1.0, 0.85, 0.35, ea))
	# Flames (behind the scrim, so text over them stays legible).
	# (Two boosts: sparks only, no flames; flames arrive with the third boost.)
	if b > 0.01:
		# Three or more boosts: tall flames rising from the bottom edge (none along the top).
		var inner := maxi(4, int(w / 40.0))
		for i in range(inner):
			var x := (i + 0.5) * w / inner
			_flame(Vector2(x, h - 2.0), 34.0, minf(h * 1.0, 130.0) * b, i * 2.3 + 1.0, b * 0.9)
	# Dark scrim for text readability.
	var scrim := 0.38 + 0.12 * b
	draw_rect(Rect2(3, 3, w - 6, h - 6), Color(0.04, 0.02, 0.01, scrim), true)
	# Charred edge that glows once the wood is burning.
	var edge := Color(0.10, 0.05, 0.02).lerp(Color(1.0, 0.45, 0.08), e * (0.55 + 0.25 * sin(_t * 4.0)))
	draw_rect(Rect2(1.5, 1.5, w - 3.0, h - 3.0), edge, false, 3.0)
	# Sparks.
	for s in _sparks:
		var k : float = s["life"] / s["max"]
		var p : Vector2 = s["p"]
		draw_line(p, p - (s["v"] as Vector2) * 0.04, Color(1.0, 0.6, 0.15, k * 0.7), 1.2)
		draw_circle(p, 1.6, Color(1.0, 0.9, 0.5, k))
