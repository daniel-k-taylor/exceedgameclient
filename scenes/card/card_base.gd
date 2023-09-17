extends Area2D

const StatPanel = preload("res://scenes/card/stat_panel.gd")
@onready var range_panel : StatPanel = $CardContainer/CardBox/AbiltiesImagePanel/StatsHBox/StatsColumn/RangePanel
@onready var speed_panel : StatPanel = $CardContainer/CardBox/AbiltiesImagePanel/StatsHBox/StatsColumn/SpeedPanel
@onready var power_panel : StatPanel = $CardContainer/CardBox/AbiltiesImagePanel/StatsHBox/StatsColumn/PowerPanel
@onready var armor_panel : StatPanel = $CardContainer/CardBox/AbiltiesImagePanel/StatsHBox/StatsColumn/ArmorPanel
@onready var guard_panel : StatPanel = $CardContainer/CardBox/AbiltiesImagePanel/StatsHBox/StatsColumn/GuardPanel

enum {
	InHand,
	Focus,
	Unfocus,
	MovingToDest,
}

var state = InHand
var return_state = InHand
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

const DRAW_ANIMATION_LENGTH = 0.5
const FOCUS_ANIMATION_LENGTH = 0.2
const FOCUS_SCALE_FACTOR = 2

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

func set_hover_visible(visible):
	$CardContainer/Focus.visible = visible

func _physics_process(delta):
	match state:
		InHand:
			set_hover_visible(true)
		Focus:
			if animation_time <= 1:
				position = start_pos.lerp(target_pos, animation_time)
				rotation_degrees = lerpf(start_rotation, target_rotation, animation_time)
				scale = original_scale.lerp(target_scale, animation_time)
				animation_time += delta / animation_length
			else:
				position = target_pos
				rotation_degrees = target_rotation
				scale = target_scale
		Unfocus:
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
		MovingToDest: # animate from deck to hand
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
				change_state(return_state)

func position_card_in_hand(src_pos, dst_pos, src_rot, dst_rot):
	if state == MovingToDest:
		target_pos = dst_pos
		target_rotation = dst_rot
	else:
		change_state(MovingToDest)
		
		animate_flip = not is_front_showing()
		original_scale = scale
		start_pos = src_pos
		target_pos = dst_pos
		start_rotation = src_rot
		target_rotation = dst_rot
		animation_time = 0
		animation_length = DRAW_ANIMATION_LENGTH
		
		position = start_pos
		rotation_degrees = start_rotation
		return_state = InHand


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func initialize_card(id, card_title, image, range_min, range_max, speed, power, armor, guard, effect_text, boost_cost, boost_text):
	self.card_id = id
	$CardContainer/CardBox/TitleRow/TitlePanel/TitleNameBox/TitleName.text = card_title
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

func change_state(new_state):
	state = new_state

func focus():
	if state == Unfocus:
		# Switch the start/target
		var temp_pos = target_pos
		var temp_rot = target_rotation
		var temp_scale = original_scale
		target_pos = start_pos
		target_rotation = start_rotation
		start_pos = temp_pos
		start_rotation = temp_rot
		original_scale = target_scale
		target_scale = temp_scale
		animation_time = 0
		# Return state stays the same.
	else:
		start_pos = position
		start_rotation = rotation_degrees
		target_pos = position
		target_rotation = 0
		original_scale = scale
		target_scale = scale * FOCUS_SCALE_FACTOR
		if state == InHand:
			target_pos.y -= 100
		animation_time = 0
		animation_length = FOCUS_ANIMATION_LENGTH
		
		return_state = state
		
	change_state(Focus)

func unfocus():
	target_pos = start_pos
	target_rotation = start_rotation
	start_pos = position
	start_rotation = rotation_degrees
	target_scale = original_scale
	original_scale = scale
	animation_time = 0
	animation_length = FOCUS_ANIMATION_LENGTH
	animate_flip = false
	
	change_state(Unfocus)

func _on_focus_mouse_entered():
	match state:
		InHand, Unfocus:
			focus()
		


func _on_focus_mouse_exited():
	match state:
		Focus:
			unfocus()
