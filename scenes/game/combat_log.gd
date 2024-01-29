extends CenterContainer

signal close_button_pressed
signal filter_toggle_update

const Enums = preload("res://scenes/game/enums.gd")

@onready var log_text = $PanelContainer/OuterMargin/VerticalLayout/LogText

@onready var toggle_checkboxes = [
	$PanelContainer/OuterMargin/VerticalLayout/LogFilters/Actions,
	$PanelContainer/OuterMargin/VerticalLayout/LogFilters/CardInfo,
	$PanelContainer/OuterMargin/VerticalLayout/LogFilters/Effects,
	$PanelContainer/OuterMargin/VerticalLayout/LogFilters/Strikes,
	$PanelContainer/OuterMargin/VerticalLayout/LogFilters/Damage,
	$PanelContainer/OuterMargin/VerticalLayout/LogFilters/PlayerMovement
]

var log_filter_toggles = {
	Enums.LogType.LogType_CardInfo: true,
	Enums.LogType.LogType_CharacterMovement: true,
	Enums.LogType.LogType_Effect: true,
	Enums.LogType.LogType_Health: true,
	Enums.LogType.LogType_Action: true,
	Enums.LogType.LogType_Strike: true,
	Enums.LogType.LogType_Default: true
}

var log_player_color = "red"
var log_opponent_color = "#16c2f7"

func set_text(text):
	log_text.text = text

func get_filters():
	var filters = []
	for log_type in log_filter_toggles:
		if log_filter_toggles[log_type]:
			filters.append(log_type)
	return filters

func _on_log_filter_actions_toggle(state):
	log_filter_toggles[Enums.LogType.LogType_Action] = state
	filter_toggle_update.emit()

func _on_log_filter_card_info_toggle(state):
	log_filter_toggles[Enums.LogType.LogType_CardInfo] = state
	filter_toggle_update.emit()

func _on_log_filter_effects_toggle(state):
	log_filter_toggles[Enums.LogType.LogType_Effect] = state
	filter_toggle_update.emit()

func _on_log_filter_strikes_toggle(state):
	log_filter_toggles[Enums.LogType.LogType_Strike] = state
	filter_toggle_update.emit()

func _on_log_filter_health_toggle(state):
	log_filter_toggles[Enums.LogType.LogType_Health] = state
	filter_toggle_update.emit()

func _on_log_filter_player_movement_toggle(state):
	log_filter_toggles[Enums.LogType.LogType_CharacterMovement] = state
	filter_toggle_update.emit()

func _on_close_button_pressed():
	close_button_pressed.emit()

func _on_copy_button_pressed():
	# Get the current contents of the clipboard
	#var current_clipboard = DisplayServer.clipboard_get()
	# Set the contents of the clipboard
	DisplayServer.clipboard_set(log_text.text)
