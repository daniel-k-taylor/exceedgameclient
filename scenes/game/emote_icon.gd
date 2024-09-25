class_name EmoteIcon
extends PanelContainer

signal pressed(image_path)

var image_path

func set_image(new_image_path) -> bool:
	image_path = new_image_path
	var texture = load(image_path)
	if not texture:
		return false
	$EmoteIcon.texture = texture
	return true

func _on_focus_button_pressed():
	pressed.emit(image_path)
