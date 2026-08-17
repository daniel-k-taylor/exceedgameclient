extends GutTest

class MockSocket:
	var ready_state := WebSocketPeer.STATE_OPEN
	var sent_messages : Array = []

	func get_ready_state():
		return ready_state

	func poll():
		return OK

	func get_available_packet_count():
		return 0

	func send_text(payload : String):
		sent_messages.append(payload)
		return OK

	func close():
		ready_state = WebSocketPeer.STATE_CLOSED


func before_each():
	_reset_network_manager_state()
	NetworkManager._clear_lobby_cache(false)


func after_each():
	_reset_network_manager_state()
	NetworkManager._clear_lobby_cache(false)


func _reset_network_manager_state():
	NetworkManager._abort_reconnect_socket()
	NetworkManager.network_state = NetworkManager.NetworkState.NetworkState_NotConnected
	NetworkManager._socket = null
	NetworkManager._is_expected_disconnect = false
	NetworkManager._reconnect_elapsed = 0.0
	NetworkManager._next_auto_reconnect_in = NetworkManager.AUTO_RECONNECT_INTERVAL_SECONDS
	NetworkManager._reset_server_keepalive_tracking()
	NetworkManager.reconnect_state["is_auto_reconnecting"] = false
	NetworkManager.reconnect_state["auto_retry_enabled"] = false
	NetworkManager.reconnect_state["reconnect_seconds"] = 0
	NetworkManager.reconnect_state["last_reconnect_attempt_time"] = -1.0
	NetworkManager.reconnect_state["is_manual_reconnect"] = false
	NetworkManager.reconnect_state["user_cancelled"] = false
	NetworkManager.reconnect_state["disconnect_reason"] = ""
	NetworkManager.reconnect_state["is_waiting_for_opponent_reconnect"] = false
	NetworkManager.reconnect_state["waiting_for_opponent_reconnect_seconds"] = 0
	NetworkManager._waiting_for_opponent_reconnect_elapsed = 0.0
	NetworkManager._active_remote_match_finished = false
	NetworkManager._cold_restore_pending = false


func test_players_update_replaces_cached_lobby_snapshot():
	NetworkManager._handle_players_update({
		"players": [{
			"player_id": 1,
			"player_version": "dev_test",
			"player_name": "Host",
			"room_name": "room_a",
			"player_deck": "ryu",
		}],
		"rooms": [{
			"room_name": "room_a",
			"room_version": "dev_test",
			"player_count": 1,
			"observer_count": 0,
			"game_started": false,
			"player_names": ["Host", ""],
			"player_decks": ["ryu", ""],
		}],
		"queues": [{
			"id": "casual",
			"name": "Casual",
			"match_available": true,
			"waiting_deck_id": "ryu",
		}],
	})

	assert_eq(NetworkManager.get_player_list().size(), 1)
	assert_eq(NetworkManager.get_match_list().size(), 1)
	assert_true(NetworkManager.get_queue_list()[0]["match_available"])
	assert_eq(NetworkManager.get_queue_list()[0]["waiting_deck_id"], "ryu")

	NetworkManager._handle_players_update({
		"players": [],
		"rooms": [],
		"queues": [{
			"id": "casual",
			"name": "Casual",
			"match_available": false,
		}],
	})

	assert_eq(NetworkManager.get_player_list().size(), 0)
	assert_eq(NetworkManager.get_match_list().size(), 0)
	assert_eq(NetworkManager.get_queue_list().size(), 1)
	assert_false(NetworkManager.get_queue_list()[0]["match_available"])


func test_players_update_preserves_all_waiting_queue_fields():
	NetworkManager._handle_players_update({
		"players": [],
		"rooms": [],
		"queues": [{
			"id": "ranked",
			"name": "Ranked",
			"match_available": true,
			"waiting_character": "Ryu",
			"waiting_deck": "Ryu",
			"waiting_deck_id": "random_s3#ryu",
		}],
	})

	var queue_info = NetworkManager.get_queue_list()[0]
	assert_eq(queue_info["waiting_character"], "Ryu")
	assert_eq(queue_info["waiting_deck"], "Ryu")
	assert_eq(queue_info["waiting_deck_id"], "random_s3#ryu")


func test_players_update_filters_invalid_rooms():
	NetworkManager._handle_players_update({
		"players": [],
		"rooms": [{
			"room_name": "empty_room",
			"room_version": "dev_test",
			"player_count": 0,
			"observer_count": 0,
			"game_started": false,
			"player_names": ["", ""],
			"player_decks": ["", ""],
		}, {
			"room_name": "no_host_room",
			"room_version": "dev_test",
			"player_count": 1,
			"observer_count": 0,
			"game_started": false,
			"player_names": ["", "Guest"],
			"player_decks": ["", "kykisuke"],
		}, {
			"room_name": "half_started_room",
			"room_version": "dev_test",
			"player_count": 1,
			"observer_count": 1,
			"game_started": true,
			"joinable": false,
			"player_names": ["Host", ""],
			"player_decks": ["ryu", ""],
		}, {
			"room_name": "valid_started_room",
			"room_version": "dev_test",
			"player_count": 2,
			"observer_count": 1,
			"game_started": true,
			"player_names": ["Host", "Guest"],
			"player_decks": ["", ""],
		}],
		"queues": [],
	})

	var matches = NetworkManager.get_match_list()
	assert_eq(matches.size(), 1)
	assert_eq(matches[0]["name"], "valid_started_room")
	assert_false(matches[0]["joinable"])
	assert_true(matches[0]["observable"])


func test_players_update_keeps_game_over_room_observable():
	NetworkManager._handle_players_update({
		"players": [],
		"rooms": [{
			"room_name": "finished_room",
			"room_version": "dev_test",
			"player_count": 1,
			"observer_count": 0,
			"game_started": true,
			"game_over": true,
			"joinable": false,
			"player_names": ["Winner", ""],
			"player_decks": ["ryu", "solbadguy"],
		}],
		"queues": [],
	})

	var matches = NetworkManager.get_match_list()
	assert_eq(matches.size(), 1)
	assert_eq(matches[0]["name"], "finished_room")
	assert_false(matches[0]["joinable"])
	assert_true(matches[0]["observable"])
	assert_true(matches[0]["game_over"])


func test_server_keepalive_message_updates_keepalive_tracking():
	NetworkManager._handle_server_response(JSON.stringify({
		"type": "server_keepalive",
	}))

	assert_true(NetworkManager._server_keepalive_tracking)
	assert_gt(NetworkManager._last_server_keepalive_time, 0.0)


func test_server_keepalive_timeout_starts_reconnect_flow():
	NetworkManager.network_state = NetworkManager.NetworkState.NetworkState_Connected
	NetworkManager._server_keepalive_tracking = true
	NetworkManager._last_server_keepalive_time = Time.get_ticks_msec() / 1000.0 - NetworkManager.SERVER_KEEPALIVE_TIMEOUT_SECONDS - 1.0

	NetworkManager._update_server_keepalive_timeout()

	var state = NetworkManager.get_reconnect_state()
	assert_true(state["is_auto_reconnecting"])
	assert_true(state["auto_retry_enabled"])
	assert_eq(state["reconnect_seconds"], 1)
	assert_false(NetworkManager._server_keepalive_tracking)


func test_request_players_update_sends_explicit_refresh_message():
	var socket = MockSocket.new()
	NetworkManager._socket = socket

	assert_true(NetworkManager.request_players_update())
	assert_eq(socket.sent_messages.size(), 1)
	var parser = JSON.new()
	assert_eq(parser.parse(socket.sent_messages[0]), OK)
	assert_eq(parser.data.get("type", ""), "request_players_update")


func test_player_disconnect_pending_starts_waiting_for_opponent():
	watch_signals(NetworkManager)
	NetworkManager._handle_player_disconnect_pending({
		"type": "player_disconnect_pending",
		"player_id": 42,
		"player_name": "Opponent",
	})

	assert_true(NetworkManager.is_waiting_for_opponent_reconnect())
	# A pending disconnect must NOT end the game.
	assert_signal_not_emitted(NetworkManager, "other_player_quit")


func test_player_disconnect_reconnect_timeout_is_terminal():
	NetworkManager.begin_waiting_for_opponent_reconnect()
	watch_signals(NetworkManager)

	NetworkManager._handle_player_disconnect({
		"type": "player_disconnect",
		"player_id": 42,
		"player_name": "Opponent",
		"reason": "reconnect_timeout",
	})

	assert_false(NetworkManager.is_waiting_for_opponent_reconnect())
	assert_signal_emitted(NetworkManager, "other_player_quit")


func test_player_reconnect_ends_waiting_for_opponent():
	NetworkManager.begin_waiting_for_opponent_reconnect()
	assert_true(NetworkManager.is_waiting_for_opponent_reconnect())

	NetworkManager._handle_player_reconnect({
		"type": "player_reconnect",
		"player_id": 42,
		"player_name": "Opponent",
	})

	assert_false(NetworkManager.is_waiting_for_opponent_reconnect())


func test_leave_room_sends_normal_game_over_when_match_finished():
	var socket = MockSocket.new()
	NetworkManager._socket = socket
	NetworkManager.set_active_remote_match_finished(true)

	NetworkManager.leave_room()

	assert_eq(socket.sent_messages.size(), 1)
	var parser = JSON.new()
	assert_eq(parser.parse(socket.sent_messages[0]), OK)
	assert_eq(parser.data.get("type", ""), "leave_room")
	assert_true(parser.data.get("normal_game_over", false))
	assert_false(NetworkManager._active_remote_match_finished)


func test_player_disconnect_pending_ignored_after_normal_game_over():
	NetworkManager.set_active_remote_match_finished(true)

	NetworkManager._handle_player_disconnect_pending({
		"type": "player_disconnect_pending",
		"player_id": 42,
		"player_name": "Opponent",
	})

	assert_false(NetworkManager.is_waiting_for_opponent_reconnect())


func test_restore_request_includes_previous_session_token():
	var socket = MockSocket.new()
	NetworkManager._socket = socket
	NetworkManager.network_state = NetworkManager.NetworkState.NetworkState_Connected
	NetworkManager._previous_server_session_token = "secret-token"
	NetworkManager._previous_server_session_id = "sess-1"
	NetworkManager._previous_server_player_id = "player-1"
	NetworkManager.reconnect_state["pre_disconnect_state"] = NetworkManager.RestoreContextType.RestoreContextType_Game

	NetworkManager._request_session_restore()

	assert_eq(socket.sent_messages.size(), 1)
	var parser = JSON.new()
	assert_eq(parser.parse(socket.sent_messages[0]), OK)
	assert_eq(parser.data.get("type", ""), "restore_session")
	var context = parser.data.get("context", {})
	assert_eq(context.get("previous_session_token", ""), "secret-token")
	assert_eq(context.get("previous_session_id", ""), "sess-1")
	assert_eq(context.get("previous_player_id", ""), "player-1")
	# reset the send-guard for later tests
	NetworkManager._restore_request_sent = false


func test_session_restore_failed_clears_stored_identity():
	# Seed a persisted identity, then simulate a failed restore.
	NetworkManager._current_server_player_id = "p-1"
	NetworkManager._current_server_session_id = "s-1"
	NetworkManager._current_server_session_token = "tok-1"
	NetworkManager._last_connected_server_name = "Alice"
	NetworkManager._persist_identity()
	assert_true(FileAccess.file_exists(NetworkManager.SESSION_PERSIST_PATH))

	NetworkManager._handle_session_restore_failed({
		"type": "session_restore_failed",
		"reason": "no_matching_session",
	})

	assert_false(FileAccess.file_exists(NetworkManager.SESSION_PERSIST_PATH))
	assert_eq(NetworkManager._previous_server_session_token, "")


func test_persisted_identity_round_trips_for_cold_restart():
	NetworkManager._current_server_player_id = "cold-player"
	NetworkManager._current_server_session_id = "cold-session"
	NetworkManager._current_server_session_token = "cold-token"
	NetworkManager._last_connected_server_name = "ColdName"
	NetworkManager._persist_identity()

	# Simulate a fresh boot: clear the in-memory identity and reload from disk.
	NetworkManager._previous_server_session_token = ""
	NetworkManager._previous_server_player_id = null
	NetworkManager._cold_restore_pending = false
	NetworkManager._load_persisted_identity()

	assert_eq(NetworkManager._previous_server_session_token, "cold-token")
	assert_eq(NetworkManager._previous_server_session_id, "cold-session")
	assert_true(NetworkManager._cold_restore_pending)

	# Clean up the file so it does not leak into other runs.
	NetworkManager._clear_persisted_identity()
	assert_false(FileAccess.file_exists(NetworkManager.SESSION_PERSIST_PATH))
