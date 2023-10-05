extends Node2D
var game : Node2D

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func _on_main_menu_start_game(player_char_index : int, opponent_char_index : int):
	game = load("res://scenes/game/game.tscn").instantiate()
	game.set_characters(player_char_index, opponent_char_index)
	add_child(game)
