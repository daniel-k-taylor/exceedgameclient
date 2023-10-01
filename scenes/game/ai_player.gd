extends Node2D

const GameLogic = preload("res://scenes/game/gamelogic.gd")
const AIPolicyRandom = preload("res://scenes/game/ai/ai_policy_random.gd")

var game_player : GameLogic.Player
var game_state : AIGameState = AIGameState.new()

var ai_policy = AIPolicyRandom.new()

func set_ai_policy(new_policy):
	ai_policy = new_policy

class AIPlayerState:
	var life
	var deck
	var full_deck
	var hand
	var discards
	var continuous_boosts
	var gauge
	var arena_location
	var exceed_cost
	var exceeded
	var reshuffle_remaining

class AIGameState:
	var my_state = AIPlayerState.new()
	var opponent_state = AIPlayerState.new()

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

func create_sanitized_card_id_array(card_array):
	var card_ids = []
	for i in range(card_array.size()):
		card_ids.append(-1)
	return card_ids

func create_card_id_array(card_array):
	var card_ids = []
	for card in card_array:
		card_ids.append(card.id)
	return card_ids

func update_ai_state(_game_logic : GameLogic, me : GameLogic.Player, opponent : GameLogic.Player):
	game_state.my_state.life = me.life
	game_state.my_state.deck = create_sanitized_card_id_array(me.deck)
	game_state.my_state.full_deck = me.deck_copy
	game_state.my_state.hand = create_card_id_array(me.hand)
	game_state.my_state.discards = create_card_id_array(me.discards)
	game_state.my_state.continuous_boosts = create_card_id_array(me.continuous_boosts)
	game_state.my_state.gauge = create_card_id_array(me.gauge)
	game_state.my_state.arena_location = me.arena_location
	game_state.my_state.exceed_cost = me.exceed_cost
	game_state.my_state.exceeded = me.exceeded
	game_state.my_state.reshuffle_remaining = me.reshuffle_remaining

	game_state.opponent_state.life = opponent.life
	game_state.opponent_state.deck = create_sanitized_card_id_array(opponent.deck)
	game_state.opponent_state.full_deck = opponent.deck_copy
	game_state.opponent_state.hand = create_sanitized_card_id_array(opponent.hand)
	game_state.opponent_state.discards = create_card_id_array(opponent.discards)
	game_state.opponent_state.continuous_boosts = create_card_id_array(opponent.continuous_boosts)
	game_state.opponent_state.gauge = create_card_id_array(opponent.gauge)
	game_state.opponent_state.arena_location = opponent.arena_location
	game_state.opponent_state.exceed_cost = opponent.exceed_cost
	game_state.opponent_state.exceeded = opponent.exceeded
	game_state.opponent_state.reshuffle_remaining = opponent.reshuffle_remaining

func take_turn(game_logic : GameLogic, me : GameLogic.Player, opponent : GameLogic.Player):
	# Decide which action makes the most sense to take.
	var possible_actions = determine_possible_turn_actions(game_logic, me, opponent)
	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_turn_action(possible_actions, game_state)

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
				possible_move_actions.append(MoveAction.new(i, combo))
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
	var total_change_card_options = len(me.hand) + len(me.gauge)
	possible_actions.append(ChangeCardsAction.new([]))

	if total_change_card_options > 0:
		# Create the combined list.
		var all_change_card_ids = []
		for card in me.hand:
			all_change_card_ids.append(card.id)
		for card in me.gauge:
			all_change_card_ids.append(card.id)

		# Calculate every permutation of moves at this point.
		for target_size in range(1, total_change_card_options + 1):
			var combinations = []
			generate_card_count_combinations(all_change_card_ids, target_size, [], 0, combinations)
			for combination in combinations:
				possible_actions.append(ChangeCardsAction.new(combination))

	return possible_actions

func get_combinations_to_pay_gauge(me : GameLogic.Player, gauge_cost : int):
	var gauge_card_options = []
	for card in me.gauge:
		gauge_card_options.append(card.id)
	var combinations = []
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
		possible_actions.append(ExceedAction.new(combination))
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

func get_boost_options_for_card(game_logic : GameLogic, me : GameLogic.Player, opponent : GameLogic.Player, card_id):
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
		elif effect['effect_type'] == "name_card_opponent_discards":
			@warning_ignore("integer_division")
			choices += opponent.deck_copy.size() / 2
		elif effect['effect_type'] == "discard_continuous_boost":
			choices += len(opponent.continuous_boosts)

		if 'and' in effect and effect['and']['effect_type'] == "choice":
			choices += len(effect['and']['choice'])

	return choices

func get_boost_actions(game_logic : GameLogic, me : GameLogic.Player, opponent : GameLogic.Player):
	var possible_actions = []
	for card in me.hand:
		if does_boost_work(game_logic, me, opponent, card.id):
			var option_count = get_boost_options_for_card(game_logic, me, opponent, card.id)
			if option_count > 0:
				for i in range(0, option_count):
					possible_actions.append(BoostAction.new(card.id, i))
			else:
				# No choices, just boost normally.
				possible_actions.append(BoostAction.new(card.id, 0))

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

func pay_strike_gauge_cost(game_logic : GameLogic, me : GameLogic.Player, opponent : GameLogic.Player, gauge_cost : int, wild_swing_allowed : bool) -> PayStrikeCostAction:
	# Decide which action makes the most sense to take.
	var possible_actions = determine_pay_strike_gauge_cost_actions(me, gauge_cost, wild_swing_allowed)
	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_pay_strike_gauge_cost(possible_actions, game_state)

func determine_pay_strike_gauge_cost_actions(me : GameLogic.Player, gauge_cost : int, wild_swing_allowed : bool):
	var possible_actions = []
	if wild_swing_allowed:
		possible_actions.append(PayStrikeCostAction.new([], true))

	if len(me.gauge) >= gauge_cost:
		var combinations = get_combinations_to_pay_gauge(me, gauge_cost)
		for combination in combinations:
			possible_actions.append(PayStrikeCostAction.new(combination, false))

	return possible_actions


func pick_effect_choice(game_logic : GameLogic, me : GameLogic.Player, opponent: GameLogic.Player) -> EffectChoiceAction:
	# Decide which action makes the most sense to take.
	var possible_actions = determine_effect_choice_actions(game_logic, me)
	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_effect_choice(possible_actions, game_state)

func determine_effect_choice_actions(game_logic : GameLogic, _me : GameLogic.Player):
	var choice_count = len(game_logic.decision_choice)
	var possible_actions = []
	for i in range(0, choice_count):
		possible_actions.append(EffectChoiceAction.new(i))
	return possible_actions

func pick_force_for_armor(game_logic : GameLogic, me : GameLogic.Player, opponent: GameLogic.Player) -> ForceForArmorAction:
	var possible_actions = determine_force_for_armor_actions(game_logic, me)
	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_force_for_armor(possible_actions, game_state)

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
			possible_actions.append(ForceForArmorAction.new(combo))
	return possible_actions

func pick_strike(game_logic : GameLogic, me : GameLogic.Player, opponent: GameLogic.Player) -> StrikeAction:
	var possible_actions = get_strike_actions(game_logic, me, opponent)
	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_strike(possible_actions, game_state)

func pick_strike_response(game_logic : GameLogic, me : GameLogic.Player, opponent: GameLogic.Player) -> StrikeAction:
	var possible_actions = get_strike_actions(game_logic, me, opponent)
	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_strike_response(possible_actions, game_state)

func pick_discard_to_max(game_logic : GameLogic, me : GameLogic.Player, opponent: GameLogic.Player, to_discard_count : int) -> DiscardToMaxAction:
	var possible_actions = determine_discard_to_max_options( me, to_discard_count)
	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_discard_to_max(possible_actions, game_state)

func determine_discard_to_max_options(me : GameLogic.Player, to_discard_count: int):
	var possible_actions = []
	var all_card_ids = []
	for card in me.hand:
		all_card_ids.append(card.id)
	var combinations = []
	generate_card_count_combinations(all_card_ids, to_discard_count, [], 0, combinations)
	for combo in combinations:
		possible_actions.append(DiscardToMaxAction.new(combo))
	return possible_actions

func pick_cancel(game_logic : GameLogic, me : GameLogic.Player, opponent: GameLogic.Player, gauge_cost : int) -> CancelAction:
	var possible_actions = []
	possible_actions.append(CancelAction.new(false, []))
	var combinations = get_combinations_to_pay_gauge(me, gauge_cost)
	for combo in combinations:
		possible_actions.append(CancelAction.new(true, combo))
	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_cancel(possible_actions, game_state)

func pick_discard_continuous(game_logic : GameLogic, me : GameLogic.Player, opponent: GameLogic.Player) -> DiscardContinuousBoostAction:
	var possible_actions = []
	for card in opponent.continuous_boosts:
		possible_actions.append(DiscardContinuousBoostAction.new(card.id))
	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_discard_continuous(possible_actions, game_state)

func pick_name_opponent_card(game_logic : GameLogic, me : GameLogic.Player, opponent: GameLogic.Player) -> NameCardAction:
	var possible_actions = []
	for i in range(0, opponent.deck_copy.size(), 2):
		# Skip every other card to avoid dupes.
		var card = opponent.deck_copy[i]
		possible_actions.append(NameCardAction.new(card.id))

	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_name_opponent_card(possible_actions, game_state)

func pick_card_hand_to_gauge(game_logic : GameLogic, me : GameLogic.Player, opponent: GameLogic.Player) -> HandToGaugeAction:
	var possible_actions = []
	for i in range(me.hand.size()):
		var card = me.hand[i]
		possible_actions.append(HandToGaugeAction.new(card.id))

	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_card_hand_to_gauge(possible_actions, game_state)

func pick_mulligan(game_logic : GameLogic, me : GameLogic.Player, opponent: GameLogic.Player) -> MulliganAction:
	var possible_actions = []
	var combinations = []
	# Always can mulligan 0 cards.
	possible_actions.append(MulliganAction.new([]))
	var hand_size = me.hand.size()
	var all_card_ids = []
	for card in me.hand:
		all_card_ids.append(card.id)
	for target_size in range(1, hand_size + 1):
		generate_card_count_combinations(all_card_ids, target_size, [], 0, combinations)
		for combo in combinations:
			possible_actions.append(MulliganAction.new(combo))
	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_mulligan(possible_actions, game_state)
