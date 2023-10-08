extends Node2D

const Enums = preload("res://scenes/game/enums.gd")
const CardDatabase = preload("res://scenes/game/card_database.gd")
const GameCard = preload("res://scenes/game/game_card.gd")
const DecisionInfo = preload("res://scenes/game/decision_info.gd")

# Game Settings
const StartingHandFirstPlayer = 5
const StartingHandSecondPlayer = 6
const MaxLife = 30
const MaxHandSize = 7
const MaxReshuffle = 1
const MinArenaLocation = 1
const MaxArenaLocation = 9
const ShuffleEnabled = true

var event_queue = []

func get_latest_events() -> Array:
	var events = event_queue
	event_queue = []
	return events

var card_db : CardDatabase
var all_cards : Array = []
var game_over : bool = false
var active_strike : Strike = null

var decision_info : DecisionInfo = DecisionInfo.new()
var active_boost : Boost = null

var game_state : Enums.GameState = Enums.GameState.GameState_NotStarted

func teardown():
	card_db.teardown()
	card_db.free()
	decision_info.free()

func change_game_state(new_state : Enums.GameState):
	printlog("game_state update from %s to %s" % [Enums.GameState.keys()[game_state], Enums.GameState.keys()[new_state]])
	game_state = new_state

func printlog(text):
	print(text)

func create_event(event_type : Enums.EventType, event_player : Enums.PlayerId, num : int, reason: String = "", extra_info = null, extra_info2 = null):
	var card_name = card_db.get_card_name(num)
	var playerstr = "Player"
	if event_player == Enums.PlayerId.PlayerId_Opponent:
		playerstr = "Opponent"
	printlog("Event %s %s %d (card=%s)" % [Enums.EventType.keys()[event_type], playerstr, num, card_name])
	return {
		"event_type": event_type,
		"event_player": event_player,
		"number": num,
		"reason": reason,
		"extra_info": extra_info,
		"extra_info2": extra_info2,
	}

enum StrikeState {
	StrikeState_None,
	StrikeState_Initiator_PayCosts,
	StrikeState_Defender_PayCosts,
	StrikeState_DuringStrikeBonuses,
	StrikeState_Card1_Activation,
	StrikeState_Card1_Before,
	StrikeState_Card1_DetermineHit,
	StrikeState_Card1_Hit,
	StrikeState_Card1_Hit_Response,
	StrikeState_Card1_ApplyDamage,
	StrikeState_Card1_After,
	StrikeState_Card2_Activation,
	StrikeState_Card2_Before,
	StrikeState_Card2_DetermineHit,
	StrikeState_Card2_Hit,
	StrikeState_Card2_Hit_Response,
	StrikeState_Card2_ApplyDamage,
	StrikeState_Card2_After,
	StrikeState_Cleanup,
}

class Strike:
	var initiator : Player
	var defender : Player
	var initiator_card : GameCard
	var initiator_ex_card : GameCard = null
	var defender_card : GameCard
	var defender_ex_card : GameCard = null
	var initiator_first : bool
	var initiator_wild_strike : bool = false
	var defender_wild_strike : bool = false
	var strike_state
	var effects_resolved_in_timing : int = 0
	var player1_hit : bool = false
	var player1_stunned : bool = false
	var player2_hit : bool = false
	var player2_stunned : bool = false

	func get_card(num : int):
		if initiator_first:
			if num == 1: return initiator_card
			return defender_card
		else:
			if num == 1: return defender_card
			return initiator_card

	func get_player(num : int):
		if initiator_first:
			if num == 1: return initiator
			return defender
		else:
			if num == 1: return defender
			return initiator

	func get_player_card(performing_player : Player) -> GameCard:
		if performing_player == initiator:
			return initiator_card
		return defender_card

	func get_player_wild_strike(performing_player : Player) -> bool:
		if performing_player == initiator:
			return initiator_wild_strike
		return defender_wild_strike

	func is_player_stunned(question_player : Player) -> bool:
		if get_player(1) == question_player:
			return player1_stunned
		return player2_stunned

	func set_player_stunned(stunned_player : Player):
		if get_player(1) == stunned_player:
			player1_stunned = true
		else:
			player2_stunned = true

class Boost:
	var playing_player : Player
	var card : GameCard
	var effects_resolved = 0
	var action_after_boost = false
	var cancel_resolved = false
	var cleanup_to_gauge_card_ids = []

class StrikeStatBoosts:
	var power : int = 0
	var armor : int = 0
	var guard : int = 0
	var speed : int = 0
	var min_range : int = 0
	var max_range : int = 0
	var dodge_attacks : bool = false
	var ignore_armor : bool = false
	var ignore_guard : bool = false
	var ignore_push_and_pull : bool = false
	var always_add_to_gauge : bool = false
	var when_hit_force_for_armor : bool = false
	var is_ex : bool = false

	func clear():
		power = 0
		armor = 0
		guard = 0
		speed = 0
		min_range = 0
		max_range = 0
		dodge_attacks = false
		ignore_armor = false
		ignore_guard = false
		ignore_push_and_pull = false
		always_add_to_gauge = false
		when_hit_force_for_armor = false
		is_ex = false

	func set_ex():
		if not is_ex:
			speed += 1
			power += 1
			armor += 1
			guard += 1
			is_ex = true

class Player:
	var parent
	var card_database

	var my_id : Enums.PlayerId
	var name : String
	var life : int
	var hand : Array[GameCard]
	var deck : Array[GameCard]
	var deck_list : Array[GameCard]
	var discards : Array[GameCard]
	var deck_def : Dictionary
	var gauge : Array
	var continuous_boosts : Array[GameCard]
	var cleanup_boost_to_gauge_cards : Array[int]
	var arena_location : int
	var reshuffle_remaining : int
	var exceeded : bool
	var exceed_cost : int
	var strike_stat_boosts : StrikeStatBoosts
	var canceled_this_turn : bool
	var mulligan_complete : bool

	func _init(id, player_name, parent_ref, card_db_ref, chosen_deck, card_start_id):
		my_id = id
		name = player_name
		parent = parent_ref
		card_database = card_db_ref
		life = MaxLife
		hand = []
		deck_def = chosen_deck
		exceed_cost = deck_def['exceed_cost']
		deck = []
		deck_list = []
		strike_stat_boosts = StrikeStatBoosts.new()
		for deck_card_def in deck_def['cards']:
			var card_def = CardDefinitions.get_card(deck_card_def['definition_id'])
			var card = GameCard.new(card_start_id, card_def, deck_card_def['image'])
			card_database.add_card(card)
			deck.append(card)
			deck_list.append(card)
			card_start_id += 1
		if ShuffleEnabled:
			deck.shuffle()
		gauge = []
		continuous_boosts = []
		discards = []
		reshuffle_remaining = MaxReshuffle
		exceeded = false
		canceled_this_turn = false
		cleanup_boost_to_gauge_cards = []
		mulligan_complete = false

	func owns_card(card_id: int):
		for card in deck_list:
			if card.id == card_id:
				return true
		return false

	func exceed():
		exceeded = true
		var events = []
		events += [parent.create_event(Enums.EventType.EventType_Exceed, my_id, 0)]

		if 'on_exceed' in deck_def and deck_def['on_exceed'] == "strike":
			events += [parent.create_event(Enums.EventType.EventType_ForceStartStrike, my_id, 0)]
			parent.change_game_state(Enums.GameState.GameState_WaitForStrike)
			parent.decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
			parent.decision_info.player = my_id
		return events

	func mulligan(card_ids : Array):
		var events = []
		events += draw(len(card_ids))
		for id in card_ids:
			events += move_card_from_hand_to_deck(id)
		deck.shuffle()
		events += [parent.create_event(Enums.EventType.EventType_ReshuffleDeck_Mulligan, my_id, reshuffle_remaining)]
		mulligan_complete = true
		return events

	func is_card_in_hand(id : int):
		for card in hand:
			if card.id == id:
				return true
		return false

	func remove_card_from_hand(id : int):
		for i in range(len(hand)):
			if hand[i].id == id:
				hand.remove_at(i)
				break

	func move_card_from_hand_to_deck(id : int):
		var events = []
		for i in range(len(hand)):
			var card = hand[i]
			if card.id == id:
				deck.insert(0, card)
				hand.remove_at(i)
				events += [parent.create_event(Enums.EventType.EventType_AddToDeck, my_id, card.id)]
				break
		return events

	func move_card_from_hand_to_gauge(id : int):
		var events = []
		for i in range(len(hand)):
			var card = hand[i]
			if card.id == id:
				events += add_to_gauge(card)
				hand.remove_at(i)
				break
		return events

	func is_card_in_gauge(id : int):
		for card in gauge:
			if card.id == id:
				return true
		return false

	func can_pay_cost_with(card_ids : Array, card : GameCard):
		var gauge_generated = 0
		var force_generated = 0
		for card_id in card_ids:
			if is_card_in_hand(card_id):
				force_generated += card_database.get_card_force_value(card_id)
			elif is_card_in_gauge(card_id):
				force_generated += card_database.get_card_force_value(card_id)
				gauge_generated += 1
			else:
				parent.printlog("ERROR: Card not in hand or gauge")
				return false

		var gauge_cost = card.definition['gauge_cost']
		var force_cost = card.definition['force_cost']
		if gauge_generated < gauge_cost:
			return false
		if force_generated < force_cost:
			return false

		return true

	func can_pay_cost(card : GameCard):
		var available_force = get_available_force()
		var available_gauge = get_available_gauge()
		var gauge_cost = card.definition['gauge_cost']
		var force_cost = card.definition['force_cost']
		if available_gauge < gauge_cost:
			return false
		if available_force < force_cost:
			return false
		return true

	func can_cancel(card : GameCard):
		var available_gauge = get_available_gauge()
		var cancel_cost = card.definition['boost']['cancel_cost']
		if cancel_cost == -1: return false
		if available_gauge < cancel_cost: return false
		return true

	func draw(num_to_draw : int):
		var events : Array = []
		for i in range(num_to_draw):
			if len(deck) > 0:
				var card = deck[0]
				hand.append(card)
				deck.remove_at(0)
				events += [parent.create_event(Enums.EventType.EventType_Draw, my_id, card.id)]
			else:
				events += reshuffle_discard()
				if not parent.game_over:
					var card = deck[0]
					hand.append(card)
					deck.remove_at(0)
					events += [parent.create_event(Enums.EventType.EventType_Draw, my_id, card.id)]
		return events

	func reshuffle_discard():
		var events : Array = []
		if reshuffle_remaining == 0:
			# Game Over
			events += [parent.create_event(Enums.EventType.EventType_GameOver, my_id, 0)]
			parent.game_over = true
		else:
			# Put discard into deck, shuffle, subtract reshuffles
			deck += discards
			discards = []
			deck.shuffle()
			reshuffle_remaining -= 1
			events += [parent.create_event(Enums.EventType.EventType_ReshuffleDiscard, my_id, reshuffle_remaining)]
		return events

	func discard(card_ids : Array):
		var events = []
		for discard_id in card_ids:
			# From hand
			for i in range(len(hand)-1, -1, -1):
				var card = hand[i]
				if card.id == discard_id:
					discards.append(card)
					hand.remove_at(i)
					events += [parent.create_event(Enums.EventType.EventType_Discard, my_id, card.id)]
					break

			# From gauge
			for i in range(len(gauge)-1, -1, -1):
				var card = gauge[i]
				if card.id == discard_id:
					discards.append(card)
					gauge.remove_at(i)
					events += [parent.create_event(Enums.EventType.EventType_Discard, my_id, card.id)]
					break
		return events

	func discard_matching_or_reveal(card_definition_id : String):
		var events = []
		for card in hand:
			if card.definition['id'] == card_definition_id:
				events = discard([card.id])
				return events
		# Not found
		events += [parent.create_event(Enums.EventType.EventType_RevealHand, my_id, 0)]
		return events

	func discard_random(amount):
		var events = []
		for i in range(amount):
			if len(hand) > 0:
				var random_card_id = hand[randi() % len(hand)].id
				events += discard([random_card_id])
		return events

	func wild_strike():
		var events = []
		# Get top card of deck (reshuffle if needed)
		if len(deck) == 0:
			events += reshuffle_discard()
		if not parent.game_over:
			var card_id = deck[0].id
			if parent.active_strike.initiator == self:
				parent.active_strike.initiator_card = deck[0]
				parent.active_strike.initiator_wild_strike = true
			else:
				parent.active_strike.defender_card = deck[0]
				parent.active_strike.defender_wild_strike = true
			deck.remove_at(0)
			events += [parent.create_event(Enums.EventType.EventType_Strike_WildStrike, my_id, card_id)]
		return events

	func add_to_gauge(card: GameCard):
		gauge.append(card)
		return [parent.create_event(Enums.EventType.EventType_AddToGauge, my_id, card.id)]

	func add_to_discards(card : GameCard):
		discards.append(card)
		return [parent.create_event(Enums.EventType.EventType_AddToDiscard, my_id, card.id)]

	func get_available_force():
		var force = 0
		for card in hand:
			force += card_database.get_card_force_value(card.id)
		for card in gauge:
			force += card_database.get_card_force_value(card.id)
		return force

	func get_available_gauge():
		return len(gauge)

	func can_move_to(new_arena_location):
		if new_arena_location == arena_location: return false
		var other_player_loc = parent._get_player(parent.get_other_player(my_id)).arena_location
		if  other_player_loc == new_arena_location: return false
		var required_force = get_force_to_move_to(new_arena_location)
		return required_force <= get_available_force()

	func get_force_to_move_to(new_arena_location):
		var other_player_loc = parent._get_player(parent.get_other_player(my_id)).arena_location
		var required_force = abs(arena_location - new_arena_location)
		if ((arena_location < other_player_loc and new_arena_location > other_player_loc)
			or (new_arena_location < other_player_loc and arena_location > other_player_loc)):
			# No additional force needed because of abs calculation.
			#required_force += 1
			pass
		return required_force

	func move_to(new_arena_location):
		var events = []
		var previous_location = arena_location
		var distance = abs(arena_location - new_arena_location)
		arena_location = new_arena_location
		events += [parent.create_event(Enums.EventType.EventType_Move, my_id, new_arena_location, "move", distance, previous_location)]
		return events

	func close(amount):
		var events = []
		var previous_location = arena_location
		var other_location = parent._get_player(parent.get_other_player(my_id)).arena_location
		var new_location
		if arena_location < other_location:
			new_location = min(other_location-1, arena_location+amount)
		else:
			new_location = max(other_location+1, arena_location-amount)
		arena_location = new_location
		events += [parent.create_event(Enums.EventType.EventType_Move, my_id, new_location, "close", amount, previous_location)]
		return events

	func advance(amount):
		var events = []
		var previous_location = arena_location
		var other_player_location = parent._get_player(parent.get_other_player(my_id)).arena_location
		var new_location
		if arena_location < other_player_location:
			new_location = arena_location + amount
			if new_location >= other_player_location:
				new_location += 1
			new_location = min(new_location, MaxArenaLocation)
			if other_player_location == new_location:
				new_location -= 1
		else:
			new_location = arena_location - amount
			if new_location <= other_player_location:
				new_location -= 1
			new_location = max(new_location, MinArenaLocation)
			if other_player_location == new_location:
				new_location += 1

		arena_location = new_location
		events += [parent.create_event(Enums.EventType.EventType_Move, my_id, new_location, "advance", amount, previous_location)]

		return events

	func retreat(amount):
		var events = []
		var previous_location = arena_location
		var other_location = parent._get_player(parent.get_other_player(my_id)).arena_location
		var new_location
		if arena_location < other_location:
			new_location = arena_location - amount
			new_location = max(new_location, MinArenaLocation)
		else:
			new_location = arena_location + amount
			new_location = min(new_location, MaxArenaLocation)

		arena_location = new_location
		events += [parent.create_event(Enums.EventType.EventType_Move, my_id, new_location, "retreat", amount, previous_location)]

		return events

	func push(amount):
		var events = []
		var previous_location = arena_location
		var other_player = parent._get_player(parent.get_other_player(my_id))
		if other_player.strike_stat_boosts.ignore_push_and_pull:
			events += [parent.create_event(Enums.EventType.EventType_Strike_IgnoredPushPull, other_player.my_id, 0)]
		else:
			var other_location = other_player.arena_location
			var new_location
			if arena_location < other_location:
				new_location = other_location + amount
				new_location = min(new_location, MaxArenaLocation)
			else:
				new_location = other_location - amount
				new_location = max(new_location, MinArenaLocation)

			other_player.arena_location = new_location
			events += [parent.create_event(Enums.EventType.EventType_Move, other_player.my_id, new_location, "push", amount, previous_location)]

		return events

	func pull(amount):
		var events = []
		var previous_location = arena_location
		var other_player = parent._get_player(parent.get_other_player(my_id))
		if other_player.strike_stat_boosts.ignore_push_and_pull:
			events += [parent.create_event(Enums.EventType.EventType_Strike_IgnoredPushPull, other_player.my_id, 0)]
		else:
			var other_player_location = other_player.arena_location
			var new_location
			if arena_location < other_player_location:
				new_location = other_player_location - amount
				if arena_location >= new_location:
					new_location -= 1
				new_location = max(new_location, MinArenaLocation)
				if other_player_location == new_location:
					new_location += 1
			else:
				new_location = other_player_location + amount
				if arena_location <= new_location:
					new_location += 1
				new_location = min(new_location, MaxArenaLocation)
				if other_player_location == new_location:
					new_location -= 1

			other_player.arena_location = new_location
			events += [parent.create_event(Enums.EventType.EventType_Move, other_player.my_id, new_location, "pull", amount, previous_location)]

		return events

	func add_to_continuous_boosts(card : GameCard):
		var events = []
		continuous_boosts.append(card)
		events += [parent.create_event(Enums.EventType.EventType_Boost_Continuous_Added, my_id, card.id)]
		return events

	func remove_from_continuous_boosts(card : GameCard, to_gauge : bool):
		var events = []
		for i in range(len(continuous_boosts)):
			if continuous_boosts[i].id == card.id:
				if to_gauge:
					events += add_to_gauge(card)
				else:
					events += add_to_discards(card)
				continuous_boosts.remove_at(i)
				break
		return events

	func get_all_non_immediate_continuous_boost_effects():
		var effects = []
		for card in continuous_boosts:
			for effect in card.definition['boost']['effects']:
				if effect['timing'] != "now":
					effects.append(effect)
		return effects

	func is_card_in_continuous_boosts(id : int):
		for card in continuous_boosts:
			if card.id == id:
				return true
		return false

	func add_boost_to_gauge_on_strike_cleanup(card_id):
		cleanup_boost_to_gauge_cards.append(card_id)

	func on_cancel_boost():
		var events = []
		events += [parent.create_event(Enums.EventType.EventType_Boost_Canceled, my_id, 0)]
		if not canceled_this_turn:
			# Create a strike state just to track completing effects at this timing.
			var effects = get_character_effects_at_timing("on_cancel_boost")
			# NOTE: Only 1 choice currently allowed.
			for effect in effects:
				if parent.is_effect_condition_met(self, effect, null):
					events += parent.handle_strike_effect(-1, effect, self)
			canceled_this_turn = true

		return events

	func cleanup_continuous_boosts():
		var events = []
		for boost_card in continuous_boosts:
			if boost_card.id in cleanup_boost_to_gauge_cards:
				events += add_to_gauge(boost_card)
			else:
				events += add_to_discards(boost_card)
		continuous_boosts = []
		cleanup_boost_to_gauge_cards = []
		return events

	func force_opponent_respond_wild_swing() -> bool:
		for boost_card in continuous_boosts:
			for effect in boost_card.definition['boost']['effects']:
				if effect['effect_type'] == "opponent_wild_swings":
					return true
		return false

	func get_character_effects_at_timing(timing_name : String):
		var effects = []
		var ability_label = "ability_effects"
		if exceeded:
			ability_label = "exceed_ability_effects"

		for effect in deck_def[ability_label]:
			if effect['timing'] == timing_name:
				effects.append(effect)
		return effects

var player : Player
var opponent : Player

var active_turn_player : Enums.PlayerId
var next_turn_player : Enums.PlayerId

func initialize_game(player_deck, opponent_deck):
	card_db = CardDatabase.new()
	player = Player.new(Enums.PlayerId.PlayerId_Player, "Player", self, card_db, player_deck, 100)
	opponent = Player.new(Enums.PlayerId.PlayerId_Opponent, "Opponent", self, card_db, opponent_deck, 200)

	active_turn_player = Enums.PlayerId.PlayerId_Player
	player.arena_location = 3
	next_turn_player = Enums.PlayerId.PlayerId_Opponent
	opponent.arena_location = 7

func draw_starting_hands_and_begin():
	var events = []
	events += player.draw(StartingHandFirstPlayer)
	events += opponent.draw(StartingHandSecondPlayer)
	change_game_state(Enums.GameState.GameState_Mulligan)
	events += [create_event(Enums.EventType.EventType_MulliganDecision, player.my_id, 0)]
	event_queue += events
	return true

func _test_add_to_gauge(amount: int):
	var events = []
	for i in range(amount):
		events += player.draw(1)
		var card = player.hand[0]
		player.remove_card_from_hand(card.id)
		events += player.add_to_gauge(card)
	event_queue += events
	return true

func get_card_database() -> CardDatabase:
	return card_db

func get_player_name(player_id : Enums.PlayerId) -> String:
	if player_id == Enums.PlayerId.PlayerId_Player:
		return player.name
	return opponent.name

func _get_player(player_id : Enums.PlayerId) -> Player:
	if player_id == Enums.PlayerId.PlayerId_Player:
		return player
	return opponent

func get_other_player(test_player : Enums.PlayerId) -> Enums.PlayerId:
	if test_player == Enums.PlayerId.PlayerId_Player:
		return Enums.PlayerId.PlayerId_Opponent
	return Enums.PlayerId.PlayerId_Player


func advance_to_next_turn():
	var events = []
	player.canceled_this_turn = false
	opponent.canceled_this_turn = false

	active_turn_player = next_turn_player
	next_turn_player = get_other_player(active_turn_player)

	# Iterate in reverse as items can be removed.
	var starting_turn_player = _get_player(active_turn_player)
	for i in range(len(starting_turn_player.continuous_boosts) - 1, -1, -1):
		var card = starting_turn_player.continuous_boosts[i]
		for effect in card.definition['boost']['effects']:
			if effect['timing'] == "start_of_next_turn":
				if effect['effect_type'] == 'add_to_gauge_immediately':
					events += starting_turn_player.remove_from_continuous_boosts(card, true)

	if game_over:
		change_game_state(Enums.GameState.GameState_GameOver)
	else:
		change_game_state(Enums.GameState.GameState_PickAction)
		events += [create_event(Enums.EventType.EventType_AdvanceTurn, active_turn_player, 0)]
	return events

func begin_resolve_strike():
	var events = []
	# Strike is just beginning.
	events += [create_event(Enums.EventType.EventType_Strike_Reveal, active_strike.initiator.my_id, 0)]

	active_strike.initiator.strike_stat_boosts.clear()
	active_strike.defender.strike_stat_boosts.clear()

	# Handle EX
	if active_strike.initiator_ex_card != null:
		active_strike.initiator.strike_stat_boosts.set_ex()
	if active_strike.defender_ex_card != null:
		active_strike.defender.strike_stat_boosts.set_ex()

	# Begin initial state
	active_strike.strike_state = StrikeState.StrikeState_Initiator_PayCosts
	active_strike.effects_resolved_in_timing = 0

	events += continue_resolve_strike()
	return events

func strike_determine_order():
	# Determine activation
	var initiator_speed = active_strike.initiator_card.definition['speed'] + active_strike.initiator.strike_stat_boosts.speed
	var defender_speed = active_strike.defender_card.definition['speed'] + active_strike.defender.strike_stat_boosts.speed
	active_strike.initiator_first = initiator_speed >= defender_speed

func is_effect_condition_met(performing_player : Player, effect, local_conditions : LocalStrikeConditions):
	var other_player = _get_player(get_other_player(performing_player.my_id))
	if "condition" in effect:
		var condition = effect['condition']
		if condition == "initiated_strike":
			var initiated_strike = active_strike.initiator == performing_player
			return initiated_strike
		elif condition == "not_initiated_strike":
			var initiated_strike = active_strike.initiator == performing_player
			return not initiated_strike
		elif condition == "canceled_this_turn":
			return performing_player.canceled_this_turn
		elif condition == "not_canceled_this_turn":
			return not performing_player.canceled_this_turn
		elif condition == "not_full_close" and not local_conditions.fully_closed:
			return true
		elif condition == "advanced_through" and local_conditions.advanced_through:
			return true
		elif condition == "not_advanced_through" and not local_conditions.advanced_through:
			return true
		elif condition == "not_full_push" and not local_conditions.fully_pushed:
			return true
		elif condition == "pulled_past" and local_conditions.pulled_past:
			return true
		elif condition == "opponent_stunned":
			return active_strike.is_player_stunned(other_player)
		elif condition == "range":
			var amount = effect['condition_amount']
			var distance = abs(performing_player.arena_location - other_player.arena_location)
			return amount == distance
		# Unmet condition
		return false
	return true

class LocalStrikeConditions:
	var fully_closed : bool = false
	var fully_retreated : bool = false
	var fully_pushed : bool = false
	var advanced_through : bool = false
	var pulled_past : bool = false

func handle_strike_effect(card_id :int, effect, performing_player : Player):
	printlog("STRIKE: Handling effect %s" % [effect])
	var events = []
	var local_conditions = LocalStrikeConditions.new()
	var performing_start = performing_player.arena_location
	var opposing_player : Player = _get_player(get_other_player(performing_player.my_id))
	var other_start = opposing_player.arena_location
	match effect['effect_type']:
		"add_boost_to_gauge_on_strike_cleanup":
			if card_id == -1:
				assert(false)
				printlog("ERROR: Unimplemented path to add_boost_to_gauge_on_strike_cleanup")
			performing_player.add_boost_to_gauge_on_strike_cleanup(card_id)
		"add_strike_to_gauge_after_cleanup":
			performing_player.strike_stat_boosts.always_add_to_gauge = true
		"add_to_gauge_boost_play_cleanup":
			active_boost.cleanup_to_gauge_card_ids.append(card_id)
		"advance":
			events += performing_player.advance(effect['amount'])
			var new_location = performing_player.arena_location
			if (performing_start < other_start and new_location > other_start) or (performing_start > other_start and new_location < other_start):
				local_conditions.advanced_through = true
		"armorup":
			performing_player.strike_stat_boosts.armor += effect['amount']
			events += [create_event(Enums.EventType.EventType_Strike_ArmorUp, performing_player.my_id, effect['amount'])]
		"attack_is_ex":
			performing_player.strike_stat_boosts.set_ex()
			events += [create_event(Enums.EventType.EventType_Strike_ExUp, performing_player.my_id, card_id)]
		"bonus_action":
			active_boost.action_after_boost = true
		"choice":
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.type = Enums.DecisionType.DecisionType_EffectChoice
			decision_info.player = performing_player.my_id
			decision_info.choice = effect['choice']
			decision_info.choice_card_id = card_id
			events += [create_event(Enums.EventType.EventType_Strike_EffectChoice, performing_player.my_id, 0)]
		"close":
			events += performing_player.close(effect['amount'])
			var new_location = performing_player.arena_location
			var close_amount = abs(performing_start - new_location)
			local_conditions.fully_closed = close_amount == effect['amount']
		"dodge_attacks":
			performing_player.strike_stat_boosts.dodge_attacks = true
			events += [create_event(Enums.EventType.EventType_Strike_DodgeAttacks, performing_player.my_id, 0)]
		"draw":
			events += performing_player.draw(effect['amount'])
		"discard_continuous_boost":
			var boosts = _get_player(get_other_player(performing_player.my_id)).continuous_boosts
			if len(boosts) > 0:
				# Player gets to pick which continuous boost to discard.
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.type = Enums.DecisionType.DecisionType_ChooseDiscardContinuousBoost
				decision_info.effect_type = "discard_continuous_boost_INTERNAL"
				decision_info.choice_card_id = card_id
				decision_info.player = performing_player.my_id
				events += [create_event(Enums.EventType.EventType_Boost_DiscardContinuousChoice, performing_player.my_id, 1)]
		"discard_continuous_boost_INTERNAL":
			var boost_to_discard_id = effect['card_id']
			var card = card_db.get_card(boost_to_discard_id)
			events += _get_player(get_other_player(performing_player.my_id)).remove_from_continuous_boosts(card, false)
		"gain_advantage":
			next_turn_player = performing_player.my_id
			events += [create_event(Enums.EventType.EventType_Strike_GainAdvantage, performing_player.my_id, 0)]
		"gauge_from_hand":
			if len(performing_player.hand) > 0:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.type = Enums.DecisionType.DecisionType_CardFromHandToGauge
				decision_info.player = performing_player.my_id
				decision_info.choice_card_id = card_id
				events += [create_event(Enums.EventType.EventType_CardFromHandToGauge_Choice, performing_player.my_id, 1)]
		"guardup":
			performing_player.strike_stat_boosts.guard += effect['amount']
			events += [create_event(Enums.EventType.EventType_Strike_GuardUp, performing_player.my_id, effect['amount'])]
		"ignore_armor":
			performing_player.strike_stat_boosts.ignore_armor = true
		"ignore_guard":
			performing_player.strike_stat_boosts.ignore_guard = true
		"ignore_push_and_pull":
			performing_player.strike_stat_boosts.ignore_push_and_pull = true
		"name_card_opponent_discards":
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.type = Enums.DecisionType.DecisionType_NameCard_OpponentDiscards
			decision_info.effect_type = "name_card_opponent_discards_internal"
			decision_info.choice_card_id = card_id
			decision_info.player = performing_player.my_id
			events += [create_event(Enums.EventType.EventType_Boost_NameCardOpponentDiscards, performing_player.my_id, 1)]
		"name_card_opponent_discards_internal":
			var named_card = card_db.get_card(effect['card_id'])
			# named_card is the individual card but
			# this should discard "by name", so instead of using that
			# match card.definition['id']'s instead.
			events += opposing_player.discard_matching_or_reveal(named_card.definition['id'])
		"opponent_discard_random":
			events += opposing_player.discard_random(effect['amount'])
		"pass":
			# Do nothing.
			pass
		"powerup":
			performing_player.strike_stat_boosts.power += effect['amount']
			events += [create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, effect['amount'])]
		"pull":
			events += performing_player.pull(effect['amount'])
			var new_location = opposing_player.arena_location
			if (other_start < performing_start and new_location > performing_start) or (other_start > performing_start and new_location < performing_start):
				local_conditions.pulled_past = true
		"push":
			events += performing_player.push(effect['amount'])
			var new_location = opposing_player.arena_location
			var push_amount = abs(other_start - new_location)
			local_conditions.fully_pushed = push_amount == effect['amount']
		"rangeup":
			performing_player.strike_stat_boosts.min_range += effect['amount']
			performing_player.strike_stat_boosts.max_range += effect['amount2']
			events += [create_event(Enums.EventType.EventType_Strike_RangeUp, performing_player.my_id, effect['amount'], "", effect['amount2'])]
		"retreat":
			events += performing_player.retreat(effect['amount'])
			var new_location = performing_player.arena_location
			var retreat_amount = abs(performing_start - new_location)
			local_conditions.fully_retreated = retreat_amount == effect['amount']
		"speedup":
			performing_player.strike_stat_boosts.speed += effect['amount']
			events += [create_event(Enums.EventType.EventType_Strike_SpeedUp, performing_player.my_id, effect['amount'])]
		"when_hit_force_for_armor":
			performing_player.strike_stat_boosts.when_hit_force_for_armor = true

	if not game_state == Enums.GameState.GameState_PlayerDecision and "and" in effect:
		var and_effect = effect['and']
		if is_effect_condition_met(performing_player, and_effect, local_conditions):
			events += handle_strike_effect(card_id, and_effect, performing_player)

	if not game_state == Enums.GameState.GameState_PlayerDecision and "bonus_effect" in effect:
		var bonus_effect = effect['bonus_effect']
		if is_effect_condition_met(performing_player, bonus_effect, local_conditions):
			events += handle_strike_effect(card_id, bonus_effect, performing_player)

	return events

func get_boost_effects_at_timing(timing_name : String, performing_player : Player):
	var effects = []
	for boost_card in performing_player.continuous_boosts:
		for effect in boost_card.definition['boost']['effects']:
			if effect['timing'] == timing_name:
				effects.append(effect)
	return effects

func get_boost_card_ids_for_effects_at_timing(timing_name : String, performing_player : Player):
	var card_ids = []
	for boost_card in performing_player.continuous_boosts:
		for effect in boost_card.definition['boost']['effects']:
			if effect['timing'] == timing_name:
				card_ids.append(boost_card.id)
	return card_ids

func do_effects_for_timing(timing_name : String, performing_player : Player, card : GameCard, next_state):
	var events = []
	var effects = card_db.get_card_effects_at_timing(card, timing_name)
	var boost_effects = get_boost_effects_at_timing(timing_name, performing_player)
	var boost_card_ids = get_boost_card_ids_for_effects_at_timing(timing_name, performing_player)
	var character_effects = performing_player.get_character_effects_at_timing(timing_name)
	# Effects are resolved in the order:
	# Card > Continuous Boost > Character
	while true:
		var boost_effects_resolved = active_strike.effects_resolved_in_timing - len(effects)
		var character_effects_resolved = boost_effects_resolved - len(boost_effects)
		if active_strike.effects_resolved_in_timing < len(effects):
			# Resolve card effects
			var effect = effects[active_strike.effects_resolved_in_timing]
			if is_effect_condition_met(performing_player, effect, null):
				events += handle_strike_effect(card.id, effect, performing_player)
			if game_state == Enums.GameState.GameState_PlayerDecision:
				# Player has a decision to make, so stop mid-effect resolve.
				break

			# Effect was resolved, continue loop to resolve more.
			active_strike.effects_resolved_in_timing += 1
		elif boost_effects_resolved < len(boost_effects):
			# Resolve boost effects
			var effect = boost_effects[boost_effects_resolved]
			var boost_card_id = boost_card_ids[boost_effects_resolved]
			if is_effect_condition_met(performing_player, effect, null):
				events += handle_strike_effect(boost_card_id, effect, performing_player)
			if game_state == Enums.GameState.GameState_PlayerDecision:
				# Player has a decision to make, so stop mid-effect resolve.
				break

			# Effect was resolved, continue loop to resolve more.
			active_strike.effects_resolved_in_timing += 1
		elif character_effects_resolved < len(character_effects):
			# Resolve character effects
			var effect = character_effects[character_effects_resolved]
			if is_effect_condition_met(performing_player, effect, null):
				events += handle_strike_effect(card.id, effect, performing_player)
			if game_state == Enums.GameState.GameState_PlayerDecision:
				# Player has a decision to make, so stop mid-effect resolve.
				break

			# Effect was resolved, continue loop to resolve more.
			active_strike.effects_resolved_in_timing += 1
		else:
			# Cleanup
			active_strike.strike_state = next_state
			active_strike.effects_resolved_in_timing = 0
			break

	return events

func in_range(atacking_player, defending_player, card):
	if defending_player.strike_stat_boosts.dodge_attacks:
		return false
	var min_range = card.definition['range_min'] + atacking_player.strike_stat_boosts.min_range
	var max_range = card.definition['range_max'] + atacking_player.strike_stat_boosts.max_range
	var distance = abs(atacking_player.arena_location - defending_player.arena_location)
	if min_range <= distance and distance <= max_range:
		return true
	return false

func apply_damage(offense_player : Player, defense_player : Player, offense_card : GameCard, defense_card : GameCard):
	var events = []
	var damage = offense_card.definition['power'] + offense_player.strike_stat_boosts.power
	var armor = defense_card.definition['armor'] + defense_player.strike_stat_boosts.armor
	var guard = defense_card.definition['guard'] + defense_player.strike_stat_boosts.guard

	if offense_player.strike_stat_boosts.ignore_guard:
		guard = 0
	if offense_player.strike_stat_boosts.ignore_armor:
		armor = 0

	var damage_after_armor = max(damage - armor, 0)
	defense_player.life -= damage_after_armor
	events += [create_event(Enums.EventType.EventType_Strike_TookDamage, defense_player.my_id, damage_after_armor)]
	if damage_after_armor > guard:
		events += [create_event(Enums.EventType.EventType_Strike_Stun, defense_player.my_id, defense_card.id)]
		active_strike.set_player_stunned(defense_player)

	if defense_player.life <= 0:
		events += [create_event(Enums.EventType.EventType_GameOver, defense_player.my_id, 0)]
		game_over = true
	return events

func ask_for_cost(performing_player, card, next_state):
	var events = []
	var gauge_cost = card.definition['gauge_cost']
	var force_cost = card.definition['force_cost']
	if gauge_cost == 0 and force_cost == 0:
		active_strike.strike_state = next_state
	else:
		if performing_player.can_pay_cost(card):
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.player = performing_player.my_id
			if active_strike.get_player_wild_strike(performing_player):
				decision_info.type = Enums.DecisionType.DecisionType_PayStrikeCost_CanWild
			else:
				decision_info.type = Enums.DecisionType.DecisionType_PayStrikeCost_Required

			if gauge_cost > 0:
				events += [create_event(Enums.EventType.EventType_Strike_PayCost_Gauge, performing_player.my_id, card.id)]
			elif force_cost > 0:
				events += [create_event(Enums.EventType.EventType_Strike_PayCost_Force, performing_player.my_id, card.id)]
		else:
			# Failed to pay the cost by default.
			events += performing_player.add_to_discards(card)
			events += performing_player.wild_strike();
			if game_over:
				return events
			var wild_card_id = active_strike.get_player_card(performing_player).id
			events += [create_event(Enums.EventType.EventType_Strike_PayCost_Unable, performing_player.my_id, wild_card_id)]
	return events

func do_hit_response_effects(hit_player : Player, next_state : StrikeState):
	# If more of these are added, need to sequence them to ensure all handled correctly.
	var events = []
	active_strike.strike_state = next_state
	if hit_player.strike_stat_boosts.when_hit_force_for_armor:
		change_game_state(Enums.GameState.GameState_PlayerDecision)
		decision_info.player = hit_player.my_id
		decision_info.type = Enums.DecisionType.DecisionType_ForceForArmor
		decision_info.choice_card_id = active_strike.get_player_card(hit_player).id
		events += [create_event(Enums.EventType.EventType_Strike_ForceForArmor, hit_player.my_id, 0)]
	return events

func continue_resolve_strike():
	var events = []
	change_game_state(Enums.GameState.GameState_Strike_Processing)

	while true:
		if game_over:
			change_game_state(Enums.GameState.GameState_GameOver)
			break
		# Cards might change due to paying costs, so get them every loop.
		# Do NOT use before strike_determine_order and the StrikeState_DuringStrikeBonuses state has been called.
		var card1 = active_strike.get_card(1)
		var card2 = active_strike.get_card(2)
		var player1 = active_strike.get_player(1)
		var player2 = active_strike.get_player(2)

		if game_state == Enums.GameState.GameState_PlayerDecision:
			var player_name = get_player_name(decision_info.player)
			printlog("STRIKE: Pausing for decision %s %s" % [player_name, Enums.DecisionType.keys()[decision_info.type]])
			break

		printlog("STRIKE: processing state %s " % [StrikeState.keys()[active_strike.strike_state]])
		match active_strike.strike_state:
			StrikeState.StrikeState_Initiator_PayCosts:
				events += ask_for_cost(active_strike.initiator, active_strike.initiator_card, StrikeState.StrikeState_Defender_PayCosts)
			StrikeState.StrikeState_Defender_PayCosts:
				events += ask_for_cost(active_strike.defender, active_strike.defender_card, StrikeState.StrikeState_DuringStrikeBonuses)
			StrikeState.StrikeState_DuringStrikeBonuses:
				events += do_effects_for_timing("during_strike", active_strike.initiator, active_strike.initiator_card, StrikeState.StrikeState_DuringStrikeBonuses)
				# Should never be interrupted by player decisions.
				events += do_effects_for_timing("during_strike", active_strike.defender, active_strike.defender_card, StrikeState.StrikeState_Card1_Activation)
				strike_determine_order()
			StrikeState.StrikeState_Card1_Activation:
				events += [create_event(Enums.EventType.EventType_Strike_CardActivation, active_strike.get_player(1).my_id, card1.id)]
				active_strike.strike_state = StrikeState.StrikeState_Card1_Before
			StrikeState.StrikeState_Card1_Before:
				events += do_effects_for_timing("before", player1, card1, StrikeState.StrikeState_Card1_DetermineHit)
			StrikeState.StrikeState_Card1_DetermineHit:
				if in_range(player1, player2, card1):
					active_strike.player1_hit = true
					active_strike.strike_state = StrikeState.StrikeState_Card1_Hit
				else:
					events += [create_event(Enums.EventType.EventType_Strike_Miss, player1.my_id, 0)]
					active_strike.strike_state = StrikeState.StrikeState_Card1_After
			StrikeState.StrikeState_Card1_Hit:
				events += do_effects_for_timing("hit", player1, card1, StrikeState.StrikeState_Card1_Hit_Response)
			StrikeState.StrikeState_Card1_Hit_Response:
				events += do_hit_response_effects(player2, StrikeState.StrikeState_Card1_ApplyDamage)
			StrikeState.StrikeState_Card1_ApplyDamage:
				events += apply_damage(player1, player2, card1, card2)
				active_strike.strike_state = StrikeState.StrikeState_Card1_After
				if game_over:
					active_strike.strike_state = StrikeState.StrikeState_Cleanup
			StrikeState.StrikeState_Card1_After:
				events += do_effects_for_timing("after", player1, card1, StrikeState.StrikeState_Card2_Activation)
			StrikeState.StrikeState_Card2_Activation:
				if active_strike.player2_stunned:
					active_strike.strike_state = StrikeState.StrikeState_Cleanup
				else:
					events += [create_event(Enums.EventType.EventType_Strike_CardActivation, active_strike.get_player(2).my_id, card2.id)]
					active_strike.strike_state = StrikeState.StrikeState_Card2_Before
			StrikeState.StrikeState_Card2_Before:
				events += do_effects_for_timing("before", player2, card2, StrikeState.StrikeState_Card2_DetermineHit)
			StrikeState.StrikeState_Card2_DetermineHit:
				if in_range(player2, player1, card2):
					active_strike.player2_hit = true
					active_strike.strike_state = StrikeState.StrikeState_Card2_Hit
				else:
					events += [create_event(Enums.EventType.EventType_Strike_Miss, player2.my_id, 0)]
					active_strike.strike_state = StrikeState.StrikeState_Card2_After
			StrikeState.StrikeState_Card2_Hit:
				events += do_effects_for_timing("hit", player2, card2, StrikeState.StrikeState_Card2_Hit_Response)
			StrikeState.StrikeState_Card2_Hit_Response:
				events += do_hit_response_effects(player1, StrikeState.StrikeState_Card2_ApplyDamage)
			StrikeState.StrikeState_Card2_ApplyDamage:
				events += apply_damage(player2, player1, card2, card1)
				active_strike.strike_state = StrikeState.StrikeState_Card2_After
				if game_over:
					active_strike.strike_state = StrikeState.StrikeState_Cleanup
			StrikeState.StrikeState_Card2_After:
				events += do_effects_for_timing("after", player2, card2, StrikeState.StrikeState_Cleanup)
			StrikeState.StrikeState_Cleanup:
				# If hit, move card to gauge, otherwise move to discard.
				if active_strike.player1_hit or player1.strike_stat_boosts.always_add_to_gauge:
					events += player1.add_to_gauge(card1)
				else:
					events += player1.add_to_discards(card1)

				if active_strike.player2_hit or player2.strike_stat_boosts.always_add_to_gauge:
					events += player2.add_to_gauge(card2)
				else:
					events += player2.add_to_discards(card2)

				# Discard any EX cards
				if active_strike.initiator_ex_card != null:
					events += active_strike.initiator.add_to_discards(active_strike.initiator_ex_card)
				if active_strike.defender_ex_card != null:
					events += active_strike.defender.add_to_discards(active_strike.defender_ex_card)

				# Cleanup any continuous boosts.
				events += player1.cleanup_continuous_boosts()
				events += player2.cleanup_continuous_boosts()

				active_strike = null
				if game_over:
					change_game_state(Enums.GameState.GameState_GameOver)
				else:
					events += advance_to_next_turn()
				break
	return events

func begin_resolve_boost(performing_player : Player, card_id : int):
	var events = []

	active_boost = Boost.new()
	active_boost.playing_player = performing_player
	active_boost.card = card_db.get_card(card_id)
	performing_player.remove_card_from_hand(card_id)
	events += [create_event(Enums.EventType.EventType_Boost_Played, performing_player.my_id, card_id)]

	# Resolve all immediate/now effects
	# If continuous, put it into continous boost tracking.
	events += continue_resolve_boost()
	return events

func continue_resolve_boost():
	var events = []

	change_game_state(Enums.GameState.GameState_Boost_Processing)

	var effects = card_db.get_card_boost_effects_now_immediate(active_boost.card)
	while true:
		if active_boost.effects_resolved < len(effects):
			var effect = effects[active_boost.effects_resolved]
			if is_effect_condition_met(active_boost.playing_player, effect, null):
				events += handle_strike_effect(active_boost.card.id, effect, active_boost.playing_player)

			if game_state == Enums.GameState.GameState_PlayerDecision:
				break

			active_boost.effects_resolved += 1
		else:
			# After all effects are resolved, check for cancel.
			if active_boost.effects_resolved == len(effects) and active_boost.playing_player.can_cancel(active_boost.card):
				var cancel_cost = card_db.get_card_cancel_cost(active_boost.card.id)
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.type = Enums.DecisionType.DecisionType_BoostCancel
				decision_info.player = active_boost.playing_player.my_id
				decision_info.choice = cancel_cost
				events += [create_event(Enums.EventType.EventType_Boost_CancelDecision, active_boost.playing_player.my_id, cancel_cost)]
				break
			else:
				events += boost_play_cleanup(active_boost.playing_player)
				break

	return events

func boost_play_cleanup(performing_player : Player):
	var events = []
	# All boost immediate/now effects are done.
	# If continuous, add to player.
	# If immediate, add to discard.
	if active_boost.card.definition['boost']['boost_type'] == "continuous":
		events += performing_player.add_to_continuous_boosts(active_boost.card)
	else:
		if active_boost.card.id in active_boost.cleanup_to_gauge_card_ids:
			events += performing_player.add_to_gauge(active_boost.card)
		else:
			events += performing_player.add_to_discards(active_boost.card)

	if active_boost.action_after_boost:
		events += [create_event(Enums.EventType.EventType_Boost_ActionAfterBoost, performing_player.my_id, 0)]
		change_game_state(Enums.GameState.GameState_PickAction)
	else:
		events += performing_player.draw(1)
		events += check_hand_size_advance_turn(performing_player)
	active_boost = null
	return events

func can_do_prepare(performing_player : Player):
	if game_state != Enums.GameState.GameState_PickAction:
		return false
	if active_turn_player != performing_player.my_id:
		return false
	return true

func can_do_move(performing_player : Player):
	if game_state != Enums.GameState.GameState_PickAction:
		return false
	if active_turn_player != performing_player.my_id:
		return false

	# Check if the player can generate force (2 if cornered)
	var force_needed = 1
	var player_location = performing_player.arena_location
	var other_player_location = _get_player(get_other_player(performing_player.my_id)).arena_location
	if ((player_location == 1 and other_player_location == 2)
		or (player_location == 9 and other_player_location == 8)):
		force_needed = 2
		pass

	var force_available = performing_player.get_available_force()
	if force_available >= force_needed:
		return true
	return false

func can_do_change(performing_player : Player):
	if game_state != Enums.GameState.GameState_PickAction:
		return false
	if active_turn_player != performing_player.my_id:
		return false

	var force_available = performing_player.get_available_force()
	return force_available > 0

func can_do_exceed(performing_player : Player):
	if game_state != Enums.GameState.GameState_PickAction:
		return false
	if active_turn_player != performing_player.my_id:
		return false
	if performing_player.exceeded:
		return false

	var gauge_available = len(performing_player.gauge)
	return gauge_available >= performing_player.exceed_cost

func can_do_reshuffle(performing_player : Player):
	if game_state != Enums.GameState.GameState_PickAction:
		return false
	if active_turn_player != performing_player.my_id:
		return false
	if len(performing_player.discards) == 0:
		return false
	return performing_player.reshuffle_remaining > 0

func can_do_boost(performing_player : Player):
	if game_state != Enums.GameState.GameState_PickAction:
		return false
	if active_turn_player != performing_player.my_id:
		return false

	var force_available = performing_player.get_available_force()
	for card in performing_player.hand:
		if card.definition['boost']['force_cost'] <= force_available:
			return true

	return false

func can_do_strike(performing_player : Player):
	if game_state != Enums.GameState.GameState_WaitForStrike and decision_info.player == performing_player.my_id:
		return true
	if game_state != Enums.GameState.GameState_PickAction:
		return false
	if active_turn_player != performing_player.my_id:
		return false

	# Can always wild swing!

	return true

func check_hand_size_advance_turn(performing_player : Player):
	var events = []
	if len(performing_player.hand) > MaxHandSize:
		change_game_state(Enums.GameState.GameState_DiscardDownToMax)
		events += [create_event(Enums.EventType.EventType_HandSizeExceeded, performing_player.my_id, len(performing_player.hand) - MaxHandSize)]
	else:
		events += advance_to_next_turn()
	return events

func do_prepare(performing_player) -> bool:
	printlog("MainAction: PREPARE by %s" % [performing_player.name])
	if not can_do_prepare(performing_player):
		printlog("ERROR: Tried to Prepare but can't.")
		return false

	var events : Array = []
	events += [create_event(Enums.EventType.EventType_Prepare, performing_player.my_id, 0)]
	events += performing_player.draw(2)
	events += check_hand_size_advance_turn(performing_player)
	event_queue += events
	return true

func do_discard_to_max(performing_player : Player, card_ids) -> bool:
	printlog("SubAction: DISCARD_TO_MAX by %s - %s" % [get_player_name(performing_player.my_id), card_ids])
	if performing_player.my_id != active_turn_player:
		printlog("ERROR: Tried to discard for wrong player.")
		return false
	if game_state != Enums.GameState.GameState_DiscardDownToMax:
		printlog("ERROR: Tried to discard wrong game state.")
		return false

	for id in card_ids:
		if not performing_player.is_card_in_hand(id):
			# Card not found, error
			printlog("ERROR: Tried to discard cards that aren't in hand.")
			return false

	if len(performing_player.hand) - len(card_ids) > MaxHandSize:
		printlog("ERROR: Not discarding enough cards")
		return false

	var events = performing_player.discard(card_ids)
	events += advance_to_next_turn()

	event_queue += events
	return true

func do_reshuffle(performing_player : Player) -> bool:
	printlog("MainAction: RESHUFFLE by %s" % [performing_player.name])
	if not can_do_reshuffle(performing_player):
		printlog("ERROR: Tried to reshuffle but can't.")
		return false

	var events = performing_player.reshuffle_discard()
	events += performing_player.draw(1)
	events += check_hand_size_advance_turn(performing_player)
	event_queue += events
	return true

func do_move(performing_player : Player, card_ids, new_arena_location) -> bool:
	printlog("MainAction: MOVE by %s to %s" % [performing_player.name, str(new_arena_location)])
	if not can_do_move(performing_player):
		printlog("ERROR: Cannot perform the move action for this player.")
		return false

	if not performing_player.can_move_to(new_arena_location):
		printlog("ERROR: Unable to move to that arena location.")
		return false

	# Ensure cards are in hand/gauge
	for id in card_ids:
		if not performing_player.is_card_in_hand(id) and not performing_player.is_card_in_gauge(id):
			# Card not found, error
			printlog("ERROR: Tried to discard cards that aren't in hand/gauge.")
			return false

	# Ensure cards generate enough force.
	var required_force = performing_player.get_force_to_move_to(new_arena_location)
	var generated_force = 0
	for id in card_ids:
		generated_force += card_db.get_card_force_value(id)

	if generated_force < required_force:
		printlog("ERROR: Not enough force with these cards to move there.")
		return false

	var events = performing_player.discard(card_ids)
	events += performing_player.move_to(new_arena_location)
	events += performing_player.draw(1)
	events += check_hand_size_advance_turn(performing_player)
	event_queue += events
	return true

func do_change(performing_player : Player, card_ids) -> bool:
	printlog("MainAction: CHANGE_CARDS by %s - %s" % [performing_player.name, card_ids])
	if not can_do_change(performing_player):
		printlog("ERROR: Cannot do change action for this player.")
		return false

	for id in card_ids:
		if not performing_player.is_card_in_hand(id) and not performing_player.is_card_in_gauge(id):
			# Card not found, error
			printlog("ERROR: Tried to discard cards that aren't in hand or gauge.")
			return false

	var events = []
	events += [create_event(Enums.EventType.EventType_ChangeCards, performing_player.my_id, 0)]
	events += performing_player.discard(card_ids)
	var force_generated = 0
	for id in card_ids:
		force_generated += card_db.get_card_force_value(id)
	events += performing_player.draw(force_generated + 1)
	events += check_hand_size_advance_turn(performing_player)

	event_queue += events
	return true

func do_exceed(performing_player : Player, card_ids : Array) -> bool:
	printlog("MainAction: EXCEED by %s - %s" % [performing_player.name, card_ids])
	if game_state != Enums.GameState.GameState_PickAction:
		printlog("ERROR: Tried to exceed but not in correct game state.")
		return false
	if performing_player.my_id != active_turn_player:
		printlog("ERROR: Tried to exceed for wrong player.")
		return false
	for id in card_ids:
		if not performing_player.is_card_in_gauge(id):
			# Card not found, error
			printlog("ERROR: Tried to exced with cards that not in gauge.")
			return false
	if len(card_ids) < performing_player.exceed_cost:
		printlog("ERROR: Tried to exceed with too few cards.")
		return false

	var events = performing_player.discard(card_ids)
	events += performing_player.exceed()
	if game_state != Enums.GameState.GameState_WaitForStrike:
		events += performing_player.draw(1)
		events += check_hand_size_advance_turn(performing_player)
	event_queue += events
	return true

func do_boost(performing_player : Player, card_id : int) -> bool:
	printlog("MainAction: BOOST by %s - %s" % [get_player_name(performing_player.my_id), card_db.get_card_name(card_id)])
	if game_state != Enums.GameState.GameState_PickAction or performing_player.my_id != active_turn_player:
		printlog("ERROR: Tried to boost but not your turn")
		return false

	var events = []
	events += begin_resolve_boost(performing_player, card_id)
	event_queue += events
	return true

func do_strike(performing_player : Player, card_id : int, wild_strike: bool, ex_card_id : int) -> bool:
	printlog("MainAction: STRIKE by %s card %s wild %s" % [get_player_name(performing_player.my_id), card_db.get_card_name(card_id), str(wild_strike)])
	if game_state == Enums.GameState.GameState_PickAction:
		if performing_player.my_id != active_turn_player:
			printlog("ERROR: Tried to strike but not current player")
			return false
	elif game_state == Enums.GameState.GameState_Strike_Opponent_Response:
		if performing_player.my_id != get_other_player(active_turn_player):
			printlog("ERROR: Strike response from wrong player.")
			return false
	elif game_state == Enums.GameState.GameState_WaitForStrike:
		if performing_player.my_id != decision_info.player:
			printlog("ERROR: Strike response from wrong player.")
			return false

	if not wild_strike and not performing_player.is_card_in_hand(card_id):
		printlog("ERROR: Tried to strike with a card not in hand.")
		return false
	if ex_card_id != -1 and not performing_player.is_card_in_hand(ex_card_id):
		printlog("ERROR: Tried to strike with a ex card not in hand.")
		return false
	if ex_card_id != -1 and not card_db.are_same_card(card_id, ex_card_id):
		printlog("ERROR: Tried to strike with a ex card that doesn't match.")
		return false

	# Begin the strike
	var events = []

	# Lay down the strike
	match game_state:
		Enums.GameState.GameState_PickAction, Enums.GameState.GameState_WaitForStrike:
			active_strike = Strike.new()
			active_strike.initiator = performing_player
			if wild_strike:
				events += performing_player.wild_strike()
				if game_over:
					event_queue += events
					return true
				card_id = active_strike.initiator_card.id
			else:
				active_strike.initiator_card = card_db.get_card(card_id)
				performing_player.remove_card_from_hand(card_id)
				if ex_card_id != -1:
					active_strike.initiator_ex_card = card_db.get_card(ex_card_id)
					performing_player.remove_card_from_hand(ex_card_id)
			active_strike.defender = _get_player(get_other_player(performing_player.my_id))
			# Send the EX first as that is visual and logic is triggered off the regular one.
			if ex_card_id != -1:
				events += [create_event(Enums.EventType.EventType_Strike_Started_Ex, performing_player.my_id, ex_card_id)]
			events += [create_event(Enums.EventType.EventType_Strike_Started, performing_player.my_id, card_id)]
			change_game_state(Enums.GameState.GameState_Strike_Opponent_Response)
			if performing_player.force_opponent_respond_wild_swing():
				events += [create_event(Enums.EventType.EventType_Strike_ForceWildSwing, performing_player.my_id, 0)]
				# Queue any events so far, then empty this tally and call do_strike.
				event_queue += events
				events = []
				do_strike(_get_player(get_other_player(performing_player.my_id)), -1, true, -1)
		Enums.GameState.GameState_Strike_Opponent_Response:
			if wild_strike:
				events += performing_player.wild_strike()
				if game_over:
					event_queue += events
					return true
				card_id = active_strike.defender_card.id
			else:
				active_strike.defender_card = card_db.get_card(card_id)
				performing_player.remove_card_from_hand(card_id)
				if ex_card_id != -1:
					active_strike.defender_ex_card = card_db.get_card(ex_card_id)
					performing_player.remove_card_from_hand(ex_card_id)
			# Send the EX first as that is visual and logic is triggered off the regular one.
			if ex_card_id != -1:
				events += [create_event(Enums.EventType.EventType_Strike_Response_Ex, performing_player.my_id, ex_card_id)]
			events += [create_event(Enums.EventType.EventType_Strike_Response, performing_player.my_id, card_id)]

			events += begin_resolve_strike()
	event_queue += events
	return true

func do_pay_strike_cost(performing_player : Player, card_ids : Array, wild_strike : bool) -> bool:
	printlog("SubAction: PAY_STRIKE by %s cards %s wild %s" % [performing_player.name, card_ids, str(wild_strike)])
	if game_state != Enums.GameState.GameState_PlayerDecision:
		printlog("ERROR: Tried to pay costs but not in decision state.")
		return false
	if decision_info.type != Enums.DecisionType.DecisionType_PayStrikeCost_CanWild and decision_info.type != Enums.DecisionType.DecisionType_PayStrikeCost_Required:
		printlog("ERROR: Tried to pay costs but not in correct decision type.")
		return false
	if decision_info.type == Enums.DecisionType.DecisionType_PayStrikeCost_Required and wild_strike:
		# Only allowed if you can't pay the cost.
		var card = active_strike.get_player_card(performing_player)
		if performing_player.can_pay_cost(card):
			printlog("ERROR: Tried to wild strike when not allowed.")
			return false
	if decision_info.player != performing_player.my_id:
		printlog("ERROR: Tried to pay costs for wrong player.")
		return false

	var events = []
	if wild_strike:
		# Replace existing card with a wild strike
		var current_card = active_strike.get_player_card(performing_player)
		events += performing_player.add_to_discards(current_card)
		events += performing_player.wild_strike()
	else:
		var card = active_strike.get_player_card(performing_player)
		if performing_player.can_pay_cost_with(card_ids, card):
			events += performing_player.discard(card_ids)
			match active_strike.strike_state:
				StrikeState.StrikeState_Initiator_PayCosts:
					active_strike.strike_state = StrikeState.StrikeState_Defender_PayCosts
				StrikeState.StrikeState_Defender_PayCosts:
					active_strike.strike_state = StrikeState.StrikeState_DuringStrikeBonuses
		else:
			printlog("ERROR: Tried to pay costs but not correct cards.")
			return false
	events += continue_resolve_strike()
	event_queue += events
	return true

func do_force_for_armor(performing_player : Player, card_ids : Array) -> bool:
	printlog("SubAction: FORCEARMOR by %s cards %s" % [performing_player.name, card_ids])
	if game_state != Enums.GameState.GameState_PlayerDecision or decision_info.type != Enums.DecisionType.DecisionType_ForceForArmor:
		printlog("ERROR: Tried to force for armor but not in decision state.")
		return false
	if decision_info.player != performing_player.my_id:
		printlog("ERROR: Tried to force for armor for wrong player.")
		return false

	var events = []
	for card_id in card_ids:
		if not performing_player.is_card_in_hand(card_id) and not performing_player.is_card_in_gauge(card_id):
			printlog("ERROR: Tried to force for armor with card not in hand or gauge.")
			return false

	var force_generated = 0
	for card_id in card_ids:
		force_generated += card_db.get_card_force_value(card_id)
	if force_generated > 0:
		events += performing_player.discard(card_ids)
		events += handle_strike_effect(decision_info.choice_card_id, {'effect_type': 'armorup', 'amount': force_generated * 2}, performing_player)
	events += continue_resolve_strike()
	event_queue += events
	return true

func do_boost_cancel(performing_player : Player, gauge_card_ids : Array, doing_cancel : bool) -> bool:
	printlog("SubAction: BOOST_CANCEL by %s cards %s cancel %s" % [performing_player.name, gauge_card_ids, str(doing_cancel)])
	if game_state != Enums.GameState.GameState_PlayerDecision or decision_info.type != Enums.DecisionType.DecisionType_BoostCancel:
		printlog("ERROR: Tried to cancel boost but not in decision state.")
		return false
	if decision_info.player != performing_player.my_id:
		printlog("ERROR: Tried to boost cancel wrong player.")
		return false
	if not active_boost:
		printlog("ERROR: Tried to cancel boost but no active boost.")
		return false
	if doing_cancel and len(gauge_card_ids) < card_db.get_card_cancel_cost(active_boost.card.id):
		printlog("ERROR: Tried to cancel boost with too few cards.")
		return false
	for id in gauge_card_ids:
		if not performing_player.is_card_in_gauge(id):
			# Card not found, error
			printlog("ERROR: Tried to cancel boost with cards that aren't in gauge.")
			return false

	change_game_state(Enums.GameState.GameState_Boost_Processing)

	var events = []
	if doing_cancel:
		events += performing_player.discard(gauge_card_ids)
		events += performing_player.on_cancel_boost()
		active_boost.action_after_boost = true

	# Ky, for example, has a choice after canceling the first time.
	if game_state != Enums.GameState.GameState_PlayerDecision:
		events += boost_play_cleanup(performing_player)

	event_queue += events
	return true

func do_card_from_hand_to_gauge(performing_player : Player, card_id : int) -> bool:
	printlog("SubAction: CARD_HAND_TO_GAUGE by %s card %s" % [get_player_name(performing_player.my_id), card_db.get_card_name(card_id)])
	if decision_info.player != performing_player.my_id:
		printlog("ERROR: Tried to do_card_from_hand_to_gauge for wrong player.")
		return false
	if game_state != Enums.GameState.GameState_PlayerDecision or decision_info.type != Enums.DecisionType.DecisionType_CardFromHandToGauge:
		printlog("ERROR: Tried to do_card_from_hand_to_gauge but not in decision state.")
		return false
	if not performing_player.is_card_in_hand(card_id):
		printlog("ERROR: Tried to do_card_from_hand_to_gauge with card not in hand.")
		return false
	var events = []

	events += performing_player.move_card_from_hand_to_gauge(card_id)
	active_boost.effects_resolved += 1
	events += continue_resolve_boost()

	event_queue += events
	return true

func do_boost_name_card_choice_effect(performing_player : Player, card_id : int) -> bool:
	printlog("SubAction: BOOST_NAME_CARD by %s card %s" % [get_player_name(performing_player.my_id), card_db.get_card_name(card_id)])
	if decision_info.player != performing_player.my_id:
		printlog("ERROR: Tried to force for armor for wrong player.")
		return false
	if game_state != Enums.GameState.GameState_PlayerDecision:
		printlog("ERROR: Tried to make a choice but not in decision state.")
		return false

	var effect = {
		"effect_type": decision_info.effect_type,
		"card_id": card_id,
	}

	game_state = Enums.GameState.GameState_Boost_Processing
	var events = handle_strike_effect(decision_info.choice_card_id, effect, performing_player)
	active_boost.effects_resolved += 1
	events += continue_resolve_boost()
	event_queue += events
	return true

func do_choice(performing_player : Player, choice_index : int) -> bool:
	printlog("SubAction: CHOICE by %s card %s" % [performing_player.name, str(choice_index)])
	if decision_info.player != performing_player.my_id:
		printlog("ERROR: Tried to force for armor for wrong player.")
		return false
	if game_state != Enums.GameState.GameState_PlayerDecision:
		printlog("ERROR: Tried to make a choice but not in decision state.")
		return false
	if choice_index >= len(decision_info.choice):
		printlog("ERROR: Tried to make a choice that doesn't exist.")
		return false

	var effect = decision_info.choice[choice_index]
	if active_strike:
		game_state = Enums.GameState.GameState_Strike_Processing
	elif active_boost:
		game_state = Enums.GameState.GameState_Boost_Processing

	var events = handle_strike_effect(decision_info.choice_card_id, effect, performing_player)

	if active_strike:
		active_strike.effects_resolved_in_timing += 1
		events += continue_resolve_strike()
	elif active_boost:
		active_boost.effects_resolved += 1
		events += continue_resolve_boost()
	else:
		printlog("ERROR: Tried to make choice but no active strike or boost.")
	event_queue += events
	return true

func do_mulligan(performing_player : Player, card_ids : Array) -> bool:
	printlog("InitialAction: MULLIGAN by %s cards %s" % [performing_player.name, card_ids])
	if performing_player.mulligan_complete:
		printlog("ERROR: Tried to mulligan but already done.")
		return false
	if game_state != Enums.GameState.GameState_Mulligan:
		printlog("ERROR: Tried to mulligan but not in correct game state.")
		return false

	for card_id in card_ids:
		if not performing_player.is_card_in_hand(card_id):
			printlog("ERROR: Tried to mulligan with card not in hand.")
			return false

	var events = []
	events += performing_player.mulligan(card_ids)

	if player.mulligan_complete and opponent.mulligan_complete:
		change_game_state(Enums.GameState.GameState_PickAction)
		events += [create_event(Enums.EventType.EventType_AdvanceTurn, active_turn_player, 0)]
	else:
		events += [create_event(Enums.EventType.EventType_MulliganDecision, get_other_player(performing_player.my_id), 0)]
	event_queue += events
	return true
