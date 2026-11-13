extends Control
# Phone layout: a shine that sweeps across the action island's buttons when it appears, to draw
# the eye to them. `inner` is the buttons' rect in this control's coordinates. It
# never takes the mouse.

const DURATION := 0.6
var inner := Rect2()
var _t : float = DURATION

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func burst() -> void:
	_t = 0.0
	queue_redraw()

func _process(delta : float) -> void:
	if _t < DURATION:
		_t += delta
		queue_redraw()

func _draw() -> void:
	if _t >= DURATION or inner.size.x <= 1.0:
		return
	# A shine sweeping across the buttons.
	var sweep := _t / 0.55
	if sweep < 1.0:
		var h := inner.size.y
		var x := lerpf(inner.position.x - h, inner.end.x + h, sweep)
		var band := PackedVector2Array([Vector2(x, inner.position.y), Vector2(x + h * 0.45, inner.position.y),
				Vector2(x + h * 0.45 - h * 0.5, inner.end.y), Vector2(x - h * 0.5, inner.end.y)])
		var box := PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y), inner.end,
				Vector2(inner.position.x, inner.end.y)])
		for poly in Geometry2D.intersect_polygons(band, box):
			draw_colored_polygon(poly, Color(1, 1, 1, 0.35 * sin(sweep * PI)))
