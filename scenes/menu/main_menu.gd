extends Control

signal start_game(vs_info)
signal start_remote_game(vs_info, data)

@onready var player_select : OptionButton = $PlayerChooser/Margin/VBox/PlayerCharSelect
@onready var opponent_select : OptionButton = $MenuList/VSAIBox/OpponentChooser/Margin/VBox/OpponentCharSelect
@onready var player_list : ItemList = $PlayerList

@onready var start_ai_button : Button = $MenuList/VSAIBox/StartButton
@onready var char_select = $PlayerChooser/Margin/VBox/PlayerCharSelect
@onready var room_select = $RoomNameBox

func _initialize_character_select():
	player_select.clear()
	opponent_select.clear()
	var num_chars = CardDefinitions.SelectorIndexToDeckId.size()
	for i in range(num_chars):
		player_select.add_item(CardDefinitions.SelectorIndexToDeckId[i], i)
		opponent_select.add_item(CardDefinitions.SelectorIndexToDeckId[i], i)

	player_select.selected = 0
	opponent_select.selected = 1

# Called when the node enters the scene tree for the first time.
func _ready():
	_initialize_character_select()
	NetworkManager.connect("connected_to_server", _on_connected)
	NetworkManager.connect("disconnected_from_server", _on_disconnected)
	NetworkManager.connect("game_started", _on_remote_game_started)
	NetworkManager.connect("players_update", _on_players_update)
	NetworkManager.connect("room_join_failed", _on_join_failed)
	$MenuList/CancelButton.visible = false
	$ReconnectToServerButton.visible = false
	_on_players_update(NetworkManager.get_player_list())

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func returned_from_game():
	_on_players_update(NetworkManager.get_player_list())
	update_buttons(false)

func _on_start_button_pressed():
	var player_deck = CardDefinitions.get_deck_from_selector_index(player_select.selected)
	var opponent_deck = CardDefinitions.get_deck_from_selector_index(opponent_select.selected)
	var player_name = get_player_name()
	var opponent_name = "CPU"
	start_game.emit(get_vs_info(player_name, player_deck, opponent_name, opponent_deck))

func _on_quit_button_pressed():
	get_tree().quit()

func _on_connected(player_name):
	$MenuList/JoinButton.disabled = false
	$MenuList/MatchmakeButton.disabled = false
	$PlayerNameBox.editable = true
	$PlayerNameBox.text = player_name
	$ReconnectToServerButton.visible = false
	$ServerStatusLabel.text = "Connected to server."

func _on_disconnected():
	update_buttons(false)
	$MenuList/JoinButton.disabled = true
	$MenuList/MatchmakeButton.disabled = true
	$ReconnectToServerButton.visible = true
	$ReconnectToServerButton.disabled = false
	$ServerStatusLabel.text = "Disconnected from server."

func get_vs_info(player_name, player_deck, opponent_name, opponent_deck):
	return {
		'player_name': player_name,
		'player_deck': player_deck,
		'opponent_name': opponent_name,
		'opponent_deck': opponent_deck,
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

func _on_players_update(players):
	player_list.clear()
	for player in players:
		player_list.add_item(player['player_name'] + " - " + player['room_name'])

func _on_join_failed():
	update_buttons(false)

func get_player_name() -> String:
	return $PlayerNameBox.text

func _on_join_button_pressed():
	var player_name = get_player_name()
	var room_name = $RoomNameBox.text
	NetworkManager.join_room(player_name, room_name, player_select.selected)
	update_buttons(true)

func update_buttons(joining : bool):
	start_ai_button.disabled = joining
	char_select.disabled = joining
	room_select.editable = not joining
	$MenuList/JoinButton.visible = not joining
	$MenuList/MatchmakeButton.visible = not joining
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
	NetworkManager.join_matchmaking(player_name, player_select.selected)
	update_buttons(true)
