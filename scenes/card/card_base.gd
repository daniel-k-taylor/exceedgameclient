extends Area2D

signal raised_card(card)
signal lowered_card(card)

const StatPanel = preload("res://scenes/card/stat_panel.gd")
@onready var range_panel : StatPanel = $CardContainer/CardBox/AbiltiesImagePanel/StatsHBox/StatsColumn/RangePanel
@onready var speed_panel : StatPanel = $CardContainer/CardBox/AbiltiesImagePanel/StatsHBox/StatsColumn/SpeedPanel
@onready var power_panel : StatPanel = $CardContainer/CardBox/AbiltiesImagePanel/StatsHBox/StatsColumn/PowerPanel
@onready var armor_panel : StatPanel = $CardContainer/CardBox/AbiltiesImagePanel/StatsHBox/StatsColumn/ArmorPanel
@onready var guard_panel : StatPanel = $CardContainer/CardBox/AbiltiesImagePanel/StatsHBox/StatsColumn/GuardPanel

enum {
	InDeck,
	InHand,
	Focusing,
	Unfocusing,
	DrawingToHand,
	Dragging,
}

var state = InDeck
var return_state = InDeck
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

var follow_mouse = false
var saved_hand_index = -1

var resting_position
var resting_rotation
var resting_scale
var focus_pos
var focus_rot

const DRAW_ANIMATION_LENGTH = 0.5
const FOCUS_ANIMATION_LENGTH = 0.2
const FOCUS_SCALE_FACTOR = 2
const DRAG_SCALE_FACTOR = 1.2

# Called when the node enters the scene tree for the first time.
func _ready():
	flip_card_to_front(false)
	set_hover_visible(false)

func flip_card_to_front(front):
	if front:
		$CardContainer/CardBack.visible = false
		$CardContainer/Background.visible = true
		$CardContainer/CardBox.visible = true
	else:
		$CardContainer/CardBack.visible = true
		$CardContainer/Background.visible = false
		$CardContainer/CardBox.visible = false

func is_front_showing():
	return not $CardContainer/CardBack.visible

func set_hover_visible(hover_visible):
	$CardContainer/Focus.visible = hover_visible

func _physics_process(delta):
	match state:
		InHand:
			set_hover_visible(true)
		Focusing:
			if animation_time <= 1:
				position = start_pos.lerp(target_pos, animation_time)
				rotation_degrees = lerpf(start_rotation, target_rotation, animation_time)
				scale = original_scale.lerp(target_scale, animation_time)
				animation_time += delta / animation_length
			else:
				position = target_pos
				rotation_degrees = target_rotation
				scale = target_scale
		Unfocusing:
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
		DrawingToHand: # animate from deck to hand
			if animation_time <= 1:
				position = start_pos.lerp(target_pos, animation_time)
				rotation_degrees = lerpf(start_rotation, target_rotation, animation_time)
				if animate_flip:
					scale.x = original_scale.x * abs(1 - 2*animation_time)
				if animation_time >= 0.5:
					flip_card_to_front(true)
				animation_time += delta / animation_length
			else:
				position = target_pos
				rotation_degrees = target_rotation
				scale.x = original_scale.x
				change_state(InHand)
		Dragging:
			var mouse_pos = get_viewport().get_mouse_position()
			position = Vector2(mouse_pos.x, mouse_pos.y)
			if animation_time <= 1:
				rotation_degrees = lerpf(start_rotation, target_rotation, animation_time)
				scale = original_scale.lerp(target_scale, animation_time)
				animation_time += delta / animation_length
			else:
				rotation_degrees = target_rotation
				scale = target_scale

func position_card_in_hand(dst_pos, dst_rot):
	if state == DrawingToHand:
		target_pos = dst_pos
		target_rotation = dst_rot
	else:
		change_state(DrawingToHand)

		animate_flip = not is_front_showing()
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

func initialize_card(id, card_title, card_scale, _image, range_min, range_max, speed, power, armor, guard, effect_text, boost_cost, boost_text):
	self.card_id = id
	$CardContainer/CardBox/TitleRow/TitlePanel/TitleNameBox/TitleName.text = card_title
	self.resting_scale = card_scale
	scale = card_scale
	# TODO: Set image

	# Set Stats
	self.range_panel.set_stats("RANGE", range_min, range_max)
	self.speed_panel.set_stats("SPEED", speed, speed)
	self.power_panel.set_stats("POWER", power, power, true)
	self.armor_panel.set_stats("ARMOR", armor, armor, true)
	self.guard_panel.set_stats("GUARD", guard, guard, true)

	# Set Effect and Boost
	$CardContainer/CardBox/EffectBox/EffectText.text = "[center]%s[/center]" % effect_text
	$CardContainer/CardBox/BoostBox/BoostDetailsBox/BoostCostIcon/BoostCost.text = "[center]%s[/center]" % boost_cost
	$CardContainer/CardBox/BoostBox/BoostDetailsBox/BoostText.text = "[center]%s[/center]" % boost_text

func set_resting_position(pos, rot):
	resting_position = pos
	resting_rotation = rot

	match state:
		InDeck, InHand, DrawingToHand:
			position_card_in_hand(pos, rot)
		Unfocusing:
			target_pos = pos
			target_rotation = rot


func change_state(new_state):
	state = new_state

func focus():

	if state == Unfocusing:
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
		if state == InHand:
			focus_pos.y -= 100

		return_state = state

	target_pos = focus_pos
	target_rotation = focus_rot
	target_scale = resting_scale * FOCUS_SCALE_FACTOR
	animation_time = 0
	animation_length = FOCUS_ANIMATION_LENGTH

	emit_signal("raised_card", self)
	change_state(Focusing)

func unfocus():
	target_pos = resting_position
	target_rotation = resting_rotation
	target_scale = resting_scale

	start_pos = position
	start_rotation = rotation_degrees
	original_scale = scale

	animation_time = 0
	animation_length = FOCUS_ANIMATION_LENGTH

	change_state(Unfocusing)
	emit_signal("lowered_card", self)

func begin_drag():
	follow_mouse = true
	original_scale = scale
	target_scale = resting_scale * DRAG_SCALE_FACTOR
	start_rotation = rotation_degrees
	target_rotation = 0
	animation_time = 0
	animation_length = FOCUS_ANIMATION_LENGTH
	return_state = InHand
	emit_signal("raised_card", self)
	change_state(Dragging)

func end_drag():
	follow_mouse = false
	unfocus()

func _on_focus_mouse_entered():
	match state:
		InHand, Unfocusing:
			focus()


func _on_focus_mouse_exited():
	match state:
		Focusing:
			unfocus()

func _on_focus_button_down():
	match state:
		InHand, Focusing:
			begin_drag()

func _on_focus_button_up():
	match state:
		Dragging:
			end_drag()
