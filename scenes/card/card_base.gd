class_name CardBase
extends Node2D

@warning_ignore("unused_signal")
signal raised_card(card)
@warning_ignore("unused_signal")
signal lowered_card(card)
@warning_ignore("unused_signal")
signal clicked_card(card)

@onready var card_container = $CardFocusFeatures/CardContainer
@onready var card_back = $CardFocusFeatures/CardContainer/CardBack
@onready var card_front = $CardFocusFeatures/CardContainer/CardFront
@onready var fancy_card = $CardFocusFeatures/CardContainer/CardFront/FancyCard
@onready var backup_label = $CardFocusFeatures/CardContainer/CardFront/BackupLabel
@onready var backup_label_text = $CardFocusFeatures/CardContainer/CardFront/BackupLabel/CardNameText
@onready var backlight = $CardFocusFeatures/Backlight
@onready var stun_indicator = $CardFocusFeatures/StunIndicator
@onready var card_features = $CardFocusFeatures
@onready var focus_feature = $FocusFeatures
@onready var remaining_count_obj = $CardFocusFeatures/RemainingCount
@onready var remaining_count_label : Label = $CardFocusFeatures/RemainingCount/PanelContainer/MarginContainer/RemainingCountLabel
@onready var hand_icons_obj = $CardFocusFeatures/HandIcons
@onready var hand_icon_panel = $CardFocusFeatures/HandIcons/HandPanel
@onready var icon1 = $CardFocusFeatures/HandIcons/HandPanel/HandMargin/HandVBox/Row1/IconPanel1/Icon
@onready var icon2 = $CardFocusFeatures/HandIcons/HandPanel/HandMargin/HandVBox/Row1/IconPanel2/Icon
@onready var icon3 = $CardFocusFeatures/HandIcons/HandPanel/HandMargin/HandVBox/Row2/IconPanel1/Icon
@onready var icon4 = $CardFocusFeatures/HandIcons/HandPanel/HandMargin/HandVBox/Row2/IconPanel2/Icon
@onready var icon5 = $CardFocusFeatures/HandIcons/HandPanel/HandMargin/HandVBox/Row3/IconPanel1/Icon
@onready var icon6 = $CardFocusFeatures/HandIcons/HandPanel/HandMargin/HandVBox/Row3/IconPanel2/Icon
@onready var bonus_ex = $CardFocusFeatures/BonusEffects/BonusPanel/BonusMargins/HandVBox/ExLabel
@onready var bonus_wild = $CardFocusFeatures/BonusEffects/BonusPanel/BonusMargins/HandVBox/WildLabel
@onready var bonus_crit = $CardFocusFeatures/BonusEffects/BonusPanel/BonusMargins/HandVBox/CritLabel
@onready var bonus_infuse = $CardFocusFeatures/BonusEffects/BonusPanel/BonusMargins/HandVBox/InfuseLabel

const ActualCardSize = Vector2(250,350)
const HandCardScale = Vector2(0.7, 0.7)
const OpponentHandCardScale = Vector2(0.3, 0.3)
const FocusScale = Vector2(1.4, 1.4)
const ReferenceCardScale = Vector2(0.6, 0.6)
const StrikeCardScale = Vector2(0.4, 0.4)
const DiscardCardScale = Vector2(0.4, 0.4)
const HighlightColor = Color('#36fff3')
const GreyedOutColor = Color(0.5, 0.5, 0.5)
const NormalColor = Color(1, 1, 1)

# Phone (portrait) layout overrides, set by PhoneLayout.
static var phone_mode : bool = false
static var phone_strike_scale : Vector2 = Vector2(1.0, 1.0)
static var phone_discard_scale : Vector2 = Vector2(0.3, 0.3)
static var phone_focus_center : Vector2 = Vector2(360, 400)
static var phone_focus_scale : Vector2 = Vector2(2.0, 2.0)

static func get_hand_card_size() -> Vector2:
	return ActualCardSize * HandCardScale

static func get_opponent_hand_card_size() -> Vector2:
	return ActualCardSize * OpponentHandCardScale

enum CardState {
	CardState_Focusing,
	CardState_InDeck,
	CardState_InHand,
	CardState_InGauge,
	CardState_InBoost,
	CardState_InPopout,  # 5
	CardState_Offscreen,
	CardState_Discarding,
	CardState_Discarded,
	CardState_InStrike,
	CardState_DrawingToHand,
	CardState_Unfocusing,
}

const CharacterCardReferenceId = -2
const BuddyCardReferenceId = -3

var state : CardState = CardState.CardState_InDeck
var return_state : CardState = CardState.CardState_InDeck
var card_id : int = -1
var start_pos = 0
var target_pos = 0
var start_rotation = 0
var target_rotation = 0
var animation_time = 0
var original_scale = 1
var target_scale = 1
var animate_flip = false
var animation_length = 0
var manual_flip_needed = false
var skip_flip_when_drawing = false
var remaining_count = -1
var hand_icon_state = {}
var hide_count = false

var follow_mouse = false
var saved_hand_index = -1

var default_scale = Vector2(1, 1)
var resting_position
var resting_rotation
var resting_scale
var focus_pos
var focus_rot
var cancel_visible_on_front
var card_url_loaded_image
var card_url_loaded_cardback
var card_attack_name
var card_boost_name

var selected = false

var hand_texture : Texture2D
var handeye_texture : Texture2D
var question_texture : Texture2D
var questioneye_texture : Texture2D
var topdeck_texture : Texture2D

const DRAW_ANIMATION_LENGTH = 0.5
const FOCUS_ANIMATION_LENGTH = 0.1
# Phone: cards moving to a zone (discard pile, gauge, boost box, strike area...) take a little
# longer, and fly over everything else on the screen except the help screen and the menu.
const PHONE_ZONE_ANIMATION_LENGTH = 0.3
const PHONE_ZONE_FLIGHT_Z = 85 # (help screen: 90; hamburger menu: its own canvas layer)

# Called when the node enters the scene tree for the first time.
func _ready():
	flip_card_to_front(false)
	set_hover_visible(false)
	remaining_count_obj.visible = false
	remaining_count_label.text = ""
	hand_icons_obj.visible = false

	hand_texture = load("res://assets/icons/hand.png")
	question_texture = load("res://assets/icons/handquestion.png")

	handeye_texture = load("res://assets/icons/handeye.png")
	questioneye_texture = load("res://assets/icons/handeyequestion.png")

	topdeck_texture = load("res://assets/icons/topdeck.png")

func set_remaining_count(count : int):
	if hide_count:
		return
		
	remaining_count_obj.visible = true
	remaining_count = count
	if count == 0:
		remaining_count_label.text = "None"
		card_front.modulate = GreyedOutColor
	else:
		remaining_count_label.text = "%s Left" % count
		card_front.modulate = NormalColor

func get_remaining_count():
	return remaining_count

func update_hand_icons(known : int, questionable : int, on_topdeck : bool, player_hand : bool):
	hand_icon_state = {
		"known": known,
		"questionable": questionable,
		"on_topdeck": on_topdeck,
		"player_hand": player_hand
	}
	if known or questionable or on_topdeck:
		hand_icons_obj.visible = true
	else:
		hand_icons_obj.visible = false

	var icons : Array[TextureRect] = [icon1, icon2, icon3, icon4, icon5, icon6]
	var set_count = 0
	for i in range(known):
		icons[set_count].visible = true
		if player_hand:
			icons[set_count].texture = handeye_texture
		else:
			icons[set_count].texture = hand_texture
		set_count += 1
	for i in range(questionable):
		icons[set_count].visible = true
		if player_hand:
			icons[set_count].texture = questioneye_texture
		else:
			icons[set_count].texture = question_texture
		set_count += 1
	if on_topdeck:
		icons[set_count].visible = true
		icons[set_count].texture = topdeck_texture
		set_count += 1

	# Set the remaining icons to invisible.
	for i in range(set_count, 6):
		icons[i].visible = false

func update_hand_icons_from_state(icon_state):
	update_hand_icons(icon_state["known"], icon_state["questionable"], icon_state["on_topdeck"], icon_state["player_hand"])

func get_hand_icon_state():
	return hand_icon_state

func set_label(label : String):
	remaining_count_obj.visible = true
	remaining_count_label.text = label

func get_label():
	return remaining_count_label.text

func clear_label():
	remaining_count_obj.visible = false
	remaining_count_label.text = ""

func flip_card_to_front(front):
	if front:
		card_back.visible = false
		card_front.visible = true
	else:
		card_back.visible = true
		card_front.visible = false
	_update_badge_visibility()

# --- Special / ultra markers (phone layout) ---
# A bold coloured roman numeral (specials) or lower-case greek letter (ultras)
# in the top-left and top-right corners of the card. The value comes from the
# card's fixed position in its character's special/ultra list, so it never
# changes between matches. Hidden while the card is face down.
var badge_text : String = ""
var badge_color : Color = Color.WHITE

var badge_s6 : bool = false

func set_badge(text : String, color : Color, s6 : bool = false) -> void:
	badge_text = text
	badge_color = color
	badge_s6 = s6
	if text != "":
		var font : Font = load("res://scenes/game/badge_font.gd").make_font()
		# Positions are in card-local pixels (origin = card centre).
		var is_ultra : bool = text.unicode_at(0) >= 0x370
		var font_size := 23 if is_ultra else 36
		var outline := 5 if is_ultra else 8
		if not is_ultra:
			if text.length() == 2 or text.length() == 3:
				font_size = 29
			elif text.length() > 3:
				font_size = 23
		# Top corners (clear of the gauge cost diamond at the bottom-left).
		var anchor := Vector2(91.0, -144.0)
		# Season 6 ultras print their gauge cost in the top-left corner: tuck the left marker
		# in beside it (between the cost and the title).
		var left_pos := Vector2(-anchor.x, anchor.y)
		var right_pos := Vector2(anchor.x, anchor.y)
		if is_ultra and s6:
			# Lower-right corner of the cost square, mirrored on the other side.
			left_pos = Vector2(-70.0, -134.0)
			right_pos = Vector2(70.0, -134.0)
		for pair in [["BadgeLeft", left_pos],
				["BadgeRight", right_pos]]:
			var label := card_features.get_node_or_null(pair[0]) as Label
			if label == null:
				label = Label.new()
				label.name = pair[0]
				label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				label.size = Vector2(70, 56)
				card_features.add_child(label)
			label.position = pair[1] - label.size / 2.0
			label.text = text
			label.add_theme_font_override("font", font)
			label.add_theme_font_size_override("font_size", font_size)
			label.add_theme_color_override("font_color", color)
			label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
			label.add_theme_constant_override("outline_size", outline)
	_update_badge_visibility()

func _update_badge_visibility() -> void:
	if card_features == null:
		return
	var show_it : bool = badge_text != "" and card_front != null and card_front.visible
	for n in ["BadgeLeft", "BadgeRight"]:
		var label = card_features.get_node_or_null(n)
		if label != null:
			label.visible = show_it

func set_backlight_visible(backlight_visible):
	backlight.visible = backlight_visible

var _stun_badge = null

func set_stun(stun_visible):
	if not phone_mode:
		stun_indicator.visible = stun_visible
		return
	# Phone: an onyx STUNNED badge across the middle of the card instead of the red X.
	stun_indicator.visible = false
	if stun_visible:
		if _stun_badge == null or not is_instance_valid(_stun_badge):
			_stun_badge = load("res://scenes/game/stun_badge.gd").new()
			$CardFocusFeatures.add_child(_stun_badge)
			_stun_badge.size = Vector2(236, 64)
			_stun_badge.position = -_stun_badge.size / 2.0
		elif _stun_badge.visible and _stun_badge.modulate.a > 0.9:
			return
		_stun_badge.slam_in()
	elif _stun_badge != null and is_instance_valid(_stun_badge) and _stun_badge.visible:
		_stun_badge.fade_out()

func set_ex(ex_visible):
	bonus_ex.visible = ex_visible

func set_wild(wild_visible):
	bonus_wild.visible = wild_visible

func set_crit(crit_visible):
	bonus_crit.visible = crit_visible

func set_infuse(infuse_visible):
	bonus_infuse.visible = infuse_visible

func clear_bonuses():
	set_ex(false)
	set_wild(false)
	set_crit(false)
	set_infuse(false)

func is_front_showing():
	return not card_back.visible

func set_hover_visible(hover_visible):
	focus_feature.visible = hover_visible

func update_visibility():
	match state:
		CardState.CardState_InDeck, CardState.CardState_InGauge, CardState.CardState_InBoost, CardState.CardState_Offscreen:
			visible = false
		_:
			visible = true

	match state:
		CardState.CardState_InHand, CardState.CardState_InStrike, CardState.CardState_InPopout, CardState.CardState_Focusing:
			set_hover_visible(true)
		_:
			set_hover_visible(false)

func _physics_process(delta):
	update_visibility()
	delta *= phone_anim_pace # (phone: animations at their own pace, PhoneLayout.ANIM_PACE)

	match state:
		CardState.CardState_Focusing:
			if animation_time <= 1:
				card_features.position = start_pos.lerp(target_pos, animation_time)
				card_features.rotation_degrees = lerpf(start_rotation, target_rotation, animation_time)
				card_features.scale = original_scale.lerp(target_scale, animation_time)
				animation_time += delta / animation_length
			else:
				card_features.position = target_pos
				card_features.rotation_degrees = target_rotation
				card_features.scale = target_scale
				_end_focus_raise()
		CardState.CardState_Unfocusing:
			if animation_time <= 1:
				card_features.position = start_pos.lerp(target_pos, animation_time)
				card_features.rotation_degrees = lerpf(start_rotation, target_rotation, animation_time)
				card_features.scale = original_scale.lerp(target_scale, animation_time)
				animation_time += delta / animation_length
			else:
				card_features.position = target_pos
				card_features.rotation_degrees = target_rotation
				card_features.scale = target_scale
				_end_unfocus_raise()
				change_state(return_state)
		CardState.CardState_DrawingToHand: # animate from deck to hand
			if animation_time <= 1:
				var lerp_pos = start_pos.lerp(target_pos, animation_time)
				var lerp_rot = lerpf(start_rotation, target_rotation, animation_time)
				var lerp_sca = original_scale
				if animate_flip and not skip_flip_when_drawing:
					lerp_sca.x = original_scale.x * abs(1 - 2*animation_time)
				if animation_time >= 0.5 and not manual_flip_needed:
					if not skip_flip_when_drawing:
						flip_card_to_front(true)
				animation_time += delta / animation_length
				set_card_and_focus(lerp_pos, lerp_rot, lerp_sca)
			else:
				set_card_and_focus(target_pos, target_rotation, original_scale)
				change_state(CardState.CardState_InHand)
		CardState.CardState_Discarding:
			if animation_time <= 1:
				var lerp_pos = start_pos.lerp(target_pos, animation_time)
				var lerp_rot = lerpf(start_rotation, target_rotation, animation_time)
				var lerp_sca =  original_scale.lerp(target_scale, animation_time)
				set_card_and_focus(lerp_pos, lerp_rot, lerp_sca)
				animation_time += delta / animation_length
			else:
				set_card_and_focus(target_pos, target_rotation, target_scale)
				_end_zone_flight()
				change_state(return_state)

# Phone: a card being unfocused is drawn over everything (the highest z there is) until it is
# back in place.
const PHONE_UNFOCUS_Z := RenderingServer.CANVAS_ITEM_Z_MAX
static var phone_anim_pace : float = 1.0
var _unfocus_raised : bool = false

func _end_unfocus_raise() -> void:
	_raise_hand_for_anim(false)
	if _unfocus_raised:
		_unfocus_raised = false
		if not z_as_relative and z_index == PHONE_UNFOCUS_Z:
			z_as_relative = true
			z_index = 0

# Phone: while a hand card grows out of the hand or shrinks back into it, the whole hand is drawn
# over everything else (the highest z), the card keeping its place among the hand cards: those
# lying over it in the fan still cover it. Counted on the hand zone, as several cards can be
# animating at once.
var _hand_raise_zone : Node2D = null

func _raise_hand_for_anim(on : bool) -> void:
	if on:
		if _hand_raise_zone != null:
			return
		var zone = get_parent()
		if not zone is Node2D:
			return
		var n : int = int(zone.get_meta("phone_anim_raise", 0))
		if n == 0:
			zone.set_meta("phone_raise_orig", [zone.z_as_relative, zone.z_index])
			zone.z_as_relative = false
			zone.z_index = PHONE_UNFOCUS_Z
		zone.set_meta("phone_anim_raise", n + 1)
		_hand_raise_zone = zone
	else:
		var zone := _hand_raise_zone
		_hand_raise_zone = null
		if zone == null or not is_instance_valid(zone):
			return
		var n : int = int(zone.get_meta("phone_anim_raise", 1)) - 1
		zone.set_meta("phone_anim_raise", maxi(n, 0))
		if n <= 0 and zone.has_meta("phone_raise_orig"):
			var orig : Array = zone.get_meta("phone_raise_orig")
			zone.z_as_relative = orig[0]
			zone.z_index = orig[1]
			zone.remove_meta("phone_raise_orig")

# A focused hand card in place: back to its normal focus level (z 14), the hand to its own.
func _end_focus_raise() -> void:
	if _hand_raise_zone != null:
		_raise_hand_for_anim(false)
		if phone_mode and z_as_relative and z_index == 0:
			z_index = 14

# Phone: back to its normal drawing order once it has landed.
func _end_zone_flight() -> void:
	if has_meta("phone_center_hold"):
		return # (stopping at the screen center on its way to a zone: stays raised)
	if not z_as_relative:
		z_as_relative = true
		z_index = 0

func position_card_in_hand(dst_pos, dst_rot):
	if state == CardState.CardState_DrawingToHand:
		target_pos = dst_pos
		target_rotation = dst_rot
	else:
		change_state(CardState.CardState_DrawingToHand)

		animate_flip = not manual_flip_needed and not is_front_showing()
		original_scale = card_features.scale
		start_pos = card_features.position
		target_pos = dst_pos
		start_rotation = card_features.rotation_degrees
		target_rotation = dst_rot
		animation_time = 0
		animation_length = DRAW_ANIMATION_LENGTH

		set_card_and_focus(start_pos, start_rotation, original_scale)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func initialize_card(id, url_loaded_image, url_loaded_cardback, is_opponent: bool, card_name, boost_name):
	card_id = id
	var starting_scale = HandCardScale
	if is_opponent:
		starting_scale = OpponentHandCardScale
	default_scale = starting_scale
	resting_scale = starting_scale
	card_features.scale = starting_scale
	focus_feature.scale = starting_scale

	card_url_loaded_image = url_loaded_image
	card_url_loaded_cardback = url_loaded_cardback
	card_attack_name = card_name
	card_boost_name = boost_name

	var target_card_node = fancy_card
	if url_loaded_image:
		fancy_card.texture = url_loaded_image
	else:
		backup_label_text.text = "[center]Card: " + card_name + "\nBoost: " + boost_name + "[/center]"
		target_card_node = backup_label

	target_card_node.visible = true
	if url_loaded_cardback:
		card_back.texture = url_loaded_cardback

func initialize_simple(id, url_loaded_image, url_loaded_cardback, card_name, boost_name):
	card_id = id
	var starting_scale = HandCardScale
	default_scale = starting_scale
	resting_scale = starting_scale
	card_features.scale = starting_scale
	focus_feature.scale = starting_scale

	card_url_loaded_image = url_loaded_image
	card_url_loaded_cardback = url_loaded_cardback
	card_attack_name = card_name
	card_boost_name = boost_name

	var target_card_node = fancy_card
	if url_loaded_image:
		fancy_card.texture = url_loaded_image
	else:
		backup_label_text.text = "[center]Card: " + card_name + "\nBoost: " + boost_name + "[/center]"
		target_card_node = backup_label

	target_card_node.visible = true
	if url_loaded_cardback:
		card_back.texture = url_loaded_cardback

func set_card_and_focus(pos, rot, sca):
	if pos != null:
		card_features.position = pos
		focus_feature.position = pos
	if rot != null:
		card_features.rotation_degrees = rot
		focus_feature.rotation_degrees = rot
	if sca != null:
		card_features.scale = sca
		focus_feature.scale = sca

func reset(pos = null):
	if not pos:
		pos = card_features.position
	resting_scale = default_scale
	set_card_and_focus(pos, 0, default_scale)
	change_state(CardState.CardState_InDeck)
	selected = false

func set_position_if_at_position(check_pos : Vector2, pos : Vector2):
	if card_features.position == check_pos:
		set_card_and_focus(pos, null, null)

func set_selected(is_selected):
	selected = is_selected
	$CardFocusFeatures/CardContainer/SelectedBorder.visible = is_selected

func set_resting_position(pos, rot):
	resting_position = pos
	resting_rotation = rot

	match state:
		CardState.CardState_InDeck, CardState.CardState_InHand, CardState.CardState_DrawingToHand:
			resting_scale = default_scale
			set_card_and_focus(null, null, resting_scale)
			position_card_in_hand(pos, rot)
		CardState.CardState_Unfocusing:
			target_pos = pos
			target_rotation = rot
		CardState.CardState_InPopout:
			resting_scale = ReferenceCardScale
			set_card_and_focus(null, null, resting_scale)
		CardState.CardState_Discarded:
			resting_scale = phone_discard_scale if phone_mode else DiscardCardScale
			set_card_and_focus(null, null, resting_scale)

func discard_to(pos, target_state):
	set_meta("phone_prev_state", state) # (the phone layout's flight hook checks where it came from)
	set_selected(false)
	set_resting_position(pos, 0)
	unfocus() # Sets animation_time to 0
	if target_state == CardState.CardState_InStrike:
		target_scale = phone_strike_scale if phone_mode else StrikeCardScale
	elif target_state == CardState.CardState_Discarded:
		target_scale = phone_discard_scale if phone_mode else DiscardCardScale
	else:
		target_scale = ReferenceCardScale
	resting_scale = target_scale
	return_state = target_state
	if phone_mode:
		animation_length = PHONE_ZONE_ANIMATION_LENGTH
		z_as_relative = false
		z_index = PHONE_ZONE_FLIGHT_Z
	var from_zone = get_parent()
	change_state(CardState.CardState_Discarding)
	# Phone layout: it may change how the card gets there (e.g. no flight at all).
	if phone_mode and phone_zone_flight_hook.is_valid():
		phone_zone_flight_hook.call(self, from_zone, target_state)

func finish_animation_immediately():
	match state:
		CardState.CardState_Focusing:
			set_card_and_focus(target_pos, target_rotation, target_scale)
			_end_focus_raise()
		CardState.CardState_Unfocusing:
			set_card_and_focus(target_pos, target_rotation, target_scale)
			_end_unfocus_raise()
			change_state(return_state)
		CardState.CardState_DrawingToHand:
			if not manual_flip_needed and not skip_flip_when_drawing:
				flip_card_to_front(true)
			set_card_and_focus(target_pos, target_rotation, original_scale)
			change_state(CardState.CardState_InHand)
		CardState.CardState_Discarding:
			set_card_and_focus(target_pos, target_rotation, target_scale)
			_end_zone_flight()
			change_state(return_state)
		_:
			return
	animation_time = 0

func change_state(new_state):
	state = new_state
	# (a card leaving its focus animation some other way, e.g. played from the hand mid-way,
	# lets the hand go back to its own drawing order)
	if _hand_raise_zone != null and new_state != CardState.CardState_Focusing and new_state != CardState.CardState_Unfocusing:
		_raise_hand_for_anim(false)

func clamp_to_screen(center_pos : Vector2, size: Vector2) -> Vector2:
	var global_pos = Vector2(0,0)
	if state == CardState.CardState_InPopout:
		global_pos = card_container.global_position
	center_pos = global_pos + center_pos

	var screen_size = get_viewport().content_scale_size
	var top_left = center_pos - size / 2
	var new_top_left = top_left
	var max_x = max(0.0, screen_size.x - size.x)
	var max_y = max(0.0, screen_size.y - size.y)
	if new_top_left.x < 0:
		new_top_left.x = 0
	if new_top_left.x > max_x:
		new_top_left.x = max_x
	if new_top_left.y < 0:
		new_top_left.y = 0
	if new_top_left.y > max_y:
		new_top_left.y = max_y
	var new_center = new_top_left + size / 2

	new_center = new_center - global_pos
	return new_center

func focus():

	if state == CardState.CardState_Unfocusing:
		# Switch the start/target
		start_pos = card_features.position
		start_rotation = card_features.rotation_degrees
		original_scale = card_features.scale
		# Return state stays the same.
	else:
		start_pos = card_features.position
		start_rotation = card_features.rotation_degrees
		original_scale = card_features.scale

		focus_pos = card_features.position
		focus_rot = 0

		return_state = state

	# NOTE: If you don't want it to animate a focus and want to leave
	# it where it is and use HugeCard, use this instead.
	if false and return_state == CardState.CardState_InHand:
		target_pos = card_features.position
		target_rotation = card_features.rotation_degrees
		target_scale = card_features.scale
	else:
		target_rotation = focus_rot
		target_scale = FocusScale
		var size_at_scale = $CardFocusFeatures/CardContainer.size * target_scale
		target_pos = clamp_to_screen(focus_pos, size_at_scale)
		if phone_mode and return_state == CardState.CardState_InHand:
			target_scale = phone_focus_scale
			target_pos = phone_focus_center
	animation_time = 0
	animation_length = FOCUS_ANIMATION_LENGTH

	z_as_relative = true
	z_index = 10
	# Phone: a focused hand card also shows over the strike cards (z 11), e.g. when a card is
	# picked from the hand in the middle of a strike.
	if phone_mode and return_state == CardState.CardState_InHand:
		z_index = 14
		# While it grows out of the hand it is drawn over everything except the hand cards
		# lying over it (see _raise_hand_for_anim); z 14 once it is in place.
		z_index = 0
		_raise_hand_for_anim(true)

	# Phone: the preview moves away from the hand, so its (still full-size)
	# hit button must not swallow taps meant for neighbouring cards or the
	# empty hand area.
	if phone_mode and return_state == CardState.CardState_InHand:
		focus_feature.get_node("Focus").mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_preview_input_ignored(true)

	emit_signal("raised_card", self)
	change_state(CardState.CardState_Focusing)

func unfocus():
	target_pos = resting_position
	target_rotation = resting_rotation
	target_scale = resting_scale

	start_pos = card_features.position
	start_rotation = card_features.rotation_degrees
	original_scale = card_features.scale

	animation_time = 0
	animation_length = FOCUS_ANIMATION_LENGTH

	if phone_mode and return_state == CardState.CardState_InHand:
		# Phone: back into the hand, drawn over everything except the hand cards lying over it.
		z_as_relative = true
		z_index = 0
		_raise_hand_for_anim(true)
	elif phone_mode:
		# Phone: on its way back down it is drawn over everything else on screen.
		z_as_relative = false
		z_index = PHONE_UNFOCUS_Z
		_unfocus_raised = true
	else:
		z_as_relative = true
		z_index = 0
	focus_feature.get_node("Focus").mouse_filter = Control.MOUSE_FILTER_STOP
	_set_preview_input_ignored(false)

	change_state(CardState.CardState_Unfocusing)
	emit_signal("lowered_card", self)

# Phone preview: GUI picking follows tree order, so the big preview card would
# otherwise sit on top of the layout's tap targets. Let taps pass through it.
func _set_preview_input_ignored(ignored : bool) -> void:
	for n in card_features.find_children("*", "Control", true, false):
		if ignored:
			if not n.has_meta("phone_orig_mouse_filter"):
				n.set_meta("phone_orig_mouse_filter", n.mouse_filter)
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif n.has_meta("phone_orig_mouse_filter"):
			n.mouse_filter = n.get_meta("phone_orig_mouse_filter")
			n.remove_meta("phone_orig_mouse_filter")

func _on_focus_mouse_entered():
	if phone_mode:
		return
	match state:
		CardState.CardState_InHand, CardState.CardState_Unfocusing, CardState.CardState_InStrike, CardState.CardState_InPopout:
			focus()

func _on_focus_mouse_exited():
	if phone_mode:
		return
	match state:
		CardState.CardState_Focusing:
			unfocus()

const PhoneLongPressTime := 0.45
# Set by the phone layout when "Phone Controls" are on; called as handler(card)
# when a card is held down for a long press.
static var phone_long_press_handler : Callable = Callable()
# Phone layout: called (card, zone it is leaving, target state) once discard_to has set up a
# card's flight to a zone.
static var phone_zone_flight_hook : Callable = Callable()
var _long_press_fired : bool = false
var _press_token : int = 0

func _on_focus_button_down():
	_long_press_fired = false
	_press_token += 1
	if phone_mode and phone_long_press_handler.is_valid():
		var token := _press_token
		get_tree().create_timer(PhoneLongPressTime).timeout.connect(func(): _check_long_press(token))

func _check_long_press(token : int):
	if token != _press_token or not is_inside_tree():
		return
	var btn = focus_feature.get_node_or_null("Focus")
	if btn != null and btn.button_pressed and phone_long_press_handler.is_valid():
		_long_press_fired = true
		phone_long_press_handler.call(self)

func _on_focus_button_up():
	_press_token += 1 # cancels a pending long press

func _on_focus_pressed():
	if _long_press_fired:
		_long_press_fired = false
		return # the long press already handled this touch
	emit_signal("clicked_card", self)
