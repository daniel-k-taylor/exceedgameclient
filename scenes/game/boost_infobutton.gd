class_name BoostInfoButton
extends HBoxContainer

@onready var container : PanelContainer = $BackgroundPanel
@onready var label : Label = $BackgroundPanel/MarginContainer/HBoxContainer/Label

func _ready():
	reset()

func reset():
	set_visibility(false)
	set_number(0)

func set_visibility(set_to_visible : bool):
	container.visible = set_to_visible

func set_number(number : int):
	label.text = str(number)
