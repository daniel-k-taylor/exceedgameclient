extends Control

signal start_game(vs_info)
signal start_remote_game(vs_info, data)

const RoomMaxLen = 12
const PlayerNameMaxLen = 12

const ModalList = preload("res://scenes/menu/modal_list.gd")
const ModalDialog = preload("res://scenes/game/modal_dialog.gd")

@onready var player_list : ItemList = $PlayerList
@onready var player_selected_character : String = "solbadguy"
@onready var opponent_selected_character : String = "kykisuke"
@onready var selecting_player : bool = true

@onready var player_name_box : TextEdit = $PlayerNameBox

@onready var start_ai_button : Button = $MenuList/VSAIBox/FightSettings/StartButton
@onready var randomize_first_box : CheckBox = $MenuList/VSAIBox/FightSettings/RandomizeFirstCheckbox
@onready var room_select : LineEdit = $MenuList/JoinBox/RoomNameBox
@onready var join_room_button = $MenuList/JoinBox/JoinButton
@onready var join_box = $MenuList/JoinBox
@onready var matchmake_button = $MenuList/MatchmakeButton
@onready var bgm_checkbox = $SettingsPanel/VBoxContainer/BGMCheckBox

@onready var char_select = $CharSelect
@onready var change_player_character_button : Button = $PlayerChooser/ChangePlayerCharacterButton
@onready var player_char_label : Label = $PlayerChooser/MarginContainer/VBoxContainer/HBoxContainer/CharName
@onready var player_char_portrait : TextureRect = $PlayerChooser/MarginContainer/VBoxContainer/HBoxContainer/CharPortrait

@onready var opponent_char_label : Label = $MenuList/VSAIBox/OpponentChooser/MarginContainer/VBoxContainer/HBoxContainer/CharName
@onready var opponent_char_portrait : TextureRect = $MenuList/VSAIBox/OpponentChooser/MarginContainer/VBoxContainer/HBoxContainer/CharPortrait

@onready var modal_list : ModalList = $ModalList
@onready var modal_dialog : ModalDialog = $ModalDialog

@onready var player_list_button = $PlayerListContainer/PlayerListHBox/PlayersButton
@onready var match_list_button = $RoomListContainer/RoomListHBox/MatchesButton

@onready var label_font_normal = 32
@onready var label_font_small = 18
@onready var label_length_threshold = 15

# Start as true to not play sounds right when you get to the main menu.
@onready var was_match_available : bool = true
@onready var just_clicked_matchmake : bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	NetworkManager.connect("connected_to_server", _on_connected)
	NetworkManager.connect("disconnected_from_server", _on_disconnected)
	NetworkManager.connect("game_started", _on_remote_game_started)
	NetworkManager.connect("observe_started", _on_observe_game_started)
	NetworkManager.connect("players_update", _on_players_update)
	NetworkManager.connect("room_join_failed", _on_join_failed)
	$MenuList/CancelButton.visible = false
	$ReconnectToServerButton.visible = false
	_on_players_update(NetworkManager.get_player_list(), NetworkManager.get_match_list(), NetworkManager.get_match_available())
	selecting_player = false
	just_clicked_matchmake = false
	_on_char_select_select_character(opponent_selected_character)
	modal_dialog.visible = false
	modal_list.visible = false

func settings_loaded():
	bgm_checkbox.button_pressed = GlobalSettings.BGMEnabled
	start_music()

func stop_music():
	$BGM.stop()

func start_music():
	if GlobalSettings.BGMEnabled:
		$BGM.play()
	else:
		$BGM.stop()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func returned_from_game():
	_on_players_update(NetworkManager.get_player_list(), NetworkManager.get_match_list(), NetworkManager.get_match_available())
	update_buttons(false)
	just_clicked_matchmake = false
	start_music()

func _on_start_button_pressed():
	# For local play, random selection is still random at this point.
	var player_random_tag = ""
	if player_selected_character.begins_with("random"):
		player_random_tag = player_selected_character
	var opponent_random_tag = ""
	if opponent_selected_character.begins_with("random"):
		opponent_random_tag = opponent_selected_character

	var player_deck = CardDefinitions.get_deck_from_str_id(player_selected_character)
	var opponent_deck = CardDefinitions.get_deck_from_str_id(opponent_selected_character)
	var player_name = get_player_name()
	var opponent_name = "CPU"
	var randomize_first = randomize_first_box.button_pressed
	start_game.emit(get_vs_info(player_name, player_deck, player_random_tag, opponent_name, opponent_deck, opponent_random_tag, randomize_first))

func _on_quit_button_pressed():
	get_tree().quit()

func _on_connected(player_name):
	join_room_button.disabled = false
	matchmake_button.disabled = false
	player_list_button.disabled = false
	match_list_button.disabled = false
	player_name_box.editable = true
	player_name_box.text = player_name
	$ReconnectToServerButton.visible = false
	$ServerStatusLabel.text = "Connected to server."
	if GlobalSettings.DefaultPlayerName:
		player_name_box.text = GlobalSettings.DefaultPlayerName
		NetworkManager.set_player_name(player_name_box.text)
	else:
		NetworkManager.set_player_name("")

func _on_disconnected():
	update_buttons(false)
	join_room_button.disabled = true
	matchmake_button.disabled = true
	player_list_button.disabled = true
	match_list_button.disabled = true
	$ReconnectToServerButton.visible = true
	$ReconnectToServerButton.disabled = false
	$ServerStatusLabel.text = "Disconnected from server."
	just_clicked_matchmake = false
	_on_players_update([], [], false)

func get_vs_info(player_name, player_deck, player_random_tag, opponent_name, opponent_deck, opponent_random_tag, randomize_first_vs_ai = false):
	return {
		'player_name': player_name,
		'player_deck': player_deck,
		'player_random_tag': player_random_tag,
		'opponent_name': opponent_name,
		'opponent_deck': opponent_deck,
		'opponent_random_tag': opponent_random_tag,
		'randomize_first_vs_ai': randomize_first_vs_ai
	}

func get_random_tag(deck_id):
	if deck_id.begins_with("random"):
		return deck_id.split("#")[0]
	return ""

func get_deck_id_without_random_tag(deck_id):
	if deck_id.begins_with("random"):
		return deck_id.split("#")[1]
	return deck_id

func _on_observe_game_started(data):
	just_clicked_matchmake = false

	# Observe games pass in the full message log up to this point.
	# The first message is the game_start message.
	var message_log = data['message_log']
	var start_data = message_log[0]

	# The observer will view from player 1's perspective.
	var player_deck = start_data['player1_deck_id']
	var player_name = start_data['player1_name']
	var opponent_deck = start_data['player2_deck_id']
	var opponent_name = start_data['player2_name']
	# For remote play, random was decided locally first
	# and the deck id is random#deck_id.
	var player_random_tag = get_random_tag(player_deck)
	var player_deck_no_random = get_deck_id_without_random_tag(player_deck)
	var opponent_random_tag = get_random_tag(opponent_deck)
	var opponent_deck_no_random = get_deck_id_without_random_tag(opponent_deck)

	start_data['player1_deck_id'] = player_deck_no_random
	start_data['player2_deck_id'] = opponent_deck_no_random

	start_data['observer_mode'] = true
	start_data['observer_log'] = message_log.slice(1)

	var player_deck_object = CardDefinitions.get_deck_from_str_id(player_deck_no_random)
	var opponent_deck_object = CardDefinitions.get_deck_from_str_id(opponent_deck_no_random)
	start_remote_game.emit(get_vs_info(player_name, player_deck_object, player_random_tag, opponent_name, opponent_deck_object, opponent_random_tag), start_data)


func _on_remote_game_started(data):
	just_clicked_matchmake = false
	$MatchStartingAudio.play()
	var player1_is_me = true
	var player_deck = data['player1_deck_id']
	var player_name = data['player1_name']
	var opponent_deck = data['player2_deck_id']
	var opponent_name = data['player2_name']
	if data['your_player_id'] != data['player1_id']:
		player1_is_me = false
		player_deck = data['player2_deck_id']
		player_name = data['player2_name']
		opponent_deck = data['player1_deck_id']
		opponent_name = data['player1_name']

	# For remote play, random was decided locally first
	# and the deck id is random#deck_id.
	var player_random_tag = get_random_tag(player_deck)
	var player_deck_no_random = get_deck_id_without_random_tag(player_deck)
	var opponent_random_tag = get_random_tag(opponent_deck)
	var opponent_deck_no_random = get_deck_id_without_random_tag(opponent_deck)

	if player1_is_me:
		data['player1_deck_id'] = player_deck_no_random
		data['player2_deck_id'] = opponent_deck_no_random
	else:
		data['player1_deck_id'] = opponent_deck_no_random
		data['player2_deck_id'] = player_deck_no_random

	var player_deck_object = CardDefinitions.get_deck_from_str_id(player_deck_no_random)
	var opponent_deck_object = CardDefinitions.get_deck_from_str_id(opponent_deck_no_random)
	start_remote_game.emit(get_vs_info(player_name, player_deck_object, player_random_tag, opponent_name, opponent_deck_object, opponent_random_tag), data)

func _on_players_update(players, matches, match_available : bool):
	player_list.clear()
	for player in players:
		player_list.add_item(player['player_name'] + " - " + player['room_name'])

	var player_count = players.size()
	var match_count = matches.size()
	$PlayerListContainer/PlayerListHBox/PlayerCount.text = str(player_count)
	$RoomListContainer/RoomListHBox/MatchCount.text = str(match_count)

	if match_available:
		matchmake_button.text = "Join Match Now"
		if not was_match_available and not just_clicked_matchmake:
			if visible:
				$MatchAvailableAudio.play()
	else:
		matchmake_button.text = "Start Matchmaking"

	was_match_available = match_available

func _on_join_failed(error_message : String):
	modal_dialog.set_text_fields(error_message, "OK", "")

	update_buttons(false)

func get_player_name() -> String:
	return player_name_box.text

func _on_join_button_pressed():
	var player_name = get_player_name()
	var room_name = room_select.text
	var chosen_deck = CardDefinitions.get_deck_from_str_id(player_selected_character)
	var chosen_deck_id = chosen_deck['id']
	if player_selected_character.begins_with("random"):
		chosen_deck_id = player_selected_character + "#" + chosen_deck_id
	NetworkManager.join_room(player_name, room_name, chosen_deck_id)
	update_buttons(true)

func update_buttons(joining : bool):
	start_ai_button.disabled = joining
	randomize_first_box.disabled = joining
	change_player_character_button.disabled = joining
	room_select.editable = not joining
	join_box.visible = not joining
	matchmake_button.visible = not joining
	$MenuList/CancelButton.visible = joining
	player_list_button.disabled = joining
	match_list_button.disabled = joining

func _on_cancel_button_pressed():
	NetworkManager.leave_room()
	update_buttons(false)
	just_clicked_matchmake = false


func _on_update_name_button_pressed():
	var player_name = get_player_name()
	NetworkManager.set_player_name(player_name)
	GlobalSettings.set_player_name(player_name)

func _on_reconnect_to_server_button_pressed():
	$ServerStatusLabel.text = "Reconnecting to server..."
	NetworkManager.connect_to_server()
	$ReconnectToServerButton.disabled = true

func _on_matchmake_button_pressed():
	just_clicked_matchmake = true
	var player_name = get_player_name()
	var chosen_deck = CardDefinitions.get_deck_from_str_id(player_selected_character)
	var chosen_deck_id = chosen_deck['id']
	if player_selected_character.begins_with("random"):
		chosen_deck_id = player_selected_character + "#" + chosen_deck_id
	NetworkManager.join_matchmaking(player_name, chosen_deck_id)
	update_buttons(true)

func _on_char_select_close_character_select():
	char_select.visible = false

func update_char(label, portrait, char_id):
	var display_name = "Random"
	if char_id == "random_s7":
		char_id = "random"
	elif char_id == "random_s6":
		char_id = "unilogo"
	elif char_id == "random_s5":
		char_id = "blazbluelogo2"
	elif char_id == "random_s4":
		char_id = "sklogo"
	elif char_id == "random_s3":
		char_id = "sflogo"
	elif char_id == "random":
		char_id = "exceedrandom"
	else:
		var deck = CardDefinitions.get_deck_from_str_id(char_id)
		display_name = deck['display_name']
	label.text = display_name
	portrait.texture = load("res://assets/portraits/" + char_id + ".png")
	if len(display_name) <= label_length_threshold:
		label.set("theme_override_font_sizes/font_size", label_font_normal)
	else:
		label.set("theme_override_font_sizes/font_size", label_font_small)

func _on_char_select_select_character(char_id):
	if selecting_player:
		player_selected_character = char_id
		update_char(player_char_label, player_char_portrait, char_id)
	else:
		opponent_selected_character =char_id
		update_char(opponent_char_label, opponent_char_portrait, char_id)
	_on_char_select_close_character_select()

func _on_change_player_character_button_pressed(is_player : bool):
	var char_id = player_selected_character
	if not is_player:
		char_id = opponent_selected_character
	char_select.show_char_select(char_id)
	char_select.visible = true
	selecting_player = is_player

func cropLineToMaxLength_room_line_edit(new_text : String, max_length: int) -> void:
	if new_text.length() > max_length:
		var col = room_select.caret_column
		if col != 0:
			new_text = new_text.substr(0, col-1) + new_text.substr(col)
		else:
			new_text = new_text.substr(1)
		new_text = new_text.substr(0, max_length)
		room_select.text = new_text
		room_select.caret_column = col - 1

func cropLineToMaxLength_name_text_edit(new_text : String, max_length: int) -> void:
	if new_text.length() > max_length:
		var col = player_name_box.get_caret_column()
		if col != 0:
			new_text = new_text.substr(0, col-1) + new_text.substr(col)
		else:
			new_text = new_text.substr(1)
		new_text = new_text.substr(0, max_length)
		player_name_box.text = new_text
		player_name_box.set_caret_column(col - 1)

func _on_room_name_box_text_changed(new_text):
	cropLineToMaxLength_room_line_edit(new_text, RoomMaxLen)

func _on_player_name_box_focus_entered():
	player_name_box.select_all()

func _on_player_name_box_text_changed():
	cropLineToMaxLength_name_text_edit(player_name_box.text, PlayerNameMaxLen)

func _on_bgm_check_box_toggled(button_pressed : bool):
	GlobalSettings.set_bgm(button_pressed)
	if GlobalSettings.BGMEnabled:
		start_music()
	else:
		stop_music()

func _on_players_button_pressed():
	modal_list.show_player_list()

func _on_matches_button_pressed():
	modal_list.show_match_list()


func _on_modal_list_join_match_pressed(row_index):
	var matches = NetworkManager.get_match_list()
	var selected_match = matches[row_index]
	room_select.text = selected_match['name']
	_on_join_button_pressed()

func _on_modal_list_observe_match_pressed(row_index):
	var matches = NetworkManager.get_match_list()
	var selected_match = matches[row_index]
	var room_name = selected_match['name']
	var player_name = get_player_name()
	NetworkManager.observe_room(player_name, room_name)
	update_buttons(true)

