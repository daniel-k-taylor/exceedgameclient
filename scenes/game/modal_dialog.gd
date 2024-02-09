extends CenterContainer

signal accept_button_pressed
signal close_button_pressed

@onready var message_label: Label = $PanelContainer/OuterMargin/VerticalLayout/MessageLabel
@onready var accept_button : Button = $PanelContainer/OuterMargin/VerticalLayout/ChoiceButtons/AcceptButton
@onready var cancel_button : Button = $PanelContainer/OuterMargin/VerticalLayout/ChoiceButtons/CancelButton

func set_text_fields(message_text, accept_text, cancel_text):
	message_label.text = message_text
	accept_button.text = accept_text
	cancel_button.text = cancel_text
	cancel_button.visible = cancel_text != ""
	visible = true

func _on_close_button_pressed():
	visible = false
	close_button_pressed.emit()

func _on_accept_button_pressed():
	visible = false
	accept_button_pressed.emit()

