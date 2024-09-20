extends Control

signal close_window
signal pressed_ok(index)
signal pressed_cancel
signal pressed_toggle
signal card_clicked(card_id)

const ColsAtMaxSize = 5
const SlotsAtExpectedCols = 10
const MaxCols = 20
const MaxSlotCount = 40
const DefaultSeparation = 0
const MinSeparation = -120

var used_slots = 0
var total_cols = 0

const CardBaseScene = preload("res://scenes/card/card_base.tscn")
const CardBase = preload("res://scenes/card/card_base.gd")

@onready var instruction_box = $PopoutContainer/PopoutVBox/RestOfThing
@onready var instruction_label = $PopoutContainer/PopoutVBox/RestOfThing/InstructionLabel
@onready var instruction_button_ok = $PopoutContainer/PopoutVBox/RestOfThing/InstructionButtonOk
@onready var instruction_button_ok2 = $PopoutContainer/PopoutVBox/RestOfThing/InstructionButtonOk2
@onready var instruction_button_cancel = $PopoutContainer/PopoutVBox/RestOfThing/InstructionButtonCancel
@onready var toggle_container = $PopoutContainer/PopoutVBox/ToggleContainer
@onready var toggle_button = $PopoutContainer/PopoutVBox/ToggleContainer/WithBuffer/ReshuffleToggle
@onready var title_label = $PopoutContainer/PopoutVBox/HBoxContainer/TitleLabel
@onready var title_amount = $PopoutContainer/PopoutVBox/HBoxContainer/TitleAmount
@onready var rows = $PopoutContainer/PopoutVBox/Margin/Rows
@onready var popout_container = $PopoutContainer

func _input(event):
	if (event is InputEventMouseButton) and event.pressed:
		var evLocal = make_input_local(event)
		if !Rect2(Vector2(0,0),popout_container.size).has_point(evLocal.position):
			close_window.emit()

func set_title(text : String):
	title_label.text = text

func set_amount(text : String):
	title_amount.text = text

func set_instructions(instruction_info):
	if instruction_info == null:
		instruction_box.visible = false
	else:
		instruction_box.visible = true
		var instruction_text = instruction_info['instruction_text']
		var ok_text = instruction_info['ok_text']
		var cancel_text = instruction_info['cancel_text']
		var ok_enabled = instruction_info['ok_enabled']
		var cancel_visible = instruction_info['cancel_visible']
		var ok2_text = ""
		if 'ok2_text' in instruction_info:
			ok2_text = instruction_info['ok2_text']

		instruction_label.text = instruction_text
		instruction_button_ok.text = ok_text
		instruction_button_ok.disabled = not ok_enabled
		instruction_button_ok2.visible = ok2_text != ""
		instruction_button_ok2.text = ok2_text
		instruction_button_ok2.disabled = not ok_enabled
		instruction_button_cancel.visible = cancel_visible
		instruction_button_cancel.text = cancel_text

func set_reference_toggle(toggle_text, toggle_visible):
	toggle_container.visible = toggle_visible
	if toggle_text == "":
		toggle_button.text = "Show cards before reshuffle"
		toggle_button.disabled = true
	else:
		toggle_button.text = toggle_text
		toggle_button.disabled = false

func show_cards(cards : Array):
	var total_cards = len(cards)
	used_slots = total_cards
	total_cols = min(ceil(total_cards / 2.0), MaxCols)
	for i in range(total_cards):
		var card = cards[i]
		var new_card = CardBaseScene.instantiate()
		new_card.clicked_card.connect(on_card_clicked)
		var spot = get_spot(i)
		spot.add_child(new_card)
		new_card.initialize_simple(card.card_id, card.card_image, card.cardback_image,
			card.card_url_loaded_image, card.card_attack_name, card.card_boost_name)
		new_card.flip_card_to_front(true)

		var label = card.get_label()
		if label:
			new_card.set_label(label)

		var remaining_count = card.get_remaining_count()
		if remaining_count != -1:
			new_card.set_remaining_count(remaining_count)

		var icon_state = card.get_hand_icon_state()
		if icon_state:
			new_card.update_hand_icons_from_state(icon_state)

	adjust_spacing()
	popout_container.reset_size()

	for i in range(total_cards):
		var spot = get_spot(i)
		var card : CardBase = spot.get_child(0)
		var pos = Vector2(0,0)
		var adjusted_pos = pos + CardBase.ReferenceCardScale * CardBase.ActualCardSize / 2
		card.set_card_and_focus(adjusted_pos, null, null)
		card.change_state(CardBase.CardState.CardState_InPopout)
		card.set_resting_position(adjusted_pos, 0)

func modify_card_selection(card_id, selected):
	for row in rows.get_children():
		for spot in row.get_children():
			if spot.get_child_count() == 0:
				continue
			var card : CardBase = spot.get_child(0)
			if card.card_id == card_id:
				card.set_selected(selected)

func adjust_spacing():
	for child in rows.get_children():
		if used_slots > SlotsAtExpectedCols:
			var extra_cols = floor((used_slots - SlotsAtExpectedCols) / 2.0) + 1
			var percent : float = float(extra_cols) / (MaxCols - ColsAtMaxSize)
			var sep = floor(lerpf(DefaultSeparation, MinSeparation, percent))
			child.add_theme_constant_override("separation", sep)
		else:
			child.add_theme_constant_override("separation", DefaultSeparation)

func get_spot(slot_index):
	var row_num = 0
	var col_num = slot_index
	if slot_index >= total_cols:
		row_num = 1
		col_num = slot_index - total_cols
	var row = rows.get_child(row_num)
	var col = row.get_child(col_num)
	col.visible = true
	return col

func on_card_clicked(card : CardBase):
	card_clicked.emit(card.card_id)

func _on_close_window_button_pressed():
	close_window.emit()

func _on_instruction_button_ok_pressed():
	pressed_ok.emit(0)

func _on_instruction_button_ok2_pressed():
	pressed_ok.emit(1)

func _on_instruction_button_cancel_pressed():
	pressed_cancel.emit()

func _on_reshuffle_toggle_pressed():
	pressed_toggle.emit()

