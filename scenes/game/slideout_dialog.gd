class_name SlideoutDialog
extends PanelContainer

signal action_pressed(accept: bool, optional: bool)

@onready var optional_check: CheckBox = $MarginContainer/VBoxContainer/OptionalCheck

func set_fields(message: String, accept_text: String, cancel_text: String, optional_text: String = ""):
	$MarginContainer/VBoxContainer/MessageLabel.text = message
	$MarginContainer/VBoxContainer/AcceptButton.text = accept_text
	$MarginContainer/VBoxContainer/CancelButton.text = cancel_text
	optional_check.text = optional_text
	optional_check.visible = optional_text != ""
	optional_check.button_pressed = false

func _on_accept_button_pressed() -> void:
	action_pressed.emit(true, optional_check.button_pressed)

func _on_cancel_button_pressed() -> void:
	action_pressed.emit(false, optional_check.button_pressed)
