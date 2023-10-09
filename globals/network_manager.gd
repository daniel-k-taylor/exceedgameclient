extends Node

signal disconnected_from_server
signal connected_to_server(server_name)

enum NetworkState {
	NetworkState_NotConnected,
	NetworkState_Connecting,
	NetworkState_Connected,
}

var network_state = NetworkState.NetworkState_NotConnected

const azure_url = "wss://fightingcardslinux.azurewebsites.net"
const local_url = "ws://localhost:8080"

var _socket = WebSocketPeer.new()

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func connect_to_server(local : bool):
	if local:
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
		"player_disconnect":
			_handle_disconnect(data_obj)

func _handle_server_hello(hello_message):
	var player_name = hello_message["player_name"]
	print("Connected to server as : ", player_name)
	connected_to_server.emit(player_name)

func _handle_room_waiting_for_opponent(_waiting_message):
	print("Waiting for opponent in room")

func _handle_room_join_failed(failed_message):
	var reason = failed_message["reason"]
	print("Failed to join room: ", reason)

func _handle_game_start(game_start_message):
	var player1_id = game_start_message["player1_id"]
	var player1_name = game_start_message["player1_name"]
	var player2_id = game_start_message["player2_id"]
	var player2_name = game_start_message["player2_name"]
	print("Game started between [%s] %s and [%s] %s" % [player1_id, player1_name, player2_id, player2_name])

func _handle_disconnect(disconnect_message):
	var id = disconnect_message["id"]
	var player_name = disconnect_message["name"]
	print("Player [%s] %s disconnected" % [id, player_name])



func join_room(player_name, room_name, deck_index):
	var deck = CardDefinitions.get_deck_from_selector_index(deck_index)
	var join_room_message = {
		"type": "join_room",
		"player_name": player_name,
		"room_id": room_name,
		"deck_id": deck["id"],
	}
	var json = JSON.stringify(join_room_message)
	_socket.send_text(json)
