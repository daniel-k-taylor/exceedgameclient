class_name VersusSplash
extends Node2D

var start_me_position = Vector2(-950,20)
var final_me_position = Vector2(50,20)

var start_you_position = Vector2(440 + 1000, 460)
var final_you_position = Vector2(440, 460)

var label_font_normal = 90
var label_font_small = 60
var label_length_threshold = 15

const tween_duration = 1.0

@onready var me_deck_label : Label = $MeNameBox/MeDeckHbox/MyDeckLabel
@onready var you_deck_label : Label = $YouNameBox/YouDeckHbox/YouDeckLabel
@onready var me_portrait : TextureRect = $MeNameBox/MeDeckHbox/MePortrait
@onready var you_portrait : TextureRect = $YouNameBox/YouDeckHbox/YouPortrait

func load_portrait_texture(texture_rect : TextureRect, random_tag : String, deck_id : String):
	match random_tag:
		"random":
			texture_rect.texture = load("res://assets/portraits/exceedrandom.png")
		"random_s1":
			texture_rect.texture = load("res://assets/portraits/redhorizon.png")
		"random_s2":
			texture_rect.texture = load("res://assets/portraits/sclogo.png")
		"random_s3":
			texture_rect.texture = load("res://assets/portraits/sflogo.png")
		"random_s4":
			texture_rect.texture = load("res://assets/portraits/sklogo.png")
		"random_s5":
			texture_rect.texture = load("res://assets/portraits/blazbluelogo2.png")
		"random_s6":
			texture_rect.texture = load("res://assets/portraits/unilogo.png")
		"random_s7":
			texture_rect.texture = load("res://assets/portraits/random.png")
		_:
			if deck_id.begins_with("custom_") and deck_id in ImageCache.loaded_portraits:
				texture_rect.texture = ImageCache.loaded_portraits[deck_id]
			else:
				texture_rect.texture = load("res://assets/portraits/" + deck_id + ".png")
			# fallback
			if not texture_rect.texture:
				texture_rect.texture = load("res://assets/portraits/custom.png")

func set_info(vs_info):
	var my_char_name = vs_info['player_deck']['display_name']
	me_deck_label.text = my_char_name
	if len(my_char_name) <= label_length_threshold:
		me_deck_label.set("theme_override_font_sizes/font_size", label_font_normal)
	else:
		me_deck_label.set("theme_override_font_sizes/font_size", label_font_small)
	$MeNameBox/MyNameLabel.text = vs_info['player_name']

	var your_char_name = vs_info['opponent_deck']['display_name']
	you_deck_label.text = your_char_name
	if len(your_char_name) <= label_length_threshold:
		you_deck_label.set("theme_override_font_sizes/font_size", label_font_normal)
	else:
		you_deck_label.set("theme_override_font_sizes/font_size", label_font_small)
	$YouNameBox/YouNameLabel.text = vs_info['opponent_name']

	# Setup portraits
	var player_deck_id = vs_info['player_deck']['id']
	var player_random_tag = vs_info['player_random_tag']
	var opponent_deck_id = vs_info['opponent_deck']['id']
	var opponent_random_tag = vs_info['opponent_random_tag']
	load_portrait_texture(me_portrait, player_random_tag, player_deck_id)
	load_portrait_texture(you_portrait, opponent_random_tag, opponent_deck_id)

# Called when the node enters the scene tree for the first time.
func _ready():
	$MeNameBox.position = start_me_position
	$YouNameBox.position = start_you_position
	var me_tween = get_tree().create_tween()
	me_tween.tween_property($MeNameBox, "position", final_me_position, tween_duration)
	var you_tween = get_tree().create_tween()
	you_tween.tween_property($YouNameBox, "position", final_you_position, tween_duration)
