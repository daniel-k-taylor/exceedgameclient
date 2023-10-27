extends Control

signal select_character(char_id)
signal close_character_select

@onready var hover_label : Label = $HoverBox/HBoxContainer/VBoxContainer/Label
@onready var hover_portrait : TextureRect = $HoverBox/HBoxContainer/VBoxContainer/Portrait

var default_char_id : String = "random"

func update_hover(char_id):
	if char_id == "random":
		hover_label.text = "Random"
		hover_portrait.texture = load("res://assets/portraits/" + char_id + ".png")
	else:
		var deck = CardDefinitions.get_deck_from_str_id(char_id)
		hover_label.text = deck['display_name']
		hover_portrait.texture = load("res://assets/portraits/" + char_id + ".png")
	
func show_char_select(char_id : String):
	default_char_id = char_id
	update_hover(char_id)

func _on_background_button_pressed():
	close_character_select.emit()

func _on_character_button_pressed(character_id : String):
	select_character.emit(character_id)

func _on_char_button_on_pressed(character_id : String):
	select_character.emit(character_id)

func _on_char_hover(char_id : String, enter : bool):
	if enter:
		update_hover(char_id)
	else:
		update_hover(default_char_id)
