extends PanelContainer

signal choice_selected(choice_index : int)
signal ultra_force_toggled(new_value : bool)

@onready var instructions_label : RichTextLabel = $OuterMargin/MainVBox/PanelContainer/InstructionHBox/InstructionsLabel
@onready var show_image : TextureRect = $OuterMargin/MainVBox/PanelContainer/ShowHideHBox/MarginContainer/MarginContainer/ShowImage
@onready var hide_image : TextureRect = $OuterMargin/MainVBox/PanelContainer/ShowHideHBox/MarginContainer/MarginContainer/HideImage
@onready var choice_buttons_grid : GridContainer = $OuterMargin/MainVBox/ChoiceButtons
@onready var number_panel : PanelContainer = $OuterMargin/MainVBox/NumberSelectionPanel
@onready var number_panel_label : Label = $OuterMargin/MainVBox/NumberSelectionPanel/Hbox/NumberLabel

var showing = true
var number_panel_current_number : int = 0
var number_panel_max : int = 0
var number_panel_min : int = 0

func set_choices(instructions_text : String, choices : Array, ultra_force_toggle : bool, number_picker_min : int, number_picker_max : int):
	$OuterMargin/MainVBox/CheckHBox/UltrasForceOptionCheck.visible = ultra_force_toggle
	var col_count = 1
	if choices.size() > 5:
		col_count = 3
	elif choices.size() > 3:
		col_count = 2
	choice_buttons_grid.columns = col_count

	instructions_label.text = "[center]%s[/center]" % instructions_text
	var choice_buttons = choice_buttons_grid.get_children()
	var total_choices = choices.size()
	for i in range(choice_buttons.size()):
		var button = choice_buttons[i]
		if i < total_choices:
			button.visible = true
			button.disabled = 'disabled' in choices[i] and choices[i].disabled
			button.text = choices[i].text
		else:
			button.disabled = true
			button.visible = false
	reset_size()
	
	if number_picker_min != -1 and number_picker_max != -1:
		number_panel_current_number = 0
		number_panel_min = number_picker_min
		number_panel_max = number_picker_max
		number_panel.visible = true
		number_panel_label.text = str(number_panel_current_number)
	else:
		number_panel.visible = false

func _on_choice_pressed(num : int):
	visible = false
	choice_selected.emit(num)

func _on_show_hide_button_pressed():
	showing = not showing
	show_image.visible = not showing
	hide_image.visible = showing
	choice_buttons_grid.visible = showing

func set_force_ultra_toggle(value):
	$OuterMargin/MainVBox/CheckHBox/UltrasForceOptionCheck.button_pressed = value

func _on_ultras_force_option_check_toggled(button_pressed):
	ultra_force_toggled.emit(button_pressed)

func get_current_number_picker_value():
	return number_panel_current_number

func _on_number_picker_update():
	number_panel_current_number = max(number_panel_current_number, number_panel_min)
	number_panel_current_number = min(number_panel_current_number, number_panel_max)
	number_panel_label.text = str(number_panel_current_number)
	
func _on_minus_button_pressed():
	number_panel_current_number -= 1
	_on_number_picker_update()

func _on_plus_button_pressed():
	number_panel_current_number += 1
	_on_number_picker_update()
