extends PanelContainer

signal choice_selected(choice_index : int)

func set_choices(instructions_text : String, choices : Array):
	$OuterMargin/MainVBox/InstructionsLabel.text = instructions_text
	var choice_buttons = $OuterMargin/MainVBox/ChoiceButtons.get_children()
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
