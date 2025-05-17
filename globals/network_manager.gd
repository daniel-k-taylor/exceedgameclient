extends Node

signal disconnected_from_server
signal connected_to_server(server_name)
signal room_join_failed(error_message)
signal game_started(data)
signal game_message_received(message)
signal observe_started(data)
signal other_player_quit(is_disconnect)
signal players_update(players, matches, queues, newly_available_match)
signal customs_update(customs)
signal name_update(name)

enum NetworkState {
	NetworkState_NotConnected,
	NetworkState_Connecting,
	NetworkState_Connected,
}

var network_state = NetworkState.NetworkState_NotConnected
var cached_players = []
var cached_matches = []
var cached_queues = []
var cached_customs = {}

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
	var server_url = GlobalSettings.get_server_url()
	_socket.connect_to_url(server_url)
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
				disconnected_from_server.emit()
				network_state = NetworkState.NetworkState_NotConnected
				var code = _socket.get_close_code()
				var reason = _socket.get_close_reason()
				print("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
				_socket = null

func _is_socket_open():
	return _socket and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN

func _handle_server_response(data):
	var parser = JSON.new()
	var result = parser.parse(data)
	if result != OK:
		print("Error parsing JSON from server: ", data)
		return

	var data_obj = CardDataManager.convert_floats_to_ints(parser.get_data())
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
		"name_update":
			_handle_name_update(data_obj)
		"observe_start":
			_handle_observe_start(data_obj)
		"player_disconnect":
			_handle_player_disconnect(data_obj)
		"player_quit":
			_handle_player_quit(data_obj)
		"players_update":
			_handle_players_update(data_obj)
		"customs_update":
			_handle_customs_update(data_obj)

func _handle_server_hello(hello_message):
	var player_name = hello_message["player_name"]
	print("Connected to server as : ", player_name)
	connected_to_server.emit(player_name)

func _handle_room_waiting_for_opponent(_waiting_message):
	print("Waiting for opponent in room")

func _handle_room_join_failed(failed_message):
	var reason = failed_message["reason"]
	var error_message = "ERROR: Failed to join room:\n"
	var invalid_deck = false
	match reason:
		"invalid_custom_deck":
			error_message += "Custom deck is invalid."
			invalid_deck = true
		"invalid_deck_for_queue":
			error_message = "Character not allowed in this queue."
			invalid_deck = true
		"room_full":
			error_message += "Room is full."
		"version_mismatch":
			error_message += "Client Version Mismatch\nCheck for new client version."
		_:
			error_message += "Join Error\n" + reason
	print(error_message)
	room_join_failed.emit(error_message, invalid_deck)

# Accepts a message from the game server indicating a game started.
# Rebroadcasts the message to our scripts.
func _handle_game_start(game_start_message):
	var player1_id = game_start_message["player1_id"]
	var player1_name = game_start_message["player1_name"]
	var player2_id = game_start_message["player2_id"]
	var player2_name = game_start_message["player2_name"]
	print("Game started between [%s] %s and [%s] %s" % [player1_id, player1_name, player2_id, player2_name])
	game_started.emit(game_start_message)

func _handle_name_update(name_update_message):
	var new_name = name_update_message["name"]
	name_update.emit(new_name)

func _handle_observe_start(observe_start_message):
	observe_started.emit(observe_start_message)

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

func get_stripped_room_name(room_name : String):
	# If the room name starts with "custom_" remove that from the string.
	if room_name.find("custom_") == 0:
		room_name = room_name.substr(7)
	return room_name

func _handle_players_update(message):
	var players = message["players"]
	var rooms = message["rooms"]
	var queues = message['queues']
	var player_list = []
	for player in players:
		var id = player["player_id"]
		var version = player["player_version"]
		var player_name = player["player_name"]
		var room_name = player["room_name"]
		var player_deck = player["player_deck"]
		room_name = get_stripped_room_name(room_name)
		player_list.append({
			"player_id": id,
			"player_deck": player_deck,
			"player_version": version,
			"player_name": player_name,
			"room_name": room_name,
		})
	cached_players = player_list
	var newly_available_match = false
	for old_queue in cached_queues:
		var new_queue = null
		for queue in queues:
			if old_queue['id'] == queue['id']:
				new_queue = queue
				break
		if new_queue and new_queue['match_available'] and not old_queue['match_available']:
			newly_available_match = true
			break
	cached_queues = queues

	# Process rooms
	var match_list = []
	for room in rooms:
		var room_name = room['room_name']
		var room_version = room['room_version']
		room_name = get_stripped_room_name(room_name)
		var observer_count = int(room['observer_count'])
		var started = room['game_started']
		var host = "<EMPTY>"
		var opponent = "<EMPTY>"
		host = room['player_names'][0]
		if room['player_names'][1]:
			opponent = room['player_names'][1]
		var decks = room["player_decks"]
		var host_deck_icon_path = ""
		var opponent_deck_icon_path = ""
		if decks[0]:
			host_deck_icon_path = CardDataManager.get_portrait_asset_path(decks[0])
		if decks[1]:
			opponent_deck_icon_path = CardDataManager.get_portrait_asset_path(decks[1])
		var match_info = {
			"name": room_name,
			"host": host,
			"host_deck_icon": host_deck_icon_path,
			"opponent": opponent,
			"opponent_deck_icon": opponent_deck_icon_path,
			"version": room_version,
			"observer_count": observer_count,
			"joinable": not started,
			"observable": started
		}
		match_list.append(match_info)
	cached_matches = match_list

	players_update.emit(player_list, match_list, queues, newly_available_match)

func _handle_customs_update(message):
	# Read the new customs dict from the message.
	var new_customs = message["customs"]
	# Update all keys in cached_customs.
	for key in new_customs.keys():
		cached_customs[key] = CardDataManager.convert_floats_to_ints(new_customs[key])
	customs_update.emit(cached_customs)

### Commands ###

func join_room(player_name, room_name, deck_id_str : String,
		starting_timer : int, enforce_timer : bool, minimum_time_per_choice : int, custom_deck_definition):
	if not _is_socket_open(): return
	var join_room_message = {
		"version": GlobalSettings.get_client_version(),
		"type": "join_room",
		"player_name": player_name,
		"room_id": room_name,
		"deck_id": deck_id_str,
		"starting_timer": starting_timer,
		"enforce_timer": enforce_timer,
		"minimum_time_per_choice": minimum_time_per_choice,
		"custom_deck_definition": custom_deck_definition
	}
	var json = JSON.stringify(join_room_message)
	_socket.send_text(json)

func observe_room(player_name, room_name):
	if not _is_socket_open(): return
	var observe_room_message = {
		"version": GlobalSettings.get_client_version(),
		"type": "observe_room",
		"player_name": player_name,
		"room_id": room_name,
	}
	var json = JSON.stringify(observe_room_message)
	_socket.send_text(json)

func join_matchmaking(player_name, deck_id_str : String, queue_id : String, custom_deck_definition):
	if not _is_socket_open(): return
	var message = {
		"version": GlobalSettings.get_client_version(),
		"type": "join_matchmaking",
		"queue_id": queue_id,
		"player_name": player_name,
		"deck_id": deck_id_str,
		"starting_timer": GlobalSettings.MatchmakingStartingTimer,
		"enforce_timer": GlobalSettings.MatchmakingEnforceTimer,
		"minimum_time_per_choice": GlobalSettings.MatchmakingMinimumTimePerChoice,
		"custom_deck_definition": custom_deck_definition
	}
	var json = JSON.stringify(message)
	_socket.send_text(json)

func leave_room():
	if not _is_socket_open(): return
	var leave_room_message = {
		"type": "leave_room",
	}
	var json = JSON.stringify(leave_room_message)
	_socket.send_text(json)

func submit_game_message(message):
	if not _is_socket_open(): return
	message['type'] = "game_message"
	var json = JSON.stringify(message)
	_socket.send_text(json)

func set_player_name(player_name):
	if not _is_socket_open(): return
	var message = {
		"version": GlobalSettings.get_client_version(),
		"type": "set_name",
		"player_name": player_name,
	}
	var json = JSON.stringify(message)
	_socket.send_text(json)

func set_lobby_state(lobby_state : String):
	if not _is_socket_open(): return
	var message = {
		"type": "set_lobby_state",
		"lobby_state": lobby_state,
	}
	var json = JSON.stringify(message)
	_socket.send_text(json)

func get_customs():
	if not _is_socket_open(): return
	var message = {
		"type": "get_customs",
	}
	var json = JSON.stringify(message)
	_socket.send_text(json)

### Getters ###

func get_player_list():
	return cached_players

func get_match_list():
	return cached_matches

func get_queue_list():
	return cached_queues

func get_customs_dict():
	return cached_customs

func any_available_match():
	for queue in cached_queues:
		if queue['match_available']:
			return true
	return false
