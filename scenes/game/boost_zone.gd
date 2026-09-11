class_name BoostZone
extends Node2D

signal clicked_zone

# The summary grows with the number of active boosts. Cap it so the opponent's
# zone never covers the leftmost arena square (clickable at y ~310) and the
# player's zone never covers the Exit to Menu button (y ~652). Anything longer
# than the cap scrolls.
const MaxEffectsHeight : float = 180.0
const ScrollWheelStep : float = 32.0

@onready var focus_button : TextureButton = $OuterMargin/Focus
@onready var effects_label : RichTextLabel = $OuterMargin/BoostPanel/InnerMargin/BoostVBox/BoostEffects

func _ready():
	effects_label.resized.connect(_update_effects_height)
	_update_effects_height()

func _on_focus_pressed():
	clicked_zone.emit()

func _on_focus_gui_input(event):
	# The focus button covers the whole zone, so the summary label never sees
	# the mouse wheel on its own; forward it so a capped summary can scroll.
	if not (event is InputEventMouseButton and event.pressed):
		return
	var scroll_bar := effects_label.get_v_scroll_bar()
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		scroll_bar.value -= ScrollWheelStep
		focus_button.accept_event()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		scroll_bar.value += ScrollWheelStep
		focus_button.accept_event()

func set_text(text):
	effects_label.text = text
	_update_effects_height()

func _update_effects_height():
	if not is_node_ready():
		return
	var content_height : float = effects_label.get_content_height()
	var desired : float = content_height
	if content_height > MaxEffectsHeight:
		# Snap the cap to whole lines so the summary never ends on a half-drawn
		# row of text.
		desired = MaxEffectsHeight
		var line_count : int = effects_label.get_line_count()
		if line_count > 0:
			var line_height : float = content_height / line_count
			if line_height > 0:
				desired = maxf(line_height, floorf(MaxEffectsHeight / line_height) * line_height)
	if not is_equal_approx(effects_label.custom_minimum_size.y, desired):
		effects_label.custom_minimum_size.y = desired
