extends Node

const AIPlayer = preload("res://scenes/game/ai_player.gd")
const GameCard = preload("res://scenes/game/game_card.gd")
const Enums = preload("res://scenes/game/enums.gd")

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

func calculate_damage_for_strike(_check_player : Enums.PlayerId, _ai_game_state : AIPlayer.AIGameState) -> int:
	return 4

func get_locations_after_effect(effect, my_location, opponent_location):
	var direction = -1
	if my_location < opponent_location:
		direction = 1

	match effect['effect_type']:
		'advance':
			for i in range(effect['amount']):
				my_location += direction
				if my_location == opponent_location:
					my_location += direction
			my_location = clamp(my_location, 1, 9)
			if my_location == opponent_location:
				my_location -= direction
		'close':
			for i in range(effect['amount']):
				my_location += direction
				if my_location == opponent_location:
					break
		'pull':
			for i in range(effect['amount']):
				opponent_location -= direction
				if my_location == opponent_location:
					opponent_location -= direction
			opponent_location = clamp(my_location, 1, 9)
			if my_location == opponent_location:
				opponent_location += direction
		'push':
			for i in range(effect['amount']):
				opponent_location += direction
			opponent_location = clamp(my_location, 1, 9)
		'retreat':
			for i in range(effect['amount']):
				my_location -= direction
			my_location = clamp(my_location, 1, 9)

	if 'and' in effect:
		var and_result = get_locations_after_effect(effect['and'], my_location, opponent_location)
		my_location = and_result['my_location']
		opponent_location = and_result['opponent_location']

	var result = {
		"my_location": my_location,
		"opponent_location": opponent_location,
	}
	return result

func can_card_hit(card_id : int, ex_card_id : int, ai_game_state : AIPlayer.AIGameState):
	if card_id == -1:
		return false

	var card : GameCard = ai_game_state.card_db.get_card(card_id)
	var ex_card = null
	if ex_card_id != -1:
		ex_card = ai_game_state.card_db.get_card(ex_card_id)
	if card.definition['id'] == "gg_normal_block":
		if ex_card and ex_card.definition['id'] == "gg_normal_block":
			# No EX Block!
			return false
		return true

	var gauge_cost = card.definition['gauge_cost']
	if gauge_cost > ai_game_state.my_state.gauge.size():
		return false

	var my_location = ai_game_state.my_state.arena_location
	var opponent_location = ai_game_state.opponent_state.arena_location
	for effect in card.definition['effects']:
		if effect['timing'] == "before":
			var result = get_locations_after_effect(effect, my_location, opponent_location)
			my_location = result['my_location']
			opponent_location = result['opponent_location']

	var distance_after_effects = abs(my_location - opponent_location)
	if card.definition['range_min'] <= distance_after_effects and distance_after_effects <= card.definition['range_max']:
		return true
	else:
		return false

func pick_turn_action(possible_actions : Array, ai_game_state : AIPlayer.AIGameState):

	# Pretty much don't reshuffle ever?

	var has_more_cards = ai_game_state.my_state.hand.size() > ai_game_state.opponent_state.hand.size()
	if has_more_cards or ai_game_state.my_state.hand.size() >= 6:
		# Exceed if possible.
		for action in possible_actions:
			if action is AIPlayer.ExceedAction:
				return action

		# Otherwise, see how many strikes are valid at this location.
		# If none, move to a better spot.
		var valid_strike_count = 0
		for card_id in ai_game_state.my_state.hand:
			if can_card_hit(card_id, -1, ai_game_state):
				valid_strike_count += 1
		if valid_strike_count == 0:
			# Need to move to a better spot.
			var current_distance = abs(ai_game_state.my_state.arena_location - ai_game_state.opponent_state.arena_location)
			for action in possible_actions:
				if action is AIPlayer.MoveAction:
					var new_distance = abs(action.location - ai_game_state.opponent_state.arena_location)
					if new_distance < current_distance:
						if abs(new_distance - current_distance) == 1 and abs(ai_game_state.my_state.arena_location - action.location) <= 2:
							return action

		# Boost
		# Don't boost if you already have 3. That's enough.
		if ai_game_state.my_state.continuous_boosts.size() < 3:
			for action in possible_actions:
				var continuous_choices = []
				if action is AIPlayer.BoostAction:
					var card : GameCard = ai_game_state.card_db.get_card(action.card_id)
					if card.definition['boost']['boost_type'] == "continuous":
						continuous_choices.append(action)
				if continuous_choices.size() > 0:
					return continuous_choices[randi() % continuous_choices.size()]

		# Strike
		var strike_choices = []
		for action in possible_actions:
			if action is AIPlayer.StrikeAction:
				if can_card_hit(action.card_id, action.ex_card_id, ai_game_state):
					strike_choices.append(action)
		if strike_choices.size() > 0:
			return strike_choices[randi() % strike_choices.size()]
	else:
		if ai_game_state.my_state.hand.size() < 3:
			var highest_change_cards_value = 0
			var highest_change_cards_action = null
			var prepare_action = null
			for action in possible_actions:
				if action is AIPlayer.ChangeCardsAction:
					var force_value = 0
					for card_id in action.card_ids:
						force_value += ai_game_state.card_db.get_card_force_value(card_id)
					if force_value > highest_change_cards_value:
						highest_change_cards_value = force_value
						highest_change_cards_action = action
				elif action is AIPlayer.PrepareAction:
					prepare_action = action
			if highest_change_cards_value > 3:
				return highest_change_cards_action
			elif prepare_action:
				return prepare_action
		else:
			for action in possible_actions:
				if action is AIPlayer.PrepareAction:
					return action

	# Didn't find anything good just go random.
	return possible_actions[randi() % len(possible_actions)]

func pick_pay_strike_gauge_cost(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_effect_choice(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_force_for_armor(possible_actions : Array, ai_game_state : AIPlayer.AIGameState):
	var armor = 2
	var expected_damage = calculate_damage_for_strike(ai_game_state.my_state.player_id, ai_game_state)
	for action in possible_actions:
		if action is AIPlayer.ForceForArmorAction:
			var force_generated = 0
			for card_id in action.card_ids:
				force_generated += ai_game_state.card_db.get_card_force_value(card_id)
			var armor_generated = armor + force_generated * 2
			if armor_generated == expected_damage or armor_generated == expected_damage + 1:
				return action

	return possible_actions[randi() % len(possible_actions)]

func pick_strike(possible_actions : Array, ai_game_state : AIPlayer.AIGameState):
	var strike_choices = []
	for action in possible_actions:
		if action is AIPlayer.StrikeAction:
			if can_card_hit(action.card_id, action.ex_card_id, ai_game_state):
				strike_choices.append(action)
	if strike_choices.size() > 0:
		return strike_choices[randi() % strike_choices.size()]

	return possible_actions[randi() % len(possible_actions)]

func pick_strike_response(possible_actions : Array, ai_game_state : AIPlayer.AIGameState):
	var strike_choices = []
	var wild_action
	for action in possible_actions:
		if action is AIPlayer.StrikeAction:
			if action.wild_swing:
				wild_action = action
				continue
			if can_card_hit(action.card_id, action.ex_card_id, ai_game_state):
				strike_choices.append(action)
	if strike_choices.size() > 0:
		return strike_choices[randi() % strike_choices.size()]

	return wild_action
	#return possible_actions[randi() % len(possible_actions)]

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

func pick_choose_from_discard(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_force_for_effect(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_choose_to_discard(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]
