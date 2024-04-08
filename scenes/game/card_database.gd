class_name CardDatabase
extends Node

var all_cards = {}  # int (runtime id) --> GameCard

func teardown():
	for card in all_cards.values():
		card.free()
	all_cards = {}

## Basic operations

func add_card(card : GameCard) -> void:
	all_cards[card.id] = card

func get_card(id : int):
	return all_cards.get(id, null)

func id_exists(id: int):
	return id in all_cards

func list_all_cards():
	return all_cards.values()

## Actual lookup utilities

func get_card_sort_key(card_id : int):
	var gamecard = get_card(card_id)
	var card_type = gamecard.definition['type']
	var speed = gamecard.definition['speed']
	var display_name = gamecard.definition['display_name']
	var sort_key = 0
	if card_type == "normal":
		sort_key = 100
	elif card_type == "special":
		sort_key = 200
	elif card_type == "ultra":
		sort_key = 300

	# Use inverse speed so that higher speed cards are sorted first.
	# Because we want to use the display name as alpha sort.
	sort_key += (99 - speed)

	return "%s_%s" % [sort_key, display_name]

func get_card_names(card_ids) -> String:
	return ", ".join(card_ids.map(get_card_name))

func _test_insert_card(card : GameCard):
	if id_exists(card.id):
		get_card(card.id).free()
	add_card(card)

func get_card_name(id : int) -> String:
	if id_exists(id):
		return get_card(id).definition['display_name']
	return "MISSING CARD"

func get_card_name_by_card_definition_id(id : String) -> String:
	for card in list_all_cards():
		if card.definition['id'] == id:
			return card.definition['display_name']
	return "MISSING CARD"

func get_card_id(id : int) -> String:  # runtime id --> definition id
	if id_exists(id):
		return get_card(id).definition['id']
	return "MISSING CARD"

func are_same_card(id1 : int, id2 : int) -> bool:
	var card1 = get_card(id1)
	var card2 = get_card(id2)
	return card1.definition['id'] == card2.definition['id']

func get_card_force_value(id : int) -> int:
	var card = get_card(id)
	if card.definition['type'] == 'ultra':
		return 2
	elif card.definition['type'] in ['normal', 'special']:
		return 1
	return 0

func is_normal_card(id : int) -> bool:
	if id < 0: return false
	var card = get_card(id)
	return card.definition['type'] == 'normal'

func does_card_have_cost(id : int) -> bool:
	var card = get_card(id)
	return card.definition['force_cost'] > 0 or card.definition['gauge_cost'] > 0

func get_card_boost_force_cost(id : int) -> int:
	var card = get_card(id)
	return card.definition['boost']['force_cost']

func get_card_gauge_cost(id : int) -> int:
	var card = get_card(id)
	return card.definition['gauge_cost']

func get_card_cancel_cost(id : int) -> int:
	var card = get_card(id)
	return card.definition['boost']['cancel_cost']

func get_card_effects_at_timing(card : GameCard, effect_timing : String):
	if card == null:
		return []
	var relevant_effects = []
	for effect in card['definition']['effects']:
		if effect['timing'] == effect_timing:
			relevant_effects.append(effect)
	return relevant_effects

func get_card_boost_effects(card : GameCard):
	return card.definition['boost']['effects']

func get_card_boost_effects_now_immediate(card : GameCard):
	var relevant_effects = []
	for effect in card['definition']['boost']['effects']:
		if effect['timing'] == "now" or effect['timing'] == "immediate":
			relevant_effects.append(effect)
	return relevant_effects
