extends Node
# Phone layout: stages a strike so the character animations stay in clear view.
#
#  * Strike cards are set face down and kept out of sight (see Game._on_strike_started): instead
#    a "STRIKE" banner sweeps across the character sprites and stays there until the response is
#    chosen, with an EX / WILD SWING tag over the side of whoever struck that way.
#  * When both are set (Game._on_strike_reveal -> play_reveal): the banner leaves, then a metal
#    plate in two halves slides in over the hand area from both sides (curtains closing), each
#    half carrying one strike card, and the cards flip face up.
#  * While the plate is closed and a choice has to be made, the plate opens sideways and a small
#    metal tab with a picture of each strike card waits at each edge (tap one to close the plate
#    and look at the cards); it closes once the choice is done (see _slide).
#  * When the strike ends (Game._on_end_of_strike -> end_strike) the plate splits and slides
#    open, and the cards leave the screen with their halves (PhoneLayout._on_card_zone_flight),
#    revealing the hand again.

const CARD_W := 250.0
const CARD_H := 350.0
const PLATE_Z := 9
const CARDS_Z := 11
const SLIDE_TIME := 0.28
const SLIDE_IN := 0.3 # same speed as the plate opening (OPEN_TIME)
const OPEN_TIME := 0.3

var phone
var game
var plate : Control
var _left : Control
var _right : Control
var _active : bool = false
var _plate_ready : bool = false
var _up : bool = false
var _down_timer : float = 0.0
var _slide_tween : Tween
var _zone_home : Dictionary = {}
var _z_token : int = 0
var _break_until : float = 0.0
var _pending_open : bool = false

func setup(p, g) -> void:
	phone = p
	game = g

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0 * phone.ANIM_PACE # (animation-paced, see PhoneLayout)

func _pt(t : float) -> float:
	return t / phone.ANIM_PACE

# Seconds until the plate is gone and the hand is clear again (0 if nothing is pending).
# Ends the staging if it is still up.
func plate_wait() -> float:
	if _active:
		end_strike()
	return maxf(0.0, _break_until - _now())

func _striking() -> Node2D:
	return game.get_node("AllCards/Striking")

func _is_player_card(card) -> bool:
	return game.game_wrapper.does_card_belong_to_player(Enums.PlayerId.PlayerId_Player, card.card_id)

# Called when both strike cards are set. Returns how long the event should take (seconds).
func play_reveal() -> float:
	var cards : Array = _striking().get_children()
	if _pending_open:
		_do_open() # a new strike while the last plate is still waiting to open
	if _active:
		# Already staged (an extra attack...): just turn up whatever is still face down.
		for c in cards:
			if not c.is_front_showing():
				game.make_card_revealed(c)
		return 1.0
	if cards.is_empty():
		return 0.5
	_active = true
	_plate_ready = false
	_peak_cards = 0
	_up = false
	_z_token += 1
	_striking().z_index = CARDS_Z
	_set_discard_z(CARDS_Z)
	# The (hidden) cards wait off screen at the sides, ready to ride in on the plate.
	for c in cards:
		park_card(c)
	_cards_leave()
	var t := create_tween()
	var pre := 0.0
	if _banner != null and is_instance_valid(_banner):
		# The STRIKE banner has been up since the strike began: a beat to see the response's
		# tag (if any), then it leaves.
		t.tween_interval(BANNER_RESPONSE_HOLD)
		t.tween_callback(_dismiss_banner)
		t.tween_interval(BANNER_OUT + 0.05)
		pre = BANNER_RESPONSE_HOLD + BANNER_OUT + 0.05
	else:
		t.tween_callback(_show_banner)
		t.tween_interval(BANNER_TOTAL + 0.05) # the plate closes once the banner has gone
		pre = BANNER_TOTAL + 0.05
	t.tween_callback(_close_plate)
	t.tween_interval(SLIDE_IN + 0.15)
	t.tween_callback(_flip_cards)
	# (the revealed cards sit a moment before the strike goes on)
	return pre + SLIDE_IN + 0.15 + 0.4 + REVEAL_SIT

# How long the just-revealed strike cards sit before the strike's effects start.
const REVEAL_SIT := 0.35

var _peak_cards : int = 0
# Banners sit over the board, but under a focused card (a hand card is z 14, previews 40), so a
# card can be looked at while a banner is up.
const BANNER_Z := 12
const BANNER_RESPONSE_HOLD := 0.5
const BANNER_OUT := 0.22
# The banner: slides in (0.28s), holds, fades out (0.22s). Everything after it waits for
# BANNER_TOTAL, so changing the hold changes the whole timeline.
const BANNER_HOLD := 0.35
const BANNER_TOTAL := 0.28 + BANNER_HOLD + 0.22
const BANNER_IN := 0.28 # (the slide in: a boost's card starts its flight once the banner is up)

func _cards_leave() -> void:
	var w : float = phone.W
	for c in _striking().get_children():
		var p : Vector2 = c.card_features.position
		var x : float = -CARD_W * 1.3 if _is_player_card(c) else w + CARD_W * 1.3
		c.discard_to(Vector2(x, p.y), CardBase.CardState.CardState_InStrike)
		c.animation_length = 0.4

func _set_discard_z(z : int) -> void:
	for n in ["PlayerDiscards", "OpponentDiscards"]:
		var node = game.get_node_or_null("AllCards/" + n)
		if node != null:
			node.z_index = z

# ---- "STRIKE" banner ---------------------------------------------------------------

# The same banner for the opponent's other actions (PREPARE!, MOVE!...); returns its duration.
# `side`: the player the banner is about (0 you, 1 the opponent): its letters are in that player's
# color. -1: neither (the gold letters).
func show_action_banner(text : String, side : int = -1) -> float:
	# (shown right away, even over another banner: banners don't wait their turn)
	_show_action_banner_now(text, side, true)
	return BANNER_TOTAL

func _show_action_banner_now(text : String, side : int, claim_mini : bool) -> void:
	phone.action_banner_up = true # (the opponent's queued cards may start)
	phone.current_action_banner = text
	var m := _claim_mini() if claim_mini else null
	if m != null:
		_morph_to_banner(m, text, true, side)
	else:
		_show_banner(text, side)


# Banner letters: [fill, outline]. A player's banner is lettered in that player's color (a light
# shade of it, with a deep shade of it for the outline); otherwise gold on dark red.
func _banner_colors(side : int) -> Array:
	if side < 0:
		return [Color(1.0, 0.86, 0.25), Color(0.55, 0.05, 0.02)]
	var c : Color = phone._side_color(side == 0)
	return [c.lightened(0.3), c.darkened(0.72)]

func _color_banner_label(lab : Label, side : int) -> void:
	if lab == null:
		return
	var cols := _banner_colors(side)
	lab.add_theme_color_override("font_color", cols[0])
	lab.add_theme_color_override("font_outline_color", cols[1])

func _show_banner(text : String = "STRIKE", side : int = -1) -> void:
	var b := _make_banner(text, 1.0, side)
	var t := b.create_tween()
	t.tween_property(b, "position:x", 0.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(BANNER_HOLD)
	t.tween_callback(func(): _leave_when_ready(b))

# After its hold, a banner stays up while a card is still on its way to the screen center under
# it (a boost being played: PhoneLayout._fly_via_center), then fades out.
func _leave_when_ready(b : Control) -> void:
	var waited := 0.0
	while is_instance_valid(b) and waited < 10.0 and phone.center_cards_arriving():
		await get_tree().create_timer(_pt(0.05)).timeout
		waited += 0.05
	phone.action_banner_up = false
	if not is_instance_valid(b):
		return
	var t := b.create_tween()
	# (the two fades run together)
	t.tween_property(b, "modulate:a", 0.0, 0.22)
	t.parallel().tween_property(b, "scale:y", 0.1, 0.22)
	t.tween_callback(b.queue_free)

# ---- The STRIKE banner held while the response is chosen ---------------------------------
var _banner : Control = null
var _banner_tags : Dictionary = {} # "side|kind" -> tag node

# A strike card has been set (Game._on_strike_started), before the reveal: the card stays out of
# sight, and the STRIKE banner comes in (once) and stays, tagged EX / WILD SWING over the side
# of whoever struck that way.
func card_set(card, is_player : bool, is_ex : bool, is_wild : bool) -> void:
	if _active:
		return # (mid-strike: a replacement wild swing etc. is handled by the staged strike)
	park_card(card)
	if _banner == null or not is_instance_valid(_banner):
		_banner_tags = {}
		var m := _claim_mini()
		if m != null:
			# Confirmed in the island: the small STRIKE banner grows into the held one.
			_banner = m
			_morph_to_banner(m, "STRIKE", false, 0 if is_player else 1)
		else:
			# (in the color of whoever struck first)
			_banner = _make_banner("STRIKE", 1.0, 0 if is_player else 1)
			_banner.create_tween().tween_property(_banner, "position:x", 0.0, 0.28) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_ex:
		_add_banner_tag(is_player, "EX")
	if is_wild:
		_add_banner_tag(is_player, "WILD SWING")

# The opponent's strike card is face up (set face up, or turned up by an effect while the STRIKE
# banner is held): the banner names it, "STRIKE (Gun Flame)".
func name_opponent_strike(card) -> void:
	if card == null or not is_instance_valid(card) or _banner == null or not is_instance_valid(_banner):
		return
	var nm := str(card.card_attack_name).strip_edges() if card.card_attack_name != null else ""
	if nm == "":
		return
	var lab := _banner.get_child(1) as Label
	if lab == null:
		return
	var text := "STRIKE (%s)" % nm
	if lab.text == text:
		return
	lab.text = text
	# (shrunk to fit across the screen)
	var f : Font = lab.get_theme_font("font")
	var fs : int = lab.get_theme_font_size("font_size")
	var w : float = phone.W - 40.0
	while fs > 30 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
		fs -= 4
	lab.add_theme_font_size_override("font_size", fs)
	lab.add_theme_constant_override("outline_size", int(fs * 0.12))

# Keeps a strike card out of sight until the plate brings it in.
func park_card(card) -> void:
	if card.has_meta("phone_parked"):
		return
	card.set_meta("phone_parked", true)
	card.card_features.visible = false
	card.focus_feature.get_node("Focus").mouse_filter = Control.MOUSE_FILTER_IGNORE

func _unpark(card) -> void:
	if not card.has_meta("phone_parked"):
		return
	card.remove_meta("phone_parked")
	if card.has_meta("ex_hidden"):
		return # (the EX copy stays hidden behind the visible card)
	card.card_features.visible = true
	card.focus_feature.get_node("Focus").mouse_filter = Control.MOUSE_FILTER_STOP

func _add_banner_tag(is_player : bool, kind : String) -> void:
	var key := "%s|%s" % [is_player, kind]
	if _banner == null or not is_instance_valid(_banner) or _banner_tags.has(key):
		return
	var w : float = phone.W
	var tag := PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	var wild := kind == "WILD SWING"
	sb.bg_color = Color(0.42, 0.12, 0.62) if wild else Color(0.85, 0.55, 0.05)
	sb.border_color = Color(1, 1, 1)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 6
	tag.add_theme_stylebox_override("panel", sb)
	var lab := Label.new()
	lab.text = kind
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fv := FontVariation.new()
	fv.base_font = lab.get_theme_default_font()
	fv.variation_embolden = 1.0
	lab.add_theme_font_override("font", fv)
	lab.add_theme_font_size_override("font_size", 34)
	lab.add_theme_color_override("font_color", Color(1, 1, 1))
	lab.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lab.add_theme_constant_override("outline_size", 8)
	tag.add_child(lab)
	_banner.add_child(tag)
	tag.reset_size()
	# Over that character's side, straddling the banner's top edge (clear of the big letters).
	var cx : float = w * (0.25 if is_player else 0.75)
	tag.position = Vector2(cx - tag.size.x / 2.0, -tag.size.y * 0.55)
	tag.pivot_offset = tag.size / 2.0
	tag.scale = Vector2(0.2, 0.2)
	tag.create_tween().tween_property(tag, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tags[key] = tag

func _dismiss_banner() -> void:
	if _banner == null or not is_instance_valid(_banner):
		_banner = null
		return
	var b := _banner
	_banner = null
	_banner_tags = {}
	var t := b.create_tween()
	t.tween_property(b, "modulate:a", 0.0, BANNER_OUT)
	t.parallel().tween_property(b, "scale:y", 0.1, BANNER_OUT)
	t.tween_callback(b.queue_free)

# ---- Small banner while an action waits for its confirmation in the island ---------------
var _mini : Control = null
var _mini_text : String = ""
var _mini_side : int = -1

# `side`: the player the action is about (its letters in their color), as for show_action_banner.
func set_mini_banner(text : String, side : int = -1) -> void:
	if text == _mini_text and (text == "" or side == _mini_side):
		return
	if text != "" and _mini_text != "" and _mini != null and is_instance_valid(_mini):
		# Same banner, new text (e.g. CHANGE CARDS 1 -> 2): update it with a little pop.
		_mini_text = text
		_mini_side = side
		var lab := _mini.get_child(1) as Label
		if lab != null:
			lab.text = text
			_color_banner_label(lab, side)
		if text.begins_with("WAITING"):
			return # (just its dots moving on: no pop)
		_mini.scale = Vector2(1.08, 1.08)
		_mini.create_tween().tween_property(_mini, "scale", Vector2.ONE, 0.15)
		return
	var was_text := _mini_text
	_mini_text = text
	_mini_side = side
	if _mini != null and is_instance_valid(_mini):
		var old := _mini
		_mini = null
		if text == "" and (was_text.begins_with("PAY ") or was_text.begins_with("VALIDATE")):
			# Paid (an Ultra's gauge): stays until the spent gauge has gone through the center.
			_hold_mini_for_cards(old)
		elif text == "":
			# Confirmed or declined? If the action's banner follows right away (confirmed), this
			# one grows into it; otherwise (declined) it fades after a short moment.
			_leaving_mini = old
			var token := old.get_instance_id()
			get_tree().create_timer(_pt(MINI_GRACE)).timeout.connect(func():
				if _leaving_mini != null and is_instance_valid(_leaving_mini) and _leaving_mini.get_instance_id() == token:
					_leaving_mini = null
					_fade_mini(old))
		else:
			_fade_mini(old)
	if text == "":
		return
	_mini = _make_banner(text, 0.5, side)
	_mini.position.x = (phone.W - _mini.size.x) / 2.0
	_mini.modulate.a = 0.0
	_mini.scale = Vector2(0.7, 0.7)
	var t2 := _mini.create_tween().set_parallel(true)
	t2.tween_property(_mini, "modulate:a", 1.0, 0.18)
	t2.tween_property(_mini, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

const MINI_GRACE := 0.6

# A payment banner (PAY 2/2 GAUGE) after it is confirmed: up while the paid cards are on their way
# (they start a moment later), then it fades. (Declined: they never come, and it fades.)
func _hold_mini_for_cards(m : Control) -> void:
	phone.expect_center_cards(1.2)
	phone.payment_banner_up = true # (the cards needn't wait for an action banner)
	await get_tree().create_timer(_pt(0.1)).timeout
	var waited := 0.0
	while is_instance_valid(m) and waited < 8.0 and phone.center_cards_arriving():
		await get_tree().create_timer(_pt(0.05)).timeout
		waited += 0.05
	phone.payment_banner_up = false
	_fade_mini(m)

# True while the STRIKE banner is held for the strike's response (or the strike is staged).
func strike_banner_held() -> bool:
	return _active or (_banner != null and is_instance_valid(_banner))
var _leaving_mini : Control = null

func _fade_mini(m : Control) -> void:
	if m == null or not is_instance_valid(m):
		return
	var t := m.create_tween()
	t.tween_property(m, "modulate:a", 0.0, 0.15)
	t.parallel().tween_property(m, "scale", Vector2(0.8, 0.8), 0.15)
	t.tween_callback(m.queue_free)

# The confirmation banner, if one is up or just left: taken over by the action's banner.
func _claim_mini() -> Control:
	for m in [_leaving_mini, _mini]:
		if m != null and is_instance_valid(m):
			if m == _mini:
				_mini = null
				_mini_text = ""
			_leaving_mini = null
			return m
	return null

# The confirmed action: its small banner smoothly grows into the full banner (across the
# screen, big letters), holds, then fades out like any action banner.
func _morph_to_banner(m : Control, text : String, then_leave : bool = true, side : int = -1) -> void:
	var w : float = phone.W
	var bh := 190.0
	var cy : float = phone.stage_y + (phone.stage_h - phone.band_h) / 2.0
	var lab := m.get_child(1) as Label
	var bg := m.get_child(0) as Panel
	if lab != null:
		lab.text = text
		_color_banner_label(lab, side)
	m.modulate.a = 1.0
	m.scale = Vector2.ONE
	var from_fs : int = lab.get_theme_font_size("font_size") if lab != null else 60
	var to_fs := 150
	if lab != null:
		var f : Font = lab.get_theme_font("font")
		while to_fs > 40 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, to_fs).x > w - 40.0:
			to_fs -= 6
	var sb : StyleBoxFlat = null
	if bg != null:
		sb = bg.get_theme_stylebox("panel") as StyleBoxFlat
	var t := m.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(m, "position", Vector2(0.0, cy - bh / 2.0), 0.28)
	t.tween_property(m, "size", Vector2(w, bh), 0.28)
	if lab != null:
		t.tween_method(func(v : float):
			lab.add_theme_font_size_override("font_size", int(v))
			lab.add_theme_constant_override("outline_size", int(v * 0.12)), float(from_fs), float(to_fs), 0.28)
	if sb != null:
		# The rounded box becomes a full-width band (no side borders or corners).
		t.tween_method(func(v : float):
			sb.set_corner_radius_all(int(v))
			sb.border_width_left = int(v * 0.25)
			sb.border_width_right = int(v * 0.25), 16.0, 0.0, 0.28)
		t.tween_property(sb, "border_width_top", 6, 0.28)
		t.tween_property(sb, "border_width_bottom", 6, 0.28)
	t.chain().tween_callback(func(): m.pivot_offset = Vector2(w / 2.0, bh / 2.0))
	if not then_leave:
		return # (the held STRIKE banner: it stays until the response is chosen)
	t.chain().tween_interval(BANNER_HOLD)
	t.chain().tween_callback(func(): _leave_when_ready(m))

# The banner itself (off screen to the left). `k` scales it down (the mini banner).
func _make_banner(text : String, k : float = 1.0, side : int = -1) -> Control:
	var w : float = phone.W * (1.0 if k >= 1.0 else 0.72)
	var cy : float = phone.stage_y + (phone.stage_h - phone.band_h) / 2.0
	var bh := 190.0 * k
	var b := Control.new()
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.size = Vector2(w, bh)
	b.position = Vector2(-w, cy - bh / 2.0)
	b.z_index = BANNER_Z
	var bg := Panel.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.02, 0.02, 0.9)
	sb.border_color = Color(1.0, 0.72, 0.18)
	sb.border_width_top = maxi(3, int(6 * k))
	sb.border_width_bottom = maxi(3, int(6 * k))
	if k < 1.0:
		# The mini banner is a rounded box, not a full-width band.
		sb.set_border_width_all(maxi(3, int(6 * k)))
		sb.set_corner_radius_all(16)
	bg.add_theme_stylebox_override("panel", sb)
	b.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var lab := Label.new()
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.text = text
	var fv := FontVariation.new()
	fv.base_font = lab.get_theme_default_font()
	fv.variation_embolden = 1.0
	lab.add_theme_font_override("font", fv)
	# Longer words ("CHANGE CARDS!") shrink to fit across the screen.
	var fsz := int(150 * k)
	while fsz > 24 and fv.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x > w - 40.0:
		fsz -= 4
	lab.add_theme_font_size_override("font_size", fsz)
	_color_banner_label(lab, side)
	lab.add_theme_constant_override("outline_size", int(18 * k))
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(lab)
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.pivot_offset = Vector2(w / 2.0, bh / 2.0)
	game.add_child(b)
	return b

# ---- The metal plate (two halves) ----------------------------------------------------

func _make_half(w : float, h : float) -> Control:
	var half := Control.new()
	half.size = Vector2(w, h)
	half.mouse_filter = Control.MOUSE_FILTER_STOP
	var fill : Control = load("res://scenes/game/metal_bar.gd").new()
	fill.brushed = true
	half.add_child(fill)
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fill.set_colors(Color(0.64, 0.67, 0.72), Color(0.36, 0.38, 0.44))
	var frame : Control = load("res://scenes/game/metal_bar.gd").new()
	frame.screws_only = true
	frame.edge = 14.0
	frame.screw_radius = 8.0
	frame.screw_inset = 22.0
	half.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return half

func _make_plate() -> void:
	var w : float = phone.W
	var h : float = phone.hand_h
	plate = Control.new()
	plate.name = "StrikePlate"
	plate.size = Vector2(w, h)
	plate.position = Vector2(0.0, phone.hand_y)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.z_index = PLATE_Z
	_left = _make_half(w / 2.0, h)
	_right = _make_half(w / 2.0, h)
	_left.position = Vector2(-w / 2.0 - 20.0, 0.0)
	_right.position = Vector2(w + 20.0, 0.0)
	_peek = false
	for half in [_left, _right]:
		half.gui_input.connect(_on_plate_input)
	_add_pocket(_left, true)
	_add_pocket(_right, false)
	plate.add_child(_left)
	plate.add_child(_right)
	game.add_child(plate)
	# The island's 3rd / 4th choice buttons hang over the hand area: keep the island after the
	# plate in the scene tree so those buttons still take taps while the plate is closed.
	if phone.island_root != null and is_instance_valid(phone.island_root):
		game.move_child(phone.island_root, -1)

# The halves slide in from both sides (curtains closing), each with its strike card.
func _close_plate() -> void:
	_make_plate()
	var w : float = phone.W
	var t := plate.create_tween().set_parallel(true)
	t.tween_property(_left, "position:x", 0.0, SLIDE_IN).set_trans(Tween.TRANS_LINEAR)
	t.tween_property(_right, "position:x", w / 2.0, SLIDE_IN).set_trans(Tween.TRANS_LINEAR)
	t.chain().tween_callback(func(): _plate_ready = true)
	_zones_to_plate(true)
	var cy : float = phone.hand_y + phone.hand_h / 2.0
	var sides := {true: [], false: []}
	for c in _striking().get_children():
		_unpark(c)
		# The cards are off screen: bring them to the plate's height first, so they slide in
		# horizontally along with their half (not diagonally from above).
		c.set_card_and_focus(Vector2(c.card_features.position.x, cy), null, null)
		if c.has_meta("ex_hidden"):
			# The EX copy stays out of sight, tucked behind the visible card.
			var hx : float = w * (0.25 if _is_player_card(c) else 0.75)
			c.discard_to(Vector2(hx, cy), CardBase.CardState.CardState_InStrike)
			c.animation_length = SLIDE_IN
			continue
		sides[_is_player_card(c)].append(c)
	for side in [true, false]:
		var list : Array = sides[side]
		var cx : float = w * (0.25 if side else 0.75)
		for i in range(list.size()):
			var x : float = cx + (i - (list.size() - 1) / 2.0) * 110.0
			var c = list[i]
			c.discard_to(Vector2(x, cy), CardBase.CardState.CardState_InStrike)
			c.animation_length = SLIDE_IN

func _zones_to_plate(on : bool) -> void:
	for pair in [["PlayerStrike/StrikeZone", 0.25], ["OpponentStrike/StrikeZone", 0.75]]:
		var zone : Control = game.get_node_or_null(pair[0])
		if zone == null:
			continue
		if on:
			if not _zone_home.has(zone):
				_zone_home[zone] = zone.position
			var center := Vector2(phone.W * pair[1], phone.hand_y + phone.hand_h / 2.0)
			zone.position = center - zone.size * zone.scale / 2.0
		elif _zone_home.has(zone):
			zone.position = _zone_home[zone]
			_zone_home.erase(zone)

# EX strike: the second card is hidden; the remaining card carries the EX label.
func hide_ex_card(card) -> void:
	card.set_meta("ex_hidden", true)
	card.card_features.visible = false
	card.focus_feature.get_node("Focus").mouse_filter = Control.MOUSE_FILTER_IGNORE

# The hidden EX copy is discarded mid-strike (when costs are paid): show it again as it
# leaves, without ending the strike (the metal plate stays closed).
func release_ex_card(card) -> void:
	if card.has_meta("ex_hidden"):
		card.remove_meta("ex_hidden")
		card.card_features.visible = true
		card.focus_feature.get_node("Focus").mouse_filter = Control.MOUSE_FILTER_STOP

func _show_ex_cards() -> void:
	for c in _striking().get_children():
		if c.has_meta("ex_hidden"):
			c.remove_meta("ex_hidden")
			c.card_features.visible = true
			c.focus_feature.get_node("Focus").mouse_filter = Control.MOUSE_FILTER_STOP

func _flip_cards() -> void:
	# The opponent's last-action box names their attack as the cards turn face up.
	get_tree().create_timer(_pt(0.14)).timeout.connect(phone.release_last_action_hold)
	for c in _striking().get_children():
		var ft : Node2D = c.card_features
		var sx : float = ft.scale.x
		var tw := create_tween()
		tw.tween_property(ft, "scale:x", 0.0, 0.14)
		tw.tween_callback(func(): game.make_card_revealed(c))
		tw.tween_property(ft, "scale:x", sx, 0.14)
	# Once they're face up, the stat gems show the strike (and its cards' stats).
	get_tree().create_timer(_pt(0.3)).timeout.connect(phone.on_strike_cards_flipped)

# ---- Sliding up for hand selections --------------------------------------------------

func _wants_up() -> bool:
	# Any choice you have to make during the strike (a card, a payment, an effect option, a
	# space to move to...): the plates move up out of the way.
	if game.observer_mode:
		return false
	return game.ui_state in [game.UIState.UIState_SelectCards, game.UIState.UIState_MakeChoice,
			game.UIState.UIState_SelectArenaLocation]

func _process(delta : float) -> void:
	if not _active or not _plate_ready or plate == null:
		return
	var wants := _wants_up()
	if not wants:
		_peek = false # (the choice is made: next time the plates open again by themselves)
	if wants and not _peek:
		_down_timer = 0.0
		if not _up:
			_slide(true)
	elif _up:
		_down_timer += delta
		if _down_timer > 0.2 or _peek:
			_slide(false)

# A choice to make during the strike: the two halves of the plate open sideways (curtains) right
# off the screen, showing the hand, and a small metal tab slides in at each edge, centered on the
# hand area, holding a picture of that side's strike card (the cards themselves ride out with the
# halves). Tapping a tab closes the plate again to look at the cards (`_peek`): a tap on a strike
# card then shows it large, a tap elsewhere on the plate opens it again. When the choice is made
# the plate closes.
var _pocket_tween : Tween = null
const POCKET_IN_TIME := 0.5 # (slow enough to read as sliding in, not just appearing)
var _peek : bool = false

func _slide(up : bool) -> void:
	_up = up
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	var w : float = phone.W
	_slide_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not up:
		# Closing: first the pockets slide away off the screen edges (back onto their halves,
		# which wait off screen), showing "OPEN" once out of sight; then the halves close, the
		# pockets riding in with them.
		var any_out := false
		for half in [_left, _right]:
			var pk = half.get_node_or_null("Pocket") if half != null else null
			if pk == null or is_zero_approx(pk.position.x):
				continue
			any_out = true
			_slide_tween.tween_property(pk, "position:x", 0.0, SLIDE_TIME).set_ease(Tween.EASE_IN)
		if any_out:
			_slide_tween.chain().tween_callback(func():
				for half in [_left, _right]:
					var pk = half.get_node_or_null("Pocket") if half != null and is_instance_valid(half) else null
					if pk != null:
						pk.set_meta("open", false)
						var et = pk.get_node_or_null("Etch")
						if et != null:
							et.queue_redraw())
	var left_x : float = (-w / 2.0 - 20.0) if up else 0.0
	var right_x : float = (w + 20.0) if up else w / 2.0
	_slide_tween.tween_property(_left, "position:x", left_x, SLIDE_TIME)
	_slide_tween.tween_property(_right, "position:x", right_x, SLIDE_TIME)
	# Opening: the pockets leave with their halves, then, once the halves have receded, slide back
	# in from the screen edges to where they were, now carrying the attack names. (Closing: see the
	# top of this function.)
	if _pocket_tween != null and _pocket_tween.is_valid():
		_pocket_tween.kill()
	# (a sequence: the wait, then every pocket step together. set_parallel() would run the steps
	# alongside the wait instead, so each step after the first is joined with .parallel())
	_pocket_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pocket_tween.tween_interval(SLIDE_TIME)
	var pocket_steps := [0]
	for pair in [[_left, 0.0, left_x], [_right, w / 2.0, right_x]]:
		var half : Control = pair[0]
		var pocket = half.get_node_or_null("Pocket") if half != null else null
		if pocket == null:
			continue
		pocket.set_meta("name", _side_attack_name(half == _left))
		var etch = pocket.get_node_or_null("Etch")
		var set_open := func(v : bool):
			if is_instance_valid(pocket):
				pocket.set_meta("open", v)
				if etch != null and is_instance_valid(etch):
					etch.queue_redraw()
		# (its wording changes while it is out of sight)
		if up:
			_pocket_step(pocket_steps).tween_callback(set_open.bind(true))
		if up:
			_pocket_step(pocket_steps).tween_property(pocket, "position:x", float(pair[1]) - float(pair[2]), POCKET_IN_TIME)
		# (closing: already slid back onto its half above, it rides in with it)
	for c in _striking().get_children():
		if c.has_meta("ex_hidden"):
			continue
		# The cards ride out with their halves, on just past the screen edge, and back in when the
		# plate closes.
		if up and not c.has_meta("plate_home_x"):
			c.set_meta("plate_home_x", c.card_features.position.x)
		var home : float = float(c.get_meta("plate_home_x", c.card_features.position.x))
		var cw : float = CARD_W * c.card_features.scale.x
		var x : float = home
		if up:
			x = -cw / 2.0 - 30.0 if home < w / 2.0 else w + cw / 2.0 + 30.0 # (highlight included)
		else:
			c.remove_meta("plate_home_x")
		for f in [c.card_features, c.focus_feature]:
			_slide_tween.tween_property(f, "position:x", x, SLIDE_TIME)
		# While the plate is shut for a look during a choice, taps go to the plate (a tap on a card
		# shows it large there), not to the cards.
		c._set_preview_input_ignored(not up and _peek)

# The tabs (made once per strike): brushed metal, the strike card's picture inset in it.
# The pocket tween, set up for its next step: the first step follows the wait, the rest run
# alongside it (`count` is a one-element array, counting the steps added).
func _pocket_step(count : Array) -> Tween:
	count[0] += 1
	if count[0] == 1:
		return _pocket_tween
	return _pocket_tween.parallel()

func _on_plate_input(ev : InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or mb.pressed:
		return
	if not _active or not _plate_ready or plate == null or not _wants_up():
		return
	if _up:
		_peek = true # a tab tapped: shut the plate to look at the cards
		return
	if _peek:
		var pos : Vector2 = plate.get_global_mouse_position()
		for c in _striking().get_children():
			if c.has_meta("ex_hidden") or not c.visible:
				continue
			var sc : Vector2 = c.card_features.global_scale
			var r := Rect2(c.card_features.global_position - Vector2(CARD_W, CARD_H) * sc / 2.0, Vector2(CARD_W, CARD_H) * sc)
			if r.has_point(pos):
				phone.show_popout_preview(c.card_id, c)
				return
		# (the pocket's "OPEN" opens it again: _on_pocket_input)

# ---- The pockets: the cards sit in the plate like papers in a school folder ----------------------
# Each half carries a metal pocket along its bottom, from the screen edge to the middle, over the
# bottom of its strike card (well below the card's boost section): a rectangle whose inner edge is
# cut on a slope, from about 3/4 of the way in down to the bottom inner corner. It's brushed metal
# with screws like the plates, with "OPEN" and an arrow toward the screen edge etched into it;
# tapping it during a choice opens the plate (after a tab has closed it).
const POCKET_Z := 12 # over the strike cards (z 11), so they sit inside it
const POCKET_BOOST_TOP := 0.8 # the card's boost section starts at about this fraction of its height
const POCKET_HEIGHT := 0.5 # of the space from there to the plate's bottom

func _add_pocket(half : Control, is_left : bool) -> void:
	var hw : float = half.size.x
	var hh : float = half.size.y
	var ch : float = CARD_H * CardBase.phone_strike_scale.y
	var boost_top : float = hh / 2.0 - ch / 2.0 + ch * POCKET_BOOST_TOP
	var ph : float = (hh - boost_top) * POCKET_HEIGHT
	var pocket := Control.new()
	pocket.name = "Pocket"
	pocket.position = Vector2(0.0, hh - ph)
	pocket.size = Vector2(hw, ph)
	pocket.z_as_relative = false
	pocket.z_index = POCKET_Z
	pocket.mouse_filter = Control.MOUSE_FILTER_STOP
	pocket.set_meta("left", is_left)
	# The pocket's own drawing is its outline; it clips its metal (and etching) to it.
	pocket.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	pocket.draw.connect(func():
		pocket.draw_colored_polygon(_pocket_points(pocket.size.x, pocket.size.y, is_left), Color(0.36, 0.38, 0.44)))
	var fill : Control = load("res://scenes/game/metal_bar.gd").new()
	fill.brushed = true
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pocket.add_child(fill)
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A shade lighter than the plate, so it reads as a separate sheet laid on it.
	fill.set_colors(Color(0.72, 0.75, 0.8), Color(0.42, 0.44, 0.5))
	var etch := Control.new()
	etch.name = "Etch"
	etch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pocket.add_child(etch)
	etch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	etch.draw.connect(func(): _draw_pocket(etch, is_left, pocket))
	pocket.gui_input.connect(_on_pocket_input)
	half.add_child(pocket)

# The pocket's outline: the outer side full height, the top straight for 3/4 of the width, then the
# inner edge slopes down to the bottom inner corner.
func _pocket_points(pw : float, ph : float, is_left : bool) -> PackedVector2Array:
	var cut := pw * 0.75
	if is_left:
		return PackedVector2Array([Vector2(0, 0), Vector2(cut, 0), Vector2(pw, ph), Vector2(0, ph)])
	return PackedVector2Array([Vector2(pw - cut, 0), Vector2(pw, 0), Vector2(pw, ph), Vector2(0, ph)])

# On top of the metal: a bright lip along the top and the slope, a dark edge, the screws, and the
# etched "OPEN" with its arrow.
func _draw_pocket(ci : Control, is_left : bool, pocket : Control = null) -> void:
	var pw : float = ci.size.x
	var ph : float = ci.size.y
	if pw <= 0.0 or ph <= 0.0:
		return
	var shape := _pocket_points(pw, ph, is_left)
	var lip := PackedVector2Array([shape[0], shape[1], shape[2]]) if is_left else PackedVector2Array([shape[3], shape[0], shape[1]])
	ci.draw_polyline(lip, Color(0.18, 0.19, 0.22), 3.0, true)
	ci.draw_polyline(lip, Color(1, 1, 1, 0.7), 1.2, true)
	# Screws: two at the outer end, one near the start of the slope, one by the bottom inner point.
	var r := minf(5.0, ph * 0.14)
	var inset := r + 5.0
	var cut := pw * 0.75
	var pts : Array
	if is_left:
		pts = [Vector2(inset, inset), Vector2(inset, ph - inset), Vector2(cut - inset * 1.6, inset),
				Vector2(pw - (pw - cut) * (inset / ph) - inset * 2.6, ph - inset)]
	else:
		pts = [Vector2(pw - inset, inset), Vector2(pw - inset, ph - inset), Vector2(pw - cut + inset * 1.6, inset),
				Vector2((pw - cut) * (inset / ph) + inset * 2.6, ph - inset)]
	var angles := [0.5, 2.2, 1.1, 2.9]
	for k in range(pts.size()):
		_draw_screw(ci, pts[k], r, angles[k])
	# Closed: "OPEN" and an arrow toward the screen edge, etched (dark, with a light lip below),
	# centered in the straight part. Open: the attack name in capitals, with a small arrow pointing
	# in at the outer edge.
	var f : Font = ThemeDB.fallback_font
	var fs := int(clampf(ph * 0.5, 12.0, 30.0))
	if pocket != null and bool(pocket.get_meta("open", false)):
		_draw_pocket_name(ci, is_left, str(pocket.get_meta("name", "")).to_upper(), f, fs, pw, ph, cut, inset)
		return
	# Same layout as the name pocket: a triangle at the outer edge (here pointing out, toward the
	# screen edge), with "OPEN" centered between it and the screw by the slope.
	var txt := "OPEN"
	var cy := ph * 0.5
	var aw := ph * 0.3
	var hy := ph * 0.16
	var ax : float = inset * 2.0 if is_left else pw - inset * 2.0 # (clear of the outer screws)
	var tip := Vector2(ax, cy)
	var base_x : float = ax + aw if is_left else ax - aw
	var x_from : float = (ax + aw + 8.0) if is_left else (pw - cut + inset * 2.6)
	var x_to : float = (cut - inset * 2.6) if is_left else (ax - aw - 8.0)
	var room := maxf(x_to - x_from, 10.0)
	while fs > 10 and f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 1
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tx := x_from + maxf(0.0, (room - tw) / 2.0)
	var base_y := cy + (f.get_ascent(fs) - f.get_descent(fs)) / 2.0
	for pass_i in range(2):
		var off := Vector2(0, 1.2) if pass_i == 0 else Vector2.ZERO
		var col := Color(1, 1, 1, 0.55) if pass_i == 0 else Color(0.16, 0.17, 0.21)
		ci.draw_colored_polygon(PackedVector2Array([tip + off, Vector2(base_x, cy - hy) + off, Vector2(base_x, cy + hy) + off]), col)
		ci.draw_string(f, Vector2(tx, base_y) + off, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _draw_pocket_name(ci : Control, is_left : bool, txt : String, f : Font, fs0 : int,
		pw : float, ph : float, cut : float, inset : float) -> void:
	var cy := ph * 0.5
	# The arrow at the outer edge, pointing in.
	var aw := ph * 0.3
	var hy := ph * 0.16
	var ax : float = inset * 2.0 if is_left else pw - inset * 2.0 # (clear of the outer screws)
	var tip := Vector2(ax + aw, cy) if is_left else Vector2(ax - aw, cy)
	var base_x : float = ax
	# The name: between the arrow and the screw by the slope, shrunk to fit on one line.
	var x_from : float = (ax + aw + 8.0) if is_left else (pw - cut + inset * 2.6)
	var x_to : float = (cut - inset * 2.6) if is_left else (ax - aw - 8.0)
	var room := maxf(x_to - x_from, 10.0)
	# One line if it fits at a readable size; otherwise two lines (split between words as evenly as
	# possible), each shrunk to fit.
	var lines : Array[String] = [txt]
	var fs := fs0
	while fs > 13 and f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 1
	if f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		var words := txt.split(" ", false)
		var best := 1
		var best_w := INF
		for k in range(1, words.size()):
			var a1 := " ".join(words.slice(0, k))
			var a2 := " ".join(words.slice(k))
			var wmax := maxf(f.get_string_size(a1, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x, f.get_string_size(a2, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x)
			if wmax < best_w:
				best_w = wmax
				best = k
		if words.size() > 1:
			lines = [" ".join(words.slice(0, best)), " ".join(words.slice(best))]
		fs = mini(fs0, int((ph - 8.0) / 2.0 / 1.2))
		for ln in lines:
			while fs > 8 and f.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
				fs -= 1
	var lh := f.get_height(fs)
	var top_y := cy - lh * lines.size() / 2.0
	for pass_i in range(2):
		var off := Vector2(0, 1.2) if pass_i == 0 else Vector2.ZERO
		var col := Color(1, 1, 1, 0.55) if pass_i == 0 else Color(0.16, 0.17, 0.21)
		ci.draw_colored_polygon(PackedVector2Array([tip + off, Vector2(base_x, cy - hy) + off, Vector2(base_x, cy + hy) + off]), col)
		for li in range(lines.size()):
			var ln : String = lines[li]
			var tw := f.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var tx := x_from + maxf(0.0, (room - tw) / 2.0)
			var by := top_y + lh * li + f.get_ascent(fs)
			ci.draw_string(f, Vector2(tx, by) + off, ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

# The attack name(s) of a side's strike card(s), joined.
func _side_attack_name(player_side : bool) -> String:
	var names : Array[String] = []
	for c in _striking().get_children():
		if c.has_meta("ex_hidden") or _is_player_card(c) != player_side:
			continue
		var n := str(c.card_attack_name) if c.card_attack_name != null else ""
		if n != "" and not n in names:
			names.append(n)
	return " / ".join(names)

# A screw head like the plates' (metal_bar.gd).
func _draw_screw(ci : CanvasItem, c : Vector2, r : float, ang : float) -> void:
	ci.draw_circle(c + Vector2(0.8, 1.0), r + 0.8, Color(0, 0, 0, 0.45))
	ci.draw_circle(c, r + 0.5, Color(0.18, 0.19, 0.22))
	ci.draw_circle(c, r, Color(0.66, 0.68, 0.73))
	ci.draw_circle(c - Vector2(0.9, 0.9), r * 0.55, Color(0.88, 0.90, 0.94))
	var d := Vector2(cos(ang), sin(ang)) * (r - 0.6)
	ci.draw_line(c - d, c + d, Color(0.22, 0.23, 0.27), 1.4)

func _on_pocket_input(ev : InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or mb.pressed:
		return
	if not _active or not _plate_ready or plate == null or not _wants_up():
		return
	if _up:
		_peek = true # the plate is open: shut it to look at the cards
	else:
		_peek = false # opens the plate (the choice is still to be made)

# ---- End of the strike ---------------------------------------------------------------

# Game.reparent_to_zone: a strike card is being sent to a gauge / discard / sealed /
# overdrive area. That happens before the end-of-strike event, so the plate opens now.
func strike_card_sent_away() -> void:
	if _active and _plate_ready and plate != null:
		end_strike()

var ended_at_ms : int = -100000 # (when the last strike ended: its cards resolving afterwards slide off)

func end_strike() -> void:
	ended_at_ms = Time.get_ticks_msec()
	phone.strike_cleanup_started()
	_show_ex_cards() # (they are shown again as they head for the discard pile)
	_dismiss_banner()
	for c in _striking().get_children():
		_unpark(c)
	if not _active:
		return
	_active = false
	_plate_ready = false
	_zones_to_plate(false)
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	_striking().position.y = 0.0
	_up = false
	_peek = false
	for c in _striking().get_children():
		c.modulate.a = 1.0
		c._set_preview_input_ignored(false)
		if c.has_meta("plate_home_x"):
			c.remove_meta("plate_home_x")
	if plate == null:
		_break_until = 0.0
		_reset_z_later(1.5)
		return
	# The plate opens as the cards head for their gauge / discard areas.
	_do_open()

# The two halves split and slide open, revealing the hand area.
func _do_open() -> void:
	_pending_open = false
	if plate == null:
		_break_until = 0.0
		return
	var p : Control = plate
	var l : Control = _left
	var r : Control = _right
	plate = null
	_left = null
	_right = null
	_break_until = _now() + OPEN_TIME + 0.15
	for half in [l, r]:
		half.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w : float = phone.W
	var t := p.create_tween().set_parallel(true)
	t.tween_property(l, "position:x", -w / 2.0 - 20.0, OPEN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(r, "position:x", w + 20.0, OPEN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(p, "position:y", phone.hand_y, 0.2)
	t.chain().tween_callback(p.queue_free)
	# (the cards are still flying to their areas: keep them above the board a while)
	_reset_z_later(1.5)

func _reset_z_later(delay : float) -> void:
	var token := _z_token
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_callback(func():
		if token == _z_token and not _active:
			_striking().z_index = 0
			_set_discard_z(0))
