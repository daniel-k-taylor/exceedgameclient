class_name MetalBar
extends Control
# A bar with a soft vertical colour gradient, a bevelled metallic edge and a screw in each
# corner. Purely decorative: it ignores the mouse.

var top_color : Color = Color(0.24, 0.30, 0.58)
var bottom_color : Color = Color(0.15, 0.19, 0.40)
var screws_only : bool = false
var brushed : bool = false # faint horizontal brushed-metal streaks on the fill layer
var edge : float = 7.0
var screw_radius : float = 5.5
var screw_inset : float = 10.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func set_colors(top : Color, bottom : Color) -> void:
	top_color = top
	bottom_color = bottom
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 2.0 or h <= 2.0:
		return
	var e := minf(edge, h * 0.2)
	if not screws_only:
		_draw_fill(w, h, e)
		return
	# Metallic bevelled edge: light on the top / left, dark on the bottom / right.
	var c_top := Color(0.90, 0.92, 0.96)
	var c_left := Color(0.72, 0.74, 0.79)
	var c_right := Color(0.50, 0.52, 0.57)
	var c_bot := Color(0.33, 0.35, 0.40)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w - e, e), Vector2(e, e)]),
			PackedColorArray([c_top, c_top, c_left, c_left]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(e, e), Vector2(e, h - e), Vector2(0, h)]),
			PackedColorArray([c_top, c_left, c_right, c_right]))
	draw_polygon(PackedVector2Array([Vector2(w, 0), Vector2(w, h), Vector2(w - e, h - e), Vector2(w - e, e)]),
			PackedColorArray([c_right, c_bot, c_bot, c_right]))
	draw_polygon(PackedVector2Array([Vector2(0, h), Vector2(w, h), Vector2(w - e, h - e), Vector2(e, h - e)]),
			PackedColorArray([c_right, c_bot, c_bot, c_right]))
	# Thin dark outlines: outside of the plate and where the edge meets the fill.
	draw_rect(Rect2(0.5, 0.5, w - 1.0, h - 1.0), Color(0.12, 0.13, 0.16), false, 1.5)
	draw_rect(Rect2(e, e, w - 2.0 * e, h - 2.0 * e), Color(0.0, 0.0, 0.0, 0.45), false, 1.5)
	_draw_screws()

# Soft vertical gradient, with a faint lighter sheen across the upper third (the layer under the cards).
func _draw_fill(w : float, h : float, e : float) -> void:
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([top_color, top_color, bottom_color, bottom_color]))
	var sheen := Color(1, 1, 1, 0.07)
	var clear := Color(1, 1, 1, 0.0)
	draw_polygon(PackedVector2Array([Vector2(e, e), Vector2(w - e, e), Vector2(w - e, h * 0.45), Vector2(e, h * 0.45)]),
			PackedColorArray([sheen, sheen, clear, clear]))
	if brushed:
		var y := 3.0
		var k := 0
		while y < h:
			var v := fmod(float(k) * 0.6180339, 1.0)
			var col := Color(1, 1, 1, 0.03 + 0.07 * v) if k % 3 != 0 else Color(0, 0, 0, 0.04 + 0.06 * v)
			draw_line(Vector2(0, y), Vector2(w, y), col, 1.0 + fmod(v * 7.0, 1.0))
			y += 3.0 + fmod(v * 11.0, 4.0)
			k += 1

# The four corner screws, drawn by a second instance (screws_only) layered above the cards.
func _draw_screws() -> void:
	var w := size.x
	var h := size.y
	var inset := minf(screw_inset, minf(w, h) * 0.2)
	var angles := [0.5, 2.2, 1.1, 2.9]
	var centers := [Vector2(inset, inset), Vector2(w - inset, inset), Vector2(inset, h - inset), Vector2(w - inset, h - inset)]
	for i in range(4):
		var c : Vector2 = centers[i]
		draw_circle(c + Vector2(0.8, 1.0), screw_radius + 0.8, Color(0, 0, 0, 0.45)) # drop shadow
		draw_circle(c, screw_radius + 0.5, Color(0.18, 0.19, 0.22))
		draw_circle(c, screw_radius, Color(0.66, 0.68, 0.73))
		draw_circle(c - Vector2(0.9, 0.9), screw_radius * 0.55, Color(0.88, 0.90, 0.94)) # highlight
		var d := Vector2(cos(angles[i]), sin(angles[i])) * (screw_radius - 0.6)
		draw_line(c - d, c + d, Color(0.22, 0.23, 0.27), 1.4)
