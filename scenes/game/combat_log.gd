extends CenterContainer

signal close_button_pressed
signal filter_toggle_update

var DEFAULT_PLAYER_COLOR = "red"
var DEFAULT_OPPONENT_COLOR = "#16c2f7"
var DEFAULT_CARD_COLOR = "#7DF9FF"

@onready var log_text = $PanelContainer/OuterMargin/VerticalLayout/LogText

@onready var toggle_checkboxes = [
	$PanelContainer/OuterMargin/VerticalLayout/LogFilters/Actions,
	$PanelContainer/OuterMargin/VerticalLayout/LogFilters/CardInfo,
	$PanelContainer/OuterMargin/VerticalLayout/LogFilters/Effects,
	$PanelContainer/OuterMargin/VerticalLayout/LogFilters/Strikes,
	$PanelContainer/OuterMargin/VerticalLayout/LogFilters/Damage,
	$PanelContainer/OuterMargin/VerticalLayout/LogFilters/PlayerMovement
]

@onready var player_color_picker = $PanelContainer/OuterMargin/VerticalLayout/LogFilters/PlayerColorPicker
@onready var opponent_color_picker = $PanelContainer/OuterMargin/VerticalLayout/LogFilters/OpponentColorPicker
@onready var card_color_picker = $PanelContainer/OuterMargin/VerticalLayout/LogFilters/CardColorPicker

var log_filter_toggles = {
	Enums.LogType.LogType_CardInfo: get_log_setting('filter_cardinfo'),
	Enums.LogType.LogType_CharacterMovement: get_log_setting('filter_charactermovement'),
	Enums.LogType.LogType_Effect: get_log_setting('filter_effect'),
	Enums.LogType.LogType_Health: get_log_setting('filter_health'),
	Enums.LogType.LogType_Action: get_log_setting('filter_action'),
	Enums.LogType.LogType_Strike: get_log_setting('filter_strike'),
	Enums.LogType.LogType_Default: true
}

var log_player_color = get_log_setting('player_color')
var log_opponent_color = get_log_setting('opponent_color')
var log_card_color = get_log_setting('card_color')

func get_log_setting(setting: String):
	if setting in GlobalSettings.CombatLogSettings:
		return GlobalSettings.CombatLogSettings[setting]
	elif setting.begins_with('filter'):
		return true
	elif setting == "player_color":
		return DEFAULT_PLAYER_COLOR
	elif setting == "opponent_color":
		return DEFAULT_OPPONENT_COLOR
	elif setting == "card_color":
		return DEFAULT_CARD_COLOR
	assert(false, "Unexpected log setting")
	return true

# Called when the node enters the scene tree for the first time.
func _ready():
#	$PanelContainer/OuterMargin/VerticalLayout/LogFilters/Actions,
	toggle_checkboxes[0].set_pressed_no_signal(log_filter_toggles[Enums.LogType.LogType_Action])
#	$PanelContainer/OuterMargin/VerticalLayout/LogFilters/CardInfo,
	toggle_checkboxes[1].set_pressed_no_signal(log_filter_toggles[Enums.LogType.LogType_CardInfo])
#	$PanelContainer/OuterMargin/VerticalLayout/LogFilters/Effects,
	toggle_checkboxes[2].set_pressed_no_signal(log_filter_toggles[Enums.LogType.LogType_Effect])
#	$PanelContainer/OuterMargin/VerticalLayout/LogFilters/Strikes,
	toggle_checkboxes[3].set_pressed_no_signal(log_filter_toggles[Enums.LogType.LogType_Strike])
#	$PanelContainer/OuterMargin/VerticalLayout/LogFilters/Damage,
	toggle_checkboxes[4].set_pressed_no_signal(log_filter_toggles[Enums.LogType.LogType_Health])
#	$PanelContainer/OuterMargin/VerticalLayout/LogFilters/PlayerMovement
	toggle_checkboxes[5].set_pressed_no_signal(log_filter_toggles[Enums.LogType.LogType_CharacterMovement])

	player_color_picker.set_pick_color(log_player_color)
	opponent_color_picker.set_pick_color(log_opponent_color)
	card_color_picker.set_pick_color(log_card_color)

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
	GlobalSettings.set_combat_log_setting('filter_action', state)
	filter_toggle_update.emit()

func _on_log_filter_card_info_toggle(state):
	log_filter_toggles[Enums.LogType.LogType_CardInfo] = state
	GlobalSettings.set_combat_log_setting('filter_cardinfo', state)
	filter_toggle_update.emit()

func _on_log_filter_effects_toggle(state):
	log_filter_toggles[Enums.LogType.LogType_Effect] = state
	GlobalSettings.set_combat_log_setting('filter_effect', state)
	filter_toggle_update.emit()

func _on_log_filter_strikes_toggle(state):
	log_filter_toggles[Enums.LogType.LogType_Strike] = state
	GlobalSettings.set_combat_log_setting('filter_strike', state)
	filter_toggle_update.emit()

func _on_log_filter_health_toggle(state):
	log_filter_toggles[Enums.LogType.LogType_Health] = state
	GlobalSettings.set_combat_log_setting('filter_health', state)
	filter_toggle_update.emit()

func _on_log_filter_player_movement_toggle(state):
	log_filter_toggles[Enums.LogType.LogType_CharacterMovement] = state
	GlobalSettings.set_combat_log_setting('filter_charactermovement', state)
	filter_toggle_update.emit()

func _on_close_button_pressed():
	close_button_pressed.emit()

func _on_copy_button_pressed():
	# Get the current contents of the clipboard
	#var current_clipboard = DisplayServer.clipboard_get()
	# Set the contents of the clipboard
	DisplayServer.clipboard_set(log_text.text)

func _on_player_color_changed(color):
	log_player_color = "#%02x%02x%02x" % [color.r8, color.g8, color.b8]
	GlobalSettings.set_combat_log_setting('player_color', log_player_color)
	filter_toggle_update.emit()

func _on_opponent_color_changed(color):
	log_opponent_color = "#%02x%02x%02x" % [color.r8, color.g8, color.b8]
	GlobalSettings.set_combat_log_setting('opponent_color', log_opponent_color)
	filter_toggle_update.emit()

func _on_card_color_changed(color):
	log_card_color = "#%02x%02x%02x" % [color.r8, color.g8, color.b8]
	GlobalSettings.set_combat_log_setting('card_color', log_card_color)
	filter_toggle_update.emit()
