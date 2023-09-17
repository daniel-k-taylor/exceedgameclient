extends Node

var card_data = []

var card_definitions_path = "res://data/card_definitions.json"
var decks_path = "res://data/decks"
var decks = []

func load_json_file(file_path : String):
	if FileAccess.file_exists(file_path):
		var data = FileAccess.open(file_path, FileAccess.READ)
		var json = JSON.parse_string(data.get_as_text())
		return json
	else:
		print("Card definitions file doesn't exist")

# Called when the node enters the scene tree for the first time.
func _ready():
	card_data = load_json_file(card_definitions_path)
	var deck_files = DirAccess.get_files_at(decks_path)
	for deck_file in deck_files:
		var deck_data = load_json_file(decks_path + "/" + deck_file)
		if deck_data:
			decks.append(deck_data)

func get_card(definition_id):
	for card in card_data:
		if card['id'] == definition_id:
			return card
	return null

func get_effect_text(card_def):
	return "Effect text here"
	
func get_boost_text(card_def):
	return "Boost text here"
	
