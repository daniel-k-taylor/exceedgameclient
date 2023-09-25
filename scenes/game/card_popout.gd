extends PanelContainer

signal close_window

const ColsAtMaxSize = 5
const SlotsAtExpectedCols = 10
const MaxCols = 20
const MaxSlotCount = 40
const DefaultSeparation = 20
const MinSeparation = -220

var used_slots = 0
var total_cols = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	clear(0)

func shrink_size():
	reset_size()

func set_title(text : String):
	$PopoutVBox/HBoxContainer/TitleLabel.text = text

func set_amount(num : int):
	$PopoutVBox/HBoxContainer/TitleAmount.text = str(num)

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
