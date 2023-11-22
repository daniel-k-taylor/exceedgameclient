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
var game_over_winning_player : Player = null
var active_strike : Strike = null
var active_exceed : bool = false

var decision_info : DecisionInfo = DecisionInfo.new()
var active_boost : Boost = null

var game_state : Enums.GameState = Enums.GameState.GameState_NotStarted

var combat_log : String = ""

func get_combat_log() -> String:
	return combat_log

func _append_log(text):
	combat_log += text + "\n"

func teardown():
	card_db.teardown()
	card_db.free()
	decision_info.free()

func change_game_state(new_state : Enums.GameState):
	if game_state != Enums.GameState.GameState_GameOver:
		printlog("game_state update from %s to %s" % [Enums.GameState.keys()[game_state], Enums.GameState.keys()[new_state]])
		game_state = new_state
	else:
		_append_log("GAME OVER - WINNER - %s" % [game_over_winning_player.name])

func get_game_state() -> Enums.GameState:
	return game_state

func get_decision_info() -> DecisionInfo:
	return decision_info

func printlog(text):
	if GlobalSettings.is_logging_enabled():
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

func trigger_game_over(event_player : Enums.PlayerId, reason : Enums.GameOverReason):
	var events = []
	events += [create_event(Enums.EventType.EventType_GameOver, event_player, reason)]
	game_over = true
	game_over_winning_player = _get_player(get_other_player(event_player))
	change_game_state(Enums.GameState.GameState_GameOver)
	return events

enum StrikeState {
	StrikeState_None,
	StrikeState_Initiator_SetEffects,
	StrikeState_Defender_SetEffects,
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
	StrikeState_Cleanup_Player1Effects,
	StrikeState_Cleanup_Player1EffectsComplete,
	StrikeState_Cleanup_Player2Effects,
	StrikeState_Cleanup_Complete
}

class Strike:
	var initiator : Player
	var defender : Player
	var initiator_card : GameCard = null
	var initiator_ex_card : GameCard = null
	var defender_card : GameCard = null
	var defender_ex_card : GameCard = null
	var initiator_first : bool
	var initiator_wild_strike : bool = false
	var defender_wild_strike : bool = false
	var strike_state
	var starting_distance : int = -1
	var in_setup : bool = true
	var remaining_effect_list : Array = []
	var effects_resolved_in_timing : int = 0
	var player1_hit : bool = false
	var player1_stunned : bool = false
	var player2_hit : bool = false
	var player2_stunned : bool = false
	var initiator_damage_taken = 0
	var defender_damage_taken = 0

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

	func add_damage_taken(performing_player : Player, damage : int) -> void:
		if performing_player == initiator:
			initiator_damage_taken += damage
		else:
			defender_damage_taken += damage

	func get_damage_taken(performing_player : Player) -> int:
		if performing_player == initiator:
			return initiator_damage_taken
		return defender_damage_taken

	func will_be_ex(performing_player : Player) -> bool:
		for boost_card in performing_player.continuous_boosts:
			var effects = boost_card.definition['boost']['effects']
			for effect in effects:
				if effect['timing'] == 'during_strike' and effect['effect_type'] == "attack_is_ex":
					return true
		if performing_player == initiator:
			return initiator_ex_card != null
		else:
			return defender_ex_card != null

class Boost:
	var playing_player : Player
	var card : GameCard
	var effects_resolved = 0
	var action_after_boost = false
	var strike_after_boost = false
	var cancel_resolved = false
	var cleanup_to_gauge_card_ids = []
	var cleanup_to_hand_card_ids = []

class StrikeStatBoosts:
	var power : int = 0
	var armor : int = 0
	var guard : int = 0
	var speed : int = 0
	var min_range : int = 0
	var max_range : int = 0
	var dodge_attacks : bool = false
	var dodge_at_range_min : int = -1
	var dodge_at_range_max : int = -1
	var ignore_armor : bool = false
	var ignore_guard : bool = false
	var ignore_push_and_pull : bool = false
	var lose_all_armor : bool = false
	var always_add_to_gauge : bool = false
	var return_attack_to_hand : bool = false
	var when_hit_force_for_armor : bool = false
	var stun_immunity : bool = false
	var was_hit : bool = false
	var is_ex : bool = false
	var opponent_cant_move_past : bool = false
	var active_character_effects = []

	func clear():
		power = 0
		armor = 0
		guard = 0
		speed = 0
		min_range = 0
		max_range = 0
		dodge_attacks = false
		dodge_at_range_min = -1
		dodge_at_range_max = -1
		ignore_armor = false
		ignore_guard = false
		ignore_push_and_pull = false
		lose_all_armor = false
		always_add_to_gauge = false
		return_attack_to_hand = false
		when_hit_force_for_armor = false
		stun_immunity = false
		was_hit = false
		is_ex = false
		opponent_cant_move_past = false
		active_character_effects = []

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
	var used_character_action : bool
	var exceed_at_end_of_turn : bool
	var specials_invalid : bool
	var mulligan_complete : bool
	var reading_card_id : String
	var next_strike_faceup : bool
	var strike_on_boost_cleanup : bool
	var max_hand_size : int
	var starting_hand_size_bonus : int
	var pre_strike_movement : int
	var sustained_boosts : Array[int]
	var sustain_next_boost : bool

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
		gauge = []
		continuous_boosts = []
		discards = []
		reshuffle_remaining = MaxReshuffle
		exceeded = false
		canceled_this_turn = false
		used_character_action = false
		exceed_at_end_of_turn = false
		specials_invalid = false
		cleanup_boost_to_gauge_cards = []
		mulligan_complete = false
		reading_card_id = ""
		next_strike_faceup = false
		strike_on_boost_cleanup = false
		pre_strike_movement = 0
		sustained_boosts = []
		sustain_next_boost = false

		max_hand_size = MaxHandSize	
		if 'alt_hand_size' in deck_def:
			max_hand_size = deck_def['alt_hand_size']
		
		starting_hand_size_bonus = 0
		if 'bonus_starting_hand' in deck_def:
			starting_hand_size_bonus = deck_def['bonus_starting_hand']

	func initial_shuffle():
		if ShuffleEnabled:
			random_shuffle_deck()

	func random_shuffle_deck():
		parent.shuffle_array(deck)

	func owns_card(card_id: int):
		for card in deck_list:
			if card.id == card_id:
				return true
		return false

	func exceed():
		exceeded = true
		var events = []
		events += [parent.create_event(Enums.EventType.EventType_Exceed, my_id, 0)]

		if 'on_exceed' in deck_def:
			var effect = deck_def['on_exceed']
			events += parent.handle_strike_effect(-1, effect, self)
		return events

	func revert_exceed():
		exceeded = false
		var events = []
		events += [parent.create_event(Enums.EventType.EventType_ExceedRevert, my_id, 0)]
		if 'on_revert' in deck_def:
			var effect = deck_def['on_revert']
			events += parent.handle_strike_effect(-1, effect, self)
		return events

	func mulligan(card_ids : Array):
		var events = []
		events += draw(len(card_ids))
		for id in card_ids:
			events += move_card_from_hand_to_deck(id)
		if ShuffleEnabled:
			random_shuffle_deck()
		events += [parent.create_event(Enums.EventType.EventType_ReshuffleDeck_Mulligan, my_id, reshuffle_remaining)]
		mulligan_complete = true
		return events

	func is_card_in_hand(id : int):
		for card in hand:
			if card.id == id:
				return true
		return false

	func is_card_in_discards(id : int):
		for card in discards:
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

	func move_card_from_discard_to_deck(id : int):
		var events = []
		for i in range(len(discards)):
			var card = discards[i]
			if card.id == id:
				deck.insert(0, card)
				discards.remove_at(i)
				random_shuffle_deck()
				events += [parent.create_event(Enums.EventType.EventType_AddToDeck, my_id, card.id)]
				break
		return events

	func move_card_from_discard_to_gauge(id : int):
		var events = []
		for i in range(len(discards)):
			var card = discards[i]
			if card.id == id:
				events += add_to_gauge(card)
				discards.remove_at(i)
				break
		return events

	func move_card_from_discard_to_hand(id : int):
		var events = []
		for i in range(len(discards)):
			var card = discards[i]
			if card.id == id:
				events += add_to_hand(card)
				discards.remove_at(i)
				break
		return events

	func add_top_deck_to_gauge():
		var events = []
		if len(deck) > 0:
			var card = deck[0]
			events += add_to_gauge(card)
			deck.remove_at(0)
			parent._append_log("%s added %s to gauge from top of deck." % [name, parent.card_db.get_card_name(card.id)])
		return events

	func return_all_cards_gauge_to_hand():
		var events = []
		for card in gauge:
			events += add_to_hand(card)
		gauge = []
		return events

	func is_card_in_gauge(id : int):
		for card in gauge:
			if card.id == id:
				return true
		return false

	func get_discard_count_of_type(limitation : String):
		var count = 0
		for card in discards:
			match limitation:
				"special":
					if card.definition['type'] == "special":
						count += 1
				_:
					count += 1
		return count

	func can_pay_cost_with(card_ids : Array, force_cost : int, gauge_cost : int):
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

		if gauge_generated < gauge_cost:
			return false
		if force_generated < force_cost:
			return false

		return true

	func can_pay_cost(force_cost : int, gauge_cost : int):
		var available_force = get_available_force()
		var available_gauge = get_available_gauge()
		if available_gauge < gauge_cost:
			return false
		if available_force < force_cost:
			return false
		return true

	func can_boost_something(allow_gauge : bool, limitation : String) -> bool:
		var force_available = get_available_force()
		for card in hand:
			var meets_limitation = true
			if limitation:
				meets_limitation = card.definition['boost']['boost_type'] == limitation
			if not meets_limitation:
				continue
			var force_available_when_boosting_this = force_available - parent.card_db.get_card_force_value(card.id)
			var cost = parent.card_db.get_card_boost_force_cost(card.id)
			if force_available_when_boosting_this >= cost:
				return true
		if allow_gauge:
			for card in gauge:
				var meets_limitation = true
				if limitation:
					meets_limitation = card.definition['boost']['boost_type'] == limitation
				if not meets_limitation:
					continue
				var force_available_when_boosting_this = force_available - parent.card_db.get_card_force_value(card.id)
				var cost = parent.card_db.get_card_boost_force_cost(card.id)
				if force_available_when_boosting_this >= cost:
					return true
		return false

	func can_cancel(card : GameCard):
		if strike_on_boost_cleanup:
			return false
		if parent.active_strike:
			return false
			
		var available_gauge = get_available_gauge()
		var cancel_cost = card.definition['boost']['cancel_cost']
		if cancel_cost == -1: return false
		if available_gauge < cancel_cost: return false
		return true

	func get_character_action():
		if exceeded and 'character_action_exceeded' in deck_def:
			var action = deck_def['character_action_exceeded']
			return action
		elif not exceeded and 'character_action_default' in deck_def:
			var action = deck_def['character_action_default']
			return action
		return null

	func can_do_character_action() -> bool:
		if exceeded and 'character_action_exceeded' in deck_def:
			var action = deck_def['character_action_exceeded']
			var gauge_cost = action['gauge_cost']
			var force_cost = action['force_cost']
			if get_available_gauge() < gauge_cost: return false
			if get_available_force() < force_cost: return false
			return true
		elif not exceeded and 'character_action_default' in deck_def:
			var action = deck_def['character_action_default']
			var gauge_cost = action['gauge_cost']
			var force_cost = action['force_cost']
			if get_available_gauge() < gauge_cost: return false
			if get_available_force() < force_cost: return false
			return true
		return false

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
			parent._append_log("%s ran out of cards." % [name])
			events += parent.trigger_game_over(my_id, Enums.GameOverReason.GameOverReason_Decked)
		else:
			# Put discard into deck, shuffle, subtract reshuffles
			parent._append_log("%s reshuffled." % [name])
			deck += discards
			discards = []
			random_shuffle_deck()
			reshuffle_remaining -= 1
			events += [parent.create_event(Enums.EventType.EventType_ReshuffleDiscard, my_id, reshuffle_remaining)]
			var effects = get_character_effects_at_timing("on_reshuffle")
			for effect in effects:
				if parent.is_effect_condition_met(self, effect, null):
					events += parent.handle_strike_effect(-1, effect, self)
		return events

	func discard(card_ids : Array):
		var events = []
		for discard_id in card_ids:
			# From hand
			for i in range(len(hand)-1, -1, -1):
				var card = hand[i]
				if card.id == discard_id:
					parent._append_log("%s discarded %s from hand." % [name, parent.card_db.get_card_name(card.id)])
					discards.append(card)
					hand.remove_at(i)
					events += [parent.create_event(Enums.EventType.EventType_Discard, my_id, card.id)]
					break

			# From gauge
			for i in range(len(gauge)-1, -1, -1):
				var card = gauge[i]
				if card.id == discard_id:
					parent._append_log("%s discarded %s from gauge." % [name, parent.card_db.get_card_name(card.id)])
					discards.append(card)
					gauge.remove_at(i)
					events += [parent.create_event(Enums.EventType.EventType_Discard, my_id, card.id)]
					break
		return events

	func discard_hand():
		var events = []
		var card_ids = []
		for card in hand:
			card_ids.append(card.id)
		events += discard(card_ids)
		return events

	func discard_matching_or_reveal(card_definition_id : String):
		var events = []
		for card in hand:
			if card.definition['id'] == card_definition_id:
				parent._append_log("%s discarded matching card %s." % [name, parent.card_db.get_card_name(card.id)])
				events = discard([card.id])
				return events
		# Not found
		events += reveal_hand()
		return events

	func next_strike_with_or_reveal(card_definition_id : String) -> void:
		reading_card_id = card_definition_id

	func get_reading_card_in_hand() -> GameCard:
		for card in hand:
			if card.definition['id'] == reading_card_id:
				return card
		return null

	func reveal_hand():
		var events = []
		var card_names = ""
		if hand.size() > 0:
			card_names = parent.card_db.get_card_name(hand[0].id)
		for i in range (1, hand.size()):
			card_names += ", " + parent.card_db.get_card_name(hand[i].id)
		parent._append_log("%s revealed hand: %s." % [name, card_names])
		events += [parent.create_event(Enums.EventType.EventType_RevealHand, my_id, 0)]
		return events

	func reveal_topdeck():
		var events = []
		if deck.size() == 0:
			parent._append_log("%s deck is empty, can't reveal top of deck." % [name])
			return events

		var card_name = parent.card_db.get_card_name(deck[0].id)
		if self == parent.player:
			parent._append_log("%s revealed top of deck to opponent." % [name])
		else:
			parent._append_log("%s revealed top of deck: %s." % [name, card_name])
		events += [parent.create_event(Enums.EventType.EventType_RevealTopDeck, my_id, deck[0].id)]
		return events

	func discard_random(amount):
		var events = []
		for i in range(amount):
			if len(hand) > 0:
				var random_card_id = hand[parent.get_random_int() % len(hand)].id
				parent._append_log("%s discarded random card %s." % [name, parent.card_db.get_card_name(random_card_id)])
				events += discard([random_card_id])
		return events

	func wild_strike(is_immediate_reveal : bool = false):
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
			events += [parent.create_event(Enums.EventType.EventType_Strike_WildStrike, my_id, card_id, "", is_immediate_reveal)]
		return events

	func add_to_gauge(card: GameCard):
		gauge.append(card)
		return [parent.create_event(Enums.EventType.EventType_AddToGauge, my_id, card.id)]

	func add_to_discards(card : GameCard):
		discards.append(card)
		return [parent.create_event(Enums.EventType.EventType_AddToDiscard, my_id, card.id)]

	func add_to_hand(card : GameCard):
		hand.append(card)
		return [parent.create_event(Enums.EventType.EventType_AddToHand, my_id, card.id)]

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
		if not parent.active_strike:
			pre_strike_movement += abs(arena_location - new_location)
		arena_location = new_location
		events += [parent.create_event(Enums.EventType.EventType_Move, my_id, new_location, "close", amount, previous_location)]
		return events

	func advance(amount):
		var events = []
		var previous_location = arena_location
		var other_player_location = parent._get_player(parent.get_other_player(my_id)).arena_location
		var blocked_from_passing = parent._get_player(parent.get_other_player(my_id)).strike_stat_boosts.opponent_cant_move_past
		var new_location
		if arena_location < other_player_location:
			new_location = arena_location + amount
			if new_location >= other_player_location:
				new_location += 1
			var max_position = MaxArenaLocation
			if blocked_from_passing:
				max_position = other_player_location
			new_location = min(new_location, max_position)
			if other_player_location == new_location:
				new_location -= 1
		else:
			new_location = arena_location - amount
			if new_location <= other_player_location:
				new_location -= 1
			var min_position = MinArenaLocation
			if blocked_from_passing:
				min_position = other_player_location
			new_location = max(new_location, min_position)
			if other_player_location == new_location:
				new_location += 1

		if not parent.active_strike:
			pre_strike_movement += abs(arena_location - new_location)
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

		if not parent.active_strike:
			pre_strike_movement += abs(arena_location - new_location)
		arena_location = new_location
		events += [parent.create_event(Enums.EventType.EventType_Move, my_id, new_location, "retreat", amount, previous_location)]

		return events

	func push(amount):
		var events = []
		var other_player = parent._get_player(parent.get_other_player(my_id))
		if other_player.strike_stat_boosts.ignore_push_and_pull:
			events += [parent.create_event(Enums.EventType.EventType_Strike_IgnoredPushPull, other_player.my_id, 0)]
		else:
			var other_location = other_player.arena_location
			var previous_location = other_location
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
		var other_player = parent._get_player(parent.get_other_player(my_id))
		if other_player.strike_stat_boosts.ignore_push_and_pull:
			events += [parent.create_event(Enums.EventType.EventType_Strike_IgnoredPushPull, other_player.my_id, 0)]
		else:
			var other_player_location = other_player.arena_location
			var previous_location = other_player_location
			var new_location
			if arena_location < other_player_location:
				new_location = other_player_location - amount
				if arena_location >= new_location:
					new_location -= 1
				new_location = max(new_location, MinArenaLocation)
				if arena_location == new_location:
					new_location += 1
			else:
				new_location = other_player_location + amount
				if arena_location <= new_location:
					new_location += 1
				new_location = min(new_location, MaxArenaLocation)
				if arena_location == new_location:
					new_location -= 1

			other_player.arena_location = new_location
			events += [parent.create_event(Enums.EventType.EventType_Move, other_player.my_id, new_location, "pull", amount, previous_location)]

		return events

	func pull_not_past(amount):
		var events = []
		var other_player = parent._get_player(parent.get_other_player(my_id))
		if other_player.strike_stat_boosts.ignore_push_and_pull:
			events += [parent.create_event(Enums.EventType.EventType_Strike_IgnoredPushPull, other_player.my_id, 0)]
		else:
			var other_player_location = other_player.arena_location
			var previous_location = other_player_location
			var new_location
			if arena_location < other_player_location:
				new_location = other_player_location - amount
				new_location = max(new_location, arena_location + 1)
			else:
				new_location = other_player_location + amount
				new_location = min(new_location, arena_location - 1)

			other_player.arena_location = new_location
			events += [parent.create_event(Enums.EventType.EventType_Move, other_player.my_id, new_location, "pull", amount, previous_location)]

		return events

	func add_to_continuous_boosts(card : GameCard):
		var events = []
		for boost_card in continuous_boosts:
			if boost_card.id == card.id:
				assert(false, "Should not have boost already here.")
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
		parent._append_log("%s boost %s added to gauge." % [name, parent.card_db.get_card_name(card_id)])
		cleanup_boost_to_gauge_cards.append(card_id)

	func on_cancel_boost():
		var events = []
		events += [parent.create_event(Enums.EventType.EventType_Boost_Canceled, my_id, 0)]
		
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
		var sustained_cards : Array[GameCard] = []
		for boost_card in continuous_boosts:
			if boost_card.id in cleanup_boost_to_gauge_cards:
				events += add_to_gauge(boost_card)
				parent._append_log("%s continuous boost %s added to gauge." % [name, parent.card_db.get_card_name(boost_card.id)])
			else:
				if boost_card.id in sustained_boosts:
					sustained_cards.append(boost_card)
					parent._append_log("%s continuous boost %s sustained." % [name, parent.card_db.get_card_name(boost_card.id)])
				else:
					events += add_to_discards(boost_card)
					parent._append_log("%s continuous boost %s discarded from play." % [name, parent.card_db.get_card_name(boost_card.id)])
		continuous_boosts = sustained_cards
		sustained_boosts = []
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

	func get_set_strike_effects() -> Array:
		var effects = []

		# Maybe later get them from boosts, but for now, just character ability.
		effects = get_character_effects_at_timing("set_strike")

		return effects

var player : Player
var opponent : Player

var active_turn_player : Enums.PlayerId
var next_turn_player : Enums.PlayerId

func get_active_player() -> Enums.PlayerId:
	return active_turn_player

var random_number_generator : RandomNumberGenerator = RandomNumberGenerator.new()

func shuffle_array(arr) -> void:
	var n = arr.size()
	for i in range(n - 1, 0, -1):
		var j = get_random_int() % (i + 1)
		var temp = arr[j]
		arr[j] = arr[i]
		arr[i] = temp

func get_random_int() -> int:
	return random_number_generator.randi()

func get_random_int_range(from : int, to : int) -> int:
	return random_number_generator.randi_range(from, to)

func initialize_game(player_deck, opponent_deck, player_name : String, opponent_name : String, first_player : Enums.PlayerId, seed_value : int):
	random_number_generator.seed = seed_value
	card_db = CardDatabase.new()
	var player_card_id_start = 100
	var opponent_card_id_start = 200
	if first_player == Enums.PlayerId.PlayerId_Opponent:
		player_card_id_start = 200
		opponent_card_id_start = 100
	player = Player.new(Enums.PlayerId.PlayerId_Player, player_name, self, card_db, player_deck, player_card_id_start)
	opponent = Player.new(Enums.PlayerId.PlayerId_Opponent, opponent_name, self, card_db, opponent_deck, opponent_card_id_start)

	active_turn_player = first_player
	next_turn_player = get_other_player(first_player)
	var starting_player = _get_player(active_turn_player)
	var second_player = _get_player(next_turn_player)
	starting_player.arena_location = 3
	second_player.arena_location = 7
	starting_player.initial_shuffle()
	second_player.initial_shuffle()

func draw_starting_hands_and_begin():
	var events = []
	var starting_player = _get_player(active_turn_player)
	var second_player = _get_player(next_turn_player)
	_append_log("Game Start - %s (1st) vs %s (2nd)" % [starting_player.name, second_player.name])
	events += starting_player.draw(StartingHandFirstPlayer + starting_player.starting_hand_size_bonus)
	events += second_player.draw(StartingHandSecondPlayer + second_player.starting_hand_size_bonus)
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
	player.pre_strike_movement = 0
	opponent.pre_strike_movement = 0
	player.used_character_action = false
	opponent.used_character_action = false

	var player_ending_turn = _get_player(active_turn_player)
	var other_player = _get_player(get_other_player(active_turn_player))

	active_turn_player = next_turn_player
	next_turn_player = get_other_player(active_turn_player)

	# Handle any end of turn boost effects.
	# Iterate in reverse as items can be removed.
	var starting_turn_player = _get_player(active_turn_player)
	for i in range(len(starting_turn_player.continuous_boosts) - 1, -1, -1):
		var card = starting_turn_player.continuous_boosts[i]
		for effect in card.definition['boost']['effects']:
			if effect['timing'] == "start_of_next_turn":
				if is_effect_condition_met(starting_turn_player, effect, null):
					events += handle_strike_effect(card.id, effect, starting_turn_player)

	# Handle any end of turn exceed.
	if player_ending_turn.exceed_at_end_of_turn:
		events += player_ending_turn.exceed()
		player_ending_turn.exceed_at_end_of_turn = false
	if other_player.exceed_at_end_of_turn:
		events += other_player.exceed()
		other_player.exceed_at_end_of_turn = false

	if game_over:
		change_game_state(Enums.GameState.GameState_GameOver)
	else:
		_append_log("%s Turn Start" % [starting_turn_player.name])
		change_game_state(Enums.GameState.GameState_PickAction)
		events += [create_event(Enums.EventType.EventType_AdvanceTurn, active_turn_player, 0)]
	return events

func initialize_new_strike():
	active_strike = Strike.new()
	active_strike.strike_state = StrikeState.StrikeState_Initiator_SetEffects
	active_strike.effects_resolved_in_timing = 0

	player.strike_stat_boosts.clear()
	opponent.strike_stat_boosts.clear()

	active_strike.starting_distance = abs(player.arena_location - opponent.arena_location)

func continue_setup_strike(events):
	if active_strike.strike_state == StrikeState.StrikeState_Initiator_SetEffects:
		var initiator_set_strike_effects = active_strike.initiator.get_set_strike_effects()
		while active_strike.effects_resolved_in_timing < initiator_set_strike_effects.size():
			var effect = initiator_set_strike_effects[active_strike.effects_resolved_in_timing]
			if is_effect_condition_met(active_strike.initiator, effect, null):
				events += handle_strike_effect(-1, effect, active_strike.initiator)
			if game_state == Enums.GameState.GameState_PlayerDecision:
				return events

			active_strike.effects_resolved_in_timing += 1

		# All effects resolved, move to next state.
		var defender = _get_player(get_other_player(active_strike.initiator.my_id))
		active_strike.effects_resolved_in_timing = 0
		active_strike.strike_state = StrikeState.StrikeState_Defender_SetEffects
		change_game_state(Enums.GameState.GameState_Strike_Opponent_Response)
		var ask_for_response = true
		if active_strike.initiator.force_opponent_respond_wild_swing():
			events += [create_event(Enums.EventType.EventType_Strike_ForceWildSwing, active_strike.initiator.my_id, 0)]
			# Queue any events so far, then empty this tally and call do_strike.
			event_queue += events
			events = []
			do_strike(defender, -1, true, -1)
			ask_for_response = false
		elif defender.reading_card_id:
			# The Reading effect goes here and will either force the player to strike
			# with the named card or to reveal their hand.
			var reading_card = defender.get_reading_card_in_hand()
			if reading_card:
				# TODO: Potentially they can EX here.
				# Queue any events so far, then empty this tally and call do_strike.
				event_queue += events
				events = []
				do_strike(defender, reading_card.id, false, -1)
				ask_for_response = false
			else:
				events += defender.reveal_hand()
		if ask_for_response:
			events += [create_event(Enums.EventType.EventType_Strike_DoResponseNow, defender.my_id, 0)]
	elif active_strike.strike_state == StrikeState.StrikeState_Defender_SetEffects:
		var defender_set_strike_effects = active_strike.defender.get_set_strike_effects()
		while active_strike.effects_resolved_in_timing < defender_set_strike_effects.size():
			var effect = defender_set_strike_effects[active_strike.effects_resolved_in_timing]
			if is_effect_condition_met(active_strike.defender, effect, null):
				events += handle_strike_effect(-1, effect, active_strike.defender)
			if game_state == Enums.GameState.GameState_PlayerDecision:
				return events
			active_strike.effects_resolved_in_timing += 1

		# All effects resolved, move to next state.
		active_strike.effects_resolved_in_timing = 0
		events += begin_resolve_strike()
	return events

func begin_resolve_strike():
	var events = []
	# Strike is beginning, setup has been completed.
	active_strike.in_setup = false
	events += [create_event(Enums.EventType.EventType_Strike_Reveal, active_strike.initiator.my_id, 0)]
	var initiator_name = active_strike.initiator.name
	var defender_name = active_strike.defender.name
	var initiator_card = card_db.get_card_name(active_strike.initiator_card.id)
	var defender_card = card_db.get_card_name(active_strike.defender_card.id)
	var initiator_ex = ""
	if active_strike.initiator_ex_card != null:
		initiator_ex = "EX "
	var defender_ex = ""
	if active_strike.defender_ex_card != null:
		defender_ex = "EX "
	_append_log("Strike Reveal - %s %s%s vs %s %s%s." % [initiator_name, initiator_ex, initiator_card, defender_name, defender_ex, defender_card])

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
	var first_player_name = active_strike.initiator.name
	var first_player_card = card_db.get_card_name(active_strike.initiator_card.id)
	var first_player_speed = initiator_speed
	var second_player_speed = defender_speed
	if not active_strike.initiator_first:
		first_player_name = active_strike.defender.name
		first_player_card = card_db.get_card_name(active_strike.defender_card.id)
		first_player_speed = defender_speed
		second_player_speed = initiator_speed

	_append_log("%s %s activates first at speed %s vs speed %s." % [first_player_name, first_player_card, first_player_speed, second_player_speed])

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
		elif condition == "initiated_at_range":
			var range_min = effect['range_min']
			var range_max = effect['range_max']
			var initiated_strike = active_strike.initiator == performing_player
			var starting_distance = active_strike.starting_distance
			return initiated_strike and starting_distance >= range_min and starting_distance <= range_max
		elif condition == "initiated_after_moving":
			var initiated_strike = active_strike.initiator == performing_player
			var required_amount = effect['condition_amount']
			return initiated_strike and performing_player.pre_strike_movement >= required_amount
		elif condition == "is_normal_attack":
			return active_strike.get_player_card(performing_player).definition['type'] == "normal"
		elif condition == "is_special_attack":
			return active_strike.get_player_card(performing_player).definition['type'] == "special"
		elif condition == "is_ex_strike":
			return active_strike.will_be_ex(performing_player)
		elif condition == "at_edge_of_arena":
			return performing_player.arena_location == MaxArenaLocation or performing_player.arena_location == MinArenaLocation
		elif condition == "boost_in_play":
			return performing_player.continuous_boosts.size() > 0
		elif condition == "canceled_this_turn":
			return performing_player.canceled_this_turn
		elif condition == "not_canceled_this_turn":
			return not performing_player.canceled_this_turn
		elif condition == "used_character_action":
			return performing_player.used_character_action
		elif condition == "not_full_close":
			return  not local_conditions.fully_closed
		elif condition == "advanced_through":
			return local_conditions.advanced_through
		elif condition == "not_advanced_through":
			return not local_conditions.advanced_through
		elif condition == "not_full_push":
			return not local_conditions.fully_pushed
		elif condition == "pulled_past":
			return local_conditions.pulled_past
		elif condition == "exceeded":
			return performing_player.exceeded
		elif condition == "max_cards_in_hand":
			var amount = effect['condition_amount']
			return performing_player.hand.size() <= amount
		elif condition == "opponent_stunned":
			return active_strike.is_player_stunned(other_player)
		elif condition == "range":
			var amount = effect['condition_amount']
			var distance = abs(performing_player.arena_location - other_player.arena_location)
			return amount == distance
		elif condition == "was_hit":
			return performing_player.strike_stat_boosts.was_hit
		else:
			assert(false, "Unimplemented condition")
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
	if 'character_effect' in effect and effect['character_effect']:
		performing_player.strike_stat_boosts.active_character_effects.append(effect)
		events += [create_event(Enums.EventType.EventType_Strike_CharacterEffect, performing_player.my_id, card_id, "", effect)]
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
			var card_name = card_db.get_card_name(card_id)
			_append_log("%s - %s goes to gauge." % [performing_player.name, card_name])
			active_boost.cleanup_to_gauge_card_ids.append(card_id)
		"add_to_gauge_immediately":
			var card = card_db.get_card(card_id)
			_append_log("%s Start of turn card %s goes to gauge." % [performing_player.name, card_db.get_card_name(card.id)])
			events += performing_player.remove_from_continuous_boosts(card, true)
		"add_to_gauge_immediately_mid_strike_undo_effects":
			var card = card_db.get_card(card_id)
			_append_log("%s added %s to gauge." % [performing_player.name, card_db.get_card_name(card.id)])
			events += performing_player.remove_from_continuous_boosts(card, true)
			if 'undo_effect' in effect:
				var undo_effect = effect['undo_effect']
				if undo_effect == "dodge_at_range":
					performing_player.strike_stat_boosts.dodge_at_range_min = -1
					performing_player.strike_stat_boosts.dodge_at_range_max = -1
					_append_log("%s is no longer dodging attacks from %s." % [performing_player.name, card_db.get_card_name(card.id)])
		"add_top_deck_to_gauge":
			events += performing_player.add_top_deck_to_gauge()
		"advance":
			var previous_location = performing_player.arena_location
			events += performing_player.advance(effect['amount'])
			var new_location = performing_player.arena_location
			if (performing_start < other_start and new_location > other_start) or (performing_start > other_start and new_location < other_start):
				local_conditions.advanced_through = true
			_append_log("%s Advance %s - Moved from %s to %s." % [performing_player.name, str(effect['amount']), str(previous_location), str(new_location)])
		"armorup":
			performing_player.strike_stat_boosts.armor += effect['amount']
			events += [create_event(Enums.EventType.EventType_Strike_ArmorUp, performing_player.my_id, effect['amount'])]
		"attack_is_ex":
			performing_player.strike_stat_boosts.set_ex()
			events += [create_event(Enums.EventType.EventType_Strike_ExUp, performing_player.my_id, card_id)]
		"bonus_action":
			active_boost.action_after_boost = true
		"boost_then_sustain":
			var allow_gauge = 'allow_gauge' in effect and effect['allow_gauge']
			if performing_player.can_boost_something(allow_gauge, effect['limitation']):
				events += [create_event(Enums.EventType.EventType_ForceStartBoost, performing_player.my_id, 0, "", allow_gauge, effect['limitation'])]
				change_game_state(Enums.GameState.GameState_WaitForBoost)
				decision_info.type = Enums.DecisionType.DecisionType_BoostNow
				decision_info.player = performing_player.my_id
				decision_info.allow_gauge = allow_gauge
				decision_info.limitation = effect['limitation']
				performing_player.sustain_next_boost = true
		"boost_then_strike":
			var allow_gauge = 'allow_gauge' in effect and effect['allow_gauge']
			if performing_player.can_boost_something(allow_gauge, effect['limitation']):
				events += [create_event(Enums.EventType.EventType_ForceStartBoost, performing_player.my_id, 0, "", allow_gauge, effect['limitation'])]
				change_game_state(Enums.GameState.GameState_WaitForBoost)
				decision_info.type = Enums.DecisionType.DecisionType_BoostNow
				decision_info.player = performing_player.my_id
				decision_info.allow_gauge = allow_gauge
				decision_info.limitation = effect['limitation']
				performing_player.strike_on_boost_cleanup = true
			else:
				events += [create_event(Enums.EventType.EventType_ForceStartStrike, performing_player.my_id, 0)]
				change_game_state(Enums.GameState.GameState_WaitForStrike)
				decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
				decision_info.player = performing_player.my_id
		"choice":
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.type = Enums.DecisionType.DecisionType_EffectChoice
			decision_info.player = performing_player.my_id
			decision_info.choice = effect['choice']
			decision_info.choice_card_id = card_id
			events += [create_event(Enums.EventType.EventType_Strike_EffectChoice, performing_player.my_id, 0, "EffectOption")]
		"choose_discard":
			var choice_count = performing_player.get_discard_count_of_type(effect['limitation'])
			if choice_count > 0:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.type = Enums.DecisionType.DecisionType_ChooseFromDiscard
				decision_info.player = performing_player.my_id
				decision_info.choice_card_id = card_id
				decision_info.limitation = effect['limitation']
				decision_info.destination = effect['destination']
				var amount = 1
				if 'amount' in effect:
					amount = min(choice_count, effect['amount'])
				decision_info.amount = amount
				decision_info.amount_min = amount
				if 'amount_min' in effect:
					decision_info.amount_min = effect['amount_min']
				events += [create_event(Enums.EventType.EventType_ChooseFromDiscard, performing_player.my_id, amount)]
		"close":
			var previous_location = performing_player.arena_location
			events += performing_player.close(effect['amount'])
			var new_location = performing_player.arena_location
			var close_amount = abs(performing_start - new_location)
			local_conditions.fully_closed = close_amount == effect['amount']
			_append_log("%s Close %s - Moved from %s to %s." % [performing_player.name, str(effect['amount']), str(previous_location), str(new_location)])
		"discard_this":
			var card = card_db.get_card(card_id)
			_append_log("%s Start of turn card %s goes to discard." % [performing_player.name, card_db.get_card_name(card.id)])
			events += performing_player.remove_from_continuous_boosts(card, false)
		"dodge_at_range":
			performing_player.strike_stat_boosts.dodge_at_range_min = effect['range_min']
			performing_player.strike_stat_boosts.dodge_at_range_max = effect['range_max']
			events += [create_event(Enums.EventType.EventType_Strike_DodgeAttacksAtRange, performing_player.my_id, effect['range_min'], "", effect['range_max'])]
			_append_log("%s is now dodging attacks at range %s-%s." % [performing_player.name, str(effect['range_min']), str(effect['range_max'])])
		"dodge_attacks":
			performing_player.strike_stat_boosts.dodge_attacks = true
			events += [create_event(Enums.EventType.EventType_Strike_DodgeAttacks, performing_player.my_id, 0)]
			_append_log("%s is now dodging attacks." % [performing_player.name])
		"draw":
			events += performing_player.draw(effect['amount'])
		"discard_continuous_boost":
			var my_boosts = performing_player.continuous_boosts
			var opponent_boosts = opposing_player.continuous_boosts
			if len(my_boosts) > 0 or len(opponent_boosts) > 0:
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
			if performing_player.is_card_in_continuous_boosts(boost_to_discard_id):
				events += performing_player.remove_from_continuous_boosts(card, false)
			else:
				events += opposing_player.remove_from_continuous_boosts(card, false)
		"discard_hand":
			_append_log("%s discards hand." % [performing_player.name])
			events += performing_player.discard_hand()
		"discard_opponent_gauge":
			if opposing_player.gauge.size() > 0:
				# Player gets to pick which gauge to discard.
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.type = Enums.DecisionType.DecisionType_ChooseDiscardOpponentGauge
				decision_info.effect_type = "discard_opponent_gauge_INTERNAL"
				decision_info.choice_card_id = card_id
				decision_info.player = performing_player.my_id
				decision_info.amount = effect['amount2']
				events += [create_event(Enums.EventType.EventType_Boost_DiscardOpponentGauge, performing_player.my_id, 0)]
		"discard_opponent_gauge_INTERNAL":
			var chosen_card_id = effect['card_id']
			events += opposing_player.discard([chosen_card_id])
		"exceed_end_of_turn":
			performing_player.exceed_at_end_of_turn = true
		"force_for_effect":
			var available_force = performing_player.get_available_force()
			var can_do_something = false
			if effect['per_force_effect'] and available_force > 0:
				can_do_something = true
			elif effect['overall_effect'] and available_force >= effect['force_max']:
				can_do_something = true
			if can_do_something:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.player = performing_player.my_id
				decision_info.type = Enums.DecisionType.DecisionType_ForceForEffect
				decision_info.choice_card_id = card_id
				decision_info.effect = effect
				events += [create_event(Enums.EventType.EventType_ForceForEffect, performing_player.my_id, 0)]
		"gauge_for_effect":
			var available_gauge = performing_player.get_available_gauge()
			var can_do_something = false
			if effect['per_gauge_effect'] and available_gauge > 0:
				can_do_something = true
			elif effect['overall_effect'] and available_gauge >= effect['gauge_max']:
				can_do_something = true
			if can_do_something:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.player = performing_player.my_id
				decision_info.type = Enums.DecisionType.DecisionType_GaugeForEffect
				decision_info.choice_card_id = card_id
				decision_info.effect = effect
				events += [create_event(Enums.EventType.EventType_GaugeForEffect, performing_player.my_id, 0)]
		"gain_advantage":
			next_turn_player = performing_player.my_id
			events += [create_event(Enums.EventType.EventType_Strike_GainAdvantage, performing_player.my_id, 0)]
			_append_log("%s gains Advantage." % [performing_player.name])
		"gauge_from_hand":
			if len(performing_player.hand) > 0:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.type = Enums.DecisionType.DecisionType_CardFromHandToGauge
				decision_info.player = performing_player.my_id
				decision_info.choice_card_id = card_id
				var min_amount = effect['min_amount']
				var max_amount = effect['max_amount']
				decision_info.effect = {
					"min_amount": min_amount,
					"max_amount": max_amount,
				}
				events += [create_event(Enums.EventType.EventType_CardFromHandToGauge_Choice, performing_player.my_id, min_amount, "", max_amount)]
		"guardup":
			performing_player.strike_stat_boosts.guard += effect['amount']
			events += [create_event(Enums.EventType.EventType_Strike_GuardUp, performing_player.my_id, effect['amount'])]
		"ignore_armor":
			performing_player.strike_stat_boosts.ignore_armor = true
		"ignore_guard":
			performing_player.strike_stat_boosts.ignore_guard = true
		"ignore_push_and_pull":
			performing_player.strike_stat_boosts.ignore_push_and_pull = true
		"look_at_top_opponent_deck":
			events += opposing_player.reveal_topdeck()
		"lose_all_armor":
			performing_player.strike_stat_boosts.lose_all_armor = true
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
		"opponent_cant_move_past":
			performing_player.strike_stat_boosts.opponent_cant_move_past = true
			events += [create_event(Enums.EventType.EventType_Strike_OpponentCantMovePast, performing_player.my_id, 0)]
			_append_log("%s is blocking opponent from advancing past." % [performing_player.name])
		"opponent_discard_choose":
			if opposing_player.hand.size() > effect['amount']:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.type = Enums.DecisionType.DecisionType_ChooseToDiscard
				decision_info.effect_type = "opponent_discard_choose_internal"
				decision_info.effect = effect
				decision_info.choice_card_id = card_id
				decision_info.player = opposing_player.my_id
				events += [create_event(Enums.EventType.EventType_Strike_ChooseToDiscard, opposing_player.my_id, effect['amount'])]
			else:
				events += [create_event(Enums.EventType.EventType_Strike_ChooseToDiscard_Info, opposing_player.my_id, effect['amount'])]
				# Forced to discard whole hand.
				var card_ids = []
				for card in opposing_player.hand:
					card_ids.append(card.id)
				events += opposing_player.discard(card_ids)
		"opponent_discard_choose_internal":
			var cards = effect['card_ids']
			events += performing_player.discard(cards)
		"opponent_discard_hand":
			_append_log("%s discards hand." % [opposing_player.name])
			events += opposing_player.discard_hand()
		"opponent_discard_random":
			events += opposing_player.discard_random(effect['amount'])
		"pass":
			# Do nothing.
			pass
		"powerup":
			performing_player.strike_stat_boosts.power += effect['amount']
			events += [create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, effect['amount'])]
		"powerup_per_boosts_in_play":
			var boosts_in_play = performing_player.continuous_boosts.size()
			if boosts_in_play > 0:
				performing_player.strike_stat_boosts.power += effect['amount'] * boosts_in_play
				events += [create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, effect['amount'] * boosts_in_play)]
		"powerup_damagetaken":
			var power_per_damage = effect['amount']
			var total_powerup = power_per_damage * active_strike.get_damage_taken(performing_player)
			if total_powerup > 0:
				performing_player.strike_stat_boosts.power += total_powerup
				events += [create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, total_powerup)]
		"powerup_opponent":
			opposing_player.strike_stat_boosts.power += effect['amount']
			events += [create_event(Enums.EventType.EventType_Strike_PowerUp, opposing_player.my_id, effect['amount'])]
		"pull":
			var previous_location = opposing_player.arena_location
			events += performing_player.pull(effect['amount'])
			var new_location = opposing_player.arena_location
			if (other_start < performing_start and new_location > performing_start) or (other_start > performing_start and new_location < performing_start):
				local_conditions.pulled_past = true
			_append_log("%s Pull %s - %s moved from %s to %s." % [performing_player.name, str(effect['amount']), _get_player(get_other_player(performing_player.my_id)).name, str(previous_location), str(new_location)])
		"pull_not_past":
			var previous_location = opposing_player.arena_location
			events += performing_player.pull_not_past(effect['amount'])
			var new_location = opposing_player.arena_location
			_append_log("%s Pull %s (without pulling past) - %s moved from %s to %s." % [performing_player.name, str(effect['amount']), _get_player(get_other_player(performing_player.my_id)).name, str(previous_location), str(new_location)])
		"push":
			var previous_location = opposing_player.arena_location
			events += performing_player.push(effect['amount'])
			var new_location = opposing_player.arena_location
			var push_amount = abs(other_start - new_location)
			local_conditions.fully_pushed = push_amount == effect['amount']
			_append_log("%s Push %s - %s moved from %s to %s." % [performing_player.name, str(effect['amount']), _get_player(get_other_player(performing_player.my_id)).name, str(previous_location), str(new_location)])
		"rangeup":
			performing_player.strike_stat_boosts.min_range += effect['amount']
			performing_player.strike_stat_boosts.max_range += effect['amount2']
			events += [create_event(Enums.EventType.EventType_Strike_RangeUp, performing_player.my_id, effect['amount'], "", effect['amount2'])]
		"rangeup_per_boost_in_play":
			var boosts_in_play = performing_player.continuous_boosts.size()
			if boosts_in_play > 0:
				performing_player.strike_stat_boosts.min_range += effect['amount'] * boosts_in_play
				performing_player.strike_stat_boosts.max_range += effect['amount2'] * boosts_in_play
				events += [create_event(Enums.EventType.EventType_Strike_RangeUp, performing_player.my_id, effect['amount'] * boosts_in_play, "", effect['amount2'] * boosts_in_play)]
		"reading_normal":
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.type = Enums.DecisionType.DecisionType_ReadingNormal
			decision_info.effect_type = "reading_normal_internal"
			decision_info.choice_card_id = card_id
			decision_info.player = performing_player.my_id
			events += [create_event(Enums.EventType.EventType_ReadingNormal, performing_player.my_id, 0)]
		"reading_normal_internal":
			var named_card = card_db.get_card(effect['card_id'])
			# named_card is the individual card but
			# this should discard "by name", so instead of using that
			# match card.definition['id']'s instead.
			opposing_player.next_strike_with_or_reveal(named_card.definition['id'])
		"retreat":
			var previous_location = performing_player.arena_location
			events += performing_player.retreat(effect['amount'])
			var new_location = performing_player.arena_location
			var retreat_amount = abs(performing_start - new_location)
			local_conditions.fully_retreated = retreat_amount == effect['amount']
			_append_log("%s Retreat %s - Moved from %s to %s." % [performing_player.name, str(effect['amount']), str(previous_location), str(new_location)])
		"return_all_cards_gauge_to_hand":
			var card_names = ""
			for card in performing_player.gauge:
				card_names += card_db.get_card_name(card.id) + ", "
			if card_names:
				card_names = card_names.substr(0, card_names.length() - 2)
			_append_log("%s - Returned cards %s from gauge to hand." % [performing_player.name, card_names])
			events += performing_player.return_all_cards_gauge_to_hand()
		"return_this_to_hand":
			var card_name = card_db.get_card_name(card_id)
			_append_log("%s - %s returned to hand." % [performing_player.name, card_name])
			if active_strike:
				performing_player.strike_stat_boosts.return_attack_to_hand = true
			if active_boost:
				active_boost.cleanup_to_hand_card_ids.append(card_id)
		"revert":
			events += performing_player.revert_exceed()
		"self_discard_choose":
			if performing_player.hand.size() > effect['amount']:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.type = Enums.DecisionType.DecisionType_ChooseToDiscard
				decision_info.effect_type = "self_discard_choose_internal"
				decision_info.effect = effect
				decision_info.choice_card_id = card_id
				decision_info.player = performing_player.my_id
				events += [create_event(Enums.EventType.EventType_Strike_ChooseToDiscard, performing_player.my_id, effect['amount'])]
			else:
				events += [create_event(Enums.EventType.EventType_Strike_ChooseToDiscard_Info, performing_player.my_id, effect['amount'])]
				# Forced to discard whole hand.
				var card_ids = []
				for card in performing_player.hand:
					card_ids.append(card.id)
				events += performing_player.discard(card_ids)
		"self_discard_choose_internal":
			var cards = effect['card_ids']
			events += performing_player.discard(cards)
		"specials_invalid":
			performing_player.specials_invalid = effect['enabled']
		"speedup":
			performing_player.strike_stat_boosts.speed += effect['amount']
			events += [create_event(Enums.EventType.EventType_Strike_SpeedUp, performing_player.my_id, effect['amount'])]
		"strike":
			events += [create_event(Enums.EventType.EventType_ForceStartStrike, performing_player.my_id, 0)]
			change_game_state(Enums.GameState.GameState_WaitForStrike)
			decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
			decision_info.player = performing_player.my_id
		"strike_faceup":
			events += [create_event(Enums.EventType.EventType_ForceStartStrike, performing_player.my_id, 0)]
			change_game_state(Enums.GameState.GameState_WaitForStrike)
			decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
			decision_info.player = performing_player.my_id
			performing_player.next_strike_faceup = true
		"stun_immunity":
			performing_player.strike_stat_boosts.stun_immunity = true
		"sustain_this":
			performing_player.sustained_boosts.append(card_id)
			events += [create_event(Enums.EventType.EventType_SustainBoost, performing_player.my_id, card_id)]
		"take_nonlethal_damage":
			var damage = effect['amount']
			if damage >= performing_player.life:
				damage = performing_player.life - 1
			performing_player.life -= damage
			if active_strike:
				active_strike.add_damage_taken(performing_player, damage)
			_append_log("%s takes %s non-lethal damage. Life is now %s." % [performing_player.name, str(damage), str(performing_player.life)])
			events += [create_event(Enums.EventType.EventType_Strike_TookDamage, performing_player.my_id, damage)]
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

func get_striking_card_ids_for_player(check_player : Player) -> Array:
	var card_ids = []
	if active_strike:
		if active_strike.initiator == check_player:
			if active_strike.initiator_card:
				card_ids.append(active_strike.initiator_card.definition['id'])
			if active_strike.initiator_ex_card:
				card_ids.append(active_strike.initiator_ex_card.definition['id'])
		elif active_strike.defender == check_player:
			if active_strike.defender_card:
				card_ids.append(active_strike.defender_card.definition['id'])
			if active_strike.defender_ex_card:
				card_ids.append(active_strike.defender_ex_card.definition['id'])
	return card_ids

func get_boost_effects_at_timing(timing_name : String, performing_player : Player):
	var effects = []
	for boost_card in performing_player.continuous_boosts:
		for effect in boost_card.definition['boost']['effects']:
			if effect['timing'] == timing_name:
				var effect_with_id = effect.duplicate(true)
				effect_with_id['card_id'] = boost_card.id
				effects.append(effect_with_id)
	return effects

func get_all_effects_for_timing(timing_name : String, performing_player : Player, card : GameCard) -> Array:
	var effects = card_db.get_card_effects_at_timing(card, timing_name)
	for effect in effects:
		effect['card_id'] = card.id
	var boost_effects = get_boost_effects_at_timing(timing_name, performing_player)
	var character_effects = performing_player.get_character_effects_at_timing(timing_name)
	for effect in character_effects:
		effect['card_id'] = card.id
	var all_effects = []
	for effect in effects:
		if is_effect_condition_met(performing_player, effect, null):
			all_effects.append(effect)
	for effect in boost_effects:
		if is_effect_condition_met(performing_player, effect, null):
			all_effects.append(effect)
	for effect in character_effects:
		if is_effect_condition_met(performing_player, effect, null):
			all_effects.append(effect)
	return all_effects

func do_remaining_effects(performing_player : Player, next_state):
	var events = []
	while active_strike.remaining_effect_list.size() > 0:
		var remaining_effect_count = active_strike.remaining_effect_list.size()
		if remaining_effect_count > 1:
			# Send choice to player
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.type = Enums.DecisionType.DecisionType_ChooseSimultaneousEffect
			decision_info.player = performing_player.my_id
			decision_info.choice = active_strike.remaining_effect_list
			events += [create_event(Enums.EventType.EventType_Strike_EffectChoice, performing_player.my_id, 0, "EffectOrder")]
			break
		else:
			var effect = active_strike.remaining_effect_list[0]
			active_strike.remaining_effect_list = []
			if is_effect_condition_met(performing_player, effect, null):
				events += handle_strike_effect(effect['card_id'], effect, performing_player)

	if active_strike.remaining_effect_list.size() == 0 and not game_state == Enums.GameState.GameState_PlayerDecision:
		active_strike.effects_resolved_in_timing = 0
		active_strike.strike_state = next_state
	return events

func do_effects_for_timing(timing_name : String, performing_player : Player, card : GameCard, next_state):
	var events = []
	var effects = card_db.get_card_effects_at_timing(card, timing_name)
	var boost_effects = get_boost_effects_at_timing(timing_name, performing_player)
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
			if is_effect_condition_met(performing_player, effect, null):
				events += handle_strike_effect(effect['card_id'], effect, performing_player)
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
	if defending_player.strike_stat_boosts.dodge_at_range_min != -1:
		if defending_player.strike_stat_boosts.dodge_at_range_min <= distance and distance <= defending_player.strike_stat_boosts.dodge_at_range_max:
			return false
	if min_range <= distance and distance <= max_range:
		return true
	return false

func calculate_damage(offense_player : Player, defense_player : Player, offense_card : GameCard, defense_card : GameCard) -> int:
	var damage = offense_card.definition['power'] + offense_player.strike_stat_boosts.power
	var armor = defense_card.definition['armor'] + defense_player.strike_stat_boosts.armor
	if offense_player.strike_stat_boosts.ignore_armor or defense_player.strike_stat_boosts.lose_all_armor:
		armor = 0
	var damage_after_armor = max(damage - armor, 0)
	return damage_after_armor

func apply_damage(offense_player : Player, defense_player : Player, offense_card : GameCard, defense_card : GameCard):
	var events = []
	var damage = offense_card.definition['power'] + offense_player.strike_stat_boosts.power
	var armor = defense_card.definition['armor'] + defense_player.strike_stat_boosts.armor
	var guard = defense_card.definition['guard'] + defense_player.strike_stat_boosts.guard

	defense_player.strike_stat_boosts.was_hit = true

	if offense_player.strike_stat_boosts.ignore_guard:
		guard = 0
	if offense_player.strike_stat_boosts.ignore_armor or defense_player.strike_stat_boosts.lose_all_armor:
		armor = 0

	var damage_after_armor = calculate_damage(offense_player, defense_player, offense_card, defense_card)
	defense_player.life -= damage_after_armor
	active_strike.add_damage_taken(defense_player, damage_after_armor)

	_append_log("%s %s has %s total power." % [offense_player.name, card_db.get_card_name(offense_card.id), str(damage)])
	_append_log("%s %s has %s total armor and %s total guard." % [defense_player.name, card_db.get_card_name(defense_card.id), str(armor), str(guard)])
	_append_log("%s takes %s damage. Life is now %s." % [defense_player.name, str(damage_after_armor), str(defense_player.life)])
	events += [create_event(Enums.EventType.EventType_Strike_TookDamage, defense_player.my_id, damage_after_armor)]
	if damage_after_armor > guard:
		if defense_player.strike_stat_boosts.stun_immunity:
			_append_log("%s has stun immunity." % [defense_player.name])
			events += [create_event(Enums.EventType.EventType_Strike_Stun_Immunity, defense_player.my_id, defense_card.id)]
		else:
			_append_log("%s is stunned." % [defense_player.name])
			events += [create_event(Enums.EventType.EventType_Strike_Stun, defense_player.my_id, defense_card.id)]
			active_strike.set_player_stunned(defense_player)

	if defense_player.life <= 0:
		_append_log("%s is defeated." % [defense_player.name])
		events += trigger_game_over(defense_player.my_id, Enums.GameOverReason.GameOverReason_Life)
	return events

func ask_for_cost(performing_player, card, next_state):
	var events = []
	var gauge_cost = card.definition['gauge_cost']
	var is_ex = active_strike.will_be_ex(performing_player)
	if 'gauge_cost_ex' in card.definition and is_ex:
		gauge_cost = card.definition['gauge_cost_ex']
	var force_cost = card.definition['force_cost']
	var is_special = card.definition['type'] == "special"
	
	var card_forced_invalid = (is_special and performing_player.specials_invalid)
	if gauge_cost == 0 and force_cost == 0 and not card_forced_invalid:
		active_strike.strike_state = next_state
	else:
		if not card_forced_invalid and performing_player.can_pay_cost(force_cost, gauge_cost):
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.player = performing_player.my_id
			if active_strike.get_player_wild_strike(performing_player):
				decision_info.type = Enums.DecisionType.DecisionType_PayStrikeCost_CanWild
			else:
				decision_info.type = Enums.DecisionType.DecisionType_PayStrikeCost_Required

			if gauge_cost > 0:
				decision_info.cost = gauge_cost
				events += [create_event(Enums.EventType.EventType_Strike_PayCost_Gauge, performing_player.my_id, card.id)]
			elif force_cost > 0:
				decision_info.cost = force_cost
				events += [create_event(Enums.EventType.EventType_Strike_PayCost_Force, performing_player.my_id, card.id)]
		else:
			# Failed to pay the cost by default.
			events += performing_player.add_to_discards(card)
			var new_wild_card = null
			while new_wild_card == null:
				events += performing_player.wild_strike(true);
				if game_over:
					return events
				new_wild_card = active_strike.get_player_card(performing_player)
				is_special = new_wild_card.definition['type'] == "special"
				card_forced_invalid = (is_special and performing_player.specials_invalid)
				if card_forced_invalid:
					events += performing_player.add_to_discards(new_wild_card)
					new_wild_card = null
			events += [create_event(Enums.EventType.EventType_Strike_PayCost_Unable, performing_player.my_id, new_wild_card.id)]
	return events

func do_hit_response_effects(offense_player : Player, defense_player : Player, incoming_damage : int, next_state : StrikeState):
	# If more of these are added, need to sequence them to ensure all handled correctly.
	var events = []
	active_strike.strike_state = next_state
	if not offense_player.strike_stat_boosts.ignore_armor and defense_player.strike_stat_boosts.when_hit_force_for_armor:
		change_game_state(Enums.GameState.GameState_PlayerDecision)
		decision_info.player = defense_player.my_id
		decision_info.type = Enums.DecisionType.DecisionType_ForceForArmor
		decision_info.choice_card_id = active_strike.get_player_card(defense_player).id
		events += [create_event(Enums.EventType.EventType_Strike_ForceForArmor, defense_player.my_id, incoming_damage)]
	return events

func log_boosts_in_play():
	var card_names = "None"
	if len(active_strike.initiator.continuous_boosts) > 0:
		card_names = card_db.get_card_name(active_strike.initiator.continuous_boosts[0].id)
		for i in range(1, active_strike.initiator.continuous_boosts.size()):
			var card = active_strike.initiator.continuous_boosts[i]
			card_names += ", " + card_db.get_card_name(card.id)
	_append_log("%s boosts in play: %s" % [active_strike.initiator.name, card_names])
	card_names = "None"
	if len(active_strike.defender.continuous_boosts) > 0:
		card_names = card_db.get_card_name(active_strike.defender.continuous_boosts[0].id)
		for i in range(1, active_strike.defender.continuous_boosts.size()):
			var card = active_strike.defender.continuous_boosts[i]
			card_names += ", " + card_db.get_card_name(card.id)
	_append_log("%s boosts in play: %s" % [active_strike.defender.name, card_names])

func continue_resolve_strike():
	if active_strike.in_setup:
		return continue_setup_strike([])

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
				log_boosts_in_play()
				events += do_effects_for_timing("during_strike", active_strike.initiator, active_strike.initiator_card, StrikeState.StrikeState_DuringStrikeBonuses)
				# Should never be interrupted by player decisions.
				events += do_effects_for_timing("during_strike", active_strike.defender, active_strike.defender_card, StrikeState.StrikeState_Card1_Activation)
				strike_determine_order()
			StrikeState.StrikeState_Card1_Activation:
				_append_log("%s %s activates." % [player1.name, card_db.get_card_name(card1.id)])
				events += [create_event(Enums.EventType.EventType_Strike_CardActivation, active_strike.get_player(1).my_id, card1.id)]
				active_strike.strike_state = StrikeState.StrikeState_Card1_Before
				active_strike.remaining_effect_list = get_all_effects_for_timing("before", player1, card1)
			StrikeState.StrikeState_Card1_Before:
				events += do_remaining_effects(player1, StrikeState.StrikeState_Card1_DetermineHit)
				#events += do_effects_for_timing("before", player1, card1, StrikeState.StrikeState_Card1_DetermineHit)
			StrikeState.StrikeState_Card1_DetermineHit:
				_append_log("Range Check: %s (%s) vs %s (%s)." % [player1.name, player1.arena_location, player2.name, player2.arena_location])
				if in_range(player1, player2, card1):
					_append_log("%s %s hits." % [player1.name, card_db.get_card_name(card1.id)])
					active_strike.player1_hit = true
					active_strike.strike_state = StrikeState.StrikeState_Card1_Hit
					active_strike.remaining_effect_list = get_all_effects_for_timing("hit", player1, card1)
				else:
					_append_log("%s %s misses." % [player1.name, card_db.get_card_name(card1.id)])
					events += [create_event(Enums.EventType.EventType_Strike_Miss, player1.my_id, 0)]
					active_strike.strike_state = StrikeState.StrikeState_Card1_After
					active_strike.remaining_effect_list = get_all_effects_for_timing("after", player1, card1)
			StrikeState.StrikeState_Card1_Hit:
				events += do_remaining_effects(player1, StrikeState.StrikeState_Card1_Hit_Response)
				#events += do_effects_for_timing("hit", player1, card1, StrikeState.StrikeState_Card1_Hit_Response)
			StrikeState.StrikeState_Card1_Hit_Response:
				var incoming_damage = calculate_damage(player1, player2, card1, card2)
				events += do_hit_response_effects(player1, player2, incoming_damage, StrikeState.StrikeState_Card1_ApplyDamage)
			StrikeState.StrikeState_Card1_ApplyDamage:
				events += apply_damage(player1, player2, card1, card2)
				active_strike.strike_state = StrikeState.StrikeState_Card1_After
				active_strike.remaining_effect_list = get_all_effects_for_timing("after", player1, card1)
				if game_over:
					active_strike.strike_state = StrikeState.StrikeState_Cleanup
			StrikeState.StrikeState_Card1_After:
				events += do_remaining_effects(player1, StrikeState.StrikeState_Card2_Activation)
				#events += do_effects_for_timing("after", player1, card1, StrikeState.StrikeState_Card2_Activation)
			StrikeState.StrikeState_Card2_Activation:
				if active_strike.player2_stunned:
					_append_log("%s is stunned. %s does not activate." % [player2.name, card_db.get_card_name(card2.id)])
					active_strike.strike_state = StrikeState.StrikeState_Cleanup
				else:
					_append_log("%s %s activates." % [player2.name, card_db.get_card_name(card2.id)])
					events += [create_event(Enums.EventType.EventType_Strike_CardActivation, active_strike.get_player(2).my_id, card2.id)]
					active_strike.strike_state = StrikeState.StrikeState_Card2_Before
					active_strike.remaining_effect_list = get_all_effects_for_timing("before", player2, card2)
			StrikeState.StrikeState_Card2_Before:
				events += do_remaining_effects(player2, StrikeState.StrikeState_Card2_DetermineHit)
				#events += do_effects_for_timing("before", player2, card2, StrikeState.StrikeState_Card2_DetermineHit)
			StrikeState.StrikeState_Card2_DetermineHit:
				_append_log("Range Check: %s (%s) vs %s (%s)." % [player2.name, player2.arena_location, player1.name, player1.arena_location])
				if in_range(player2, player1, card2):
					_append_log("%s %s hits." % [player2.name, card_db.get_card_name(card2.id)])
					active_strike.player2_hit = true
					active_strike.strike_state = StrikeState.StrikeState_Card2_Hit
					active_strike.remaining_effect_list = get_all_effects_for_timing("hit", player2, card2)
				else:
					_append_log("%s %s misses." % [player2.name, card_db.get_card_name(card2.id)])
					events += [create_event(Enums.EventType.EventType_Strike_Miss, player2.my_id, 0)]
					active_strike.strike_state = StrikeState.StrikeState_Card2_After
					active_strike.remaining_effect_list = get_all_effects_for_timing("after", player2, card2)
			StrikeState.StrikeState_Card2_Hit:
				events += do_remaining_effects(player2, StrikeState.StrikeState_Card2_Hit_Response)
				#events += do_effects_for_timing("hit", player2, card2, StrikeState.StrikeState_Card2_Hit_Response)
			StrikeState.StrikeState_Card2_Hit_Response:
				var incoming_damage = calculate_damage(player2, player1, card2, card1)
				events += do_hit_response_effects(player2, player1, incoming_damage, StrikeState.StrikeState_Card2_ApplyDamage)
			StrikeState.StrikeState_Card2_ApplyDamage:
				events += apply_damage(player2, player1, card2, card1)
				active_strike.strike_state = StrikeState.StrikeState_Card2_After
				active_strike.remaining_effect_list = get_all_effects_for_timing("after", player2, card2)
				if game_over:
					active_strike.strike_state = StrikeState.StrikeState_Cleanup
			StrikeState.StrikeState_Card2_After:
				events += do_remaining_effects(player2, StrikeState.StrikeState_Cleanup)
				#events += do_effects_for_timing("after", player2, card2, StrikeState.StrikeState_Cleanup)
			StrikeState.StrikeState_Cleanup:
				active_strike.strike_state = StrikeState.StrikeState_Cleanup_Player1Effects
				active_strike.remaining_effect_list = get_all_effects_for_timing("cleanup", player1, card1)
			StrikeState.StrikeState_Cleanup_Player1Effects:
				events += do_remaining_effects(player1, StrikeState.StrikeState_Cleanup_Player1EffectsComplete)
			StrikeState.StrikeState_Cleanup_Player1EffectsComplete:
				active_strike.strike_state = StrikeState.StrikeState_Cleanup_Player2Effects
				active_strike.remaining_effect_list = get_all_effects_for_timing("cleanup", player2, card2)
			StrikeState.StrikeState_Cleanup_Player2Effects:
				events += do_remaining_effects(player2, StrikeState.StrikeState_Cleanup_Complete)
			StrikeState.StrikeState_Cleanup_Complete:
				# If hit, move card to gauge, otherwise move to discard.
				if player1.strike_stat_boosts.return_attack_to_hand:
					events += player1.add_to_hand(card1)
				elif active_strike.player1_hit or player1.strike_stat_boosts.always_add_to_gauge:
					_append_log("%s %s goes to gauge after the attack." % [player1.name, card_db.get_card_name(card1.id)])
					events += player1.add_to_gauge(card1)
				else:
					_append_log("%s %s discarded after the attack." % [player1.name, card_db.get_card_name(card1.id)])
					events += player1.add_to_discards(card1)

				if player2.strike_stat_boosts.return_attack_to_hand:
					events += player2.add_to_hand(card2)
				elif active_strike.player2_hit or player2.strike_stat_boosts.always_add_to_gauge:
					_append_log("%s %s goes to gauge after the attack." % [player2.name, card_db.get_card_name(card2.id)])
					events += player2.add_to_gauge(card2)
				else:
					_append_log("%s %s discarded after the attack." % [player2.name, card_db.get_card_name(card2.id)])
					events += player2.add_to_discards(card2)

				# Discard any EX cards
				if active_strike.initiator_ex_card != null:
					events += active_strike.initiator.add_to_discards(active_strike.initiator_ex_card)
				if active_strike.defender_ex_card != null:
					events += active_strike.defender.add_to_discards(active_strike.defender_ex_card)

				# Remove any Reading effects
				player1.reading_card_id = ""
				player2.reading_card_id = ""

				# Cleanup any continuous boosts.
				events += player1.cleanup_continuous_boosts()
				events += player2.cleanup_continuous_boosts()

				# Remove all stat boosts.
				player.strike_stat_boosts.clear()
				opponent.strike_stat_boosts.clear()
				
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

	if game_state == Enums.GameState.GameState_WaitForStrike:
		active_boost.strike_after_boost = true
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
		elif active_boost.effects_resolved < len(effects) + 1:
			# After all effects are resolved, discard/move the card then check for cancel.
			events += boost_finish_resolving_card(active_boost.playing_player)
			active_boost.effects_resolved += 1
			if active_boost.playing_player.can_cancel(active_boost.card) and not active_boost.strike_after_boost:
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

func boost_finish_resolving_card(performing_player : Player):
	var events = []
	# All boost immediate/now effects are done.
	# If continuous, add to player.
	# If immediate, add to discard.
	if active_boost.card.definition['boost']['boost_type'] == "continuous":
		events += performing_player.add_to_continuous_boosts(active_boost.card)
		if performing_player.sustain_next_boost:
			performing_player.sustain_next_boost = false
			performing_player.sustained_boosts.append(active_boost.card.id)
	else:
		if active_boost.card.id in active_boost.cleanup_to_gauge_card_ids:
			events += performing_player.add_to_gauge(active_boost.card)
		elif active_boost.card.id in active_boost.cleanup_to_hand_card_ids:
			events += performing_player.add_to_hand(active_boost.card)
		else:
			events += performing_player.add_to_discards(active_boost.card)

	if game_state == Enums.GameState.GameState_WaitForStrike:
		active_boost.strike_after_boost = true
	return events

func boost_play_cleanup(performing_player : Player):
	var events = []

	if performing_player.strike_on_boost_cleanup:
		performing_player.strike_on_boost_cleanup = false
		active_boost.strike_after_boost = true
		events += [create_event(Enums.EventType.EventType_ForceStartStrike, performing_player.my_id, 0)]
		decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
		decision_info.player = performing_player.my_id

	if active_boost.strike_after_boost:
		change_game_state(Enums.GameState.GameState_WaitForStrike)
	elif active_boost.action_after_boost:
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

	return true

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
	if game_state != Enums.GameState.GameState_PickAction and game_state != Enums.GameState.GameState_WaitForBoost:
		return false
	if active_turn_player != performing_player.my_id and game_state != Enums.GameState.GameState_WaitForBoost:
		return false

	return true

func can_do_strike(performing_player : Player):
	if game_state == Enums.GameState.GameState_WaitForStrike and decision_info.player == performing_player.my_id:
		return true
	if game_state != Enums.GameState.GameState_PickAction:
		return false
	if active_turn_player != performing_player.my_id:
		return false

	# Can always wild swing!

	return true

func check_hand_size_advance_turn(performing_player : Player):
	var events = []
	if len(performing_player.hand) > performing_player.max_hand_size:
		change_game_state(Enums.GameState.GameState_DiscardDownToMax)
		events += [create_event(Enums.EventType.EventType_HandSizeExceeded, performing_player.my_id, len(performing_player.hand) - performing_player.max_hand_size)]
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
	_append_log("%s Turn Action - Prepare - Now %s cards in hand." % [performing_player.name, str(performing_player.hand.size())])
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

	if len(performing_player.hand) - len(card_ids) > performing_player.max_hand_size:
		printlog("ERROR: Not discarding enough cards")
		return false

	var card_names = card_db.get_card_name(card_ids[0])
	for i in range(1, card_ids.size()):
		card_names += ", " + card_db.get_card_name(card_ids[i])
	_append_log("%s discarded %s to get to max hand size." % [performing_player.name, card_names])

	var events = performing_player.discard(card_ids)
	events += advance_to_next_turn()

	event_queue += events
	return true

func do_reshuffle(performing_player : Player) -> bool:
	printlog("MainAction: RESHUFFLE by %s" % [performing_player.name])
	if not can_do_reshuffle(performing_player):
		printlog("ERROR: Tried to reshuffle but can't.")
		return false

	_append_log("%s Turn Action - Manual Reshuffle." % [performing_player.name])
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
	var card_names = card_db.get_card_name(card_ids[0])
	for i in range(1, card_ids.size()):
		card_names += ", " + card_db.get_card_name(card_ids[i])
	_append_log("%s Turn Action - Move - to position %s by generating force with %s." % [performing_player.name, str(new_arena_location), card_names])
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
	_append_log("%s Turn Action - Change Cards - for %s and now has %s cards." % [performing_player.name, str(force_generated), str(performing_player.hand.size())])
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

	_append_log("%s Turn Action - Exceed" % [performing_player.name])
	var events = performing_player.discard(card_ids)
	events += performing_player.exceed()
	if game_state != Enums.GameState.GameState_WaitForStrike and game_state != Enums.GameState.GameState_PlayerDecision:
		events += performing_player.draw(1)
		events += check_hand_size_advance_turn(performing_player)
	else:
		# Some other player action will result in the end turn finishing.
		active_exceed = true
	event_queue += events
	return true

func do_boost(performing_player : Player, card_id : int) -> bool:
	printlog("MainAction: BOOST by %s - %s" % [get_player_name(performing_player.my_id), card_db.get_card_id(card_id)])
	if game_state != Enums.GameState.GameState_PickAction or performing_player.my_id != active_turn_player:
		if game_state != Enums.GameState.GameState_WaitForBoost:
			printlog("ERROR: Tried to boost but not your turn")
			return false

	_append_log("%s Turn Action - Boost - %s." % [performing_player.name, card_db.get_card_name(card_id)])
	var events = []
	events += begin_resolve_boost(performing_player, card_id)
	event_queue += events
	return true

func do_strike(performing_player : Player, card_id : int, wild_strike: bool, ex_card_id : int) -> bool:
	printlog("MainAction: STRIKE by %s card %s wild %s" % [get_player_name(performing_player.my_id), card_db.get_card_id(card_id), str(wild_strike)])
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
			initialize_new_strike()
			active_strike.initiator = performing_player
			if wild_strike:
				_append_log("%s Turn Action - Strike - Wild Swing" % [performing_player.name])
				events += performing_player.wild_strike()
				if game_over:
					event_queue += events
					return true
				card_id = active_strike.initiator_card.id
			else:
				active_strike.initiator_card = card_db.get_card(card_id)
				performing_player.remove_card_from_hand(card_id)
				if ex_card_id != -1:
					_append_log("%s Turn Action - Strike - EX" % [performing_player.name])
					active_strike.initiator_ex_card = card_db.get_card(ex_card_id)
					performing_player.remove_card_from_hand(ex_card_id)
				else:
					_append_log("%s Turn Action - Strike" % [performing_player.name])
			active_strike.defender = _get_player(get_other_player(performing_player.my_id))

			var reveal_immediately = false
			if active_strike.initiator.next_strike_faceup:
				reveal_immediately = true
				active_strike.initiator.next_strike_faceup = false

			# Send the EX first as that is visual and logic is triggered off the regular one.
			if ex_card_id != -1:
				events += [create_event(Enums.EventType.EventType_Strike_Started_Ex, performing_player.my_id, ex_card_id, "", reveal_immediately)]
			events += [create_event(Enums.EventType.EventType_Strike_Started, performing_player.my_id, card_id, "", reveal_immediately)]
			events = continue_setup_strike(events)
		Enums.GameState.GameState_Strike_Opponent_Response:
			if wild_strike:
				_append_log("%s Strike Response - Wild Swing" % [performing_player.name])
				events += performing_player.wild_strike()
				if game_over:
					event_queue += events
					return true
				card_id = active_strike.defender_card.id
			else:
				active_strike.defender_card = card_db.get_card(card_id)
				performing_player.remove_card_from_hand(card_id)
				if ex_card_id != -1:
					_append_log("%s Strike Response - EX" % [performing_player.name])
					active_strike.defender_ex_card = card_db.get_card(ex_card_id)
					performing_player.remove_card_from_hand(ex_card_id)
				else:
					_append_log("%s Strike Response" % [performing_player.name])
			# Send the EX first as that is visual and logic is triggered off the regular one.
			if ex_card_id != -1:
				events += [create_event(Enums.EventType.EventType_Strike_Response_Ex, performing_player.my_id, ex_card_id)]
			events += [create_event(Enums.EventType.EventType_Strike_Response, performing_player.my_id, card_id)]
			events = continue_setup_strike(events)
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
		var force_cost = card.definition['force_cost']
		var gauge_cost = card.definition['gauge_cost']
		var is_ex = active_strike.will_be_ex(performing_player)
		if 'gauge_cost_ex' in card.definition and is_ex:
			gauge_cost = card.definition['gauge_cost_ex']
		if performing_player.can_pay_cost(force_cost, gauge_cost):
			printlog("ERROR: Tried to wild strike when not allowed.")
			return false
	if decision_info.player != performing_player.my_id:
		printlog("ERROR: Tried to pay costs for wrong player.")
		return false

	var events = []
	var card = active_strike.get_player_card(performing_player)
	if wild_strike:
		_append_log("%s did a wild swing instead of validating %s." % [performing_player.name, card_db.get_card_name(card.id)])
		# Replace existing card with a wild strike
		var current_card = active_strike.get_player_card(performing_player)
		events += performing_player.add_to_discards(current_card)
		events += performing_player.wild_strike(true)
	else:
		var force_cost = card.definition['force_cost']
		var gauge_cost = card.definition['gauge_cost']
		var is_ex = active_strike.will_be_ex(performing_player)
		if 'gauge_cost_ex' in card.definition and is_ex:
			gauge_cost = card.definition['gauge_cost_ex']
		if performing_player.can_pay_cost_with(card_ids, force_cost, gauge_cost):
			var card_names = card_db.get_card_name(card_ids[0])
			for i in range(1, card_ids.size()):
				card_names += ", " + card_db.get_card_name(card_ids[0])
			_append_log("%s paid for %s with %s." % [performing_player.name, card_db.get_card_name(card.id), card_names])
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
		var card_names = card_db.get_card_name(card_ids[0])
		for i in range(1, card_ids.size()):
			card_names += ", " + card_db.get_card_name(card_ids[i])
		_append_log("%s generated force for armor with %s." % [performing_player.name, card_names])
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
		var card_names = card_db.get_card_name(gauge_card_ids[0])
		for i in range(1, gauge_card_ids.size()):
			card_names += ", " + card_db.get_card_name(gauge_card_ids[i])
		_append_log("%s canceled using %s." % [performing_player.name, card_names])
		events += performing_player.discard(gauge_card_ids)
		events += performing_player.on_cancel_boost()
		active_boost.action_after_boost = true

	# Ky, for example, has a choice after canceling the first time.
	if game_state != Enums.GameState.GameState_PlayerDecision:
		events += boost_play_cleanup(performing_player)

	event_queue += events
	return true

func do_card_from_hand_to_gauge(performing_player : Player, card_ids : Array) -> bool:
	printlog("SubAction: CARD_HAND_TO_GAUGE by %s: %s" % [get_player_name(performing_player.my_id), card_ids])
	if decision_info.player != performing_player.my_id:
		printlog("ERROR: Tried to do_card_from_hand_to_gauge for wrong player.")
		return false
	if game_state != Enums.GameState.GameState_PlayerDecision or decision_info.type != Enums.DecisionType.DecisionType_CardFromHandToGauge:
		printlog("ERROR: Tried to do_card_from_hand_to_gauge but not in decision state.")
		return false
	for card_id in card_ids:
		if not performing_player.is_card_in_hand(card_id):
			printlog("ERROR: Tried to do_card_from_hand_to_gauge with card not in hand.")
			return false
	var events = []
	if card_ids.size() > 0:
		var card_names = card_db.get_card_name(card_ids[0])
		for i in range(1, card_ids.size()):
			card_names += ", " + card_db.get_card_name(card_ids[i])
		_append_log("%s moved cards (%s) from hand to gauge." % [performing_player.name, card_names])
		for card_id in card_ids:
			events += performing_player.move_card_from_hand_to_gauge(card_id)

	if active_strike:
		active_strike.effects_resolved_in_timing += 1
		events += continue_resolve_strike()
	elif active_boost:
		active_boost.effects_resolved += 1
		events += continue_resolve_boost()
	elif active_exceed:
		active_exceed = false
		events += performing_player.draw(1)
		events += check_hand_size_advance_turn(performing_player)
	else:
		# Could be exceeding.
		printlog("ERROR: do_card_from_hand_to_gauge but no active strike or boost.")

	event_queue += events
	return true

func do_boost_name_card_choice_effect(performing_player : Player, card_id : int) -> bool:
	var card_name = card_db.get_card_name(card_id)
	printlog("SubAction: BOOST_NAME_CARD by %s card %s" % [get_player_name(performing_player.my_id), card_name])
	if decision_info.player != performing_player.my_id:
		printlog("ERROR: Tried to name card for wrong player.")
		return false
	if game_state != Enums.GameState.GameState_PlayerDecision:
		printlog("ERROR: Tried to make a choice but not in decision state.")
		return false

	var effect = {
		"effect_type": decision_info.effect_type,
		"card_id": card_id,
	}
	_append_log("%s named %s." % [performing_player.name, card_name])
	game_state = Enums.GameState.GameState_Boost_Processing
	var events = handle_strike_effect(decision_info.choice_card_id, effect, performing_player)
	if active_strike:
		active_strike.effects_resolved_in_timing += 1
		events += continue_resolve_strike()
	elif active_boost:
		active_boost.effects_resolved += 1
		events += continue_resolve_boost()
	event_queue += events
	return true

func do_choice(performing_player : Player, choice_index : int) -> bool:
	printlog("SubAction: CHOICE by %s card %s" % [performing_player.name, str(choice_index)])
	if decision_info.player != performing_player.my_id:
		printlog("ERROR: Tried to name card for wrong player.")
		return false
	if game_state != Enums.GameState.GameState_PlayerDecision:
		printlog("ERROR: Tried to make a choice but not in decision state.")
		return false
	if choice_index >= len(decision_info.choice):
		printlog("ERROR: Tried to make a choice that doesn't exist.")
		return false

	var card_id = decision_info.choice_card_id
	var effect = decision_info.choice[choice_index]
	if 'card_id' in effect:
		card_id = effect['card_id']
	if active_strike:
		game_state = Enums.GameState.GameState_Strike_Processing
	elif active_boost:
		game_state = Enums.GameState.GameState_Boost_Processing

	if decision_info.type == Enums.DecisionType.DecisionType_ChooseSimultaneousEffect:
		# This was the player choosing what to do next.
		# Remove this effect from the remaining effects.
		active_strike.remaining_effect_list.erase(effect)

	var events = handle_strike_effect(card_id, effect, performing_player)
	if game_state != Enums.GameState.GameState_PlayerDecision:
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
	_append_log("%s mulligan for %s cards." % [performing_player.name, str(len(card_ids))])
	if player.mulligan_complete and opponent.mulligan_complete:
		change_game_state(Enums.GameState.GameState_PickAction)
		events += [create_event(Enums.EventType.EventType_AdvanceTurn, active_turn_player, 0)]
	else:
		events += [create_event(Enums.EventType.EventType_MulliganDecision, get_other_player(performing_player.my_id), 0)]
	event_queue += events
	return true

func do_choose_from_discard(performing_player : Player, card_ids : Array) -> bool:
	printlog("SubAction: CHOOSE FROM DISCARD by %s cards: %s" % [performing_player.name, str(card_ids)])
	if game_state != Enums.GameState.GameState_PlayerDecision or decision_info.type != Enums.DecisionType.DecisionType_ChooseFromDiscard:
		printlog("ERROR: Tried to choose from discard but not in correct game state.")
		return false

	# Validation.
	if card_ids.size() < decision_info.amount_min or card_ids.size() > decision_info.amount:
		printlog("ERROR: Tried to choose from discard with wrong number of cards.")
		return false

	for card_id in card_ids:
		if not performing_player.is_card_in_discards(card_id):
			printlog("ERROR: Tried to choose from discard with card not in discard.")
			return false
			
	for card_id in card_ids:
		var card = card_db.get_card(card_id)
		var limitation = decision_info.limitation
		match limitation:
			"special":
				if card.definition['type'] != "special":
					printlog("ERROR: Tried to choose from discard with card that doesn't meet limitation special.")
					return false
			_:
				pass
				
	# Move the cards.
	var events = []
	for card_id in card_ids:
		var destination = decision_info.destination
		match destination:
			"deck":
				events += performing_player.move_card_from_discard_to_deck(card_id)
			"gauge":
				events += performing_player.move_card_from_discard_to_gauge(card_id)
			"hand":
				events += performing_player.move_card_from_discard_to_hand(card_id)
			_:
				printlog("ERROR: Choose from discard destination not implemented.")
				assert(false, "Choose from discard destination not implemented.")
				return false

		_append_log("%s chose %s to put from discard to %s." % [performing_player.name, card_db.get_card_name(card_id), destination])

	if active_strike:
		active_strike.effects_resolved_in_timing += 1
		events += continue_resolve_strike()
	elif active_boost:
		active_boost.effects_resolved += 1
		events += continue_resolve_boost()
	else:
		printlog("ERROR: When is this choose from discard happening?")
		assert(false, "When is this choose from discard happening?")

	event_queue += events
	return true

func do_force_for_effect(performing_player : Player, card_ids : Array) -> bool:
	printlog("SubAction: FORCE_FOR_EFFECT by %s cards %s" % [performing_player.name, card_ids])
	if game_state != Enums.GameState.GameState_PlayerDecision or decision_info.type != Enums.DecisionType.DecisionType_ForceForEffect:
		printlog("ERROR: Tried to force for effect but not in decision state.")
		return false
	if decision_info.player != performing_player.my_id:
		printlog("ERROR: Tried to force for armor for wrong player.")
		return false

	var events = []
	for card_id in card_ids:
		if not performing_player.is_card_in_hand(card_id) and not performing_player.is_card_in_gauge(card_id):
			printlog("ERROR: Tried to force for effect with card not in hand or gauge.")
			return false

	var force_generated = 0
	var ultras = 0
	for card_id in card_ids:
		var force_value = card_db.get_card_force_value(card_id)
		if force_value == 2:
			ultras += 1
		force_generated += force_value

	if force_generated > decision_info.effect['force_max']:
		if force_generated - ultras <= decision_info.effect['force_max']:
			force_generated = decision_info.effect['force_max']
		else:
			printlog("ERROR: Tried to force for effect with too much force.")
			return false
	change_game_state(Enums.GameState.GameState_Strike_Processing)
	if force_generated > 0:
		var card_names = card_db.get_card_name(card_ids[0])
		for i in range(1, card_ids.size()):
			card_names += ", " + card_db.get_card_name(card_ids[i])

		var source_card_name = card_db.get_card_name(decision_info.choice_card_id)
		var effect_text = ""
		var decision_effect = null
		var effect_times = 0
		if decision_info.effect['per_force_effect']:
			decision_effect = decision_info.effect['per_force_effect']
			effect_text = CardDefinitions.get_effect_text(decision_effect, false, false, false, source_card_name) + " per force"
			effect_times = force_generated
		elif decision_info.effect['overall_effect']:
			decision_effect = decision_info.effect['overall_effect']
			effect_text = CardDefinitions.get_effect_text(decision_effect, false, false, false, source_card_name)
			effect_times = 1

		_append_log("%s generated %s force for %s with %s." % [performing_player.name, str(force_generated), effect_text, card_names])
		events += performing_player.discard(card_ids)
		for i in range(0, effect_times):
			events += handle_strike_effect(decision_info.choice_card_id, decision_effect, performing_player)

	if game_state != Enums.GameState.GameState_PlayerDecision:
		if active_strike:
			active_strike.effects_resolved_in_timing += 1
			events += continue_resolve_strike()
		elif active_boost:
			active_boost.effects_resolved += 1
			events += continue_resolve_boost()
		else:
			printlog("ERROR: When is this force for effect happening?")
			assert(false, "When is this force for effect happening?")
	else:
		# Some other effect will result in this continuing.
		pass
	event_queue += events
	return true

func do_gauge_for_effect(performing_player : Player, card_ids : Array) -> bool:
	printlog("SubAction: GAUGE_FOR_EFFECT by %s cards %s" % [performing_player.name, card_ids])
	if game_state != Enums.GameState.GameState_PlayerDecision or decision_info.type != Enums.DecisionType.DecisionType_GaugeForEffect:
		printlog("ERROR: Tried to gauge for effect but not in decision state.")
		return false
	if decision_info.player != performing_player.my_id:
		printlog("ERROR: Tried to gauge for armor for wrong player.")
		return false

	var events = []
	for card_id in card_ids:
		if not performing_player.is_card_in_gauge(card_id):
			printlog("ERROR: Tried to gauge for effect with card not in gauge.")
			return false

	var gauge_generated = len(card_ids)

	if gauge_generated > decision_info.effect['gauge_max']:
		printlog("ERROR: Tried to gauge for effect with too many cards.")
		return false
	change_game_state(Enums.GameState.GameState_Strike_Processing)
	if gauge_generated > 0:
		var card_names = card_db.get_card_name(card_ids[0])
		for i in range(1, card_ids.size()):
			card_names += ", " + card_db.get_card_name(card_ids[i])

		var source_card_name = card_db.get_card_name(decision_info.choice_card_id)
		var effect_text = ""
		var decision_effect = null
		var effect_times = 0
		if decision_info.effect['per_gauge_effect']:
			decision_effect = decision_info.effect['per_gauge_effect']
			effect_text = CardDefinitions.get_effect_text(decision_effect, false, false, false, source_card_name) + " per gauge"
			effect_times = gauge_generated
		elif decision_info.effect['overall_effect']:
			decision_effect = decision_info.effect['overall_effect']
			effect_text = CardDefinitions.get_effect_text(decision_effect, false, false, false, source_card_name)
			effect_times = 1

		_append_log("%s spent %s gauge for %s with %s." % [performing_player.name, str(gauge_generated), effect_text, card_names])
		events += performing_player.discard(card_ids)
		for i in range(0, effect_times):
			events += handle_strike_effect(decision_info.choice_card_id, decision_effect, performing_player)

	if game_state != Enums.GameState.GameState_PlayerDecision:
		if active_strike:
			active_strike.effects_resolved_in_timing += 1
			events += continue_resolve_strike()
		elif active_boost:
			active_boost.effects_resolved += 1
			events += continue_resolve_boost()
		else:
			printlog("ERROR: When is this gauge for effect happening?")
			assert(false, "When is this gauge for effect happening?")
	else:
		# Some other effect will result in this continuing.
		pass
	event_queue += events
	return true

func do_choose_to_discard(performing_player : Player, card_ids):
	var card_names = card_db.get_card_names(card_ids)
	printlog("SubAction: %s choosing to discard %s" % [get_player_name(performing_player.my_id), card_names])
	if decision_info.player != performing_player.my_id:
		printlog("ERROR: Tried to choose to discard for wrong player.")
		return false
	if game_state != Enums.GameState.GameState_PlayerDecision:
		printlog("ERROR: Tried to make a choice but not in decision state.")
		return false

	var amount = decision_info.effect['amount']
	if len(card_ids) != amount and performing_player.hand.size() >= amount:
		printlog("ERROR: Tried to choose to discard wrong number of cards.")
		return false

	for card_id in card_ids:
		if not performing_player.is_card_in_hand(card_id):
			printlog("ERROR: Tried to choose to discard with card not in hand.")
			return false

	var effect = {
		"effect_type": decision_info.effect_type,
		"card_ids": card_ids,
	}
	_append_log("%s discarding chosen cards: %s." % [performing_player.name, card_names])
	var events = []
	if active_strike:
		game_state = Enums.GameState.GameState_Strike_Processing
		events = handle_strike_effect(decision_info.choice_card_id, effect, performing_player)
		active_strike.effects_resolved_in_timing += 1
		events += continue_resolve_strike()
	elif active_boost:
		game_state = Enums.GameState.GameState_Boost_Processing
		events = handle_strike_effect(decision_info.choice_card_id, effect, performing_player)
		active_boost.effects_resolved += 1
		events += continue_resolve_boost()
	event_queue += events
	return true

func do_character_action(performing_player : Player, card_ids):
	printlog("MainAction: CHARACTER_ACTION by %s" % [get_player_name(performing_player.my_id)])
	if game_state != Enums.GameState.GameState_PickAction:
		printlog("ERROR: Tried to character action but not in correct game state.")
		return false

	if performing_player.my_id != active_turn_player:
		printlog("ERROR: Tried to character action but not current player")
		return false

	var action = performing_player.get_character_action()
	var force_cost = action['force_cost']
	var gauge_cost = action['gauge_cost']
	if not performing_player.can_pay_cost_with(card_ids, force_cost, gauge_cost):
		printlog("ERROR: Tried to character action but can't pay cost with these cards.")
		return false

	var events = []
	# Spend the cards used to pay the cost.
	if card_ids.size() > 0:
		var card_names = card_db.get_card_name(card_ids[0])
		for i in range(1, card_ids.size()):
			card_names += ", " + card_db.get_card_name(card_ids[0])
		_append_log("%s paid for character action with %s." % [performing_player.name, card_names])
		events += performing_player.discard(card_ids)

	# Do the character action effects.
	events += [create_event(Enums.EventType.EventType_CharacterAction, performing_player.my_id, 0)]
	performing_player.used_character_action = true
	events += handle_strike_effect(-1, action['effect'], performing_player)
	if game_state != Enums.GameState.GameState_WaitForStrike and game_state != Enums.GameState.GameState_WaitForBoost:
		events += performing_player.draw(1)
		events += check_hand_size_advance_turn(performing_player)
	event_queue += events
	return true

func do_quit(player_id : Enums.PlayerId, reason : Enums.GameOverReason):
	printlog("InitialAction: QUIT by %s" % [get_player_name(player_id)])
	if game_state == Enums.GameState.GameState_GameOver:
		printlog("ERROR: Game already over.")
		return false

	var performing_player = _get_player(player_id)
	_append_log("%s quit." % [performing_player.name])
	var events = []
	events += [create_event(Enums.EventType.EventType_GameOver, player_id, reason)]
	event_queue += events
	return true
