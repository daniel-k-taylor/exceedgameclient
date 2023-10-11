extends Control

signal start_game(player_char_index, opponent_char_index)
signal start_remote_game(data)

@onready var player_select : OptionButton = $PlayerChooser/Margin/VBox/PlayerCharSelect
@onready var opponent_select : OptionButton = $MenuList/VSAIBox/OpponentChooser/Margin/VBox/OpponentCharSelect
@onready var player_list : ItemList = $PlayerList

@onready var start_ai_button : Button = $MenuList/VSAIBox/StartButton
@onready var char_select = $PlayerChooser/Margin/VBox/PlayerCharSelect
@onready var room_select = $RoomNameBox

# Called when the node enters the scene tree for the first time.
func _ready():
	NetworkManager.connect("connected_to_server", _on_connected)
	NetworkManager.connect("game_started", _on_remote_game_started)
	NetworkManager.connect("players_update", _on_players_update)
	NetworkManager.connect("room_join_failed", _on_join_failed)
	$MenuList/CancelButton.visible = false
	_on_players_update(NetworkManager.get_player_list())

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func returned_from_game():
	_on_players_update(NetworkManager.get_player_list())
	update_buttons(false)

func _on_start_button_pressed():
	start_game.emit(player_select.selected, opponent_select.selected)

func _on_quit_button_pressed():
	get_tree().quit()

func _on_connected(player_name):
	$MenuList/JoinButton.disabled = false
	$PlayerNameBox.editable = true
	$PlayerNameBox.text = player_name

func _on_remote_game_started(data):
	start_remote_game.emit(data)

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
	$MenuList/CancelButton.visible = joining

func _on_cancel_button_pressed():
	NetworkManager.leave_room()
	update_buttons(false)


func _on_update_name_button_pressed():
	var player_name = get_player_name()
	NetworkManager.set_player_name(player_name)
