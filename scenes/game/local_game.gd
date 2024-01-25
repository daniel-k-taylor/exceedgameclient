extends Node2D

const Enums = preload("res://scenes/game/enums.gd")
const CardDatabase = preload("res://scenes/game/card_database.gd")
const GameCard = preload("res://scenes/game/game_card.gd")
const DecisionInfo = preload("res://scenes/game/decision_info.gd")

const BuddyStartsOutOfArena = -10
const NullNamedCard = "_"

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
var active_character_action : bool = false
var active_exceed : bool = false
var active_overdrive : bool = false
var remaining_overdrive_effects = []
var remaining_character_action_effects = []

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
	StrikeState_Defender_SetFirst,
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
	var initiator_set_from_gauge : bool = false
	var initiator_set_face_up : bool = false
	var defender_wild_strike : bool = false
	var strike_state
	var starting_distance : int = -1
	var in_setup : bool = true
	var opponent_sets_first : bool = false
	var remaining_effect_list : Array = []
	var effects_resolved_in_timing : int = 0
	var player1_hit : bool = false
	var player1_stunned : bool = false
	var player2_hit : bool = false
	var player2_stunned : bool = false
	var initiator_damage_taken = 0
	var defender_damage_taken = 0
	var remaining_topdeck_boosts = 0
	var remaining_topdeck_boosts_player_id = Enums.PlayerId.PlayerId_Player

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

	func get_player_strike_from_gauge(performing_player : Player) -> bool:
		if performing_player == defender:
			return false
		# ensure that the strike from gauge wasn't invalidated
		return initiator_set_from_gauge and not initiator_wild_strike

	func is_player_stunned(question_player : Player) -> bool:
		if get_player(1) == question_player:
			return player1_stunned
		return player2_stunned

	func set_player_stunned(stunned_player : Player):
		if get_player(1) == stunned_player:
			player1_stunned = true
		else:
			player2_stunned = true

	func did_player_hit_opponent(check_player : Player):
		if get_player(1) == check_player:
			return player1_hit
		return player2_hit

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
	var discard_on_cleanup = false
	var seal_on_cleanup = false
	var cancel_resolved = false
	var cleanup_to_gauge_card_ids = []
	var cleanup_to_hand_card_ids = []

class StrikeStatBoosts:
	var power : int = 0
	var armor : int = 0
	var consumed_armor : int = 0
	var guard : int = 0
	var speed : int = 0
	var strike_x : int = 0
	var min_range : int = 0
	var max_range : int = 0
	var attack_does_not_hit : bool = false
	var dodge_attacks : bool = false
	var dodge_at_range_min : int = -1
	var dodge_at_range_max : int = -1
	var dodge_at_range_from_buddy : bool = false
	var dodge_from_opposite_buddy : bool = false
	var ignore_armor : bool = false
	var ignore_guard : bool = false
	var ignore_push_and_pull : bool = false
	var lose_all_armor : bool = false
	var cannot_stun : bool = false
	var always_add_to_gauge : bool = false
	var return_attack_to_hand : bool = false
	var move_strike_to_boosts : bool = false
	var move_strike_to_opponent_boosts : bool = false
	var when_hit_force_for_armor : bool = false
	var stun_immunity : bool = false
	var was_hit : bool = false
	var is_ex : bool = false
	var higher_speed_misses : bool = false
	var calculate_range_from_buddy : bool = false
	var attack_to_topdeck_on_cleanup : bool = false
	var discard_attack_on_cleanup : bool = false
	var seal_attack_on_cleanup : bool = false
	var power_bonus_multiplier : int = 1
	var speed_bonus_multiplier : int = 1
	var active_character_effects = []
	var added_attack_effects = []
	var ex_count : int = 0
	var critical : bool = false
	var overwrite_printed_power : bool = false
	var overwritten_printed_power : int = 0
	var overwrite_total_power : bool = false
	var overwritten_total_power : int = 0

	func clear():
		power = 0
		armor = 0
		consumed_armor = 0
		guard = 0
		speed = 0
		strike_x = 0
		min_range = 0
		max_range = 0
		attack_does_not_hit = false
		dodge_attacks = false
		dodge_at_range_min = -1
		dodge_at_range_max = -1
		dodge_at_range_from_buddy = false
		dodge_from_opposite_buddy = false
		ignore_armor = false
		ignore_guard = false
		ignore_push_and_pull = false
		lose_all_armor = false
		cannot_stun = false
		always_add_to_gauge = false
		return_attack_to_hand = false
		move_strike_to_boosts = false
		move_strike_to_opponent_boosts = false
		when_hit_force_for_armor = false
		stun_immunity = false
		was_hit = false
		is_ex = false
		higher_speed_misses = false
		calculate_range_from_buddy = false
		attack_to_topdeck_on_cleanup = false
		discard_attack_on_cleanup = false
		seal_attack_on_cleanup = false
		power_bonus_multiplier = 1
		speed_bonus_multiplier = 1
		active_character_effects = []
		added_attack_effects = []
		ex_count = 0
		critical = false
		overwrite_printed_power = false
		overwritten_printed_power = 0
		overwrite_total_power = false
		overwritten_total_power = 0

	func set_ex():
		ex_count += 1
		if not is_ex:
			speed += 1
			power += 1
			armor += 1
			guard += 1
			is_ex = true

	func remove_ex():
		ex_count -= 1
		if ex_count == 0:
			is_ex = false
			speed -= 1
			power -= 1
			armor -= 1
			guard -= 1

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
	var sealed : Array[GameCard]
	var overdrive : Array[GameCard]
	var has_overdrive : bool
	var set_aside_cards : Array[GameCard]
	var deck_def : Dictionary
	var gauge : Array
	var continuous_boosts : Array[GameCard]
	var cleanup_boost_to_gauge_cards : Array[int]
	var boosts_to_gauge_on_move : Array[int]
	var on_buddy_boosts : Array[int]
	var arena_location : int
	var reshuffle_remaining : int
	var exceeded : bool
	var exceed_cost : int
	var strike_stat_boosts : StrikeStatBoosts
	var did_strike_this_turn : bool
	var bonus_actions : int
	var canceled_this_turn : bool
	var cancel_blocked_this_turn : bool
	var used_character_action : bool
	var used_character_action_details : Array
	var used_character_bonus : bool
	var force_spent_before_strike : int
	var exceed_at_end_of_turn : bool
	var specials_invalid : bool
	var mulligan_complete : bool
	var reading_card_id : String
	var next_strike_faceup : bool
	var next_strike_from_gauge : bool
	var next_strike_random_gauge : bool
	var strike_on_boost_cleanup : bool
	var max_hand_size : int
	var starting_hand_size_bonus : int
	var pre_strike_movement : int
	var sustained_boosts : Array[int]
	var sustain_next_boost : bool
	var buddy_starting_offset : int
	var buddy_location : int
	var do_not_cleanup_buddy_this_turn : bool
	var cannot_move : bool
	var cannot_move_past_opponent : bool
	var ignore_push_and_pull : bool
	var extra_effect_after_set_strike
	var end_of_turn_boost_delay_card_ids : Array[int]
	var saved_power : int
	var movement_limit : int

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
		set_aside_cards = []
		for deck_card_def in deck_def['cards']:
			var card_def = CardDefinitions.get_card(deck_card_def['definition_id'])
			var card = GameCard.new(card_start_id, card_def, deck_card_def['image'], id)
			card_database.add_card(card)
			if 'set_aside' in deck_card_def and deck_card_def['set_aside']:
				card.set_aside = true
				card.hide_from_reference = 'hide_from_reference' in deck_card_def and deck_card_def['hide_from_reference']
				set_aside_cards.append(card)
			else:
				deck.append(card)
			deck_list.append(card)
			card_start_id += 1
		gauge = []
		continuous_boosts = []
		discards = []
		sealed = []
		overdrive = []
		has_overdrive = 'exceed_to_overdrive' in deck_def and deck_def['exceed_to_overdrive']
		reshuffle_remaining = MaxReshuffle
		exceeded = false
		did_strike_this_turn = false
		bonus_actions = 0
		canceled_this_turn = false
		cancel_blocked_this_turn = false
		used_character_action = false
		used_character_action_details = []
		used_character_bonus = false
		force_spent_before_strike = 0
		exceed_at_end_of_turn = false
		specials_invalid = false
		cleanup_boost_to_gauge_cards = []
		boosts_to_gauge_on_move = []
		on_buddy_boosts = []
		mulligan_complete = false
		reading_card_id = ""
		next_strike_faceup = false
		next_strike_from_gauge = false
		next_strike_random_gauge = false
		strike_on_boost_cleanup = false
		pre_strike_movement = 0
		sustained_boosts = []
		sustain_next_boost = false
		buddy_starting_offset = BuddyStartsOutOfArena
		buddy_location = -1
		do_not_cleanup_buddy_this_turn = false
		cannot_move = false
		cannot_move_past_opponent = false
		ignore_push_and_pull = false
		extra_effect_after_set_strike = null
		end_of_turn_boost_delay_card_ids = []
		saved_power = 0

		movement_limit = MaxArenaLocation
		if 'movement_limit' in deck_def:
			movement_limit = deck_def['movement_limit']

		max_hand_size = MaxHandSize
		if 'alt_hand_size' in deck_def:
			max_hand_size = deck_def['alt_hand_size']

		starting_hand_size_bonus = 0
		if 'bonus_starting_hand' in deck_def:
			starting_hand_size_bonus = deck_def['bonus_starting_hand']

		if 'buddy_starting_offset' in deck_def:
			buddy_starting_offset = deck_def['buddy_starting_offset']

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

	func get_set_aside_card(card_str_id : String, remove : bool = false):
		for i in range(set_aside_cards.size()):
			var card = set_aside_cards[i]
			if card.definition['id'] == card_str_id:
				if remove:
					set_aside_cards.remove_at(i)
				return card
		return null

	func is_set_aside_card(card_id : int):
		for card in set_aside_cards:
			if card.id == card_id:
				return true
		return false

	func set_end_of_turn_boost_delay(card_id):
		if card_id not in end_of_turn_boost_delay_card_ids:
			end_of_turn_boost_delay_card_ids.append(card_id)

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

	func get_copy_in_hand(definition_id : String):
		for card in hand:
			if card.definition['id'] == definition_id:
				return card.id
		return -1

	func is_card_in_discards(id : int):
		for card in discards:
			if card.id == id:
				return true
		return false

	func is_card_in_sealed(id : int):
		for card in sealed:
			if card.id == id:
				return true
		return false

	func is_card_in_overdrive(id: int):
		for card in overdrive:
			if card.id == id:
				return true
		return false

	func get_overdrive_effect():
		return deck_def['overdrive_effect']

	func remove_card_from_hand(id : int):
		for i in range(len(hand)):
			if hand[i].id == id:
				hand.remove_at(i)
				break

	func remove_card_from_gauge(id : int):
		for i in range(len(gauge)):
			if gauge[i].id == id:
				gauge.remove_at(i)
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

	func move_card_from_gauge_to_hand(id : int):
		var events = []
		for i in range(len(gauge)):
			var card = gauge[i]
			if card.id == id:
				events += add_to_hand(card)
				gauge.remove_at(i)
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

	func shuffle_sealed_to_deck():
		var events = []
		for card in sealed:
			deck.insert(0, card)
			events += [parent.create_event(Enums.EventType.EventType_AddToDeck, my_id, card.id)]
		random_shuffle_deck()
		sealed = []
		return events

	func shuffle_hand_to_deck():
		var events = []
		for card in hand:
			deck.insert(0, card)
			events += [parent.create_event(Enums.EventType.EventType_AddToDeck, my_id, card.id)]
		hand = []
		random_shuffle_deck()
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

	func move_card_from_sealed_to_hand(id : int):
		var events = []
		for i in range(len(sealed)):
			var card = sealed[i]
			if card.id == id:
				events += add_to_hand(card)
				sealed.remove_at(i)
				break
		return events

	func add_top_deck_to_gauge(amount : int):
		var events = []
		for i in range(amount):
			if len(deck) > 0:
				var card = deck[0]
				events += add_to_gauge(card)
				deck.remove_at(0)
				parent._append_log("%s added %s to gauge from top of deck." % [name, parent.card_db.get_card_name(card.id)])
		return events

	func add_top_discard_to_gauge(amount : int):
		var events = []
		for i in range(amount):
			if len(discards) > 0:
				# The top of the discard pile is the end of discards.
				var top_index = len(discards) - 1
				var card = discards[top_index]
				events += add_to_gauge(card)
				discards.remove_at(top_index)
				parent._append_log("%s added %s to gauge from top of discard pile." % [name, parent.card_db.get_card_name(card.id)])
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
				"ultra":
					if card.definition['type'] == "ultra":
						count += 1
				_:
					count += 1
		return count

	func get_sealed_count_of_type(limitation : String):
		var count = 0
		for card in sealed:
			match limitation:
				"special":
					if card.definition['type'] == "special":
						count += 1
				"ultra":
					if card.definition['type'] == "ultra":
						count += 1
				_:
					count += 1
		return count

	func get_cards_in_hand_of_type(limitation : String):
		var cards = []
		for card in hand:
			match limitation:
				"special":
					if card.definition['type'] == "special":
						cards.append(card)
				"ultra":
					if card.definition['type'] == "ultra":
						cards.append(card)
				_:
					cards.append(card)
		return cards

	func get_buddy_name():
		return deck_def['buddy_display_name']

	func is_buddy_in_play():
		return buddy_location != -1

	func get_buddy_location():
		return buddy_location

	func place_buddy(new_location : int):
		var events = []
		var old_buddy_pos = buddy_location
		buddy_location = new_location
		on_position_changed(arena_location, old_buddy_pos)
		events += [parent.create_event(Enums.EventType.EventType_PlaceBuddy, my_id, buddy_location)]
		return events

	func remove_buddy():
		var events = []
		if not do_not_cleanup_buddy_this_turn:
			var old_buddy_pos = buddy_location
			buddy_location = -1
			on_position_changed(arena_location, old_buddy_pos)
			events += [parent.create_event(Enums.EventType.EventType_PlaceBuddy, my_id, buddy_location)]
		return events

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
		if strike_on_boost_cleanup or cancel_blocked_this_turn:
			return false
		if parent.active_strike:
			return false

		var available_gauge = get_available_gauge()
		var cancel_cost = card.definition['boost']['cancel_cost']
		if cancel_cost == -1: return false
		if available_gauge < cancel_cost: return false
		return true

	func get_bonus_actions():
		var actions = parent.get_boost_effects_at_timing("action", self)
		return actions

	func get_character_action(i : int = 0):
		if i > get_character_action_count():
			parent.printlog("ERROR: Character action index out of range")
			return null

		if exceeded and 'character_action_exceeded' in deck_def:
			var actions = deck_def['character_action_exceeded']
			return actions[i]
		elif not exceeded and 'character_action_default' in deck_def:
			var actions = deck_def['character_action_default']
			return actions[i]
		return null

	func get_character_action_count():
		if exceeded and 'character_action_exceeded' in deck_def:
			var actions = deck_def['character_action_exceeded']
			return len(actions)
		elif not exceeded and 'character_action_default' in deck_def:
			var actions = deck_def['character_action_default']
			return len(actions)
		return 0

	func can_do_character_action(action_index : int) -> bool:
		if action_index >= get_character_action_count():
			parent.printlog("ERROR: Character action index out of range")
			return false

		var action = null
		if exceeded and 'character_action_exceeded' in deck_def:
			action = deck_def['character_action_exceeded'][action_index]
		elif not exceeded and 'character_action_default' in deck_def:
			action = deck_def['character_action_default'][action_index]
		else:
			return false

		var gauge_cost = action['gauge_cost']
		var force_cost = action['force_cost']
		if get_available_gauge() < gauge_cost: return false
		if get_available_force() < force_cost: return false

		if 'min_hand_size' in action:
			if len(hand) < action['min_hand_size']: return false

		if 'requires_buddy_in_play' in action and action['requires_buddy_in_play']:
			if not is_buddy_in_play(): return false

		if 'per_turn_limit' in action:
			var limit = action['per_turn_limit']
			var used = 0
			for detail in used_character_action_details:
				if exceeded and detail[0] != "exceed":
					continue
				if not exceeded and detail[0] != "default":
					continue
				if detail[1] == action_index:
					# Player is in correct exceed state and this is the action index.
					used += 1
			if used >= limit:
				return false

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
				events += reshuffle_discard(false)
				if not parent.game_over:
					var card = deck[0]
					hand.append(card)
					deck.remove_at(0)
					events += [parent.create_event(Enums.EventType.EventType_Draw, my_id, card.id)]
		return events

	func add_set_aside_card_to_deck(card_str_id : String):
		var events : Array = []
		var card = get_set_aside_card(card_str_id, true)
		if card:
			deck.insert(0, card)
		return events

	func begin_reshuffle(manual : bool):
		var events : Array = []
		if reshuffle_remaining == 0:
			# Game Over
			parent._append_log("%s ran out of cards." % [name])
			events += parent.trigger_game_over(my_id, Enums.GameOverReason.GameOverReason_Decked)
		else:
			# Prompt other player to review discards
			parent.change_game_state(Enums.GameState.GameState_PlayerDecision)
			parent.decision_info.type = Enums.DecisionType.DecisionType_ReviewReshuffle
			parent.decision_info.source = manual
			events += [parent.create_event(Enums.EventType.EventType_BeginReshuffle, my_id, 0, "", manual)]
		return events

	func reshuffle_discard(manual : bool):
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
			var local_conditions = LocalStrikeConditions.new()
			local_conditions.manual_reshuffle = manual
			var effects = get_character_effects_at_timing("on_reshuffle")
			for effect in effects:
				events += parent.do_effect_if_condition_met(self, -1, effect, local_conditions)
		return events

	func discard(card_ids : Array, special_message : String = ""):
		var events = []
		for discard_id in card_ids:
			# From hand
			for i in range(len(hand)-1, -1, -1):
				var card = hand[i]
				if card.id == discard_id:
					if special_message:
						parent._append_log("%s discarded %s from %s." % [name, parent.card_db.get_card_name(card.id), special_message])
					else:
						parent._append_log("%s discarded %s from hand." % [name, parent.card_db.get_card_name(card.id)])
					hand.remove_at(i)
					events += add_to_discards(card)
					break

			# From gauge
			for i in range(len(gauge)-1, -1, -1):
				var card = gauge[i]
				if card.id == discard_id:
					parent._append_log("%s discarded %s from gauge." % [name, parent.card_db.get_card_name(card.id)])
					gauge.remove_at(i)
					events += add_to_discards(card)
					break

			# From overdrive
			for i in range(len(overdrive)-1, -1, -1):
				var card = overdrive[i]
				if card.id == discard_id:
					parent._append_log("%s discarded %s from overdrive." % [name, parent.card_db.get_card_name(card.id)])
					overdrive.remove_at(i)
					events += add_to_discards(card)
					break
		return events

	func add_to_overdrive(card_ids : Array):
		var events = []
		for card_id in card_ids:
			for i in range(len(gauge)-1, -1, -1):
				var card = gauge[i]
				if card.id == card_id:
					parent._append_log("%s added %s to overdrive." % [name, parent.card_db.get_card_name(card.id)])
					gauge.remove_at(i)
					overdrive.append(card)
					events += [parent.create_event(Enums.EventType.EventType_AddToOverdrive, my_id, card.id)]
					break
		return events

	func seal_from_hand(card_ids : Array):
		var events = []
		for card_id in card_ids:
			for i in range(len(hand)-1, -1, -1):
				var card = hand[i]
				if card.id == card_id:
					parent._append_log("%s sealed %s from hand." % [name, parent.card_db.get_card_name(card.id)])
					hand.remove_at(i)
					sealed.append(card)
					events += [parent.create_event(Enums.EventType.EventType_Seal, my_id, card.id)]
					break
		return events

	func seal_hand():
		var events = []
		var card_ids = []
		for card in hand:
			card_ids.append(card.id)
		events += seal_from_hand(card_ids)
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

	func discard_topdeck():
		var events = []
		if deck.size() > 0:
			var card = deck[0]
			parent._append_log("%s discarded top of deck: %s." % [name, parent.card_db.get_card_name(card.id)])
			deck.remove_at(0)
			events += add_to_discards(card)
		return events

	func next_strike_with_or_reveal(card_definition_id : String) -> void:
		reading_card_id = card_definition_id

	func get_reading_card_in_hand() -> Array:
		var cards = []
		for card in hand:
			if card.definition['id'] == reading_card_id:
				cards.append(card)
		return cards

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

	func discard_random(amount, discard_callback = null):
		var events = []
		var discarded_ids = []
		for i in range(amount):
			if len(hand) > 0:
				var random_card_id = hand[parent.get_random_int() % len(hand)].id
				discarded_ids.append(random_card_id)
				parent._append_log("%s discarded random card %s." % [name, parent.card_db.get_card_name(random_card_id)])
				events += discard([random_card_id])
		if discard_callback:
			discard_callback.call(self, discarded_ids)
		return events

	func invalidate_card(card : GameCard):
		var events = []
		if 'on_invalid' in card.definition:
			var invalid_effect = card.definition['on_invalid']
			events += parent.do_effect_if_condition_met(self, -1, invalid_effect, null)
		return events

	func wild_strike(is_immediate_reveal : bool = false):
		var events = []
		# Get top card of deck (reshuffle if needed)
		if len(deck) == 0:
			events += reshuffle_discard(false)
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

	func random_gauge_strike():
		var events = []
		if len(gauge) == 0:
			parent._append_log("%s has no gauge to strike with; wild swings instead." % [name])
			return wild_strike(true)
		else:
			var random_gauge_idx = parent.get_random_int() % len(gauge)
			var random_card_id = gauge[random_gauge_idx].id
			if parent.active_strike.initiator == self:
				parent.active_strike.initiator_card = gauge[random_gauge_idx]
			else:
				assert(false)
				parent.printlog("ERROR: Random gauge strike by non-initiator")
			parent._append_log("%s strikes with %s from gauge." % [name, parent.card_db.get_card_name(random_card_id)])
			gauge.remove_at(random_gauge_idx)
			parent.active_strike.initiator_set_from_gauge = true
			events += [parent.create_event(Enums.EventType.EventType_Strike_RandomGaugeStrike, my_id, random_card_id, "", true)]
		return events

	func add_to_gauge(card: GameCard):
		gauge.append(card)
		return [parent.create_event(Enums.EventType.EventType_AddToGauge, my_id, card.id)]

	func add_to_discards(card : GameCard):
		if card.owner_id == my_id:
			discards.append(card)
			return [parent.create_event(Enums.EventType.EventType_AddToDiscard, my_id, card.id)]
		else:
			# Card belongs to the other player, so discard it there.
			return parent._get_player(parent.get_other_player(my_id)).add_to_discards(card)

	func add_to_hand(card : GameCard):
		hand.append(card)
		return [parent.create_event(Enums.EventType.EventType_AddToHand, my_id, card.id)]

	func add_to_sealed(card : GameCard):
		sealed.append(card)
		return [parent.create_event(Enums.EventType.EventType_Seal, my_id, card.id)]

	func add_to_top_of_deck(card : GameCard):
		deck.insert(0, card)
		return [parent.create_event(Enums.EventType.EventType_AddToDeck, my_id, card.id)]

	func get_available_force():
		var force = 0
		for card in hand:
			force += card_database.get_card_force_value(card.id)
		for card in gauge:
			force += card_database.get_card_force_value(card.id)
		return force

	func get_available_gauge():
		return len(gauge)

	func can_move_to(new_arena_location, ignore_force_req : bool):
		if cannot_move: return false
		if new_arena_location == arena_location: return false
		var other_player_loc = parent._get_player(parent.get_other_player(my_id)).arena_location
		if  other_player_loc == new_arena_location: return false
		if cannot_move_past_opponent:
			if arena_location < other_player_loc and new_arena_location > other_player_loc:
				return false
			if arena_location > other_player_loc and new_arena_location < other_player_loc:
				return false
		if ignore_force_req:
			return true

		var distance = abs(arena_location - new_arena_location)
		var required_force = get_force_to_move_to(new_arena_location)
		var distance_for_movement_limit_calculation = distance
		if is_other_player_between_locations(arena_location, new_arena_location):
			distance_for_movement_limit_calculation -= 1
		if distance_for_movement_limit_calculation > movement_limit:
			return false
		return required_force <= get_available_force()

	func is_other_player_between_locations(loc1, loc2):
		var other_player_loc = parent._get_player(parent.get_other_player(my_id)).arena_location
		if loc1 < loc2:
			if other_player_loc > loc1 and other_player_loc < loc2:
				return true
		else:
			if other_player_loc > loc2 and other_player_loc < loc1:
				return true
		return false

	func get_force_to_move_to(new_arena_location):
		var other_player_loc = parent._get_player(parent.get_other_player(my_id)).arena_location
		var required_force = abs(arena_location - new_arena_location)
		if ((arena_location < other_player_loc and new_arena_location > other_player_loc)
			or (new_arena_location < other_player_loc and arena_location > other_player_loc)):
			# No additional force needed because of abs calculation.
			#required_force += 1
			pass
		return required_force

	func on_position_changed(old_pos, buddy_old_pos):
		if arena_location == buddy_location:
			if old_pos != buddy_old_pos:
				handle_on_buddy_boosts(true)
		else:
			if old_pos == buddy_old_pos:
				handle_on_buddy_boosts(false)

	func move_to(new_arena_location):
		var events = []

		if cannot_move:
			events += [parent.create_event(Enums.EventType.EventType_BlockMovement, my_id, 0)]
			return events

		var other_player_loc = parent._get_player(parent.get_other_player(my_id)).arena_location
		if cannot_move_past_opponent:
			if arena_location < other_player_loc and new_arena_location > other_player_loc:
				new_arena_location = other_player_loc - 1
			if arena_location > other_player_loc and new_arena_location < other_player_loc:
				new_arena_location = other_player_loc + 1

		var previous_location = arena_location
		var distance = abs(arena_location - new_arena_location)

		var position_changed = arena_location != new_arena_location
		arena_location = new_arena_location
		events += [parent.create_event(Enums.EventType.EventType_Move, my_id, new_arena_location, "move", distance, previous_location)]
		if position_changed:
			on_position_changed(previous_location, buddy_location)
			events += add_boosts_to_gauge_on_move()

		return events

	func close(amount):
		var events = []
		if cannot_move:
			events += [parent.create_event(Enums.EventType.EventType_BlockMovement, my_id, 0)]
			return events

		amount = min(amount, movement_limit)

		var previous_location = arena_location
		var other_location = parent._get_player(parent.get_other_player(my_id)).arena_location
		var new_location
		if arena_location < other_location:
			new_location = min(other_location-1, arena_location+amount)
		else:
			new_location = max(other_location+1, arena_location-amount)
		if not parent.active_strike:
			pre_strike_movement += abs(arena_location - new_location)
		var position_changed = arena_location != new_location
		arena_location = new_location
		events += [parent.create_event(Enums.EventType.EventType_Move, my_id, new_location, "close", amount, previous_location)]
		if position_changed:
			on_position_changed(previous_location, buddy_location)
			events += add_boosts_to_gauge_on_move()

		return events

	func advance(amount):
		var events = []
		if cannot_move:
			events += [parent.create_event(Enums.EventType.EventType_BlockMovement, my_id, 0)]
			return events

		amount = min(amount, movement_limit)

		var previous_location = arena_location
		var other_player_location = parent._get_player(parent.get_other_player(my_id)).arena_location
		var blocked_from_passing = cannot_move_past_opponent
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
		var position_changed = arena_location != new_location
		arena_location = new_location
		events += [parent.create_event(Enums.EventType.EventType_Move, my_id, new_location, "advance", amount, previous_location)]
		if position_changed:
			on_position_changed(previous_location, buddy_location)
			events += add_boosts_to_gauge_on_move()

		return events

	func retreat(amount):
		var events = []
		if cannot_move:
			events += [parent.create_event(Enums.EventType.EventType_BlockMovement, my_id, 0)]
			return events

		amount = min(amount, movement_limit)

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
		var position_changed = arena_location != new_location
		arena_location = new_location
		events += [parent.create_event(Enums.EventType.EventType_Move, my_id, new_location, "retreat", amount, previous_location)]
		if position_changed:
			on_position_changed(previous_location, buddy_location)
			events += add_boosts_to_gauge_on_move()

		return events

	func push(amount):
		var events = []
		var other_player = parent._get_player(parent.get_other_player(my_id))
		if other_player.strike_stat_boosts.ignore_push_and_pull or other_player.ignore_push_and_pull:
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
			other_player.on_position_changed(previous_location, other_player.buddy_location)
			events += [parent.create_event(Enums.EventType.EventType_Move, other_player.my_id, new_location, "push", amount, previous_location)]

		return events

	func pull(amount):
		var events = []
		var other_player = parent._get_player(parent.get_other_player(my_id))
		if other_player.strike_stat_boosts.ignore_push_and_pull or other_player.ignore_push_and_pull:
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
			other_player.on_position_changed(previous_location, other_player.buddy_location)
			events += [parent.create_event(Enums.EventType.EventType_Move, other_player.my_id, new_location, "pull", amount, previous_location)]

		return events

	func pull_not_past(amount):
		var events = []
		var other_player = parent._get_player(parent.get_other_player(my_id))
		if other_player.strike_stat_boosts.ignore_push_and_pull or other_player.ignore_push_and_pull:
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
			other_player.on_position_changed(previous_location, other_player.buddy_location)
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

	func _find_during_strike_effects(card : GameCard):
		var found_effects = []
		for effect in card.definition['boost']['effects']:
			if effect['timing'] == "during_strike":
				found_effects.append(effect)
		var i = 0
		while i < len(found_effects):
			var effect = found_effects[i]
			if 'and' in effect:
				found_effects.append(effect['and'])
			i += 1
		return found_effects

	func reenable_boost_effects(card : GameCard):
		# Redo boost properties
		for effect in card.definition['boost']['effects']:
			if effect['timing'] == "now":
				match effect['effect_type']:
					"ignore_push_and_pull_passive_bonus":
						ignore_push_and_pull = true
		if parent.active_strike:
			# Redo continuous effects
			for effect in _find_during_strike_effects(card):
				if not parent.is_effect_condition_met(self, effect, null):
					# Only redo effects that have conditions met.
					continue

				# May want a "add_remaining_effects" if something using this has before/hit/after triggers
				match effect['effect_type']:
					"attack_is_ex":
						strike_stat_boosts.set_ex()
					"dodge_at_range":
						strike_stat_boosts.dodge_at_range_min = effect['amount']
						strike_stat_boosts.dodge_at_range_max = effect['amount2']
						if effect['from_buddy']:
							strike_stat_boosts.dodge_at_range_from_buddy = effect['from_buddy']
						parent._append_log("%s is now dodging attacks from %s." % [name, parent.card_db.get_card_name(card.id)])
					"powerup":
						strike_stat_boosts.power += effect['amount']
					"armorup":
						strike_stat_boosts.armor += effect['amount']
					"guardup":
						strike_stat_boosts.guard += effect['amount']
					"rangeup":
						strike_stat_boosts.min_range += effect['amount']
						strike_stat_boosts.max_range += effect['amount2']

	func disable_boost_effects(card : GameCard, buddy_ignore_condition : bool = false):
		# Undo boost properties
		for effect in card.definition['boost']['effects']:
			if effect['timing'] == "now":
				match effect['effect_type']:
					"ignore_push_and_pull_passive_bonus":
						ignore_push_and_pull = false
		if parent.active_strike:
			# Undo continuous effects
			for effect in _find_during_strike_effects(card):
				if not buddy_ignore_condition and not parent.is_effect_condition_met(self, effect, null):
					# Only undo effects that were given in the first place.
					continue

				parent.remove_remaining_effect(effect, card.id)
				match effect['effect_type']:
					"attack_is_ex":
						strike_stat_boosts.remove_ex()
					"dodge_at_range":
						strike_stat_boosts.dodge_at_range_min = -1
						strike_stat_boosts.dodge_at_range_max = -1
						strike_stat_boosts.dodge_at_range_from_buddy = false
						parent._append_log("%s is no longer dodging attacks from %s." % [name, parent.card_db.get_card_name(card.id)])
					"powerup":
						strike_stat_boosts.power -= effect['amount']
					"armorup":
						strike_stat_boosts.armor -= effect['amount']
					"guardup":
						strike_stat_boosts.guard -= effect['amount']
					"rangeup":
						strike_stat_boosts.min_range -= effect['amount']
						strike_stat_boosts.max_range -= effect['amount2']

	func remove_from_continuous_boosts(card : GameCard, to_gauge : bool, to_hand : bool = false):
		var events = []
		disable_boost_effects(card)

		# Do any discarded effects
		events += do_discarded_effects_for_boost(card)

		# Add to gauge or discard as appropriate.
		for i in range(len(continuous_boosts)):
			if continuous_boosts[i].id == card.id:
				if to_gauge:
					events += add_to_gauge(card)
				elif to_hand:
					events += add_to_hand(card)
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

	func set_add_boost_to_gauge_on_move(card_id):
		boosts_to_gauge_on_move.append(card_id)

	func set_boost_applies_if_on_buddy(card_id):
		on_buddy_boosts.append(card_id)

	func add_boosts_to_gauge_on_move():
		var events = []
		for card_id in boosts_to_gauge_on_move:
			var card = parent.card_db.get_card(card_id)
			parent._append_log("%s Added card %s to gauge." % [name, parent.card_db.get_card_name(card_id)])
			events += remove_from_continuous_boosts(card, true)
		boosts_to_gauge_on_move = []
		return events

	func handle_on_buddy_boosts(enable):
		for card_id in on_buddy_boosts:
			var card = parent.card_db.get_card(card_id)
			if enable:
				parent._append_log("%s Boost %s re-activated." % [name, parent.card_db.get_card_name(card_id)])
				reenable_boost_effects(card)
			else:
				parent._append_log("%s Boost %s disabled." % [name, parent.card_db.get_card_name(card_id)])
				disable_boost_effects(card, true)

	func on_cancel_boost():
		var events = []
		events += [parent.create_event(Enums.EventType.EventType_Boost_Canceled, my_id, 0)]

		# Create a strike state just to track completing effects at this timing.
		var effects = get_character_effects_at_timing("on_cancel_boost")
		# NOTE: Only 1 choice currently allowed.
		for effect in effects:
			events += parent.do_effect_if_condition_met(self, -1, effect, null)
		canceled_this_turn = true

		return events

	func do_discarded_effects_for_boost(card : GameCard):
		var events = []
		for effect in card.definition['boost']['effects']:
			if effect['timing'] == "discarded":
				var owner_player = parent._get_player(card.owner_id)
				events += parent.handle_strike_effect(card.id, effect, owner_player)
		return events

	func cleanup_continuous_boosts():
		var events = []
		var sustained_cards : Array[GameCard] = []
		for boost_card in continuous_boosts:
			var sustained = false
			if boost_card.id in cleanup_boost_to_gauge_cards:
				events += add_to_gauge(boost_card)
				parent._append_log("%s continuous boost %s added to gauge." % [name, parent.card_db.get_card_name(boost_card.id)])
			else:
				if boost_card.id in sustained_boosts:
					sustained = true
					sustained_cards.append(boost_card)
					parent._append_log("%s continuous boost %s sustained." % [name, parent.card_db.get_card_name(boost_card.id)])
				else:
					events += add_to_discards(boost_card)
					parent._append_log("%s continuous boost %s discarded from play." % [name, parent.card_db.get_card_name(boost_card.id)])
			for boost_array in [boosts_to_gauge_on_move, on_buddy_boosts]:
				var card_idx = boost_array.find(boost_card.id)
				if card_idx != -1 and boost_card.id not in sustained_boosts:
					boost_array.remove_at(card_idx)

			if not sustained:
				events += do_discarded_effects_for_boost(boost_card)
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

	func get_bonus_effects_at_timing(timing_name : String):
		var effects = []
		for effect in strike_stat_boosts.added_attack_effects:
			if effect['timing'] == timing_name:
				effects.append(effect)
		return effects

	func set_strike_x(value : int):
		var events = []
		strike_stat_boosts.strike_x = max(value, 0)
		parent._append_log("%s X for strike set to %s." % [name, value])
		events += [parent.create_event(Enums.EventType.EventType_Strike_SetX, my_id, value)]
		return events

	func get_set_strike_effects(card : GameCard) -> Array:
		var effects = []

		# Maybe later get them from boosts, but for now, just character ability.
		var ignore_condition = false
		effects = parent.get_all_effects_for_timing("set_strike", self, card, ignore_condition)

		if extra_effect_after_set_strike:
			effects.append(extra_effect_after_set_strike)

		return effects

var player : Player
var opponent : Player

var active_turn_player : Enums.PlayerId
var next_turn_player : Enums.PlayerId

var strike_happened_this_turn : bool = false
var last_turn_was_strike : bool = false

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
	if starting_player.buddy_starting_offset != BuddyStartsOutOfArena:
		var buddy_space = 3 + starting_player.buddy_starting_offset
		event_queue += starting_player.place_buddy(buddy_space)
	second_player.arena_location = 7
	if second_player.buddy_starting_offset != BuddyStartsOutOfArena:
		var buddy_space = 7 - second_player.buddy_starting_offset
		event_queue += second_player.place_buddy(buddy_space)
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

	var player_ending_turn = _get_player(active_turn_player)
	var other_player = _get_player(get_other_player(active_turn_player))

	# Do any end of turn character effects.
	var effects = player_ending_turn.get_character_effects_at_timing("end_of_turn")
	for effect in effects:
		events += do_effect_if_condition_met(player_ending_turn, -1, effect, null)

	# Do any end of turn boost effects.
	# Iterate in reverse as items can be removed.
	for i in range(len(player_ending_turn.continuous_boosts) - 1, -1, -1):
		var card = player_ending_turn.continuous_boosts[i]
		for effect in card.definition['boost']['effects']:
			if effect['timing'] == "end_of_turn":
				if card.id in player_ending_turn.end_of_turn_boost_delay_card_ids:
					# This effect is delayed a turn, so remove it from the list and skip it for now.
					player_ending_turn.end_of_turn_boost_delay_card_ids.erase(card.id)
					continue
				events += do_effect_if_condition_met(player_ending_turn, card.id, effect, null)

	# Turn is over, reset state.
	player.did_strike_this_turn = false
	opponent.did_strike_this_turn = false
	player.canceled_this_turn = false
	opponent.canceled_this_turn = false
	player.do_not_cleanup_buddy_this_turn = false
	opponent.do_not_cleanup_buddy_this_turn = false
	player.cancel_blocked_this_turn = false
	opponent.cancel_blocked_this_turn = false
	player.pre_strike_movement = 0
	opponent.pre_strike_movement = 0
	player.used_character_action = false
	opponent.used_character_action = false
	player.used_character_action_details = []
	opponent.used_character_action_details = []
	player.used_character_bonus = false
	opponent.used_character_bonus = false
	player.force_spent_before_strike = 0
	opponent.force_spent_before_strike = 0

	# Update strike turn tracking
	last_turn_was_strike = strike_happened_this_turn
	strike_happened_this_turn = false

	# Figure out next turn's player.
	active_turn_player = next_turn_player
	next_turn_player = get_other_player(active_turn_player)

	# Handle any end of turn exceed.
	if player_ending_turn.exceed_at_end_of_turn:
		events += player_ending_turn.exceed()
		player_ending_turn.exceed_at_end_of_turn = false
	if other_player.exceed_at_end_of_turn:
		events += other_player.exceed()
		other_player.exceed_at_end_of_turn = false

	# Handle any end of turn boost effects.
	# Iterate in reverse as items can be removed.
	var starting_turn_player = _get_player(active_turn_player)
	for i in range(len(starting_turn_player.continuous_boosts) - 1, -1, -1):
		var card = starting_turn_player.continuous_boosts[i]
		for effect in card.definition['boost']['effects']:
			if effect['timing'] == "start_of_next_turn":
				events += do_effect_if_condition_met(starting_turn_player, card.id, effect, null)

	if game_over:
		change_game_state(Enums.GameState.GameState_GameOver)
	else:
		if starting_turn_player.exceeded and starting_turn_player.overdrive.size() > 0:
			# Do overdrive effect.
			var overdrive_effects = [{
				"effect_type": "choose_discard",
				"source": "overdrive",
				"limitation": "",
				"destination": "discard",
				"amount": 1,
				"amount_min": 1
			}]
			overdrive_effects.append(starting_turn_player.get_overdrive_effect())
			if starting_turn_player.overdrive.size() == 1:
				overdrive_effects.append({
					"effect_type": "revert"
				})
			active_overdrive = true
			remaining_overdrive_effects = overdrive_effects
			events += do_remaining_overdrive(starting_turn_player)
		else:
			_append_log("%s Turn Start" % [starting_turn_player.name])
			change_game_state(Enums.GameState.GameState_PickAction)
			events += [create_event(Enums.EventType.EventType_AdvanceTurn, active_turn_player, 0)]
	return events

func initialize_new_strike(performing_player : Player, opponent_sets_first : bool):
	active_strike = Strike.new()
	active_strike.effects_resolved_in_timing = 0

	strike_happened_this_turn = true

	active_strike.opponent_sets_first = opponent_sets_first
	if opponent_sets_first:
		active_strike.strike_state = StrikeState.StrikeState_Defender_SetFirst
	else:
		active_strike.strike_state = StrikeState.StrikeState_Initiator_SetEffects

	player.strike_stat_boosts.clear()
	opponent.strike_stat_boosts.clear()
	player.bonus_actions = 0
	opponent.bonus_actions = 0

	active_strike.starting_distance = abs(player.arena_location - opponent.arena_location)

	active_strike.initiator = performing_player
	active_strike.defender = _get_player(get_other_player(performing_player.my_id))

func continue_setup_strike(events):
	if active_strike.strike_state == StrikeState.StrikeState_Initiator_SetEffects:
		var initiator_set_strike_effects = active_strike.initiator.get_set_strike_effects(active_strike.initiator_card)
		while active_strike.effects_resolved_in_timing < initiator_set_strike_effects.size():
			var effect = initiator_set_strike_effects[active_strike.effects_resolved_in_timing]
			events += do_effect_if_condition_met(active_strike.initiator, -1, effect, null)
			if game_state == Enums.GameState.GameState_PlayerDecision:
				return events

			active_strike.effects_resolved_in_timing += 1

		# All effects resolved, move to next state.
		active_strike.effects_resolved_in_timing = 0
		if active_strike.opponent_sets_first:
			events += begin_resolve_strike()
		else:
			events = strike_setup_defender_response(events)

	elif active_strike.strike_state == StrikeState.StrikeState_Defender_SetFirst:
		# Opponent will set first; check for restrictions on what they can set
		events = strike_setup_defender_response(events)

	elif active_strike.strike_state == StrikeState.StrikeState_Defender_SetEffects:
		var defender_set_strike_effects = active_strike.defender.get_set_strike_effects(active_strike.defender_card)
		while active_strike.effects_resolved_in_timing < defender_set_strike_effects.size():
			var effect = defender_set_strike_effects[active_strike.effects_resolved_in_timing]
			events += do_effect_if_condition_met(active_strike.defender, -1, effect, null)
			if game_state == Enums.GameState.GameState_PlayerDecision:
				return events
			active_strike.effects_resolved_in_timing += 1

		# All effects resolved, move to next state.
		active_strike.effects_resolved_in_timing = 0
		if active_strike.opponent_sets_first:
			events = strike_setup_initiator_response(events)
		else:
			events += begin_resolve_strike()
	return events

func strike_setup_defender_response(events):
	active_strike.strike_state = StrikeState.StrikeState_Defender_SetEffects
	change_game_state(Enums.GameState.GameState_Strike_Opponent_Response)
	var ask_for_response = true
	if active_strike.initiator.force_opponent_respond_wild_swing():
		events += [create_event(Enums.EventType.EventType_Strike_ForceWildSwing, active_strike.initiator.my_id, 0)]
		# Queue any events so far, then empty this tally and call do_strike.
		event_queue += events
		events = []
		do_strike(active_strike.defender, -1, true, -1, active_strike.opponent_sets_first)
		ask_for_response = false
	elif active_strike.defender.reading_card_id:
		# The Reading effect goes here and will either force the player to strike
		# with the named card or to reveal their hand.
		var reading_cards = active_strike.defender.get_reading_card_in_hand()
		if len(reading_cards) > 0:
			var reading_card = reading_cards[0]
			var ex_card_id = -1
			if len(reading_cards) >= 2:
				ex_card_id = reading_cards[1].id

			# Send choice to player
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			var defender_id = active_strike.defender.my_id

			decision_info.type = Enums.DecisionType.DecisionType_ChooseSimultaneousEffect
			decision_info.player = defender_id
			decision_info.choice = [
				{ "effect_type": "strike_response_reading", "card_id": reading_card.id },
				{ "effect_type": "strike_response_reading", "card_id": reading_card.id, "ex_card_id": ex_card_id, "_choice_disabled": ex_card_id == -1 },
			]
			events += [create_event(Enums.EventType.EventType_Strike_EffectChoice, defender_id, 0, "Reading", reading_card.definition['display_name'])]
			ask_for_response = false
		else:
			events += active_strike.defender.reveal_hand()
	if ask_for_response:
		if active_strike.opponent_sets_first:
			events += [create_event(Enums.EventType.EventType_Strike_OpponentSetsFirst_DefenderSet, active_strike.defender.my_id, 0)]
		else:
			events += [create_event(Enums.EventType.EventType_Strike_DoResponseNow, active_strike.defender.my_id, 0)]
	return events

func strike_setup_initiator_response(events):
	active_strike.strike_state = StrikeState.StrikeState_Initiator_SetEffects
	change_game_state(Enums.GameState.GameState_WaitForStrike)
	var ask_for_response = true
	if active_strike.initiator.next_strike_random_gauge:
		# Queue any events so far, then empty this tally and call do_strike.
		event_queue += events
		events = []
		decision_info.player = active_strike.initiator.my_id
		do_strike(active_strike.initiator, -1, false, -1, active_strike.opponent_sets_first)
		ask_for_response = false
	if ask_for_response:
		events += [create_event(Enums.EventType.EventType_Strike_OpponentSetsFirst_InitiatorSet, active_strike.initiator.my_id, 0)]
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

	active_strike.initiator.did_strike_this_turn = true
	active_strike.defender.did_strike_this_turn = true

	# Clear any setup stuff.
	player.extra_effect_after_set_strike = null
	opponent.extra_effect_after_set_strike = null


	events = continue_resolve_strike(events)
	return events

func calculate_speed(check_player, check_card):
	var bonus_speed = check_player.strike_stat_boosts.speed * check_player.strike_stat_boosts.speed_bonus_multiplier
	var speed = check_card.definition['speed'] + bonus_speed
	return speed

func strike_determine_order():
	# Determine activation
	var initiator_speed = calculate_speed(active_strike.initiator, active_strike.initiator_card)
	var defender_speed = calculate_speed(active_strike.defender, active_strike.defender_card)
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

func do_effect_if_condition_met(performing_player : Player, card_id : int, effect, local_conditions : LocalStrikeConditions):
	var events = []
	if is_effect_condition_met(performing_player, effect, local_conditions):
		events += handle_strike_effect(card_id, effect, performing_player)
	elif 'negative_condition_effect' in effect:
		var negative_condition_effect = effect['negative_condition_effect']
		events += handle_strike_effect(card_id, negative_condition_effect, performing_player)
	return events

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
		elif condition == "initiated_face_up":
			var initiated_strike = active_strike.initiator == performing_player
			return initiated_strike and active_strike.initiator_set_face_up
		elif condition == "is_normal_attack":
			return active_strike.get_player_card(performing_player).definition['type'] == "normal"
		elif condition == "top_deck_is_normal_attack":
			if performing_player.deck.size() > 0:
				return performing_player.deck[0].definition['type'] == "normal"
			return false
		elif condition == "is_buddy_special_or_ultra_attack":
			var attack_type = active_strike.get_player_card(performing_player).definition['type']
			return performing_player.is_buddy_in_play() and (attack_type == "special" or attack_type == "ultra")
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
			if not performing_player.used_character_action:
				return false
			elif 'condition_details' in effect:
				var target_details = effect['condition_details']
				var matching_details = false
				for used_action in performing_player.used_character_action_details:
					if used_action[0] == target_details[0] and used_action[1] == target_details[1]:
						matching_details = true
						break
				return matching_details
			else:
				return true
		elif condition == "used_character_bonus":
			return performing_player.used_character_bonus
		elif condition == "hit_opponent":
			return active_strike.did_player_hit_opponent(performing_player)
		elif condition == "last_turn_was_strike":
			return last_turn_was_strike
		elif condition == "not_last_turn_was_strike":
			return not last_turn_was_strike
		elif condition == "life_equals":
			var amount = effect['condition_amount']
			return performing_player.life == amount
		elif condition == "not_full_close":
			return  not local_conditions.fully_closed
		elif condition == "advanced_through":
			return local_conditions.advanced_through
		elif condition == "not_advanced_through":
			return not local_conditions.advanced_through
		elif condition == "advanced_through_buddy":
			return local_conditions.advanced_through_buddy
		elif condition == "not_advanced_through_buddy":
			return not local_conditions.advanced_through_buddy
		elif condition == "not_full_push":
			return not local_conditions.fully_pushed
		elif condition == "pulled_past":
			return local_conditions.pulled_past
		elif condition == "exceeded":
			return performing_player.exceeded
		elif condition == "max_cards_in_hand":
			var amount = effect['condition_amount']
			return performing_player.hand.size() <= amount
		elif condition == "min_cards_in_hand":
			var amount = effect['condition_amount']
			return performing_player.hand.size() >= amount
		elif condition == "min_cards_in_gauge":
			var amount = effect['condition_amount']
			return performing_player.gauge.size() >= amount
		elif condition == "manual_reshuffle":
			return local_conditions.manual_reshuffle
		elif condition == "more_cards_than_opponent":
			return performing_player.hand.size() > other_player.hand.size()
		elif condition == "no_strike_caused":
			return game_state != Enums.GameState.GameState_WaitForStrike
		elif condition == "no_strike_this_turn":
			return not performing_player.did_strike_this_turn
		elif condition == "during_strike":
			return active_strike != null
		elif condition == "stunned":
			return active_strike.is_player_stunned(performing_player)
		elif condition == "not_stunned":
			return not active_strike.is_player_stunned(performing_player)
		elif condition == "buddy_in_opponent_space":
			return performing_player.is_buddy_in_play() and performing_player.get_buddy_location() == other_player.arena_location
		elif condition == "buddy_in_play":
			return performing_player.is_buddy_in_play()
		elif condition == "not_buddy_in_play":
			return not performing_player.is_buddy_in_play()
		elif condition == "on_buddy_space":
			if not performing_player.is_buddy_in_play():
				return false
			return performing_player.arena_location == performing_player.get_buddy_location()
		elif condition == "buddy_between_attack_source":
			if not performing_player.is_buddy_in_play():
				return false
			var pos1 = performing_player.arena_location
			var pos2 = other_player.arena_location
			if other_player.strike_stat_boosts.calculate_range_from_buddy:
				pos2 = other_player.buddy_location
			var buddy_pos = performing_player.get_buddy_location()
			if pos1 < pos2: # opponent is on the right
				return buddy_pos > pos1 and buddy_pos < pos2
			else: # opponent is on the left
				return buddy_pos > pos2 and buddy_pos < pos1
		elif condition == "buddy_between_opponent":
			if not performing_player.is_buddy_in_play():
				return false
			var pos1 = performing_player.arena_location
			var pos2 = other_player.arena_location
			var buddy_pos = performing_player.get_buddy_location()
			if pos1 < pos2: # opponent is on the right
				return buddy_pos > pos1 and buddy_pos < pos2
			else: # opponent is on the left
				return buddy_pos > pos2 and buddy_pos < pos1
		elif condition == "opponent_between_buddy":
			if not performing_player.is_buddy_in_play():
				return false
			var pos1 = performing_player.arena_location
			var pos2 = performing_player.get_buddy_location()
			var other_pos = other_player.arena_location
			if pos1 < pos2: # Buddy is on the right
				return other_pos > pos1 and other_pos < pos2
			else: # Buddy is on the left
				return other_pos > pos2 and other_pos < pos1
		elif condition == "buddy_space_unoccupied":
			if not performing_player.is_buddy_in_play():
				return false
			var buddy_location = performing_player.get_buddy_location()
			if buddy_location == performing_player.arena_location:
				return false
			if buddy_location == other_player.arena_location:
				return false
			return true
		elif condition == "opponent_at_edge_of_arena":
			return other_player.arena_location == MinArenaLocation or other_player.arena_location == MaxArenaLocation
		elif condition == "opponent_stunned":
			return active_strike.is_player_stunned(other_player)
		elif condition == "range":
			var amount = effect['condition_amount']
			var distance = abs(performing_player.arena_location - other_player.arena_location)
			return amount == distance
		elif condition == "range_greater_or_equal":
			var amount = effect['condition_amount']
			var distance = abs(performing_player.arena_location - other_player.arena_location)
			return distance >= amount
		elif condition == "range_multiple":
			var min_amount = effect["condition_amount_min"]
			var max_amount = effect["condition_amount_max"]
			var distance = abs(performing_player.arena_location - other_player.arena_location)
			return distance >= min_amount and distance <= max_amount
		elif condition == "was_hit":
			return performing_player.strike_stat_boosts.was_hit
		elif condition == "was_wild_swing":
			return active_strike.get_player_wild_strike(performing_player)
		elif condition == "was_not_wild_swing":
			return not active_strike.get_player_wild_strike(performing_player)
		elif condition == "was_strike_from_gauge":
			return active_strike.get_player_strike_from_gauge(performing_player)
		elif condition == "is_critical":
			return performing_player.strike_stat_boosts.critical
		elif condition == "choose_cards_from_top_deck_action":
			return decision_info.action == effect["condition_details"]
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
	var advanced_through_buddy : bool = false
	var pulled_past : bool = false
	var manual_reshuffle : bool = false

func wait_for_mid_strike_boost():
	return game_state == Enums.GameState.GameState_PlayerDecision and decision_info.type == Enums.DecisionType.DecisionType_BoostNow

func handle_strike_effect(card_id :int, effect, performing_player : Player):
	printlog("STRIKE: Handling effect %s" % [effect])
	if 'for_other_player' in effect:
		performing_player = _get_player(get_other_player(performing_player.my_id))
	var events = []
	if 'character_effect' in effect and effect['character_effect']:
		performing_player.strike_stat_boosts.active_character_effects.append(effect)
		events += [create_event(Enums.EventType.EventType_Strike_CharacterEffect, performing_player.my_id, card_id, "", effect)]
	var local_conditions = LocalStrikeConditions.new()
	var performing_start = performing_player.arena_location
	var opposing_player : Player = _get_player(get_other_player(performing_player.my_id))
	var other_start = opposing_player.arena_location
	var buddy_start = performing_player.get_buddy_location()
	var ignore_extra_effects = false
	match effect['effect_type']:
		"add_boost_to_gauge_on_strike_cleanup":
			if card_id == -1:
				assert(false)
				printlog("ERROR: Unimplemented path to add_boost_to_gauge_on_strike_cleanup")
			#performing_player.add_boost_to_gauge_on_strike_cleanup(card_id)
			# Switching to doing it immediately
			var card = card_db.get_card(card_id)
			_append_log("%s Added card %s goes to gauge." % [performing_player.name, card_db.get_card_name(card.id)])
			events += performing_player.remove_from_continuous_boosts(card, true)
		"add_boost_to_gauge_on_move":
			if card_id == -1:
				assert(false)
				printlog("ERROR: Unimplemented path to add_boost_to_gauge_on_move")
			performing_player.set_add_boost_to_gauge_on_move(card_id)
		"add_set_aside_card_to_deck":
			events += performing_player.add_set_aside_card_to_deck(effect['id'])
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
		"add_top_deck_to_gauge":
			var amount = 1
			if 'amount' in effect:
				amount = effect['amount']
			events += performing_player.add_top_deck_to_gauge(amount)
		"add_top_discard_to_gauge":
			var amount = 1
			if 'amount' in effect:
				amount = effect['amount']
			events += performing_player.add_top_discard_to_gauge(amount)
		"advance":
			decision_info.source = "advance"
			decision_info.amount = effect['amount']
			decision_info.limitation = { 'and': null, 'bonus_effect': null }
			if 'and' in effect:
				decision_info.limitation['and'] = effect['and']
			if 'bonus_effect' in effect:
				decision_info.limitation['bonus_effect'] = effect['bonus_effect']

			var effects = performing_player.get_character_effects_at_timing("on_advance_or_close")
			for sub_effect in effects:
				events += do_effect_if_condition_met(performing_player, -1, sub_effect, null)
			if game_state != Enums.GameState.GameState_PlayerDecision:
				var advance_effect = effect.duplicate()
				advance_effect['effect_type'] = "advance_INTERNAL"
				events += handle_strike_effect(card_id, advance_effect, performing_player)
				# and/bonus_effect should be handled by internal version
				ignore_extra_effects = true
		"advance_INTERNAL":
			var amount = effect['amount']
			if str(amount) == "strike_x":
				amount = performing_player.strike_stat_boosts.strike_x

			var previous_location = performing_player.arena_location
			events += performing_player.advance(amount)
			var new_location = performing_player.arena_location
			if (performing_start < other_start and new_location > other_start) or (performing_start > other_start and new_location < other_start):
				local_conditions.advanced_through = true
			if (performing_start <= buddy_start and new_location >= buddy_start) or (performing_start >= buddy_start and new_location <= buddy_start):
				local_conditions.advanced_through_buddy = true
			_append_log("%s Advance %s - Moved from %s to %s." % [performing_player.name, str(amount), str(previous_location), str(new_location)])
		"armorup":
			performing_player.strike_stat_boosts.armor += effect['amount']
			events += [create_event(Enums.EventType.EventType_Strike_ArmorUp, performing_player.my_id, effect['amount'])]
		"armorup_times_gauge":
			var amount = performing_player.gauge.size() * effect['amount']
			performing_player.strike_stat_boosts.armor += amount
			events += [create_event(Enums.EventType.EventType_Strike_ArmorUp, performing_player.my_id, amount)]
		"attack_does_not_hit":
			performing_player.strike_stat_boosts.attack_does_not_hit = true
			if 'hide_notice' not in effect or not effect['hide_notice']:
				events += [create_event(Enums.EventType.EventType_Strike_AttackDoesNotHit, performing_player.my_id, card_id)]
		"attack_is_ex":
			performing_player.strike_stat_boosts.set_ex()
			events += [create_event(Enums.EventType.EventType_Strike_ExUp, performing_player.my_id, card_id)]
		"block_opponent_move":
			opposing_player.cannot_move = true
			events += [create_event(Enums.EventType.EventType_BlockMovement, opposing_player.my_id, card_id)]
		"remove_block_opponent_move":
			opposing_player.cannot_move = false
		"bonus_action":
			active_boost.action_after_boost = true
		"boost_applies_if_on_buddy":
			if card_id == -1:
				assert(false)
				printlog("ERROR: Unimplemented path to boost_applies_if_on_buddy")
			performing_player.set_boost_applies_if_on_buddy(card_id)
		"boost_this_then_sustain":
			performing_player.strike_stat_boosts.move_strike_to_boosts = true
			if 'boost_effect' in effect:
				var boost_effect = effect['boost_effect']
				events += handle_strike_effect(card_id, boost_effect, performing_player)
		"boost_then_sustain":
			var allow_gauge = 'allow_gauge' in effect and effect['allow_gauge']
			if performing_player.can_boost_something(allow_gauge, effect['limitation']):
				events += [create_event(Enums.EventType.EventType_ForceStartBoost, performing_player.my_id, 0, "", allow_gauge, effect['limitation'])]
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.type = Enums.DecisionType.DecisionType_BoostNow
				decision_info.player = performing_player.my_id
				decision_info.allow_gauge = allow_gauge
				decision_info.limitation = effect['limitation']
				performing_player.sustain_next_boost = true
				performing_player.cancel_blocked_this_turn = true
			else:
				_append_log("%s has no cards available to boost." % [performing_player.name])
		"boost_then_sustain_topdeck":
			if performing_player.deck.size() > 0:
				performing_player.cancel_blocked_this_turn = true
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.type = Enums.DecisionType.DecisionType_ForceBoostSustainTopdeck
				decision_info.player = performing_player.my_id
				active_strike.remaining_topdeck_boosts = effect['amount']
				active_strike.remaining_topdeck_boosts_player_id = performing_player.my_id
			else:
				_append_log("%s deck is empty." % [performing_player.name])
		"boost_then_strike":
			var allow_gauge = 'allow_gauge' in effect and effect['allow_gauge']
			if performing_player.can_boost_something(allow_gauge, effect['limitation']):
				events += [create_event(Enums.EventType.EventType_ForceStartBoost, performing_player.my_id, 0, "", allow_gauge, effect['limitation'])]
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.type = Enums.DecisionType.DecisionType_BoostNow
				decision_info.player = performing_player.my_id
				decision_info.allow_gauge = allow_gauge
				decision_info.limitation = effect['limitation']
				performing_player.strike_on_boost_cleanup = true
			else:
				_append_log("%s has no cards available to boost." % [performing_player.name])
				events += [create_event(Enums.EventType.EventType_ForceStartStrike, performing_player.my_id, 0)]
				change_game_state(Enums.GameState.GameState_WaitForStrike)
				decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
				decision_info.player = performing_player.my_id
		"cannot_stun":
			performing_player.strike_stat_boosts.cannot_stun = true
		"choice":
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.type = Enums.DecisionType.DecisionType_EffectChoice
			decision_info.player = performing_player.my_id
			decision_info.choice = effect['choice']
			decision_info.choice_card_id = card_id
			events += [create_event(Enums.EventType.EventType_Strike_EffectChoice, performing_player.my_id, 0, "EffectOption")]
		"choice_altered_values":
			# Make a deep copy of the choices and replace any needed values.
			var updated_choices = effect['choice'].duplicate(true)
			for choice_effect in updated_choices:
				if choice_effect['amount'] == "TOTAL_POWER":
					choice_effect['amount'] = get_total_power(performing_player)

			# Same as normal choice.
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.type = Enums.DecisionType.DecisionType_EffectChoice
			decision_info.player = performing_player.my_id
			decision_info.choice = updated_choices
			decision_info.choice_card_id = card_id
			events += [create_event(Enums.EventType.EventType_Strike_EffectChoice, performing_player.my_id, 0, "EffectOption")]
		"choose_cards_from_top_deck":
			var look_amount = min(effect['look_amount'], performing_player.deck.size())
			if look_amount == 0:
				_append_log("%s has no cards in their deck." % [performing_player.name])
				if 'strike_after' in effect and effect['strike_after']:
					events += [create_event(Enums.EventType.EventType_ForceStartStrike, performing_player.my_id, 0)]
					change_game_state(Enums.GameState.GameState_WaitForStrike)
					decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
					decision_info.player = performing_player.my_id
			elif look_amount > 0:
				performing_player.cancel_blocked_this_turn = true
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.type = Enums.DecisionType.DecisionType_ChooseFromTopDeck
				decision_info.player = performing_player.my_id
				decision_info.choice_card_id = card_id
				decision_info.action = effect['action_choices']
				decision_info.can_pass = effect['can_pass']
				decision_info.destination = effect['destination_unchosen']
				decision_info.amount = look_amount
				events += [create_event(Enums.EventType.EventType_ChooseFromTopDeck, performing_player.my_id, 0)]

				if 'strike_after' in effect and effect['strike_after']:
					performing_player.strike_on_boost_cleanup = true
		"choose_discard":
			var source = "discard"
			if 'source' in effect:
				source = effect['source']
			var choice_count = 0
			if source == "discard":
				choice_count = performing_player.get_discard_count_of_type(effect['limitation'])
			elif source == "sealed":
				choice_count = performing_player.get_sealed_count_of_type(effect['limitation'])
			elif source == "overdrive":
				choice_count = performing_player.overdrive.size()
			else:
				assert(false, "Unimplemented source")
			if choice_count > 0:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.type = Enums.DecisionType.DecisionType_ChooseFromDiscard
				decision_info.player = performing_player.my_id
				decision_info.choice_card_id = card_id
				decision_info.source = source
				decision_info.limitation = effect['limitation']
				decision_info.destination = effect['destination']
				var amount = 1
				if 'amount' in effect:
					amount = min(choice_count, effect['amount'])
				decision_info.amount = amount
				decision_info.amount_min = amount
				if 'amount_min' in effect:
					decision_info.amount_min = min(effect['amount_min'], amount)
				events += [create_event(Enums.EventType.EventType_ChooseFromDiscard, performing_player.my_id, amount)]
			else:
				if effect['limitation']:
					_append_log("%s has no cards in %s of type %s." % [performing_player.name, source, effect['limitation']])
				else:
					_append_log("%s has no cards in %s." % [performing_player.name, source])
		"choose_sustain_boost":
			var choice_count = performing_player.continuous_boosts.size()
			choice_count -= performing_player.sustained_boosts.size()
			if choice_count > 0:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.type = Enums.DecisionType.DecisionType_ChooseFromBoosts
				decision_info.player = performing_player.my_id
				decision_info.choice_card_id = card_id
				var amount = 1
				if 'amount' in effect:
					amount = min(choice_count, effect['amount'])
				decision_info.amount = amount
				decision_info.amount_min = amount
				if 'amount_min' in effect:
					decision_info.amount_min = effect['amount_min']
				events += [create_event(Enums.EventType.EventType_ChooseFromBoosts, performing_player.my_id, amount)]
		"close":
			decision_info.source = "close"
			decision_info.amount = effect['amount']
			decision_info.limitation = { 'and': null, 'bonus_effect': null }
			if 'and' in effect:
				decision_info.limitation['and'] = effect['and']
			if 'bonus_effect' in effect:
				decision_info.limitation['and'] = effect['bonus_effect']

			var effects = performing_player.get_character_effects_at_timing("on_advance_or_close")
			for sub_effect in effects:
				events += do_effect_if_condition_met(performing_player, -1, sub_effect, null)
			if game_state != Enums.GameState.GameState_PlayerDecision:
				var close_effect = effect.duplicate()
				close_effect['effect_type'] = "close_INTERNAL"
				events += handle_strike_effect(card_id, close_effect, performing_player)
				# and/bonus_effect should be handled by internal version
				ignore_extra_effects = true
		"close_INTERNAL":
			var previous_location = performing_player.arena_location
			events += performing_player.close(effect['amount'])
			var new_location = performing_player.arena_location
			var close_amount = abs(performing_start - new_location)
			local_conditions.fully_closed = close_amount == effect['amount']
			_append_log("%s Close %s - Moved from %s to %s." % [performing_player.name, str(effect['amount']), str(previous_location), str(new_location)])
		"copy_other_hit_effect":
			var card = active_strike.get_player_card(performing_player)
			var hit_effects = get_all_effects_for_timing("hit", performing_player, card)

			var effect_options = []
			for possible_effect in hit_effects:
				if possible_effect['effect_type'] != "copy_other_hit_effect":
					effect_options.append(get_base_remaining_effect(possible_effect))

			if len(effect_options) > 0:
				# Send choice to player
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.type = Enums.DecisionType.DecisionType_ChooseSimultaneousEffect
				decision_info.player = performing_player.my_id
				decision_info.effect_type = "copy_other_hit_effect"
				decision_info.choice = effect_options
				events += [create_event(Enums.EventType.EventType_Strike_EffectChoice, performing_player.my_id, 0, "Duplicate")]
		"critical":
			performing_player.strike_stat_boosts.critical = true
			events += [create_event(Enums.EventType.EventType_Strike_Critical, performing_player.my_id, 0)]
		"discard_this":
			if active_boost:
				active_boost.discard_on_cleanup = true
			else:
				var card = card_db.get_card(card_id)
				_append_log("%s discarded %s from boosts." % [performing_player.name, card_db.get_card_name(card.id)])
				events += performing_player.remove_from_continuous_boosts(card, false)
				events += opposing_player.remove_from_continuous_boosts(card, false)
		"discard_strike_after_cleanup":
			performing_player.strike_stat_boosts.discard_attack_on_cleanup = true
		"discard_opponent_topdeck":
			events += opposing_player.discard_topdeck()
		"discard_topdeck":
			events += performing_player.discard_topdeck()
		"draw_or_discard_to":
			events += handle_player_draw_or_discard_to_effect(performing_player, card_id, effect)
		"draw_to":
			var target_hand_size = effect['amount']
			var hand_size = performing_player.hand.size()
			if hand_size < target_hand_size:
				var amount_to_draw = target_hand_size - hand_size
				events += performing_player.draw(amount_to_draw)
		"opponent_draw_or_discard_to":
			events += handle_player_draw_or_discard_to_effect(opposing_player, card_id, effect)
		"dodge_at_range":
			performing_player.strike_stat_boosts.dodge_at_range_min = effect['range_min']
			performing_player.strike_stat_boosts.dodge_at_range_max = effect['range_max']
			var buddy_name = null
			var extra_text = ""
			if 'from_buddy' in effect:
				performing_player.strike_stat_boosts.dodge_at_range_from_buddy = effect['from_buddy']
				buddy_name = effect['buddy_name']
				extra_text = " from %s" % buddy_name
			events += [create_event(Enums.EventType.EventType_Strike_DodgeAttacksAtRange, performing_player.my_id, effect['range_min'], "", effect['range_max'], buddy_name)]
			_append_log("%s is now dodging attacks at range %s-%s%s." % [performing_player.name, str(effect['range_min']), str(effect['range_max']), extra_text])
		"dodge_attacks":
			performing_player.strike_stat_boosts.dodge_attacks = true
			events += [create_event(Enums.EventType.EventType_Strike_DodgeAttacks, performing_player.my_id, 0)]
			_append_log("%s is now dodging attacks." % [performing_player.name])
		"dodge_from_opposite_buddy":
			performing_player.strike_stat_boosts.dodge_from_opposite_buddy = true
			events += [create_event(Enums.EventType.EventType_Strike_DodgeFromOppositeBuddy, performing_player.my_id, 0, "", effect['buddy_name'])]
			_append_log("%s is now dodging attacks from opponents behind %s." % [performing_player.name, effect['buddy_name']])
		"draw":
			events += performing_player.draw(effect['amount'])
		"discard_continuous_boost":
			var my_boosts = performing_player.continuous_boosts
			var opponent_boosts = opposing_player.continuous_boosts
			decision_info.limitation = ""
			if 'limitation' in effect:
				decision_info.limitation = effect['limitation']

			if len(my_boosts) > 0 or (not decision_info.limitation == "mine" and len(opponent_boosts) > 0):
				# Player gets to pick which continuous boost to discard.
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.type = Enums.DecisionType.DecisionType_ChooseDiscardContinuousBoost
				decision_info.effect_type = "discard_continuous_boost_INTERNAL"
				decision_info.choice_card_id = card_id
				if 'overall_effect' in effect:
					decision_info.effect = effect['overall_effect']
				else:
					decision_info.effect = null
				decision_info.can_pass = not effect['required']
				decision_info.player = performing_player.my_id
				events += [create_event(Enums.EventType.EventType_Boost_DiscardContinuousChoice, performing_player.my_id, 1)]
		"discard_continuous_boost_INTERNAL":
			var boost_to_discard_id = effect['card_id']
			if boost_to_discard_id != -1:
				var card = card_db.get_card(boost_to_discard_id)
				if performing_player.is_card_in_continuous_boosts(boost_to_discard_id):
					events += performing_player.remove_from_continuous_boosts(card, false)
				elif opposing_player.is_card_in_continuous_boosts(boost_to_discard_id):
					events += opposing_player.remove_from_continuous_boosts(card, false)

				# Do any bonus effect
				if decision_info.effect:
					handle_strike_effect(card_id, decision_info.effect, performing_player)
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
		"discard_random_and_add_triggers":
			events += performing_player.discard_random(1, func(inner_player, ids): add_attack_triggers(inner_player, ids, true))
		"exceed_end_of_turn":
			performing_player.exceed_at_end_of_turn = true
		"exceed_now":
			events += performing_player.exceed()
		"extra_trigger_resolutions":
			duplicate_attack_triggers(performing_player, effect['amount'])
		"force_for_effect":
			var force_player = performing_player
			if 'other_player' in effect and effect['other_player']:
				force_player = opposing_player
			var available_force = force_player.get_available_force()
			var can_do_something = false
			if effect['per_force_effect'] and available_force > 0:
				can_do_something = true
			elif effect['overall_effect'] and available_force >= effect['force_max']:
				can_do_something = true
			if can_do_something:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.player = force_player.my_id
				decision_info.type = Enums.DecisionType.DecisionType_ForceForEffect
				decision_info.choice_card_id = card_id
				decision_info.effect = effect
				events += [create_event(Enums.EventType.EventType_ForceForEffect, force_player.my_id, 0)]
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
		"gain_life":
			var amount = effect['amount']
			performing_player.life = min(MaxLife, performing_player.life + amount)
			events += [create_event(Enums.EventType.EventType_Strike_GainLife, performing_player.my_id, amount, "", performing_player.life)]
			_append_log("%s gains %s life. Life is now %s." % [performing_player.name, str(amount), str(performing_player.life)])
		"gauge_from_hand":
			if len(performing_player.hand) > 0:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.type = Enums.DecisionType.DecisionType_CardFromHandToGauge
				decision_info.player = performing_player.my_id
				decision_info.choice_card_id = card_id
				decision_info.destination = "gauge"
				var min_amount = effect['min_amount']
				var max_amount = effect['max_amount']
				decision_info.effect = {
					"min_amount": min_amount,
					"max_amount": max_amount,
				}
				events += [create_event(Enums.EventType.EventType_CardFromHandToGauge_Choice, performing_player.my_id, min_amount, "", max_amount)]
		"give_to_player":
			performing_player.strike_stat_boosts.move_strike_to_opponent_boosts = true
		"guardup":
			performing_player.strike_stat_boosts.guard += effect['amount']
			events += [create_event(Enums.EventType.EventType_Strike_GuardUp, performing_player.my_id, effect['amount'])]
		"higher_speed_misses":
			performing_player.strike_stat_boosts.higher_speed_misses = true
		"ignore_armor":
			performing_player.strike_stat_boosts.ignore_armor = true
		"ignore_guard":
			performing_player.strike_stat_boosts.ignore_guard = true
		"ignore_push_and_pull":
			performing_player.strike_stat_boosts.ignore_push_and_pull = true
		"ignore_push_and_pull_passive_bonus":
			performing_player.ignore_push_and_pull = true
		"increase_force_spent_before_strike":
			performing_player.force_spent_before_strike += 1
		"remove_ignore_push_and_pull_passive_bonus":
			performing_player.ignore_push_and_pull = false
		"look_at_top_opponent_deck":
			events += opposing_player.reveal_topdeck()
		"lose_all_armor":
			performing_player.strike_stat_boosts.lose_all_armor = true
		"may_advance_bonus_spaces":
			# TODO source is advance/retreat, amount is amount
			var movement_type = decision_info.source
			var movement_amount = decision_info.amount
			var followups = decision_info.limitation

			var choice = [
				{
					'effect_type': movement_type + '_INTERNAL',
					'amount': movement_amount
				},
				{
					'effect_type': movement_type + '_INTERNAL',
					'amount': movement_amount + effect['amount']
				}
			]
			if followups['and']:
				choice[0]['and'] = followups['and']
				choice[1]['and'] = followups['and']
			if followups['bonus_effect']:
				choice[0]['bonus_effect'] = followups['bonus_effect']
				choice[1]['bonus_effect'] = followups['bonus_effect']

			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.type = Enums.DecisionType.DecisionType_EffectChoice
			decision_info.player = performing_player.my_id
			decision_info.choice = choice
			decision_info.choice_card_id = card_id
			events += [create_event(Enums.EventType.EventType_Strike_EffectChoice, performing_player.my_id, 0, "EffectOption")]
		"move_to_space":
			var space = effect['amount']
			events += performing_player.move_to(space)
		"move_to_any_space":
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.type = Enums.DecisionType.DecisionType_ChooseArenaLocationForEffect
			decision_info.player = performing_player.my_id
			decision_info.choice_card_id = card_id
			decision_info.effect_type = "move_to_space"
			# Can always pass.
			decision_info.choice = [{
				"effect_type": "pass"
			}]
			decision_info.limitation = [0]
			var ignore_force_req = true
			for i in range(MinArenaLocation, MaxArenaLocation + 1):
				if not performing_player.can_move_to(i, ignore_force_req):
					continue
				decision_info.limitation.append(i)
				decision_info.choice.append({
					"effect_type": "move_to_space",
					"amount": i
				})
			events += [create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)]
		"name_card_opponent_discards":
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.type = Enums.DecisionType.DecisionType_NameCard_OpponentDiscards
			decision_info.effect_type = "name_card_opponent_discards_internal"
			decision_info.choice_card_id = card_id
			decision_info.player = performing_player.my_id
			events += [create_event(Enums.EventType.EventType_Boost_NameCardOpponentDiscards, performing_player.my_id, 1)]
		"name_card_opponent_discards_internal":
			var named_card_name = NullNamedCard
			if effect['card_id'] != -1:
				var named_card = card_db.get_card(effect['card_id'])
				# named_card is the individual card but
				# this should discard "by name", so instead of using that
				# match card.definition['id']'s instead.
				named_card_name = named_card.definition['id']
			events += opposing_player.discard_matching_or_reveal(named_card_name)
		"reveal_copy_for_advantage":
			var copy_id = effect['copy_id']
			# The player has selected to reveal a copy if they have one.
			# Otherwise, do nothing.
			var copy_card_id = performing_player.get_copy_in_hand(copy_id)
			if copy_card_id != -1:
				var card_name = card_db.get_card_name(copy_card_id)
				next_turn_player = performing_player.my_id
				events += [create_event(Enums.EventType.EventType_RevealCard, performing_player.my_id, copy_card_id)]
				events += [create_event(Enums.EventType.EventType_Strike_GainAdvantage, performing_player.my_id, 0)]
				_append_log("%s reveals %s to gain Advantage." % [performing_player.name, card_name])
		"reveal_hand":
			events += performing_player.reveal_hand()
		"reveal_strike":
			if performing_player == active_strike.initiator:
				active_strike.initiator_set_face_up = true
			events += [create_event(Enums.EventType.EventType_RevealStrike_OnePlayer, performing_player.my_id, 0)]
		"move_buddy":
			decision_info.choice = []
			decision_info.limitation = []
			var optional = 'optional' in effect and effect['optional']
			if optional:
				decision_info.limitation.append(0)
				decision_info.choice.append({
					"effect_type": "pass"
				})
			var min_spaces = effect['amount']
			var max_spaces = effect['amount2']
			for i in range(MinArenaLocation, MaxArenaLocation + 1):
				var distance = abs(performing_player.buddy_location - i)
				if distance >= min_spaces and distance <= max_spaces:
					decision_info.limitation.append(i)
					decision_info.choice.append({
						"effect_type": "place_buddy_into_space",
						"amount": i
					})
			if decision_info.limitation.size() > 1 or (not optional and decision_info.limitation.size() > 0):
				decision_info.type = Enums.DecisionType.DecisionType_ChooseArenaLocationForEffect
				decision_info.player = performing_player.my_id
				decision_info.choice_card_id = card_id
				decision_info.effect_type = "place_buddy_into_space"
				decision_info.source = effect['buddy_name']
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				events += [create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)]
		"move_to_buddy":
			events += performing_player.move_to(performing_player.buddy_location)
		"multiply_power_bonuses":
			performing_player.strike_stat_boosts.power_bonus_multiplier = max(effect['amount'], performing_player.strike_stat_boosts.power_bonus_multiplier)
		"multiply_speed_bonuses":
			performing_player.strike_stat_boosts.speed_bonus_multiplier = max(effect['amount'], performing_player.strike_stat_boosts.speed_bonus_multiplier)
		"opponent_cant_move_past":
			opposing_player.cannot_move_past_opponent = true
			events += [create_event(Enums.EventType.EventType_Strike_OpponentCantMovePast, performing_player.my_id, 0)]
			_append_log("%s is blocking opponent from advancing past." % [performing_player.name])
		"remove_opponent_cant_move_past":
			opposing_player.cannot_move_past_opponent = false
		"return_attack_to_top_of_deck":
			performing_player.strike_stat_boosts.attack_to_topdeck_on_cleanup = true
		"opponent_discard_choose":
			if opposing_player.hand.size() > effect['amount']:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.type = Enums.DecisionType.DecisionType_ChooseToDiscard
				decision_info.effect_type = "opponent_discard_choose_internal"
				decision_info.effect = effect
				decision_info.bonus_effect = null
				decision_info.destination = "discard"
				decision_info.limitation = ""
				decision_info.can_pass = false

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
		"place_buddy_into_space":
			var space = effect['amount']
			events += performing_player.place_buddy(space)
		"place_buddy_in_any_space":
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.type = Enums.DecisionType.DecisionType_ChooseArenaLocationForEffect
			decision_info.player = performing_player.my_id
			decision_info.choice_card_id = card_id
			decision_info.effect_type = "place_buddy_into_space"
			decision_info.source = effect['buddy_name']
			decision_info.choice = []
			decision_info.limitation = []
			if 'optional' in effect and effect['optional']:
				decision_info.limitation.append(0)
				decision_info.choice.append({
					"effect_type": "pass"
				})
			for i in range(MinArenaLocation, MaxArenaLocation + 1):
				decision_info.limitation.append(i)
				decision_info.choice.append({
					"effect_type": "place_buddy_into_space",
					"amount": i
				})
			events += [create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)]
		"place_buddy_in_attack_range":
			decision_info.choice = []
			decision_info.limitation = []
			var attack_card = active_strike.get_player_card(performing_player)
			var optional = 'optional' in effect and effect['optional']
			if optional:
				decision_info.limitation.append(0)
				decision_info.choice.append({
					"effect_type": "pass"
				})
			for i in range(MinArenaLocation, MaxArenaLocation + 1):
				if is_location_in_range(performing_player, attack_card, i):
					decision_info.limitation.append(i)
					decision_info.choice.append({
						"effect_type": "place_buddy_into_space",
						"amount": i
					})
			if decision_info.limitation.size() > 1 or (not optional and decision_info.limitation.size() > 0):
				decision_info.type = Enums.DecisionType.DecisionType_ChooseArenaLocationForEffect
				decision_info.player = performing_player.my_id
				decision_info.choice_card_id = card_id
				decision_info.effect_type = "place_buddy_into_space"
				decision_info.source = effect['buddy_name']
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				events += [create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)]
		"place_buddy_onto_opponent":
			events += performing_player.place_buddy(opposing_player.arena_location)
		"place_buddy_onto_self":
			events += performing_player.place_buddy(performing_player.arena_location)
		"powerup":
			var amount = effect['amount']
			if str(amount) == "strike_x":
				amount = performing_player.strike_stat_boosts.strike_x
			performing_player.strike_stat_boosts.power += amount
			events += [create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, amount)]
		"powerup_per_boost_in_play":
			var boosts_in_play = performing_player.continuous_boosts.size()
			if boosts_in_play > 0:
				performing_player.strike_stat_boosts.power += effect['amount'] * boosts_in_play
				events += [create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, effect['amount'] * boosts_in_play)]
		"powerup_damagetaken":
			var power_per_damage = effect['amount']
			var damage_taken = active_strike.get_damage_taken(performing_player)
			var total_powerup = power_per_damage * damage_taken
			# Checking for negative damage taken so that powerup is in expected "direction"
			if total_powerup != 0 and damage_taken > 0:
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
		"push_from_source":
			var attack_source_location = performing_player.arena_location
			if performing_player.strike_stat_boosts.calculate_range_from_buddy:
				attack_source_location = performing_player.get_buddy_location()

			var previous_location = opposing_player.arena_location
			if attack_source_location == previous_location:
				# Make choice to push or pull.
				var choice_effect = {
					"effect_type": "choice",
					"choice": [
						{ "effect_type": "push", "amount": effect['amount'] },
						{ "effect_type": "pull", "amount": effect['amount'] }
					]
				}
				for choice in choice_effect['choice']:
					if 'and' in choice:
						choice['and'] = effect['and']
					if 'bonus_effect' in choice:
						choice['bonus_effect'] = effect['bonus_effect']
				events += handle_strike_effect(card_id, choice_effect, performing_player)
			else:
				# Convert this to a regular push or pull.
				if attack_source_location < previous_location:
					# Source to the left of opponent. Move to the right.
					if performing_player.arena_location < previous_location:
						# Player to the left of opponent. Push to move opponent right.
						events += performing_player.push(effect['amount'])
					else:
						# Player to the right of opponent. Pull to move opponent right.
						events += performing_player.pull(effect['amount'])
					pass
				else:
					# Source to the right of opponent. Move to the left.
					if performing_player.arena_location < previous_location:
						# Player to the left of opponent. Pull to move opponent left.
						events += performing_player.pull(effect['amount'])
					else:
						# Player to the right of opponent. Push to move opponent left.
						events += performing_player.push(effect['amount'])
				var new_location = opposing_player.arena_location
				var push_amount = abs(other_start - new_location)
				local_conditions.fully_pushed = push_amount == effect['amount']
				_append_log("%s Push from attack source %s - %s moved from %s to %s." % [performing_player.name, str(effect['amount']), _get_player(get_other_player(performing_player.my_id)).name, str(previous_location), str(new_location)])
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
		"remove_buddy":
			events += performing_player.remove_buddy()
		"do_not_remove_buddy":
			performing_player.do_not_cleanup_buddy_this_turn = true
		"calculate_range_from_buddy":
			performing_player.strike_stat_boosts.calculate_range_from_buddy = true
		"retreat":
			var amount = effect['amount']
			if str(amount) == "strike_x":
				amount = performing_player.strike_stat_boosts.strike_x

			var previous_location = performing_player.arena_location
			events += performing_player.retreat(amount)
			var new_location = performing_player.arena_location
			var retreat_amount = abs(performing_start - new_location)
			local_conditions.fully_retreated = retreat_amount == amount
			_append_log("%s Retreat %s - Moved from %s to %s." % [performing_player.name, str(amount), str(previous_location), str(new_location)])
		"return_all_cards_gauge_to_hand":
			var card_names = ""
			for card in performing_player.gauge:
				card_names += card_db.get_card_name(card.id) + ", "
			if card_names:
				card_names = card_names.substr(0, card_names.length() - 2)
			_append_log("%s - Returned cards %s from gauge to hand." % [performing_player.name, card_names])
			events += performing_player.return_all_cards_gauge_to_hand()
		"return_attack_to_hand":
			performing_player.strike_stat_boosts.return_attack_to_hand = true
		"return_this_attack_to_hand_after_attack":
			var card_name = card_db.get_card_name(card_id)
			_append_log("%s - %s returned to hand." % [performing_player.name, card_name])
			performing_player.strike_stat_boosts.return_attack_to_hand = true
		"return_this_boost_to_hand_strike_effect":
			var card_name = card_db.get_card_name(card_id)
			_append_log("%s - %s returned to hand." % [performing_player.name, card_name])
			var card = card_db.get_card(card_id)
			events += performing_player.remove_from_continuous_boosts(card, false, true)
		"return_this_to_hand_immediate_boost":
			var card_name = card_db.get_card_name(card_id)
			_append_log("%s - %s returned to hand." % [performing_player.name, card_name])
			if active_boost:
				active_boost.cleanup_to_hand_card_ids.append(card_id)
		"revert":
			events += performing_player.revert_exceed()
		"save_power":
			var amount = effect['amount']
			performing_player.saved_power = amount
		"use_saved_power_as_printed_power":
			performing_player.strike_stat_boosts.overwrite_printed_power = true
			performing_player.strike_stat_boosts.overwritten_printed_power = performing_player.saved_power
		"seal_this":
			if active_boost:
				# Part of a boost.
				active_boost.seal_on_cleanup = true
			else:
				# Part of an attack.
				performing_player.strike_stat_boosts.seal_attack_on_cleanup = true
		"seal_hand":
			events += performing_player.seal_hand()
		"self_discard_choose":
			var optional = 'optional' in effect and effect['optional']
			var limitation = ""
			if 'limitation' in effect:
				limitation = effect['limitation']
			var destination = "discard"
			if 'destination' in effect:
				destination = effect['destination']
			var discard_effect = null
			if 'discard_effect' in effect:
				discard_effect = effect['discard_effect']
			var cards_available = performing_player.get_cards_in_hand_of_type(limitation)
			# Even if #cards == effect amount, still do the choosing manually because of all the additional
			# functionality that has been added to this besides discarding.
			if cards_available.size() >= effect['amount'] or (optional and cards_available.size() > 0):
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.type = Enums.DecisionType.DecisionType_ChooseToDiscard
				decision_info.effect_type = "self_discard_choose_internal"
				decision_info.effect = effect
				decision_info.choice_card_id = card_id
				decision_info.player = performing_player.my_id
				decision_info.destination = destination
				decision_info.limitation = limitation
				decision_info.bonus_effect = discard_effect
				decision_info.can_pass = optional
				events += [create_event(Enums.EventType.EventType_Strike_ChooseToDiscard, performing_player.my_id, effect['amount'])]
			else:
				if not optional and cards_available.size() > 0:
					events += [create_event(Enums.EventType.EventType_Strike_ChooseToDiscard_Info, performing_player.my_id, effect['amount'])]
					# Forced to discard whole hand.
					var card_ids = []
					for card in performing_player.hand:
						card_ids.append(card.id)
					events += performing_player.discard(card_ids)
				elif cards_available.size() == 0:
					if destination == "reveal" and 'and' in effect and effect['and']['effect_type'] == "save_power":
						performing_player.saved_power = 0
		"set_end_of_turn_boost_delay":
			performing_player.set_end_of_turn_boost_delay(card_id)
		"set_strike_x":
			events += do_set_strike_x(performing_player, effect['source'])
		"set_total_power":
			performing_player.strike_stat_boosts.overwrite_total_power = true
			performing_player.strike_stat_boosts.overwritten_total_power = effect['amount']
		"set_used_character_bonus":
			performing_player.used_character_bonus = true
		"self_discard_choose_internal":
			var card_ids = effect['card_ids']
			var card_names = card_db.get_card_names(card_ids)
			if effect['destination'] == "discard":
				_append_log("%s discarding chosen card(s): %s." % [performing_player.name, card_names])
				events += performing_player.discard(card_ids)
			elif effect['destination'] == "sealed":
				_append_log("%s sealing chosen %s card(s)." % [performing_player.name, str(len(card_names))])
				events += performing_player.seal_from_hand(card_ids)
			elif effect['destination'] == "reveal":
				_append_log("%s revealing chosen card(s): %s." % [performing_player.name, card_names])
				for revealed_card_id in card_ids:
					events += [create_event(Enums.EventType.EventType_RevealCard, performing_player.my_id, revealed_card_id)]
				if 'and' in effect and effect['and']['effect_type'] == "save_power":
					# Specifically get the printed power.
					var card_power = card_db.get_card(card_ids[0]).definition['power']
					effect['and']['amount'] = card_power
			else:
				# Nothing else implemented.
				assert(false)
		"shuffle_hand_to_deck":
			_append_log("%s shuffled hand to deck." % [performing_player.name])
			events += performing_player.shuffle_hand_to_deck()
		"shuffle_sealed_to_deck":
			var card_names = ""
			for card in performing_player.sealed:
				card_names += card_db.get_card_name(card.id) + ", "
			if card_names:
				card_names = card_names.substr(0, card_names.length() - 2)
			_append_log("%s shuffled sealed area to deck. Cards: %s" % [performing_player.name, card_names])
			events += performing_player.shuffle_sealed_to_deck()
		"specials_invalid":
			performing_player.specials_invalid = effect['enabled']
		"speedup":
			performing_player.strike_stat_boosts.speed += effect['amount']
			events += [create_event(Enums.EventType.EventType_Strike_SpeedUp, performing_player.my_id, effect['amount'])]
		"speedup_amount_in_gauge":
			var amount = performing_player.gauge.size()
			performing_player.strike_stat_boosts.speed += amount
			events += [create_event(Enums.EventType.EventType_Strike_SpeedUp, performing_player.my_id, amount)]
		"spend_life":
			var amount = effect['amount']
			performing_player.life -= amount
			events += [create_event(Enums.EventType.EventType_Strike_TookDamage, performing_player.my_id, amount, "spend", performing_player.life)]
			_append_log("%s spent %s life, life is now %s." % [performing_player.name, amount, performing_player.life])
			if performing_player.life <= 0:
				_append_log("%s is defeated." % [performing_player.name])
				events += trigger_game_over(performing_player.my_id, Enums.GameOverReason.GameOverReason_Life)
		"strike":
			events += [create_event(Enums.EventType.EventType_ForceStartStrike, performing_player.my_id, 0)]
			change_game_state(Enums.GameState.GameState_WaitForStrike)
			decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
			decision_info.player = performing_player.my_id
		"strike_effect_after_setting":
			events += [create_event(Enums.EventType.EventType_ForceStartStrike, performing_player.my_id, 0)]
			change_game_state(Enums.GameState.GameState_WaitForStrike)
			decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
			decision_info.player = performing_player.my_id
			performing_player.extra_effect_after_set_strike = effect['after_set_effect']
		"strike_effect_after_opponent_sets":
			events += [create_event(Enums.EventType.EventType_ForceStartStrike, performing_player.my_id, 0)]
			change_game_state(Enums.GameState.GameState_WaitForStrike)
			decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
			decision_info.player = performing_player.my_id
			opposing_player.extra_effect_after_set_strike = effect['after_set_effect']
		"strike_faceup":
			var disable_wild_swing = 'disable_wild_swing' in effect and effect['disable_wild_swing']
			var disable_ex = 'disable_ex' in effect and effect['disable_ex']
			events += [create_event(Enums.EventType.EventType_ForceStartStrike, performing_player.my_id, 0, "", disable_wild_swing, disable_ex)]
			change_game_state(Enums.GameState.GameState_WaitForStrike)
			decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
			decision_info.player = performing_player.my_id
			performing_player.next_strike_faceup = true
		"strike_from_gauge":
			decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
			decision_info.player = performing_player.my_id
			if len(performing_player.gauge) > 0:
				events += [create_event(Enums.EventType.EventType_Strike_FromGauge, performing_player.my_id, 0)]
				change_game_state(Enums.GameState.GameState_WaitForStrike)
				performing_player.next_strike_faceup = true
				performing_player.next_strike_from_gauge = true
			else:
				event_queue += events
				events = []
				change_game_state(Enums.GameState.GameState_WaitForStrike)
				do_strike(performing_player, -1, true, -1)
		"strike_opponent_sets_first":
			events += [create_event(Enums.EventType.EventType_Strike_OpponentSetsFirst, performing_player.my_id, 0)]
			change_game_state(Enums.GameState.GameState_Strike_Opponent_Set_First)
			decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
			decision_info.player = performing_player.my_id
		"strike_random_from_gauge":
			events += [create_event(Enums.EventType.EventType_Strike_OpponentSetsFirst, performing_player.my_id, 0)]
			change_game_state(Enums.GameState.GameState_Strike_Opponent_Set_First)
			decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
			decision_info.player = performing_player.my_id
			performing_player.next_strike_random_gauge = true
		"strike_response_reading":
			var card = effect['card_id']
			var ex_card = -1
			if 'ex_card_id' in effect:
				ex_card = effect['ex_card_id']
			event_queue += events
			events = []
			change_game_state(Enums.GameState.GameState_Strike_Opponent_Response)
			do_strike(performing_player, card, false, ex_card)
		"strike_with_deus_ex_machina":
			change_game_state(Enums.GameState.GameState_AutoStrike)
			decision_info.effect_type ="happychaos_deusexmachina"
		"stun_immunity":
			performing_player.strike_stat_boosts.stun_immunity = true
		"sustain_this":
			performing_player.sustained_boosts.append(card_id)
			events += [create_event(Enums.EventType.EventType_SustainBoost, performing_player.my_id, card_id)]
		"switch_spaces_with_buddy":
			var old_space = performing_player.arena_location
			events += performing_player.move_to(performing_player.buddy_location)
			events += performing_player.place_buddy(old_space)
		"take_bonus_actions":
			var num = effect['amount']
			performing_player.bonus_actions += num
			performing_player.cancel_blocked_this_turn = true
			_append_log("%s can take %s bonus actions." % [performing_player.name, str(num)])
		"take_nonlethal_damage":
			var damage = effect['amount']
			var damage_prevention = 0
			if active_strike:
				var defense_card = active_strike.get_player_card(performing_player)
				var armor_remaining = defense_card.definition['armor'] + performing_player.strike_stat_boosts.armor - performing_player.strike_stat_boosts.consumed_armor
				if performing_player.strike_stat_boosts.lose_all_armor:
					armor_remaining = 0
				damage_prevention = armor_remaining
			var unmitigated_damage = max(0, damage - damage_prevention)
			var used_armor = damage - unmitigated_damage
			if active_strike:
				performing_player.strike_stat_boosts.consumed_armor += used_armor
			if unmitigated_damage >= performing_player.life:
				unmitigated_damage = performing_player.life - 1
			performing_player.life -= unmitigated_damage
			events += [create_event(Enums.EventType.EventType_Strike_TookDamage, performing_player.my_id, unmitigated_damage, "", performing_player.life)]
			if used_armor > 0:
				_append_log("%s takes %s non-lethal damage (%s blocked by armor). Life is now %s." % [performing_player.name, str(used_armor), str(unmitigated_damage), str(performing_player.life)])
			else:
				_append_log("%s takes %s non-lethal damage. Life is now %s." % [performing_player.name, str(unmitigated_damage), str(performing_player.life)])
			if active_strike:
				active_strike.add_damage_taken(performing_player, damage)
				events += check_for_stun(performing_player, false)
		"topdeck_from_hand":
			if len(performing_player.hand) > 0:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.type = Enums.DecisionType.DecisionType_CardFromHandToGauge
				decision_info.player = performing_player.my_id
				decision_info.choice_card_id = card_id
				decision_info.destination = "topdeck"
				var min_amount = effect['min_amount']
				var max_amount = effect['max_amount']
				decision_info.effect = {
					"min_amount": min_amount,
					"max_amount": max_amount,
				}
				events += [create_event(Enums.EventType.EventType_CardFromHandToGauge_Choice, performing_player.my_id, min_amount, "", max_amount)]
		"when_hit_force_for_armor":
			performing_player.strike_stat_boosts.when_hit_force_for_armor = true

	if not ignore_extra_effects:
		if "and" in effect:
			if not game_state == Enums.GameState.GameState_PlayerDecision:
				var and_effect = effect['and']
				events += do_effect_if_condition_met(performing_player, card_id, and_effect, local_conditions)
			elif active_character_action:
				remaining_character_action_effects.append(effect['and'])

		if "bonus_effect" in effect:
			if not game_state == Enums.GameState.GameState_PlayerDecision:
				var bonus_effect = effect['bonus_effect']
				events += do_effect_if_condition_met(performing_player, card_id, bonus_effect, local_conditions)
			elif active_character_action:
				remaining_character_action_effects.append(effect['bonus_effect'])

	return events

func handle_player_draw_or_discard_to_effect(performing_player : Player, card_id, effect):
	var events = []
	var target_hand_size = effect['amount']
	var hand_size = performing_player.hand.size()
	if hand_size < target_hand_size:
		var amount_to_draw = target_hand_size - hand_size
		events += performing_player.draw(amount_to_draw)
	elif hand_size > target_hand_size:
		var amount_to_discard = hand_size - target_hand_size
		var discard_effect = {
			"effect_type": "self_discard_choose",
			"amount": amount_to_discard
		}
		events += handle_strike_effect(card_id, discard_effect, performing_player)
	else:
		pass
	return events

func get_card_stat(check_player : Player, card : GameCard, stat : String) -> int:
	if stat == 'power' and check_player.strike_stat_boosts.overwrite_printed_power:
		return check_player.strike_stat_boosts.overwritten_printed_power

	var value = card.definition[stat]
	if str(value) == "X":
		if active_strike:
			return check_player.strike_stat_boosts.strike_x
		else:
			assert(false, "ERROR: No support for interpreting X outside of strikes")
	elif str(value) == "CARDS_IN_HAND":
		value = check_player.hand.size()
	elif str(value) == "TOTAL_POWER":
		value = get_total_power(check_player)
	return value

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

func add_attack_triggers(performing_player : Player, card_ids : Array, set_character_effect : bool = false):
	var new_effects = []
	for card_id in card_ids:
		var card = card_db.get_card(card_id)
		_append_log("%s adding before/hit/after effects of %s to attack." % [performing_player.name, card_db.get_card_name(card.id)])
		var card_effects = []
		for timing in ["before", "hit", "after"]:
			for card_effect in card_db.get_card_effects_at_timing(card, timing):
				if set_character_effect:
					var as_character_effect = card_effect.duplicate()
					as_character_effect['character_effect'] = true
					card_effects.append(as_character_effect)
				else:
					card_effects.append(card_effect)
		new_effects += card_effects
	performing_player.strike_stat_boosts.added_attack_effects += new_effects

func duplicate_attack_triggers(performing_player : Player, amount : int):
	var card = active_strike.get_player_card(performing_player)

	var effects = []
	for timing in ["before", "hit", "after"]:
		effects += get_all_effects_for_timing(timing, performing_player, card)
	for i in range(amount):
		performing_player.strike_stat_boosts.added_attack_effects += effects

func get_boost_effects_at_timing(timing_name : String, performing_player : Player):
	var effects = []
	for boost_card in performing_player.continuous_boosts:
		for effect in boost_card.definition['boost']['effects']:
			if effect['timing'] == timing_name:
				var effect_with_id = effect.duplicate(true)
				effect_with_id['card_id'] = boost_card.id
				effects.append(effect_with_id)
	return effects

func get_all_effects_for_timing(timing_name : String, performing_player : Player, card : GameCard, ignore_condition : bool = true) -> Array:
	var effects = card_db.get_card_effects_at_timing(card, timing_name)
	for effect in effects:
		effect['card_id'] = card.id
	var boost_effects = get_boost_effects_at_timing(timing_name, performing_player)
	var character_effects = performing_player.get_character_effects_at_timing(timing_name)
	for effect in character_effects:
		effect['card_id'] = card.id
	var bonus_effects = performing_player.get_bonus_effects_at_timing(timing_name)

	var both_players_boost_effects = []
	both_players_boost_effects += get_boost_effects_at_timing("both_players_" + timing_name, performing_player)
	var other_player = _get_player(get_other_player(performing_player.my_id))
	both_players_boost_effects += get_boost_effects_at_timing("both_players_" + timing_name, other_player)

	var all_effects = []
	for effect in effects:
		if ignore_condition or is_effect_condition_met(performing_player, effect, null):
			all_effects.append(effect)
		elif 'negative_condition_effect' in effect:
			all_effects.append(effect['negative_condition_effect'])
	for effect in boost_effects:
		if ignore_condition or is_effect_condition_met(performing_player, effect, null):
			all_effects.append(effect)
		elif 'negative_condition_effect' in effect:
			all_effects.append(effect['negative_condition_effect'])
	for effect in both_players_boost_effects:
		if ignore_condition or is_effect_condition_met(performing_player, effect, null):
			all_effects.append(effect)
		elif 'negative_condition_effect' in effect:
			all_effects.append(effect['negative_condition_effect'])
	for effect in character_effects:
		if ignore_condition or is_effect_condition_met(performing_player, effect, null):
			all_effects.append(effect)
		elif 'negative_condition_effect' in effect:
			all_effects.append(effect['negative_condition_effect'])
	for effect in bonus_effects:
		if ignore_condition or is_effect_condition_met(performing_player, effect, null):
			all_effects.append(effect)
		elif 'negative_condition_effect' in effect:
			all_effects.append(effect['negative_condition_effect'])

	for effect in all_effects:
		if not 'card_id' in effect:
			effect['card_id'] = card.id
		if 'negative_condition_effect' in effect:
			effect['negative_condition_effect']['card_id'] = card.id
	return all_effects

func remove_remaining_effect(effect, card_id):
	if active_strike and 'timing' in effect:
		for remaining_effect in active_strike.remaining_effect_list:
			if remaining_effect['timing'] == effect['timing'] and remaining_effect['card_id'] == card_id:
				active_strike.remaining_effect_list.erase(remaining_effect)
				break

func get_base_remaining_effect(effect):
	# Gets the base effect in the active strike's remaining effect list
	if 'is_negative_effect' in effect and effect['is_negative_effect']:
		# Find the actual effect this goes with, to avoid revealing condition outcomes early
		for remaining_effect in active_strike.remaining_effect_list:
			if 'negative_condition_effect' in remaining_effect:
				if remaining_effect['negative_condition_effect'] == effect:
					return remaining_effect
	return effect

func do_remaining_effects(performing_player : Player, next_state):
	var events = []
	while active_strike.remaining_effect_list.size() > 0:
		var remaining_effect_count = active_strike.remaining_effect_list.size()
		if remaining_effect_count > 1:
			# Check to see if any of these effects actually have their condition met (or have a negative condition).
			# If more than 1, send only those choices to the player.
			# If only 1 does, remove it from the list and do it immediately.
			# If none do, this is over, clear out the list.
			var effects_to_choose = []
			for effect in active_strike.remaining_effect_list:
				if is_effect_condition_met(performing_player, effect, null):
					effects_to_choose.append(effect)
				elif 'negative_condition_effect' in effect and is_effect_condition_met(performing_player, effect['negative_condition_effect'], null):
					effects_to_choose.append(effect['negative_condition_effect'])

			if effects_to_choose.size() > 1:
				# Send choice to player
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.type = Enums.DecisionType.DecisionType_ChooseSimultaneousEffect
				decision_info.player = performing_player.my_id
				decision_info.choice = []
				for effect in effects_to_choose:
					decision_info.choice.append(get_base_remaining_effect(effect))
				events += [create_event(Enums.EventType.EventType_Strike_EffectChoice, performing_player.my_id, 0, "EffectOrder")]
				break
			elif effects_to_choose.size() == 1:
				var effect = effects_to_choose[0]
				active_strike.remaining_effect_list.erase(effect)
				events += do_effect_if_condition_met(performing_player, effect['card_id'], effect, null)

				if game_state == Enums.GameState.GameState_PlayerDecision:
					break
			else:
				# No more effects have their conditions met.
				active_strike.remaining_effect_list = []
		else:
			# Only 1 effect in the list, do it.
			var effect = active_strike.remaining_effect_list[0]
			active_strike.remaining_effect_list = []
			events += do_effect_if_condition_met(performing_player, effect['card_id'], effect, null)
		if game_over:
			return events

	if active_strike.remaining_effect_list.size() == 0 and not game_state == Enums.GameState.GameState_PlayerDecision:
		active_strike.effects_resolved_in_timing = 0
		active_strike.strike_state = next_state
	return events

func do_remaining_overdrive(performing_player : Player):
	var events = []
	change_game_state(Enums.GameState.GameState_Boost_Processing)
	while remaining_overdrive_effects.size() > 0:
		var effect = remaining_overdrive_effects[0]
		remaining_overdrive_effects.erase(effect)
		events += do_effect_if_condition_met(performing_player, -1, effect, null)
		if game_state == Enums.GameState.GameState_PlayerDecision:
			# Player has a decision to make, so stop mid-effect resolve.
			break

	if game_state != Enums.GameState.GameState_PlayerDecision:
		_append_log("%s Turn Start" % [performing_player.name])
		active_overdrive = false
		change_game_state(Enums.GameState.GameState_PickAction)
		events += [create_event(Enums.EventType.EventType_AdvanceTurn, active_turn_player, 0)]

	return events

func do_remaining_character_action(performing_player : Player):
	var events = []
	if game_state != Enums.GameState.GameState_WaitForStrike and game_state != Enums.GameState.GameState_Strike_Opponent_Set_First:
		change_game_state(Enums.GameState.GameState_Boost_Processing)
	while remaining_character_action_effects.size() > 0:
		var effect = remaining_character_action_effects[0]
		remaining_character_action_effects.erase(effect)
		events += do_effect_if_condition_met(performing_player, -1, effect, null)
		if game_state == Enums.GameState.GameState_PlayerDecision:
			# Player has a decision to make, so stop mid-effect resolve.
			break

	if game_state != Enums.GameState.GameState_PlayerDecision:
		active_character_action = false
		if game_state != Enums.GameState.GameState_WaitForStrike and game_state != Enums.GameState.GameState_Strike_Opponent_Set_First:
			events += check_hand_size_advance_turn(performing_player)
	return events

func do_set_strike_x(performing_player : Player, source : String):
	var events = []

	var value = 0
	match source:
		"random_gauge_power":
			if len(performing_player.gauge) > 0:
				var random_gauge_idx = get_random_int() % len(performing_player.gauge)
				var card = performing_player.gauge[random_gauge_idx]
				var power = get_card_stat(performing_player, card, 'power')
				value = max(power, 0)
				_append_log("%s setting X for strike from power of %s in gauge." % [performing_player.name, card_db.get_card_name(card.id)])
				events += [create_event(Enums.EventType.EventType_RevealRandomGauge, performing_player.my_id, card.id)]
		"top_discard_power":
			if len(performing_player.discards) > 0:
				var card = performing_player.discards[-1]
				var power = get_card_stat(performing_player, card, 'power')
				value = max(power, 0)
				_append_log("%s setting X for strike from power of %s on top of discards." % [performing_player.name, card_db.get_card_name(card.id)])
		"opponent_speed":
			if active_strike:
				if performing_player == active_strike.initiator:
					var defender_speed = calculate_speed(active_strike.defender, active_strike.defender_card)
					value = max(defender_speed, 0)
				else:
					var initiator_speed = calculate_speed(active_strike.initiator, active_strike.initiator_card)
					value = max(initiator_speed, 0)
		"force_spent_before_strike":
			value = performing_player.force_spent_before_strike
		_:
			assert(false, "Unknown source for setting X")

	events += performing_player.set_strike_x(value)
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
			events += do_effect_if_condition_met(performing_player, card.id, effect, null)
			if game_state == Enums.GameState.GameState_PlayerDecision:
				# Player has a decision to make, so stop mid-effect resolve.
				break

			# Effect was resolved, continue loop to resolve more.
			active_strike.effects_resolved_in_timing += 1
		elif boost_effects_resolved < len(boost_effects):
			# Resolve boost effects
			var effect = boost_effects[boost_effects_resolved]
			events += do_effect_if_condition_met(performing_player, card.id, effect, null)
			if game_state == Enums.GameState.GameState_PlayerDecision:
				# Player has a decision to make, so stop mid-effect resolve.
				break

			# Effect was resolved, continue loop to resolve more.
			active_strike.effects_resolved_in_timing += 1
		elif character_effects_resolved < len(character_effects):
			# Resolve character effects
			var effect = character_effects[character_effects_resolved]
			events += do_effect_if_condition_met(performing_player, card.id, effect, null)
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

func is_location_in_range(attacking_player, card, test_location : int):
	if get_card_stat(attacking_player, card, 'range_min') == -1:
		return false
	var min_range = get_card_stat(attacking_player, card, 'range_min') + attacking_player.strike_stat_boosts.min_range
	var max_range = get_card_stat(attacking_player, card, 'range_max') + attacking_player.strike_stat_boosts.max_range
	var attack_source_location = attacking_player.arena_location
	if attacking_player.strike_stat_boosts.calculate_range_from_buddy:
		attack_source_location = attacking_player.buddy_location
	var distance = abs(attack_source_location - test_location)
	if min_range <= distance and distance <= max_range:
		return true
	return false

func in_range(attacking_player, defending_player, card):
	if attacking_player.strike_stat_boosts.attack_does_not_hit:
		return false
	if defending_player.strike_stat_boosts.dodge_attacks:
		return false

	if defending_player.strike_stat_boosts.dodge_from_opposite_buddy and defending_player.is_buddy_in_play():
		var pos1 = defending_player.arena_location
		var pos2 = attacking_player.arena_location
		var buddy_pos = defending_player.get_buddy_location()
		if pos1 < pos2: # opponent is on the right
			if buddy_pos > pos1 and buddy_pos < pos2:
				return false
		else: # opponent is on the left
			if buddy_pos > pos2 and buddy_pos < pos1:
				return false


	var attack_source_location = attacking_player.arena_location
	if attacking_player.strike_stat_boosts.calculate_range_from_buddy:
		attack_source_location = attacking_player.buddy_location
	var distance = abs(attack_source_location - defending_player.arena_location)
	var opponent_in_range = is_location_in_range(attacking_player, card, defending_player.arena_location)

	if defending_player.strike_stat_boosts.dodge_at_range_min != -1:
		if defending_player.strike_stat_boosts.dodge_at_range_from_buddy:
			var buddy_distance = abs(attack_source_location - defending_player.buddy_location)
			if defending_player.strike_stat_boosts.dodge_at_range_min <= buddy_distance and buddy_distance <= defending_player.strike_stat_boosts.dodge_at_range_max:
				return false
		else:
			if defending_player.strike_stat_boosts.dodge_at_range_min <= distance and distance <= defending_player.strike_stat_boosts.dodge_at_range_max:
				return false
	if defending_player.strike_stat_boosts.higher_speed_misses:
		var attacking_speed = calculate_speed(attacking_player, active_strike.get_player_card(attacking_player))
		var defending_speed = calculate_speed(defending_player, active_strike.get_player_card(defending_player))
		if attacking_speed > defending_speed:
			return false
	return opponent_in_range

func get_total_power(performing_player : Player):
	if performing_player.strike_stat_boosts.overwrite_total_power:
		return performing_player.strike_stat_boosts.overwritten_total_power

	var card = active_strike.get_player_card(performing_player)
	var power = get_card_stat(performing_player, card, 'power')
	var power_boost = performing_player.strike_stat_boosts.power * performing_player.strike_stat_boosts.power_bonus_multiplier
	return power + power_boost

func calculate_damage(offense_player : Player, defense_player : Player, _offense_card : GameCard, defense_card : GameCard) -> int:
	var power = get_total_power(offense_player)
	var armor = defense_card.definition['armor'] + defense_player.strike_stat_boosts.armor - defense_player.strike_stat_boosts.consumed_armor
	if offense_player.strike_stat_boosts.ignore_armor or defense_player.strike_stat_boosts.lose_all_armor:
		armor = 0
	var damage_after_armor = max(power - armor, 0)
	return damage_after_armor

func check_for_stun(check_player : Player, ignore_guard : bool):
	var events = []

	var total_damage = active_strike.get_damage_taken(check_player)
	var defense_card = active_strike.get_player_card(check_player)
	var guard = get_card_stat(check_player, defense_card, 'guard') + check_player.strike_stat_boosts.guard
	if ignore_guard:
		guard = 0

	guard = max(guard, 0)
	if total_damage > guard:
		if check_player.strike_stat_boosts.stun_immunity:
			_append_log("%s has stun immunity." % [check_player.name])
			events += [create_event(Enums.EventType.EventType_Strike_Stun_Immunity, check_player.my_id, defense_card.id)]
		else:
			_append_log("%s is stunned." % [check_player.name])
			events += [create_event(Enums.EventType.EventType_Strike_Stun, check_player.my_id, defense_card.id)]
			active_strike.set_player_stunned(check_player)

	return events

func apply_damage(offense_player : Player, defense_player : Player, offense_card : GameCard, defense_card : GameCard):
	var events = []
	var power = get_total_power(offense_player)
	var armor = defense_card.definition['armor'] + defense_player.strike_stat_boosts.armor - defense_player.strike_stat_boosts.consumed_armor
	var guard = get_card_stat(defense_player, defense_card, 'guard') + defense_player.strike_stat_boosts.guard

	defense_player.strike_stat_boosts.was_hit = true

	if offense_player.strike_stat_boosts.ignore_guard:
		guard = 0
	if offense_player.strike_stat_boosts.ignore_armor or defense_player.strike_stat_boosts.lose_all_armor:
		armor = 0

	var damage_after_armor = calculate_damage(offense_player, defense_player, offense_card, defense_card)
	defense_player.life -= damage_after_armor
	if armor > 0:
		defense_player.strike_stat_boosts.consumed_armor += (power - damage_after_armor)
	events += [create_event(Enums.EventType.EventType_Strike_TookDamage, defense_player.my_id, damage_after_armor, "", defense_player.life)]

	_append_log("%s %s has %s total power." % [offense_player.name, card_db.get_card_name(offense_card.id), str(power)])
	_append_log("%s %s has %s total armor and %s total guard." % [defense_player.name, card_db.get_card_name(defense_card.id), str(armor), str(guard)])
	_append_log("%s takes %s damage. Life is now %s." % [defense_player.name, str(damage_after_armor), str(defense_player.life)])

	active_strike.add_damage_taken(defense_player, damage_after_armor)
	if offense_player.strike_stat_boosts.cannot_stun:
		_append_log("%s %s cannot stun." % [offense_player.name, card_db.get_card_name(offense_card.id)])
	else:
		events += check_for_stun(defense_player, offense_player.strike_stat_boosts.ignore_guard)

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
	var gauge_discard_reminder = false
	if 'gauge_discard_reminder' in card.definition:
		gauge_discard_reminder = true

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
				decision_info.limitation = "gauge"
				decision_info.cost = gauge_cost
				events += [create_event(Enums.EventType.EventType_Strike_PayCost_Gauge, performing_player.my_id, card.id, "", gauge_discard_reminder)]
			elif force_cost > 0:
				decision_info.limitation = "force"
				decision_info.cost = force_cost
				events += [create_event(Enums.EventType.EventType_Strike_PayCost_Force, performing_player.my_id, card.id)]
		else:
			# Failed to pay the cost by default.
			events += performing_player.invalidate_card(card)
			events += performing_player.add_to_discards(card)
			if performing_player == active_strike.initiator:
				if active_strike.initiator_ex_card != null:
					events += performing_player.add_to_discards(active_strike.initiator_ex_card)
					active_strike.initiator_ex_card = null
					performing_player.strike_stat_boosts.remove_ex()
			else:
				if active_strike.defender_ex_card != null:
					events += performing_player.add_to_discards(active_strike.defender_ex_card)
					active_strike.defender_ex_card = null
					performing_player.strike_stat_boosts.remove_ex()
			var new_wild_card = null
			while new_wild_card == null:
				events += performing_player.wild_strike(true);
				if game_over:
					return events
				new_wild_card = active_strike.get_player_card(performing_player)
				is_special = new_wild_card.definition['type'] == "special"
				card_forced_invalid = (is_special and performing_player.specials_invalid)
				if card_forced_invalid:
					events += performing_player.invalidate_card(new_wild_card)
					events += performing_player.add_to_discards(new_wild_card)
					new_wild_card = null
			events += [create_event(Enums.EventType.EventType_Strike_PayCost_Unable, performing_player.my_id, new_wild_card.id)]
	return events

func do_hit_response_effects(offense_player : Player, defense_player : Player, incoming_damage : int, next_state : StrikeState):
	# If more of these are added, need to sequence them to ensure all handled correctly.
	var events = []
	active_strike.strike_state = next_state

	# Assumes these will be armor-related.
	# No choices currently allowed at this timing.
	var effects = get_all_effects_for_timing("when_hit", defense_player, active_strike.get_player_card(defense_player))
	for effect in effects:
		events += do_effect_if_condition_met(defense_player, -1, effect, null)
	assert(active_strike.strike_state == next_state)

	if defense_player.strike_stat_boosts.when_hit_force_for_armor:
		change_game_state(Enums.GameState.GameState_PlayerDecision)
		decision_info.player = defense_player.my_id
		decision_info.type = Enums.DecisionType.DecisionType_ForceForArmor
		decision_info.choice_card_id = active_strike.get_player_card(defense_player).id
		events += [create_event(Enums.EventType.EventType_Strike_ForceForArmor, defense_player.my_id, incoming_damage, "", offense_player.strike_stat_boosts.ignore_armor)]

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

func continue_resolve_strike(events):
	if active_strike.in_setup:
		return continue_setup_strike(events)

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
				# Discard any EX cards
				if active_strike.initiator_ex_card != null:
					events += active_strike.initiator.add_to_discards(active_strike.initiator_ex_card)
				# Ask player to pay for this card if applicable.
				events += ask_for_cost(active_strike.initiator, active_strike.initiator_card, StrikeState.StrikeState_Defender_PayCosts)
			StrikeState.StrikeState_Defender_PayCosts:
				# Discard any EX cards
				if active_strike.defender_ex_card != null:
					events += active_strike.defender.add_to_discards(active_strike.defender_ex_card)
				# Ask player to pay for this card if applicable.
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
			StrikeState.StrikeState_Card1_DetermineHit:
				if player1.strike_stat_boosts.calculate_range_from_buddy:
					_append_log("Range Check: %s's %s (%s) vs %s (%s)." % [player1.name, player1.get_buddy_name(), player1.get_buddy_location(), player2.name, player2.arena_location])
				else:
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
			StrikeState.StrikeState_Card2_DetermineHit:
				if player2.strike_stat_boosts.calculate_range_from_buddy:
					_append_log("Range Check: %s's %s (%s) vs %s (%s)." % [player2.name, player2.get_buddy_name(), player2.get_buddy_location(), player1.name, player1.arena_location])
				else:
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
				events += handle_strike_attack_cleanup(player1, card1)
				events += handle_strike_attack_cleanup(player2, card2)

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

	if game_state == Enums.GameState.GameState_PlayerDecision and decision_info.type == Enums.DecisionType.DecisionType_ForceBoostSustainTopdeck:
		do_topdeck_boost(events)
		events = []

	return events

func handle_strike_attack_cleanup(performing_player : Player, card):
	var events = []
	var hit = active_strike.player1_hit
	var stat_boosts = performing_player.strike_stat_boosts
	if active_strike.get_player(2) == performing_player:
		hit = active_strike.player2_hit
	var other_player = _get_player(get_other_player(performing_player.my_id))
	if performing_player.is_set_aside_card(card.id):
		events += [create_event(Enums.EventType.EventType_SetCardAside, performing_player.my_id, card.id)]
	elif performing_player.strike_stat_boosts.seal_attack_on_cleanup:
		events += performing_player.add_to_sealed(card)
	elif performing_player.strike_stat_boosts.return_attack_to_hand:
		events += performing_player.add_to_hand(card)
	elif performing_player.strike_stat_boosts.move_strike_to_opponent_boosts:
		events += other_player.add_to_continuous_boosts(card)
		other_player.sustained_boosts.append(card.id)
	elif performing_player.strike_stat_boosts.move_strike_to_boosts:
		events += performing_player.add_to_continuous_boosts(card)
		performing_player.sustained_boosts.append(card.id)
	elif performing_player.strike_stat_boosts.attack_to_topdeck_on_cleanup:
		events += performing_player.add_to_top_of_deck(card)
	elif performing_player.strike_stat_boosts.discard_attack_on_cleanup:
		events += performing_player.add_to_discards(card)
	elif hit or stat_boosts.always_add_to_gauge:
		_append_log("%s %s goes to gauge after the attack." % [performing_player.name, card_db.get_card_name(card.id)])
		events += performing_player.add_to_gauge(card)
	else:
		_append_log("%s %s discarded after the attack." % [performing_player.name, card_db.get_card_name(card.id)])
		events += performing_player.add_to_discards(card)

	return events

func do_topdeck_boost(events):
	# Unique case where we need to push all events to the queue, draw the top deck, and boost it.
	var performing_player = _get_player(active_strike.remaining_topdeck_boosts_player_id)
	performing_player.sustain_next_boost = true
	active_strike.remaining_topdeck_boosts -= 1

	events += performing_player.draw(1)
	event_queue += events
	change_game_state(Enums.GameState.GameState_PlayerDecision)
	decision_info.type = Enums.DecisionType.DecisionType_BoostNow
	do_boost(performing_player, performing_player.hand[performing_player.hand.size()-1].id)

func begin_resolve_boost(performing_player : Player, card_id : int):
	var events = []

	active_boost = Boost.new()
	active_boost.playing_player = performing_player
	active_boost.card = card_db.get_card(card_id)
	performing_player.remove_card_from_hand(card_id)
	performing_player.remove_card_from_gauge(card_id)
	events += [create_event(Enums.EventType.EventType_Boost_Played, performing_player.my_id, card_id)]

	# Resolve all immediate/now effects
	# If continuous, put it into continous boost tracking.
	events = continue_resolve_boost(events)
	return events

func continue_resolve_boost(events):
	if game_state == Enums.GameState.GameState_WaitForStrike or game_state == Enums.GameState.GameState_Strike_Opponent_Set_First:
		active_boost.strike_after_boost = true
	change_game_state(Enums.GameState.GameState_Boost_Processing)

	var effects = card_db.get_card_boost_effects_now_immediate(active_boost.card)
	while true:
		if active_boost.effects_resolved < len(effects):
			var effect = effects[active_boost.effects_resolved]
			events += do_effect_if_condition_met(active_boost.playing_player, active_boost.card.id, effect, null)
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
			events = boost_play_cleanup(events, active_boost.playing_player)
			break

		if game_over:
			break

	return events

func boost_finish_resolving_card(performing_player : Player):
	var events = []
	# All boost immediate/now effects are done.
	# If continuous, add to player.
	# If immediate, add to discard.
	if active_boost.card.definition['boost']['boost_type'] == "continuous" and not active_boost.discard_on_cleanup:
		events += performing_player.add_to_continuous_boosts(active_boost.card)
		if active_strike:
			# Do the during_strike effects and add any before effects to the remaining effects list.
			for effect in active_boost.card.definition['boost']['effects']:
				if effect['timing'] == "during_strike":
					events += do_effect_if_condition_met(performing_player, active_boost.card.id, effect, null)
				elif (effect['timing'] == "before" or effect['timing'] == "both_players_before") and (active_strike.strike_state == StrikeState.StrikeState_Card1_Before or active_strike.strike_state == StrikeState.StrikeState_Card2_Before):
					effect['card_id'] = active_boost.card.id
					active_strike.remaining_effect_list.append(effect)

		if performing_player.sustain_next_boost:
			performing_player.sustained_boosts.append(active_boost.card.id)
	else:
		if active_boost.seal_on_cleanup:
			events += performing_player.add_to_sealed(active_boost.card)
		elif active_boost.card.id in active_boost.cleanup_to_gauge_card_ids:
			events += performing_player.add_to_gauge(active_boost.card)
		elif active_boost.card.id in active_boost.cleanup_to_hand_card_ids:
			events += performing_player.add_to_hand(active_boost.card)
		else:
			events += performing_player.add_to_discards(active_boost.card)

	performing_player.sustain_next_boost = false
	if game_state == Enums.GameState.GameState_WaitForStrike or game_state == Enums.GameState.GameState_Strike_Opponent_Set_First:
		active_boost.strike_after_boost = true
	return events

func boost_play_cleanup(events, performing_player : Player):
	if performing_player.strike_on_boost_cleanup and not active_strike:
		performing_player.strike_on_boost_cleanup = false
		active_boost.strike_after_boost = true
		events += [create_event(Enums.EventType.EventType_ForceStartStrike, performing_player.my_id, 0)]
		decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
		decision_info.player = performing_player.my_id

	if active_boost.strike_after_boost and not active_strike:
		if game_state != Enums.GameState.GameState_Strike_Opponent_Set_First:
			change_game_state(Enums.GameState.GameState_WaitForStrike)
		active_boost = null
	elif active_boost.action_after_boost and not active_strike:
		events += [create_event(Enums.EventType.EventType_Boost_ActionAfterBoost, performing_player.my_id, 0)]
		change_game_state(Enums.GameState.GameState_PickAction)
		active_boost = null
	else:
		if active_strike:
			# If this strike is mid-before effects or mid-after effects, add this boost's effects to the list.
			if active_strike.strike_state == StrikeState.StrikeState_Card1_Before or active_strike.strike_state == StrikeState.StrikeState_Card2_Before:
				for effect in active_boost.card.definition['boost']['effects']:
					if effect['timing'] == "before" or effect['timing'] == "both_players_before":
						effect['card_id'] = active_boost.card.id
						active_strike.remaining_effect_list.append(effect)
			elif active_strike.strike_state == StrikeState.StrikeState_Card1_After or active_strike.strike_state == StrikeState.StrikeState_Card2_After:
				for effect in active_boost.card.definition['boost']['effects']:
					if effect['timing'] == "after" or effect['timing'] == "both_players_after":
						effect['card_id'] = active_boost.card.id
						active_strike.remaining_effect_list.append(effect)

			# Continue resolving the strike (or doing another boost if you're doing Faust things...)
			if active_strike.remaining_topdeck_boosts > 0 and performing_player.deck.size() > 0:
				active_boost = null
				do_topdeck_boost(events)
				events = []
			else:
				active_boost = null
				active_strike.effects_resolved_in_timing += 1
				events = continue_resolve_strike(events)
		else:
			active_boost = null
			events += check_hand_size_advance_turn(performing_player)
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
	if game_state != Enums.GameState.GameState_PickAction and not wait_for_mid_strike_boost():
		return false
	if active_turn_player != performing_player.my_id and not wait_for_mid_strike_boost():
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
	if performing_player.bonus_actions > 0:
		change_game_state(Enums.GameState.GameState_PickAction)
		performing_player.bonus_actions -= 1
		_append_log("%s Taking Bonus Action (%s left)" % [performing_player.name, performing_player.bonus_actions])
		events += [create_event(Enums.EventType.EventType_Boost_ActionAfterBoost, performing_player.my_id, performing_player.bonus_actions)]
	else:
		events += performing_player.draw(1)
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
	events += performing_player.draw(1)
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
	var events = performing_player.begin_reshuffle(true)
	event_queue += events
	return true

func do_finish_reshuffle(performing_player : Player, manual : bool) -> bool:
	var events = performing_player.reshuffle_discard(manual)
	events += check_hand_size_advance_turn(performing_player)
	event_queue += events
	return true

func do_move(performing_player : Player, card_ids, new_arena_location) -> bool:
	printlog("MainAction: MOVE by %s to %s" % [performing_player.name, str(new_arena_location)])
	if not can_do_move(performing_player):
		printlog("ERROR: Cannot perform the move action for this player.")
		return false

	var ignore_force_req = false
	if not performing_player.can_move_to(new_arena_location, ignore_force_req):
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
	events += performing_player.draw(force_generated)
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
			printlog("ERROR: Tried to exceed with cards that not in gauge.")
			return false
	if len(card_ids) < performing_player.exceed_cost:
		printlog("ERROR: Tried to exceed with too few cards.")
		return false

	_append_log("%s Turn Action - Exceed" % [performing_player.name])
	var events = []
	if performing_player.has_overdrive:
		events = performing_player.add_to_overdrive(card_ids)
	else:
		events = performing_player.discard(card_ids)
	events += performing_player.exceed()
	if game_state == Enums.GameState.GameState_AutoStrike:
		# Draw the set aside card.
		var card = performing_player.get_set_aside_card(decision_info.effect_type)
		events += performing_player.add_to_hand(card)
		# Strike with it
		event_queue += events
		events = []
		change_game_state(Enums.GameState.GameState_PickAction)
		performing_player.next_strike_faceup = true
		do_strike(performing_player, card.id, false, -1)
	elif game_state != Enums.GameState.GameState_WaitForStrike and game_state != Enums.GameState.GameState_PlayerDecision:
		events += check_hand_size_advance_turn(performing_player)
	else:
		# Some other player action will result in the end turn finishing.
		active_exceed = true
	event_queue += events
	return true

func do_boost(performing_player : Player, card_id : int, payment_card_ids : Array = []) -> bool:
	printlog("MainAction: BOOST by %s - %s" % [get_player_name(performing_player.my_id), card_db.get_card_id(card_id)])
	if game_state != Enums.GameState.GameState_PickAction or performing_player.my_id != active_turn_player:
		if not wait_for_mid_strike_boost():
			printlog("ERROR: Tried to boost but not your turn")
			assert(false)
			return false

	if game_state == Enums.GameState.GameState_PickAction:
		_append_log("%s Turn Action - Boost - %s." % [performing_player.name, card_db.get_card_name(card_id)])
	else:
		_append_log("%s Boost from effect boosting - %s." % [performing_player.name, card_db.get_card_name(card_id)])
	var events = []
	if payment_card_ids.size() > 0:
		var card_names = card_db.get_card_name(payment_card_ids[0])
		for i in range(1, payment_card_ids.size()):
			card_names += ", " + card_db.get_card_name(payment_card_ids[i])
		_append_log("%s paid for %s with %s." % [performing_player.name, card_db.get_card_name(card_id), card_names])
		events += performing_player.discard(payment_card_ids)
	events += begin_resolve_boost(performing_player, card_id)
	event_queue += events
	return true

func do_strike(performing_player : Player, card_id : int, wild_strike: bool, ex_card_id : int,
		opponent_sets_first : bool = false) -> bool:
	printlog("MainAction: STRIKE by %s card %s wild %s" % [get_player_name(performing_player.my_id), card_db.get_card_id(card_id), str(wild_strike)])
	if game_state == Enums.GameState.GameState_PickAction:
		if performing_player.my_id != active_turn_player:
			printlog("ERROR: Tried to strike but not current player")
			return false
	elif game_state == Enums.GameState.GameState_Strike_Opponent_Response:
		if performing_player.my_id != get_other_player(active_turn_player):
			printlog("ERROR: Strike response from wrong player.")
			return false
	elif game_state == Enums.GameState.GameState_Strike_Opponent_Set_First:
		if performing_player.my_id != active_turn_player:
			printlog("ERROR: Tried to strike but not current player")
			return false
		if not opponent_sets_first:
			printlog("ERROR: Inconsistent state for opponent setting first on Strike.")
			return false
	elif game_state == Enums.GameState.GameState_WaitForStrike:
		if performing_player.my_id != decision_info.player:
			printlog("ERROR: Strike response from wrong player.")
			return false

	if performing_player.next_strike_from_gauge:
		if not wild_strike and not performing_player.is_card_in_gauge(card_id):
			if not (game_state == Enums.GameState.GameState_Strike_Opponent_Set_First or performing_player.next_strike_random_gauge):
				printlog("ERROR: Tried to strike with a card not in gauge.")
				return false
		if ex_card_id != -1:
			printlog("ERROR: Tried to ex strike from gauge.")
			return false
	else:
		if not wild_strike and not performing_player.is_card_in_hand(card_id):
			if not (game_state == Enums.GameState.GameState_Strike_Opponent_Set_First or performing_player.next_strike_random_gauge):
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
			if not opponent_sets_first:
				initialize_new_strike(performing_player, opponent_sets_first)

			if wild_strike:
				_append_log("%s Turn Action - Strike - Wild Swing" % [performing_player.name])
				events += performing_player.wild_strike()
				if game_over:
					event_queue += events
					return true
				card_id = active_strike.initiator_card.id
			elif performing_player.next_strike_random_gauge:
				events += performing_player.random_gauge_strike()
				performing_player.next_strike_random_gauge = false
				if game_over:
					event_queue += events
					return true
				card_id = active_strike.initiator_card.id
			else:
				active_strike.initiator_card = card_db.get_card(card_id)
				if performing_player.next_strike_from_gauge:
					performing_player.remove_card_from_gauge(card_id)
					active_strike.initiator_set_from_gauge = true
					performing_player.next_strike_from_gauge = false
				else:
					performing_player.remove_card_from_hand(card_id)

				if ex_card_id != -1:
					_append_log("%s Turn Action - Strike - EX" % [performing_player.name])
					active_strike.initiator_ex_card = card_db.get_card(ex_card_id)
					performing_player.remove_card_from_hand(ex_card_id)
				else:
					_append_log("%s Turn Action - Strike" % [performing_player.name])

			var reveal_immediately = false
			if active_strike.initiator.next_strike_faceup:
				reveal_immediately = true
				active_strike.initiator_set_face_up = true
				active_strike.initiator.next_strike_faceup = false

			# Send the EX first as that is visual and logic is triggered off the regular one.
			if ex_card_id != -1:
				events += [create_event(Enums.EventType.EventType_Strike_Started_Ex, performing_player.my_id, ex_card_id, "", reveal_immediately)]
			events += [create_event(Enums.EventType.EventType_Strike_Started, performing_player.my_id, card_id, "", reveal_immediately)]
			events = continue_setup_strike(events)

		Enums.GameState.GameState_Strike_Opponent_Set_First:
			if opponent_sets_first: # should always be true
				initialize_new_strike(performing_player, opponent_sets_first)
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
	var card = active_strike.get_player_card(performing_player)
	if decision_info.type == Enums.DecisionType.DecisionType_PayStrikeCost_Required and wild_strike:
		# Only allowed if you can't pay the cost.
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
	if wild_strike:
		_append_log("%s did a wild swing instead of validating %s." % [performing_player.name, card_db.get_card_name(card.id)])
		# Replace existing card with a wild strike
		var current_card = active_strike.get_player_card(performing_player)
		events += performing_player.invalidate_card(current_card)
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
				card_names += ", " + card_db.get_card_name(card_ids[i])
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
	events = continue_resolve_strike(events)
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
	events = continue_resolve_strike(events)
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
		events = boost_play_cleanup(events, performing_player)

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
		var destination_string = ""

		for card_id in card_ids:
			if decision_info.destination == "gauge":
				events += performing_player.move_card_from_hand_to_gauge(card_id)
				destination_string = "gauge"
			elif decision_info.destination == "topdeck":
				events += performing_player.move_card_from_hand_to_deck(card_id)
				card_names = str(card_ids.size())
				destination_string = "top of deck"
			else:
				assert(false, "Unknown destination for do_card_from_hand_to_gauge")

		_append_log("%s moved cards (%s) from hand to %s." % [performing_player.name, card_names, destination_string])

	if active_overdrive:
		events += do_remaining_overdrive(performing_player)
	elif active_boost:
		active_boost.effects_resolved += 1
		events = continue_resolve_boost(events)
	elif active_strike:
		active_strike.effects_resolved_in_timing += 1
		events = continue_resolve_strike(events)
	elif active_character_action:
		events += do_remaining_character_action(performing_player)
	elif active_exceed:
		active_exceed = false
		events += check_hand_size_advance_turn(performing_player)
	else:
		# Could be exceeding.
		printlog("ERROR: do_card_from_hand_to_gauge but no active strike or boost.")

	event_queue += events
	return true

func do_boost_name_card_choice_effect(performing_player : Player, card_id : int) -> bool:
	var card_name = card_db.get_card_name(card_id)
	if card_id == -1:
		card_name = "a nonexistent card"
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
	if active_overdrive:
		events += do_remaining_overdrive(performing_player)
	elif active_boost:
		active_boost.effects_resolved += 1
		events = continue_resolve_boost(events)
	elif active_strike:
		active_strike.effects_resolved_in_timing += 1
		events = continue_resolve_strike(events)

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
	var copying_effect = false
	if decision_info.effect_type:
		copying_effect = decision_info.effect_type == "copy_other_hit_effect"

	if active_overdrive:
		game_state = Enums.GameState.GameState_Boost_Processing
	elif active_boost:
		game_state = Enums.GameState.GameState_Boost_Processing
	elif active_strike:
		game_state = Enums.GameState.GameState_Strike_Processing
	elif active_character_action:
		game_state = Enums.GameState.GameState_Boost_Processing
	elif active_exceed:
		game_state = Enums.GameState.GameState_Boost_Processing

	if decision_info.type == Enums.DecisionType.DecisionType_ChooseSimultaneousEffect:
		if copying_effect:
			# If we're duplicating an effect, no need to remove it yet
			decision_info.effect_type = ""
		else:
			# This was the player choosing what to do next.
			# Remove this effect from the remaining effects.
			active_strike.remaining_effect_list.erase(get_base_remaining_effect(effect))

	var events = do_effect_if_condition_met(performing_player, card_id, effect, null)
	if game_state == Enums.GameState.GameState_PlayerDecision and decision_info.type == Enums.DecisionType.DecisionType_ForceBoostSustainTopdeck:
		# Handle stupid Faust case.
		do_topdeck_boost(events)
		events = []
	else:
		if game_state != Enums.GameState.GameState_PlayerDecision:
			if active_overdrive:
				events += do_remaining_overdrive(performing_player)
			elif active_boost:
				active_boost.effects_resolved += 1
				events = continue_resolve_boost(events)
			elif active_strike:
				active_strike.effects_resolved_in_timing += 1
				events = continue_resolve_strike(events)
			elif active_character_action:
				events += do_remaining_character_action(performing_player)
			elif active_exceed:
				active_exceed = false
				if game_state != Enums.GameState.GameState_WaitForStrike:
					events += check_hand_size_advance_turn(performing_player)
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

func do_choose_from_boosts(performing_player : Player, card_ids : Array) -> bool:
	printlog("SubAction: CHOOSE FROM BOOSTS by %s cards: %s" % [performing_player.name, str(card_ids)])
	if game_state != Enums.GameState.GameState_PlayerDecision or decision_info.type != Enums.DecisionType.DecisionType_ChooseFromBoosts:
		printlog("ERROR: Tried to choose from boosts but not in correct game state.")
		return false

	# Validation.
	if card_ids.size() < decision_info.amount_min or card_ids.size() > decision_info.amount:
		printlog("ERROR: Tried to choose from boosts with wrong number of cards.")
		return false

	for card_id in card_ids:
		if not performing_player.is_card_in_continuous_boosts(card_id):
			printlog("ERROR: Tried to choose from boosts with card not in boosts.")
			return false

	# Move the cards.
	var events = []
	for card_id in card_ids:
		events += [create_event(Enums.EventType.EventType_SustainBoost, performing_player.my_id, card_id)]
		performing_player.sustained_boosts.append(card_id)
		_append_log("%s sustained %s." % [performing_player.name, card_db.get_card_name(card_id)])

	if active_boost:
		active_boost.effects_resolved += 1
		events = continue_resolve_boost(events)
	elif active_strike:
		active_strike.effects_resolved_in_timing += 1
		events = continue_resolve_strike(events)
	else:
		printlog("ERROR: When is this choose from boosts happening?")
		assert(false, "When is this choose from boosts happening?")

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
		if decision_info.source == "discard":
			if not performing_player.is_card_in_discards(card_id):
				printlog("ERROR: Tried to choose from discard with card not in discard.")
				return false
		elif decision_info.source == "sealed":
			if not performing_player.is_card_in_sealed(card_id):
				printlog("ERROR: Tried to choose from discard with card not in sealed.")
				return false
		elif decision_info.source == "overdrive":
			if not performing_player.is_card_in_overdrive(card_id):
				printlog("ERROR: Tried to choose from discard with card not in overdrive.")
				return false
		else:
			printlog("ERROR: Tried to choose from discard with unknown source.")
			return false

	for card_id in card_ids:
		var card = card_db.get_card(card_id)
		var limitation = decision_info.limitation
		match limitation:
			"special":
				if card.definition['type'] != "special":
					printlog("ERROR: Tried to choose from discard with card that doesn't meet limitation special.")
					return false
			"ultra":
				if card.definition['type'] != "ultra":
					printlog("ERROR: Tried to choose from discard with card that doesn't meet limitation ultra.")
					return false
			_:
				pass

	# Move the cards.
	var events = []
	for card_id in card_ids:
		var destination = decision_info.destination
		if decision_info.source == "discard":
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
		elif decision_info.source == "sealed":
			match destination:
				"hand":
					events += performing_player.move_card_from_sealed_to_hand(card_id)
				_:
					printlog("ERROR: Choose from sealed destination not implemented.")
					assert(false, "Choose from sealed destination not implemented.")
					return false

			_append_log("%s chose %s to put from sealed to %s." % [performing_player.name, card_db.get_card_name(card_id), destination])
		elif decision_info.source == "overdrive":
			match destination:
				"discard":
					events += performing_player.discard([card_id])
				_:
					printlog("ERROR: Choose from overdrive destination not implemented.")
					assert(false, "Choose from overdrive destination not implemented.")
					return false

			_append_log("%s chose %s to put from overdrive to %s." % [performing_player.name, card_db.get_card_name(card_id), destination])
		else:
			printlog("ERROR: Choose from discard source not implemented.")
			assert(false, "Choose from discard source not implemented.")
			return false

	if active_overdrive:
		events += do_remaining_overdrive(performing_player)
	elif active_boost:
		active_boost.effects_resolved += 1
		events = continue_resolve_boost(events)
	elif active_strike:
		active_strike.effects_resolved_in_timing += 1
		events = continue_resolve_strike(events)
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

		if active_overdrive:
			events += do_remaining_overdrive(performing_player)
		elif active_boost:
			active_boost.effects_resolved += 1
			events = continue_resolve_boost(events)
		elif active_strike:
			active_strike.effects_resolved_in_timing += 1
			events = continue_resolve_strike(events)
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

		var to_hand = 'spent_cards_to_hand' in decision_effect and decision_effect['spent_cards_to_hand']
		if to_hand:
			if effect_text:
				_append_log("%s returned %s gauge to hand for %s: %s." % [performing_player.name, str(gauge_generated), effect_text, card_names])
			else:
				_append_log("%s returned %s gauge to hand: %s." % [performing_player.name, str(gauge_generated), card_names])
		else:
			_append_log("%s spent %s gauge for %s: %s." % [performing_player.name, str(gauge_generated), effect_text, card_names])

		# Move the spent cards to the right place.
		if to_hand:
			for card_id in card_ids:
				events += performing_player.move_card_from_gauge_to_hand(card_id)
		else:
			events += performing_player.discard(card_ids)
		for i in range(0, effect_times):
			events += handle_strike_effect(decision_info.choice_card_id, decision_effect, performing_player)

	if game_state != Enums.GameState.GameState_PlayerDecision:
		if active_overdrive:
			events += do_remaining_overdrive(performing_player)
		elif active_boost:
			active_boost.effects_resolved += 1
			events = continue_resolve_boost(events)
		elif active_strike:
			active_strike.effects_resolved_in_timing += 1
			events = continue_resolve_strike(events)
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
	if not decision_info.can_pass and len(card_ids) != amount and performing_player.hand.size() >= amount:
		printlog("ERROR: Tried to choose to discard wrong number of cards.")
		return false

	for card_id in card_ids:
		if not performing_player.is_card_in_hand(card_id):
			printlog("ERROR: Tried to choose to discard with card not in hand.")
			return false
		if decision_info.limitation:
			var card = card_db.get_card(card_id)
			if card.definition['type'] != decision_info.limitation:
				printlog("ERROR: Tried to choose to discard with card that doesn't meet limitation.")
				return false

	var skip_effect = false
	if len(card_ids) == 0:
		_append_log("%s chose to %s nothing." % [performing_player.name, decision_info.destination])
		skip_effect = true

	var effect = {
		"effect_type": decision_info.effect_type,
		"card_ids": card_ids,
		"destination": decision_info.destination
	}
	if not skip_effect and decision_info.bonus_effect:
		effect['and'] = decision_info.bonus_effect

	var events = []
	if active_overdrive:
		game_state = Enums.GameState.GameState_Boost_Processing
		events = handle_strike_effect(decision_info.choice_card_id, effect, performing_player)
		events += do_remaining_overdrive(performing_player)
	elif active_boost:
		game_state = Enums.GameState.GameState_Boost_Processing
		events = handle_strike_effect(decision_info.choice_card_id, effect, performing_player)
		active_boost.effects_resolved += 1
		events = continue_resolve_boost(events)
	elif active_strike:
		game_state = Enums.GameState.GameState_Strike_Processing
		events = handle_strike_effect(decision_info.choice_card_id, effect, performing_player)
		active_strike.effects_resolved_in_timing += 1
		events = continue_resolve_strike(events)
	event_queue += events
	return true

func do_character_action(performing_player : Player, card_ids, action_idx : int = 0):
	printlog("MainAction: CHARACTER_ACTION %s by %s" % [str(action_idx), get_player_name(performing_player.my_id)])
	if game_state != Enums.GameState.GameState_PickAction:
		printlog("ERROR: Tried to character action but not in correct game state.")
		return false

	if performing_player.my_id != active_turn_player:
		printlog("ERROR: Tried to character action but not current player")
		return false

	var action = performing_player.get_character_action(action_idx)
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
	else:
		_append_log("%s Turn Action - Character Action." % [performing_player.name])

	# Do the character action effects.
	events += [create_event(Enums.EventType.EventType_CharacterAction, performing_player.my_id, 0)]
	performing_player.used_character_action = true
	var exceed_detail = "exceed" if performing_player.exceeded else "default"
	performing_player.used_character_action_details.append([exceed_detail, action_idx])
	remaining_character_action_effects = []
	active_character_action = true
	event_queue += events
	events = do_effect_if_condition_met(performing_player, -1, action['effect'], null)
	if game_state not in [
			Enums.GameState.GameState_WaitForStrike,
			Enums.GameState.GameState_PlayerDecision,
			Enums.GameState.GameState_Strike_Opponent_Set_First,
			Enums.GameState.GameState_Strike_Opponent_Response
	] and not wait_for_mid_strike_boost():
		events += check_hand_size_advance_turn(performing_player)
	if game_state != Enums.GameState.GameState_PlayerDecision:
		active_character_action = false
	event_queue += events
	return true

func do_bonus_turn_action(performing_player : Player, action_index : int):
	printlog("MainAction: BONUS_ACTION by %s" % [get_player_name(performing_player.my_id)])
	if game_state != Enums.GameState.GameState_PickAction:
		printlog("ERROR: Tried to bonus action but not in correct game state.")
		return false

	if performing_player.my_id != active_turn_player:
		printlog("ERROR: Tried to bonus action but not current player")
		return false

	var actions = performing_player.get_bonus_actions()
	if action_index >= len(actions):
		printlog("ERROR: Tried to bonus action with invalid index.")
		return false

	var chosen_action = actions[action_index]

	# Do the bonus action effects.
	var events = []
	events += handle_strike_effect(chosen_action['card_id'], chosen_action, performing_player)
	if game_state != Enums.GameState.GameState_WaitForStrike:
		events += check_hand_size_advance_turn(performing_player)
	event_queue += events
	return true

func do_choose_from_topdeck(performing_player : Player, chosen_card_id : int, action : String):
	printlog("SubAction: CHOOSE_FROM_TOPDECK by %s" % [get_player_name(performing_player.my_id)])
	if game_state != Enums.GameState.GameState_PlayerDecision or decision_info.type != Enums.DecisionType.DecisionType_ChooseFromTopDeck:
		printlog("ERROR: Tried to choose from topdeck but not in correct game state.")
		return false

	var destination = decision_info.destination
	var look_amount = decision_info.amount

	if action == "pass":
		chosen_card_id = -1

	_append_log("%s looking at top %s cards." % [performing_player.name, look_amount])
	var leftover_card_ids = []
	for i in range(look_amount):
		var id = performing_player.deck[i].id
		if chosen_card_id != id:
			leftover_card_ids.append(id)

	var events = []
	events += performing_player.draw(look_amount)
	match destination:
		"discard":
			events += performing_player.discard(leftover_card_ids, "top of deck")
		"topdeck":
			for card_id in leftover_card_ids:
				events += performing_player.move_card_from_hand_to_deck(card_id)
		_:
			printlog("ERROR: Choose from topdeck destination not implemented.")
			assert(false, "Choose from topdeck destination not implemented.")
			return false

	# If this effect came from a boost and another action is about to happen, cleanup that boost before continuing.
	decision_info.action = action

	var real_actions = ["boost", "strike", "pass"]
	if action in real_actions and active_boost:
		active_boost.action_after_boost = true
		active_boost.effects_resolved += 1
		events = continue_resolve_boost(events)

	# Now the boost is done and we are in the pick action state.
	match action:
		"boost":
			event_queue += events
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.type = Enums.DecisionType.DecisionType_BoostNow
			do_boost(performing_player, chosen_card_id)
		"strike":
			event_queue += events
			change_game_state(Enums.GameState.GameState_PickAction)
			do_strike(performing_player, chosen_card_id, false, -1)
		"add_to_hand":
			# We've already drawn the cards we looked at
			event_queue += events
		"add_to_gauge":
			events += performing_player.move_card_from_hand_to_gauge(chosen_card_id)
			event_queue += events
		"pass":
			events += check_hand_size_advance_turn(performing_player)
			event_queue += events
		_:
			assert(false, "Unknown action for choose from topdeck.")

	# If it wasn't a "real" action, clean up the boost now
	if action not in real_actions and active_boost:
		active_boost.effects_resolved += 1
		event_queue += continue_resolve_boost([])

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

func do_emote(performing_player : Player, is_image_emote : bool, emote : String):
	printlog("Emote by %s: %s" % [get_player_name(performing_player.my_id), emote])
	var events = []
	events += [create_event(Enums.EventType.EventType_Emote, performing_player.my_id, is_image_emote, emote)]
	event_queue += events
	return true
