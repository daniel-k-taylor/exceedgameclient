class_name DamagePopup
extends Node2D

@onready var animation_player : AnimationPlayer = $AnimationPlayer
@onready var label : Label = $LabelContainer/Label
@onready var label_container : Node2D = $LabelContainer

func remove():
	animation_player.stop()
	if is_inside_tree():
		get_parent().remove_child(self)

func set_values_and_animate(value:String, start_pos: Vector2, height:float):
	label.text = value
	animation_player.play("Rise and Fade")
	var tween = get_tree().create_tween()
	var end_pos = Vector2(0, -height) + start_pos
	var tween_length = animation_player.get_animation("Rise and Fade").length

	tween.tween_property(label_container, "position", end_pos, tween_length).from(start_pos)
