extends Node

signal settings_loaded

const ReleaseLoggingEnabled = false # If true, log even on release builds.
const UseAzureServerAlways = true # If true, always defaults to the azure server.
var MuteEmotes = false
const ClientVersionString : String = "260830.1700" # YYMMDD.HHMM
const ReplayVersion : int = 1

const CharacterBanlist = ['carmine']
# All times are in seconds
const DefaultStartingTimer : int = 15 * 60
const DefaultEnforceTimer : bool = false
const DefaultMinimumTimePerChoice : int = 20
const DefaultBestOf : int = 1
const DefaultRandomizeFirstVsAi : bool = false
const DefaultAIMode : String = "rules"  # "rules" | "omniscient"
const ValidAIModes := ["rules", "omniscient"]
const DefaultArenaStyle : String = "classic"       # GameBackgroundManager background id
const DefaultMainMenuBackgroundStyle : String = "MP1"  # GameBackgroundManager main-menu id
const MatchmakingStartingTimer : int = 15 * 60
const MatchmakingEnforceTimer : bool = false
const MatchmakingMinimumTimePerChoice : int = 20
const MatchmakingBestOf : int = 1

# Persistent Settings
# Music defaults off on web and in dev builds (editor runs, headless unit test
# runs) so they don't blast the main menu BGM; release builds default on. An
# explicit user toggle is still remembered and honoured.
var BGMEnabled : bool = default_bgm_enabled()
var _bgm_preference_set : bool = false
var DefaultPlayerName = ""
var GameSoundsEnabled = true
var PlayerCharacter = ""
var CombatLogSettings = {}
var CustomStartingTimer : int = DefaultStartingTimer
var CustomBestOf : int = DefaultBestOf
var CustomEnforceTimer : bool = DefaultEnforceTimer
var CustomMinimumTimePerChoice : int = DefaultMinimumTimePerChoice
var RandomizeFirstVsAI : bool = DefaultRandomizeFirstVsAi
var AIMode : String = DefaultAIMode
var ArenaStyle : String = DefaultArenaStyle
var MainMenuBackgroundStyle : String = DefaultMainMenuBackgroundStyle
var ReplayShowOpponentHand : bool = false
var RandomHistory = []
const RandomHistoryMaxSize = 10
var IgnoreRandomHistory = false
var ActionConfirmationEnabled : bool = false
var _web_fullscreen_initialized := false
var _web_fullscreen_window = null
var _web_fullscreen_support_initialized := false
var _web_fullscreen_supported := false

const user_settings_file = "user://settings.json"

# --- Fullscreen (desktop DisplayServer + web JavaScriptBridge) ---------------

func can_request_fullscreen() -> bool:
	if OS.has_feature("web"):
		return _is_web_fullscreen_supported()
	return DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS)

func is_fullscreen() -> bool:
	if OS.has_feature("web"):
		return _is_web_fullscreen()
	var window_mode := DisplayServer.window_get_mode()
	return window_mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or window_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

func request_fullscreen() -> void:
	if OS.has_feature("web"):
		_request_web_fullscreen()
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func exit_fullscreen() -> void:
	if OS.has_feature("web"):
		_exit_web_fullscreen()
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func toggle_fullscreen() -> void:
	if is_fullscreen():
		exit_fullscreen()
	else:
		request_fullscreen()

func _request_web_fullscreen() -> void:
	if not _is_web_fullscreen_supported():
		return
	_ensure_web_fullscreen_window()
	if _web_fullscreen_window == null:
		return
	_web_fullscreen_window.requestGameFullscreen()

func _exit_web_fullscreen() -> void:
	if not _is_web_fullscreen_supported():
		return
	_ensure_web_fullscreen_window()
	if _web_fullscreen_window == null:
		return
	_web_fullscreen_window.exitGameFullscreen()

func _is_web_fullscreen() -> bool:
	if not _is_web_fullscreen_supported():
		return false
	_ensure_web_fullscreen_window()
	if _web_fullscreen_window == null:
		return false
	return _web_fullscreen_window.isGameFullscreen()

func _is_web_fullscreen_supported() -> bool:
	if _web_fullscreen_support_initialized:
		return _web_fullscreen_supported
	_ensure_web_fullscreen_window()
	if _web_fullscreen_window == null:
		_web_fullscreen_support_initialized = true
		_web_fullscreen_supported = false
		return false
	_web_fullscreen_support_initialized = true
	_web_fullscreen_supported = bool(_web_fullscreen_window.isGameFullscreenSupported())
	return _web_fullscreen_supported

func _ensure_web_fullscreen_window() -> void:
	# JavaScriptBridge is a built-in Godot 4 class on Web, not an Engine singleton.
	# Callers already guard with OS.has_feature("web"), so we can use it directly here.
	if not _web_fullscreen_initialized:
		_web_fullscreen_window = JavaScriptBridge.get_interface("window")
		_web_fullscreen_initialized = _web_fullscreen_window != null

func set_web_rotation_render_scale(enabled : bool) -> bool:
	if not OS.has_feature("web"):
		return false
	_ensure_web_fullscreen_window()
	if _web_fullscreen_window == null:
		return false
	if not _web_fullscreen_window.hasOwnProperty("setGameRotationRenderScale"):
		return false
	return bool(_web_fullscreen_window.setGameRotationRenderScale(enabled))

func get_client_version() -> String:
	var prepend = ""
	if OS.is_debug_build():
		prepend = "dev_"
	return prepend + ClientVersionString

func is_logging_enabled() -> bool:
	if ReleaseLoggingEnabled:
		return true
	return OS.is_debug_build()

# Whether BGM should play when the player has never explicitly chosen. Web and
# dev builds (editor runs, headless test runs) stay silent so they don't blast
# the main menu music; release builds keep the music on.
static func default_bgm_enabled() -> bool:
	if OS.has_feature("web"):
		return false
	return not OS.is_debug_build()

# Resolve the BGM preference from a loaded settings dictionary (non-web).
func _apply_loaded_bgm_settings(json) -> void:
	var stored_bgm = json['BGMEnabled'] if 'BGMEnabled' in json and json['BGMEnabled'] is bool else null
	var preference_set = 'BGMPreferenceSet' in json and json['BGMPreferenceSet'] is bool \
			and json['BGMPreferenceSet']

	if preference_set and stored_bgm != null:
		# The player toggled BGM at some point, so honour their choice.
		BGMEnabled = stored_bgm
		_bgm_preference_set = true
	elif stored_bgm == false:
		# Legacy settings file written before BGMPreferenceSet existed. Back then
		# the default was on, so a stored `false` can only have come from the
		# player switching the music off - keep honouring that. A stored `true`
		# is indistinguishable from the old default, so it falls through below.
		BGMEnabled = false
		_bgm_preference_set = true
	else:
		BGMEnabled = default_bgm_enabled()
		_bgm_preference_set = false

func get_server_url() -> String:
	const azure_url = "wss://fightingcardslinux.azurewebsites.net"
	const local_url = "ws://localhost:8080"
	if UseAzureServerAlways or not OS.is_debug_build():
		return azure_url
	else:
		return local_url

func load_persistent_settings() -> bool:  # returns success code
	if not FileAccess.file_exists(user_settings_file):
		print("Unable to load settings file.")
		return false # Error! We don't have a save to load.

	var file = FileAccess.open(user_settings_file, FileAccess.READ)
	var text = file.get_as_text()
	var json = JSON.parse_string(text)
	print("Settings json: %s" % text)
	if OS.has_feature("web"):
		# On web, always default BGM off each session; ignore any stored BGM preference.
		BGMEnabled = false
		_bgm_preference_set = false
	else:
		_apply_loaded_bgm_settings(json)
	if 'DefaultPlayerName' in json and json['DefaultPlayerName'] is String:
		DefaultPlayerName = json['DefaultPlayerName']
	if 'GameSoundsEnabled' in json and json['GameSoundsEnabled'] is bool:
		GameSoundsEnabled = json['GameSoundsEnabled']
	if 'CombatLogSettings' in json and json['CombatLogSettings'] is Dictionary:
		CombatLogSettings = json['CombatLogSettings']
	if 'CustomStartingTimer' in json: #raise concern
		CustomStartingTimer = json['CustomStartingTimer']
	if 'CustomEnforceTimer' in json and json['CustomEnforceTimer'] is bool:
		CustomEnforceTimer = json['CustomEnforceTimer']
	if 'CustomBestOf' in json:
		CustomBestOf = json['CustomBestOf']
	if 'CustomMinimumTimePerChoice' in json:
		CustomMinimumTimePerChoice = json['CustomMinimumTimePerChoice']
	if 'RandomizeFirstVsAI' in json and json['RandomizeFirstVsAI'] is bool:
		RandomizeFirstVsAI = json['RandomizeFirstVsAI']
	if 'AIMode' in json and json['AIMode'] is String and json['AIMode'] in ValidAIModes:
		AIMode = json['AIMode']
	if 'ArenaStyle' in json and json['ArenaStyle'] is String:
		ArenaStyle = json['ArenaStyle']
	if 'MainMenuBackgroundStyle' in json and json['MainMenuBackgroundStyle'] is String:
		MainMenuBackgroundStyle = json['MainMenuBackgroundStyle']
	if 'ReplayShowOpponentHand' in json and json['ReplayShowOpponentHand'] is bool:
		ReplayShowOpponentHand = json['ReplayShowOpponentHand']
	if 'PlayerCharacter' in json and json['PlayerCharacter'] is String and not json['PlayerCharacter'].is_empty():
		PlayerCharacter = json['PlayerCharacter']
	if 'RandomHistory' in json and json['RandomHistory'] is Array:
		RandomHistory = json['RandomHistory']
	if 'IgnoreRandomHistory' in json and json['IgnoreRandomHistory'] is bool:
		IgnoreRandomHistory = json['IgnoreRandomHistory']
	if 'ActionConfirmationEnabled' in json and json['ActionConfirmationEnabled'] is bool:
		ActionConfirmationEnabled = json['ActionConfirmationEnabled']
	else:
		PlayerCharacter = 'solbadguy'
	settings_loaded.emit()
	return true


func save_persistent_settings():
	var settings = {
		"BGMPreferenceSet": _bgm_preference_set,
		"BGMEnabled": BGMEnabled,
		"DefaultPlayerName": DefaultPlayerName,
		"GameSoundsEnabled": GameSoundsEnabled,
		"PlayerCharacter": PlayerCharacter,
		"CombatLogSettings": CombatLogSettings,
		"CustomStartingTimer": CustomStartingTimer,
		"CustomEnforceTimer": CustomEnforceTimer,
		"CustomBestOf": CustomBestOf,
		"CustomMinimumTimePerChoice": CustomMinimumTimePerChoice,
		"RandomizeFirstVsAI": RandomizeFirstVsAI,
		"AIMode": AIMode,
		"ArenaStyle": ArenaStyle,
		"MainMenuBackgroundStyle": MainMenuBackgroundStyle,
		"ReplayShowOpponentHand": ReplayShowOpponentHand,
		"RandomHistory": RandomHistory,
		"IgnoreRandomHistory": IgnoreRandomHistory,
		"ActionConfirmationEnabled": ActionConfirmationEnabled,
	}

	var file = FileAccess.open(user_settings_file, FileAccess.WRITE)
	file.store_line(JSON.stringify(settings))

func set_bgm(value : bool):
	BGMEnabled = value
	_bgm_preference_set = true
	save_persistent_settings()

func set_game_sounds_enabled(value : bool):
	GameSoundsEnabled = value
	save_persistent_settings()

func set_player_name(value : String):
	DefaultPlayerName = value
	save_persistent_settings()

func set_player_character(value: String):
	if not value.begins_with("custom_"):
		PlayerCharacter = value
		save_persistent_settings()

func set_combat_log_setting(setting : String, value):
	CombatLogSettings[setting] = value
	save_persistent_settings()

func set_randomize_first_player_vs_ai(value : bool):
	RandomizeFirstVsAI = value
	save_persistent_settings()

func set_ai_mode(value : String):
	if value not in ValidAIModes:
		value = DefaultAIMode
	AIMode = value
	save_persistent_settings()

func set_arena_style(value : String):
	ArenaStyle = value
	save_persistent_settings()

func set_main_menu_background_style(value : String):
	MainMenuBackgroundStyle = value
	save_persistent_settings()

func set_replay_show_opponent_hand(value : bool):
	ReplayShowOpponentHand = value
	save_persistent_settings()

func set_starting_timers(value : int):
	CustomStartingTimer = value
	save_persistent_settings()

func set_enforce_timers(value : bool):
	CustomEnforceTimer = value
	save_persistent_settings()

func set_minimum_time_per_choice(value : int):
	CustomMinimumTimePerChoice = value
	save_persistent_settings()

func append_random_history(value : String):
	if RandomHistory.size() >= RandomHistoryMaxSize:
		RandomHistory.pop_front()
	RandomHistory.append(value)
	save_persistent_settings()

func set_ignore_random_history(value : bool):
	IgnoreRandomHistory = value
	save_persistent_settings()

func set_action_confirmation_enabled(value : bool):
	ActionConfirmationEnabled = value
	save_persistent_settings()
