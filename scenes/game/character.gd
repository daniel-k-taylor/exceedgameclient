extends Node2D

enum AnimationState {
	AnimationState_Idle,
	AnimationState_Moving,
}

@onready var animation : AnimatedSprite2D = $Animation
@onready var exceed_icon = $ExceedIcon

var animation_state = AnimationState.AnimationState_Idle
var current_position
var target_position

var remaining_animation_time : float = -1
const MoveTime : float = 1.0

# Called when the node enters the scene tree for the first time.
func _ready():
	animation.play("idle")
	exceed_icon.visible = false

func set_facing(to_left):
	animation.flip_h = to_left

func set_exceed(is_exceed):
	exceed_icon.visible = is_exceed

func get_size():
	return animation.sprite_frames.get_frame_texture("idle", 0).get_size()

func move_to(pos):
	current_position = position
	target_position = pos
	remaining_animation_time = MoveTime
	animation_state = AnimationState.AnimationState_Moving

func _physics_process(delta):
	exceed_icon.rotation_degrees += 0.01 / delta
	if animation_state == AnimationState.AnimationState_Moving:
		remaining_animation_time -= delta
		if remaining_animation_time < 0:
			remaining_animation_time = -1
			animation_state = AnimationState.AnimationState_Idle
			position = target_position
		else:
			position = current_position.lerp(target_position, (MoveTime - remaining_animation_time) / MoveTime)

