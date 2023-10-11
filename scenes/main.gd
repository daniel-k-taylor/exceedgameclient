extends Node2D
var game : Node2D

# Called when the node enters the scene tree for the first time.
func _ready():
	NetworkManager.connect_to_server(true)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func _on_return_from_game():
	$MainMenu.returned_from_game()

func _on_main_menu_start_game(player_char_index : int, opponent_char_index : int):
	game = load("res://scenes/game/game.tscn").instantiate()
	game.begin_local_game(player_char_index, opponent_char_index)
	add_child(game)


func _on_main_menu_start_remote_game(data):
	game = load("res://scenes/game/game.tscn").instantiate()
	game.connect("returning_from_game", _on_return_from_game)
	game.begin_remote_game(data)
	add_child(game)
