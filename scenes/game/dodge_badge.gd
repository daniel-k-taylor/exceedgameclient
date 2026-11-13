extends "res://scenes/game/pop_badge.gd"
# "DODGE" badge (phone layout): a green pill with coolant circulating inside it, bright green
# fluid looping around a channel with bubbles riding along, behind a glassy sheen. Same rim
# as the ADVANTAGE badge (a black line over a white rim) and bold lettering. Pops in with a
# little bounce and fades away when told to.

var text : String = "DODGE"
var _t : float = 0.0
var _label : Label
var _bubbles : Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for i in range(9):
		_bubbles.append({"u": rng.randf(), "sp": rng.randf_range(0.18, 0.3), "r": rng.randf_range(1.2, 2.6),
				"lane": rng.randf_range(-0.12, 0.12)})
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.variation_embolden = 1.0
	_label.add_theme_font_override("font", fv)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.16, 0.05))
	add_child(_label)
	resized.connect(_fit_label)
	set_text(text)

func set_text(t : String) -> void:
	text = t
	if _label != null:
		_label.text = t
		_fit_label()

func _fit_label() -> void:
	if _label == null:
		return
	_label.position = Vector2.ZERO
	_label.size = size
	var fs := maxi(12, int(size.y * 0.48))
	var f : Font = _label.get_theme_font("font")
	while fs > 10 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - size.y * 0.9:
		fs -= 1
	_label.add_theme_font_size_override("font_size", fs)
	_label.add_theme_constant_override("outline_size", maxi(4, int(size.y * 0.14)))

func _process(delta : float) -> void:
	_t += delta
	queue_redraw()

func _pill(rect : Rect2, steps : int = 12) -> PackedVector2Array:
	var r := rect.size.y / 2.0
	var pts := PackedVector2Array()
	var cl := rect.position + Vector2(r, r)
	var cr := rect.position + Vector2(rect.size.x - r, r)
	for k in range(steps + 1):
		var a := PI / 2.0 + PI * k / steps
		pts.append(cl + Vector2(cos(a), sin(a)) * r)
	for k in range(steps + 1):
		var a := -PI / 2.0 + PI * k / steps
		pts.append(cr + Vector2(cos(a), sin(a)) * r)
	return pts

# A point on the loop (u in 0..1) running around the inside of the pill.
func _loop_point(inner : Rect2, u : float, lane : float) -> Vector2:
	var r := inner.size.y / 2.0
	var ring := r * (0.55 + lane * 0.4)
	var straight := inner.size.x - 2.0 * r
	var total := 2.0 * straight + TAU * ring
	var d := fposmod(u, 1.0) * total
	var cl := inner.position + Vector2(r, r)
	var cr := inner.position + Vector2(inner.size.x - r, r)
	if d < straight: # along the top, left to right
		return Vector2(cl.x + d, cl.y - ring)
	d -= straight
	if d < PI * ring: # around the right end
		var a := -PI / 2.0 + d / ring
		return cr + Vector2(cos(a), sin(a)) * ring
	d -= PI * ring
	if d < straight: # along the bottom, right to left
		return Vector2(cr.x - d, cr.y + ring)
	d -= straight
	var a2 := PI / 2.0 + d / ring # around the left end
	return cl + Vector2(cos(a2), sin(a2)) * ring

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 10.0 or h < 10.0:
		return
	draw_colored_polygon(_pill(Rect2(Vector2.ZERO, size)), Color(1, 1, 1))
	draw_colored_polygon(_pill(Rect2(Vector2(3, 3), size - Vector2(6, 6))), Color(0, 0, 0))
	var inner := Rect2(Vector2(6, 6), size - Vector2(12, 12))
	# Dark green tank.
	var tank := _pill(inner)
	var cols := PackedColorArray()
	for p in tank:
		cols.append(Color(0.05, 0.42, 0.16).lerp(Color(0.02, 0.24, 0.09), (p.y - inner.position.y) / inner.size.y))
	draw_polygon(tank, cols)
	# The coolant: a glowing tube looping round the badge, with bright slugs of fluid racing
	# along it so it reads as liquid being pumped round.
	var n := 96
	var tube := PackedVector2Array()
	for k in range(n + 1):
		tube.append(_loop_point(inner, float(k) / n, 0.0))
	var tw := inner.size.y * 0.24
	draw_polyline(tube, Color(0.0, 0.12, 0.04, 0.9), tw + 2.0, true)
	draw_polyline(tube, Color(0.1, 0.55, 0.22, 1.0), tw, true)
	for k in range(n):
		var u := float(k) / n
		var wave := fposmod(u - _t * 0.32, 1.0 / 3.0) * 3.0 # three slugs round the loop
		var glow := pow(wave, 2.5) # long tail, bright head
		if glow < 0.02:
			continue
		var a := _loop_point(inner, u, 0.0)
		var b := _loop_point(inner, u + 1.0 / n, 0.0)
		draw_line(a, b, Color(0.3, 1.0, 0.5, 0.35 * glow), tw * 1.3, true)
		draw_line(a, b, Color(0.75, 1.0, 0.8, 0.9 * glow), tw * 0.7, true)
	# Bubbles riding the current.
	for bb in _bubbles:
		var p := _loop_point(inner, bb["u"] + _t * bb["sp"], bb["lane"])
		draw_circle(p, bb["r"] * 0.7 + 0.6, Color(0.9, 1.0, 0.92, 0.8))
	# Glassy sheen across the top half.
	var sheen := Rect2(inner.position + Vector2(inner.size.y * 0.3, 2.0), Vector2(inner.size.x - inner.size.y * 0.6, inner.size.y * 0.3))
	draw_rect(sheen, Color(1, 1, 1, 0.14))
