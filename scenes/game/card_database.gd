extends Node

const GameCard = preload("res://scenes/game/game_card.gd")

var all_cards : Array[GameCard] = []

func teardown():
	for card in all_cards:
		card.free()
	all_cards = []

func add_card(card : GameCard) -> void:
	all_cards.append(card)

func get_card(id : int):
	if id == -1:
		return "(NO CARD)"
	for card in all_cards:
		if card.id == id:
			return card
	return null

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
	var card_names = ""
	for id in card_ids:
		card_names += get_card_name(id) + ", "
	if card_names:
		card_names = card_names.substr(0, card_names.length() - 2)
	return card_names

func _test_insert_card(card : GameCard):
	for check_card in all_cards:
		if card.id == check_card.id:
			all_cards.erase(check_card)
			check_card.free()
			break
	all_cards.append(card)

func get_card_name(id : int) -> String:
	for card in all_cards:
		if card.id == id:
			return card.definition['display_name']
	return "MISSING CARD"

func get_card_id(id : int) -> String:
	for card in all_cards:
		if card.id == id:
			return card.definition['id']
	return "MISSING CARD"

func are_same_card(id1 : int, id2 : int) -> bool:
	var card1 = get_card(id1)
	var card2 = get_card(id2)
	return card1.definition['id'] == card2.definition['id']

func get_card_force_value(id : int) -> int:
	var card = get_card(id)
	if card.definition['type'] == 'ultra':
		return 2
	return 1

func is_normal_card(id : int) -> bool:
	if id < 0: return false
	var card = get_card(id)
	return card.definition['type'] == 'normal'

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
