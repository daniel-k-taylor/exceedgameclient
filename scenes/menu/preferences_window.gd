class_name PreferencesWindow
extends PopupPanel

const GameBackgroundManager = preload("res://globals/game_background_manager.gd")

signal bgm_check_toggled
signal main_menu_background_changed

## Largest size the window is allowed to take. Shrunk to fit at runtime so the
## panel never runs off a small (or mobile browser) viewport.
const MaxWindowSize := Vector2i(1040, 660)
const MinWindowSize := Vector2i(420, 320)

@onready var timer_selection = %StartingTimersSelection
@onready var best_of_selection = %BestOfSelection
@onready var enforce_timer_checkbutton = %EnforceTimerCheckbutton
@onready var minimum_time_selection = %MinimumTimeSelection
@onready var bgm_checkbutton = %BGMCheckbutton
@onready var game_sound_checkbutton = %GameSoundsCheckbutton
@onready var ai_first_player_checkbutton = %AIFirstPlayerCheckbutton
@onready var ai_mode_selection = %AIModeSelection
@onready var replay_show_opponent_hand_button = %ReplayShowOpponentHandButton
@onready var true_random_checkbutton = %TrueRandomSelectCheckbox
@onready var action_confirmation_button = %ActionConfirmationButton
@onready var fullscreen_button = %FullscreenButton
@onready var arena_style_selection = %ArenaStyleSelection
@onready var menu_background_selection = %MenuBackgroundSelection

# Called when the node enters the scene tree for the first time.
func _ready():
	GlobalSettings.settings_loaded.connect(display_loaded_settings)
	about_to_popup.connect(_fit_to_screen)
	visibility_changed.connect(_on_visibility_changed)
	# Populate the possible custom game timer selections
	for mins in [1, 6, 9, 12, 15, 20, 25, 30]:
		timer_selection.add_item("%s:00" % mins, mins*60)
	timer_selection.select(timer_selection.get_item_index(GlobalSettings.CustomStartingTimer))

	# Populate the possible minimum time per choice selections
	for secs in [0, 10, 15, 20, 25, 30, 45, 60]:
		minimum_time_selection.add_item("%02d:%02d" % [secs / 60, secs % 60], secs)

	# AI difficulty. id 0 = rules (fair/beginner), id 1 = omniscient (cheats).
	ai_mode_selection.add_item("Beginner", 0)
	ai_mode_selection.add_item("Super (cheats)", 1)

	# Arena background style. Only styles with art on disk render fully; the
	# rest degrade to the classic board look.
	_populate_background_selection(arena_style_selection,
		GameBackgroundManager.get_background_ids(),
		Callable(GameBackgroundManager, "get_background_label"))
	# Main-menu background style.
	_populate_background_selection(menu_background_selection,
		GameBackgroundManager.get_main_menu_background_ids(),
		Callable(GameBackgroundManager, "get_main_menu_background_label"))

	_fit_to_screen()

func _on_visibility_changed():
	if visible:
		_fit_to_screen()

## Clamps the popup to the available screen/viewport so it can never render
## off the bottom edge. Content scrolls if it does not fit.
func _fit_to_screen():
	var available := Vector2i(MaxWindowSize)
	if get_tree() != null and get_tree().root != null:
		if is_embedded():
			# Embedded (web/mobile): sized in the stretched canvas coordinate space.
			available = Vector2i(get_tree().root.get_visible_rect().size)
		else:
			# Native subwindow: sized in real screen pixels.
			available = DisplayServer.screen_get_usable_rect(
				DisplayServer.window_get_current_screen()).size

	# Shrink to the height the sections actually need. The ScrollContainer
	# reports no minimum height of its own, so add the columns' height in.
	var desired := Vector2i(MaxWindowSize)
	var root_margin := get_node_or_null("Root") as Control
	var columns := get_node_or_null("Root/Main/Scroll/Columns") as Control
	if root_margin != null and columns != null:
		desired.y = int(ceil(root_margin.get_combined_minimum_size().y
			+ columns.get_combined_minimum_size().y)) + 8

	size = Vector2i(
		clampi(mini(desired.x, available.x - 40), MinWindowSize.x, MaxWindowSize.x),
		clampi(mini(desired.y, available.y - 40), MinWindowSize.y, MaxWindowSize.y))

func _populate_background_selection(option_button : OptionButton, background_ids : Array, label_getter : Callable):
	option_button.clear()
	for index in range(background_ids.size()):
		var background_id : String = background_ids[index]
		option_button.add_item(label_getter.call(background_id))
		option_button.set_item_metadata(index, background_id)

func _select_background_in_option(option_button : OptionButton, background_id : String):
	for index in range(option_button.item_count):
		if option_button.get_item_metadata(index) == background_id:
			option_button.select(index)
			return
	if option_button.item_count > 0:
		option_button.select(0)

func display_loaded_settings():
	best_of_selection.select(best_of_selection.get_item_index((GlobalSettings.CustomBestOf)))
	enforce_timer_checkbutton.set_pressed_no_signal(GlobalSettings.CustomEnforceTimer)
	bgm_checkbutton.set_pressed_no_signal(GlobalSettings.BGMEnabled)
	ai_first_player_checkbutton.set_pressed_no_signal(GlobalSettings.RandomizeFirstVsAI)
	ai_mode_selection.select(1 if GlobalSettings.AIMode == "omniscient" else 0)
	game_sound_checkbutton.set_pressed_no_signal(GlobalSettings.GameSoundsEnabled)
	timer_selection.select(timer_selection.get_item_index(GlobalSettings.CustomStartingTimer))
	minimum_time_selection.select(minimum_time_selection.get_item_index((GlobalSettings.CustomMinimumTimePerChoice)))
	replay_show_opponent_hand_button.set_pressed_no_signal(GlobalSettings.ReplayShowOpponentHand)
	true_random_checkbutton.set_pressed_no_signal(GlobalSettings.IgnoreRandomHistory)
	action_confirmation_button.set_pressed_no_signal(GlobalSettings.ActionConfirmationEnabled)
	_select_background_in_option(arena_style_selection,
		GameBackgroundManager.get_selectable_background_id(GlobalSettings.ArenaStyle))
	_select_background_in_option(menu_background_selection,
		GameBackgroundManager.normalize_main_menu_background_id(GlobalSettings.MainMenuBackgroundStyle))
	_refresh_fullscreen_button()

func _refresh_fullscreen_button():
	if fullscreen_button == null:
		return
	if not GlobalSettings.can_request_fullscreen():
		fullscreen_button.disabled = true
		fullscreen_button.text = "Fullscreen unsupported"
		return
	fullscreen_button.disabled = false
	fullscreen_button.text = "Exit Fullscreen" if GlobalSettings.is_fullscreen() else "Enter Fullscreen"

func _on_action_confirmation_button_toggled(button_pressed):
	GlobalSettings.set_action_confirmation_enabled(button_pressed)

func _on_fullscreen_button_pressed():
	GlobalSettings.toggle_fullscreen()
	_refresh_fullscreen_button()

func _on_bgm_check_box_toggled(button_pressed):
	GlobalSettings.set_bgm(button_pressed)
	bgm_check_toggled.emit()

func _on_game_sounds_check_box_toggled(button_pressed):
	GlobalSettings.set_game_sounds_enabled(button_pressed)

func _on_starting_timers_selection_item_selected(_index):
	GlobalSettings.set_starting_timers(timer_selection.get_selected_id())

func _on_enforce_timer_check_box_toggled(toggled_on):
	GlobalSettings.set_enforce_timers(toggled_on)

func _on_minimum_time_selection_item_selected(_index):
	GlobalSettings.set_minimum_time_per_choice(minimum_time_selection.get_selected_id())

func _on_ai_first_player_checkbutton_toggled(button_pressed):
	GlobalSettings.set_randomize_first_player_vs_ai(button_pressed)

func _on_ai_mode_selection_item_selected(_index):
	var ai_mode := "omniscient" if ai_mode_selection.get_selected_id() == 1 else "rules"
	GlobalSettings.set_ai_mode(ai_mode)

func _on_arena_style_selection_item_selected(index):
	var background_id = arena_style_selection.get_item_metadata(index)
	if background_id == null:
		return
	GlobalSettings.set_arena_style(str(background_id))

func _on_menu_background_selection_item_selected(index):
	var background_id = menu_background_selection.get_item_metadata(index)
	if background_id == null:
		return
	GlobalSettings.set_main_menu_background_style(str(background_id))
	main_menu_background_changed.emit()

func _on_replay_show_opponent_hand_button_toggled(button_pressed):
	GlobalSettings.set_replay_show_opponent_hand(button_pressed)

func _on_true_random_select_checkbox_toggled(button_pressed: bool) -> void:
	GlobalSettings.set_ignore_random_history(button_pressed)

func _on_close_button_pressed():
	hide()
