extends "res://scenes/game/pop_badge.gd"
# "ADVANTAGE" badge (phone layout): a sky-blue pill with wind streaks blowing through it,
# a white rim with a black line on top of it, and bold italic lettering. It pops in with a
# little bounce and fades away when told to.

var _t : float = 0.0
var _streaks : Array = []
var _label : Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in range(7):
		_streaks.append({"y": rng.randf_range(0.18, 0.82), "len": rng.randf_range(0.25, 0.5),
				"sp": rng.randf_range(0.45, 0.9), "ph": rng.randf(), "w": rng.randf_range(1.5, 3.0),
				"amp": rng.randf_range(1.5, 3.5)})
	_label = Label.new()
	_label.text = "ADVANTAGE"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.variation_embolden = 1.0
	fv.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.22, 1), Vector2.ZERO) # italic slant
	_label.add_theme_font_override("font", fv)
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_label.add_theme_color_override("font_outline_color", Color(0.02, 0.1, 0.2))
	_label.add_theme_constant_override("outline_size", 7)
	add_child(_label)
	resized.connect(_fit_label)

const SLANT := 0.22 # the lettering's italic slant (see the font's transform in _ready)

func _fit_label() -> void:
	var fs := maxi(12, int(size.y * 0.48))
	_label.add_theme_font_size_override("font_size", fs)
	_label.add_theme_constant_override("outline_size", maxi(4, int(size.y * 0.14)))
	# The slant shifts each letter sideways by its height above the baseline, so the word sits
	# left of center: move the label right by that shift halfway up the letters to center it.
	var asc : float = _label.get_theme_font("font").get_ascent(fs)
	_label.position = Vector2(SLANT * asc * 0.5, 0.0)
	_label.size = size

func _process(delta : float) -> void:
	_t += delta
	queue_redraw()

func _pill(rect : Rect2) -> PackedVector2Array:
	var r := rect.size.y / 2.0
	var pts := PackedVector2Array()
	var cl := rect.position + Vector2(r, r)
	var cr := rect.position + Vector2(rect.size.x - r, r)
	for k in range(13):
		var a := PI / 2.0 + PI * k / 12.0
		pts.append(cl + Vector2(cos(a), sin(a)) * r)
	for k in range(13):
		var a := -PI / 2.0 + PI * k / 12.0
		pts.append(cr + Vector2(cos(a), sin(a)) * r)
	return pts

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 10.0 or h < 10.0:
		return
	# White rim, then the black line over it, then the sky.
	draw_colored_polygon(_pill(Rect2(Vector2.ZERO, size)), Color(1, 1, 1))
	draw_colored_polygon(_pill(Rect2(Vector2(3, 3), size - Vector2(6, 6))), Color(0, 0, 0))
	var inner := Rect2(Vector2(6, 6), size - Vector2(12, 12))
	var sky := _pill(inner)
	var cols := PackedColorArray()
	for p in sky:
		cols.append(Color(0.55, 0.85, 1.0).lerp(Color(0.25, 0.62, 0.95), (p.y - inner.position.y) / inner.size.y))
	draw_polygon(sky, cols)
	# Wind: soft white streaks curling across, inside the pill.
	var r := inner.size.y / 2.0
	for s in _streaks:
		var y : float = inner.position.y + s["y"] * inner.size.y
		var u : float = fmod(s["ph"] + _t * s["sp"], 1.4) - 0.2
		var x0 : float = inner.position.x + u * inner.size.x
		var ln : float = s["len"] * inner.size.x
		var pts := PackedVector2Array()
		for k in range(10):
			var f := float(k) / 9.0
			var x := x0 + f * ln
			# keep inside the rounded ends
			var dy : float = absf(y - (inner.position.y + r))
			var half := sqrt(maxf(r * r - dy * dy, 0.0))
			var lo := inner.position.x + r - half
			var hi := inner.position.x + inner.size.x - r + half
			x = clampf(x, lo, hi)
			pts.append(Vector2(x, y + sin(f * TAU + _t * 3.0 + s["ph"] * 6.0) * s["amp"]))
		var fade := clampf(1.0 - absf(u - 0.5) * 1.6, 0.0, 1.0)
		draw_polyline(pts, Color(1, 1, 1, 0.45 * fade), s["w"], true)
