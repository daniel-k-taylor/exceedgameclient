class_name AIPolicyRandom
extends Node

func pick_turn_action(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_boost_action(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_pay_strike_force_cost(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
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

func pick_discard_opponent_gauge(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_name_opponent_card(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_card_hand_to_gauge(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_mulligan(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_choose_from_boosts(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_choose_from_discard(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_force_for_effect(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_gauge_for_effect(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_choose_to_discard(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_choose_opponent_card_to_discard(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_choose_from_topdeck(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_choose_arena_location_for_effect(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_number_from_range_for_effect(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]
