extends Control
# Phone layout: one stat badge (Range, Power, Speed, Armor or Guard) drawn as a cut gemstone in
# that stat's colour, showing the current modifier ("+3", "-1", "+0-2"). When the value changes
# it rolls to the new number like a slot machine reel, one step at a time. It pops in when it
# first gets a value and fades out when the modifier is gone. It never takes the mouse.

var color : Color = Color(1, 0.3, 0.3)
var _lo : int = 0
var _hi : int = 0
var _shown := ""          # text currently resting in the window
var _queue : Array = []   # texts still to roll through
var _roll : float = 1.0   # 0..1 progress of the current step (1 = at rest)
var _from := ""
var _to := ""
var _t : float = 0.0
var _font : Font
const STEP_TIME := 0.09
# How long each reel step takes (the life gem rolls a little slower).
var step_time : float = STEP_TIME
# The value is a total (a base stat plus its modifiers, or a life total): shown without a "+".
var absolute : bool = false
# Shown even when the value is 0 (a strike's Range / Power / Speed, a life total).
var force_show : bool = false
# Leaves with a pop (shrinking away) instead of a fade.
var pop_out_on_hide : bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.variation_embolden = 1.0
	_font = fv

static func fmt(lo : int, hi : int) -> String:
	var s := ("+%d" % lo) if lo >= 0 else str(lo)
	if hi != lo:
		s += "-%d" % hi if hi >= 0 else "-(%d)" % hi
	return s

func _fmt(lo : int, hi : int) -> String:
	if not absolute:
		return fmt(lo, hi)
	return str(lo) if hi == lo else "%d-%d" % [lo, hi]

func is_active() -> bool:
	return force_show or _lo != 0 or _hi != 0

# Switches between showing a modifier and a total (or forced showing) without any roll: the
# next set_value rolls from the re-formatted current value.
func set_mode(is_absolute : bool, show_always : bool) -> void:
	if is_absolute == absolute and show_always == force_show:
		return
	var was_active := is_active() and visible
	absolute = is_absolute
	force_show = show_always
	_shown = _fmt(_lo, _hi)
	if was_active and not is_active():
		_fade_out()
	elif not was_active and is_active():
		_queue.clear()
		_roll = 1.0
		_pop_in()

# Sets the modifier; the change rolls in (each whole step of the larger number shown in turn).
func set_value(lo : int, hi : int) -> void:
	if lo == _lo and hi == _hi:
		return
	var was_active := is_active() and visible # (a forced-show gem isn't up until it has a value)
	var old_lo := _lo
	var old_hi := _hi
	_lo = lo
	_hi = hi
	if not is_active():
		_fade_out()
		return
	if not was_active:
		# Appears showing its value.
		_queue.clear()
		_shown = _fmt(lo, hi)
		_roll = 1.0
		_pop_in()
		return
	# Roll through the in-between values (at most 6 steps, so big jumps stay quick).
	var steps := clampi(absi(hi - old_hi), 1, 6)
	for i in range(1, steps + 1):
		var k := float(i) / steps
		_queue.append(_fmt(roundi(lerpf(old_lo, lo, k)), roundi(lerpf(old_hi, hi, k))))
	if _roll >= 1.0:
		_next_step()

func _next_step() -> void:
	if _queue.is_empty():
		_roll = 1.0
		return
	_from = _shown
	_to = _queue.pop_front()
	_roll = 0.0

func _pop_in() -> void:
	visible = true
	pivot_offset = size / 2.0
	scale = Vector2(0.3, 0.3)
	modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.15)

func is_rolling() -> bool:
	return _roll < 1.0 or not _queue.is_empty()

# Pops out of view: a quick swell, then shrinks away.
func pop_out(then_free : bool = false) -> void:
	_queue.clear()
	_roll = 1.0
	pivot_offset = size / 2.0
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.12, 1.12), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(0.05, 0.05), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.22)
	tw.tween_callback(func():
		if then_free:
			queue_free()
		elif not is_active():
			visible = false)

func _fade_out() -> void:
	if pop_out_on_hide:
		pop_out()
		return
	_queue.clear()
	_roll = 1.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func():
		if not is_active():
			visible = false)

func _process(delta : float) -> void:
	if not visible:
		return
	_t += delta
	if _roll < 1.0:
		_roll = minf(1.0, _roll + delta / step_time)
		if _roll >= 1.0:
			_shown = _to
			_next_step()
	queue_redraw()

func _gem_points(r : Rect2, cut : float) -> PackedVector2Array:
	# An emerald-cut outline: a rectangle with its corners cut off.
	return PackedVector2Array([
		r.position + Vector2(cut, 0), Vector2(r.end.x - cut, r.position.y), Vector2(r.end.x, r.position.y + cut),
		Vector2(r.end.x, r.end.y - cut), Vector2(r.end.x - cut, r.end.y), Vector2(r.position.x + cut, r.end.y),
		Vector2(r.position.x, r.end.y - cut), Vector2(r.position.x, r.position.y + cut)])

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 8.0 or h < 8.0:
		return
	var outer := Rect2(Vector2.ZERO, size)
	var cut := h * 0.28
	var o := _gem_points(outer, cut)
	# Dark rim, then the stone.
	draw_colored_polygon(o, color.darkened(0.7))
	var body := outer.grow(-2.0)
	var b := _gem_points(body, cut * 0.92)
	draw_colored_polygon(b, color.darkened(0.25))
	# The table (flat top facet) and the bevel facets around it, lit from the top left.
	var tbl := body.grow_individual(-body.size.x * 0.16, -body.size.y * 0.22, -body.size.x * 0.16, -body.size.y * 0.22)
	var t := _gem_points(tbl, cut * 0.5)
	for i in range(8):
		var j := (i + 1) % 8
		var facet := PackedVector2Array([b[i], b[j], t[j], t[i]])
		var mid := (b[i] + b[j]) / 2.0 - outer.get_center()
		var lit := clampf(0.5 - (mid.x / w) * 0.6 - (mid.y / h) * 0.9, 0.0, 1.0)
		draw_colored_polygon(facet, color.darkened(0.45).lerp(color.lightened(0.35), lit))
	draw_colored_polygon(t, color.lightened(0.08))
	# Facet edges and a moving glint.
	var edge := Color(1, 1, 1, 0.22)
	var tl := t.duplicate()
	tl.append(t[0])
	draw_polyline(tl, edge, 1.0, true)
	for i in range(8):
		draw_line(b[i], t[i], edge, 1.0, true)
	var gx := fposmod(_t * 0.35, 1.6) - 0.3
	if gx >= 0.0 and gx <= 1.0:
		var sx := lerpf(tbl.position.x, tbl.end.x, gx)
		draw_line(Vector2(sx, tbl.position.y + 2), Vector2(sx - tbl.size.y * 0.5, tbl.end.y - 2), Color(1, 1, 1, 0.35), 3.0, true)
	# The number, rolling like a reel inside the table.
	var fs := int(h * 0.62)
	var win := tbl.grow_individual(4, 2, 4, 2)
	_draw_number(_shown if _roll >= 1.0 else _from, fs, win, -_roll if _roll < 1.0 else 0.0)
	if _roll < 1.0:
		_draw_number(_to, fs, win, 1.0 - _roll)

# Draws `txt` centred in `win`, shifted by `offset` window-heights (negative = up), clipped to
# the window by fading near its edges.
func _draw_number(txt : String, fs : int, win : Rect2, offset : float) -> void:
	if txt == "":
		return
	var f := _font
	var sz := fs
	while sz > 8 and f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > size.x - 8.0:
		sz -= 1
	var asc := f.get_ascent(sz)
	var desc := f.get_descent(sz)
	var y := win.get_center().y + (asc - desc) / 2.0 + offset * win.size.y
	var a := clampf(1.0 - absf(offset) * 1.6, 0.0, 1.0)
	if a <= 0.0:
		return
	var pos := Vector2(0, y)
	draw_string_outline(f, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, size.x, sz, maxi(3, sz / 6), Color(0, 0, 0, 0.85 * a))
	draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, size.x, sz, Color(1, 1, 1, a))
