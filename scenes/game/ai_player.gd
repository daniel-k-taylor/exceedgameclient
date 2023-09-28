extends Node2D

const GameLogic = preload("res://scenes/game/gamelogic.gd")

var test = 1

class AIPlayerState:
	var life
	var deck
	var hand
	var discards
	var boosts
	var gauge
	var arena_location
	var exceed_cost
	var exceeded
	var reshuffle_remaining

class AIGameState:
	var my_state
	var opponent_state

class PrepareAction:
	pass

class MoveAction:
	var location
	var force_card_ids
	func _init(to_location, cards_to_get_there):
		location = to_location
		force_card_ids = cards_to_get_there

class ChangeCardsAction:
	var card_ids
	func _init(card_id_combination):
		card_ids = card_id_combination

class ExceedAction:
	var card_ids
	func _init(card_id_combination):
		card_ids = card_id_combination

class ReshuffleAction:
	pass

class BoostAction:
	var card_id
	var boost_choice_index
	func _init(boost_card_id, boost_decision_choice_index):
		card_id = boost_card_id
		boost_choice_index = boost_decision_choice_index

class StrikeAction:
	var card_id
	var ex_card_id
	var wild_swing
	func _init(cid, eid, wild):
		card_id = cid
		ex_card_id = eid
		wild_swing = wild

class PayStrikeCostAction:
	var card_ids
	var wild_swing
	func _init(card_id_combination, wild):
		card_ids = card_id_combination
		wild_swing = wild

class EffectChoiceAction:
	var choice
	func _init(choice_index):
		choice = choice_index

class ForceForArmorAction:
	var card_ids
	func _init(card_id_combination):
		card_ids = card_id_combination

class DiscardToMaxAction:
	var card_ids
	func _init(card_id_combination):
		card_ids = card_id_combination

class CancelAction:
	var cancel
	var card_ids
	func _init(do_cancel, gauge_card_ids):
		cancel = do_cancel
		card_ids = gauge_card_ids

class DiscardContinuousBoostAction:
	var card_id
	func _init(boost_card_id):
		card_id = boost_card_id

class NameCardAction:
	var card_id
	func _init(named_id):
		card_id = named_id

class HandToGaugeAction:
	var card_id
	func _init(chosen_id):
		card_id = chosen_id

class MulliganAction:
	var card_ids
	func _init(card_id_combination):
		card_ids = card_id_combination

func take_turn(game_logic : GameLogic, me : GameLogic.Player, opponent : GameLogic.Player):
	# Decide which action makes the most sense to take.
	var possible_actions = determine_possible_turn_actions(game_logic, me, opponent)

	# Choose random action
	var action = possible_actions[randi() % len(possible_actions)]
	return action

func determine_possible_turn_actions(game_logic : GameLogic, me : GameLogic.Player, opponent : GameLogic.Player):
	var possible_actions = []

	possible_actions += get_prepare_actions(game_logic, me, opponent)
	possible_actions += get_move_actions(game_logic, me, opponent)
	possible_actions += get_change_cards_actions(game_logic, me, opponent)
	possible_actions += get_exceed_actions(game_logic, me, opponent)
	possible_actions += get_reshuffle_actions(game_logic, me, opponent)
	possible_actions += get_boost_actions(game_logic, me, opponent)
	possible_actions += get_strike_actions(game_logic, me, opponent)

	return possible_actions

func get_prepare_actions(_game_logic : GameLogic, me : GameLogic.Player, _opponent : GameLogic.Player):
	# Don't allow if you insta-lose from doing so.
	if me.reshuffle_remaining == 0 and len(me.deck) < 2:
		return []
	return [PrepareAction.new()]

func get_move_actions(_game_logic : GameLogic, me : GameLogic.Player, opponent : GameLogic.Player):
	var possible_move_actions = []
	var available_force = me.get_available_force()

	for i in range(1, 10):
		if me.arena_location == i or opponent.arena_location == i:
			continue
		var force_to_move_here = me.get_force_to_move_to(i)
		if available_force >= force_to_move_here:
			# Generate an action for every possible combination of cards that can get here.
			var all_force_option_ids = []
			for card in me.hand:
				all_force_option_ids.append(card.id)
			for card in me.gauge:
				all_force_option_ids.append(card.id)
			var combinations = []
			generate_force_combinations(_game_logic, all_force_option_ids, force_to_move_here, [], 0, combinations)
			for combo in combinations:
				possible_move_actions += [MoveAction.new(i, combo)]
	return possible_move_actions

func generate_force_combinations(game_logic, cards, force_target, current_combination, current_index, combinations):
	var current_force = 0
	for card_id in current_combination:
		current_force += game_logic.get_card_force(card_id)
	if current_force >= force_target:
		combinations.append(current_combination.duplicate())
		return

	for i in range(current_index, cards.size()):
		current_combination.append(cards[i])
		generate_force_combinations(game_logic, cards, force_target, current_combination, i + 1, combinations)
		current_combination.pop_back()

func generate_card_count_combinations(cards, hand_size, current_combination, current_index, combinations):
	if current_combination.size() == hand_size:
		combinations.append(current_combination.duplicate())
		return

	for i in range(current_index, cards.size()):
		current_combination.append(cards[i])
		generate_card_count_combinations(cards, hand_size, current_combination, i + 1, combinations)
		current_combination.pop_back()

func get_change_cards_actions(_game_logic : GameLogic, me : GameLogic.Player, _opponent : GameLogic.Player):
	var possible_actions = []
	var deck_remaining = len(me.deck)
	var total_change_card_options = len(me.hand) + len(me.gauge)
	if me.reshuffle_remaining == 0:
		# Don't allow insta-lose.
		total_change_card_options = min(total_change_card_options, deck_remaining - 1)

	if total_change_card_options > 0:
		# Create the combined list.
		var all_change_card_ids = []
		for card in me.hand:
			all_change_card_ids.append(card.id)
		for card in me.gauge:
			all_change_card_ids.append(card.id)

		# Calculate every permutation of moves at this point.
		var combinations = []
		for i in range(1, total_change_card_options):
			generate_card_count_combinations(all_change_card_ids, i, [], 0, combinations)
			for combination in combinations:
				possible_actions += [ChangeCardsAction.new(combination)]

	return possible_actions

func get_combinations_to_pay_gauge(me : GameLogic.Player, gauge_cost : int):
	var combinations = []
	var gauge_card_options = []
	for card in me.gauge:
		gauge_card_options.append(card.id)
	generate_card_count_combinations(gauge_card_options, gauge_cost, [], 0, combinations)
	return combinations

func get_exceed_actions(_game_logic : GameLogic, me : GameLogic.Player, _opponent : GameLogic.Player):
	var possible_actions = []
	if me.exceeded:
		return []
	if me.exceed_cost > me.gauge.size():
		return []

	var combinations = get_combinations_to_pay_gauge(me, me.exceed_cost)
	for combination in combinations:
		possible_actions += [ExceedAction.new(combination)]
	return possible_actions

func get_reshuffle_actions(_game_logic : GameLogic, me : GameLogic.Player, _opponent : GameLogic.Player):
	if me.reshuffle_remaining == 0 or me.discards.size() == 0:
		return []
	return [ReshuffleAction.new()]

func does_boost_work(_game_logic : GameLogic, _me : GameLogic.Player, _opponent : GameLogic.Player, _card_id):
	# Examine the boost effect of the card to see if it does anything.
	# For example, Retreat/Advance when they don't move, and there are no bonuses.
	# Though maybe you do this just to cancel? So only:
	# Draw when it kills you.
	return true

func get_boost_options_for_card(game_logic : GameLogic, me : GameLogic.Player, _opponent : GameLogic.Player, card_id):
	# Examine the boost effect of the card to see how many options it has.
	# For example, Push 1-2 or Push 1-2 has 4 options.
	var card = game_logic.get_card(card_id)
	var boost_effects = card.definition['boost']['effects']
	var choices = 0
	for effect in boost_effects:
		if effect['effect_type'] == "choice":
			choices += len(effect['choice'])
		elif effect['effect_type'] == "gauge_from_hand":
			choices += me.hand.size() - 1 # -1 for this card.

		if 'and' in effect and effect['and']['effect_type'] == "choice":
			choices += len(effect['and']['choice'])

	return choices

func get_boost_actions(game_logic : GameLogic, me : GameLogic.Player, opponent : GameLogic.Player):
	var possible_actions = []
	if me.hand.size() == 0:
		# Can't boost with no cards.
		return []

	for card in me.hand:
		if does_boost_work(game_logic, me, opponent, card.id):
			var option_count = get_boost_options_for_card(game_logic, me, opponent, card.id)
			for i in range(0, option_count):
				possible_actions += [BoostAction.new(card.id, i)]

	return possible_actions

func get_ex_option_in_hand(game_logic : GameLogic, me : GameLogic.Player, card_id : int):
	for card in me.hand:
		if card.id == card_id:
			continue
		if game_logic.are_same_card(card_id, card.id):
			return card.id
	return -1

func get_strike_actions(game_logic : GameLogic, me : GameLogic.Player, _opponent : GameLogic.Player):
	var possible_actions = []
	# Always allow wild swing.
	possible_actions.append(StrikeAction.new(-1, -1, true))

	# Ignore cards that you can't pay for.
	# Wait to pay for cards until later (you get to see what they flip).
	# Add wild swing.
	var added_ex_options = [-1]
	for card in me.hand:
		if card.definition['gauge_cost'] > me.gauge.size():
			# Skip cards we can't pay for.
			continue
		var ex_card_id = get_ex_option_in_hand(game_logic, me, card.id)
		if ex_card_id not in added_ex_options and card.id not in added_ex_options:
			# If we can play EX, add that as an option.
			# Don't consider ex again for these cards.
			added_ex_options.append(ex_card_id)
			added_ex_options.append(card.id)
			possible_actions.append(StrikeAction.new(card.id, ex_card_id, false))

		# Always consider playing this.
		possible_actions.append(StrikeAction.new(card.id, -1, false))

	return possible_actions

func pay_strike_gauge_cost(_game_logic : GameLogic, me : GameLogic.Player, _opponent : GameLogic.Player, gauge_cost : int, wild_swing_allowed : bool):
	# Decide which action makes the most sense to take.
	var possible_actions = determine_pay_strike_gauge_cost_actions(me, gauge_cost, wild_swing_allowed)

	# Choose random action
	var action = possible_actions[randi() % len(possible_actions)]
	return action

func determine_pay_strike_gauge_cost_actions(me : GameLogic.Player, gauge_cost : int, wild_swing_allowed : bool):
	var possible_actions = []
	if wild_swing_allowed:
		possible_actions.append(PayStrikeCostAction.new([], true))

	if len(me.gauge) >= gauge_cost:
		var combinations = get_combinations_to_pay_gauge(me, gauge_cost)
		for combination in combinations:
			possible_actions.append(PayStrikeCostAction.new(combination, false))

	return possible_actions


func pick_effect_choice(game_logic : GameLogic, me : GameLogic.Player, _opponent: GameLogic.Player):
	# Decide which action makes the most sense to take.
	var possible_actions = determine_effect_choice_actions(game_logic, me)

	# Choose random action
	var action = possible_actions[randi() % len(possible_actions)]
	return action

func determine_effect_choice_actions(game_logic : GameLogic, _me : GameLogic.Player):
	var choice_count = len(game_logic.decision_choice)
	var possible_actions = []
	for i in range(0, choice_count):
		possible_actions.append(EffectChoiceAction.new(i))
	return possible_actions

func pick_force_for_armor(game_logic : GameLogic, me : GameLogic.Player, _opponent: GameLogic.Player):
	var possible_actions = determine_force_for_armor_actions(game_logic, me)

	# Choose random action
	var action = possible_actions[randi() % len(possible_actions)]
	return action

func determine_force_for_armor_actions(game_logic : GameLogic, me : GameLogic.Player):
	var possible_actions = []
	var available_force = me.get_available_force()
	var all_force_option_ids = []
	for card in me.hand:
		all_force_option_ids.append(card.id)
	for card in me.gauge:
		all_force_option_ids.append(card.id)
	for target_force in range(0, available_force + 1):
		# Generate an action for every possible combination of cards that can get here.
		var combinations = []
		generate_force_combinations(game_logic, all_force_option_ids, target_force, [], 0, combinations)
		for combo in combinations:
			possible_actions += [ForceForArmorAction.new(combo)]
	return possible_actions

func pick_strike(game_logic : GameLogic, me : GameLogic.Player, _opponent: GameLogic.Player):
	var possible_actions = get_strike_actions(game_logic, me, _opponent)
	# Choose random action
	var action = possible_actions[randi() % len(possible_actions)]
	return action

func pick_strike_response(game_logic : GameLogic, me : GameLogic.Player, _opponent: GameLogic.Player):
	var possible_actions = get_strike_actions(game_logic, me, _opponent)
	# Choose random action
	var action = possible_actions[randi() % len(possible_actions)]
	return action


func pick_discard_to_max(_game_logic : GameLogic, me : GameLogic.Player, _opponent: GameLogic.Player, to_discard_count : int):
	var possible_actions = determine_discard_to_max_options( me, to_discard_count)
	# Choose random action
	var action = possible_actions[randi() % len(possible_actions)]
	return action

func determine_discard_to_max_options(me : GameLogic.Player, to_discard_count: int):
	var possible_actions = []
	var all_card_ids = []
	for card in me.hand:
		all_card_ids.append(card.id)
	var combinations = []
	generate_card_count_combinations(all_card_ids, to_discard_count, [], 0, combinations)
	for combo in combinations:
		possible_actions += [DiscardToMaxAction.new(combo)]
	return possible_actions

func pick_cancel(_game_logic : GameLogic, me : GameLogic.Player, _opponent: GameLogic.Player, gauge_cost : int):
	var possible_actions = []
	possible_actions.append(CancelAction.new(false, []))
	var combinations = get_combinations_to_pay_gauge(me, gauge_cost)
	for combo in combinations:
		possible_actions.append(CancelAction.new(true, combo))
	# Choose random action
	var action = possible_actions[randi() % len(possible_actions)]
	return action

func pick_discard_continuous(_game_logic : GameLogic, _me : GameLogic.Player, opponent: GameLogic.Player):
	var possible_actions = []
	for card in opponent.continuous_boosts:
		possible_actions.append(DiscardContinuousBoostAction.new(card.id))
	# Choose random action
	var action = possible_actions[randi() % len(possible_actions)]
	return action

func pick_name_opponent_card(_game_logic : GameLogic, _me : GameLogic.Player, opponent: GameLogic.Player):
	var possible_actions = []
	for i in range(0, opponent.deck_copy.size(), 2):
		# Skip every other card to avoid dupes.
		var card = opponent.deck_copy[i]
		possible_actions.append(NameCardAction.new(card.id))

	# Choose random action
	var action = possible_actions[randi() % len(possible_actions)]
	return action

func pick_card_hand_to_gauge(_game_logic : GameLogic, me : GameLogic.Player, _opponent: GameLogic.Player):
	var possible_actions = []
	for i in range(me.hand.size()):
		var card = me.hand[i]
		possible_actions.append(HandToGaugeAction.new(card.id))

	# Choose random action
	var action = possible_actions[randi() % len(possible_actions)]
	return action

func pick_mulligan(_game_logic : GameLogic, me : GameLogic.Player, _opponent: GameLogic.Player):
	var possible_actions = []
	var combinations = []
	# Always can mulligan 0 cards.
	possible_actions.append(MulliganAction.new([]))
	var hand_size = me.hand.size()
	for target_size in range(1, hand_size + 1):
		generate_card_count_combinations(me.hand, target_size, [], 0, combinations)
		for combo in combinations:
			possible_actions.append(MulliganAction.new(combo))
	# Choose random action
	var action = possible_actions[randi() % len(possible_actions)]
	return action
