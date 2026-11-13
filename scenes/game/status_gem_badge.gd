extends "res://scenes/game/pop_badge.gd"
# Shared base for the strike-status badges drawn as gems / energy (STUN IMMUNE, IGNORE ARMOR,
# IGNORE GUARD): a pill with the same white rim and black line as the other badges, bold
# lettering that shrinks to fit, the same pop-in bounce and fade-out. Subclasses draw the
# inside of the pill in _draw_fill(inner, poly).

var text : String = ""
var _t : float = 0.0
var _label : Label
var font_color : Color = Color(1, 1, 1)
var outline_color : Color = Color(0, 0, 0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_t = randf() * 3.0
	_setup()
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.variation_embolden = 1.0
	_label.add_theme_font_override("font", fv)
	_label.add_theme_color_override("font_color", font_color)
	_label.add_theme_color_override("font_outline_color", outline_color)
	add_child(_label)
	resized.connect(_fit_label)
	set_text(text)

# Subclasses: one-off setup (random shapes etc.) before the label is made.
func _setup() -> void:
	pass

# Subclasses: draw the inside of the badge. `poly` is the inner pill outline.
func _draw_fill(_inner : Rect2, _poly : PackedVector2Array) -> void:
	pass

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
	var fs := maxi(12, int(size.y * 0.46))
	var f : Font = _label.get_theme_font("font")
	while fs > 10 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - size.y * 0.8:
		fs -= 1
	_label.add_theme_font_size_override("font_size", fs)
	_label.add_theme_constant_override("outline_size", maxi(4, int(size.y * 0.13)))

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

# Draws `poly` clipped to `clip` (both convex or simple polygons).
func _draw_clipped(poly : PackedVector2Array, clip : PackedVector2Array, col : Color) -> void:
	for p in Geometry2D.intersect_polygons(poly, clip):
		if p.size() >= 3:
			draw_colored_polygon(p, col)

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 10.0 or h < 10.0:
		return
	var rim := maxf(3.0, h * 0.075)
	draw_colored_polygon(_pill(Rect2(Vector2.ZERO, size)), Color(1, 1, 1))
	draw_colored_polygon(_pill(Rect2(Vector2(rim, rim), size - Vector2(rim, rim) * 2.0)), Color(0, 0, 0))
	var inner := Rect2(Vector2(rim, rim) * 2.0, size - Vector2(rim, rim) * 4.0)
	_draw_fill(inner, _pill(inner))

# A sweeping glint across the badge every `period` seconds.
func _draw_glint(inner : Rect2, poly : PackedVector2Array, period : float, strength : float) -> void:
	var h := size.y
	var cycle := fposmod(_t, period) / 1.1
	if cycle >= 1.0:
		return
	var gx := lerpf(inner.position.x - h, inner.end.x + h, cycle)
	var bw := h * 0.35
	var band := PackedVector2Array([Vector2(gx, inner.position.y - 2), Vector2(gx + bw, inner.position.y - 2),
			Vector2(gx + bw - h * 0.5, inner.end.y + 2), Vector2(gx - h * 0.5, inner.end.y + 2)])
	_draw_clipped(band, poly, Color(1, 1, 1, strength * sin(cycle * PI)))

# A four-pointed twinkle star.
func _draw_sparkle(c : Vector2, r : float, col : Color) -> void:
	if r < 0.5:
		return
	var t := r * 0.22
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(t, -t), c + Vector2(r, 0), c + Vector2(t, t),
			c + Vector2(0, r), c + Vector2(-t, t), c + Vector2(-r, 0), c + Vector2(-t, -t)]), col)
	draw_circle(c, t * 1.2, Color(1, 1, 1, col.a))
