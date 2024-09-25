class_name LocationInfoButtonPair
extends HBoxContainer

signal button_pressed(player)

@onready var p1_container : PanelContainer = $PlayerInfo1
@onready var p2_container : PanelContainer = $PlayerInfo2
@onready var p1_button : TextureButton = $PlayerInfo1/P1Button
@onready var p2_button : TextureButton = $PlayerInfo2/P2Button
@onready var p1_label : Label = $PlayerInfo1/MarginContainer/HBoxContainer/P1Label
@onready var p2_label : Label = $PlayerInfo2/MarginContainer/HBoxContainer/P2Label

const visible_color = Color(1,1,1,1)
const hidden_color = Color(1,1,1,0)

func _ready():
	_set_number_internal(p1_container, p1_button, p1_label, 0)
	_set_number_internal(p2_container, p2_button, p2_label, 0)

func _set_number_internal(container, button, label, number):
	var show_panel = number > 0
	label.text = str(number)
	button.disabled = not show_panel
	if show_panel:
		container.modulate = visible_color
		button.mouse_filter = MOUSE_FILTER_STOP
	else:
		container.modulate = hidden_color
		button.mouse_filter = MOUSE_FILTER_IGNORE

func set_number(player : Enums.PlayerId, number : int):
	if player == Enums.PlayerId.PlayerId_Player:
		_set_number_internal(p1_container, p1_button, p1_label, number)
	else:
		_set_number_internal(p2_container, p2_button, p2_label, number)

func _on_p_1_button_pressed():
	button_pressed.emit(Enums.PlayerId.PlayerId_Player)

func _on_p_2_button_pressed():
	button_pressed.emit(Enums.PlayerId.PlayerId_Opponent)
