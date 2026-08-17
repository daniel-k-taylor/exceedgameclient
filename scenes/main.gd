extends Node2D
var game : Node2D
var splash : Node2D

const VersusSplashScene = preload("res://scenes/menu/versus_splash.tscn")
const GameScene = preload("res://scenes/game/game.tscn")

const VersusSplashTimeout = 3.0
var versus_splash_timer_ready = false
var versus_splash_load_ready = false

@onready var reconnect_overlay : Control = $ReconnectOverlay
@onready var reconnect_message_label : Label = $ReconnectOverlay/PanelContainer/MarginContainer/VBoxContainer/MessageLabel
@onready var reconnect_timer_label : Label = $ReconnectOverlay/PanelContainer/MarginContainer/VBoxContainer/TimerLabel
@onready var reconnect_button : Button = $ReconnectOverlay/PanelContainer/MarginContainer/VBoxContainer/ButtonRow/ReconnectButton
@onready var reconnect_cancel_button : Button = $ReconnectOverlay/PanelContainer/MarginContainer/VBoxContainer/ButtonRow/CancelButton

# Called when the node enters the scene tree for the first time.
func _ready():
	GlobalSettings.load_persistent_settings()
	ImageCache.load_image_cache()
	NetworkManager.connect("reconnect_state_changed", _on_reconnect_state_changed)
	NetworkManager.connect("waiting_for_opponent_reconnect_changed", _on_waiting_for_opponent_reconnect_changed)
	NetworkManager.connect("session_restore_failed", _on_session_restore_failed)
	$MainMenu.settings_loaded()
	NetworkManager.connect_to_server()
	_on_reconnect_state_changed(NetworkManager.get_reconnect_state())

	var http_request = HTTPRequest.new()
	add_child(http_request)

func _on_return_from_game():
	$MainMenu.visible = true
	$MainMenu.returned_from_game()
	_on_reconnect_state_changed(NetworkManager.get_reconnect_state())

func _on_splash_timeout():
	print("Timeout finished!")
	versus_splash_timer_ready = true
	if versus_splash_load_ready:
		remove_child(splash)
		splash = null

func _on_loading_complete():
	print("Images loaded!")
	versus_splash_load_ready = true
	if versus_splash_timer_ready:
		remove_child(splash)
		splash = null

func create_versus_splash(vs_info):
	splash = VersusSplashScene.instantiate()
	add_child(splash)
	splash.set_info(vs_info)

	versus_splash_timer_ready = false
	versus_splash_load_ready = false

	var timer := Timer.new()
	timer.wait_time = VersusSplashTimeout
	timer.one_shot = true
	timer.connect("timeout", _on_splash_timeout)
	add_child(timer)
	timer.start()

	game.load_characters_complete.connect(_on_loading_complete)


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
	var is_restore_rebuild = data.has("restore_log")
	# If a live game already exists and this is NOT a restore rebuild, ignore a
	# stray game_start (we do not want to clobber the current match).
	if game and NetworkManager.get_reconnect_state()["was_in_game"] and not is_restore_rebuild:
		return
	# A restore rebuild replaces the existing game scene entirely.
	if game and is_restore_rebuild:
		if splash:
			remove_child(splash)
			splash = null
		game.queue_free()
		game = null
	$MainMenu.visible = false
	$MainMenu.stop_music()
	game = GameScene.instantiate()
	game.connect("returning_from_game", _on_return_from_game)
	game.set_not_started_directly()
	add_child(game)
	game.begin_remote_game(data)
	game.initialization_after_begin_game()
	create_versus_splash(vs_info)

### Reconnect overlay ###

func _on_reconnect_state_changed(state : Dictionary):
	if state["is_waiting_for_opponent_reconnect"]:
		_show_waiting_for_opponent_overlay(state["waiting_for_opponent_reconnect_seconds"])
		return
	if state["is_manual_reconnect"]:
		_show_manual_reconnect_overlay()
		return
	if state["is_auto_reconnecting"]:
		_show_auto_reconnect_overlay(state["reconnect_seconds"])
		return
	reconnect_overlay.visible = false

func _on_waiting_for_opponent_reconnect_changed(is_waiting : bool, seconds : int):
	if is_waiting:
		_show_waiting_for_opponent_overlay(seconds)
	else:
		_on_reconnect_state_changed(NetworkManager.get_reconnect_state())

func _on_session_restore_failed(reason : String):
	print("Session restore failed, returning to menu: ", reason)
	reconnect_overlay.visible = false
	if game and game.has_method("abandon_match_after_disconnect"):
		game.abandon_match_after_disconnect()

func _show_auto_reconnect_overlay(seconds : int):
	reconnect_overlay.visible = true
	reconnect_message_label.text = "Reconnecting to server..."
	reconnect_timer_label.text = str(max(seconds, 1))
	reconnect_button.visible = false
	reconnect_cancel_button.visible = true
	reconnect_cancel_button.text = "Cancel"

func _show_manual_reconnect_overlay():
	reconnect_overlay.visible = true
	reconnect_message_label.text = "Automatic reconnect failed. Please reconnect manually."
	reconnect_timer_label.text = ""
	reconnect_button.visible = true
	reconnect_button.text = "Reconnect"
	reconnect_button.disabled = NetworkManager.network_state == NetworkManager.NetworkState.NetworkState_Connecting
	reconnect_cancel_button.visible = false

func _show_waiting_for_opponent_overlay(seconds : int):
	reconnect_overlay.visible = true
	reconnect_message_label.text = "Opponent disconnected. Waiting for them to reconnect..."
	reconnect_timer_label.text = str(max(seconds, 1))
	reconnect_button.visible = false
	reconnect_cancel_button.visible = true
	reconnect_cancel_button.text = "Cancel"

func _on_reconnect_button_pressed():
	NetworkManager.attempt_manual_reconnect()
	_on_reconnect_state_changed(NetworkManager.get_reconnect_state())

func _on_reconnect_cancel_button_pressed():
	var reconnect_state = NetworkManager.get_reconnect_state()
	if reconnect_state["is_waiting_for_opponent_reconnect"]:
		NetworkManager.quit_waiting_for_opponent()
		if game and game.has_method("abandon_match_after_disconnect"):
			game.abandon_match_after_disconnect()
		return
	NetworkManager.cancel_reconnect()
	_on_reconnect_state_changed(NetworkManager.get_reconnect_state())
