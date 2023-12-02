extends Node2D

var start_me_position = Vector2(-950,20)
var final_me_position = Vector2(50,20)

var start_you_position = Vector2(550 + 1000, 500)
var final_you_position = Vector2(550, 500)

const tween_duration = 1.0

func set_info(vs_info):
	$MeNameBox/MyDeckLabel.text = vs_info['player_deck']['display_name']
	$MeNameBox/MyNameLabel.text = vs_info['player_name']
	$YouNameBox/YouDeckLabel.text = vs_info['opponent_deck']['display_name']
	$YouNameBox/YouNameLabel.text = vs_info['opponent_name']

# Called when the node enters the scene tree for the first time.
func _ready():
	$MeNameBox.position = start_me_position
	$YouNameBox.position = start_you_position
	var me_tween = get_tree().create_tween()
	me_tween.tween_property($MeNameBox, "position", final_me_position, tween_duration)
	var you_tween = get_tree().create_tween()
	you_tween.tween_property($YouNameBox, "position", final_you_position, tween_duration)
