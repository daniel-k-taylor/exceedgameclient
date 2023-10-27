extends PanelContainer

signal on_pressed(char_id)
signal on_hover(char_id : String, enter : bool)

@export var char_id : String
@export var portrait_texture : Texture

@onready var portrait : TextureRect = $Margin/Portrait

# Called when the node enters the scene tree for the first time.
func _ready():
	portrait.texture = portrait_texture

func _on_button_pressed():
	on_pressed.emit(char_id)

func _on_button_mouse_entered():
	on_hover.emit(char_id, true)

func _on_button_mouse_exited():
	on_hover.emit(char_id, false)
