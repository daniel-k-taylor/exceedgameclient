class_name PreferencesWindow
extends PopupPanel

signal bgm_check_toggled

@onready var timer_selection = $VBoxContainer/StartingTimersSelection
@onready var best_of_selection = $VBoxContainer/BestOfSelection
@onready var enforce_timer_checkbutton = $VBoxContainer/EnforceTimerCheckbutton
@onready var minimum_time_selection = $VBoxContainer/MinimumTimeSelection
@onready var bgm_checkbutton = $VBoxContainer/BGMCheckbutton
@onready var game_sound_checkbutton = $VBoxContainer/GameSoundsCheckbutton
@onready var ai_first_player_checkbutton = $VBoxContainer/AIFirstPlayerCheckbutton
@onready var replay_show_opponent_hand_button = $VBoxContainer/ReplayShowOpponentHandButton
@onready var true_random_checkbutton = $VBoxContainer/TrueRandomSelectCheckbox

# Called when the node enters the scene tree for the first time.
func _ready():
	GlobalSettings.settings_loaded.connect(display_loaded_settings)
	# Populate the possible custom game timer selections
	for mins in [1, 6, 9, 12, 15, 20, 25, 30]:
		timer_selection.add_item("%s:00" % mins, mins*60)
	timer_selection.select(timer_selection.get_item_index(GlobalSettings.CustomStartingTimer))

	# Populate the possible minimum time per choice selections
	for secs in [0, 10, 15, 20, 25, 30, 45, 60]:
		minimum_time_selection.add_item("%02d:%02d" % [secs / 60, secs % 60], secs)

func display_loaded_settings():
	best_of_selection.select(best_of_selection.get_item_index((GlobalSettings.CustomBestOf)))
	enforce_timer_checkbutton.set_pressed_no_signal(GlobalSettings.CustomEnforceTimer)
	bgm_checkbutton.set_pressed_no_signal(GlobalSettings.BGMEnabled)
	ai_first_player_checkbutton.set_pressed_no_signal(GlobalSettings.RandomizeFirstVsAI)
	game_sound_checkbutton.set_pressed_no_signal(GlobalSettings.GameSoundsEnabled)
	timer_selection.select(timer_selection.get_item_index(GlobalSettings.CustomStartingTimer))
	minimum_time_selection.select(minimum_time_selection.get_item_index((GlobalSettings.CustomMinimumTimePerChoice)))
	replay_show_opponent_hand_button.set_pressed_no_signal(GlobalSettings.ReplayShowOpponentHand)
	true_random_checkbutton.set_pressed_no_signal(GlobalSettings.IgnoreRandomHistory)

func _on_bgm_check_box_toggled(button_pressed):
	GlobalSettings.set_bgm(button_pressed)
	bgm_check_toggled.emit()

func _on_game_sounds_check_box_toggled(button_pressed):
	GlobalSettings.set_game_sounds_enabled(button_pressed)

func _on_starting_timers_selection_item_selected(_index):
	GlobalSettings.set_starting_timers($VBoxContainer/StartingTimersSelection.get_selected_id())

func _on_enforce_timer_check_box_toggled(toggled_on):
	GlobalSettings.set_enforce_timers(toggled_on)

func _on_minimum_time_selection_item_selected(_index):
	GlobalSettings.set_minimum_time_per_choice($VBoxContainer/MinimumTimeSelection.get_selected_id())

func _on_ai_first_player_checkbutton_toggled(button_pressed):
	GlobalSettings.set_randomize_first_player_vs_ai(button_pressed)

func _on_replay_show_opponent_hand_button_toggled(button_pressed):
	GlobalSettings.set_replay_show_opponent_hand(button_pressed)

func _on_true_random_select_checkbox_toggled(button_pressed: bool) -> void:
	GlobalSettings.set_ignore_random_history(button_pressed)
