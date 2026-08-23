extends GutTest

# Guards how a restore snapshot is turned into reconnect UI state. Getting this
# wrong strands the player in an inescapable "waiting for opponent" overlay for
# an opponent who already quit, which is what happened when a match ended by a
# player leaving and both clients were then relaunched.

func before_each():
	NetworkManager.end_waiting_for_opponent_reconnect()

func after_each():
	NetworkManager.end_waiting_for_opponent_reconnect()

func _is_waiting() -> bool:
	return NetworkManager.get_reconnect_state()["is_waiting_for_opponent_reconnect"]

func _live_match_snapshot() -> Dictionary:
	return {
		"in_game": true,
		"game_over": false,
		"room_id": "room",
		"opponent_name": "Bob",
		"opponent_connected": false,
		"opponent_reconnect_deadline": (Time.get_unix_time_from_system() + 60.0) * 1000.0,
	}

func test_a_disconnected_opponent_in_a_live_match_is_waited_for():
	NetworkManager._apply_restore_waiting_state(_live_match_snapshot())
	assert_true(_is_waiting(), "this is the case the overlay exists for")
	var remaining = NetworkManager.get_reconnect_state()["waiting_for_opponent_reconnect_remaining_seconds"]
	assert_between(remaining, 58, 61)

func test_a_connected_opponent_is_not_waited_for():
	var snapshot = _live_match_snapshot()
	snapshot["opponent_connected"] = true
	NetworkManager._apply_restore_waiting_state(snapshot)
	assert_false(_is_waiting())

func test_an_opponent_who_already_quit_is_not_waited_for():
	# The server reports a null opponent once they leave for good. Treating
	# that as "disconnected" produced the bogus overlay.
	var snapshot = _live_match_snapshot()
	snapshot["opponent_name"] = null
	snapshot["opponent_connected"] = null
	snapshot["opponent_reconnect_deadline"] = null
	NetworkManager._apply_restore_waiting_state(snapshot)
	assert_false(_is_waiting(), "there is nobody left to wait for")

func test_a_finished_match_is_not_waited_for():
	var snapshot = _live_match_snapshot()
	snapshot["game_over"] = true
	NetworkManager._apply_restore_waiting_state(snapshot)
	assert_false(_is_waiting(), "a finished match has no seat to hold")

func test_a_restore_that_is_not_in_a_match_is_not_waited_for():
	var snapshot = _live_match_snapshot()
	snapshot["in_game"] = false
	snapshot["room_id"] = null
	NetworkManager._apply_restore_waiting_state(snapshot)
	assert_false(_is_waiting())

func test_a_lobby_restore_clears_any_waiting_state():
	NetworkManager._apply_restore_waiting_state(_live_match_snapshot())
	assert_true(_is_waiting())
	NetworkManager._apply_restore_waiting_state({
		"in_game": false,
		"room_id": null,
		"opponent_name": null,
		"opponent_connected": null,
	})
	assert_false(_is_waiting())

func test_a_replaced_session_stops_trying_to_reclaim_itself():
	# Two windows sharing one stored identity used to take turns restoring the
	# session, disconnecting each other in an endless loop.
	NetworkManager._apply_restore_waiting_state(_live_match_snapshot())
	assert_true(_is_waiting())

	var replaced_reason = []
	var handler = func(reason): replaced_reason.append(reason)
	NetworkManager.session_replaced.connect(handler)
	NetworkManager._handle_session_replaced({ "reason": "opened_elsewhere" })
	NetworkManager.session_replaced.disconnect(handler)

	assert_eq(replaced_reason, ["opened_elsewhere"], "the UI must be told why")
	assert_false(_is_waiting(), "there is no match to wait on any more")
	assert_false(NetworkManager._has_previous_restore_identity(),
		"the stolen identity must not be reclaimed, or the two clients ping pong")
	assert_false(NetworkManager.get_reconnect_state()["is_auto_reconnecting"],
		"a replaced session is not a network blip to retry")

func test_leaving_while_waiting_targets_the_lobby_on_any_later_reconnect():
	NetworkManager._apply_restore_waiting_state(_live_match_snapshot())
	assert_true(_is_waiting())

	NetworkManager.quit_waiting_for_opponent()

	assert_false(_is_waiting())
	assert_eq(NetworkManager.get_reconnect_state()["pre_disconnect_state"],
		NetworkManager.RestoreContextType.RestoreContextType_Lobby,
		"leaving must not restore the player back into the match they left")

# --- Rejoining a match from a restore snapshot ---
# The user's report: closing every client mid match and relaunching dropped
# them straight back into a ghost match against an absent opponent.

func _game_start_log() -> Array:
	return [{"type": "game_start", "player1_id": "p1", "player2_id": "p2"}]

func test_a_live_match_is_rejoined():
	var data = {"in_game": true, "game_over": false, "messages": _game_start_log()}
	assert_true(MainMenu.should_rejoin_restored_match(data))

func test_a_finished_match_is_not_rejoined():
	# The seat can still be held after the room ended, so in_game stays true.
	var data = {"in_game": true, "game_over": true, "messages": _game_start_log()}
	assert_false(MainMenu.should_rejoin_restored_match(data),
		"rejoining a dead match traps the player in a game they cannot leave")

func test_a_lobby_restore_is_not_rejoined():
	var data = {"in_game": false, "game_over": false, "messages": []}
	assert_false(MainMenu.should_rejoin_restored_match(data))

func test_a_match_without_a_replay_log_is_not_rejoined():
	var data = {"in_game": true, "game_over": false, "messages": []}
	assert_false(MainMenu.should_rejoin_restored_match(data))

func test_a_log_that_does_not_start_with_game_start_is_not_rejoined():
	var data = {"in_game": true, "game_over": false, "messages": [{"type": "game_message"}]}
	assert_false(MainMenu.should_rejoin_restored_match(data))
