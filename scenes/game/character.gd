class_name Character
extends Node2D

enum AnimationState {
	AnimationState_Idle,
	AnimationState_Moving,
}

@onready var animation : AnimatedSprite2D = $Animation
@onready var exceed_icon = $ExceedIcon
@onready var base_scale = scale
@onready var base_exceed_icon_scale = exceed_icon.scale

var animation_state = AnimationState.AnimationState_Idle
var current_position
var target_position

var is_wide : bool = false
var vertical_offset : float = 0
var horizontal_offset : float = 0
var horizontal_offset_buddy : float = 0
var use_buddy_extra_offset : bool = false
var runtime_texture_scale_compensation := 1.0

var remaining_animation_time : float = -1
const MoveTime : float = 1.0
const HitTime : float = 1.0
const MOBILE_WEB_CHARACTER_TEXTURE_SCALE := 0.5

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

func load_character(image_loader: CardImageLoader, character_data: Dictionary, char_id: String, yield_between_textures := true):
	var check_ids = [char_id]
	if char_id.begins_with("custom_"):
		check_ids.append(char_id.substr(7))
	for check_id in check_ids:
		if 'custom_animations' in character_data and check_id in character_data['custom_animations']:
			return await load_character_custom_anims(image_loader, character_data['custom_animations'][check_id])

	# Undo any previous mobile-web texture-scale compensation before reloading.
	scale /= runtime_texture_scale_compensation
	exceed_icon.scale *= runtime_texture_scale_compensation
	runtime_texture_scale_compensation = 1.0

	var path = "res://assets/character_animations/" + char_id + "/animations.tres"
	var loaded_frames = load(path)
	if not loaded_frames:
		path = "res://assets/character_animations/custom/animations.tres"
		loaded_frames = load(path)
	animation.sprite_frames = await _prepare_sprite_frames_for_runtime(loaded_frames as SpriteFrames, yield_between_textures)
	play_animation("idle")
	if animation.sprite_frames.has_meta("scaling"):
		var scaling = animation.sprite_frames.get_meta("scaling")
		if scaling:
			scale = scale * scaling
			$ExceedIcon.scale = $ExceedIcon.scale / scaling
	if _is_mobile_web():
		# Textures were downscaled by MOBILE_WEB_CHARACTER_TEXTURE_SCALE; compensate the
		# node scale so the character stays the same on-screen size (~4x less texture memory).
		runtime_texture_scale_compensation = 1.0 / MOBILE_WEB_CHARACTER_TEXTURE_SCALE
		scale *= runtime_texture_scale_compensation
		exceed_icon.scale /= runtime_texture_scale_compensation
	if animation.sprite_frames.has_meta("vertical_offset"):
		vertical_offset = animation.sprite_frames.get_meta("vertical_offset")
	if animation.sprite_frames.has_meta("horizontal_offset"):
		horizontal_offset = animation.sprite_frames.get_meta("horizontal_offset")
		animation.offset.x = horizontal_offset
	if animation.sprite_frames.has_meta("horizontal_offset_buddy"):
		horizontal_offset_buddy = animation.sprite_frames.get_meta("horizontal_offset_buddy")

func _is_mobile_web() -> bool:
	return OS.has_feature("web") and (
		OS.has_feature("mobile")
		or OS.has_feature("web_android")
		or OS.has_feature("web_ios")
	)

static func get_mobile_web_character_texture_size(source_size : Vector2i) -> Vector2i:
	return Vector2i(
		maxi(1, int(round(source_size.x * MOBILE_WEB_CHARACTER_TEXTURE_SCALE))),
		maxi(1, int(round(source_size.y * MOBILE_WEB_CHARACTER_TEXTURE_SCALE))))

func _prepare_sprite_frames_for_runtime(source_frames : SpriteFrames, yield_between_textures := true) -> SpriteFrames:
	if source_frames == null or not _is_mobile_web():
		return source_frames

	var optimized_frames := SpriteFrames.new()
	if optimized_frames.has_animation(&"default"):
		optimized_frames.remove_animation(&"default")
	for metadata_name in source_frames.get_meta_list():
		optimized_frames.set_meta(metadata_name, source_frames.get_meta(metadata_name))
	for animation_name in source_frames.get_animation_names():
		optimized_frames.add_animation(animation_name)
		optimized_frames.set_animation_loop(animation_name, source_frames.get_animation_loop(animation_name))
		optimized_frames.set_animation_speed(animation_name, source_frames.get_animation_speed(animation_name))

	var scaled_texture_cache := {}
	for animation_name in source_frames.get_animation_names():
		for frame_index in range(source_frames.get_frame_count(animation_name)):
			var source_texture := source_frames.get_frame_texture(animation_name, frame_index)
			var optimized_texture := await _create_mobile_web_frame_texture(
				source_texture,
				scaled_texture_cache,
				yield_between_textures)
			optimized_frames.add_frame(
				animation_name,
				optimized_texture,
				source_frames.get_frame_duration(animation_name, frame_index))
	return optimized_frames

func _create_mobile_web_frame_texture(
		source_texture : Texture2D,
		scaled_texture_cache : Dictionary,
		yield_between_textures : bool) -> Texture2D:
	if source_texture == null:
		return null

	if source_texture is AtlasTexture:
		var source_atlas : Texture2D = source_texture.atlas
		if source_atlas == null:
			return source_texture
		var atlas_key : int = source_atlas.get_instance_id()
		if not scaled_texture_cache.has(atlas_key):
			scaled_texture_cache[atlas_key] = _create_mobile_web_base_texture(source_atlas)
			if yield_between_textures:
				await get_tree().process_frame
		var optimized_atlas := AtlasTexture.new()
		optimized_atlas.atlas = scaled_texture_cache[atlas_key]
		optimized_atlas.region = _scale_mobile_web_rect(source_texture.region)
		optimized_atlas.margin = _scale_mobile_web_rect(source_texture.margin)
		optimized_atlas.filter_clip = source_texture.filter_clip
		return optimized_atlas

	var texture_key := source_texture.get_instance_id()
	if not scaled_texture_cache.has(texture_key):
		scaled_texture_cache[texture_key] = _create_mobile_web_base_texture(source_texture)
		if yield_between_textures:
			await get_tree().process_frame
	return scaled_texture_cache[texture_key]

func _create_mobile_web_base_texture(source_texture : Texture2D) -> Texture2D:
	var source_image := source_texture.get_image()
	if source_image == null or source_image.is_empty():
		return source_texture
	var target_size := get_mobile_web_character_texture_size(source_image.get_size())
	ImageResizer.resize_in_place(source_image, target_size.x, target_size.y)
	return ImageTexture.create_from_image(source_image)

static func _scale_mobile_web_rect(source_rect : Rect2) -> Rect2:
	return Rect2(
		source_rect.position * MOBILE_WEB_CHARACTER_TEXTURE_SCALE,
		source_rect.size * MOBILE_WEB_CHARACTER_TEXTURE_SCALE)

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
		scale = base_scale * scaling
		exceed_icon.scale = base_exceed_icon_scale / scaling

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

func snap_to(pos : Vector2):
	position = pos
	current_position = pos
	target_position = pos
	remaining_animation_time = -1
	animation_state = AnimationState.AnimationState_Idle
	play_animation("idle")

func finish_movement():
	if animation_state != AnimationState.AnimationState_Moving:
		return
	position = target_position
	current_position = target_position
	remaining_animation_time = -1
	animation_state = AnimationState.AnimationState_Idle
	play_animation("idle")

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
