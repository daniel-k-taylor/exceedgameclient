extends Node

var card_data = {}

var card_definitions_path = "res://data/card_definitions.json"
var decks_path = "res://data/decks"
var skin_decks_path = "res://data/decks_skin"
var decks = {}  # A dictionary of (JSON) dictionaries

func get_deck_test_deck():
	return decks.get("rachel", get_random_deck(-1))

func get_random_deck(season : int) -> Dictionary:
	# Randomize
	var unbanned_decks = decks.values().filter(func (deck):
			return deck['id'] not in GlobalSettings.CharacterBanlist and _is_random_selectable_deck(deck))
	if season == -1:
		return unbanned_decks.pick_random()
	else:
		var season_decks = unbanned_decks.filter(func (deck):
				return deck['season'] == season)
		return season_decks.pick_random()

func _is_random_selectable_deck(deck: Dictionary) -> bool:
	var deck_id = str(deck.get('id', ""))
	if deck_id.is_empty():
		return false

	var skin_manager = get_node_or_null("/root/CharSkinManager")
	if skin_manager:
		return skin_manager.get_base_character_id(deck_id) == deck_id

	return not deck_id.contains("_") or FileAccess.file_exists("%s/%s.json" % [decks_path, deck_id])

func get_deck(str_id : String) -> Dictionary:
	if str_id == "random_s7":
		return get_random_deck(7)
	if str_id == "random_s6":
		return get_random_deck(6)
	if str_id == "random_s5":
		return get_random_deck(5)
	if str_id == "random_s4":
		return get_random_deck(4)
	if str_id == "random_s3":
		return get_random_deck(3)
	if str_id == "random_s2":
		return get_random_deck(2)
	if str_id == "random_s1":
		return get_random_deck(1)
	if str_id == "random":
		return get_random_deck(-1)
	return decks.get(str_id)

func get_deck_from_str_id(str_id : String, exclude_ids : Array = []) -> Dictionary:
	var deck = get_deck(str_id)
	var max_attempts = 10
	while deck["id"] in exclude_ids and not GlobalSettings.IgnoreRandomHistory:
		deck = get_deck(str_id)
		max_attempts -= 1
		if max_attempts <= 0:
			# If you can't get it after 10 tries, just deal with it.
			break

	return deck

func get_portrait_asset_path(deck_id : String) -> String:
	var skin_manager = get_node_or_null("/root/CharSkinManager")
	if skin_manager:
		return skin_manager.get_portrait_path_for_deck_id(deck_id)
	# Fallback when the skin manager isn't available: only take the part after
	# '#' if there is one, then use the base portrait directory.
	var split_index = deck_id.find("#")
	if split_index != -1:
		deck_id = deck_id.substr(split_index + 1)
	var portrait_path = "res://assets/portraits/" + deck_id + ".png"
	if ResourceLoader.exists(portrait_path, "Texture2D"):
		return portrait_path
	return "res://assets/portraits/custom.png"

func load_json_file(file_path : String):
	if FileAccess.file_exists(file_path):
		var data = FileAccess.open(file_path, FileAccess.READ)
		var json = convert_floats_to_ints(JSON.parse_string(data.get_as_text()))
		return json
	else:
		print("Card definitions file doesn't exist")

func convert_floats_to_ints(data):
	if typeof(data) == TYPE_DICTIONARY:
		for key in data:
			data[key] = convert_floats_to_ints(data[key])
	elif typeof(data) == TYPE_ARRAY:
		for i in range(data.size()):
			data[i] = convert_floats_to_ints(data[i])
	elif typeof(data) == TYPE_FLOAT:
		if data == int(data):
			return int(data)
	return data

# Called when the node enters the scene tree for the first time.
func _ready():
	card_data = {}
	var all_cards = load_json_file(card_definitions_path)
	for card in all_cards:
		_load_card_definition(card, card_definitions_path)
	_load_decks_from_path(decks_path, false)
	_load_decks_from_path(skin_decks_path, true)

func _load_decks_from_path(path: String, use_file_name_as_id: bool) -> void:
	var deck_files = DirAccess.get_files_at(path)
	for deck_file in deck_files:
		if deck_file[0] == "_":
			continue
		var deck_data = load_json_file(path + "/" + deck_file)
		if deck_data:
			if use_file_name_as_id:
				if not _is_valid_skin_deck_file(deck_file, deck_data):
					continue
				deck_data = deck_data.duplicate(true)
				deck_data['base_id'] = str(deck_data.get('id', ""))
				deck_data['id'] = deck_file.get_basename()
			else:
				deck_data['base_id'] = str(deck_data.get('id', ""))
			decks[deck_data['id']] = deck_data

func _is_valid_skin_deck_file(deck_file: String, deck_data: Dictionary, report_error: bool = true) -> bool:
	var base_character_id = str(deck_data.get('id', ""))
	var skin_file_id = deck_file.get_basename()
	var expected_prefix = base_character_id + "_"
	if base_character_id.is_empty() or not skin_file_id.begins_with(expected_prefix):
		_report_skin_deck_error("Skin deck filename '%s' must begin with its JSON id '%s_'." % [deck_file, base_character_id], report_error)
		return false

	var skin_index_text = skin_file_id.trim_prefix(expected_prefix)
	if not skin_index_text.is_valid_int() or int(skin_index_text) < 1 or str(int(skin_index_text)) != skin_index_text:
		_report_skin_deck_error("Skin deck filename '%s' must end with a positive integer skin index." % deck_file, report_error)
		return false

	var original_deck_path = decks_path + "/" + base_character_id + ".json"
	if not FileAccess.file_exists(original_deck_path):
		_report_skin_deck_error("Skin deck '%s' requires original deck file '%s'." % [deck_file, original_deck_path], report_error)
		return false
	var original_deck_data = load_json_file(original_deck_path)
	if not original_deck_data or str(original_deck_data.get('id', "")) != base_character_id:
		_report_skin_deck_error("Skin deck '%s' requires '%s' with matching JSON id '%s'." % [deck_file, original_deck_path, base_character_id], report_error)
		return false

	if not decks.has(base_character_id):
		_report_skin_deck_error("Skin deck '%s' references unloaded original character id '%s'." % [deck_file, base_character_id], report_error)
		return false

	return true

func _report_skin_deck_error(message: String, report_error: bool) -> void:
	if report_error:
		push_error(message)

func get_card(definition_id):
	var card = card_data.get(definition_id)
	if card:
		return card
	assert(false, "Missing card definition: " + definition_id)
	return null

func load_deck_if_custom(deck_definition):
	var custom_cards = deck_definition.get("custom_card_definitions")
	if custom_cards:
		load_custom_cards(custom_cards)

	# Sanitize deck definition fields
	sanitize_bonus_effects_in_data(deck_definition.get("on_exceed"))
	sanitize_bonus_effects_in_data(deck_definition.get("ability_effects"))
	sanitize_bonus_effects_in_data(deck_definition.get("exceed_ability_effects"))
	sanitize_bonus_effects_in_data(deck_definition.get("overdrive_effect"))
	sanitize_bonus_effects_in_data(deck_definition.get("character_action_default"))
	sanitize_bonus_effects_in_data(deck_definition.get("character_action_exceeded"))

func load_custom_cards(custom_cards):
	if custom_cards == null:
		return
	for card in custom_cards:
		# Sanitize card effects and boost fields
		sanitize_bonus_effects_in_data(card.get("effects"))
		sanitize_bonus_effects_in_data(card.get("boost"))
		_load_card_definition(card, "custom_card_definitions")

func _load_card_definition(card, source_name : String):
	if typeof(card) != TYPE_DICTIONARY:
		push_warning("Skipping non-dictionary card definition from %s." % source_name)
		return
	if not card.has('id'):
		push_warning("Skipping card definition without id from %s." % source_name)
		return
	card_data[card['id']] = card

func sanitize_bonus_effects_in_data(data):
	if data == null:
		return

	if typeof(data) == TYPE_DICTIONARY:
		sanitize_bonus_effects_in_dict(data)
	elif typeof(data) == TYPE_ARRAY:
		for item in data:
			sanitize_bonus_effects_in_data(item)

func sanitize_bonus_effects_in_dict(dict_data):
	if dict_data == null:
		return

	# Check if this dictionary has a bonus_effect field
	if dict_data.has("bonus_effect"):
		# Replace bonus_effect with and
		dict_data["and"] = dict_data["bonus_effect"]
		dict_data.erase("bonus_effect")
		# Add the use_semicolon_for_and flag
		dict_data["use_semicolon_for_and"] = true

	# Recursively process all values in the dictionary
	for key in dict_data.keys():
		var value = dict_data[key]
		sanitize_bonus_effects_in_data(value)
