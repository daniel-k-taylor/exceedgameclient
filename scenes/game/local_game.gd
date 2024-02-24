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
const CenterArenaLocation = 5
const MaxArenaLocation = 9
const ShuffleEnabled = true

# Conditions that shouldn't change during a strike
const StrikeStaticConditions = [
	"is_critical", "is_not_critical",
	"was_hit",
	"initiated_strike", "not_initiated_strike",
	"exceeded", "not_exceeded",
	"buddy_in_play",
	"boost_caused_start_of_turn_strike",
	"used_character_bonus",
	"used_character_action",
	"hit_opponent",
	"opponent_stunned",
	"initiated_face_up",
	"stunned", "not_stunned",
	"initiated_after_moving",
	"was_wild_swing",
	"last_turn_was_strike",
	"speed_greater_than",
	"is_special_or_ultra_attack", "is_normal_attack", "is_special_attack", "is_buddy_special_or_ultra_attack",
	"discarded_matches_attack_speed",
	"canceled_this_turn"
]

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
var active_overdrive_boost_top_discard_on_cleanup : bool = false
var active_change_cards : bool = false
var active_dan_effect : bool = false
var active_start_of_turn_effects : bool = false
var active_end_of_turn_effects : bool = false
var remaining_overdrive_effects = []
var remaining_character_action_effects = []
var remaining_start_of_turn_effects = []
var remaining_end_of_turn_effects = []

var decision_info : DecisionInfo = DecisionInfo.new()
var active_boost : Boost = null

var game_state : Enums.GameState = Enums.GameState.GameState_NotStarted

var full_combat_log : Array = []

func get_combat_log(log_type_filters):
	var filtered_log = full_combat_log.filter(func (item): return item['log_type'] in log_type_filters)
	var log_strings = filtered_log.map(_full_log_item_to_string)
	return "\n".join(log_strings)

func _full_log_item_to_string(log_item):
	var log_type = log_item['log_type']
	var log_player = log_item['log_player']
	var message = log_item['message']
	var prefix = ""

	var prefix_symbol = ""
	if log_type == Enums.LogType.LogType_Default:
		prefix_symbol += "**"
	if log_type == Enums.LogType.LogType_Action:
		prefix_symbol += "*"

	if log_player != null:
		if log_player == player:
			prefix += "[color={_player_color}]"
		if log_player == opponent:
			prefix += "[color={_opponent_color}]"
		prefix += "%s%s[/color] " % [prefix_symbol, log_player.name]
	else:
		prefix = prefix_symbol
	return prefix + message

func _append_log_full(log_type : Enums.LogType, log_player : Player, message : String):
	full_combat_log.append({
		'log_type': log_type,
		'log_player': log_player,
		'message': message
	})

func _card_list_to_string(cards):
	if len(cards) > 0:
		var card_names = card_db.get_card_name(cards[0].id)
		for i in range(1, cards.size()):
			card_names += ", " + card_db.get_card_name(cards[i].id)
		return card_names
	return ""

func _get_boost_and_card_name(card):
	var card_name = card.definition['display_name']
	var boost_name = card.definition['boost']['display_name']
	return "%s (%s)" % [boost_name, card_name]

func teardown():
	card_db.teardown()
	card_db.free()
	decision_info.free()

func change_game_state(new_state : Enums.GameState):
	if game_state != Enums.GameState.GameState_GameOver:
		printlog("game_state update from %s to %s" % [Enums.GameState.keys()[game_state], Enums.GameState.keys()[new_state]])
		game_state = new_state
	else:
		_append_log_full(Enums.LogType.LogType_Default, game_over_winning_player, " wins! GAME OVER")

func get_game_state() -> Enums.GameState:
	return game_state

func get_decision_info() -> DecisionInfo:
	return decision_info

func printlog(text):
	if GlobalSettings.is_logging_enabled():
		print(text)

func is_number(test_value):
	return test_value is int or test_value is float

func create_event(event_type : Enums.EventType, event_player : Enums.PlayerId, num : int, reason: String = "", extra_info = null, extra_info2 = null, extra_info3 = null):
	var card_name = card_db.get_card_name(num)
	var playerstr = "Player"
	if event_player == Enums.PlayerId.PlayerId_Opponent:
		playerstr = "Opponent"
	printlog("Event %s %s %d (card=%s)" % [Enums.EventType.keys()[event_type], playerstr, num, card_name])
	return {
		"event_name": Enums.EventType.keys()[event_type],
		"event_type": event_type,
		"event_player": event_player,
		"number": num,
		"reason": reason,
		"extra_info": extra_info,
		"extra_info2": extra_info2,
		"extra_info3": extra_info3,
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
	StrikeState_Initiator_RevealEffects,
	StrikeState_Defender_RevealEffects,
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

func get_current_strike_timing():
	if active_strike:
		if active_strike.extra_attack_in_progress:
			# Implement this later if we really need it or it makes sense.
			# Potentially needs to return the current timing of the main strike.
			assert(false)
			return "extra attack not implemented"
		else:
			match active_strike.strike_state:
				StrikeState.StrikeState_Initiator_SetEffects, StrikeState.StrikeState_Defender_SetFirst, StrikeState.StrikeState_Defender_SetEffects:
					return "set_strike"
				StrikeState.StrikeState_DuringStrikeBonuses:
					return "during_strike"
				StrikeState.StrikeState_Card1_Before, StrikeState.StrikeState_Card2_Before:
					return "before"
				StrikeState.StrikeState_Card1_Hit, StrikeState.StrikeState_Card2_Hit:
					return "hit"
				StrikeState.StrikeState_Card1_After, StrikeState.StrikeState_Card2_After:
					return "after"
				StrikeState.StrikeState_Cleanup, StrikeState.StrikeState_Cleanup_Player1Effects, StrikeState.StrikeState_Cleanup_Player2Effects:
					return "cleanup"
				_:
					return "other"
	return "no active strike"

func get_current_strike_timing_player_id():
	if active_strike:
		if active_strike.extra_attack_in_progress:
			# Implement this later if we really need it or it makes sense.
			assert(false)
			return active_strike.extra_attack_data.extra_attack_player.my_id
		else:
			match active_strike.strike_state:
				StrikeState.StrikeState_Initiator_SetEffects:
					return active_strike.initiator.my_id
				StrikeState.StrikeState_Defender_SetFirst, StrikeState.StrikeState_Defender_SetEffects:
					return active_strike.defender.my_id
				StrikeState.StrikeState_DuringStrikeBonuses:
					assert(false, "Unexpected call to get_current_strike_timing_player_id, investigate further.")
					return active_strike.initiator.my_id
				StrikeState.StrikeState_Card1_Before, StrikeState.StrikeState_Card1_Hit, StrikeState.StrikeState_Card1_After, StrikeState.StrikeState_Cleanup_Player1Effects:
					return active_strike.get_player(1).my_id
				StrikeState.StrikeState_Card2_Before, StrikeState.StrikeState_Card2_Hit, StrikeState.StrikeState_Card2_After, StrikeState.StrikeState_Cleanup_Player2Effects:
					return active_strike.get_player(2).my_id
				_:
					assert(false, "Unexpected call to get_current_strike_timing_player_id, investigate further.")
					return active_strike.get_player(1).my_id
	# If no active strike, assume it is current active player.
	return active_turn_player

enum ExtraAttackState {
	ExtraAttackState_None,
	ExtraAttackState_PayCosts,
	ExtraAttackState_DuringStrikeBonuses,
	ExtraAttackState_Activation,
	ExtraAttackState_Before,
	ExtraAttackState_DetermineHit,
	ExtraAttackState_Hit,
	ExtraAttackState_Hit_Response,
	ExtraAttackState_Hit_ApplyDamage,
	ExtraAttackState_After,
	ExtraAttackState_Cleanup,
	ExtraAttackState_CleanupEffects,
	ExtraAttackState_Complete,
}

class ExtraAttackData:
	var extra_attack_in_progress = false
	var extra_attack_card : GameCard = null
	var extra_attack_player : Player = null
	var extra_attack_previous_attack_power_bonus = 0
	var extra_attack_previous_attack_speed_bonus = 0
	var extra_attack_previous_attack_min_range_bonus = 0
	var extra_attack_previous_attack_max_range_bonus = 0
	var extra_attack_state = ExtraAttackState.ExtraAttackState_None
	var extra_attack_hit = false
	var extra_attack_remaining_effects = []
	var extra_attack_parent = null
	var extra_attack_always_miss = false
	var extra_attack_always_go_to_gauge = false

	func reset():
		extra_attack_in_progress = false
		extra_attack_card = null
		extra_attack_player = null
		extra_attack_previous_attack_power_bonus = 0
		extra_attack_previous_attack_speed_bonus = 0
		extra_attack_previous_attack_min_range_bonus = 0
		extra_attack_previous_attack_max_range_bonus = 0
		extra_attack_state = ExtraAttackState.ExtraAttackState_None
		extra_attack_hit = false
		extra_attack_remaining_effects = []
		extra_attack_parent = null
		extra_attack_always_miss = false
		extra_attack_always_go_to_gauge = false

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
	var initiator_set_from_boosts : bool = false
	var initiator_set_face_up : bool = false
	var defender_set_face_up : bool = false
	var defender_wild_strike : bool = false
	var defender_set_from_boosts : bool = false
	var strike_state
	var starting_distance : int = -1
	var in_setup : bool = true
	var waiting_for_reading_response : bool = false
	var opponent_sets_first : bool = false
	var remaining_effect_list : Array = []
	var effects_resolved_in_timing : int = 0
	var player1_hit : bool = false
	var player1_stunned : bool = false
	var player2_hit : bool = false
	var player2_stunned : bool = false
	var initiator_damage_taken = 0
	var defender_damage_taken = 0
	var remaining_forced_boosts = 0
	var remaining_forced_boosts_source = ""
	var remaining_forced_boosts_player_id = Enums.PlayerId.PlayerId_Player
	var remaining_forced_boosts_sustaining = false
	var cards_in_play: Array[GameCard] = []
	var when_hit_effects_processed = []

	var extra_attack_in_progress = false
	var extra_attack_data : ExtraAttackData = ExtraAttackData.new()

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

	func get_player_ex_card(performing_player : Player) -> GameCard:
		if performing_player == initiator:
			return initiator_ex_card
		return defender_ex_card

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
	var strike_after_boost_opponent_first = false
	var discard_on_cleanup = false
	var seal_on_cleanup = false
	var cancel_resolved = false
	var cleanup_to_gauge_card_ids = []
	var cleanup_to_hand_card_ids = []
	var parent_boost = null

class StrikeStatBoosts:
	var power : int = 0
	var power_positive_only : int = 0
	var power_modify_per_buddy_between : int = 0
	var armor : int = 0
	var consumed_armor : int = 0
	var guard : int = 0
	var speed : int = 0
	var strike_x : int = 0
	var min_range : int = 0
	var max_range : int = 0
	var attack_does_not_hit : bool = false
	var only_hits_if_opponent_on_any_buddy : bool = false
	var cannot_go_below_life : int = 0
	var dodge_attacks : bool = false
	var dodge_at_range_min : int = -1
	var dodge_at_range_max : int = -1
	var dodge_at_range_late_calculate_with : String = ""
	var dodge_at_range_from_buddy : bool = false
	var dodge_at_speed_greater_or_equal : int = -1
	var dodge_from_opposite_buddy : bool = false
	var range_includes_opponent : bool = false
	var range_includes_if_moved_past : bool = false
	var range_includes_lightningrods : bool = false
	var ignore_armor : bool = false
	var ignore_guard : bool = false
	var ignore_push_and_pull : bool = false
	var cannot_move_if_in_opponents_range : bool = false
	var cannot_stun : bool = false
	var deal_nonlethal_damage : bool = false
	var always_add_to_gauge : bool = false
	var always_add_to_overdrive : bool = false
	var discard_attack_now_for_lightningrod : bool = false
	var return_attack_to_hand : bool = false
	var move_strike_to_boosts : bool = false
	var move_strike_to_boosts_sustain : bool = true
	var move_strike_to_opponent_boosts : bool = false
	var when_hit_force_for_armor : String = ""
	var stun_immunity : bool = false
	var was_hit : bool = false
	var is_ex : bool = false
	var higher_speed_misses : bool = false
	var calculate_range_from_center : bool = false
	var calculate_range_from_buddy : bool = false
	var calculate_range_from_buddy_id : String = ""
	var attack_to_topdeck_on_cleanup : bool = false
	var discard_attack_on_cleanup : bool = false
	var seal_attack_on_cleanup : bool = false
	var power_bonus_multiplier : int = 1
	var power_bonus_multiplier_positive_only : int = 1
	var speed_bonus_multiplier : int = 1
	var active_character_effects = []
	var added_attack_effects = []
	var ex_count : int = 0
	var critical : bool = false
	var overwrite_printed_power : bool = false
	var overwritten_printed_power : int = 0
	var overwrite_total_power : bool = false
	var overwritten_total_power : int = 0
	var overwrite_total_speed : bool = false
	var overwritten_total_speed : int = 0
	var overwrite_total_armor : bool = false
	var overwritten_total_armor : int = 0
	var overwrite_total_guard : bool = false
	var overwritten_total_guard : int = 0
	var overwrite_range_to_invalid : bool = false
	var buddies_that_entered_play_this_strike : Array[String] = []
	var buddy_immune_to_flip : bool = false
	var may_generate_gauge_with_force : bool = false
	var may_invalidate_ultras : bool = false
	var increase_movement_effects_by : int = 0
	var increase_move_opponent_effects_by : int = 0
	var increase_draw_effects_by : int = 0

	func clear():
		power = 0
		power_positive_only = 0
		power_modify_per_buddy_between = 0
		armor = 0
		consumed_armor = 0
		guard = 0
		speed = 0
		strike_x = 0
		min_range = 0
		max_range = 0
		attack_does_not_hit = false
		only_hits_if_opponent_on_any_buddy = false
		cannot_go_below_life = 0
		dodge_attacks = false
		dodge_at_range_min = -1
		dodge_at_range_max = -1
		dodge_at_range_late_calculate_with = ""
		dodge_at_range_from_buddy = false
		dodge_at_speed_greater_or_equal = -1
		dodge_from_opposite_buddy = false
		range_includes_opponent = false
		range_includes_if_moved_past = false
		range_includes_lightningrods = false
		ignore_armor = false
		ignore_guard = false
		ignore_push_and_pull = false
		cannot_move_if_in_opponents_range = false
		cannot_stun = false
		deal_nonlethal_damage = false
		always_add_to_gauge = false
		always_add_to_overdrive = false
		discard_attack_now_for_lightningrod = false
		return_attack_to_hand = false
		move_strike_to_boosts = false
		move_strike_to_boosts_sustain = true
		move_strike_to_opponent_boosts = false
		when_hit_force_for_armor = ""
		stun_immunity = false
		was_hit = false
		is_ex = false
		higher_speed_misses = false
		calculate_range_from_center = false
		calculate_range_from_buddy = false
		calculate_range_from_buddy_id = ""
		attack_to_topdeck_on_cleanup = false
		discard_attack_on_cleanup = false
		seal_attack_on_cleanup = false
		power_bonus_multiplier = 1
		power_bonus_multiplier_positive_only = 1
		speed_bonus_multiplier = 1
		active_character_effects = []
		added_attack_effects = []
		ex_count = 0
		critical = false
		overwrite_printed_power = false
		overwritten_printed_power = 0
		overwrite_total_power = false
		overwritten_total_power = 0
		overwrite_total_speed = false
		overwritten_total_speed = 0
		overwrite_total_armor = false
		overwritten_total_armor = 0
		overwrite_total_guard = false
		overwritten_total_guard = 0
		overwrite_range_to_invalid = false
		buddies_that_entered_play_this_strike = []
		buddy_immune_to_flip = false
		may_generate_gauge_with_force = false
		may_invalidate_ultras = false
		increase_movement_effects_by = 0
		increase_move_opponent_effects_by = 0
		increase_draw_effects_by = 0

	func set_ex():
		ex_count += 1
		if not is_ex:
			speed += 1
			power += 1
			power_positive_only += 1
			armor += 1
			guard += 1
			is_ex = true

	func remove_ex():
		ex_count -= 1
		if ex_count == 0:
			is_ex = false
			speed -= 1
			power -= 1
			power_positive_only -= 1
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
	var sealed_area_is_secret : bool
	var deck_def : Dictionary
	var gauge : Array[GameCard]
	var continuous_boosts : Array[GameCard]
	var lightningrod_zones : Array
	var cleanup_boost_to_gauge_cards : Array
	var boosts_to_gauge_on_move : Array
	var on_buddy_boosts : Array
	var starting_location : int
	var arena_location : int
	var extra_width : int
	var reshuffle_remaining : int
	var exceeded : bool
	var exceed_cost : int
	var strike_stat_boosts : StrikeStatBoosts
	var did_end_of_turn_draw : bool
	var did_strike_this_turn : bool
	var bonus_actions : int
	var canceled_this_turn : bool
	var cancel_blocked_this_turn : bool
	var used_character_action : bool
	var used_character_action_details : Array
	var used_character_bonus : bool
	var start_of_turn_strike : bool
	var force_spent_before_strike : int
	var gauge_spent_before_strike : int
	var exceed_at_end_of_turn : bool
	var specials_invalid : bool
	var mulligan_complete : bool
	var reading_card_id : String
	var next_strike_faceup : bool
	var next_strike_from_gauge : bool
	var next_strike_from_sealed : bool
	var next_strike_random_gauge : bool
	var strike_on_boost_cleanup : bool
	var wild_strike_on_boost_cleanup : bool
	var max_hand_size : int
	var starting_hand_size_bonus : int
	var pre_strike_movement : int
	var moved_self_this_strike : bool
	var moved_past_this_strike : bool
	var spaces_moved_this_strike : int
	var spaces_moved_or_forced_this_strike : int
	var sustained_boosts : Array
	var sustain_next_boost : bool
	var buddy_starting_offset : int
	var buddy_starting_id : String
	var buddy_locations : Array[int]
	var buddy_id_to_index : Dictionary
	var do_not_cleanup_buddy_this_turn : bool
	var cannot_move : bool
	var cannot_move_past_opponent : bool
	var cannot_move_past_opponent_buddy_id : Variant
	var ignore_push_and_pull : int
	var extra_effect_after_set_strike
	var end_of_turn_boost_delay_card_ids : Array
	var saved_power : int
	var movement_limit : int
	var free_force : int
	var free_gauge : int
	var guile_change_cards_bonus : bool
	var cards_that_will_not_hit : Array[String]
	var cards_invalid_during_strike : Array[String]
	var plague_knight_discard_names : Array[String]
	var public_hand : Array[String]
	var public_hand_questionable : Array[String]
	var public_hand_tracked_topdeck : Array[int]
	var public_topdeck_id : int
	var skip_end_of_turn_draw : bool
	var dan_draw_choice : bool
	var dan_draw_choice_from_bottom : bool
	var boost_id_locations : Dictionary # [card_id : int, location : int]
	var boost_buddy_card_id_to_buddy_id_map : Dictionary # [card_id : int, buddy_id : String]
	var effect_on_turn_start
	var strike_action_disabled : bool

	func _init(id, player_name, parent_ref, card_db_ref, chosen_deck, card_start_id):
		my_id = id
		name = player_name
		parent = parent_ref
		card_database = card_db_ref
		hand = []
		deck_def = chosen_deck
		life = MaxLife
		if 'starting_life' in deck_def:
			life = deck_def['starting_life']
		extra_width = 0
		if 'wide_card' in deck_def and deck_def['wide_card']:
			extra_width = 1
		exceed_cost = deck_def['exceed_cost']
		deck = []
		deck_list = []
		strike_stat_boosts = StrikeStatBoosts.new()
		set_aside_cards = []
		sealed = []
		for deck_card_def in deck_def['cards']:
			var card_def = CardDefinitions.get_card(deck_card_def['definition_id'])
			var card = GameCard.new(card_start_id, card_def, deck_card_def['image'], id)
			card_database.add_card(card)
			if 'set_aside' in deck_card_def and deck_card_def['set_aside']:
				card.set_aside = true
				card.hide_from_reference = 'hide_from_reference' in deck_card_def and deck_card_def['hide_from_reference']
				set_aside_cards.append(card)
			elif 'start_sealed' in deck_card_def and deck_card_def['start_sealed']:
				sealed.append(card)
				parent.event_queue += [parent.create_event(Enums.EventType.EventType_Seal, my_id, card.id, "", false)]
			else:
				deck.append(card)
			deck_list.append(card)
			card_start_id += 1
		gauge = []
		continuous_boosts = []
		lightningrod_zones = []
		for i in range(MinArenaLocation, MaxArenaLocation + 1):
			lightningrod_zones.append([])
		discards = []
		overdrive = []
		sealed_area_is_secret = 'sealed_area_is_secret' in deck_def and deck_def['sealed_area_is_secret']
		has_overdrive = 'exceed_to_overdrive' in deck_def and deck_def['exceed_to_overdrive']
		reshuffle_remaining = MaxReshuffle
		exceeded = false
		did_end_of_turn_draw = false
		did_strike_this_turn = false
		bonus_actions = 0
		canceled_this_turn = false
		cancel_blocked_this_turn = false
		used_character_action = false
		used_character_action_details = []
		used_character_bonus = false
		start_of_turn_strike = false
		force_spent_before_strike = 0
		gauge_spent_before_strike = 0
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
		wild_strike_on_boost_cleanup = false
		pre_strike_movement = 0
		moved_self_this_strike = false
		moved_past_this_strike = false
		spaces_moved_this_strike = 0
		spaces_moved_or_forced_this_strike = 0
		sustained_boosts = []
		sustain_next_boost = false
		buddy_starting_offset = BuddyStartsOutOfArena
		buddy_starting_id = ""
		buddy_locations = []
		buddy_id_to_index = {}
		do_not_cleanup_buddy_this_turn = false
		cannot_move = false
		cannot_move_past_opponent = false
		cannot_move_past_opponent_buddy_id = null
		ignore_push_and_pull = 0
		extra_effect_after_set_strike = null
		end_of_turn_boost_delay_card_ids = []
		saved_power = 0
		free_force = 0
		free_gauge = 0
		guile_change_cards_bonus = false
		cards_that_will_not_hit = []
		cards_invalid_during_strike = []
		plague_knight_discard_names = []
		public_hand = []
		public_hand_questionable = []
		public_hand_tracked_topdeck = []
		public_topdeck_id = -1
		skip_end_of_turn_draw = false
		dan_draw_choice = false
		dan_draw_choice_from_bottom = false
		boost_id_locations = {}
		boost_buddy_card_id_to_buddy_id_map = {}
		effect_on_turn_start = false
		strike_action_disabled = false

		if "buddy_cards" in deck_def:
			var buddy_index = 0
			for buddy_card in deck_def['buddy_cards']:
				buddy_id_to_index[buddy_card] = buddy_index
				buddy_locations.append(-1)
				buddy_index += 1
		elif 'buddy_card' in deck_def:
			buddy_id_to_index[deck_def['buddy_card']] = 0
			buddy_locations.append(-1)

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
			if 'buddy_starting_id' in deck_def:
				buddy_starting_id = deck_def['buddy_starting_id']

		if 'guile_change_cards_bonus' in deck_def:
			guile_change_cards_bonus = deck_def['guile_change_cards_bonus']

	func initial_shuffle():
		if ShuffleEnabled:
			random_shuffle_deck()

	func random_shuffle_deck():
		public_topdeck_id = -1
		parent.shuffle_array(deck)

	func random_shuffle_discard_in_place():
		parent.shuffle_array(discards)

	func owns_card(card_id: int):
		for card in deck_list:
			if card.id == card_id:
				return true
		return false

	func get_exceed_cost():
		var cost = exceed_cost
		if 'exceed_cost_reduced_by' in deck_def and deck_def['exceed_cost_reduced_by'] == "overdrive_count":
			cost -= len(overdrive)
			cost = max(0, cost)
		return cost

	func get_set_aside_card(card_str_id : String, remove : bool = false):
		for i in range(set_aside_cards.size()):
			var card = set_aside_cards[i]
			if card.definition['id'] == card_str_id:
				if remove:
					set_aside_cards.remove_at(i)
				return card
		return null

	func get_card_ids_in_hand():
		var card_ids = []
		for card in hand:
			card_ids.append(card.id)
		return card_ids

	func get_card_ids_in_gauge():
		var card_ids = []
		for card in gauge:
			card_ids.append(card.id)
		return card_ids

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
		parent._append_log_full(Enums.LogType.LogType_Effect, self, "Exceeds!")
		events += [parent.create_event(Enums.EventType.EventType_Exceed, my_id, 0)]

		if 'on_exceed' in deck_def:
			var effect = deck_def['on_exceed']
			events += parent.do_effect_if_condition_met(self, -1, effect, null)
		return events

	func revert_exceed():
		exceeded = false
		var events = []
		parent._append_log_full(Enums.LogType.LogType_Effect, self, "Reverts.")
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

	func get_copy_in_discards(definition_id : String):
		for card in discards:
			if card.definition['id'] == definition_id:
				return card.id
		return -1

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

	func remove_card_from_hand(id : int, is_revealed : bool, is_revealed_on_strike_reveal : bool):
		for i in range(len(hand)):
			if hand[i].id == id:
				hand.remove_at(i)
				if is_revealed:
					on_hand_remove_public_card(id)
				elif is_revealed_on_strike_reveal:
					pass
				else:
					on_hand_remove_secret_card()
				break

	func remove_card_from_gauge(id : int):
		for i in range(len(gauge)):
			if gauge[i].id == id:
				gauge.remove_at(i)
				break

	func remove_card_from_discards(id : int):
		for i in range(len(discards)):
			if discards[i].id == id:
				discards.remove_at(i)
				break

	func remove_card_from_sealed(id : int):
		for i in range(len(sealed)):
			if sealed[i].id == id:
				sealed.remove_at(i)
				break

	func on_hand_add_public_card(card_id : int):
		var card_def_id = parent.card_db.get_card(card_id).definition['id']
		public_hand.append(card_def_id)

	func on_hand_remove_public_card(card_id : int):
		if hand.size() == 0:
			reset_public_hand_knowledge()
		else:
			var card_def_id = parent.card_db.get_card(card_id).definition['id']
			public_hand.erase(card_def_id)
			public_hand_questionable.erase(card_def_id)

	func on_hand_remove_secret_card():
		if hand.size() == 0:
			reset_public_hand_knowledge()
		else:
			public_hand_questionable.append_array(public_hand)
			public_hand = []

	func on_hand_track_topdeck(card_id : int):
		public_hand_tracked_topdeck.append(card_id)

	func on_hand_removed_topdeck(card_id : int):
		# If this card was being tracked because it went to the topdeck
		# from the hand, then when it is removed to a public zone,
		# it should no longer be tracked.
		if card_id in public_hand_tracked_topdeck:
			public_hand_tracked_topdeck.erase(card_id)
			on_hand_remove_public_card(card_id)

	func reset_public_hand_knowledge():
		public_hand = []
		public_hand_questionable = []
		public_hand_tracked_topdeck = []

	func get_public_hand_info():
		var public_hand_info = {
			"all": [],
			"known": {},
			"questionable": {},
			"topdeck": ""
		}
		for card_def_id in public_hand:
			if card_def_id in public_hand_info['known']:
				public_hand_info['known'][card_def_id] += 1
			else:
				public_hand_info['known'][card_def_id] = 1

			if not card_def_id in public_hand_info['all']:
				public_hand_info['all'].append(card_def_id)
		for card_def_id in public_hand_questionable:
			if card_def_id in public_hand_info['questionable']:
				public_hand_info['questionable'][card_def_id] += 1
			else:
				public_hand_info['questionable'][card_def_id] = 1

			if not card_def_id in public_hand_info['all']:
				public_hand_info['all'].append(card_def_id)
		if public_topdeck_id != -1:
			var topdeck_def_id = parent.card_db.get_card(public_topdeck_id).definition['id']
			public_hand_info['topdeck'] = topdeck_def_id
			if not topdeck_def_id in public_hand_info['all']:
				public_hand_info['all'].append(topdeck_def_id)
		return public_hand_info

	func update_public_hand_if_deck_empty():
		if len(deck) == 0:
			# Determine if there are any unknown cards.
			# Secret sealed area or facedown strike.
			if sealed_area_is_secret and len(sealed) > 0:
				# Can't do anything
				return
			elif parent.active_strike and parent.active_strike.in_setup:
				# Can't do anything, strike is still secret.
				return
			else:
				# All cards are known.
				reset_public_hand_knowledge()
				for card in hand:
					on_hand_add_public_card(card.id)

	func move_card_from_hand_to_deck(id : int, destination_index : int = 0):
		var events = []
		for i in range(len(hand)):
			var card = hand[i]
			if card.id == id:
				deck.insert(destination_index, card)
				hand.remove_at(i)
				on_hand_remove_secret_card()
				if destination_index == 0:
					on_hand_track_topdeck(id)
					public_topdeck_id = -1
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
				on_hand_remove_public_card(id)
				break
		return events

	func move_card_from_gauge_to_hand(id : int):
		var events = []
		for i in range(len(gauge)):
			var card = gauge[i]
			if card.id == id:
				events += add_to_hand(card, true)
				gauge.remove_at(i)
				break
		return events

	func move_card_from_gauge_to_sealed(id : int):
		var events = []
		for i in range(len(gauge)):
			var card = gauge[i]
			if card.id == id:
				events += add_to_sealed(card)
				gauge.remove_at(i)
				break
		return events

	func get_lightningrod_zone_for_location(location : int):
		return lightningrod_zones[location - 1]

	func is_opponent_on_lightningrod():
		var other_player = parent._get_player(parent.get_other_player(my_id))
		for i in range(MinArenaLocation, MaxArenaLocation + 1):
			var lightningrod_zone = get_lightningrod_zone_for_location(i)
			if len(lightningrod_zone) > 0 and other_player.is_in_location(i):
				return true
		return false

	func place_top_discard_as_lightningrod(location : int):
		var events = []
		assert(len(discards) > 0, "Tried to place a card as a lightningrod when there are no discards.")
		if len(discards) > 0:
			var card = discards[len(discards) - 1]
			discards.remove_at(len(discards) - 1)
			var lightningrod_zone = get_lightningrod_zone_for_location(location)
			lightningrod_zone.append(card)
			events += [parent.create_event(Enums.EventType.EventType_PlaceLightningRod, my_id, card.id, "", location, true)]
			var card_name = parent.card_db.get_card_name(card.id)
			parent._append_log_full(Enums.LogType.LogType_Effect, self, "places %s as a Lightning Rod at location %s." % [card_name, location])
		return events

	func remove_lightning_card(card_id : int, location : int):
		var lightningrod_zone = get_lightningrod_zone_for_location(location)
		for i in range(len(lightningrod_zone)):
			var card = lightningrod_zone[i]
			if card.id == card_id:
				lightningrod_zone.remove_at(i)
				return card
		return null

	func move_card_from_discard_to_deck(id : int, shuffle : bool = true):
		var events = []
		for i in range(len(discards)):
			var card = discards[i]
			if card.id == id:
				deck.insert(0, card)
				discards.remove_at(i)
				if shuffle:
					random_shuffle_deck()
				else:
					public_topdeck_id = id
				events += [parent.create_event(Enums.EventType.EventType_AddToDeck, my_id, card.id)]
				break
		return events

	func bring_card_to_top_of_discard(id : int):
		for i in range(len(discards)):
			var card = discards[i]
			if card.id == id:
				discards.remove_at(i)
				discards.append(card)
				break

	func shuffle_sealed_to_deck():
		var events = []
		var card_names = parent._card_list_to_string(sealed)
		if card_names:
			parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "shuffles their sealed area into their deck, containing %s." % card_names)
		else:
			parent._append_log_full(Enums.LogType.LogType_Effect, self, "has no sealed cards to shuffle into their deck.")
		for card in sealed:
			deck.insert(0, card)
			events += [parent.create_event(Enums.EventType.EventType_AddToDeck, my_id, card.id)]
		random_shuffle_deck()
		sealed = []
		return events

	func shuffle_hand_to_deck():
		var events = []
		if len(hand) > 0:
			parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "shuffles their hand of %s card(s) into their deck." % len(hand))
		else:
			parent._append_log_full(Enums.LogType.LogType_Effect, self, "has no cards in hand to shuffle into their deck.")
		for card in hand:
			deck.insert(0, card)
			events += [parent.create_event(Enums.EventType.EventType_AddToDeck, my_id, card.id)]
		hand = []
		reset_public_hand_knowledge()
		random_shuffle_deck()
		return events

	func shuffle_card_from_hand_to_deck(id : int):
		var events = []
		for i in range(len(hand)):
			var card = hand[i]
			if card.id == id:
				deck.insert(0, card)
				hand.remove_at(i)
				on_hand_remove_secret_card()
				events += [parent.create_event(Enums.EventType.EventType_AddToDeck, my_id, card.id)]
				break
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
				events += add_to_hand(card, true)
				discards.remove_at(i)
				break
		return events

	func move_card_from_sealed_to_hand(id : int):
		var events = []
		for i in range(len(sealed)):
			var card = sealed[i]
			if card.id == id:
				events += add_to_hand(card, not sealed_area_is_secret)
				sealed.remove_at(i)
				break
		return events

	func move_card_from_sealed_to_top_deck(id : int):
		var events = []
		for i in range(len(sealed)):
			var card = sealed[i]
			if card.id == id:
				events += add_to_top_of_deck(card, not sealed_area_is_secret)
				sealed.remove_at(i)
				if sealed_area_is_secret:
					public_topdeck_id = -1
				else:
					public_topdeck_id = id
				break
		return events

	func remove_top_card_from_deck():
		deck.remove_at(0)
		update_public_hand_if_deck_empty()

	func add_top_deck_to_gauge(amount : int):
		var events = []
		for i in range(amount):
			if len(deck) > 0:
				var card = deck[0]
				events += add_to_gauge(card)
				remove_top_card_from_deck()
				on_hand_removed_topdeck(card.id)
				public_topdeck_id = -1
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
		return events

	func add_top_discard_to_overdrive(amount : int):
		var events = []
		for i in range(amount):
			if len(discards) > 0:
				# The top of the discard pile is the end of discards.
				var top_index = len(discards) - 1
				var card = discards[top_index]
				events += move_cards_to_overdrive([card.id], "discard")
		return events

	func return_all_cards_gauge_to_hand():
		var events = []
		var card_names = parent._card_list_to_string(gauge)
		if card_names:
			parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "adds their gauge to their hand, containing %s." % card_names)
		for card in gauge:
			events += add_to_hand(card, true)
		gauge = []
		return events

	func return_all_copies_of_top_discard_to_hand():
		var events = []
		var top_card = get_top_discard_card()
		if not top_card:
			return events

		var all_card_ids = []
		for card in discards:
			if card.definition['id'] == top_card.definition['id']:
				all_card_ids.append(card.id)
		for id in all_card_ids:
			events += move_card_from_discard_to_hand(id)
		var card_names = parent.card_db.get_card_names(all_card_ids)
		parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "returns these cards to hand from discard: %s." % card_names)
		return events

	func swap_deck_and_sealed():
		var events = []
		var current_sealed_ids = sealed.map(func(card) : return card.id)
		var current_deck_ids = deck.map(func(card) : return card.id)
		for card_id in current_deck_ids:
			events += parent.do_seal_effect(self, card_id, "deck", true)
		for card_id in current_sealed_ids:
			events += move_card_from_sealed_to_top_deck(card_id)
		parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "swaps their sealed cards and deck!")
		events += [parent.create_event(Enums.EventType.EventType_SwapSealedAndDeck, my_id, 0)]
		random_shuffle_deck()
		return events

	func is_card_in_gauge(id : int):
		for card in gauge:
			if card.id == id:
				return true
		return false

	func get_copy_in_gauge(definition_id : String):
		for card in gauge:
			if card.definition['id'] == definition_id:
				return card.id
		return -1

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
				"special/ultra":
					if card.definition['type'] == "special" or card.definition['type'] == "ultra":
						count += 1
				"continuous":
					if card.definition['boost']['boost_type'] == "continuous":
						count += 1
				_:
					count += 1
		return count

	func get_sealed_count_of_type(limitation : String):
		var count = 0
		for card in sealed:
			match limitation:
				"normal":
					if card.definition['type'] == "normal":
						count += 1
				"special":
					if card.definition['type'] == "special":
						count += 1
				"special/ultra":
					if card.definition['type'] == "special" or card.definition['type'] == "ultra":
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
				"special/ultra":
					if card.definition['type'] == "special" or card.definition['type'] == "ultra":
						cards.append(card)
				"can_pay_cost":
					var gauge_cost = parent.get_gauge_cost(self, card, true)
					var force_cost = card.definition['force_cost']
					if strike_stat_boosts.may_generate_gauge_with_force:
						# Convert the gauge cost to a force cost.
						force_cost = gauge_cost
						gauge_cost = 0

					if gauge_cost == 0:
						# To make sure this card isn't included in this check,
						# increase the force cost by 1, 2 if ultra.
						if force_cost:
							force_cost += 1
							if card.definition['type'] == "ultra":
								force_cost += 1
					if can_pay_cost(gauge_cost, force_cost):
						cards.append(card)
				_:
					cards.append(card)
		return cards

	func get_top_continuous_boost_in_discard():
		for i in range(len(discards)-1, -1, -1):
			var card = discards[i]
			if card.definition['boost']['boost_type'] == "continuous":
				return card.id
		return -1

	func get_size():
		return 1 + (2 * extra_width)

	func is_in_location(check_location : int, self_location : int = arena_location):
		var left_check = check_location <= self_location + extra_width
		var right_check = check_location >= self_location - extra_width
		return left_check and right_check

	func is_at_edge_of_arena():
		return arena_location - extra_width == MinArenaLocation or arena_location + extra_width == MaxArenaLocation

	func is_left_of_location(check_location : int, self_location : int = arena_location):
		return self_location + extra_width < check_location

	func is_right_of_location(check_location : int, self_location : int = arena_location):
		return self_location - extra_width > check_location

	func is_in_or_left_of_location(check_location : int, self_location : int = arena_location):
		return is_in_location(check_location, self_location) or is_left_of_location(check_location, self_location)

	func is_in_or_right_of_location(check_location : int, self_location : int = arena_location):
		return is_in_location(check_location, self_location) or is_right_of_location(check_location, self_location)

	func is_in_range_of_location(check_location : int, min_range : int, max_range : int):
		for check_space in range(arena_location - extra_width, arena_location + extra_width + 1):
			var distance = abs(check_space - check_location)
			if min_range <= distance and distance <= max_range:
				return true
		return false

	func distance_to_opponent():
		var other_player = parent._get_player(parent.get_other_player(my_id))
		var other_location = other_player.arena_location
		var other_width = other_player.extra_width
		if arena_location < other_location:
			return (other_location - other_width) - (arena_location + extra_width)
		else:
			return (arena_location - extra_width) - (other_location + other_width)

	func get_closest_occupied_space_to(check_location : int):
		if is_in_location(check_location):
			return check_location
		elif check_location < arena_location:
			return arena_location - extra_width
		else:
			return arena_location + extra_width

	func get_furthest_edge_from(check_location : int):
		if check_location == arena_location:
			return arena_location
		elif check_location < arena_location:
			return arena_location + extra_width
		else:
			return arena_location - extra_width

	func movement_distance_between(initial_location : int, target_location : int):
		var other_player = parent._get_player(parent.get_other_player(my_id))
		var other_location = other_player.arena_location
		var other_width = other_player.extra_width

		var distance = abs(initial_location - target_location)
		if (initial_location < other_location and other_location < target_location) or (initial_location > other_location and other_location > target_location):
			distance -= 1 + (2 * extra_width) + (2 * other_width)
		return distance

	func is_overlapping_opponent(check_location : int = -1, check_opponent_location : int = -1):
		var other_player = parent._get_player(parent.get_other_player(my_id))
		var other_width = other_player.extra_width

		if check_location == -1:
			check_location = arena_location
		if check_opponent_location == -1:
			check_opponent_location = other_player.arena_location

		var left_check = (check_opponent_location - other_width) <= (check_location + extra_width)
		var right_check = (check_opponent_location + other_width) >= (check_location - extra_width)
		return left_check and right_check

	func get_top_discard_card():
		if len(discards) > 0:
			return discards[len(discards) - 1]
		return null

	func get_top_deck_card():
		if len(deck) > 0:
			return deck[0]
		return null

	func get_buddy_name(buddy_id : String = ""):
		if 'buddy_display_name' in deck_def:
			return deck_def['buddy_display_name']

		if not buddy_id:
			buddy_id = buddy_id_to_index.keys()[0]
		var buddy_index = buddy_id_to_index[buddy_id]
		return deck_def['buddy_display_names'][buddy_index]

	func is_buddy_in_play(buddy_id : String = ""):
		if not buddy_id:
			buddy_id = buddy_id_to_index.keys()[0]
		return get_buddy_location(buddy_id) != -1

	func is_opponent_between_buddy(buddy_id : String, other_player : Player, include_buddy_space : bool):
		if not is_buddy_in_play(buddy_id):
			return false
		var pos1 = arena_location
		var pos2 = get_buddy_location(buddy_id)
		var other_pos = other_player.arena_location
		if include_buddy_space and other_player.is_in_location(pos2): # On buddy
			return true
		if pos1 < pos2: # Buddy is on the right
			return other_pos > pos1 and other_pos < pos2
		else: # Buddy is on the left
			return other_pos > pos2 and other_pos < pos1

	func get_buddy_location(buddy_id : String = ""):
		var buddy_index = 0
		if buddy_id:
			buddy_index = buddy_id_to_index[buddy_id]
		if buddy_locations.size() == 0:
			return -1
		return buddy_locations[buddy_index]

	func set_buddy_location(buddy_id : String, new_location : int):
		var buddy_index = 0
		if buddy_id:
			buddy_index = buddy_id_to_index[buddy_id]
		buddy_locations[buddy_index] = new_location

	func get_next_free_buddy_id():
		for i in range(buddy_locations.size()):
			if buddy_locations[i] == -1:
				return buddy_id_to_index.keys()[i]
		return ""

	func get_buddy_id_at_location(location : int):
		for i in range(buddy_locations.size()):
			if buddy_locations[i] == location:
				return buddy_id_to_index.keys()[i]
		return ""

	func get_buddies_in_play():
		var buddies = []
		for i in range(buddy_locations.size()):
			if buddy_locations[i] != -1:
				buddies.append(buddy_id_to_index.keys()[i])
		return buddies

	func get_buddies_on_opponent():
		var opposing_player = parent._get_player(parent.get_other_player(my_id))
		var matching_buddies = []
		for i in range(buddy_locations.size()):
			if opposing_player.is_in_location(buddy_locations[i]):
				matching_buddies.append(buddy_id_to_index.keys()[i])
		return matching_buddies

	func get_buddies_adjacent_opponent():
		var opposing_player = parent._get_player(parent.get_other_player(my_id))
		var matching_buddies = []
		for i in range(buddy_locations.size()):
			var location = buddy_locations[i]
			if not opposing_player.is_in_location(location):
				if opposing_player.is_in_location(location - 1) or opposing_player.is_in_location(location + 1):
					matching_buddies.append(buddy_id_to_index.keys()[i])
		return matching_buddies

	func count_buddies_between_opponent():
		var opposing_player = parent._get_player(parent.get_other_player(my_id))
		var count = 0
		var started = false
		for location in range(MinArenaLocation, MaxArenaLocation + 1):
			# Only count starting with the rightmost edge of one of the players.
			if not started and \
			((opposing_player.is_in_location(location) and not opposing_player.is_in_location(location + 1)) or \
			(self.is_in_location(location) and not self.is_in_location(location + 1))):
				# Found a player, begin counting until the other player is reached.
				started = true
			elif started and \
			(opposing_player.is_in_location(location) or self.is_in_location(location)):
				# Reached the other end, stop.
				break
			elif started and get_buddy_id_at_location(location):
				count += 1

		return count

	func are_all_buddies_in_play():
		for i in range(buddy_locations.size()):
			if buddy_locations[i] == -1:
				return false
		return true

	func place_buddy(new_location : int, buddy_id : String = "", silent : bool = false, description : String = "", extra_offset : bool = false):
		var events = []
		if not buddy_id:
			buddy_id = buddy_id_to_index.keys()[0]
		var old_buddy_pos = get_buddy_location(buddy_id)
		if parent.active_strike and old_buddy_pos == -1 and new_location != -1:
			# Buddy entering play.
			strike_stat_boosts.buddies_that_entered_play_this_strike.append(buddy_id)
		set_buddy_location(buddy_id, new_location)
		on_position_changed(arena_location, old_buddy_pos, false)
		events += [parent.create_event(Enums.EventType.EventType_PlaceBuddy, my_id, get_buddy_location(buddy_id), description, buddy_id, silent, extra_offset)]
		return events

	func remove_buddy(buddy_id : String, silent : bool = false):
		var events = []
		if not buddy_id:
			buddy_id = buddy_id_to_index.keys()[0]
		if not do_not_cleanup_buddy_this_turn:
			var old_buddy_pos = get_buddy_location(buddy_id)
			set_buddy_location(buddy_id, -1)
			on_position_changed(arena_location, old_buddy_pos, false)
			events += [parent.create_event(Enums.EventType.EventType_PlaceBuddy, my_id, get_buddy_location(buddy_id), "", buddy_id, silent, false)]
		return events

	func swap_buddy(buddy_id_to_remove : String, buddy_id_to_place : String, description : String):
		var events = []
		var location = get_buddy_location(buddy_id_to_remove)
		events += remove_buddy(buddy_id_to_remove, true)
		events += place_buddy(location, buddy_id_to_place, false, description)
		return events

	func get_buddy_id_for_boost(card_id : int):
		var card_def = parent.card_db.get_card(card_id).definition
		assert('linked_buddy_id' in card_def, "Unexpected: Card does not have a linked buddy id.")
		var linked_buddy_id = card_def['linked_buddy_id']

		if card_id in boost_buddy_card_id_to_buddy_id_map:
			return boost_buddy_card_id_to_buddy_id_map[card_id]
		else:
			# Currently assumes there are only 2 possible linked buddies.
			var targetid1 = linked_buddy_id + "1"
			var targetid2 = linked_buddy_id + "2"
			# Check the values of the map.
			if targetid1 in boost_buddy_card_id_to_buddy_id_map.values():
				return targetid2
			else:
				return targetid1

	func get_boost_location(card_id : int):
		# Check if the id is in boost_id_locations as a key.
		if card_id in boost_id_locations:
			return boost_id_locations[card_id]
		return -1

	func add_boost_to_location(card_id : int, location : int):
		assert(card_id not in boost_id_locations)
		var buddy_id = get_buddy_id_for_boost(card_id)
		boost_id_locations[card_id] = location
		boost_buddy_card_id_to_buddy_id_map[card_id] = buddy_id
		var extra_offset = buddy_id.ends_with("2")

		var events = []
		events += place_buddy(location, buddy_id, false, "", extra_offset)
		return events

	func remove_boost_in_location(card_id : int):
		# Check if the id is in the dictionary, and if so remove it.
		var events = []
		if card_id in boost_id_locations:
			var buddy_id = get_buddy_id_for_boost(card_id)
			boost_id_locations.erase(card_id)
			boost_buddy_card_id_to_buddy_id_map.erase(card_id)
			events += remove_buddy(buddy_id)
		return events

	func get_force_with_cards(card_ids : Array, reason : String, treat_ultras_as_single_force : bool):
		var force_generated = free_force
		var has_card_in_gauge = false
		for card_id in card_ids:
			if treat_ultras_as_single_force:
				force_generated += 1
			else:
				force_generated += parent.card_db.get_card_force_value(card_id)
			if is_card_in_gauge(card_id):
				has_card_in_gauge = true

		# Handle Guile bonus
		if reason == "CHANGE_CARDS" and has_card_in_gauge and guile_change_cards_bonus:
			force_generated += 2

		return force_generated

	func can_pay_cost_with(card_ids : Array, force_cost : int, gauge_cost : int):
		if force_cost and gauge_cost:
			# UNEXPECTED - NOT IMPLEMENTED
			assert(false)
		elif force_cost:
			var force_generated = get_force_with_cards(card_ids, "GENERIC_PAY_FORCE_COST", false)
			for card_id in card_ids:
				if not is_card_in_hand(card_id) and not is_card_in_gauge(card_id):
					assert(false)
					parent.printlog("ERROR: Card not in hand or gauge")
					return false
			return force_generated >= force_cost
		elif gauge_cost:
			# Cap free gauge to the max gauge cost of the effect.
			var gauge_generated = min(free_gauge, gauge_cost)
			for card_id in card_ids:
				if is_card_in_gauge(card_id):
					gauge_generated += 1
				else:
					assert(false)
					parent.printlog("ERROR: Card not in gauge")
					return false
			return gauge_generated == gauge_cost

		# No cost.
		return true

	func can_pay_cost(force_cost : int, gauge_cost : int):
		var available_force = get_available_force()
		var available_gauge = get_available_gauge()
		if available_gauge < gauge_cost:
			return false
		if available_force < force_cost:
			return false
		return true

	func can_boost_something(valid_zones : Array, limitation : String, ignore_costs : bool = false) -> bool:
		var force_available = get_available_force()
		var zone_map = {
			"hand": hand,
			"gauge": gauge,
			"discard": discards
		}

		for zone in valid_zones:
			for card in zone_map[zone]:
				var meets_limitation = true
				if limitation:
					if card.definition['boost']['boost_type'] == limitation or card.definition['type'] == limitation:
						meets_limitation = true
					else:
						meets_limitation = false
				if not meets_limitation:
					continue

				if ignore_costs:
					return true
				var force_available_when_boosting_this = force_available - parent.card_db.get_card_force_value(card.id)
				var cost = parent.card_db.get_card_boost_force_cost(card.id)
				if force_available_when_boosting_this >= cost:
					return true
		return false

	func can_cancel(card : GameCard):
		if strike_on_boost_cleanup or wild_strike_on_boost_cleanup or cancel_blocked_this_turn:
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

		if 'can_boost_continuous_boost_from_gauge' in action and action['can_boost_continuous_boost_from_gauge']:
			if not can_boost_something(['gauge'], 'continuous'): return false

		if 'min_hand_size' in action:
			if len(hand) < action['min_hand_size']: return false

		if 'requires_buddy_in_play' in action and action['requires_buddy_in_play']:
			var buddy_id = ""
			if 'buddy_id' in action:
				buddy_id = action['buddy_id']
			if not is_buddy_in_play(buddy_id): return false

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

	func draw(num_to_draw : int, is_fake_draw : bool = false, from_bottom: bool = false, update_if_empty : bool = true):
		var events : Array = []
		if num_to_draw > 0:
			if is_fake_draw:
				# Used by topdeck boost as an easy way to get it in your hand to boost.
				# This will add it, then it gets removed publicly by boost.
				on_hand_add_public_card(deck[0].id)
			elif public_topdeck_id != -1:
				on_hand_add_public_card(public_topdeck_id)
			public_topdeck_id = -1

		var draw_from_index = 0
		for i in range(num_to_draw):
			if from_bottom:
				draw_from_index = len(deck)-1

			if len(deck) > 0:
				var card = deck[draw_from_index]
				hand.append(card)
				deck.remove_at(draw_from_index)
				if draw_from_index == 0:
					on_hand_removed_topdeck(card.id)
				events += [parent.create_event(Enums.EventType.EventType_Draw, my_id, card.id)]
			else:
				events += reshuffle_discard(false)
				if not parent.game_over:
					if from_bottom:
						draw_from_index = len(deck)-1
					var card = deck[draw_from_index]
					hand.append(card)
					deck.remove_at(draw_from_index)
					events += [parent.create_event(Enums.EventType.EventType_Draw, my_id, card.id)]

			if update_if_empty:
				update_public_hand_if_deck_empty()
		return events

	func add_set_aside_card_to_deck(card_str_id : String):
		var events : Array = []
		var card = get_set_aside_card(card_str_id, true)
		if card:
			deck.insert(0, card)
			public_topdeck_id = card.id
		return events

	func get_unknown_cards():
		var unknown_cards = hand + deck
		if sealed_area_is_secret:
			unknown_cards += sealed
		if parent.active_strike:
			var strike_card = parent.active_strike.get_player_card(self)
			if strike_card:
				unknown_cards.append(strike_card)
			var strike_ex_card = parent.active_strike.get_player_ex_card(self)
			if strike_ex_card:
				unknown_cards.append(strike_ex_card)
		unknown_cards.sort_custom(func(c1, c2) : return c1.id < c2.id)
		return unknown_cards

	func reshuffle_discard(manual : bool, free : bool = false):
		var events : Array = []
		if reshuffle_remaining == 0 and not free:
			# Game Over
			parent._append_log_full(Enums.LogType.LogType_Default, self, "is out of cards!")
			events += parent.trigger_game_over(my_id, Enums.GameOverReason.GameOverReason_Decked)
		else:
			# Reveal and remember remaining cards
			var unknown_cards = get_unknown_cards()
			var card_names = parent._card_list_to_string(unknown_cards)
			if card_names == "":
				parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "reshuffles.")
			else:
				parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "reshuffles with remaining cards: %s." % card_names)

			# Put discard into deck, shuffle, subtract reshuffles
			deck += discards
			discards = []
			random_shuffle_deck()
			if not free:
				reshuffle_remaining -= 1
			events += [parent.create_event(Enums.EventType.EventType_ReshuffleDiscard, my_id, reshuffle_remaining, "", unknown_cards)]
			var local_conditions = LocalStrikeConditions.new()
			local_conditions.manual_reshuffle = manual
			var effects = get_character_effects_at_timing("on_reshuffle")
			for effect in effects:
				events += parent.do_effect_if_condition_met(self, -1, effect, local_conditions)
		return events

	func discard(card_ids : Array, from_top : int = 0):
		var events = []
		for discard_id in card_ids:
			var found_card = false

			# From hand
			for i in range(len(hand)-1, -1, -1):
				var card = hand[i]
				if card.id == discard_id:
					hand.remove_at(i)
					events += add_to_discards(card, from_top)
					on_hand_remove_public_card(discard_id)
					found_card = true
					break
			if found_card: continue

			# From gauge
			for i in range(len(gauge)-1, -1, -1):
				var card = gauge[i]
				if card.id == discard_id:
					gauge.remove_at(i)
					events += add_to_discards(card, from_top)
					found_card = true
					break
			if found_card: continue

			# From overdrive
			for i in range(len(overdrive)-1, -1, -1):
				var card = overdrive[i]
				if card.id == discard_id:
					overdrive.remove_at(i)
					events += add_to_discards(card, from_top)
					found_card = true
					break

			if not found_card:
				assert(false, "ERROR: card to discard not found")

		return events

	func move_cards_to_overdrive(card_ids : Array, source : String):
		var events = []
		var opposing_player = parent._get_player(parent.get_other_player(my_id))
		var card_names = parent.card_db.get_card_names(card_ids)
		if card_names:
			var friendly_source = source
			if source == "opponent_discard":
				friendly_source = "opponent's discard"
			parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "moves cards from %s to overdrive: %s." % [friendly_source, card_names])
		for card_id in card_ids:
			var source_array
			match source:
				"hand":
					source_array = hand
					on_hand_remove_public_card(card_id)
				"gauge":
					source_array = gauge
				"discard":
					source_array = discards
				"deck":
					source_array = deck
					# Only tests currently use this, but
					# presumably these would be coming from top deck
					public_topdeck_id = -1
				"opponent_discard":
					source_array = opposing_player.discards
				"_":
					assert(false)
					parent.printlog("ERROR: Unexpected source of card going to overdrive: %s" % source)

			for i in range(len(source_array)-1, -1, -1):
				var card = source_array[i]
				if card.id == card_id:
					source_array.remove_at(i)
					events += add_to_overdrive(card)
					break
		return events

	func add_to_overdrive(card : GameCard):
		overdrive.append(card)
		return [parent.create_event(Enums.EventType.EventType_AddToOverdrive, my_id, card.id)]

	func seal_from_location(card_id : int, source : String, silent : bool = false):
		var events = []
		var source_array
		match source:
			"hand":
				source_array = hand
				if sealed_area_is_secret:
					on_hand_remove_secret_card()
				else:
					on_hand_remove_public_card(card_id)
			"discard":
				source_array = discards
			"deck":
				source_array = deck
				# Assuming this coming from the topdeck.
				public_topdeck_id = -1
			"_":
				assert(false)
				parent.printlog("ERROR: Unexpected source of card going to sealed area: %s" % source)
		for i in range(len(source_array)-1, -1, -1):
			var card = source_array[i]
			if card.id == card_id:
				source_array.remove_at(i)
				sealed.append(card)
				events += [parent.create_event(Enums.EventType.EventType_Seal, my_id, card.id, "", not silent)]
				break
		return events

	func seal_hand():
		var events = []
		var card_ids = []
		for card in hand:
			card_ids.append(card.id)
		var card_names = parent.card_db.get_card_names(card_ids)
		if card_names:
			if sealed_area_is_secret:
				parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "seals their hand face-down.")
			else:
				parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "seals their hand, containing %s." % card_names)
		for card_id in card_ids:
			events += parent.do_seal_effect(self, card_id, "hand")
		return events

	func discard_hand():
		var events = []
		var card_ids = []
		for card in hand:
			card_ids.append(card.id)
		var card_names = parent.card_db.get_card_names(card_ids)
		if card_names:
			parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "discards their hand, containing %s." % card_names)
		events += discard(card_ids)
		reset_public_hand_knowledge()
		return events

	func discard_gauge():
		var events = []
		for i in range(len(gauge)-1, -1, -1):
			var card = gauge[i]
			gauge.remove_at(i)
			events += add_to_discards(card)
		return events

	func add_hand_to_gauge():
		var events = []
		var card_ids = []
		for card in hand:
			card_ids.append(card.id)
		var card_names = parent.card_db.get_card_names(card_ids)
		if card_names:
			parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "adds their hand to gauge, containing %s." % card_names)
		for card_id in card_ids:
			events += move_card_from_hand_to_gauge(card_id)
		return events

	func discard_matching_or_reveal(card_definition_id : String):
		var events = []
		for card in hand:
			if card.definition['id'] == card_definition_id:
				var card_name = parent.card_db.get_card_name(card.id)
				parent._append_log_full(Enums.LogType.LogType_Effect, self, "has the named card!")
				parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "discards %s." % card_name)
				events += discard([card.id])
				return events
		# Not found
		parent._append_log_full(Enums.LogType.LogType_Effect, self, "does not have the named card.")
		events += reveal_hand()
		return events

	func discard_topdeck():
		var events = []
		if deck.size() > 0:
			var card = deck[0]
			var card_name = parent.card_db.get_card_name(card.id)
			parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "discards the top card of their deck: %s." % card_name)
			remove_top_card_from_deck()
			on_hand_removed_topdeck(card.id)
			public_topdeck_id = -1
			events += add_to_discards(card)
		return events

	func seal_topdeck():
		var events = []
		if deck.size() > 0:
			var card = deck[0]
			var card_name = parent.card_db.get_card_name(card.id)
			if sealed_area_is_secret:
				parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "seals the top card of their deck facedown.")
			else:
				parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "seals the top card of their deck: %s." % card_name)
				on_hand_removed_topdeck(card.id)
			events += parent.do_seal_effect(self, card.id, "deck")
		return events

	func next_strike_with_or_reveal(card_definition_id : String) -> void:
		reading_card_id = card_definition_id

	func get_reading_card_in_hand() -> Array:
		var cards = []
		for card in hand:
			if card.definition['id'] == reading_card_id:
				cards.append(card)
		return cards

	func reveal_card_ids(card_ids):
		# First remove them then add them back.
		# Do this because the card may be revealed to the opponent.
		# Example: 3 Tuning Satisfaction in hand, opponent knows of two.
		# Attack with one (known is now 1), then reveal one.
		# This removes it then adds it back so they still know you have 1.
		# Remove them all first if multiple so if you show like 2 two at a time
		# it doesn't look like you have just one.
		for card_id in card_ids:
			on_hand_remove_public_card(card_id)
		for card_id in card_ids:
			on_hand_add_public_card(card_id)

	func reveal_hand():
		var events = []
		var card_names = parent._card_list_to_string(hand)
		if card_names == "":
			parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "reveals their empty hand.")
		else:
			parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "reveals their hand: %s." % card_names)
		events += [parent.create_event(Enums.EventType.EventType_RevealHand, my_id, 0)]
		reset_public_hand_knowledge()
		for card in hand:
			on_hand_add_public_card(card.id)
		return events

	func reveal_hand_and_topdeck():
		var events = []
		events += reveal_hand()
		events += reveal_topdeck()
		return events

	func reveal_topdeck(reveal_to_both : bool = false):
		var events = []
		if deck.size() == 0:
			parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "has no cards in their deck to reveal.")
			return events

		var card_name = parent.card_db.get_card_name(deck[0].id)
		if self == parent.player and not reveal_to_both:
			parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "reveals the top card of their deck to the opponent.")
		else:
			parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "reveals the top card of their deck: %s." % card_name)
			public_topdeck_id = deck[0].id
		events += [parent.create_event(Enums.EventType.EventType_RevealTopDeck, my_id, deck[0].id)]
		return events

	func pick_random_cards_from_hand(amount):
		var hand_card_ids = []
		for card in hand:
			hand_card_ids.append(card.id)

		var chosen_card_ids = []
		for i in range(amount):
			if len(hand_card_ids) > 0:
				var random_idx = parent.get_random_int() % len(hand_card_ids)
				var random_card_id = hand_card_ids[random_idx]
				chosen_card_ids.append(random_card_id)
				hand_card_ids.remove_at(random_idx)
		return chosen_card_ids

	func discard_random(amount):
		var events = []
		var discarded_ids = []
		for i in range(amount):
			if len(hand) > 0:
				var random_card_id = hand[parent.get_random_int() % len(hand)].id
				discarded_ids.append(random_card_id)
				events += discard([random_card_id])
		var discarded_names = parent.card_db.get_card_names(discarded_ids)
		if discarded_names:
			parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "discards random card(s): %s." % discarded_names)
		return events

	func invalidate_card(card : GameCard):
		var events = []
		if 'on_invalid' in card.definition:
			var invalid_effect = card.definition['on_invalid']
			events += parent.do_effect_if_condition_met(self, -1, invalid_effect, null)
		if 'on_invalid_add_to_gauge' in card.definition and card.definition['on_invalid_add_to_gauge']:
			events += add_to_gauge(card)
		else:
			events += add_to_discards(card)
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
			remove_top_card_from_deck()
			public_topdeck_id = -1
			events += [parent.create_event(Enums.EventType.EventType_Strike_WildStrike, my_id, card_id, "", is_immediate_reveal)]
		return events

	func random_gauge_strike():
		var events = []
		if len(gauge) == 0:
			parent._append_log_full(Enums.LogType.LogType_Strike, self, "has no gauge to strike with and wild swings instead.")
			return wild_strike(true)
		else:
			var random_gauge_idx = parent.get_random_int() % len(gauge)
			var random_card_id = gauge[random_gauge_idx].id
			if parent.active_strike.initiator == self:
				parent.active_strike.initiator_card = gauge[random_gauge_idx]
			else:
				assert(false)
				parent.printlog("ERROR: Random gauge strike by non-initiator")
			var card_name = parent.card_db.get_card_name(random_card_id)
			parent._append_log_full(Enums.LogType.LogType_Strike, self, "strikes with %s from gauge!" % card_name)
			gauge.remove_at(random_gauge_idx)
			parent.active_strike.initiator_set_from_gauge = true
			events += [parent.create_event(Enums.EventType.EventType_Strike_RandomGaugeStrike, my_id, random_card_id, "", true)]
		return events

	func add_to_gauge(card: GameCard):
		gauge.append(card)
		return [parent.create_event(Enums.EventType.EventType_AddToGauge, my_id, card.id)]

	func add_to_discards(card : GameCard, from_top : int = 0):
		if card.owner_id == my_id:
			if from_top == 0:
				discards.append(card)
			else:
				# Insert it from_top from the end.
				discards.insert(len(discards) - from_top, card)
			return [parent.create_event(Enums.EventType.EventType_AddToDiscard, my_id, card.id, "", from_top)]
		else:
			# Card belongs to the other player, so discard it there.
			return parent._get_player(parent.get_other_player(my_id)).add_to_discards(card, from_top)

	func add_to_hand(card : GameCard, public : bool):
		hand.append(card)
		if public:
			on_hand_add_public_card(card.id)
		return [parent.create_event(Enums.EventType.EventType_AddToHand, my_id, card.id)]

	func add_to_sealed(card : GameCard, silent=false):
		sealed.append(card)
		return [parent.create_event(Enums.EventType.EventType_Seal, my_id, card.id, "", not silent)]

	func add_to_top_of_deck(card : GameCard, public : bool):
		deck.insert(0, card)
		if public:
			public_topdeck_id = card.id
		else:
			public_topdeck_id = -1
		return [parent.create_event(Enums.EventType.EventType_AddToDeck, my_id, card.id)]

	func get_available_force():
		var force = free_force
		for card in hand:
			force += card_database.get_card_force_value(card.id)
		for card in gauge:
			force += card_database.get_card_force_value(card.id)
		return force

	func get_available_gauge():
		var available_gauge = free_gauge
		return available_gauge + len(gauge)

	func can_move_to(new_arena_location, ignore_force_req : bool):
		if cannot_move: return false
		if new_arena_location == arena_location: return false
		if (new_arena_location - extra_width < MinArenaLocation) or (new_arena_location + extra_width > MaxArenaLocation): return false

		var other_player = parent._get_player(parent.get_other_player(my_id))
		var other_player_loc = other_player.arena_location
		if is_overlapping_opponent(new_arena_location): return false
		if cannot_move_past_opponent:
			if arena_location < other_player_loc and new_arena_location > other_player_loc:
				return false
			if arena_location > other_player_loc and new_arena_location < other_player_loc:
				return false
		if cannot_move_past_opponent_buddy_id:
			var other_buddy_loc = other_player.get_buddy_location(cannot_move_past_opponent_buddy_id)
			if is_left_of_location(other_buddy_loc) and is_in_or_right_of_location(other_buddy_loc, new_arena_location):
				return false
			if is_right_of_location(other_buddy_loc) and is_in_or_left_of_location(other_buddy_loc, new_arena_location):
				return false
		if ignore_force_req:
			return true

		var distance = movement_distance_between(arena_location, new_arena_location)
		var required_force = get_force_to_move_to(new_arena_location)
		if distance > movement_limit:
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
		var required_force = movement_distance_between(arena_location, new_arena_location)
		if ((arena_location < other_player_loc and new_arena_location > other_player_loc)
			or (new_arena_location < other_player_loc and arena_location > other_player_loc)):
			# movement_distance_between ignores the opponent's space(s)
			required_force += 1
		return required_force

	func on_position_changed(old_pos, buddy_old_pos, is_self_move):
		if parent.active_strike:
			var spaces_moved = movement_distance_between(old_pos, arena_location)
			spaces_moved_or_forced_this_strike += spaces_moved
			if is_self_move:
				moved_self_this_strike = true
				spaces_moved_this_strike += spaces_moved

		var buddy_location = get_buddy_location()
		if is_in_location(buddy_location):
			if not is_in_location(buddy_old_pos, old_pos):
				handle_on_buddy_boosts(true)
		else:
			if is_in_location(buddy_old_pos, old_pos):
				handle_on_buddy_boosts(false)

	func move_in_direction_by_amount(go_left : bool, amount : int, stop_at_opponent : bool, stop_on_space : int,
	movement_type : String, is_self_move : bool = true, remove_my_buddies_encountered : int = 0,
	set_x_to_buddy_spaces_entered : bool = false
	):
		var events = []
		var direction = -1 if go_left else 1
		var other_player = parent._get_player(parent.get_other_player(my_id))

		if is_self_move:
			var movement_blocked = cannot_move
			if parent.active_strike and strike_stat_boosts.cannot_move_if_in_opponents_range:
				if parent.in_range(other_player, self, parent.active_strike.get_player_card(other_player)):
					movement_blocked = true

			if movement_blocked:
				parent._append_log_full(Enums.LogType.LogType_CharacterMovement, self, "cannot move!")
				events += [parent.create_event(Enums.EventType.EventType_BlockMovement, my_id, 0)]
				return events
		else:
			if strike_stat_boosts.ignore_push_and_pull or ignore_push_and_pull:
				parent._append_log_full(Enums.LogType.LogType_CharacterMovement, self, "cannot be moved!")
				events += [parent.create_event(Enums.EventType.EventType_Strike_IgnoredPushPull, my_id, 0)]
				return events

		var previous_location = arena_location
		var new_location = arena_location
		var movement_shortened = false
		var blocked_by_buddy = false
		var stopped_on_space = false
		var distance = 0
		var my_buddies_encountered_in_order = []
		var opponent_buddies_encountered_in_order = []
		for i in range(amount):
			var target_location = new_location + direction
			if is_self_move and cannot_move_past_opponent_buddy_id:
				var other_buddy_loc = other_player.get_buddy_location(cannot_move_past_opponent_buddy_id)
				if is_in_location(other_buddy_loc, target_location):
					movement_shortened = true
					blocked_by_buddy = true
					break

			if is_overlapping_opponent(target_location):
				if stop_at_opponent:
					break
				elif is_self_move and cannot_move_past_opponent:
					movement_shortened = true
					break
				else:
					var test_location = clamp(target_location + direction, MinArenaLocation + extra_width, MaxArenaLocation - extra_width)
					var no_open_space = false
					while is_overlapping_opponent(test_location):
						var updated_test_location = clamp(test_location + direction, MinArenaLocation + extra_width, MaxArenaLocation - extra_width)
						if test_location == updated_test_location:
							# opponent is in front of wall
							no_open_space = true
							break
						test_location = updated_test_location
					if no_open_space:
						# no more space to move in this direction
						target_location -= direction
						break
					else:
						target_location = test_location

			var updated_new_location = clamp(target_location, MinArenaLocation + extra_width, MaxArenaLocation - extra_width)
			if new_location != updated_new_location:
				distance += 1
				new_location = updated_new_location
				var my_buddy_id = get_buddy_id_at_location(new_location)
				if my_buddy_id:
					my_buddies_encountered_in_order.append(my_buddy_id)
				var opponent_buddy_id = other_player.get_buddy_id_at_location(new_location)
				if opponent_buddy_id:
					opponent_buddies_encountered_in_order.append(opponent_buddy_id)
			else:
				# at edge of arena
				break

			if new_location == stop_on_space and not i == amount-1:
				# If stop_on_space is this location, the space is
				# unoccupied (after resolving the above if),
				# and there are more spaces to go (i is not the last iteration),
				# then stop the movement.
				movement_shortened = true
				stopped_on_space = true
				break

		if movement_shortened:
			if blocked_by_buddy:
				var other_buddy_name = other_player.get_buddy_name(cannot_move_past_opponent_buddy_id)
				parent._append_log_full(Enums.LogType.LogType_CharacterMovement, self, "cannot move past %s's %s!" % [other_player.name, other_buddy_name])
			elif stopped_on_space:
				parent._append_log_full(Enums.LogType.LogType_CharacterMovement, self, "forced to stop at %s by an effect!" % str(stop_on_space))
			else:
				parent._append_log_full(Enums.LogType.LogType_CharacterMovement, self, "cannot move past %s!" % other_player.name)

		if not parent.active_strike:
			pre_strike_movement += distance
		var position_changed = arena_location != new_location
		arena_location = new_location
		events += [parent.create_event(Enums.EventType.EventType_Move, my_id, new_location, movement_type, amount, previous_location)]
		if position_changed:
			on_position_changed(previous_location, get_buddy_location(), is_self_move)
			if is_self_move:
				events += add_boosts_to_gauge_on_move()

		if set_x_to_buddy_spaces_entered:
			var buddy_spaces_entered = len(opponent_buddies_encountered_in_order)
			events += other_player.set_strike_x(buddy_spaces_entered, true)

		if remove_my_buddies_encountered > 0:
			for buddy_id in my_buddies_encountered_in_order:
				events += remove_buddy(buddy_id)
				remove_my_buddies_encountered -= 1
				if remove_my_buddies_encountered == 0:
					break

		return events

	func move_to(new_location, ignore_restrictions=false, remove_buddies_encountered : int = 0):
		var events = []
		if arena_location == new_location:
			return events

		var distance = movement_distance_between(arena_location, new_location)
		if ignore_restrictions:
			var previous_location = arena_location
			arena_location = new_location
			events += [parent.create_event(Enums.EventType.EventType_Move, my_id, new_location, "move", distance, previous_location)]
			if previous_location != arena_location:
				on_position_changed(previous_location, get_buddy_location(), true)
				# This is used for resetting positions; don't process remove-on-move boosts, since it's not an advance/retreat
		else:
			var other_player = parent._get_player(parent.get_other_player(my_id))
			if arena_location < new_location:
				if other_player.is_in_location(new_location):
					new_location = other_player.get_closest_occupied_space_to(arena_location) - 1
					distance = movement_distance_between(arena_location, new_location)
				events += move_in_direction_by_amount(false, distance, false, -1, "move", true, remove_buddies_encountered)
			else:
				if other_player.is_in_location(new_location):
					new_location = other_player.get_closest_occupied_space_to(arena_location) + 1
					distance = movement_distance_between(arena_location, new_location)
				events += move_in_direction_by_amount(true, distance, false, -1, "move", true, remove_buddies_encountered)

		return events

	func close(amount):
		var events = []

		amount = min(amount, movement_limit)
		var other_location = parent._get_player(parent.get_other_player(my_id)).arena_location
		if arena_location < other_location:
			events += move_in_direction_by_amount(false, amount, true, -1, "close")
		else:
			events += move_in_direction_by_amount(true, amount, true, -1, "close")

		return events

	func advance(amount, stop_on_space):
		var events = []

		amount = min(amount, movement_limit)
		var other_location = parent._get_player(parent.get_other_player(my_id)).arena_location
		if arena_location < other_location:
			events += move_in_direction_by_amount(false, amount, false, stop_on_space, "advance")
		else:
			events += move_in_direction_by_amount(true, amount, false, stop_on_space, "advance")

		return events

	func retreat(amount):
		var events = []

		amount = min(amount, movement_limit)
		var other_location = parent._get_player(parent.get_other_player(my_id)).arena_location
		if arena_location < other_location:
			events += move_in_direction_by_amount(true, amount, false, -1, "retreat")
		else:
			events += move_in_direction_by_amount(false, amount, false, -1, "retreat")

		return events

	func push(amount, set_x_to_buddy_spaces_entered : bool = false):
		var events = []

		var other_player = parent._get_player(parent.get_other_player(my_id))
		var other_location = other_player.arena_location
		if arena_location < other_location:
			events += other_player.move_in_direction_by_amount(false, amount, false, -1, "push", false, 0, set_x_to_buddy_spaces_entered)
		else:
			events += other_player.move_in_direction_by_amount(true, amount, false, -1, "push", false, 0, set_x_to_buddy_spaces_entered)

		return events

	func pull(amount):
		var events = []

		var other_player = parent._get_player(parent.get_other_player(my_id))
		var other_location = other_player.arena_location
		if arena_location < other_location:
			events += other_player.move_in_direction_by_amount(true, amount, false, -1, "pull", false)
		else:
			events += other_player. move_in_direction_by_amount(false, amount, false, -1, "pull", false)

		return events

	func pull_not_past(amount):
		var events = []

		var other_player = parent._get_player(parent.get_other_player(my_id))
		var other_location = other_player.arena_location
		if arena_location < other_location:
			events += other_player.move_in_direction_by_amount(true, amount, true, -1, "pull", false)
		else:
			events += other_player.move_in_direction_by_amount(false, amount, true, -1, "pull", false)

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

	func add_power_bonus(amount : int):
		strike_stat_boosts.power += amount
		if amount > 0:
			strike_stat_boosts.power_positive_only += amount

	func remove_power_bonus(amount : int):
		strike_stat_boosts.power -= amount
		if amount > 0:
			strike_stat_boosts.power_positive_only -= amount

	func reenable_boost_effects(card : GameCard):
		var opposing_player = parent._get_player(parent.get_other_player(my_id))
		# Redo boost properties
		for effect in card.definition['boost']['effects']:
			if effect['timing'] == "now":
				match effect['effect_type']:
					"ignore_push_and_pull_passive_bonus":
						ignore_push_and_pull += 1
						if ignore_push_and_pull == 1:
							parent._append_log_full(Enums.LogType.LogType_Effect, self, "cannot be pushed or pulled!")
		if parent.active_strike and not parent.active_strike.in_setup:
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
						if 'special_range' in effect and effect['special_range']:
							var current_range = str(overdrive.size())
							strike_stat_boosts.dodge_at_range_late_calculate_with = effect['special_range']
							parent._append_log_full(Enums.LogType.LogType_Effect, self, "will dodge attacks from range %s!" % current_range)
						else:
							strike_stat_boosts.dodge_at_range_min = effect['amount']
							strike_stat_boosts.dodge_at_range_max = effect['amount2']
							if effect['from_buddy']:
								strike_stat_boosts.dodge_at_range_from_buddy = effect['from_buddy']
							var dodge_range = str(strike_stat_boosts.dodge_at_range_min)
							if strike_stat_boosts.dodge_at_range_min != strike_stat_boosts.dodge_at_range_max:
								dodge_range += "-%s" % strike_stat_boosts.dodge_at_range_max
							parent._append_log_full(Enums.LogType.LogType_Effect, self, "will dodge attacks from range %s!" % dodge_range)
					"powerup":
						add_power_bonus(effect['amount'])
					"powerup_both_players":
						add_power_bonus(effect['amount'])
						opposing_player.add_power_bonus(effect['amount'])
					"speedup":
						strike_stat_boosts.speed += effect['amount']
					"armorup":
						strike_stat_boosts.armor += effect['amount']
					"guardup":
						strike_stat_boosts.guard += effect['amount']
					"rangeup":
						strike_stat_boosts.min_range += effect['amount']
						strike_stat_boosts.max_range += effect['amount2']
					"rangeup_both_players":
						strike_stat_boosts.min_range += effect['amount']
						strike_stat_boosts.max_range += effect['amount2']
						opposing_player.strike_stat_boosts.min_range += effect['amount']
						opposing_player.strike_stat_boosts.max_range += effect['amount2']

	func disable_boost_effects(card : GameCard, buddy_ignore_condition : bool = false, being_discarded : bool = true):
		var opposing_player = parent._get_player(parent.get_other_player(my_id))

		# Undo timing effects and passive bonuses.
		var current_timing = parent.get_current_strike_timing()
		for effect in card.definition['boost']['effects']:
			if effect['timing'] == "now":
				match effect['effect_type']:
					"ignore_push_and_pull_passive_bonus":
						# ensure this won't be doubly-undone by a discard effect
						if not being_discarded:
							ignore_push_and_pull -= 1
							if ignore_push_and_pull == 0:
								parent._append_log_full(Enums.LogType.LogType_Effect, self, "no longer ignores pushes and pulls.")
			elif effect['timing'] == current_timing:
				# Need to remove these effects from the remaining effects.
				# Only if the current timing belongs to the player who has this in their continuous boosts.
				assert(current_timing != "during_strike", "Can't remove boosts at this timing, unexpected, and effects are handled differently.")
				var current_timing_player_id = parent.get_current_strike_timing_player_id()
				if current_timing_player_id == my_id:
					# The current timing matches the player whose continuous boosts this is in.
					# Remove it from the ongoing remaining effects.
					parent.remove_remaining_effect(effect, card.id)

		if parent.active_strike and not parent.active_strike.in_setup:
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
						if 'special_range' in effect:
							var current_range = str(overdrive.size())
							strike_stat_boosts.dodge_at_range_late_calculate_with = ""
							parent._append_log_full(Enums.LogType.LogType_Effect, self, "will no longer dodge attacks from range %s!" % current_range)
						else:
							var dodge_range = str(strike_stat_boosts.dodge_at_range_min)
							if strike_stat_boosts.dodge_at_range_min != strike_stat_boosts.dodge_at_range_max:
								dodge_range += "-%s" % strike_stat_boosts.dodge_at_range_max
							parent._append_log_full(Enums.LogType.LogType_Effect, self, "will no longer dodge attacks from range %s." % dodge_range)
							strike_stat_boosts.dodge_at_range_min = -1
							strike_stat_boosts.dodge_at_range_max = -1
							strike_stat_boosts.dodge_at_range_from_buddy = false
					"powerup":
						remove_power_bonus(effect['amount'])
					"powerup_both_players":
						remove_power_bonus(effect['amount'])
						opposing_player.remove_power_bonus(effect['amount'])
					"speedup":
						strike_stat_boosts.speed -= effect['amount']
					"armorup":
						strike_stat_boosts.armor -= effect['amount']
					"guardup":
						strike_stat_boosts.guard -= effect['amount']
					"rangeup":
						strike_stat_boosts.min_range -= effect['amount']
						strike_stat_boosts.max_range -= effect['amount2']
					"rangeup_both_players":
						strike_stat_boosts.min_range -= effect['amount']
						strike_stat_boosts.max_range -= effect['amount2']
						opposing_player.strike_stat_boosts.min_range -= effect['amount']
						opposing_player.strike_stat_boosts.max_range -= effect['amount2']

	func remove_from_continuous_boosts(card : GameCard, destination : String = "discard"):
		var events = []
		disable_boost_effects(card)

		# Do any discarded effects
		events += do_discarded_effects_for_boost(card)

		# Update internal boost arrays
		for boost_array in [boosts_to_gauge_on_move, on_buddy_boosts]:
			var card_idx = boost_array.find(card.id)
			if card_idx != -1:
				boost_array.remove_at(card_idx)

		# Add to gauge or discard as appropriate.
		for i in range(len(continuous_boosts)):
			if continuous_boosts[i].id == card.id:
				if destination == "gauge":
					events += add_to_gauge(card)
				elif destination == "hand":
					# This should go to the owner's hand.
					var owner_player = parent._get_player(card.owner_id)
					events += owner_player.add_to_hand(card, true)
				elif destination == "overdrive":
					events += add_to_overdrive(card)
				elif destination == "sealed":
					events += add_to_sealed(card)
				elif destination == "strike":
					pass
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

	func set_add_boost_to_gauge_on_move(card_id):
		boosts_to_gauge_on_move.append(card_id)

	func set_boost_applies_if_on_buddy(card_id):
		on_buddy_boosts.append(card_id)

	func add_boosts_to_gauge_on_move():
		var events = []
		for card_id in boosts_to_gauge_on_move:
			var card = parent.card_db.get_card(card_id)
			var card_name = parent.card_db.get_card_name(card_id)
			parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "adds boosted card %s to gauge after moving." % card_name)
			events += remove_from_continuous_boosts(card, "gauge")
		boosts_to_gauge_on_move = []
		return events

	func handle_on_buddy_boosts(enable):
		for card_id in on_buddy_boosts:
			var card = parent.card_db.get_card(card_id)
			var boost_name = parent._get_boost_and_card_name(card)
			if enable:
				parent._append_log_full(Enums.LogType.LogType_Effect, self, "'s boost %s re-activated." % boost_name)
				reenable_boost_effects(card)
			else:
				parent._append_log_full(Enums.LogType.LogType_Effect, self, "'s boost %s was disabled." % boost_name)
				disable_boost_effects(card, true, false)

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

		# Remove it from boost locations if it is in the arena.
		events += remove_boost_in_location(card.id)

		return events

	func cleanup_continuous_boosts():
		var events = []
		var sustained_cards : Array[GameCard] = []
		for boost_card in continuous_boosts:
			var sustained = false
			if boost_card.id in cleanup_boost_to_gauge_cards:
				events += add_to_gauge(boost_card)
				var card_name = parent.card_db.get_card_name(boost_card.id)
				parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "adds boosted card %s to gauge." % card_name)
			else:
				var boost_name = parent._get_boost_and_card_name(boost_card)
				if boost_card.id in sustained_boosts:
					sustained = true
					sustained_cards.append(boost_card)
				else:
					events += add_to_discards(boost_card)
					parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "discards their continuous boost %s from play." % boost_name)
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

		# Check for lightning rods.
		if timing_name == "after":
			for i in range(len(lightningrod_zones)):
				var location = i + 1
				for card in lightningrod_zones[i]:
					var card_name = parent.card_db.get_card_name(card.id)
					var lightning_effect = {
						"timing": "after",
						"condition": "opponent_at_location",
						"condition_detail": location,
						"special_choice_name": "Lightning Rod (%s)" % [card_name],
						"effect_type": "choice",
						"choice": [
							{
								"effect_type": "lightningrod_strike",
								"card_name": card_name,
								"card_id": card.id,
								"location": location,
							},
							{ "effect_type": "pass" }
						]
					}
					effects.append(lightning_effect)
		return effects

	func get_bonus_effects_at_timing(timing_name : String):
		var effects = []
		for effect in strike_stat_boosts.added_attack_effects:
			if effect['timing'] == timing_name:
				effects.append(effect)
		return effects

	func get_on_boost_effects(boost_card : GameCard):
		var effects = []
		var ability_label = "ability_effects"
		if exceeded:
			ability_label = "exceed_ability_effects"
		var is_continuous_boost = boost_card.definition['boost']['boost_type'] == "continuous"
		for effect in deck_def[ability_label]:
			if effect['timing'] == "on_continuous_boost" and is_continuous_boost:
				effects.append(effect)
		return effects

	func set_strike_x(value : int, silent : bool = false):
		var events = []
		strike_stat_boosts.strike_x = max(value, 0)
		if not silent:
			events += [parent.create_event(Enums.EventType.EventType_Strike_SetX, my_id, value)]
		return events

	func get_set_strike_effects(card : GameCard) -> Array:
		var effects = []

		# Maybe later get them from boosts, but for now, just character ability.
		var ignore_condition = true
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

func get_priority_player() -> Enums.PlayerId:
	match game_state:
		Enums.GameState.GameState_PickAction, Enums.GameState.GameState_DiscardDownToMax:
			return active_turn_player
		Enums.GameState.GameState_PlayerDecision, Enums.GameState.GameState_WaitForStrike, \
		Enums.GameState.GameState_Strike_Opponent_Response, Enums.GameState.GameState_Strike_Opponent_Set_First:
			return decision_info.player
		_:
			# Any other states are internal processing.
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
	starting_player.starting_location = 3
	if starting_player.buddy_starting_offset != BuddyStartsOutOfArena:
		var buddy_space = 3 + starting_player.buddy_starting_offset
		event_queue += starting_player.place_buddy(buddy_space, starting_player.buddy_starting_id, true)
	second_player.arena_location = 7
	second_player.starting_location = 7
	if second_player.buddy_starting_offset != BuddyStartsOutOfArena:
		var buddy_space = 7 - second_player.buddy_starting_offset
		event_queue += second_player.place_buddy(buddy_space, second_player.buddy_starting_id, true)
	starting_player.initial_shuffle()
	second_player.initial_shuffle()

func draw_starting_hands_and_begin():
	var events = []
	var starting_player = _get_player(active_turn_player)
	var second_player = _get_player(next_turn_player)
	_append_log_full(Enums.LogType.LogType_Default, null,
		"Game Start - %s as %s (1st) vs %s as %s (2nd)" % [starting_player.name, starting_player.deck_def['display_name'], second_player.name, second_player.deck_def['display_name']])
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
		player.remove_card_from_hand(card.id, true, false)
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


func start_end_turn():
	active_end_of_turn_effects = true

	# Queue any end of turn character effects.
	var player_ending_turn = _get_player(active_turn_player)
	var effects = player_ending_turn.get_character_effects_at_timing("end_of_turn")
	for effect in effects:
		remaining_end_of_turn_effects.append(effect)

	# Queue any end of turn boost effects.
	for i in range(len(player_ending_turn.continuous_boosts) - 1, -1, -1):
		var card = player_ending_turn.continuous_boosts[i]
		for effect in card.definition['boost']['effects']:
			if effect['timing'] == "end_of_turn":
				if card.id in player_ending_turn.end_of_turn_boost_delay_card_ids:
					# This effect is delayed a turn, so remove it from the list and skip it for now.
					player_ending_turn.end_of_turn_boost_delay_card_ids.erase(card.id)
					continue
				effect['card_id'] = card.id
				remaining_end_of_turn_effects.append(effect)

	return continue_end_turn()

func continue_end_turn():
	var events = []
	var player_ending_turn = _get_player(active_turn_player)
	change_game_state(Enums.GameState.GameState_Boost_Processing)
	while remaining_end_of_turn_effects.size() > 0:
		var effect = remaining_end_of_turn_effects[0]
		remaining_end_of_turn_effects.erase(effect)
		var card_id = -1
		if 'card_id' in effect:
			card_id = effect['card_id']
		events += do_effect_if_condition_met(player_ending_turn, card_id, effect, null)
		if game_state == Enums.GameState.GameState_PlayerDecision:
			# Player has a decision to make, so stop mid-effect resolve.
			break

	if game_state != Enums.GameState.GameState_PlayerDecision:
		active_end_of_turn_effects = false
		events += advance_to_next_turn()

	return events

func advance_to_next_turn():
	var events = []

	var player_ending_turn = _get_player(active_turn_player)
	var other_player = _get_player(get_other_player(active_turn_player))

	# Turn is over, reset state.
	player.did_end_of_turn_draw = false
	opponent.did_end_of_turn_draw = false
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
	player.start_of_turn_strike = false
	opponent.start_of_turn_strike = false
	player.force_spent_before_strike = 0
	opponent.force_spent_before_strike = 0
	player.gauge_spent_before_strike = 0
	opponent.gauge_spent_before_strike = 0
	player.moved_self_this_strike = false
	opponent.moved_self_this_strike = false
	player.moved_past_this_strike = false
	opponent.moved_past_this_strike = false
	player.spaces_moved_this_strike = 0
	opponent.spaces_moved_this_strike = 0
	player.spaces_moved_or_forced_this_strike = 0
	opponent.spaces_moved_or_forced_this_strike = 0
	player.cards_that_will_not_hit = []
	opponent.cards_that_will_not_hit = []
	player.cards_invalid_during_strike = []
	opponent.cards_invalid_during_strike = []
	player.plague_knight_discard_names = []
	opponent.plague_knight_discard_names = []
	player.strike_action_disabled = false
	opponent.strike_action_disabled = false

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

	if game_over:
		change_game_state(Enums.GameState.GameState_GameOver)
	else:
		var starting_turn_player = _get_player(active_turn_player)
		if starting_turn_player.exceeded and starting_turn_player.overdrive.size() > 0:
			# Do overdrive effect.
			var overdrive_effects = [{
				"overdrive_action": true,
				"effect_type": "choose_discard",
				"source": "overdrive",
				"limitation": "",
				"destination": "discard",
				"amount": 1,
				"amount_min": 1
			}]
			overdrive_effects.append(starting_turn_player.get_overdrive_effect())
			overdrive_effects.append({
				"condition": "overdrive_empty",
				"effect_type": "revert"
			})
			active_overdrive = true
			remaining_overdrive_effects = overdrive_effects
			_append_log_full(Enums.LogType.LogType_Default, starting_turn_player, "'s Overdrive Effects!")
			# Intentional events = because events are passed in.
			# Note: This particular call is never expected to add the events to the queue
			# and return nothing. If it were, this function should also be passing in events
			# until we get to a top-level function that was called from game_wrapper.
			# For simplicity though, advance_to_next_turn is left as is.
			events = do_remaining_overdrive(events, starting_turn_player)
		else:
			events += start_begin_turn()
	return events

func start_begin_turn():
	active_start_of_turn_effects = true

	# Handle any start of turn boost effects.
	# Iterate in reverse as items can be removed.
	var starting_turn_player = _get_player(active_turn_player)
	for i in range(len(starting_turn_player.continuous_boosts) - 1, -1, -1):
		var card = starting_turn_player.continuous_boosts[i]
		for effect in card.definition['boost']['effects']:
			if effect['timing'] == "start_of_next_turn":
				effect['card_id'] = card.id
				remaining_start_of_turn_effects.append(effect)

	return continue_begin_turn()

func continue_begin_turn():
	var events = []
	var starting_turn_player = _get_player(active_turn_player)
	change_game_state(Enums.GameState.GameState_Boost_Processing)
	while remaining_start_of_turn_effects.size() > 0:
		var effect = remaining_start_of_turn_effects[0]
		remaining_start_of_turn_effects.erase(effect)
		events += do_effect_if_condition_met(starting_turn_player, effect['card_id'], effect, null)
		if game_state == Enums.GameState.GameState_PlayerDecision:
			# Player has a decision to make, so stop mid-effect resolve.
			break

	if game_state != Enums.GameState.GameState_PlayerDecision:
		active_start_of_turn_effects = false

		# Transition to the pick action state, the player can now make their action for the turn.
		_append_log_full(Enums.LogType.LogType_Default, starting_turn_player, "'s Turn Start!")
		change_game_state(Enums.GameState.GameState_PickAction)
		events += [create_event(Enums.EventType.EventType_AdvanceTurn, active_turn_player, 0)]

		# Check if the player has to do a forced action for their turn.
		if starting_turn_player.effect_on_turn_start:
			var effect = starting_turn_player.effect_on_turn_start
			starting_turn_player.effect_on_turn_start = null
			# Pretend this is a character action.
			# Currently, this either does a choice which results in bonus action and boosting something
			# or causes a strike to begin. So execution will resume in do_choice or do_strike as if this
			# was the appropriate action
			active_character_action = true
			set_player_action_processing_state()
			events += do_effect_if_condition_met(starting_turn_player, -1, effect, null)
			# This is not expected to do anything currently, but potentially does some future-proofing.
			events = continue_player_action_resolution(events, starting_turn_player)
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

	active_strike.starting_distance = player.distance_to_opponent()

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
			# Intentional events = because events are passed in.
			events = begin_resolve_strike(events)
		else:
			# Intentional events = because events are passed in.
			events = strike_setup_defender_response(events)

	elif active_strike.strike_state == StrikeState.StrikeState_Defender_SetFirst:
		# Opponent will set first; check for restrictions on what they can set
		# Intentional events = because events are passed in.
		events = strike_setup_defender_response(events)

	elif active_strike.strike_state == StrikeState.StrikeState_Defender_SetEffects:
		if active_strike.waiting_for_reading_response:
			return events

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
			# Intentional events = because events are passed in.
			events = strike_setup_initiator_response(events)
		else:
			# Intentional events = because events are passed in.
			events = begin_resolve_strike(events)
	return events

func strike_setup_defender_response(events):
	active_strike.strike_state = StrikeState.StrikeState_Defender_SetEffects
	change_game_state(Enums.GameState.GameState_Strike_Opponent_Response)
	var ask_for_response = true
	decision_info.clear()
	if active_strike.initiator.force_opponent_respond_wild_swing():
		events += [create_event(Enums.EventType.EventType_Strike_ForceWildSwing, active_strike.initiator.my_id, 0)]
		# Queue any events so far, then empty this tally and call do_strike.
		event_queue += events
		events = []
		_append_log_full(Enums.LogType.LogType_Effect, active_strike.defender, "is forced to wild swing.")
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
			active_strike.waiting_for_reading_response = true
			ask_for_response = false
		else:
			_append_log_full(Enums.LogType.LogType_Effect, active_strike.defender, "does not have the named card.")
			events += active_strike.defender.reveal_hand()
	if ask_for_response:
		decision_info.player = active_strike.defender.my_id
		if active_strike.opponent_sets_first:
			events += [create_event(Enums.EventType.EventType_Strike_OpponentSetsFirst_DefenderSet, active_strike.defender.my_id, 0)]
		else:
			events += [create_event(Enums.EventType.EventType_Strike_DoResponseNow, active_strike.defender.my_id, 0)]
	return events

func strike_setup_initiator_response(events):
	active_strike.strike_state = StrikeState.StrikeState_Initiator_SetEffects
	change_game_state(Enums.GameState.GameState_WaitForStrike)
	var ask_for_response = true
	decision_info.clear()
	if active_strike.initiator.next_strike_random_gauge:
		# Queue any events so far, then empty this tally and call do_strike.
		event_queue += events
		events = []
		decision_info.player = active_strike.initiator.my_id
		do_strike(active_strike.initiator, -1, false, -1, active_strike.opponent_sets_first)
		ask_for_response = false
	if ask_for_response:
		decision_info.player = active_strike.initiator.my_id
		events += [create_event(Enums.EventType.EventType_Strike_OpponentSetsFirst_InitiatorSet, active_strike.initiator.my_id, 0)]
	return events

func begin_resolve_strike(events):
	# Strike is beginning, setup has been completed.
	active_strike.in_setup = false

	# Handle known cards, don't include wild swings.
	# However, wild swings do get removed from known cards if they were being tracked
	# from having been put on top deck.
	if not active_strike.get_player_wild_strike(active_strike.initiator):
		active_strike.initiator.on_hand_remove_public_card(active_strike.initiator_card.id)
		if active_strike.initiator_ex_card != null:
			active_strike.initiator.on_hand_remove_public_card(active_strike.initiator_ex_card.id)
	else:
		active_strike.initiator.on_hand_removed_topdeck(active_strike.initiator_card.id)

	if not active_strike.get_player_wild_strike(active_strike.defender):
		active_strike.defender.on_hand_remove_public_card(active_strike.defender_card.id)
		if active_strike.defender_ex_card != null:
			active_strike.defender.on_hand_remove_public_card(active_strike.defender_ex_card.id)
	else:
		active_strike.defender.on_hand_removed_topdeck(active_strike.defender_card.id)

	active_strike.initiator.update_public_hand_if_deck_empty()
	active_strike.defender.update_public_hand_if_deck_empty()

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
	_append_log_full(Enums.LogType.LogType_Strike, null, "Strike Reveal: %s's %s%s vs %s's %s%s!" % [initiator_name, initiator_ex, initiator_card, defender_name, defender_ex, defender_card])

	# Handle EX
	if active_strike.initiator_ex_card != null:
		active_strike.initiator.strike_stat_boosts.set_ex()
	if active_strike.defender_ex_card != null:
		active_strike.defender.strike_stat_boosts.set_ex()

	# Begin initial state
	active_strike.effects_resolved_in_timing = 0
	active_strike.strike_state = StrikeState.StrikeState_Initiator_RevealEffects
	active_strike.remaining_effect_list = get_all_effects_for_timing("on_strike_reveal", active_strike.initiator, active_strike.initiator_card)

	active_strike.initiator.did_strike_this_turn = true
	active_strike.defender.did_strike_this_turn = true

	# Clear any setup stuff.
	player.extra_effect_after_set_strike = null
	opponent.extra_effect_after_set_strike = null

	# Intentional events = because events are passed in.
	events = continue_resolve_strike(events)
	return events

func get_total_speed(check_player):
	if check_player.strike_stat_boosts.overwrite_total_speed:
		return check_player.strike_stat_boosts.overwritten_total_speed

	var check_card = active_strike.get_player_card(check_player)
	var bonus_speed = check_player.strike_stat_boosts.speed * check_player.strike_stat_boosts.speed_bonus_multiplier
	var speed = check_card.definition['speed'] + bonus_speed
	if active_strike and active_strike.extra_attack_in_progress:
		# If an extra attack character has ways to get speed multipliers, deal with that then.
		speed -= active_strike.extra_attack_data.extra_attack_previous_attack_speed_bonus
	return speed

func strike_determine_order():
	# Determine activation
	var initiator_speed = get_total_speed(active_strike.initiator)
	var defender_speed = get_total_speed(active_strike.defender)
	active_strike.initiator_first = initiator_speed >= defender_speed
	_append_log_full(Enums.LogType.LogType_Strike, null, "%s has speed %s, %s has speed %s." % [active_strike.initiator.name, initiator_speed, active_strike.defender.name, defender_speed])

func do_effect_if_condition_met(performing_player : Player, card_id : int, effect, local_conditions : LocalStrikeConditions):
	var events = []

	if 'skip_if_boost_sustained' in effect and effect['skip_if_boost_sustained']:
		if card_id in performing_player.sustained_boosts:
			return events

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
		elif condition == "not_moved_self_this_strike":
			return not performing_player.moved_self_this_strike
		elif condition == "opponent_not_moved_this_strike":
			return not other_player.moved_self_this_strike
		elif condition == "initiated_at_range":
			var range_min = effect['range_min']
			var range_max = effect['range_max']
			if active_strike.initiator != performing_player:
				return false

			# check each space that the opponent occupied
			var starting_distance = active_strike.starting_distance
			var other_size = other_player.get_size()
			for i in range(other_size):
				if starting_distance+i >= range_min and starting_distance+i <= range_max:
					return true
			return false
		elif condition == "initiated_after_moving":
			var initiated_strike = active_strike.initiator == performing_player
			var required_amount = effect['condition_amount']
			return initiated_strike and performing_player.pre_strike_movement >= required_amount
		elif condition == "moved_during_strike":
			var required_amount = effect['condition_amount']
			return performing_player.spaces_moved_this_strike >= required_amount
		elif condition == "opponent_moved_or_was_moved":
			var required_amount = effect['condition_amount']
			return other_player.spaces_moved_or_forced_this_strike >= required_amount
		elif condition == "initiated_face_up":
			var initiated_strike = active_strike.initiator == performing_player
			return initiated_strike and active_strike.initiator_set_face_up
		elif condition == "is_normal_attack":
			return active_strike.get_player_card(performing_player).definition['type'] == "normal"
		elif condition == "deck_not_empty":
			return performing_player.deck.size() > 0
		elif condition == "top_deck_is_normal_attack":
			if performing_player.deck.size() > 0:
				return performing_player.deck[0].definition['type'] == "normal"
			return false
		elif condition == "is_buddy_special_or_ultra_attack":
			var buddy_id = ""
			if 'condition_buddy_id' in effect:
				buddy_id = effect['condition_buddy_id']
			var attack_type = active_strike.get_player_card(performing_player).definition['type']
			return performing_player.is_buddy_in_play(buddy_id) and (attack_type == "special" or attack_type == "ultra")
		elif condition == "is_special_attack":
			return active_strike.get_player_card(performing_player).definition['type'] == "special"
		elif condition == "is_special_or_ultra_attack":
			var special = active_strike.get_player_card(performing_player).definition['type'] == "special"
			var ultra = active_strike.get_player_card(performing_player).definition['type'] == "ultra"
			return special or ultra
		elif condition == "is_ex_strike":
			return active_strike.will_be_ex(performing_player)
		elif condition == "at_edge_of_arena":
			return performing_player.is_at_edge_of_arena()
		elif condition == "boost_in_play":
			return performing_player.continuous_boosts.size() > 0
		elif condition == "no_boost_in_play":
			return performing_player.continuous_boosts.size() == 0
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
		elif condition == "boost_caused_start_of_turn_strike":
			return performing_player.start_of_turn_strike
		elif condition == "hit_opponent":
			if active_strike.extra_attack_in_progress:
				return active_strike.extra_attack_data.extra_attack_hit
			else:
				return active_strike.did_player_hit_opponent(performing_player)
		elif condition == "not_hit_opponent":
			if active_strike.extra_attack_in_progress:
				return not active_strike.extra_attack_data.extra_attack_hit
			else:
				return not active_strike.did_player_hit_opponent(performing_player)
		elif condition == "not_this_turn_was_strike":
			return not strike_happened_this_turn
		elif condition == "last_turn_was_strike":
			return last_turn_was_strike
		elif condition == "not_last_turn_was_strike":
			return not last_turn_was_strike
		elif condition == "life_equals":
			var amount = effect['condition_amount']
			return performing_player.life == amount
		elif condition == "did_end_of_turn_draw":
			return performing_player.did_end_of_turn_draw
		elif condition == "discarded_matches_attack_speed":
			var discarded_card_ids = effect['discarded_card_ids']
			assert(discarded_card_ids.size() == 1)
			var card = card_db.get_card(discarded_card_ids[0])
			var speed_of_discarded = card.definition['speed']
			var attack_card = active_strike.get_player_card(performing_player)
			var printed_speed_of_attack = attack_card.definition['speed']
			return speed_of_discarded == printed_speed_of_attack
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
		elif condition == "pushed_min_spaces":
			return local_conditions.push_amount >= effect['condition_amount']
		elif condition == "pulled_past":
			return local_conditions.pulled_past
		elif condition == "exceeded":
			return performing_player.exceeded
		elif condition == "not_exceeded":
			return not performing_player.exceeded
		elif condition == "max_cards_in_hand":
			var amount = effect['condition_amount']
			return performing_player.hand.size() <= amount
		elif condition == "matches_named_card":
			var player_card = active_strike.get_player_card(performing_player)
			return player_card.definition['id'] == effect['condition_card_id']
		elif condition == "min_cards_in_discard":
			var amount = effect['condition_amount']
			return performing_player.discards.size() >= amount
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
		elif condition == "moved_past":
			return performing_player.moved_past_this_strike
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
		elif condition == "any_buddy_in_opponent_space":
			var buddies = performing_player.get_buddies_on_opponent()
			return buddies.size() > 0
		elif condition == "not_any_buddy_in_opponent_space":
			var buddies = performing_player.get_buddies_on_opponent()
			return buddies.size() == 0
		elif condition == "any_buddy_adjacent_opponent_space":
			var buddies = performing_player.get_buddies_adjacent_opponent()
			return buddies.size() > 0
		elif condition == "any_buddy_in_or_adjacent_opponent_space":
			var buddies = performing_player.get_buddies_on_opponent() + performing_player.get_buddies_adjacent_opponent()
			return buddies.size() > 0
		elif condition == "buddy_in_opponent_space":
			var buddy_id = ""
			if 'condition_buddy_id' in effect:
				buddy_id = effect['condition_buddy_id']
			if not performing_player.is_buddy_in_play(buddy_id):
				return false
			return other_player.is_in_location(performing_player.get_buddy_location(buddy_id))
		elif condition == "any_buddy_in_play":
			for buddy_location in performing_player.buddy_locations:
				if buddy_location != -1:
					return true
		elif condition == "buddy_in_play":
			var buddy_id = ""
			if 'condition_buddy_id' in effect:
				buddy_id = effect['condition_buddy_id']
			if 'condition_extra' in effect and effect['condition_extra'] == "buddy_not_entered_play_this_strike":
				# If the buddy just entered play, this condition fails.
				if buddy_id in performing_player.strike_stat_boosts.buddies_that_entered_play_this_strike:
					return false
			return performing_player.is_buddy_in_play(buddy_id)
		elif condition == "not_buddy_in_play":
			var buddy_id = ""
			if 'condition_buddy_id' in effect:
				buddy_id = effect['condition_buddy_id']
			return not performing_player.is_buddy_in_play(buddy_id)
		elif condition == "on_buddy_space":
			var buddy_id = ""
			if 'condition_buddy_id' in effect:
				buddy_id = effect['condition_buddy_id']
			if not performing_player.is_buddy_in_play(buddy_id):
				return false
			return performing_player.is_in_location(performing_player.get_buddy_location(buddy_id))
		elif condition == "opponent_on_buddy_space":
			var buddy_id = ""
			if 'condition_buddy_id' in effect:
				buddy_id = effect['condition_buddy_id']
			if not performing_player.is_buddy_in_play(buddy_id):
				return false
			return other_player.is_in_location(performing_player.get_buddy_location(buddy_id))
		elif condition == "opponent_in_boost_space":
			var this_boost_location = performing_player.get_boost_location(effect['card_id'])
			return other_player.is_in_location(this_boost_location)
		elif condition == "buddy_between_attack_source":
			var buddy_id = ""
			if 'condition_buddy_id' in effect:
				buddy_id = effect['condition_buddy_id']
			if not performing_player.is_buddy_in_play(buddy_id):
				return false

			var pos1 = performing_player.get_closest_occupied_space_to(other_player.arena_location)
			var pos2 = get_attack_origin(other_player, performing_player.arena_location)
			var buddy_pos = performing_player.get_buddy_location(buddy_id)
			if pos1 < pos2: # opponent is on the right
				return buddy_pos > pos1 and buddy_pos < pos2
			else: # opponent is on the left
				return buddy_pos > pos2 and buddy_pos < pos1
		elif condition == "buddy_between_opponent":
			var buddy_id = ""
			if 'condition_buddy_id' in effect:
				buddy_id = effect['condition_buddy_id']
			if not performing_player.is_buddy_in_play(buddy_id):
				return false

			var pos1 = performing_player.get_closest_occupied_space_to(other_player.arena_location)
			var pos2 = other_player.get_closest_occupied_space_to(performing_player.arena_location)

			var buddy_pos = performing_player.get_buddy_location(buddy_id)
			if pos1 < pos2: # opponent is on the right
				return buddy_pos > pos1 and buddy_pos < pos2
			else: # opponent is on the left
				return buddy_pos > pos2 and buddy_pos < pos1
		elif condition == "boost_space_between_opponent":
			var pos1 = performing_player.get_closest_occupied_space_to(other_player.arena_location)
			var pos2 = other_player.get_closest_occupied_space_to(performing_player.arena_location)

			var this_boost_location = performing_player.get_boost_location(effect['card_id'])
			if pos1 < pos2: # opponent is on the right
				return this_boost_location > pos1 and this_boost_location < pos2
			else: # opponent is on the left
				return this_boost_location > pos2 and this_boost_location < pos1
		elif condition == "opponent_between_buddy":
			var include_buddy_space = 'include_buddy_space' in effect and effect['include_buddy_space']
			if 'condition_buddy_id' in effect:
				var buddy_id = effect['condition_buddy_id']
				return performing_player.is_opponent_between_buddy(buddy_id, other_player, include_buddy_space)
			elif 'condition_any_of_buddy_ids' in effect:
				for buddy_id in effect['condition_any_of_buddy_ids']:
					if performing_player.is_opponent_between_buddy(buddy_id, other_player, include_buddy_space):
						return true
				return false
			else:
				# Use default buddy id.
				return performing_player.is_opponent_between_buddy("", other_player, include_buddy_space)
		elif condition == "opponent_buddy_in_range":
			var buddy_id = effect['condition_buddy_id']
			var require_not_immune = 'condition_extra' in effect and effect['condition_extra'] == "buddy_not_immune_to_flip"
			if not other_player.is_buddy_in_play(buddy_id):
				return false
			if require_not_immune and other_player.strike_stat_boosts.buddy_immune_to_flip:
				return false
			if not active_strike:
				return false
			var buddy_location = other_player.get_buddy_location(buddy_id)
			var attack_card = active_strike.get_player_card(performing_player)
			return is_location_in_range(performing_player, attack_card, buddy_location) or performing_player.is_in_location(buddy_location)
		elif condition == "buddy_space_unoccupied":
			var buddy_id = ""
			if 'condition_buddy_id' in effect:
				buddy_id = effect['condition_buddy_id']
			if not performing_player.is_buddy_in_play(buddy_id):
				return false

			var buddy_location = performing_player.get_buddy_location(buddy_id)
			if performing_player.is_in_location(buddy_location) or other_player.is_in_location(buddy_location):
				return false

			return true
		elif condition == "opponent_at_edge_of_arena":
			return other_player.is_at_edge_of_arena()
		elif condition == "opponent_at_location":
			var location = effect['condition_detail']
			return other_player.is_in_location(location)
		elif condition == "opponent_at_max_range":
			assert(active_strike)
			var max_range = get_total_max_range(performing_player)
			var origin = get_attack_origin(performing_player, other_player.arena_location)
			return other_player.is_in_range_of_location(origin, max_range, max_range)
		elif condition == "opponent_stunned":
			return active_strike.is_player_stunned(other_player)
		elif condition == "overdrive_empty":
			return performing_player.overdrive.size() == 0
		elif condition == "range":
			var amount = effect['condition_amount']
			var origin = performing_player.get_closest_occupied_space_to(other_player.arena_location)
			return other_player.is_in_range_of_location(origin, amount, amount)
		elif condition == "range_greater_or_equal":
			var amount = effect['condition_amount']
			var origin = performing_player.get_closest_occupied_space_to(other_player.arena_location)
			var farthest_point = other_player.get_furthest_edge_from(origin)
			var distance = abs(origin - farthest_point)
			return distance >= amount
		elif condition == "range_multiple":
			var min_amount = effect["condition_amount_min"]
			var max_amount = effect["condition_amount_max"]
			var origin = performing_player.get_closest_occupied_space_to(other_player.arena_location)
			return other_player.is_in_range_of_location(origin, min_amount, max_amount)
		elif condition == "strike_x_greater_than":
			var amount = effect['condition_amount']
			return performing_player.strike_stat_boosts.strike_x > amount
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
		elif condition == "is_not_critical":
			return not performing_player.strike_stat_boosts.critical
		elif condition == "choose_cards_from_top_deck_action":
			return decision_info.action == effect["condition_details"]
		elif condition == "total_powerup_greater_or_equal":
			var amount = effect["condition_amount"]
			var strike_card = active_strike.get_player_card(performing_player)
			var power = get_card_stat(performing_player, strike_card, 'power')
			var total_power = get_total_power(performing_player)
			var total_powerup = total_power - power
			return total_powerup >= amount
		elif condition == "opponent_total_guard_greater_or_equal":
			var amount = effect["condition_amount"]
			var total_guard = get_total_guard(other_player)
			return total_guard >= amount
		elif condition == "no_sealed_copy_of_attack":
			var card_id = active_strike.get_player_card(performing_player).definition["id"]
			for sealed_card in performing_player.sealed:
				if sealed_card.definition["id"] == card_id:
					return false
			return true
		elif condition == "speed_greater_than":
			if effect['condition_amount'] == "OPPONENT_SPEED":
				return get_total_speed(performing_player) > get_total_speed(other_player)
			else:
				return get_total_speed(performing_player) > effect['condition_amount']
		elif condition == "top_discard_is_continous_boost":
			var top_discard_card = performing_player.get_top_discard_card()
			if top_discard_card:
				return top_discard_card.definition['boost']['boost_type'] == "continuous"
			else:
				return false
		elif condition == "can_continuous_boost_from_gauge":
			return performing_player.can_boost_something(['gauge'], 'continuous')
		else:
			assert(false, "Unimplemented condition")
		# Unmet condition
		return false
	return true

class LocalStrikeConditions:
	var fully_closed : bool = false
	var fully_retreated : bool = false
	var fully_pushed : bool = false
	var push_amount : int = 0
	var advanced_through : bool = false
	var advanced_through_buddy : bool = false
	var pulled_past : bool = false
	var manual_reshuffle : bool = false

func wait_for_mid_strike_boost():
	return game_state == Enums.GameState.GameState_PlayerDecision and decision_info.type == Enums.DecisionType.DecisionType_BoostNow

func handle_strike_effect(card_id : int, effect, performing_player : Player):
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
		"add_attack_effect":
			var current_timing = get_current_strike_timing()
			var effect_to_add = effect['added_effect']
			var to_add_timing = effect['added_effect']['timing']
			effect_to_add['card_id'] = card_id
			if current_timing == to_add_timing:
				# Add it into the current remaining effects list.
				# Assumption! There is no way to add stuff during the opponent's timings.
				add_remaining_effect(effect_to_add)
			else:
				performing_player.strike_stat_boosts.added_attack_effects.append(effect_to_add)
		"add_boost_to_gauge_on_strike_cleanup":
			if card_id == -1:
				assert(false)
				printlog("ERROR: Unimplemented path to add_boost_to_gauge_on_strike_cleanup")
			#performing_player.add_boost_to_gauge_on_strike_cleanup(card_id)
			# Switching to doing it immediately
			var card = card_db.get_card(card_id)
			var card_name = card_db.get_card_name(card.id)
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds boosted card %s to gauge." % card_name)
			events += performing_player.remove_from_continuous_boosts(card, "gauge")
		"add_boost_to_gauge_on_move":
			if card_id == -1:
				assert(false)
				printlog("ERROR: Unimplemented path to add_boost_to_gauge_on_move")
			performing_player.set_add_boost_to_gauge_on_move(card_id)
		"add_boost_to_overdrive_during_strike_immediately":
			if card_id == -1:
				assert(false)
				printlog("ERROR: Unimplemented path to add_boost_to_overdrive_during_strike_immediately")
			var card = card_db.get_card(card_id)
			var card_name = card_db.get_card_name(card.id)
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds boosted card %s to overdrive." % card_name)
			events += performing_player.remove_from_continuous_boosts(card, "overdrive")
		"add_hand_to_gauge":
			events += performing_player.add_hand_to_gauge()
		"add_set_aside_card_to_deck":
			var card_name = performing_player.get_set_aside_card(effect['id']).definition['display_name']
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "will draw the set-aside card %s." % card_name)
			events += performing_player.add_set_aside_card_to_deck(effect['id'])
		"add_strike_to_gauge_after_cleanup":
			performing_player.strike_stat_boosts.always_add_to_gauge = true
		"add_strike_to_overdrive_after_cleanup":
			performing_player.strike_stat_boosts.always_add_to_overdrive = true
			events += handle_strike_attack_immediate_removal(performing_player)
		"add_to_gauge_boost_play_cleanup":
			active_boost.cleanup_to_gauge_card_ids.append(card_id)
		"add_to_gauge_immediately":
			var card = card_db.get_card(card_id)
			var card_name = card_db.get_card_name(card.id)
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds boosted card %s to gauge." % card_name)
			events += performing_player.remove_from_continuous_boosts(card, "gauge")
		"add_to_gauge_immediately_mid_strike_undo_effects":
			var card = card_db.get_card(card_id)
			var card_name = card_db.get_card_name(card.id)
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds boosted card %s to gauge." % card_name)
			events += performing_player.remove_from_continuous_boosts(card, "gauge")
		"add_top_deck_to_gauge":
			var amount = 1
			if 'amount' in effect:
				amount = effect['amount']

			var actual_amount = min(amount, len(performing_player.deck))
			if actual_amount > 0:
				var card_names = _card_list_to_string(performing_player.deck.slice(0, actual_amount))
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds the top %s card(s) of their deck to gauge: %s." % [amount, card_names])
			else:
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "has no cards in their deck to add to gauge.")
			events += performing_player.add_top_deck_to_gauge(amount)
		"add_top_discard_to_gauge":
			var amount = 1
			if 'amount' in effect:
				amount = effect['amount']

			var actual_amount = min(amount, len(performing_player.discards))
			if actual_amount > 0:
				var card_ids = []
				for i in range(performing_player.discards.size() - 1, -1, -1):
					card_ids.append(performing_player.discards[i].id)
				var card_names = card_db.get_card_names(card_ids)
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds the top %s card(s) of their discards to gauge: %s." % [amount, card_names])
			else:
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "has no cards in their discard pile to add to gauge.")
			events += performing_player.add_top_discard_to_gauge(amount)
		"add_top_discard_to_overdrive":
			var amount = 1
			if 'amount' in effect:
				amount = effect['amount']

			var actual_amount = min(amount, len(performing_player.discards))
			if actual_amount > 0:
				var card_ids = []
				for i in range(performing_player.discards.size() - 1, -1, -1):
					card_ids.append(performing_player.discards[i].id)
				var card_names = card_db.get_card_names(card_ids)
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds the top %s card(s) of their discards to overdrive: %s." % [amount, card_names])
			else:
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "has no cards in their discard pile to add to overdrive.")
			events += performing_player.add_top_discard_to_overdrive(amount)
		"advance":
			decision_info.clear()
			decision_info.source = "advance"
			decision_info.amount = effect['amount']
			decision_info.limitation = { 'and': null, 'bonus_effect': null }
			if 'and' in effect:
				decision_info.limitation['and'] = effect['and']
			if 'bonus_effect' in effect:
				decision_info.limitation['bonus_effect'] = effect['bonus_effect']

			var stop_on_space = -1
			if 'stop_on_buddy_space' in effect:
				var buddy_location = performing_player.get_buddy_location(effect['stop_on_buddy_space'])
				if buddy_location != performing_player.arena_location and buddy_location != opposing_player.arena_location:
					stop_on_space = buddy_location

			var effects = performing_player.get_character_effects_at_timing("on_advance_or_close")
			for sub_effect in effects:
				events += do_effect_if_condition_met(performing_player, -1, sub_effect, null)
			if game_state != Enums.GameState.GameState_PlayerDecision:
				var advance_effect = effect.duplicate()
				advance_effect['effect_type'] = "advance_INTERNAL"
				advance_effect['stop_on_space'] = stop_on_space
				events += handle_strike_effect(card_id, advance_effect, performing_player)
				# and/bonus_effect should be handled by internal version
				ignore_extra_effects = true
		"advance_INTERNAL":
			var amount = effect['amount']
			if str(amount) == "strike_x":
				amount = performing_player.strike_stat_boosts.strike_x
			amount += performing_player.strike_stat_boosts.increase_movement_effects_by

			var stop_on_space = -1
			if 'stop_on_space' in effect:
				stop_on_space = effect['stop_on_space']
			var previous_location = performing_player.arena_location
			events += performing_player.advance(amount, stop_on_space)
			var new_location = performing_player.arena_location
			_append_log_full(Enums.LogType.LogType_CharacterMovement, performing_player, "advances %s, moving from space %s to %s." % [str(amount), str(previous_location), str(new_location)])
			if (performing_start < other_start and new_location > other_start) or (performing_start > other_start and new_location < other_start):
				local_conditions.advanced_through = true
				performing_player.moved_past_this_strike = true
				if performing_player.strike_stat_boosts.range_includes_if_moved_past:
					performing_player.strike_stat_boosts.range_includes_opponent = true
					_append_log_full(Enums.LogType.LogType_Effect, performing_player, "advanced through the opponent, putting them in range!")
			if ((performing_player.is_in_or_left_of_location(buddy_start, performing_start) and performing_player.is_in_or_right_of_location(buddy_start, new_location)) or
					(performing_player.is_in_or_right_of_location(buddy_start, performing_start) and performing_player.is_in_or_left_of_location(buddy_start, new_location))):
				local_conditions.advanced_through_buddy = true
		"armorup":
			performing_player.strike_stat_boosts.armor += effect['amount']
			events += [create_event(Enums.EventType.EventType_Strike_ArmorUp, performing_player.my_id, effect['amount'])]
		"armorup_damage_dealt":
			# If Tenacious Mist can be used as an additional attack, this implementation will be incorrect for that case
			var damage_dealt = active_strike.get_damage_taken(opposing_player)
			performing_player.strike_stat_boosts.armor += damage_dealt
			events += [create_event(Enums.EventType.EventType_Strike_ArmorUp, performing_player.my_id, damage_dealt)]
		"armorup_current_power":
			var current_power = get_total_power(performing_player)
			performing_player.strike_stat_boosts.armor += current_power
			events += [create_event(Enums.EventType.EventType_Strike_ArmorUp, performing_player.my_id, current_power)]
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
		"become_wide":
			performing_player.extra_width = 1
			var new_form_string = "3 spaces wide"
			if 'description' in effect:
				new_form_string = effect['description']
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "is now %s!" % new_form_string)
			events += [create_event(Enums.EventType.EventType_BecomeWide, performing_player.my_id, 0, "", "Tinker Tank")]
		"block_opponent_move":
			_append_log_full(Enums.LogType.LogType_Effect, opposing_player, "is prevented from moving.")
			opposing_player.cannot_move = true
			events += [create_event(Enums.EventType.EventType_BlockMovement, opposing_player.my_id, card_id)]
		"remove_block_opponent_move":
			_append_log_full(Enums.LogType.LogType_Effect, opposing_player, "is no longer prevented from moving.")
			opposing_player.cannot_move = false
		"bonus_action":
			# You cannot take bonus actions during a strike.
			if not active_strike:
				active_boost.action_after_boost = true
		"boost_additional":
			assert(active_boost, "ERROR: Additional boost effect when a boost isn't in play")

			var valid_zones = ['hand']
			if 'valid_zones' in effect:
				valid_zones = effect['valid_zones']
			var ignore_costs = 'ignore_costs' in effect and effect['ignore_costs']
			if performing_player.can_boost_something(valid_zones, effect['limitation'], ignore_costs):
				events += [create_event(Enums.EventType.EventType_ForceStartBoost, performing_player.my_id, 0, "", valid_zones, effect['limitation'], ignore_costs)]
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_BoostNow
				decision_info.player = performing_player.my_id
				decision_info.valid_zones = valid_zones
				decision_info.limitation = effect['limitation']
				decision_info.ignore_costs = ignore_costs
			else:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no cards available to boost.")
		"boost_applies_if_on_buddy":
			if card_id == -1:
				assert(false)
				printlog("ERROR: Unimplemented path to boost_applies_if_on_buddy")
			performing_player.set_boost_applies_if_on_buddy(card_id)
		"boost_from_gauge":
			# This effect is expected to be a character action.
			if performing_player.can_boost_something(['gauge'], effect['limitation']):
				events += [create_event(Enums.EventType.EventType_ForceStartBoost, performing_player.my_id, 0, "", ['gauge'], effect['limitation'])]
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_BoostNow
				decision_info.player = performing_player.my_id
				decision_info.valid_zones = ['gauge']
				decision_info.limitation = effect['limitation']
			else:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no valid cards in gauge to boost with.")
		"boost_discarded_overdrive":
			assert(active_overdrive)
			# Doing the boost here in handle_strike_effect is awkward as do_boost is ideal but
			# queues all the events. Instead, set a flag and do it on overdrive cleanup.
			active_overdrive_boost_top_discard_on_cleanup = true
		"boost_or_reveal_hand":
			# This effect is expected to be a character action.
			if performing_player.can_boost_something(['hand'], effect['limitation']):
				events += [create_event(Enums.EventType.EventType_ForceStartBoost, performing_player.my_id, 0, "", ['hand'], effect['limitation'])]
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_BoostNow
				decision_info.player = performing_player.my_id
				decision_info.valid_zones = ['hand']
				decision_info.limitation = effect['limitation']
			else:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no valid cards in hand to boost with.")
				events += performing_player.reveal_hand()
		"boost_this_then_sustain":
			# This effect is expected to be mid-strike.
			assert(active_strike)
			var card_name = card_db.get_card_name(card_id)
			performing_player.strike_stat_boosts.move_strike_to_boosts = true
			if 'dont_sustain' in effect: # Should eventually rename effect to be more general
				performing_player.strike_stat_boosts.move_strike_to_boosts_sustain = not effect['dont_sustain']
			var and_sustain_str = ""
			if performing_player.strike_stat_boosts.move_strike_to_boosts_sustain:
				and_sustain_str = " and sustains"
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "boosts%s %s." % [and_sustain_str, card_name])
			# This removes the attack from play, so it needs to affect stats.
			events += handle_strike_attack_immediate_removal(performing_player)
			if 'boost_effect' in effect:
				var boost_effect = effect['boost_effect']
				events += do_effect_if_condition_met(performing_player, card_id, boost_effect, null)
		"boost_then_sustain":
			# This effect is expected to be mid-strike.
			assert(active_strike)
			var valid_zones = ['hand']
			if 'valid_zones' in effect:
				valid_zones = effect['valid_zones']
			if performing_player.can_boost_something(valid_zones, effect['limitation']):
				events += [create_event(Enums.EventType.EventType_ForceStartBoost, performing_player.my_id, 0, "", valid_zones, effect['limitation'])]
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_BoostNow
				decision_info.player = performing_player.my_id
				decision_info.valid_zones = valid_zones
				decision_info.limitation = effect['limitation']
				decision_info.ignore_costs = 'ignore_costs' in effect and effect['ignore_costs']
				var sustain = true
				if 'sustain' in effect and not effect['sustain']:
					sustain = false
				performing_player.sustain_next_boost = sustain
				performing_player.cancel_blocked_this_turn = true
			else:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no cards available to boost.")
		"boost_then_sustain_topdeck":
			# This effect is expected to be mid-strike.
			assert(active_strike)
			var top_deck_card = performing_player.get_top_deck_card()
			if top_deck_card:
				var skip = false
				if 'discard_if_not_continuous' in effect and effect['discard_if_not_continuous']:
					if top_deck_card.definition['boost']['boost_type'] != "continuous":
						skip = true
						events += performing_player.discard_topdeck()

				if not skip:
					var sustain = true
					if 'sustain' in effect and not effect['sustain']:
						sustain = false
					performing_player.cancel_blocked_this_turn = true
					change_game_state(Enums.GameState.GameState_PlayerDecision)
					decision_info.clear()
					decision_info.type = Enums.DecisionType.DecisionType_ForceBoostSustainTopdeck
					decision_info.player = performing_player.my_id
					active_strike.remaining_forced_boosts_sustaining = sustain
					active_strike.remaining_forced_boosts = effect['amount']
					active_strike.remaining_forced_boosts_source = "topdeck"
					active_strike.remaining_forced_boosts_player_id = performing_player.my_id
			else:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no cards in deck to boost with.")
		"boost_then_sustain_topdiscard":
			# This effect is expected to be mid-strike.
			assert(active_strike)
			var boost_card_id = performing_player.get_top_continuous_boost_in_discard()
			if boost_card_id != -1:
				var sustain = true
				if 'sustain' in effect and not effect['sustain']:
					sustain = false
				performing_player.cancel_blocked_this_turn = true
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_ForceBoostSustainTopDiscard
				decision_info.player = performing_player.my_id
				active_strike.remaining_forced_boosts_sustaining = sustain
				var amount = effect['amount']
				if amount is String and amount == "DISCARDED_COUNT":
					amount = len(effect['discarded_card_ids'])
				active_strike.remaining_forced_boosts = amount
				active_strike.remaining_forced_boosts_source = "topdiscard"
				active_strike.remaining_forced_boosts_player_id = performing_player.my_id
			else:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no cards in discards to boost with.")
		"boost_then_strike":
			# This effect is expected to be a character action.
			var valid_zones = ['hand']
			if 'valid_zones' in effect:
				valid_zones = effect['valid_zones']
			if performing_player.can_boost_something(valid_zones, effect['limitation']):
				events += [create_event(Enums.EventType.EventType_ForceStartBoost, performing_player.my_id, 0, "", valid_zones, effect['limitation'])]
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_BoostNow
				decision_info.player = performing_player.my_id
				decision_info.valid_zones = valid_zones
				decision_info.limitation = effect['limitation']
				performing_player.strike_on_boost_cleanup = true
				if 'wild_strike' in effect and effect['wild_strike']:
					performing_player.wild_strike_on_boost_cleanup = true
			else:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no cards available to boost.")
				if not active_boost:
					events += [create_event(Enums.EventType.EventType_ForceStartStrike, performing_player.my_id, 0)]
				change_game_state(Enums.GameState.GameState_WaitForStrike)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
				decision_info.player = performing_player.my_id
		"boost_as_overdrive":
			# This effect will occur after all start of turn stuff is done.
			# This will be carried out as a special forced character action that
			# automatically happens at that time.
			performing_player.effect_on_turn_start = {
				"effect_type": "choice",
				"choice": [
					{
						"effect_type": "boost_as_overdrive_internal",
						"limitation": effect['limitation'],
						"valid_zones": effect['valid_zones'],
					},
					{
						"effect_type": "pass",
						"suppress_and_description": true,
						"and": {
							"effect_type": "take_bonus_actions",
							"amount": 1
						}
					}
				]
			}
		"boost_as_overdrive_internal":
			# All overdrive/start of turn stuff is done and the player chose to boost.
			# They may not have a continuous boost, but
			# they need the bonus action regardless as this is in a weird forced character action timing.
			var valid_zones = effect['valid_zones']
			var limitation = effect['limitation']
			performing_player.bonus_actions = 1
			if performing_player.can_boost_something(valid_zones, effect['limitation']):
				events += [create_event(Enums.EventType.EventType_ForceStartBoost, performing_player.my_id, 0, "", valid_zones, limitation)]
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_BoostNow
				decision_info.player = performing_player.my_id
				decision_info.valid_zones = valid_zones
				decision_info.limitation = limitation
			else:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no cards available to boost for the overdrive effect.")
		"buddy_immune_to_flip":
			performing_player.strike_stat_boosts.buddy_immune_to_flip = true
		"cannot_go_below_life":
			performing_player.strike_stat_boosts.cannot_go_below_life = effect['amount']
		"cannot_stun":
			performing_player.strike_stat_boosts.cannot_stun = true
		"choice":
			var choice_player = performing_player
			if 'opponent' in effect and effect['opponent']:
				choice_player = opposing_player
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.clear()
			decision_info.type = Enums.DecisionType.DecisionType_EffectChoice
			decision_info.player = choice_player.my_id
			if 'add_topdeck_card_name_to_choices' in effect:
				# Add a 'card_name' field to each choice that's in this array.
				for index in effect['add_topdeck_card_name_to_choices']:
					var choice = effect['choice'][index]
					var card_name = "nothing (deck empty)"
					if choice_player.deck.size() > 0:
						card_name = card_db.get_card_name(choice_player.deck[0].id)
					choice['card_name'] = card_name
			elif 'add_topdiscard_card_name_to_choices' in effect:
				# Add a 'card_name' field to each choice that's in this array.
				for index in effect['add_topdiscard_card_name_to_choices']:
					var choice = effect['choice'][index]
					var card_name = "nothing (discard empty)"
					if choice_player.discards.size() > 0:
						card_name = card_db.get_card_name(choice_player.discards[choice_player.discards.size() - 1].id)
					choice['card_name'] = card_name

			decision_info.choice = effect['choice']
			decision_info.choice_card_id = card_id
			events += [create_event(Enums.EventType.EventType_Strike_EffectChoice, choice_player.my_id, 0, "EffectOption")]
		"choice_altered_values":
			# Make a deep copy of the choices and replace any needed values.
			var updated_choices = effect['choice'].duplicate(true)
			for choice_effect in updated_choices:
				if str(choice_effect['amount']) == "TOTAL_POWER":
					choice_effect['amount'] = get_total_power(performing_player)
				elif str(choice_effect['amount']) == "strike_x":
					choice_effect['amount'] = performing_player.strike_stat_boosts.strike_x

			# Same as normal choice.
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.clear()
			decision_info.type = Enums.DecisionType.DecisionType_EffectChoice
			decision_info.player = performing_player.my_id
			decision_info.choice = updated_choices
			decision_info.choice_card_id = card_id
			events += [create_event(Enums.EventType.EventType_Strike_EffectChoice, performing_player.my_id, 0, "EffectOption")]
		"choose_cards_from_top_deck":
			var look_amount = min(effect['look_amount'], performing_player.deck.size())
			if look_amount == 0:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no cards in their deck to look at.")
				if 'strike_after' in effect and effect['strike_after']:
					if not active_boost:
						events += [create_event(Enums.EventType.EventType_ForceStartStrike, performing_player.my_id, 0)]
					change_game_state(Enums.GameState.GameState_WaitForStrike)
					decision_info.clear()
					decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
					decision_info.player = performing_player.my_id
			elif look_amount > 0:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "looks at the top %s cards of their deck." % look_amount)
				performing_player.cancel_blocked_this_turn = true
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
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
			var discard_effect = null
			if 'discard_effect' in effect:
				discard_effect = effect['discard_effect']
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
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_ChooseFromDiscard
				decision_info.player = performing_player.my_id
				decision_info.choice_card_id = card_id
				decision_info.source = source
				decision_info.limitation = effect['limitation']
				decision_info.destination = effect['destination']
				decision_info.bonus_effect = discard_effect
				decision_info.action = null
				if 'overdrive_action' in effect and effect['overdrive_action']:
					decision_info.action = "overdrive_action"
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
					_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no %s cards in %s." % [effect['limitation'], source])
				else:
					_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no cards in %s." % source)
		"choose_sustain_boost":
			var choice_count = performing_player.continuous_boosts.size()
			choice_count -= performing_player.sustained_boosts.size()
			if choice_count > 0:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
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
			else:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no more boosts to sustain.")
		"close":
			decision_info.clear()
			decision_info.source = "close"
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
				var close_effect = effect.duplicate()
				close_effect['effect_type'] = "close_INTERNAL"
				events += handle_strike_effect(card_id, close_effect, performing_player)
				# and/bonus_effect should be handled by internal version
				ignore_extra_effects = true
		"close_INTERNAL":
			var amount = effect['amount']
			amount += performing_player.strike_stat_boosts.increase_movement_effects_by

			var previous_location = performing_player.arena_location
			events += performing_player.close(amount)
			var new_location = performing_player.arena_location
			var close_amount = abs(performing_start - new_location)
			local_conditions.fully_closed = close_amount == amount
			_append_log_full(Enums.LogType.LogType_CharacterMovement, performing_player, "closes %s, moving from space %s to %s." % [str(amount), str(previous_location), str(new_location)])
			if 'save_spaces_as_strike_x' in effect and effect['save_spaces_as_strike_x']:
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "'s X for this strike is set to the number of spaces closed, %s." % close_amount)
				events += performing_player.set_strike_x(close_amount)
		"copy_other_hit_effect":
			var card = active_strike.get_player_card(performing_player)
			var hit_effects = get_all_effects_for_timing("hit", performing_player, card)

			var effect_options = []
			for possible_effect in hit_effects:
				if possible_effect['effect_type'] != "copy_other_hit_effect":
					effect_options.append(get_base_remaining_effect(possible_effect))

			if len(effect_options) > 0:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "is copying another hit effect.")
				# Send choice to player
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_ChooseSimultaneousEffect
				decision_info.player = performing_player.my_id
				decision_info.effect_type = "copy_other_hit_effect"
				decision_info.choice = effect_options
				events += [create_event(Enums.EventType.EventType_Strike_EffectChoice, performing_player.my_id, 0, "Duplicate")]
			else:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no other hit effects to copy.")
		"critical":
			performing_player.strike_stat_boosts.critical = true
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "'s strike is Critical!")
			var strike_card = active_strike.get_player_card(performing_player)
			events += [create_event(Enums.EventType.EventType_Strike_Critical, performing_player.my_id, strike_card.id)]
		"discard_this":
			if active_boost:
				active_boost.discard_on_cleanup = true
			else:
				var card = card_db.get_card(card_id)
				var card_name = card_db.get_card_name(card.id)
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards the boosted card %s." % card_name)
				events += performing_player.remove_from_continuous_boosts(card)
				events += opposing_player.remove_from_continuous_boosts(card)
		"discard_strike_after_cleanup":
			performing_player.strike_stat_boosts.discard_attack_on_cleanup = true
		"discard_opponent_topdeck":
			events += opposing_player.discard_topdeck()
		"discard_topdeck":
			events += performing_player.discard_topdeck()
		"draw_or_discard_to":
			events += handle_player_draw_or_discard_to_effect(performing_player, card_id, effect)
		"draw_for_card_in_hand":
			var hand_size = performing_player.hand.size()
			if hand_size > 0:
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "draws %s card(s)." % hand_size)
				events += performing_player.draw(hand_size)
		"draw_to":
			var target_hand_size = effect['amount']
			var hand_size = performing_player.hand.size()
			if hand_size < target_hand_size:
				var amount_to_draw = target_hand_size - hand_size
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "draws %s card(s) to reach a hand size of %s." % [amount_to_draw, target_hand_size])
				events += performing_player.draw(amount_to_draw)
		"discard_to":
			var target_hand_size = effect['amount']
			var hand_size = performing_player.hand.size()
			if hand_size > target_hand_size:
				var amount_to_discard = hand_size - target_hand_size
				var discard_effect = {
					"effect_type": "self_discard_choose",
					"amount": amount_to_discard
				}
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "must discard %s card(s) to reach a hand size of %s." % [amount_to_discard, target_hand_size])
				events += handle_strike_effect(card_id, discard_effect, performing_player)
		"opponent_draw_or_discard_to":
			events += handle_player_draw_or_discard_to_effect(opposing_player, card_id, effect)
		"dodge_at_range":
			if 'special_range' in effect and effect['special_range'] == "OVERDRIVE_COUNT":
				var current_range = performing_player.overdrive.size()
				performing_player.strike_stat_boosts.dodge_at_range_late_calculate_with  = effect['special_range']
				events += [create_event(Enums.EventType.EventType_Strike_DodgeAttacksAtRange, performing_player.my_id, current_range, "", current_range, "")]
			else:
				performing_player.strike_stat_boosts.dodge_at_range_min = effect['range_min']
				performing_player.strike_stat_boosts.dodge_at_range_max = effect['range_max']
				var buddy_name = null
				if 'from_buddy' in effect:
					performing_player.strike_stat_boosts.dodge_at_range_from_buddy = effect['from_buddy']
					buddy_name = effect['buddy_name']
				events += [create_event(Enums.EventType.EventType_Strike_DodgeAttacksAtRange, performing_player.my_id, effect['range_min'], "", effect['range_max'], buddy_name)]
		"dodge_attacks":
			performing_player.strike_stat_boosts.dodge_attacks = true
			events += [create_event(Enums.EventType.EventType_Strike_DodgeAttacks, performing_player.my_id, 0)]
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "is now dodging attacks!")
		"dodge_from_opposite_buddy":
			performing_player.strike_stat_boosts.dodge_from_opposite_buddy = true
			events += [create_event(Enums.EventType.EventType_Strike_DodgeFromOppositeBuddy, performing_player.my_id, 0, "", effect['buddy_name'])]
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "will dodge attacks from opponents behind %s!" % effect['buddy_name'])
		"draw":
			var amount = effect['amount']
			if str(amount) == "strike_x":
				amount = performing_player.strike_stat_boosts.strike_x
			amount += performing_player.strike_stat_boosts.increase_draw_effects_by

			var from_bottom = false
			var from_bottom_string = ""
			if 'from_bottom' in effect and effect['from_bottom']:
				from_bottom = true
				from_bottom_string = " from bottom of deck"

			if amount > 0:
				if 'opponent' in effect and effect['opponent']:
					events += opposing_player.draw(amount, false, from_bottom)
					_append_log_full(Enums.LogType.LogType_CardInfo, opposing_player, "draws %s card(s)%s." % [amount, from_bottom_string])
				else:
					events += performing_player.draw(amount, false, from_bottom)
					_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "draws %s card(s)%s." % [amount, from_bottom_string])
		"draw_any_number":
			var max_user_can_draw = performing_player.deck.size()
			if performing_player.reshuffle_remaining > 0:
				max_user_can_draw += performing_player.discards.size()

			decision_info.clear()
			decision_info.type = Enums.DecisionType.DecisionType_PickNumberFromRange
			decision_info.player = performing_player.my_id
			decision_info.choice_card_id = card_id
			decision_info.effect_type = "draw"
			decision_info.choice = []
			decision_info.amount_min = 0
			decision_info.amount = max_user_can_draw

			decision_info.limitation = []
			for i in range(max_user_can_draw + 1):
				decision_info.limitation.append(i)
				decision_info.choice.append({
					"effect_type": "draw",
					"amount": i
				})

			change_game_state(Enums.GameState.GameState_PlayerDecision)
			events += [create_event(Enums.EventType.EventType_PickNumberFromRange, performing_player.my_id, 0)]
		"discard_continuous_boost":
			var my_boosts = performing_player.continuous_boosts
			var opponent_boosts = opposing_player.continuous_boosts
			decision_info.clear()
			decision_info.limitation = ""
			if 'limitation' in effect:
				decision_info.limitation = effect['limitation']
			decision_info.destination = "discard"
			if 'destination' in effect:
				decision_info.destination = effect['destination']

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
				var boost_name = _get_boost_and_card_name(card)
				# Default destination is to discard.
				var destination = "discard"
				if decision_info.destination == "owner_hand":
					destination = "hand"
				if performing_player.is_card_in_continuous_boosts(boost_to_discard_id):
					events += performing_player.remove_from_continuous_boosts(card, destination)
					_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards their boost %s." % boost_name)
				elif opposing_player.is_card_in_continuous_boosts(boost_to_discard_id):
					events += opposing_player.remove_from_continuous_boosts(card, destination)
					_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards %s's boost %s." % [opposing_player.name, boost_name])

				# Do any bonus effect
				if decision_info.effect:
					handle_strike_effect(card_id, decision_info.effect, performing_player)
		"discard_hand":
			events += performing_player.discard_hand()
		"discard_opponent_gauge":
			if opposing_player.gauge.size() > 0:
				# Player gets to pick which gauge to discard.
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_ChooseDiscardOpponentGauge
				decision_info.effect_type = "discard_opponent_gauge_INTERNAL"
				decision_info.choice_card_id = card_id
				decision_info.player = performing_player.my_id
				decision_info.amount = effect['amount2']
				events += [create_event(Enums.EventType.EventType_Boost_DiscardOpponentGauge, performing_player.my_id, 0)]
		"discard_opponent_gauge_INTERNAL":
			var chosen_card_id = effect['card_id']
			var card_name = card_db.get_card_name(chosen_card_id)
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards %s from %s's gauge." % [card_name, opposing_player.name])
			events += opposing_player.discard([chosen_card_id])
		"discard_random":
			var discard_ids = performing_player.pick_random_cards_from_hand(effect['amount'])
			if discard_ids.size() > 0:
				var discarded_names = card_db.get_card_names(discard_ids)
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards random card(s): %s." % discarded_names)
				events += performing_player.discard(discard_ids)
		"discard_random_and_add_triggers":
			var cards_to_discard = performing_player.pick_random_cards_from_hand(1)
			if cards_to_discard.size() > 0:
				events += performing_player.discard(cards_to_discard)
				events += add_attack_triggers(performing_player, cards_to_discard, true)
				var discarded_name = card_db.get_card_name(cards_to_discard[0])
				performing_player.plague_knight_discard_names.append(discarded_name)
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards random card: %s." % discarded_name)
		"exceed_end_of_turn":
			performing_player.exceed_at_end_of_turn = true
		"exceed_now":
			events += performing_player.exceed()
		"extra_trigger_resolutions":
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "'s before/hit/after effects will resolve %s additional time(s)!" % effect['amount'])
			duplicate_attack_triggers(performing_player, effect['amount'])
		"flip_buddy_miss_get_gauge":
			if active_strike.extra_attack_in_progress:
				active_strike.extra_attack_data.extra_attack_always_miss = true
				active_strike.extra_attack_data.extra_attack_always_go_to_gauge = true
			else:
				performing_player.strike_stat_boosts.attack_does_not_hit = true
				performing_player.strike_stat_boosts.always_add_to_gauge = true
			events += handle_strike_effect(
				-1,
				{
					'effect_type': "swap_buddy",
					"buddy_to_remove": effect['buddy_to_remove'],
					"buddy_to_place": effect['buddy_to_place'],
					"description": effect['swap_description']
				},
				opposing_player
			)
			var buddy_name = opposing_player.get_buddy_name(effect['buddy_to_remove'])
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "flips %s, missing %s." % [buddy_name, opposing_player.name])
		"force_costs_reduced_passive":
			performing_player.free_force += effect['amount']
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "now has their force costs reduced by %s!" % performing_player.free_force)
		"remove_force_costs_reduced_passive":
			performing_player.free_force -= effect['amount']
			if performing_player.free_force == 0:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "no longer has their force costs reduced.")
			else:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "now only has their force costs reduced by %s." % performing_player.free_force)
		"gauge_costs_reduced_passive":
			if 'remove' in effect and effect['remove']:
				performing_player.free_gauge -= effect['amount']
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "no longer has their gauge costs reduced.")
			else:
				performing_player.free_gauge += effect['amount']
				var reduction_str = "by %s" % str(effect['amount'])
				if effect['amount'] == 99:
					reduction_str = "to zero"
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "now has their gauge costs reduced %s!" % reduction_str)
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
				decision_info.clear()
				decision_info.player = force_player.my_id
				decision_info.type = Enums.DecisionType.DecisionType_ForceForEffect
				decision_info.choice_card_id = card_id
				decision_info.effect = effect
				events += [create_event(Enums.EventType.EventType_ForceForEffect, force_player.my_id, 0)]
		"gauge_for_effect":
			if active_strike and performing_player.strike_stat_boosts.may_generate_gauge_with_force:
				# Convert this to a force_for_effect instead.
				var changed_effect = {
					"effect_type": "force_for_effect",
					"per_force_effect": effect['per_gauge_effect'],
					"overall_effect": effect['overall_effect'],
					"force_max": effect['gauge_max'],
					"required": 'required' in effect and effect['required'],
				}
				events += handle_strike_effect(card_id, changed_effect, performing_player)
			else:
				var available_gauge = performing_player.get_available_gauge()
				var can_do_something = false
				var bonus_effect = {}
				if effect['per_gauge_effect'] and available_gauge > 0:
					can_do_something = true
				elif effect['overall_effect'] and available_gauge >= effect['gauge_max']:
					can_do_something = true
				if 'bonus_effect' in effect:
					bonus_effect = effect['bonus_effect']
				if can_do_something:
					change_game_state(Enums.GameState.GameState_PlayerDecision)
					decision_info.clear()
					decision_info.player = performing_player.my_id
					decision_info.type = Enums.DecisionType.DecisionType_GaugeForEffect
					decision_info.choice_card_id = card_id
					decision_info.effect = effect
					decision_info.bonus_effect = bonus_effect
					events += [create_event(Enums.EventType.EventType_GaugeForEffect, performing_player.my_id, 0)]
		"gain_advantage":
			next_turn_player = performing_player.my_id
			events += [create_event(Enums.EventType.EventType_Strike_GainAdvantage, performing_player.my_id, 0)]
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "gains Advantage!")
		"gain_life":
			var amount = effect['amount']
			performing_player.life = min(MaxLife, performing_player.life + amount)
			events += [create_event(Enums.EventType.EventType_Strike_GainLife, performing_player.my_id, amount, "", performing_player.life)]
			_append_log_full(Enums.LogType.LogType_Health, performing_player, "gains %s life, bringing them to %s!" % [str(amount), str(performing_player.life)])
		"gauge_from_hand":
			if len(performing_player.hand) > 0:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
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
				decision_info.bonus_effect = {}
				if 'per_card_effect' in effect and effect['per_card_effect']:
					decision_info.bonus_effect = effect['per_card_effect']
				events += [create_event(Enums.EventType.EventType_CardFromHandToGauge_Choice, performing_player.my_id, min_amount, "", max_amount)]
			else:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no cards in hand to put in gauge.")
		"give_to_player":
			performing_player.strike_stat_boosts.move_strike_to_opponent_boosts = true
			events += handle_strike_attack_immediate_removal(performing_player)
		"guardup":
			var amount = effect['amount']
			if str(amount) == "strike_x":
				amount = performing_player.strike_stat_boosts.strike_x
			performing_player.strike_stat_boosts.guard += amount
			events += [create_event(Enums.EventType.EventType_Strike_GuardUp, performing_player.my_id, amount)]
		"higher_speed_misses":
			performing_player.strike_stat_boosts.higher_speed_misses = true
			if 'dodge_at_speed_greater_or_equal' in effect:
				var speed_dodge = effect['dodge_at_speed_greater_or_equal']
				performing_player.strike_stat_boosts.dodge_at_speed_greater_or_equal = speed_dodge
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "will dodge attacks of speed %s or greater!" % speed_dodge)
			else:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "will dodge attacks of a higher speed!")
		"ignore_armor":
			if 'opponent' in effect and effect['opponent']:
				opposing_player.strike_stat_boosts.ignore_armor = true
				_append_log_full(Enums.LogType.LogType_Effect, opposing_player, "gains ignore armor.")
			else:
				performing_player.strike_stat_boosts.ignore_armor = true
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "gains ignore armor.")
		"ignore_guard":
			if 'opponent' in effect and effect['opponent']:
				opposing_player.strike_stat_boosts.ignore_guard = true
				_append_log_full(Enums.LogType.LogType_Effect, opposing_player, "gains ignore guard.")
			else:
				performing_player.strike_stat_boosts.ignore_guard = true
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "gains ignore guard.")
		"ignore_push_and_pull":
			performing_player.strike_stat_boosts.ignore_push_and_pull = true
		"ignore_push_and_pull_passive_bonus":
			performing_player.ignore_push_and_pull += 1
			if performing_player.ignore_push_and_pull == 1:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "cannot be pushed or pulled!")
		"immediate_force_for_armor":
			var offense_player = opposing_player
			var defense_player = performing_player
			if 'opponent' in effect and effect['opponent']:
				offense_player = performing_player
				defense_player = opposing_player
			var incoming_damage = calculate_damage(offense_player, defense_player)

			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.clear()
			decision_info.player = defense_player.my_id
			decision_info.type = Enums.DecisionType.DecisionType_ForceForArmor
			decision_info.choice_card_id = card_id
			decision_info.limitation = "force"
			decision_info.amount = effect['amount']
			events += [create_event(Enums.EventType.EventType_Strike_ForceForArmor, defense_player.my_id, incoming_damage, "", offense_player.strike_stat_boosts.ignore_armor)]
		"increase_draw_effects":
			var amount = effect['amount']
			performing_player.strike_stat_boosts.increase_draw_effects_by += amount
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "'s draw effects are increased by %s!" % amount)
		"increase_force_spent_before_strike":
			performing_player.force_spent_before_strike += 1
		"increase_movement_effects":
			var amount = effect['amount']
			performing_player.strike_stat_boosts.increase_movement_effects_by += amount
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "'s advance and retreat effects are increased by %s!" % amount)
		"increase_move_opponent_effects":
			var amount = effect['amount']
			performing_player.strike_stat_boosts.increase_move_opponent_effects_by += amount
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "'s push and pull effects are increased by %s!" % amount)
		"remove_ignore_push_and_pull_passive_bonus":
			performing_player.ignore_push_and_pull -= 1
			if performing_player.ignore_push_and_pull == 0:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "no longer ignores pushes and pulls.")
		"lose_all_armor":
			if active_strike:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "loses all armor!")
				var remaining_armor = get_total_armor(performing_player)
				performing_player.strike_stat_boosts.armor -= remaining_armor
		"may_advance_bonus_spaces":
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

			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "may %s %s extra space(s)!" % [movement_type, movement_amount])
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.clear()
			decision_info.type = Enums.DecisionType.DecisionType_EffectChoice
			decision_info.player = performing_player.my_id
			decision_info.choice = choice
			decision_info.choice_card_id = card_id
			events += [create_event(Enums.EventType.EventType_Strike_EffectChoice, performing_player.my_id, 0, "EffectOption")]
		"move_to_space":
			var space = effect['amount']
			var remove_buddies_encountered = effect['remove_buddies_encountered']
			var previous_location = performing_player.arena_location
			events += performing_player.move_to(space, false, remove_buddies_encountered)
			_append_log_full(Enums.LogType.LogType_CharacterMovement, performing_player, "moves from space %s to %s." % [str(previous_location), str(performing_player.arena_location)])
		"move_to_any_space":
			decision_info.clear()
			decision_info.type = Enums.DecisionType.DecisionType_ChooseArenaLocationForEffect
			decision_info.player = performing_player.my_id
			decision_info.choice_card_id = card_id
			decision_info.effect_type = "move_to_space"
			decision_info.choice = []
			decision_info.extra_info = ""

			var remove_buddies_encountered = 0
			if 'remove_buddies_encountered' in effect:
				remove_buddies_encountered = effect['remove_buddies_encountered']
				decision_info.extra_info = "Remove the first %s %ss you move onto" % [remove_buddies_encountered, effect['buddy_name']]

			var move_min = 0
			var move_max = 8
			if 'move_min' in effect:
				move_min = effect['move_min']
			if 'move_max' in effect:
				move_max = effect['move_max']

			decision_info.limitation = []
			# If not moving is an option, enable "pass" button
			if move_min == 0:
				decision_info.limitation.append(0)
				decision_info.choice.append({ "effect_type": "pass" })

			var nowhere_to_move = true
			var player_location = performing_player.arena_location
			for i in range(MinArenaLocation, MaxArenaLocation+1):
				if not performing_player.can_move_to(i, true):
					continue
				var movement_distance = performing_player.movement_distance_between(player_location, i)
				if move_min <= movement_distance and movement_distance <= move_max:
					decision_info.limitation.append(i)
					decision_info.choice.append({
						"effect_type": "move_to_space",
						"amount": i,
						"remove_buddies_encountered": remove_buddies_encountered,
					})
					nowhere_to_move = false

			if not nowhere_to_move:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				events += [create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)]
			else:
				_append_log_full(Enums.LogType.LogType_CharacterMovement, performing_player, "has no spaces to move to!")
				events += [create_event(Enums.EventType.EventType_BlockMovement, performing_player.my_id, 0)]
		"name_card_opponent_discards":
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.clear()
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
		"name_range":
			decision_info.clear()
			decision_info.type = Enums.DecisionType.DecisionType_PickNumberFromRange
			decision_info.player = performing_player.my_id
			decision_info.choice_card_id = card_id
			decision_info.choice = []
			decision_info.limitation = []
			if effect['target_effect'] == "opponent_discard_range_or_reveal":
				decision_info.amount_min = 0
				decision_info.amount = 9
				decision_info.valid_zones = ["Range X", "Range N/A (-)"]
				decision_info.effect_type = "have opponent discard a card including that Range or reveal their hand"
				for i in range(decision_info.amount + 1):
					decision_info.limitation.append(i)
					decision_info.choice.append({
						"effect_type": "opponent_discard_range_or_reveal",
						"target_range": i,
						"amount": 1
					})
				var next_num = decision_info.amount + 1
				for i in range(2):
					decision_info.limitation.append(next_num)
					decision_info.choice.append({
						"effect_type": "opponent_discard_range_or_reveal",
						"target_range": decision_info.valid_zones[i],
						"amount": 1
					})

				change_game_state(Enums.GameState.GameState_PlayerDecision)
				events += [create_event(Enums.EventType.EventType_PickNumberFromRange, performing_player.my_id, 0)]
			else:
				assert(false, "Target effect for name_range not found.")
				decision_info.clear()
		"only_hits_if_opponent_on_any_buddy":
			performing_player.strike_stat_boosts.only_hits_if_opponent_on_any_buddy = true
		"opponent_discard_range_or_reveal":
			var target_range = effect['target_range']
			var range_name_str = target_range
			if not target_range is String:
				range_name_str = "Range %s" % target_range
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "names %s." % range_name_str)
			var card_ids_in_range = []
			if target_range is String:
				if target_range == "Range X":
					# If the range is a string like "TOTAL_POWER".
					for card in opposing_player.hand:
						if card.definition['range_min'] is String or card.definition['range_max'] is String:
							card_ids_in_range.append(card.id)
				elif target_range == "Range N/A (-)":
					# If the range is -1 like Block.
					for card in opposing_player.hand:
						var card_range = card.definition['range_min']
						if is_number(card_range) and card_range == -1:
							card_ids_in_range.append(card.id)
				else:
					assert(false, "Unknown target range")
			else:
				# If the range is an actual number.
				for card in opposing_player.hand:
					# Evaluate any special ranges via get_card_stat.
					var card_range_min = get_card_stat(opposing_player, card, 'range_min')
					var card_range_max = get_card_stat(opposing_player, card, 'range_max')
					if is_number(card_range_min) and is_number(card_range_max):
						if target_range >= card_range_min and target_range <= card_range_max:
							card_ids_in_range.append(card.id)
					elif is_number(card_range_min) and target_range == card_range_min:
						card_ids_in_range.append(card.id)
					elif is_number(card_range_max) and target_range == card_range_max:
						card_ids_in_range.append(card.id)
			if card_ids_in_range.size() > 0:
				# Opponent must choose one of these cards to discard.
				var amount = effect['amount']
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_ChooseToDiscard
				decision_info.effect_type = "opponent_discard_choose_internal"
				decision_info.effect = effect
				decision_info.bonus_effect = null
				decision_info.destination = "discard"
				decision_info.limitation = "from_array"
				if target_range is String:
					decision_info.extra_info = "include %s" % target_range
				else:
					decision_info.extra_info = "include Range %s" % target_range
				decision_info.choice = card_ids_in_range
				decision_info.can_pass = false

				decision_info.choice_card_id = card_id
				decision_info.player = opposing_player.my_id
				events += [create_event(Enums.EventType.EventType_Strike_ChooseToDiscard, opposing_player.my_id, amount)]
			else:
				# Didn't have any that matched, so forced to reveal hand.
				_append_log_full(Enums.LogType.LogType_Effect, opposing_player, "has no matching cards so their hand is revealed.")
				events += opposing_player.reveal_hand()
		"remove_buddy_near_opponent":
			ignore_extra_effects = true
			var buddies = []
			var same_space_allowed = effect['same_space_allowed']
			var offset_allowed = effect['offset_allowed']
			var optional = 'optional' in effect and effect['optional']
			if same_space_allowed:
				buddies += performing_player.get_buddies_on_opponent()
			if offset_allowed == 1:
				buddies += performing_player.get_buddies_adjacent_opponent()

			if buddies.size() > 0:
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_ChooseArenaLocationForEffect
				decision_info.player = performing_player.my_id
				decision_info.choice_card_id = card_id
				decision_info.effect_type = "remove_buddy_near_opponent"
				decision_info.choice = []
				decision_info.limitation = []
				decision_info.source = effect['buddy_name']
				var and_effect = null
				var and_with_bonus = null
				if 'and' in effect:
					and_effect = effect['and']
					and_with_bonus = and_effect
				if 'if_removed_effect' in effect:
					var additional_and_effect = and_effect
					and_with_bonus = effect['if_removed_effect']
					and_with_bonus['and'] = additional_and_effect
				if optional:
					decision_info.limitation.append(0)
					decision_info.choice.append({
						"effect_type": "pass",
						"and": and_effect
					})
				for buddy_id in buddies:
					decision_info.limitation.append(performing_player.get_buddy_location(buddy_id))
					decision_info.choice.append({
						"effect_type": "remove_buddy",
						"buddy_id": buddy_id,
						"and": and_with_bonus
					})
				if decision_info.limitation.size() > 1:
					# There are multiple choices, so player must choose.
					change_game_state(Enums.GameState.GameState_PlayerDecision)
					events += [create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)]
				else:
					# Just do it immediately.
					events += handle_strike_effect(card_id, decision_info.choice[0], performing_player)
		"remove_X_buddies":
			ignore_extra_effects = true
			if 'reset_strike_x' in effect and effect['reset_strike_x']:
				performing_player.strike_stat_boosts.strike_x = 0
			var buddies = performing_player.get_buddies_in_play()
			if buddies.size() > 0:
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_ChooseArenaLocationForEffect
				decision_info.player = performing_player.my_id
				decision_info.choice_card_id = card_id
				decision_info.effect_type = "remove_buddy_near_opponent"
				decision_info.choice = []
				decision_info.limitation = []
				decision_info.source = effect['buddy_name']
				var and_effect = null
				if 'and' in effect:
					and_effect = effect['and']
				# Add optional pass.
				decision_info.limitation.append(0)
				decision_info.choice.append({
					"effect_type": "pass",
					"and": and_effect
				})
				if buddies.size() == 1:
					# This is the last iteration, so do not include the remove_X_buddies recursive effect.
					pass
				else:
					var additional_and = and_effect
					and_effect = {
						"effect_type": "remove_X_buddies",
						"buddy_name": "Ice Spike",
						"and": additional_and
					}
				for buddy_id in buddies:
					decision_info.limitation.append(performing_player.get_buddy_location(buddy_id))
					decision_info.choice.append({
						"effect_type": "remove_buddy",
						"increase_strike_x": 1,
						"buddy_id": buddy_id,
						"and": and_effect
					})
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				events += [create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)]
		"reveal_copy_for_advantage":
			var copy_id = effect['copy_id']
			# The player has selected to reveal a copy if they have one.
			# Otherwise, do nothing.
			var copy_card_id = performing_player.get_copy_in_hand(copy_id)
			if copy_card_id != -1:
				var card_name = card_db.get_card_name(copy_card_id)
				next_turn_player = performing_player.my_id
				performing_player.reveal_card_ids([copy_card_id])
				events += [create_event(Enums.EventType.EventType_RevealCard, performing_player.my_id, copy_card_id)]
				events += [create_event(Enums.EventType.EventType_Strike_GainAdvantage, performing_player.my_id, 0)]
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "reveals a copy of %s in their hand." % card_name)
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "gains Advantage!")
		"reveal_hand":
			if 'opponent' in effect and effect['opponent']:
				events += opposing_player.reveal_hand()
			else:
				events += performing_player.reveal_hand()
		"reveal_hand_and_topdeck":
			if 'opponent' in effect and effect['opponent']:
				events += opposing_player.reveal_hand_and_topdeck()
			else:
				events += performing_player.reveal_hand_and_topdeck()
		"reveal_topdeck":
			if 'opponent' in effect and effect['opponent']:
				events += opposing_player.reveal_topdeck()
			else:
				var reveal_to_both = false
				if 'reveal_to_both' in effect and effect['reveal_to_both']:
					reveal_to_both = true
				events += performing_player.reveal_topdeck(reveal_to_both)
		"reveal_strike":
			if performing_player == active_strike.initiator:
				active_strike.initiator_set_face_up = true
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "initiates with a face-up attack!")
				var card_name = card_db.get_card_name(active_strike.initiator_card.id)
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "is striking with %s." % card_name)
			else:
				active_strike.defender_set_face_up = true
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "responds with a face-up attack!")
				var card_name = card_db.get_card_name(active_strike.defender_card.id)
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "is striking with %s." % card_name)
			events += [create_event(Enums.EventType.EventType_RevealStrike_OnePlayer, performing_player.my_id, 0)]
		"may_generate_gauge_with_force":
			performing_player.strike_stat_boosts.may_generate_gauge_with_force = true
		"may_invalidate_ultras":
			performing_player.strike_stat_boosts.may_invalidate_ultras = true
		"move_buddy":
			var buddy_id = ""
			if 'buddy_id' in effect:
				buddy_id = effect['buddy_id']
			decision_info.clear()
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
				var distance = abs(performing_player.get_buddy_location() - i)
				if distance >= min_spaces and distance <= max_spaces:
					decision_info.limitation.append(i)
					var location_choice = {
						"effect_type": "place_buddy_into_space",
						"buddy_id": buddy_id,
						"amount": i
					}
					if 'strike_after' in effect and effect['strike_after']:
						location_choice["and"] = {
							"effect_type": "strike"
						}
					decision_info.choice.append(location_choice)
			if decision_info.limitation.size() > 1 or (not optional and decision_info.limitation.size() > 0):
				decision_info.type = Enums.DecisionType.DecisionType_ChooseArenaLocationForEffect
				decision_info.player = performing_player.my_id
				decision_info.choice_card_id = card_id
				decision_info.effect_type = "place_buddy_into_space"
				decision_info.source = effect['buddy_name']
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				events += [create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)]
		"move_to_buddy":
			var buddy_id = ""
			if 'buddy_id' in effect:
				buddy_id = effect['buddy_id']
			var buddy_name = performing_player.get_buddy_name(buddy_id)
			var buddy_location = performing_player.get_buddy_location(buddy_id)
			var previous_location = performing_player.arena_location
			events += performing_player.move_to(buddy_location)
			_append_log_full(Enums.LogType.LogType_CharacterMovement, performing_player, "moves to %s, from space %s to %s." % [buddy_name, str(previous_location), str(performing_player.arena_location)])
		"multiply_power_bonuses":
			performing_player.strike_stat_boosts.power_bonus_multiplier = max(effect['amount'], performing_player.strike_stat_boosts.power_bonus_multiplier)
		"multiply_positive_power_bonuses":
			performing_player.strike_stat_boosts.power_bonus_multiplier_positive_only = max(effect['amount'], performing_player.strike_stat_boosts.power_bonus_multiplier_positive_only)
		"multiply_speed_bonuses":
			performing_player.strike_stat_boosts.speed_bonus_multiplier = max(effect['amount'], performing_player.strike_stat_boosts.speed_bonus_multiplier)
		"nonlethal_attack":
			performing_player.strike_stat_boosts.deal_nonlethal_damage = true
		"opponent_cant_move_if_in_range":
			opposing_player.strike_stat_boosts.cannot_move_if_in_opponents_range = true
			_append_log_full(Enums.LogType.LogType_Effect, opposing_player, "is prevented from moving while in %s's range." % performing_player.name)
		"opponent_cant_move_past":
			opposing_player.cannot_move_past_opponent = true
			events += [create_event(Enums.EventType.EventType_Strike_OpponentCantMovePast, performing_player.my_id, 0)]
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "cannot be advanced through!")
		"opponent_cant_move_past_buddy":
			var buddy_id = ""
			if 'buddy_id' in effect:
				buddy_id = effect['buddy_id']
			else:
				buddy_id = performing_player.buddy_id_to_index.keys()[0]
			var buddy_name = performing_player.get_buddy_name(buddy_id)

			opposing_player.cannot_move_past_opponent_buddy_id = buddy_id
			events += [create_event(Enums.EventType.EventType_Strike_OpponentCantMovePast, performing_player.my_id, 0, "", buddy_name)]
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "'s %s cannot be advanced through!" % buddy_name)
		"remove_opponent_cant_move_past":
			opposing_player.cannot_move_past_opponent = false
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "is no longer blocking opponent movement.")
		"remove_opponent_cant_move_past_buddy":
			var buddy_id = ""
			if 'buddy_id' in effect:
				buddy_id = effect['buddy_id']
			else:
				buddy_id = performing_player.buddy_id_to_index.keys()[0]
			var buddy_name = performing_player.get_buddy_name(buddy_id)

			opposing_player.cannot_move_past_opponent_buddy_id = null
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "'s %s is no longer blocking opponent movement." % buddy_name)
		"return_attack_to_top_of_deck":
			if active_strike.extra_attack_in_progress:
				var extra_card = active_strike.extra_attack_data.extra_attack_card
				var extra_card_name = extra_card.definition['display_name']

				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "returns their attack %s to the top of their deck." % extra_card_name)
				events += performing_player.add_to_top_of_deck(extra_card, true)
				active_strike.cards_in_play.erase(extra_card) #???
			else:
				performing_player.strike_stat_boosts.attack_to_topdeck_on_cleanup = true
				events += handle_strike_attack_immediate_removal(performing_player)
		"return_all_copies_of_top_discard_to_hand":
			events += performing_player.return_all_copies_of_top_discard_to_hand()
		"nothing":
			# Do nothing.
			pass
		"opponent_discard_choose":
			if opposing_player.hand.size() > effect['amount']:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
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
				var card_names = card_db.get_card_names(card_ids)
				_append_log_full(Enums.LogType.LogType_CardInfo, opposing_player, "has card(s) discarded by %s: %s." % [performing_player.name, card_names])
				events += opposing_player.discard(card_ids)
		"opponent_discard_choose_internal":
			var cards = effect['card_ids']
			var card_names = card_db.get_card_names(cards)
			_append_log_full(Enums.LogType.LogType_CardInfo, opposing_player, "has %s choose cards to discard: %s." % [performing_player.name, card_names])
			events += performing_player.discard(cards)
		"opponent_discard_hand":
			var num_discarded = opposing_player.hand.size()
			events += opposing_player.discard_hand()
			if 'save_num_discarded_as_strike_x' in effect and effect['save_num_discarded_as_strike_x']:
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "'s X for this strike is set to the number of discarded cards, %s." % num_discarded)
				events += performing_player.set_strike_x(num_discarded)
		"opponent_discard_random":
			var discard_ids = opposing_player.pick_random_cards_from_hand(effect['amount'])
			if discard_ids.size() > 0:
				var discarded_names = card_db.get_card_names(discard_ids)
				if 'destination' in effect and effect['destination'] == "overdrive":
					_append_log_full(Enums.LogType.LogType_CardInfo, opposing_player, "discards random card(s) to opponent's overdrive: %s." % discarded_names)
					events += opposing_player.discard(discard_ids)
					events += performing_player.move_cards_to_overdrive(discard_ids, "opponent_discard")
				else:
					_append_log_full(Enums.LogType.LogType_CardInfo, opposing_player, "discards random card(s): %s." % discarded_names)
					events += opposing_player.discard(discard_ids)
		"pass":
			# Do nothing.
			pass
		"place_boost_in_space":
			var in_attack_range = 'in_attack_range' in effect and effect['in_attack_range']

			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.clear()
			decision_info.type = Enums.DecisionType.DecisionType_ChooseArenaLocationForEffect
			decision_info.player = performing_player.my_id
			decision_info.choice_card_id = card_id
			decision_info.effect_type = "place_boost_in_space"
			var boost_name = card_db.get_card(card_id).definition['boost']['display_name']
			decision_info.source = boost_name
			decision_info.choice = []
			decision_info.limitation = []
			var and_effect = null
			if 'and' in effect:
				and_effect = effect['and']
			if 'optional' in effect and effect['optional']:
				decision_info.limitation.append(0)
				decision_info.choice.append({
					"effect_type": "pass"
				})
			for i in range(MinArenaLocation, MaxArenaLocation + 1):
				if in_attack_range and not is_location_in_range(performing_player, active_strike.get_player_card(performing_player), i):
					continue

				decision_info.limitation.append(i)
				decision_info.choice.append({
					"effect_type": "place_boost_in_space_internal",
					"card_id": card_id,
					"location": i,
					"and": and_effect
				})
			events += [create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)]
		"place_boost_in_space_internal":
			var location = effect['location']
			var placed_card_id = effect['card_id']
			events += performing_player.add_boost_to_location(placed_card_id, location)
		"lightningrod_strike":
			var lightning_card_id = effect['card_id']
			var location = effect['location']
			var card_name = effect['card_name']

			# Remove lightning rod and put the card back in hand.
			var lightning_card = performing_player.remove_lightning_card(lightning_card_id, location)
			events += performing_player.add_to_hand(lightning_card, true)
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds Lightning Rod %s to their hand." % card_name)
			events += [create_event(Enums.EventType.EventType_PlaceLightningRod, performing_player.my_id, lightning_card_id, "", location, false)]

			# Deal the damage
			var damage_effect = {
				"effect_type": "take_damage",
				"opponent": true,
				"nonlethal": true,
				"amount": 2
			}
			events += handle_strike_effect(lightning_card_id, damage_effect, performing_player)
		"move_to_lightningrods":
			var valid_locations = []
			for i in range(MinArenaLocation, MaxArenaLocation + 1):
				var lightningzone = performing_player.get_lightningrod_zone_for_location(i)
				if len(lightningzone) > 0:
					if performing_player.can_move_to(i, true):
						if i not in valid_locations:
							valid_locations.append(i)
					elif opposing_player.is_in_location(i):
						# If the opponent is on a lightning rod, you can treat this like Close.
						var direction = 1
						if performing_player.arena_location < opposing_player.arena_location:
							direction = -1

						# Include the next available space closest to the opponent.
						# Loop from i towards the player.
						for test_location in range(i, performing_player.arena_location, direction):
							if performing_player.can_move_to(test_location, true):
								if test_location not in valid_locations:
									valid_locations.append(test_location)
									break

			if len(valid_locations) > 0:
				# Let the player choose where to go.
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_ChooseArenaLocationForEffect
				decision_info.player = performing_player.my_id
				decision_info.choice_card_id = card_id
				decision_info.effect_type = "move_to_space"
				decision_info.choice = []
				decision_info.limitation = []
				decision_info.extra_info = ""

				for location in valid_locations:
					decision_info.limitation.append(location)
					decision_info.choice.append({
						"effect_type": "move_to_space",
						"amount": location,
						"remove_buddies_encountered": false,
					})

				change_game_state(Enums.GameState.GameState_PlayerDecision)
				events += [create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)]
			else:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no lightning rods to move to!")
		"place_lightningrod":
			var source = effect['source']
			var limitation = effect['limitation']
			var lightning_card
			var valid_locations = []

			match limitation:
				"any":
					for i in range(MinArenaLocation, MaxArenaLocation + 1):
						valid_locations.append(i)
				"attack_range":
					assert(active_strike, "No active strike for lightningrod attack_range.")
					var attack_card = active_strike.get_player_card(performing_player)
					for i in range(MinArenaLocation, MaxArenaLocation + 1):
						if is_location_in_range(performing_player, attack_card, i):
							valid_locations.append(i)
				_:
					assert(false, "Unknown lightningrod limitation.")

			# Make sure not to handle the attack card before the range check above,
			# because discarding the attack card here will force the range check
			# to fail as the attack is no longer valid.
			match source:
				"top_discard":
					lightning_card = performing_player.get_top_discard_card()
				"this_attack_card":
					lightning_card = active_strike.get_player_card(performing_player)
					# If this is the current attack, get rid of it now, putting it on top the discard pile.
					# This is convenient since now lightning rods always come from the top discard card.
					performing_player.strike_stat_boosts.discard_attack_now_for_lightningrod = true
					events += handle_strike_attack_immediate_removal(performing_player)
				_:
					assert(false, "Unknown lightningrod source.")

			if lightning_card and valid_locations:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_ChooseArenaLocationForEffect
				decision_info.player = performing_player.my_id
				decision_info.choice_card_id = card_id
				decision_info.effect_type = "place_lightningrod"
				decision_info.choice = []
				decision_info.limitation = []
				for i in valid_locations:
					decision_info.limitation.append(i)
					decision_info.choice.append({
						"effect_type": "place_lightningrod_internal",
						"location": i,
					})
				events += [create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)]
		"place_lightningrod_internal":
			var location = effect['location']
			events += performing_player.place_top_discard_as_lightningrod(location)
		"place_buddy_at_range":
			events += handle_place_buddy_at_range(performing_player, card_id, effect)
		"place_buddy_into_space":
			var space = effect['amount']
			var buddy_id = ""
			if 'buddy_id' in effect:
				buddy_id = effect['buddy_id']
			var old_buddy_pos = performing_player.get_buddy_location(buddy_id)
			events += performing_player.place_buddy(space, buddy_id)

			var buddy_name = performing_player.get_buddy_name(buddy_id)
			if old_buddy_pos == -1:
				_append_log_full(Enums.LogType.LogType_CharacterMovement, performing_player, "moves %s to space %s." % [buddy_name, str(space)])
			else:
				_append_log_full(Enums.LogType.LogType_CharacterMovement, performing_player, "moves %s from space %s to %s." % [buddy_name, str(old_buddy_pos), str(space)])

			if 'place_other_buddy_effect' in effect:
				events += handle_place_buddy_at_range(performing_player, card_id, effect['place_other_buddy_effect'])
		"place_buddy_in_any_space":
			var buddy_id = ""
			if 'buddy_id' in effect:
				buddy_id = effect['buddy_id']
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.clear()
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
				var new_choice = {
					"effect_type": "place_buddy_into_space",
					"buddy_id": buddy_id,
					"amount": i
				}
				if 'additional_effect' in effect:
					new_choice['and'] = effect['additional_effect']
				decision_info.choice.append(new_choice)
			events += [create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)]
		"place_buddy_in_attack_range":
			var buddy_id = ""
			if 'buddy_id' in effect:
				buddy_id = effect['buddy_id']
			decision_info.clear()
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
					var new_choice = {
						"effect_type": "place_buddy_into_space",
						"buddy_id": buddy_id,
						"amount": i
					}
					if 'additional_effect' in effect:
						new_choice['and'] = effect['additional_effect']
					decision_info.choice.append(new_choice)
			if decision_info.limitation.size() > 1 or (not optional and decision_info.limitation.size() > 0):
				decision_info.type = Enums.DecisionType.DecisionType_ChooseArenaLocationForEffect
				decision_info.player = performing_player.my_id
				decision_info.choice_card_id = card_id
				decision_info.effect_type = "place_buddy_into_space"
				decision_info.source = effect['buddy_name']
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				events += [create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)]
		"place_buddy_onto_opponent":
			var buddy_id = ""
			if 'buddy_id' in effect:
				buddy_id = effect['buddy_id']
			var old_buddy_pos = performing_player.get_buddy_location(buddy_id)
			var buddy_name = performing_player.get_buddy_name(buddy_id)
			events += performing_player.place_buddy(opposing_player.arena_location, buddy_id)
			var space = performing_player.get_buddy_location(buddy_id)
			if old_buddy_pos == -1:
				_append_log_full(Enums.LogType.LogType_CharacterMovement, performing_player, "moves %s to %s on space %s." % [buddy_name, opposing_player.name, str(space)])
			else:
				_append_log_full(Enums.LogType.LogType_CharacterMovement, performing_player, "moves %s to %s, from space %s to %s." % [buddy_name, opposing_player.name, str(old_buddy_pos), str(space)])
		"place_buddy_onto_self":
			var buddy_id = ""
			if 'buddy_id' in effect:
				buddy_id = effect['buddy_id']
			var old_buddy_pos = performing_player.get_buddy_location(buddy_id)
			var buddy_name = performing_player.get_buddy_name(buddy_id)
			events += performing_player.place_buddy(performing_player.arena_location, buddy_id)
			var space = performing_player.get_buddy_location(buddy_id)
			if old_buddy_pos == -1:
				_append_log_full(Enums.LogType.LogType_CharacterMovement, performing_player, "moves %s to themselves on space %s." % [buddy_name, str(space)])
			else:
				_append_log_full(Enums.LogType.LogType_CharacterMovement, performing_player, "moves %s to themselves, from space %s to %s." % [buddy_name, str(old_buddy_pos), str(space)])
		"place_next_buddy":
			var require_unoccupied = effect['require_unoccupied']
			var destination = effect['destination']
			var num_buddies = effect['amount']
			var valid_new_positions = [1,2,3,4,5,6,7,8,9]
			var already_removed_buddy = 'already_removed_buddy' in effect and effect['already_removed_buddy']
			if already_removed_buddy:
				valid_new_positions = effect['valid_new_positions']
			else:
				# Filter based on destination requirements.
				match destination:
					"attack_range":
						var attack_card = active_strike.get_player_card(performing_player)
						for i in range(valid_new_positions.size() - 1, -1, -1):
							var check_position = valid_new_positions[i]
							if not is_location_in_range(performing_player, attack_card, check_position):
								valid_new_positions.remove_at(i)
					"anywhere":
						pass
					"adjacent_self":
						for i in range(valid_new_positions.size() - 1, -1, -1):
							var check_position = valid_new_positions[i]
							if not (check_position == performing_player.arena_location - 1 or check_position == performing_player.arena_location + 1):
								valid_new_positions.remove_at(i)
					"self":
						for i in range(valid_new_positions.size() - 1, -1, -1):
							var check_position = valid_new_positions[i]
							if not performing_player.is_in_location(check_position):
								valid_new_positions.remove_at(i)
					_:
						assert(false, "Unknown destination for place_next_buddy")

				# Filter based on requiring no players in those spaces.
				if require_unoccupied:
					for i in range(valid_new_positions.size() - 1, -1, -1):
						var check_position = valid_new_positions[i]
						if performing_player.is_in_location(check_position) or opposing_player.is_in_location(check_position):
							valid_new_positions.remove_at(i)
				# Filter out any location that already has your buddy.
				for i in range(valid_new_positions.size() - 1, -1, -1):
					var check_position = valid_new_positions[i]
					if check_position in performing_player.buddy_locations:
						valid_new_positions.remove_at(i)

			if valid_new_positions.size() > 0:
				var must_select_other_buddy_first = performing_player.are_all_buddies_in_play()
				# The player can now select one of these new spaces to place their buddy,
				# or they can select and existing buddy and remove it first.
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_ChooseArenaLocationForEffect
				decision_info.player = performing_player.my_id
				decision_info.choice_card_id = card_id
				decision_info.effect_type = "place_next_buddy"
				decision_info.source = effect['buddy_name']
				decision_info.choice = []
				decision_info.limitation = []
				decision_info.extra_info = must_select_other_buddy_first
				var and_effect = null
				if 'and' in effect:
					and_effect = effect['and']
				if num_buddies > 1:
					# Placing multiple buddies, so turn the and effect into a copy of this effect.
					and_effect = {
						"effect_type": "place_next_buddy",
						"buddy_name": effect['buddy_name'],
						"amount": num_buddies - 1,
						"destination": destination,
						"require_unoccupied": require_unoccupied,
						"and": and_effect
					}
				for i in range(MinArenaLocation, MaxArenaLocation + 1):
					if not must_select_other_buddy_first and i in valid_new_positions:
						# The player elects to place the next available buddy here.
						decision_info.limitation.append(i)
						decision_info.choice.append({
							"effect_type": "place_buddy_into_space",
							"buddy_id": performing_player.get_next_free_buddy_id(),
							"amount": i,
							"and": and_effect
						})
					elif not already_removed_buddy and i in performing_player.buddy_locations:
						# The player elects to remove this buddy first.
						decision_info.limitation.append(i)
						decision_info.choice.append({
							"effect_type": "remove_buddy",
							"buddy_id": performing_player.get_buddy_id_at_location(i),
							"and": {
								"effect_type": "place_next_buddy",
								"buddy_name": effect['buddy_name'],
								"amount": -1, # Additional already in the and effect.
								"already_removed_buddy": true,
								"require_unoccupied": require_unoccupied,
								"destination": destination,
								"valid_new_positions": valid_new_positions,
								"and": and_effect
							}
						})
				if decision_info.choice.size() == 1:
					# Only one choice, so just do it immediately.
					events += handle_strike_effect(card_id, decision_info.choice[0], performing_player)
				else:
					change_game_state(Enums.GameState.GameState_PlayerDecision)
					events += [create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)]
			else:
				# No valid positions to put the buddy, so skip this.
				# The and effect will occur normally if one exists.
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no valid locations to place %s." % effect['buddy_name'])
		"move_any_buddy":
			var move_to_opponent = 'to_opponent' in effect and effect['to_opponent']
			var move_min = effect['amount_min']
			var move_max = effect['amount_max']
			var optional = (move_min == 0)
			var must_select_other_buddy_first = true
			decision_info.clear()
			decision_info.type = Enums.DecisionType.DecisionType_ChooseArenaLocationForEffect
			decision_info.player = performing_player.my_id
			decision_info.choice_card_id = card_id
			decision_info.effect_type = "place_next_buddy"
			decision_info.source = effect['buddy_name']
			decision_info.choice = []
			decision_info.limitation = []
			decision_info.extra_info = must_select_other_buddy_first
			if optional:
				decision_info.limitation.append(0)
				decision_info.choice.append({
					"effect_type": "pass"
				})
			# First, the player has to select a buddy to remove.
			# Then, they have to place it in a valid space.
			for location in performing_player.buddy_locations:
				if location == -1:
					continue
				var buddy_id = performing_player.get_buddy_id_at_location(location)
				var valid_new_positions = []
				for i in range(MinArenaLocation, MaxArenaLocation + 1):
					if performing_player.get_buddy_id_at_location(i) != "":
						# Skip if there is already a buddy here, including self.
						continue
					if move_to_opponent and opposing_player.is_in_location(i):
						valid_new_positions.append(i)
					else:
						# Add this space if it is within the amount from the starting buddy location.
						if abs(location - i) >= move_min and abs(location - i) <= move_max:
							valid_new_positions.append(i)

				if valid_new_positions.size() > 0:
					decision_info.limitation.append(location)
					decision_info.choice.append({
						"effect_type": "remove_buddy",
						"buddy_id": buddy_id,
						"and": {
							"effect_type": "place_next_buddy",
							"buddy_name": effect['buddy_name'],
							"amount": -1,
							"already_removed_buddy": true,
							"require_unoccupied": false,
							"destination": "",
							"valid_new_positions": valid_new_positions
						}
					})
			var actual_choices = len(decision_info.limitation)
			if optional:
				actual_choices -= 1

			# If the only option is to pass, just let this pass.
			if actual_choices > 0:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				events += [create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)]
			else:
				assert(false, "Unexpected called move_any_buddy but can't.")
		"play_attack_from_hand":
			# Implement the choice via discard effect.
			var discard_effect = {
				"effect_type": "self_discard_choose",
				"optional": true,
				"amount": 1,
				"limitation": "can_pay_cost",
				"destination": "play_attack",
			}
			events += handle_strike_effect(card_id, discard_effect, performing_player)
		"power_modify_per_buddy_between":
			performing_player.strike_stat_boosts.power_modify_per_buddy_between += effect['amount']
		"powerup":
			var amount = effect['amount']
			if str(amount) == "strike_x":
				amount = performing_player.strike_stat_boosts.strike_x
			elif str(amount) == "DISCARDED_COUNT":
				amount = performing_player.discards.size()
			var multiplier = 1
			if 'multiplier' in effect:
				multiplier = effect['multiplier']
			amount = amount * multiplier
			performing_player.add_power_bonus(amount)
			events += [create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, amount)]
		"powerup_both_players":
			var amount = effect['amount']
			performing_player.add_power_bonus(amount)
			opposing_player.add_power_bonus(amount)
			events += [create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, amount)]
			events += [create_event(Enums.EventType.EventType_Strike_PowerUp, opposing_player.my_id, amount)]
		"powerup_per_armor_used":
			var armor_consumed = performing_player.strike_stat_boosts.consumed_armor
			var power_change = armor_consumed * effect['amount']
			performing_player.add_power_bonus(power_change)
			events += [create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, power_change)]
		"powerup_per_boost_in_play":
			var boosts_in_play = performing_player.continuous_boosts.size()
			if boosts_in_play > 0:
				var amount = effect['amount'] * boosts_in_play
				performing_player.add_power_bonus(amount)
				events += [create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, effect['amount'] * boosts_in_play)]
		"powerup_per_sealed_normal":
			var sealed_normals = performing_player.get_sealed_count_of_type("normal")
			if sealed_normals > 0:
				var bonus_power = effect['amount'] * sealed_normals
				if 'maximum' in effect:
					bonus_power = min(bonus_power, effect['maximum'])
				performing_player.add_power_bonus(bonus_power)
				events += [create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, bonus_power)]
		"powerup_damagetaken":
			var power_per_damage = effect['amount']
			var damage_taken = active_strike.get_damage_taken(performing_player)
			var total_powerup = power_per_damage * damage_taken
			# Checking for negative damage taken so that powerup is in expected "direction"
			if total_powerup != 0 and damage_taken > 0:
				performing_player.add_power_bonus(total_powerup)
				events += [create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, total_powerup)]
		"powerup_opponent":
			opposing_player.add_power_bonus(effect['amount'])
			events += [create_event(Enums.EventType.EventType_Strike_PowerUp, opposing_player.my_id, effect['amount'])]
		"pull":
			var previous_location = opposing_player.arena_location
			var amount = effect['amount']
			amount += performing_player.strike_stat_boosts.increase_move_opponent_effects_by

			events += performing_player.pull(amount)
			var new_location = opposing_player.arena_location
			if (other_start < performing_start and new_location > performing_start) or (other_start > performing_start and new_location < performing_start):
				local_conditions.pulled_past = true
			_append_log_full(Enums.LogType.LogType_CharacterMovement, opposing_player, "is pulled %s, moving from space %s to %s." % [str(amount), str(previous_location), str(new_location)])
		"pull_any_number_of_spaces_and_gain_power":
			decision_info.clear()
			decision_info.type = Enums.DecisionType.DecisionType_ChooseArenaLocationForEffect
			decision_info.player = performing_player.my_id
			decision_info.choice_card_id = card_id
			decision_info.effect_type = "pull_to_space_and_gain_power"
			decision_info.choice = []
			decision_info.extra_info = ""
			decision_info.limitation = []

			decision_info.limitation.append(0)
			decision_info.choice.append({ "effect_type": "pass" })

			var player_location = performing_player.arena_location
			var opponent_location = opposing_player.arena_location
			var nowhere_to_pull = true
			for i in range(MinArenaLocation, MaxArenaLocation+1):
				if opposing_player.is_overlapping_opponent(i):
					continue
				if opponent_location == i:
					continue
				if player_location < opponent_location and i > opponent_location:
					continue
				if player_location > opponent_location and i < opponent_location:
					continue
				decision_info.limitation.append(i)
				decision_info.choice.append({
					"effect_type": "pull_to_space_and_gain_power",
					"amount": i
				})
				nowhere_to_pull = false

			if not nowhere_to_pull:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				events += [create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)]
		"pull_to_space_and_gain_power":
			var space = effect['amount']
			var previous_location = opposing_player.arena_location
			var distance = opposing_player.movement_distance_between(space, previous_location)
			if space == previous_location:
				# This effect should only be called with an actual attempt to pull.
				assert(false)
			elif space < previous_location and performing_player.arena_location < previous_location \
			or space > previous_location and performing_player.arena_location > previous_location:
				events += performing_player.pull(distance)
				var new_location = opposing_player.arena_location
				var pull_amount = opposing_player.movement_distance_between(previous_location, new_location)
				if (other_start < performing_start and new_location > performing_start) or (other_start > performing_start and new_location < performing_start):
					local_conditions.pulled_past = true
				performing_player.add_power_bonus(pull_amount)
				events += [create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, pull_amount)]
				_append_log_full(Enums.LogType.LogType_CharacterMovement, opposing_player, "is pulled %s, moving from space %s to %s." % [str(distance), str(previous_location), str(new_location)])
			else:
				# This effect should not be called with a push.
				assert(false)
		"pull_not_past":
			var previous_location = opposing_player.arena_location
			events += performing_player.pull_not_past(effect['amount'])
			var new_location = opposing_player.arena_location
			_append_log_full(Enums.LogType.LogType_CharacterMovement, opposing_player, "is pulled %s without going past %s, moving from space %s to %s." % [str(effect['amount']), performing_player.name, str(previous_location), str(new_location)])
		"pull_to_buddy":
			var amount = effect['amount']
			var buddy_id = ""
			if 'buddy_id' in effect:
				buddy_id = effect['buddy_id']
			var buddy_location = performing_player.get_buddy_location(buddy_id)
			var previous_location = opposing_player.arena_location
			if buddy_location == previous_location:
				# Choice since opponent is on buddy.
				var choice_effect = {
					"effect_type": "choice",
					"choice": [
						{ "effect_type": "push", "amount": amount },
						{ "effect_type": "pull", "amount": amount }
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
				if buddy_location < previous_location:
					# Buddy to the left of opponent. Move to the left.
					if performing_player.arena_location < previous_location:
						# Player to the left of opponent. Pull to move left,
						# otherwise push.
						events += performing_player.pull(amount)
					else:
						events += performing_player.push(amount)
				else:
					# Buddy to the right of opponent. Move to the right.
					if performing_player.arena_location < previous_location:
						# Player to the left of opponent. Push to move opponent right,
						# otherwise, pull.
						events += performing_player.push(amount)
					else:
						events += performing_player.pull(amount)
				var new_location = opposing_player.arena_location
				var buddy_name = performing_player.get_buddy_name(buddy_id)
				_append_log_full(Enums.LogType.LogType_CharacterMovement, opposing_player, "is pulled %s towards %s, moving from space %s to %s." % [str(effect['amount']), buddy_name, str(previous_location), str(new_location)])
		"push":
			var set_x_to_buddy_spaces_entered = 'save_buddy_spaces_entered_as_strike_x' in effect and effect['save_buddy_spaces_entered_as_strike_x']
			var previous_location = opposing_player.arena_location
			var amount = effect['amount']
			amount += performing_player.strike_stat_boosts.increase_move_opponent_effects_by

			events += performing_player.push(amount, set_x_to_buddy_spaces_entered)
			var new_location = opposing_player.arena_location
			var push_amount = abs(other_start - new_location)
			local_conditions.push_amount = push_amount
			local_conditions.fully_pushed = push_amount == amount
			_append_log_full(Enums.LogType.LogType_CharacterMovement, opposing_player, "is pushed %s, moving from space %s to %s." % [str(amount), str(previous_location), str(new_location)])
		"push_from_source":
			var attack_source_location = get_attack_origin(performing_player, opposing_player.arena_location)
			if opposing_player.is_in_location(attack_source_location):
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
				var previous_location = opposing_player.arena_location
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
				var push_amount = opposing_player.movement_distance_between(other_start, new_location)
				local_conditions.push_amount = push_amount
				local_conditions.fully_pushed = push_amount == effect['amount']
				_append_log_full(Enums.LogType.LogType_CharacterMovement, opposing_player, "is pushed %s from the attack source at %s, moving from space %s to %s." % [str(effect['amount']), str(attack_source_location), str(previous_location), str(new_location)])
		"push_or_pull_to_any_space":
			decision_info.clear()
			decision_info.type = Enums.DecisionType.DecisionType_ChooseArenaLocationForEffect
			decision_info.player = performing_player.my_id
			decision_info.choice_card_id = card_id
			decision_info.effect_type = "push_or_pull_to_space"
			decision_info.choice = []
			decision_info.extra_info = ""
			decision_info.limitation = []

			decision_info.limitation.append(0)
			decision_info.choice.append({ "effect_type": "pass" })

			var opponent_location = opposing_player.arena_location
			for i in range(MinArenaLocation, MaxArenaLocation+1):
				if opposing_player.is_overlapping_opponent(i):
					continue
				if opponent_location == i:
					continue
				decision_info.limitation.append(i)
				decision_info.choice.append({
					"effect_type": "push_or_pull_to_space",
					"amount": i
				})

			change_game_state(Enums.GameState.GameState_PlayerDecision)
			events += [create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)]
		"push_or_pull_to_space":
			var space = effect['amount']
			var previous_location = opposing_player.arena_location
			var distance = opposing_player.movement_distance_between(space, previous_location)
			# Convert this to a regular push or pull.
			if space == previous_location:
				# This effect should only be called with an actual attempt to push or pull.
				assert(false)
			elif space < previous_location and performing_player.arena_location < previous_location \
			or space > previous_location and performing_player.arena_location > previous_location:
				events += performing_player.pull(distance)
				var new_location = opposing_player.arena_location
				if (other_start < performing_start and new_location > performing_start) or (other_start > performing_start and new_location < performing_start):
					local_conditions.pulled_past = true
				_append_log_full(Enums.LogType.LogType_CharacterMovement, opposing_player, "is pulled %s, moving from space %s to %s." % [str(distance), str(previous_location), str(new_location)])
			else:
				events += performing_player.push(distance)
				var new_location = opposing_player.arena_location
				var push_amount = opposing_player.movement_distance_between(previous_location, new_location)
				local_conditions.push_amount = push_amount
				local_conditions.fully_pushed = push_amount == effect['amount']
				_append_log_full(Enums.LogType.LogType_CharacterMovement, opposing_player, "is pushed %s, moving from space %s to %s." % [str(distance), str(previous_location), str(new_location)])
		"push_to_attack_max_range":
			var attack_max_range = get_total_max_range(performing_player)
			var furthest_location
			var previous_location = opposing_player.arena_location
			var origin = performing_player.get_closest_occupied_space_to(previous_location)
			if performing_player.arena_location < opposing_player.arena_location:
				furthest_location = max(origin + attack_max_range, MinArenaLocation)
			else:
				furthest_location = min(origin - attack_max_range, MaxArenaLocation)
			var push_needed = abs(furthest_location - opposing_player.get_closest_occupied_space_to(performing_player.arena_location))
			events += performing_player.push(push_needed)
			var new_location = opposing_player.arena_location
			_append_log_full(Enums.LogType.LogType_CharacterMovement, opposing_player, "is pushed to the attack's max range %s, moving from space %s to %s." % [str(attack_max_range), str(previous_location), str(new_location)])
		"range_includes_if_moved_past":
			performing_player.strike_stat_boosts.range_includes_if_moved_past = true
		"range_includes_lightningrods":
			performing_player.strike_stat_boosts.range_includes_lightningrods = true
		"rangeup":
			performing_player.strike_stat_boosts.min_range += effect['amount']
			performing_player.strike_stat_boosts.max_range += effect['amount2']
			events += [create_event(Enums.EventType.EventType_Strike_RangeUp, performing_player.my_id, effect['amount'], "", effect['amount2'])]
		"rangeup_both_players":
			performing_player.strike_stat_boosts.min_range += effect['amount']
			performing_player.strike_stat_boosts.max_range += effect['amount2']
			events += [create_event(Enums.EventType.EventType_Strike_RangeUp, performing_player.my_id, effect['amount'], "", effect['amount2'])]
			opposing_player.strike_stat_boosts.min_range += effect['amount']
			opposing_player.strike_stat_boosts.max_range += effect['amount2']
			events += [create_event(Enums.EventType.EventType_Strike_RangeUp, opposing_player.my_id, effect['amount'], "", effect['amount2'])]
		"rangeup_per_boost_in_play":
			var boosts_in_play = performing_player.continuous_boosts.size()
			if 'all_boosts' in effect and effect['all_boosts']:
				boosts_in_play += opposing_player.continuous_boosts.size()
			if boosts_in_play > 0:
				performing_player.strike_stat_boosts.min_range += effect['amount'] * boosts_in_play
				performing_player.strike_stat_boosts.max_range += effect['amount2'] * boosts_in_play
				events += [create_event(Enums.EventType.EventType_Strike_RangeUp, performing_player.my_id, effect['amount'] * boosts_in_play, "", effect['amount2'] * boosts_in_play)]
		"rangeup_per_sealed_normal":
			var sealed_normals = performing_player.get_sealed_count_of_type("normal")
			if sealed_normals > 0:
				performing_player.strike_stat_boosts.min_range += effect['amount'] * sealed_normals
				performing_player.strike_stat_boosts.max_range += effect['amount2'] * sealed_normals
				events += [create_event(Enums.EventType.EventType_Strike_RangeUp, performing_player.my_id, effect['amount'] * sealed_normals, "", effect['amount2'] * sealed_normals)]
		"reading_normal":
			# Cannot do Reading during a strike.
			if not active_strike:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
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
			if 'increase_strike_x' in effect:
				performing_player.strike_stat_boosts.strike_x += effect['increase_strike_x']
			var buddy_id = ""
			if 'buddy_id' in effect:
				buddy_id = effect['buddy_id']
			var buddy_was_in_play = performing_player.is_buddy_in_play(buddy_id)
			var buddy_name = performing_player.get_buddy_name(buddy_id)
			var silent = 'silent' in effect and effect['silent']
			if not silent:
				_append_log_full(Enums.LogType.LogType_CharacterMovement, performing_player, "removes %s from the arena." % buddy_name)
			events += performing_player.remove_buddy(buddy_id, silent)
			if buddy_was_in_play and active_strike:
				# Handle character effects like Litchi where removing buddy mid-strike
				# Can have an effect on the stats.
				var char_effects = performing_player.get_character_effects_at_timing("during_strike")
				for char_effect in char_effects:
					if char_effect['condition'] == "not_buddy_in_play":
						events += do_effect_if_condition_met(performing_player, -1, char_effect, null)
					elif char_effect['condition'] == "buddy_in_play":
						# Not implemented - if someone has an effect that needs to go away, do that here.
						assert(false)
		"do_not_remove_buddy":
			performing_player.do_not_cleanup_buddy_this_turn = true
		"calculate_range_from_buddy":
			performing_player.strike_stat_boosts.calculate_range_from_buddy = true
			performing_player.strike_stat_boosts.calculate_range_from_buddy_id = ""
			if 'buddy_id' in effect:
				performing_player.strike_stat_boosts.calculate_range_from_buddy_id = effect['buddy_id']
		"calculate_range_from_center":
			performing_player.strike_stat_boosts.calculate_range_from_center = true
		"reshuffle_discard_into_deck":
			events += performing_player.reshuffle_discard(false, true)
		"retreat":
			var amount = effect['amount']
			if str(amount) == "strike_x":
				amount = performing_player.strike_stat_boosts.strike_x
			amount += performing_player.strike_stat_boosts.increase_movement_effects_by

			var previous_location = performing_player.arena_location
			events += performing_player.retreat(amount)
			var new_location = performing_player.arena_location
			var retreat_amount = abs(performing_start - new_location)
			local_conditions.fully_retreated = retreat_amount == amount
			_append_log_full(Enums.LogType.LogType_CharacterMovement, performing_player, "retreats %s, moving from space %s to %s." % [str(amount), str(previous_location), str(new_location)])
		"repeat_effect_optionally":
			if active_strike:
				var amount = effect['amount']
				var first_not_automatic = 'first_not_automatic' in effect and effect['first_not_automatic']
				if str(amount) == "every_two_sealed_normals":
					var sealed_normals = performing_player.get_sealed_count_of_type("normal")
					amount = int(sealed_normals / 2)
				elif str(amount) == "strike_x":
					amount = performing_player.strike_stat_boosts.strike_x

				var linked_effect = effect['linked_effect']
				if amount > 0:
					var repeat_effect = {
						"card_id": card_id,
						"effect_type": "choice",
						"choice": [
							{
								"effect_type": "repeat_effect_optionally",
								"amount": amount-1,
								"linked_effect": linked_effect
							},
							{ "effect_type": "pass" }
						]
					}
					add_remaining_effect(repeat_effect)
				if not first_not_automatic:
					events += handle_strike_effect(card_id, linked_effect, performing_player)
		"reset_character_positions":
			events += performing_player.move_to(performing_player.starting_location, true)
			events += opposing_player.move_to(opposing_player.starting_location, true)
			_append_log_full(Enums.LogType.LogType_CharacterMovement, null, "Both players return to their starting positions!")
		"return_all_cards_gauge_to_hand":
			var card_names = ""
			for card in performing_player.gauge:
				card_names += card_db.get_card_name(card.id) + ", "
			if card_names:
				card_names = card_names.substr(0, card_names.length() - 2)
			events += performing_player.return_all_cards_gauge_to_hand()
		"return_attack_to_hand":
			performing_player.strike_stat_boosts.return_attack_to_hand = true
			events += handle_strike_attack_immediate_removal(performing_player)
		"return_sealed_with_same_speed":
			var sealed_card_id = decision_info.amount
			var sealed_card = card_db.get_card(sealed_card_id)
			var target_card = null
			for card in performing_player.sealed:
				if card.definition['speed'] == sealed_card.definition['speed']:
					target_card = card
					break
			if target_card:
				var card_name = target_card.definition["display_name"]
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds the sealed card with speed %s to their hand: %s." % [sealed_card.definition['speed'], card_name])
				events += performing_player.move_card_from_sealed_to_hand(target_card.id)
		"return_this_boost_to_hand_strike_effect":
			var card_name = card_db.get_card_name(card_id)
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "returns boosted card %s to their hand." % card_name)
			var card = card_db.get_card(card_id)
			events += performing_player.remove_from_continuous_boosts(card, "hand")
		"return_this_to_hand_immediate_boost":
			var card_name = card_db.get_card_name(card_id)
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "returns boosted card %s to their hand." % card_name)
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
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "sets their attack's printed power to %s!" % performing_player.saved_power)
		"use_top_discard_as_printed_power":
			if len(performing_player.discards) > 0:
				var card = performing_player.get_top_discard_card()
				var power = max(get_card_stat(performing_player, card, 'power'), 0)
				performing_player.strike_stat_boosts.overwritten_printed_power = power
				var card_name = card_db.get_card_name(card.id)
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "sets their attack's printed power to the power of %s on top of discards, %s!" % [card_name, power])
			else:
				performing_player.strike_stat_boosts.overwritten_printed_power = 0
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no discards, their attack's printed power is set to 0.")
			performing_player.strike_stat_boosts.overwrite_printed_power = true
		"seal_attack_on_cleanup":
			performing_player.strike_stat_boosts.seal_attack_on_cleanup = true
		"seal_card_INTERNAL":
			decision_info.amount = effect['seal_card_id']
			var effects = performing_player.get_character_effects_at_timing("on_seal")
			for sub_effect in effects:
				events += do_effect_if_condition_met(performing_player, -1, sub_effect, null)

			# note that this doesn't support effects causing decisions
			var seal_effect = effect.duplicate()
			seal_effect['effect_type'] = "seal_card_complete_INTERNAL"
			seal_effect['silent'] = false
			if 'silent' in effect:
				seal_effect['silent'] = effect['silent']
			events += handle_strike_effect(card_id, seal_effect, performing_player)
			# and/bonus_effect should be handled by internal version
			ignore_extra_effects = true
		"seal_card_complete_INTERNAL":
			var card = card_db.get_card(effect['seal_card_id'])
			var silent = effect['silent']
			if effect['source']:
				events += performing_player.seal_from_location(card.id, effect['source'], silent)
			else:
				events += performing_player.add_to_sealed(card, silent)
		"seal_this":
			if active_boost:
				# Part of a boost.
				active_boost.seal_on_cleanup = true
			else:
				# Part of an attack.
				performing_player.strike_stat_boosts.seal_attack_on_cleanup = true
		"seal_this_boost":
			var card = card_db.get_card(card_id)
			var card_name = card_db.get_card_name(card.id)
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "seals the boosted card %s." % card_name)
			events += performing_player.remove_from_continuous_boosts(card, "sealed")
			events += opposing_player.remove_from_continuous_boosts(card, "sealed")
		"seal_topdeck":
			events += performing_player.seal_topdeck()
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
				decision_info.clear()
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
					if destination == "discard":
						events += performing_player.discard_hand()
					elif destination == "sealed":
						events += performing_player.seal_hand()
				elif cards_available.size() == 0:
					if destination == "reveal" and 'and' in effect and effect['and']['effect_type'] == "save_power":
						_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no cards in hand to reveal.")
						performing_player.saved_power = 0
		"set_dan_draw_choice":
			performing_player.dan_draw_choice = true
		"set_dan_draw_choice_INTERNAL":
			performing_player.dan_draw_choice_from_bottom = effect['from_bottom']
		"set_end_of_turn_boost_delay":
			performing_player.set_end_of_turn_boost_delay(card_id)
		"set_strike_x":
			var extra_info = []
			if 'extra_info' in effect:
				extra_info = effect['extra_info']
			events += do_set_strike_x(performing_player, effect['source'], extra_info)
		"set_total_power":
			performing_player.strike_stat_boosts.overwrite_total_power = true
			performing_player.strike_stat_boosts.overwritten_total_power = effect['amount']
		"set_used_character_bonus":
			performing_player.used_character_bonus = true
		"self_discard_choose_internal":
			var card_ids = effect['card_ids']
			var card_names = card_db.get_card_names(card_ids)
			if effect['destination'] == "discard":
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards the chosen card(s): %s." % card_names)
				events += performing_player.discard(card_ids)
			elif effect['destination'] == "sealed":
				if performing_player.sealed_area_is_secret:
					_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "seals %s card(s) face-down." % str(len(card_ids)))
				else:
					_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "seals the chosen card(s): %s." % card_names)
				for seal_card_id in card_ids:
					events += do_seal_effect(performing_player, seal_card_id, "hand")
			elif effect['destination'] == "reveal":
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "reveals the chosen card(s): %s." % card_names)
				performing_player.reveal_card_ids(card_ids)
				for revealed_card_id in card_ids:
					events += [create_event(Enums.EventType.EventType_RevealCard, performing_player.my_id, revealed_card_id)]
				if 'and' in effect and effect['and']['effect_type'] == "save_power":
					# Specifically get the printed power.
					var card_power = card_db.get_card(card_ids[0]).definition['power']
					effect['and']['amount'] = card_power
			elif effect['destination'] == "opponent_overdrive":
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards the chosen card(s) to opponent's overdrive: %s." % card_names)
				events += performing_player.discard(card_ids)
				events += opposing_player.move_cards_to_overdrive(card_ids, "opponent_discard")
			elif effect['destination'] == "play_attack":
				# Can do 0 to pass.
				if card_ids.size() == 1:
					# Intentional events = because events are passed in.
					events = begin_extra_attack(events, performing_player, card_ids[0])
			else:
				# Nothing else implemented.
				assert(false)
		"set_life_per_gauge":
			var gauge = len(performing_player.gauge)
			var amount_per_gauge = effect['amount']
			var maximum = MaxLife
			if 'maximum' in effect:
				maximum = effect['maximum']
			var amount = gauge * amount_per_gauge
			amount = min(maximum, amount)
			performing_player.life = amount
			events += [create_event(Enums.EventType.EventType_Strike_GainLife, performing_player.my_id, amount, "", performing_player.life)]
			_append_log_full(Enums.LogType.LogType_Health, performing_player, "gains %s life, bringing them to %s!" % [str(amount), str(performing_player.life)])
		"shuffle_deck":
			performing_player.random_shuffle_deck()
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "shuffled their deck.")
			events += [create_event(Enums.EventType.EventType_ReshuffleDeck, performing_player.my_id, 0)]
		"shuffle_discard_in_place":
			performing_player.random_shuffle_discard_in_place()
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "shuffled their discard pile.")
			events += [create_event(Enums.EventType.EventType_ReshuffleDiscardInPlace, performing_player.my_id, 0)]
		"shuffle_into_deck_from_hand":
			if len(performing_player.hand) > 0:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_CardFromHandToGauge
				decision_info.player = performing_player.my_id
				decision_info.choice_card_id = card_id
				decision_info.destination = "deck"
				var min_amount = effect['min_amount']
				var max_amount = effect['max_amount']
				decision_info.effect = {
					"min_amount": min_amount,
					"max_amount": max_amount,
				}
				events += [create_event(Enums.EventType.EventType_CardFromHandToGauge_Choice, performing_player.my_id, min_amount, "", max_amount)]
		"shuffle_hand_to_deck":
			events += performing_player.shuffle_hand_to_deck()
		"shuffle_sealed_to_deck":
			var card_names = ""
			for card in performing_player.sealed:
				card_names += card_db.get_card_name(card.id) + ", "
			if card_names:
				card_names = card_names.substr(0, card_names.length() - 2)
			events += performing_player.shuffle_sealed_to_deck()
		"sidestep_transparent_foe":
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.clear()
			decision_info.type = Enums.DecisionType.DecisionType_Sidestep
			decision_info.effect_type = "sidestep_internal"
			decision_info.choice_card_id = card_id
			decision_info.player = performing_player.my_id
			events += [create_event(Enums.EventType.EventType_Boost_Sidestep, performing_player.my_id, 0)]
		"sidestep_dialogue":
			# this exists purely for ui, no-op here
			pass
		"sidestep_internal":
			var named_card = card_db.get_card(effect['card_id'])
			# named_card is the individual card but
			# this should match "by name", so instead of using that
			# match card.definition['id']'s instead.
			opposing_player.cards_that_will_not_hit.append(named_card.definition['id'])
		"skip_end_of_turn_draw":
			performing_player.skip_end_of_turn_draw = true
		"specials_invalid":
			performing_player.specials_invalid = effect['enabled']
		"specific_card_discard_to_hand":
			var card_name = effect['card_name']
			var copy_id = effect['copy_id']
			var return_effect = null
			if 'return_effect' in effect:
				return_effect = effect['return_effect']

			var copy_card_id = performing_player.get_copy_in_discards(copy_id)
			if copy_card_id != -1:
				events += performing_player.move_card_from_discard_to_hand(copy_card_id)
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "moves a copy of %s from discard to hand." % card_name)
				if return_effect:
					events += do_effect_if_condition_met(performing_player, card_id, return_effect, null)
			else:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no copies of %s in discard." % card_name)
		"specific_card_seal_from_gauge":
			var card_name = effect['card_name']
			var copy_id = effect['copy_id']
			var seal_effect = null
			if 'seal_effect' in effect:
				seal_effect = effect['seal_effect']

			var copy_card_id = performing_player.get_copy_in_gauge(copy_id)
			if copy_card_id != -1:
				events += performing_player.move_card_from_gauge_to_sealed(copy_card_id)
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "seals a copy of %s from gauge." % card_name)
				if seal_effect:
					events += do_effect_if_condition_met(performing_player, card_id, seal_effect, null)
			else:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no copies of %s in gauge." % card_name)
		"speedup":
			performing_player.strike_stat_boosts.speed += effect['amount']
			events += [create_event(Enums.EventType.EventType_Strike_SpeedUp, performing_player.my_id, effect['amount'])]
		"speedup_amount_in_gauge":
			var amount = performing_player.gauge.size()
			performing_player.strike_stat_boosts.speed += amount
			events += [create_event(Enums.EventType.EventType_Strike_SpeedUp, performing_player.my_id, amount)]
		"speedup_per_boost_in_play":
			var boosts_in_play = performing_player.continuous_boosts.size()
			if 'all_boosts' in effect and effect['all_boosts']:
				boosts_in_play += opposing_player.continuous_boosts.size()
			if boosts_in_play > 0:
				performing_player.strike_stat_boosts.speed += effect['amount'] * boosts_in_play
				events += [create_event(Enums.EventType.EventType_Strike_SpeedUp, performing_player.my_id, effect['amount'] * boosts_in_play)]
		"spend_all_force_and_save_amount":
			var force_amount = performing_player.get_available_force()
			var card_names = ""
			if performing_player.hand.size() > 0:
				card_names = ": " + performing_player.hand[0].definition['display_name']
				for i in range(1, len(performing_player.hand)):
					card_names += ", " + performing_player.hand[i].definition['display_name']
			if performing_player.gauge.size() > 0:
				if card_names == "":
					card_names += ": "
				else:
					card_names += ", "
				card_names += performing_player.gauge[0].definition['display_name']
				for i in range(1, len(performing_player.gauge)):
					card_names += ", " + performing_player.gauge[i].definition['display_name']
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "spends all cards in hand and gauge to generate %s force%s." % [force_amount, card_names])
			events += performing_player.discard_hand()
			events += performing_player.discard_gauge()
			performing_player.force_spent_before_strike = force_amount
		"spend_all_gauge_and_save_amount":
			var gauge_amount = performing_player.get_available_gauge()
			var card_names = ""
			if performing_player.gauge.size() > 0:
				card_names = ": " + performing_player.gauge[0].definition['display_name']
				for i in range(1, len(performing_player.gauge)):
					card_names += ", " + performing_player.gauge[i].definition['display_name']
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards all %s card(s) from their gauge%s." % [gauge_amount, card_names])
			events += performing_player.discard_gauge()
			performing_player.gauge_spent_before_strike = gauge_amount
		"spend_life":
			var amount = effect['amount']
			performing_player.life -= amount
			events += [create_event(Enums.EventType.EventType_Strike_TookDamage, performing_player.my_id, amount, "spend", performing_player.life)]
			_append_log_full(Enums.LogType.LogType_Health, performing_player, "spends %s life, bringing them to %s!" % [str(amount), str(performing_player.life)])
			if performing_player.life <= 0:
				_append_log_full(Enums.LogType.LogType_Default, performing_player, "has no life remaining!")
				events += on_death(performing_player)
		"start_of_turn_strike":
			performing_player.start_of_turn_strike = true
			performing_player.effect_on_turn_start = { "effect_type": "strike" }
		"strike":
			# Cannot strike during a strike.
			if not active_strike:
				change_game_state(Enums.GameState.GameState_WaitForStrike)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
				decision_info.player = performing_player.my_id
				if active_boost:
					# Don't send the event now, we're processing a boost.
					# That has code to set flags on the active_boost to strike after the boost.
					# There could be more effects before the strike occurs, so wait on the event until then
					# and we don't want to send it twice.
					pass
				else:
					events += [create_event(Enums.EventType.EventType_ForceStartStrike, performing_player.my_id, 0)]
		"strike_effect_after_setting":
			if not active_boost:
				events += [create_event(Enums.EventType.EventType_ForceStartStrike, performing_player.my_id, 0)]
			change_game_state(Enums.GameState.GameState_WaitForStrike)
			decision_info.clear()
			decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
			decision_info.player = performing_player.my_id
			performing_player.extra_effect_after_set_strike = effect['after_set_effect']
		"strike_effect_after_opponent_sets":
			if not active_boost:
				events += [create_event(Enums.EventType.EventType_ForceStartStrike, performing_player.my_id, 0)]
			change_game_state(Enums.GameState.GameState_WaitForStrike)
			decision_info.clear()
			decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
			decision_info.player = performing_player.my_id
			opposing_player.extra_effect_after_set_strike = effect['after_set_effect']
		"strike_faceup":
			var disable_wild_swing = 'disable_wild_swing' in effect and effect['disable_wild_swing']
			var disable_ex = 'disable_ex' in effect and effect['disable_ex']
			if not active_boost:
				events += [create_event(Enums.EventType.EventType_ForceStartStrike, performing_player.my_id, 0, "", disable_wild_swing, disable_ex)]
			change_game_state(Enums.GameState.GameState_WaitForStrike)
			decision_info.clear()
			decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
			decision_info.player = performing_player.my_id
			performing_player.next_strike_faceup = true
		"strike_from_gauge":
			decision_info.clear()
			decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
			decision_info.player = performing_player.my_id
			decision_info.source = "gauge"
			if len(performing_player.gauge) > 0:
				if not active_boost: # Boosts will send strikes on their own
					events += [create_event(Enums.EventType.EventType_Strike_FromGauge, performing_player.my_id, 0)]
				change_game_state(Enums.GameState.GameState_WaitForStrike)
				performing_player.next_strike_faceup = true
				performing_player.next_strike_from_gauge = true
			else:
				change_game_state(Enums.GameState.GameState_WaitForStrike)
				var strike_info = {
					"card_id": -1,
					"wild_swing": true,
					"ex_card_id": -1
				}
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no gauge to strike with.")
				if not active_boost: # Boosts will send strikes on their own
					events += [create_event(Enums.EventType.EventType_Strike_EffectDoStrike, performing_player.my_id, 0, "", strike_info)]
		"strike_from_sealed":
			decision_info.clear()
			decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
			decision_info.player = performing_player.my_id
			decision_info.source = "sealed"
			if len(performing_player.sealed) > 0:
				change_game_state(Enums.GameState.GameState_WaitForStrike)
				performing_player.next_strike_faceup = not performing_player.sealed_area_is_secret
				performing_player.next_strike_from_sealed = true
				if not active_boost: # Boosts will send strikes on their own
					events += [create_event(Enums.EventType.EventType_Strike_FromGauge, performing_player.my_id, 0)]
			else:
				change_game_state(Enums.GameState.GameState_WaitForStrike)
				var strike_info = {
					"card_id": -1,
					"wild_swing": true,
					"ex_card_id": -1
				}
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no sealed cards to strike with.")
				if not active_boost: # Boosts will send strikes on their own
					events += [create_event(Enums.EventType.EventType_Strike_EffectDoStrike, performing_player.my_id, 0, "", strike_info)]
		"strike_opponent_sets_first":
			events += [create_event(Enums.EventType.EventType_Strike_OpponentSetsFirst, performing_player.my_id, 0)]
			change_game_state(Enums.GameState.GameState_Strike_Opponent_Set_First)
			decision_info.clear()
			decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
			decision_info.player = performing_player.my_id
		"strike_random_from_gauge":
			events += [create_event(Enums.EventType.EventType_Strike_OpponentSetsFirst, performing_player.my_id, 0)]
			change_game_state(Enums.GameState.GameState_Strike_Opponent_Set_First)
			decision_info.clear()
			decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
			decision_info.player = performing_player.my_id
			performing_player.next_strike_random_gauge = true
		"strike_response_reading":
			var card = effect['card_id']
			var ex_card = -1
			if 'ex_card_id' in effect:
				ex_card = effect['ex_card_id']
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has the named card!")
			change_game_state(Enums.GameState.GameState_Strike_Opponent_Response)
			var strike_info = {
				"card_id": card,
				"wild_swing": false,
				"ex_card_id": ex_card
			}
			events += [create_event(Enums.EventType.EventType_Strike_EffectDoStrike, performing_player.my_id, 0, "", strike_info)]
		"strike_with_deus_ex_machina":
			change_game_state(Enums.GameState.GameState_AutoStrike)
			decision_info.clear()
			decision_info.effect_type = "happychaos_deusexmachina"
		"strike_wild":
			change_game_state(Enums.GameState.GameState_WaitForStrike)
			var strike_info = {
				"card_id": -1,
				"wild_swing": true,
				"ex_card_id": -1
			}
			events += [create_event(Enums.EventType.EventType_Strike_EffectDoStrike, performing_player.my_id, 0, "", strike_info)]
		"stun_immunity":
			performing_player.strike_stat_boosts.stun_immunity = true
		"sustain_all_boosts":
			for boost in performing_player.continuous_boosts:
				if boost.id not in performing_player.sustained_boosts:
					performing_player.sustained_boosts.append(boost.id)
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "sustains all continuous boosts.")
			events += [create_event(Enums.EventType.EventType_SustainBoost, performing_player.my_id, -1)]
		"sustain_this":
			performing_player.sustained_boosts.append(card_id)
			var card = card_db.get_card(card_id)
			var boost_name = _get_boost_and_card_name(card)
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "sustains their continuous boost %s." % boost_name)
			events += [create_event(Enums.EventType.EventType_SustainBoost, performing_player.my_id, card_id)]
		"swap_buddy":
			var buddy_id_to_remove = effect['buddy_to_remove']
			var buddy_id_to_place = effect['buddy_to_place']
			events += performing_player.swap_buddy(buddy_id_to_remove, buddy_id_to_place, effect['description'])
		"swap_deck_and_sealed":
			events += performing_player.swap_deck_and_sealed()
		"switch_spaces_with_buddy":
			var old_space = performing_player.arena_location
			var old_buddy_space = performing_player.get_buddy_location()
			events += performing_player.move_to(old_buddy_space)
			events += performing_player.place_buddy(old_space)
			_append_log_full(Enums.LogType.LogType_CharacterMovement, performing_player, "moves from space %s to %s." % [str(old_space), str(performing_player.arena_location)])
			_append_log_full(Enums.LogType.LogType_CharacterMovement, performing_player, "moves %s from space %s to %s." % [performing_player.get_buddy_name(), str(old_buddy_space), str(performing_player.get_buddy_location())])
		"take_bonus_actions":
			var silent = false
			if 'silent' in effect:
				silent = effect['silent']

			# Cannot take bonus actions during a strike.
			if not active_strike:
				var num = effect['amount']
				performing_player.bonus_actions += num
				performing_player.cancel_blocked_this_turn = true
				performing_player.strike_action_disabled = false
				if 'disable_strike_action' in effect and effect['disable_strike_action']:
					performing_player.strike_action_disabled = true
				if not silent:
					_append_log_full(Enums.LogType.LogType_Effect, performing_player, "gains %s bonus actions!" % str(num))
		"take_damage":
			var nonlethal = 'nonlethal' in effect and effect['nonlethal']
			var damaged_player = performing_player
			if 'opponent' in effect and effect['opponent']:
				damaged_player = opposing_player
			var damage = effect['amount']
			var damage_prevention = 0
			if active_strike:
				damage_prevention = get_total_armor(damaged_player)
			var unmitigated_damage = max(0, damage - damage_prevention)
			var used_armor = damage - unmitigated_damage
			if active_strike:
				damaged_player.strike_stat_boosts.consumed_armor += used_armor
			if nonlethal and unmitigated_damage >= damaged_player.life:
				unmitigated_damage = damaged_player.life - 1
			damaged_player.life -= unmitigated_damage
			events += [create_event(Enums.EventType.EventType_Strike_TookDamage, damaged_player.my_id, unmitigated_damage, "", damaged_player.life)]
			if used_armor > 0:
				_append_log_full(Enums.LogType.LogType_Health, damaged_player, "takes %s non-lethal damage (%s blocked by armor), bringing them to %s life!" % [str(unmitigated_damage), str(used_armor), str(damaged_player.life)])
			else:
				_append_log_full(Enums.LogType.LogType_Health, damaged_player, "takes %s non-lethal damage, bringing them to %s life!" % [str(unmitigated_damage), str(damaged_player.life)])
			if active_strike:
				active_strike.add_damage_taken(damaged_player, unmitigated_damage)
				events += check_for_stun(damaged_player, false)
			if damaged_player.life < 0:
				events += trigger_game_over(damaged_player.my_id, Enums.GameOverReason.GameOverReason_Life)
		"topdeck_from_hand":
			if len(performing_player.hand) > 0:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
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
			if 'use_gauge_instead' in effect and effect['use_gauge_instead']:
				# Ignore if already using Block's force version.
				if performing_player.strike_stat_boosts.when_hit_force_for_armor != "force":
					performing_player.strike_stat_boosts.when_hit_force_for_armor = "gauge"
			else:
				performing_player.strike_stat_boosts.when_hit_force_for_armor = "force"
		"zero_vector":
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.clear()
			decision_info.type = Enums.DecisionType.DecisionType_ZeroVector
			decision_info.effect_type = "zero_vector_internal"
			decision_info.choice_card_id = card_id
			decision_info.bonus_effect = true
			decision_info.player = performing_player.my_id
			events += [create_event(Enums.EventType.EventType_Boost_ZeroVector, performing_player.my_id, 0)]
		"zero_vector_internal":
			var named_card = card_db.get_card(effect['card_id'])
			# named_card is the individual card but
			# this should match "by name", so instead of using that
			# match on the display name, because Dive hits all Dives but Dust doesn't hit Spike.
			performing_player.cards_invalid_during_strike.append(named_card.definition['display_name'])
			opposing_player.cards_invalid_during_strike.append(named_card.definition['display_name'])
		"zero_vector_dialogue":
			# this exists purely for ui, no-op here
			pass
		_:
			assert(false, "ERROR: Unhandled effect type: %s" % effect['effect_type'])

	if not ignore_extra_effects:
		if "and" in effect and effect['and']:
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

func change_stats_when_attack_leaves_play(performing_player : Player):
	# Set total power and speed to invalid (0).
	# Set range to invalid - NOTE! If a buddy character can remove attacks, check all buddy range check functions.
	# Lose printed armor/guard values but keep boosts/powerups.
	# Lose focus ignore push/pull.
	# Lose block when_hit_force_for_armor
	var card = active_strike.get_player_card(performing_player)

	# Invalid stats.
	performing_player.strike_stat_boosts.overwrite_total_power = true
	performing_player.strike_stat_boosts.overwritten_total_power = 0
	performing_player.strike_stat_boosts.overwrite_total_speed = true
	performing_player.strike_stat_boosts.overwritten_total_speed = 0
	performing_player.strike_stat_boosts.overwrite_range_to_invalid = true

	# Remove printed stats by subtracting from bonuses.
	performing_player.strike_stat_boosts.armor -= get_card_stat(performing_player, card, "armor")
	performing_player.strike_stat_boosts.guard -= get_card_stat(performing_player, card, "guard")

	# Assumption! No character that currently has attacks returning to play can gain
	# the focus or block passives twice from a boost and a card somehow.
	# You would also lose ignore armor/guard but that shouldn't matter.
	performing_player.strike_stat_boosts.ignore_push_and_pull = false
	performing_player.strike_stat_boosts.when_hit_force_for_armor = ""

	# This currently assumes that this would always from the played attack
	performing_player.strike_stat_boosts.higher_speed_misses = false

	# If a character that can do this has Cleanup effects on the strike,
	# this needs to be added here somehow as well.

func handle_place_buddy_at_range(performing_player : Player, card_id, effect):
	var events = []
	# The player can place on either side within min/max range.
	var range_min = effect['range_min']
	var range_max = effect['range_max']
	decision_info.choice = []
	decision_info.limitation = []
	for i in range(MinArenaLocation, MaxArenaLocation + 1):
		var range_origin = performing_player.get_closest_occupied_space_to(i)
		var distance = abs(range_origin - i)
		if distance >= range_min and distance <= range_max:
			decision_info.limitation.append(i)
			var buddy_id = ""
			if 'buddy_id' in effect:
				buddy_id = effect['buddy_id']
			var choice = {
				"effect_type": "place_buddy_into_space",
				"buddy_id": buddy_id,
				"amount": i
			}
			if 'then_place_other_buddy' in effect and effect['then_place_other_buddy']:
				var other_buddy_id = ""
				if 'other_buddy_id' in effect:
					other_buddy_id = effect['other_buddy_id']
				choice['place_other_buddy_effect'] = {
					"effect_type": "place_buddy_at_range",
					"buddy_id": other_buddy_id,
					"buddy_name": effect['other_buddy_name'],
					"range_min": range_min,
					"range_max": range_max
				}
			decision_info.choice.append(choice)
	if decision_info.limitation.size() > 0:
		decision_info.type = Enums.DecisionType.DecisionType_ChooseArenaLocationForEffect
		decision_info.player = performing_player.my_id
		decision_info.choice_card_id = card_id
		decision_info.effect_type = "place_buddy_into_space"
		decision_info.source = effect['buddy_name']
		change_game_state(Enums.GameState.GameState_PlayerDecision)
		events += [create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)]

	return events

func do_seal_effect(performing_player : Player, card_id : int, source : String, silent : bool = false):
	var events = []
	var seal_effect = {
		"effect_type": "seal_card_INTERNAL",
		"seal_card_id": card_id,
		"source": source,
		"silent": silent
	}
	events += handle_strike_effect(-1, seal_effect, performing_player)
	return events

func handle_player_draw_or_discard_to_effect(performing_player : Player, card_id, effect):
	var events = []
	var target_hand_size = effect['amount']
	var hand_size = performing_player.hand.size()
	if hand_size < target_hand_size:
		var amount_to_draw = target_hand_size - hand_size
		events += performing_player.draw(amount_to_draw)
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "draws %s card(s) to reach a hand size of %s." % [amount_to_draw, target_hand_size])
	elif hand_size > target_hand_size:
		var amount_to_discard = hand_size - target_hand_size
		var discard_effect = {
			"effect_type": "self_discard_choose",
			"amount": amount_to_discard
		}
		_append_log_full(Enums.LogType.LogType_Effect, performing_player, "must discard %s card(s) to reach a hand size of %s." % [amount_to_discard, target_hand_size])
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
		value = get_total_power(check_player, card)
	elif str(value) == "RANGE_TO_OPPONENT":
		value = check_player.distance_to_opponent()
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
	var events = []
	for card_id in card_ids:
		var card = card_db.get_card(card_id)
		var card_name = card_db.get_card_name(card.id)
		_append_log_full(Enums.LogType.LogType_Effect, performing_player, "will add the before/hit/after effects of %s to their attack!" % card_name)
		for timing in ["before", "hit", "after"]:
			for card_effect in card_db.get_card_effects_at_timing(card, timing):
				var added_effect = {
					"effect_type": "add_attack_effect",
					"added_effect": card_effect.duplicate()
				}

				if set_character_effect:
					added_effect['character_effect'] = true
				events += handle_strike_effect(-1, added_effect, performing_player)
	return events

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

func get_all_effects_for_timing(timing_name : String, performing_player : Player, card : GameCard, ignore_condition : bool = true, only_card_and_bonus_effects : bool = false) -> Array:
	var card_effects = card_db.get_card_effects_at_timing(card, timing_name)
	for effect in card_effects:
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

	# Check for opponent-given character effects
	var opponent_given_effects = other_player.get_character_effects_at_timing("opponent_" + timing_name)

	var all_effects = []
	for effect in card_effects:
		if ignore_condition or is_effect_condition_met(performing_player, effect, null):
			all_effects.append(effect)
		elif 'negative_condition_effect' in effect:
			all_effects.append(effect['negative_condition_effect'])
	if not only_card_and_bonus_effects:
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
	for effect in opponent_given_effects:
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

func get_remaining_effect_count():
	if active_strike.extra_attack_in_progress:
		return active_strike.extra_attack_data.extra_attack_remaining_effects.size()
	else:
		return active_strike.remaining_effect_list.size()

func add_remaining_effect(effect):
	if active_strike.extra_attack_in_progress:
		active_strike.extra_attack_data.extra_attack_remaining_effects.append(effect)
	else:
		active_strike.remaining_effect_list.append(effect)

func erase_remaining_effect(effect):
	if active_strike.extra_attack_in_progress:
		active_strike.extra_attack_data.extra_attack_remaining_effects.erase(effect)
	else:
		active_strike.remaining_effect_list.erase(effect)

func remove_remaining_effect(effect, card_id):
	# This function is not intended to be called from extra attacks.
	assert(not active_strike.extra_attack_in_progress)
	if active_strike.extra_attack_in_progress:
		printlog("ERROR: Unexpected call during extra attacks.")
		return

	var base_effect = get_base_remaining_effect(effect)
	if active_strike and 'timing' in base_effect:
		for remaining_effect in active_strike.remaining_effect_list:
			if remaining_effect['timing'] == base_effect['timing'] and remaining_effect['card_id'] == card_id:
				active_strike.remaining_effect_list.erase(remaining_effect)
				break

func get_base_remaining_effect(effect):
	var remaining_effect_list = active_strike.remaining_effect_list
	if active_strike.extra_attack_in_progress:
		remaining_effect_list = active_strike.extra_attack_data.extra_attack_remaining_effects

	# Gets the base effect in the active strike's remaining effect list
	if 'is_negative_effect' in effect and effect['is_negative_effect']:
		# Find the actual effect this goes with, to avoid revealing condition outcomes early
		for remaining_effect in remaining_effect_list:
			if 'negative_condition_effect' in remaining_effect:
				if remaining_effect['negative_condition_effect'] == effect:
					return remaining_effect
	return effect

func sort_next_remaining_effects_to_choose(performing_player : Player):
	var remaining_effects = active_strike.remaining_effect_list
	if active_strike.extra_attack_in_progress:
		remaining_effects = active_strike.extra_attack_data.extra_attack_remaining_effects

	var effects_to_choose = {
		"condition_met": [],
		"condition_unmet": []
	}
	for effect in remaining_effects:
		if is_effect_condition_met(performing_player, effect, null):
			effects_to_choose["condition_met"].append(effect)
		elif 'negative_condition_effect' in effect and is_effect_condition_met(performing_player, effect['negative_condition_effect'], null):
			effects_to_choose["condition_met"].append(effect['negative_condition_effect'])
		else:
			# Should only be here if there was an effect that wasn't met
			assert("condition" in effect)
			if effect["condition"] not in StrikeStaticConditions:
				effects_to_choose["condition_unmet"].append(effect)
	return effects_to_choose

func reset_remaining_effects():
	if active_strike.extra_attack_in_progress:
		active_strike.extra_attack_data.extra_attack_remaining_effects = []
	else:
		active_strike.remaining_effect_list = []

func get_first_remaining_effect():
	if active_strike.extra_attack_in_progress:
		return active_strike.extra_attack_data.extra_attack_remaining_effects[0]
	else:
		return active_strike.remaining_effect_list[0]

func do_remaining_effects(performing_player : Player, next_state):
	var events = []

	while get_remaining_effect_count() > 0:
		if get_remaining_effect_count() > 1:
			# Check to see if any of these effects actually have their condition met (or have a negative condition).
			# If more than 1, send only those choices to the player.
			# If only 1 does, remove it from the list and do it immediately.
			# If none do, this is over, clear out the list.
			var effects_to_choose = sort_next_remaining_effects_to_choose(performing_player)
			var condition_met_effects = effects_to_choose["condition_met"]
			var condition_unmet_effects = effects_to_choose["condition_unmet"]

			# Check if any of these effects want to be resolved immediately
			# If so, just pick the first one.
			# This is done to reduce unnecessary choice dialogs for the user (ie. exceed Hazama).
			if condition_met_effects.size() + condition_unmet_effects.size() > 1:
				for effect in condition_met_effects + condition_unmet_effects:
					if 'resolve_before_simultaneous_effects' in effect and effect['resolve_before_simultaneous_effects']:
						condition_met_effects = [effect]
						condition_unmet_effects = []
						break

			# See if at least one effect can be resolved, potentially satisfying another's condition
			if condition_met_effects and condition_met_effects.size() + condition_unmet_effects.size() > 1:
				# Send choice to player
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_ChooseSimultaneousEffect
				decision_info.player = performing_player.my_id
				decision_info.choice = []
				decision_info.limitation = []
				for effect in condition_met_effects:
					decision_info.choice.append(get_base_remaining_effect(effect))
					decision_info.limitation.append(true)
				for effect in condition_unmet_effects:
					decision_info.choice.append(get_base_remaining_effect(effect))
					decision_info.limitation.append(false)
				events += [create_event(Enums.EventType.EventType_Strike_EffectChoice, performing_player.my_id, 0, "EffectOrder")]
				break
			elif condition_met_effects.size() == 1:
				# Use the base effect to account for negative effects.
				var effect = get_base_remaining_effect(condition_met_effects[0])
				erase_remaining_effect(effect)
				events += do_effect_if_condition_met(performing_player, effect['card_id'], effect, null)

				if game_state == Enums.GameState.GameState_PlayerDecision:
					break
			else:
				# No more effects have their conditions met.
				reset_remaining_effects()
		else:
			# Only 1 effect in the list, do it.
			var effect = get_first_remaining_effect()
			reset_remaining_effects()
			events += do_effect_if_condition_met(performing_player, effect['card_id'], effect, null)

			if game_state == Enums.GameState.GameState_PlayerDecision:
				break
		if game_over:
			return events

	if get_remaining_effect_count() == 0 and not game_state == Enums.GameState.GameState_PlayerDecision:
		active_strike.effects_resolved_in_timing = 0
		if active_strike.extra_attack_in_progress:
			active_strike.extra_attack_data.extra_attack_state = next_state
		else:
			active_strike.strike_state = next_state
	return events

func do_remaining_overdrive(events, performing_player : Player):
	change_game_state(Enums.GameState.GameState_Boost_Processing)
	while remaining_overdrive_effects.size() > 0:
		var effect = remaining_overdrive_effects[0]
		remaining_overdrive_effects.erase(effect)
		events += do_effect_if_condition_met(performing_player, -1, effect, null)
		if game_state == Enums.GameState.GameState_PlayerDecision:
			# Player has a decision to make, so stop mid-effect resolve.
			break

	if game_state != Enums.GameState.GameState_PlayerDecision:
		# Overdrive Cleanup
		if active_overdrive_boost_top_discard_on_cleanup:
			active_overdrive_boost_top_discard_on_cleanup = false
			# Assumption! The top discarded card is a continuous boost and
			# that boost has NO choices or decisions, it just goes into play.
			# do_boost will complete all the way through boost resolution.
			# Also, this boost has no cost.
			var card = performing_player.get_top_discard_card()
			# Put the card in the hand so do_boost has easy access.
			events += performing_player.move_card_from_discard_to_hand(card.id)
			# Queue events because do_boost will have its own events stack.
			event_queue += events
			# Intentional events = as events were queued and no more
			# will be added when this callstack returns.
			events = []

			# Prep gamestate so we can boost.
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.type = Enums.DecisionType.DecisionType_BoostNow
			do_boost(performing_player, card.id, [])

		# Very explicitly don't unset active_overdrive until after do_boost, so boost knows we're in overdrive doing this.
		# Also, there should be no decisions so we're good to advance the turn.
		active_overdrive = false
		events += start_begin_turn()

	return events

func do_remaining_character_action(performing_player : Player):
	var events = []
	if game_state != Enums.GameState.GameState_WaitForStrike and game_state != Enums.GameState.GameState_Strike_Opponent_Set_First:
		change_game_state(Enums.GameState.GameState_Boost_Processing)
	while remaining_character_action_effects.size() > 0:
		var effect = remaining_character_action_effects[0]
		remaining_character_action_effects.erase(effect)
		var card_id = -1
		if 'card_id' in effect:
			card_id = effect['card_id']
		events += do_effect_if_condition_met(performing_player, card_id, effect, null)
		if game_state == Enums.GameState.GameState_PlayerDecision:
			# Player has a decision to make, so stop mid-effect resolve.
			break

	if game_state != Enums.GameState.GameState_PlayerDecision:
		active_character_action = false
		if game_state != Enums.GameState.GameState_WaitForStrike and game_state != Enums.GameState.GameState_Strike_Opponent_Set_First:
			events += check_hand_size_advance_turn(performing_player)
	return events

func do_set_strike_x(performing_player : Player, source : String, extra_info):
	var events = []

	var value = 0
	match source:
		"random_gauge_power":
			if len(performing_player.gauge) > 0:
				var random_gauge_idx = get_random_int() % len(performing_player.gauge)
				var card = performing_player.gauge[random_gauge_idx]
				var power = get_card_stat(performing_player, card, 'power')
				value = max(power, 0)
				var card_name = card_db.get_card_name(card.id)
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "'s X for this strike is set to the power of %s in gauge, %s." % [card_name, value])
				events += [create_event(Enums.EventType.EventType_RevealRandomGauge, performing_player.my_id, card.id)]
			else:
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "has no cards in gauge, so X is set to 0.")
		"top_discard_power":
			if len(performing_player.discards) > 0:
				var card = performing_player.get_top_discard_card()
				var power = get_card_stat(performing_player, card, 'power')
				value = max(power, 0)
				var card_name = card_db.get_card_name(card.id)
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "'s X for this strike is set to the power of %s on top of discards, %s." % [card_name, value])
			else:
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "has no discards, so X is set to 0.")
		"top_deck_power":
			if len(performing_player.deck) > 0:
				var card = performing_player.get_top_deck_card()
				var power = get_card_stat(performing_player, card, 'power')
				value = max(power, 0)
				var card_name = card_db.get_card_name(card.id)
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "'s X for this strike is set to the power of %s on top of deck, %s." % [card_name, value])
			else:
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "'s deck is empty, so X is set to 0.")
		"opponent_speed":
			if active_strike:
				if performing_player == active_strike.initiator:
					var defender_speed = get_total_speed(active_strike.defender)
					value = max(defender_speed, 0)
				else:
					var initiator_speed = get_total_speed(active_strike.initiator)
					value = max(initiator_speed, 0)
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "'s X for this strike is set to the opponent's speed, %s." % value)
		"force_spent_before_strike":
			value = performing_player.force_spent_before_strike
			_append_log_full(Enums.LogType.LogType_Strike, performing_player, "'s X for this strike is set to the force spent, %s." % value)
		"gauge_spent_before_strike":
			value = performing_player.gauge_spent_before_strike
			_append_log_full(Enums.LogType.LogType_Strike, performing_player, "'s X for this strike is set to the gauge spent, %s." % value)
		"copies_in_gauge":
			var card_id = extra_info['card_id']
			var card_name = extra_info['card_name']
			for card in performing_player.gauge:
				if card.definition['id'] == card_id:
					value += 1
			_append_log_full(Enums.LogType.LogType_Strike, performing_player, "'s X for this strike is set to the number of copies of %s in gauge, %s." % [card_name, value])
		"lightningsrods_in_opponent_space":
			var opposing_player = _get_player(get_other_player(performing_player.my_id))
			for i in range(MinArenaLocation, MaxArenaLocation + 1):
				if opposing_player.is_in_location(i):
					var lightningzone = performing_player.get_lightningrod_zone_for_location(i)
					value += len(lightningzone)
			_append_log_full(Enums.LogType.LogType_Strike, opposing_player, "is on %s Lightning Rods." % [value])
		_:
			assert(false, "Unknown source for setting X")

	events += performing_player.set_strike_x(value)
	return events

func do_effects_for_timing(timing_name : String, performing_player : Player, card : GameCard, next_state, only_card_and_bonus_effects : bool = false):
	var events = []
	var effects = card_db.get_card_effects_at_timing(card, timing_name)
	var boost_effects = get_boost_effects_at_timing(timing_name, performing_player)
	var character_effects = performing_player.get_character_effects_at_timing(timing_name)
	var bonus_effects = performing_player.get_bonus_effects_at_timing(timing_name)
	if only_card_and_bonus_effects:
		boost_effects = []
		character_effects = []

	# Effects are resolved in the order:
	# Card > Continuous Boost > Character > Bonus
	while true:
		var boost_effects_resolved = active_strike.effects_resolved_in_timing - len(effects)
		var character_effects_resolved = boost_effects_resolved - len(boost_effects)
		var bonus_effects_resolved = character_effects_resolved - len(character_effects)
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
		elif bonus_effects_resolved < len(bonus_effects):
			# Resolve bonus effects
			var effect = bonus_effects[bonus_effects_resolved]
			events += do_effect_if_condition_met(performing_player, card.id, effect, null)
			if game_state == Enums.GameState.GameState_PlayerDecision:
				# Player has a decision to make, so stop mid-effect resolve.
				break

			# Effect was resolved, continue loop to resolve more.
			active_strike.effects_resolved_in_timing += 1
		else:
			# Cleanup
			if active_strike.extra_attack_in_progress:
				active_strike.extra_attack_data.extra_attack_state = next_state
			else:
				active_strike.strike_state = next_state
			active_strike.effects_resolved_in_timing = 0
			break

	return events

func is_location_in_range(attacking_player, card, test_location : int):
	if get_card_stat(attacking_player, card, 'range_min') == -1 or attacking_player.strike_stat_boosts.overwrite_range_to_invalid:
		return false
	var min_range = get_total_min_range(attacking_player)
	var max_range = get_total_max_range(attacking_player)

	if attacking_player.strike_stat_boosts.calculate_range_from_buddy:
		if not attacking_player.is_buddy_in_play(attacking_player.strike_stat_boosts.calculate_range_from_buddy_id):
			return false
	var attack_source_location = get_attack_origin(attacking_player, test_location)

	var distance = abs(attack_source_location - test_location)
	if min_range <= distance and distance <= max_range:
		return true
	return false

func in_range(attacking_player, defending_player, card, combat_logging=false):
	if attacking_player.strike_stat_boosts.attack_does_not_hit or attacking_player.strike_stat_boosts.overwrite_range_to_invalid:
		return false
	if active_strike and active_strike.extra_attack_in_progress:
		if active_strike.extra_attack_data.extra_attack_always_miss:
			return false
	if attacking_player.strike_stat_boosts.only_hits_if_opponent_on_any_buddy:
		var buddies = attacking_player.get_buddies_on_opponent()
		if buddies.size() == 0:
			return false
	if defending_player.strike_stat_boosts.dodge_attacks:
		if combat_logging:
			_append_log_full(Enums.LogType.LogType_Effect, defending_player, "is dodging attacks!")
		return false

	if defending_player.strike_stat_boosts.dodge_from_opposite_buddy and defending_player.is_buddy_in_play():
		var buddy_pos = defending_player.get_buddy_location()
		var dodging = false
		if attacking_player.is_left_of_location(buddy_pos) and defending_player.is_right_of_location(buddy_pos):
			dodging = true
		elif attacking_player.is_right_of_location(buddy_pos) and defending_player.is_left_of_location(buddy_pos):
				dodging = true
		if dodging:
			if combat_logging:
				_append_log_full(Enums.LogType.LogType_Effect, defending_player, "dodges attacks from behind %s!" % defending_player.get_buddy_name())
			return false

	var standard_source = true
	if attacking_player.strike_stat_boosts.calculate_range_from_buddy:
		standard_source = false
		if not attacking_player.is_buddy_in_play(attacking_player.strike_stat_boosts.calculate_range_from_buddy_id):
			return false
	if attacking_player.strike_stat_boosts.calculate_range_from_center:
		standard_source = false
	var attack_source_location = get_attack_origin(attacking_player, defending_player.arena_location)

	var defender_location = defending_player.arena_location
	var defender_width = defending_player.extra_width
	var opponent_in_range = false
	if attacking_player.strike_stat_boosts.range_includes_lightningrods and attacking_player.is_opponent_on_lightningrod():
		opponent_in_range = true
		_append_log_full(Enums.LogType.LogType_Strike, defending_player, "is on a Lightning Rod.")
	elif attacking_player.strike_stat_boosts.range_includes_opponent:
		opponent_in_range = true
	else:
		for defender_space_offset in range(-defender_width, defender_width+1):
			var defender_space = defender_location + defender_space_offset
			if is_location_in_range(attacking_player, card, defender_space):
				opponent_in_range = true
				break

		var min_range = get_total_min_range(attacking_player)
		var max_range = get_total_max_range(attacking_player)
		if active_strike.extra_attack_in_progress:
			min_range -= active_strike.extra_attack_data.extra_attack_previous_attack_min_range_bonus
			max_range -= active_strike.extra_attack_data.extra_attack_previous_attack_max_range_bonus
		var range_string = str(min_range)
		if min_range != max_range:
			range_string += "-%s" % str(max_range)
		_append_log_full(Enums.LogType.LogType_Strike, attacking_player, "has range %s." % range_string)

	# Apply special late calculation range dodges
	if defending_player.strike_stat_boosts.dodge_at_range_late_calculate_with == "OVERDRIVE_COUNT":
		var overdrive_count = defending_player.overdrive.size()
		defending_player.strike_stat_boosts.dodge_at_range_min = overdrive_count
		defending_player.strike_stat_boosts.dodge_at_range_max = overdrive_count

	# Range dodge
	if defending_player.strike_stat_boosts.dodge_at_range_min != -1:
		var dodge_range_string = str(defending_player.strike_stat_boosts.dodge_at_range_min)
		if defending_player.strike_stat_boosts.dodge_at_range_max != defending_player.strike_stat_boosts.dodge_at_range_min:
			dodge_range_string += "-%s" % str(defending_player.strike_stat_boosts.dodge_at_range_max)

		if defending_player.strike_stat_boosts.dodge_at_range_from_buddy:
			var buddy_location = defending_player.get_buddy_location()
			var buddy_attack_source_location = attack_source_location
			if standard_source:
				buddy_attack_source_location = attacking_player.get_closest_occupied_space_to(buddy_location)
			var buddy_distance = abs(buddy_attack_source_location - buddy_location)
			if defending_player.strike_stat_boosts.dodge_at_range_min <= buddy_distance and buddy_distance <= defending_player.strike_stat_boosts.dodge_at_range_max:
				if combat_logging:
					_append_log_full(Enums.LogType.LogType_Effect, defending_player, "is dodging attacks at range %s from %s!" % [dodge_range_string, defending_player.get_buddy_name()])
				return false
		else:
			var dodge_range_min = defending_player.strike_stat_boosts.dodge_at_range_min
			var dodge_range_max = defending_player.strike_stat_boosts.dodge_at_range_max
			if defending_player.is_in_range_of_location(attack_source_location, dodge_range_min, dodge_range_max):
				if combat_logging:
					_append_log_full(Enums.LogType.LogType_Effect, defending_player, "is dodging attacks at range %s!" % dodge_range_string)
				return false

	# Speed dodge
	var attacking_speed = get_total_speed(attacking_player)
	var defending_speed = get_total_speed(defending_player)
	if defending_player.strike_stat_boosts.higher_speed_misses:
		var speed_dodge = defending_player.strike_stat_boosts.dodge_at_speed_greater_or_equal
		if speed_dodge > 0:
			if attacking_speed >= speed_dodge:
				if combat_logging:
					_append_log_full(Enums.LogType.LogType_Effect, defending_player, "is dodging attacks with more than %s speed!" % str(speed_dodge))
				return false
		elif attacking_speed > defending_speed:
			if combat_logging:
				_append_log_full(Enums.LogType.LogType_Effect, defending_player, "is dodging higher speed attacks!")
			return false

	return opponent_in_range

func get_total_power(performing_player : Player, card : GameCard = null):
	if performing_player.strike_stat_boosts.overwrite_total_power:
		return performing_player.strike_stat_boosts.overwritten_total_power

	assert(card or active_strike, "ERROR: No card or active strike to get power from.")
	if active_strike:
		card = active_strike.get_player_card(performing_player)
		if active_strike.extra_attack_in_progress:
			card = active_strike.extra_attack_data.extra_attack_card

	var power = get_card_stat(performing_player, card, 'power')
	# If some character multiplies both all bonuses and positive bonuses, that will need to be considered carefully.
	# For now, just assert we're not doing that.
	assert(performing_player.strike_stat_boosts.power_bonus_multiplier == 1 or performing_player.strike_stat_boosts.power_bonus_multiplier_positive_only == 1)

	var boosted_power = performing_player.strike_stat_boosts.power
	if performing_player.strike_stat_boosts.power_modify_per_buddy_between:
		# NOTE: This does not interact with the positive power multiplier.
		# If someone ever needs that, this needs to be updated.
		var buddy_count = performing_player.count_buddies_between_opponent()
		boosted_power += buddy_count * performing_player.strike_stat_boosts.power_modify_per_buddy_between

	# Multiply all power bonuses.
	var power_modifier = boosted_power * performing_player.strike_stat_boosts.power_bonus_multiplier

	# Multiply positive power bonuses and add that in.
	var positive_multiplier_bonus = performing_player.strike_stat_boosts.power_positive_only
	positive_multiplier_bonus *= (performing_player.strike_stat_boosts.power_bonus_multiplier_positive_only - 1)
	power_modifier += positive_multiplier_bonus

	if active_strike and active_strike.extra_attack_in_progress:
		# If an extra attack character has ways to get power multipliers, deal with that then.
		power_modifier = performing_player.strike_stat_boosts.power - active_strike.extra_attack_data.extra_attack_previous_attack_power_bonus
	return power + power_modifier

func get_total_armor(performing_player : Player):
	if performing_player.strike_stat_boosts.overwrite_total_armor:
		return performing_player.strike_stat_boosts.overwritten_total_armor

	var card = active_strike.get_player_card(performing_player)
	var armor = card.definition['armor']
	var armor_modifier = performing_player.strike_stat_boosts.armor - performing_player.strike_stat_boosts.consumed_armor
	return max(0, armor + armor_modifier)

func get_total_guard(performing_player : Player):
	if performing_player.strike_stat_boosts.overwrite_total_guard:
		return performing_player.strike_stat_boosts.overwritten_total_guard

	var card = active_strike.get_player_card(performing_player)
	var guard = get_card_stat(performing_player, card, 'guard')
	var guard_modifier = performing_player.strike_stat_boosts.guard
	return guard + guard_modifier

func get_total_min_range(performing_player : Player):
	assert(active_strike)
	var card = active_strike.get_player_card(performing_player)
	if active_strike.extra_attack_in_progress:
		card = active_strike.extra_attack_data.extra_attack_card

	var min_range = get_card_stat(performing_player, card, 'range_min')
	var min_range_modifier = performing_player.strike_stat_boosts.min_range
	return min_range + min_range_modifier

func get_total_max_range(performing_player : Player):
	assert(active_strike)
	var card = active_strike.get_player_card(performing_player)
	if active_strike.extra_attack_in_progress:
		card = active_strike.extra_attack_data.extra_attack_card

	var max_range = get_card_stat(performing_player, card, 'range_max')
	var max_range_modifier = performing_player.strike_stat_boosts.max_range
	return max_range + max_range_modifier

func get_attack_origin(performing_player : Player, target_location : int):
	var origin = performing_player.get_closest_occupied_space_to(target_location)
	if performing_player.strike_stat_boosts.calculate_range_from_buddy:
		origin = performing_player.get_buddy_location(performing_player.strike_stat_boosts.calculate_range_from_buddy_id)
	elif performing_player.strike_stat_boosts.calculate_range_from_center:
		origin = CenterArenaLocation
	return origin

func calculate_damage(offense_player : Player, defense_player : Player) -> int:
	var power = get_total_power(offense_player)
	var armor = get_total_armor(defense_player)
	if offense_player.strike_stat_boosts.ignore_armor:
		armor = 0
	var damage_after_armor = max(power - armor, 0)
	return damage_after_armor

func check_for_stun(check_player : Player, ignore_guard : bool):
	var events = []

	if active_strike.is_player_stunned(check_player):
		# If they're already stunned, can't stun again.
		return events

	var total_damage = active_strike.get_damage_taken(check_player)
	var defense_card = active_strike.get_player_card(check_player)
	var guard = get_total_guard(check_player)
	_append_log_full(Enums.LogType.LogType_Strike, null, "Stun check: %s total damage vs %s guard." % [total_damage, guard])
	if ignore_guard:
		_append_log_full(Enums.LogType.LogType_Strike, _get_player(get_other_player(check_player.my_id)), "ignores Guard!")
		guard = 0

	guard = max(guard, 0)
	if total_damage > guard:
		if check_player.strike_stat_boosts.stun_immunity:
			_append_log_full(Enums.LogType.LogType_Strike, check_player, "has stun immunity!")
			events += [create_event(Enums.EventType.EventType_Strike_Stun_Immunity, check_player.my_id, defense_card.id)]
		else:
			_append_log_full(Enums.LogType.LogType_Strike, check_player, "is stunned!")
			events += [create_event(Enums.EventType.EventType_Strike_Stun, check_player.my_id, defense_card.id)]
			active_strike.set_player_stunned(check_player)

			# Assumes non-decision effects only
			var effects = check_player.get_character_effects_at_timing("on_stunned")
			for effect in effects:
				events += do_effect_if_condition_met(check_player, -1, effect, null)

	return events

func apply_damage(offense_player : Player, defense_player : Player):
	var events = []
	var power = get_total_power(offense_player)
	var armor = get_total_armor(defense_player)

	defense_player.strike_stat_boosts.was_hit = true

	_append_log_full(Enums.LogType.LogType_Strike, null, "Damage calculation: %s total power vs %s total armor." % [str(power), str(armor)])

	if offense_player.strike_stat_boosts.ignore_armor:
		_append_log_full(Enums.LogType.LogType_Strike, offense_player, "ignores Armor!")
		armor = 0

	var damage_after_armor = calculate_damage(offense_player, defense_player)
	if offense_player.strike_stat_boosts.deal_nonlethal_damage:
		_append_log_full(Enums.LogType.LogType_Health, offense_player, "'s attack does nonlethal damage.")
		damage_after_armor = min(damage_after_armor, defense_player.life-1)
	defense_player.life -= damage_after_armor
	if defense_player.strike_stat_boosts.cannot_go_below_life > 0:
		defense_player.life = max(defense_player.life, defense_player.strike_stat_boosts.cannot_go_below_life)
	if armor > 0:
		defense_player.strike_stat_boosts.consumed_armor += (power - damage_after_armor)
	events += [create_event(Enums.EventType.EventType_Strike_TookDamage, defense_player.my_id, damage_after_armor, "", defense_player.life)]

	_append_log_full(Enums.LogType.LogType_Health, defense_player, "takes %s damage, bringing them to %s life!" % [str(damage_after_armor), str(defense_player.life)])

	active_strike.add_damage_taken(defense_player, damage_after_armor)
	if offense_player.strike_stat_boosts.cannot_stun:
		_append_log_full(Enums.LogType.LogType_Strike, offense_player, "'s attack cannot stun!")
	else:
		events += check_for_stun(defense_player, offense_player.strike_stat_boosts.ignore_guard)

	if defense_player.life <= 0:
		_append_log_full(Enums.LogType.LogType_Default, defense_player, "has no life remaining!")
		events += on_death(defense_player)
	return events

func on_death(performing_player):
	var events = []
	if 'on_death' in performing_player.deck_def:
		events += do_effect_if_condition_met(performing_player, -1, performing_player.deck_def['on_death'], null)
	if performing_player.life <= 0:
		events += trigger_game_over(performing_player.my_id, Enums.GameOverReason.GameOverReason_Life)
	return events

func get_gauge_cost(performing_player, card, check_if_card_in_hand = false):
	var gauge_cost = card.definition['gauge_cost']
	var is_ex = active_strike.will_be_ex(performing_player)
	if 'gauge_cost_ex' in card.definition and is_ex:
		gauge_cost = card.definition['gauge_cost_ex']
	if 'gauge_cost_exceed' in card.definition and performing_player.exceeded:
		gauge_cost = card.definition['gauge_cost_exceed']

	if 'gauge_cost_reduction' in card.definition:
		match card.definition['gauge_cost_reduction']:
			"per_sealed_normal":
				var sealed_normals = performing_player.get_sealed_count_of_type("normal")
				gauge_cost = max(0, gauge_cost - sealed_normals)
			"per_card_copy_in_gauge":
				var card_id = card.definition['gauge_cost_reduction_card_id']
				for gauge_card in performing_player.gauge:
					if gauge_card.definition['id'] == card_id:
						gauge_cost -= 1
				gauge_cost = max(0, gauge_cost)
			"free_if_no_cards_in_hand":
				var hand_size = performing_player.hand.size()
				if check_if_card_in_hand and card in performing_player.hand:
					hand_size -= 1
				if hand_size == 0:
					gauge_cost = 0
			"free_if_4_specials_in_overdrive":
				var different_special_count = 0
				var found_specials = []
				for overdrive_card in performing_player.overdrive:
					if overdrive_card.definition['type'] == "special" and not overdrive_card.definition['id'] in found_specials:
						different_special_count += 1
						found_specials.append(overdrive_card.definition['id'])
				if different_special_count == 4:
					gauge_cost = 0


	return gauge_cost

func ask_for_cost(performing_player, card, next_state):
	var events = []
	var gauge_cost = get_gauge_cost(performing_player, card)
	var force_cost = card.definition['force_cost']
	var card_has_printed_cost = card.definition['gauge_cost'] > 0 or force_cost > 0
	var is_special = card.definition['type'] == "special"
	var is_ultra = card.definition['type'] == "ultra"
	var is_ex = active_strike.get_player_ex_card(performing_player) != null
	var gauge_discard_reminder = false
	if 'gauge_discard_reminder' in card.definition:
		gauge_discard_reminder = true

	if performing_player.strike_stat_boosts.may_generate_gauge_with_force and gauge_cost > 0:
		# Convert the gauge cost to a force cost.
		force_cost = gauge_cost
		gauge_cost = 0

	var card_in_invalid_list = card.definition['display_name'] in performing_player.cards_invalid_during_strike

	var invalidate_if_not_faceup = 'invalid_if_not_set_face_up' in card.definition and card.definition['invalid_if_not_set_face_up']
	var invalid_because_facedown = false
	if invalidate_if_not_faceup:
		if performing_player == active_strike.initiator:
			invalid_because_facedown = not active_strike.initiator_set_face_up
		else:
			invalid_because_facedown = not active_strike.defender_set_face_up

	var invalidate_if_not_set_from_boosts = 'must_set_from_boost' in card.definition and card.definition['must_set_from_boost']
	var invalid_because_not_set_from_boosts = false
	if invalidate_if_not_set_from_boosts:
		if performing_player == active_strike.initiator:
			invalid_because_not_set_from_boosts = not active_strike.initiator_set_from_boosts
		else:
			invalid_because_not_set_from_boosts = not active_strike.defender_set_from_boosts

	var card_forced_invalid = (is_special and performing_player.specials_invalid) or card_in_invalid_list or invalid_because_facedown or invalid_because_not_set_from_boosts
	# Even if the cost can be paid for free, if the card has a cost wild swing is allowed.
	var was_wild_swing = active_strike.get_player_wild_strike(performing_player)
	var can_invalidate_ultra = is_ultra and performing_player.strike_stat_boosts.may_invalidate_ultras
	var can_invalidate_anyway = (was_wild_swing and card_has_printed_cost) or can_invalidate_ultra

	# Extra attacks live outside of lots of rules.
	# They cannot fail to pay the cost.
	if active_strike.extra_attack_in_progress:
		was_wild_swing = false
		card_forced_invalid = false
		can_invalidate_anyway = false

	if performing_player.can_pay_cost_with([], force_cost, gauge_cost) and not card_forced_invalid and not can_invalidate_anyway:
		if active_strike.extra_attack_in_progress:
			active_strike.extra_attack_data.extra_attack_state = next_state
		else:
			active_strike.strike_state = next_state
	else:
		if not card_forced_invalid and performing_player.can_pay_cost(force_cost, gauge_cost):
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.player = performing_player.my_id
			if was_wild_swing:
				decision_info.type = Enums.DecisionType.DecisionType_PayStrikeCost_CanWild
			else:
				decision_info.type = Enums.DecisionType.DecisionType_PayStrikeCost_Required

			var still_use_gauge = card.definition['gauge_cost'] > 0 and not performing_player.strike_stat_boosts.may_generate_gauge_with_force
			if gauge_cost > 0 or still_use_gauge:
				decision_info.limitation = "gauge"
				decision_info.cost = gauge_cost
				events += [create_event(Enums.EventType.EventType_Strike_PayCost_Gauge, performing_player.my_id, card.id, "", gauge_discard_reminder, is_ex)]
			elif force_cost > 0:
				decision_info.limitation = "force"
				decision_info.cost = force_cost
				events += [create_event(Enums.EventType.EventType_Strike_PayCost_Force, performing_player.my_id, card.id, "", false, is_ex)]
			else:
				assert(false, "ERROR: Expected card to have a force to pay")
			_append_log_full(Enums.LogType.LogType_Strike, performing_player, "is selecting cards to pay the %s cost." % decision_info.limitation)
		else:
			# Failed to pay the cost by default.
			_append_log_full(Enums.LogType.LogType_Strike, performing_player, "cannot validate %s, so they wild swing." % card.definition['display_name'])
			events += performing_player.invalidate_card(card)
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
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "wild swings %s!" % new_wild_card.definition['display_name'])
				is_special = new_wild_card.definition['type'] == "special"
				card_forced_invalid = (is_special and performing_player.specials_invalid)
				if card_forced_invalid:
					_append_log_full(Enums.LogType.LogType_Strike, performing_player, "'s specials are invalid, so they wild swing.")
					events += performing_player.invalidate_card(new_wild_card)
					new_wild_card = null
			events += [create_event(Enums.EventType.EventType_Strike_PayCost_Unable, performing_player.my_id, new_wild_card.id)]
	return events

func do_hit_response_effects(offense_player : Player, defense_player : Player, incoming_damage : int, next_state):
	# If more of these are added, need to sequence them to ensure all handled correctly.
	var events = []

	var defender_card = active_strike.get_player_card(defense_player)
	if active_strike.extra_attack_in_progress:
		active_strike.extra_attack_data.extra_attack_state = next_state
	else:
		active_strike.strike_state = next_state

	# Assumes these will be armor-related.
	# No choices currently allowed at this timing.
	var effects = get_all_effects_for_timing("when_hit", defense_player, defender_card)
	for effect in effects:
		var first_time_only = 'first_time_only' in effect and effect['first_time_only']
		if first_time_only and effect in active_strike.when_hit_effects_processed:
			continue
		active_strike.when_hit_effects_processed.append(effect)
		var card_id = -1
		if 'card_id' in effect:
			card_id = effect['card_id']
		events += do_effect_if_condition_met(defense_player, card_id, effect, null)

		if game_over:
			change_game_state(Enums.GameState.GameState_GameOver)
			return events


	if defense_player.strike_stat_boosts.when_hit_force_for_armor:
		change_game_state(Enums.GameState.GameState_PlayerDecision)
		decision_info.clear()
		decision_info.player = defense_player.my_id
		decision_info.type = Enums.DecisionType.DecisionType_ForceForArmor
		decision_info.choice_card_id = defender_card.id
		decision_info.limitation = defense_player.strike_stat_boosts.when_hit_force_for_armor
		decision_info.amount = 2
		events += [create_event(Enums.EventType.EventType_Strike_ForceForArmor, defense_player.my_id, incoming_damage, "", offense_player.strike_stat_boosts.ignore_armor)]

	return events

func log_boosts_in_play():
	var card_names = "None"
	if len(active_strike.initiator.continuous_boosts) > 0:
		card_names = card_db.get_card_name(active_strike.initiator.continuous_boosts[0].id)
		for i in range(1, active_strike.initiator.continuous_boosts.size()):
			var card = active_strike.initiator.continuous_boosts[i]
			card_names += ", " + card_db.get_card_name(card.id)
		_append_log_full(Enums.LogType.LogType_Strike, active_strike.initiator, "has active continuous boosts: %s" % card_names)

	card_names = "None"
	if len(active_strike.defender.continuous_boosts) > 0:
		card_names = card_db.get_card_name(active_strike.defender.continuous_boosts[0].id)
		for i in range(1, active_strike.defender.continuous_boosts.size()):
			var card = active_strike.defender.continuous_boosts[i]
			card_names += ", " + card_db.get_card_name(card.id)
		_append_log_full(Enums.LogType.LogType_Strike, active_strike.defender, "has active continuous boosts: %s" % card_names)

func continue_resolve_strike(events):
	if active_strike.in_setup:
		return continue_setup_strike(events)
	elif active_strike.extra_attack_in_progress:
		return continue_extra_attack(events)

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
			StrikeState.StrikeState_Initiator_RevealEffects:
				events += do_remaining_effects(active_strike.initiator, StrikeState.StrikeState_Defender_RevealEffects)
				if active_strike.strike_state == StrikeState.StrikeState_Defender_RevealEffects:
					active_strike.remaining_effect_list = get_all_effects_for_timing("on_strike_reveal", active_strike.defender, active_strike.defender_card)
			StrikeState.StrikeState_Defender_RevealEffects:
				events += do_remaining_effects(active_strike.defender, StrikeState.StrikeState_Initiator_PayCosts)
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
				active_strike.cards_in_play += [active_strike.initiator_card, active_strike.defender_card]
				_append_log_full(Enums.LogType.LogType_Strike, active_strike.initiator, "initiated with %s; %s responded with %s." % [active_strike.initiator_card.definition['display_name'], active_strike.defender.name, active_strike.defender_card.definition['display_name']])
				log_boosts_in_play()
				events += do_effects_for_timing("during_strike", active_strike.initiator, active_strike.initiator_card, StrikeState.StrikeState_DuringStrikeBonuses)
				# Should never be interrupted by player decisions.
				events += do_effects_for_timing("during_strike", active_strike.defender, active_strike.defender_card, StrikeState.StrikeState_Card1_Activation)
				strike_determine_order()
			StrikeState.StrikeState_Card1_Activation:
				var card_name = card_db.get_card_name(card1.id)
				_append_log_full(Enums.LogType.LogType_Strike, player1, "strikes first with %s!" % card_name)
				events += [create_event(Enums.EventType.EventType_Strike_CardActivation, active_strike.get_player(1).my_id, card1.id)]
				active_strike.strike_state = StrikeState.StrikeState_Card1_Before
				active_strike.remaining_effect_list = get_all_effects_for_timing("before", player1, card1)
			StrikeState.StrikeState_Card1_Before:
				events += do_remaining_effects(player1, StrikeState.StrikeState_Card1_DetermineHit)
			StrikeState.StrikeState_Card1_DetermineHit:
				var hit = determine_if_attack_hits(events, player1, player2, card1)
				if hit:
					active_strike.player1_hit = true
					active_strike.strike_state = StrikeState.StrikeState_Card1_Hit
					active_strike.remaining_effect_list = get_all_effects_for_timing("hit", player1, card1)
				else:
					active_strike.strike_state = StrikeState.StrikeState_Card1_After
					active_strike.remaining_effect_list = get_all_effects_for_timing("after", player1, card1)
			StrikeState.StrikeState_Card1_Hit:
				events += do_remaining_effects(player1, StrikeState.StrikeState_Card1_Hit_Response)
			StrikeState.StrikeState_Card1_Hit_Response:
				var incoming_damage = calculate_damage(player1, player2)
				events += do_hit_response_effects(player1, player2, incoming_damage, StrikeState.StrikeState_Card1_ApplyDamage)
			StrikeState.StrikeState_Card1_ApplyDamage:
				events += apply_damage(player1, player2)
				active_strike.strike_state = StrikeState.StrikeState_Card1_After
				active_strike.remaining_effect_list = get_all_effects_for_timing("after", player1, card1)
				if game_over:
					active_strike.strike_state = StrikeState.StrikeState_Cleanup
			StrikeState.StrikeState_Card1_After:
				events += do_remaining_effects(player1, StrikeState.StrikeState_Card2_Activation)
			StrikeState.StrikeState_Card2_Activation:
				var card_name = card_db.get_card_name(card2.id)
				if active_strike.player2_stunned:
					_append_log_full(Enums.LogType.LogType_Strike, player2, "is stunned, so %s does not activate!" % card_name)
					active_strike.strike_state = StrikeState.StrikeState_Cleanup
				else:
					_append_log_full(Enums.LogType.LogType_Strike, player2, "responds with %s!" % card_name)
					events += [create_event(Enums.EventType.EventType_Strike_CardActivation, active_strike.get_player(2).my_id, card2.id)]
					active_strike.strike_state = StrikeState.StrikeState_Card2_Before
					active_strike.remaining_effect_list = get_all_effects_for_timing("before", player2, card2)
			StrikeState.StrikeState_Card2_Before:
				events += do_remaining_effects(player2, StrikeState.StrikeState_Card2_DetermineHit)
			StrikeState.StrikeState_Card2_DetermineHit:
				var hit = determine_if_attack_hits(events, player2, player1, card2)
				if hit:
					active_strike.player2_hit = true
					active_strike.strike_state = StrikeState.StrikeState_Card2_Hit
					active_strike.remaining_effect_list = get_all_effects_for_timing("hit", player2, card2)
				else:
					active_strike.strike_state = StrikeState.StrikeState_Card2_After
					active_strike.remaining_effect_list = get_all_effects_for_timing("after", player2, card2)
			StrikeState.StrikeState_Card2_Hit:
				events += do_remaining_effects(player2, StrikeState.StrikeState_Card2_Hit_Response)
			StrikeState.StrikeState_Card2_Hit_Response:
				var incoming_damage = calculate_damage(player2, player1)
				events += do_hit_response_effects(player2, player1, incoming_damage, StrikeState.StrikeState_Card2_ApplyDamage)
			StrikeState.StrikeState_Card2_ApplyDamage:
				events += apply_damage(player2, player1)
				active_strike.strike_state = StrikeState.StrikeState_Card2_After
				active_strike.remaining_effect_list = get_all_effects_for_timing("after", player2, card2)
				if game_over:
					active_strike.strike_state = StrikeState.StrikeState_Cleanup
			StrikeState.StrikeState_Card2_After:
				events += do_remaining_effects(player2, StrikeState.StrikeState_Cleanup)
			StrikeState.StrikeState_Cleanup:
				_append_log_full(Enums.LogType.LogType_Strike, null, "Starting strike cleanup.")
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
				# Handle cleanup effects that cause attack cards to leave play before the standard timing
				events += handle_strike_attack_cleanup(player1, card1)
				events += handle_strike_attack_cleanup(player2, card2)

				# Remove any Reading effects
				player1.reading_card_id = ""
				player2.reading_card_id = ""

				# Cleanup any continuous boosts.
				events += player1.cleanup_continuous_boosts()
				events += player2.cleanup_continuous_boosts()

				# Cleanup attacks, if hit, move card to gauge, otherwise move to discard.
				if card1 in active_strike.cards_in_play:
					events += strike_send_attack_to_discard_or_gauge(player1, card1)
				if card2 in active_strike.cards_in_play:
					events += strike_send_attack_to_discard_or_gauge(player2, card2)
				assert(active_strike.cards_in_play.size() == 0, "ERROR: cards still in play after strike should have been cleaned up")

				# Remove all stat boosts.
				player.strike_stat_boosts.clear()
				opponent.strike_stat_boosts.clear()

				# Cleanup UI
				events.append(create_event(Enums.EventType.EventType_Strike_Cleanup, player1.my_id, -1))

				active_strike = null
				if game_over:
					change_game_state(Enums.GameState.GameState_GameOver)
				else:
					events += start_end_turn()
				break

	if game_state == Enums.GameState.GameState_PlayerDecision and decision_info.type == Enums.DecisionType.DecisionType_ForceBoostSustainTopdeck:
		do_topdeck_boost(events)
		events = []
	elif game_state == Enums.GameState.GameState_PlayerDecision and decision_info.type == Enums.DecisionType.DecisionType_ForceBoostSustainTopDiscard:
		do_discard_boost(events)
		events = []

	return events

func handle_strike_attack_immediate_removal(performing_player : Player):
	var events = []
	var other_player = _get_player(get_other_player(performing_player.my_id))
	var card = active_strike.get_player_card(performing_player)
	var card_name = card.definition['display_name']

	# NOTE: Currently, active strike will still have this card set as the active_strike player card.
	# Potentially removing that may break things.
	# As long as all state/stats is correctly updated though, it should be okay
	# unless some card effect that references something on that card and it should
	# behave differently if the strike card is gone.

	change_stats_when_attack_leaves_play(performing_player)

	if performing_player.strike_stat_boosts.discard_attack_now_for_lightningrod:
		# No logline since there will be a log about this in the lightning rod effect.
		events += performing_player.add_to_discards(card)
		active_strike.cards_in_play.erase(card)
	elif performing_player.strike_stat_boosts.return_attack_to_hand:
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "returns their attack %s to their hand." % card_name)
		events += performing_player.add_to_hand(card, true)
		active_strike.cards_in_play.erase(card)
	elif performing_player.strike_stat_boosts.move_strike_to_opponent_boosts:
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "'s attack %s is set as a continuous boost for %s." % [card_name, other_player.name])
		events += other_player.add_to_continuous_boosts(card)
		other_player.sustained_boosts.append(card.id)
		active_strike.cards_in_play.erase(card)
	elif performing_player.strike_stat_boosts.move_strike_to_boosts:
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "'s attack %s is set as a continuous boost." % card_name)
		events += performing_player.add_to_continuous_boosts(card)
		if performing_player.strike_stat_boosts.move_strike_to_boosts_sustain:
			performing_player.sustained_boosts.append(card.id)
		active_strike.cards_in_play.erase(card)
	elif performing_player.strike_stat_boosts.attack_to_topdeck_on_cleanup:
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "returns their attack %s to the top of their deck." % card_name)
		events += performing_player.add_to_top_of_deck(card, true)
		active_strike.cards_in_play.erase(card)
	elif performing_player.strike_stat_boosts.always_add_to_overdrive:
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds their attack %s to overdrive." % card_name)
		events += performing_player.add_to_overdrive(card)
		active_strike.cards_in_play.erase(card)
	else:
		assert(false, "ERROR: Unexpected call to attack removal but state doesn't match.")

	return events

func handle_strike_attack_cleanup(performing_player : Player, card):
	var events = []
	var card_name = card.definition['display_name']

	if card not in active_strike.cards_in_play:
		# Already removed from play mid-strike
		return events

	if performing_player.is_set_aside_card(card.id):
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "sets aside their attack %s." % card_name)
		events += [create_event(Enums.EventType.EventType_SetCardAside, performing_player.my_id, card.id)]
		active_strike.cards_in_play.erase(card)
	elif performing_player.strike_stat_boosts.seal_attack_on_cleanup:
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "seals their attack %s." % card_name)
		events += do_seal_effect(performing_player, card.id, "")
		active_strike.cards_in_play.erase(card)
	elif performing_player.strike_stat_boosts.discard_attack_on_cleanup:
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards their attack %s." % card_name)
		events += performing_player.add_to_discards(card)
		active_strike.cards_in_play.erase(card)

	return events

func strike_send_attack_to_discard_or_gauge(performing_player : Player, card):
	var events = []
	var hit = active_strike.player1_hit
	var stat_boosts = performing_player.strike_stat_boosts
	if active_strike.get_player(2) == performing_player:
		hit = active_strike.player2_hit
	var card_name = card.definition['display_name']

	if hit or stat_boosts.always_add_to_gauge:
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds their attack %s to gauge." % card_name)
		events += performing_player.add_to_gauge(card)
	else:
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards their attack %s." % card_name)
		events += performing_player.add_to_discards(card)
	active_strike.cards_in_play.erase(card)

	return events

func begin_extra_attack(events, performing_player : Player, card_id : int):
	assert(active_strike)
	# The player is mid-strike and playing an extra attack card.
	# These are the steps of extra attack:
	# * Pay its cost.
	# * Put it into play, gaining any Armor, Guard, and passive effects on it.
	# * Perform its Before effects, then check its Range.
	# * If it hit, perform its Hit effects.
	# * If it hit, deal damage equal to its printed Power.
	# * Perform its After effects.
	# * At the end of the Strike, if the additional attack hit, add it to your Gauge. Otherwise, discard it.
	# * Note that bonuses and effects that apply to your attack (e.g., Continuous Boost effects such as "+2 Power") only apply to your initial attack unless they specify "Your attacks have [...]" (as the Graviton does).
	#
	# Since the strike is still active, there is a hook in continue_resolve_strike
	# that goes to continue_extra_attack if there is an extra attack active.
	# This way all things that work during strikes will also work during extra attacks.
	#
	# As you gain passive effects, those will go straight into strike_stat_boosts.
	# However, for damage calculation, subtract the saved power bonus as that does not apply.
	# Also, for hit calculation range bonuses do not apply.
	#

	# Also extra attacks can happen inside of extra attacks, so do a linked list thing to handle that
	if active_strike.extra_attack_in_progress:
		var new_extra_attack_data = ExtraAttackData.new()
		new_extra_attack_data.extra_attack_parent = active_strike.extra_attack_data
		active_strike.extra_attack_data = new_extra_attack_data
	else:
		active_strike.extra_attack_in_progress = true
		active_strike.extra_attack_data.reset()
	active_strike.extra_attack_data.extra_attack_card = card_db.get_card(card_id)
	active_strike.extra_attack_data.extra_attack_player = performing_player
	active_strike.extra_attack_data.extra_attack_previous_attack_power_bonus = performing_player.strike_stat_boosts.power
	active_strike.extra_attack_data.extra_attack_previous_attack_speed_bonus = performing_player.strike_stat_boosts.speed
	active_strike.extra_attack_data.extra_attack_previous_attack_min_range_bonus = performing_player.strike_stat_boosts.min_range
	active_strike.extra_attack_data.extra_attack_previous_attack_max_range_bonus = performing_player.strike_stat_boosts.max_range
	active_strike.extra_attack_data.extra_attack_state = ExtraAttackState.ExtraAttackState_PayCosts
	active_strike.extra_attack_data.extra_attack_hit = false

	# Other relevant passives that need to be undone.
	# If other extra attack characters are added, consider what else might be needed.
	# For example: If an extra attack character can have positive power bonus boosts, those need to be removed too.
	performing_player.strike_stat_boosts.ignore_armor = false
	performing_player.strike_stat_boosts.ignore_guard = false

	# Extra attacks are unaffected by the attack_does_not_hit effect from hitting Nirvana or the effect on Block.
	performing_player.strike_stat_boosts.attack_does_not_hit = false

	# This can happen with more After effects to resolve.
	# This should be fine as we use a different remaining effects list.
	# Also, nothing that uses active_strike.effects_resolved_in_timing should be active.
	# If a new timing is added for extra attacks, then more state may need to be preserved.
	active_strike.effects_resolved_in_timing = 0
	active_strike.extra_attack_data.extra_attack_remaining_effects = []

	# Remove the card from the hand, it is now in the striking area.
	# Notify via an event.
	performing_player.remove_card_from_hand(card_id, true, false)
	events.append(create_event(Enums.EventType.EventType_Strike_Started_ExtraAttack, performing_player.my_id, card_id, ""))

	var card_name = card_db.get_card_name(card_id)
	_append_log_full(Enums.LogType.LogType_Strike, performing_player, "performs an extra attack with %s." % [card_name])

	# Intentional events = because events are passed in.
	events = continue_resolve_strike(events)
	return events

func continue_extra_attack(events):
	change_game_state(Enums.GameState.GameState_Strike_Processing)

	var attacker_player = active_strike.extra_attack_data.extra_attack_player
	var attacker_card = active_strike.extra_attack_data.extra_attack_card
	var defender_player = _get_player(get_other_player(attacker_player.my_id))

	while true:
		if game_over:
			change_game_state(Enums.GameState.GameState_GameOver)
			break

		if game_state == Enums.GameState.GameState_PlayerDecision:
			var player_name = get_player_name(decision_info.player)
			printlog("EXTRA ATTACK: Pausing for decision %s %s" % [player_name, Enums.DecisionType.keys()[decision_info.type]])
			break

		printlog("EXTRA ATTACK: processing state %s " % [ExtraAttackState.keys()[active_strike.extra_attack_data.extra_attack_state]])
		match active_strike.extra_attack_data.extra_attack_state:
			ExtraAttackState.ExtraAttackState_PayCosts:
				# Ask player to pay for this card if applicable.
				events += ask_for_cost(attacker_player, attacker_card, ExtraAttackState.ExtraAttackState_DuringStrikeBonuses)
			ExtraAttackState.ExtraAttackState_DuringStrikeBonuses:
				events += do_effects_for_timing("during_strike", attacker_player, attacker_card, ExtraAttackState.ExtraAttackState_Activation, true)
			ExtraAttackState.ExtraAttackState_Activation:
				# Gain armor/guard from the card.
				attacker_player.strike_stat_boosts.armor += get_card_stat(attacker_player, attacker_card, "armor")
				attacker_player.strike_stat_boosts.guard += get_card_stat(attacker_player, attacker_card, "guard")
				# Do the attack starting at Before.
				active_strike.extra_attack_data.extra_attack_state = ExtraAttackState.ExtraAttackState_Before
				active_strike.extra_attack_data.extra_attack_remaining_effects = get_all_effects_for_timing("before", attacker_player, attacker_card, true, true)
			ExtraAttackState.ExtraAttackState_Before:
				events += do_remaining_effects(attacker_player, ExtraAttackState.ExtraAttackState_DetermineHit)
			ExtraAttackState.ExtraAttackState_DetermineHit:
				var hit = determine_if_attack_hits(events, attacker_player, defender_player, attacker_card)
				if hit:
					active_strike.extra_attack_data.extra_attack_hit = true
					active_strike.extra_attack_data.extra_attack_state = ExtraAttackState.ExtraAttackState_Hit
					active_strike.extra_attack_data.extra_attack_remaining_effects = get_all_effects_for_timing("hit", attacker_player, attacker_card, true, true)
				else:
					active_strike.extra_attack_data.extra_attack_state = ExtraAttackState.ExtraAttackState_After
					active_strike.extra_attack_data.extra_attack_remaining_effects = get_all_effects_for_timing("after", attacker_player, attacker_card, true, true)
			ExtraAttackState.ExtraAttackState_Hit:
				events += do_remaining_effects(attacker_player, ExtraAttackState.ExtraAttackState_Hit_Response)
			ExtraAttackState.ExtraAttackState_Hit_Response:
				var incoming_damage = calculate_damage(attacker_player, defender_player)
				events += do_hit_response_effects(attacker_player, defender_player, incoming_damage, ExtraAttackState.ExtraAttackState_Hit_ApplyDamage)
			ExtraAttackState.ExtraAttackState_Hit_ApplyDamage:
				events += apply_damage(attacker_player, defender_player)
				active_strike.extra_attack_data.extra_attack_state = ExtraAttackState.ExtraAttackState_After
				active_strike.extra_attack_data.extra_attack_remaining_effects = get_all_effects_for_timing("after", attacker_player, attacker_card, true, true)
				if game_over:
					active_strike.strike_state = ExtraAttackState.ExtraAttackState_Cleanup
			ExtraAttackState.ExtraAttackState_After:
				events += do_remaining_effects(attacker_player, ExtraAttackState.ExtraAttackState_Cleanup)
			ExtraAttackState.ExtraAttackState_Cleanup:
				active_strike.extra_attack_data.extra_attack_state = ExtraAttackState.ExtraAttackState_CleanupEffects
				active_strike.extra_attack_data.extra_attack_remaining_effects = get_all_effects_for_timing("cleanup", attacker_player, attacker_card, true, true)
			ExtraAttackState.ExtraAttackState_CleanupEffects:
				events += do_remaining_effects(attacker_player, ExtraAttackState.ExtraAttackState_Complete)
			ExtraAttackState.ExtraAttackState_Complete:
				var card_name = attacker_card.definition['display_name']
				if active_strike.extra_attack_data.extra_attack_hit or active_strike.extra_attack_data.extra_attack_always_go_to_gauge:
					_append_log_full(Enums.LogType.LogType_CardInfo, attacker_player, "adds their extra attack %s to gauge." % card_name)
					events += attacker_player.add_to_gauge(attacker_card)
				else:
					_append_log_full(Enums.LogType.LogType_CardInfo, attacker_player, "discards their extra attack %s." % card_name)
					events += attacker_player.add_to_discards(attacker_card)

				# Finally, resume the original strike (unless there was another extra attack to deal with).
				if game_over:
					change_game_state(Enums.GameState.GameState_GameOver)
				else:
					if active_strike.extra_attack_data.extra_attack_parent:
						active_strike.extra_attack_data = active_strike.extra_attack_data.extra_attack_parent
						# surely this won't change the attacking player
						attacker_card = active_strike.extra_attack_data.extra_attack_card
						continue
					else:
						active_strike.extra_attack_in_progress = false
						# Intentional events = because events are passed in.
						events = continue_resolve_strike(events)
				break
	return events

func determine_if_attack_hits(events, attacker_player : Player, defender_player : Player, card : GameCard):
	var card_name = card_db.get_card_name(card.id)
	if attacker_player.strike_stat_boosts.calculate_range_from_buddy:
		var buddy_location = attacker_player.get_buddy_location(attacker_player.strike_stat_boosts.calculate_range_from_buddy_id)
		var buddy_name = attacker_player.get_buddy_name(attacker_player.strike_stat_boosts.calculate_range_from_buddy_id)
		_append_log_full(Enums.LogType.LogType_Strike, null, "Range check: attacking from %s's %s (space %s) to %s (space %s)." % [attacker_player.name, buddy_name, buddy_location, defender_player.name, defender_player.arena_location])
	elif attacker_player.strike_stat_boosts.calculate_range_from_center:
		_append_log_full(Enums.LogType.LogType_Strike, null, "Range check: %s attacking from center of arena (space %s) to %s (space %s)." % [attacker_player.name, CenterArenaLocation, defender_player.name, defender_player.arena_location])
	else:
		_append_log_full(Enums.LogType.LogType_Strike, null, "Range check: attacking from %s (space %s) to %s (space %s)." % [attacker_player.name, attacker_player.arena_location, defender_player.name, defender_player.arena_location])

	if in_range(attacker_player, defender_player, card, true) and not card.definition['id'] in attacker_player.cards_that_will_not_hit:
		_append_log_full(Enums.LogType.LogType_Strike, attacker_player, "hits with %s!" % card_name)
		return true
	else:
		var extra_details = ""
		if card.definition['id'] in attacker_player.cards_that_will_not_hit:
			extra_details = "the named card "
		_append_log_full(Enums.LogType.LogType_Strike, attacker_player, "misses with %s%s!" % [extra_details, card_name])
		events.append(create_event(Enums.EventType.EventType_Strike_Miss, attacker_player.my_id, 0))
		return false

func do_topdeck_boost(events):
	# Unique case where we need to push all events to the queue, draw the top deck, and boost it.
	var performing_player = _get_player(active_strike.remaining_forced_boosts_player_id)
	performing_player.sustain_next_boost = active_strike.remaining_forced_boosts_sustaining
	active_strike.remaining_forced_boosts -= 1

	events += performing_player.draw(1, true)
	event_queue += events
	change_game_state(Enums.GameState.GameState_PlayerDecision)
	decision_info.type = Enums.DecisionType.DecisionType_BoostNow
	do_boost(performing_player, performing_player.hand[performing_player.hand.size()-1].id)

func do_discard_boost(events):
	# Unique case where we need to push all events to the queue, draw a card from the discard, and boost it.
	var performing_player = _get_player(active_strike.remaining_forced_boosts_player_id)
	performing_player.sustain_next_boost = active_strike.remaining_forced_boosts_sustaining
	active_strike.remaining_forced_boosts -= 1

	var boost_card_id = performing_player.get_top_continuous_boost_in_discard()
	events += performing_player.move_card_from_discard_to_hand(boost_card_id)
	event_queue += events
	change_game_state(Enums.GameState.GameState_PlayerDecision)
	decision_info.type = Enums.DecisionType.DecisionType_BoostNow
	do_boost(performing_player, boost_card_id)

func begin_resolve_boost(performing_player : Player, card_id : int):
	var events = []

	var new_boost = Boost.new()
	if active_boost:
		if active_strike:
			assert(false, "No current support for boosts that play other boosts mid-strike")
		new_boost.parent_boost = active_boost

	active_boost = new_boost
	active_boost.playing_player = performing_player
	active_boost.card = card_db.get_card(card_id)
	performing_player.remove_card_from_hand(card_id, true, false)
	performing_player.remove_card_from_gauge(card_id)
	performing_player.remove_card_from_discards(card_id)
	events += [create_event(Enums.EventType.EventType_Boost_Played, performing_player.my_id, card_id)]

	# Resolve all immediate/now effects
	# If continuous, put it into continous boost tracking.
	# Intentional events = because events are passed in.
	events = continue_resolve_boost(events)
	return events

func continue_resolve_boost(events):
	if game_state == Enums.GameState.GameState_WaitForStrike or game_state == Enums.GameState.GameState_Strike_Opponent_Set_First:
		active_boost.strike_after_boost = true
		if game_state == Enums.GameState.GameState_Strike_Opponent_Set_First:
			active_boost.strike_after_boost_opponent_first = true
	change_game_state(Enums.GameState.GameState_Boost_Processing)

	var effects = card_db.get_card_boost_effects_now_immediate(active_boost.card)
	var character_effects = active_boost.playing_player.get_on_boost_effects(active_boost.card)
	while true:
		if game_state == Enums.GameState.GameState_WaitForStrike or game_state == Enums.GameState.GameState_Strike_Opponent_Set_First:
			active_boost.strike_after_boost = true
			if game_state == Enums.GameState.GameState_Strike_Opponent_Set_First:
				active_boost.strike_after_boost_opponent_first = true

		if active_boost.effects_resolved < len(effects):
			var effect = effects[active_boost.effects_resolved]
			events += do_effect_if_condition_met(active_boost.playing_player, active_boost.card.id, effect, null)
			if game_state == Enums.GameState.GameState_PlayerDecision:
				break

			active_boost.effects_resolved += 1
		elif active_boost.effects_resolved < len(effects) + len(character_effects):
			# Resolve character effects.
			var character_effect_index = active_boost.effects_resolved - len(effects)
			var effect = character_effects[character_effect_index]
			events += do_effect_if_condition_met(active_boost.playing_player, active_boost.card.id, effect, null)
			if game_state == Enums.GameState.GameState_PlayerDecision:
				break

			active_boost.effects_resolved += 1
		elif active_boost.effects_resolved < len(effects) + len(character_effects) + 1:
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
			# Intentional events = because events are passed in.
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

		if performing_player.sustain_next_boost:
			performing_player.sustained_boosts.append(active_boost.card.id)
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "set and sustained %s as a continuous boost." % _get_boost_and_card_name(active_boost.card))
		else:
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "set %s as a continuous boost." % _get_boost_and_card_name(active_boost.card))
	else:
		if active_boost.seal_on_cleanup:
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "seals the boosted card %s." % active_boost.card.definition['display_name'])
			events += do_seal_effect(performing_player, active_boost.card.id, "")
		elif active_boost.card.id in active_boost.cleanup_to_gauge_card_ids:
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds the boosted card %s to gauge." % active_boost.card.definition['display_name'])
			events += performing_player.add_to_gauge(active_boost.card)
		elif active_boost.card.id in active_boost.cleanup_to_hand_card_ids:
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "returns the boosted card %s to hand." % active_boost.card.definition['display_name'])
			events += performing_player.add_to_hand(active_boost.card, true)
		else:
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards the boosted card %s." % active_boost.card.definition['display_name'])
			events += performing_player.add_to_discards(active_boost.card)

	performing_player.sustain_next_boost = false
	if game_state == Enums.GameState.GameState_WaitForStrike or game_state == Enums.GameState.GameState_Strike_Opponent_Set_First:
		active_boost.strike_after_boost = true
		if game_state == Enums.GameState.GameState_Strike_Opponent_Set_First:
			active_boost.strike_after_boost_opponent_first = true
	return events

func boost_play_cleanup(events, performing_player : Player):
	# Account for boosts that played other boosts
	if active_boost.parent_boost:
		# Pass on any relevant fields.
		active_boost.parent_boost.action_after_boost = active_boost.parent_boost.action_after_boost or active_boost.action_after_boost
		active_boost.parent_boost.strike_after_boost = active_boost.parent_boost.strike_after_boost or active_boost.strike_after_boost
		active_boost.parent_boost.strike_after_boost_opponent_first = active_boost.parent_boost.strike_after_boost_opponent_first or active_boost.strike_after_boost_opponent_first

		# Go back to the parent boost.
		active_boost = active_boost.parent_boost
		active_boost.effects_resolved += 1
		return continue_resolve_boost(events)

	var preparing_strike = false
	if performing_player.strike_on_boost_cleanup and not active_boost.strike_after_boost and not active_strike:
		if performing_player.wild_strike_on_boost_cleanup:
			var wild_effect = { "effect_type": "strike_wild" }
			events += handle_strike_effect(-1, wild_effect, performing_player)
		else:
			active_boost.strike_after_boost = true
			# event creation handled below
		active_character_action = false
		preparing_strike = true
		decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
		decision_info.player = performing_player.my_id
	performing_player.strike_on_boost_cleanup = false
	performing_player.wild_strike_on_boost_cleanup = false

	if active_boost.strike_after_boost and not active_strike:
		if active_boost.strike_after_boost_opponent_first:
			change_game_state(Enums.GameState.GameState_Strike_Opponent_Set_First)
		else:
			change_game_state(Enums.GameState.GameState_WaitForStrike)
			decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
			decision_info.player = performing_player.my_id
			if performing_player.next_strike_from_sealed:
				decision_info.source = "sealed"
				events += [create_event(Enums.EventType.EventType_Strike_FromGauge, performing_player.my_id, 0)]
			elif performing_player.next_strike_from_gauge:
				decision_info.source = "gauge"
				events += [create_event(Enums.EventType.EventType_Strike_FromGauge, performing_player.my_id, 0)]
			else:
				events += [create_event(Enums.EventType.EventType_ForceStartStrike, performing_player.my_id, 0)]
		active_boost = null
		preparing_strike = true
	elif active_boost.action_after_boost and not active_strike:
		_append_log_full(Enums.LogType.LogType_Action, performing_player, "takes an additional action!")
		events += [create_event(Enums.EventType.EventType_Boost_ActionAfterBoost, performing_player.my_id, 0)]
		change_game_state(Enums.GameState.GameState_PickAction)
		active_boost = null
	else:
		if active_strike:
			# If this strike is mid-before effects or mid-after effects, add this boost's effects to the list.
			# Assumption here is that you cannot add effects with a boost during your opponent's timing.
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
			var handled_weird_boost = false
			if active_strike.remaining_forced_boosts > 0:
				if active_strike.remaining_forced_boosts_source == "topdeck" and performing_player.deck.size() > 0:
					handled_weird_boost = true
					active_boost = null
					do_topdeck_boost(events)
					events = []
				elif active_strike.remaining_forced_boosts_source == "topdiscard":
					var boost_card_id = performing_player.get_top_continuous_boost_in_discard()
					if boost_card_id != -1:
						handled_weird_boost = true
						active_boost = null
						do_discard_boost(events)
						events = []

			if not handled_weird_boost:
				active_strike.remaining_forced_boosts = 0
				active_boost = null
				active_strike.effects_resolved_in_timing += 1
				# Intentional events = because events are passed in.
				events = continue_resolve_strike(events)
		else:
			active_boost = null
			if not preparing_strike and not active_overdrive:
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

	# Check if the player can generate force
	var force_needed = 1
	var player_location = performing_player.arena_location
	# If cornered, will need 2 force to get out
	# Left corner
	if performing_player.get_closest_occupied_space_to(MinArenaLocation) == MinArenaLocation:
		if performing_player.is_overlapping_opponent(player_location+1):
			force_needed = 2
	# Right corner
	elif performing_player.get_closest_occupied_space_to(MaxArenaLocation) == MaxArenaLocation:
		if performing_player.is_overlapping_opponent(player_location-1):
			force_needed = 2

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
	return gauge_available >= performing_player.get_exceed_cost()

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
	if performing_player.strike_action_disabled:
		return false
	# Can always wild swing!

	return true

func check_hand_size_advance_turn(performing_player : Player):
	var events = []
	if performing_player.bonus_actions > 0:
		change_game_state(Enums.GameState.GameState_PickAction)
		performing_player.bonus_actions -= 1
		if performing_player.bonus_actions == 0:
			_append_log_full(Enums.LogType.LogType_Action, performing_player, "takes an additional action!")
		else:
			_append_log_full(Enums.LogType.LogType_Action, performing_player, "takes an additional action! (%s left)" % performing_player.bonus_actions)
		events += [create_event(Enums.EventType.EventType_Boost_ActionAfterBoost, performing_player.my_id, performing_player.bonus_actions)]
	elif performing_player.dan_draw_choice and not active_dan_effect and not performing_player.skip_end_of_turn_draw:
		var choice_effect = {
			"effect_type": "choice",
			"choice": [
				{ "effect_type": "set_dan_draw_choice_INTERNAL", "from_bottom": false },
				{ "effect_type": "set_dan_draw_choice_INTERNAL", "from_bottom": true }
			]
		}
		events += handle_strike_effect(-1, choice_effect, performing_player)
		active_dan_effect = true
	else:
		if performing_player.skip_end_of_turn_draw:
			performing_player.skip_end_of_turn_draw = false
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "skips drawing for end of turn. Their hand size is %s." % len(performing_player.hand))
		else:
			var from_bottom_str = ""
			if active_dan_effect and performing_player.dan_draw_choice_from_bottom:
				events += performing_player.draw(1, false, true)
				from_bottom_str = " from bottom of deck"
			else:
				events += performing_player.draw(1)
			performing_player.did_end_of_turn_draw = true
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "draws %sfor end of turn. Their hand size is now %s." % [from_bottom_str, len(performing_player.hand)])

		active_dan_effect = false
		if len(performing_player.hand) > performing_player.max_hand_size:
			change_game_state(Enums.GameState.GameState_DiscardDownToMax)
			events += [create_event(Enums.EventType.EventType_HandSizeExceeded, performing_player.my_id, len(performing_player.hand) - performing_player.max_hand_size)]
		else:
			events += start_end_turn()
	return events

func do_prepare(performing_player) -> bool:
	printlog("MainAction: PREPARE by %s" % [performing_player.name])
	if not can_do_prepare(performing_player):
		printlog("ERROR: Tried to Prepare but can't.")
		return false

	var events : Array = []
	events += [create_event(Enums.EventType.EventType_Prepare, performing_player.my_id, 0)]
	_append_log_full(Enums.LogType.LogType_Action, performing_player, "Turn Action: Prepare")
	_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "draws a card.")
	events += performing_player.draw(1)
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
	_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards down to their max hand size: %s." % card_names)

	var events = performing_player.discard(card_ids)
	events += start_end_turn()

	event_queue += events
	return true

func do_reshuffle(performing_player : Player) -> bool:
	printlog("MainAction: RESHUFFLE by %s" % [performing_player.name])
	if not can_do_reshuffle(performing_player):
		printlog("ERROR: Tried to reshuffle but can't.")
		return false

	_append_log_full(Enums.LogType.LogType_Action, performing_player, "Turn Action: Manual Reshuffle")
	var events = performing_player.reshuffle_discard(true)
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
	var generated_force = performing_player.get_force_with_cards(card_ids, "MOVE", false)

	if generated_force < required_force:
		printlog("ERROR: Not enough force with these cards to move there.")
		return false

	var events = performing_player.discard(card_ids)
	var old_location = performing_player.arena_location
	events += performing_player.move_to(new_arena_location)
	var card_names = ""
	if card_ids.size() > 0:
		card_names = card_db.get_card_name(card_ids[0])
		for i in range(1, card_ids.size()):
			card_names += ", " + card_db.get_card_name(card_ids[i])
	else:
		card_names = "passive bonus"
	_append_log_full(Enums.LogType.LogType_Action, performing_player, "Turn Action: Move")
	if len(card_ids) > 0:
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "generates force to move by discarding %s." % card_names)
	_append_log_full(Enums.LogType.LogType_CharacterMovement, performing_player, "moves from space %s to %s." % [str(old_location), str(new_arena_location)])
	events += check_hand_size_advance_turn(performing_player)
	event_queue += events
	return true

func do_change(performing_player : Player, card_ids, treat_ultras_as_single_force : bool) -> bool:
	printlog("MainAction: CHANGE_CARDS by %s - %s" % [performing_player.name, card_ids])
	if not can_do_change(performing_player):
		printlog("ERROR: Cannot do change action for this player.")
		return false

	var has_card_from_gauge = false
	for id in card_ids:
		if performing_player.is_card_in_gauge(id):
			has_card_from_gauge = true

		if not performing_player.is_card_in_hand(id) and not performing_player.is_card_in_gauge(id):
			# Card not found, error
			printlog("ERROR: Tried to discard cards that aren't in hand or gauge.")
			return false

	var events = []
	events += [create_event(Enums.EventType.EventType_ChangeCards, performing_player.my_id, 0)]
	var force_generated = performing_player.get_force_with_cards(card_ids, "CHANGE_CARDS", treat_ultras_as_single_force)
	events += performing_player.discard(card_ids)

	# Handle Guile's Change Cards strike bonus
	var can_strike_after_change = false
	if performing_player.guile_change_cards_bonus and has_card_from_gauge and performing_player.exceeded:
		can_strike_after_change = true

	_append_log_full(Enums.LogType.LogType_Action, performing_player, "Turn Action: Change Cards")
	if len(card_ids) > 0:
		var card_names = card_db.get_card_names(card_ids)
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "generates force by discarding %s." % card_names)
	else:
		_append_log_full(Enums.LogType.LogType_Effect, performing_player, "generates %s force." % force_generated)
	_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "draws %s card(s)." % force_generated)
	events += performing_player.draw(force_generated)

	# Handle Guile's Exceed strike bonus
	# Otherwise just end the turn.
	if can_strike_after_change:
		# Need to give the player a choice to strike.
		events += handle_strike_effect(
			-1,
			{
				"effect_type": "choice",
				"choice": [
					{ "effect_type": "strike" },
					{ "effect_type": "pass" }
				]
			},
			performing_player
		)
		active_change_cards = true
	else:
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
	if len(card_ids) < performing_player.get_exceed_cost():
		printlog("ERROR: Tried to exceed with too few cards.")
		return false

	_append_log_full(Enums.LogType.LogType_Action, performing_player, "Turn Action: Exceed")
	var events = []
	if performing_player.has_overdrive:
		events += performing_player.move_cards_to_overdrive(card_ids, "gauge")
	else:
		var card_names = card_db.get_card_names(card_ids)
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "spends %s card(s) from gauge: %s" % [len(card_ids), card_names])
		events += performing_player.discard(card_ids)

	events += performing_player.exceed()
	if game_state == Enums.GameState.GameState_AutoStrike:
		# Draw the set aside card.
		var card = performing_player.get_set_aside_card(decision_info.effect_type)
		events += performing_player.add_to_hand(card, false)
		# Strike with it
		event_queue += events
		events = []
		change_game_state(Enums.GameState.GameState_PickAction)
		performing_player.next_strike_faceup = true
		do_strike(performing_player, card.id, false, -1)
	elif game_state != Enums.GameState.GameState_WaitForStrike and game_state != Enums.GameState.GameState_PlayerDecision:
		events += check_hand_size_advance_turn(performing_player)
	elif game_state == Enums.GameState.GameState_PlayerDecision:
		# Some other player action will result in the end turn finishing.
		# Striking is the end of an exceed so don't set this to true.
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

	var card = card_db.get_card(card_id)
	if not decision_info.ignore_costs:
		var force_cost = card.definition['boost']['force_cost']
		if not performing_player.can_pay_cost_with(payment_card_ids, force_cost, 0):
			printlog("ERROR: Tried to boost action but can't pay force cost with these cards.")
			return false

	if game_state == Enums.GameState.GameState_PickAction:
		_append_log_full(Enums.LogType.LogType_Action, performing_player, "Turn Action: Boost")
	_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "boosts %s." % _get_boost_and_card_name(card))

	var events = []
	if payment_card_ids.size() > 0:
		var card_names = card_db.get_card_name(payment_card_ids[0])
		for i in range(1, payment_card_ids.size()):
			card_names += ", " + card_db.get_card_name(payment_card_ids[i])
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards cards to pay for the boost: %s." % card_names)
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

	var ex_strike = ex_card_id != -1
	var strike_from_boosts = false
	if performing_player.next_strike_from_gauge:
		if not wild_strike and not performing_player.is_card_in_gauge(card_id):
			if not (game_state == Enums.GameState.GameState_Strike_Opponent_Set_First or performing_player.next_strike_random_gauge):
				printlog("ERROR: Tried to strike with a card not in gauge.")
				return false
		if ex_strike:
			printlog("ERROR: Tried to ex strike from gauge.")
			return false
	elif performing_player.next_strike_from_sealed:
		if not wild_strike and not performing_player.is_card_in_sealed(card_id):
			if not game_state == Enums.GameState.GameState_Strike_Opponent_Set_First:
				printlog("ERROR: Tried to strike with a card not in sealed.")
				return false
		if ex_strike:
			printlog("ERROR: Tried to ex strike from sealed.")
			return false
	else:
		if not wild_strike and not performing_player.is_card_in_hand(card_id):
			if performing_player.is_card_in_continuous_boosts(card_id):
				strike_from_boosts = true
				var card = card_db.get_card(card_id)
				if not 'must_set_from_boost' in card.definition or not card.definition['must_set_from_boost']:
					printlog("ERROR: Tried to strike with a card not in hand.")
					return false
				elif ex_strike:
					printlog("ERROR: Tried to EX strike from boost area.")
					return false
			elif not (game_state == Enums.GameState.GameState_Strike_Opponent_Set_First or performing_player.next_strike_random_gauge):
				printlog("ERROR: Tried to strike with a card not in hand.")
				return false
		if ex_strike and not performing_player.is_card_in_hand(ex_card_id):
			printlog("ERROR: Tried to strike with a ex card not in hand.")
			return false
	if ex_strike and not card_db.are_same_card(card_id, ex_card_id):
		printlog("ERROR: Tried to strike with a ex card that doesn't match.")
		return false

	# Begin the strike
	var events = []

	# Lay down the strike
	match game_state:
		Enums.GameState.GameState_PickAction, Enums.GameState.GameState_WaitForStrike:
			if not opponent_sets_first:
				initialize_new_strike(performing_player, opponent_sets_first)
				if game_state == Enums.GameState.GameState_PickAction:
					_append_log_full(Enums.LogType.LogType_Action, performing_player, "Turn Action: Strike")
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "initiates a strike!")

			if wild_strike:
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "wild swings!")
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
				elif performing_player.next_strike_from_sealed:
					performing_player.remove_card_from_sealed(card_id)
					performing_player.next_strike_from_sealed = false
				elif strike_from_boosts:
					performing_player.remove_from_continuous_boosts(card_db.get_card(card_id), "strike")
					active_strike.initiator_set_from_boosts = true
				else:
					performing_player.remove_card_from_hand(card_id, false, true)

				if ex_strike:
					_append_log_full(Enums.LogType.LogType_Strike, performing_player, "sets an EX attack!")
					active_strike.initiator_ex_card = card_db.get_card(ex_card_id)
					performing_player.remove_card_from_hand(ex_card_id, false, true)
				else:
					_append_log_full(Enums.LogType.LogType_Strike, performing_player, "sets their attack.")

			var reveal_immediately = false
			if active_strike.initiator.next_strike_faceup or strike_from_boosts:
				reveal_immediately = true
				active_strike.initiator_set_face_up = true
				active_strike.initiator.next_strike_faceup = false
				var card_name = card_db.get_card_name(card_id)
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "sets %s as a face-up attack!" % card_name)

			# Send the EX first as that is visual and logic is triggered off the regular one.
			if ex_strike:
				events += [create_event(Enums.EventType.EventType_Strike_Started_Ex, performing_player.my_id, ex_card_id, "", reveal_immediately)]
			events += [create_event(Enums.EventType.EventType_Strike_Started, performing_player.my_id, card_id, "", reveal_immediately, ex_strike)]
			# Intentional events = because events are passed in
			events = continue_setup_strike(events)

		Enums.GameState.GameState_Strike_Opponent_Set_First:
			if opponent_sets_first: # should always be true
				initialize_new_strike(performing_player, opponent_sets_first)
				var opponent_name = _get_player(get_other_player(performing_player.my_id)).name
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "initiates a strike! %s will set their attack first." % opponent_name)
				# Intentional events = because events are passed in.
				events = continue_setup_strike(events)

		Enums.GameState.GameState_Strike_Opponent_Response:
			if active_strike.waiting_for_reading_response:
				active_strike.waiting_for_reading_response = false
				# Reset effect counter due to reading card choice
				active_strike.effects_resolved_in_timing = 0

			if wild_strike:
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "wild swings!")
				events += performing_player.wild_strike()
				if game_over:
					event_queue += events
					return true
				card_id = active_strike.defender_card.id
			else:
				active_strike.defender_card = card_db.get_card(card_id)
				if strike_from_boosts:
					performing_player.remove_from_continuous_boosts(card_db.get_card(card_id), "strike")
					active_strike.defender_set_from_boosts = true
				else:
					performing_player.remove_card_from_hand(card_id, false, true)

				if ex_strike:
					_append_log_full(Enums.LogType.LogType_Strike, performing_player, "sets an EX attack!")
					active_strike.defender_ex_card = card_db.get_card(ex_card_id)
					performing_player.remove_card_from_hand(ex_card_id, false, true)
				else:
					_append_log_full(Enums.LogType.LogType_Strike, performing_player, "sets their attack.")
			# Send the EX first as that is visual and logic is triggered off the regular one.
			if ex_strike:
				events += [create_event(Enums.EventType.EventType_Strike_Response_Ex, performing_player.my_id, ex_card_id)]
			events += [create_event(Enums.EventType.EventType_Strike_Response, performing_player.my_id, card_id, "", strike_from_boosts, ex_strike)]
			# Intentional events = because events are passed in.
			events = continue_setup_strike(events)
	event_queue += events
	return true

func do_pay_strike_cost(performing_player : Player, card_ids : Array, wild_strike : bool, discard_ex_first : bool = true) -> bool:
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
		var gauge_cost = get_gauge_cost(performing_player, card)
		if performing_player.can_pay_cost(force_cost, gauge_cost):
			printlog("ERROR: Tried to wild strike when not allowed.")
			return false
	if decision_info.player != performing_player.my_id:
		printlog("ERROR: Tried to pay costs for wrong player.")
		return false

	var events = []
	if wild_strike:
		_append_log_full(Enums.LogType.LogType_Strike, performing_player, "chooses to wild swing instead of validating %s." % card.definition['display_name'])
		# Replace existing card with a wild strike
		var current_card = active_strike.get_player_card(performing_player)
		events += performing_player.invalidate_card(current_card)
		events += performing_player.wild_strike(true)
		var new_card = active_strike.get_player_card(performing_player)
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "wild swings %s!" % new_card.definition['display_name'])
	else:
		var force_cost = card.definition['force_cost']
		var gauge_cost = get_gauge_cost(performing_player, card)
		if performing_player.strike_stat_boosts.may_generate_gauge_with_force:
			# Convert the gauge cost to a force cost.
			force_cost = gauge_cost
			gauge_cost = 0

		if performing_player.can_pay_cost_with(card_ids, force_cost, gauge_cost):
			var card_names = ""
			if card_ids.size() > 0:
				card_names = card_db.get_card_name(card_ids[0])
				for i in range(1, card_ids.size()):
					card_names += ", " + card_db.get_card_name(card_ids[i])
			else:
				card_names = "passive bonus"
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "validates by discarding %s." % card_names)
			var where_to_discard = 0
			if not discard_ex_first and active_strike.get_player_ex_card(performing_player) != null:
				where_to_discard = 1
			events += performing_player.discard(card_ids, where_to_discard)

			if active_strike.extra_attack_in_progress:
				active_strike.extra_attack_data.extra_attack_state = ExtraAttackState.ExtraAttackState_DuringStrikeBonuses
			else:
				match active_strike.strike_state:
					StrikeState.StrikeState_Initiator_PayCosts:
						active_strike.strike_state = StrikeState.StrikeState_Defender_PayCosts
					StrikeState.StrikeState_Defender_PayCosts:
						active_strike.strike_state = StrikeState.StrikeState_DuringStrikeBonuses
		else:
			printlog("ERROR: Tried to pay costs but not correct cards.")
			return false
	# Intentional events = because events are passed in.
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

	var use_gauge_instead = decision_info.limitation == "gauge"
	var events = []
	if use_gauge_instead:
		for card_id in card_ids:
			if not performing_player.is_card_in_gauge(card_id):
				printlog("ERROR: Tried to force(gauge) for armor with card not in gauge.")
				return false
	else:
		for card_id in card_ids:
			if not performing_player.is_card_in_hand(card_id) and not performing_player.is_card_in_gauge(card_id):
				printlog("ERROR: Tried to force for armor with card not in hand or gauge.")
				return false

	var force_generated = 0
	if use_gauge_instead:
		force_generated = len(card_ids)
	else:
		force_generated = performing_player.get_force_with_cards(card_ids, "FORCE_FOR_ARMOR", false)

	if force_generated > 0:
		var card_names = ""
		if card_ids.size() > 0:
			card_names = card_db.get_card_name(card_ids[0])
			for i in range(1, card_ids.size()):
				card_names += ", " + card_db.get_card_name(card_ids[i])
		else:
			card_names = "passive bonus"
		if use_gauge_instead:
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "spends gauge for armor: %s." % card_names)
		else:
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards cards as force for armor: %s." % card_names)
		var armor_per_force = decision_info.amount
		events += performing_player.discard(card_ids)
		events += handle_strike_effect(decision_info.choice_card_id, {'effect_type': 'armorup', 'amount': force_generated * armor_per_force}, performing_player)
	# Intentional events = because events are passed in.
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
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "spends gauge to Cancel, discarding %s." % card_names)
		events += performing_player.discard(gauge_card_ids)
		events += performing_player.on_cancel_boost()
		active_boost.action_after_boost = true

	# Ky, for example, has a choice after canceling the first time.
	if game_state != Enums.GameState.GameState_PlayerDecision:
		# Intentional events = because events are passed in.
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
		for card_id in card_ids:
			var card_name = card_db.get_card_name(card_id)
			if decision_info.destination == "gauge":
				events += performing_player.move_card_from_hand_to_gauge(card_id)
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "moves a card (%s) from hand to gauge." % card_name)
			elif decision_info.destination == "topdeck":
				events += performing_player.move_card_from_hand_to_deck(card_id)
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "moves %s card(s) from hand to top of deck." % str(card_ids.size()))
			elif decision_info.destination == "deck":
				events += performing_player.shuffle_card_from_hand_to_deck(card_id)
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "shuffles %s card(s) from hand into deck." % str(card_ids.size()))
			else:
				assert(false, "Unknown destination for do_card_from_hand_to_gauge")

	set_player_action_processing_state()

	if decision_info.bonus_effect and card_ids.size() > 0:
		var per_card_effect = decision_info.bonus_effect.duplicate()
		per_card_effect['amount'] = card_ids.size() * per_card_effect['amount']
		events += handle_strike_effect(decision_info.choice_card_id, per_card_effect, performing_player)

	# Intentional events = because events are passed in.
	events = continue_player_action_resolution(events, performing_player)
	event_queue += events
	return true

func do_boost_name_card_choice_effect(performing_player : Player, card_id : int) -> bool:
	var card_name = "the card " + card_db.get_card_name(card_id)
	if card_id == -1:
		card_name = "a nonexistent card"
	printlog("SubAction: BOOST_NAME_CARD by %s; named %s" % [get_player_name(performing_player.my_id), card_name])
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
	_append_log_full(Enums.LogType.LogType_Effect, performing_player, "names %s." % card_name)
	set_player_action_processing_state()
	var events = handle_strike_effect(decision_info.choice_card_id, effect, performing_player)
	# Intentional events = because events are passed in.
	events = continue_player_action_resolution(events, performing_player)
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

	set_player_action_processing_state()

	if decision_info.type == Enums.DecisionType.DecisionType_ChooseSimultaneousEffect:
		if copying_effect:
			# If we're duplicating an effect, no need to remove it yet
			decision_info.effect_type = ""
		else:
			# This was the player choosing what to do next.
			# Remove this effect from the remaining effects.
			erase_remaining_effect(get_base_remaining_effect(effect))

	var events = do_effect_if_condition_met(performing_player, card_id, effect, null)
	# Intentional events = because events are passed in.
	events = continue_player_action_resolution(events, performing_player)
	event_queue += events
	return true

func set_player_action_processing_state():
	if active_start_of_turn_effects or active_end_of_turn_effects or active_overdrive or active_boost \
	or active_character_action or active_exceed or active_change_cards or active_dan_effect:
		game_state = Enums.GameState.GameState_Boost_Processing
	elif active_strike:
		game_state = Enums.GameState.GameState_Strike_Processing
	else:
		printlog("ERROR: Unexpected game state - no active thing to be resolving?")
		assert(false)

func continue_player_action_resolution(events, performing_player : Player):
	# This function is intended to be called at the end of the various do_* functions
	# that are called by the game wrapper to resolve player actions/decisions.

	# Handle the wacky forced boost cases (Faust/Platinum/Hazama),
	# then, if the player has a decision it just returns.
	# If they don't, call the appropriate continue/do_remaining function
	# depending on what is active.
	if game_state == Enums.GameState.GameState_PlayerDecision and decision_info.type == Enums.DecisionType.DecisionType_ForceBoostSustainTopdeck:
		# Handle stupid Faust case.
		do_topdeck_boost(events)
		events = []
	elif game_state == Enums.GameState.GameState_PlayerDecision and decision_info.type == Enums.DecisionType.DecisionType_ForceBoostSustainTopDiscard:
		do_discard_boost(events)
		events = []
	else:
		if game_state != Enums.GameState.GameState_PlayerDecision:
			if active_dan_effect:
				events += check_hand_size_advance_turn(performing_player)
			elif active_end_of_turn_effects:
				events += continue_end_turn()
			elif active_start_of_turn_effects:
				events += continue_begin_turn()
			elif active_overdrive:
				# Intentional events = because events are passed in.
				events = do_remaining_overdrive(events, performing_player)
			elif active_boost:
				active_boost.effects_resolved += 1
				# Intentional events = because events are passed in.
				events = continue_resolve_boost(events)
			elif active_strike:
				active_strike.effects_resolved_in_timing += 1
				# Intentional events = because events are passed in.
				events = continue_resolve_strike(events)
			elif active_character_action:
				events += do_remaining_character_action(performing_player)
			elif active_exceed:
				active_exceed = false
				if game_state != Enums.GameState.GameState_WaitForStrike:
					events += check_hand_size_advance_turn(performing_player)
			elif active_change_cards:
				active_change_cards = false
				if game_state != Enums.GameState.GameState_WaitForStrike:
					events += check_hand_size_advance_turn(performing_player)
			else:
				# End of turn states (pick action for next player or discard down for current) or strikes are expected.
				if game_state == Enums.GameState.GameState_PickAction or game_state == Enums.GameState.GameState_DiscardDownToMax or game_state == Enums.GameState.GameState_WaitForStrike:
					pass
				else:
					assert(false, "ERROR: Unexpected game state - no active action resolution")
	return events

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
	_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "mulligans %s card(s)." % str(len(card_ids)))
	if player.mulligan_complete and opponent.mulligan_complete:
		change_game_state(Enums.GameState.GameState_PickAction)
		_append_log_full(Enums.LogType.LogType_Default, _get_player(active_turn_player), "'s Turn Start!")
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
		performing_player.sustained_boosts.append(int(card_id))
		var boost_name = _get_boost_and_card_name(card_db.get_card(card_id))
		_append_log_full(Enums.LogType.LogType_Effect, performing_player, "sustains their continuous boost %s." % boost_name)

	set_player_action_processing_state()
	# Intentional events = because events are passed in.
	events = continue_player_action_resolution(events, performing_player)
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
			"special/ultra":
				if card.definition['type'] not in ["special", "ultra"]:
					printlog("ERROR: Tried to choose from discard with card that doesn't meet limitation special/ultra.")
					return false
			"continuous":
				if card.definition['boost']['boost_type'] != "continuous":
					printlog("ERROR: Tried to choose from discard with card that doesn't meet limitation continuous.")
					return false
			_:
				pass

	# Move the cards.
	var events = []
	var secret_zones = false
	for card_id in card_ids:
		var destination = decision_info.destination
		if decision_info.source == "discard":
			match destination:
				"deck":
					events += performing_player.move_card_from_discard_to_deck(card_id)
				"deck_noshuffle":
					events += performing_player.move_card_from_discard_to_deck(card_id, false)
				"gauge":
					events += performing_player.move_card_from_discard_to_gauge(card_id)
				"hand":
					events += performing_player.move_card_from_discard_to_hand(card_id)
				"lightningrod_any_space":
					# Bring this card to the top of the discard pile.
					# The discard_effect will place it as a lightning rod from there.
					performing_player.bring_card_to_top_of_discard(card_id)
				"overdrive":
					events += performing_player.move_cards_to_overdrive([card_id], "discard")
				"sealed":
					events += do_seal_effect(performing_player, card_id, "discard")
				"play_boost":
					# This effect currently is expected to put the discarded cards on top of the discard pile.
					# Then the discard_effect is expected to be boost_then_sustain_topdiscard.
					# Assumption that a character doing this doesn't have boosts that alter the discard pile.
					# If a character can put things into discard as a boost, then this could
					# be modified to use the bottom of the discard, or some other zone.
					performing_player.bring_card_to_top_of_discard(card_id)
				_:
					printlog("ERROR: Choose from discard destination not implemented.")
					assert(false, "Choose from discard destination not implemented.")
					return false

		elif decision_info.source == "sealed":
			match destination:
				"hand":
					events += performing_player.move_card_from_sealed_to_hand(card_id)
					secret_zones = performing_player.sealed_area_is_secret
				_:
					printlog("ERROR: Choose from sealed destination not implemented.")
					assert(false, "Choose from sealed destination not implemented.")
					return false

		elif decision_info.source == "overdrive":
			match destination:
				"discard":
					events += performing_player.discard([card_id])
				"hand":
					# Drop the discard event because we really just want the add to hand event.
					performing_player.discard([card_id])
					events += performing_player.move_card_from_discard_to_hand(card_id)
				_:
					printlog("ERROR: Choose from overdrive destination not implemented.")
					assert(false, "Choose from overdrive destination not implemented.")
					return false

		else:
			printlog("ERROR: Choose from discard source not implemented.")
			assert(false, "Choose from discard source not implemented.")
			return false

	var dest_name = decision_info.destination
	if dest_name == "deck":
		dest_name = "top of deck"
	var card_names = card_db.get_card_names(card_ids)
	if decision_info.destination == "play_boost":
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "plays %s from %s." % [card_names, decision_info.source])
	elif secret_zones:
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "moves %s card(s) from %s to %s." % [str(len(card_ids)), decision_info.source, dest_name])
	else:
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "moves card(s) from %s to %s: %s." % [decision_info.source, dest_name, card_names])

	set_player_action_processing_state()

	# Do any bonus effect.
	if decision_info.bonus_effect:
		var effect = decision_info.bonus_effect
		effect['discarded_card_ids'] = card_ids
		events += do_effect_if_condition_met(performing_player, decision_info.choice_card_id, effect, null)

	# Intentional events = because events are passed in.
	events = continue_player_action_resolution(events, performing_player)
	event_queue += events
	return true

func do_force_for_effect(performing_player : Player, card_ids : Array, treat_ultras_as_single_force : bool, cancel : bool = false) -> bool:
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

	var force_generated = performing_player.get_force_with_cards(card_ids, "FORCE_FOR_EFFECT", treat_ultras_as_single_force)
	if cancel:
		force_generated = 0
	var ultras = 0
	# If not treating ultras as a single force, count them
	# to allow overpaying.
	if not treat_ultras_as_single_force:
		for card_id in card_ids:
			var force_value = card_db.get_card_force_value(card_id)
			if force_value == 2:
				ultras += 1

	if performing_player.free_force > decision_info.effect['force_max']:
		if decision_info.effect['force_max'] == -1:
			force_generated += performing_player.free_force
		else:
			force_generated = decision_info.effect['force_max']

	if decision_info.effect['force_max'] != -1 and force_generated > decision_info.effect['force_max']:
		if force_generated - ultras <= decision_info.effect['force_max']:
			force_generated = decision_info.effect['force_max']
		else:
			printlog("ERROR: Tried to force for effect with too much force.")
			return false

	set_player_action_processing_state()
	if force_generated > 0:
		var card_names = ""
		if card_ids.size() > 0:
			card_names = card_db.get_card_name(card_ids[0])
			for i in range(1, card_ids.size()):
				card_names += ", " + card_db.get_card_name(card_ids[i])
		else:
			card_names = "passive bonus"

		var decision_effect = null
		var effect_times = 0
		if decision_info.effect['per_force_effect']:
			decision_effect = decision_info.effect['per_force_effect']
			effect_times = force_generated
			if force_generated > 0 and 'combine_multiple_into_one' in decision_effect and decision_effect['combine_multiple_into_one']:
				# This assumes this effect has no "and" effects.
				decision_effect = decision_effect.duplicate()
				decision_effect['amount'] = effect_times * decision_effect['amount']
				effect_times = 1
		elif decision_info.effect['overall_effect']:
			decision_effect = decision_info.effect['overall_effect']
			effect_times = 1

		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "generates force by discarding %s." % card_names)
		events += performing_player.discard(card_ids)
		for i in range(0, effect_times):
			events += handle_strike_effect(decision_info.choice_card_id, decision_effect, performing_player)

	# Intentional events = because events are passed in.
	events = continue_player_action_resolution(events, performing_player)
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
	if 'require_specific_card_id' in decision_info.effect:
		var required_card_id = decision_info.effect['require_specific_card_id']
		for card_id in card_ids:
			if card_db.get_card(card_id).definition['id'] != required_card_id:
				printlog("ERROR: Invalid card id selected for card-specific gauge for effect.")
				return false

	# Cap free gauge to the max gauge cost of the effect.
	var gauge_generated = min(performing_player.free_gauge, decision_info.effect['gauge_max'])
	gauge_generated += len(card_ids)

	if gauge_generated > decision_info.effect['gauge_max']:
		printlog("ERROR: Tried to gauge for effect with too many cards.")
		return false

	set_player_action_processing_state()

	if gauge_generated > 0:
		var card_names = ""
		if card_ids.size() > 0:
			card_names = card_db.get_card_name(card_ids[0])
			for i in range(1, card_ids.size()):
				card_names += ", " + card_db.get_card_name(card_ids[i])
		else:
			card_names = "passive bonus"

		var decision_effect = null
		var effect_times = 0
		if decision_info.effect['per_gauge_effect']:
			decision_effect = decision_info.effect['per_gauge_effect']
			effect_times = gauge_generated
			if gauge_generated > 0 and 'combine_multiple_into_one' in decision_effect and decision_effect['combine_multiple_into_one']:
				# This assumes this effect has no "and" effects.
				decision_effect = decision_effect.duplicate()
				decision_effect['amount'] = effect_times * decision_effect['amount']
				effect_times = 1
		elif decision_info.effect['overall_effect']:
			decision_effect = decision_info.effect['overall_effect']
			effect_times = 1

		var to_hand = 'spent_cards_to_hand' in decision_effect and decision_effect['spent_cards_to_hand']
		if to_hand:
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "returns card(s) from gauge to hand: %s." % card_names)
		else:
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "spends %s gauge, discarding %s." % [str(gauge_generated), card_names])

		# Move the spent cards to the right place.
		if to_hand:
			for card_id in card_ids:
				events += performing_player.move_card_from_gauge_to_hand(card_id)
		else:
			events += performing_player.discard(card_ids)
		for i in range(0, effect_times):
			events += handle_strike_effect(decision_info.choice_card_id, decision_effect, performing_player)

	if decision_info.bonus_effect:
		events += handle_strike_effect(decision_info.choice_card_id, decision_info.bonus_effect, performing_player)

	# Intentional events = because events are passed in.
	events = continue_player_action_resolution(events, performing_player)
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
	if not (decision_info.can_pass or amount == -1):
		if len(card_ids) != amount and performing_player.hand.size() >= amount:
			printlog("ERROR: Tried to choose to discard wrong number of cards.")
			return false

	for card_id in card_ids:
		if not performing_player.is_card_in_hand(card_id):
			printlog("ERROR: Tried to choose to discard with card not in hand.")
			return false
		if decision_info.limitation and not decision_info.limitation == "can_pay_cost" and not decision_info.limitation == "from_array":
			var card = card_db.get_card(card_id)
			if card.definition['type'] != decision_info.limitation:
				printlog("ERROR: Tried to choose to discard with card that doesn't meet limitation.")
				return false

	var skip_effect = false
	if len(card_ids) == 0:
		skip_effect = true

	var effect = {
		"effect_type": decision_info.effect_type,
		"card_ids": card_ids,
		"destination": decision_info.destination
	}
	if not skip_effect and decision_info.bonus_effect:
		effect['and'] = decision_info.bonus_effect

	var events = []
	set_player_action_processing_state()

	events += do_effect_if_condition_met(performing_player, decision_info.choice_card_id, effect, null)
	# Intentional events = because events are passed in.
	events = continue_player_action_resolution(events, performing_player)
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
	var action_name = "Character Action"
	if 'action_name' in action:
		action_name = action['action_name']
	_append_log_full(Enums.LogType.LogType_Action, performing_player, "Turn Action: %s" % action_name)
	# Spend the cards used to pay the cost.
	if card_ids.size() > 0:
		var card_names = card_db.get_card_name(card_ids[0])
		for i in range(1, card_ids.size()):
			card_names += ", " + card_db.get_card_name(card_ids[0])
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "pays for the action by discarding %s." % card_names)
		events += performing_player.discard(card_ids)

	# Do the character action effects.
	events += [create_event(Enums.EventType.EventType_CharacterAction, performing_player.my_id, 0)]
	performing_player.used_character_action = true
	var exceed_detail = "exceed" if performing_player.exceeded else "default"
	performing_player.used_character_action_details.append([exceed_detail, action_idx])
	remaining_character_action_effects = []
	active_character_action = true
	# Queue all current events and start a new events list.
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

	var action_name = "Special Action"
	if 'text' in chosen_action:
		action_name = chosen_action['text']
	_append_log_full(Enums.LogType.LogType_Action, performing_player, "Turn Action: %s" % action_name)

	# Handle the bonus action effects as a character action.
	remaining_character_action_effects = [chosen_action]
	active_character_action = true
	event_queue += continue_player_action_resolution([], performing_player)

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

	var leftover_card_ids = []
	for i in range(look_amount):
		var id = performing_player.deck[i].id
		if chosen_card_id != id:
			leftover_card_ids.append(id)

	var events = []
	var will_replace_leftovers = false
	if destination == "topdeck":
		will_replace_leftovers = true
	events += performing_player.draw(look_amount, false, false, not will_replace_leftovers)
	var leftover_card_names = card_db.get_card_names(leftover_card_ids)
	match destination:
		"discard":
			events += performing_player.discard(leftover_card_ids)
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards the unchosen cards: %s." % leftover_card_names)
		"topdeck":
			for card_id in leftover_card_ids:
				events += performing_player.move_card_from_hand_to_deck(card_id)
			performing_player.update_public_hand_if_deck_empty()
		_:
			printlog("ERROR: Choose from topdeck destination not implemented.")
			assert(false, "Choose from topdeck destination not implemented.")
			return false

	# If this effect came from a boost and another action is about to happen, cleanup that boost before continuing.
	set_player_action_processing_state()
	decision_info.action = action

	var did_strike_or_boost = false
	var real_actions = ["boost", "strike", "pass"]
	if action in real_actions and active_boost:
		active_boost.action_after_boost = true
		active_boost.effects_resolved += 1
		# Intentional events = because events are passed in.
		events = continue_resolve_boost(events)

	# Now the boost is done and we are in the pick action state.
	match action:
		"boost":
			event_queue += events
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.type = Enums.DecisionType.DecisionType_BoostNow
			do_boost(performing_player, chosen_card_id)
			did_strike_or_boost = true
		"strike":
			event_queue += events
			change_game_state(Enums.GameState.GameState_PickAction)
			do_strike(performing_player, chosen_card_id, false, -1)
			did_strike_or_boost = true
		"add_to_hand":
			# We've already drawn the cards we looked at
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds one of the cards to their hand.")
			event_queue += events
		"add_to_gauge":
			events += performing_player.move_card_from_hand_to_gauge(chosen_card_id)
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds one of the cards to gauge: %s." % card_db.get_card_name(chosen_card_id))
			event_queue += events
		"add_to_overdrive":
			events += performing_player.move_cards_to_overdrive([chosen_card_id], "hand")
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds one of the cards to overdrive: %s." % card_db.get_card_name(chosen_card_id))
			event_queue += events
		"add_to_sealed":
			events += do_seal_effect(performing_player, chosen_card_id, "hand")
			if performing_player.sealed_area_is_secret:
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds one of the cards to sealed facedown.")
			else:
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds one of the cards to sealed: %s." % card_db.get_card_name(chosen_card_id))
			event_queue += events
		"return_to_topdeck":
			assert(leftover_card_ids.size() == 1 or leftover_card_ids.size() == 0)
			# If this was the last card in deck, leftover_card_ids.size is 0, so this card goes on top.
			var destination_index = leftover_card_ids.size()
			events += performing_player.move_card_from_hand_to_deck(chosen_card_id, destination_index)
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds the remaining cards back to the top of their deck.")
			event_queue += events
		"add_to_topdeck_under":
			assert(leftover_card_ids.size() == 1 or leftover_card_ids.size() == 0)
			# If this was the last card in deck, leftover_card_ids.size is 0, so this card goes on top.
			var destination_index = leftover_card_ids.size()
			events += performing_player.move_card_from_hand_to_deck(chosen_card_id, destination_index)
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds the remaining cards back to the top of their deck.")
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
	else:
		# If this choose started a strike or boost, don't try to continue the player action resolution.
		if not did_strike_or_boost:
			# Came from somewhere else (maybe exceed or character action?)
			# Events were already queued earlier, so just pass in empty [] for the current events,
			# and use events =.
			events = continue_player_action_resolution([], performing_player)
			event_queue += events
	return true

func do_quit(player_id : Enums.PlayerId, reason : Enums.GameOverReason):
	printlog("InitialAction: QUIT by %s" % [get_player_name(player_id)])
	var performing_player = _get_player(player_id)
	_append_log_full(Enums.LogType.LogType_Default, performing_player, "left the game.")
	if game_state == Enums.GameState.GameState_GameOver:
		printlog("ERROR: Game already over.")
		return false

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

func do_match_result(_player_clock_remaining, _opponent_clock_remaining):
	return true
