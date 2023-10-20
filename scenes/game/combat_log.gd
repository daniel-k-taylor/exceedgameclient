extends CenterContainer

signal close_button_pressed

@onready var log_text = $PanelContainer/OuterMargin/VerticalLayout/LogText

func set_text(text):
	log_text.text = text

func _on_close_button_pressed():
	close_button_pressed.emit()
