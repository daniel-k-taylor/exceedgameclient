extends Node2D

var start_me_position = Vector2(-950,20)
var final_me_position = Vector2(50,20)

var start_you_position = Vector2(550 + 1000, 500)
var final_you_position = Vector2(550, 500)

var label_font_normal = 90
var label_font_small = 60
var label_length_threshold = 16

const tween_duration = 1.0

func set_info(vs_info):
	var my_char_name = vs_info['player_deck']['display_name']
	$MeNameBox/MyDeckLabel.text = my_char_name
	if len(my_char_name) <= label_length_threshold:
		$MeNameBox/MyDeckLabel.set("theme_override_font_sizes/font_size", label_font_normal)
	else:
		$MeNameBox/MyDeckLabel.set("theme_override_font_sizes/font_size", label_font_small)
	$MeNameBox/MyNameLabel.text = vs_info['player_name']

	var your_char_name = vs_info['opponent_deck']['display_name']
	$YouNameBox/YouDeckLabel.text = your_char_name
	if len(your_char_name) <= label_length_threshold:
		$YouNameBox/YouDeckLabel.set("theme_override_font_sizes/font_size", label_font_normal)
	else:
		$YouNameBox/YouDeckLabel.set("theme_override_font_sizes/font_size", label_font_small)
	$YouNameBox/YouNameLabel.text = vs_info['opponent_name']

# Called when the node enters the scene tree for the first time.
func _ready():
	$MeNameBox.position = start_me_position
	$YouNameBox.position = start_you_position
	var me_tween = get_tree().create_tween()
	me_tween.tween_property($MeNameBox, "position", final_me_position, tween_duration)
	var you_tween = get_tree().create_tween()
	you_tween.tween_property($YouNameBox, "position", final_you_position, tween_duration)
