extends Node2D

const LocalGame = preload("res://scenes/game/local_game.gd")
const AIPolicyRandom = preload("res://scenes/game/ai/ai_policy_random.gd")
const AIPolicyRules = preload("res://scenes/game/ai/ai_policy_rules.gd")
const Enums = preload("res://scenes/game/enums.gd")
const CardDatabase = preload("res://scenes/game/card_database.gd")

var game_player : LocalGame.Player
var game_state : AIGameState = AIGameState.new()

var ai_policy = AIPolicyRules.new()

func set_ai_policy(new_policy):
	ai_policy = new_policy

class AIPlayerState:
	var player_id : Enums.PlayerId
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

class AIStrikeState:
	var active : bool = false
	var initiator : Enums.PlayerId
	var initiator_card_id : int
	var initiator_ex_card_id : int
	var defender_card_id : int
	var defender_ex_card_id : int

class AIGameState:
	var my_state = AIPlayerState.new()
	var opponent_state = AIPlayerState.new()
	var active_strike = AIStrikeState.new()
	var card_db : CardDatabase

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
	var payment_card_ids
	func _init(boost_card_id, boost_payment_card_ids):
		card_id = boost_card_id
		payment_card_ids = boost_payment_card_ids

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

class ForceForEffectAction:
	var card_ids
	func _init(card_id_combination):
		card_ids = card_id_combination

class GaugeForEffectAction:
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
	var mine : bool
	func _init(boost_card_id, is_mine : bool):
		card_id = boost_card_id
		mine = is_mine

class DiscardGaugeAction:
	var card_id
	func _init(chosen_id):
		card_id = chosen_id

class NameCardAction:
	var card_id
	func _init(named_id):
		card_id = named_id

class HandToGaugeAction:
	var card_ids
	func _init(chosen_ids):
		card_ids = chosen_ids

class MulliganAction:
	var card_ids
	func _init(card_id_combination):
		card_ids = card_id_combination

class ChooseFromBoostsAction:
	var card_ids
	func _init(chosen_ids):
		card_ids = chosen_ids

class ChooseFromDiscardAction:
	var card_ids
	func _init(chosen_ids):
		card_ids = chosen_ids

class ChooseToDiscardAction:
	var card_ids
	func _init(card_id_combination):
		card_ids = card_id_combination

class ChooseFromTopdeckAction:
	var card_id
	var action
	func _init(chosen_card_id : int, chosen_action : String):
		card_id = chosen_card_id
		action = chosen_action

class CharacterActionAction:
	var card_ids
	var action_idx
	func _init(card_id_combination, action_idx_value):
		card_ids = card_id_combination
		self.action_idx = action_idx_value

class ChooseArenaLocationAction:
	var location
	func _init(chosen_location):
		location = chosen_location

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

func update_ai_state(_game_logic : LocalGame, me : LocalGame.Player, opponent : LocalGame.Player):
	game_state.card_db = _game_logic.get_card_database()

	game_state.my_state.player_id = me.my_id
	game_state.my_state.life = me.life
	game_state.my_state.deck = create_sanitized_card_id_array(me.deck)
	game_state.my_state.full_deck = me.deck_list
	game_state.my_state.hand = create_card_id_array(me.hand)
	game_state.my_state.discards = create_card_id_array(me.discards)
	game_state.my_state.continuous_boosts = create_card_id_array(me.continuous_boosts)
	game_state.my_state.gauge = create_card_id_array(me.gauge)
	game_state.my_state.arena_location = me.arena_location
	game_state.my_state.exceed_cost = me.exceed_cost
	game_state.my_state.exceeded = me.exceeded
	game_state.my_state.reshuffle_remaining = me.reshuffle_remaining

	game_state.opponent_state.player_id = opponent.my_id
	game_state.opponent_state.life = opponent.life
	game_state.opponent_state.deck = create_sanitized_card_id_array(opponent.deck)
	game_state.opponent_state.full_deck = opponent.deck_list
	game_state.opponent_state.hand = create_sanitized_card_id_array(opponent.hand)
	game_state.opponent_state.discards = create_card_id_array(opponent.discards)
	game_state.opponent_state.continuous_boosts = create_card_id_array(opponent.continuous_boosts)
	game_state.opponent_state.gauge = create_card_id_array(opponent.gauge)
	game_state.opponent_state.arena_location = opponent.arena_location
	game_state.opponent_state.exceed_cost = opponent.exceed_cost
	game_state.opponent_state.exceeded = opponent.exceeded
	game_state.opponent_state.reshuffle_remaining = opponent.reshuffle_remaining

	game_state.active_strike.active = _game_logic.active_strike != null
	if game_state.active_strike.active:
		game_state.active_strike.initiator = _game_logic.active_strike.initiator.my_id
		game_state.active_strike.initiator_card_id = -1
		if _game_logic.active_strike.initiator_card:
			game_state.active_strike.initiator_card_id = _game_logic.active_strike.initiator_card.id
		game_state.active_strike.initiator_ex_card_id = -1
		if _game_logic.active_strike.initiator_ex_card:
			game_state.active_strike.initiator_ex_card_id = _game_logic.active_strike.initiator_ex_card.id
		game_state.active_strike.defender_card_id = -1
		if _game_logic.active_strike.defender_card:
			game_state.active_strike.defender_card_id = _game_logic.active_strike.defender_card.id
		game_state.active_strike.defender_ex_card_id = -1
		if _game_logic.active_strike.defender_ex_card:
			game_state.active_strike.defender_ex_card_id = _game_logic.active_strike.defender_ex_card.id


func take_turn(game_logic : LocalGame, my_id : Enums.PlayerId):
	var me = game_logic._get_player(my_id)
	var opponent = game_logic._get_player(game_logic.get_other_player(my_id))
	# Decide which action makes the most sense to take.
	var possible_actions = determine_possible_turn_actions(game_logic, me, opponent)
	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_turn_action(possible_actions, game_state)

func take_boost(game_logic : LocalGame, my_id : Enums.PlayerId, allow_gauge : bool, limitation : String) -> BoostAction:
	var me = game_logic._get_player(my_id)
	var opponent = game_logic._get_player(game_logic.get_other_player(my_id))
	# Decide which action makes the most sense to take.
	var possible_actions = get_boost_actions(game_logic, me, opponent, allow_gauge, limitation)
	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_boost_action(possible_actions, game_state)

func determine_possible_turn_actions(game_logic : LocalGame, me : LocalGame.Player, opponent : LocalGame.Player):
	var possible_actions = []

	possible_actions += get_prepare_actions(game_logic, me, opponent)
	possible_actions += get_move_actions(game_logic, me, opponent)
	possible_actions += get_change_cards_actions(game_logic, me, opponent)
	possible_actions += get_exceed_actions(game_logic, me, opponent)
	possible_actions += get_reshuffle_actions(game_logic, me, opponent)
	possible_actions += get_boost_actions(game_logic, me, opponent, false, "")
	possible_actions += get_strike_actions(game_logic, me, opponent)
	possible_actions += get_character_action_actions(game_logic, me, opponent)
	return possible_actions

func get_prepare_actions(_game_logic : LocalGame, me : LocalGame.Player, _opponent : LocalGame.Player):
	# Don't allow if you insta-lose from doing so.
	if me.reshuffle_remaining == 0 and len(me.deck) < 2:
		return []
	return [PrepareAction.new()]

func get_move_actions(game_logic : LocalGame, me : LocalGame.Player, opponent : LocalGame.Player):
	var possible_move_actions = []
	var available_force = me.get_available_force()
	if me.cannot_move:
		return possible_move_actions

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
			generate_force_combinations(game_logic, all_force_option_ids, force_to_move_here, [], 0, combinations)
			for combo in combinations:
				possible_move_actions.append(MoveAction.new(i, combo))
	return possible_move_actions

func generate_force_combinations(game_logic : LocalGame, cards, force_target, current_combination, current_index, combinations):
	var current_force = 0
	var card_db = game_logic.get_card_database()
	for card_id in current_combination:
		current_force += card_db.get_card_force_value(card_id)
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

func get_change_cards_actions(_game_logic : LocalGame, me : LocalGame.Player, _opponent : LocalGame.Player):
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

func get_combinations_to_pay_gauge(me : LocalGame.Player, gauge_cost : int):
	var gauge_card_options = []
	for card in me.gauge:
		gauge_card_options.append(card.id)
	var combinations = []
	generate_card_count_combinations(gauge_card_options, gauge_cost, [], 0, combinations)
	return combinations

func get_exceed_actions(_game_logic : LocalGame, me : LocalGame.Player, _opponent : LocalGame.Player):
	var possible_actions = []
	if me.exceeded:
		return []
	if me.exceed_cost > me.gauge.size():
		return []

	var combinations = get_combinations_to_pay_gauge(me, me.exceed_cost)
	for combination in combinations:
		possible_actions.append(ExceedAction.new(combination))
	return possible_actions

func get_reshuffle_actions(_game_logic : LocalGame, me : LocalGame.Player, _opponent : LocalGame.Player):
	if me.reshuffle_remaining == 0 or me.discards.size() == 0:
		return []
	return [ReshuffleAction.new()]

func does_boost_work(_game_logic : LocalGame, _me : LocalGame.Player, _opponent : LocalGame.Player, _card_id):
	# Examine the boost effect of the card to see if it does anything.
	# For example, Retreat/Advance when they don't move, and there are no bonuses.
	# Though maybe you do this just to cancel? So only:
	# Draw when it kills you.
	return true

func get_boost_options_for_card(game_logic : LocalGame, me : LocalGame.Player, opponent : LocalGame.Player, card_id):
	# Examine the boost effect of the card to see how many options it has.
	# For example, Push 1-2 or Push 1-2 has 4 options.
	var card_db = game_logic.get_card_database()
	var card = card_db.get_card(card_id)
	var boost_effects = card.definition['boost']['effects']
	var choices = 0
	for effect in boost_effects:
		if effect['effect_type'] == "choice":
			choices += len(effect['choice'])
		elif effect['effect_type'] == "gauge_from_hand":
			choices += me.hand.size() - 1 # -1 for this card.
		elif effect['effect_type'] == "name_card_opponent_discards":
			@warning_ignore("integer_division")
			choices += opponent.deck_list.size() / 2
		elif effect['effect_type'] == "discard_continuous_boost":
			choices += len(opponent.continuous_boosts) + len(me.continuous_boosts)
		elif effect['effect_type'] == "reading_normal":
			choices = 8

		if 'and' in effect and effect['and']['effect_type'] == "choice":
			choices += len(effect['and']['choice'])

	return choices

func get_boost_actions(game_logic : LocalGame, me : LocalGame.Player, opponent : LocalGame.Player, allow_gauge : bool, limitation : String):
	var possible_actions = []
	for card in me.hand:
		if limitation and card.definition['boost']['boost_type'] != limitation:
			continue
		if does_boost_work(game_logic, me, opponent, card.id):
			var cost = card.definition['boost']['force_cost']
			if cost > 0:
				var all_force_option_ids = []
				for payment_card in me.hand:
					all_force_option_ids.append(payment_card.id)
				for payment_card in me.gauge:
					all_force_option_ids.append(payment_card.id)
				all_force_option_ids.erase(card.id)
				var combinations = []
				generate_force_combinations(game_logic, all_force_option_ids, cost, [], 0, combinations)
				for combo in combinations:
					possible_actions.append(BoostAction.new(card.id, combo))
			else:
				possible_actions.append(BoostAction.new(card.id, []))
	if allow_gauge:
		for card in me.gauge:
			if limitation and card.definition['boost']['boost_type'] != limitation:
				continue
			if does_boost_work(game_logic, me, opponent, card.id):
				var cost = card.definition['boost']['force_cost']
				if cost > 0:
					var all_force_option_ids = []
					for payment_card in me.hand:
						all_force_option_ids.append(payment_card.id)
					for payment_card in me.gauge:
						all_force_option_ids.append(payment_card.id)
					all_force_option_ids.erase(card.id)
					var combinations = []
					generate_force_combinations(game_logic, all_force_option_ids, cost, [], 0, combinations)
					for combo in combinations:
						possible_actions.append(BoostAction.new(card.id, combo))
				else:
					possible_actions.append(BoostAction.new(card.id, []))
	return possible_actions

func get_ex_option_in_hand(game_logic : LocalGame, me : LocalGame.Player, card_id : int):
	var card_db = game_logic.get_card_database()
	for card in me.hand:
		if card.id == card_id:
			continue
		if card_db.are_same_card(card_id, card.id):
			return card.id
	return -1

func get_strike_actions(game_logic : LocalGame, me : LocalGame.Player, _opponent : LocalGame.Player, from_gauge : bool = false):
	var possible_actions = []
	# Always allow wild swing if allowed.
	if not from_gauge:
		possible_actions.append(StrikeAction.new(-1, -1, true))

	# Ignore cards that you can't pay for.
	# Wait to pay for cards until later (you get to see what they flip).
	# Add wild swing.
	var added_ex_options = [-1]
	if from_gauge:
		for card in me.gauge:
			if card.definition['gauge_cost'] > me.gauge.size() - 1:
				# Skip cards we can't pay for.
				continue
			possible_actions.append(StrikeAction.new(card.id, -1, false))
	else:
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

func get_character_action_actions(game_logic : LocalGame, me : LocalGame.Player, _opponent : LocalGame.Player):
	var possible_actions = []
	for action_idx in range(me.get_character_action_count()):
		if me.can_do_character_action(action_idx):
			var action = me.get_character_action(action_idx)
			var force_cost = action['force_cost']
			var gauge_cost = action['gauge_cost']
			if force_cost > 0:
				var all_force_option_ids = []
				for card in me.hand:
					all_force_option_ids.append(card.id)
				for card in me.gauge:
					all_force_option_ids.append(card.id)
				var combinations = []
				generate_force_combinations(game_logic, all_force_option_ids, force_cost, [], 0, combinations)
				for combo in combinations:
					possible_actions.append(CharacterActionAction.new(combo, action_idx))
			elif gauge_cost > 0:
				var combinations = get_combinations_to_pay_gauge(me, gauge_cost)
				for combination in combinations:
					possible_actions.append(CharacterActionAction.new(combination, action_idx))
			else:
				# No cost.
				possible_actions.append(CharacterActionAction.new([], action_idx))
	return possible_actions

func pay_strike_gauge_cost(game_logic : LocalGame, my_id : Enums.PlayerId, gauge_cost : int, wild_swing_allowed : bool) -> PayStrikeCostAction:
	var me = game_logic._get_player(my_id)
	var opponent = game_logic._get_player(game_logic.get_other_player(my_id))
	# Decide which action makes the most sense to take.
	var possible_actions = determine_pay_strike_gauge_cost_actions(me, gauge_cost, wild_swing_allowed)
	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_pay_strike_gauge_cost(possible_actions, game_state)

func determine_pay_strike_gauge_cost_actions(me : LocalGame.Player, gauge_cost : int, wild_swing_allowed : bool):
	var possible_actions = []
	if wild_swing_allowed:
		possible_actions.append(PayStrikeCostAction.new([], true))

	if len(me.gauge) >= gauge_cost:
		var combinations = get_combinations_to_pay_gauge(me, gauge_cost)
		for combination in combinations:
			possible_actions.append(PayStrikeCostAction.new(combination, false))

	return possible_actions

func pick_effect_choice(game_logic : LocalGame, my_id : Enums.PlayerId) -> EffectChoiceAction:
	var me = game_logic._get_player(my_id)
	var opponent = game_logic._get_player(game_logic.get_other_player(my_id))
	# Decide which action makes the most sense to take.
	var possible_actions = determine_effect_choice_actions(game_logic, me)
	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_effect_choice(possible_actions, game_state)

func determine_effect_choice_actions(game_logic : LocalGame, _me : LocalGame.Player):
	var choice_count = len(game_logic.decision_info.choice)
	var possible_actions = []
	for i in range(0, choice_count):
		possible_actions.append(EffectChoiceAction.new(i))
	return possible_actions

func pick_force_for_armor(game_logic : LocalGame, my_id : Enums.PlayerId) -> ForceForArmorAction:
	var me = game_logic._get_player(my_id)
	var opponent = game_logic._get_player(game_logic.get_other_player(my_id))
	var possible_actions = determine_force_for_armor_actions(game_logic, me)
	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_force_for_armor(possible_actions, game_state)

func determine_force_for_armor_actions(game_logic : LocalGame, me : LocalGame.Player):
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

func determine_force_for_effect_actions(game_logic: LocalGame, me : LocalGame.Player, options : Array):
	var possible_actions = []
	var available_force = me.get_available_force()
	var all_force_option_ids = []
	for card in me.hand:
		all_force_option_ids.append(card.id)
	for card in me.gauge:
		all_force_option_ids.append(card.id)

	var max_force = game_logic.decision_info.effect['force_max']
	max_force = min(max_force, available_force)
	for target_force in options:
		if target_force > max_force:
			continue
		# Generate an action for every possible combination of cards that can get here.
		var combinations = []
		generate_force_combinations(game_logic, all_force_option_ids, target_force, [], 0, combinations)
		for combo in combinations:
			possible_actions.append(ForceForEffectAction.new(combo))
	return possible_actions

func determine_gauge_for_effect_actions(game_logic: LocalGame, me : LocalGame.Player, options : Array):
	var possible_actions = []
	var available_gauge = me.gauge.size()
	var all_option_ids = []
	for card in me.gauge:
		all_option_ids.append(card.id)

	var max_gauge = game_logic.decision_info.effect['gauge_max']
	max_gauge = min(max_gauge, available_gauge)

	for target_gauge in options:
		if target_gauge > max_gauge:
			continue
		# Generate an action for every possible combination of cards that can get here.
		var combinations = get_combinations_to_pay_gauge(me, target_gauge)
		for combo in combinations:
			possible_actions.append(GaugeForEffectAction.new(combo))
	return possible_actions

func determine_choose_to_discard_options(me : LocalGame.Player, to_discard_count : int, limitation : String, can_pass : bool):
	var possible_actions = []
	var all_card_ids = []
	for card in me.hand:
		if limitation:
			if card.definition['type'] != limitation:
				continue
		all_card_ids.append(card.id)
	to_discard_count = min(to_discard_count, all_card_ids.size())
	var combinations = []
	if can_pass:
		possible_actions.append(ChooseToDiscardAction.new([]))
	generate_card_count_combinations(all_card_ids, to_discard_count, [], 0, combinations)
	for combo in combinations:
		possible_actions.append(ChooseToDiscardAction.new(combo))
	return possible_actions

func pick_strike(game_logic : LocalGame, my_id : Enums.PlayerId, from_gauge : bool = false) -> StrikeAction:
	var me = game_logic._get_player(my_id)
	var opponent = game_logic._get_player(game_logic.get_other_player(my_id))
	var possible_actions = get_strike_actions(game_logic, me, opponent, from_gauge)
	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_strike(possible_actions, game_state)

func pick_strike_response(game_logic : LocalGame, my_id : Enums.PlayerId) -> StrikeAction:
	var me = game_logic._get_player(my_id)
	var opponent = game_logic._get_player(game_logic.get_other_player(my_id))
	var possible_actions = get_strike_actions(game_logic, me, opponent)
	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_strike_response(possible_actions, game_state)

func pick_discard_to_max(game_logic : LocalGame, my_id : Enums.PlayerId, to_discard_count : int) -> DiscardToMaxAction:
	var me = game_logic._get_player(my_id)
	var opponent = game_logic._get_player(game_logic.get_other_player(my_id))
	var possible_actions = determine_discard_to_max_options( me, to_discard_count)
	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_discard_to_max(possible_actions, game_state)

func determine_discard_to_max_options(me : LocalGame.Player, to_discard_count: int):
	var possible_actions = []
	var all_card_ids = []
	for card in me.hand:
		all_card_ids.append(card.id)
	var combinations = []
	generate_card_count_combinations(all_card_ids, to_discard_count, [], 0, combinations)
	for combo in combinations:
		possible_actions.append(DiscardToMaxAction.new(combo))
	return possible_actions

func pick_cancel(game_logic : LocalGame, my_id : Enums.PlayerId, gauge_cost : int) -> CancelAction:
	var me = game_logic._get_player(my_id)
	var opponent = game_logic._get_player(game_logic.get_other_player(my_id))
	var possible_actions = []
	possible_actions.append(CancelAction.new(false, []))
	var combinations = get_combinations_to_pay_gauge(me, gauge_cost)
	for combo in combinations:
		possible_actions.append(CancelAction.new(true, combo))
	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_cancel(possible_actions, game_state)

func pick_discard_continuous(game_logic : LocalGame, my_id : Enums.PlayerId, limitation, can_pass) -> DiscardContinuousBoostAction:
	var me = game_logic._get_player(my_id)
	var opponent = game_logic._get_player(game_logic.get_other_player(my_id))
	var possible_actions = []
	if can_pass:
		possible_actions.append(DiscardContinuousBoostAction.new(-1, true))
	for card in me.continuous_boosts:
		possible_actions.append(DiscardContinuousBoostAction.new(card.id, true))
	if limitation != "mine":
		for card in opponent.continuous_boosts:
			possible_actions.append(DiscardContinuousBoostAction.new(card.id, false))
	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_discard_continuous(possible_actions, game_state)

func pick_discard_opponent_gauge(game_logic : LocalGame, my_id : Enums.PlayerId) -> DiscardGaugeAction:
	var me = game_logic._get_player(my_id)
	var opponent = game_logic._get_player(game_logic.get_other_player(my_id))
	var possible_actions = []
	for card in opponent.gauge:
		possible_actions.append(DiscardGaugeAction.new(card.id))
	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_discard_opponent_gauge(possible_actions, game_state)

func pick_name_opponent_card(game_logic : LocalGame, my_id : Enums.PlayerId, normal_only : bool) -> NameCardAction:
	var me = game_logic._get_player(my_id)
	var opponent = game_logic._get_player(game_logic.get_other_player(my_id))
	var possible_actions = []
	for i in range(0, opponent.deck_list.size(), 2):
		# Skip every other card to avoid dupes.
		var card = opponent.deck_list[i]
		if normal_only and card.definition['type'] != "normal":
			continue
		possible_actions.append(NameCardAction.new(card.id))

	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_name_opponent_card(possible_actions, game_state)

func pick_card_hand_to_gauge(game_logic : LocalGame, my_id : Enums.PlayerId, min_amount : int, max_amount : int) -> HandToGaugeAction:
	var me = game_logic._get_player(my_id)
	var opponent = game_logic._get_player(game_logic.get_other_player(my_id))
	var possible_actions = []
	for i in range(min_amount, max_amount + 1):
		if i == 0:
			possible_actions.append(HandToGaugeAction.new([]))
			continue
		var all_card_ids = []
		for card in me.hand:
			all_card_ids.append(card.id)
		var combinations = []
		generate_card_count_combinations(all_card_ids, i, [], 0, combinations)
		for combo in combinations:
			possible_actions.append(HandToGaugeAction.new(combo))

	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_card_hand_to_gauge(possible_actions, game_state)

func pick_mulligan(game_logic : LocalGame, my_id : Enums.PlayerId) -> MulliganAction:
	var me = game_logic._get_player(my_id)
	var opponent = game_logic._get_player(game_logic.get_other_player(my_id))
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

func pick_choose_from_boosts(game_logic : LocalGame, my_id : Enums.PlayerId, choose_count : int) -> ChooseFromBoostsAction:
	var me = game_logic._get_player(my_id)
	var opponent = game_logic._get_player(game_logic.get_other_player(my_id))
	var possible_actions = []
	var possible_choice_cards = []
	for card in me.continuous_boosts:
		if card.id in me.sustained_boosts:
			continue
		possible_choice_cards.append(card.id)

	var combinations = []
	generate_card_count_combinations(possible_choice_cards, choose_count, [], 0, combinations)
	for combo in combinations:
		possible_actions.append(ChooseFromBoostsAction.new(combo))
	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_choose_from_boosts(possible_actions, game_state)

func pick_choose_from_discard(game_logic : LocalGame, my_id : Enums.PlayerId, choose_count : int) -> ChooseFromDiscardAction:
	var me = game_logic._get_player(my_id)
	var opponent = game_logic._get_player(game_logic.get_other_player(my_id))
	var possible_actions = []
	var limitation = game_logic.decision_info.limitation
	var source = game_logic.decision_info.source
	var possible_choice_cards = []
	var source_cards = me.discards
	if source == "sealed":
		source_cards = me.sealed
	elif source == "overdrive":
		source_cards = me.overdrive
	for card in source_cards:
		var can_choose = false
		match limitation:
			"special":
				can_choose = card.definition['type'] == "special"
			"ultra":
				can_choose = card.definition['type'] == "ultra"
			_:
				can_choose = true
		if can_choose:
			possible_choice_cards.append(card.id)

	var combinations = []
	generate_card_count_combinations(possible_choice_cards, choose_count, [], 0, combinations)
	for combo in combinations:
		possible_actions.append(ChooseFromDiscardAction.new(combo))
	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_choose_from_discard(possible_actions, game_state)

func pick_force_for_effect(game_logic : LocalGame, my_id : Enums.PlayerId, options : Array) -> ForceForEffectAction:
	var me = game_logic._get_player(my_id)
	var opponent = game_logic._get_player(game_logic.get_other_player(my_id))
	var possible_actions = determine_force_for_effect_actions(game_logic, me, options)
	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_force_for_effect(possible_actions, game_state)

func pick_gauge_for_effect(game_logic : LocalGame, my_id : Enums.PlayerId, options : Array) -> GaugeForEffectAction:
	var me = game_logic._get_player(my_id)
	var opponent = game_logic._get_player(game_logic.get_other_player(my_id))
	var possible_actions = determine_gauge_for_effect_actions(game_logic, me, options)
	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_gauge_for_effect(possible_actions, game_state)
	
func pick_choose_to_discard(game_logic : LocalGame, my_id : Enums.PlayerId, to_discard_count : int, limitation : String, can_pass : bool) -> ChooseToDiscardAction:
	var me = game_logic._get_player(my_id)
	var opponent = game_logic._get_player(game_logic.get_other_player(my_id))
	var possible_actions = determine_choose_to_discard_options(me, to_discard_count, limitation, can_pass)
	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_choose_to_discard(possible_actions, game_state)

func pick_choose_from_topdeck(game_logic : LocalGame, my_id : Enums.PlayerId, action_choices : Array, look_amount : int, can_pass : bool) -> ChooseFromTopdeckAction:
	var me = game_logic._get_player(my_id)
	var opponent = game_logic._get_player(game_logic.get_other_player(my_id))
	var possible_actions = []
	if can_pass:
		possible_actions.append(ChooseFromTopdeckAction.new(-1, "pass"))

	for i in range(0, look_amount):
		var card = me.deck[i]
		for action_choice in action_choices:
			possible_actions.append(ChooseFromTopdeckAction.new(card.id, action_choice))

	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_choose_from_topdeck(possible_actions, game_state)

func pick_choose_arena_location_for_effect(game_logic : LocalGame, my_id : Enums.PlayerId, options : Array) -> ChooseArenaLocationAction:
	var me = game_logic._get_player(my_id)
	var opponent = game_logic._get_player(game_logic.get_other_player(my_id))
	var possible_actions = []
	for option in options:
		possible_actions.append(ChooseArenaLocationAction.new(option))
	update_ai_state(game_logic, me, opponent)
	return ai_policy.pick_choose_arena_location_for_effect(possible_actions, game_state)
