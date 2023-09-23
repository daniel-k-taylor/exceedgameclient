extends PanelContainer

signal close_window

const ColsAtMaxSize = 5
const SlotsAtExpectedCols = 10
const MaxCols = 20
const MaxSlotCount = 40
const DefaultSeparation = 20
const MinSeparation = -220

var used_slots = 0

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
	used_slots = visible_slots
	for i in range(MaxSlotCount):
		var spot = get_spot(i)
		spot.visible = i < visible_slots
		if i % 2 == 0:
			spot.get_parent().visible = spot.visible
	adjust_spacing()
	await get_tree().process_frame
	await get_tree().process_frame

func get_spot(slot_index):
	var col_num = (slot_index / 2) + 1
	var spot_num : int = (slot_index % 2) + 1
	var col = $PopoutVBox/Margin/Row.get_node("Col%s" % str(col_num))
	var spot = col.get_node("Spot%s" % str(spot_num))
	return spot

func get_slot_position(slot_index : int) -> Vector2:
	var spot = get_spot(slot_index)
	var pos = spot.global_position
	return pos

func _on_close_window_button_pressed():
	close_window.emit()
