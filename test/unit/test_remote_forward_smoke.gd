extends ExceedGutTest

func who_am_i():
	return "ryu"

class CaptureRemoteGame extends RemoteGame:
	var last_action_message = {}

	func _init():
		super(null)

	func _submit_game_message(action_message):
		last_action_message = action_message

# Smoke check: RemoteGame must forward the generic methods that online (remote)
# matches rely on. Missing forwards previously broke actions in remote play.

func test_remote_game_has_forwarded_methods():
	var rg = RemoteGame.new(null)
	assert_true(rg.has_method("get_other_player"), "RemoteGame.get_other_player missing")
	assert_true(rg.has_method("do_quit"), "RemoteGame.do_quit missing")
	assert_true(rg.has_method("get_pending_observer_messages"), "RemoteGame.get_pending_observer_messages missing")
	assert_true(rg.has_method("get_next_observer_message"), "RemoteGame.get_next_observer_message missing")
	rg.free()

func test_remote_game_do_quit_sends_action_quit_message():
	var rg = CaptureRemoteGame.new()
	rg._player_info = {
		'id': 17,
	}
	rg._opponent_info = {
		'id': 23,
	}

	assert_true(rg.do_quit(Enums.PlayerId.PlayerId_Player, Enums.GameOverReason.GameOverReason_Quit))
	assert_eq(rg.last_action_message.get('action_type', ''), 'action_quit')
	assert_eq(int(rg.last_action_message.get('player_id', -1)), 17)
	assert_eq(int(rg.last_action_message.get('reason', -1)), Enums.GameOverReason.GameOverReason_Quit)
	rg.free()

func test_remote_game_do_quit_uses_opponent_id_for_opponent():
	var rg = CaptureRemoteGame.new()
	rg._player_info = {
		'id': 17,
	}
	rg._opponent_info = {
		'id': 23,
	}

	assert_true(rg.do_quit(Enums.PlayerId.PlayerId_Opponent, Enums.GameOverReason.GameOverReason_Disconnect))
	assert_eq(int(rg.last_action_message.get('player_id', -1)), 23)
	assert_eq(int(rg.last_action_message.get('reason', -1)), Enums.GameOverReason.GameOverReason_Disconnect)
	rg.free()

func test_remote_game_do_boost_sends_action():
	var rg = CaptureRemoteGame.new()
	rg._player_info = {
		'id': 17,
	}
	rg._opponent_info = {
		'id': 23,
	}
	assert_true(rg.do_boost(player1, 42))
	assert_eq(rg.last_action_message.get('action_type', ''), 'action_boost')
	assert_eq(int(rg.last_action_message.get('player_id', -1)), 17)
	assert_eq(int(rg.last_action_message.get('card_id', -1)), 42)
	rg.free()

func test_remote_game_get_next_observer_message_empty_by_default():
	var rg = CaptureRemoteGame.new()
	assert_eq(rg.get_next_observer_message(), {})
	assert_eq(rg.get_pending_observer_messages(), [])
	rg.free()

# The server issues player ids with uuidv4(), so they are GUID strings rather
# than ints. A `-> int` return annotation on _get_player_remote_id used to make
# every remote action throw as soon as an online match started.
const GuidPlayer = "0f2b7a1e-7f4a-4a3c-9a1e-1d2c3b4a5e6f"
const GuidOpponent = "9c8b7a6d-5e4f-4321-8765-0a1b2c3d4e5f"

func test_remote_game_forwards_guid_player_ids():
	var rg = CaptureRemoteGame.new()
	rg._player_info = { 'id': GuidPlayer }
	rg._opponent_info = { 'id': GuidOpponent }

	assert_true(rg.do_quit(Enums.PlayerId.PlayerId_Player, Enums.GameOverReason.GameOverReason_Quit))
	assert_eq(rg.last_action_message.get('player_id', ''), GuidPlayer)

	assert_true(rg.do_quit(Enums.PlayerId.PlayerId_Opponent, Enums.GameOverReason.GameOverReason_Quit))
	assert_eq(rg.last_action_message.get('player_id', ''), GuidOpponent)

	assert_true(rg.do_boost(player1, 42))
	assert_eq(rg.last_action_message.get('player_id', ''), GuidPlayer)
	rg.free()

func test_remote_game_resolves_players_from_guid_ids():
	var rg = CaptureRemoteGame.new()
	rg.local_game = game_logic
	rg._player_info = { 'id': GuidPlayer }
	rg._opponent_info = { 'id': GuidOpponent }

	assert_eq(rg._get_player_remote_id(player1), GuidPlayer)
	assert_eq(rg._get_player_remote_id(player2), GuidOpponent)
	assert_eq(rg._get_player_from_remote_id(GuidPlayer), player1)
	assert_eq(rg._get_player_from_remote_id(GuidOpponent), player2)

	rg.local_game = null
	rg.free()

func test_remote_game_clock_ran_out_matches_guid_owner():
	var rg = CaptureRemoteGame.new()
	rg._player_info = { 'id': GuidPlayer }
	rg._opponent_info = { 'id': GuidOpponent }

	rg.do_clock_ran_out()
	assert_eq(rg.last_action_message.get('action_type', ''), 'action_clock_ran_out')
	assert_eq(rg.last_action_message.get('clock_ran_out_player', ''), GuidPlayer)
	rg.free()
