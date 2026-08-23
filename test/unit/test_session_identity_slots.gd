extends GutTest

# Two clients that share a storage location (two Godot debug windows, or two
# browser tabs on the same origin) must not persist into the same identity file.
# When they did, both replayed the same session token on the next launch and
# took turns kicking each other off the one seat with session_replaced.

const NetworkManagerScript = preload("res://globals/network_manager.gd")

var _managers : Array = []

func _make_manager():
	var manager = NetworkManagerScript.new()
	# _ready() claims a slot; add_child triggers it.
	add_child(manager)
	_managers.append(manager)
	return manager

func before_each():
	_managers = []
	_clear_session_files()

func after_each():
	# Free immediately rather than deferring: a manager that is still alive keeps
	# heartbeating its lock, which would leak slot ownership into the next test.
	for manager in _managers:
		if is_instance_valid(manager):
			remove_child(manager)
			manager.free()
	_managers = []
	_clear_session_files()

func _clear_session_files():
	var dir = DirAccess.open("user://")
	if not dir:
		return
	for file_name in dir.get_files():
		if file_name.begins_with("session"):
			dir.remove(file_name)

# A stateless helper instance used only to call the slot predicates.
var _manager_under_test = NetworkManagerScript.new()

# Writes a lock as an abandoned owner would leave it behind after a hard kill.
func _write_abandoned_lock(slot : int, seconds_old : int):
	var config = ConfigFile.new()
	config.set_value("lock", "instance_id", "abandoned_instance")
	config.set_value("lock", "heartbeat", int(Time.get_unix_time_from_system()) - seconds_old)
	config.save(NetworkManagerScript.SESSION_SLOT_LOCK_FORMAT % slot)

# A unix timestamp written as a float goes through ConfigFile in scientific
# notation and comes back rounded to the nearest few thousand seconds - often
# into the future - which silently breaks staleness detection entirely.
func test_slot_lock_heartbeat_survives_a_round_trip():
	var manager = _make_manager()
	var before = int(Time.get_unix_time_from_system())
	manager._write_session_slot_lock(manager._session_slot, "precision_check")
	var after = int(Time.get_unix_time_from_system())

	var lock = manager._read_session_slot_lock(manager._session_slot)
	assert_between(lock["heartbeat"], before, after,
		"heartbeat must round-trip to the exact second, not a rounded float")

func _persist(manager, token : String, player_name : String):
	manager._current_server_session_token = token
	manager._current_server_session_id = "session_" + token
	manager._current_server_player_id = "player_" + token
	manager._last_connected_server_name = player_name
	manager._persist_identity()

func test_first_instance_claims_slot_zero():
	var manager = _make_manager()
	assert_eq(manager._session_slot, 0)

func test_second_concurrent_instance_claims_a_different_slot():
	var first = _make_manager()
	var second = _make_manager()
	assert_eq(first._session_slot, 0)
	assert_eq(second._session_slot, 1)

func test_concurrent_instances_persist_to_separate_files():
	var first = _make_manager()
	var second = _make_manager()
	assert_ne(first._get_session_store_key(), second._get_session_store_key())

# The original bug: the last writer won, so both instances reloaded one token.
func test_concurrent_instances_do_not_share_a_stored_token():
	var first = _make_manager()
	var second = _make_manager()
	_persist(first, "token_a", "Anon_1")
	_persist(second, "token_b", "Anon_2")

	var first_reloaded = NetworkManagerScript.new()
	first_reloaded._session_slot = first._session_slot
	first_reloaded._load_persisted_identity()
	var second_reloaded = NetworkManagerScript.new()
	second_reloaded._session_slot = second._session_slot
	second_reloaded._load_persisted_identity()

	assert_eq(first_reloaded._previous_server_session_token, "token_a")
	assert_eq(second_reloaded._previous_server_session_token, "token_b")
	assert_ne(first_reloaded._previous_server_session_token,
		second_reloaded._previous_server_session_token)

	first_reloaded.free()
	second_reloaded.free()

# Restore only works if a relaunched instance gets its own prior identity back.
func test_slot_is_reused_after_the_owner_exits():
	var first = _make_manager()
	_persist(first, "token_a", "Anon_1")
	var slot = first._session_slot

	# Simulate a hard kill: the owner vanishes without releasing its lock, and
	# its heartbeat ages out.
	_managers.erase(first)
	remove_child(first)
	first.free()
	_write_abandoned_lock(slot, int(NetworkManagerScript.SESSION_SLOT_STALE_SECONDS) + 5)

	assert_true(_manager_under_test._session_slot_is_available(slot),
		"an abandoned slot should be reclaimable")

	var relaunched = NetworkManagerScript.new()
	relaunched._session_slot = slot
	relaunched._load_persisted_identity()
	assert_eq(relaunched._previous_server_session_token, "token_a",
		"a relaunched instance should get its own previous identity back")
	relaunched.free()

# Liveness must not depend on OS process APIs: production runs on web, and
# OS.is_process_running() only reports on processes this instance spawned, so
# it would mark every other live client as dead and hand out a shared slot.
func test_a_recently_heartbeat_slot_is_not_reclaimable():
	var slot = 6
	_write_abandoned_lock(slot, 0)
	assert_false(_manager_under_test._session_slot_is_available(slot),
		"a slot heartbeat a moment ago must not be stolen")

func test_slot_ownership_is_revalidated_when_another_instance_takes_over():
	var first = _make_manager()
	var slot = first._session_slot
	first._current_server_session_token = "token_a"
	first._previous_server_session_token = "token_a"

	# Another instance claims the slot while this one is stalled.
	var config = ConfigFile.new()
	config.set_value("lock", "instance_id", "someone_else")
	config.set_value("lock", "heartbeat", int(Time.get_unix_time_from_system()))
	config.save(NetworkManagerScript.SESSION_SLOT_LOCK_FORMAT % slot)

	first._session_slot_heartbeat_timer = 0.0
	first._update_session_slot_heartbeat(1.0)

	assert_ne(first._session_slot, slot,
		"an instance that lost its slot should move to a different one")
	assert_eq(first._previous_server_session_token, "",
		"it must drop the identity that belongs to the slot it lost")

func test_clean_exit_releases_the_slot():
	var first = _make_manager()
	var slot = first._session_slot
	var lock_path = NetworkManagerScript.SESSION_SLOT_LOCK_FORMAT % slot
	assert_true(FileAccess.file_exists(lock_path), "a running instance holds its lock")

	_managers.erase(first)
	remove_child(first)
	first.free()

	assert_false(FileAccess.file_exists(lock_path),
		"a clean shutdown should free the slot for the next launch")

func test_a_live_slot_is_not_considered_available():
	var first = _make_manager()
	assert_false(_manager_under_test._session_slot_is_available(first._session_slot),
		"a slot whose owner is still running must not be reclaimable")

func test_live_slot_is_not_stolen_by_a_new_instance():
	var first = _make_manager()
	var second = NetworkManagerScript.new()
	second._claim_session_slot()
	assert_ne(second._session_slot, first._session_slot)
	second.free()
	_clear_session_files()

func test_legacy_session_file_is_migrated_into_slot_zero():
	var config = ConfigFile.new()
	config.set_value("session", "player_id", "legacy_player")
	config.set_value("session", "session_id", "legacy_session")
	config.set_value("session", "session_token", "legacy_token")
	config.set_value("session", "player_name", "LegacyName")
	config.save(NetworkManagerScript.SESSION_PERSIST_PATH)

	var manager = _make_manager()
	assert_eq(manager._session_slot, 0)
	manager._load_persisted_identity()
	assert_eq(manager._previous_server_session_token, "legacy_token")
	assert_false(FileAccess.file_exists(NetworkManagerScript.SESSION_PERSIST_PATH),
		"legacy file should be consumed so a second instance cannot inherit it")

func test_clearing_identity_only_removes_this_instances_file():
	var first = _make_manager()
	var second = _make_manager()
	_persist(first, "token_a", "Anon_1")
	_persist(second, "token_b", "Anon_2")

	first._clear_persisted_identity()
	assert_true(first._store_read(first._get_session_store_key(), "session").is_empty())
	assert_false(second._store_read(second._get_session_store_key(), "session").is_empty(),
		"one instance logging out must not wipe the other's identity")

# Closing a browser tab does not run _exit_tree, so the lock keeps a heartbeat
# that is only a second or two old. A tab reopened straight away used to skip
# that slot, take a fresh identity, and silently abandon the seat the server was
# still holding open. Releasing the slot on unload is what makes the reopened
# tab land back on its own identity.
func test_relaunch_after_a_released_slot_reclaims_the_same_identity():
	var first = _make_manager()
	var slot = first._session_slot
	_persist(first, "held_token", "Anon_held")

	# Simulate the tab going away: the unload hook clears the lock.
	first._release_session_slot()

	var relaunched = _make_manager()
	assert_eq(relaunched._session_slot, slot,
		"a reopened client should land back on the freed slot")
	relaunched._load_persisted_identity()
	assert_eq(relaunched._previous_server_session_token, "held_token",
		"the reopened client must replay the token so it can reclaim its seat")
	assert_true(relaunched._cold_restore_pending,
		"a stored token should queue a restore on the next server hello")

# The failure the player hit: without the unload hook the lock still looks live,
# so the relaunch lands on a different slot with no token and never asks to
# restore, leaving the held seat stranded.
func test_relaunch_while_the_lock_still_looks_live_gets_a_different_slot():
	var first = _make_manager()
	var slot = first._session_slot
	_persist(first, "held_token", "Anon_held")

	var relaunched = _make_manager()
	assert_ne(relaunched._session_slot, slot)
	relaunched._load_persisted_identity()
	assert_eq(relaunched._previous_server_session_token, "",
		"this is why the seat was stranded: no token to replay")

func test_releasing_a_slot_leaves_the_stored_identity_alone():
	var first = _make_manager()
	var slot = first._session_slot
	_persist(first, "keep_me", "Anon_keep")

	first._release_session_slot()

	assert_false(first._store_read(first._session_slot_store_key(slot), "session").is_empty(),
		"releasing the lock must not discard the identity we want to restore with")
