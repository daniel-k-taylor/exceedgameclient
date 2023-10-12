extends Node2D
var game : Node2D
var splash : Node2D

const VersusSplash = preload("res://scenes/menu/versus_splash.gd")
const VersusSplashScene = preload("res://scenes/menu/versus_splash.tscn")

const GameScene = preload("res://scenes/game/game.tscn")

const VersusSplashTimeout = 3.0

# Called when the node enters the scene tree for the first time.
func _ready():
	NetworkManager.connect_to_server()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func _on_return_from_game():
	$MainMenu.returned_from_game()

func _on_splash_timeout():
	print("Timeout finished!")
	remove_child(splash)
	splash = null

func create_versus_splash(vs_info):
	splash = VersusSplashScene.instantiate()
	add_child(splash)
	splash.set_info(vs_info)
	var timer := Timer.new()
	timer.wait_time = VersusSplashTimeout
	timer.one_shot = true
	timer.connect("timeout", _on_splash_timeout)
	add_child(timer)
	timer.start()
	

func _on_main_menu_start_game(vs_info, player_char_index : int, opponent_char_index : int):
	game = GameScene.instantiate()
	game.begin_local_game(player_char_index, opponent_char_index)
	add_child(game)
	create_versus_splash(vs_info)

func _on_main_menu_start_remote_game(vs_info, data):
	game = GameScene.instantiate()
	game.connect("returning_from_game", _on_return_from_game)
	game.begin_remote_game(data)
	add_child(game)
	create_versus_splash(vs_info)
