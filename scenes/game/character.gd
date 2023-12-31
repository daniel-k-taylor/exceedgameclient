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
const HitTime : float = 1.0

enum CharacterAnim {
	CharacterAnim_None,
	CharacterAnim_DashBack,
	CharacterAnim_Hit,
	CharacterAnim_Pulled,
	CharacterAnim_Pushed,
	CharacterAnim_Run,
	CharacterAnim_Stunned,
	CharacterAnim_WalkForward,
	CharacterAnim_WalkBackward,
}

var animation_map = {
	CharacterAnim.CharacterAnim_None: func():
		animation.play("idle"),
	CharacterAnim.CharacterAnim_DashBack: func():
		animation.play("dash_back"),
	CharacterAnim.CharacterAnim_Hit: func():
		animation.play("hit"),
	CharacterAnim.CharacterAnim_Pulled: func():
		animation.play("pulled"),
	CharacterAnim.CharacterAnim_Pushed: func():
		animation.play("pushed"),
	CharacterAnim.CharacterAnim_Run: func():
		animation.play("run"),
	CharacterAnim.CharacterAnim_Stunned: func():
		animation.play("stunned"),
	CharacterAnim.CharacterAnim_WalkForward: func():
		animation.play("walk_forward"),
	CharacterAnim.CharacterAnim_WalkBackward: func():
		animation.play("walk_backward"),
}

# Called when the node enters the scene tree for the first time.
func _ready():
	exceed_icon.visible = false

func load_character(char_id : String):
	var path = "res://assets/character_animations/" + char_id + "/animations.tres"
	animation.sprite_frames = load(path)
	animation.play("idle")
	if animation.sprite_frames.has_meta("scaling"):
		var scaling = animation.sprite_frames.get_meta("scaling")
		if scaling:
			scale = scale * scaling
			$ExceedIcon.scale = $ExceedIcon.scale / scaling

func set_facing(to_left : bool):
	animation.flip_h = to_left
	if animation.sprite_frames.has_meta("flip") and animation.sprite_frames.get_meta("flip"):
		animation.flip_h = not animation.flip_h

func set_exceed(is_exceed : bool):
	exceed_icon.visible = is_exceed

func get_size():
	return animation.sprite_frames.get_frame_texture("idle", 0).get_size()

func play_hit():
	current_position = position
	target_position = position
	remaining_animation_time = HitTime
	animation_state = AnimationState.AnimationState_Moving
	animation.play("hit")

func play_stunned():
	current_position = position
	target_position = position
	remaining_animation_time = HitTime
	animation_state = AnimationState.AnimationState_Moving
	animation.play("stunned")

func move_to(pos : Vector2, move_type : CharacterAnim):
	current_position = position
	target_position = pos
	remaining_animation_time = MoveTime
	animation_state = AnimationState.AnimationState_Moving
	var selected_func = animation_map[move_type]
	selected_func.call()

func _physics_process(delta):
	exceed_icon.rotation_degrees += 0.01 / delta
	if animation_state == AnimationState.AnimationState_Moving:
		remaining_animation_time -= delta
		if remaining_animation_time < 0:
			remaining_animation_time = -1
			animation_state = AnimationState.AnimationState_Idle
			position = target_position
			animation.play("idle")
		else:
			position = current_position.lerp(target_position, (MoveTime - remaining_animation_time) / MoveTime)

