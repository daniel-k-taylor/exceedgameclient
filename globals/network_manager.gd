extends Node

signal disconnected_from_server
signal connected_to_server(server_name)
signal room_join_failed(error_message)
signal request_failed(error_message)
signal game_started(data)
signal game_message_received(message)
signal observe_started(data)
signal other_player_quit(is_disconnect)
signal players_update(players, matches, queues, newly_available_match)
signal customs_update(customs)
signal name_update(name)
signal reconnect_state_changed(state)
signal waiting_for_opponent_reconnect_changed(is_waiting, seconds)
signal session_restore_requested(context)
signal session_restore_succeeded(data)
signal session_restore_failed(reason)
signal session_replaced(reason)

enum NetworkState {
	NetworkState_NotConnected,
	NetworkState_Connecting,
	NetworkState_Connected,
}

var network_state = NetworkState.NetworkState_NotConnected
var cached_players = []
var cached_matches = []
var cached_queues = []
var cached_customs = {}

# Auto-reconnect / keepalive tuning.
const AUTO_RECONNECT_INTERVAL_SECONDS = 5.0
const AUTO_RECONNECT_MANUAL_THRESHOLD_SECONDS = 100
const SERVER_KEEPALIVE_TIMEOUT_SECONDS = 30.0
# Guards the opponent reconnect countdown against client/server clock skew.
const MaxReasonableReconnectGraceSeconds = 30 * 60

# Where the identity triple is persisted so a cold app/browser restart can
# reclaim the seat. On HTML5 web exports user:// maps to localStorage.
#
# Each running instance owns its own slot. Without this, two clients sharing a
# storage location (two Godot debug windows, or two browser tabs on the same
# origin - localStorage is per-origin, not per-tab) both persist into one file
# and then both replay the *same* token on the next launch. They take turns
# reclaiming the one seat, kicking each other off with session_replaced in a
# loop. A slot keeps each instance's identity separate while still being stable
# across a restart, so restore still works.
const SESSION_PERSIST_PATH = "user://session.cfg"
const SESSION_SLOT_PATH_FORMAT = "user://session_slot_%d.cfg"
const SESSION_SLOT_LOCK_FORMAT = "user://session_slot_%d.lock"
const MAX_SESSION_SLOTS = 8
# A slot whose owner has not refreshed its lock within this window is treated as
# abandoned (the process was killed) and may be reclaimed. Kept short so a
# relaunch after a hard kill does not have to wait long, but comfortably above
# the heartbeat interval so a busy frame cannot expire a live slot.
const SESSION_SLOT_STALE_SECONDS = 8.0
const SESSION_SLOT_HEARTBEAT_SECONDS = 2.0

enum RestoreContextType {
	RestoreContextType_None,
	RestoreContextType_Lobby,
	RestoreContextType_Room,
	RestoreContextType_Matchmaking,
	RestoreContextType_Game,
	RestoreContextType_Observe,
}

var reconnect_state = {
	"is_auto_reconnecting": false,
	"auto_retry_enabled": false,
	"reconnect_seconds": 0,
	"last_reconnect_attempt_time": -1.0,
	"is_manual_reconnect": false,
	"pre_disconnect_state": RestoreContextType.RestoreContextType_None,
	"was_in_game": false,
	"is_waiting_for_opponent_reconnect": false,
	"waiting_for_opponent_reconnect_seconds": 0,
	# Seconds left before the server gives the opponent's seat away, or -1 when
	# the server did not tell us a deadline.
	"waiting_for_opponent_reconnect_remaining_seconds": -1,
	"user_cancelled": false,
	"disconnect_reason": "",
}

var _reconnect_elapsed := 0.0
var _next_auto_reconnect_in := AUTO_RECONNECT_INTERVAL_SECONDS
var _is_expected_disconnect := false
var _pending_restore_context = {}
var _waiting_for_opponent_reconnect_elapsed := 0.0
# Absolute server deadline (unix ms) for the opponent's held seat, 0 if unknown.
var _waiting_for_opponent_reconnect_deadline_ms := 0.0
var _last_connected_server_name := ""
var _restore_request_sent := false
var _awaiting_name_sync := false
var _current_server_player_id = null
var _previous_server_player_id = null
var _current_server_session_id = ""
var _previous_server_session_id = ""
var _current_server_session_token = ""
var _previous_server_session_token = ""
var _last_server_keepalive_time := -1.0
var _server_keepalive_tracking := false
var _waiting_for_restore_name_sync := false
var _active_remote_match_finished := false

# Cold-restart restore: a stored token loaded at boot that we try once against
# the first server_hello of a brand new connection.
var _cold_restore_pending := false
# Which persisted-identity slot this instance owns. -1 means no slot was free,
# in which case the instance simply runs without persisting an identity.
var _session_slot := -1
var _session_slot_instance_id := ""
var _session_slot_heartbeat_timer := 0.0
# Set once the server tells us another connection owns our session. The stored
# identity is gone, so this client must never try to reclaim it again.
var _session_replaced := false

var _socket = null

func _ready():
	_claim_session_slot()
	_load_persisted_identity()

func _clear_lobby_cache(emit_update := true):
	cached_players = []
	cached_matches = []
	cached_queues = []
	if emit_update:
		players_update.emit(cached_players, cached_matches, cached_queues, false)

func get_restore_context() -> Dictionary:
	return _pending_restore_context.duplicate(true)

func is_server_connected() -> bool:
	return _socket != null

func connect_to_server():
	if _socket != null: return
	_socket = WebSocketPeer.new()
	var server_url = GlobalSettings.get_server_url()
	var result = _socket.connect_to_url(server_url)
	if result != OK:
		_socket = null
		network_state = NetworkState.NetworkState_NotConnected
		_reset_server_keepalive_tracking()
		if reconnect_state["is_auto_reconnecting"] or reconnect_state["is_manual_reconnect"]:
			_mark_reconnect_attempt_failed("Failed to connect to server: %s" % error_string(result))
		else:
			request_failed.emit("Failed to connect to server: %s" % error_string(result))
		return
	print("Connecting to server...")
	network_state = NetworkState.NetworkState_Connecting
	if reconnect_state["is_auto_reconnecting"] or reconnect_state["is_manual_reconnect"]:
		reconnect_state["last_reconnect_attempt_time"] = Time.get_ticks_msec() / 1000.0
		_emit_reconnect_state_changed()

### Reconnect state machine ###

func attempt_manual_reconnect():
	if _socket != null or network_state == NetworkState.NetworkState_Connecting:
		return false
	if reconnect_state["user_cancelled"]:
		reconnect_state["user_cancelled"] = false
	_reconnect_elapsed = 0.0
	_next_auto_reconnect_in = 0.0
	reconnect_state["is_auto_reconnecting"] = true
	reconnect_state["auto_retry_enabled"] = true
	reconnect_state["is_manual_reconnect"] = false
	reconnect_state["reconnect_seconds"] = 1
	reconnect_state["last_reconnect_attempt_time"] = -1.0
	_awaiting_name_sync = false
	_emit_reconnect_state_changed()
	return true

func get_reconnect_state() -> Dictionary:
	return reconnect_state.duplicate(true)

func is_reconnect_active() -> bool:
	return reconnect_state["is_auto_reconnecting"] or reconnect_state["is_manual_reconnect"]

func is_waiting_for_opponent_reconnect() -> bool:
	return reconnect_state["is_waiting_for_opponent_reconnect"]

func set_restore_context(state_type : RestoreContextType, context : Dictionary = {}):
	_pending_restore_context = context.duplicate(true)
	_pending_restore_context["state_type"] = state_type
	if not _pending_restore_context.has("player_name"):
		_pending_restore_context["player_name"] = _get_preferred_player_name()
	reconnect_state["pre_disconnect_state"] = state_type
	reconnect_state["was_in_game"] = state_type == RestoreContextType.RestoreContextType_Game
	_emit_reconnect_state_changed()

func clear_restore_context(clear_game_flag := true):
	_pending_restore_context = {}
	reconnect_state["pre_disconnect_state"] = RestoreContextType.RestoreContextType_None
	if clear_game_flag:
		reconnect_state["was_in_game"] = false
	_emit_reconnect_state_changed()

func begin_waiting_for_opponent_reconnect(deadline_unix_ms : float = 0.0):
	if reconnect_state["is_waiting_for_opponent_reconnect"]:
		return
	reconnect_state["is_waiting_for_opponent_reconnect"] = true
	reconnect_state["waiting_for_opponent_reconnect_seconds"] = 1
	_waiting_for_opponent_reconnect_elapsed = 0.0
	_waiting_for_opponent_reconnect_deadline_ms = deadline_unix_ms
	reconnect_state["waiting_for_opponent_reconnect_remaining_seconds"] = _remaining_opponent_reconnect_seconds()
	waiting_for_opponent_reconnect_changed.emit(true, 1)
	_emit_reconnect_state_changed()

# Converts the server's absolute deadline into seconds remaining. Returns -1
# when there is no usable deadline so callers fall back to counting elapsed
# time. The result is sanity checked because it depends on the client and
# server clocks roughly agreeing.
func _remaining_opponent_reconnect_seconds() -> int:
	if _waiting_for_opponent_reconnect_deadline_ms <= 0.0:
		return -1
	var now_ms = Time.get_unix_time_from_system() * 1000.0
	var remaining_seconds = (_waiting_for_opponent_reconnect_deadline_ms - now_ms) / 1000.0
	if remaining_seconds < 0.0:
		return 0
	if remaining_seconds > MaxReasonableReconnectGraceSeconds:
		return -1
	return int(ceil(remaining_seconds))

# The server sends null for the deadline whenever a seat is not actually being
# held, so this cannot assume a number is present.
func _parse_reconnect_deadline_ms(raw) -> float:
	if raw == null:
		return 0.0
	if raw is float or raw is int:
		return float(raw)
	if raw is String and raw.is_valid_float():
		return float(raw)
	return 0.0

func end_waiting_for_opponent_reconnect():
	if not reconnect_state["is_waiting_for_opponent_reconnect"]:
		return
	reconnect_state["is_waiting_for_opponent_reconnect"] = false
	reconnect_state["waiting_for_opponent_reconnect_seconds"] = 0
	reconnect_state["waiting_for_opponent_reconnect_remaining_seconds"] = -1
	_waiting_for_opponent_reconnect_elapsed = 0.0
	_waiting_for_opponent_reconnect_deadline_ms = 0.0
	waiting_for_opponent_reconnect_changed.emit(false, 0)
	_emit_reconnect_state_changed()

func cancel_reconnect():
	_abort_reconnect_socket()
	reconnect_state["user_cancelled"] = true
	reconnect_state["is_auto_reconnecting"] = false
	reconnect_state["auto_retry_enabled"] = false
	reconnect_state["is_manual_reconnect"] = true
	reconnect_state["last_reconnect_attempt_time"] = -1.0
	_next_auto_reconnect_in = AUTO_RECONNECT_INTERVAL_SECONDS
	_awaiting_name_sync = false
	_emit_reconnect_state_changed()

func _abort_reconnect_socket():
	if _socket:
		_socket.close()
		_socket = null
	network_state = NetworkState.NetworkState_NotConnected
	_reset_server_keepalive_tracking()

func quit_waiting_for_opponent():
	end_waiting_for_opponent_reconnect()
	# The player asked to leave, so the match must be abandoned even if the
	# socket is already gone. Recording the lobby context first means any
	# later reconnect drops them in the lobby instead of restoring them into
	# the match they just walked away from.
	_active_remote_match_finished = false
	set_restore_context(RestoreContextType.RestoreContextType_Lobby, {
		"player_name": _get_preferred_player_name(),
		"lobby_state": "Lobby",
	})
	leave_room()

func _emit_reconnect_state_changed():
	reconnect_state_changed.emit(get_reconnect_state())

func _mark_reconnect_attempt_failed(reason : String):
	if reason:
		reconnect_state["disconnect_reason"] = reason
	reconnect_state["last_reconnect_attempt_time"] = Time.get_ticks_msec() / 1000.0
	_emit_reconnect_state_changed()

func _begin_unexpected_disconnect(reason := ""):
	if _is_expected_disconnect:
		_is_expected_disconnect = false
		return
	if reconnect_state["is_auto_reconnecting"] or reconnect_state["is_manual_reconnect"]:
		return
	_reconnect_elapsed = 0.0
	_next_auto_reconnect_in = 0.0
	reconnect_state["is_auto_reconnecting"] = true
	reconnect_state["auto_retry_enabled"] = true
	reconnect_state["is_manual_reconnect"] = false
	reconnect_state["reconnect_seconds"] = 1
	reconnect_state["last_reconnect_attempt_time"] = -1.0
	reconnect_state["user_cancelled"] = false
	reconnect_state["disconnect_reason"] = reason
	reconnect_state["was_in_game"] = reconnect_state["pre_disconnect_state"] == RestoreContextType.RestoreContextType_Game
	_previous_server_player_id = _current_server_player_id
	_previous_server_session_id = _current_server_session_id
	_previous_server_session_token = _current_server_session_token
	_restore_request_sent = false
	_awaiting_name_sync = false
	_waiting_for_restore_name_sync = false
	_emit_reconnect_state_changed()

func _end_reconnect_flow(restored : bool):
	_reconnect_elapsed = 0.0
	_next_auto_reconnect_in = AUTO_RECONNECT_INTERVAL_SECONDS
	_restore_request_sent = false
	_cold_restore_pending = false
	reconnect_state["is_auto_reconnecting"] = false
	reconnect_state["auto_retry_enabled"] = false
	reconnect_state["is_manual_reconnect"] = false
	reconnect_state["reconnect_seconds"] = 0
	reconnect_state["last_reconnect_attempt_time"] = -1.0
	_awaiting_name_sync = false
	_waiting_for_restore_name_sync = false
	if restored:
		reconnect_state["disconnect_reason"] = ""
	_emit_reconnect_state_changed()

func _request_session_restore():
	if _restore_request_sent:
		return
	if reconnect_state["pre_disconnect_state"] == RestoreContextType.RestoreContextType_None and not _has_previous_restore_identity():
		_end_reconnect_flow(true)
		return
	var context = _pending_restore_context.duplicate(true)
	context["last_connected_server_name"] = _last_connected_server_name
	context["player_name"] = context.get("player_name", _get_preferred_player_name())
	if _previous_server_player_id != null:
		context["previous_player_id"] = _previous_server_player_id
	if _current_server_player_id != null:
		context["current_player_id"] = _current_server_player_id
	if _previous_server_session_id:
		context["previous_session_id"] = _previous_server_session_id
	if _current_server_session_id:
		context["current_session_id"] = _current_server_session_id
	if _previous_server_session_token:
		context["previous_session_token"] = _previous_server_session_token
	if _current_server_session_token:
		context["current_session_token"] = _current_server_session_token
	session_restore_requested.emit(context)
	var restore_message = {
		"type": "restore_session",
		"version": GlobalSettings.get_client_version(),
		"context": context,
	}
	if not _is_socket_open():
		_handle_restore_failed("socket_not_open")
		return
	_restore_request_sent = true
	_send_socket_text(JSON.stringify(restore_message), "restore session")

func _has_previous_restore_identity() -> bool:
	if _session_replaced:
		return false
	return _previous_server_player_id != null or _previous_server_session_id != "" or _previous_server_session_token != ""

func _apply_server_identity(message : Dictionary):
	if message.has("player_id"):
		_current_server_player_id = message["player_id"]
	elif message.has("restored_player_id"):
		_current_server_player_id = message["restored_player_id"]
	elif message.has("old_player_id"):
		_current_server_player_id = message["old_player_id"]
	if message.has("session_id"):
		_current_server_session_id = str(message["session_id"])
	if message.has("session_token"):
		_current_server_session_token = str(message["session_token"])
	if message.has("player_name"):
		_last_connected_server_name = str(message["player_name"])
		_pending_restore_context["player_name"] = _last_connected_server_name
	_persist_identity()

func _apply_restored_server_identity(message : Dictionary):
	# Adopt the restored identity, never the throwaway reconnect player_id.
	if message.has("restored_player_id"):
		_current_server_player_id = message["restored_player_id"]
	elif message.has("old_player_id"):
		_current_server_player_id = message["old_player_id"]
	elif message.has("player_id"):
		_current_server_player_id = message["player_id"]
	if message.has("session_id"):
		_current_server_session_id = str(message["session_id"])
	if message.has("session_token"):
		_current_server_session_token = str(message["session_token"])
	if message.has("player_name"):
		_last_connected_server_name = str(message["player_name"])
		_pending_restore_context["player_name"] = _last_connected_server_name
	_persist_identity()

func _get_preferred_player_name() -> String:
	if _pending_restore_context.has("player_name") and _pending_restore_context["player_name"]:
		return _pending_restore_context["player_name"]
	if GlobalSettings.DefaultPlayerName:
		return GlobalSettings.DefaultPlayerName
	return _last_connected_server_name

func _restore_context_from_server(data):
	session_restore_succeeded.emit(data)
	_apply_restore_waiting_state(data)
	_active_remote_match_finished = false
	_end_reconnect_flow(true)

func _apply_restore_waiting_state(data : Dictionary):
	# There is only somebody to wait for if the restore actually put us back
	# into a live match alongside a named opponent. Without these guards a
	# finished or abandoned match restores straight into a reconnect overlay
	# for an opponent who already quit, which the player cannot escape.
	if not _restore_snapshot_has_live_opponent(data):
		end_waiting_for_opponent_reconnect()
		return
	var has_authoritative_waiting_state = data.has("opponent_disconnected") \
		or data.has("opponent_waiting_for_reconnect") \
		or data.has("opponent_connected")
	if not has_authoritative_waiting_state:
		end_waiting_for_opponent_reconnect()
		return
	var should_wait_for_opponent = false
	if data.has("opponent_connected"):
		should_wait_for_opponent = not _message_flag_is_true(data.get("opponent_connected", true))
	if data.has("opponent_disconnected"):
		should_wait_for_opponent = _message_flag_is_true(data.get("opponent_disconnected", false))
	if data.has("opponent_waiting_for_reconnect"):
		should_wait_for_opponent = _message_flag_is_true(data.get("opponent_waiting_for_reconnect", false))
	if should_wait_for_opponent:
		begin_waiting_for_opponent_reconnect(_parse_reconnect_deadline_ms(data.get("opponent_reconnect_deadline", null)))
	else:
		end_waiting_for_opponent_reconnect()

# A snapshot only describes a seat worth waiting for when the match is still
# running and an opponent still occupies it. The server reports a null
# opponent when they have left for good, which must not be confused with an
# opponent who is merely disconnected.
func _restore_snapshot_has_live_opponent(data : Dictionary) -> bool:
	if data.has("in_game") and not _message_flag_is_true(data.get("in_game", false)):
		return false
	if _message_flag_is_true(data.get("game_over", false)):
		return false
	if data.has("room_id") and data.get("room_id") == null:
		return false
	if data.has("opponent_name") and not data.get("opponent_name"):
		return false
	if data.has("opponent_connected") and data.get("opponent_connected") == null:
		return false
	return true

func _handle_restore_failed(reason):
	print("Session restore failed: ", reason)
	# A stale/expired stored session cannot be reclaimed; drop it and continue
	# as a fresh session.
	_clear_persisted_identity()
	_previous_server_player_id = null
	_previous_server_session_id = ""
	_previous_server_session_token = ""
	clear_restore_context()
	_clear_lobby_cache()
	_waiting_for_restore_name_sync = false
	session_restore_failed.emit(reason)
	_end_reconnect_flow(false)

### Identity persistence (user:// -> localStorage on web) ###

# Claims the lowest slot whose lock is free or stale. Each instance writes a
# unique id into its lock and re-reads it, so two instances starting at the same
# moment cannot both believe they own the same slot.
func _claim_session_slot():
	if _session_slot != -1:
		return
	var instance_id = "%d_%d" % [Time.get_ticks_usec(), randi()]
	for slot in range(MAX_SESSION_SLOTS):
		if not _session_slot_is_available(slot):
			continue
		if not _write_session_slot_lock(slot, instance_id):
			continue
		# Re-read to resolve a race with another instance claiming the same slot.
		if _read_session_slot_lock(slot).get("instance_id", "") != instance_id:
			continue
		_session_slot = slot
		_session_slot_instance_id = instance_id
		_session_slot_heartbeat_timer = 0.0
		_migrate_legacy_session_file()
		return
	# Every slot is live. Run without persistence rather than stealing an
	# identity that another instance is actively using.
	_session_slot = -1

func _session_slot_is_available(slot : int) -> bool:
	var lock = _read_session_slot_lock(slot)
	if lock.is_empty():
		return true
	# Process-id liveness is not usable here: OS.is_process_running() only knows
	# about processes this instance spawned, so it reports every unrelated
	# client as dead and two live instances would share a slot.
	var age = _get_unix_time_seconds() - lock.get("heartbeat", 0)
	# A heartbeat in the future means a clock change; treat it as live rather
	# than stealing a slot that may still be in use.
	if age < 0:
		return false
	return age > SESSION_SLOT_STALE_SECONDS

# Unix time is stored as an int: ConfigFile serialises large floats in
# scientific notation, which rounds a timestamp to the nearest few thousand
# seconds and makes staleness comparisons meaningless.
func _get_unix_time_seconds() -> int:
	return int(Time.get_unix_time_from_system())

func _read_session_slot_lock(slot : int) -> Dictionary:
	var lock_path = SESSION_SLOT_LOCK_FORMAT % slot
	if not FileAccess.file_exists(lock_path):
		return {}
	var config = ConfigFile.new()
	if config.load(lock_path) != OK:
		return {}
	return {
		"instance_id": str(config.get_value("lock", "instance_id", "")),
		"heartbeat": int(config.get_value("lock", "heartbeat", 0)),
	}

func _write_session_slot_lock(slot : int, instance_id : String) -> bool:
	var config = ConfigFile.new()
	config.set_value("lock", "instance_id", instance_id)
	config.set_value("lock", "heartbeat", _get_unix_time_seconds())
	return config.save(SESSION_SLOT_LOCK_FORMAT % slot) == OK

# Free the slot on a clean shutdown so the next launch reuses it right away and
# keeps its identity. A hard kill leaves the lock behind to expire instead.
func _release_session_slot():
	if _session_slot == -1:
		return
	var lock_name = (SESSION_SLOT_LOCK_FORMAT % _session_slot).get_file()
	var dir = DirAccess.open("user://")
	if dir and dir.file_exists(lock_name):
		dir.remove(lock_name)
	_session_slot = -1

func _exit_tree():
	_release_session_slot()

func _update_session_slot_heartbeat(delta : float):
	if _session_slot == -1:
		return
	_session_slot_heartbeat_timer -= delta
	if _session_slot_heartbeat_timer > 0.0:
		return
	_session_slot_heartbeat_timer = SESSION_SLOT_HEARTBEAT_SECONDS

	# If this instance stalled long enough for its lock to look abandoned,
	# another instance may have taken the slot. Re-validating before writing
	# stops two clients from sharing a slot and then fighting over one seat.
	var lock = _read_session_slot_lock(_session_slot)
	var owner_id = str(lock.get("instance_id", ""))
	if not lock.is_empty() and owner_id != _session_slot_instance_id:
		_handle_session_slot_lost()
		return
	_write_session_slot_lock(_session_slot, _session_slot_instance_id)

# Another instance owns our slot now. Drop the identity that came with it and
# move to a slot of our own rather than replaying a token someone else is using.
func _handle_session_slot_lost():
	_session_slot = -1
	_session_slot_instance_id = ""
	_previous_server_player_id = null
	_previous_server_session_id = ""
	_previous_server_session_token = ""
	_cold_restore_pending = false
	_claim_session_slot()

func _get_session_persist_path() -> String:
	if _session_slot == -1:
		return ""
	return SESSION_SLOT_PATH_FORMAT % _session_slot

# Upgrade path for clients that stored an identity before slots existed. Only
# slot 0 adopts it, so a second instance cannot inherit the same token.
func _migrate_legacy_session_file():
	if _session_slot != 0:
		return
	if not FileAccess.file_exists(SESSION_PERSIST_PATH):
		return
	var slot_path = _get_session_persist_path()
	if not FileAccess.file_exists(slot_path):
		var config = ConfigFile.new()
		if config.load(SESSION_PERSIST_PATH) == OK:
			config.save(slot_path)
	var dir = DirAccess.open("user://")
	if dir and dir.file_exists("session.cfg"):
		dir.remove("session.cfg")

func _persist_identity():
	if _current_server_session_token == "":
		return
	var path = _get_session_persist_path()
	if path == "":
		return
	var config = ConfigFile.new()
	config.set_value("session", "player_id", _current_server_player_id)
	config.set_value("session", "session_id", _current_server_session_id)
	config.set_value("session", "session_token", _current_server_session_token)
	config.set_value("session", "player_name", _last_connected_server_name)
	config.save(path)

func _clear_persisted_identity():
	var path = _get_session_persist_path()
	if path == "":
		return
	var dir = DirAccess.open("user://")
	var file_name = path.get_file()
	if dir and dir.file_exists(file_name):
		dir.remove(file_name)

func _load_persisted_identity():
	var path = _get_session_persist_path()
	if path == "" or not FileAccess.file_exists(path):
		return
	var config = ConfigFile.new()
	if config.load(path) != OK:
		return
	var token = str(config.get_value("session", "session_token", ""))
	if token == "":
		return
	_previous_server_player_id = config.get_value("session", "player_id", null)
	_previous_server_session_id = str(config.get_value("session", "session_id", ""))
	_previous_server_session_token = token
	var stored_name = str(config.get_value("session", "player_name", ""))
	if stored_name != "":
		_last_connected_server_name = stored_name
		_pending_restore_context["player_name"] = stored_name
	_cold_restore_pending = true

### Frame update ###

func _process(_delta):
	_update_session_slot_heartbeat(_delta)
	_update_reconnect_timers(_delta)
	_update_server_keepalive_timeout()
	_handle_sockets()

func _begin_server_keepalive_tracking():
	_server_keepalive_tracking = true
	_last_server_keepalive_time = Time.get_ticks_msec() / 1000.0

func _reset_server_keepalive_tracking():
	_server_keepalive_tracking = false
	_last_server_keepalive_time = -1.0

func _record_server_keepalive():
	_server_keepalive_tracking = true
	_last_server_keepalive_time = Time.get_ticks_msec() / 1000.0

func _update_server_keepalive_timeout():
	if not _server_keepalive_tracking:
		return
	if network_state != NetworkState.NetworkState_Connected:
		return
	var elapsed = Time.get_ticks_msec() / 1000.0 - _last_server_keepalive_time
	if elapsed >= SERVER_KEEPALIVE_TIMEOUT_SECONDS:
		_handle_server_keepalive_timeout(elapsed)

func _handle_server_keepalive_timeout(elapsed : float):
	var reason = "Server keepalive timed out after %.1f seconds." % elapsed
	print(reason)
	if _socket:
		_socket.close()
		_socket = null
	network_state = NetworkState.NetworkState_NotConnected
	_reset_server_keepalive_tracking()
	_clear_lobby_cache()
	disconnected_from_server.emit()
	if reconnect_state["is_auto_reconnecting"] or reconnect_state["is_manual_reconnect"]:
		_mark_reconnect_attempt_failed(reason)
	else:
		_begin_unexpected_disconnect(reason)

func _update_reconnect_timers(delta):
	if reconnect_state["is_auto_reconnecting"]:
		_reconnect_elapsed += delta
		var next_seconds = int(floor(_reconnect_elapsed)) + 1
		if reconnect_state["reconnect_seconds"] != next_seconds:
			reconnect_state["reconnect_seconds"] = next_seconds
			if next_seconds >= AUTO_RECONNECT_MANUAL_THRESHOLD_SECONDS:
				_abort_reconnect_socket()
				reconnect_state["is_auto_reconnecting"] = false
				reconnect_state["auto_retry_enabled"] = false
				reconnect_state["is_manual_reconnect"] = true
			_emit_reconnect_state_changed()
		if reconnect_state["auto_retry_enabled"]:
			_next_auto_reconnect_in -= delta
			if _next_auto_reconnect_in <= 0.0 and _socket == null and network_state != NetworkState.NetworkState_Connecting:
				_next_auto_reconnect_in = AUTO_RECONNECT_INTERVAL_SECONDS
				connect_to_server()
	if reconnect_state["is_waiting_for_opponent_reconnect"]:
		_waiting_for_opponent_reconnect_elapsed += delta
		var waiting_seconds = int(floor(_waiting_for_opponent_reconnect_elapsed)) + 1
		var remaining_seconds = _remaining_opponent_reconnect_seconds()
		var remaining_changed = reconnect_state["waiting_for_opponent_reconnect_remaining_seconds"] != remaining_seconds
		if reconnect_state["waiting_for_opponent_reconnect_seconds"] != waiting_seconds or remaining_changed:
			reconnect_state["waiting_for_opponent_reconnect_seconds"] = waiting_seconds
			reconnect_state["waiting_for_opponent_reconnect_remaining_seconds"] = remaining_seconds
			waiting_for_opponent_reconnect_changed.emit(true, waiting_seconds)
			_emit_reconnect_state_changed()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _socket:
			_is_expected_disconnect = true
			_socket.close()

func _handle_sockets():
	if _socket:
		_socket.poll()
		var state = _socket.get_ready_state()
		match state:
			WebSocketPeer.STATE_OPEN:
				if network_state == NetworkState.NetworkState_Connecting:
					print("Connected to server")
					_begin_server_keepalive_tracking()
				network_state = NetworkState.NetworkState_Connected
				while _socket.get_available_packet_count():
					var packet = _socket.get_packet()
					if _socket.was_string_packet():
						var strpacket = packet.get_string_from_utf8()
						_handle_server_response(strpacket)
			WebSocketPeer.STATE_CLOSING:
				pass
			WebSocketPeer.STATE_CLOSED:
				var code = _socket.get_close_code()
				var reason = _socket.get_close_reason()
				var is_expected_disconnect = _is_expected_disconnect
				_handle_socket_closed(code, reason, is_expected_disconnect)

func _handle_socket_closed(code : int, reason : String, is_expected_disconnect : bool):
	if _socket:
		_socket.close()
	_socket = null
	network_state = NetworkState.NetworkState_NotConnected
	_reset_server_keepalive_tracking()
	_clear_lobby_cache()
	disconnected_from_server.emit()
	print("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
	_is_expected_disconnect = false
	if code != -1:
		var close_message = "Disconnected from server"
		if reason:
			close_message += ": %s" % reason
		else:
			close_message += " (code %d)" % code
		if is_expected_disconnect:
			request_failed.emit(close_message)
		else:
			_begin_unexpected_disconnect(close_message)
	else:
		if not is_expected_disconnect:
			_begin_unexpected_disconnect(reason)

func _is_socket_open():
	return _socket and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN

func _send_socket_text(json : String, action : String) -> bool:
	if not _is_socket_open():
		_handle_socket_send_failed("Cannot %s: socket is not open." % action)
		return false
	var result = _socket.send_text(json)
	if result != OK:
		_handle_socket_send_failed("Cannot %s: %s" % [action, error_string(result)])
		return false
	return true

func _handle_socket_send_failed(reason : String):
	if reconnect_state["is_auto_reconnecting"] or reconnect_state["is_manual_reconnect"]:
		_mark_reconnect_attempt_failed(reason)
		return
	if _socket:
		_socket.close()
		_socket = null
	network_state = NetworkState.NetworkState_NotConnected
	_clear_lobby_cache()
	disconnected_from_server.emit()
	_begin_unexpected_disconnect(reason)

func _emit_not_connected_error(action : String):
	request_failed.emit("Cannot %s: not connected to server." % action)

func _handle_server_response(data):
	var parser = JSON.new()
	var result = parser.parse(data)
	if result != OK:
		print("Error parsing JSON from server: ", data)
		return

	var data_obj = CardDataManager.convert_floats_to_ints(parser.get_data())
	var type = data_obj["type"]
	match type:
		"server_keepalive", "keepalive", "heartbeat":
			_handle_server_keepalive(data_obj)
		"server_hello":
			_handle_server_hello(data_obj)
		"room_waiting_for_opponent":
			_handle_room_waiting_for_opponent(data_obj)
		"room_join_failed":
			_handle_room_join_failed(data_obj)
		"game_start":
			_handle_game_start(data_obj)
		"game_message":
			_handle_game_message(data_obj)
		"name_update":
			_handle_name_update(data_obj)
		"observe_start":
			_handle_observe_start(data_obj)
		"player_disconnect_pending":
			_handle_player_disconnect_pending(data_obj)
		"player_disconnect":
			_handle_player_disconnect(data_obj)
		"player_reconnect":
			_handle_player_reconnect(data_obj)
		"player_quit":
			_handle_player_quit(data_obj)
		"players_update":
			_handle_players_update(data_obj)
		"customs_update":
			_handle_customs_update(data_obj)
		"session_restored":
			_handle_session_restored(data_obj)
		"session_restore_failed":
			_handle_session_restore_failed(data_obj)
		"session_replaced":
			_handle_session_replaced(data_obj)

func _handle_server_keepalive(_message):
	_record_server_keepalive()

func _handle_server_hello(hello_message):
	var player_name = hello_message["player_name"]
	_apply_server_identity(hello_message)
	_last_connected_server_name = player_name
	print("Connected to server as : ", player_name)
	connected_to_server.emit(player_name)
	if is_reconnect_active():
		var preferred_player_name = _get_preferred_player_name().strip_edges()
		if preferred_player_name != "" and preferred_player_name != player_name:
			_waiting_for_restore_name_sync = true
			set_player_name(preferred_player_name)
		else:
			_waiting_for_restore_name_sync = false
			_request_session_restore()
	elif _cold_restore_pending and _previous_server_session_token != "":
		# Brand-new connection at startup with a stored token: try to reclaim
		# the old seat once. Failure clears the stored session.
		_cold_restore_pending = false
		_request_session_restore()
	else:
		# A clean identity from the server means the takeover is behind us.
		_session_replaced = false

func _handle_room_waiting_for_opponent(_waiting_message):
	print("Waiting for opponent in room")
	set_restore_context(RestoreContextType.RestoreContextType_Room, _pending_restore_context)

func _handle_room_join_failed(failed_message):
	var reason = failed_message["reason"]
	var error_message = "ERROR: Failed to join room:\n"
	var invalid_deck = false
	match reason:
		"invalid_custom_deck":
			error_message += "Custom deck is invalid."
			invalid_deck = true
		"invalid_deck_for_queue":
			error_message = "Character not allowed in this queue."
			invalid_deck = true
		"room_full":
			error_message += "Room is full."
		"version_mismatch":
			error_message += "Client Version Mismatch\nCheck for new client version."
		_:
			error_message += "Join Error\n" + reason
	print(error_message)
	room_join_failed.emit(error_message, invalid_deck)

# Accepts a message from the game server indicating a game started.
# Rebroadcasts the message to our scripts.
func _handle_game_start(game_start_message):
	_active_remote_match_finished = false
	var player1_id = game_start_message["player1_id"]
	var player1_name = game_start_message["player1_name"]
	var player2_id = game_start_message["player2_id"]
	var player2_name = game_start_message["player2_name"]
	print("Game started between [%s] %s and [%s] %s" % [player1_id, player1_name, player2_id, player2_name])
	var local_player_name = player1_name
	if game_start_message.get("your_player_id", 0) == player2_id:
		local_player_name = player2_name
	set_restore_context(RestoreContextType.RestoreContextType_Game, {
		"room_id": game_start_message.get("room_id", _pending_restore_context.get("room_id", "")),
		"game_id": game_start_message.get("game_id", ""),
		"player_name": local_player_name,
		"your_player_id": game_start_message.get("your_player_id", 0),
	})
	end_waiting_for_opponent_reconnect()
	game_started.emit(game_start_message)

func _handle_name_update(name_update_message):
	var new_name = name_update_message["name"]
	_apply_server_identity(name_update_message)
	_last_connected_server_name = new_name
	if _pending_restore_context:
		_pending_restore_context["player_name"] = new_name
	name_update.emit(new_name)
	if (_awaiting_name_sync or _waiting_for_restore_name_sync) and is_reconnect_active():
		_awaiting_name_sync = false
		_waiting_for_restore_name_sync = false
		_request_session_restore()

func _handle_observe_start(observe_start_message):
	set_restore_context(RestoreContextType.RestoreContextType_Observe, {
		"player_name": _get_preferred_player_name(),
		"room_id": observe_start_message.get("room_id", ""),
		"game_id": observe_start_message.get("game_id", ""),
	})
	observe_started.emit(observe_start_message)

func _get_message_player_id(message : Dictionary):
	return message.get("id", message.get("player_id", 0))

func _get_message_player_name(message : Dictionary) -> String:
	return str(message.get("name", message.get("player_name", "")))

func _message_flag_is_true(value) -> bool:
	if value is bool:
		return value
	if value is int or value is float:
		return value != 0
	if value is String:
		return value.to_lower() in ["true", "1", "yes"]
	return false

func _message_is_disconnect(message : Dictionary) -> bool:
	return _message_flag_is_true(message.get("disconnect", false)) or _message_flag_is_true(message.get("is_disconnect", false))

# Our server holds a dropped player's seat during a grace period and broadcasts
# player_disconnect_pending to the opponent. This is where the opponent begins
# "waiting for reconnect"; the game is NOT over yet.
func _handle_player_disconnect_pending(message):
	if _active_remote_match_finished:
		return
	var id = _get_message_player_id(message)
	var player_name = _get_message_player_name(message)
	print("Player [%s] %s disconnected, holding seat for reconnect" % [id, player_name])
	begin_waiting_for_opponent_reconnect(_parse_reconnect_deadline_ms(message.get("reconnect_deadline", null)))

# player_disconnect is terminal: either the reconnect grace expired
# (reason == reconnect_timeout) or the game was never a live reconnectable game.
# In every case the seat is gone, so the match ends.
func _handle_player_disconnect(message):
	if _active_remote_match_finished:
		return
	var id = _get_message_player_id(message)
	var player_name = _get_message_player_name(message)
	var reason = str(message.get("reason", ""))
	print("Player [%s] %s disconnected (terminal, reason=%s)" % [id, player_name, reason])
	end_waiting_for_opponent_reconnect()
	other_player_quit.emit(true)

func _handle_player_quit(message):
	if _active_remote_match_finished:
		return
	var id = _get_message_player_id(message)
	var player_name = _get_message_player_name(message)
	if _message_is_disconnect(message):
		print("Player [%s] %s disconnected" % [id, player_name])
		end_waiting_for_opponent_reconnect()
		other_player_quit.emit(true)
		return
	print("Player [%s] %s quit" % [id, player_name])
	end_waiting_for_opponent_reconnect()
	other_player_quit.emit(false)

func _handle_player_reconnect(message):
	var id = _get_message_player_id(message)
	var player_name = _get_message_player_name(message)
	print("Player [%s] %s reconnected" % [id, player_name])
	end_waiting_for_opponent_reconnect()

func _handle_session_restored(message):
	_apply_restored_server_identity(message)
	if message.has("player_name"):
		name_update.emit(message["player_name"])
	_restore_context_from_server(message)
	if _message_flag_is_true(message.get("opponent_left_game", false)) or _message_flag_is_true(message.get("opponent_quit", false)):
		end_waiting_for_opponent_reconnect()
		other_player_quit.emit(false)

func _handle_session_restore_failed(message):
	var reason = message.get("reason", "restore_failed")
	_handle_restore_failed(reason)

# Another connection took ownership of this session, so this client no longer
# owns the stored identity. It must forget it, otherwise the two clients would
# take turns reclaiming the session and disconnecting each other forever.
func _handle_session_replaced(message):
	var reason = str(message.get("reason", "opened_elsewhere"))
	print("Session was taken over by another connection: ", reason)
	_session_replaced = true
	_is_expected_disconnect = true
	end_waiting_for_opponent_reconnect()
	_clear_persisted_identity()
	_previous_server_player_id = null
	_previous_server_session_id = ""
	_previous_server_session_token = ""
	_current_server_session_token = ""
	clear_restore_context()
	_clear_lobby_cache()
	_end_reconnect_flow(false)
	session_replaced.emit(reason)

func _handle_game_message(game_message):
	game_message_received.emit(game_message)

func get_stripped_room_name(room_name : String):
	# If the room name starts with "custom_" remove that from the string.
	if room_name.find("custom_") == 0:
		room_name = room_name.substr(7)
	return room_name

func _handle_players_update(message):
	var players = message["players"]
	var rooms = message["rooms"]
	var queues = message['queues']
	var player_list = []
	for player in players:
		var id = player["player_id"]
		var version = player["player_version"]
		var player_name = player["player_name"]
		var room_name = player["room_name"]
		var player_deck = player["player_deck"]
		room_name = get_stripped_room_name(room_name)
		player_list.append({
			"player_id": id,
			"player_deck": player_deck,
			"player_version": version,
			"player_name": player_name,
			"room_name": room_name,
		})
	cached_players = player_list

	# Preserve the extra "who is queued" fields the server now sends so the
	# lobby can show the waiting character.
	var queue_list = []
	for queue in queues:
		var queue_info = {
			"id": queue["id"],
			"name": queue["name"],
			"match_available": queue["match_available"],
		}
		if queue.has("waiting_character"):
			queue_info["waiting_character"] = queue["waiting_character"]
		if queue.has("waiting_deck"):
			queue_info["waiting_deck"] = queue["waiting_deck"]
		if queue.has("waiting_deck_id"):
			queue_info["waiting_deck_id"] = queue["waiting_deck_id"]
		queue_list.append(queue_info)
	var newly_available_match = false
	for old_queue in cached_queues:
		var new_queue = null
		for queue in queue_list:
			if old_queue['id'] == queue['id']:
				new_queue = queue
				break
		if new_queue and new_queue['match_available'] and not old_queue['match_available']:
			newly_available_match = true
			break
	cached_queues = queue_list

	# Process rooms
	var match_list = []
	for room in rooms:
		var room_name = room['room_name']
		var room_version = room['room_version']
		room_name = get_stripped_room_name(room_name)
		var player_count = int(room.get('player_count', 0))
		var observer_count = int(room['observer_count'])
		var started = room['game_started']
		var game_over = room.get("game_over", false)
		var joinable = room.get("joinable", not started)
		var player_names = room['player_names']
		# Defense-in-depth against ghost rooms in the lobby view.
		if player_count == 0 and observer_count == 0:
			push_warning("Ignoring empty room from players_update: %s" % room_name)
			continue
		if not started and (player_names.size() == 0 or not player_names[0]):
			push_warning("Ignoring unstarted room without host from players_update: %s" % room_name)
			continue
		if started and player_count < 2 and not joinable and not game_over:
			push_warning("Ignoring started room with fewer than two players from players_update: %s" % room_name)
			continue
		var host = "<EMPTY>"
		var opponent = "<EMPTY>"
		if player_names.size() > 0 and player_names[0]:
			host = player_names[0]
		if player_names.size() > 1 and player_names[1]:
			opponent = player_names[1]
		var decks = room["player_decks"]
		var host_deck_icon_path = ""
		var opponent_deck_icon_path = ""
		if decks.size() > 0 and decks[0]:
			host_deck_icon_path = CardDataManager.get_portrait_asset_path(decks[0])
		if decks.size() > 1 and decks[1]:
			opponent_deck_icon_path = CardDataManager.get_portrait_asset_path(decks[1])
		var match_info = {
			"name": room_name,
			"host": host,
			"host_deck_icon": host_deck_icon_path,
			"opponent": opponent,
			"opponent_deck_icon": opponent_deck_icon_path,
			"version": room_version,
			"observer_count": observer_count,
			"joinable": joinable,
			"observable": started,
			"game_over": game_over
		}
		match_list.append(match_info)
	cached_matches = match_list

	players_update.emit(player_list, match_list, queue_list, newly_available_match)

func _handle_customs_update(message):
	# Read the new customs dict from the message.
	var new_customs = message["customs"]
	# Update all keys in cached_customs.
	for key in new_customs.keys():
		cached_customs[key] = CardDataManager.convert_floats_to_ints(new_customs[key])
	customs_update.emit(cached_customs)

### Commands ###

func join_room(player_name, room_name, deck_id_str : String,
		starting_timer : int, enforce_timer : bool, minimum_time_per_choice : int, custom_deck_definition):
	if not _is_socket_open():
		_emit_not_connected_error("join room")
		return false
	set_restore_context(RestoreContextType.RestoreContextType_Room, {
		"player_name": player_name,
		"lobby_state": "Room",
		"room_id": room_name,
		"deck_id": deck_id_str,
		"starting_timer": starting_timer,
		"enforce_timer": enforce_timer,
		"minimum_time_per_choice": minimum_time_per_choice,
		"custom_deck_definition": custom_deck_definition,
	})
	var join_room_message = {
		"version": GlobalSettings.get_client_version(),
		"value": "join_room",
		"type": "join_room",
		"player_name": player_name,
		"room_id": room_name,
		"deck_id": deck_id_str,
		"starting_timer": starting_timer,
		"enforce_timer": enforce_timer,
		"minimum_time_per_choice": minimum_time_per_choice,
		"custom_deck_definition": custom_deck_definition
	}
	var json = JSON.stringify(join_room_message)
	return _send_socket_text(json, "join room")

func observe_room(player_name, room_name):
	if not _is_socket_open():
		_emit_not_connected_error("observe room")
		return false
	set_restore_context(RestoreContextType.RestoreContextType_Observe, {
		"player_name": player_name,
		"lobby_state": "Observe",
		"room_id": room_name,
	})
	var observe_room_message = {
		"version": GlobalSettings.get_client_version(),
		"type": "observe_room",
		"player_name": player_name,
		"room_id": room_name,
	}
	var json = JSON.stringify(observe_room_message)
	return _send_socket_text(json, "observe room")

func join_matchmaking(player_name, deck_id_str : String, queue_id : String, custom_deck_definition):
	if not _is_socket_open():
		_emit_not_connected_error("join matchmaking")
		return false
	set_restore_context(RestoreContextType.RestoreContextType_Matchmaking, {
		"player_name": player_name,
		"lobby_state": "Matchmaking",
		"deck_id": deck_id_str,
		"queue_id": queue_id,
		"starting_timer": GlobalSettings.MatchmakingStartingTimer,
		"enforce_timer": GlobalSettings.MatchmakingEnforceTimer,
		"minimum_time_per_choice": GlobalSettings.MatchmakingMinimumTimePerChoice,
		"custom_deck_definition": custom_deck_definition,
	})
	var message = {
		"version": GlobalSettings.get_client_version(),
		"value": "join_room",
		"type": "join_matchmaking",
		"queue_id": queue_id,
		"player_name": player_name,
		"deck_id": deck_id_str,
		"starting_timer": GlobalSettings.MatchmakingStartingTimer,
		"enforce_timer": GlobalSettings.MatchmakingEnforceTimer,
		"minimum_time_per_choice": GlobalSettings.MatchmakingMinimumTimePerChoice,
		"custom_deck_definition": custom_deck_definition
	}
	var json = JSON.stringify(message)
	return _send_socket_text(json, "join matchmaking")

func leave_room():
	if not _is_socket_open(): return
	_is_expected_disconnect = false
	var normal_game_over = _active_remote_match_finished
	end_waiting_for_opponent_reconnect()
	set_restore_context(RestoreContextType.RestoreContextType_Lobby, {
		"player_name": _get_preferred_player_name(),
		"lobby_state": "Lobby",
	})
	var leave_room_message = {
		"type": "leave_room",
		"normal_game_over": normal_game_over,
	}
	_active_remote_match_finished = false
	var json = JSON.stringify(leave_room_message)
	_send_socket_text(json, "leave room")

func submit_game_message(message):
	if not _is_socket_open(): return
	# Never send local actions while a reconnect is in flight; they would be
	# rejected or race the restore snapshot.
	if is_reconnect_active() or _waiting_for_restore_name_sync:
		return
	message['type'] = "game_message"
	var json = JSON.stringify(message)
	_send_socket_text(json, "submit game message")

func set_player_name(player_name):
	if not _is_socket_open(): return
	_pending_restore_context["player_name"] = player_name
	var message = {
		"version": GlobalSettings.get_client_version(),
		"type": "set_name",
		"player_name": player_name,
	}
	var json = JSON.stringify(message)
	_send_socket_text(json, "set player name")

func set_lobby_state(lobby_state : String):
	if not _is_socket_open(): return
	if lobby_state == "Lobby":
		set_restore_context(RestoreContextType.RestoreContextType_Lobby, {
			"player_name": _get_preferred_player_name(),
			"lobby_state": lobby_state,
		})
	else:
		_pending_restore_context["lobby_state"] = lobby_state
	var message = {
		"type": "set_lobby_state",
		"lobby_state": lobby_state,
	}
	var json = JSON.stringify(message)
	_send_socket_text(json, "set lobby state")

func get_customs():
	if not _is_socket_open(): return
	var message = {
		"type": "get_customs",
	}
	var json = JSON.stringify(message)
	_send_socket_text(json, "get customs")

# Called by the game when a match ends normally so a subsequent opponent
# disconnect does not pop the "waiting for reconnect" overlay.
func set_active_remote_match_finished(is_finished : bool):
	_active_remote_match_finished = is_finished
	if is_finished:
		end_waiting_for_opponent_reconnect()

func request_players_update():
	if not _is_socket_open():
		return false
	var message = {
		"type": "request_players_update",
	}
	var json = JSON.stringify(message)
	return _send_socket_text(json, "request players update")

### Getters ###

func get_player_list():
	return cached_players

func get_match_list():
	return cached_matches

func get_queue_list():
	return cached_queues

func get_customs_dict():
	return cached_customs

func any_available_match():
	for queue in cached_queues:
		if queue['match_available']:
			return true
	return false
