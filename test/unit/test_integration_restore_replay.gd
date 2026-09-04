extends GutTest

# Verifies the reconnect restore-log fast-forward drain logic in game.gd:
# `_advance_restore_fast_forward()` must flip the fast-forward flags correctly and
# drain the starting message queue (surfaced via
# GameWrapper.observer_process_next_message_from_queue) until it is empty.

# Stands in for the RemoteGame current_game: reports a fixed number of queued
# restore-log messages, then reports the queue is empty.
class FakeCurrentGame extends RefCounted:
	var remaining : int
	var drained_calls : int = 0
	# Indexes (by drained_calls order) at which a message is consumed off the queue
	# but reports "nothing processed" -- e.g. a match_result entry in the log.
	var unprocessed_at : Array = []
	func _init(count : int):
		remaining = count
	func has_pending_queued_messages() -> bool:
		return remaining > 0
	func observer_process_next_message_from_queue():
		var index = drained_calls
		drained_calls += 1
		if remaining > 0:
			remaining -= 1
			return not (index in unprocessed_at)
		return false

func _make_game_with_queue(count : int) -> Game:
	var game = Game.new()
	autofree(game)
	autofree(game.game_wrapper)
	game.game_wrapper.current_game = FakeCurrentGame.new(count)
	return game

func test_first_advance_activates_fast_forward():
	var game = _make_game_with_queue(2)
	game.restore_fast_forward_pending = true
	game.restore_fast_forwarding = false
	game._advance_restore_fast_forward()
	assert_true(game.restore_fast_forwarding)
	assert_false(game.restore_fast_forward_pending)

func test_advance_drains_queue_then_resumes_live_play():
	var game = _make_game_with_queue(3)
	game.restore_fast_forward_pending = true
	game.restore_fast_forwarding = false
	# Three messages to drain; each returns true while draining.
	for i in range(3):
		game._advance_restore_fast_forward()
		assert_true(game.restore_fast_forwarding, "Still fast-forwarding on drain %d" % i)
	# The next advance finds the queue empty and resumes live play.
	game._advance_restore_fast_forward()
	assert_false(game.restore_fast_forwarding)

func test_unprocessed_message_midqueue_does_not_strand_the_rest():
	# A restore log can contain an entry that is consumed but dispatches nothing
	# (e.g. match_result). Ending the drain there would strand every later message
	# in the queue, leaving this client permanently behind its opponent.
	var game = _make_game_with_queue(4)
	game.game_wrapper.current_game.unprocessed_at = [1]
	game.restore_fast_forward_pending = true
	game.restore_fast_forwarding = false
	for i in range(4):
		game._advance_restore_fast_forward()
		assert_true(game.restore_fast_forwarding, "Drain stopped early at %d" % i)
	assert_eq(game.game_wrapper.current_game.remaining, 0, "Whole queue must drain")
	game._advance_restore_fast_forward()
	assert_false(game.restore_fast_forwarding)

func test_empty_restore_log_resumes_live_immediately():
	var game = _make_game_with_queue(0)
	game.restore_fast_forward_pending = true
	game.restore_fast_forwarding = false
	game._advance_restore_fast_forward()
	assert_false(game.restore_fast_forwarding)
	assert_false(game.restore_fast_forward_pending)

func test_begin_delay_is_zeroed_while_fast_forwarding():
	var game = _make_game_with_queue(1)
	# change_ui_state() early-returns on GameOver, so begin_delay's delay logic
	# runs without touching UI nodes that don't exist in this bare harness.
	game.ui_state = Game.UIState.UIState_GameOver
	game.restore_fast_forwarding = true
	game.begin_delay(0.5, [])
	assert_eq(game.remaining_delay, 0.0)

func test_begin_delay_uses_raw_delay_when_not_fast_forwarding():
	var game = _make_game_with_queue(1)
	game.ui_state = Game.UIState.UIState_GameOver
	game.restore_fast_forwarding = false
	game.begin_delay(0.5, [])
	assert_eq(game.remaining_delay, 0.5)

func test_emote_spawn_is_suppressed_during_fast_forward():
	var game = _make_game_with_queue(1)
	game.restore_fast_forwarding = true
	# Guard returns before touching any (unready) emote nodes; must not error.
	game.spawn_emote(Enums.PlayerId.PlayerId_Player, false, "hello")
	game._on_emote({
		"event_player": Enums.PlayerId.PlayerId_Player,
		"number": 0,
		"reason": "hello",
	})
	pass_test("Emote entry points returned during fast-forward without error")
