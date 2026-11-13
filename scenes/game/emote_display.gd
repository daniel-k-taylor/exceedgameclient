class_name EmoteDisplay
extends Node2D

@onready var panel : PanelContainer = $Panel
@onready var image : TextureRect = $Panel/Margin/EmoteIcon
@onready var text : Label = $Panel/Margin/EmoteText
@onready var animation_player : AnimationPlayer = $AnimationPlayer

func remove():
	animation_player.stop()

const TEXT_SIZE := 28
const BASE_SPEED := 0.75 # (the animation player's own speed scale)

# `size_mult`: a text emote's size (1 = the normal 28 pt; shrunk if needed to fit across the
# screen). `time_mult`: how much longer it stays up. (Both are set every time.)
func play_emote(is_image_emote : bool, emote : String, start_pos: Vector2, height : float,
		size_mult : float = 1.0, time_mult : float = 1.0):
	animation_player.stop()
	animation_player.speed_scale = BASE_SPEED / maxf(time_mult, 0.01)
	var fs := int(round(TEXT_SIZE * size_mult))
	var max_w : float = get_viewport_rect().size.x - 40.0
	var f : Font = text.get_theme_font("font")
	if not is_image_emote and f != null:
		while fs > TEXT_SIZE and f.get_string_size(emote, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 20.0 > max_w:
			fs -= 2
	text.add_theme_font_size_override("font_size", fs)
	if is_image_emote:
		var texture = load(emote)
		if texture:
			image.texture = texture
		else:
			is_image_emote = false
			emote = "Failed to load image:\n%s" % emote

	if not is_image_emote:
		text.text = emote

	image.visible = is_image_emote
	text.visible = not is_image_emote

	panel.reset_size()
	panel.modulate = Color(1, 1, 1, 0)
	animation_player.play("Rise and Fade")
	var tween = get_tree().create_tween()
	var end_pos = Vector2(0, -height) + start_pos
	var tween_length = animation_player.get_animation("Rise and Fade").length * time_mult

	tween.tween_property(panel, "position", end_pos, tween_length).from(start_pos)
