extends Node2D
# Lightning for a gauge strip (phone layout). The first gauge card sends a main bolt streaking
# from the "G" in the first space to the top, outer or bottom edge of the 7th space; each further
# card (up to 5 in all) branches a new bolt off the main one, starting in the space that card went
# into. Every bolt ends on its own edge: the top / outer / bottom edges of the 7th space and the
# top / bottom edges of the 6th, so five bolts use all five. Endpoints are handed out so bolts
# never cross (see _pick_endpoint). The bolts keep their shape and thickness once they have
# streaked in; with each bolt they all grow more vibrant, and at five they glow like plasma with
# electricity crackling along them. Cards beyond five add nothing; as cards leave, the newest
# bolts fade away and the effect dims.
# The phone layout puts this node in a clipping box around its gauge strip (so the boost and
# arena areas are never drawn over) and under the gauge icons. A Node2D takes no input.

const MAX_BOLTS := 5
const STREAK_TIME := 0.22   # a new bolt's streak from start to end
const FADE_TIME := 0.35     # a removed bolt fading out (the effect dims with it)
const SEGMENTS := 12        # kinks along a bolt
const INSET := 3.0          # how far inside the boxes' outer edges a bolt may go

# The five endpoints in order around the far end of the strip (top of the 6th space, top of
# the 7th, the 7th's outer edge, bottom of the 7th, bottom of the 6th).
const ORDER := ["t6", "t7", "o7", "b7", "b6"]

var color : Color = Color(1.0, 0.3, 0.25)
var slot_rects : Array = [] # Rect2s in fill order (slot 0 holds the "G"), in parent coordinates

var _count : int = 0        # bolts wanted (cards in gauge, capped at MAX_BOLTS)
var _bolts : Array = []     # {start_slot, end, born, dying, seed}
var _intensity : float = 0.0
var _t : float = 0.0
var _sparks : Array = []    # short crackling arcs: {p, dir, len, life, max, seed}
var _spark_acc : float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

# Called whenever the gauge is laid out: the boxes' rects (fill order) and the card count.
func set_gauge(rects : Array, cards : int, col : Color) -> void:
	slot_rects = rects
	color = col
	var want := mini(cards, MAX_BOLTS)
	if want == _count:
		return
	if want > _count:
		for i in range(_live_bolts().size(), want):
			_bolts.append(_new_bolt(i))
	else:
		# The newest bolts fade first.
		var live := _live_bolts()
		for i in range(live.size() - 1, want - 1, -1):
			live[i]["dying"] = _t
	_count = want

func _live_bolts() -> Array:
	var out := []
	for b in _bolts:
		if b["dying"] < 0.0:
			out.append(b)
	return out

func _new_bolt(index : int) -> Dictionary:
	var b := {"start_slot": index, "born": _t, "dying": -1.0, "seed": _rng.randi()}
	if index == 0:
		b["end"] = ["t7", "o7", "b7"][_rng.randi() % 3]
	else:
		b["end"] = _pick_endpoint(index)
	return b

# A branch's endpoint. Branches split off the main bolt further along the strip each time, so to
# never cross, each new branch must end between the main bolt's endpoint and the endpoints of
# the branches already on that side of it (in ORDER). Of those, it picks one that still leaves
# room for the rest, so five bolts end on all five edges.
func _pick_endpoint(index : int) -> String:
	var live := _live_bolts()
	var used := {}
	var main_end := "o7"
	for b in live:
		used[b["end"]] = true
		if b["start_slot"] == 0:
			main_end = b["end"]
	var pm := ORDER.find(main_end)
	var above_in := -1          # innermost used endpoint above the main bolt's
	var below_in := ORDER.size() # innermost used endpoint below it
	for e in used:
		var i := ORDER.find(e)
		if i < pm:
			above_in = maxi(above_in, i)
		elif i > pm:
			below_in = mini(below_in, i)
	var still_to_come := MAX_BOLTS - index - 1
	var ok := []
	var feasible := []
	for i in range(ORDER.size()):
		var e : String = ORDER[i]
		if used.has(e):
			continue
		var left := -1
		if i < pm and i > above_in:
			left = (pm - i - 1) + (below_in - pm - 1)
		elif i > pm and i < below_in:
			left = (pm - above_in - 1) + (i - pm - 1)
		if left < 0:
			continue
		feasible.append(e)
		if left >= still_to_come:
			ok.append(e)
	if not ok.is_empty():
		return ok[_rng.randi() % ok.size()]
	if not feasible.is_empty():
		return feasible[_rng.randi() % feasible.size()]
	for e in ORDER:
		if not used.has(e):
			return e
	return "o7"

func _process(delta : float) -> void:
	_t += delta
	var target := float(_count) / float(MAX_BOLTS)
	_intensity = move_toward(_intensity, target, delta * 1.6)
	var keep := []
	for b in _bolts:
		if b["dying"] < 0.0 or _t - b["dying"] < FADE_TIME:
			keep.append(b)
	_bolts = keep
	# Crackling sparks from three bolts up, many at five.
	var live := _live_bolts().size()
	if live >= 3 and slot_rects.size() >= 7:
		_spark_acc += delta * (6.0 if live < 5 else 26.0) * (live - 2)
		while _spark_acc >= 1.0:
			_spark_acc -= 1.0
			_spawn_spark()
	for s in _sparks:
		s["life"] -= delta
	_sparks = _sparks.filter(func(s): return s["life"] > 0.0)
	visible = not _bolts.is_empty() or not _sparks.is_empty()
	queue_redraw()

func _slot(i : int) -> Rect2:
	if i < 0 or i >= slot_rects.size():
		return Rect2()
	return slot_rects[i]

func _top() -> float:
	return _slot(0).position.y + INSET

func _bottom() -> float:
	return _slot(0).end.y - INSET

func _end_point(e : String) -> Vector2:
	match e:
		"t6": return Vector2(_slot(5).get_center().x, _top())
		"t7": return Vector2(_slot(6).get_center().x, _top())
		"b6": return Vector2(_slot(5).get_center().x, _bottom())
		"b7": return Vector2(_slot(6).get_center().x, _bottom())
	# The 7th space's outer edge: the side away from the first space.
	var r := _slot(6)
	var outer := r.end.x - INSET if r.get_center().x > _slot(0).get_center().x else r.position.x + INSET
	return Vector2(outer, r.get_center().y)

# A jagged path from a to b: small sideways kinks (none at the ends), kept inside the boxes.
func _zigzag(a : Vector2, b : Vector2, amp : float, seed_n : int, clamp_y : bool = true) -> PackedVector2Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed_n
	var pts := PackedVector2Array()
	var dir := b - a
	var n := Vector2(-dir.y, dir.x).normalized()
	var segs := maxi(3, int(SEGMENTS * clampf(dir.length() / 200.0, 0.4, 1.0)))
	for i in range(segs + 1):
		var f := float(i) / segs
		var p := a + dir * f
		if i > 0 and i < segs:
			p += n * r.randf_range(-amp, amp) * sin(f * PI)
		if clamp_y:
			p.y = clampf(p.y, _top(), _bottom())
		pts.append(p)
	return pts

# The point of a polyline at a given x (where a branch splits off the main bolt).
func _point_at_x(pts : PackedVector2Array, x : float) -> Vector2:
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		if (a.x - x) * (b.x - x) <= 0.0 and a.x != b.x:
			return a.lerp(b, (x - a.x) / (b.x - a.x))
	return pts[0]

func _cut(pts : PackedVector2Array, frac : float) -> PackedVector2Array:
	if frac >= 1.0:
		return pts
	var total := 0.0
	for i in range(pts.size() - 1):
		total += pts[i].distance_to(pts[i + 1])
	var want := total * frac
	var out := PackedVector2Array([pts[0]])
	var run := 0.0
	for i in range(pts.size() - 1):
		var l := pts[i].distance_to(pts[i + 1])
		if run + l >= want:
			out.append(pts[i].lerp(pts[i + 1], (want - run) / maxf(l, 0.001)))
			return out
		run += l
		out.append(pts[i + 1])
	return out

func _spawn_spark() -> void:
	var live := _live_bolts()
	if live.is_empty():
		return
	var b = live[_rng.randi() % live.size()]
	var path := _bolt_path(b)
	if path.size() < 2:
		return
	var i := _rng.randi() % (path.size() - 1)
	var p := path[i].lerp(path[i + 1], _rng.randf())
	var life := _rng.randf_range(0.06, 0.16)
	_sparks.append({"p": p, "dir": Vector2.RIGHT.rotated(_rng.randf() * TAU),
			"len": _rng.randf_range(5.0, 11.0), "life": life, "max": life, "seed": _rng.randi()})

func _main_path() -> PackedVector2Array:
	for b in _bolts:
		if b["start_slot"] == 0:
			return _bolt_path(b, false)
	# No main bolt (it is fading after the others): branches start on the straight line.
	return PackedVector2Array([_slot(0).get_center(), _slot(6).get_center()])

# Each endpoint has its own lane across the strip, in ORDER from top to bottom. A bolt moves into
# its lane right after it starts (the main bolt within the first space, a branch within half a
# space of where it splits off), runs along it, and turns to its edge only at the end. Branches
# that split off later always end between earlier ones and the main bolt (_pick_endpoint), so
# their lanes lie between those bolts' lanes and nothing ever crosses.
func _lane_y(e : String) -> float:
	var i := ORDER.find(e)
	return lerpf(_top(), _bottom(), (i + 0.5) / ORDER.size())

func _bolt_path(b : Dictionary, cut : bool = true) -> PackedVector2Array:
	var slot_w := absf(_slot(1).get_center().x - _slot(0).get_center().x)
	var dirx := signf(_slot(6).get_center().x - _slot(0).get_center().x)
	var e : String = b["end"]
	var start : Vector2
	if b["start_slot"] == 0:
		start = _slot(0).get_center() # the center of the G
	else:
		start = _point_at_x(_main_path(), _slot(b["start_slot"]).get_center().x)
	var end := _end_point(e)
	var lane := _lane_y(e)
	var a := Vector2(start.x + dirx * slot_w * 0.5, lane)
	var turn_x := end.x if e == "o7" else end.x - dirx * slot_w * 0.45
	var bpt := Vector2(turn_x, lane)
	# Kinks stay well within half the gap between lanes.
	var amp := (_bottom() - _top()) / ORDER.size() * 0.3
	var r := RandomNumberGenerator.new()
	r.seed = int(b["seed"])
	var pts := PackedVector2Array([start])
	_kinked(pts, start, a, 2, amp * 0.6, r)
	var run := maxi(2, int(absf(bpt.x - a.x) / maxf(slot_w * 0.3, 1.0)))
	_kinked(pts, a, bpt, run, amp, r)
	if bpt != end:
		_kinked(pts, bpt, end, 2, amp * 0.6, r)
	if cut:
		pts = _cut(pts, clampf((_t - b["born"]) / STREAK_TIME, 0.0, 1.0))
	return pts

# Appends the points from a (exclusive) to b, with n segments and vertical kinks of up to amp
# at the inner points.
func _kinked(pts : PackedVector2Array, a : Vector2, b : Vector2, n : int, amp : float, r : RandomNumberGenerator) -> void:
	for i in range(1, n + 1):
		var p := a.lerp(b, float(i) / n)
		if i < n:
			p.y += r.randf_range(-amp, amp)
		p.y = clampf(p.y, _top(), _bottom())
		pts.append(p)

func _draw() -> void:
	if slot_rects.size() < 7:
		return
	var k := _intensity # 0..1 (one bolt = 0.2, five = 1.0); brightness only, never width
	var pulse := 0.5 + 0.5 * sin(_t * lerpf(4.0, 14.0, k))
	var hot := color.lerp(Color.WHITE, 0.2 + 0.25 * k)
	var core := color.lerp(Color.WHITE, 0.55 + 0.3 * k)
	var plasma : float = clampf((k - 0.75) / 0.25, 0.0, 1.0) # only near five bolts
	for b in _bolts:
		var pts := _bolt_path(b)
		if pts.size() < 2:
			continue
		var a := 1.0
		if b["dying"] >= 0.0:
			a = 1.0 - clampf((_t - b["dying"]) / FADE_TIME, 0.0, 1.0)
		# Plasma: a halo of the player's color radiating from the bolt, breathing in brightness.
		if plasma > 0.0:
			draw_polyline(pts, Color(color, 0.16 * a * plasma * (0.5 + 0.5 * pulse)), 12.0, true)
			draw_polyline(pts, Color(color.lerp(Color(1, 0.55, 1), 0.3), 0.32 * a * plasma * (0.7 + 0.3 * pulse)), 6.0, true)
		# A dark backing (so the bolt reads on the light boxes), the glow in the player's color,
		# then the hot core.
		draw_polyline(pts, Color(0, 0, 0, (0.35 + 0.15 * k) * a * (1.0 - 0.6 * plasma)), 3.0, true)
		draw_polyline(pts, Color(color, (0.4 + 0.4 * k) * a), 2.6, true)
		draw_polyline(pts, Color(hot, (0.6 + 0.4 * k) * a), 1.5, true)
		draw_polyline(pts, Color(core.lerp(Color.WHITE, 0.6 * plasma * pulse), (0.6 + 0.4 * k) * a), 0.8, true)
	# Crackle.
	for s in _sparks:
		var f : float = s["life"] / s["max"]
		var end : Vector2 = s["p"] + s["dir"] * s["len"]
		var arc := _zigzag(s["p"], end, s["len"] * 0.35, int(s["seed"]))
		draw_polyline(arc, Color(color, 0.8 * f), 2.0, true)
		draw_polyline(arc, Color(core, 0.95 * f), 0.8, true)
