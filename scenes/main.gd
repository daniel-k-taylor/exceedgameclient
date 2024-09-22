extends Node2D
var game : Node2D
var splash : Node2D

const VersusSplash = preload("res://scenes/menu/versus_splash.gd")
const VersusSplashScene = preload("res://scenes/menu/versus_splash.tscn")

const GameScene = preload("res://scenes/game/game.tscn")

const VersusSplashTimeout = 3.0


# Called when the node enters the scene tree for the first time.
func _ready():
	GlobalSettings.load_persistent_settings()
	ImageCache.load_image_cache()
	$MainMenu.settings_loaded()
	NetworkManager.connect_to_server()

	var http_request = HTTPRequest.new()
	add_child(http_request)

func _on_return_from_game():
	$MainMenu.visible = true
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


func _on_main_menu_start_game(vs_info):
	$MainMenu.visible = false
	$MainMenu.stop_music()
	game = GameScene.instantiate()
	game.connect("returning_from_game", _on_return_from_game)
	game.set_not_started_directly()
	add_child(game)
	game.begin_local_game(vs_info)
	game.initialization_after_begin_game()
	create_versus_splash(vs_info)

# Listens for a signal from _start_remote_game in main_menu.
func _on_main_menu_start_remote_game(vs_info, data):
	$MainMenu.visible = false
	$MainMenu.stop_music()
	game = GameScene.instantiate()
	game.connect("returning_from_game", _on_return_from_game)
	game.set_not_started_directly()
	add_child(game)
	game.begin_remote_game(data)
	game.initialization_after_begin_game()
	create_versus_splash(vs_info)
