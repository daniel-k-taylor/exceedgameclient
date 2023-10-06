extends Node

const GameCard = preload("res://scenes/game/game_card.gd")

var all_cards : Array[GameCard] = []

func add_card(card : GameCard) -> void:
	all_cards.append(card)
	
func get_card(id : int):
	for card in all_cards:
		if card.id == id:
			return card
	return null

func _test_insert_card(card : GameCard):
	all_cards.append(card)

func get_card_name(id : int) -> String:
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
