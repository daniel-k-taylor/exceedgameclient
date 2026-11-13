extends "res://scenes/game/pop_badge.gd"
# "STUNNED" badge (phone layout): a pill of polished black onyx with faint grey-white veins
# running through the stone, a glossy highlight along the top and a slow glint that sweeps
# across it now and then. Same white-and-black rim as the other badges. Used in the badge
# grid and, larger, over the middle of a stunned strike card.

var text : String = "STUNNED"
var _t : float = 0.0
var _label : Label
var _veins : Array = [] # each: PackedVector2Array in 0..1 units, plus a width and alpha
var _vein_seed : int = 2024

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_t = randf() * 3.0
	_make_veins()
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.variation_embolden = 1.0
	_label.add_theme_font_override("font", fv)
	_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.18))
	_label.add_theme_constant_override("shadow_offset_x", 0)
	_label.add_theme_constant_override("shadow_offset_y", -1)
	add_child(_label)
	resized.connect(_fit_label)
	set_text(text)

func _make_veins() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _vein_seed
	_veins.clear()
	for i in range(7):
		var pts := PackedVector2Array()
		var x := rng.randf_range(-0.15, 0.5)
		var y := rng.randf_range(0.05, 0.95)
		var dx := rng.randf_range(0.06, 0.1)
		var dy := rng.randf_range(-0.12, 0.12)
		for k in range(12):
			pts.append(Vector2(x, y))
			x += dx * rng.randf_range(0.6, 1.4)
			y += dy + rng.randf_range(-0.1, 0.1)
		_veins.append({"pts": pts, "w": rng.randf_range(0.6, 1.6), "a": rng.randf_range(0.12, 0.3)})

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
	while fs > 10 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - size.y * 0.8:
		fs -= 1
	_label.add_theme_font_size_override("font_size", fs)
	_label.add_theme_constant_override("outline_size", maxi(4, int(size.y * 0.12)))

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

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 10.0 or h < 10.0:
		return
	var rim := maxf(3.0, h * 0.075)
	draw_colored_polygon(_pill(Rect2(Vector2.ZERO, size)), Color(1, 1, 1))
	draw_colored_polygon(_pill(Rect2(Vector2(rim, rim), size - Vector2(rim, rim) * 2.0)), Color(0, 0, 0))
	var inner := Rect2(Vector2(rim, rim) * 2.0, size - Vector2(rim, rim) * 4.0)
	var stone := _pill(inner)
	# The stone: near-black, a touch lighter toward the top.
	var cols := PackedColorArray()
	for p in stone:
		var v := (p.y - inner.position.y) / inner.size.y
		cols.append(Color(0.16, 0.16, 0.18).lerp(Color(0.02, 0.02, 0.03), clampf(v, 0.0, 1.0)))
	draw_polygon(stone, cols)
	# Veins through the onyx.
	for vein in _veins:
		var pts := PackedVector2Array()
		for q in vein["pts"]:
			pts.append(inner.position + Vector2(q.x * inner.size.x, q.y * inner.size.y))
		for seg in Geometry2D.intersect_polyline_with_polygon(pts, stone):
			if seg.size() >= 2:
				draw_polyline(seg, Color(0.85, 0.85, 0.9, vein["a"]), vein["w"] * h / 40.0, true)
	# Glossy highlight along the top.
	var gloss := _pill(Rect2(inner.position + Vector2(inner.size.y * 0.35, inner.size.y * 0.08),
			Vector2(inner.size.x - inner.size.y * 0.7, inner.size.y * 0.32)), 8)
	draw_colored_polygon(gloss, Color(1, 1, 1, 0.13))
	# A glint sweeping across every few seconds.
	var cycle := fposmod(_t, 3.2) / 1.1
	if cycle < 1.0:
		var gx := lerpf(inner.position.x - h, inner.end.x + h, cycle)
		var bw := h * 0.35
		var band := PackedVector2Array([Vector2(gx, inner.position.y - 2), Vector2(gx + bw, inner.position.y - 2),
				Vector2(gx + bw - h * 0.5, inner.end.y + 2), Vector2(gx - h * 0.5, inner.end.y + 2)])
		for poly in Geometry2D.intersect_polygons(band, stone):
			draw_colored_polygon(poly, Color(1, 1, 1, 0.16 * sin(cycle * PI)))


# A heavier landing for the card: drops in from large, like a stone slab slamming down.
func slam_in() -> void:
	pivot_offset = size / 2.0
	scale = Vector2(1.8, 1.8)
	modulate.a = 0.0
	visible = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 1.0, 0.15)
	tw.chain().tween_property(self, "scale", Vector2(1.06, 1.06), 0.06)
	tw.chain().tween_property(self, "scale", Vector2.ONE, 0.1)
