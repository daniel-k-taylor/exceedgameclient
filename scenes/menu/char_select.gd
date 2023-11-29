extends Control

signal select_character(char_id)
signal close_character_select

@onready var hover_label : Label = $HoverBox/HBoxContainer/VBoxContainer/Label
@onready var hover_portrait : TextureRect = $HoverBox/HBoxContainer/VBoxContainer/Portrait

@onready var charselect_s5 = $CenterContainer/BBCharacterSelect
@onready var charselect_s7 = $CenterContainer/GGCharacterSelect

@onready var season_button_s5 = $TabSelect/CategoriesHBox/Season5
@onready var season_button_s7 = $TabSelect/CategoriesHBox/Season7

var default_char_id : String = "random"

func _ready():
	show_season(charselect_s7, season_button_s7)

func update_hover(char_id):
	if char_id == "random_s7":
		hover_label.text = "Random"
		hover_portrait.texture = load("res://assets/portraits/random.png")
	elif char_id == "random_s5":
		hover_label.text = "Random"
		hover_portrait.texture = load("res://assets/portraits/blazbluelogo2.png")
	elif char_id == "random":
		hover_label.text = "Random"
		hover_portrait.texture = load("res://assets/portraits/random.png")
	else:
		var deck = CardDefinitions.get_deck_from_str_id(char_id)
		hover_label.text = deck['display_name']
		hover_portrait.texture = load("res://assets/portraits/" + char_id + ".png")
	
func show_char_select(char_id : String):
	default_char_id = char_id
	update_hover(char_id)

func _on_background_button_pressed():
	close_character_select.emit()

func show_season(node, selector_button):
	charselect_s5.visible = false
	charselect_s7.visible = false
	node.visible = true

	season_button_s5.set_selected(false)
	season_button_s7.set_selected(false)
	selector_button.set_selected(true)

func _on_char_button_on_pressed(character_id : String):
	if character_id.begins_with("season"):
		# Get the int season from the last character of the str.
		if character_id == "season5":
			show_season(charselect_s5, season_button_s5)
		elif character_id == "season7":
			show_season(charselect_s7, season_button_s7)
	else:
		select_character.emit(character_id)

func _on_char_hover(char_id : String, enter : bool):
	if char_id.begins_with("season"):
		return
		
	if enter:
		update_hover(char_id)
	else:
		update_hover(default_char_id)
