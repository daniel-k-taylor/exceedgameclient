extends PopupPanel

@onready var timer_selection = $VBoxContainer/StartingTimersSelection
@onready var best_of_selection = $VBoxContainer/BestOfSelection

# Called when the node enters the scene tree for the first time.
func _ready():
	timer_selection.select(timer_selection.get_item_index(GlobalSettings.CustomStartingTimer))
	best_of_selection.select(best_of_selection.get_item_index((GlobalSettings.CustomStartingBestOf)))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func _on_bgm_check_box_toggled(button_pressed):
	GlobalSettings.set_bgm(button_pressed)

func _on_game_sounds_check_box_toggled(button_pressed):
	GlobalSettings.set_game_sounds_enabled(button_pressed)

func _on_starting_timers_selection_item_selected(_index):
	GlobalSettings.CustomStartingTimer = $VBoxContainer/StartingTimersSelection.get_selected_id()

func _on_enforce_timer_check_box_toggled(toggled_on):
	GlobalSettings.EnforceTimer = toggled_on
