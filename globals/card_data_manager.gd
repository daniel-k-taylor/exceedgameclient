extends Node

var card_data = {}

var card_definitions_path = "res://data/card_definitions.json"
var decks_path = "res://data/decks"
var decks = {}  # A dictionary of (JSON) dictionaries

func get_deck_test_deck():
	return decks.get("rachel", get_random_deck(-1))

func get_random_deck(season : int) -> Dictionary:
	# Randomize
	var unbanned_decks = decks.values().filter(func (deck):
			return deck['id'] not in GlobalSettings.CharacterBanlist)
	if season == -1:
		return unbanned_decks.pick_random()
	else:
		var season_decks = unbanned_decks.filter(func (deck):
				return deck['season'] == season)
		return season_decks.pick_random()

func get_deck_from_str_id(str_id : String) -> Dictionary:
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

func get_portrait_asset_path(deck_id : String) -> String:
	# Only take part after # if there is one.
	var split_index = deck_id.find("#")
	if split_index != -1:
		deck_id = deck_id.substr(split_index + 1)
	return "res://assets/portraits/" + deck_id + ".png"

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
		card_data[card['id']] = card
	var deck_files = DirAccess.get_files_at(decks_path)
	for deck_file in deck_files:
		if deck_file[0] == "_":
			continue
		var deck_data = load_json_file(decks_path + "/" + deck_file)
		if deck_data:
			decks[deck_data['id']] = deck_data

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

func load_custom_cards(custom_cards):
	if custom_cards == null:
		return
	for card in custom_cards:
		card_data[card['id']] = card
