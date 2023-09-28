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
	func _init(to_location):
		location = to_location

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
	var card_choice_index
	func _init(card_id, card_choice_index):
		card_id = card_id
		card_choice_index = card_choice_index

class StrikeAction:
	pass

func take_turn(game_logic : GameLogic, me : GameLogic.Player, opponent : GameLogic.Player):
	# Decide which action makes the most sense to take.
	var possible_actions = determine_possible_actions(game_logic, me, opponent)

	# Choose random action
	var action = possible_actions[randi() % len(possible_actions)]
	return action

func determine_possible_actions(game_logic : GameLogic, me : GameLogic.Player, opponent : GameLogic.Player):
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
			possible_move_actions += [MoveAction.new(i)]
	return possible_move_actions

func generate_combinations(cards, hand_size, current_combination, current_index, combinations):
	if current_combination.size() == hand_size:
		combinations.append(current_combination.duplicate())
		return

	for i in range(current_index, cards.size()):
		current_combination.append(cards[i])
		generate_combinations(cards, hand_size, current_combination, i + 1, combinations)
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
			generate_combinations(all_change_card_ids, i, [], 0, combinations)
			for combination in combinations:
				possible_actions += [ChangeCardsAction.new(combination)]

	return possible_actions

func get_exceed_actions(_game_logic : GameLogic, me : GameLogic.Player, _opponent : GameLogic.Player):
	var possible_actions = []
	if me.exceeded:
		return []
	if me.exceed_cost > me.gauge.size():
		return []

	var gauge_card_options = []
	for card in me.gauge:
		gauge_card_options.append(card.id)
	var combinations = []
	generate_combinations(gauge_card_options, me.exceed_cost, [], 0, combinations)
	for combination in combinations:
		possible_actions += [ExceedAction.new(combination)]
	return possible_actions

func get_reshuffle_actions(_game_logic : GameLogic, me : GameLogic.Player, _opponent : GameLogic.Player):
	if me.reshuffle_remaining == 0 or me.discards.size() == 0:
		return []
	return [ReshuffleAction.new()]

func does_boost_work(game_logic : GameLogic, me : GameLogic.Player, opponent : GameLogic.Player, card_id):
	# Examine the boost effect of the card to see if it does anything.
	# For example, Retreat when you can't retreat is useless.
	return false

func get_boost_options_for_card(game_logic : GameLogic, me : GameLogic.Player, opponent : GameLogic.Player, card_id):
	# Examine the boost effect of the card to see how many options it has.
	# For example, Push 1-2 or Push 1-2 has 4 options.
	return 0

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

func get_strike_actions(game_logic : GameLogic, me : GameLogic.Player, opponent : GameLogic.Player):
	var possible_actions = []

	# Ignore cards that you can't pay for.
	# Wait to pay for cards until later (you get to see what they flip).
	# Add wild swing.


	return possible_actions
