class_name Character
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

var is_wide : bool = false
var vertical_offset : float = 0
var horizontal_offset : float = 0
var horizontal_offset_buddy : float = 0
var use_buddy_extra_offset : bool = false

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
		play_animation("idle"),
	CharacterAnim.CharacterAnim_DashBack: func():
		play_animation("dash_back"),
	CharacterAnim.CharacterAnim_Hit: func():
		play_animation("hit"),
	CharacterAnim.CharacterAnim_Pulled: func():
		play_animation("pulled"),
	CharacterAnim.CharacterAnim_Pushed: func():
		play_animation("pushed"),
	CharacterAnim.CharacterAnim_Run: func():
		play_animation("run"),
	CharacterAnim.CharacterAnim_Stunned: func():
		play_animation("stunned"),
	CharacterAnim.CharacterAnim_WalkForward: func():
		play_animation("walk_forward"),
	CharacterAnim.CharacterAnim_WalkBackward: func():
		play_animation("walk_backward"),
}

var buddy_id : String = ""

# Called when the node enters the scene tree for the first time.
func _ready():
	exceed_icon.visible = false

func load_character(image_loader: CardImageLoader, character_data: Dictionary, char_id: String):
	var check_ids = [char_id]
	if char_id.begins_with("custom_"):
		check_ids.append(char_id.substr(7))
	for check_id in check_ids:
		if 'custom_animations' in character_data and check_id in character_data['custom_animations']:
			return await load_character_custom_anims(image_loader, character_data['custom_animations'][check_id])

	var path = "res://assets/character_animations/" + char_id + "/animations.tres"
	animation.sprite_frames = load(path)
	if not animation.sprite_frames:
		path = "res://assets/character_animations/custom/animations.tres"
		animation.sprite_frames = load(path)
	play_animation("idle")
	if animation.sprite_frames.has_meta("scaling"):
		var scaling = animation.sprite_frames.get_meta("scaling")
		if scaling:
			scale = scale * scaling
			$ExceedIcon.scale = $ExceedIcon.scale / scaling
	if animation.sprite_frames.has_meta("vertical_offset"):
		vertical_offset = animation.sprite_frames.get_meta("vertical_offset")
	if animation.sprite_frames.has_meta("horizontal_offset"):
		horizontal_offset = animation.sprite_frames.get_meta("horizontal_offset")
		animation.offset.x = horizontal_offset
	if animation.sprite_frames.has_meta("horizontal_offset_buddy"):
		horizontal_offset_buddy = animation.sprite_frames.get_meta("horizontal_offset_buddy")

func load_character_custom_anims(image_loader : CardImageLoader, animation_data):
	var sprite_frames = SpriteFrames.new()
	var anim_metadata = {}

	for animation_name in animation_data:
		if animation_name == "metadata":
			anim_metadata = animation_data[animation_name]
			continue
		var anim = animation_data[animation_name]

		var image_url = anim["url"]
		var frame_count = anim.get("frame_count", 1)
		var sprite_offset_x = anim.get("sprite_offset_x", 0)
		var sprite_offset_y = anim.get("sprite_offset_y", 0)
		var sprite_region_width = anim.get("sprite_region_width", -1)
		var sprite_region_height = anim.get("sprite_region_height", -1)
		var sprite_count_width = anim.get("sprite_count_width", frame_count)
		var sprite_count_height = anim.get("sprite_count_height", 1)

		var animation_images = await image_loader.get_animation_images(
			image_url,
			sprite_offset_x,
			sprite_offset_y,
			sprite_region_width,
			sprite_region_height,
			sprite_count_width,
			sprite_count_height
		)

		if animation_images:
			sprite_frames.add_animation(animation_name)
			for i in range(frame_count):
				sprite_frames.add_frame(animation_name, animation_images[i])

	# default
	if !sprite_frames.has_animation("idle"):
		sprite_frames.add_animation("idle")
		sprite_frames.add_frame("idle", load("res://assets/portraits/custom.png").duplicate())

	animation.sprite_frames = sprite_frames
	if anim_metadata:
		var scaling = anim_metadata.get("scaling", 1)
		sprite_frames.set_meta("scaling", scaling)
		scale = scale * scaling
		$ExceedIcon.scale = $ExceedIcon.scale / scaling

		sprite_frames.set_meta("vertical_offset", anim_metadata.get("vertical_offset", 0))
		vertical_offset = anim_metadata.get("vertical_offset", 0)

		sprite_frames.set_meta("horizontal_offset", anim_metadata.get("horizontal_offset", 0))
		horizontal_offset = anim_metadata.get("horizontal_offset", 0)
		animation.offset.x = horizontal_offset

		sprite_frames.set_meta("horizontal_offset_buddy", anim_metadata.get("horizontal_offset_buddy", 0))
		horizontal_offset_buddy = anim_metadata.get("horizontal_offset_buddy", 0)

		sprite_frames.set_meta("flip", anim_metadata.get("flip", false))
		set_facing(animation.flip_h)

	play_animation("idle")

func set_facing(to_left : bool):
	animation.flip_h = to_left
	if animation.sprite_frames.has_meta("flip") and animation.sprite_frames.get_meta("flip"):
		animation.flip_h = not animation.flip_h
	var offset_sign = 1 if to_left else -1
	animation.offset.x = horizontal_offset * offset_sign

func set_exceed(
		is_exceed : bool,
		image_loader: CardImageLoader = null,
		character_data: Dictionary = {},
		new_animation : String = ""):
	exceed_icon.visible = is_exceed
	if new_animation:
		load_character(image_loader, character_data, new_animation)

func get_size():
	return animation.sprite_frames.get_frame_texture("idle", 0).get_size()

func set_buddy_id(id : String):
	buddy_id = id

func get_buddy_id():
	return buddy_id

func set_buddy_extra_offset(use_buddy_extra_offset_value : bool):
	use_buddy_extra_offset = use_buddy_extra_offset_value

func play_animation(named_animation : String):
	if animation.sprite_frames.has_animation(named_animation):
		animation.play(named_animation)
	elif named_animation == "run":
		play_animation("walk_forward")
	elif named_animation == "dash_back":
		play_animation("walk_backward")

func play_hit():
	current_position = position
	target_position = position
	remaining_animation_time = HitTime
	animation_state = AnimationState.AnimationState_Moving
	play_animation("hit")

func play_stunned():
	current_position = position
	target_position = position
	remaining_animation_time = HitTime
	animation_state = AnimationState.AnimationState_Moving
	play_animation("stunned")

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
			play_animation("idle")
		else:
			position = current_position.lerp(target_position, (MoveTime - remaining_animation_time) / MoveTime)
