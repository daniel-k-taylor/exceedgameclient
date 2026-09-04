extends GutTest

# End-to-end netcode tests. Both clients run their own deterministic LocalGame
# and only exchange action messages, so any divergence in how those messages are
# ordered, queued or replayed shows up as two engines disagreeing about state.
#
# These tests stand up two RemoteGames plus a miniature "server" that logs and
# broadcasts, which lets us reproduce reconnect restore, observer catch-up and
# replay against the real engine instead of mocks.

const P1Deck = "solbadguy"
const P2Deck = "ryu"
const P1Id = "11111111-1111-4111-8111-111111111111"
const P2Id = "22222222-2222-4222-8222-222222222222"
const TestSeed = 987654321

class SyncClient extends RemoteGame:
	# True when this client is sitting in the first player's seat.
	var is_p1_seat : bool = true
	var outbox : Array = []

	func _init():
		super(null)

	func _submit_game_message(action_message):
		_add_pending_minato_seal_payment(action_message)
		outbox.append(action_message.duplicate(true))

var _clients : Array = []
var _message_log : Array = []

func after_each():
	for client in _clients:
		if is_instance_valid(client):
			if client.local_game:
				client.local_game.teardown()
				client.local_game.free()
				client.local_game = null
			client.free()
	_clients = []
	_message_log = []

# --- harness ----------------------------------------------------------------

# Mirrors RemoteGame.initialize_game() without touching NetworkManager, so the
# test drives message delivery itself.
func _make_client(is_p1_seat : bool, observer_mode : bool = false, starting_queue : Array = []) -> SyncClient:
	var p1_info = { 'id': P1Id, 'name': 'p1', 'deck': CardDataManager.get_deck_from_str_id(P1Deck) }
	var p2_info = { 'id': P2Id, 'name': 'p2', 'deck': CardDataManager.get_deck_from_str_id(P2Deck) }

	var client = SyncClient.new()
	client.is_p1_seat = is_p1_seat
	client._observer_mode = observer_mode
	client._replay_mode = false
	client._game_message_queue = starting_queue
	client._game_message_history = []

	# p1 always moves first, so from p2's seat the starting player is "Opponent".
	var me = p1_info if is_p1_seat else p2_info
	var them = p2_info if is_p1_seat else p1_info
	var starting_player = Enums.PlayerId.PlayerId_Player if is_p1_seat else Enums.PlayerId.PlayerId_Opponent

	client._player_info = me
	client._opponent_info = them
	client.image_loader = CardImageLoader.new(true)
	client.local_game = LocalGame.new(client.image_loader)
	client.local_game.initialize_game(me['deck'], them['deck'], me['name'], them['name'],
		starting_player, TestSeed)
	client.local_game.draw_starting_hands_and_begin()
	client.local_game.get_latest_events()
	_clients.append(client)
	return client

func _seat_player(client : SyncClient, want_p1 : bool) -> Player:
	if client.is_p1_seat == want_p1:
		return client.local_game.player
	return client.local_game.opponent

func _card_ids(cards : Array) -> Array:
	var ids = []
	for card in cards:
		ids.append(card.id)
	return ids

# A perspective-neutral description of the whole game. Two clients that agree on
# this string have identical engine state, including hidden zones and deck order.
func _signature(client : SyncClient) -> String:
	var game = client.local_game
	var active_is_p1 = (game.active_turn_player == Enums.PlayerId.PlayerId_Player) == client.is_p1_seat
	var parts = [
		"state=%s" % str(game.game_state),
		"active_p1=%s" % str(active_is_p1),
		"over=%s" % str(game.game_over),
	]
	for want_p1 in [true, false]:
		var seat = _seat_player(client, want_p1)
		parts.append("seat%s{life=%d loc=%d exceeded=%s hand=%s deck=%s gauge=%s discards=%s}" % [
			"1" if want_p1 else "2",
			seat.life, seat.arena_location, str(seat.exceeded),
			str(_card_ids(seat.hand)), str(_card_ids(seat.deck)),
			str(_card_ids(seat.gauge)), str(_card_ids(seat.discards)),
		])
	return " | ".join(parts)

# Delivers everything sitting in any client's outbox, in submission order,
# exactly the way gameroom.js broadcast() does: log it, then send to everyone.
func _pump() -> int:
	var delivered = 0
	var progressed = true
	while progressed:
		progressed = false
		for source in _clients:
			while not source.outbox.is_empty():
				var message = source.outbox.pop_front()
				_message_log.append(message.duplicate(true))
				for target in _clients:
					target._on_remote_game_message(message.duplicate(true))
				delivered += 1
				progressed = true
	return delivered

func _drain(client : SyncClient) -> int:
	var count = 0
	while client.observer_process_next_message_from_queue():
		count += 1
	return count

func _assert_in_sync(a : SyncClient, b : SyncClient, context : String):
	assert_eq(_signature(b), _signature(a), "Clients out of sync: %s" % context)

# Plays a short but real game: both mulligan, then each player prepares on their
# turn, discarding down to max when the engine asks.
func _play_opening(a : SyncClient, b : SyncClient, turns : int):
	a.do_mulligan(_seat_player(a, true), [])
	_pump()
	b.do_mulligan(_seat_player(b, false), [])
	_pump()
	_assert_in_sync(a, b, "after mulligans")

	for i in range(turns):
		if a.local_game.game_over:
			break
		var actor = a if a.local_game.active_turn_player == Enums.PlayerId.PlayerId_Player else b
		var acting_player = actor.local_game.player
		assert_true(actor.local_game.can_do_prepare(acting_player), "Prepare should be legal on turn %d" % i)
		actor.do_prepare(acting_player)
		_pump()
		_resolve_discard_to_max(a, b)
		_assert_in_sync(a, b, "after turn %d" % i)

func _resolve_discard_to_max(a : SyncClient, b : SyncClient):
	while a.local_game.game_state == Enums.GameState.GameState_DiscardDownToMax:
		# The engine only ever asks the active turn player to discard.
		var actor = a if a.local_game.active_turn_player == Enums.PlayerId.PlayerId_Player else b
		var acting_player = actor.local_game.player
		var over_by = acting_player.hand.size() - acting_player.max_hand_size
		assert_gt(over_by, 0, "Expected an oversized hand")
		var to_discard = _card_ids(acting_player.hand).slice(0, over_by)
		actor.do_discard_to_max(acting_player, to_discard)
		_pump()

# --- baseline sync ----------------------------------------------------------

func test_two_clients_start_in_sync():
	var a = _make_client(true)
	var b = _make_client(false)
	_assert_in_sync(a, b, "at game start")
	# Sanity: the seat mapping really is crossed between the two perspectives.
	assert_eq(a.local_game.player.name, "p1")
	assert_eq(b.local_game.player.name, "p2")
	assert_eq(_card_ids(_seat_player(a, true).deck), _card_ids(_seat_player(b, true).deck),
		"Both clients must shuffle the first player's deck identically")

func test_clients_stay_in_sync_across_several_turns():
	var a = _make_client(true)
	var b = _make_client(false)
	_play_opening(a, b, 6)
	assert_gt(_message_log.size(), 6, "Expected a real message log")

func test_every_delivered_message_lands_in_both_histories():
	var a = _make_client(true)
	var b = _make_client(false)
	_play_opening(a, b, 4)
	assert_eq(a.get_message_history().size(), _message_log.size())
	assert_eq(b.get_message_history().size(), _message_log.size())
	for i in range(_message_log.size()):
		assert_eq(a.get_message_history()[i]['action_type'], _message_log[i]['action_type'],
			"History order diverged at %d" % i)

func test_history_stamps_the_local_player_id():
	# Replays are saved from history, so each client has to stamp its own seat.
	var a = _make_client(true)
	var b = _make_client(false)
	_play_opening(a, b, 2)
	assert_gt(a.get_message_history().size(), 0)
	assert_eq(a.get_message_history()[0]['your_player_id'], P1Id)
	assert_eq(b.get_message_history()[0]['your_player_id'], P2Id)

# --- reconnect restore ------------------------------------------------------

func test_reconnecting_client_rebuilds_identical_state_from_the_restore_log():
	var a = _make_client(true)
	var b = _make_client(false)
	_play_opening(a, b, 6)

	# The server hands a reconnecting client the full log (gameroom.js
	# get_replay_messages) and the client replays it from a fresh engine.
	var restored = _make_client(true, false, _message_log.duplicate(true))
	assert_true(restored.has_pending_queued_messages())
	var replayed = _drain(restored)
	assert_eq(replayed, _message_log.size(), "Restore log should replay in full")
	assert_false(restored.has_pending_queued_messages())
	_assert_in_sync(a, restored, "after replaying the restore log")

func test_live_action_during_restore_replay_is_not_lost():
	# The reported reconnect deadlock: while the restore log is still draining, an
	# opponent action arrives. If it is applied ahead of the backlog the engine
	# rejects it, the action vanishes, and both clients wait on each other.
	var a = _make_client(true)
	var b = _make_client(false)
	_play_opening(a, b, 5)

	# The restoring client joins the broadcast group with the log preloaded, so
	# everything the live game produces from here also lands on its socket.
	var restored = _make_client(true, false, _message_log.duplicate(true))
	var backlog_size = _message_log.size()

	# game.gd drains a message per frame; stop partway, like a real client.
	for i in range(3):
		assert_true(restored.observer_process_next_message_from_queue())
	assert_true(restored.has_pending_queued_messages(), "Backlog should remain")

	# The live game moves on while the backlog is still draining.
	var actor = a if a.local_game.active_turn_player == Enums.PlayerId.PlayerId_Player else b
	actor.do_prepare(actor.local_game.player)
	_pump()
	_resolve_discard_to_max(a, b)
	assert_gt(_message_log.size(), backlog_size, "Expected new live messages")

	# Those live messages must be sitting behind the backlog, not applied already.
	assert_eq(restored.get_message_history().size(), 3,
		"A live message jumped the restore backlog and was applied out of order")

	while restored.has_pending_queued_messages():
		restored.observer_process_next_message_from_queue()
	_assert_in_sync(a, restored, "after a live action arrived mid-restore")

func test_restore_log_replays_when_the_client_reconnects_at_game_start():
	# Degenerate case: dropped before doing anything. The log is short but the
	# same code path has to work.
	var a = _make_client(true)
	var b = _make_client(false)
	a.do_mulligan(_seat_player(a, true), [])
	_pump()

	var restored = _make_client(true, false, _message_log.duplicate(true))
	_drain(restored)
	_assert_in_sync(a, restored, "after replaying a one-message restore log")

func test_empty_restore_log_leaves_the_client_at_game_start():
	var a = _make_client(true)
	var restored = _make_client(true, false, [])
	assert_false(restored.has_pending_queued_messages())
	assert_eq(_drain(restored), 0)
	_assert_in_sync(a, restored, "with an empty restore log")

# --- observers --------------------------------------------------------------

func test_observer_queues_everything_and_catches_up_in_order():
	var a = _make_client(true)
	var b = _make_client(false)
	var observer = _make_client(true, true)
	_play_opening(a, b, 5)

	# The observer received every broadcast but processed none of them yet.
	assert_eq(observer.get_pending_observer_messages().size(), _message_log.size())
	assert_eq(observer.get_message_history().size(), 0, "Observers must not auto-apply messages")

	assert_eq(_drain(observer), _message_log.size())
	_assert_in_sync(a, observer, "after the observer caught up")

func test_observer_peek_helpers_do_not_consume():
	var a = _make_client(true)
	var b = _make_client(false)
	var observer = _make_client(true, true)
	a.do_mulligan(_seat_player(a, true), [])
	_pump()

	var before = observer.get_pending_observer_messages().size()
	assert_gt(before, 0)
	assert_eq(observer.get_next_observer_message()['action_type'], 'action_mulligan')
	assert_eq(observer.get_pending_observer_messages().size(), before, "Peeking must not consume")

	# The pending list is a copy; mutating it must not disturb the real queue.
	var peeked = observer.get_pending_observer_messages()
	peeked.clear()
	assert_eq(observer.get_pending_observer_messages().size(), before)
	assert_true(b != null)

func test_get_next_observer_message_is_empty_when_drained():
	var observer = _make_client(true, true)
	assert_eq(observer.get_next_observer_message(), {})
	assert_eq(observer.get_pending_observer_messages(), [])
	assert_false(observer.has_pending_queued_messages())

# --- queue mechanics --------------------------------------------------------

func test_match_result_stops_the_drain_but_is_consumed():
	# observer_process_next_message_from_queue() reports "no more" on match_result
	# so the UI stops stepping; the message must still leave the queue or the
	# client would spin on it forever.
	var observer = _make_client(true, true)
	observer._on_remote_game_message({ 'action_type': 'match_result' })
	observer._on_remote_game_message({ 'action_type': 'action_prepare', 'player_id': P1Id })
	assert_eq(observer.get_pending_observer_messages().size(), 2)

	assert_false(observer.observer_process_next_message_from_queue(), "match_result ends the drain")
	assert_eq(observer.get_pending_observer_messages().size(), 1, "match_result must be consumed")

func test_queued_backlog_keeps_later_live_messages_queued():
	var a = _make_client(true)
	var b = _make_client(false)
	# Give the p1 client a pretend backlog so it must not apply live messages.
	a._game_message_queue.append({ 'action_type': 'match_result' })

	b.do_mulligan(_seat_player(b, false), [])
	_pump()
	assert_eq(a.get_message_history().size(), 0, "Live message must wait behind the backlog")
	assert_eq(a.get_pending_observer_messages().size(), 2)
