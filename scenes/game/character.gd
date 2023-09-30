extends AnimatedSprite2D

enum AnimationState {
	AnimationState_Idle,
	AnimationState_Moving,
}

var animation_state = AnimationState.AnimationState_Idle
var current_position
var target_position

var remaining_animation_time : float = -1
const MoveTime : float = 1.0

# Called when the node enters the scene tree for the first time.
func _ready():
	play("idle")

func set_facing(to_left):
	flip_h = to_left

func get_size():
	return self.sprite_frames.get_frame_texture("idle", 0).get_size()

func move_to(pos):
	current_position = position
	target_position = pos
	remaining_animation_time = MoveTime
	animation_state = AnimationState.AnimationState_Moving

func _physics_process(delta):
	if animation_state == AnimationState.AnimationState_Moving:
		remaining_animation_time -= delta
		if remaining_animation_time < 0:
			remaining_animation_time = -1
			animation_state = AnimationState.AnimationState_Idle
			position = target_position
		else:
			position = current_position.lerp(target_position, (MoveTime - remaining_animation_time) / MoveTime)

