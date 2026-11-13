extends Control
# Defeat storm: dark clouds descend from the top of the screen, then rain pours down and
# lightning flickers now and then. Ignores the mouse. Size it to the whole screen.

var _t : float = 0.0
var _blobs : Array = []
var _drops : Array = []
var _descend : float = 0.0 # 0 = clouds above the screen, 1 = in place
var _flash : float = 0.0
var _next_flash : float = 2.5
var _rng := RandomNumberGenerator.new()
# The lowest the clouds may reach once in place (e.g. the top of the player names); INF: no limit.
var max_bottom : float = INF

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 31337
	for layer in range(3):
		for i in range(11):
			var cluster := []
			for k in range(5):
				cluster.append({"dx": _rng.randf_range(-70.0, 70.0), "dy": _rng.randf_range(-22.0, 26.0),
						"r": _rng.randf_range(48.0, 92.0)})
			_blobs.append({"layer": layer, "x": (i + _rng.randf_range(-0.2, 0.2)) / 10.0, "y": _rng.randf_range(0.0, 1.0), "c": cluster})
	for i in range(260):
		_drops.append({"x": _rng.randf(), "y": _rng.randf(), "s": _rng.randf_range(0.8, 1.5), "l": _rng.randf_range(26.0, 54.0)})
	var tw := create_tween()
	tw.tween_property(self, "_descend", 1.0, 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _process(delta : float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 2.6)
	if _descend > 0.8:
		_next_flash -= delta
		if _next_flash <= 0.0:
			_flash = 1.0
			_next_flash = _rng.randf_range(3.0, 6.0)
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 1.0:
		return
	var dark := _descend * 0.5
	draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.03, 0.08, dark))
	var yoff := -(1.0 - _descend) * h * 0.3
	if max_bottom < INF:
		# Lifted so their lowest point, once in place, is at max_bottom.
		var low := 0.0
		for b in _blobs:
			var by : float = h * (0.02 + 0.03 * b["layer"]) + float(b["y"]) * h * 0.05 + 5.0
			for c in b["c"]:
				low = maxf(low, by + float(c["dy"]) + float(c["r"]))
		low = maxf(low, h * 0.09)
		yoff += minf(0.0, max_bottom - low)
	# Rain, behind the front cloud layer; falls diagonally, fades in as the clouds arrive.
	var ra := clampf((_descend - 0.25) / 0.6, 0.0, 1.0)
	if ra > 0.0:
		for d in _drops:
			var speed : float = 1100.0 * float(d["s"])
			var y : float = fposmod(float(d["y"]) * h + _t * speed, h + 80.0) - 40.0
			var x : float = fposmod(float(d["x"]) * w - y * 0.18, w)
			var ln : float = float(d["l"])
			draw_line(Vector2(x, y), Vector2(x - ln * 0.18, y + ln), Color(0.7, 0.8, 1.0, 0.55 * ra), 2.5)
	# Clouds.
	draw_rect(Rect2(0, -300 + yoff, w, 300 + h * 0.09), Color(0.12, 0.13, 0.18))
	var cols := [Color(0.30, 0.33, 0.42), Color(0.22, 0.24, 0.32), Color(0.14, 0.15, 0.21)]
	for layer in range(3):
		var drift := (_t * (6.0 + layer * 5.0)) * (1.0 if layer % 2 == 0 else -1.0)
		for b in _blobs:
			if b["layer"] != layer:
				continue
			var cx : float = fposmod(b["x"] * w + drift + 140.0, w + 280.0) - 140.0
			var cy : float = h * (0.02 + 0.03 * layer) + float(b["y"]) * h * 0.05 + sin(_t * 0.8 + b["x"] * 9.0) * 5.0 + yoff
			for c in b["c"]:
				draw_circle(Vector2(cx + c["dx"], cy + c["dy"]), c["r"], cols[layer])
	if _flash > 0.0:
		draw_rect(Rect2(0, 0, w, h), Color(0.9, 0.93, 1.0, 0.35 * _flash))
