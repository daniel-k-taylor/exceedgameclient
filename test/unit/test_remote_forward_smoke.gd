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

# Renea places continuous boosts face-down, and the pre-strike reveal that
# resolves them has to travel to the opponent so both engines stay in sync.
func test_remote_game_do_boost_forwards_facedown_override():
	var rg = CaptureRemoteGame.new()
	rg._player_info = { 'id': 17 }
	rg._opponent_info = { 'id': 23 }

	assert_true(rg.do_boost(player1, 42, [], false, 0, [], true))
	assert_eq(rg.last_action_message.get('facedown_override'), true)

	assert_true(rg.do_boost(player1, 42, [], false, 0, [], false))
	assert_eq(rg.last_action_message.get('facedown_override'), false)

	assert_true(rg.do_boost(player1, 42))
	assert_eq(rg.last_action_message.get('facedown_override'), null)
	rg.free()

func test_remote_game_do_renea_pre_strike_reveal_sends_action():
	var rg = CaptureRemoteGame.new()
	rg._player_info = { 'id': 17 }
	rg._opponent_info = { 'id': 23 }

	assert_true(rg.do_renea_pre_strike_reveal(player1))
	assert_eq(rg.last_action_message.get('action_type', ''), 'action_renea_pre_strike_reveal')
	assert_eq(int(rg.last_action_message.get('player_id', -1)), 17)
	assert_eq(rg.last_action_message.get('strike_response'), false)

	assert_true(rg.do_renea_pre_strike_reveal(player1, true))
	assert_eq(rg.last_action_message.get('strike_response'), true)
	rg.free()

# RemoteGame dispatches incoming messages by turning "action_X" into "process_X",
# so a missing handler silently breaks the action in online play.
func test_remote_game_has_renea_pre_strike_reveal_handler():
	var rg = RemoteGame.new(null)
	assert_true(rg.has_method("process_renea_pre_strike_reveal"), "RemoteGame.process_renea_pre_strike_reveal missing")
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

# Tournelouse's optional transform choices can be backed out of; each cancel is
# its own remote action, and a missing process_* handler breaks online play only.
func test_remote_game_cancel_tournelouse_actions_forward():
	var rg = CaptureRemoteGame.new()
	rg._player_info = { 'id': 17 }
	rg._opponent_info = { 'id': 23 }

	assert_true(rg.do_cancel_tournelouse_transform_bonus_choice(player1))
	assert_eq(rg.last_action_message.get('action_type', ''), 'action_cancel_tournelouse_transform_bonus_choice')
	assert_eq(int(rg.last_action_message.get('player_id', -1)), 17)

	assert_true(rg.do_cancel_tournelouse_ouroboros_hand_choice(player1))
	assert_eq(rg.last_action_message.get('action_type', ''), 'action_cancel_tournelouse_ouroboros_hand_choice')

	assert_true(rg.do_cancel_tournelouse_ouroboros_transform_choice(player1))
	assert_eq(rg.last_action_message.get('action_type', ''), 'action_cancel_tournelouse_ouroboros_transform_choice')
	rg.free()

func test_remote_game_has_cancel_tournelouse_handlers():
	var rg = RemoteGame.new(null)
	for handler in [
		"process_cancel_tournelouse_transform_bonus_choice",
		"process_cancel_tournelouse_ouroboros_hand_choice",
		"process_cancel_tournelouse_ouroboros_transform_choice",
	]:
		assert_true(rg.has_method(handler), "RemoteGame.%s missing" % handler)
	rg.free()

# Minato stages seal-to-pay amounts on the RemoteGame before submitting; backing
# out of the payment must not leak that amount into the next action sent.
func test_clear_pending_minato_seal_payment_discards_staged_amount():
	var rg = CaptureRemoteGame.new()
	rg._player_info = { 'id': 17 }
	rg._opponent_info = { 'id': 23 }

	rg.set_pending_minato_seal_payment(2, 1)
	rg.clear_pending_minato_seal_payment()
	var cleared_message = {}
	rg._add_pending_minato_seal_payment(cleared_message)
	assert_false(cleared_message.has('minato_sealed_force'))
	assert_false(cleared_message.has('minato_sealed_gauge'))

	rg.set_pending_minato_seal_payment(2, 1)
	var staged_message = {}
	rg._add_pending_minato_seal_payment(staged_message)
	assert_eq(int(staged_message.get('minato_sealed_force', 0)), 2)
	assert_eq(int(staged_message.get('minato_sealed_gauge', 0)), 1)
	rg.free()
