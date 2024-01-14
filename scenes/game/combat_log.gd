extends CenterContainer

signal close_button_pressed

@onready var log_text = $PanelContainer/OuterMargin/VerticalLayout/LogText

func set_text(text):
	log_text.text = text

func _on_close_button_pressed():
	close_button_pressed.emit()

func _on_copy_button_pressed():
	# Get the current contents of the clipboard
	#var current_clipboard = DisplayServer.clipboard_get()
	# Set the contents of the clipboard
	DisplayServer.clipboard_set(log_text.text)
