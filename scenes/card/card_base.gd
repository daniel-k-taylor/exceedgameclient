extends Area2D

signal raised_card(card)
signal lowered_card(card)
signal clicked_card(card)

const StatPanel = preload("res://scenes/card/stat_panel.gd")
@onready var range_panel : StatPanel = $CardContainer/CardBox/AbiltiesImagePanel/StatsHBox/StatsColumn/RangePanel
@onready var speed_panel : StatPanel = $CardContainer/CardBox/AbiltiesImagePanel/StatsHBox/StatsColumn/SpeedPanel
@onready var power_panel : StatPanel = $CardContainer/CardBox/AbiltiesImagePanel/StatsHBox/StatsColumn/PowerPanel
@onready var armor_panel : StatPanel = $CardContainer/CardBox/AbiltiesImagePanel/StatsHBox/StatsColumn/ArmorPanel
@onready var guard_panel : StatPanel = $CardContainer/CardBox/AbiltiesImagePanel/StatsHBox/StatsColumn/GuardPanel
@onready var card_box = $CardContainer/CardBox
@onready var cancel_container = $CancelContainer
@onready var cancel_cost_label = $CancelContainer/CancelCost
@onready var card_back = $CardContainer/CardBack
@onready var fancy_card = $CardContainer/FancyCard



const ActualCardSize = Vector2(250,350)
const HandCardScale = Vector2(0.7, 0.7)
const OpponentHandCardScale = Vector2(0.3, 0.3)
const FocusScale = Vector2(1.4, 1.4)
const ReferenceCardScale = Vector2(0.6, 0.6)
const StrikeCardScale = Vector2(0.4, 0.4)
const DiscardCardScale = Vector2(0.4, 0.4)
const HighlightColor = Color('#36fff3')

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
	CardState_InPopout,
	CardState_Offscreen,
	CardState_Discarding,
	CardState_Discarded,
	CardState_InStrike,
	CardState_Dragging,
	CardState_DrawingToHand,
	CardState_Unfocusing,
}

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

var follow_mouse = false
var saved_hand_index = -1

var default_scale = Vector2(1, 1)
var resting_position
var resting_rotation
var resting_scale
var focus_pos
var focus_rot
var focus_y_pos
var cancel_visible_on_front
var use_custom_card_image = false

var selected = false

const DRAW_ANIMATION_LENGTH = 0.5
const FOCUS_ANIMATION_LENGTH = 0.2
const DRAG_SCALE_FACTOR = 1.2

# Called when the node enters the scene tree for the first time.
func _ready():
	flip_card_to_front(false)
	set_hover_visible(false)
	$CardContainer/Focus.modulate = HighlightColor

func flip_card_to_front(front):
	if front:
		$CardContainer/CardBack.visible = false
		card_box.visible = use_custom_card_image
		fancy_card.visible = not use_custom_card_image
		cancel_container.visible = cancel_visible_on_front
	else:
		$CardContainer/CardBack.visible = true
		card_box.visible = false
		fancy_card.visible = false
		cancel_container.visible = false

func set_backlight_visible(backlight_visible):
	$Backlight.visible = backlight_visible

func set_stun(stun_visible):
	$StunIndicator.visible = stun_visible

func is_front_showing():
	return not $CardContainer/CardBack.visible

func set_hover_visible(hover_visible):
	$CardContainer/Focus.visible = hover_visible

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
				position = start_pos.lerp(target_pos, animation_time)
				rotation_degrees = lerpf(start_rotation, target_rotation, animation_time)
				scale = original_scale.lerp(target_scale, animation_time)
				animation_time += delta / animation_length
			else:
				position = target_pos
				rotation_degrees = target_rotation
				scale = target_scale
		CardState.CardState_Unfocusing:
			if animation_time <= 1:
				position = start_pos.lerp(target_pos, animation_time)
				rotation_degrees = lerpf(start_rotation, target_rotation, animation_time)
				scale = original_scale.lerp(target_scale, animation_time)
				animation_time += delta / animation_length
			else:
				position = target_pos
				rotation_degrees = target_rotation
				scale = target_scale
				change_state(return_state)
		CardState.CardState_DrawingToHand: # animate from deck to hand
			if animation_time <= 1:
				position = start_pos.lerp(target_pos, animation_time)
				rotation_degrees = lerpf(start_rotation, target_rotation, animation_time)
				if animate_flip:
					scale.x = original_scale.x * abs(1 - 2*animation_time)
				if animation_time >= 0.5 and not manual_flip_needed:
					flip_card_to_front(true)
				animation_time += delta / animation_length
			else:
				position = target_pos
				rotation_degrees = target_rotation
				scale.x = original_scale.x
				change_state(CardState.CardState_InHand)
		CardState.CardState_Dragging:
			var mouse_pos = get_viewport().get_mouse_position()
			position = Vector2(mouse_pos.x, mouse_pos.y)
			if animation_time <= 1:
				rotation_degrees = lerpf(start_rotation, target_rotation, animation_time)
				scale = original_scale.lerp(target_scale, animation_time)
				animation_time += delta / animation_length
			else:
				rotation_degrees = target_rotation
				scale = target_scale
		CardState.CardState_Discarding:
			if animation_time <= 1:
				position = start_pos.lerp(target_pos, animation_time)
				rotation_degrees = lerpf(start_rotation, target_rotation, animation_time)
				scale = original_scale.lerp(target_scale, animation_time)
				animation_time += delta / animation_length
			else:
				position = target_pos
				rotation_degrees = target_rotation
				scale = target_scale
				change_state(return_state)

func position_card_in_hand(dst_pos, dst_rot):
	if state == CardState.CardState_DrawingToHand:
		target_pos = dst_pos
		target_rotation = dst_rot
	else:
		change_state(CardState.CardState_DrawingToHand)

		animate_flip = not manual_flip_needed and not is_front_showing()
		original_scale = scale
		start_pos = position
		target_pos = dst_pos
		start_rotation = rotation_degrees
		target_rotation = dst_rot
		animation_time = 0
		animation_length = DRAW_ANIMATION_LENGTH

		position = start_pos
		rotation_degrees = start_rotation


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func initialize_card(id, card_title, image, card_back_image, range_min, range_max, speed, power, armor, guard, effect_text, boost_cost, boost_text, strike_cost, cancel_cost, hand_focus_y_pos, is_opponent: bool):
	card_id = id
	$CardContainer/CardBox/TitleRow/TitlePanel/TitleNameBox/TitleName.text = card_title
	var starting_scale = HandCardScale
	if is_opponent:
		starting_scale = OpponentHandCardScale
	default_scale = starting_scale
	resting_scale = starting_scale
	scale = starting_scale
	if image != "":
		use_custom_card_image = false
		fancy_card.texture = load(image)
		fancy_card.visible = true
		card_box.visible = false
	else:
		use_custom_card_image = true
	card_back.texture = load(card_back_image)

	# Set Stats
	range_panel.set_stats("RANGE", range_min, range_max)
	speed_panel.set_stats("SPEED", speed, speed)
	power_panel.set_stats("POWER", power, power, true)
	armor_panel.set_stats("ARMOR", armor, armor, true)
	guard_panel.set_stats("GUARD", guard, guard, true)

	cancel_visible_on_front = use_custom_card_image and cancel_cost != -1
	cancel_cost_label.text = str(cancel_cost)

	# Set Effect and Boost
	$CardContainer/CardBox/EffectBox/EffectText.text = "[center]%s[/center]" % effect_text
	$CardContainer/CardBox/BoostBox/BoostDetailsBox/BoostCostIcon/BoostCost.text = "  %s" % boost_cost
	$CardContainer/CardBox/BoostBox/BoostDetailsBox/BoostText.text = "%s" % boost_text
	$CardContainer/CardBox/TitleRow/TitleIcon.visible = strike_cost == 0
	$CardContainer/CardBox/TitleRow/CardCost.visible = strike_cost != 0
	$CardContainer/CardBox/TitleRow/CardCost.text = "  " + str(strike_cost)

	focus_y_pos = hand_focus_y_pos

func reset():
	resting_scale = default_scale
	scale = default_scale
	change_state(CardState.CardState_InDeck)
	selected = false

func set_selected(is_selected):
	selected = is_selected
	$CardContainer/SelectedBorder.visible = is_selected

func set_resting_position(pos, rot):
	resting_position = pos
	resting_rotation = rot

	match state:
		CardState.CardState_InDeck, CardState.CardState_InHand, CardState.CardState_DrawingToHand:
			resting_scale = default_scale
			scale = resting_scale
			position_card_in_hand(pos, rot)
		CardState.CardState_Unfocusing:
			target_pos = pos
			target_rotation = rot
		CardState.CardState_InPopout:
			resting_scale = ReferenceCardScale
			scale = resting_scale
		CardState.CardState_Discarded:
			resting_scale = DiscardCardScale
			scale = resting_scale

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
	return new_center

func focus():

	if state == CardState.CardState_Unfocusing:
		# Switch the start/target
		start_pos = position
		start_rotation = rotation_degrees
		original_scale = scale
		# Return state stays the same.
	else:
		start_pos = position
		start_rotation = rotation_degrees
		original_scale = scale

		focus_pos = position
		focus_rot = 0
		#if state == CardState.CardState_InHand:
		#	focus_pos.y = focus_y_pos

		return_state = state

	target_rotation = focus_rot
	target_scale = FocusScale
	var size_at_scale = $CardContainer.size * target_scale
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

	start_pos = position
	start_rotation = rotation_degrees
	original_scale = scale

	animation_time = 0
	animation_length = FOCUS_ANIMATION_LENGTH

	z_index = 0

	change_state(CardState.CardState_Unfocusing)
	emit_signal("lowered_card", self)

func begin_drag():
	follow_mouse = true
	original_scale = scale
	target_scale = resting_scale * DRAG_SCALE_FACTOR
	start_rotation = rotation_degrees
	target_rotation = 0
	animation_time = 0
	animation_length = FOCUS_ANIMATION_LENGTH
	return_state = CardState.CardState_InHand
	emit_signal("raised_card", self)
	change_state(CardState.CardState_Dragging)

func end_drag():
	follow_mouse = false
	unfocus()

func _on_focus_mouse_entered():
	match state:
		CardState.CardState_InHand, CardState.CardState_Unfocusing, CardState.CardState_InStrike, CardState.CardState_InPopout:
			focus()


func _on_focus_mouse_exited():
	match state:
		CardState.CardState_Focusing:
			unfocus()

func _on_focus_button_down():
	# TODO: When to drag?
#	match state:
#		InHand, Focusing:
#			begin_drag()
	pass

func _on_focus_button_up():
	match state:
		CardState.CardState_Dragging:
			end_drag()


func _on_focus_pressed():
	emit_signal("clicked_card", self)
