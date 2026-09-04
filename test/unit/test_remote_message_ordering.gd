extends GutTest

# On reconnect, RemoteGame is created with the server's restore log preloaded
# into its message queue, and game.gd drains that queue one message per frame.
# A live opponent action that arrives mid-drain must be appended to the queue.
# If it is applied immediately it runs against a partially rebuilt game state,
# the engine rejects it, the action is lost forever, and both clients end up
# waiting on each other.

class RecordingRemoteGame extends RemoteGame:
	var processed : Array = []

	func _init():
		super(null)

	func _process_game_message(game_message):
		processed.append(game_message['action_type'])

func _make_remote_game(observer_mode : bool, starting_queue : Array) -> RecordingRemoteGame:
	var rg = RecordingRemoteGame.new()
	rg._observer_mode = observer_mode
	rg._replay_mode = false
	rg._game_message_queue = starting_queue
	return rg

func test_live_message_processed_immediately_when_no_backlog():
	var rg = _make_remote_game(false, [])
	rg._on_remote_game_message({ 'action_type': 'action_move' })
	assert_eq(rg.processed, ['action_move'], "Live message should apply immediately in a normal remote game")
	assert_false(rg.has_pending_queued_messages())
	rg.free()

func test_live_message_queued_behind_restore_log():
	var restore_log = [
		{ 'action_type': 'action_restore_1' },
		{ 'action_type': 'action_restore_2' },
	]
	var rg = _make_remote_game(false, restore_log)

	rg._on_remote_game_message({ 'action_type': 'action_live' })
	assert_eq(rg.processed, [], "Live message must not jump ahead of the restore log")
	assert_eq(rg._game_message_queue.size(), 3)

	# Drain the way game.gd's restore fast-forward does.
	while rg.observer_process_next_message_from_queue():
		pass

	assert_eq(rg.processed, ['action_restore_1', 'action_restore_2', 'action_live'],
		"Restore log then the live action, in arrival order")
	assert_false(rg.has_pending_queued_messages())
	rg.free()

func test_live_messages_stay_ordered_while_backlog_drains():
	var rg = _make_remote_game(false, [{ 'action_type': 'action_restore_1' }])

	rg._on_remote_game_message({ 'action_type': 'action_live_1' })
	# Drain one message; the queue still holds action_live_1.
	assert_true(rg.observer_process_next_message_from_queue())
	rg._on_remote_game_message({ 'action_type': 'action_live_2' })
	assert_eq(rg.processed, ['action_restore_1'])

	while rg.observer_process_next_message_from_queue():
		pass
	assert_eq(rg.processed, ['action_restore_1', 'action_live_1', 'action_live_2'])

	# Backlog is gone, so later messages go straight through again.
	rg._on_remote_game_message({ 'action_type': 'action_live_3' })
	assert_eq(rg.processed, ['action_restore_1', 'action_live_1', 'action_live_2', 'action_live_3'])
	rg.free()

func test_observer_messages_are_always_queued():
	var rg = _make_remote_game(true, [])
	rg._on_remote_game_message({ 'action_type': 'action_move' })
	assert_eq(rg.processed, [], "Observers always step through the queue")
	assert_true(rg.has_pending_queued_messages())
	rg.free()
