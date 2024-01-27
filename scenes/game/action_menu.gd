extends PanelContainer

signal choice_selected(choice_index : int)

@onready var instructions_label : Label = $OuterMargin/MainVBox/PanelContainer/InstructionHBox/InstructionsLabel
@onready var show_image : TextureRect = $OuterMargin/MainVBox/PanelContainer/ShowHideHBox/MarginContainer/MarginContainer/ShowImage
@onready var hide_image : TextureRect = $OuterMargin/MainVBox/PanelContainer/ShowHideHBox/MarginContainer/MarginContainer/HideImage
@onready var choice_buttons_grid : GridContainer = $OuterMargin/MainVBox/ChoiceButtons

var showing = true

func set_choices(instructions_text : String, choices : Array):
	var col_count = 1
	if choices.size() > 5:
		col_count = 3
	elif choices.size() > 3:
		col_count = 2
	choice_buttons_grid.columns = col_count

	instructions_label.text = instructions_text
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

func _on_choice_pressed(num : int):
	visible = false
	choice_selected.emit(num)

func _on_show_hide_button_pressed():
	showing = not showing
	show_image.visible = not showing
	hide_image.visible = showing
	choice_buttons_grid.visible = showing
	
