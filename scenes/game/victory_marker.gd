extends Control
# Phone layout: one victory slot under a player's life bar. Empty, it is a bold dot centered in the
# slot; once that player has won a game it is a small bordered metal plate with a letter for how the
# game was won: a black "N" on bronze (normal attack), an "S" in the player's color on silver
# (special), a rainbow "U" on gold (ultra), or a green "X" on platinum (any other way). A match of
# several games stacks them up (see PhoneLayout).

const RAINBOW := [Color(0.95, 0.15, 0.15), Color(1.0, 0.55, 0.05), Color(0.98, 0.85, 0.1),
		Color(0.2, 0.8, 0.25), Color(0.2, 0.5, 1.0), Color(0.6, 0.25, 0.9)]

const METALS := {
	"N": Color(0.78, 0.48, 0.22), # bronze
	"S": Color(0.74, 0.76, 0.8), # silver
	"U": Color(0.96, 0.74, 0.18), # gold
	"X": Color(0.86, 0.87, 0.9), # platinum
}

var won_kind : String = "" # "", "N", "S", "U" or "X"
var player_color : Color = Color.WHITE
var x_color : Color = Color(0.25, 0.85, 0.3)
var _letter_root : Control = null
var _dot_scale : float = 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_rebuild_letter)

# Wins this slot (`kind`: "N", "S", "U" or "X"): the dot shrinks away and the square pops in.
func set_won(kind : String, animate : bool = true) -> void:
	if kind == won_kind:
		return
	if kind == "" or not animate:
		won_kind = kind
		_dot_scale = 1.0
		scale = Vector2.ONE
		_rebuild_letter()
		queue_redraw()
		return
	pivot_offset = size / 2.0
	var t := create_tween()
	t.tween_method(func(v : float): _dot_scale = v; queue_redraw(), 1.0, 0.0, 0.18)
	t.tween_callback(func():
		won_kind = kind
		_rebuild_letter()
		scale = Vector2(0.2, 0.2)
		queue_redraw())
	t.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	var c := size / 2.0
	var s : float = minf(size.x, size.y)
	if won_kind == "":
		var r := s * 0.2 * _dot_scale
		if r <= 0.5:
			return
		draw_circle(c, r + 2.0, Color(0, 0, 0, 0.85))
		draw_circle(c, r, Color(0.95, 0.95, 0.95))
		return
	# The square, filling the slot: a metal plate for how the game was won (bronze N, silver S,
	# gold U, platinum X), brushed, lit from the top, inside a border of the same metal, darker.
	var metal : Color = METALS.get(won_kind, METALS["X"])
	var rect := Rect2(c - Vector2(s, s) / 2.0, Vector2(s, s))
	draw_rect(rect.grow(1.0), Color(0, 0, 0, 0.9)) # (a fine dark edge outside the border)
	draw_rect(rect, metal.darkened(0.45)) # the border
	var bw := maxf(2.0, s * 0.1)
	var inner := rect.grow(-bw)
	# the plate: lighter at the top, darker at the bottom
	var bands := 8
	for i in range(bands):
		var t := float(i) / float(bands - 1)
		var col := metal.lightened(0.35).lerp(metal.darkened(0.12), t)
		draw_rect(Rect2(inner.position + Vector2(0, inner.size.y * i / bands), Vector2(inner.size.x, inner.size.y / bands + 0.5)), col)
	# brushed: fine horizontal streaks
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	for i in range(int(inner.size.y * 1.2)):
		var y := inner.position.y + rng.randf() * inner.size.y
		var x0 := inner.position.x + rng.randf() * inner.size.x * 0.6
		var ln := rng.randf_range(0.25, 0.6) * inner.size.x
		var light := rng.randf() < 0.5
		draw_line(Vector2(x0, y), Vector2(minf(x0 + ln, inner.end.x), y),
				Color(1, 1, 1, 0.18) if light else Color(0, 0, 0, 0.1), 1.0)
	# the border's bevel: a light top-left, a dark bottom-right
	draw_line(rect.position, Vector2(rect.end.x, rect.position.y), metal.lightened(0.5), 1.5)
	draw_line(rect.position, Vector2(rect.position.x, rect.end.y), metal.lightened(0.3), 1.5)
	draw_line(Vector2(rect.position.x, rect.end.y), rect.end, metal.darkened(0.7), 1.5)
	draw_line(Vector2(rect.end.x, rect.position.y), rect.end, metal.darkened(0.6), 1.5)
	draw_rect(inner, Color(0, 0, 0, 0.35), false, 1.0) # (the plate set into the border)

# The letter: a bold Label (the rainbow "U" is made of horizontal bands, each one clipped, in
# the colors of the rainbow).
func _rebuild_letter() -> void:
	if _letter_root != null and is_instance_valid(_letter_root):
		_letter_root.queue_free()
		_letter_root = null
	if won_kind == "" or size.x <= 1.0:
		return
	_letter_root = Control.new()
	_letter_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_letter_root.size = size
	add_child(_letter_root)
	var colors : Array = [Color.BLACK]
	match won_kind:
		"S": colors = [player_color]
		"U": colors = RAINBOW
		"X": colors = [x_color]
	var n := colors.size()
	var band_h := size.y / n
	for i in range(n):
		var clip := Control.new()
		clip.clip_contents = true
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.position = Vector2(0, band_h * i)
		clip.size = Vector2(size.x, band_h + (0.0 if i == n - 1 else 0.5))
		_letter_root.add_child(clip)
		var lab := Label.new()
		lab.text = won_kind
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fv := FontVariation.new()
		fv.base_font = ThemeDB.fallback_font
		fv.variation_embolden = 1.2
		lab.add_theme_font_override("font", fv)
		lab.add_theme_font_size_override("font_size", int(size.y * 0.64)) # (inside the border)
		lab.add_theme_color_override("font_color", colors[i])
		# (a light outline keeps the colored letters crisp on the white)
		if won_kind != "N":
			lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
			lab.add_theme_constant_override("outline_size", maxi(2, int(size.y * 0.06)))
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.position = Vector2(0, -band_h * i)
		lab.size = size
		clip.add_child(lab)
