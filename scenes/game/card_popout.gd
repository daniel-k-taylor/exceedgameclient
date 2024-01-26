extends PanelContainer

signal close_window
signal pressed_ok(index)
signal pressed_cancel
signal pressed_toggle

const ColsAtMaxSize = 5
const SlotsAtExpectedCols = 10
const MaxCols = 20
const MaxSlotCount = 40
const DefaultSeparation = 20
const MinSeparation = -220

var used_slots = 0
var total_cols = 0

@onready var instruction_box = $PopoutVBox/HBoxContainer/RestOfThing
@onready var instruction_label = $PopoutVBox/HBoxContainer/RestOfThing/InstructionLabel
@onready var instruction_button_ok = $PopoutVBox/HBoxContainer/RestOfThing/InstructionButtonOk
@onready var instruction_button_ok2 = $PopoutVBox/HBoxContainer/RestOfThing/InstructionButtonOk2
@onready var instruction_button_cancel = $PopoutVBox/HBoxContainer/RestOfThing/InstructionButtonCancel
@onready var toggle_button = $PopoutVBox/ToggleContainer/WithBuffer/ReshuffleToggle

# Called when the node enters the scene tree for the first time.
func _ready():
	clear(0)

func shrink_size():
	reset_size()

func _input(event):
	if (event is InputEventMouseButton) and event.pressed:
		var evLocal = make_input_local(event)
		if !Rect2(Vector2(0,0),size).has_point(evLocal.position):
			close_window.emit()

func set_title(text : String):
	$PopoutVBox/HBoxContainer/TitleLabel.text = text

func set_amount(text : String):
	$PopoutVBox/HBoxContainer/TitleAmount.text = text

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

func set_reference_toggle(toggle_text):
	if toggle_text == "":
		toggle_button.text = "Show cards before reshuffle"
		toggle_button.disabled = true
	else:
		toggle_button.text = toggle_text
		toggle_button.disabled = false

func adjust_spacing():
	if used_slots > SlotsAtExpectedCols:
		@warning_ignore("integer_division")
		var extra_cols = floor((used_slots - SlotsAtExpectedCols) / 2) + 1
		var percent : float = float(extra_cols) / (MaxCols - ColsAtMaxSize)
		var sep = floor(lerpf(DefaultSeparation, MinSeparation, percent))
		$PopoutVBox/Margin/Row.add_theme_constant_override("separation", sep)
	else:
		$PopoutVBox/Margin/Row.add_theme_constant_override("separation", DefaultSeparation)
	shrink_size()

func clear(visible_slots : int):
	# For the currently visible spots, set them invisible.
	for i in range(used_slots):
		var spot = get_spot(i)
		spot.visible = false
		if i % 2 == 0:
			spot.get_parent().visible = spot.visible

	# Update the used slots and column count.
	used_slots = visible_slots
	@warning_ignore("integer_division")
	total_cols = floor((used_slots + 1) / 2)

	# Now set the new used slots visible.
	for i in range(used_slots):
		var spot = get_spot(i)
		spot.visible = true
		spot.get_parent().visible = true

	# Fix up spacing and wait a couple frames to let the container adjust.
	adjust_spacing()
	await get_tree().process_frame
	await get_tree().process_frame

func get_spot(slot_index):
	# Slots should be given out in the order first row then second row.
	var row_num = 0
	var col_num = 0
	@warning_ignore("integer_division")
	if used_slots > 0:
		row_num = floor(slot_index / total_cols)
		col_num = (slot_index % total_cols)
	var col = $PopoutVBox/Margin/Row.get_node("Col%s" % str(col_num + 1))
	var spot = col.get_node("Spot%s" % str(row_num + 1))
	return spot

func get_slot_position(slot_index : int) -> Vector2:
	var spot = get_spot(slot_index)
	var pos = spot.global_position
	return pos

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

