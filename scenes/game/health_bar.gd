extends Node2D

const MaxHealth = 30
@onready var health = MaxHealth
@onready var health_bar = $BackgroundPanel/Margin/HealthProgressBar
@onready var lost_bar = $RedBarBackground/Margin/JustLostHealthBar

enum AnimationState {
	AnimationState_None,
	AnimationState_Paused,
	AnimationState_Moving,
}

@onready var animation_state : AnimationState = AnimationState.AnimationState_None
const AnimationLength : float = 4.0
const PauseLength : float = 4.0
var remaining_animation_time : float = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	set_health(20)
	#set_health(health)
	lost_bar.value = 25

func set_health(num):
	if animation_state == AnimationState.AnimationState_None:
		lost_bar.value = health_bar.value
	remaining_animation_time = PauseLength
	health_bar.value = num
	animation_state = AnimationState.AnimationState_Paused

func _physics_process(delta):
	if animation_state == AnimationState.AnimationState_Paused:
		remaining_animation_time -= delta
		if remaining_animation_time < 0:
			remaining_animation_time = AnimationLength
			animation_state = AnimationState.AnimationState_Moving
	elif animation_state == AnimationState.AnimationState_Moving:
		remaining_animation_time -= delta
		if remaining_animation_time < 0:
			remaining_animation_time = -1
			animation_state = AnimationState.AnimationState_None
			lost_bar.value = 0
		else:
			lost_bar.value = lerpf(lost_bar.value, health_bar.value, (AnimationLength - remaining_animation_time) / AnimationLength)



