extends Control

signal start_game(vs_info)
signal start_remote_game(vs_info, data)

const RoomMaxLen = 16

@onready var player_list : ItemList = $PlayerList
@onready var player_selected_character : String = "solbadguy"
@onready var opponent_selected_character : String = "kykisuke"
@onready var selecting_player : bool = true

@onready var start_ai_button : Button = $MenuList/VSAIBox/FightSettings/StartButton
@onready var randomize_first_box : CheckBox = $MenuList/VSAIBox/FightSettings/RandomizeFirstCheckbox
@onready var room_select : LineEdit = $MenuList/JoinBox/RoomNameBox
@onready var join_room_button = $MenuList/JoinBox/JoinButton
@onready var join_box = $MenuList/JoinBox
@onready var matchmake_button = $MenuList/MatchmakeButton

@onready var char_select = $CharSelect
@onready var change_player_character_button : Button = $PlayerChooser/ChangePlayerCharacterButton
@onready var player_char_label : Label = $PlayerChooser/MarginContainer/VBoxContainer/HBoxContainer/CharName
@onready var player_char_portrait : TextureRect = $PlayerChooser/MarginContainer/VBoxContainer/HBoxContainer/CharPortrait

@onready var opponent_char_label : Label = $MenuList/VSAIBox/OpponentChooser/MarginContainer/VBoxContainer/HBoxContainer/CharName
@onready var opponent_char_portrait : TextureRect = $MenuList/VSAIBox/OpponentChooser/MarginContainer/VBoxContainer/HBoxContainer/CharPortrait

@onready var label_font_normal = 32
@onready var label_font_small = 18
@onready var label_length_threshold = 16

# Called when the node enters the scene tree for the first time.
func _ready():
	NetworkManager.connect("connected_to_server", _on_connected)
	NetworkManager.connect("disconnected_from_server", _on_disconnected)
	NetworkManager.connect("game_started", _on_remote_game_started)
	NetworkManager.connect("players_update", _on_players_update)
	NetworkManager.connect("room_join_failed", _on_join_failed)
	$MenuList/CancelButton.visible = false
	$ReconnectToServerButton.visible = false
	_on_players_update(NetworkManager.get_player_list(), NetworkManager.get_match_available())
	selecting_player = false
	_on_char_select_select_character(opponent_selected_character)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func returned_from_game():
	_on_players_update(NetworkManager.get_player_list(), NetworkManager.get_match_available())
	update_buttons(false)

func _on_start_button_pressed():
	var player_deck = CardDefinitions.get_deck_from_str_id(player_selected_character)
	var opponent_deck = CardDefinitions.get_deck_from_str_id(opponent_selected_character)
	var player_name = get_player_name()
	var opponent_name = "CPU"
	var randomize_first = randomize_first_box.button_pressed
	start_game.emit(get_vs_info(player_name, player_deck, opponent_name, opponent_deck, randomize_first))

func _on_quit_button_pressed():
	get_tree().quit()

func _on_connected(player_name):
	join_room_button.disabled = false
	matchmake_button.disabled = false
	$PlayerNameBox.editable = true
	$PlayerNameBox.text = player_name
	$ReconnectToServerButton.visible = false
	$ServerStatusLabel.text = "Connected to server."

func _on_disconnected():
	update_buttons(false)
	join_room_button.disabled = true
	matchmake_button.disabled = true
	$ReconnectToServerButton.visible = true
	$ReconnectToServerButton.disabled = false
	$ServerStatusLabel.text = "Disconnected from server."

func get_vs_info(player_name, player_deck, opponent_name, opponent_deck, randomize_first_vs_ai = false):
	return {
		'player_name': player_name,
		'player_deck': player_deck,
		'opponent_name': opponent_name,
		'opponent_deck': opponent_deck,
		'randomize_first_vs_ai': randomize_first_vs_ai
	}

func _on_remote_game_started(data):
	var player_deck = data['player1_deck_id']
	var player_name = data['player1_name']
	var opponent_deck = data['player2_deck_id']
	var opponent_name = data['player2_name']
	if data['your_player_id'] != data['player1_id']:
		player_deck = data['player2_deck_id']
		player_name = data['player2_name']
		opponent_deck = data['player1_deck_id']
		opponent_name = data['player1_name']

	player_deck = CardDefinitions.get_deck_from_str_id(player_deck)
	opponent_deck = CardDefinitions.get_deck_from_str_id(opponent_deck)
	start_remote_game.emit(get_vs_info(player_name, player_deck, opponent_name, opponent_deck), data)

func _on_players_update(players, match_available : bool):
	player_list.clear()
	for player in players:
		player_list.add_item(player['player_name'] + " - " + player['room_name'])

	if match_available:
		matchmake_button.text = "Join Match Now"
	else:
		matchmake_button.text = "Start Matchmaking"

func _on_join_failed():
	update_buttons(false)

func get_player_name() -> String:
	return $PlayerNameBox.text

func _on_join_button_pressed():
	var player_name = get_player_name()
	var room_name = room_select.text
	var chosen_deck = CardDefinitions.get_deck_from_str_id(player_selected_character)
	NetworkManager.join_room(player_name, room_name, chosen_deck['id'])
	update_buttons(true)

func update_buttons(joining : bool):
	start_ai_button.disabled = joining
	randomize_first_box.disabled = joining
	change_player_character_button.disabled = joining
	room_select.editable = not joining
	join_box.visible = not joining
	matchmake_button.visible = not joining
	$MenuList/CancelButton.visible = joining

func _on_cancel_button_pressed():
	NetworkManager.leave_room()
	update_buttons(false)


func _on_update_name_button_pressed():
	var player_name = get_player_name()
	NetworkManager.set_player_name(player_name)


func _on_reconnect_to_server_button_pressed():
	$ServerStatusLabel.text = "Reconnecting to server..."
	NetworkManager.connect_to_server()
	$ReconnectToServerButton.disabled = true

func _on_matchmake_button_pressed():
	var player_name = get_player_name()
	var chosen_deck = CardDefinitions.get_deck_from_str_id(player_selected_character)
	NetworkManager.join_matchmaking(player_name, chosen_deck['id'])
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

func cropLineToMaxLength(new_text : String, max_length: int) -> void:
	if new_text.length() > max_length:
		var col = room_select.caret_column
		if col != 0:
			new_text = new_text.substr(0, col-1) + new_text.substr(col)
		else:
			new_text = new_text.substr(1)
		new_text = new_text.substr(0, max_length)
		room_select.text = new_text
		room_select.caret_column = col - 1

func _on_room_name_box_text_changed(new_text):
	cropLineToMaxLength(new_text, RoomMaxLen)
