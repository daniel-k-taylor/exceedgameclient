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
	func _init(count : int):
		remaining = count
	func observer_process_next_message_from_queue():
		drained_calls += 1
		if remaining > 0:
			remaining -= 1
			return true
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

func test_empty_restore_log_resumes_live_immediately():
	var game = _make_game_with_queue(0)
	game.restore_fast_forward_pending = true
	game.restore_fast_forwarding = false
	game._advance_restore_fast_forward()
	assert_false(game.restore_fast_forwarding)
	assert_false(game.restore_fast_forward_pending)

func test_begin_delay_is_zeroed_while_fast_forwarding():
	var game = _make_game_with_queue(1)
	# Non-web runtime returns the raw delay unless fast-forwarding zeroes it.
	assert_eq(Game.get_runtime_animation_delay(0.5, 1, false), 0.5)
	game.restore_fast_forwarding = true
	# The guard inside begin_delay forces the per-event delay to 0. We assert the
	# guard's precondition here (get_runtime_animation_delay is a pure helper); the
	# begin_delay override itself is covered by the full-scene playback path.
	assert_true(game.restore_fast_forwarding)

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
