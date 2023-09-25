extends Node2D

const StartingHandFirstPlayer = 5
const StartingHandSecondPlayer = 6
const MaxLife = 30
const MaxHandSize = 7
const MaxReshuffle = 1
const WildSwingCardId = 7
const MinArenaLocation = 1
const MaxArenaLocation = 9
const ShuffleEnabled = true

var NextCardId = 1
var all_cards : Array = []
var game_over : bool = false
var active_strike : Strike = null
var decision_player : Player = null
var decision_type : DecisionType
var decision_effect_type
var decision_choice
var decision_choice_card_id : int
var active_boost : Boost = null

enum DecisionType {
	DecisionType_BoostCancel,
	DecisionType_ChooseDiscardContinuousBoost,
	DecisionType_EffectChoice,
	DecisionType_NameCard_OpponentDiscards,
	DecisionType_PayStrikeCost_Required,
	DecisionType_PayStrikeCost_CanWild,
	DecisionType_ForceForArmor,
	DecisionType_CardFromHandToGauge,
}

enum GameState {
	GameState_NotStarted,
	GameState_Boost_Processing,
	GameState_PickAction,
	GameState_DiscardDownToMax,
	GameState_WaitForStrike,
	GameState_PlayerDecision,
	GameState_Strike_Opponent_Response,
	GameState_Strike_Processing,
}
var game_state : GameState = GameState.GameState_NotStarted

func change_game_state(new_state : GameState):
	printlog("game_state update from %s to %s" % [GameState.keys()[game_state], GameState.keys()[new_state]])
	game_state = new_state

enum EventType {
	EventType_AddToGauge,
	EventType_AddToDiscard,
	EventType_AdvanceTurn,
	EventType_Boost_ActionAfterBoost,
	EventType_Boost_CancelDecision,
	EventType_Boost_DiscardContinuousChoice,
	EventType_Boost_Played,
	EventType_Boost_Canceled,
	EventType_Boost_Continuous_Added,
	EventType_Boost_NameCardOpponentDiscards,
	EventType_CardFromHandToGauge_Choice,
	EventType_Discard,
	EventType_Draw,
	EventType_Exceed,
	EventType_ForceStartStrike,
	EventType_GameOver,
	EventType_HandSizeExceeded,
	EventType_Move,
	EventType_ReshuffleDiscard,
	EventType_RevealHand,
	EventType_Strike_ArmorUp,
	EventType_Strike_DodgeAttacks,
	EventType_Strike_EffectChoice,
	EventType_Strike_ExUp,
	EventType_Strike_ForceForArmor,
	EventType_Strike_ForceWildSwing,
	EventType_Strike_GainAdvantage,
	EventType_Strike_GuardUp,
	EventType_Strike_IgnoredPushPull,
	EventType_Strike_Miss,
	EventType_Strike_PayCost_Gauge,
	EventType_Strike_PayCost_Force,
	EventType_Strike_PayCost_Unable,
	EventType_Strike_PowerUp,
	EventType_Strike_Response,
	EventType_Strike_Response_Ex,
	EventType_Strike_Reveal,
	EventType_Strike_Started,
	EventType_Strike_Started_Ex,
	EventType_Strike_Stun,
	EventType_Strike_TookDamage,
	EventType_Strike_WildStrike,
}

func printlog(text):
	print(text)

func create_event(event_type : EventType, event_player : Player, num : int):
	var card_name = get_card_name(num)
	printlog("Event %s %s %d (card=%s)" % [EventType.keys()[event_type], event_player.name, num, card_name])
	return {
		"event_type": event_type,
		"event_player": event_player,
		"number": num,
		"early_exit": event_type == EventType.EventType_GameOver
	}

func should_exit(events):
	return events[len(events) - 1]['early_exit']

enum StrikeState {
	StrikeState_Initiator_PayCosts,
	StrikeState_Defender_PayCosts,
	StrikeState_DuringStrikeBonuses,
	StrikeState_Card1_Before,
	StrikeState_Card1_DetermineHit,
	StrikeState_Card1_Hit,
	StrikeState_Card1_Hit_Response,
	StrikeState_Card1_ApplyDamage,
	StrikeState_Card1_After,
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
	var initiator_card : Card
	var initiator_ex_card : Card = null
	var defender_card : Card
	var defender_ex_card : Card = null
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

	func get_player_card(performing_player : Player) -> Card:
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
	var card : Card
	var effects_resolved = 0
	var action_after_boost = false
	var cancel_resolved = false
	var cleanup_to_gauge_card_ids = []

class Card:
	var id
	var definition
	var image

	func _init(card_id, card_def, card_image):
		id = card_id
		definition = card_def
		image = card_image

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

	var name : String
	var life : int
	var hand : Array[Card]
	var deck : Array[Card]
	var deck_copy : Array[Card]
	var discards : Array[Card]
	var deck_def : Dictionary
	var gauge : Array
	var continuous_boosts : Array[Card]
	var cleanup_boost_to_gauge_cards : Array[int]
	var arena_location : int
	var reshuffle_remaining : int
	var exceeded : bool
	var exceed_cost : int
	var strike_stat_boosts : StrikeStatBoosts
	var canceled_this_turn : bool

	func _init(player_name, parent_ref, chosen_deck, card_start_id):
		name = player_name
		parent = parent_ref
		life = MaxLife
		hand = []
		deck_def = chosen_deck
		exceed_cost = deck_def['character']['exceed_cost']
		deck = []
		deck_copy = []
		strike_stat_boosts = StrikeStatBoosts.new()
		for deck_card_def in deck_def['cards']:
			var card_def = CardDefinitions.get_card(deck_card_def['definition_id'])
			var card = Card.new(card_start_id, card_def, deck_card_def['image'])
			deck.append(card)
			deck_copy.append(card)
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

	func exceed():
		exceeded = true
		var events = []
		events += [parent.create_event(EventType.EventType_Exceed, self, 0)]

		if deck_def['character']['on_exceed'] == "strike":
			events += [parent.create_event(EventType.EventType_ForceStartStrike, self, 0)]
			parent.change_game_state(GameState.GameState_WaitForStrike)
			parent.decision_player = self
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

	func can_pay_cost_with(card_ids : Array, card : Card):
		var gauge_generated = 0
		var force_generated = 0
		for card_id in card_ids:
			if is_card_in_hand(card_id):
				force_generated += parent.get_card_force(card_id)
			elif is_card_in_gauge(card_id):
				force_generated += parent.get_card_force(card_id)
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

	func can_pay_cost(card : Card):
		var available_force = get_available_force()
		var available_gauge = get_available_gauge()
		var gauge_cost = card.definition['gauge_cost']
		var force_cost = card.definition['force_cost']
		if available_gauge < gauge_cost:
			return false
		if available_force < force_cost:
			return false
		return true

	func can_cancel(card : Card):
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
				events += [parent.create_event(EventType.EventType_Draw, self, card.id)]
			else:
				events += reshuffle_discard()
				if not parent.game_over:
					var card = deck[0]
					hand.append(card)
					deck.remove_at(0)
					events += [parent.create_event(EventType.EventType_Draw, self, card.id)]
		return events

	func reshuffle_discard():
		var events : Array = []
		if reshuffle_remaining == 0:
			# Game Over
			events += [parent.create_event(EventType.EventType_GameOver, self, 0)]
			parent.game_over = true
		else:
			# Put discard into deck, shuffle, subtract reshuffles
			deck += discards
			discards = []
			deck.shuffle()
			reshuffle_remaining -= 1
			events += [parent.create_event(EventType.EventType_ReshuffleDiscard, self, reshuffle_remaining)]
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
					events += [parent.create_event(EventType.EventType_Discard, self, card.id)]
					break

			# From gauge
			for i in range(len(gauge)-1, -1, -1):
				var card = gauge[i]
				if card.id == discard_id:
					discards.append(card)
					gauge.remove_at(i)
					events += [parent.create_event(EventType.EventType_Discard, self, card.id)]
					break
		return events

	func discard_matching_or_reveal(card_definition_id : String):
		var events = []
		for card in hand:
			if card.definition['id'] == card_definition_id:
				events = discard([card.id])
				return events
		# Not found
		events += [parent.create_event(EventType.EventType_RevealHand, self, 0)]
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
		var card_id = deck[0].id
		if parent.active_strike.initiator == self:
			parent.active_strike.initiator_card = deck[0]
			parent.active_strike.initiator_wild_strike = true
		else:
			parent.active_strike.defender_card = deck[0]
			parent.active_strike.defender_wild_strike = true
		deck.remove_at(0)
		events += [parent.create_event(EventType.EventType_Strike_WildStrike, self, card_id)]
		return events

	func add_to_gauge(card: Card):
		gauge.append(card)
		return [parent.create_event(EventType.EventType_AddToGauge, self, card.id)]

	func add_to_discards(card : Card):
		discards.append(card)
		return [parent.create_event(EventType.EventType_AddToDiscard, self, card.id)]

	func get_available_force():
		var force = 0
		for card in hand:
			force += parent.get_card_force(card.id)
		for card in gauge:
			force += parent.get_card_force(card.id)
		return force

	func get_available_gauge():
		return len(gauge)

	func can_move_to(new_arena_location):
		if new_arena_location == arena_location: return false
		var other_player_loc = parent.other_player(self).arena_location
		if  other_player_loc == new_arena_location: return false
		var required_force = get_force_to_move_to(new_arena_location)
		return required_force <= get_available_force()

	func get_force_to_move_to(new_arena_location):
		var other_player_loc = parent.other_player(self).arena_location
		var required_force = abs(arena_location - new_arena_location)
		if ((arena_location < other_player_loc and new_arena_location > other_player_loc)
			or (new_arena_location < other_player_loc and arena_location > other_player_loc)):
			# No additional force needed because of abs calculation.
			#required_force += 1
			pass
		return required_force

	func move_to(new_arena_location):
		var events = []
		arena_location = new_arena_location
		events += [parent.create_event(EventType.EventType_Move, self, new_arena_location)]
		return events

	func close(amount):
		var events = []
		var other_location = parent.other_player(self).arena_location
		var new_location
		if arena_location < other_location:
			new_location = min(other_location-1, arena_location+amount)
		else:
			new_location = max(other_location+1, arena_location-amount)
		arena_location = new_location
		events += [parent.create_event(EventType.EventType_Move, self, new_location)]
		return events

	func advance(amount):
		var events = []
		var other_location = parent.other_player(self).arena_location
		var new_location
		if arena_location < other_location:
			new_location = arena_location + amount
			if new_location >= other_location:
				new_location += 1
			new_location = min(new_location, MaxArenaLocation)
		else:
			new_location = arena_location - amount
			if new_location <= other_location:
				new_location -= 1
			new_location = max(new_location, MinArenaLocation)

		arena_location = new_location
		events += [parent.create_event(EventType.EventType_Move, self, new_location)]

		return events

	func retreat(amount):
		var events = []
		var other_location = parent.other_player(self).arena_location
		var new_location
		if arena_location < other_location:
			new_location = arena_location - amount
			new_location = max(new_location, MinArenaLocation)
		else:
			new_location = arena_location + amount
			new_location = min(new_location, MaxArenaLocation)

		arena_location = new_location
		events += [parent.create_event(EventType.EventType_Move, self, new_location)]

		return events

	func push(amount):
		var events = []
		var other_player = parent.other_player(self)
		if other_player.strike_stat_boosts.ignore_push_and_pull:
			events += [parent.create_event(EventType.EventType_Strike_IgnoredPushPull, other_player, 0)]
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
			events += [parent.create_event(EventType.EventType_Move, other_player, new_location)]

		return events

	func pull(amount):
		var events = []
		var other_player = parent.other_player(self)
		if other_player.strike_stat_boosts.ignore_push_and_pull:
			events += [parent.create_event(EventType.EventType_Strike_IgnoredPushPull, other_player, 0)]
		else:
			var other_location = other_player.arena_location
			var new_location
			if arena_location < other_location:
				new_location = other_location - amount
				if arena_location >= new_location:
					new_location -= 1
				new_location = max(new_location, MinArenaLocation)
			else:
				new_location = other_location + amount
				if arena_location <= new_location:
					new_location += 1
				new_location = min(new_location, MaxArenaLocation)

			other_player.arena_location = new_location
			events += [parent.create_event(EventType.EventType_Move, other_player, new_location)]

		return events

	func add_to_continuous_boosts(card : Card):
		var events = []
		continuous_boosts.append(card)
		events += [parent.create_event(EventType.EventType_Boost_Continuous_Added, self, card.id)]
		return events

	func remove_from_continuous_boosts(card : Card, to_gauge : bool):
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
		if not canceled_this_turn:
			canceled_this_turn = true

		events += [parent.create_event(EventType.EventType_Boost_Canceled, self, 0)]

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

		for effect in deck_def['character'][ability_label]:
			if effect['timing'] == timing_name:
				effects.append(effect)
		return effects

var player : Player
var opponent : Player

var active_turn_player : Player
var next_turn_player : Player

func initialize_game(player_deck, opponent_deck):
	player = Player.new("Player", self, player_deck, 100)
	opponent = Player.new("Opponent", self, opponent_deck, 200)

	for card in player.deck:
		all_cards.append(card)
	for card in opponent.deck:
		all_cards.append(card)

	active_turn_player = player
	player.arena_location = 3
	next_turn_player = opponent
	opponent.arena_location = 7

func draw_starting_hands_and_begin():
	player.draw(StartingHandFirstPlayer)
	opponent.draw(StartingHandSecondPlayer)

	change_game_state(GameState.GameState_PickAction)

func get_card(id : int):
	for card in all_cards:
		if card.id == id:
			return card
	return null

func get_card_name(id : int):
	for card in all_cards:
		if card.id == id:
			return card.definition['id']
	return "MISSING CARD"

func are_same_card(id1 : int, id2 : int):
	var card1 = get_card(id1)
	var card2 = get_card(id2)
	return card1.definition['id'] == card2.definition['id']

func get_card_force(id : int):
	var card = get_card(id)
	if card.definition['type'] == 'ultra':
		return 2
	return 1

func get_card_boost_force_cost(id : int):
	var card = get_card(id)
	return card.definition['boost']['force_cost']

func get_card_gauge_cost(id : int):
	var card = get_card(id)
	return card.definition['gauge_cost']

func get_card_cancel_cost(id : int):
	var card = get_card(id)
	return card.definition['boost']['cancel_cost']

func get_card_effects(card : Card, effect_type):
	var relevant_effects = []
	for effect in card['definition']['effects']:
		if effect['timing'] == effect_type:
			relevant_effects.append(effect)
	return relevant_effects

func get_card_boost_effects(card : Card):
	return card.definition['boost']['effects']

func get_card_boost_effects_now_immediate(card : Card):
	var relevant_effects = []
	for effect in card['definition']['boost']['effects']:
		if effect['timing'] == "now" or effect['timing'] == "immediate":
			relevant_effects.append(effect)
	return relevant_effects

func other_player(test_player : Player) -> Player:
	if test_player == player:
		return opponent
	return player

func advance_to_next_turn():
	player.canceled_this_turn = false
	opponent.canceled_this_turn = false

	active_turn_player = next_turn_player
	next_turn_player = other_player(active_turn_player)

	# Iterate in reverse as items can be removed.
	for i in range(len(active_turn_player.continuous_boosts) - 1, -1, -1):
		var card = active_turn_player.continuous_boosts[i]
		for effect in card.definition['boost']['effects']:
			if effect['timing'] == "start_of_next_turn":
				if effect['effect_type'] == 'add_to_gauge_immediately':
					active_turn_player.remove_from_continuous_boosts(card, true)

	change_game_state(GameState.GameState_PickAction)
	return [create_event(EventType.EventType_AdvanceTurn, active_turn_player, 0)]

func begin_resolve_strike():
	var events = []
	# Strike is just beginning.
	events += [create_event(EventType.EventType_Strike_Reveal, active_strike.initiator, 0)]

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
		elif condition == "not_full_close" and not local_conditions.fully_closed:
			return true
		elif condition == "advanced_through" and local_conditions.advanced_through:
			return true
		elif condition == "not_full_push" and not local_conditions.fully_pushed:
			return true
		elif condition == "pulled_past" and local_conditions.pulled_past:
			return true
		elif condition == "opponent_stunned":
			return active_strike.is_player_stunned(other_player(performing_player))

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
	var opposing_player : Player = other_player(performing_player)
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
			events += [create_event(EventType.EventType_Strike_ArmorUp, performing_player, effect['amount'])]
		"attack_is_ex":
			performing_player.strike_stat_boosts.set_ex()
			events += [create_event(EventType.EventType_Strike_ExUp, performing_player, card_id)]
		"bonus_action":
			active_boost.action_after_boost = true
		"choice":
			change_game_state(GameState.GameState_PlayerDecision)
			decision_type = DecisionType.DecisionType_EffectChoice
			decision_player = performing_player
			decision_choice = effect['choice']
			decision_choice_card_id = card_id
			events += [create_event(EventType.EventType_Strike_EffectChoice, performing_player, 0)]
		"close":
			events += performing_player.close(effect['amount'])
			var new_location = performing_player.arena_location
			var close_amount = abs(performing_start - new_location)
			local_conditions.fully_closed = close_amount == effect['amount']
		"dodge_attacks":
			performing_player.strike_stat_boosts.dodge_attacks = true
			events += [create_event(EventType.EventType_Strike_DodgeAttacks, performing_player, 0)]
		"draw":
			events += performing_player.draw(effect['amount'])
		"discard_continuous_boost":
			var boosts = other_player(performing_player).continuous_boosts
			if len(boosts) > 0:
				# Player gets to pick which continuous boost to discard.
				change_game_state(GameState.GameState_PlayerDecision)
				decision_type = DecisionType.DecisionType_ChooseDiscardContinuousBoost
				decision_effect_type = "discard_continuous_boost_INTERNAL"
				decision_choice_card_id = card_id
				decision_player = performing_player
				events += [create_event(EventType.EventType_Boost_DiscardContinuousChoice, performing_player, 1)]
		"discard_continuous_boost_INTERNAL":
			var boost_to_discard_id = effect['card_id']
			events += other_player(performing_player).remove_from_continuous_boosts(boost_to_discard_id, false)
		"gain_advantage":
			next_turn_player = performing_player
			events += [create_event(EventType.EventType_Strike_GainAdvantage, performing_player, 0)]
		"gauge_from_hand":
			if len(performing_player.hand) > 0:
				change_game_state(GameState.GameState_PlayerDecision)
				decision_type = DecisionType.DecisionType_CardFromHandToGauge
				decision_player = performing_player
				decision_choice_card_id = card_id
				events += [create_event(EventType.EventType_CardFromHandToGauge_Choice, performing_player, 1)]
		"guardup":
			performing_player.strike_stat_boosts.guard += effect['amount']
			events += [create_event(EventType.EventType_Strike_GuardUp, performing_player, effect['amount'])]
		"ignore_armor":
			performing_player.strike_stat_boosts.ignore_armor = true
		"ignore_guard":
			performing_player.strike_stat_boosts.ignore_guard = true
		"ignore_push_and_pull":
			performing_player.strike_stat_boosts.ignore_push_and_pull = true
		"name_card_opponent_discards":
			change_game_state(GameState.GameState_PlayerDecision)
			decision_type = DecisionType.DecisionType_NameCard_OpponentDiscards
			decision_effect_type = "name_card_opponent_discards_internal"
			decision_choice_card_id = card_id
			decision_player = performing_player
			events += [create_event(EventType.EventType_Boost_NameCardOpponentDiscards, performing_player, 1)]
		"name_card_opponent_discards_internal":
			var named_card = get_card(effect['card_id'])
			# named_card is the individual card but
			# this should discard "by name", so instead of using that
			# match card.definition['id']'s instead.
			events += opposing_player.discard_matching_or_reveal(named_card.definition['id'])
		"opponent_discard_random":
			events += opposing_player.discard_random(effect['amount'])
		"powerup":
			performing_player.strike_stat_boosts.power += effect['amount']
			events += [create_event(EventType.EventType_Strike_PowerUp, performing_player, effect['amount'])]
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
		"retreat":
			events += performing_player.retreat(effect['amount'])
			var new_location = performing_player.arena_location
			var retreat_amount = abs(performing_start - new_location)
			local_conditions.fully_retreated = retreat_amount == effect['amount']
		"when_hit_force_for_armor":
			performing_player.strike_stat_boosts.when_hit_force_for_armor = true

	if not game_state == GameState.GameState_PlayerDecision and "and" in effect:
		var and_effect = effect['and']
		if is_effect_condition_met(performing_player, and_effect, local_conditions):
			events += handle_strike_effect(card_id, and_effect, performing_player)

	if not game_state == GameState.GameState_PlayerDecision and "bonus_effect" in effect:
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
	for boost_card in other_player(performing_player).continuous_boosts:
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
	for boost_card in other_player(performing_player).continuous_boosts:
		for effect in boost_card.definition['boost']['effects']:
			if effect['timing'] == timing_name:
				card_ids.append(boost_card.id)
	return card_ids

func do_effects_for_timing(timing_name : String, performing_player : Player, card : Card, next_state):
	var events = []
	var effects = get_card_effects(card, timing_name)
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
			if game_state == GameState.GameState_PlayerDecision:
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
			if game_state == GameState.GameState_PlayerDecision:
				# Player has a decision to make, so stop mid-effect resolve.
				break

			# Effect was resolved, continue loop to resolve more.
			active_strike.effects_resolved_in_timing += 1
		elif character_effects_resolved < len(character_effects):
			# Resolve character effects
			var effect = character_effects[character_effects_resolved]
			if is_effect_condition_met(performing_player, effect, null):
				events += handle_strike_effect(card.id, effect, performing_player)
			if game_state == GameState.GameState_PlayerDecision:
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
	var min_range = card.definition['range_min']
	var max_range = card.definition['range_max']
	var distance = abs(atacking_player.arena_location - defending_player.arena_location)
	if min_range <= distance and distance <= max_range:
		return true
	return false

func apply_damage(offense_player : Player, defense_player : Player, offense_card : Card, defense_card : Card):
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
	events += [create_event(EventType.EventType_Strike_TookDamage, defense_player, damage_after_armor)]
	if damage_after_armor > guard:
		events += [create_event(EventType.EventType_Strike_Stun, defense_player, damage_after_armor-guard)]
		active_strike.set_player_stunned(defense_player)

	if defense_player.life <= 0:
		events += [create_event(EventType.EventType_GameOver, defense_player, 0)]
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
			change_game_state(GameState.GameState_PlayerDecision)
			decision_player = performing_player
			if active_strike.get_player_wild_strike(performing_player):
				decision_type = DecisionType.DecisionType_PayStrikeCost_CanWild
			else:
				decision_type = DecisionType.DecisionType_PayStrikeCost_Required

			if gauge_cost > 0:
				events += [create_event(EventType.EventType_Strike_PayCost_Gauge, performing_player, card.id)]
			elif force_cost > 0:
				events += [create_event(EventType.EventType_Strike_PayCost_Force, performing_player, card.id)]
		else:
			# Failed to pay the cost by default.
			events += [create_event(EventType.EventType_Strike_PayCost_Unable, performing_player, card.id)]
			events += performing_player.add_to_discards(card)
			events += performing_player.wild_strike();
	return events

func do_hit_response_effects(hit_player : Player, next_state : StrikeState):
	# If more of these are added, need to sequence them to ensure all handled correctly.
	var events = []
	active_strike.strike_state = next_state
	if hit_player.strike_stat_boosts.when_hit_force_for_armor:
		change_game_state(GameState.GameState_PlayerDecision)
		decision_player = hit_player
		decision_type = DecisionType.DecisionType_ForceForArmor
		decision_choice_card_id = active_strike.get_player_card(hit_player).id
		events += [create_event(EventType.EventType_Strike_ForceForArmor, decision_player, 0)]
	return events

func continue_resolve_strike():
	var events = []
	change_game_state(GameState.GameState_Strike_Processing)

	while true:
		# Cards might change due to paying costs, so get them every loop.
		# Do NOT use before strike_determine_order and the StrikeState_DuringStrikeBonuses state has been called.
		var card1 = active_strike.get_card(1)
		var card2 = active_strike.get_card(2)
		var player1 = active_strike.get_player(1)
		var player2 = active_strike.get_player(2)

		if game_state == GameState.GameState_PlayerDecision:
			printlog("STRIKE: Breaking for decision %s %s" % [decision_player.name, DecisionType.keys()[decision_type]])
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
				events += do_effects_for_timing("during_strike", active_strike.defender, active_strike.defender_card, StrikeState.StrikeState_Card1_Before)
				strike_determine_order()
			StrikeState.StrikeState_Card1_Before:
				events += do_effects_for_timing("before", player1, card1, StrikeState.StrikeState_Card1_DetermineHit)
			StrikeState.StrikeState_Card1_DetermineHit:
				if in_range(player1, player2, card1):
					active_strike.player1_hit = true
					active_strike.strike_state = StrikeState.StrikeState_Card1_Hit
				else:
					events += [create_event(EventType.EventType_Strike_Miss, player1, 0)]
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
				events += do_effects_for_timing("after", player1, card1, StrikeState.StrikeState_Card2_Before)
			StrikeState.StrikeState_Card2_Before:
				if active_strike.player2_stunned:
					active_strike.strike_state = StrikeState.StrikeState_Cleanup
				else:
					events += do_effects_for_timing("before", player2, card2, StrikeState.StrikeState_Card2_DetermineHit)
			StrikeState.StrikeState_Card2_DetermineHit:
				if in_range(player2, player1, card2):
					active_strike.player2_hit = true
					active_strike.strike_state = StrikeState.StrikeState_Card2_Hit
				else:
					events += [create_event(EventType.EventType_Strike_Miss, player2, 0)]
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
				events += advance_to_next_turn()
				break
	return events

func begin_resolve_boost(performing_player : Player, card_id : int):
	var events = []

	active_boost = Boost.new()
	active_boost.playing_player = performing_player
	active_boost.card = get_card(card_id)
	performing_player.remove_card_from_hand(card_id)
	events += [create_event(EventType.EventType_Boost_Played, performing_player, card_id)]

	# Resolve all immediate/now effects
	# If continuous, put it into continous boost tracking.
	events += continue_resolve_boost()
	return events

func continue_resolve_boost():
	var events = []

	change_game_state(GameState.GameState_Boost_Processing)

	var effects = get_card_boost_effects_now_immediate(active_boost.card)
	while true:
		if active_boost.effects_resolved < len(effects):
			var effect = effects[active_boost.effects_resolved]
			if is_effect_condition_met(active_boost.playing_player, effect, null):
				events += handle_strike_effect(active_boost.card.id, effect, active_boost.playing_player)

			if game_state == GameState.GameState_PlayerDecision:
				break

			active_boost.effects_resolved += 1
		else:
			# After all effects are resolved, check for cancel.
			if active_boost.playing_player.can_cancel(active_boost.card):
				change_game_state(GameState.GameState_PlayerDecision)
				decision_type = DecisionType.DecisionType_BoostCancel
				decision_player = active_boost.playing_player
				events += [create_event(EventType.EventType_Boost_CancelDecision, active_boost.playing_player, get_card_cancel_cost(active_boost.card.id))]
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
		events += [create_event(EventType.EventType_Boost_ActionAfterBoost, performing_player, 0)]
		change_game_state(GameState.GameState_PickAction)
	else:
		events += performing_player.draw(1)
		events += check_hand_size_advance_turn(performing_player)
	active_boost = null
	return events

func can_do_prepare(performing_player : Player):
	if game_state != GameState.GameState_PickAction:
		return false
	if active_turn_player != performing_player:
		return false
	return true

func can_do_move(performing_player : Player):
	if game_state != GameState.GameState_PickAction:
		return false
	if active_turn_player != performing_player:
		return false

	# Check if the player can generate force (2 if cornered)
	var force_needed = 1
	if ((performing_player.arena_location == 1 and other_player(performing_player).arena_location == 2)
		or (performing_player.arena_location == 9 and other_player(performing_player).arena_location == 8)):
		force_needed = 2
		pass

	var force_available = performing_player.get_available_force()
	if force_available >= force_needed:
		return true
	return false

func can_do_change(performing_player : Player):
	if game_state != GameState.GameState_PickAction:
		return false
	if active_turn_player != performing_player:
		return false

	var force_available = performing_player.get_available_force()
	return force_available > 0

func can_do_exceed(performing_player : Player):
	if game_state != GameState.GameState_PickAction:
		return false
	if active_turn_player != performing_player:
		return false
	if performing_player.exceeded:
		return false

	var gauge_available = len(performing_player.gauge)
	return gauge_available >= performing_player.exceed_cost

func can_do_reshuffle(performing_player : Player):
	if game_state != GameState.GameState_PickAction:
		return false
	if active_turn_player != performing_player:
		return false
	if len(performing_player.discards) == 0:
		return false
	return performing_player.reshuffle_remaining > 0

func can_do_boost(performing_player : Player):
	if game_state != GameState.GameState_PickAction:
		return false
	if active_turn_player != performing_player:
		return false

	var force_available = performing_player.get_available_force()
	for card in performing_player.hand:
		if card.definition['boost']['force_cost'] <= force_available:
			return true

	return false

func can_player_boost(performing_player : Player, card_id : int):
	if not performing_player.is_card_in_hand(card_id):
		return false
	var force_cost = get_card_boost_force_cost(card_id)
	var force_available = performing_player.get_available_force() - get_card_force(card_id)
	if force_cost <= force_available:
		return true

func can_do_strike(performing_player : Player):
	if game_state != GameState.GameState_WaitForStrike and decision_player == performing_player:
		return true
	if game_state != GameState.GameState_PickAction:
		return false
	if active_turn_player != performing_player:
		return false

	# Can always wild swing!

	return true

func check_hand_size_advance_turn(performing_player : Player):
	var events = []
	if len(performing_player.hand) > MaxHandSize:
		change_game_state(GameState.GameState_DiscardDownToMax)
		events += [create_event(EventType.EventType_HandSizeExceeded, performing_player, len(performing_player.hand) - MaxHandSize)]
	else:
		events += advance_to_next_turn()
	return events

func do_prepare(performing_player):
	if not can_do_prepare(performing_player):
		printlog("ERROR: Tried to Prepare but can't.")
		return []

	var events : Array = performing_player.draw(2)
	events += check_hand_size_advance_turn(performing_player)
	return events

func do_discard_to_max(performing_player : Player, card_ids):
	if performing_player != active_turn_player:
		printlog("ERROR: Tried to discard for wrong player.")
		return []
	if game_state != GameState.GameState_DiscardDownToMax:
		printlog("ERROR: Tried to discard wrong game state.")
		return []

	for id in card_ids:
		if not performing_player.is_card_in_hand(id):
			# Card not found, error
			printlog("ERROR: Tried to discard cards that aren't in hand.")
			return []

	if len(performing_player.hand) - len(card_ids) > MaxHandSize:
		printlog("ERROR: Not discarding enough cards")
		return []

	var events = performing_player.discard(card_ids)
	events += advance_to_next_turn()

	return events

func do_reshuffle(performing_player : Player):
	if not can_do_reshuffle(performing_player):
		printlog("ERROR: Tried to reshuffle but can't.")
		return []

	var events = performing_player.reshuffle_discard()
	events += performing_player.draw(1)
	events += check_hand_size_advance_turn(performing_player)
	return events

func do_move(performing_player : Player, card_ids, new_arena_location):
	if not can_do_move(performing_player):
		printlog("ERROR: Cannot perform the move action for this player.")
		return []

	if not performing_player.can_move_to(new_arena_location):
		printlog("ERROR: Unable to move to that arena location.")
		return []

	# Ensure cards are in hand/gauge
	for id in card_ids:
		if not performing_player.is_card_in_hand(id) and not performing_player.is_card_in_gauge(id):
			# Card not found, error
			printlog("ERROR: Tried to discard cards that aren't in hand/gauge.")
			return []

	# Ensure cards generate enough force.
	var required_force = performing_player.get_force_to_move_to(new_arena_location)
	var generated_force = 0
	for id in card_ids:
		generated_force += get_card_force(id)

	if generated_force < required_force:
		printlog("ERROR: Not enough force with these cards to move there.")
		return []

	var events = performing_player.discard(card_ids)
	events += performing_player.move_to(new_arena_location)
	events += performing_player.draw(1)
	events += check_hand_size_advance_turn(performing_player)
	return events

func do_change(performing_player : Player, card_ids):
	if not can_do_change(performing_player):
		printlog("ERROR: Cannot do change action for this player.")
		return []

	for id in card_ids:
		if not performing_player.is_card_in_hand(id) and not performing_player.is_card_in_gauge(id):
			# Card not found, error
			printlog("ERROR: Tried to discard cards that aren't in hand or gauge.")
			return []

	var events = performing_player.discard(card_ids)
	var force_generated = 0
	for id in card_ids:
		force_generated += get_card_force(id)
	events += performing_player.draw(force_generated + 1)
	events += check_hand_size_advance_turn(performing_player)

	return events

func do_exceed(performing_player : Player, card_ids : Array):
	if game_state != GameState.GameState_PickAction:
		printlog("ERROR: Tried to exceed but not in correct game state.")
		return []
	if performing_player != active_turn_player:
		printlog("ERROR: Tried to exceed for wrong player.")
		return []
	for id in card_ids:
		if not performing_player.is_card_in_gauge(id):
			# Card not found, error
			printlog("ERROR: Tried to exced with cards that not in gauge.")
			return []
	if len(card_ids) < performing_player.exceed_cost:
		printlog("ERROR: Tried to exceed with too few cards.")
		return []

	var events = performing_player.discard(card_ids)
	events += performing_player.exceed()
	events += performing_player.draw(1)
	events += check_hand_size_advance_turn(performing_player)
	return events

func do_boost(performing_player : Player, card_id : int):
	printlog("Boosting player %s card %s" % [performing_player.name, get_card_name(card_id)])
	if game_state != GameState.GameState_PickAction or performing_player != active_turn_player:
		printlog("ERROR: Tried to boost but not your turn")
		return []

	var events = []

	events += begin_resolve_boost(performing_player, card_id)

	return events

func do_strike(performing_player : Player, card_id : int, wild_strike: bool, ex_card_id : int):
	printlog("Starting strike player %s card %s wild %s" % [performing_player.name, get_card_name(card_id), str(wild_strike)])
	if game_state == GameState.GameState_PickAction:
		if performing_player != active_turn_player:
			printlog("ERROR: Tried to strike but not current player")
			return []
	elif game_state == GameState.GameState_Strike_Opponent_Response:
		if performing_player != other_player(active_turn_player):
			printlog("ERROR: Strike response from wrong player.")
			return []
	elif game_state == GameState.GameState_WaitForStrike:
		if performing_player != decision_player:
			printlog("ERROR: Strike response from wrong player.")
			return []

	if not wild_strike and not performing_player.is_card_in_hand(card_id):
		printlog("ERROR: Tried to strike with a card not in hand.")
		return []
	if ex_card_id != -1 and not performing_player.is_card_in_hand(ex_card_id):
		printlog("ERROR: Tried to strike with a ex card not in hand.")
		return []

	# Begin the strike
	var events = []

	# Lay down the strike
	match game_state:
		GameState.GameState_PickAction, GameState.GameState_WaitForStrike:
			active_strike = Strike.new()
			active_strike.initiator = performing_player
			if wild_strike:
				events += performing_player.wild_strike()
				card_id = active_strike.initiator_card.id
			else:
				active_strike.initiator_card = get_card(card_id)
				performing_player.remove_card_from_hand(card_id)
				if ex_card_id != -1:
					active_strike.initiator_ex_card = get_card(ex_card_id)
					performing_player.remove_card_from_hand(ex_card_id)
			active_strike.defender = other_player(performing_player)
			# Send the EX first as that is visual and logic is triggered off the regular one.
			if ex_card_id != -1:
				events += [create_event(EventType.EventType_Strike_Started_Ex, performing_player, ex_card_id)]
			events += [create_event(EventType.EventType_Strike_Started, performing_player, card_id)]
			change_game_state(GameState.GameState_Strike_Opponent_Response)
			if performing_player.force_opponent_respond_wild_swing():
				events += [create_event(EventType.EventType_Strike_ForceWildSwing, performing_player, 0)]
				events += do_strike(other_player(performing_player), -1, true, -1)
		GameState.GameState_Strike_Opponent_Response:
			if wild_strike:
				events += performing_player.wild_strike()
				card_id = active_strike.defender_card.id
			else:
				active_strike.defender_card = get_card(card_id)
				performing_player.remove_card_from_hand(card_id)
				if ex_card_id != -1:
					active_strike.defender_ex_card = get_card(ex_card_id)
					performing_player.remove_card_from_hand(ex_card_id)
			# Send the EX first as that is visual and logic is triggered off the regular one.
			if ex_card_id != -1:
				events += [create_event(EventType.EventType_Strike_Response_Ex, performing_player, ex_card_id)]
			events += [create_event(EventType.EventType_Strike_Response, performing_player, card_id)]

			events += begin_resolve_strike()
	return events

func do_pay_strike_cost(performing_player : Player, card_ids : Array, wild_strike : bool):
	if game_state != GameState.GameState_PlayerDecision:
		printlog("ERROR: Tried to pay costs but not in decision state.")
		return []
	if decision_type != DecisionType.DecisionType_PayStrikeCost_CanWild and decision_type != DecisionType.DecisionType_PayStrikeCost_Required:
		printlog("ERROR: Tried to pay costs but not in correct decision type.")
		return []
	if decision_type == DecisionType.DecisionType_PayStrikeCost_Required and wild_strike:
		# Only allowed if you can't pay the cost.
		var card = active_strike.get_player_card(performing_player)
		if performing_player.can_pay_cost(card):
			printlog("ERROR: Tried to wild strike when not allowed.")
			return []
	if decision_player != performing_player:
		printlog("ERROR: Tried to pay costs for wrong player.")
		return []

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
			return []
	events += continue_resolve_strike()
	return events

func do_force_for_armor(performing_player : Player, card_ids : Array):
	if game_state != GameState.GameState_PlayerDecision or decision_type != DecisionType.DecisionType_ForceForArmor:
		printlog("ERROR: Tried to force for armor but not in decision state.")
		return []
	if decision_player != performing_player:
		printlog("ERROR: Tried to force for armor for wrong player.")
		return []

	var events = []
	for card_id in card_ids:
		if not performing_player.is_card_in_hand(card_id) and not performing_player.is_card_in_gauge(card_id):
			printlog("ERROR: Tried to force for armor with card not in hand or gauge.")
			return []

	var force_generated = 0
	for card_id in card_ids:
		force_generated += get_card_force(card_id)
	if force_generated > 0:
		events += performing_player.discard(card_ids)
		events += handle_strike_effect(decision_choice_card_id, {'effect_type': 'armorup', 'amount': force_generated * 2}, performing_player)
	events += continue_resolve_strike()
	return events

func do_boost_cancel(performing_player : Player, gauge_card_ids : Array, doing_cancel : bool):
	if game_state != GameState.GameState_PlayerDecision or decision_type != DecisionType.DecisionType_BoostCancel:
		printlog("ERROR: Tried to cancel boost but not in decision state.")
		return []
	if decision_player != performing_player:
		printlog("ERROR: Tried to boost cancel wrong player.")
		return []
	if not active_boost:
		printlog("ERROR: Tried to cancel boost but no active boost.")
		return []
	if doing_cancel and len(gauge_card_ids) < get_card_cancel_cost(active_boost.card.id):
		printlog("ERROR: Tried to cancel boost with too few cards.")
		return []
	for id in gauge_card_ids:
		if not performing_player.is_card_in_gauge(id):
			# Card not found, error
			printlog("ERROR: Tried to cancel boost with cards that aren't in gauge.")
			return []

	var events = []
	if doing_cancel:
		events += performing_player.discard(gauge_card_ids)
		events += performing_player.on_cancel_boost()
		active_boost.action_after_boost = true
	events += boost_play_cleanup(performing_player)

	return events

func do_card_from_hand_to_gauge(performing_player : Player, card_id : int):
	if decision_player != performing_player:
		printlog("ERROR: Tried to do_card_from_hand_to_gauge for wrong player.")
		return []
	if game_state != GameState.GameState_PlayerDecision or decision_type != DecisionType.DecisionType_CardFromHandToGauge:
		printlog("ERROR: Tried to do_card_from_hand_to_gauge but not in decision state.")
		return []
	if not performing_player.is_card_in_hand(card_id):
		printlog("ERROR: Tried to do_card_from_hand_to_gauge with card not in hand.")
		return []
	var events = []

	events += performing_player.move_card_from_hand_to_gauge(card_id)
	active_boost.effects_resolved += 1
	events += continue_resolve_boost()

	return events

func do_boost_name_card_choice_effect(performing_player : Player, card_id : int):
	if decision_player != performing_player:
		printlog("ERROR: Tried to force for armor for wrong player.")
		return []
	if game_state != GameState.GameState_PlayerDecision:
		printlog("ERROR: Tried to make a choice but not in decision state.")
		return []

	var effect = {
		"effect_type": decision_effect_type,
		"card_id": card_id,
	}

	var events = handle_strike_effect(decision_choice_card_id, effect, performing_player)
	active_boost.effects_resolved += 1
	events += continue_resolve_boost()
	return events

func do_choice(performing_player : Player, choice_index : int):
	if decision_player != performing_player:
		printlog("ERROR: Tried to force for armor for wrong player.")
		return []
	if game_state != GameState.GameState_PlayerDecision:
		printlog("ERROR: Tried to make a choice but not in decision state.")
		return []
	if choice_index >= len(decision_choice):
		printlog("ERROR: Tried to make a choice that doesn't exist.")
		return []

	var effect = decision_choice[choice_index]
	var events = handle_strike_effect(decision_choice_card_id, effect, performing_player)
	if active_strike:
		active_strike.effects_resolved_in_timing += 1
		events += continue_resolve_strike()
	elif active_boost:
		active_boost.effects_resolved += 1
		events += continue_resolve_boost()
	else:
		printlog("ERROR: Tried to make choice but no active strike or boost.")
	return events
