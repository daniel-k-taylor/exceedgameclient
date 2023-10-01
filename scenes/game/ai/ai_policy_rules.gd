extends Node

const GameLogic = preload("res://scenes/game/gamelogic.gd")
const AIPlayer = preload("res://scenes/game/ai_player.gd")

func _factorial(n: int) -> int:
	var result = 1
	for i in range(2, n + 1):
		result *= i
	return result

func _combinations(n: int, r: int) -> int:
	@warning_ignore("integer_division")
	return _factorial(n) / (_factorial(r) * _factorial(n - r))

func _probability_of_drawing(cards_to_find: Array, num_draws: int, deck: Array) -> float:
	var total_cards = deck.size()
	var total_success_cards = 0
	for card in deck:
		if card in cards_to_find:
			total_success_cards += 1

	var success_probability : float = 0.0
	for i in range(1, num_draws + 1):
		var success_cases : float = _combinations(total_success_cards, i) * _combinations(total_cards - total_success_cards, num_draws - i)
		var total_cases : float = _combinations(total_cards, num_draws)
		success_probability += success_cases / total_cases

	return success_probability


func get_hand_card_probabilities():
	pass

func evaluate_card_matchup(_card1, _card2):
	pass

func pick_turn_action(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_pay_strike_gauge_cost(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_effect_choice(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_force_for_armor(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_strike(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_strike_response(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_discard_to_max(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_cancel(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_discard_continuous(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_name_opponent_card(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_card_hand_to_gauge(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_mulligan(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]
