extends GutTest

# RemoteGame maps network messages to handlers by string surgery:
#   'action_foo'  ->  process_foo()
# (see the warning banner at the top of remote_game.gd). A typo or a missing
# handler compiles fine and only breaks online play, so these tests scan the
# source and assert the contract holds for every action, including future ones.

const RemoteGamePath = "res://scenes/core/remote_game.gd"
const GameWrapperPath = "res://scenes/core/game_wrapper.gd"
const LocalGamePath = "res://scenes/core/local_game.gd"

var _file_cache = {}

func _read(path : String) -> String:
	if _file_cache.has(path):
		return _file_cache[path]
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		fail_test("Could not open %s" % path)
		return ""
	var text = file.get_as_text()
	file.close()
	_file_cache[path] = text
	return text

func _find_all(text : String, pattern : String, group : int = 1) -> Array:
	var regex = RegEx.new()
	if regex.compile(pattern) != OK:
		fail_test("Bad regex: %s" % pattern)
		return []
	var found = []
	for match_result in regex.search_all(text):
		found.append(match_result.get_string(group))
	return found

func _action_types() -> Array:
	return _find_all(_read(RemoteGamePath), "'action_type'\\s*:\\s*'(action_[a-z_0-9]+)'")

func _declared_functions(path : String) -> Array:
	return _find_all(_read(path), "(?m)^func\\s+([a-zA-Z_0-9]+)")

# --- action_* <-> process_* --------------------------------------------------

func test_every_action_type_has_a_process_handler():
	var action_types = _action_types()
	assert_gt(action_types.size(), 20, "Expected to find the remote action list")
	var rg = RemoteGame.new(null)
	for action_type in action_types:
		var handler = action_type.replace("action_", "process_")
		assert_true(rg.has_method(handler),
			"RemoteGame.%s missing for '%s'. Incoming remote actions are dispatched by name, so this silently breaks online play." % [handler, action_type])
	rg.free()

func test_every_process_handler_has_an_action_type():
	# Catches a renamed/typo'd action_type that leaves an orphaned handler behind.
	var expected_handlers = {}
	for action_type in _action_types():
		expected_handlers[action_type.replace("action_", "process_")] = true
	for handler in _declared_functions(RemoteGamePath):
		if not handler.begins_with("process_"):
			continue
		assert_true(expected_handlers.has(handler),
			"RemoteGame.%s has no matching 'action_type' literal, so nothing can ever dispatch to it." % handler)

func test_action_types_are_unique_per_handler():
	var seen = {}
	for action_type in _action_types():
		assert_false(seen.has(action_type),
			"Duplicate action_type literal '%s'. Two different actions sharing a name collide on the same handler." % action_type)
		seen[action_type] = true

func test_every_do_action_is_paired_with_a_submit():
	# Each do_* that builds an action_message must actually send it, otherwise the
	# local client acts and the opponent never hears about it.
	var text = _read(RemoteGamePath)
	var blocks = text.split("\nfunc ")
	for block in blocks:
		if not block.begins_with("do_"):
			continue
		if not block.contains("'action_type'"):
			continue
		var func_name = block.split("(")[0]
		assert_true(block.contains("_submit_game_message("),
			"RemoteGame.%s builds an action_message but never calls _submit_game_message()." % func_name)

# --- game_wrapper forwarding -------------------------------------------------

func _wrapper_calls_by_function() -> Dictionary:
	# Returns { function_name: { "guarded": bool, "calls": [names] } }
	# Setup entry points and test-only helpers target one engine by definition.
	var engine_specific = ["initialize_local_game", "initialize_remote_game"]
	var text = _read(GameWrapperPath)
	var result = {}
	for block in text.split("\nfunc "):
		var func_name = block.split("(")[0]
		var calls = _find_all(block, "current_game\\.([a-zA-Z_0-9]+)\\s*\\(")
		if calls.is_empty():
			continue
		# A call is allowed to be one-sided when the wrapper explicitly branches
		# on which engine is running.
		var guarded = block.contains("current_game is ") or block.contains("has_method(") \
			or func_name in engine_specific or func_name.begins_with("_test_")
		result[func_name] = { "guarded": guarded, "calls": calls }
	return result

func test_unguarded_wrapper_forwards_exist_on_both_engines():
	var remote_functions = _declared_functions(RemoteGamePath)
	var local_functions = _declared_functions(LocalGamePath)
	# Object built-ins the wrapper legitimately calls on either engine.
	var builtins = ["free", "has_method", "call", "queue_free"]
	var wrapper_calls = _wrapper_calls_by_function()
	var checked = 0
	for func_name in wrapper_calls:
		var entry = wrapper_calls[func_name]
		if entry["guarded"]:
			continue
		for call_name in entry["calls"]:
			if call_name in builtins:
				continue
			checked += 1
			if not call_name in remote_functions:
				fail_test("game_wrapper.%s calls current_game.%s() unguarded, but RemoteGame has no such method: this crashes online play." % [func_name, call_name])
			if not call_name in local_functions:
				fail_test("game_wrapper.%s calls current_game.%s() unguarded, but LocalGame has no such method: this crashes AI/local play." % [func_name, call_name])
	assert_gt(checked, 30, "Expected to scan the wrapper's forwards")

func test_remote_game_exposes_queue_inspection_api():
	# game.gd's restore fast-forward drives the queue through these.
	var rg = RemoteGame.new(null)
	for method_name in [
		"observer_process_next_message_from_queue",
		"has_pending_queued_messages",
		"get_pending_observer_messages",
		"get_next_observer_message",
		"get_message_history",
	]:
		assert_true(rg.has_method(method_name), "RemoteGame.%s missing" % method_name)
	rg.free()
