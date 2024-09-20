extends Node2D

signal raised_card(card)
signal lowered_card(card)
signal clicked_card(card)

const StatPanel = preload("res://scenes/card/stat_panel.gd")
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

var follow_mouse = false
var saved_hand_index = -1

var default_scale = Vector2(1, 1)
var resting_position
var resting_rotation
var resting_scale
var focus_pos
var focus_rot
var cancel_visible_on_front
var card_image
var cardback_image
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

func set_backlight_visible(backlight_visible):
	backlight.visible = backlight_visible

func set_stun(stun_visible):
	stun_indicator.visible = stun_visible

func set_ex(ex_visible):
	bonus_ex.visible = ex_visible

func set_wild(wild_visible):
	bonus_wild.visible = wild_visible

func set_crit(crit_visible):
	bonus_crit.visible = crit_visible

func clear_bonuses():
	set_ex(false)
	set_wild(false)
	set_crit(false)

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
				change_state(return_state)

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

func initialize_card(id, image, card_back_image, is_opponent: bool,
		url_loaded_image, url_loaded_cardback, card_name, boost_name):
	card_id = id
	var starting_scale = HandCardScale
	if is_opponent:
		starting_scale = OpponentHandCardScale
	default_scale = starting_scale
	resting_scale = starting_scale
	card_features.scale = starting_scale
	focus_feature.scale = starting_scale

	card_image = image
	cardback_image = card_back_image
	card_url_loaded_image = url_loaded_image
	card_url_loaded_cardback = url_loaded_cardback
	card_attack_name = card_name
	card_boost_name = boost_name
	assert(image, "Must have image for card")

	var target_card_node = fancy_card
	if url_loaded_image:
		fancy_card.texture = url_loaded_image
	else:
		if image.split('/')[-1]:
			fancy_card.texture = load(image)
		else:
			backup_label_text.text = "[center]Card: " + card_name + "\nBoost: " + boost_name + "[/center]"
			target_card_node = backup_label

	target_card_node.visible = true
	if url_loaded_cardback:
		card_back.texture = url_loaded_cardback
	elif cardback_image:
		card_back.texture = load(card_back_image)

func initialize_simple(id, image, card_back_image,
		url_loaded_image, url_loaded_cardback, card_name, boost_name):
	card_id = id
	var starting_scale = HandCardScale
	default_scale = starting_scale
	resting_scale = starting_scale
	card_features.scale = starting_scale
	focus_feature.scale = starting_scale

	card_image = image
	cardback_image = card_back_image
	card_url_loaded_image = url_loaded_image
	card_url_loaded_cardback = url_loaded_cardback
	card_attack_name = card_name
	card_boost_name = boost_name

	var target_card_node = fancy_card
	if url_loaded_image:
		fancy_card.texture = url_loaded_image
	else:
		if image.split('/')[-1]:
			fancy_card.texture = load(image)
		else:
			backup_label_text.text = "[center]Card: " + card_name + "\nBoost: " + boost_name + "[/center]"
			target_card_node = backup_label

	target_card_node.visible = true
	if url_loaded_cardback:
		card_back.texture = url_loaded_cardback
	elif cardback_image:
		card_back.texture = load(card_back_image)

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
			resting_scale = DiscardCardScale
			set_card_and_focus(null, null, resting_scale)

func discard_to(pos, target_state):
	set_selected(false)
	set_resting_position(pos, 0)
	unfocus() # Sets animation_time to 0
	if target_state == CardState.CardState_InStrike:
		target_scale = StrikeCardScale
	elif target_state == CardState.CardState_Discarded:
		target_scale = DiscardCardScale
	else:
		target_scale = ReferenceCardScale
	resting_scale = target_scale
	return_state = target_state
	change_state(CardState.CardState_Discarding)

func change_state(new_state):
	state = new_state

func clamp_to_screen(center_pos : Vector2, size: Vector2) -> Vector2:
	var global_pos = Vector2(0,0)
	if state == CardState.CardState_InPopout:
		global_pos = card_container.global_position
	center_pos = global_pos + center_pos

	var screen_size = get_viewport().content_scale_size
	var top_left = center_pos - size / 2
	var new_top_left = top_left
	if new_top_left.x < 0:
		new_top_left.x = 0
	if new_top_left.x + size.x > screen_size.x:
		new_top_left.x = screen_size.x - size.x
	if new_top_left.y < 0:
		new_top_left.y = 0
	if new_top_left.y + size.y > screen_size.y:
		new_top_left.y = screen_size.y - size.y
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
	animation_time = 0
	animation_length = FOCUS_ANIMATION_LENGTH

	z_index = 10

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

	z_index = 0

	change_state(CardState.CardState_Unfocusing)
	emit_signal("lowered_card", self)

func _on_focus_mouse_entered():
	match state:
		CardState.CardState_InHand, CardState.CardState_Unfocusing, CardState.CardState_InStrike, CardState.CardState_InPopout:
			focus()

func _on_focus_mouse_exited():
	match state:
		CardState.CardState_Focusing:
			unfocus()

func _on_focus_button_down():
	pass

func _on_focus_button_up():
	pass

func _on_focus_pressed():
	emit_signal("clicked_card", self)
