class_name MainMenu
extends Control

signal start_game(vs_info)
signal start_remote_game(vs_info, data)

const RoomMaxLen = 12
const PlayerNameMaxLen = 12

const MatchQueueItemScene = preload("res://scenes/menu/match_queue_item.tscn")

var _dialog_handler : Callable
var _custom_deck_definition = null

#These only get set and used if run on web
var window
var file_load_callback

@onready var player_list : ItemList = $PlayerList
@onready var player_selected_character : String = "solbadguy"
@onready var opponent_selected_character : String = "kykisuke"
@onready var selecting_player : bool = true

@onready var player_name_box : TextEdit = $PlayerNameBox

@onready var start_ai_button : Button = $AIBox/VSAIBox/StartButton
@onready var room_select : LineEdit = $MenuList/JoinBox/RoomNameBox
@onready var join_room_button = $MenuList/JoinBox/JoinButton
@onready var join_box = $MenuList/JoinBox
@onready var settings_button = $SettingsButton
@onready var settings_window = $PreferencesWindow
@onready var file_dialog = $FileDialog

@onready var char_select = $CharSelect
@onready var change_player_character_button : Button = $PlayerChooser/ChangePlayerCharacterButton
@onready var player_char_label : Label = $PlayerChooser/MarginContainer/VBoxContainer/HBoxContainer/CharName
@onready var player_char_portrait : TextureRect = $PlayerChooser/MarginContainer/VBoxContainer/HBoxContainer/CharPortrait

@onready var opponent_char_label : Label = $AIBox/VSAIBox/OpponentChooser/MarginContainer/VBoxContainer/HBoxContainer/CharName
@onready var opponent_char_portrait : TextureRect = $AIBox/VSAIBox/OpponentChooser/MarginContainer/VBoxContainer/HBoxContainer/CharPortrait

@onready var modal_list : ModalList = $ModalList
@onready var modal_dialog : ModalDialog = $ModalDialog

@onready var player_list_button = $PlayerListContainer/PlayerListHBox/PlayersButton
@onready var match_list_button = $RoomListContainer/RoomListHBox/MatchesButton

@onready var cancel_button = $CancelButton
@onready var match_queues : HBoxContainer = $Queues

@onready var label_font_normal = 32
@onready var label_font_small = 18
@onready var label_length_threshold = 15

# Start as true to not play sounds right when you get to the main menu.
@onready var was_match_available : bool = true
@onready var just_clicked_matchmake : bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	$VersionContainer/MarginContainer/HBoxContainer/ClientVersion.text = GlobalSettings.get_client_version()
	NetworkManager.connect("connected_to_server", _on_connected)
	NetworkManager.connect("disconnected_from_server", _on_disconnected)
	NetworkManager.connect("game_started", _on_remote_game_started)
	NetworkManager.connect("observe_started", _on_observe_game_started)
	NetworkManager.connect("players_update", _on_players_update)
	NetworkManager.connect("room_join_failed", _on_join_failed)
	NetworkManager.connect("name_update", _on_name_update)
	cancel_button.visible = false
	$ReconnectToServerButton.visible = false
	_on_players_update(NetworkManager.get_player_list(), NetworkManager.get_match_list(), NetworkManager.get_queue_list(), NetworkManager.any_available_match())
	selecting_player = false
	just_clicked_matchmake = false
	_on_char_select_select_character(opponent_selected_character)
	modal_dialog.visible = false
	modal_list.visible = false
	file_dialog.visible = false
	update_queues(true)

	# Initialize settings window
	settings_window.visible = false
	settings_window.bgm_check_toggled.connect(_on_bgm_check_toggled)

	if OS.has_feature("web"):
		#setupFileLoad defined in the HTML5 export header
		#calls _dialog_handler when file gets user-selected by window.input.click()
		window = JavaScriptBridge.get_interface("window")
		file_load_callback = JavaScriptBridge.create_callback(_dialog_handler)
		window.setupFileLoad(file_load_callback)

func settings_loaded():
	player_selected_character = GlobalSettings.PlayerCharacter if GlobalSettings.PlayerCharacter else "solbadguy"
	update_char(player_selected_character, true)
	start_music()

func _on_bgm_check_toggled():
	if GlobalSettings.BGMEnabled:
		start_music()
	else:
		stop_music()

func stop_music():
	$BGM.stop()

func start_music():
	if GlobalSettings.BGMEnabled:
		$BGM.play()
	else:
		$BGM.stop()

func returned_from_game():
	_on_players_update(NetworkManager.get_player_list(), NetworkManager.get_match_list(), NetworkManager.get_queue_list(), NetworkManager.any_available_match())
	update_buttons(false)
	just_clicked_matchmake = false
	NetworkManager.set_lobby_state("Lobby")
	start_music()
	if OS.has_feature("web"):
		window.setupFileLoad(file_load_callback)

func _on_start_button_pressed():
	# For local play, random selection is still random at this point.
	var player_random_tag = ""
	if player_selected_character.begins_with("random"):
		player_random_tag = player_selected_character
	var opponent_random_tag = ""
	if opponent_selected_character.begins_with("random"):
		opponent_random_tag = opponent_selected_character

	var player_deck = _get_deck(player_selected_character)
	var opponent_deck = _get_deck(opponent_selected_character)
	var player_name = get_player_name()
	var opponent_name = "CPU"
	NetworkManager.set_lobby_state("AI")
	start_game.emit(get_vs_info(player_name,
		player_deck,
		player_random_tag,
		opponent_name,
		opponent_deck,
		opponent_random_tag,
		GlobalSettings.RandomizeFirstVsAI))

func _on_connected(player_name):
	join_room_button.disabled = false
	player_list_button.disabled = false
	match_list_button.disabled = false
	player_name_box.editable = true
	player_name_box.text = player_name
	$ReconnectToServerButton.visible = false
	$ServerStatusLabel.text = "Connected to server."
	if GlobalSettings.DefaultPlayerName:
		player_name_box.text = GlobalSettings.DefaultPlayerName
		NetworkManager.set_player_name(player_name_box.text)
	else:
		NetworkManager.set_player_name("")

func _on_disconnected():
	update_buttons(false)
	join_room_button.disabled = true
	update_queues(false)
	player_list_button.disabled = true
	match_list_button.disabled = true
	$ReconnectToServerButton.visible = true
	$ReconnectToServerButton.disabled = false
	$ServerStatusLabel.text = "Disconnected from server."
	just_clicked_matchmake = false
	_on_players_update([], [], [], false)

func get_vs_info(player_name, player_deck, player_random_tag, opponent_name,
		opponent_deck, opponent_random_tag, randomize_first_vs_ai = false):
	return {
		'player_name': player_name,
		'player_deck': player_deck,
		'player_random_tag': player_random_tag,
		'opponent_name': opponent_name,
		'opponent_deck': opponent_deck,
		'opponent_random_tag': opponent_random_tag,
		'randomize_first_vs_ai': randomize_first_vs_ai
	}

func get_random_tag(deck_id):
	if deck_id.begins_with("random"):
		return deck_id.split("#")[0]
	return ""

func get_deck_id_without_random_tag(deck_id):
	if deck_id.begins_with("random"):
		return deck_id.split("#")[1]
	return deck_id

func _on_observe_game_started(data, is_replay = false):
	just_clicked_matchmake = false

	# Observe games pass in the full message log up to this point.
	# The first message is the game_start message.
	var message_log = data.get('messages')
	if not message_log:
		var json = JSON.new()
		var error = json.parse(data.get('MatchLog'))
		if error == OK:
			message_log = json.data
		else:
			assert(false, "Unexpected data")
			return
	var start_data = message_log[0]

	# The observer will view from player 1's perspective.
	var player_deck = start_data['player1_deck_id']
	var player_name = start_data['player1_name']
	var opponent_deck = start_data['player2_deck_id']
	var opponent_name = start_data['player2_name']
	# For remote play, random was decided locally first
	# and the deck id is random#deck_id.
	var player_random_tag = get_random_tag(player_deck)
	var player_deck_no_random = get_deck_id_without_random_tag(player_deck)
	var opponent_random_tag = get_random_tag(opponent_deck)
	var opponent_deck_no_random = get_deck_id_without_random_tag(opponent_deck)

	start_data['player1_deck_id'] = player_deck_no_random
	start_data['player2_deck_id'] = opponent_deck_no_random

	start_data['observer_mode'] = true
	start_data['replay_mode'] = is_replay
	start_data['observer_log'] = message_log.slice(1)

	var player_deck_object = _get_deck_object(player_deck, start_data.get('player1_custom_deck'))
	var opponent_deck_object = _get_deck_object(opponent_deck, start_data.get('player2_custom_deck'))
	start_remote_game.emit(get_vs_info(player_name, player_deck_object,
		player_random_tag, opponent_name, opponent_deck_object, opponent_random_tag), start_data)

func _get_deck_object(deck, custom_deck):
	var deck_no_random = get_deck_id_without_random_tag(deck)
	if deck_no_random.begins_with("custom_"):
		return custom_deck
	else:
		return CardDefinitions.get_deck_from_str_id(deck_no_random)

# Handles a signal from _handle_game_start in network manager
func _on_remote_game_started(data):
	just_clicked_matchmake = false
	$MatchStartingAudio.play()
	var player1_is_me = true
	var player_deck = data['player1_deck_id']
	var player_name = data['player1_name']
	var player_custom_deck = data.get('player1_custom_deck')
	var opponent_deck = data['player2_deck_id']
	var opponent_name = data['player2_name']
	var opponent_custom_deck = data.get('player2_custom_deck')
	if data['your_player_id'] != data['player1_id']:
		player1_is_me = false
		player_deck = data['player2_deck_id']
		player_name = data['player2_name']
		player_custom_deck = data.get('player2_custom_deck')
		opponent_deck = data['player1_deck_id']
		opponent_name = data['player1_name']
		opponent_custom_deck = data.get('player1_custom_deck')

	# For remote play, random was decided locally first
	# and the deck id is random#deck_id.
	var player_random_tag = get_random_tag(player_deck)
	var player_deck_no_random = get_deck_id_without_random_tag(player_deck)
	var opponent_random_tag = get_random_tag(opponent_deck)
	var opponent_deck_no_random = get_deck_id_without_random_tag(opponent_deck)

	if player1_is_me:
		data['player1_deck_id'] = player_deck_no_random
		data['player2_deck_id'] = opponent_deck_no_random
	else:
		data['player1_deck_id'] = opponent_deck_no_random
		data['player2_deck_id'] = player_deck_no_random

	var player_deck_object = _get_deck_object(player_deck_no_random, player_custom_deck)
	var opponent_deck_object = _get_deck_object(opponent_deck_no_random, opponent_custom_deck)
	start_remote_game.emit(get_vs_info(player_name, player_deck_object,
		player_random_tag, opponent_name, opponent_deck_object, opponent_random_tag), data)

func _on_name_update(new_name):
	player_name_box.text = new_name
	GlobalSettings.set_player_name(new_name)

func _on_players_update(players, matches, queues : Array, newly_available_match : bool):
	player_list.clear()
	for player in players:
		player_list.add_item(player['player_name'] + " - " + player['room_name'])

	var player_count = players.size()
	var match_count = matches.size()
	$PlayerListContainer/PlayerListHBox/PlayerCount.text = str(player_count)
	$RoomListContainer/RoomListHBox/MatchCount.text = str(match_count)

	var queue_items = match_queues.get_children()
	if queue_items.size() != queues.size():
		while match_queues.get_child_count() > 0:
			match_queues.remove_child(match_queues.get_child(0))
		for queue_info in queues:
			var new_queue = MatchQueueItemScene.instantiate()
			match_queues.add_child(new_queue)
			new_queue.initialize_queue(queue_info["id"], queue_info["name"], queue_info["match_available"])
			new_queue.on_join_queue.connect(_on_queue_join_clicked)

	for i in range(queues.size()):
		var queue_info = queues[i]
		var queue : MatchQueueItem = match_queues.get_child(i)
		queue.set_match_available(queue_info["match_available"])

	if visible and newly_available_match and not just_clicked_matchmake:
		$MatchAvailableAudio.play()

func _on_join_failed(error_message : String, invalid_deck : bool):
	if invalid_deck and _check_banned():
		return

	modal_dialog.set_text_fields(error_message, "OK", "")
	update_buttons(false)

func get_player_name() -> String:
	return player_name_box.text

func _on_join_button_pressed():
	var player_name = get_player_name()
	var room_name = room_select.text
	var chosen_deck = _get_deck(player_selected_character)
	var chosen_deck_id = chosen_deck['id']
	if player_selected_character.begins_with("random"):
		chosen_deck_id = player_selected_character + "#" + chosen_deck_id
	NetworkManager.join_room(player_name,
		room_name,
		chosen_deck_id,
		GlobalSettings.CustomStartingTimer,
		GlobalSettings.CustomEnforceTimer,
		GlobalSettings.CustomMinimumTimePerChoice,
		_custom_deck_definition
	)
	update_buttons(true)

func update_buttons(joining : bool):
	start_ai_button.disabled = joining
	change_player_character_button.disabled = joining
	room_select.editable = not joining
	join_box.visible = not joining
	cancel_button.visible = joining
	player_list_button.disabled = joining
	match_list_button.disabled = joining
	update_queues(not joining)

func update_queues(enabled : bool):
	for child in match_queues.get_children():
		var queue_item : MatchQueueItem = child
		queue_item.set_enabled(enabled)

func _on_queue_join_clicked(queue_id):
	just_clicked_matchmake = true
	var player_name = get_player_name()

	var chosen_deck = _get_deck(player_selected_character)
	var chosen_deck_id = chosen_deck['id']
	if player_selected_character.begins_with("random"):
		chosen_deck_id = player_selected_character + "#" + chosen_deck_id
	NetworkManager.join_matchmaking(
		player_name,
		chosen_deck_id,
		queue_id,
		_custom_deck_definition
	)
	update_buttons(true)

func _on_cancel_button_pressed():
	NetworkManager.leave_room()
	update_buttons(false)
	just_clicked_matchmake = false

func _on_update_name_button_pressed():
	var player_name = get_player_name()
	NetworkManager.set_player_name(player_name)
	GlobalSettings.set_player_name(player_name)

func _on_reconnect_to_server_button_pressed():
	$ServerStatusLabel.text = "Reconnecting to server..."
	NetworkManager.connect_to_server()
	$ReconnectToServerButton.disabled = true

func _on_char_select_close_character_select():
	char_select.visible = false

func update_char(char_id: String, is_player: bool) -> void:
	var label = player_char_label if is_player else opponent_char_label
	var portrait = player_char_portrait if is_player else opponent_char_portrait
	var display_name = "Random"
	if is_player:
		player_selected_character = char_id
		GlobalSettings.set_player_character(char_id)
	else:
		opponent_selected_character = char_id
	var portrait_id: String
	if char_id == "random_s7":
		portrait_id = "random"
	elif char_id == "random_s6":
		portrait_id = "unilogo"
	elif char_id == "random_s5":
		portrait_id = "blazbluelogo2"
	elif char_id == "random_s4":
		portrait_id = "sklogo"
	elif char_id == "random_s3":
		portrait_id = "sflogo"
	elif char_id == "random_s2":
		portrait_id = "sclogo"
	elif char_id == "random_s1":
		portrait_id = "redhorizon"
	elif char_id == "random":
		portrait_id = "exceedrandom"
	else:
		var deck
		if char_id.begins_with("custom_"):
			deck = _custom_deck_definition
		else:
			deck = CardDefinitions.get_deck_from_str_id(char_id)
		display_name = deck['display_name']
		portrait_id = char_id
	label.text = display_name
	if char_id.begins_with("custom_"):
		portrait.texture = load("res://assets/portraits/exceedrandom.png")
	else:
		portrait.texture = load("res://assets/portraits/" + portrait_id + ".png")
		
	if len(display_name) <= label_length_threshold:
		label.set("theme_override_font_sizes/font_size", label_font_normal)
	else:
		label.set("theme_override_font_sizes/font_size", label_font_small)

func _on_char_select_select_character(char_id):
	if char_id == "custom":
		# Show UI to select a file from disk.
		if not selecting_player:
			modal_dialog.set_text_fields("AI Custom Not Supported Yet", "OK", "")
			update_buttons(false)
		else:
			_show_file_dialog(load_custom)
	else:
		update_char(char_id, selecting_player)
	_on_char_select_close_character_select()

func _on_change_player_character_button_pressed(is_player : bool):
	var char_id = player_selected_character
	if not is_player:
		char_id = opponent_selected_character
	char_select.show_char_select(char_id)
	char_select.visible = true
	selecting_player = is_player

func cropLineToMaxLength_room_line_edit(new_text : String, max_length: int) -> void:
	if new_text.length() > max_length:
		var col = room_select.caret_column
		if col != 0:
			new_text = new_text.substr(0, col-1) + new_text.substr(col)
		else:
			new_text = new_text.substr(1)
		new_text = new_text.substr(0, max_length)
		room_select.text = new_text
		room_select.caret_column = col - 1

func cropLineToMaxLength_name_text_edit(new_text : String, max_length: int) -> void:
	if new_text.length() > max_length:
		var col = player_name_box.get_caret_column()
		if col != 0:
			new_text = new_text.substr(0, col-1) + new_text.substr(col)
		else:
			new_text = new_text.substr(1)
		new_text = new_text.substr(0, max_length)
		player_name_box.text = new_text
		player_name_box.set_caret_column(col - 1)

func _on_room_name_box_text_changed(new_text):
	cropLineToMaxLength_room_line_edit(new_text, RoomMaxLen)

func _on_player_name_box_focus_entered():
	player_name_box.select_all()

func _on_player_name_box_text_changed():
	cropLineToMaxLength_name_text_edit(player_name_box.text, PlayerNameMaxLen)

func _on_players_button_pressed():
	modal_list.show_player_list()

func _on_matches_button_pressed():
	modal_list.show_match_list()

func _check_banned():
	var chosen_deck = _get_deck(player_selected_character)
	var chosen_deck_id = chosen_deck['id']
	if chosen_deck_id in GlobalSettings.CharacterBanlist:
		if not $SpecialSelectAudio.playing:
			$SpecialSelectAudio.play()
		modal_dialog.set_text_fields(
			"\"Weaklings should stay away...\"\n(This character is banned\nfrom standard matchmaking.)",
			"OK", "")
		update_buttons(false)

		return true
	return false

func _on_modal_list_join_match_pressed(row_index):
	var matches = NetworkManager.get_match_list()
	var selected_match = matches[row_index]
	room_select.text = selected_match['name']

	var chosen_deck = CardDefinitions.get_deck_from_str_id(player_selected_character)
	var chosen_deck_id = chosen_deck['id']
	if player_selected_character.begins_with("random"):
		chosen_deck_id = player_selected_character + "#" + chosen_deck_id

	_on_join_button_pressed()

func _on_modal_list_observe_match_pressed(row_index):
	var matches = NetworkManager.get_match_list()
	var selected_match = matches[row_index]
	var room_name = selected_match['name']
	var player_name = get_player_name()
	NetworkManager.observe_room(player_name, room_name)
	update_buttons(true)

func _on_load_replay_button_pressed():
	_show_file_dialog(load_replay)

func _show_file_dialog(dialog_hander : Callable):
	_dialog_handler = dialog_hander
	if OS.has_feature("web"):
		window.input.click()
	else:
		file_dialog.visible = true

func _on_settings_button_pressed():
	settings_window.visible = true

func load_replay(data):
	var json = JSON.new()
	if json.parse(data[0]) == OK:
		var replay_data = json.data
		var replay_version = 1
		if 'replay_version' in replay_data:
			replay_version = replay_data['replay_version']

		if replay_version == GlobalSettings.ReplayVersion:
			_on_observe_game_started(replay_data, true)
		else:
			var error_message = "Client replay version does not match replay version"
			modal_dialog.set_text_fields(error_message, "OK", "")
			update_buttons(false)
	else:
		var error_message = "JSON Parse Error: " + json.get_error_message()
		modal_dialog.set_text_fields(error_message, "OK", "")
		update_buttons(false)

func _on_file_dialog_file_selected(path):
	_dialog_handler.call([FileAccess.get_file_as_string(path)])

func load_custom(data):
	var json = JSON.new()
	if json.parse(data[0]) == OK:
		_custom_deck_definition = json.data
		var deck_id = "custom_" + _custom_deck_definition["id"]
		_custom_deck_definition["id"] = deck_id
		update_char(deck_id, true)
	else:
		var error_message = "JSON Parse Error: " + json.get_error_message()
		modal_dialog.set_text_fields(error_message, "OK", "")
		update_buttons(false)

func _get_deck(char_id):
	if char_id.begins_with("custom_"):
		return _custom_deck_definition
	else:
		return CardDefinitions.get_deck_from_str_id(char_id)
