class_name DamagePopup
extends Node2D

@onready var animation_player : AnimationPlayer = $AnimationPlayer
@onready var label : Label = $LabelContainer/Label
@onready var label_container : Node2D = $LabelContainer

func remove():
	animation_player.stop()
	if is_inside_tree():
		get_parent().remove_child(self)

func pause_for_rotation_layout():
	remove()

# `size_mult`: the text's size (1 = the normal 14 pt). `time_mult`: how much longer it stays up.
# (Popups are pooled, so both are set every time.)
func set_values_and_animate(value:String, start_pos: Vector2, height:float, size_mult : float = 1.0, time_mult : float = 1.0):
	label.text = value
	label.add_theme_font_size_override("font_size", int(round(14.0 * size_mult)))
	animation_player.speed_scale = 1.0 / maxf(time_mult, 0.01)
	animation_player.play("Rise and Fade")
	var tween = get_tree().create_tween()
	var end_pos = Vector2(0, -height) + start_pos
	var tween_length = animation_player.get_animation("Rise and Fade").length * time_mult

	tween.tween_property(label_container, "position", end_pos, tween_length).from(start_pos)
