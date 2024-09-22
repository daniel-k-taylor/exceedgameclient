## AI player controller object.

## This file describes a bunch of hooks and basic functions used to provide an
## AI with options, then relay the AI's choice from those options back to the
## game controller. The actual AI decision-making is done within its
## [i]policy[/i], which is a Node that implements the laundry list of pick_*
## functions. See ai_random_policy.gd for a very basic (but complete!) example.

## The player is initialized with a reference to the relevant game and player
## objects. After that, the main entry point into the code is through [method take_turn],
## which is called by game.gd's `ai_take_turn`. `take_turn` consults the stored
## game state the game state and returns an instance of one of the various
## *Action classes defined in this file. `ai_take_turn` then uses that return
## value to manifest the appropriate changes in the game proper.

## `take_turn` enumerates all legal actions for the AI to take, then passes them
## to policy (and then forwards the return value back to game.gd as described
## above). Note that each possible variant of a (game) action counts as a
## distinct (AI) action; for example, the choice of which cards to discard for
## Force generation during a Walk.

## A broad overview of the main chunks of this file:

##   - class *State: Data wrappers for parts of game state.
##   - class *Action: Represents an action the AI may or chooses to take,
##         including parameters like which cards to discard in payment.
##   - func get_*_actions: List all possible Action objects representing
##         the named game action.
##   - func pay_*, pick_*: Entry points for AI decisions that are not at
##         the top of a turn; for example, a mid-strike decision on movement.

class_name AIPlayer
extends Resource

const TEST_PrepareOnly = false

const LocalGame = preload("res://scenes/game/local_game.gd")
const Enums = preload("res://scenes/game/enums.gd")
const CardDatabase = preload("res://scenes/game/card_database.gd")

var game_logic : LocalGame
var game_state : AIGameState
var ai_policy

# TODO: Remove these once they're being passed into functions as part of AIGameState.
var game_player: LocalGame.Player
var game_opponent: LocalGame.Player

func _init(local_game: LocalGame, player: LocalGame.Player, policy = null):
	game_logic = local_game
	game_player = player
	game_opponent = local_game._get_player(local_game.get_other_player(player.my_id))
	game_state = AIGameState.new(game_logic, game_player, game_opponent, true)
	if policy == null:
		ai_policy = AIPolicyRules.new()
	else:
		ai_policy = policy

func set_ai_policy(new_policy):
	ai_policy.free()
	ai_policy = new_policy

## The AI states are static representations of game state; perhaps even the
## current one. They replicate a bunch of primitives and basic collections so
## that they can be reasoned about without affecting the state of the actual
## game.

class AIPlayerState extends CopyableResource:
	## The underlying game object that this player state reflects.
	var player_id : Enums.PlayerId
	var life
	var deck
	# `deck_def` is the character-defining JSON, which contains the UA/XA,
	# buddies, and everything in the player's kit in general.
	var deck_def
	# `deck_list` is the full definitions of the actual cards in the deck,
	# including Astral Heats
	var deck_list
	var hand
	var discards
	var continuous_boosts
	var gauge
	var arena_location
	var buddy_locations
	var exceed_cost
	var exceeded
	var reshuffle_remaining

	func _init(player: LocalGame.Player = null, do_update: bool = false):
		self.original = player
		if do_update:
			self.update(true)

	## Syncs the data into this object to the state of the actual game.
	func update(full: bool = false):
		var source = self.true_original()
		if full:
			# These things aren't expected to ever change during a game, so
			# updating them once (on init) should be good enough
			player_id = source.my_id
			deck_def = source.deck_def
			deck_list = source.deck_list
			exceed_cost = source.get_exceed_cost()
		life = source.life
		deck = AIPlayer.create_card_id_array(source.deck)
		hand = AIPlayer.create_card_id_array(source.hand)
		discards = AIPlayer.create_card_id_array(source.discards)
		continuous_boosts = AIPlayer.create_card_id_array(source.continuous_boosts)
		gauge = AIPlayer.create_card_id_array(source.gauge)
		arena_location = source.arena_location
		buddy_locations = source.buddy_locations
		exceeded = source.exceeded
		reshuffle_remaining = source.reshuffle_remaining

	func copy(deep: bool = true):
		return copy_impl(AIPlayerState, deep)


class AIStrikeState extends CopyableResource:
	var active : bool = false
	var initiator : Enums.PlayerId
	var initiator_card_id : int
	var initiator_ex_card_id : int
	var defender_card_id : int
	var defender_ex_card_id : int

	func _init(game_logic: LocalGame = null, do_update: bool = false):
		self.original = game_logic
		if do_update:
			self.update()

	func update():
		var source = self.true_original()
		self.active = source.active_strike != null
		if self.active:
			var source_strike = source.active_strike
			self.initiator = source_strike.initiator.my_id

			self.initiator_card_id = source_strike.initiator_card.id if source_strike.initiator_card else -1
			self.initiator_ex_card_id = source_strike.initiator_ex_card.id if source_strike.initiator_ex_card else -1
			self.defender_card_id = source_strike.defender_card.id if source_strike.defender_card else -1
			self.defender_ex_card_id = source_strike.defender_ex_card.id if source_strike.defender_ex_card else -1

	func copy(deep: bool = true):
		return copy_impl(AIStrikeState, deep)


class AIGameState extends CopyableResource:
	var player: LocalGame.Player
	var opponent: LocalGame.Player
	var my_state: AIPlayerState
	var opponent_state: AIPlayerState
	var active_strike: AIStrikeState
	var active_turn_player: Enums.PlayerId
	var card_db : CardDatabase

	func _init(
			game_logic: LocalGame = null,
			the_player: LocalGame.Player = null,
			the_opponent: LocalGame.Player = null,
			do_update: bool = false):
		self.original = game_logic
		if game_logic:
			self.card_db = game_logic.get_card_database()
		self.player = the_player
		if the_player:
			my_state = AIPlayerState.new(the_player, false)
		self.opponent = the_opponent
		if the_opponent:
			opponent_state = AIPlayerState.new(the_opponent, false)
		active_strike = AIStrikeState.new(game_logic)
		if do_update:
			self.update(true)

	func update(full: bool = false):
		var source = self.true_original()
		self.active_turn_player = source.get_active_player()
		self.my_state.update(full)
		self.opponent_state.update(full)
		self.active_strike.update()

	func copy(deep: bool = true):
		return copy_impl(AIGameState, deep)


class PrepareAction:
	pass

class MoveAction:
	var location
	var force_card_ids
	var use_free_force
	func _init(to_location, cards_to_get_there, do_use_free_force):
		location = to_location
		force_card_ids = cards_to_get_there
		use_free_force = do_use_free_force

class ChangeCardsAction:
	var card_ids
	var use_free_force
	func _init(card_id_combination, do_use_free_force):
		card_ids = card_id_combination
		use_free_force = do_use_free_force

class ExceedAction:
	var card_ids
	func _init(card_id_combination):
		card_ids = card_id_combination

class ReshuffleAction:
	pass

class BoostAction:
	var card_id
	var payment_card_ids
	var use_free_force
	var additional_boost_ids
	func _init(boost_card_id, boost_payment_card_ids, do_use_free_force, additional_boosts):
		card_id = boost_card_id
		payment_card_ids = boost_payment_card_ids
		use_free_force = do_use_free_force
		additional_boost_ids = additional_boosts

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
	var use_free_force
	func _init(card_id_combination, wild, do_use_free_force):
		card_ids = card_id_combination
		wild_swing = wild
		use_free_force = do_use_free_force

class EffectChoiceAction:
	var choice
	func _init(choice_index):
		choice = choice_index

class ForceForArmorAction:
	var card_ids
	var use_free_force
	func _init(card_id_combination, do_use_free_force):
		card_ids = card_id_combination
		use_free_force = do_use_free_force

class ForceForEffectAction:
	var card_ids
	var use_free_force
	func _init(card_id_combination, do_use_free_force):
		card_ids = card_id_combination
		use_free_force = do_use_free_force

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
	var use_free_force
	func _init(card_id_combination, action_idx_value, do_use_free_force):
		card_ids = card_id_combination
		self.action_idx = action_idx_value
		use_free_force = do_use_free_force

class ChooseArenaLocationAction:
	var location
	func _init(chosen_location):
		location = chosen_location

class NumberFromRangeAction:
	var number
	func _init(chosen_number):
		number = chosen_number

static func create_sanitized_card_id_array(card_array):
	var card_ids = []
	for i in range(card_array.size()):
		card_ids.append(-1)
	return card_ids

static func create_card_id_array(card_array):
	var card_ids = []
	for card in card_array:
		card_ids.append(card.id)
	return card_ids

func take_turn():
	game_state.update()
	var possible_actions = determine_possible_turn_actions()
	return ai_policy.pick_turn_action(possible_actions, game_state)

func take_boost(valid_zones : Array, limitation : String, ignore_costs : bool, boost_amount : int) -> BoostAction:
	game_state.update()
	var possible_actions = get_boost_actions(valid_zones, limitation, ignore_costs, boost_amount)
	return ai_policy.pick_boost_action(possible_actions, game_state)

# TODO: Change all references to game_player below to consult game_state
# instead? And possibly take game_state as an input if we ever need to generate
# possible actions out of a hypothetical scenario.

func determine_possible_turn_actions():
	var possible_actions = []

	var boost_zones = ['hand']
	if 'can_boost_from_extra' in game_player.deck_def and game_player.deck_def['can_boost_from_extra']:
		boost_zones.append('extra')

	possible_actions += get_prepare_actions()
	if not TEST_PrepareOnly:
		possible_actions += get_move_actions()
		possible_actions += get_change_cards_actions()
		possible_actions += get_exceed_actions()
		possible_actions += get_reshuffle_actions()
		possible_actions += get_boost_actions(boost_zones, "", false, 1)
		possible_actions += get_strike_actions()
		possible_actions += get_character_action_actions()
	return possible_actions

func get_prepare_actions():
	# Don't allow if you insta-lose from doing so.
	if game_player.reshuffle_remaining == 0 and len(game_player.deck) < 2:
		return []
	return [PrepareAction.new()]

func get_move_actions():
	var possible_move_actions = []
	var available_force = game_player.get_available_force()
	var free_force_available = game_player.free_force
	if game_player.cannot_move:
		return possible_move_actions

	for i in range(1, 10):
		if game_player.arena_location == i or game_opponent.arena_location == i:
			continue
		if not game_player.can_move_to(i, false):
			continue
		var force_to_move_here = game_player.get_force_to_move_to(i)
		if available_force >= force_to_move_here:
			# Generate an action for every possible combination of cards that can get here.
			var all_force_option_ids = []
			for card in game_player.hand:
				all_force_option_ids.append(card.id)
			for card in game_player.gauge:
				all_force_option_ids.append(card.id)
			var combinations = generate_force_combinations(all_force_option_ids, force_to_move_here, free_force_available)
			for combo_result in combinations:
				var combo = combo_result[0]
				var used_free_force = combo_result[1]
				possible_move_actions.append(MoveAction.new(i, combo, used_free_force))
	return possible_move_actions

## Given a list of card IDs `cards`, return all combinations of card IDs that can be spent to generate
## `force_target` Force, with up to `free_force_available` units worth of slack. The actual return value
## is a list of pairs [combination, free_force_used], where the latter is true iff at least one point of
## the "slack" is necessary for the combination.
func generate_force_combinations(cards, force_target, free_force_available):
	var current_force = game_player.force_cost_reduction
	var card_db = game_logic.get_card_database()
	if current_force >= force_target:
		return [[[], false]]

	# Each entry in result is a list whose first element is a force count
	# and whose remainder is a list of cards
	var candidates = [[current_force]]

	for card_id in cards:
		var card_force_value = card_db.get_card_force_value(card_id)
		for i in range(candidates.size()):
			# Only process candidates that already existed at the beginning of this iteration
			# (that is, ignore the ones we're about to append below, to avoid duplication).
			var combination = candidates[i]
			if combination[0] < force_target:
				if combination.size() == 1:
					candidates.append([combination[0] + card_force_value, card_id])
				else:
					candidates.append([combination[0] + card_force_value] + combination.slice(1, combination.size(), 1, true) + [card_id])
	var result = []
	for candidate in candidates:
		if candidate[0] >= force_target:
			result.append([candidate.slice(1, candidate.size(), 1, true), false])
		elif candidate[0] >= force_target - free_force_available:
			result.append([candidate.slice(1, candidate.size(), 1, true), true])
	return result

## Given a list of card IDs `cards`, return all subsets of size `hand_size`. (If not `exact`, return
## all subsets of size *up to* `hand_size`.
func generate_card_count_combinations(cards, hand_size, exact=true):
	if hand_size == 0:
		return [[]]
	var subsets = [[]]
	for card_id in cards:
		for i in range(subsets.size()):
			var subset = subsets[i]
			if subset.size() < hand_size:
				subsets.append(subset.duplicate() + [card_id])
	if not exact:
		return subsets
	var result = []
	for subset in subsets:
		if subset.size() == hand_size:
			result.append(subset)
	return result

func get_change_cards_actions():
	var possible_actions = []
	var total_change_card_options = len(game_player.hand) + len(game_player.gauge)
	possible_actions.append(ChangeCardsAction.new([], false))
	var free_force_available = game_player.free_force
	if free_force_available > 0:
		possible_actions.append(ChangeCardsAction.new([], true))

	if total_change_card_options > 5:
		# Considering more options takes too long.
		# And you never really need to CC more than this.
		total_change_card_options = 5

	if total_change_card_options > 0:
		# Create the combined list.
		var all_change_card_ids = []
		for card in game_player.hand:
			all_change_card_ids.append(card.id)
		for card in game_player.gauge:
			all_change_card_ids.append(card.id)

		# Calculate every permutation of moves at this point.
		var combinations = generate_card_count_combinations(all_change_card_ids, total_change_card_options, false)
		for i in range(1, combinations.size()):  # range excludes the first element, which is always empty
			possible_actions.append(ChangeCardsAction.new(combinations[i], false))
			if free_force_available > 0:
				possible_actions.append(ChangeCardsAction.new(combinations[i], true))

	return possible_actions

func get_combinations_to_pay_gauge(gauge_cost : int):
	var gauge_card_options = []
	for card in game_player.gauge:
		gauge_card_options.append(card.id)
	var cost_to_pay = max(gauge_cost - game_player.free_gauge, 0)
	if cost_to_pay == 0:
		return [[]]
	else:
		return generate_card_count_combinations(gauge_card_options, cost_to_pay)

func get_exceed_actions():
	var possible_actions = []
	if game_player.exceeded:
		return []
	var exceed_cost = game_player.get_exceed_cost()
	if exceed_cost == -1 or exceed_cost > game_player.gauge.size():
		return []

	var combinations = get_combinations_to_pay_gauge(game_player.get_exceed_cost())
	for combination in combinations:
		possible_actions.append(ExceedAction.new(combination))
	return possible_actions

func get_reshuffle_actions():
	if game_player.reshuffle_remaining == 0 or game_player.discards.size() == 0:
		return []
	return [ReshuffleAction.new()]

func does_boost_work(_card_id):
	# Examine the boost effect of the card to see if it does anything.
	# For example, Retreat/Advance when they don't move, and there are no bonuses.
	# Though maybe you do this just to cancel? So only:
	# Draw when it kills you.
	# TODO: Implement this lol
	return true

func get_boost_options_for_card(card_id):
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
			choices += game_player.hand.size() - 1 # -1 for this card.
		elif effect['effect_type'] == "name_card_opponent_discards":
			@warning_ignore("integer_division")
			choices += game_opponent.deck_list.size() / 2
		elif effect['effect_type'] == "discard_continuous_boost":
			choices += len(game_opponent.continuous_boosts) + len(game_player.continuous_boosts)
		elif effect['effect_type'] == "reading_normal":
			choices = 8

		if 'and' in effect and effect['and']['effect_type'] == "choice":
			choices += len(effect['and']['choice'])

	return choices

func get_boost_actions(valid_zones : Array, limitation : String, ignore_costs : bool, boost_amount : int):
	var possible_actions = []
	var zone_map = {
		"hand": game_player.hand,
		"gauge": game_player.gauge,
		"discard": game_player.discards,
		"extra": game_player.set_aside_cards
	}
	var free_force_available = game_player.free_force

	var multiple_boost_options = []
	for zone in valid_zones:
		for card in zone_map[zone]:
			if card.definition['type'] == "decree_glorious" and not game_player.exceeded:
				continue
			if card.definition['boost']['boost_type'] == "transform":
				continue
			if limitation:
				if card.definition['boost']['boost_type'] != limitation and card.definition['type'] != limitation:
					continue
			if does_boost_work(card.id):
				var cost = card.definition['boost']['force_cost']
				if not ignore_costs and cost > 0:
					assert(boost_amount <= 1)
					var all_force_option_ids = []
					for payment_card in game_player.hand:
						all_force_option_ids.append(payment_card.id)
					for payment_card in game_player.gauge:
						all_force_option_ids.append(payment_card.id)
					all_force_option_ids.erase(card.id)
					var combinations = generate_force_combinations(all_force_option_ids, cost, free_force_available)
					for combo_result in combinations:
						var combo = combo_result[0]
						var use_free_force = combo_result[1]
						possible_actions.append(BoostAction.new(card.id, combo, use_free_force, []))
				else:
					if boost_amount <= 1:
						possible_actions.append(BoostAction.new(card.id, [], false, []))
					else:
						multiple_boost_options.append(card.id)
	# If selecting multiple boosts, generate actions for their combinations
	if boost_amount > 1:
		for boost_count in range(1, boost_amount+1):
			var combinations = generate_card_count_combinations(multiple_boost_options, boost_count)
			for combination in combinations:
				possible_actions.append(BoostAction.new(combination[0], [], false, combination.slice(1)))
	return possible_actions

func get_ex_option_in_hand(card_id : int):
	var card_db = game_logic.get_card_database()
	for card in game_player.hand:
		if card.id == card_id:
			continue
		if card_db.are_same_card(card_id, card.id):
			return card.id
	return -1

func get_strike_actions(alternate_source : String = "", disable_wild_swing : bool = false, disable_ex : bool = false, require_ex : bool = false):
	var possible_actions = []
	var possible_actions_cant_pay = []
	# Always allow wild swing if allowed.
	if not alternate_source and not disable_wild_swing:
		possible_actions.append(StrikeAction.new(-1, -1, true))

	# Ignore cards that you can't pay for.
	# Wait to pay for cards until later (you get to see what they flip).
	# Add wild swing.
	var added_ex_options = [-1]
	if alternate_source == "gauge":
		for card in game_player.gauge:
			if card.definition['gauge_cost'] > game_player.gauge.size()-1:
				# Skip cards we can't pay for.
				# But remember them in case we have 0 options and must strike with something?
				possible_actions_cant_pay.append(StrikeAction.new(card.id, -1, false))
				continue

			possible_actions.append(StrikeAction.new(card.id, -1, false))
	elif alternate_source == "sealed":
		for card in game_player.sealed:
			if card.definition['gauge_cost'] > game_player.gauge.size():
				# Skip cards we can't pay for.
				# But remember them in case we have 0 options and must strike with something?
				possible_actions_cant_pay.append(StrikeAction.new(card.id, -1, false))
				continue

			possible_actions.append(StrikeAction.new(card.id, -1, false))
	else:
		var card_options = game_player.hand.duplicate()
		for card in game_player.continuous_boosts:
			if 'must_set_from_boost' in card.definition and card.definition['must_set_from_boost']:
				card_options.append(card)
			elif 'may_set_from_boost' in card.definition and card.definition['may_set_from_boost']:
				card_options.append(card)

		for card in card_options:
			if card.definition['gauge_cost'] > game_player.gauge.size():
				# Skip cards we can't pay for.
				# But remember them in case we have 0 options and must strike with something?
				if require_ex:
					var ex_card_id = get_ex_option_in_hand(card.id)
					if card in game_player.hand and ex_card_id not in added_ex_options and card.id not in added_ex_options:
						added_ex_options.append(ex_card_id)
						added_ex_options.append(card.id)
						possible_actions_cant_pay.append(StrikeAction.new(card.id, ex_card_id, false))
				else:
					possible_actions_cant_pay.append(StrikeAction.new(card.id, -1, false))
				continue

			if not disable_ex and card in game_player.hand:
				var ex_card_id = get_ex_option_in_hand(card.id)
				if ex_card_id not in added_ex_options and card.id not in added_ex_options:
					# If we can play EX, add that as an option.
					# Don't consider ex again for these cards.
					added_ex_options.append(ex_card_id)
					added_ex_options.append(card.id)
					possible_actions.append(StrikeAction.new(card.id, ex_card_id, false))

			# Always consider playing this.
			possible_actions.append(StrikeAction.new(card.id, -1, false))

	if require_ex:
		possible_actions = possible_actions.filter(func(strike_action): return strike_action.ex_card_id != -1)

	if len(possible_actions) == 0:
		# If we're forced to strike no matter what, we have to use an ultra we can't pay for.
		possible_actions += possible_actions_cant_pay

	return possible_actions

func get_character_action_actions():
	var possible_actions = []
	var free_force_available = game_player.free_force
	for action_idx in range(game_player.get_character_action_count()):
		if game_player.can_do_character_action(action_idx):
			var action = game_player.get_character_action(action_idx)
			var force_cost = action['force_cost']
			var gauge_cost = action['gauge_cost']
			if force_cost > 0:
				var all_force_option_ids = []
				for card in game_player.hand:
					all_force_option_ids.append(card.id)
				for card in game_player.gauge:
					all_force_option_ids.append(card.id)
				var combinations = generate_force_combinations(all_force_option_ids, force_cost, free_force_available)
				for combo_result in combinations:
					var combo = combo_result[0]
					var use_free_force = combo_result[1]
					possible_actions.append(CharacterActionAction.new(combo, action_idx, use_free_force))
			elif gauge_cost > 0:
				var combinations = get_combinations_to_pay_gauge(gauge_cost)
				for combination in combinations:
					possible_actions.append(CharacterActionAction.new(combination, action_idx, false))
			else:
				# No cost.
				possible_actions.append(CharacterActionAction.new([], action_idx, false))
	return possible_actions

func pay_strike_force_cost(force_cost : int, wild_swing_allowed : bool) -> PayStrikeCostAction:
	# Decide which action makes the most sense to take.
	game_state.update()
	var possible_actions = determine_pay_strike_force_cost_actions(force_cost, wild_swing_allowed)
	return ai_policy.pick_pay_strike_force_cost(possible_actions, game_state)

func pay_strike_gauge_cost(gauge_cost : int, wild_swing_allowed : bool) -> PayStrikeCostAction:
	# Decide which action makes the most sense to take.
	game_state.update()
	var possible_actions = determine_pay_strike_gauge_cost_actions(gauge_cost, wild_swing_allowed)
	return ai_policy.pick_pay_strike_gauge_cost(possible_actions, game_state)

func determine_pay_strike_force_cost_actions(force_cost : int, wild_swing_allowed : bool):
	var possible_actions = []
	if wild_swing_allowed:
		possible_actions.append(PayStrikeCostAction.new([], true, false))

	var all_force_option_ids = []
	var free_force_available = game_player.free_force
	for card in game_player.hand:
		all_force_option_ids.append(card.id)
	for card in game_player.gauge:
		all_force_option_ids.append(card.id)
	var combinations = generate_force_combinations(all_force_option_ids, force_cost, free_force_available)
	for combo_result in combinations:
		var combo = combo_result[0]
		var use_free_force = combo_result[1]
		possible_actions.append(PayStrikeCostAction.new(combo, false, use_free_force))

	return possible_actions

func determine_pay_strike_gauge_cost_actions(gauge_cost : int, wild_swing_allowed : bool):
	var possible_actions = []
	if wild_swing_allowed:
		possible_actions.append(PayStrikeCostAction.new([], true, false))

	if len(game_player.gauge) >= gauge_cost:
		var combinations = get_combinations_to_pay_gauge(gauge_cost)
		for combination in combinations:
			possible_actions.append(PayStrikeCostAction.new(combination, false, false))

	return possible_actions

func pick_effect_choice() -> EffectChoiceAction:
	# Decide which action makes the most sense to take.
	game_state.update()
	var possible_actions = determine_effect_choice_actions()
	return ai_policy.pick_effect_choice(possible_actions, game_state)

func determine_effect_choice_actions():
	var choice_count = len(game_logic.decision_info.choice)
	var possible_actions = []
	for i in range(0, choice_count):
		possible_actions.append(EffectChoiceAction.new(i))
	return possible_actions

func pick_force_for_armor(use_gauge_instead : bool) -> ForceForArmorAction:
	game_state.update()
	var possible_actions = []
	if use_gauge_instead:
		possible_actions = determine_gauge_for_armor_actions()
	else:
		possible_actions = determine_force_for_armor_actions()
	return ai_policy.pick_force_for_armor(possible_actions, game_state)

func determine_gauge_for_armor_actions():
	var possible_actions = []
	var available_gauge = game_player.gauge.size() + game_player.free_gauge
	var all_option_ids = []
	for card in game_player.gauge:
		all_option_ids.append(card.id)
	for target_gauge in range(0, available_gauge + 1):
		# Generate an action for every possible combination of cards that can get here.
		var combinations = get_combinations_to_pay_gauge(target_gauge)
		for combo in combinations:
			possible_actions.append(ForceForArmorAction.new(combo, false))
	return possible_actions

func determine_force_for_armor_actions():
	var possible_actions = []
	var available_force = game_player.get_available_force()
	if available_force > 4:
		# Considering every possible option takes way too long.
		# You're never going to need more than +8 armor AI.
		available_force = 4
	var free_force_available = game_player.free_force
	var all_force_option_ids = []

	for card in game_player.hand:
		all_force_option_ids.append(card.id)
	for card in game_player.gauge:
		all_force_option_ids.append(card.id)
	for target_force in range(0, available_force + 1):
		# Generate an action for every possible combination of cards that can get here.
		var combinations = generate_force_combinations(all_force_option_ids, target_force, free_force_available)
		for combo_result in combinations:
			var combo = combo_result[0]
			var use_free_force = combo_result[1]
			possible_actions.append(ForceForArmorAction.new(combo, use_free_force))
	return possible_actions

func determine_force_for_effect_actions(options : Array):
	var possible_actions = []
	var available_force = game_player.get_available_force()
	var free_force_available = game_player.free_force
	var all_force_option_ids = []
	for card in game_player.hand:
		all_force_option_ids.append(card.id)
	for card in game_player.gauge:
		all_force_option_ids.append(card.id)

	var max_force = game_logic.decision_info.effect['force_max']
	if max_force == -1:
		max_force = available_force
		options = []
		for i in range(max_force + 1):
			options.append(i)
	else:
		max_force = min(max_force, available_force)
	for target_force in options:
		if target_force > max_force:
			continue
		# Generate an action for every possible combination of cards that can get here.
		var combinations = generate_force_combinations(all_force_option_ids, target_force, free_force_available)
		for combo_result in combinations:
			var combo = combo_result[0]
			var use_free_force = combo_result[1]
			possible_actions.append(ForceForEffectAction.new(combo, use_free_force))
	return possible_actions

func determine_gauge_for_effect_actions(options : Array, specific_card_id : String):
	var possible_actions = []
	var available_gauge = game_player.gauge.size() + game_player.free_gauge
	var all_option_ids = []
	for card in game_player.gauge:
		if specific_card_id and card.definition['id'] != specific_card_id:
			continue
		all_option_ids.append(card.id)

	var max_gauge = game_logic.decision_info.effect['gauge_max']
	max_gauge = min(max_gauge, available_gauge)

	for target_gauge in options:
		if target_gauge > max_gauge:
			continue
		# Generate an action for every possible combination of cards that can get here.
		var combinations = get_combinations_to_pay_gauge(target_gauge)
		for combo in combinations:
			possible_actions.append(GaugeForEffectAction.new(combo))
	return possible_actions

func determine_choose_to_discard_options(to_discard_count : int, limitation : String, can_pass : bool, allow_fewer : bool, given_array = null):
	var possible_actions = []
	var all_card_ids = []
	var min_count = to_discard_count
	var max_count = to_discard_count
	if to_discard_count == -1:
		min_count = 0
		max_count = len(game_player.hand)
	elif allow_fewer:
		min_count = 0

	if limitation and limitation == "same-named":
		var card_name_map = {}
		for card in game_player.hand:
			var card_name = card.definition['display_name']
			if card_name in card_name_map:
				card_name_map[card_name].append(card.id)
			else:
				card_name_map[card_name] = [card.id]

		for card_name in card_name_map:
			possible_actions += determine_choose_to_discard_options(to_discard_count,
				"from_array", can_pass, allow_fewer, card_name_map[card_name])

	if limitation and limitation == "from_array":
		if given_array == null:
			given_array = game_logic.decision_info.choice
	for card in game_player.hand:
		if limitation:
			if limitation == "from_array":
				if card.id not in given_array:
					continue
			elif card.definition['type'] != limitation:
				continue
		all_card_ids.append(card.id)
	if to_discard_count == -1:
		to_discard_count = all_card_ids.size()
	else:
		to_discard_count = min(to_discard_count, all_card_ids.size())
	if can_pass:
		possible_actions.append(ChooseToDiscardAction.new([]))

	for discard_count in range(min_count, max_count+1):
		for combo in generate_card_count_combinations(all_card_ids, discard_count):
			possible_actions.append(ChooseToDiscardAction.new(combo))
	return possible_actions

func determine_choose_opponent_card_to_discard_options(card_ids : Array):
	var possible_actions = []
	var combinations = generate_card_count_combinations(card_ids, 1)
	for combo in combinations:
		possible_actions.append(ChooseToDiscardAction.new(combo))
	return possible_actions

func pick_strike(alternate_source : String = "", disable_wild_swing : bool = false, disable_ex : bool = false, require_ex : bool = false) -> StrikeAction:
	game_state.update()
	var possible_actions = get_strike_actions(alternate_source, disable_wild_swing, disable_ex, require_ex)
	return ai_policy.pick_strike(possible_actions, game_state)

func pick_strike_response() -> StrikeAction:
	game_state.update()
	var possible_actions = get_strike_actions()
	return ai_policy.pick_strike_response(possible_actions, game_state)

func pick_discard_to_max(to_discard_count : int) -> DiscardToMaxAction:
	game_state.update()
	var possible_actions = determine_discard_to_max_options(to_discard_count)
	return ai_policy.pick_discard_to_max(possible_actions, game_state)

func determine_discard_to_max_options(to_discard_count: int):
	var possible_actions = []
	var all_card_ids = []
	for card in game_player.hand:
		all_card_ids.append(card.id)
	var combinations = generate_card_count_combinations(all_card_ids, to_discard_count)
	for combo in combinations:
		possible_actions.append(DiscardToMaxAction.new(combo))
	return possible_actions

func pick_cancel(gauge_cost : int) -> CancelAction:
	game_state.update()
	var possible_actions = []
	possible_actions.append(CancelAction.new(false, []))
	var combinations = get_combinations_to_pay_gauge(gauge_cost)
	for combo in combinations:
		possible_actions.append(CancelAction.new(true, combo))
	return ai_policy.pick_cancel(possible_actions, game_state)

func pick_discard_continuous(limitation, can_pass, boost_name_restriction) -> DiscardContinuousBoostAction:
	game_state.update()
	var possible_actions = []
	if can_pass:
		possible_actions.append(DiscardContinuousBoostAction.new(-1, true))
	for card in game_player.continuous_boosts:
		if can_pick_discard_continuous(card, limitation, boost_name_restriction):
			possible_actions.append(DiscardContinuousBoostAction.new(card.id, true))
	if limitation not in ["mine", "in_opponent_space"]:
		for card in game_opponent.continuous_boosts:
			if can_pick_discard_continuous(card, limitation, boost_name_restriction):
				possible_actions.append(DiscardContinuousBoostAction.new(card.id, false))
	return ai_policy.pick_discard_continuous(possible_actions, game_state)

func can_pick_discard_continuous(card, limitation, boost_name_restriction):
	if 'cannot_discard' in card.definition['boost'] and card.definition['boost']['cannot_discard']:
		return false
	if limitation == "in_opponent_space":
		var card_location = game_player.get_boost_location(card.id)
		if card_location == -1 or not game_opponent.is_in_location(card_location):
			return false
		if boost_name_restriction and card.definition['boost']['display_name'] != boost_name_restriction:
			return false
	return true

func pick_discard_opponent_gauge() -> DiscardGaugeAction:
	game_state.update()
	var possible_actions = []
	for card in game_opponent.gauge:
		possible_actions.append(DiscardGaugeAction.new(card.id))
	return ai_policy.pick_discard_opponent_gauge(possible_actions, game_state)

func pick_name_opponent_card(normal_only : bool, can_use_own_reference : bool = false) -> NameCardAction:
	game_state.update()
	var card_ids = generate_distinct_opponent_card_ids(
			game_state, normal_only, can_use_own_reference)
	return ai_policy.pick_name_opponent_card(
			card_ids.map(func (card_id): return NameCardAction.new(card_id)), game_state)

func generate_distinct_opponent_card_ids(the_game_state, normal_only: bool, can_use_own_reference: bool = false):
	var possible_actions = {}
	var all_cards = the_game_state.opponent_state.deck_list.duplicate()
	if can_use_own_reference:
		all_cards.append_array(the_game_state.my_state.deck_list.duplicate())
	for card in all_cards:
		if normal_only and card.definition['type'] != 'normal':
			continue
		if card.definition['id'] not in possible_actions:
			possible_actions[card.definition['id']] = card.id
	return possible_actions.values()

func pick_card_hand_to_gauge(min_amount : int, max_amount : int) -> HandToGaugeAction:
	game_state.update()
	var possible_actions = []
	for i in range(min_amount, max_amount + 1):
		if i == 0:
			possible_actions.append(HandToGaugeAction.new([]))
			continue
		var all_card_ids = []
		for card in game_player.hand:
			all_card_ids.append(card.id)
		var combinations = generate_card_count_combinations(all_card_ids, i)
		for combo in combinations:
			possible_actions.append(HandToGaugeAction.new(combo))
	return ai_policy.pick_card_hand_to_gauge(possible_actions, game_state)

func pick_mulligan() -> MulliganAction:
	game_state.update()
	var possible_actions = []
	# Always can mulligan 0 cards.
	possible_actions.append(MulliganAction.new([]))
	var hand_size = game_player.hand.size()
	var all_card_ids = []
	for card in game_player.hand:
		all_card_ids.append(card.id)
	for target_size in range(1, hand_size + 1):
		for combo in generate_card_count_combinations(all_card_ids, target_size):
			possible_actions.append(MulliganAction.new(combo))
	return ai_policy.pick_mulligan(possible_actions, game_state)

func pick_choose_from_boosts(choose_count : int) -> ChooseFromBoostsAction:
	game_state.update()
	var possible_actions = []
	var possible_choice_cards = []
	for card in game_player.continuous_boosts:
		if card.id in game_player.sustained_boosts:
			continue
		possible_choice_cards.append(card.id)

	var combinations = generate_card_count_combinations(possible_choice_cards, choose_count)
	for combo in combinations:
		possible_actions.append(ChooseFromBoostsAction.new(combo))
	return ai_policy.pick_choose_from_boosts(possible_actions, game_state)

func pick_choose_from_discard(choose_count : int) -> ChooseFromDiscardAction:
	game_state.update()
	var possible_actions = []
	var limitation = game_logic.decision_info.limitation
	var source = game_logic.decision_info.source
	var possible_choice_cards = []
	var source_cards = game_player.discards
	if source == "sealed":
		source_cards = game_player.sealed
	elif source == "overdrive":
		source_cards = game_player.overdrive
	for card in source_cards:
		var can_choose = false
		match limitation:
			"normal":
				can_choose = card.definition['type'] == "normal"
			"special":
				can_choose = card.definition['type'] == "special"
			"ultra":
				can_choose = card.definition['type'] == "ultra"
			"special/ultra":
				can_choose = card.definition['type'] in ["special", "ultra"]
			"continuous":
				can_choose = card.definition['boost']['boost_type'] == "continuous"
			"transform":
				can_choose = card.definition['boost']['boost_type'] == "transform"
			_:
				can_choose = true
		if can_choose:
			possible_choice_cards.append(card.id)

	var combinations = generate_card_count_combinations(possible_choice_cards, choose_count)
	for combo in combinations:
		possible_actions.append(ChooseFromDiscardAction.new(combo))
	return ai_policy.pick_choose_from_discard(possible_actions, game_state)

func pick_force_for_effect(options : Array) -> ForceForEffectAction:
	game_state.update()
	var possible_actions = determine_force_for_effect_actions(options)
	return ai_policy.pick_force_for_effect(possible_actions, game_state)

func pick_gauge_for_effect(options : Array, specific_card_id : String = "") -> GaugeForEffectAction:
	game_state.update()
	var possible_actions = determine_gauge_for_effect_actions(options, specific_card_id)
	return ai_policy.pick_gauge_for_effect(possible_actions, game_state)

func pick_choose_to_discard(to_discard_count : int, limitation : String, can_pass : bool, allow_fewer : bool = false) -> ChooseToDiscardAction:
	game_state.update()
	var possible_actions = determine_choose_to_discard_options(to_discard_count, limitation, can_pass, allow_fewer)
	return ai_policy.pick_choose_to_discard(possible_actions, game_state)

func pick_choose_opponent_card_to_discard(discard_option_ids : Array) -> ChooseToDiscardAction:
	game_state.update()
	var possible_actions = determine_choose_opponent_card_to_discard_options(discard_option_ids)
	return ai_policy.pick_choose_opponent_card_to_discard(possible_actions, game_state)

func pick_choose_from_topdeck(action_choices : Array, look_amount : int, can_pass : bool) -> ChooseFromTopdeckAction:
	game_state.update()
	var possible_actions = []
	if can_pass:
		possible_actions.append(ChooseFromTopdeckAction.new(-1, "pass"))

	for i in range(0, look_amount):
		var card = game_player.deck[i]
		for action_choice in action_choices:
			possible_actions.append(ChooseFromTopdeckAction.new(card.id, action_choice))

	return ai_policy.pick_choose_from_topdeck(possible_actions, game_state)

func pick_choose_arena_location_for_effect(options : Array) -> ChooseArenaLocationAction:
	game_state.update()
	var possible_actions = []
	for option in options:
		possible_actions.append(ChooseArenaLocationAction.new(option))
	return ai_policy.pick_choose_arena_location_for_effect(possible_actions, game_state)

func pick_number_from_range_for_effect(options : Array, _effects : Array) -> NumberFromRangeAction:
	game_state.update()
	var possible_actions = []
	for option in options:
		possible_actions.append(NumberFromRangeAction.new(option))
	return ai_policy.pick_number_from_range_for_effect(possible_actions, game_state)
