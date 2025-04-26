extends Node

signal settings_loaded

const ReleaseLoggingEnabled = false # If true, log even on release builds.
const UseAzureServerAlways = true # If true, always defaults to the azure server.
var MuteEmotes = false
const ClientVersionString : String = "250426.1210" # YYMMDD.HHMM
const ReplayVersion : int = 1

const CharacterBanlist = ['carmine']
# All times are in seconds
const DefaultStartingTimer : int = 15 * 60
const DefaultEnforceTimer : bool = false
const DefaultMinimumTimePerChoice : int = 20
const DefaultBestOf : int = 1
const DefaultRandomizeFirstVsAi : bool = false
const MatchmakingStartingTimer : int = 15 * 60
const MatchmakingEnforceTimer : bool = false
const MatchmakingMinimumTimePerChoice : int = 20
const MatchmakingBestOf : int = 1

# Persistent Settings
var BGMEnabled = true
var DefaultPlayerName = ""
var GameSoundsEnabled = true
var PlayerCharacter = ""
var CombatLogSettings = {}
var CustomStartingTimer : int = DefaultStartingTimer
var CustomBestOf : int = DefaultBestOf
var CustomEnforceTimer : bool = DefaultEnforceTimer
var CustomMinimumTimePerChoice : int = DefaultMinimumTimePerChoice
var RandomizeFirstVsAI : bool = DefaultRandomizeFirstVsAi
var ReplayShowOpponentHand : bool = false

const user_settings_file = "user://settings.json"

func get_client_version() -> String:
	var prepend = ""
	if OS.is_debug_build():
		prepend = "dev_"
	return prepend + ClientVersionString

func is_logging_enabled() -> bool:
	if ReleaseLoggingEnabled:
		return true
	return OS.is_debug_build()

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
	if 'BGMEnabled' in json and json['BGMEnabled'] is bool:
		BGMEnabled = json['BGMEnabled']
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
	if 'ReplayShowOpponentHand' in json and json['ReplayShowOpponentHand'] is bool:
		ReplayShowOpponentHand = json['ReplayShowOpponentHand']
	if 'PlayerCharacter' in json and json['PlayerCharacter'] is String and not json['PlayerCharacter'].is_empty():
		PlayerCharacter = json['PlayerCharacter']
	else:
		PlayerCharacter = 'solbadguy'
	settings_loaded.emit()
	return true


func save_persistent_settings():
	var settings = {
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
		"ReplayShowOpponentHand": ReplayShowOpponentHand,
	}

	var file = FileAccess.open(user_settings_file, FileAccess.WRITE)
	file.store_line(JSON.stringify(settings))

func set_bgm(value : bool):
	BGMEnabled = value
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
