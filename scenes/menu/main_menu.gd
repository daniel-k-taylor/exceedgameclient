extends Control

signal start_game(player_char_index, opponent_char_index)

@onready var player_select : OptionButton = $PlayerChooser/Margin/VBox/PlayerCharSelect
@onready var opponent_select : OptionButton = $OpponentChooser/Margin/VBox/OpponentCharSelect

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func _on_start_button_pressed():
	start_game.emit(player_select.selected, opponent_select.selected)

func _on_quit_button_pressed():
	get_tree().quit()
