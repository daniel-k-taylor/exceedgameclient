extends Node

signal disconnected_from_server
signal connected_to_server(server_name)
signal room_join_failed
signal game_started(data)
signal game_message_received(message)
signal other_player_quit(is_disconnect)
signal players_update(players)

enum NetworkState {
	NetworkState_NotConnected,
	NetworkState_Connecting,
	NetworkState_Connected,
}

var network_state = NetworkState.NetworkState_NotConnected
var cached_players = []

const azure_url = "wss://fightingcardslinux.azurewebsites.net"
const local_url = "ws://localhost:8080"

var _socket = null

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func is_server_connected() -> bool:
	return _socket != null

func connect_to_server():
	if _socket != null: return
	_socket = WebSocketPeer.new()
	if OS.is_debug_build():
		_socket.connect_to_url(local_url)
	else:
		_socket.connect_to_url(azure_url)
	print("Connecting to server...")
	network_state = NetworkState.NetworkState_Connecting

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	_handle_sockets()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _socket:
			_socket.close()

func _handle_sockets():
	if _socket:
		_socket.poll()
		var state = _socket.get_ready_state()
		match state:
			WebSocketPeer.STATE_OPEN:
				if network_state == NetworkState.NetworkState_Connecting:
					print("Connected to server")
				network_state = NetworkState.NetworkState_Connected
				while _socket.get_available_packet_count():
					var packet = _socket.get_packet()
					if _socket.was_string_packet():
						var strpacket = packet.get_string_from_utf8()
						_handle_server_response(strpacket)
			WebSocketPeer.STATE_CLOSING:
				pass
			WebSocketPeer.STATE_CLOSED:
				if network_state == NetworkState.NetworkState_Connected:
					disconnected_from_server.emit()
				network_state = NetworkState.NetworkState_NotConnected
				var code = _socket.get_close_code()
				var reason = _socket.get_close_reason()
				print("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
				_socket = null

func _handle_server_response(data):
	var parser = JSON.new()
	var result = parser.parse(data)
	if result != OK:
		print("Error parsing JSON from server: ", data)
		return

	var data_obj = parser.get_data()
	var type = data_obj["type"]
	match type:
		"server_hello":
			_handle_server_hello(data_obj)
		"room_waiting_for_opponent":
			_handle_room_waiting_for_opponent(data_obj)
		"room_join_failed":
			_handle_room_join_failed(data_obj)
		"game_start":
			_handle_game_start(data_obj)
		"game_message":
			_handle_game_message(data_obj)
		"player_disconnect":
			_handle_player_disconnect(data_obj)
		"player_quit":
			_handle_player_quit(data_obj)
		"players_update":
			_handle_players_update(data_obj)

func _handle_server_hello(hello_message):
	var player_name = hello_message["player_name"]
	print("Connected to server as : ", player_name)
	connected_to_server.emit(player_name)

func _handle_room_waiting_for_opponent(_waiting_message):
	print("Waiting for opponent in room")

func _handle_room_join_failed(failed_message):
	var reason = failed_message["reason"]
	print("Failed to join room: ", reason)
	room_join_failed.emit()

func _handle_game_start(game_start_message):
	var player1_id = game_start_message["player1_id"]
	var player1_name = game_start_message["player1_name"]
	var player2_id = game_start_message["player2_id"]
	var player2_name = game_start_message["player2_name"]
	print("Game started between [%s] %s and [%s] %s" % [player1_id, player1_name, player2_id, player2_name])
	game_started.emit(game_start_message)

func _handle_player_disconnect(message):
	var id = message["id"]
	var player_name = message["name"]
	print("Player [%s] %s disconnected" % [id, player_name])
	other_player_quit.emit(true)

func _handle_player_quit(message):
	var id = message["id"]
	var player_name = message["name"]
	print("Player [%s] %s quit" % [id, player_name])
	other_player_quit.emit(false)

func _handle_game_message(game_message):
	game_message_received.emit(game_message)

func _handle_players_update(message):
	var players = message["players"]
	var player_list = []
	for player in players:
		var id = player["player_id"]
		var player_name = player["player_name"]
		var room_name = player["room_name"]
		player_list.append({
			"player_id": id,
			"player_name": player_name,
			"room_name": room_name,
		})
	cached_players = player_list
	players_update.emit(player_list)


### Commands ###

func join_room(player_name, room_name, deck_index):
	if not _socket: return
	var deck = CardDefinitions.get_deck_from_selector_index(deck_index)
	var join_room_message = {
		"type": "join_room",
		"player_name": player_name,
		"room_id": room_name,
		"deck_id": deck["id"],
	}
	var json = JSON.stringify(join_room_message)
	_socket.send_text(json)

func leave_room():
	if not _socket: return
	var leave_room_message = {
		"type": "leave_room",
	}
	var json = JSON.stringify(leave_room_message)
	_socket.send_text(json)

func submit_game_message(message):
	if not _socket: return
	message['type'] = "game_message"
	var json = JSON.stringify(message)
	_socket.send_text(json)

func set_player_name(player_name):
	if not _socket: return
	var message = {
		"type": "set_name",
		"player_name": player_name,
	}
	var json = JSON.stringify(message)
	_socket.send_text(json)

func get_player_list():
	return cached_players
