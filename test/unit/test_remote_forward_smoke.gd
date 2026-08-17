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
