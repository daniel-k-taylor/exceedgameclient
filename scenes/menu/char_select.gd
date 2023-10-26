extends Control

signal select_character(char_id)
signal close_character_select

func _on_background_button_pressed():
	close_character_select.emit()

func _on_character_button_pressed(character_id):
	select_character.emit(character_id)
