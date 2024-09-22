class_name AIPolicyRules
extends Node

const AIPlayer = preload("res://scenes/game/ai_player.gd")
const GameCard = preload("res://scenes/game/game_card.gd")
const Enums = preload("res://scenes/game/enums.gd")


var __factorial_cache = {
	"cache_max": 7,
	0: 1, 1: 1, 2: 2, 3: 6, 4: 24,
	5: 120, 6: 720, 7: 5040,
	}

func _factorial(n: int) -> int:
	if n not in __factorial_cache:
		for i in range(__factorial_cache["cache_max"] + 1, n + 1):
			__factorial_cache[i] = __factorial_cache[i-1] * i
	return __factorial_cache[n]


var __combinations_cache = {
	[0, 0]: 1, [1, 0]: 1, [1, 1]: 1,
	[2, 0]: 1, [2, 1]: 2, [2, 2]: 1,
	}

func _combinations(n: int, r: int) -> int:
	if n < r:
		return 0
	if [n, r] not in __combinations_cache:
		if r == 0 or r == n:
			__combinations_cache[[n, r]] = 1
		else:
			__combinations_cache[[n, r]] = _combinations(n-1, r) + _combinations(n-1, r-1)
	return __combinations_cache[[n, r]]


## Return the probability of hitting at least one of the IDs in `cards_to_find` when
## choosing `num_draws` elements at random from `deck`, without replacement.
func _probability_of_drawing(cards_to_find: Array, num_draws: int, deck: Array) -> float:
	var total_cards = deck.size()
	var total_success_cards = 0
	for card in deck:
		if card in cards_to_find:
			total_success_cards += 1
	if total_success_cards == 0:
		return 0.0

	if num_draws == 1:
		return total_success_cards * 1.0 / total_cards

	if num_draws > total_cards:
		num_draws = total_cards

	# For higher draw counts, it's easier to compute the odds of *not* hitting and then
	# subtract from 1.
	var total_cases = _combinations(total_cards, num_draws)
	var total_miss_cases = _combinations(total_cards - total_success_cards, num_draws)
	var miss_probability = 1.0 * total_miss_cases / total_cases
	return 1.0 - miss_probability


func get_hand_card_probabilities():
	pass

func evaluate_card_matchup(_card1, _card2):
	pass

func calculate_damage_for_strike(_check_player : Enums.PlayerId, _ai_game_state : AIPlayer.AIGameState) -> int:
	return 4

func get_locations_after_effect(effect, my_location, opponent_location, buddy_location):
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
		'place_buddy_onto_self':
			buddy_location = my_location

	if 'and' in effect:
		var and_result = get_locations_after_effect(effect['and'], my_location, opponent_location, buddy_location)
		my_location = and_result['my_location']
		opponent_location = and_result['opponent_location']

	var result = {
		"my_location": my_location,
		"opponent_location": opponent_location,
		"buddy_location": buddy_location
	}
	return result

func can_card_hit(card_id : int, ex_card_id : int, ai_game_state : AIPlayer.AIGameState):
	if card_id == -1:
		return false

	var card : GameCard = ai_game_state.card_db.get_card(card_id)
	var ex_card = null
	if ex_card_id != -1:
		ex_card = ai_game_state.card_db.get_card(ex_card_id)
	var blocks = ["gg_normal_block", "uni_normal_block", "standard_normal_block"]
	if card.definition['id'] in blocks:
		if ex_card and ex_card.definition['id'] in blocks:
			# No EX Block!
			return false
		return true

	var gauge_cost = card.definition['gauge_cost']
	if gauge_cost > ai_game_state.my_state.gauge.size():
		return false

	var my_location = ai_game_state.my_state.arena_location
	var opponent_location = ai_game_state.opponent_state.arena_location
	var buddy_location = -1
	if ai_game_state.my_state.buddy_locations.size() > 0:
		buddy_location = ai_game_state.my_state.buddy_locations[0]
	var from_buddy = false
	for effect in card.definition['effects']:
		if effect['timing'] == "before":
			var result = get_locations_after_effect(effect, my_location, opponent_location, buddy_location)
			my_location = result['my_location']
			opponent_location = result['opponent_location']
			buddy_location = result['buddy_location']
		if effect['effect_type'] == "calculate_range_from_buddy":
			from_buddy = true

	var distance_after_effects = abs(my_location - opponent_location)
	if from_buddy:
		distance_after_effects = abs(buddy_location - opponent_location)
	var range_min = card.definition['range_min']
	if range_min is String:
		range_min = 1
	var range_max = card.definition['range_max']
	if range_max is String:
		range_max = range_min + 3
	if range_min <= distance_after_effects and distance_after_effects <= range_max:
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
		var boost_chance = 0.5
		var should_boost = randf() < boost_chance
		var only_boost_continuous = false
		if should_boost and ai_game_state.my_state.continuous_boosts.size() < 3:
			if only_boost_continuous:
				var continuous_choices = []
				for action in possible_actions:
					if action is AIPlayer.BoostAction:
						var card : GameCard = ai_game_state.card_db.get_card(action.card_id)
						if card.definition['boost']['boost_type'] == "continuous":
							continuous_choices.append(action)
				if continuous_choices.size() > 0:
					return continuous_choices[randi() % continuous_choices.size()]
			else:
				var boost_choices = []
				for action in possible_actions:
					if action is AIPlayer.BoostAction:
						boost_choices.append(action)
				if boost_choices.size() > 0:
					return boost_choices[randi() % boost_choices.size()]

		# TODO: consider EX transform

		# Try to character action.
		var skip_character_action = false
		if ai_game_state.my_state.deck_def['id'] == 'bison' and ai_game_state.my_state.gauge.size() > 3:
			# Bison AI takes way too long when it builds up tons of gauge.
			skip_character_action = true

		if not skip_character_action:
			for action in possible_actions:
				if action is AIPlayer.CharacterActionAction:
					if randi() % 2 == 0:
						return action

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

func pick_boost_action(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]

func pick_pay_strike_force_cost(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
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
	var only_yours = []
	for action in possible_actions:
		if action is AIPlayer.DiscardContinuousBoostAction:
			if not action.mine:
				only_yours.append(action)
	if only_yours.size() > 0:
		only_yours = possible_actions
		return only_yours[randi() % len(only_yours)]
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
	if possible_actions[0].location == 0 and possible_actions.size() > 1:
		# Don't pick pass.
		return possible_actions[(randi() % (len(possible_actions)- 1)) + 1]
	return possible_actions[randi() % len(possible_actions)]

func pick_number_from_range_for_effect(possible_actions : Array, _ai_game_state : AIPlayer.AIGameState):
	return possible_actions[randi() % len(possible_actions)]
