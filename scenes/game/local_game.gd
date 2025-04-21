# This is the main game engine.
#
# Actions from either player are sent to this script via game_wrapper.gd.
# The wrapper protects the engine from having to care whether player inputs
# are from the local player, from a remote player, or were generated
# by the AI and then sent to game_wrapper.gd.

class_name LocalGame
extends Node2D

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
	"opponent_exceeded", "opponent_not_exceeded",
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
	"canceled_this_turn",
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
var active_prepare : bool = false
var active_overdrive_boost_top_discard_on_cleanup : bool = false
var active_change_cards : bool = false
var active_special_draw_effect : bool = false
var active_post_action_effect : bool = false
var active_start_of_turn_effects : bool = false
var active_end_of_turn_effects : bool = false
var remaining_overdrive_effects = []
var remaining_character_action_effects = []
var remaining_start_of_turn_effects = []
var remaining_end_of_turn_effects = []
var prepare_effects_resolved : int = 0
var post_action_effects_resolved : int = 0
var post_action_interruption : bool = false

var decision_info : DecisionInfo = DecisionInfo.new()
var active_boost : Boost = null

var game_state : Enums.GameState = Enums.GameState.GameState_NotStarted

var full_combat_log : Array = []

var image_loader : CardImageLoader
func _init(card_image_loader):
	image_loader = card_image_loader

func get_combat_log(log_type_filters):
	var filtered_log = full_combat_log.filter(func (item): return item['log_type'] in log_type_filters)
	var log_strings = filtered_log.map(_full_log_item_to_string)
	return "\n".join(log_strings)

func get_message_history() -> Array:
	return []

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

func _log_card_name(card_name):
	return "[color={_card_color}]%s[/color]" % card_name

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
	var facedown = card.definition['boost'].get("facedown")
	var boost_name = card.definition['boost']['display_name']
	if facedown:
		return _log_card_name("a facedown card")
	else:
		return _log_card_name("%s (%s)" % [boost_name, card_name])

func teardown():
	card_db.teardown()
	card_db.free()
	image_loader.free()
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

func create_event(
	event_type : Enums.EventType,
	event_player : Enums.PlayerId,
	num : int,
	reason: String = "",
	extra_info = null,
	extra_info2 = null,
	extra_info3 = null
):
	var card_name = card_db.get_card_name(num)
	var playerstr = "Player"
	if event_player == Enums.PlayerId.PlayerId_Opponent:
		playerstr = "Opponent"
	printlog("Event %s %s %d (card=%s)" % [Enums.EventType.keys()[event_type], playerstr, num, card_name])
	var new_event = {
		"event_name": Enums.EventType.keys()[event_type],
		"event_type": event_type,
		"event_player": event_player,
		"number": num,
		"reason": reason,
		"extra_info": extra_info,
		"extra_info2": extra_info2,
		"extra_info3": extra_info3,
	}
	event_queue.append(new_event)

func trigger_game_over(event_player : Enums.PlayerId, reason : Enums.GameOverReason):
	create_event(Enums.EventType.EventType_GameOver, event_player, reason)
	game_over = true
	game_over_winning_player = _get_player(get_other_player(event_player))
	change_game_state(Enums.GameState.GameState_GameOver)

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
	StrikeState_EndOfStrike,
	StrikeState_EndOfStrike_Player1Effects,
	StrikeState_EndOfStrike_Player1EffectsComplete,
	StrikeState_EndOfStrike_Player2Effects,
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
	var extra_attack_previous_attack_range_effects = []
	var extra_attack_state = ExtraAttackState.ExtraAttackState_None
	var extra_attack_hit = false
	var extra_attack_hit_response_state = {}
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
		extra_attack_previous_attack_range_effects = []
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
	var initiator_set_from_boost_space : int = -1
	var initiator_set_face_up : bool = false
	var defender_set_face_up : bool = false
	var defender_wild_strike : bool = false
	var defender_set_from_boosts : bool = false
	var defender_set_from_boost_space : int = -1
	var strike_state
	var hit_response_state : Dictionary = {}
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
	var queued_stop_on_space_boosts = []
	var cards_discarded_this_strike = 0

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
		if extra_attack_in_progress and performing_player == extra_attack_data.extra_attack_player:
			return extra_attack_data.extra_attack_card

		if performing_player == initiator:
			return initiator_card
		return defender_card

	func get_player_ex_card(performing_player : Player) -> GameCard:
		if extra_attack_in_progress and performing_player == extra_attack_data.extra_attack_player:
			return null

		if performing_player == initiator:
			return initiator_ex_card
		return defender_ex_card

	func get_player_wild_strike(performing_player : Player) -> bool:
		if extra_attack_in_progress and performing_player == extra_attack_data.extra_attack_player:
			return false

		if performing_player == initiator:
			return initiator_wild_strike
		return defender_wild_strike

	func get_player_strike_from_gauge(performing_player : Player) -> bool:
		if extra_attack_in_progress and performing_player == extra_attack_data.extra_attack_player:
			return false

		if performing_player == defender:
			return false
		# ensure that the strike from gauge wasn't invalidated
		return initiator_set_from_gauge and not initiator_wild_strike

	func get_player_set_from_boosts(performing_player : Player) -> bool:
		if extra_attack_in_progress and performing_player == extra_attack_data.extra_attack_player:
			return false

		# ensure that the strike from boosts wasn't invalidated
		if performing_player == initiator:
			return initiator_set_from_boosts and not initiator_wild_strike
		return defender_set_from_boosts and not defender_wild_strike

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
		if extra_attack_in_progress and performing_player == extra_attack_data.extra_attack_player:
			return false
		if performing_player.strike_stat_boosts.attack_copy_gauge_or_transform_becomes_ex:
			var player_card = get_player_card(performing_player)
			if performing_player.has_card_name_in_zone(player_card, "transform"):
				return true
			if performing_player.has_card_name_in_zone(player_card, "gauge"):
				return true

		for boost_card in performing_player.continuous_boosts:
			var effects = boost_card.definition['boost']['effects']
			for effect in effects:
				if effect['timing'] == 'during_strike' and effect['effect_type'] == "attack_is_ex":
					return true
		if performing_player.strike_stat_boosts.is_ex:
			return true
		if performing_player == initiator:
			return initiator_ex_card != null
		else:
			return defender_ex_card != null

class Boost:
	var playing_player : Player
	var card : GameCard
	var boosted_from_gauge = false
	var effects_resolved = 0
	var action_after_boost = false
	var strike_after_boost = false
	var strike_after_boost_opponent_first = false
	var discard_on_cleanup = false
	var shuffle_discard_on_cleanup = false
	var discarded_already = false
	var seal_on_cleanup = false
	var cancel_resolved = false
	var checked_counter = false
	var counters_resolved = 0
	var boost_negated = false
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
	var range_effects : Array = []
	var attack_does_not_hit : bool = false
	var only_hits_if_opponent_on_any_buddy : bool = false
	var cannot_go_below_life : int = 0
	var dodge_attacks : bool = false
	var dodge_at_range_min : Dictionary = {}
	var dodge_at_range_max : Dictionary = {}
	var dodge_at_range_late_calculate_with : String = ""
	var dodge_at_range_from_buddy : bool = false
	var dodge_at_speed_greater_or_equal : int = -1
	var dodge_from_opposite_buddy : bool = false
	var dodge_normals : bool = false
	var range_includes_opponent : bool = false
	var range_includes_if_moved_past : bool = false
	var range_includes_lightningrods : bool = false
	var attack_includes_ranges : Array = []
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
	var move_strike_to_transforms : bool = false
	var move_strike_to_opponent_boosts : bool = false
	var move_strike_to_opponent_gauge : bool = false
	var when_hit_force_for_armor : String = ""
	var stun_immunity : bool = false
	var was_hit : bool = false
	var is_ex : bool = false
	var higher_speed_misses : bool = false
	var calculate_range_from_space : int = -1
	var calculate_range_from_buddy : bool = false
	var calculate_range_from_buddy_id : String = ""
	var attack_to_topdeck_on_cleanup : bool = false
	var discard_attack_on_cleanup : bool = false
	var seal_attack_on_cleanup : bool = false
	var power_bonus_multiplier : int = 1
	var power_bonus_multiplier_positive_only : int = 1
	var powerup_per_sealed_amount_divisor : int = 0
	var powerup_per_sealed_amount_max : int = 0
	var speed_bonus_multiplier : int = 1
	var speedup_by_spaces_modifier : int = 0
	var speedup_per_boost_modifier : int = 0
	var speedup_per_boost_modifier_all_boosts : bool = false
	var speedup_per_unique_sealed_normals_modifier : int = 0
	var rangeup_min_per_boost_modifier : int = 0
	var rangeup_max_per_boost_modifier : int = 0
	var rangeup_min_if_ex_modifier : int = 0
	var rangeup_max_if_ex_modifier : int = 0
	var rangeup_per_boost_modifier_all_boosts : bool = false
	var guardup_if_copy_of_opponent_attack_in_sealed_modifier : int = 0
	var guardup_per_two_cards_in_hand : bool = false
	var guardup_per_gauge : bool = false
	var power_armor_up_if_sealed_or_transformed_copy_of_attack : bool = false
	var passive_powerup_per_card_in_hand : int = 0
	var passive_speedup_per_card_in_hand : int = 0
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
	var reduce_discard_effects_by : int = 0
	var increase_draw_effects_by : int = 0
	var swap_power_speed : bool = false
	var invert_range : bool = false
	var strike_payment_card_ids : Array = []
	var cap_attack_damage_taken : int = -1
	var attack_copy_gauge_or_transform_becomes_ex = false
	var repeat_printed_triggers_on_ex_attack : int = 0

	func _to_string():
		# TODO: Handle all properties
		var boosts = []
		if power or power_positive_only or power_modify_per_buddy_between:
			boosts.append("%+d%s POW" % [
					power, "*" if power_modify_per_buddy_between else ""])
		if armor:
			if consumed_armor:
				boosts.append("%+d/%d ARM" % [consumed_armor, armor])
			else:
				boosts.append("%+d ARM" % armor)
		boosts.append_array(active_character_effects)
		boosts.append_array(added_attack_effects)
		return "[%s]" % ", ".join(boosts)

	func clear():
		power = 0
		power_positive_only = 0
		power_modify_per_buddy_between = 0
		armor = 0
		consumed_armor = 0
		guard = 0
		speed = 0
		strike_x = 0
		range_effects = []
		attack_does_not_hit = false
		only_hits_if_opponent_on_any_buddy = false
		cannot_go_below_life = 0
		dodge_attacks = false
		dodge_at_range_min = {}
		dodge_at_range_max = {}
		dodge_at_range_late_calculate_with = ""
		dodge_at_range_from_buddy = false
		dodge_at_speed_greater_or_equal = -1
		dodge_normals = false
		dodge_from_opposite_buddy = false
		range_includes_opponent = false
		range_includes_if_moved_past = false
		range_includes_lightningrods = false
		attack_includes_ranges = []
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
		move_strike_to_transforms = false
		move_strike_to_opponent_boosts = false
		move_strike_to_opponent_gauge = false
		when_hit_force_for_armor = ""
		stun_immunity = false
		was_hit = false
		is_ex = false
		higher_speed_misses = false
		calculate_range_from_space = -1
		calculate_range_from_buddy = false
		calculate_range_from_buddy_id = ""
		attack_to_topdeck_on_cleanup = false
		discard_attack_on_cleanup = false
		seal_attack_on_cleanup = false
		power_bonus_multiplier = 1
		power_bonus_multiplier_positive_only = 1
		powerup_per_sealed_amount_divisor = 0
		powerup_per_sealed_amount_max = 0
		speed_bonus_multiplier = 1
		speedup_by_spaces_modifier = 0
		speedup_per_boost_modifier = 0
		speedup_per_boost_modifier_all_boosts = false
		speedup_per_unique_sealed_normals_modifier = 0
		rangeup_min_per_boost_modifier = 0
		rangeup_max_per_boost_modifier = 0
		rangeup_min_if_ex_modifier = 0
		rangeup_max_if_ex_modifier = 0
		rangeup_per_boost_modifier_all_boosts = false
		guardup_if_copy_of_opponent_attack_in_sealed_modifier = 0
		guardup_per_two_cards_in_hand = false
		guardup_per_gauge = false
		power_armor_up_if_sealed_or_transformed_copy_of_attack = false
		passive_powerup_per_card_in_hand = 0
		passive_speedup_per_card_in_hand = 0
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
		reduce_discard_effects_by = 0
		swap_power_speed = false
		invert_range = false
		strike_payment_card_ids = []
		cap_attack_damage_taken = -1
		attack_copy_gauge_or_transform_becomes_ex = false
		repeat_printed_triggers_on_ex_attack = 0

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
	var transforms : Array[GameCard]
	var lightningrod_zones : Array
	var underboost_map : Dictionary
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
	var total_force_spent_this_turn : int
	var force_spent_before_strike : int
	var gauge_spent_before_strike : int
	var gauge_spent_this_strike : int
	var gauge_cards_spent_this_strike : Array
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
	var draw_at_end_of_turn : int
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
	var movement_limit_optional_exceeded : bool
	var force_cost_reduction : int
	var free_force : int
	var free_force_cc_only : int
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
	var enchantress_draw_choice : bool
	var boost_id_locations : Dictionary # [card_id : int, location : int]
	var boost_buddy_card_id_to_buddy_id_map : Dictionary # [card_id : int, buddy_id : String]
	var stop_on_boost_space_ids : Array
	var effect_on_turn_start
	var strike_action_disabled : bool
	var face_attack_id : String
	var spend_life_for_force_amount : int
	var can_boost_from_gauge : bool
	var checked_post_action_effects : bool
	var seal_instead_of_discarding : bool
	var passive_effects : Dictionary
	var last_spent_life : int
	var opponent_next_strike_forced_wild_swing : bool
	var delayed_wild_strike : bool
	var invalid_card_moved_elsewhere : bool

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
			var image_atlas = deck_def['image_resources'][deck_card_def['image_name']]
			var image_index = deck_card_def['image_index']
			var card = GameCard.new(card_start_id, card_def, id, image_atlas, image_index)
			card_database.add_card(card)
			if 'set_aside' in deck_card_def and deck_card_def['set_aside']:
				card.set_aside = true
				card.hide_from_reference = 'hide_from_reference' in deck_card_def and deck_card_def['hide_from_reference']
				set_aside_cards.append(card)
			elif 'start_sealed' in deck_card_def and deck_card_def['start_sealed']:
				sealed.append(card)
				parent.create_event(Enums.EventType.EventType_Seal, my_id, card.id, "", false)
			else:
				deck.append(card)
			deck_list.append(card)
			card_start_id += 1
		gauge = []
		continuous_boosts = []
		transforms = []
		lightningrod_zones = []
		for i in range(MinArenaLocation, MaxArenaLocation + 1):
			lightningrod_zones.append([])
		underboost_map = {}
		discards = []
		overdrive = []
		sealed_area_is_secret = 'sealed_area_is_secret' in deck_def and deck_def['sealed_area_is_secret']
		has_overdrive = 'exceed_to_overdrive' in deck_def and deck_def['exceed_to_overdrive']
		reshuffle_remaining = MaxReshuffle
		exceeded = false
		did_end_of_turn_draw = false
		did_strike_this_turn = false
		checked_post_action_effects = false
		bonus_actions = 0
		canceled_this_turn = false
		cancel_blocked_this_turn = false
		used_character_action = false
		used_character_action_details = []
		used_character_bonus = false
		start_of_turn_strike = false
		force_spent_before_strike = 0
		gauge_spent_before_strike = 0
		gauge_spent_this_strike = 0
		gauge_cards_spent_this_strike = []
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
		force_cost_reduction = 0
		free_force = 0
		free_force_cc_only = 0
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
		enchantress_draw_choice = false
		boost_id_locations = {}
		boost_buddy_card_id_to_buddy_id_map = {}
		stop_on_boost_space_ids = []
		effect_on_turn_start = false
		strike_action_disabled = false
		face_attack_id = ""
		spend_life_for_force_amount = -1
		can_boost_from_gauge = false
		seal_instead_of_discarding = false
		passive_effects = {}
		last_spent_life = 0
		opponent_next_strike_forced_wild_swing = false
		delayed_wild_strike = false
		invalid_card_moved_elsewhere = false

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

		movement_limit_optional_exceeded = false
		if 'movement_limit_optional_exceeded' in deck_def:
			movement_limit_optional_exceeded = deck_def['movement_limit_optional_exceeded']

		max_hand_size = MaxHandSize
		if 'alt_hand_size' in deck_def:
			max_hand_size = deck_def['alt_hand_size']

		starting_hand_size_bonus = 0
		if 'bonus_starting_hand' in deck_def:
			starting_hand_size_bonus = deck_def['bonus_starting_hand']

		draw_at_end_of_turn = true
		if 'disable_end_of_turn_draw' in deck_def:
			draw_at_end_of_turn = not deck_def['disable_end_of_turn_draw']

		if 'buddy_starting_offset' in deck_def:
			buddy_starting_offset = deck_def['buddy_starting_offset']
			if 'buddy_starting_id' in deck_def:
				buddy_starting_id = deck_def['buddy_starting_id']

		if 'guile_change_cards_bonus' in deck_def:
			guile_change_cards_bonus = deck_def['guile_change_cards_bonus']

		if 'delayed_wild_strike' in deck_def:
			delayed_wild_strike = deck_def['delayed_wild_strike']

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
		if 'exceed_cost_reduced_by' in deck_def:
			for reduction_effect in deck_def['exceed_cost_reduced_by']:
				match reduction_effect["reduction_type"]:
					"in_arena_center":
						if arena_location == CenterArenaLocation:
							cost -= reduction_effect["amount"]
					"overdrive_count":
						cost -= len(overdrive)
					"transform_discount":
						cost -= 2 * len(transforms)
			cost = max(0, cost)
		return cost

	func get_replacement_boost_definition():
		return deck_def['replacement_boost_definition'].duplicate(true)

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
		if exceeded:
			return

		exceeded = true
		parent._append_log_full(Enums.LogType.LogType_Effect, self, "Exceeds!")
		parent.create_event(Enums.EventType.EventType_Exceed, my_id, 0)

		# check for weird mid-strike exceed effects
		if parent.active_strike:
			handle_mid_strike_exceed()

		if 'on_exceed' in deck_def:
			var effect = deck_def['on_exceed']
			parent.do_effect_if_condition_met(self, -1, effect, null)

	func handle_mid_strike_exceed():
		# Assumes that exceeding was due to a before/hit/after effect, and so set_strike/during_strike
		# effects have already been processed

		var base_effects = deck_def['ability_effects']
		var exceed_effects = deck_def['exceed_ability_effects']
		var attack_effects = parent.active_strike.get_player_card(self).definition["effects"]

		# need to revert certain default effects
		for ability_effect in base_effects:
			# Unwrap added effects
			if ability_effect['timing'] == "set_strike" and ability_effect['effect_type'] == "add_attack_effect":
				# If an effect was added by an action strike, it shouldn't be removed
				if 'condition' in ability_effect and ability_effect['condition'] == 'used_character_action':
					continue

				if parent.is_effect_condition_met(self, ability_effect, null):
					var character_effect_tag = 'character_effect' in ability_effect and ability_effect['character_effect']
					ability_effect = ability_effect['added_effect'].duplicate()
					ability_effect['character_effect'] = character_effect_tag

			if ability_effect['timing'] == "during_strike":
				if parent.is_effect_condition_met(self, ability_effect, null):
					_revert_strike_bonus_effect(ability_effect, -1, true)

		# Apply any permanent during_strike exceeds bonuses
		for exceed_ability_effect in exceed_effects:
			# Unwrap added effects
			if exceed_ability_effect['timing'] == "set_strike" and exceed_ability_effect['effect_type'] == "add_attack_effect":
				if parent.is_effect_condition_met(self, exceed_ability_effect, null):
					var character_effect_tag = 'character_effect' in exceed_ability_effect and exceed_ability_effect['character_effect']
					exceed_ability_effect = exceed_ability_effect['added_effect'].duplicate()
					exceed_ability_effect['character_effect'] = character_effect_tag

			if exceed_ability_effect['timing'] == "during_strike":
				parent.do_effect_if_condition_met(self, -1, exceed_ability_effect, null)

		# Check attack for exceed-conditioned during strike effects
		for attack_effect in attack_effects:
			if attack_effect['timing'] == "during_strike" and 'condition' in attack_effect and \
					attack_effect['condition'] == "exceeded":
				parent.do_effect_if_condition_met(self, -1, attack_effect, null)

	func revert_exceed():
		exceeded = false
		parent._append_log_full(Enums.LogType.LogType_Effect, self, "Reverts.")
		parent.create_event(Enums.EventType.EventType_ExceedRevert, my_id, 0)
		if 'on_revert' in deck_def:
			var effect = deck_def['on_revert']
			parent.handle_strike_effect(-1, effect, self)

	func mulligan(card_ids : Array):
		draw(len(card_ids))
		for id in card_ids:
			move_card_from_hand_to_deck(id)
		if ShuffleEnabled:
			random_shuffle_deck()
		parent.create_event(Enums.EventType.EventType_ReshuffleDeck_Mulligan, my_id, reshuffle_remaining)
		mulligan_complete = true

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

	func is_card_in_hand_match_normals(compare_card : GameCard):
		var is_normal = compare_card.definition['type'] == "normal"
		for card in hand:
			if card.id == compare_card.id:
				return true
			elif is_normal and card.definition['type'] == "normal":
				if card.definition['speed'] == compare_card.definition['speed']:
					return true
		return false

	func get_copy_in_hand_match_normals(compare_card : GameCard):
		var is_normal = compare_card.definition['type'] == "normal"
		for card in hand:
			if card.definition['id'] == compare_card.definition['id']:
				return card.id
			elif is_normal and card.definition['type'] == "normal":
				if card.definition['speed'] == compare_card.definition['speed']:
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

	func get_boosts(only_discardable : bool = false, include_placeholder_boosts : bool = false):
		var valid_boosts = []
		for boost in continuous_boosts:
			if not include_placeholder_boosts and boost.definition['boost'].get("placeholder_boost"):
				continue
			if only_discardable and boost.definition['boost'].get("cannot_discard"):
				continue
			valid_boosts.append(boost)
		return valid_boosts

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

	func remove_card_from_set_aside(id : int):
		for i in range(len(set_aside_cards)):
			if set_aside_cards[i].id == id:
				set_aside_cards.remove_at(i)
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
			if card_id not in get_card_ids_in_hand():
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

	func move_card_from_hand_to_deck(id : int, destination_index : int = 0, on_bottom : bool = false):
		for i in range(len(hand)):
			var card = hand[i]
			if card.id == id:
				var to_top_deck = false
				if on_bottom:
					deck.append(card)
				else:
					deck.insert(destination_index, card)
					to_top_deck = destination_index == 0

				if len(deck) == 1:
					to_top_deck = true
				hand.remove_at(i)
				on_hand_remove_secret_card()
				if to_top_deck:
					on_hand_track_topdeck(id)
					public_topdeck_id = -1
				parent.create_event(Enums.EventType.EventType_AddToDeck, my_id, card.id)
				break

	func move_card_from_hand_to_stored_cards(id : int, secret : bool):
		for i in range(len(hand)):
			var card = hand[i]
			if card.id == id:
				set_aside_cards.append(card)
				parent.create_event(Enums.EventType.EventType_AddToStored, my_id, card.id, "", secret)
				hand.remove_at(i)
				if secret:
					on_hand_remove_secret_card()
				else:
					on_hand_remove_public_card(id)
				break

	func move_card_from_hand_to_gauge(id : int):
		for i in range(len(hand)):
			var card = hand[i]
			if card.id == id:
				add_to_gauge(card)
				hand.remove_at(i)
				on_hand_remove_public_card(id)
				break

	func move_card_from_gauge_to_hand(id : int):
		for i in range(len(gauge)):
			var card = gauge[i]
			if card.id == id:
				add_to_hand(card, true)
				gauge.remove_at(i)
				break

	func move_card_from_gauge_to_sealed(id : int):
		for i in range(len(gauge)):
			var card = gauge[i]
			if card.id == id:
				add_to_sealed(card)
				gauge.remove_at(i)
				break

	func does_card_contain_range_to_opponent(card_id : int):
		var range_to_opponent = distance_to_opponent()
		var card = parent.card_db.get_card(card_id)
		var printed_min = parent.get_card_stat(self, card, 'range_min')
		var printed_max = parent.get_card_stat(self, card, 'range_max')
		var total_min = printed_min + get_total_min_range_bonus(card)
		var total_max = printed_max + get_total_max_range_bonus(card)
		if total_min <= range_to_opponent and total_max >= range_to_opponent:
			return true
		return false

	func get_lightningrod_zone_for_location(location : int):
		return lightningrod_zones[location - 1]

	func get_cards_under_boost(card_id : int):
		return underboost_map[card_id]

	func is_opponent_on_lightningrod():
		var other_player = parent._get_player(parent.get_other_player(my_id))
		for i in range(MinArenaLocation, MaxArenaLocation + 1):
			var lightningrod_zone = get_lightningrod_zone_for_location(i)
			if len(lightningrod_zone) > 0 and other_player.is_in_location(i):
				return true
		return false

	func place_top_discard_as_lightningrod(location : int):
		assert(len(discards) > 0, "Tried to place a card as a lightningrod when there are no discards.")
		if len(discards) > 0:
			var card = discards[len(discards) - 1]
			discards.remove_at(len(discards) - 1)
			var lightningrod_zone = get_lightningrod_zone_for_location(location)
			lightningrod_zone.append(card)
			parent.create_event(Enums.EventType.EventType_PlaceLightningRod, my_id, card.id, "", location, true)
			var card_name = parent.card_db.get_card_name(card.id)
			parent._append_log_full(Enums.LogType.LogType_Effect, self, "places %s as a Lightning Rod at location %s." % [parent._log_card_name(card_name), location])

	func remove_lightning_card(card_id : int, location : int):
		var lightningrod_zone = get_lightningrod_zone_for_location(location)
		for i in range(len(lightningrod_zone)):
			var card = lightningrod_zone[i]
			if card.id == card_id:
				lightningrod_zone.remove_at(i)
				return card
		return null

	func setup_boost_with_cards_under(boost_card_id : int):
		underboost_map[boost_card_id] = []
		parent.create_event(Enums.EventType.EventType_PlaceCardUnderBoost, my_id, boost_card_id, "", -1, true)

	func place_top_deck_under_boost(boost_card_id : int):
		if len(deck) > 0:
			var card = get_top_deck_card()
			deck.remove_at(0)
			public_topdeck_id = -1
			var underboost_cards = get_cards_under_boost(boost_card_id)
			underboost_cards.append(card)
			parent.create_event(Enums.EventType.EventType_PlaceCardUnderBoost, my_id, boost_card_id, "", card.id, true)
			var card_name = parent.card_db.get_card_name(boost_card_id)
			parent._append_log_full(Enums.LogType.LogType_Effect, self, "places the top card of their deck under %s." % parent._log_card_name(card_name))

	func remove_boost_with_cards_under(boost_card_id : int):
		underboost_map.erase(boost_card_id)
		parent.create_event(Enums.EventType.EventType_PlaceCardUnderBoost, my_id, boost_card_id, "", -1, false)

	func move_card_from_discard_to_deck(id : int, shuffle : bool = true):
		for i in range(len(discards)):
			var card = discards[i]
			if card.id == id:
				deck.insert(0, card)
				discards.remove_at(i)
				if shuffle:
					random_shuffle_deck()
				else:
					public_topdeck_id = id
				parent.create_event(Enums.EventType.EventType_AddToDeck, my_id, card.id)
				break

	func bring_card_to_top_of_discard(id : int):
		for i in range(len(discards)):
			var card = discards[i]
			if card.id == id:
				discards.remove_at(i)
				discards.append(card)
				break

	func shuffle_sealed_to_deck():
		var card_names = parent._card_list_to_string(sealed)
		if card_names:
			parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "shuffles their sealed area into their deck, containing %s." % parent._log_card_name(card_names))
		else:
			parent._append_log_full(Enums.LogType.LogType_Effect, self, "has no sealed cards to shuffle into their deck.")
		for card in sealed:
			deck.insert(0, card)
			parent.create_event(Enums.EventType.EventType_AddToDeck, my_id, card.id)
		random_shuffle_deck()
		sealed = []

	func shuffle_hand_to_deck():
		if len(hand) > 0:
			parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "shuffles their hand of %s card(s) into their deck." % len(hand))
		else:
			parent._append_log_full(Enums.LogType.LogType_Effect, self, "has no cards in hand to shuffle into their deck.")
		for card in hand:
			deck.insert(0, card)
			parent.create_event(Enums.EventType.EventType_AddToDeck, my_id, card.id)
		hand = []
		reset_public_hand_knowledge()
		random_shuffle_deck()

	func shuffle_card_from_hand_to_deck(id : int):
		for i in range(len(hand)):
			var card = hand[i]
			if card.id == id:
				deck.insert(0, card)
				hand.remove_at(i)
				on_hand_remove_secret_card()
				parent.create_event(Enums.EventType.EventType_AddToDeck, my_id, card.id)
				break
		random_shuffle_deck()

	func move_card_from_discard_to_gauge(id : int):
		for i in range(len(discards)):
			var card = discards[i]
			if card.id == id:
				add_to_gauge(card)
				discards.remove_at(i)
				break

	func move_card_from_discard_to_hand(id : int):
		for i in range(len(discards)):
			var card = discards[i]
			if card.id == id:
				add_to_hand(card, true)
				discards.remove_at(i)
				break

	func move_card_from_sealed_to_hand(id : int):
		for i in range(len(sealed)):
			var card = sealed[i]
			if card.id == id:
				add_to_hand(card, not sealed_area_is_secret)
				sealed.remove_at(i)
				break

	func move_card_from_sealed_to_top_deck(id : int):
		for i in range(len(sealed)):
			var card = sealed[i]
			if card.id == id:
				add_to_top_of_deck(card, not sealed_area_is_secret)
				sealed.remove_at(i)
				if sealed_area_is_secret:
					public_topdeck_id = -1
				else:
					public_topdeck_id = id
				break

	func remove_top_card_from_deck():
		deck.remove_at(0)
		update_public_hand_if_deck_empty()

	func add_top_deck_to_bottom():
		if deck.size() > 0:
			var card = deck[0]
			deck.append(card)
			deck.remove_at(0)
		parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "moves the top card of their deck to the bottom of their deck.")

	func add_top_deck_to_gauge(amount : int):
		for i in range(amount):
			if len(deck) > 0:
				var card = deck[0]
				add_to_gauge(card)
				remove_top_card_from_deck()
				on_hand_removed_topdeck(card.id)
				public_topdeck_id = -1

	func add_top_discard_to_gauge(amount : int, from_bottom : bool = false, destination : String = "gauge"):
		for i in range(amount):
			if len(discards) > 0:
				# The top of the discard pile is the end of discards.
				var top_index = len(discards) - 1
				if from_bottom:
					top_index = 0
				var card = discards[top_index]
				match destination:
					"gauge":
						add_to_gauge(card)
					"hand":
						add_to_hand(card, true)
				discards.remove_at(top_index)

	func add_top_discard_to_overdrive(amount : int):
		for i in range(amount):
			if len(discards) > 0:
				# The top of the discard pile is the end of discards.
				var top_index = len(discards) - 1
				var card = discards[top_index]
				move_cards_to_overdrive([card.id], "discard")

	func return_all_cards_gauge_to_hand():
		var card_names = parent._card_list_to_string(gauge)
		if card_names:
			parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "adds their gauge to their hand, containing %s." % parent._log_card_name(card_names))
		for card in gauge:
			add_to_hand(card, true)
		gauge = []

	func return_all_copies_of_top_discard_to_hand():
		var top_card = get_top_discard_card()
		if not top_card:
			return

		var all_card_ids = []
		for card in discards:
			if card.definition['id'] == top_card.definition['id']:
				all_card_ids.append(card.id)
		for id in all_card_ids:
			move_card_from_discard_to_hand(id)
		var card_names = parent.card_db.get_card_names(all_card_ids)
		parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "returns these cards to hand from discard: %s." % parent._log_card_name(card_names))

	func swap_deck_and_sealed():
		var current_sealed_ids = sealed.map(func(card) : return card.id)
		var current_deck_ids = deck.map(func(card) : return card.id)
		for card_id in current_deck_ids:
			parent.do_seal_effect(self, card_id, "deck", true)
		for card_id in current_sealed_ids:
			move_card_from_sealed_to_top_deck(card_id)
		parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "swaps their sealed cards and deck!")
		parent.create_event(Enums.EventType.EventType_SwapSealedAndDeck, my_id, 0)
		random_shuffle_deck()

	func has_passive(passive_name : String):
		return passive_name in passive_effects

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

	func get_count_of_type_from_zone(limitation : String, zone, unique_only : bool = false):
		var count = 0
		var seen_card_names = []
		for card in zone:
			if unique_only:
				if card.definition['id'] in seen_card_names:
					continue
				seen_card_names.append(card.definition['id'])
			match limitation:
				"normal":
					if card.definition['type'] == "normal":
						count += 1
				"special":
					if card.definition['type'] == "special":
						count += 1
				"ultra":
					if card.definition['type'] == "ultra":
						count += 1
				"normal/special":
					if card.definition['type'] == "normal" or card.definition['type'] == "special":
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

	func get_discard_count_of_type(limitation : String):
		return get_count_of_type_from_zone(limitation, discards)

	func get_gauge_count_of_type(limitation : String):
		return get_count_of_type_from_zone(limitation, gauge)

	func get_sealed_count_of_type(limitation : String, unique_only : bool = false):
		return get_count_of_type_from_zone(limitation, sealed, unique_only)

	func get_cards_in_hand_matching_types(types : Array):
		var cards = []
		for card in hand:
			if card.definition['type'] in types:
				cards.append(card)
		return cards

	func get_cards_in_hand_of_type(limitation : String, limitation_amount : int = 0):
		var cards = []
		for card in hand:
			match limitation:
				"normal":
					if card.definition['type'] == "normal":
						cards.append(card)
				"special":
					if card.definition['type'] == "special":
						cards.append(card)
				"ultra":
					if card.definition['type'] == "ultra":
						cards.append(card)
				"normal/special":
					if card.definition['type'] == "normal" or card.definition['type'] == "special":
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
					if can_pay_cost(force_cost, gauge_cost):
						cards.append(card)
				"last_drawn_cards":
					cards = hand.slice(-limitation_amount, hand.size())
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

	func movement_distance_between(initial_location : int, target_location : int, use_closest_location_to_opponent : bool = false):
		# By default, locations are calculated from the center of the character.
		# If use_closest_location_to_opponent is set, will instead use the closest point to the opponent (for range-based positioning).
		var other_player = parent._get_player(parent.get_other_player(my_id))
		var other_location = other_player.arena_location
		var other_width = other_player.extra_width

		var distance = abs(initial_location - target_location)
		if (initial_location < other_location and other_location < target_location) or (initial_location > other_location and other_location > target_location):
			if use_closest_location_to_opponent:
				# Account for the "closest location" changing
				distance += (2 * extra_width)
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

	func get_face_attack_card():
		if face_attack_id:
			return get_set_aside_card(face_attack_id)
		return null

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
		if not buddy_id:
			buddy_id = buddy_id_to_index.keys()[0]
		var old_buddy_pos = get_buddy_location(buddy_id)
		if parent.active_strike and old_buddy_pos == -1 and new_location != -1:
			# Buddy entering play.
			strike_stat_boosts.buddies_that_entered_play_this_strike.append(buddy_id)
		set_buddy_location(buddy_id, new_location)
		on_position_changed(arena_location, old_buddy_pos, false)
		parent.create_event(Enums.EventType.EventType_PlaceBuddy, my_id, get_buddy_location(buddy_id), description, buddy_id, silent, extra_offset)

	func remove_buddy(buddy_id : String, silent : bool = false):
		if not buddy_id:
			buddy_id = buddy_id_to_index.keys()[0]
		if not do_not_cleanup_buddy_this_turn:
			var old_buddy_pos = get_buddy_location(buddy_id)
			set_buddy_location(buddy_id, -1)
			on_position_changed(arena_location, old_buddy_pos, false)
			parent.create_event(Enums.EventType.EventType_PlaceBuddy, my_id, get_buddy_location(buddy_id), "", buddy_id, silent, false)

	func swap_buddy(buddy_id_to_remove : String, buddy_id_to_place : String, description : String):
		var location = get_buddy_location(buddy_id_to_remove)
		remove_buddy(buddy_id_to_remove, true)
		place_buddy(location, buddy_id_to_place, false, description)

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

	func add_boost_to_location(card_id : int, location : int, stop_on_space_effect : bool):
		assert(card_id not in boost_id_locations)
		var buddy_id = get_buddy_id_for_boost(card_id)
		boost_id_locations[card_id] = location
		boost_buddy_card_id_to_buddy_id_map[card_id] = buddy_id
		if stop_on_space_effect:
			stop_on_boost_space_ids.append(card_id)
		var extra_offset = buddy_id.ends_with("2")

		place_buddy(location, buddy_id, false, "", extra_offset)

	func change_boost_location(card_id : int, location : int):
		assert(card_id in boost_id_locations)
		var buddy_id = get_buddy_id_for_boost(card_id)
		boost_id_locations[card_id] = location
		var extra_offset = buddy_id.ends_with("2")

		place_buddy(location, buddy_id, false, "", extra_offset)

	func remove_boost_in_location(card_id : int):
		# Check if the id is in the dictionary, and if so remove it.
		if card_id in boost_id_locations:
			var buddy_id = get_buddy_id_for_boost(card_id)
			boost_id_locations.erase(card_id)
			boost_buddy_card_id_to_buddy_id_map.erase(card_id)
			if card_id in stop_on_boost_space_ids:
				stop_on_boost_space_ids.erase(card_id)
			remove_buddy(buddy_id)

	func play_replacement_boosts(card_ids : Array, replacement_boost):
		# Set active_overdrive to prevent the turn from ending after the boost.
		parent.active_overdrive = true
		for card_id in card_ids:
			var card : GameCard = parent.card_db.get_card(card_id)
			if replacement_boost:
				card.definition["replaced_boost"] = card.definition["boost"]
				card.definition["boost"] = replacement_boost

			# Prep gamestate so we can boost.
			parent.change_game_state(Enums.GameState.GameState_PlayerDecision)
			parent.decision_info.type = Enums.DecisionType.DecisionType_BoostNow
			parent.do_boost(self, card.id, [])
		parent.active_overdrive = false

	func get_force_with_cards(card_ids : Array, reason : String, treat_ultras_as_single_force : bool, use_free_force : bool):
		var force_generated = force_cost_reduction
		if use_free_force:
			force_generated += free_force
			if reason == "CHANGE_CARDS":
				force_generated += free_force_cc_only

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

	func get_force_from_spent_life(spent_life_for_force : int):
		if spend_life_for_force_amount > 0:
			return spent_life_for_force * spend_life_for_force_amount
		return 0

	func can_pay_cost_with(card_ids : Array, force_cost : int, gauge_cost : int, use_free_force : bool, spent_life_for_force : int, alternative_life_cost : int = 0):
		if alternative_life_cost and life > alternative_life_cost and card_ids.size() == 0:
			return true
		if force_cost and gauge_cost:
			# UNEXPECTED - NOT IMPLEMENTED
			assert(false)
		elif force_cost:
			var force_generated = get_force_with_cards(card_ids, "GENERIC_PAY_FORCE_COST", false, use_free_force)
			for card_id in card_ids:
				if not is_card_in_hand(card_id) and not is_card_in_gauge(card_id):
					assert(false)
					parent.printlog("ERROR: Card not in hand or gauge")
					return false
			if spent_life_for_force > life:
				return false
			force_generated += get_force_from_spent_life(spent_life_for_force)
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

	func can_pay_cost(force_cost : int, gauge_cost : int, alternative_life_cost : int = 0):
		if alternative_life_cost and life > alternative_life_cost:
			return true
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
			"discard": discards,
			"extra": set_aside_cards
		}

		for zone in valid_zones:
			for card in zone_map[zone]:
				if card.definition['boost']['boost_type'] in ["transform", "overload"] and limitation != "transform":
					continue

				var meets_limitation = true
				if limitation:
					if card.definition['boost']['boost_type'] == limitation or card.definition['type'] == limitation:
						meets_limitation = true
					else:
						meets_limitation = false
				if not meets_limitation:
					continue

				if limitation == "transform" and has_card_name_in_zone(card, "transform"):
					continue

				if ignore_costs:
					return true
				var force_available_when_boosting_this = force_available - parent.card_db.get_card_force_value(card.id)
				var cost = parent.card_db.get_card_boost_force_cost(card.id)
				if force_available_when_boosting_this >= cost:
					return true
		return false

	func has_card_name_in_zone(card : GameCard, zone : String):
		var zone_cards = []
		match zone:
			"boost":
				zone_cards = continuous_boosts
			"discard":
				zone_cards = discards
			"gauge":
				zone_cards = gauge
			"gauge_spent":
				zone_cards = gauge_cards_spent_this_strike
			"hand":
				zone_cards = hand
			"sealed":
				zone_cards = sealed
			"transform":
				zone_cards = transforms
		for check_card in zone_cards:
			if check_card.definition['display_name'] == card.definition['display_name']:
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

	func can_ex_strike_with_something():
		if has_ex_boost():
			return true

		var card_ids_in_hand = []
		var has_normal = false
		var has_overload = false
		for card in hand:
			if card.definition['id'] in card_ids_in_hand:
				return true
			card_ids_in_hand.append(card.definition['id'])

			if card.definition['type'] == "normal":
				has_normal = true
			if card.definition['boost']['boost_type'] == "overload":
				has_overload = true
			if has_normal and has_overload:
				return true
		return false

	func has_ex_boost():
		# May need more thorough effect scanning if anyone other than Byakuya uses this
		for card in continuous_boosts:
			for effect in card.definition['boost']['effects']:
				if effect['effect_type'] == "attack_is_ex":
					return true
		return false

	func get_bonus_actions():
		var actions = parent.get_boost_effects_at_timing("action", self)
		var other_player = parent._get_player(parent.get_other_player(my_id))
		actions += parent.get_boost_effects_at_timing("opponent_action", other_player)

		var usable_actions = []
		for action in actions:
			if not action.get("condition") or parent.is_effect_condition_met(self, action, null):
				usable_actions.append(action)
		return usable_actions

	func get_character_action(i : int = 0) -> Variant:
		if i >= get_character_action_count():
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
		if 'can_boost_ultra_boost_from_gauge' in action and action['can_boost_ultra_boost_from_gauge']:
			if not can_boost_something(['gauge'], 'ultra'): return false

		if 'min_hand_size' in action:
			var types = action.get("min_hand_size_types", ["normal", "special", "ultra"])
			var count = 0
			for card in hand:
				if card.definition['type'] in types:
					count += 1
			if count < action['min_hand_size']: return false

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

	func get_extra_strike_option(i : int = 0) -> Variant:
		var effects = parent.get_all_effects_for_timing(
			"extra_strike_option",
			self,
			null,
			false
		)
		if i >= effects.size():
			return null

		# Add a card to the effect.
		var effect = effects[i]
		match effect["effect_type"]:
			"strike_with_buddy_card":
				# This effect assumes there is 1 card in the set aside zone.
				if set_aside_cards.size() == 0:
					return null
				var card = set_aside_cards[0]
				var card_name = parent.card_db.get_card_name(card.id)
				effect["card_name"] = card_name

		return effect

	func get_extra_strike_options_count():
		var effects = parent.get_all_effects_for_timing(
			"extra_strike_option",
			self,
			null,
			false
		)
		return effects.size()

	func draw(num_to_draw : int, is_fake_draw : bool = false, from_bottom: bool = false, update_if_empty : bool = true):
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
			var draw_finished = false
			while not draw_finished:
				if from_bottom:
					draw_from_index = len(deck)-1

				if len(deck) > 0:
					var card = deck[draw_from_index]
					hand.append(card)
					deck.remove_at(draw_from_index)
					if draw_from_index == 0:
						on_hand_removed_topdeck(card.id)
					parent.create_event(Enums.EventType.EventType_Draw, my_id, card.id)
					draw_finished = true
				else:
					reshuffle_discard(false)
					if parent.game_over:
						draw_finished = true

			if update_if_empty:
				update_public_hand_if_deck_empty()

	func add_set_aside_card_to_deck(card_str_id : String):
		var card = get_set_aside_card(card_str_id, true)
		if card:
			deck.insert(0, card)
			public_topdeck_id = card.id

	func get_unknown_cards():
		var unknown_cards = hand + deck
		if sealed_area_is_secret:
			unknown_cards += sealed
		for card in continuous_boosts:
			if card.definition['boost'].get("facedown"):
				unknown_cards.append(card)
		if parent.active_strike:
			var strike_card = parent.active_strike.get_player_card(self)
			if strike_card:
				unknown_cards.append(strike_card)
			var strike_ex_card = parent.active_strike.get_player_ex_card(self)
			if strike_ex_card:
				unknown_cards.append(strike_ex_card)
		unknown_cards.sort_custom(func(c1, c2) : return c1.id < c2.id)
		return unknown_cards

	func get_stored_zone_name():
		var zone_info = deck_def.get("stored_zone_info")
		if not zone_info:
			return "Set Aside"
		if exceeded:
			zone_info = deck_def["stored_zone_info_exceeded"]
		return zone_info["name"]

	func is_stored_zone_facedown():
		var zone_info = deck_def.get("stored_zone_info")
		if not zone_info:
			return false
		if exceeded:
			zone_info = deck_def["stored_zone_info_exceeded"]
		return zone_info["facedown"]

	func reshuffle_discard(manual : bool, free : bool = false):
		if reshuffle_remaining == 0 and not free:
			# Game Over
			parent._append_log_full(Enums.LogType.LogType_Default, self, "is out of cards!")
			parent.trigger_game_over(my_id, Enums.GameOverReason.GameOverReason_Decked)
		else:
			# Reveal and remember remaining cards
			var unknown_cards = get_unknown_cards()
			var card_names = parent._card_list_to_string(unknown_cards)
			if card_names == "":
				parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "reshuffles.")
			else:
				parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "reshuffles with remaining cards: %s." % parent._log_card_name(card_names))

			# Put discard into deck, shuffle, subtract reshuffles
			deck += discards
			discards = []
			random_shuffle_deck()
			if not free:
				reshuffle_remaining -= 1
			parent.create_event(Enums.EventType.EventType_ReshuffleDiscard, my_id, reshuffle_remaining, "", unknown_cards)
			var local_conditions = LocalStrikeConditions.new()
			local_conditions.manual_reshuffle = manual
			var effects = get_character_effects_at_timing("on_reshuffle")
			for effect in effects:
				parent.do_effect_if_condition_met(self, -1, effect, local_conditions)

	func discard(card_ids : Array, from_top : int = 0, count_as_spent : bool = false):
		var spent_any_gauge = false
		for discard_id in card_ids:
			var found_card = false

			# From hand
			for i in range(len(hand)-1, -1, -1):
				var card = hand[i]
				if card.id == discard_id:
					hand.remove_at(i)
					add_to_discards(card, from_top)
					on_hand_remove_public_card(discard_id)
					found_card = true
					break
			if found_card: continue

			# From gauge
			for i in range(len(gauge)-1, -1, -1):
				var card = gauge[i]
				if card.id == discard_id:
					gauge.remove_at(i)
					if count_as_spent:
						spent_any_gauge = true
						if parent.active_strike:
							gauge_spent_this_strike += 1
							gauge_cards_spent_this_strike.append(card)
					add_to_discards(card, from_top)
					found_card = true
					break

			if found_card: continue

			# From overdrive
			for i in range(len(overdrive)-1, -1, -1):
				var card = overdrive[i]
				if card.id == discard_id:
					overdrive.remove_at(i)
					add_to_discards(card, from_top)
					found_card = true
					break

			# From deck
			for i in range(len(deck)-1, -1, -1):
				var card = deck[i]
				if card.id == discard_id:
					deck.remove_at(i)
					add_to_discards(card, from_top)
					if i == 0:
						public_topdeck_id = -1
					found_card = true
					break

			# From set aside
			for i in range(len(set_aside_cards)-1, -1, -1):
				var card = set_aside_cards[i]
				if card.id == discard_id:
					set_aside_cards.remove_at(i)
					add_to_discards(card, from_top)
					found_card = true
					break

			if not found_card:
				assert(false, "ERROR: card to discard not found")


		if spent_any_gauge:
			var on_spend_gauge_effects = parent.get_all_effects_for_timing("on_spend_gauge", self, null)
			# Assumption: No choices at this timing.
			for effect in on_spend_gauge_effects:
				parent.do_effect_if_condition_met(self, effect['card_id'], effect, null)

	func move_cards_to_overdrive(card_ids : Array, source : String):
		var opposing_player = parent._get_player(parent.get_other_player(my_id))
		var card_names = parent.card_db.get_card_names(card_ids)
		if card_names:
			var friendly_source = source
			if source == "opponent_discard":
				friendly_source = "opponent's discard"
			parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "moves cards from %s to overdrive: %s." % [friendly_source, parent._log_card_name(card_names)])
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
					add_to_overdrive(card)
					break

	func add_to_overdrive(card : GameCard):
		overdrive.append(card)
		return [parent.create_event(Enums.EventType.EventType_AddToOverdrive, my_id, card.id)]

	func seal_from_location(card_id : int, source : String, silent : bool = false):
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
				parent.create_event(Enums.EventType.EventType_Seal, my_id, card.id, "", not silent)
				break

	func seal_discard():
		var card_ids = []
		for card in discards:
			card_ids.append(card.id)
		var card_names = parent.card_db.get_card_names(card_ids)
		if card_names:
			if sealed_area_is_secret:
				parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "seals their discards face-down.")
			else:
				parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "seals their discards, containing %s." % parent._log_card_name(card_names))
		for card_id in card_ids:
			parent.do_seal_effect(self, card_id, "discard")

	func seal_hand():
		var card_ids = []
		for card in hand:
			card_ids.append(card.id)
		var card_names = parent.card_db.get_card_names(card_ids)
		if card_names:
			if sealed_area_is_secret:
				parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "seals their hand face-down.")
			else:
				parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "seals their hand, containing %s." % parent._log_card_name(card_names))
		for card_id in card_ids:
			parent.do_seal_effect(self, card_id, "hand")

	func discard_hand():
		var card_ids = []
		for card in hand:
			card_ids.append(card.id)
		var card_names = parent.card_db.get_card_names(card_ids)
		if card_names:
			parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "discards their hand, containing %s." % parent._log_card_name(card_names))
		discard(card_ids)
		reset_public_hand_knowledge()

	func discard_gauge():
		for i in range(len(gauge)-1, -1, -1):
			var card = gauge[i]
			gauge.remove_at(i)
			add_to_discards(card)

	func add_hand_to_gauge():
		var card_ids = []
		for card in hand:
			card_ids.append(card.id)
		var card_names = parent.card_db.get_card_names(card_ids)
		if card_names:
			parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "adds their hand to gauge, containing %s." % parent._log_card_name(card_names))
		for card_id in card_ids:
			move_card_from_hand_to_gauge(card_id)

	func discard_matching_or_reveal(card_definition_id : String, discard_all_copies : bool = false, skip_reveal : bool = false):
		var cards_to_discard = []
		for card in hand:
			if card.definition['id'] == card_definition_id:
				cards_to_discard.append(card)
				if not discard_all_copies:
					break

		if cards_to_discard:
			parent._append_log_full(Enums.LogType.LogType_Effect, self, "has the named card!")
			for card in cards_to_discard:
				var card_name = parent.card_db.get_card_name(card.id)
				parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "discards %s." % parent._log_card_name(card_name))
				discard([card.id])
			return

		# Not found
		if not skip_reveal:
			parent._append_log_full(Enums.LogType.LogType_Effect, self, "does not have the named card.")
			reveal_hand()

	func discard_topdeck():
		if deck.size() > 0:
			var card = deck[0]
			var card_name = parent.card_db.get_card_name(card.id)
			parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "discards the top card of their deck: %s." % parent._log_card_name(card_name))
			remove_top_card_from_deck()
			on_hand_removed_topdeck(card.id)
			public_topdeck_id = -1
			add_to_discards(card)

	func seal_topdeck():
		if deck.size() > 0:
			var card = deck[0]
			var card_name = parent.card_db.get_card_name(card.id)
			if sealed_area_is_secret:
				parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "seals the top card of their deck facedown.")
			else:
				parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "seals the top card of their deck: %s." % parent._log_card_name(card_name))
				on_hand_removed_topdeck(card.id)
			parent.do_seal_effect(self, card.id, "deck")

	func can_see_topdeck():
		return has_passive("topdeck_visible_to_self")

	func get_seen_topdeck():
		if can_see_topdeck():
			if deck.size() > 0:
				return deck[0].id
		return -1

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
		var card_names = parent._card_list_to_string(hand)
		if card_names == "":
			parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "reveals their empty hand.")
		else:
			parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "reveals their hand: %s." % parent._log_card_name(card_names))
		parent.create_event(Enums.EventType.EventType_RevealHand, my_id, 0)
		reset_public_hand_knowledge()
		for card in hand:
			on_hand_add_public_card(card.id)

	func reveal_hand_and_topdeck():
		reveal_hand()
		reveal_topdeck()

	func reveal_topdeck(reveal_to_both : bool = false):
		if deck.size() == 0:
			parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "has no cards in their deck to reveal.")
			return

		var card_name = parent.card_db.get_card_name(deck[0].id)
		if self == parent.player and not reveal_to_both:
			parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "reveals the top card of their deck to the opponent.")
		else:
			parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "reveals the top card of their deck: %s." % parent._log_card_name(card_name))
			public_topdeck_id = deck[0].id
		parent.create_event(Enums.EventType.EventType_RevealTopDeck, my_id, deck[0].id)

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
		var discarded_ids = []
		for i in range(amount):
			if len(hand) > 0:
				var random_card_id = hand[parent.get_random_int() % len(hand)].id
				discarded_ids.append(random_card_id)
				discard([random_card_id])
		var discarded_names = parent.card_db.get_card_names(discarded_ids)
		if discarded_names:
			parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "discards random card(s): %s." % parent._log_card_name(discarded_names))

	func spend_life(amount):
		life -= amount
		last_spent_life = amount
		parent.create_event(Enums.EventType.EventType_Strike_TookDamage, my_id, amount, "spend", life)
		parent._append_log_full(Enums.LogType.LogType_Health, self, "spends %s life, bringing them to %s!" % [str(amount), str(life)])
		if life <= 0:
			parent._append_log_full(Enums.LogType.LogType_Default, self, "has no life remaining!")
			parent.on_death(self)
		if not parent.game_over:
			var on_spend_life_effects = parent.get_all_effects_for_timing("on_spend_life", self, null)
			# Assumption: No choices at this timing.
			for effect in on_spend_life_effects:
				parent.do_effect_if_condition_met(self, effect["card_id"], effect, null)

	func invalidate_card(card : GameCard, invalid_by_choice : bool = false):
		invalid_card_moved_elsewhere = false
		var local_conditions = LocalStrikeConditions.new()
		if 'on_invalid' in card.definition:
			local_conditions.invalid_by_choice = invalid_by_choice

			var invalid_effect = card.definition['on_invalid']
			parent.do_effect_if_condition_met(self, -1, invalid_effect, local_conditions)
		if not invalid_card_moved_elsewhere:
			if 'on_invalid_add_to_gauge' in card.definition and card.definition['on_invalid_add_to_gauge']:
				add_to_gauge(card)
			else:
				add_to_discards(card)
		invalid_card_moved_elsewhere = false

	func wild_strike(is_immediate_reveal : bool = false):
		# Get top card of deck (reshuffle if needed)
		if len(deck) == 0:
			reshuffle_discard(false)
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
			parent.create_event(Enums.EventType.EventType_Strike_WildStrike, my_id, card_id, "", is_immediate_reveal)

	func wild_strike_delayed():
		if parent.active_strike.initiator == self:
			parent.active_strike.initiator_wild_strike = true
		else:
			parent.active_strike.defender_wild_strike = true

	func strike_with_set_aside_card(index):
		var card = set_aside_cards[index]
		set_aside_cards.remove_at(index)
		if parent.active_strike.initiator == self:
			parent.active_strike.initiator_card = card
		else:
			parent.active_strike.defender_card = card

	func random_gauge_strike():
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
			parent._append_log_full(Enums.LogType.LogType_Strike, self, "strikes with %s from gauge!" % parent._log_card_name(card_name))
			gauge.remove_at(random_gauge_idx)
			parent.active_strike.initiator_set_from_gauge = true
			parent.create_event(Enums.EventType.EventType_Strike_RandomGaugeStrike, my_id, random_card_id, "", true)

	func add_to_gauge(card: GameCard):
		gauge.append(card)
		parent.create_event(Enums.EventType.EventType_AddToGauge, my_id, card.id)

	func add_to_discards(card : GameCard, from_top : int = 0):
		if card.owner_id == my_id or seal_instead_of_discarding:
			if from_top == 0:
				discards.append(card)
			else:
				# Insert it from_top from the end.
				discards.insert(len(discards) - from_top, card)

			parent.create_event(Enums.EventType.EventType_AddToDiscard, my_id, card.id, "", from_top)
			if seal_instead_of_discarding:
				seal_from_location(card.id, "discard")
		else:
			# Card belongs to the other player, so discard it there.
			parent._get_player(parent.get_other_player(my_id)).add_to_discards(card, from_top)

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
		var force = force_cost_reduction + free_force
		for card in hand:
			force += card_database.get_card_force_value(card.id)
		for card in gauge:
			force += card_database.get_card_force_value(card.id)
		force += get_force_from_spent_life(life)
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
		if distance > movement_limit and not (exceeded and movement_limit_optional_exceeded):
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
		var direction = -1 if go_left else 1
		var other_player = parent._get_player(parent.get_other_player(my_id))

		if is_self_move:
			var movement_blocked = cannot_move
			if parent.active_strike and strike_stat_boosts.cannot_move_if_in_opponents_range:
				if parent.in_range(other_player, self, parent.active_strike.get_player_card(other_player)):
					movement_blocked = true

			if movement_blocked:
				parent._append_log_full(Enums.LogType.LogType_CharacterMovement, self, "cannot move!")
				parent.create_event(Enums.EventType.EventType_BlockMovement, my_id, 0)
				return
		else:
			if strike_stat_boosts.ignore_push_and_pull or ignore_push_and_pull:
				parent._append_log_full(Enums.LogType.LogType_CharacterMovement, self, "cannot be moved!")
				parent.create_event(Enums.EventType.EventType_Strike_IgnoredPushPull, my_id, 0)
				return

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
			if parent.active_strike and not parent.active_strike.in_setup:
				var all_stop_on_space_boosts = []
				var boost_location_map = {}
				var boost_space_resolution_order = [self, other_player]
				if not is_self_move:
					boost_space_resolution_order = [other_player, self]

				for check_player in boost_space_resolution_order:
					for boost_id in check_player.stop_on_boost_space_ids:
						all_stop_on_space_boosts.append(boost_id)
						boost_location_map[boost_id] = check_player.get_boost_location(boost_id)

				for boost_id in all_stop_on_space_boosts:
					var boost_location = boost_location_map[boost_id]
					if boost_location != -1 and is_in_location(boost_location, new_location):
						movement_shortened = true
						stopped_on_space = true
						parent.active_strike.queued_stop_on_space_boosts.append(boost_id)

			# Delays breaking in case a space is multiple movement-stopping boosts is entered
			if movement_shortened:
				break

		if movement_shortened:
			if blocked_by_buddy:
				var other_buddy_name = other_player.get_buddy_name(cannot_move_past_opponent_buddy_id)
				parent._append_log_full(Enums.LogType.LogType_CharacterMovement, self, "cannot move past %s's %s!" % [other_player.name, other_buddy_name])
			elif stopped_on_space:
				parent._append_log_full(Enums.LogType.LogType_CharacterMovement, self, "forced to stop at %s by an effect!" % str(new_location))
			else:
				parent._append_log_full(Enums.LogType.LogType_CharacterMovement, self, "cannot move past %s!" % other_player.name)

		if not parent.active_strike:
			pre_strike_movement += distance
		var position_changed = arena_location != new_location
		arena_location = new_location
		parent.create_event(Enums.EventType.EventType_Move, my_id, new_location, movement_type, amount, previous_location)
		if position_changed:
			on_position_changed(previous_location, get_buddy_location(), is_self_move)
			if is_self_move:
				add_boosts_to_gauge_on_move()

		if set_x_to_buddy_spaces_entered:
			var buddy_spaces_entered = len(opponent_buddies_encountered_in_order)
			other_player.set_strike_x(buddy_spaces_entered, true)

		if remove_my_buddies_encountered > 0:
			for buddy_id in my_buddies_encountered_in_order:
				remove_buddy(buddy_id)
				remove_my_buddies_encountered -= 1
				if remove_my_buddies_encountered == 0:
					break

	func move_to(new_location, ignore_restrictions=false, remove_buddies_encountered : int = 0):
		if arena_location == new_location:
			return

		var other_player = parent._get_player(parent.get_other_player(my_id))
		var right_of_other = other_player.arena_location < arena_location
		var distance = movement_distance_between(arena_location, new_location)
		if ignore_restrictions:
			var previous_location = arena_location
			arena_location = new_location
			parent.create_event(Enums.EventType.EventType_Move, my_id, new_location, "move", distance, previous_location)
			if previous_location != arena_location:
				on_position_changed(previous_location, get_buddy_location(), true)
				# This is used for resetting positions; don't process remove-on-move boosts, since it's not an advance/retreat
		else:
			if arena_location < new_location:
				if other_player.is_in_location(new_location):
					new_location = other_player.get_closest_occupied_space_to(arena_location) - 1
					distance = movement_distance_between(arena_location, new_location)
				move_in_direction_by_amount(false, distance, false, -1, "move", true, remove_buddies_encountered)
			else:
				if other_player.is_in_location(new_location):
					new_location = other_player.get_closest_occupied_space_to(arena_location) + 1
					distance = movement_distance_between(arena_location, new_location)
				move_in_direction_by_amount(true, distance, false, -1, "move", true, remove_buddies_encountered)

		var now_right_of_other = other_player.arena_location < arena_location
		var advanced_through = right_of_other != now_right_of_other
		if advanced_through:
			parent.handle_advanced_through(self, other_player)

	func close(amount):
		if not (exceeded and movement_limit_optional_exceeded):
			amount = min(amount, movement_limit)
		var other_location = parent._get_player(parent.get_other_player(my_id)).arena_location
		if arena_location < other_location:
			move_in_direction_by_amount(false, amount, true, -1, "close")
		else:
			move_in_direction_by_amount(true, amount, true, -1, "close")

	func advance(amount, stop_on_space):
		if not (exceeded and movement_limit_optional_exceeded):
			amount = min(amount, movement_limit)
		var other_location = parent._get_player(parent.get_other_player(my_id)).arena_location
		if arena_location < other_location:
			move_in_direction_by_amount(false, amount, false, stop_on_space, "advance")
		else:
			move_in_direction_by_amount(true, amount, false, stop_on_space, "advance")

	func retreat(amount):
		if not (exceeded and movement_limit_optional_exceeded):
			amount = min(amount, movement_limit)
		var other_location = parent._get_player(parent.get_other_player(my_id)).arena_location
		if arena_location < other_location:
			move_in_direction_by_amount(true, amount, false, -1, "retreat")
		else:
			move_in_direction_by_amount(false, amount, false, -1, "retreat")

	func push(amount, set_x_to_buddy_spaces_entered : bool = false):
		var other_player = parent._get_player(parent.get_other_player(my_id))
		var other_location = other_player.arena_location
		if arena_location < other_location:
			other_player.move_in_direction_by_amount(false, amount, false, -1, "push", false, 0, set_x_to_buddy_spaces_entered)
		else:
			other_player.move_in_direction_by_amount(true, amount, false, -1, "push", false, 0, set_x_to_buddy_spaces_entered)

	func pull(amount):
		var other_player = parent._get_player(parent.get_other_player(my_id))
		var other_location = other_player.arena_location
		if arena_location < other_location:
			other_player.move_in_direction_by_amount(true, amount, false, -1, "pull", false)
		else:
			other_player. move_in_direction_by_amount(false, amount, false, -1, "pull", false)

	func pull_not_past(amount):
		var other_player = parent._get_player(parent.get_other_player(my_id))
		var other_location = other_player.arena_location
		if arena_location < other_location:
			other_player.move_in_direction_by_amount(true, amount, true, -1, "pull", false)
		else:
			other_player.move_in_direction_by_amount(false, amount, true, -1, "pull", false)

	func add_to_continuous_boosts(card : GameCard):
		for boost_card in continuous_boosts:
			if boost_card.id == card.id:
				assert(false, "Should not have boost already here.")
		continuous_boosts.append(card)
		var facedown = card.definition["boost"].get("facedown")
		parent.create_event(Enums.EventType.EventType_Boost_Continuous_Added, my_id, card.id, "", facedown)

	func add_to_transforms(card : GameCard):
		for boost_card in transforms:
			if boost_card.id == card.id:
				assert(false, "Should not have transform already here.")
			elif boost_card.definition['display_name'] == card.definition['display_name']:
				assert(false, "Should not be able to transform two cards with same name.")
		transforms.append(card)
		parent.create_event(Enums.EventType.EventType_Transform_Added, my_id, card.id)

	func get_continuous_boosts_and_transforms():
		return continuous_boosts + transforms

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

	func add_range_bonus(min_bonus : int, max_bonus : int, special_only : bool = false):
		var range_effect = {
			"min_range": min_bonus,
			"max_range": max_bonus,
			"special_only": special_only
		}
		strike_stat_boosts.range_effects.append(range_effect)

	func remove_range_bonus(min_bonus : int, max_bonus : int, special_only : bool = false):
		var range_effect = {
			"min_range": -min_bonus,
			"max_range": -max_bonus,
			"special_only": special_only
		}
		strike_stat_boosts.range_effects.append(range_effect)

	func build_outside_strike_range_effect_list():
		var opposing_player = parent._get_player(parent.get_other_player(my_id))
		var effect_list = []
		# Check my boosts
		for card in continuous_boosts:
			for effect in card.definition["boost"]["effects"]:
				if effect["timing"] == "during_strike" and effect.get("works_outside_strike"):
					match effect["type"]:
						"rangeup":
							if effect.get("opponent"):
								# Ignore opponent effects.
								continue
							var min_bonus = effect['amount']
							var max_bonus = effect['amount2']
							var special_only = effect.get("special_only", false)
							var range_effect = {
								"min_range": min_bonus,
								"max_range": max_bonus,
								"special_only": special_only
							}
							effect_list.append(range_effect)

		# Check opponent boosts.
		for card in opposing_player.continuous_boosts:
			for effect in card.definition["boost"]["effects"]:
				if effect["timing"] == "during_strike" and effect.get("works_outside_strike"):
					match effect["effect_type"]:
						"rangeup":
							if not effect.get("opponent"):
								# Only care about opponent effects.
								continue
							var min_bonus = effect['amount']
							var max_bonus = effect['amount2']
							var special_only = effect.get("special_only", false)
							var range_effect = {
								"min_range": min_bonus,
								"max_range": max_bonus,
								"special_only": special_only
							}
							effect_list.append(range_effect)
						"rangeup_both_players":
							var range_effect = {
									"min_range": effect['amount'],
									"max_range": effect['amount2'],
									"special_only": false
								}
							effect_list.append(range_effect)
		return effect_list

	func get_total_min_range_bonus(card : GameCard, alt_effect_list = []):
		var is_special = card.definition["type"] == "special"
		var total_min_range = 0
		var effect_list = strike_stat_boosts.range_effects
		if not parent.active_strike:
			effect_list = build_outside_strike_range_effect_list()
		if alt_effect_list:
			effect_list = alt_effect_list
		for effect in effect_list:
			if not effect["special_only"] or is_special:
				total_min_range += effect['min_range']
		return total_min_range

	func get_total_max_range_bonus(card : GameCard, alt_effect_list = []):
		var is_special = card.definition["type"] == "special"
		var total_max_range = 0
		var effect_list = strike_stat_boosts.range_effects
		if not parent.active_strike:
			effect_list = build_outside_strike_range_effect_list()
		if alt_effect_list:
			effect_list = alt_effect_list
		for effect in effect_list:
			if not effect["special_only"] or is_special:
				total_max_range += effect['max_range']
		return total_max_range

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
							strike_stat_boosts.dodge_at_range_min[card.id] = effect['amount']
							strike_stat_boosts.dodge_at_range_max[card.id] = effect['amount2']
							if effect['from_buddy']:
								strike_stat_boosts.dodge_at_range_from_buddy = effect['from_buddy']
							var dodge_range = str(strike_stat_boosts.dodge_at_range_min[card.id])
							if strike_stat_boosts.dodge_at_range_min[card.id] != strike_stat_boosts.dodge_at_range_max[card.id]:
								dodge_range += "-%s" % strike_stat_boosts.dodge_at_range_max[card.id]
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
						var target_player = self
						if effect.get("opponent"):
							target_player = opposing_player
						var special_only = effect.get("special_only", false)
						target_player.add_range_bonus(effect['amount'], effect['amount2'], special_only)
					"rangeup_both_players":
						add_range_bonus(effect['amount'], effect['amount2'], false)
						opposing_player.add_range_bonus(effect['amount'], effect['amount2'], false)

	func disable_boost_effects(card : GameCard, buddy_ignore_condition : bool = false, being_discarded : bool = true):
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
				_revert_strike_bonus_effect(effect, card.id, false)

	func _revert_strike_bonus_effect(effect, card_id : int, check_and_effects : bool):
		var opposing_player = parent._get_player(parent.get_other_player(my_id))
		parent.remove_remaining_effect(effect, card_id)

		match effect['effect_type']:
			"attack_is_ex":
				strike_stat_boosts.remove_ex()
			"dodge_at_range":
				if 'special_range' in effect:
					var current_range = str(overdrive.size())
					strike_stat_boosts.dodge_at_range_late_calculate_with = ""
					parent._append_log_full(Enums.LogType.LogType_Effect, self, "will no longer dodge attacks from range %s!" % current_range)
				else:
					var dodge_range = str(strike_stat_boosts.dodge_at_range_min[card_id])
					if strike_stat_boosts.dodge_at_range_min[card_id] != strike_stat_boosts.dodge_at_range_max[card_id]:
						dodge_range += "-%s" % strike_stat_boosts.dodge_at_range_max[card_id]
					parent._append_log_full(Enums.LogType.LogType_Effect, self, "will no longer dodge attacks from range %s." % dodge_range)
					strike_stat_boosts.dodge_at_range_min.erase(card_id)
					strike_stat_boosts.dodge_at_range_max.erase(card_id)
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
				var target_player = self
				if effect.get("opponent"):
					target_player = opposing_player
				var special_only = effect.get("special_only", false)
				target_player.remove_range_bonus(effect['amount'], effect['amount2'], special_only)
			"rangeup_both_players":
				remove_range_bonus(effect['amount'], effect['amount2'], false)
				opposing_player.remove_range_bonus(effect['amount'], effect['amount2'], false)
			"rangeup_if_ex_modifier":
				strike_stat_boosts.rangeup_min_if_ex_modifier -= effect['amount']
				strike_stat_boosts.rangeup_max_if_ex_modifier -= effect['amount2']
			"guardup_per_two_cards_in_hand":
				strike_stat_boosts.guardup_per_two_cards_in_hand = false

		if check_and_effects and "and" in effect:
			_revert_strike_bonus_effect(effect['and'], card_id, check_and_effects)

	func remove_from_continuous_boosts(card : GameCard, destination : String = "discard"):
		disable_boost_effects(card)

		var discards_to_sealed = card.definition["boost"].get("discards_to_sealed")
		if discards_to_sealed:
			destination = "sealed"

		do_discarded_effects_for_boost(card)

		# Update internal boost arrays
		for boost_array in [boosts_to_gauge_on_move, on_buddy_boosts]:
			var card_idx = boost_array.find(card.id)
			if card_idx != -1:
				boost_array.remove_at(card_idx)

		# Add to gauge or discard as appropriate.
		for i in range(len(continuous_boosts)):
			if continuous_boosts[i].id == card.id:
				if destination == "gauge":
					add_to_gauge(card)
				elif destination == "hand":
					# This should go to the owner's hand.
					var owner_player = parent._get_player(card.owner_id)
					owner_player.add_to_hand(card, true)
				elif destination == "overdrive":
					add_to_overdrive(card)
				elif destination == "sealed":
					add_to_sealed(card)
				elif destination == "strike":
					pass
				else:
					add_to_discards(card)
				continuous_boosts.remove_at(i)
				break

	func get_all_non_immediate_continuous_boost_effects():
		var effects = []
		for card in get_continuous_boosts_and_transforms():
			for effect in card.definition['boost']['effects']:
				if effect['timing'] != "now":
					effects.append(effect)
		return effects

	func is_card_in_continuous_boosts(id : int):
		for card in continuous_boosts:
			if card.id == id:
				return true
		return false

	func is_card_in_transforms(id : int):
		for card in transforms:
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
		while boosts_to_gauge_on_move:
			var card_id = boosts_to_gauge_on_move[0]
			var card = parent.card_db.get_card(card_id)
			var card_name = parent.card_db.get_card_name(card_id)
			parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "adds boosted card %s to gauge after moving." % parent._log_card_name(card_name))
			remove_from_continuous_boosts(card, "gauge") # This also removes it from boosts_to_gauge_on_move

	func handle_on_buddy_boosts(enable):
		for card_id in on_buddy_boosts:
			var card = parent.card_db.get_card(card_id)
			assert(card in continuous_boosts)
			var boost_name = parent._get_boost_and_card_name(card)
			if enable:
				parent._append_log_full(Enums.LogType.LogType_Effect, self, "'s boost %s re-activated." % boost_name)
				reenable_boost_effects(card)
			else:
				parent._append_log_full(Enums.LogType.LogType_Effect, self, "'s boost %s was disabled." % boost_name)
				disable_boost_effects(card, true, false)

	func on_cancel_boost():
		parent.create_event(Enums.EventType.EventType_Boost_Canceled, my_id, 0)

		# Create a strike state just to track completing effects at this timing.
		var effects = get_character_effects_at_timing("on_cancel_boost")
		# NOTE: Only 1 choice currently allowed.
		for effect in effects:
			parent.do_effect_if_condition_met(self, -1, effect, null)
		canceled_this_turn = true

	func do_discarded_effects_for_boost(card : GameCard):
		for effect in card.definition['boost']['effects']:
			if effect['timing'] == "discarded":
				var owner_player = parent._get_player(card.owner_id)
				parent.do_effect_if_condition_met(owner_player, card.id, effect, null)
			elif effect['timing'] == "now":
				match effect['effect_type']:
					"add_passive":
						if effect['passive'] in passive_effects:
							passive_effects[effect['passive']] -= 1
							if passive_effects[effect['passive']] == 0:
								passive_effects.erase(effect['passive'])
								parent._append_log_full(Enums.LogType.LogType_Effect, self, "no longer %s." % effect['description'])
		if card.definition.get("replaced_boost"):
			card.definition["boost"] = card.definition["replaced_boost"]
			card.definition.erase("replaced_boost")
			on_hand_remove_public_card(card.id)

		# Remove it from boost locations if it is in the arena.
		remove_boost_in_location(card.id)

	func cleanup_continuous_boosts():
		var sustained_cards : Array[GameCard] = []
		for boost_card in continuous_boosts:
			var sustained = false
			if boost_card.id in cleanup_boost_to_gauge_cards:
				add_to_gauge(boost_card)
				var card_name = parent.card_db.get_card_name(boost_card.id)
				parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "adds boosted card %s to gauge." % parent._log_card_name(card_name))
			else:
				var boost_name = parent._get_boost_and_card_name(boost_card)
				if boost_card.id in sustained_boosts:
					sustained = true
					sustained_cards.append(boost_card)
				else:
					var discards_to_sealed = boost_card.definition["boost"].get("discards_to_sealed")
					if discards_to_sealed:
						add_to_sealed(boost_card)
					else:
						add_to_discards(boost_card)
					parent._append_log_full(Enums.LogType.LogType_CardInfo, self, "discards their continuous boost %s from play." % boost_name)
			for boost_array in [boosts_to_gauge_on_move, on_buddy_boosts]:
				var card_idx = boost_array.find(boost_card.id)
				if card_idx != -1 and boost_card.id not in sustained_boosts:
					boost_array.remove_at(card_idx)
			if not sustained:
				do_discarded_effects_for_boost(boost_card)
		continuous_boosts = sustained_cards
		sustained_boosts = []
		cleanup_boost_to_gauge_cards = []

	func force_opponent_respond_wild_swing() -> bool:
		if opponent_next_strike_forced_wild_swing:
			opponent_next_strike_forced_wild_swing = false
			return true

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

		var effect_sets = [deck_def[ability_label]]
		for card in get_continuous_boosts_and_transforms():
			effect_sets.append(card.definition['boost']['effects'])
		for effect_set in effect_sets:
			for effect in effect_set:
				if effect['timing'] == "on_continuous_boost" and is_continuous_boost:
					effects.append(effect)
			for effect in effect_set:
				if effect['timing'] == "on_any_boost":
					effects.append(effect)
		return effects

	func get_counter_boost_effects():
		var effects = []
		var ability_label = "ability_effects"
		if exceeded:
			ability_label = "exceed_ability_effects"
		for effect in deck_def[ability_label]:
			if effect['timing'] == "counter_boost":
				effects.append(effect)
		for card in get_continuous_boosts_and_transforms():
			for effect in card.definition['boost']['effects']:
				if effect['timing'] == "counter_boost":
					effects.append(effect)
		return effects

	func set_strike_x(value : int, silent : bool = false):
		strike_stat_boosts.strike_x = max(value, 0)
		if not silent:
			parent.create_event(Enums.EventType.EventType_Strike_SetX, my_id, value)

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

func initialize_game(
	player_deck,
	opponent_deck,
	player_name : String,
	opponent_name : String,
	first_player : Enums.PlayerId,
	seed_value : int
):
	random_number_generator.seed = seed_value
	card_db = CardDatabase.new(image_loader)
	CardDefinitions.load_deck_if_custom(player_deck)
	CardDefinitions.load_deck_if_custom(opponent_deck)
	var player_card_id_start = 100
	var opponent_card_id_start = 200
	if first_player == Enums.PlayerId.PlayerId_Opponent:
		player_card_id_start = 200
		opponent_card_id_start = 100
	player = Player.new(Enums.PlayerId.PlayerId_Player,
		player_name,
		self,
		card_db,
		player_deck,
		player_card_id_start)
	opponent = Player.new(Enums.PlayerId.PlayerId_Opponent,
		opponent_name,
		self,
		card_db,
		opponent_deck,
		opponent_card_id_start)

	active_turn_player = first_player
	next_turn_player = get_other_player(first_player)
	var starting_player = _get_player(active_turn_player)
	var second_player = _get_player(next_turn_player)
	starting_player.arena_location = 3
	starting_player.starting_location = 3
	if starting_player.buddy_starting_offset != BuddyStartsOutOfArena:
		var buddy_space = 3 + starting_player.buddy_starting_offset
		starting_player.place_buddy(buddy_space,
			starting_player.buddy_starting_id, true)
	second_player.arena_location = 7
	second_player.starting_location = 7
	if second_player.buddy_starting_offset != BuddyStartsOutOfArena:
		var buddy_space = 7 - second_player.buddy_starting_offset
		second_player.place_buddy(buddy_space, second_player.buddy_starting_id, true)
	starting_player.initial_shuffle()
	second_player.initial_shuffle()

func draw_starting_hands_and_begin():
	var starting_player = _get_player(active_turn_player)
	var second_player = _get_player(next_turn_player)
	_append_log_full(Enums.LogType.LogType_Default, null,
		"Game Start - %s as %s (1st) vs %s as %s (2nd)" % [starting_player.name,
			starting_player.deck_def['display_name'], second_player.name,
			second_player.deck_def['display_name']])
	starting_player.draw(StartingHandFirstPlayer + starting_player.starting_hand_size_bonus)
	second_player.draw(StartingHandSecondPlayer + second_player.starting_hand_size_bonus)
	change_game_state(Enums.GameState.GameState_Mulligan)
	create_event(Enums.EventType.EventType_MulliganDecision, player.my_id, 0)
	return true

func _test_add_to_gauge(amount: int):
	for i in range(amount):
		player.draw(1)
		var card = player.hand[0]
		player.remove_card_from_hand(card.id, true, false)
		player.add_to_gauge(card)
	return true

func get_card_database() -> CardDatabase:
	return card_db

func get_player_name(player_id : Enums.PlayerId) -> String:
	if player_id == Enums.PlayerId.PlayerId_Player:
		return player.name
	return opponent.name

# TODO: This function is frequently called from outside and probably shouldn't
# start with an underscore.
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
	var boost_list = player_ending_turn.get_continuous_boosts_and_transforms()
	for i in range(len(boost_list) - 1, -1, -1):
		var card = boost_list[i]
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
	var player_ending_turn = _get_player(active_turn_player)
	change_game_state(Enums.GameState.GameState_Boost_Processing)
	while remaining_end_of_turn_effects.size() > 0:
		var effect = remaining_end_of_turn_effects[0]
		remaining_end_of_turn_effects.erase(effect)
		var card_id = -1
		if 'card_id' in effect:
			card_id = effect['card_id']
		do_effect_if_condition_met(player_ending_turn, card_id, effect, null)
		if game_state == Enums.GameState.GameState_PlayerDecision:
			# Player has a decision to make, so stop mid-effect resolve.
			break

	if game_state != Enums.GameState.GameState_PlayerDecision:
		active_end_of_turn_effects = false
		advance_to_next_turn()

func advance_to_next_turn():

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
	player.total_force_spent_this_turn = 0
	opponent.total_force_spent_this_turn = 0
	player.force_spent_before_strike = 0
	opponent.force_spent_before_strike = 0
	player.gauge_spent_before_strike = 0
	opponent.gauge_spent_before_strike = 0
	player.gauge_spent_this_strike = 0
	opponent.gauge_spent_this_strike = 0
	player.gauge_cards_spent_this_strike = []
	opponent.gauge_cards_spent_this_strike = []
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
	player.checked_post_action_effects = false
	opponent.checked_post_action_effects = false

	# Update strike turn tracking
	last_turn_was_strike = strike_happened_this_turn
	strike_happened_this_turn = false

	# Figure out next turn's player.
	active_turn_player = next_turn_player
	next_turn_player = get_other_player(active_turn_player)

	# Handle any end of turn exceed.
	if player_ending_turn.exceed_at_end_of_turn:
		player_ending_turn.exceed()
		player_ending_turn.exceed_at_end_of_turn = false
	if other_player.exceed_at_end_of_turn:
		other_player.exceed()
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
			do_remaining_overdrive(starting_turn_player)
		elif starting_turn_player.exceeded and starting_turn_player.has_overdrive and starting_turn_player.overdrive.size() == 0:
			# Overdrive is empty, so revert to normal.
			starting_turn_player.revert_exceed()
			start_begin_turn()
		else:
			start_begin_turn()

func start_begin_turn():
	active_start_of_turn_effects = true

	# Handle any start of turn boost effects.
	# Iterate in reverse as items can be removed.
	var starting_turn_player = _get_player(active_turn_player)
	remaining_start_of_turn_effects = get_all_effects_for_timing("start_of_next_turn", starting_turn_player, null)
	return continue_begin_turn()

func continue_begin_turn():
	var starting_turn_player = _get_player(active_turn_player)
	var other_player = _get_player(get_other_player(starting_turn_player.my_id))
	change_game_state(Enums.GameState.GameState_Boost_Processing)
	while remaining_start_of_turn_effects.size() > 0:
		var effect = remaining_start_of_turn_effects[0]
		remaining_start_of_turn_effects.erase(effect)

		var card_id = -1
		if 'card_id' in effect:
			card_id = effect['card_id']

		if effect['timing'] == "start_of_next_turn":
			do_effect_if_condition_met(starting_turn_player, card_id, effect, null)
		elif effect['timing'] == "opponent_start_of_next_turn":
			do_effect_if_condition_met(other_player, card_id, effect, null)
		else:
			assert(false, "Unexpected timing for start of turn effect")

		if game_state == Enums.GameState.GameState_PlayerDecision:
			# Player has a decision to make, so stop mid-effect resolve.
			break

	if game_state != Enums.GameState.GameState_PlayerDecision:
		active_start_of_turn_effects = false

		# Transition to the pick action state, the player can now make their action for the turn.
		_append_log_full(Enums.LogType.LogType_Default, starting_turn_player, "'s Turn Start!")
		change_game_state(Enums.GameState.GameState_PickAction)
		decision_info.clear()
		create_event(Enums.EventType.EventType_AdvanceTurn, active_turn_player, 0)

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
			do_effect_if_condition_met(starting_turn_player, -1, effect, null)
			# This is not expected to do anything currently, but potentially does some future-proofing.
			continue_player_action_resolution(starting_turn_player)

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

func continue_setup_strike():
	if active_strike.strike_state == StrikeState.StrikeState_Initiator_SetEffects:
		var initiator_set_strike_effects = active_strike.initiator.get_set_strike_effects(active_strike.initiator_card)
		while active_strike.effects_resolved_in_timing < initiator_set_strike_effects.size():
			var effect = initiator_set_strike_effects[active_strike.effects_resolved_in_timing]
			do_effect_if_condition_met(active_strike.initiator, -1, effect, null)
			if game_state == Enums.GameState.GameState_PlayerDecision:
				return

			active_strike.effects_resolved_in_timing += 1

		# All effects resolved, move to next state.
		active_strike.effects_resolved_in_timing = 0
		if active_strike.initiator_wild_strike and active_strike.initiator.delayed_wild_strike:
			# Do the wild swing now.
			active_strike.initiator.wild_strike()
			if game_over:
				return

			create_event(
				Enums.EventType.EventType_Strike_Started,
				active_strike.initiator.my_id,
				active_strike.initiator_card.id,
				"",
				false,
				false
			)

		if active_strike.opponent_sets_first:
			begin_resolve_strike()
		else:
			strike_setup_defender_response()

	elif active_strike.strike_state == StrikeState.StrikeState_Defender_SetFirst:
		# Opponent will set first; check for restrictions on what they can set
		strike_setup_defender_response()

	elif active_strike.strike_state == StrikeState.StrikeState_Defender_SetEffects:
		if active_strike.waiting_for_reading_response:
			return

		var defender_set_strike_effects = active_strike.defender.get_set_strike_effects(active_strike.defender_card)
		while active_strike.effects_resolved_in_timing < defender_set_strike_effects.size():
			var effect = defender_set_strike_effects[active_strike.effects_resolved_in_timing]
			do_effect_if_condition_met(active_strike.defender, -1, effect, null)
			if game_state == Enums.GameState.GameState_PlayerDecision:
				return
			active_strike.effects_resolved_in_timing += 1

		# All effects resolved, move to next state.
		active_strike.effects_resolved_in_timing = 0
		if active_strike.defender_wild_strike and active_strike.defender.delayed_wild_strike:
			# Do the wild swing now.
			active_strike.defender.wild_strike()
			if game_over:
				return

			create_event(
				Enums.EventType.EventType_Strike_Response,
				active_strike.defender.my_id,
				active_strike.defender_card.id,
				"",
				false,
				false
			)

		if active_strike.opponent_sets_first:
			strike_setup_initiator_response()
		else:
			begin_resolve_strike()

func strike_setup_defender_response():
	active_strike.strike_state = StrikeState.StrikeState_Defender_SetEffects
	change_game_state(Enums.GameState.GameState_Strike_Opponent_Response)
	var ask_for_response = true
	decision_info.clear()
	if active_strike.initiator.force_opponent_respond_wild_swing():
		create_event(Enums.EventType.EventType_Strike_ForceWildSwing, active_strike.initiator.my_id, 0)
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

			# Add potential overloads as options for EX
			var overload_options = {}
			if reading_card.definition['type'] == "normal":
				for card in active_strike.defender.hand:
					if card.definition['id'] not in overload_options and card.definition['boost']['boost_type'] == "overload":
						overload_options[card.definition['id']] = card

			# Send choice to player
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			var defender_id = active_strike.defender.my_id

			decision_info.type = Enums.DecisionType.DecisionType_ChooseSimultaneousEffect
			decision_info.player = defender_id
			decision_info.choice = [
				{ "effect_type": "strike_response_reading", "card_id": reading_card.id },
				{ "effect_type": "strike_response_reading", "card_id": reading_card.id, "ex_card_id": ex_card_id, "_choice_disabled": ex_card_id == -1 },
			]

			for overload_option_id in overload_options:
				var overload_card = overload_options[overload_option_id]
				decision_info.choice.append(
					{ "effect_type": "strike_response_reading", "card_id": reading_card.id, "ex_card_id": overload_card.id, "overload_name": overload_card.definition['display_name'] }
				)

			create_event(Enums.EventType.EventType_Strike_EffectChoice, defender_id, 0, "Reading", reading_card.definition['display_name'])
			active_strike.waiting_for_reading_response = true
			ask_for_response = false
		else:
			_append_log_full(Enums.LogType.LogType_Effect, active_strike.defender, "does not have the named card.")
			active_strike.defender.reveal_hand()
	if ask_for_response:
		decision_info.player = active_strike.defender.my_id
		if active_strike.opponent_sets_first:
			create_event(Enums.EventType.EventType_Strike_OpponentSetsFirst_DefenderSet, active_strike.defender.my_id, 0)
		else:
			create_event(Enums.EventType.EventType_Strike_DoResponseNow, active_strike.defender.my_id, 0)

func strike_setup_initiator_response():
	active_strike.strike_state = StrikeState.StrikeState_Initiator_SetEffects
	change_game_state(Enums.GameState.GameState_WaitForStrike)
	var ask_for_response = true
	decision_info.clear()
	if active_strike.initiator.next_strike_random_gauge:
		decision_info.player = active_strike.initiator.my_id
		do_strike(active_strike.initiator, -1, false, -1, active_strike.opponent_sets_first)
		ask_for_response = false
	if ask_for_response:
		decision_info.player = active_strike.initiator.my_id
		create_event(Enums.EventType.EventType_Strike_OpponentSetsFirst_InitiatorSet, active_strike.initiator.my_id, 0)

func begin_resolve_strike():
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

	create_event(Enums.EventType.EventType_Strike_Reveal, active_strike.initiator.my_id, 0)
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

	continue_resolve_strike()

func get_total_speed(check_player, ignore_swap : bool = false):
	if check_player.strike_stat_boosts.swap_power_speed and not ignore_swap:
		return get_total_power(check_player, true)

	if check_player.strike_stat_boosts.overwrite_total_speed:
		return check_player.strike_stat_boosts.overwritten_total_speed

	var check_card = active_strike.get_player_card(check_player)
	var bonus_speed = check_player.strike_stat_boosts.speed * check_player.strike_stat_boosts.speed_bonus_multiplier
	if check_player.strike_stat_boosts.speedup_by_spaces_modifier > 0:
		# Note: This does not interact with speed multipliers.
		# If a later character has that, it will need to be implemented.
		var empty_spaces_between = check_player.distance_to_opponent() - 1
		bonus_speed += empty_spaces_between * check_player.strike_stat_boosts.speedup_by_spaces_modifier
	if check_player.strike_stat_boosts.speedup_per_boost_modifier > 0:
		# same note on speed multipliers
		var boosts_in_play = check_player.get_boosts().size()
		if check_player.strike_stat_boosts.speedup_per_boost_modifier_all_boosts:
			var opposing_player = _get_player(get_other_player(check_player.my_id))
			boosts_in_play += opposing_player.get_boosts().size()
		if boosts_in_play > 0:
			bonus_speed += check_player.strike_stat_boosts.speedup_per_boost_modifier * boosts_in_play
	if check_player.strike_stat_boosts.passive_speedup_per_card_in_hand != 0:
		var hand_size = len(check_player.hand)
		bonus_speed += hand_size * check_player.strike_stat_boosts.passive_speedup_per_card_in_hand
	if check_player.strike_stat_boosts.speedup_per_unique_sealed_normals_modifier != 0:
		var unique_normals = check_player.get_sealed_count_of_type("normal", true)
		bonus_speed += unique_normals * check_player.strike_stat_boosts.speedup_per_unique_sealed_normals_modifier
	var speed = get_card_stat(check_player, check_card, 'speed') + bonus_speed
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

func do_effect_if_condition_met(
	performing_player : Player,
	card_id : int,
	effect,
	local_conditions : LocalStrikeConditions,
	recorded_failed_effects = null
	):

	if 'skip_if_boost_sustained' in effect and effect['skip_if_boost_sustained']:
		if card_id in performing_player.sustained_boosts:
			return

	if is_effect_condition_met(performing_player, effect, local_conditions):
		handle_strike_effect(card_id, effect, performing_player)
	elif 'negative_condition_effect' in effect:
		var negative_condition_effect = effect['negative_condition_effect']
		do_effect_if_condition_met(performing_player, card_id, negative_condition_effect, local_conditions)
	elif recorded_failed_effects != null:
		recorded_failed_effects.append(effect)

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
		elif condition == "opponent_is_special_attack":
			return active_strike.get_player_card(other_player).definition['type'] == "special"
		elif condition == "is_ex_strike":
			return active_strike.will_be_ex(performing_player)
		elif condition == "at_edge_of_arena":
			return performing_player.is_at_edge_of_arena()
		elif condition == "attack_still_in_play":
			var card = active_strike.get_player_card(performing_player)
			return card in active_strike.cards_in_play
		elif condition == "attacks_match_printed_speed":
			var card = active_strike.get_player_card(performing_player)
			var opposing_card = active_strike.get_player_card(other_player)
			return card.definition['speed'] == opposing_card.definition['speed']
		elif condition == "boost_in_play":
			return performing_player.get_boosts().size() > 0
		elif condition == "no_boost_in_play":
			return performing_player.get_boosts().size() == 0
		elif condition == "canceled_this_turn":
			return performing_player.canceled_this_turn
		elif condition == "not_canceled_this_turn":
			return not performing_player.canceled_this_turn
		elif condition == "copy_of_attack_in_zones":
			var zones = effect["condition_zones"]
			var card = active_strike.get_player_card(performing_player)
			for zone in zones:
				if performing_player.has_card_name_in_zone(card, zone):
					return true
			return false
		elif condition == "has_card_with_range_to_opponent":
			for card in performing_player.hand:
				if performing_player.does_card_contain_range_to_opponent(card.id):
					return true
			return false
		elif condition == "has_transform":
			var required_card = effect.get("required_transform_card")
			for card in performing_player.transforms:
				if card.definition["id"] == required_card:
					return true
			return false
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
		elif condition == "not_used_character_bonus":
			return not performing_player.used_character_bonus
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
		elif condition == "life_equal_or_below":
			var amount = effect['condition_amount']
			return performing_player.life <= amount
		elif condition == "life_less_than_opponent":
			return performing_player.life < other_player.life
		elif condition == "did_end_of_turn_draw":
			return performing_player.did_end_of_turn_draw
		elif condition == "discarded_matches_attack_speed":
			var discarded_card_ids = effect['discarded_card_ids']
			assert(discarded_card_ids.size() == 1)
			var card = card_db.get_card(discarded_card_ids[0])
			var speed_of_discarded = get_card_stat(performing_player, card, 'speed')
			var attack_card = active_strike.get_player_card(performing_player)
			var printed_speed_of_attack = get_card_stat(performing_player, attack_card, 'speed')
			return speed_of_discarded == printed_speed_of_attack
		elif condition == "not_full_close":
			return not local_conditions.fully_closed
		elif condition == "moved_less_than":
			var amount = effect['condition_amount']
			return local_conditions.movement_amount < amount
		elif condition == "moved_at_least":
			var amount = effect['condition_amount']
			return local_conditions.movement_amount >= amount
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
		elif condition == "not_full_pull":
			return not local_conditions.fully_pulled
		elif condition == "pushed_min_spaces":
			return local_conditions.push_amount >= effect['condition_amount']
		elif condition == "pulled_past":
			return local_conditions.pulled_past
		elif condition == "exceeded":
			return performing_player.exceeded
		elif condition == "not_exceeded":
			return not performing_player.exceeded
		elif condition == "opponent_exceeded":
			return other_player.exceeded
		elif condition == "opponent_not_exceeded":
			return not other_player.exceeded
		elif condition == "max_cards_in_gauge":
			var amount = effect['condition_amount']
			return performing_player.gauge.size() <= amount
		elif condition == "max_cards_in_hand":
			var amount = effect['condition_amount']
			return performing_player.hand.size() <= amount
		elif condition == "matches_named_card":
			var player_card = active_strike.get_player_card(performing_player)
			return player_card.definition['id'] == effect['condition_card_id']
		elif condition == "min_cards_in_deck":
			var amount = effect['condition_amount']
			return performing_player.deck.size() >= amount
		elif condition == "min_cards_in_discard":
			var amount = effect['condition_amount']
			return performing_player.discards.size() >= amount
		elif condition == "min_cards_in_hand":
			var amount = effect['condition_amount']
			return performing_player.hand.size() >= amount
		elif condition == "min_cards_in_gauge":
			var amount = effect['condition_amount']
			if effect.get("condition_opponent"):
				return other_player.gauge.size() >= amount
			else:
				return performing_player.gauge.size() >= amount
		elif condition == "min_spaces_behind_opponent":
			var amount = effect['condition_amount']
			var spaces_behind = 0
			# Default to assuming player is to the right and counting from left to right.
			var start = MinArenaLocation
			var direction = 1
			if performing_player.arena_location < other_player.arena_location:
				# Player to left.
				# Count starting from max and stop when you find the player.
				start = MaxArenaLocation
				direction = -1
			for i in range(start, other_player.arena_location, direction):
				if other_player.is_in_location(i):
					break
				spaces_behind += 1
			return spaces_behind >= amount
		elif condition == "manual_reshuffle":
			return local_conditions.manual_reshuffle
		elif condition == "less_cards_than_opponent":
			return performing_player.hand.size() < other_player.hand.size()
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
		elif condition == "no_active_strike":
			return active_strike == null
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
		elif condition == "boost_space_in_range_towards_opponent":
			if not active_strike:
				return false
			var this_boost_location = performing_player.get_boost_location(effect['card_id'])
			var attack_card = active_strike.get_player_card(performing_player)

			# Check if boost is toward the opponent
			var self_pos = get_attack_origin(performing_player, other_player.arena_location)
			var opponent_pos = other_player.get_closest_occupied_space_to(performing_player.arena_location)
			if self_pos < opponent_pos and self_pos > this_boost_location:
				return false
			elif self_pos > opponent_pos and self_pos < this_boost_location:
				return false

			return is_location_in_range(performing_player, attack_card, this_boost_location)
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
			var origin = get_attack_origin(performing_player, other_player.arena_location)
			return other_player.is_in_range_of_location(origin, amount, amount)
		elif condition == "range_from_self":
			var amount = effect['condition_amount']
			var origin = performing_player.get_closest_occupied_space_to(other_player.arena_location)
			return other_player.is_in_range_of_location(origin, amount, amount)
		elif condition == "range_greater_or_equal":
			var amount = effect['condition_amount']
			var origin = get_attack_origin(performing_player, other_player.arena_location)
			var farthest_point = other_player.get_furthest_edge_from(origin)
			var distance = abs(origin - farthest_point)
			return distance >= amount
		elif condition == "range_multiple":
			var min_amount = effect["condition_amount_min"]
			var max_amount = effect["condition_amount_max"]
			var origin = get_attack_origin(performing_player, other_player.arena_location)
			return other_player.is_in_range_of_location(origin, min_amount, max_amount)
		elif condition == "strike_x_greater_than":
			var amount = effect['condition_amount']
			return performing_player.strike_stat_boosts.strike_x > amount
		elif condition == "was_hit":
			return performing_player.strike_stat_boosts.was_hit
		elif condition == "was_wild_swing":
			if active_strike:
				var detail = effect.get("condition_detail", false)
				var ignore_if_invalid_by_choice = detail and detail == "ignore_if_invalid_by_choice"
				if local_conditions and ignore_if_invalid_by_choice and local_conditions.invalid_by_choice:
					return false
				return active_strike.get_player_wild_strike(performing_player)
			return false
		elif condition == "was_not_wild_swing":
			if active_strike:
				return not active_strike.get_player_wild_strike(performing_player)
			return false
		elif condition == "was_strike_from_gauge":
			return active_strike.get_player_strike_from_gauge(performing_player)
		elif condition == "was_set_from_boosts":
			return active_strike.get_player_set_from_boosts(performing_player)
		elif condition == "is_critical":
			return performing_player.strike_stat_boosts.critical
		elif condition == "is_not_critical":
			return not performing_player.strike_stat_boosts.critical
		elif condition == "choose_cards_from_top_deck_action":
			return decision_info.action == effect["condition_details"]
		elif condition == "total_powerup_greater_or_equal":
			var amount = effect["condition_amount"]
			var positive_boosted_power = performing_player.strike_stat_boosts.power_positive_only
			return positive_boosted_power >= amount
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
		elif condition == "opponent_speed_less_or_equal":
			return get_total_speed(other_player) <= effect['condition_amount']
		elif condition == "spent_gauge_this_strike":
			return performing_player.gauge_spent_this_strike > 0
		elif condition == "top_discard_is_continous_boost":
			var top_discard_card = performing_player.get_top_discard_card()
			if top_discard_card:
				return top_discard_card.definition['boost']['boost_type'] == "continuous"
			else:
				return false
		elif condition == "opponent_top_discard_is_special":
			var top_discard_card = other_player.get_top_discard_card()
			if top_discard_card:
				return top_discard_card.definition['type'] == "special"
			else:
				return false
		elif condition == "can_continuous_boost_from_gauge":
			return performing_player.can_boost_something(['gauge'], 'continuous')
		elif condition == "not_discarding_boost":
			return active_boost and not active_boost.discard_on_cleanup
		elif condition == "not_sustained":
			var boost_card_id = effect["condition_card_id"]
			for card_id in performing_player.sustained_boosts:
				var card = card_db.get_card(card_id)
				if card.definition['id'] == boost_card_id:
					return false
			return true
		elif condition == "discarded_copy_of_attack":
			var card = active_strike.get_player_card(performing_player)
			return performing_player.get_copy_in_discards(card.definition['id']) != -1
		elif condition == "boost_in_play_or_parents":
			var boost_name = effect["condition_detail"]
			for card in performing_player.continuous_boosts:
				if card.definition['boost']['display_name'] == boost_name:
					return true
			var check_parent_boost = active_boost
			while check_parent_boost:
				if check_parent_boost.card.definition['boost']['display_name'] == boost_name:
					return true
				check_parent_boost = check_parent_boost.parent_boost
			return false
		elif condition == "same_card_as_boost_in_hand":
			assert(active_boost)
			return performing_player.is_card_in_hand_match_normals(active_boost.card)
		elif condition == "boosted_from_gauge":
			assert(active_boost)
			return active_boost.boosted_from_gauge
		else:
			assert(false, "Unimplemented condition")
		# Unmet condition
		return false
	return true

class LocalStrikeConditions:
	var fully_closed : bool = false
	var fully_retreated : bool = false
	var fully_pushed : bool = false
	var fully_pulled : bool = false
	var push_amount : int = 0
	var advanced_through : bool = false
	var advanced_through_buddy : bool = false
	var pulled_past : bool = false
	var manual_reshuffle : bool = false
	var movement_amount : int = 0
	var invalid_by_choice : bool = false

func wait_for_mid_strike_boost():
	return game_state == Enums.GameState.GameState_PlayerDecision and decision_info.type == Enums.DecisionType.DecisionType_BoostNow

func handle_strike_effect(card_id : int, effect, performing_player : Player):
	printlog("STRIKE: Handling effect %s" % [effect])
	if 'for_other_player' in effect:
		performing_player = _get_player(get_other_player(performing_player.my_id))
	if 'character_effect' in effect and effect['character_effect']:
		performing_player.strike_stat_boosts.active_character_effects.append(effect)
		create_event(Enums.EventType.EventType_Strike_CharacterEffect, performing_player.my_id, card_id, "", effect)
	var local_conditions = LocalStrikeConditions.new()
	var performing_start = performing_player.arena_location
	var opposing_player : Player = _get_player(get_other_player(performing_player.my_id))
	var other_start = opposing_player.arena_location
	var buddy_start = performing_player.get_buddy_location()
	var ignore_extra_effects = false
	match effect['effect_type']:
		"add_attack_effect":
			var current_timing = get_current_strike_timing()
			var is_current_timing_player = true
			if current_timing in ['before', 'hit', 'after', 'cleanup']:
				is_current_timing_player = get_current_strike_timing_player_id() == performing_player.my_id
			var effect_to_add = effect['added_effect']
			var to_add_timing = effect['added_effect']['timing']
			effect_to_add['card_id'] = card_id
			if current_timing == to_add_timing and is_current_timing_player:
				# Add it into the current remaining effects list.
				add_remaining_effect(effect_to_add)
			else:
				performing_player.strike_stat_boosts.added_attack_effects.append(effect_to_add)
		"add_attack_triggers":
			var card_ids = effect["discarded_card_ids"]
			add_attack_triggers(performing_player, card_ids, true)
		"add_boost_to_gauge_on_strike_cleanup":
			if card_id == -1:
				assert(false, "ERROR: Unimplemented path to add_boost_to_gauge_on_strike_cleanup")
			if 'not_immediate' in effect and effect['not_immediate']:
				var card = card_db.get_card(card_id)
				var card_name = card_db.get_card_name(card.id)
				performing_player.add_boost_to_gauge_on_strike_cleanup(card_id)
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "'s boosted card %s will go to gauge." % _log_card_name(card_name))
			else:
				# Most effects that use this expect it to be added to gauge immediately
				var card = card_db.get_card(card_id)
				var card_name = card_db.get_card_name(card.id)
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds boosted card %s to gauge." % _log_card_name(card_name))
				performing_player.remove_from_continuous_boosts(card, "gauge")
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
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds boosted card %s to overdrive." % _log_card_name(card_name))
			performing_player.remove_from_continuous_boosts(card, "overdrive")
		"add_hand_to_gauge":
			performing_player.add_hand_to_gauge()
		"add_opponent_strike_to_gauge":
			opposing_player.strike_stat_boosts.move_strike_to_opponent_gauge = true
			handle_strike_attack_immediate_removal(opposing_player)
		"add_passive":
			var passive_name = effect["passive"]
			if performing_player.passive_effects.get(passive_name):
				performing_player.passive_effects[passive_name] += 1
			else:
				performing_player.passive_effects[passive_name] = 1
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "now %s." % effect['description'])
		"add_recursive_choice_for_opponent":
			var recursive_effect = effect["recursive_effect"].duplicate(true)
			for choice in recursive_effect['choice']:
				if choice.get("recursive"):
					choice["per_card_effect"] = effect.duplicate(true)
			do_effect_if_condition_met(opposing_player, card_id, recursive_effect, null)
		"add_set_aside_card_to_deck":
			var card_name = performing_player.get_set_aside_card(effect['id']).definition['display_name']
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "will draw the set-aside card %s." % _log_card_name(card_name))
			performing_player.add_set_aside_card_to_deck(effect['id'])
		"add_strike_to_gauge_after_cleanup":
			if active_strike.extra_attack_in_progress:
				active_strike.extra_attack_data.extra_attack_always_go_to_gauge = true
			else:
				performing_player.strike_stat_boosts.always_add_to_gauge = true
		"add_strike_to_overdrive_after_cleanup":
			performing_player.strike_stat_boosts.always_add_to_overdrive = true
			handle_strike_attack_immediate_removal(performing_player)
		"add_to_gauge_boost_play_cleanup":
			active_boost.cleanup_to_gauge_card_ids.append(card_id)
		"add_to_gauge_immediately":
			var card = card_db.get_card(card_id)
			var card_name = card_db.get_card_name(card.id)
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds boosted card %s to gauge." % _log_card_name(card_name))
			performing_player.remove_from_continuous_boosts(card, "gauge")
		"add_to_gauge_immediately_mid_strike_undo_effects":
			var card = card_db.get_card(card_id)
			var card_name = card_db.get_card_name(card.id)
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds boosted card %s to gauge." % _log_card_name(card_name))
			performing_player.remove_from_continuous_boosts(card, "gauge")
		"add_bottom_discard_to_gauge":
			var amount = 1
			if 'amount' in effect:
				amount = effect['amount']

			var actual_amount = min(amount, len(performing_player.discards))
			if actual_amount > 0:
				var card_ids = []
				for i in range(0, actual_amount):
					card_ids.append(performing_player.discards[i].id)
				var card_names = card_db.get_card_names(card_ids)
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds the bottom %s card(s) of their discards to gauge: %s." % [amount, _log_card_name(card_names)])
				performing_player.add_top_discard_to_gauge(amount, true)
			else:
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "has no cards in their discard pile to add to gauge.")
		"add_bottom_discard_to_hand":
			var amount = 1
			if 'amount' in effect:
				amount = effect['amount']

			var actual_amount = min(amount, len(performing_player.discards))
			if actual_amount > 0:
				var card_ids = []
				for i in range(0, actual_amount):
					card_ids.append(performing_player.discards[i].id)
				var card_names = card_db.get_card_names(card_ids)
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds the bottom %s card(s) of their discards to hand: %s." % [amount, _log_card_name(card_names)])
				performing_player.add_top_discard_to_gauge(amount, true, "hand")
			else:
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "has no cards in their discard pile to add to hand.")
		"add_top_deck_to_bottom":
			performing_player.add_top_deck_to_bottom()
		"add_top_deck_to_gauge":
			var target_player = performing_player
			if 'opponent' in effect and effect['opponent']:
				target_player = opposing_player
			var amount = 1
			if 'amount' in effect:
				amount = effect['amount']
				if str(amount) == "num_discarded_card_ids":
					amount = len(effect['discarded_card_ids'])
				elif str(amount) == "force_spent_this_turn":
					amount = performing_player.total_force_spent_this_turn

			var actual_amount = min(amount, len(target_player.deck))
			if actual_amount > 0:
				var card_names = _card_list_to_string(target_player.deck.slice(0, actual_amount))
				_append_log_full(Enums.LogType.LogType_CardInfo, target_player, "adds the top %s card(s) of their deck to gauge: %s." % [amount, _log_card_name(card_names)])
				target_player.add_top_deck_to_gauge(amount)
			else:
				_append_log_full(Enums.LogType.LogType_CardInfo, target_player, "has no cards in their deck to add to gauge.")
		"add_top_discard_to_gauge":
			var amount = 1
			if 'amount' in effect:
				amount = effect['amount']

			var target_player = performing_player
			if effect.get("opponent"):
				target_player = opposing_player

			var actual_amount = min(amount, len(target_player.discards))
			if actual_amount > 0:
				var card_ids = []
				for i in range(target_player.discards.size() - 1, target_player.discards.size() - 1 - actual_amount, -1):
					card_ids.append(target_player.discards[i].id)
				var card_names = card_db.get_card_names(card_ids)
				_append_log_full(Enums.LogType.LogType_CardInfo, target_player, "adds the top %s card(s) of their discards to gauge: %s." % [amount, _log_card_name(card_names)])
				target_player.add_top_discard_to_gauge(amount)
			else:
				_append_log_full(Enums.LogType.LogType_CardInfo, target_player, "has no cards in their discard pile to add to gauge.")
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
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds the top %s card(s) of their discards to overdrive: %s." % [amount, _log_card_name(card_names)])
				performing_player.add_top_discard_to_overdrive(amount)
			else:
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "has no cards in their discard pile to add to overdrive.")
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
				do_effect_if_condition_met(performing_player, -1, sub_effect, null)
			if game_state != Enums.GameState.GameState_PlayerDecision:
				var advance_effect = effect.duplicate()
				advance_effect['effect_type'] = "advance_INTERNAL"
				advance_effect['stop_on_space'] = stop_on_space
				handle_strike_effect(card_id, advance_effect, performing_player)
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
			performing_player.advance(amount, stop_on_space)
			var new_location = performing_player.arena_location
			var advance_amount = abs(performing_start - new_location)
			_append_log_full(Enums.LogType.LogType_CharacterMovement, performing_player, "advances %s, moving from space %s to %s." % [str(amount), str(previous_location), str(new_location)])
			if (performing_start < other_start and new_location > other_start) or (performing_start > other_start and new_location < other_start):
				# The opponent's space doesn't count as one you move through
				advance_amount -= 1
				local_conditions.advanced_through = true
				handle_advanced_through(performing_player, opposing_player)
				performing_player.moved_past_this_strike = true
				if performing_player.strike_stat_boosts.range_includes_if_moved_past:
					performing_player.strike_stat_boosts.range_includes_opponent = true
					_append_log_full(Enums.LogType.LogType_Effect, performing_player, "advanced through the opponent, putting them in range!")
			if ((performing_player.is_in_or_left_of_location(buddy_start, performing_start) and performing_player.is_in_or_right_of_location(buddy_start, new_location)) or
					(performing_player.is_in_or_right_of_location(buddy_start, performing_start) and performing_player.is_in_or_left_of_location(buddy_start, new_location))):
				local_conditions.advanced_through_buddy = true
			local_conditions.movement_amount = advance_amount
		"armorup":
			performing_player.strike_stat_boosts.armor += effect['amount']
			create_event(Enums.EventType.EventType_Strike_ArmorUp, performing_player.my_id, effect['amount'])
		"armorup_damage_dealt":
			# If Tenacious Mist can be used as an additional attack, this implementation will be incorrect for that case
			var damage_dealt = active_strike.get_damage_taken(opposing_player)
			performing_player.strike_stat_boosts.armor += damage_dealt
			create_event(Enums.EventType.EventType_Strike_ArmorUp, performing_player.my_id, damage_dealt)
		"armorup_current_power":
			var current_power = get_total_power(performing_player)
			performing_player.strike_stat_boosts.armor += current_power
			create_event(Enums.EventType.EventType_Strike_ArmorUp, performing_player.my_id, current_power)
		"armorup_times_gauge":
			var amount = performing_player.gauge.size() * effect['amount']
			performing_player.strike_stat_boosts.armor += amount
			create_event(Enums.EventType.EventType_Strike_ArmorUp, performing_player.my_id, amount)
		"armorup_opponent_per_force_spent_this_turn":
			var amount = performing_player.total_force_spent_this_turn * effect['amount']
			opposing_player.strike_stat_boosts.armor += amount
			create_event(Enums.EventType.EventType_Strike_ArmorUp, opposing_player.my_id, amount)
		"armorup_per_continuous_boost":
			var amount = effect["amount"] * performing_player.get_boosts().size()
			performing_player.strike_stat_boosts.armor += amount
			create_event(Enums.EventType.EventType_Strike_ArmorUp, performing_player.my_id, amount)
		"attack_copy_gauge_or_transform_becomes_ex":
			performing_player.strike_stat_boosts.attack_copy_gauge_or_transform_becomes_ex = true
		"attack_does_not_hit":
			var affected_player = performing_player
			if 'opponent' in effect and effect['opponent']:
				affected_player = opposing_player
			affected_player.strike_stat_boosts.attack_does_not_hit = true
			if 'hide_notice' not in effect or not effect['hide_notice']:
				create_event(Enums.EventType.EventType_Strike_AttackDoesNotHit, affected_player.my_id, card_id)
		"attack_includes_range":
			performing_player.strike_stat_boosts.attack_includes_ranges.append(effect['amount'])
		"attack_is_ex":
			performing_player.strike_stat_boosts.set_ex()
			create_event(Enums.EventType.EventType_Strike_ExUp, performing_player.my_id, card_id)
		"become_wide":
			performing_player.extra_width = 1
			var new_form_string = "3 spaces wide"
			if 'description' in effect:
				new_form_string = effect['description']
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "is now %s!" % new_form_string)
			create_event(Enums.EventType.EventType_BecomeWide, performing_player.my_id, 0, "", "Tinker Tank")
		"block_opponent_move":
			_append_log_full(Enums.LogType.LogType_Effect, opposing_player, "is prevented from moving.")
			opposing_player.cannot_move = true
			create_event(Enums.EventType.EventType_BlockMovement, opposing_player.my_id, card_id)
		"remove_block_opponent_move":
			_append_log_full(Enums.LogType.LogType_Effect, opposing_player, "is no longer prevented from moving.")
			opposing_player.cannot_move = false
		"bonus_action":
			# You cannot take bonus actions during a strike.
			if not active_strike:
				active_boost.action_after_boost = true
				performing_player.strike_action_disabled = false
		"boost_additional":
			assert(active_boost, "ERROR: Additional boost effect when a boost isn't in play")

			if 'discard_this_first' in effect and effect['discard_this_first']:
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards the boosted card %s." % active_boost.card.definition['display_name'])
				active_boost.discarded_already = true
				performing_player.add_to_discards(active_boost.card)

			var valid_zones = ['hand']
			if 'valid_zones' in effect:
				valid_zones = effect['valid_zones']
			var ignore_costs = 'ignore_costs' in effect and effect['ignore_costs']
			if performing_player.can_boost_something(valid_zones, effect['limitation'], ignore_costs):
				create_event(Enums.EventType.EventType_ForceStartBoost, performing_player.my_id, 0, "", valid_zones, effect['limitation'], ignore_costs)
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
		"boost_from_extra":
			# This effect is expected to be a character action.
			if performing_player.can_boost_something(['extra'], effect['limitation']):
				create_event(Enums.EventType.EventType_ForceStartBoost, performing_player.my_id, 0, "", ['extra'], effect['limitation'])
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_BoostNow
				decision_info.player = performing_player.my_id
				decision_info.valid_zones = ['extra']
				decision_info.limitation = effect['limitation']
			else:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no valid extra cards to boost with.")
		"boost_from_gauge":
			# This effect is expected to be a character action.
			if performing_player.can_boost_something(['gauge'], effect['limitation']):
				create_event(Enums.EventType.EventType_ForceStartBoost, performing_player.my_id, 0, "", ['gauge'], effect['limitation'])
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
			# Doing the boost here in handle_strike_effect is awkward as do_boost is ideal
			# Instead, set a flag and do it on overdrive cleanup.
			active_overdrive_boost_top_discard_on_cleanup = true
		"boost_multiple":
			var valid_zones = ['hand']
			if 'valid_zones' in effect:
				valid_zones = effect['valid_zones']
			var amount = effect['amount']
			var shuffle_discard_after = false
			if 'shuffle_discard_after' in effect:
				shuffle_discard_after = effect['shuffle_discard_after']
			var ignore_costs = false
			if 'ignore_costs' in effect:
				ignore_costs = effect['ignore_costs']
			if performing_player.can_boost_something(valid_zones, effect['limitation']):
				create_event(Enums.EventType.EventType_ForceStartBoost, performing_player.my_id, amount, "", valid_zones, effect['limitation'], ignore_costs)
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_BoostNow
				decision_info.amount = amount
				decision_info.player = performing_player.my_id
				decision_info.valid_zones = valid_zones
				decision_info.limitation = effect['limitation']
				decision_info.ignore_costs = ignore_costs
				decision_info.extra_info = shuffle_discard_after
				performing_player.cancel_blocked_this_turn = true
			else:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no cards available to boost.")
		"boost_or_reveal_hand":
			# This effect is expected to be a character action.
			if performing_player.can_boost_something(['hand'], effect['limitation']):
				create_event(Enums.EventType.EventType_ForceStartBoost, performing_player.my_id, 0, "", ['hand'], effect['limitation'])
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_BoostNow
				decision_info.player = performing_player.my_id
				decision_info.valid_zones = ['hand']
				decision_info.limitation = effect['limitation']
			else:
				if "strike_instead_of_reveal" in effect and effect["strike_instead_of_reveal"]:
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
						create_event(Enums.EventType.EventType_ForceStartStrike, performing_player.my_id, 0)
						if active_post_action_effect:
							post_action_interruption = true
				else:
					_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no valid cards in hand to boost with.")
					performing_player.reveal_hand()
		"boost_specific_card":
			var boost_name = effect['boost_name']
			var boost_card_id = -1
			for card in performing_player.hand:
				if card.definition['boost']['display_name'] == boost_name:
					boost_card_id = card.id
					break
			if boost_card_id != -1:
				# Have to set this for do_boost to behave, though it's not technically a decision
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_BoostNow
				decision_info.player = performing_player.my_id
				decision_info.valid_zones = ['hand']
				decision_info.limitation = ""
				decision_info.ignore_costs = false
				create_event(Enums.EventType.EventType_EffectDoBoost, performing_player.my_id, boost_card_id)
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
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "boosts%s %s." % [and_sustain_str, _log_card_name(card_name)])
			# This removes the attack from play, so it needs to affect stats.
			handle_strike_attack_immediate_removal(performing_player)
			if 'boost_effect' in effect:
				var boost_effect = effect['boost_effect']
				do_effect_if_condition_met(performing_player, card_id, boost_effect, null)
		"boost_then_sustain":
			# This effect is expected to be mid-strike.
			assert(active_strike)
			var valid_zones = ['hand']
			if 'valid_zones' in effect:
				valid_zones = effect['valid_zones']
			var ignore_costs = false
			if 'ignore_costs' in effect:
				ignore_costs = effect['ignore_costs']
			var bonus_effect = null
			if 'play_boost_effect' in effect:
				bonus_effect = effect['play_boost_effect']
			if performing_player.can_boost_something(valid_zones, effect['limitation']):
				create_event(Enums.EventType.EventType_ForceStartBoost, performing_player.my_id, 0, "", valid_zones, effect['limitation'], ignore_costs)
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_BoostNow
				decision_info.player = performing_player.my_id
				decision_info.valid_zones = valid_zones
				decision_info.limitation = effect['limitation']
				decision_info.ignore_costs = ignore_costs
				decision_info.bonus_effect = bonus_effect
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
						performing_player.discard_topdeck()

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
				create_event(Enums.EventType.EventType_ForceStartBoost, performing_player.my_id, 0, "", valid_zones, effect['limitation'])
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
					create_event(Enums.EventType.EventType_ForceStartStrike, performing_player.my_id, 0)
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
				create_event(Enums.EventType.EventType_ForceStartBoost, performing_player.my_id, 0, "", valid_zones, limitation)
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_BoostNow
				decision_info.player = performing_player.my_id
				decision_info.valid_zones = valid_zones
				decision_info.limitation = limitation
			else:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no cards available to boost for the overdrive effect.")
		"bottomdeck_from_hand":
			if len(performing_player.hand) > 0:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_CardFromHandToGauge
				decision_info.player = performing_player.my_id
				decision_info.choice_card_id = card_id
				decision_info.destination = "bottomdeck"
				decision_info.valid_zones = ["hand"]
				var min_amount = effect['min_amount']
				var max_amount = effect['max_amount']
				if max_amount == -1:
					max_amount = len(performing_player.hand)
				decision_info.effect = {
					"min_amount": min_amount,
					"max_amount": max_amount,
				}
				if 'per_card_effect' in effect and effect['per_card_effect']:
					decision_info.bonus_effect = effect['per_card_effect']
				create_event(Enums.EventType.EventType_CardFromHandToGauge_Choice, performing_player.my_id, min_amount, "", max_amount)
		"buddy_immune_to_flip":
			performing_player.strike_stat_boosts.buddy_immune_to_flip = true
		"can_spend_life_for_force":
			performing_player.spend_life_for_force_amount = effect['amount']
		"cannot_go_below_life":
			performing_player.strike_stat_boosts.cannot_go_below_life = effect['amount']
		"cannot_stun":
			performing_player.strike_stat_boosts.cannot_stun = true
		"cap_attack_damage_taken":
			performing_player.strike_stat_boosts.cap_attack_damage_taken = effect['amount']
		"choice":
			var multiple = 1
			if 'multiple_amount' in effect:
				multiple = effect['multiple_amount']
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
			elif 'add_bottomdiscard_card_name_to_choices' in effect:
				# Add a 'card_name' field to each choice that's in this array.
				for index in effect['add_bottomdiscard_card_name_to_choices']:
					var choice = effect['choice'][index]
					var card_name = "nothing (discard empty)"
					if choice_player.discards.size() > 0:
						card_name = card_db.get_card_name(choice_player.discards[0].id)
					choice['card_name'] = card_name

			decision_info.choice = effect['choice']
			decision_info.choice_card_id = card_id
			decision_info.multiple_choice_amount = multiple
			create_event(Enums.EventType.EventType_Strike_EffectChoice, choice_player.my_id, 0, "EffectOption")
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
			create_event(Enums.EventType.EventType_Strike_EffectChoice, performing_player.my_id, 0, "EffectOption")
		"choose_calculate_range_from_buddy":
			var optional = 'optional' in effect and effect['optional']
			decision_info.clear()
			decision_info.type = Enums.DecisionType.DecisionType_ChooseArenaLocationForEffect
			decision_info.player = performing_player.my_id
			decision_info.choice_card_id = card_id
			decision_info.effect_type = "calculate_range_from_buddy_current_location"
			decision_info.source = effect['buddy_name']
			decision_info.choice = []
			decision_info.limitation = []
			if optional:
				decision_info.limitation.append(0)
				decision_info.choice.append({
					"effect_type": "pass"
				})

			for location in performing_player.buddy_locations:
				if location == -1:
					continue
				var buddy_id = performing_player.get_buddy_id_at_location(location)

				if location not in decision_info.limitation:
					decision_info.limitation.append(location)
					decision_info.choice.append({
						"effect_type": "calculate_range_from_buddy_current_location",
						"buddy_id": buddy_id
					})
			var actual_choices = len(decision_info.limitation)
			if optional:
				actual_choices -= 1

			# If the only option is to pass, just let this pass.
			if actual_choices > 0:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)
			else:
				assert(false, "Unexpected called choose_calculate_range_from_buddy but can't.")
		"choose_cards_from_top_deck":
			var look_amount = min(effect['look_amount'], performing_player.deck.size())
			if look_amount == 0:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no cards in their deck to look at.")
				if 'strike_after' in effect and effect['strike_after']:
					if not active_boost:
						create_event(Enums.EventType.EventType_ForceStartStrike, performing_player.my_id, 0)
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
				decision_info.effect = effect
				decision_info.amount = look_amount
				decision_info.bonus_effect = effect.get('and_not_passed', null)
				create_event(Enums.EventType.EventType_ChooseFromTopDeck, performing_player.my_id, 0)

				if 'strike_after' in effect and effect['strike_after']:
					performing_player.strike_on_boost_cleanup = true
		"choose_discard":
			var source = "discard"
			var discard_effect = null
			var target_player = performing_player
			if effect.get("opponent"):
				target_player = opposing_player
			if 'discard_effect' in effect:
				discard_effect = effect['discard_effect']
			if 'source' in effect:
				source = effect['source']
			var choice_count = 0
			if source == "discard":
				choice_count = target_player.get_discard_count_of_type(effect['limitation'])
			elif source == "gauge":
				choice_count = target_player.get_gauge_count_of_type(effect['limitation'])
			elif source == "sealed":
				choice_count = target_player.get_sealed_count_of_type(effect['limitation'])
			elif source == "overdrive":
				choice_count = target_player.overdrive.size()
			else:
				assert(false, "Unimplemented source")
			if choice_count > 0:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_ChooseFromDiscard
				decision_info.player = target_player.my_id
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
				create_event(Enums.EventType.EventType_ChooseFromDiscard, target_player.my_id, amount)
			else:
				if effect['limitation']:
					_append_log_full(Enums.LogType.LogType_Effect, target_player, "has no %s cards in %s." % [effect['limitation'], source])
				else:
					_append_log_full(Enums.LogType.LogType_Effect, target_player, "has no cards in %s." % source)
		"choose_opponent_card_to_discard":
			var choice_player = performing_player
			var choice_other_player = opposing_player
			if 'opponent' in effect and effect['opponent']:
				choice_player = opposing_player
				choice_other_player = performing_player

			var cards_available = choice_other_player.get_card_ids_in_hand()
			if 'use_discarded_card_ids' in effect and effect['use_discarded_card_ids']:
				cards_available = effect['discarded_card_ids']
			var decision_effect = effect.duplicate()
			decision_effect['amount'] = 1
			if cards_available.size() > 0:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_ChooseToDiscard
				decision_info.effect_type = "choose_opponent_card_to_discard_internal"
				decision_info.effect = decision_effect
				decision_info.choice_card_id = card_id
				decision_info.player = choice_player.my_id
				decision_info.choice = cards_available
				decision_info.limitation = ""
				create_event(Enums.EventType.EventType_ChooseOpponentCardToDiscard, choice_player.my_id, 0)
			else:
				_append_log_full(Enums.LogType.LogType_Effect, choice_other_player, "has no cards in hand to discard.")
		"choose_opponent_card_to_discard_internal":
			var card_ids = effect['card_ids']
			var card_names = card_db.get_card_names(card_ids)
			_append_log_full(Enums.LogType.LogType_CardInfo, opposing_player, "has card(s) discarded by %s: %s." % [performing_player.name, _log_card_name(card_names)])
			opposing_player.discard(card_ids)
		"choose_sustain_boost":
			var choice_count = performing_player.get_boosts().size()
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
				create_event(Enums.EventType.EventType_ChooseFromBoosts, performing_player.my_id, amount)
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
				do_effect_if_condition_met(performing_player, -1, sub_effect, null)
			if game_state != Enums.GameState.GameState_PlayerDecision:
				var close_effect = effect.duplicate()
				close_effect['effect_type'] = "close_INTERNAL"
				handle_strike_effect(card_id, close_effect, performing_player)
				# and/bonus_effect should be handled by internal version
				ignore_extra_effects = true
		"close_damagetaken":
			var close_per = effect['amount']
			var damage_taken = active_strike.get_damage_taken(performing_player)
			var total_close = close_per * damage_taken
			if total_close > 0:
				var close_effect = {
					"effect_type": "close",
					"amount": total_close,
				}
				handle_strike_effect(card_id, close_effect, performing_player)
		"close_INTERNAL":
			var amount = effect['amount']
			amount += performing_player.strike_stat_boosts.increase_movement_effects_by

			var previous_location = performing_player.arena_location
			performing_player.close(amount)
			var new_location = performing_player.arena_location
			var close_amount = abs(performing_start - new_location)
			local_conditions.fully_closed = close_amount == amount
			_append_log_full(Enums.LogType.LogType_CharacterMovement, performing_player, "closes %s, moving from space %s to %s." % [str(amount), str(previous_location), str(new_location)])
			if 'save_spaces_as_strike_x' in effect and effect['save_spaces_as_strike_x']:
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "'s X for this strike is set to the number of spaces closed, %s." % close_amount)
				performing_player.set_strike_x(close_amount)
			elif 'save_spaces_not_closed_as_strike_x' in effect and effect['save_spaces_not_closed_as_strike_x']:
				var not_closed = amount - close_amount
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "'s X for this strike is set to the number of spaces not closed, %s." % not_closed)
				performing_player.set_strike_x(not_closed)
			local_conditions.movement_amount = close_amount
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
				create_event(Enums.EventType.EventType_Strike_EffectChoice, performing_player.my_id, 0, "Duplicate")
			else:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no other hit effects to copy.")
		"critical":
			performing_player.strike_stat_boosts.critical = true
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "'s strike is Critical!")
			var strike_card = active_strike.get_player_card(performing_player)
			create_event(Enums.EventType.EventType_Strike_Critical, performing_player.my_id, strike_card.id)
		"discard_this":
			if active_boost and not effect.get("ignore_active_boost"):
				active_boost.discard_on_cleanup = true
			else:
				var card = card_db.get_card(card_id)
				var card_name = card_db.get_card_name(card.id)
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards the boosted card %s." % _log_card_name(card_name))
				performing_player.remove_from_continuous_boosts(card)
				opposing_player.remove_from_continuous_boosts(card)
		"discard_same_card_as_boost":
			assert(active_boost)
			var boost_copy_id = performing_player.get_copy_in_hand_match_normals(active_boost.card)
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards a copy of the boosted card %s." % [_log_card_name(active_boost.card.definition['display_name'])])
			performing_player.discard([boost_copy_id])
		"discard_stored_cards":
			var card_ids = []
			for card in performing_player.set_aside_cards:
				card_ids.append(card.id)
			performing_player.discard(card_ids)
		"discard_strike_after_cleanup":
			performing_player.strike_stat_boosts.discard_attack_on_cleanup = true
		"discard_opponent_topdeck":
			opposing_player.discard_topdeck()
		"discard_topdeck":
			performing_player.discard_topdeck()
		"draw_or_discard_to":
			handle_player_draw_or_discard_to_effect(performing_player, card_id, effect)
		"draw_for_card_in_gauge":
			var draw_amount = performing_player.gauge.size()
			if 'per_gauge' in effect:
				draw_amount = floor(draw_amount / effect['per_gauge'])
			if draw_amount > 0:
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "draws %s card(s)." % draw_amount)
				performing_player.draw(draw_amount)
		"draw_for_card_in_hand":
			var hand_size = performing_player.hand.size()
			if hand_size > 0:
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "draws %s card(s)." % hand_size)
				performing_player.draw(hand_size)
		"draw_to":
			var target_hand_size = effect['amount']
			var hand_size = performing_player.hand.size()
			if hand_size < target_hand_size:
				var amount_to_draw = target_hand_size - hand_size
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "draws %s card(s) to reach a hand size of %s." % [amount_to_draw, target_hand_size])
				performing_player.draw(amount_to_draw)
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
				handle_strike_effect(card_id, discard_effect, performing_player)
		"opponent_draw_or_discard_to":
			handle_player_draw_or_discard_to_effect(opposing_player, card_id, effect)
		"dodge_at_range":
			if 'special_range' in effect and effect['special_range'] == "OVERDRIVE_COUNT":
				var current_range = performing_player.overdrive.size()
				performing_player.strike_stat_boosts.dodge_at_range_late_calculate_with  = effect['special_range']
				create_event(Enums.EventType.EventType_Strike_DodgeAttacksAtRange, performing_player.my_id, current_range, "", current_range, "")
			else:
				var effect_card_id = card_id
				if 'card_id' in effect:
					effect_card_id = effect['card_id']
				performing_player.strike_stat_boosts.dodge_at_range_min[effect_card_id] = effect['range_min']
				performing_player.strike_stat_boosts.dodge_at_range_max[effect_card_id] = effect['range_max']
				var buddy_name = null
				if 'from_buddy' in effect:
					performing_player.strike_stat_boosts.dodge_at_range_from_buddy = effect['from_buddy']
					buddy_name = effect['buddy_name']
				create_event(Enums.EventType.EventType_Strike_DodgeAttacksAtRange, performing_player.my_id, effect['range_min'], "", effect['range_max'], buddy_name)
		"dodge_attacks":
			performing_player.strike_stat_boosts.dodge_attacks = true
			create_event(Enums.EventType.EventType_Strike_DodgeAttacks, performing_player.my_id, 0)
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "is now dodging attacks!")
		"dodge_from_opposite_buddy":
			performing_player.strike_stat_boosts.dodge_from_opposite_buddy = true
			create_event(Enums.EventType.EventType_Strike_DodgeFromOppositeBuddy, performing_player.my_id, 0, "", effect['buddy_name'])
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "will dodge attacks from opponents behind %s!" % effect['buddy_name'])
		"dodge_normals":
			performing_player.strike_stat_boosts.dodge_normals = true
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "is now dodging normal attacks!")
		"draw":
			var amount = effect['amount']
			if str(amount) == "strike_x":
				amount = performing_player.strike_stat_boosts.strike_x
			elif str(amount) == "GAUGE_COUNT":
				amount = performing_player.gauge.size()
			elif str(amount) == "SPACES_BETWEEN":
				amount = performing_player.distance_to_opponent() - 1
			amount += performing_player.strike_stat_boosts.increase_draw_effects_by

			var from_bottom = false
			var from_bottom_string = ""
			if 'from_bottom' in effect and effect['from_bottom']:
				from_bottom = true
				from_bottom_string = " from bottom of deck"

			if amount > 0:
				var target_player = performing_player
				if effect.get("opponent"):
					target_player = opposing_player
				target_player.draw(amount, false, from_bottom)
				_append_log_full(Enums.LogType.LogType_CardInfo, target_player, "draws %s card(s)%s." % [amount, from_bottom_string])
				var drawn_card_ids = target_player.hand.slice(-amount, target_player.hand.size()).map(func(item): return item.id)
				if effect.get("reveal"):
					target_player.reveal_card_ids(drawn_card_ids)
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
			create_event(Enums.EventType.EventType_PickNumberFromRange, performing_player.my_id, 0)
		"discard_boost_in_opponent_space":
			decision_info.clear()
			decision_info.destination = "discard"
			var boost_name = ""
			if 'boost_name' in effect:
				boost_name = effect['boost_name']
			if 'overall_effect' in effect:
				decision_info.effect = effect['overall_effect']
			else:
				decision_info.effect = null

			var valid_boosts = []
			for boost in performing_player.get_boosts(true):
				if boost_name and boost.definition['boost']['display_name'] != boost_name:
					continue
				var boost_location = performing_player.get_boost_location(boost.id)
				if boost_location != -1 and opposing_player.is_in_location(boost_location):
					valid_boosts.append(boost)

			if len(valid_boosts) == 1:
				var discard_effect = {
					"effect_type": "discard_continuous_boost_INTERNAL",
					"card_id": valid_boosts[0].id,
				}
				handle_strike_effect(card_id, discard_effect, performing_player)
			elif len(valid_boosts) > 1:
				# Player gets to pick which continuous boost to discard.
				decision_info.limitation = "in_opponent_space"
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.type = Enums.DecisionType.DecisionType_ChooseDiscardContinuousBoost
				decision_info.effect_type = "discard_continuous_boost_INTERNAL"
				decision_info.choice_card_id = card_id
				decision_info.can_pass = false
				decision_info.player = performing_player.my_id
				decision_info.extra_info = boost_name
				create_event(Enums.EventType.EventType_Boost_DiscardContinuousChoice, performing_player.my_id, 1, "", boost_name)
		"discard_continuous_boost":
			var my_boosts = performing_player.get_boosts(true)
			var opponent_boosts = opposing_player.get_boosts(true)
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
				create_event(Enums.EventType.EventType_Boost_DiscardContinuousChoice, performing_player.my_id, 1)
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
					performing_player.remove_from_continuous_boosts(card, destination)
					_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards their boost %s." % boost_name)
				elif opposing_player.is_card_in_continuous_boosts(boost_to_discard_id):
					opposing_player.remove_from_continuous_boosts(card, destination)
					_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards %s's boost %s." % [opposing_player.name, boost_name])

				# Do any bonus effect
				if decision_info.effect:
					handle_strike_effect(card_id, decision_info.effect, performing_player)
		"discard_hand":
			performing_player.discard_hand()
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
				create_event(Enums.EventType.EventType_Boost_DiscardOpponentGauge, performing_player.my_id, 0)
		"discard_opponent_gauge_INTERNAL":
			var chosen_card_id = effect['card_id']
			var card_name = card_db.get_card_name(chosen_card_id)
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards %s from %s's gauge." % [_log_card_name(card_name), opposing_player.name])
			opposing_player.discard([chosen_card_id])
		"discard_random":
			var discard_ids = performing_player.pick_random_cards_from_hand(effect['amount'])
			if discard_ids.size() > 0:
				if effect.get("record_discarded_amount"):
					active_strike.cards_discarded_this_strike += discard_ids.size()
				var discarded_names = card_db.get_card_names(discard_ids)
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards random card(s): %s." % _log_card_name(discarded_names))
				performing_player.discard(discard_ids)
		"discard_random_and_add_triggers":
			var cards_to_discard = performing_player.pick_random_cards_from_hand(1)
			if cards_to_discard.size() > 0:
				performing_player.discard(cards_to_discard)
				add_attack_triggers(performing_player, cards_to_discard, true)
				var discarded_name = card_db.get_card_name(cards_to_discard[0])
				performing_player.plague_knight_discard_names.append(discarded_name)
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards random card: %s." % _log_card_name(discarded_name))
		"effect_per_card_in_zone":
			var zone = effect['zone']
			var per_effect = effect['per_card_effect'].duplicate(true)
			var limitation = effect.get('limitation', "")
			var effect_times = 0
			var cards = []
			match zone:
				"transform":
					cards = performing_player.transforms
				"gauge":
					cards = performing_player.gauge
				"hand":
					cards = performing_player.hand
				"discard":
					cards = performing_player.discards
				"sealed":
					cards = performing_player.sealed
				"stored_cards":
					cards = performing_player.set_aside_cards
				"overdrive":
					cards = performing_player.overdrive
			match limitation:
				"range_to_opponent":
					for card in cards:
						var min_range = get_card_stat(performing_player, card, 'range_min')
						var max_range = get_card_stat(performing_player, card, 'range_max')
						min_range += performing_player.get_total_min_range_bonus(card)
						max_range += performing_player.get_total_max_range_bonus(card)
						var range_to_opponent = performing_player.distance_to_opponent()
						if min_range <= range_to_opponent and max_range >= range_to_opponent:
							effect_times += 1
				_:
					effect_times = cards.size()

			if effect_times > 0:
				if per_effect.get("combine_multiple_into_one"):
					per_effect["amount"] *= effect_times
					effect_times = 1
				for i in range(effect_times):
					# Assumes no decisions.
					do_effect_if_condition_met(performing_player, card_id, per_effect, null)
		"enable_boost_from_gauge":
			performing_player.can_boost_from_gauge = true
		"enable_end_of_turn_draw":
			performing_player.draw_at_end_of_turn = true
		"exceed_end_of_turn":
			performing_player.exceed_at_end_of_turn = true
		"exceed_now":
			performing_player.exceed()
		"exceed_opponent_now":
			opposing_player.exceed()
			# hoping for the best here
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
			handle_strike_effect(
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
			performing_player.force_cost_reduction += effect['amount']
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "now has their force costs reduced by %s!" % performing_player.force_cost_reduction)
		"remove_force_costs_reduced_passive":
			performing_player.force_cost_reduction -= effect['amount']
			if performing_player.force_cost_reduction == 0:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "no longer has their force costs reduced.")
			else:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "now only has their force costs reduced by %s." % performing_player.force_cost_reduction)
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
				create_event(Enums.EventType.EventType_ForceForEffect, force_player.my_id, 0)
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
				handle_strike_effect(card_id, changed_effect, performing_player)
			else:
				var gauge_player = performing_player
				if 'other_player' in effect and effect['other_player']:
					gauge_player = opposing_player
				var available_gauge = gauge_player.get_available_gauge()
				if effect['gauge_max'] == -1:
					effect = effect.duplicate()
					effect['gauge_max'] = available_gauge
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
					decision_info.player = gauge_player.my_id
					decision_info.type = Enums.DecisionType.DecisionType_GaugeForEffect
					decision_info.choice_card_id = card_id
					decision_info.effect = effect
					decision_info.bonus_effect = bonus_effect
					create_event(Enums.EventType.EventType_GaugeForEffect, gauge_player.my_id, 0)
		"gain_advantage":
			next_turn_player = performing_player.my_id
			create_event(Enums.EventType.EventType_Strike_GainAdvantage, performing_player.my_id, 0)
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "gains Advantage!")
		"gain_life":
			var amount = effect['amount']
			if str(amount) == "LAST_SPENT_LIFE":
				amount = performing_player.last_spent_life
			performing_player.life = min(MaxLife, performing_player.life + amount)
			create_event(Enums.EventType.EventType_Strike_GainLife, performing_player.my_id, amount, "", performing_player.life)
			_append_log_full(Enums.LogType.LogType_Health, performing_player, "gains %s life, bringing them to %s!" % [str(amount), str(performing_player.life)])
		"gauge_from_hand":
			var effect_player = performing_player
			if 'opponent' in effect and effect['opponent']:
				effect_player = opposing_player

			var card_type_limitation = effect.get("card_type_limitation", ["normal", "special", "ultra"])
			var valid_cards = effect_player.get_cards_in_hand_matching_types(card_type_limitation)
			var valid_ids = []
			for card in valid_cards:
				valid_ids.append(card.id)

			if len(valid_ids) > 0:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_CardFromHandToGauge
				decision_info.player = effect_player.my_id
				decision_info.choice_card_id = card_id
				decision_info.destination = effect.get("destination", "gauge")
				decision_info.valid_zones = ["hand"]

				var min_amount = effect['min_amount']
				var max_amount = effect['max_amount']
				if 'amount_is_gauge_spent' in effect and effect['amount_is_gauge_spent']:
					min_amount = effect_player.gauge_spent_before_strike
					max_amount = effect_player.gauge_spent_before_strike
				var restricted_to_card_ids = valid_ids
				var show_restriction_list_ui = false
				var from_last_cards = effect.get("from_last_cards")
				if from_last_cards:
					restricted_to_card_ids = []
					show_restriction_list_ui = true
					for i in range(from_last_cards):
						restricted_to_card_ids.append(effect_player.hand[effect_player.hand.size() - 1 - i].id)

				if min_amount > effect_player.hand.size():
					min_amount = effect_player.hand.size()

				decision_info.effect = {
					"min_amount": min_amount,
					"max_amount": max_amount,
					"restricted_to_card_ids": restricted_to_card_ids,
					"show_restriction_list_ui": show_restriction_list_ui,
				}

				decision_info.bonus_effect = {}
				if 'per_card_effect' in effect and effect['per_card_effect']:
					decision_info.bonus_effect = effect['per_card_effect']
				create_event(Enums.EventType.EventType_CardFromHandToGauge_Choice, effect_player.my_id, min_amount, "", max_amount, restricted_to_card_ids)
			else:
				_append_log_full(Enums.LogType.LogType_Effect, effect_player, "has no cards in hand to put in gauge.")
		"generate_free_force":
			performing_player.free_force = effect['amount']
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "can generate %s force for free!" % performing_player.free_force)
		"remove_generate_free_force":
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "no longer generates free force.")
			performing_player.free_force = 0
		"generate_free_force_cc_only":
			performing_player.free_force_cc_only = effect['amount']
		"give_to_player":
			performing_player.strike_stat_boosts.move_strike_to_opponent_boosts = true
			handle_strike_attack_immediate_removal(performing_player)
		"guardup":
			var amount = effect['amount']
			if str(amount) == "strike_x":
				amount = performing_player.strike_stat_boosts.strike_x
			performing_player.strike_stat_boosts.guard += amount
			create_event(Enums.EventType.EventType_Strike_GuardUp, performing_player.my_id, amount)
		"guardup_per_force_spent_this_turn":
			var amount = performing_player.total_force_spent_this_turn * effect['amount']
			performing_player.strike_stat_boosts.guard += amount
			create_event(Enums.EventType.EventType_Strike_GuardUp, performing_player.my_id, amount)
		"guardup_per_two_cards_in_hand":
			performing_player.strike_stat_boosts.guardup_per_two_cards_in_hand = true
			var hand_size = len(performing_player.hand)
			var guard_boost = floor(hand_size / 2.0)
			create_event(Enums.EventType.EventType_Strike_GuardUp, performing_player.my_id, guard_boost)
		"guardup_per_gauge":
			performing_player.strike_stat_boosts.guardup_per_gauge = true
		"guardup_if_copy_of_opponent_attack_in_sealed":
			performing_player.strike_stat_boosts.guardup_if_copy_of_opponent_attack_in_sealed_modifier = effect["amount"]
			var opponent_attack = active_strike.get_player_card(opposing_player)
			if performing_player.has_card_name_in_zone(opponent_attack, "sealed"):
				# Even though this is a passive, show an event now to cover most cases.
				var guard_boost = effect["amount"]
				create_event(Enums.EventType.EventType_Strike_GuardUp, performing_player.my_id, guard_boost)
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
			create_event(Enums.EventType.EventType_Strike_ForceForArmor, defense_player.my_id, incoming_damage, "", offense_player.strike_stat_boosts.ignore_armor)
		"increase_draw_effects":
			var amount = effect['amount']
			performing_player.strike_stat_boosts.increase_draw_effects_by += amount
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "'s draw effects are increased by %s!" % amount)
		"increase_force_spent_before_strike":
			performing_player.force_spent_before_strike += 1
		"increase_gauge_spent_before_strike":
			performing_player.gauge_spent_before_strike += 1
		"increase_movement_effects":
			var amount = effect['amount']
			performing_player.strike_stat_boosts.increase_movement_effects_by += amount
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "'s advance and retreat effects are increased by %s!" % amount)
		"increase_move_opponent_effects":
			var amount = effect['amount']
			performing_player.strike_stat_boosts.increase_move_opponent_effects_by += amount
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "'s push and pull effects are increased by %s!" % amount)
		"invert_range":
			performing_player.strike_stat_boosts.invert_range = true
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "inverts their range!")
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
			create_event(Enums.EventType.EventType_Strike_EffectChoice, performing_player.my_id, 0, "EffectOption")
		"may_ignore_movement_limit":
			var movement_type = decision_info.source
			var movement_amount = decision_info.amount
			var followups = decision_info.limitation

			var limited_amount = min(movement_amount, performing_player.movement_limit)
			if movement_amount == limited_amount:
				# There's no choice, so just do nothing because it is irrelevant.
				pass
			else:
				var choice = [
					{
						'effect_type': movement_type + '_INTERNAL',
						'amount': movement_amount
					},
					{
						'effect_type': movement_type + '_INTERNAL',
						'amount': limited_amount
					}
				]
				if followups['and']:
					choice[0]['and'] = followups['and']
					choice[1]['and'] = followups['and']
				if followups['bonus_effect']:
					choice[0]['bonus_effect'] = followups['bonus_effect']
					choice[1]['bonus_effect'] = followups['bonus_effect']

				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "may ignore the movement limit!")
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_EffectChoice
				decision_info.player = performing_player.my_id
				decision_info.choice = choice
				decision_info.choice_card_id = card_id
				create_event(Enums.EventType.EventType_Strike_EffectChoice, performing_player.my_id, 0, "EffectOption")
		"move_random_cards":
			var card_count = effect['amount']
			var from_zone = effect['from_zone']
			var to_zone = effect['to_zone']
			var target_player = performing_player
			var effecting_player = performing_player
			if effect.get("opponent", false):
				target_player = opposing_player
			if from_zone == "hand" and to_zone == "discard":
				card_count -= target_player.strike_stat_boosts.reduce_discard_effects_by
				if card_count < 0:
					card_count = 0

			var card_ids = target_player.pick_random_cards_from_hand(card_count)
			if card_ids.size() > 0:
				var card_names = card_db.get_card_names(card_ids)
				if from_zone == "hand" and to_zone == "overdrive":
					_append_log_full(Enums.LogType.LogType_CardInfo, target_player, "discards random card(s) to opponent's Overdrive: %s." % _log_card_name(card_names))
					target_player.discard(card_ids)
					effecting_player.move_cards_to_overdrive(card_ids, "opponent_discard")
				else:
					var action_word = "discards"
					var destination_str = ""
					if to_zone == "gauge":
						action_word = "moves"
						destination_str = "to Gauge"
						for to_gauge_card in card_ids:
							performing_player.move_card_from_hand_to_gauge(to_gauge_card)
					else:
						target_player.discard(card_ids)

					_append_log_full(Enums.LogType.LogType_CardInfo, target_player, "%s random card(s)%s: %s." % [action_word, destination_str, _log_card_name(card_ids)])
		"move_to_space":
			var space = effect['amount']
			var remove_buddies_encountered = effect['remove_buddies_encountered']
			var previous_location = performing_player.arena_location
			performing_player.move_to(space, false, remove_buddies_encountered)
			var new_location = performing_player.arena_location
			_append_log_full(Enums.LogType.LogType_CharacterMovement, performing_player, "moves from space %s to %s." % [str(previous_location), str(performing_player.arena_location)])

			if (performing_start < other_start and new_location > other_start) or (performing_start > other_start and new_location < other_start):
				# The opponent's space doesn't count as one you move through
				local_conditions.advanced_through = true
				handle_advanced_through(performing_player, opposing_player)
				performing_player.moved_past_this_strike = true
				if performing_player.strike_stat_boosts.range_includes_if_moved_past:
					performing_player.strike_stat_boosts.range_includes_opponent = true
					_append_log_full(Enums.LogType.LogType_Effect, performing_player, "advanced through the opponent, putting them in range!")
			if ((performing_player.is_in_or_left_of_location(buddy_start, performing_start) and performing_player.is_in_or_right_of_location(buddy_start, new_location)) or
					(performing_player.is_in_or_right_of_location(buddy_start, performing_start) and performing_player.is_in_or_left_of_location(buddy_start, new_location))):
				local_conditions.advanced_through_buddy = true
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
			var move_in_attack_range = 'move_in_attack_range' in effect and effect['move_in_attack_range']
			if 'move_min' in effect:
				move_min = effect['move_min']
			if 'move_max' in effect:
				move_max = effect['move_max']

			var advance_only = 'advance_only' in effect and effect['advance_only']

			var and_effect = null
			var bonus_effect = null
			if 'and' in effect:
				and_effect = effect['and']
			if 'bonus_effect' in effect:
				bonus_effect = effect['bonus_effect']

			decision_info.limitation = []
			# If not moving is an option, enable "pass" button
			if move_min == 0 or ('optional' in effect and effect['optional']):
				decision_info.limitation.append(0)
				decision_info.choice.append({
					"effect_type": "pass",
					"and": and_effect
				})

			var nowhere_to_move = true
			var player_location = performing_player.arena_location
			var opponent_location = opposing_player.arena_location
			for i in range(MinArenaLocation, MaxArenaLocation+1):
				if not performing_player.can_move_to(i, true):
					continue

				if advance_only:
					if performing_player.is_left_of_location(opponent_location) and performing_player.is_right_of_location(i):
						continue
					elif performing_player.is_right_of_location(opponent_location) and performing_player.is_left_of_location(i):
						continue

				var valid_space = false
				if move_in_attack_range:
					var arena_distance = abs(i - get_attack_origin(performing_player, opponent_location))
					var min_range = get_total_min_range(performing_player)
					var max_range = get_total_max_range(performing_player)
					valid_space = min_range <= arena_distance and arena_distance <= max_range
				else:
					var movement_distance = performing_player.movement_distance_between(player_location, i)
					valid_space = move_min <= movement_distance and movement_distance <= move_max

				if valid_space:
					decision_info.limitation.append(i)
					decision_info.choice.append({
						"effect_type": "move_to_space",
						"amount": i,
						"remove_buddies_encountered": remove_buddies_encountered,
						"and": and_effect,
						"bonus_effect": bonus_effect
					})
					nowhere_to_move = false

			if not nowhere_to_move:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)
			else:
				_append_log_full(Enums.LogType.LogType_CharacterMovement, performing_player, "has no spaces to move to!")
				create_event(Enums.EventType.EventType_BlockMovement, performing_player.my_id, 0)
		"name_card_opponent_discards":
			var amount = effect.get("amount", 1)
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.clear()
			decision_info.type = Enums.DecisionType.DecisionType_NameCard_OpponentDiscards
			decision_info.effect_type = "name_card_opponent_discards_internal"
			decision_info.choice_card_id = card_id
			decision_info.player = performing_player.my_id
			decision_info.amount = amount
			decision_info.effect = effect
			decision_info.extra_info = []

			if 'discard_effect' in effect:
				decision_info.bonus_effect = effect['discard_effect']
			create_event(Enums.EventType.EventType_Boost_NameCardOpponentDiscards, performing_player.my_id, decision_info.amount)
		"name_card_opponent_discards_internal":
			var named_card_name = NullNamedCard
			if effect['card_id'] > 0:
				var named_card = card_db.get_card(effect['card_id'])
				# named_card is the individual card but
				# this should discard "by name", so instead of using that
				# match card.definition['id']'s instead.
				named_card_name = named_card.definition['id']
			decision_info.extra_info.append(named_card_name)
			if decision_info.amount > 1:
				# Naming multiple cards, so queue up another name card
				# and save this one in the extra info.
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.amount -= 1
				create_event(Enums.EventType.EventType_Boost_NameCardOpponentDiscards, performing_player.my_id, decision_info.amount)
			else:
				var before_discard_count = opposing_player.discards.size()
				var effect_copy = decision_info.effect
				var reveal_hand_after = effect_copy.get("reveal_hand_after", false)
				var discard_all_copies = effect_copy.get("discard_all_copies", false)
				for discard_name in decision_info.extra_info:
					opposing_player.discard_matching_or_reveal(
						discard_name,
						discard_all_copies,
						reveal_hand_after # skip_reveal=true if we're revealing the hand afterwards.
					)

				var discarded_card = before_discard_count < opposing_player.discards.size()
				if discarded_card and decision_info.bonus_effect:
					handle_strike_effect(decision_info.choice_card_id, decision_info.bonus_effect, performing_player)
				if reveal_hand_after:
					opposing_player.reveal_hand()
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
				create_event(Enums.EventType.EventType_PickNumberFromRange, performing_player.my_id, 0)
			else:
				assert(false, "Target effect for name_range not found.")
				decision_info.clear()
		"negate_boost":
			assert(active_boost)
			_append_log_full(Enums.LogType.LogType_Effect, active_boost.playing_player, "'s boost effect is negated.")
			active_boost.boost_negated = true
			active_boost.discard_on_cleanup = true
		"only_hits_if_opponent_on_any_buddy":
			performing_player.strike_stat_boosts.only_hits_if_opponent_on_any_buddy = true
		"opponent_discard_normals_or_reveal":
			var amount = effect['amount']
			amount -= opposing_player.strike_stat_boosts.reduce_discard_effects_by
			var adjusted_effect = effect.duplicate()
			adjusted_effect['amount'] = amount

			var normals_in_hand = opposing_player.get_cards_in_hand_of_type("normal")
			var normal_ids = []
			for card in normals_in_hand:
				normal_ids.append(card.id)
			if normal_ids.size() < amount:
				# Discard all normals and reveal hand.
				_append_log_full(Enums.LogType.LogType_Effect, opposing_player, "discards all normals and reveals their hand.")
				opposing_player.discard(normal_ids)
				opposing_player.reveal_hand()
			elif amount > 0:
				# Opponent chooses which to discard, even if they only have that many to hide how many normals they have.
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_ChooseToDiscard
				decision_info.effect_type = "opponent_discard_choose_internal"
				decision_info.effect = adjusted_effect
				decision_info.bonus_effect = null
				decision_info.destination = "discard"
				decision_info.limitation = "normal"
				decision_info.can_pass = false

				decision_info.choice_card_id = card_id
				decision_info.player = opposing_player.my_id
				create_event(Enums.EventType.EventType_Strike_ChooseToDiscard, opposing_player.my_id, amount)

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
				create_event(Enums.EventType.EventType_Strike_ChooseToDiscard, opposing_player.my_id, amount)
			else:
				# Didn't have any that matched, so forced to reveal hand.
				_append_log_full(Enums.LogType.LogType_Effect, opposing_player, "has no matching cards so their hand is revealed.")
				opposing_player.reveal_hand()
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
					create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)
				else:
					# Just do it immediately.
					handle_strike_effect(card_id, decision_info.choice[0], performing_player)
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
				create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)
		"replace_wild_swing":
			# Assumption: this is still before any meaningful strike stats have happened.
			var attack_card = active_strike.get_player_card(performing_player)
			var previous_attack_goes_to = effect.get("previous_attack_to", "discard")
			performing_player.invalid_card_moved_elsewhere = true
			match previous_attack_goes_to:
				"gauge":
					performing_player.add_to_gauge(attack_card)
				"hand":
					performing_player.add_to_hand(attack_card, true)
				"discard":
					performing_player.add_to_discards(attack_card)
			if not effect.get("skip_swing"):
				performing_player.wild_strike(true)
		"reveal_copy_for_advantage":
			var copy_id = effect['copy_id']
			# The player has selected to reveal a copy if they have one.
			# Otherwise, do nothing.
			var copy_card_id = performing_player.get_copy_in_hand(copy_id)
			if copy_card_id != -1:
				var card_name = card_db.get_card_name(copy_card_id)
				next_turn_player = performing_player.my_id
				performing_player.reveal_card_ids([copy_card_id])
				create_event(Enums.EventType.EventType_RevealCard, performing_player.my_id, copy_card_id)
				create_event(Enums.EventType.EventType_Strike_GainAdvantage, performing_player.my_id, 0)
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "reveals a copy of %s in their hand." % _log_card_name(card_name))
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "gains Advantage!")
		"reveal_hand":
			if 'opponent' in effect and effect['opponent']:
				opposing_player.reveal_hand()
			else:
				performing_player.reveal_hand()
		"reveal_hand_and_topdeck":
			if 'opponent' in effect and effect['opponent']:
				opposing_player.reveal_hand_and_topdeck()
			else:
				performing_player.reveal_hand_and_topdeck()
		"reveal_topdeck":
			if 'opponent' in effect and effect['opponent']:
				opposing_player.reveal_topdeck()
			else:
				var reveal_to_both = false
				if 'reveal_to_both' in effect and effect['reveal_to_both']:
					reveal_to_both = true
				performing_player.reveal_topdeck(reveal_to_both)
		"reveal_strike":
			if performing_player == active_strike.initiator:
				active_strike.initiator_set_face_up = true
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "initiates with a face-up attack!")
				var card_name = card_db.get_card_name(active_strike.initiator_card.id)
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "is striking with %s." % _log_card_name(card_name))
			else:
				active_strike.defender_set_face_up = true
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "responds with a face-up attack!")
				var card_name = card_db.get_card_name(active_strike.defender_card.id)
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "is striking with %s." % _log_card_name(card_name))
			create_event(Enums.EventType.EventType_RevealStrike_OnePlayer, performing_player.my_id, 0)
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
				create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)
		"move_to_buddy":
			var buddy_id = ""
			if 'buddy_id' in effect:
				buddy_id = effect['buddy_id']
			var buddy_name = performing_player.get_buddy_name(buddy_id)
			var buddy_location = performing_player.get_buddy_location(buddy_id)
			var previous_location = performing_player.arena_location
			performing_player.move_to(buddy_location)
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
			create_event(Enums.EventType.EventType_Strike_OpponentCantMovePast, performing_player.my_id, 0)
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "cannot be advanced through!")
		"opponent_cant_move_past_buddy":
			var buddy_id = ""
			if 'buddy_id' in effect:
				buddy_id = effect['buddy_id']
			else:
				buddy_id = performing_player.buddy_id_to_index.keys()[0]
			var buddy_name = performing_player.get_buddy_name(buddy_id)

			opposing_player.cannot_move_past_opponent_buddy_id = buddy_id
			create_event(Enums.EventType.EventType_Strike_OpponentCantMovePast, performing_player.my_id, 0, "", buddy_name)
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

				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "returns their attack %s to the top of their deck." % _log_card_name(extra_card_name))
				performing_player.add_to_top_of_deck(extra_card, true)
				active_strike.cards_in_play.erase(extra_card) #???
			else:
				performing_player.strike_stat_boosts.attack_to_topdeck_on_cleanup = true
				handle_strike_attack_immediate_removal(performing_player)
		"return_all_copies_of_top_discard_to_hand":
			performing_player.return_all_copies_of_top_discard_to_hand()
		"nothing":
			# Do nothing.
			pass
		"opponent_discard_choose":
			var allow_fewer = 'allow_fewer' in effect and effect['allow_fewer']
			var destination = "discard"
			if 'destination' in effect:
				destination = effect['destination']
			var discard_effect = null
			if 'discard_effect' in effect:
				discard_effect = effect['discard_effect']

			var this_effect = effect.duplicate()
			if str(this_effect['amount']) == "force_spent_before_strike":
				# intentionally performing_player, rather than choice_player
				this_effect['amount'] = performing_player.force_spent_before_strike
			elif str(this_effect['amount']) == "CARDS_DISCARDED_THIS_STRIKE":
				this_effect['amount'] = active_strike.cards_discarded_this_strike

			var discard_amount = this_effect['amount']
			if not allow_fewer:
				discard_amount -= opposing_player.strike_stat_boosts.reduce_discard_effects_by
				if discard_amount < 0:
					discard_amount = 0
			this_effect['amount'] = discard_amount

			if discard_amount > 0 and (opposing_player.hand.size() > discard_amount or (allow_fewer and opposing_player.hand.size() > 0)):
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_ChooseToDiscard
				decision_info.effect_type = "opponent_discard_choose_internal"
				decision_info.effect = this_effect
				decision_info.bonus_effect = discard_effect
				decision_info.destination = destination
				decision_info.limitation = ""
				decision_info.can_pass = false

				decision_info.choice_card_id = card_id
				decision_info.player = opposing_player.my_id
				create_event(Enums.EventType.EventType_Strike_ChooseToDiscard, opposing_player.my_id, discard_amount, "", allow_fewer)
			else:
				create_event(Enums.EventType.EventType_Strike_ChooseToDiscard_Info, opposing_player.my_id, discard_amount)
				# Forced to discard whole hand.
				var card_ids = []
				if discard_amount > 0 and opposing_player.hand.size() > 0:
					assert(opposing_player.hand.size() <= discard_amount)
					card_ids = opposing_player.get_card_ids_in_hand()
					if destination == "discard":
						opposing_player.discard_hand()
					elif destination == "reveal":
						opposing_player.reveal_hand()

				if discard_effect:
					discard_effect = discard_effect.duplicate()
					discard_effect['discarded_card_ids'] = card_ids
					do_effect_if_condition_met(opposing_player, card_id, discard_effect, local_conditions)
				elif len(card_ids) < discard_amount and 'smaller_discard_effect' in effect:
					do_effect_if_condition_met(opposing_player, card_id, effect['smaller_discard_effect'], local_conditions)
		"opponent_discard_choose_internal":
			var cards = effect['card_ids']
			var card_names = card_db.get_card_names(cards)
			if effect['destination'] == "discard":
				_append_log_full(Enums.LogType.LogType_CardInfo, opposing_player, "has %s choose cards to discard: %s." % [performing_player.name, _log_card_name(card_names)])
				performing_player.discard(cards)
			elif effect['destination'] == "reveal":
				_append_log_full(Enums.LogType.LogType_CardInfo, opposing_player, "has %s choose cards to reveal: %s." % [performing_player.name, _log_card_name(card_names)])
				performing_player.reveal_card_ids(cards)
				for revealed_card_id in cards:
					create_event(Enums.EventType.EventType_RevealCard, performing_player.my_id, revealed_card_id)
		"opponent_discard_hand":
			var num_discarded = opposing_player.hand.size()

			if opposing_player.strike_stat_boosts.reduce_discard_effects_by > 0:
				var manual_discard_effect = {
					"effect_type": "opponent_discard_choose",
					"amount": num_discarded
				} # opponent_discard_choose will handle the smaller discard amount
				handle_strike_effect(card_id, manual_discard_effect, performing_player)
				num_discarded -= opposing_player.strike_stat_boosts.reduce_discard_effects_by
			else:
				opposing_player.discard_hand()

			if 'save_num_discarded_as_strike_x' in effect and effect['save_num_discarded_as_strike_x']:
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "'s X for this strike is set to the number of discarded cards, %s." % num_discarded)
				performing_player.set_strike_x(num_discarded)
		"opponent_discard_random":
			var discard_amount = effect['amount']
			discard_amount -= opposing_player.strike_stat_boosts.reduce_discard_effects_by
			if discard_amount < 0:
				discard_amount = 0

			var discard_ids = opposing_player.pick_random_cards_from_hand(discard_amount)
			if discard_ids.size() > 0:
				var discarded_names = card_db.get_card_names(discard_ids)
				if 'destination' in effect and effect['destination'] == "overdrive":
					_append_log_full(Enums.LogType.LogType_CardInfo, opposing_player, "discards random card(s) to opponent's overdrive: %s." % _log_card_name(discarded_names))
					opposing_player.discard(discard_ids)
					performing_player.move_cards_to_overdrive(discard_ids, "opponent_discard")
				else:
					_append_log_full(Enums.LogType.LogType_CardInfo, opposing_player, "discards random card(s): %s." % _log_card_name(discarded_names))
					opposing_player.discard(discard_ids)
		"pass":
			# Do nothing.
			pass
		"place_boost_in_space":
			var in_attack_range = 'in_attack_range' in effect and effect['in_attack_range']
			var valid_locations = null
			if 'valid_locations' in effect:
				valid_locations = effect['valid_locations']
			var stop_on_space_effect = 'stop_on_space_effect' in effect and 'stop_on_space_effect'
			var boost_already_placed = 'boost_already_placed' in effect and effect['boost_already_placed']

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
				if valid_locations != null and i not in valid_locations:
					continue

				decision_info.limitation.append(i)
				decision_info.choice.append({
					"effect_type": "place_boost_in_space_internal",
					"card_id": card_id,
					"location": i,
					"and": and_effect,
					"stop_on_space_effect": stop_on_space_effect,
					"boost_already_placed": boost_already_placed
				})
			create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)
		"place_boost_in_space_internal":
			var location = effect['location']
			var placed_card_id = effect['card_id']
			var stop_on_space_effect = effect['stop_on_space_effect']

			if effect['boost_already_placed']:
				performing_player.change_boost_location(placed_card_id, location)
			else:
				performing_player.add_boost_to_location(placed_card_id, location, stop_on_space_effect)
		"lightningrod_strike":
			var lightning_card_id = effect['card_id']
			var location = effect['location']
			var card_name = effect['card_name']

			# Remove lightning rod and put the card back in hand.
			var lightning_card = performing_player.remove_lightning_card(lightning_card_id, location)
			performing_player.add_to_hand(lightning_card, true)
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds Lightning Rod %s to their hand." % _log_card_name(card_name))
			create_event(Enums.EventType.EventType_PlaceLightningRod, performing_player.my_id, lightning_card_id, "", location, false)

			# Deal the damage
			var damage_effect = {
				"effect_type": "take_damage",
				"opponent": true,
				"nonlethal": true,
				"amount": 2
			}
			handle_strike_effect(lightning_card_id, damage_effect, performing_player)
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
				create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)
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
					handle_strike_attack_immediate_removal(performing_player)
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
				create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)
		"place_lightningrod_internal":
			var location = effect['location']
			performing_player.place_top_discard_as_lightningrod(location)
		"place_buddy_at_range":
			handle_place_buddy_at_range(performing_player, card_id, effect)
		"place_buddy_into_space":
			var space = effect['amount']
			var buddy_id = ""
			if 'buddy_id' in effect:
				buddy_id = effect['buddy_id']
			var old_buddy_pos = performing_player.get_buddy_location(buddy_id)
			performing_player.place_buddy(space, buddy_id)

			var buddy_name = performing_player.get_buddy_name(buddy_id)
			if old_buddy_pos == -1:
				_append_log_full(Enums.LogType.LogType_CharacterMovement, performing_player, "moves %s to space %s." % [buddy_name, str(space)])
			else:
				_append_log_full(Enums.LogType.LogType_CharacterMovement, performing_player, "moves %s from space %s to %s." % [buddy_name, str(old_buddy_pos), str(space)])

			if 'place_other_buddy_effect' in effect:
				handle_place_buddy_at_range(performing_player, card_id, effect['place_other_buddy_effect'])
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
			create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)
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
				create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)
		"place_buddy_onto_opponent":
			var buddy_id = ""
			if 'buddy_id' in effect:
				buddy_id = effect['buddy_id']
			var old_buddy_pos = performing_player.get_buddy_location(buddy_id)
			var buddy_name = performing_player.get_buddy_name(buddy_id)
			performing_player.place_buddy(opposing_player.arena_location, buddy_id)
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
			performing_player.place_buddy(performing_player.arena_location, buddy_id)
			var space = performing_player.get_buddy_location(buddy_id)
			if old_buddy_pos == -1:
				_append_log_full(Enums.LogType.LogType_CharacterMovement, performing_player, "moves %s to themselves on space %s." % [buddy_name, str(space)])
			else:
				_append_log_full(Enums.LogType.LogType_CharacterMovement, performing_player, "moves %s to themselves, from space %s to %s." % [buddy_name, str(old_buddy_pos), str(space)])
		"place_topdeck_under_boost":
			performing_player.place_top_deck_under_boost(card_id)
		"play_boost_with_cards_under":
			performing_player.setup_boost_with_cards_under(card_id)
		"draw_cards_under_boost_and_remove":
			var boost_name = card_db.get_card_name(card_id)
			var cards_under_boost = performing_player.get_cards_under_boost(card_id)
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds %s card(s) under %s to their hand." % [len(cards_under_boost), boost_name])
			for card in cards_under_boost:
				performing_player.add_to_hand(card, false)
			performing_player.remove_boost_with_cards_under(card_id)
		"place_next_buddy":
			var require_unoccupied = effect['require_unoccupied']
			var destination = effect['destination']
			var num_buddies = effect['amount']
			var valid_new_positions = [1,2,3,4,5,6,7,8,9]
			var already_removed_buddy = 'already_removed_buddy' in effect and effect['already_removed_buddy']
			if already_removed_buddy and effect.get("valid_new_positions"):
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
								"and": and_effect
							}
						})
				if decision_info.choice.size() == 1:
					# Only one choice, so just do it immediately.
					handle_strike_effect(card_id, decision_info.choice[0], performing_player)
				else:
					change_game_state(Enums.GameState.GameState_PlayerDecision)
					create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)
			else:
				# No valid positions to put the buddy, so skip this.
				# The and effect will occur normally if one exists.
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no valid locations to place %s." % effect['buddy_name'])
		"move_any_boost":
			var move_min = effect['amount_min']
			var move_max = effect['amount_max']
			var must_select_other_buddy_first = true
			decision_info.clear()
			decision_info.type = Enums.DecisionType.DecisionType_ChooseArenaLocationForEffect
			decision_info.player = performing_player.my_id
			decision_info.choice_card_id = card_id
			decision_info.effect_type = "place_boost_in_space"
			decision_info.source = effect['boost_name']
			decision_info.choice = []
			decision_info.limitation = []
			decision_info.extra_info = must_select_other_buddy_first

			var location_choice_map = {}

			# First, the player has to select a boost to remove.
			# Then, they have to place it in a valid space.
			for boost in performing_player.continuous_boosts:
				if boost.definition['boost']['display_name'] != effect['boost_name']:
					continue
				var boost_id = boost.id
				var location = performing_player.get_boost_location(boost.id)
				if location == -1:
					continue

				var valid_locations = []
				for i in range(MinArenaLocation, MaxArenaLocation + 1):
					# Add this space if it is within the amount from the starting buddy location.
					if abs(location - i) >= move_min and abs(location - i) <= move_max:
						valid_locations.append(i)

				if valid_locations.size() > 0:
					var boost_str = _get_boost_and_card_name(boost)
					if location not in location_choice_map:
						location_choice_map[location] = []
					location_choice_map[location].append({
						"effect_type": "place_boost_in_space",
						"boost_name": boost_str,
						"card_id": boost_id,
						"boost_already_placed": true,
						"valid_locations": valid_locations
					})

			# Account for multiple boosts in the same space
			for location in range(MinArenaLocation, MaxArenaLocation + 1):
				if location not in location_choice_map:
					continue

				var location_choices = location_choice_map[location]
				decision_info.limitation.append(location)
				if len(location_choices) == 1:
					decision_info.choice.append(location_choices[0])
				else:
					var choice_effect = {
						"effect_type": "choice",
						"choice": location_choices
					}
					decision_info.choice.append(choice_effect)

			var actual_choices = len(decision_info.limitation)

			# If the only option is to pass, just let this pass.
			if actual_choices > 0:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)
			else:
				assert(false, "Unexpected called move_any_boost but can't.")
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
					var buddy_at_location = performing_player.get_buddy_id_at_location(i)
					if buddy_at_location != "" and buddy_at_location != buddy_id:
						# Skip if there is already a buddy here, but allow self.
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
				create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)
			else:
				assert(false, "Unexpected called move_any_buddy but can't.")
		"passive_powerup_per_card_in_hand":
			var amount_per_hand = effect['amount']
			performing_player.strike_stat_boosts.passive_powerup_per_card_in_hand = amount_per_hand
			var hand_size = performing_player.hand.size()
			var total_powerup = amount_per_hand * hand_size
			if total_powerup != 0:
				create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, total_powerup)
		"passive_speedup_per_card_in_hand":
			var amount_per_hand = effect['amount']
			performing_player.strike_stat_boosts.passive_speedup_per_card_in_hand = amount_per_hand
			var hand_size = performing_player.hand.size()
			var total_speedup = amount_per_hand * hand_size
			if total_speedup != 0:
				create_event(Enums.EventType.EventType_Strike_SpeedUp, performing_player.my_id, total_speedup)
		"play_attack_from_hand":
			# Implement the choice via discard effect.
			var discard_effect = {
				"effect_type": "self_discard_choose",
				"optional": true,
				"amount": 1,
				"limitation": "can_pay_cost",
				"destination": "play_attack",
			}
			handle_strike_effect(card_id, discard_effect, performing_player)
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
			create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, amount)
		"powerup_both_players":
			var amount = effect['amount']
			performing_player.add_power_bonus(amount)
			opposing_player.add_power_bonus(amount)
			create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, amount)
			create_event(Enums.EventType.EventType_Strike_PowerUp, opposing_player.my_id, amount)
		"powerup_per_armor_used":
			var armor_consumed = performing_player.strike_stat_boosts.consumed_armor
			var power_change = armor_consumed * effect['amount']
			performing_player.add_power_bonus(power_change)
			create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, power_change)
		"powerup_per_boost_in_play":
			var boosts_in_play = performing_player.get_boosts().size()
			if boosts_in_play > 0:
				var amount = effect['amount'] * boosts_in_play
				performing_player.add_power_bonus(amount)
				create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, effect['amount'] * boosts_in_play)
		"powerup_per_card_in_hand":
			var amount_per_hand = effect['amount']
			var hand_size = performing_player.hand.size()
			var total_powerup = amount_per_hand * hand_size
			total_powerup = min(total_powerup, effect['amount_max'])
			if total_powerup > 0:
				performing_player.add_power_bonus(total_powerup)
				create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, total_powerup)
		"powerup_per_card_in_opponent_hand":
			var amount_per_hand = effect['amount']
			var hand_size = opposing_player.hand.size()
			if 'per_card' in effect:
				hand_size = floor(hand_size / effect['per_card'])
			var total_powerup = amount_per_hand * hand_size
			if total_powerup > 0:
				performing_player.add_power_bonus(total_powerup)
				create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, total_powerup)
		"powerup_per_force_spent_this_turn":
			var amount = performing_player.total_force_spent_this_turn * effect['amount']
			performing_player.add_power_bonus(amount)
			create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, amount)
		"powerup_per_gauge":
			var amount_per_gauge = effect['amount']
			var count_player = performing_player
			if effect.get("count_opponent"):
				count_player = opposing_player
			var gauge_size = count_player.gauge.size()
			var total_powerup = amount_per_gauge * gauge_size
			var amount_max = effect.get("amount_max", 999)
			total_powerup = min(total_powerup, amount_max)
			if total_powerup > 0:
				performing_player.add_power_bonus(total_powerup)
				create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, total_powerup)
		"powerup_per_guard":
			var guard = get_total_guard(performing_player)
			if guard > 0:
				var bonus_power = effect['amount'] * guard
				if 'maximum' in effect:
					bonus_power = min(bonus_power, effect['maximum'])
				performing_player.add_power_bonus(bonus_power)
				create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, bonus_power)
		"powerup_per_armor":
			var armor = get_total_armor(performing_player)
			if armor > 0:
				var bonus_power = effect['amount'] * armor
				if 'maximum' in effect:
					bonus_power = min(bonus_power, effect['maximum'])
				performing_player.add_power_bonus(bonus_power)
				create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, bonus_power)
		"powerup_per_speed":
			var speed = get_total_speed(performing_player)
			if speed > 0:
				var bonus_power = effect['amount'] * speed
				if 'maximum' in effect:
					bonus_power = min(bonus_power, effect['maximum'])
				performing_player.add_power_bonus(bonus_power)
				create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, bonus_power)
		"powerup_per_power":
			var power = get_total_power(performing_player)
			if power > 0:
				var bonus_power = effect['amount'] * power
				if 'maximum' in effect:
					bonus_power = min(bonus_power, effect['maximum'])
				performing_player.add_power_bonus(bonus_power)
				create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, bonus_power)
		"powerup_per_sealed_amount":
			performing_player.strike_stat_boosts.powerup_per_sealed_amount_divisor = effect['divisor']
			performing_player.strike_stat_boosts.powerup_per_sealed_amount_max = effect['max']
			create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, 5, "powerup_per_sealed_amount")
		"powerup_per_spent_gauge_matching_range_to_opponent":
			var amount_per_gauge = effect['amount']
			var matching_count = 0
			var player_location = performing_player.arena_location
			var opponent_location = opposing_player.arena_location
			var opponent_width = opposing_player.extra_width
			for payment_card_id in performing_player.strike_stat_boosts.strike_payment_card_ids:
				var payment_card = card_db.get_card(payment_card_id)
				var printed_min = get_card_stat(performing_player, payment_card, 'range_min')
				var printed_max = get_card_stat(performing_player, payment_card, 'range_max')

				for opponent_space_offset in range(-opponent_width, opponent_width+1):
					var opponent_space = opponent_location + opponent_space_offset
					var distance : int = abs(player_location - opponent_space)
					if printed_min <= distance and distance <= printed_max:
						matching_count += 1
						break

			var total_powerup = amount_per_gauge * matching_count
			if total_powerup > 0:
				performing_player.add_power_bonus(total_powerup)
				create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, total_powerup)
		"powerup_per_sealed_normal":
			var sealed_normals = performing_player.get_sealed_count_of_type("normal")
			if sealed_normals > 0:
				var bonus_power = effect['amount'] * sealed_normals
				if 'maximum' in effect:
					bonus_power = min(bonus_power, effect['maximum'])
				performing_player.add_power_bonus(bonus_power)
				create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, bonus_power)
		"powerup_damagetaken":
			var power_per_damage = effect['amount']
			var damage_taken = active_strike.get_damage_taken(performing_player)
			var total_powerup = power_per_damage * damage_taken
			# Checking for negative damage taken so that powerup is in expected "direction"
			if total_powerup != 0 and damage_taken > 0:
				performing_player.add_power_bonus(total_powerup)
				create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, total_powerup)
		"powerup_opponent":
			opposing_player.add_power_bonus(effect['amount'])
			create_event(Enums.EventType.EventType_Strike_PowerUp, opposing_player.my_id, effect['amount'])
		"power_armor_up_if_sealed_or_transformed_copy_of_attack":
			performing_player.strike_stat_boosts.power_armor_up_if_sealed_or_transformed_copy_of_attack = true
			var attack_card = active_strike.get_player_card(performing_player)
			if performing_player.has_card_name_in_zone(attack_card, "sealed") or performing_player.has_card_name_in_zone(attack_card, "transform"):
				create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, 1)
				create_event(Enums.EventType.EventType_Strike_ArmorUp, performing_player.my_id, 1)
		"pull":
			var previous_location = opposing_player.arena_location
			var amount = effect['amount']
			amount += performing_player.strike_stat_boosts.increase_move_opponent_effects_by

			performing_player.pull(amount)

			var new_location = opposing_player.arena_location
			var pull_amount = opposing_player.movement_distance_between(other_start, new_location)
			local_conditions.fully_pulled = pull_amount == effect['amount']
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
				create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)
		"pull_to_range":
			var target_range = effect['amount']
			var target_closest_location
			var previous_location = opposing_player.arena_location
			var previous_closest_location = opposing_player.get_closest_occupied_space_to(performing_player.arena_location)
			var origin = performing_player.get_closest_occupied_space_to(previous_location)
			var starting_range = abs(previous_closest_location - origin)
			if performing_player.is_left_of_location(previous_closest_location):
				if starting_range >= target_range:
					# Past target range; opponent should end on the right
					target_closest_location = min(origin + target_range, MaxArenaLocation)
				else:
					# Closer than target range; opponent should end on left
					target_closest_location = max(origin - target_range, MinArenaLocation)
			else:
				# If player is to the right
				if starting_range >= target_range:
					# Past target range; opponent should end on the left
					target_closest_location = max(origin - target_range, MinArenaLocation)
				else:
					# Closer than target range; opponent should end on right
					target_closest_location = min(origin + target_range, MaxArenaLocation)

			var pull_needed = opposing_player.movement_distance_between(previous_closest_location, target_closest_location, true)
			performing_player.pull(pull_needed)
			var new_location = opposing_player.arena_location
			_append_log_full(Enums.LogType.LogType_CharacterMovement, opposing_player, "is pulled to range %s, moving from space %s to %s." % [str(target_range), str(previous_location), str(new_location)])
		"pull_to_space_and_gain_power":
			var space = effect['amount']
			var previous_location = opposing_player.arena_location
			var distance = opposing_player.movement_distance_between(space, previous_location)
			if space == previous_location:
				# This effect should only be called with an actual attempt to pull.
				assert(false)
			elif space < previous_location and performing_player.arena_location < previous_location \
			or space > previous_location and performing_player.arena_location > previous_location:
				performing_player.pull(distance)
				var new_location = opposing_player.arena_location
				var pull_amount = opposing_player.movement_distance_between(previous_location, new_location)
				local_conditions.fully_pulled = pull_amount == effect['amount']
				if (other_start < performing_start and new_location > performing_start) or (other_start > performing_start and new_location < performing_start):
					local_conditions.pulled_past = true
				performing_player.add_power_bonus(pull_amount)
				create_event(Enums.EventType.EventType_Strike_PowerUp, performing_player.my_id, pull_amount)
				_append_log_full(Enums.LogType.LogType_CharacterMovement, opposing_player, "is pulled %s, moving from space %s to %s." % [str(distance), str(previous_location), str(new_location)])
			else:
				# This effect should not be called with a push.
				assert(false)
		"pull_not_past":
			var previous_location = opposing_player.arena_location
			performing_player.pull_not_past(effect['amount'])
			var new_location = opposing_player.arena_location
			_append_log_full(Enums.LogType.LogType_CharacterMovement, opposing_player, "is pulled %s without going past %s, moving from space %s to %s." % [str(effect['amount']), performing_player.name, str(previous_location), str(new_location)])
		"pull_from_source":
			var attack_source_location = get_attack_origin(performing_player, opposing_player.arena_location)
			var skip_on_source = effect.get("skip_if_on_source", false)
			if opposing_player.is_in_location(attack_source_location):
				if not skip_on_source:
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
					handle_strike_effect(card_id, choice_effect, performing_player)
				# else: do nothing
			else:
				var previous_location = opposing_player.arena_location
				# Convert this to a regular push or pull.
				if attack_source_location < previous_location:
					# Source to the left of opponent. Move to the left.
					if performing_player.arena_location < previous_location:
						# Player to the left of opponent. Pull opponent left.
						performing_player.pull(effect['amount'])
					else:
						# Player to the right of opponent. Push opponent left.
						performing_player.push(effect['amount'])
					pass
				else:
					# Source to the right of opponent. Move to the right.
					if performing_player.arena_location < previous_location:
						# Player to the left of opponent. Push opponent right.
						performing_player.push(effect['amount'])
					else:
						# Player to the right of opponent. Pull opponent right.
						performing_player.pull(effect['amount'])
				var new_location = opposing_player.arena_location
				_append_log_full(Enums.LogType.LogType_CharacterMovement, opposing_player, "is pulled %s from the attack source at %s, moving from space %s to %s." % [str(effect['amount']), str(attack_source_location), str(previous_location), str(new_location)])
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
				handle_strike_effect(card_id, choice_effect, performing_player)
			else:
				# Convert this to a regular push or pull.
				if buddy_location < previous_location:
					# Buddy to the left of opponent. Move to the left.
					if performing_player.arena_location < previous_location:
						# Player to the left of opponent. Pull to move left,
						# otherwise push.
						performing_player.pull(amount)
					else:
						performing_player.push(amount)
				else:
					# Buddy to the right of opponent. Move to the right.
					if performing_player.arena_location < previous_location:
						# Player to the left of opponent. Push to move opponent right,
						# otherwise, pull.
						performing_player.push(amount)
					else:
						performing_player.pull(amount)
				var new_location = opposing_player.arena_location
				var buddy_name = performing_player.get_buddy_name(buddy_id)
				_append_log_full(Enums.LogType.LogType_CharacterMovement, opposing_player, "is pulled %s towards %s, moving from space %s to %s." % [str(effect['amount']), buddy_name, str(previous_location), str(new_location)])
		"push":
			var set_x_to_buddy_spaces_entered = 'save_buddy_spaces_entered_as_strike_x' in effect and effect['save_buddy_spaces_entered_as_strike_x']
			var previous_location = opposing_player.arena_location
			var amount = effect['amount']
			if str(amount) == "OPPONENT_SPEED":
				amount = get_total_speed(opposing_player)
			amount += performing_player.strike_stat_boosts.increase_move_opponent_effects_by

			performing_player.push(amount, set_x_to_buddy_spaces_entered)
			var new_location = opposing_player.arena_location
			var push_amount = abs(other_start - new_location)
			local_conditions.push_amount = push_amount
			local_conditions.fully_pushed = push_amount == amount
			if 'save_unpushed_spaces_as_strike_x' in effect and effect['save_unpushed_spaces_as_strike_x']:
				var unpushed_spaces = amount - push_amount
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "'s X for this strike is set to the number of spaces not pushed, %s." % unpushed_spaces)
				performing_player.set_strike_x(unpushed_spaces)
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
				handle_strike_effect(card_id, choice_effect, performing_player)
			else:
				var previous_location = opposing_player.arena_location
				# Convert this to a regular push or pull.
				if attack_source_location < previous_location:
					# Source to the left of opponent. Move to the right.
					if performing_player.arena_location < previous_location:
						# Player to the left of opponent. Push to move opponent right.
						performing_player.push(effect['amount'])
					else:
						# Player to the right of opponent. Pull to move opponent right.
						performing_player.pull(effect['amount'])
					pass
				else:
					# Source to the right of opponent. Move to the left.
					if performing_player.arena_location < previous_location:
						# Player to the left of opponent. Pull to move opponent left.
						performing_player.pull(effect['amount'])
					else:
						# Player to the right of opponent. Push to move opponent left.
						performing_player.push(effect['amount'])
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
			create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)
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
				performing_player.pull(distance)
				var new_location = opposing_player.arena_location
				var pull_amount = opposing_player.movement_distance_between(other_start, new_location)
				local_conditions.fully_pulled = pull_amount == effect['amount']
				if (other_start < performing_start and new_location > performing_start) or (other_start > performing_start and new_location < performing_start):
					local_conditions.pulled_past = true
				_append_log_full(Enums.LogType.LogType_CharacterMovement, opposing_player, "is pulled %s, moving from space %s to %s." % [str(distance), str(previous_location), str(new_location)])
			else:
				performing_player.push(distance)
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
			performing_player.push(push_needed)
			var new_location = opposing_player.arena_location
			_append_log_full(Enums.LogType.LogType_CharacterMovement, opposing_player, "is pushed to the attack's max range %s, moving from space %s to %s." % [str(attack_max_range), str(previous_location), str(new_location)])
		"push_to_range":
			var target_range = effect['amount']
			var furthest_location
			var previous_location = opposing_player.arena_location
			var origin = performing_player.get_closest_occupied_space_to(previous_location)
			if performing_player.arena_location < opposing_player.arena_location:
				furthest_location = max(origin + target_range, MinArenaLocation)
			else:
				furthest_location = min(origin - target_range, MaxArenaLocation)
			var push_needed = abs(furthest_location - opposing_player.get_closest_occupied_space_to(performing_player.arena_location))
			performing_player.push(push_needed)
			var new_location = opposing_player.arena_location
			_append_log_full(Enums.LogType.LogType_CharacterMovement, opposing_player, "is pushed to range %s, moving from space %s to %s." % [str(target_range), str(previous_location), str(new_location)])
		"range_includes_if_moved_past":
			performing_player.strike_stat_boosts.range_includes_if_moved_past = true
		"range_includes_lightningrods":
			performing_player.strike_stat_boosts.range_includes_lightningrods = true
		"rangeup":
			var target_player = performing_player
			if effect.get("opponent"):
				target_player = opposing_player
			var special_only = effect.get("special_only", false)
			var min_amount = effect['amount']
			if str(min_amount) == "strike_x":
				min_amount = target_player.strike_stat_boosts.strike_x
			var max_amount = effect['amount2']
			if str(max_amount) == "strike_x":
				max_amount = target_player.strike_stat_boosts.strike_x

			target_player.add_range_bonus(min_amount, max_amount, special_only)
			create_event(Enums.EventType.EventType_Strike_RangeUp, target_player.my_id, min_amount, "", max_amount)
		"rangeup_both_players":
			performing_player.add_range_bonus(effect['amount'], effect['amount2'], false)
			create_event(Enums.EventType.EventType_Strike_RangeUp, performing_player.my_id, effect['amount'], "", effect['amount2'])
			opposing_player.add_range_bonus(effect['amount'], effect['amount2'], false)
			create_event(Enums.EventType.EventType_Strike_RangeUp, opposing_player.my_id, effect['amount'], "", effect['amount2'])
		"rangeup_if_ex_modifier":
			performing_player.strike_stat_boosts.rangeup_min_if_ex_modifier = effect['amount']
			performing_player.strike_stat_boosts.rangeup_max_if_ex_modifier = effect['amount2']
			if active_strike.will_be_ex(performing_player):
				create_event(Enums.EventType.EventType_Strike_RangeUp, performing_player.my_id, effect['amount'], "", effect['amount2'])
		"rangeup_per_boost_in_play":
			var boosts_in_play = performing_player.get_boosts().size()
			if 'all_boosts' in effect and effect['all_boosts']:
				boosts_in_play += opposing_player.get_boosts().size()
			if boosts_in_play > 0:
				var min_bonus = effect['amount'] * boosts_in_play
				var max_bonus = effect['amount2'] * boosts_in_play
				performing_player.add_range_bonus(min_bonus, max_bonus, false)
				create_event(Enums.EventType.EventType_Strike_RangeUp, performing_player.my_id, min_bonus, "", max_bonus)
		"rangeup_per_boost_modifier":
			performing_player.strike_stat_boosts.rangeup_min_per_boost_modifier = effect['amount']
			performing_player.strike_stat_boosts.rangeup_max_per_boost_modifier = effect['amount2']
			performing_player.strike_stat_boosts.rangeup_per_boost_modifier_all_boosts = false
			var boosts_in_play = performing_player.get_boosts().size()
			if 'all_boosts' in effect and effect['all_boosts']:
				performing_player.strike_stat_boosts.rangeup_per_boost_modifier_all_boosts = true
				boosts_in_play += opposing_player.get_boosts().size()
			if boosts_in_play > 0:
				create_event(Enums.EventType.EventType_Strike_RangeUp, performing_player.my_id, effect['amount'] * boosts_in_play, "", effect['amount2'] * boosts_in_play)
		"rangeup_per_card_in_hand":
			var hand_size = performing_player.hand.size()
			if hand_size > 0:
				var min_bonus = effect['amount'] * hand_size
				var max_bonus = effect['amount2'] * hand_size
				performing_player.add_range_bonus(min_bonus, max_bonus, false)
				create_event(Enums.EventType.EventType_Strike_RangeUp, performing_player.my_id, min_bonus, "", max_bonus)
		"rangeup_per_force_spent_this_turn":
			var min_bonus = performing_player.total_force_spent_this_turn * effect['amount']
			var max_bonus = performing_player.total_force_spent_this_turn * effect['amount2']
			performing_player.add_range_bonus(min_bonus, max_bonus, false)
			create_event(Enums.EventType.EventType_Strike_RangeUp, performing_player.my_id, min_bonus, "", max_bonus)
		"rangeup_per_sealed_normal":
			var sealed_normals = performing_player.get_sealed_count_of_type("normal")
			if sealed_normals > 0:
				var min_bonus = effect['amount'] * sealed_normals
				var max_bonus = effect['amount2'] * sealed_normals
				performing_player.add_range_bonus(min_bonus, max_bonus, false)
				create_event(Enums.EventType.EventType_Strike_RangeUp, performing_player.my_id, min_bonus, "", max_bonus)
		"reading_normal":
			# Cannot do Reading during a strike.
			if not active_strike:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_ReadingNormal
				decision_info.effect_type = "reading_normal_internal"
				decision_info.choice_card_id = card_id
				decision_info.player = performing_player.my_id
				create_event(Enums.EventType.EventType_ReadingNormal, performing_player.my_id, 0)
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
			performing_player.remove_buddy(buddy_id, silent)
			if buddy_was_in_play and active_strike:
				# Handle character effects like Litchi where removing buddy mid-strike
				# Can have an effect on the stats.
				var char_effects = performing_player.get_character_effects_at_timing("during_strike")
				for char_effect in char_effects:
					if char_effect['condition'] == "not_buddy_in_play":
						do_effect_if_condition_met(performing_player, -1, char_effect, null)
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
		"calculate_range_from_buddy_current_location":
			var buddy_id = ""
			if 'buddy_id' in effect:
				buddy_id = effect['buddy_id']
			performing_player.strike_stat_boosts.calculate_range_from_space = performing_player.get_buddy_location(buddy_id)
		"calculate_range_from_center":
			performing_player.strike_stat_boosts.calculate_range_from_space = CenterArenaLocation
		"calculate_range_from_set_from_boost_space":
			if performing_player == active_strike.initiator:
				performing_player.strike_stat_boosts.calculate_range_from_space = active_strike.initiator_set_from_boost_space
			else:
				performing_player.strike_stat_boosts.calculate_range_from_space = active_strike.defender_set_from_boost_space
		"reduce_discard_amount":
			var amount = effect['amount']
			performing_player.strike_stat_boosts.reduce_discard_effects_by += amount
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "'s discard amounts are reduced by %s!" % amount)
		"reshuffle_discard_into_deck":
			performing_player.reshuffle_discard(false, true)
		"retreat":
			decision_info.clear()
			decision_info.source = "retreat"
			decision_info.amount = effect['amount']
			decision_info.limitation = { 'and': null, 'bonus_effect': null }
			if 'and' in effect:
				decision_info.limitation['and'] = effect['and']
			if 'bonus_effect' in effect:
				decision_info.limitation['bonus_effect'] = effect['bonus_effect']

			var effects = performing_player.get_character_effects_at_timing("on_retreat")
			for sub_effect in effects:
				do_effect_if_condition_met(performing_player, -1, sub_effect, null)
			if game_state != Enums.GameState.GameState_PlayerDecision:
				var retreat_effect = effect.duplicate()
				retreat_effect['effect_type'] = "retreat_INTERNAL"
				handle_strike_effect(card_id, retreat_effect, performing_player)
				# and/bonus_effect should be handled by internal version
				ignore_extra_effects = true
		"retreat_INTERNAL":
			var amount = effect['amount']
			if str(amount) == "strike_x":
				amount = performing_player.strike_stat_boosts.strike_x
			amount += performing_player.strike_stat_boosts.increase_movement_effects_by

			var previous_location = performing_player.arena_location
			performing_player.retreat(amount)
			var new_location = performing_player.arena_location
			var retreat_amount = abs(performing_start - new_location)
			local_conditions.fully_retreated = retreat_amount == amount
			local_conditions.movement_amount = retreat_amount
			_append_log_full(Enums.LogType.LogType_CharacterMovement, performing_player, "retreats %s, moving from space %s to %s." % [str(amount), str(previous_location), str(new_location)])
		"repeat_effect_optionally":
			if active_strike:
				var amount = effect['amount']
				if str(amount) == "GAUGE_COUNT":
					amount = performing_player.gauge.size()
				var not_optional = 'not_optional' in effect and effect['not_optional']
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
							"effect_type": "repeat_effect_optionally",
							"amount": amount-1,
							"not_optional": not_optional,
							"linked_effect": linked_effect
						}
					if not not_optional:
						repeat_effect = {
							"card_id": card_id,
							"effect_type": "choice",
							"choice": [
								repeat_effect,
								{ "effect_type": "pass" }
							]
						}
					add_remaining_effect(repeat_effect)
				if not first_not_automatic:
					handle_strike_effect(card_id, linked_effect, performing_player)
		"repeat_printed_triggers_on_ex_attack":
			performing_player.strike_stat_boosts.repeat_printed_triggers_on_ex_attack = effect.get("amount")
		"reset_character_positions":
			performing_player.move_to(performing_player.starting_location, true)
			opposing_player.move_to(opposing_player.starting_location, true)
			_append_log_full(Enums.LogType.LogType_CharacterMovement, null, "Both players return to their starting positions!")
		"return_all_cards_gauge_to_hand":
			var card_names = ""
			for card in performing_player.gauge:
				card_names += card_db.get_card_name(card.id) + ", "
			if card_names:
				card_names = card_names.substr(0, card_names.length() - 2)
			performing_player.return_all_cards_gauge_to_hand()
		"return_attack_to_hand":
			performing_player.strike_stat_boosts.return_attack_to_hand = true
			if 'not_immediate' not in effect or not effect['not_immediate']:
				handle_strike_attack_immediate_removal(performing_player)
		"return_sealed_with_same_speed":
			var sealed_card_id = decision_info.amount
			var sealed_card = card_db.get_card(sealed_card_id)
			var target_card = null
			for card in performing_player.sealed:
				if get_card_stat(performing_player, card, 'speed') == get_card_stat(performing_player, sealed_card, 'speed'):
					target_card = card
					break
			if target_card:
				var card_name = target_card.definition["display_name"]
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds the sealed card with speed %s to their hand: %s." % [sealed_card.definition['speed'], _log_card_name(card_name)])
				performing_player.move_card_from_sealed_to_hand(target_card.id)
		"return_this_boost_to_hand_strike_effect":
			var card_name = card_db.get_card_name(card_id)
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "returns boosted card %s to their hand." % _log_card_name(card_name))
			var card = card_db.get_card(card_id)
			performing_player.remove_from_continuous_boosts(card, "hand")
		"return_this_to_hand_immediate_boost":
			var card_name = card_db.get_card_name(card_id)
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "returns boosted card %s to their hand." % _log_card_name(card_name))
			if active_boost:
				active_boost.cleanup_to_hand_card_ids.append(card_id)
		"revert":
			performing_player.revert_exceed()
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
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "sets their attack's printed power to the power of %s on top of discards, %s!" % [_log_card_name(card_name), power])
			else:
				performing_player.strike_stat_boosts.overwritten_printed_power = 0
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no discards, their attack's printed power is set to 0.")
			performing_player.strike_stat_boosts.overwrite_printed_power = true
		"say":
			var say_text = effect["text"]
			create_event(Enums.EventType.EventType_Say, performing_player.my_id, 0, "", say_text)
		"seal_attack_on_cleanup":
			performing_player.strike_stat_boosts.seal_attack_on_cleanup = true
		"seal_card_INTERNAL":
			decision_info.amount = effect['seal_card_id']
			var effects = performing_player.get_character_effects_at_timing("on_seal")
			for sub_effect in effects:
				do_effect_if_condition_met(performing_player, -1, sub_effect, null)

			# note that this doesn't support effects causing decisions
			var seal_effect = effect.duplicate()
			seal_effect['effect_type'] = "seal_card_complete_INTERNAL"
			seal_effect['silent'] = false
			if 'silent' in effect:
				seal_effect['silent'] = effect['silent']
			handle_strike_effect(card_id, seal_effect, performing_player)
			# and/bonus_effect should be handled by internal version
			ignore_extra_effects = true
		"seal_card_complete_INTERNAL":
			var card = card_db.get_card(effect['seal_card_id'])
			var silent = effect['silent']
			if effect['source']:
				performing_player.seal_from_location(card.id, effect['source'], silent)
			else:
				performing_player.add_to_sealed(card, silent)
		"seal_continuous_boosts":
			var player_boosts = performing_player.continuous_boosts.duplicate()
			for boost_card in player_boosts:
				var card_name = card_db.get_card_name(boost_card.id)
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "seals the boosted card %s." % _log_card_name(card_name))
				performing_player.remove_from_continuous_boosts(boost_card, "sealed")
		"seal_instead_of_discarding":
			performing_player.seal_instead_of_discarding = true
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
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "seals the boosted card %s." % _log_card_name(card_name))
			performing_player.remove_from_continuous_boosts(card, "sealed")
			opposing_player.remove_from_continuous_boosts(card, "sealed")
		"seal_topdeck":
			performing_player.seal_topdeck()
		"seal_discard":
			performing_player.seal_discard()
		"seal_hand":
			performing_player.seal_hand()
		"self_discard_choose":
			var optional = 'optional' in effect and effect['optional']
			var limitation = effect.get("limitation", "")
			var limitation_amount = effect.get("limitation_amount", 0)
			if str(limitation_amount) == "strike_x":
				limitation_amount = performing_player.strike_stat_boosts.strike_x
			var destination = effect.get("destination", "discard")
			var discard_effect = effect.get("discard_effect", null)
			var allow_fewer = effect.get("allow_fewer", false)
			var cards_available = performing_player.get_cards_in_hand_of_type(limitation, limitation_amount)

			var this_effect = effect.duplicate()
			if str(this_effect['amount']) == "force_spent_before_strike":
				# intentionally performing_player, rather than choice_player
				this_effect['amount'] = performing_player.force_spent_before_strike
			elif str(this_effect['amount']) == "strike_x":
				this_effect['amount'] = performing_player.strike_stat_boosts.strike_x
			# Even if #cards == effect amount, still do the choosing manually because of all the additional
			# functionality that has been added to this besides discarding.
			if cards_available.size() >= this_effect['amount'] or (optional and cards_available.size() > 0):
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_ChooseToDiscard
				decision_info.effect_type = "self_discard_choose_internal"
				decision_info.effect = this_effect
				decision_info.choice_card_id = card_id
				decision_info.player = performing_player.my_id
				decision_info.destination = destination
				decision_info.limitation = limitation
				decision_info.bonus_effect = discard_effect
				decision_info.can_pass = optional

				if limitation == "last_drawn_cards":
					decision_info.limitation = "from_array"
					decision_info.extra_info = "card_names"
					decision_info.choice = cards_available.map(func(item): return item.id)

				create_event(Enums.EventType.EventType_Strike_ChooseToDiscard, performing_player.my_id, this_effect['amount'], "", allow_fewer)
			else:
				if not optional and cards_available.size() > 0:
					create_event(Enums.EventType.EventType_Strike_ChooseToDiscard_Info, performing_player.my_id, this_effect['amount'])
					# Forced to discard whole hand.
					var card_ids = performing_player.get_card_ids_in_hand()
					if destination == "discard":
						performing_player.discard_hand()
					elif destination == "sealed":
						performing_player.seal_hand()
					elif destination == "reveal":
						performing_player.reveal_hand()

					if discard_effect:
						discard_effect = discard_effect.duplicate()
						discard_effect['discarded_card_ids'] = card_ids
						do_effect_if_condition_met(performing_player, card_id, discard_effect, local_conditions)
				elif cards_available.size() == 0:
					if destination == "reveal":
						_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no cards in hand to reveal.")
						if 'and' in this_effect and this_effect['and']['effect_type'] == "save_power":
							performing_player.saved_power = 0
		"set_dan_draw_choice":
			performing_player.dan_draw_choice = true
		"set_dan_draw_choice_INTERNAL":
			performing_player.dan_draw_choice_from_bottom = effect['from_bottom']
		"set_enchantress_draw_choice":
			performing_player.enchantress_draw_choice = true
		"set_end_of_turn_boost_delay":
			performing_player.set_end_of_turn_boost_delay(card_id)
		"set_face_attack":
			performing_player.face_attack_id = effect['card_id']
		"set_max_hand_size":
			performing_player.max_hand_size = effect['amount']
			var new_size_string = "3 spaces wide"
			if 'description' in effect:
				new_size_string = effect['description']
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "'s maximum hand size is now %s!" % new_size_string)
		"set_strike_x":
			var extra_info = []
			if 'extra_info' in effect:
				extra_info = effect['extra_info']
			do_set_strike_x(performing_player, effect['source'], extra_info)
		"set_total_power":
			performing_player.strike_stat_boosts.overwrite_total_power = true
			performing_player.strike_stat_boosts.overwritten_total_power = effect['amount']
		"set_used_character_bonus":
			performing_player.used_character_bonus = true
		"self_discard_choose_internal":
			var card_ids = effect['card_ids']
			var card_names = card_db.get_card_names(card_ids)
			if effect['destination'] == "discard":
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards the chosen card(s): %s." % _log_card_name(card_names))
				performing_player.discard(card_ids)
			elif effect['destination'] == "sealed":
				if performing_player.sealed_area_is_secret:
					_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "seals %s card(s) face-down." % str(len(card_ids)))
				else:
					_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "seals the chosen card(s): %s." % _log_card_name(card_names))
				for seal_card_id in card_ids:
					do_seal_effect(performing_player, seal_card_id, "hand")
			elif effect['destination'] == "reveal":
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "reveals the chosen card(s): %s." % _log_card_name(card_names))
				performing_player.reveal_card_ids(card_ids)
				for revealed_card_id in card_ids:
					create_event(Enums.EventType.EventType_RevealCard, performing_player.my_id, revealed_card_id)
				if 'and' in effect and effect['and']['effect_type'] == "save_power":
					# Specifically get the printed power.
					var card_power = card_db.get_card(card_ids[0]).definition['power']
					effect['and']['amount'] = card_power
			elif effect['destination'] == "opponent_overdrive":
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards the chosen card(s) to opponent's overdrive: %s." % _log_card_name(card_names))
				performing_player.discard(card_ids)
				opposing_player.move_cards_to_overdrive(card_ids, "opponent_discard")
			elif effect['destination'] == "play_attack":
				# Can do 0 to pass.
				if card_ids.size() == 1:
					begin_extra_attack(performing_player, card_ids[0])
			elif effect['destination'] == "replacement_boost":
				var replacement_boost = performing_player.get_replacement_boost_definition()
				performing_player.play_replacement_boosts(card_ids, replacement_boost)
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
			create_event(Enums.EventType.EventType_Strike_GainLife, performing_player.my_id, amount, "", performing_player.life)
			_append_log_full(Enums.LogType.LogType_Health, performing_player, "has their life set to %s!" % [str(performing_player.life)])
		"shuffle_deck":
			performing_player.random_shuffle_deck()
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "shuffled their deck.")
			create_event(Enums.EventType.EventType_ReshuffleDeck, performing_player.my_id, 0)
		"shuffle_discard_in_place":
			performing_player.random_shuffle_discard_in_place()
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "shuffled their discard pile.")
			create_event(Enums.EventType.EventType_ReshuffleDiscardInPlace, performing_player.my_id, 0)
		"shuffle_into_deck_from_hand":
			if len(performing_player.hand) > 0:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_CardFromHandToGauge
				decision_info.player = performing_player.my_id
				decision_info.choice_card_id = card_id
				decision_info.destination = "deck"
				decision_info.valid_zones = ["hand"]
				var min_amount = effect['min_amount']
				var max_amount = effect['max_amount']
				decision_info.effect = {
					"min_amount": min_amount,
					"max_amount": max_amount,
				}
				create_event(Enums.EventType.EventType_CardFromHandToGauge_Choice, performing_player.my_id, min_amount, "", max_amount)
		"shuffle_hand_to_deck":
			performing_player.shuffle_hand_to_deck()
		"shuffle_sealed_to_deck":
			var card_names = ""
			for card in performing_player.sealed:
				card_names += card_db.get_card_name(card.id) + ", "
			if card_names:
				card_names = card_names.substr(0, card_names.length() - 2)
			performing_player.shuffle_sealed_to_deck()
		"sidestep_transparent_foe":
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.clear()
			decision_info.type = Enums.DecisionType.DecisionType_Sidestep
			decision_info.effect_type = "sidestep_internal"
			decision_info.choice_card_id = card_id
			decision_info.player = performing_player.my_id
			create_event(Enums.EventType.EventType_Boost_Sidestep, performing_player.my_id, 0)
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
				performing_player.move_card_from_discard_to_hand(copy_card_id)
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "moves a copy of %s from discard to hand." % _log_card_name(card_name))
				if return_effect:
					do_effect_if_condition_met(performing_player, card_id, return_effect, null)
			else:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no copies of %s in discard." % _log_card_name(card_name))
		"specific_card_discard_to_gauge":
			var card_name = effect['card_name']
			var copy_id = effect['copy_id']

			var copy_card_id = performing_player.get_copy_in_discards(copy_id)
			if copy_card_id != -1:
				performing_player.move_card_from_discard_to_gauge(copy_card_id)
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "moves a copy of %s from discard to gauge." % _log_card_name(card_name))
			else:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no copies of %s in discard." % _log_card_name(card_name))
		"specific_card_seal_from_gauge":
			var card_name = effect['card_name']
			var copy_id = effect['copy_id']
			var seal_effect = null
			if 'seal_effect' in effect:
				seal_effect = effect['seal_effect']

			var copy_card_id = performing_player.get_copy_in_gauge(copy_id)
			if copy_card_id != -1:
				performing_player.move_card_from_gauge_to_sealed(copy_card_id)
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "seals a copy of %s from gauge." % _log_card_name(card_name))
				if seal_effect:
					do_effect_if_condition_met(performing_player, card_id, seal_effect, null)
			else:
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no copies of %s in gauge." % _log_card_name(card_name))
		"speedup":
			performing_player.strike_stat_boosts.speed += effect['amount']
			create_event(Enums.EventType.EventType_Strike_SpeedUp, performing_player.my_id, effect['amount'])
		"speedup_amount_in_gauge":
			var amount = performing_player.gauge.size()
			performing_player.strike_stat_boosts.speed += amount
			create_event(Enums.EventType.EventType_Strike_SpeedUp, performing_player.my_id, amount)
		"speedup_by_spaces_modifier":
			performing_player.strike_stat_boosts.speedup_by_spaces_modifier = effect['amount']
			# Count empty spaces so distance - 1.
			var empty_spaces_between = performing_player.distance_to_opponent() - 1
			create_event(Enums.EventType.EventType_Strike_SpeedUp, performing_player.my_id, empty_spaces_between)
		"speedup_per_boost_modifier":
			performing_player.strike_stat_boosts.speedup_per_boost_modifier = effect['amount']
			performing_player.strike_stat_boosts.speedup_per_boost_modifier_all_boosts = false
			var boosts_in_play = performing_player.get_boosts().size()
			if 'all_boosts' in effect and effect['all_boosts']:
				performing_player.strike_stat_boosts.speedup_per_boost_modifier_all_boosts = true
				boosts_in_play += opposing_player.get_boosts().size()
			if boosts_in_play > 0:
				create_event(Enums.EventType.EventType_Strike_SpeedUp, performing_player.my_id, effect['amount'] * boosts_in_play)
		"speedup_per_boost_in_play":
			var boosts_in_play = performing_player.get_boosts().size()
			if 'all_boosts' in effect and effect['all_boosts']:
				boosts_in_play += opposing_player.get_boosts().size()
			if boosts_in_play > 0:
				performing_player.strike_stat_boosts.speed += effect['amount'] * boosts_in_play
				create_event(Enums.EventType.EventType_Strike_SpeedUp, performing_player.my_id, effect['amount'] * boosts_in_play)
		"speedup_per_force_spent_this_turn":
			var amount = performing_player.total_force_spent_this_turn * effect['amount']
			performing_player.strike_stat_boosts.speed += amount
			create_event(Enums.EventType.EventType_Strike_SpeedUp, performing_player.my_id, amount)
		"speedup_per_unique_sealed_normals":
			performing_player.strike_stat_boosts.speedup_per_unique_sealed_normals_modifier = effect['amount']
			var unique_sealed_normals = performing_player.get_sealed_count_of_type("normal", true)
			if unique_sealed_normals > 0:
				create_event(Enums.EventType.EventType_Strike_SpeedUp, performing_player.my_id, effect['amount'] * unique_sealed_normals)
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
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "spends all cards in hand and gauge to generate %s force%s." % [force_amount, _log_card_name(card_names)])
			performing_player.discard_hand()
			performing_player.discard_gauge()
			performing_player.force_spent_before_strike = force_amount
		"spend_all_gauge_and_save_amount":
			var gauge_amount = performing_player.get_available_gauge()
			var card_names = ""
			if performing_player.gauge.size() > 0:
				card_names = ": " + performing_player.gauge[0].definition['display_name']
				for i in range(1, len(performing_player.gauge)):
					card_names += ", " + performing_player.gauge[i].definition['display_name']
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards all %s card(s) from their gauge%s." % [gauge_amount, _log_card_name(card_names)])
			performing_player.discard_gauge()
			performing_player.gauge_spent_before_strike = gauge_amount
		"spend_life":
			var amount = effect['amount']
			performing_player.spend_life(amount)
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
					create_event(Enums.EventType.EventType_ForceStartStrike, performing_player.my_id, 0)
					if active_post_action_effect:
						post_action_interruption = true
		"strike_effect_after_setting":
			if not active_boost:
				create_event(Enums.EventType.EventType_ForceStartStrike, performing_player.my_id, 0)
			change_game_state(Enums.GameState.GameState_WaitForStrike)
			decision_info.clear()
			decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
			decision_info.player = performing_player.my_id
			performing_player.extra_effect_after_set_strike = effect['after_set_effect']
		"strike_effect_after_opponent_sets":
			if not active_boost:
				create_event(Enums.EventType.EventType_ForceStartStrike, performing_player.my_id, 0)
			change_game_state(Enums.GameState.GameState_WaitForStrike)
			decision_info.clear()
			decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
			decision_info.player = performing_player.my_id
			opposing_player.extra_effect_after_set_strike = effect['after_set_effect']
		"strike_faceup":
			var disable_wild_swing = 'disable_wild_swing' in effect and effect['disable_wild_swing']
			var disable_ex = 'disable_ex' in effect and effect['disable_ex']
			if not active_boost:
				create_event(Enums.EventType.EventType_ForceStartStrike, performing_player.my_id, 0, "", disable_wild_swing, disable_ex)
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
					create_event(Enums.EventType.EventType_Strike_FromGauge, performing_player.my_id, 0)
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
					create_event(Enums.EventType.EventType_Strike_EffectDoStrike, performing_player.my_id, 0, "", strike_info)
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
					create_event(Enums.EventType.EventType_Strike_FromGauge, performing_player.my_id, 0)
			else:
				change_game_state(Enums.GameState.GameState_WaitForStrike)
				var strike_info = {
					"card_id": -1,
					"wild_swing": true,
					"ex_card_id": -1
				}
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "has no sealed cards to strike with.")
				if not active_boost: # Boosts will send strikes on their own
					create_event(Enums.EventType.EventType_Strike_EffectDoStrike, performing_player.my_id, 0, "", strike_info)
		"strike_opponent_sets_first":
			create_event(Enums.EventType.EventType_Strike_OpponentSetsFirst, performing_player.my_id, 0)
			change_game_state(Enums.GameState.GameState_Strike_Opponent_Set_First)
			decision_info.clear()
			decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
			decision_info.player = performing_player.my_id
		"strike_random_from_gauge":
			create_event(Enums.EventType.EventType_Strike_OpponentSetsFirst, performing_player.my_id, 0)
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
			create_event(Enums.EventType.EventType_Strike_EffectDoStrike, performing_player.my_id, 0, "", strike_info)
		"strike_with_deus_ex_machina":
			if not active_strike:
				change_game_state(Enums.GameState.GameState_AutoStrike)
				decision_info.clear()
				decision_info.effect_type = "happychaos_deusexmachina"
		"strike_with_ex":
			if performing_player.can_ex_strike_with_something():
				change_game_state(Enums.GameState.GameState_WaitForStrike)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_StrikeNow
				decision_info.player = performing_player.my_id
				if performing_player.has_ex_boost():
					# Then any attack would be a valid EX
					create_event(Enums.EventType.EventType_ForceStartStrike, performing_player.my_id, 0)
				else:
					decision_info.limitation = "EX"
					var disable_wild_swing = true
					create_event(Enums.EventType.EventType_ForceStartStrike, performing_player.my_id, 0, "", disable_wild_swing)
		"strike_wild":
			# If a character has delayed wild strikes, they use this for the choices
			# but the strike will automatically occur after the set strike effects finish.
			if not effect.get("auto_delayed_strike", false):
				var opponent_forced_wild = effect.get("opponent_forced_wild", false)
				performing_player.opponent_next_strike_forced_wild_swing = opponent_forced_wild
				change_game_state(Enums.GameState.GameState_WaitForStrike)
				var strike_info = {
					"card_id": -1,
					"wild_swing": true,
					"ex_card_id": -1
				}
				create_event(Enums.EventType.EventType_Strike_EffectDoStrike, performing_player.my_id, 0, "", strike_info)
		"stun_immunity":
			performing_player.strike_stat_boosts.stun_immunity = true
		"sustain_all_boosts":
			for boost in performing_player.continuous_boosts:
				if boost.id not in performing_player.sustained_boosts:
					performing_player.sustained_boosts.append(boost.id)
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "sustains all continuous boosts.")
			create_event(Enums.EventType.EventType_SustainBoost, performing_player.my_id, -1)
		"sustain_this":
			performing_player.sustained_boosts.append(card_id)
			if 'hide_effect' not in effect or not effect['hide_effect']:
				var card = card_db.get_card(card_id)
				var boost_name = _get_boost_and_card_name(card)
				_append_log_full(Enums.LogType.LogType_Effect, performing_player, "sustains their continuous boost %s." % boost_name)
				create_event(Enums.EventType.EventType_SustainBoost, performing_player.my_id, card_id)
		"swap_buddy":
			var buddy_id_to_remove = effect['buddy_to_remove']
			var buddy_id_to_place = effect['buddy_to_place']
			performing_player.swap_buddy(buddy_id_to_remove, buddy_id_to_place, effect['description'])
		"swap_deck_and_sealed":
			performing_player.swap_deck_and_sealed()
		"swap_power_speed":
			performing_player.strike_stat_boosts.swap_power_speed = true
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "swaps their power and speed!")
		"switch_spaces_with_buddy":
			var old_space = performing_player.arena_location
			var old_buddy_space = performing_player.get_buddy_location()
			performing_player.move_to(old_buddy_space)
			performing_player.place_buddy(old_space)
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
			if damaged_player.has_passive("discard_2x_topdeck_instead_of_damage"):
				var cards_to_discard = 2 * unmitigated_damage
				unmitigated_damage = 0
				for i in range(cards_to_discard):
					damaged_player.discard_topdeck()

			var actual_damage_taken = unmitigated_damage
			if nonlethal and unmitigated_damage >= damaged_player.life:
				actual_damage_taken = damaged_player.life - 1
			damaged_player.life -= actual_damage_taken
			create_event(Enums.EventType.EventType_Strike_TookDamage, damaged_player.my_id, actual_damage_taken, "", damaged_player.life)
			if used_armor > 0:
				_append_log_full(Enums.LogType.LogType_Health, damaged_player, "takes %s non-lethal damage (%s blocked by armor), bringing them to %s life!" % [str(unmitigated_damage), str(used_armor), str(damaged_player.life)])
			else:
				_append_log_full(Enums.LogType.LogType_Health, damaged_player, "takes %s non-lethal damage, bringing them to %s life!" % [str(unmitigated_damage), str(damaged_player.life)])
			if active_strike:
				active_strike.add_damage_taken(damaged_player, unmitigated_damage)
				check_for_stun(damaged_player, false)
			if damaged_player.life <= 0:
				trigger_game_over(damaged_player.my_id, Enums.GameOverReason.GameOverReason_Life)
		"topdeck_from_hand":
			if len(performing_player.hand) > 0:
				change_game_state(Enums.GameState.GameState_PlayerDecision)
				decision_info.clear()
				decision_info.type = Enums.DecisionType.DecisionType_CardFromHandToGauge
				decision_info.player = performing_player.my_id
				decision_info.choice_card_id = card_id
				decision_info.destination = "topdeck"
				decision_info.valid_zones = ["hand"]
				var min_amount = effect['min_amount']
				var max_amount = effect['max_amount']
				decision_info.effect = {
					"min_amount": min_amount,
					"max_amount": max_amount,
				}
				create_event(Enums.EventType.EventType_CardFromHandToGauge_Choice, performing_player.my_id, min_amount, "", max_amount)
		"transform_attack":
			# This effect is expected to be at the end of a strike.
			assert(active_strike)
			var card_name = card_db.get_card_name(card_id)
			if 'card_name' in effect:
				card_name = effect['card_name']
			performing_player.strike_stat_boosts.move_strike_to_transforms = true
			_append_log_full(Enums.LogType.LogType_Effect, performing_player, "transforms %s." % [_log_card_name(card_name)])

			# Handling immediate effects; expected to be non-blocking, mostly to establish toggles e.g.
			var transform_effects = card_db.get_card_boost_effects_now_immediate(card_db.get_card(card_id))
			for transform_effect in transform_effects:
				do_effect_if_condition_met(performing_player, card_id, transform_effect, null)
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
			create_event(Enums.EventType.EventType_Boost_ZeroVector, performing_player.my_id, 0)
		"zero_vector_internal":
			var named_id = effect['card_id']
			if named_id != -1:
				var named_card = card_db.get_card(named_id)
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
				do_effect_if_condition_met(performing_player, card_id, and_effect, local_conditions)
			elif active_character_action:
				remaining_character_action_effects.append(effect['and'])

		if "bonus_effect" in effect and effect['bonus_effect']:
			if not game_state == Enums.GameState.GameState_PlayerDecision:
				var bonus_effect = effect['bonus_effect']
				do_effect_if_condition_met(performing_player, card_id, bonus_effect, local_conditions)
			elif active_character_action:
				remaining_character_action_effects.append(effect['bonus_effect'])

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
		create_event(Enums.EventType.EventType_ChooseArenaLocationForEffect, performing_player.my_id, 0)

func do_seal_effect(performing_player : Player, card_id : int, source : String, silent : bool = false):
	var seal_effect = {
		"effect_type": "seal_card_INTERNAL",
		"seal_card_id": card_id,
		"source": source,
		"silent": silent
	}
	handle_strike_effect(-1, seal_effect, performing_player)

func handle_player_draw_or_discard_to_effect(performing_player : Player, card_id, effect):
	var target_hand_size = effect['amount']
	if str(target_hand_size) == 'other_player_hand_size':
		var other_player = _get_player(get_other_player(performing_player.my_id))
		target_hand_size = other_player.hand.size()
	var hand_size = performing_player.hand.size()
	if hand_size < target_hand_size:
		var amount_to_draw = target_hand_size - hand_size
		performing_player.draw(amount_to_draw)
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "draws %s card(s) to reach a hand size of %s." % [amount_to_draw, target_hand_size])
		if 'per_draw_effect' in effect and amount_to_draw > 0:
			var per_draw_effect = effect['per_draw_effect'].duplicate()
			per_draw_effect['amount'] = amount_to_draw * per_draw_effect['amount']
			handle_strike_effect(card_id, per_draw_effect, performing_player)
	elif hand_size > target_hand_size:
		var amount_to_discard = hand_size - target_hand_size
		var discard_effect = {
			"effect_type": "self_discard_choose",
			"amount": amount_to_discard
		}
		if 'and' in effect:
			discard_effect['discard_effect'] = effect['and']
		_append_log_full(Enums.LogType.LogType_Effect, performing_player, "must discard %s card(s) to reach a hand size of %s." % [amount_to_discard, target_hand_size])
		handle_strike_effect(card_id, discard_effect, performing_player)
	else:
		pass

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
	elif str(value) == "CARDS_IN_HAND_MAX_7":
		value = min(check_player.hand.size(), 7)
	elif str(value) == "TOTAL_POWER":
		assert(stat != 'power')
		value = get_total_power(check_player, false, card)
	elif str(value) == "RANGE_TO_OPPONENT":
		value = check_player.distance_to_opponent()
	elif str(value) == "INCLUDE_OPPONENT_IF_MOVED_PAST":
		value = -1
		# NOTE: This probably isn't necessary for any mechanics as the card that uses this
		# does the effect range_includes_if_moved_past.
		# However, this will be slightly wrong if someone has a +range boost of any kind.
		# If a character can do that and also cares about range, then worry about that then.
		if active_strike and check_player.strike_stat_boosts.range_includes_opponent:
			value = check_player.distance_to_opponent()

	var stat_limit = value
	if stat == 'speed' and 'max_base_speed' in card.definition:
		stat_limit = card.definition['max_base_speed']
	if stat == 'power' and 'max_base_power' in card.definition:
		stat_limit = card.definition['max_base_power']
	value = min(value, stat_limit)
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
	for card_id in card_ids:
		var card = card_db.get_card(card_id)
		var card_name = card_db.get_card_name(card.id)
		_append_log_full(Enums.LogType.LogType_Effect, performing_player, "will add the before/hit/after effects of %s to their attack!" % _log_card_name(card_name))
		for timing in ["before", "hit", "after"]:
			for card_effect in card_db.get_card_effects_at_timing(card, timing):
				var added_effect = {
					"effect_type": "add_attack_effect",
					"added_effect": card_effect.duplicate()
				}

				if set_character_effect:
					added_effect['character_effect'] = true
				handle_strike_effect(-1, added_effect, performing_player)

func duplicate_attack_triggers(performing_player : Player, amount : int):
	var card = active_strike.get_player_card(performing_player)

	var effects = []
	for timing in ["before", "hit", "after"]:
		effects += get_all_effects_for_timing(timing, performing_player, card)
	for i in range(amount):
		performing_player.strike_stat_boosts.added_attack_effects += effects

func get_boost_effects_at_timing(timing_name : String, performing_player : Player):
	var effects = []
	for boost_card in performing_player.get_continuous_boosts_and_transforms():
		for effect in boost_card.definition['boost']['effects']:
			if effect['timing'] == timing_name:
				var effect_with_id = effect.duplicate(true)
				effect_with_id['card_id'] = boost_card.id
				effects.append(effect_with_id)
	return effects

func get_all_effects_for_timing(
	timing_name : String,
	performing_player : Player,
	card : GameCard,
	ignore_condition : bool = true,
	only_card_and_bonus_effects : bool = false
) -> Array:
	var card_effects = []
	var card_id = -1
	var duplicate_card_effects = 0
	if performing_player.strike_stat_boosts.repeat_printed_triggers_on_ex_attack and active_strike.will_be_ex(performing_player):
		if timing_name in ["before", "hit", "after"]:
			duplicate_card_effects = performing_player.strike_stat_boosts.repeat_printed_triggers_on_ex_attack
	if card:
		card_id = card.id
		card_effects = card_db.get_card_effects_at_timing(card, timing_name)
		if duplicate_card_effects:
			for i in range(duplicate_card_effects):
				card_effects += card_db.get_card_effects_at_timing(card, timing_name)
		for effect in card_effects:
			effect['card_id'] = card_id
	var boost_effects = get_boost_effects_at_timing(timing_name, performing_player)
	var character_effects = performing_player.get_character_effects_at_timing(timing_name)
	for effect in character_effects:
		effect['card_id'] = card_id
	var bonus_effects = performing_player.get_bonus_effects_at_timing(timing_name)

	var both_players_boost_effects = []
	both_players_boost_effects += get_boost_effects_at_timing("both_players_" + timing_name, performing_player)
	var other_player = _get_player(get_other_player(performing_player.my_id))
	both_players_boost_effects += get_boost_effects_at_timing("both_players_" + timing_name, other_player)

	# Check for opponent-given effects
	var opponent_given_effects = other_player.get_character_effects_at_timing("opponent_" + timing_name)
	opponent_given_effects += get_boost_effects_at_timing("opponent_" + timing_name, other_player)

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
			effect['card_id'] = card_id
		if 'negative_condition_effect' in effect:
			effect['negative_condition_effect']['card_id'] = card_id
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

	while (active_strike.queued_stop_on_space_boosts or get_remaining_effect_count() > 0) and not game_state == Enums.GameState.GameState_PlayerDecision:
		# Before normal effect handling, proccess boosts whose spaces have just been entered
		if active_strike.queued_stop_on_space_boosts:
			var entered_boost_id = active_strike.queued_stop_on_space_boosts.pop_front()
			var entered_boost_card = card_db.get_card(entered_boost_id)
			var owning_player = _get_player(entered_boost_card.owner_id)
			var effect = entered_boost_card.definition['boost']['stop_on_space_effect']

			do_effect_if_condition_met(owning_player, entered_boost_id, effect, null)
			if game_state == Enums.GameState.GameState_PlayerDecision:
				break

		elif get_remaining_effect_count() > 1:
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
				create_event(Enums.EventType.EventType_Strike_EffectChoice, performing_player.my_id, 0, "EffectOrder")
				break
			elif condition_met_effects.size() == 1:
				# Use the base effect to account for negative effects.
				var effect = get_base_remaining_effect(condition_met_effects[0])
				erase_remaining_effect(effect)
				do_effect_if_condition_met(performing_player, effect['card_id'], effect, null)

				if game_state == Enums.GameState.GameState_PlayerDecision:
					break
			else:
				# No more effects have their conditions met.
				reset_remaining_effects()
		else:
			# Only 1 effect in the list, do it.
			var effect = get_first_remaining_effect()
			reset_remaining_effects()
			do_effect_if_condition_met(performing_player, effect['card_id'], effect, null)

			if game_state == Enums.GameState.GameState_PlayerDecision:
				break
		if game_over:
			return

	if not active_strike.queued_stop_on_space_boosts and get_remaining_effect_count() == 0 and not game_state == Enums.GameState.GameState_PlayerDecision:
		active_strike.effects_resolved_in_timing = 0
		if active_strike.extra_attack_in_progress:
			active_strike.extra_attack_data.extra_attack_state = next_state
		else:
			active_strike.strike_state = next_state

func do_remaining_overdrive(performing_player : Player):
	change_game_state(Enums.GameState.GameState_Boost_Processing)
	while remaining_overdrive_effects.size() > 0:
		var effect = remaining_overdrive_effects[0]
		remaining_overdrive_effects.erase(effect)
		do_effect_if_condition_met(performing_player, -1, effect, null)
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
			performing_player.move_card_from_discard_to_hand(card.id)

			# Prep gamestate so we can boost.
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.type = Enums.DecisionType.DecisionType_BoostNow
			do_boost(performing_player, card.id, [])

		# Very explicitly don't unset active_overdrive until after do_boost, so boost knows we're in overdrive doing this.
		# Also, there should be no decisions so we're good to advance the turn.
		active_overdrive = false
		start_begin_turn()

func do_remaining_character_action(performing_player : Player):
	if game_state != Enums.GameState.GameState_WaitForStrike and game_state != Enums.GameState.GameState_Strike_Opponent_Set_First:
		change_game_state(Enums.GameState.GameState_Boost_Processing)
	while remaining_character_action_effects.size() > 0:
		var effect = remaining_character_action_effects[0]
		remaining_character_action_effects.erase(effect)
		var card_id = -1
		if 'card_id' in effect:
			card_id = effect['card_id']
		do_effect_if_condition_met(performing_player, card_id, effect, null)
		if game_state == Enums.GameState.GameState_PlayerDecision:
			# Player has a decision to make, so stop mid-effect resolve.
			break

	if game_state != Enums.GameState.GameState_PlayerDecision:
		active_character_action = false
		if game_state != Enums.GameState.GameState_WaitForStrike and game_state != Enums.GameState.GameState_Strike_Opponent_Set_First:
			check_hand_size_advance_turn(performing_player)

func do_set_strike_x(performing_player : Player, source : String, extra_info):

	var value = 0
	match source:
		"amount_or_cards_left_in_deck":
			var amount = min(extra_info, performing_player.deck.size())
			value = amount
		"random_gauge_power":
			if len(performing_player.gauge) > 0:
				var random_gauge_idx = get_random_int() % len(performing_player.gauge)
				var card = performing_player.gauge[random_gauge_idx]
				var power = get_card_stat(performing_player, card, 'power')
				value = max(power, 0)
				var card_name = card_db.get_card_name(card.id)
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "'s X for this strike is set to the power of %s in gauge, %s." % [_log_card_name(card_name), value])
				create_event(Enums.EventType.EventType_RevealRandomGauge, performing_player.my_id, card.id)
			else:
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "has no cards in gauge, so X is set to 0.")
		"top_discard_power":
			if len(performing_player.discards) > 0:
				var card = performing_player.get_top_discard_card()
				var power = get_card_stat(performing_player, card, 'power')
				value = max(power, 0)
				var card_name = card_db.get_card_name(card.id)
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "'s X for this strike is set to the power of %s on top of discards, %s." % [_log_card_name(card_name), value])
			else:
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "has no discards, so X is set to 0.")
		"top_deck_power":
			if len(performing_player.deck) > 0:
				var card = performing_player.get_top_deck_card()
				var power = get_card_stat(performing_player, card, 'power')
				value = max(power, 0)
				var card_name = card_db.get_card_name(card.id)
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "'s X for this strike is set to the power of %s on top of deck, %s." % [_log_card_name(card_name), value])
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
			_append_log_full(Enums.LogType.LogType_Strike, performing_player, "'s X for this strike is set to the number of copies of %s in gauge, %s." % [_log_card_name(card_name), value])
		"cards_in_hand":
			value = len(performing_player.hand)
			_append_log_full(Enums.LogType.LogType_Strike, performing_player, "'s X for this strike is set to the number of cards in hand, %s." % value)
		"lightningsrods_in_opponent_space":
			var opposing_player = _get_player(get_other_player(performing_player.my_id))
			for i in range(MinArenaLocation, MaxArenaLocation + 1):
				if opposing_player.is_in_location(i):
					var lightningzone = performing_player.get_lightningrod_zone_for_location(i)
					value += len(lightningzone)
			_append_log_full(Enums.LogType.LogType_Strike, opposing_player, "is on %s Lightning Rods." % [value])
		"ultras_used_to_pay_gauge_cost":
			for payment_card_id in performing_player.strike_stat_boosts.strike_payment_card_ids:
				var payment_card = card_db.get_card(payment_card_id)
				if payment_card.definition['type'] == "ultra":
					value += 1
		_:
			assert(false, "Unknown source for setting X")

	performing_player.set_strike_x(value)

func do_effects_for_timing(
	timing_name : String,
	performing_player : Player,
	card : GameCard,
	next_state,
	only_card_and_bonus_effects : bool = false,
	recorded_failed_effects = null
	):
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
			do_effect_if_condition_met(performing_player, card.id, effect, null, recorded_failed_effects)
			if game_state == Enums.GameState.GameState_PlayerDecision:
				# Player has a decision to make, so stop mid-effect resolve.
				break

			# Effect was resolved, continue loop to resolve more.
			active_strike.effects_resolved_in_timing += 1
		elif boost_effects_resolved < len(boost_effects):
			# Resolve boost effects
			var effect = boost_effects[boost_effects_resolved]
			do_effect_if_condition_met(performing_player, card.id, effect, null, recorded_failed_effects)
			if game_state == Enums.GameState.GameState_PlayerDecision:
				# Player has a decision to make, so stop mid-effect resolve.
				break

			# Effect was resolved, continue loop to resolve more.
			active_strike.effects_resolved_in_timing += 1
		elif character_effects_resolved < len(character_effects):
			# Resolve character effects
			var effect = character_effects[character_effects_resolved]
			do_effect_if_condition_met(performing_player, card.id, effect, null, recorded_failed_effects)
			if game_state == Enums.GameState.GameState_PlayerDecision:
				# Player has a decision to make, so stop mid-effect resolve.
				break

			# Effect was resolved, continue loop to resolve more.
			active_strike.effects_resolved_in_timing += 1
		elif bonus_effects_resolved < len(bonus_effects):
			# Resolve bonus effects
			var effect = bonus_effects[bonus_effects_resolved]
			do_effect_if_condition_met(performing_player, card.id, effect, null, recorded_failed_effects)
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

func is_location_in_range(attacking_player, card, test_location : int):
	if get_card_stat(attacking_player, card, 'range_min') == -1 or attacking_player.strike_stat_boosts.overwrite_range_to_invalid:
		return false
	var min_range = get_total_min_range(attacking_player)
	var max_range = get_total_max_range(attacking_player)
	var in_range_return_value = true
	if attacking_player.strike_stat_boosts.invert_range:
		in_range_return_value = false

	if attacking_player.strike_stat_boosts.calculate_range_from_buddy:
		if not attacking_player.is_buddy_in_play(attacking_player.strike_stat_boosts.calculate_range_from_buddy_id):
			return false
	var attack_source_location = get_attack_origin(attacking_player, test_location)

	var distance : int = abs(attack_source_location - test_location)
	if min_range <= distance and distance <= max_range:
		return in_range_return_value
	for included_range in attacking_player.strike_stat_boosts.attack_includes_ranges:
		if included_range == distance:
			return in_range_return_value
	return not in_range_return_value

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

	if defending_player.strike_stat_boosts.dodge_normals and card.definition['type'] == "normal":
		if combat_logging:
			_append_log_full(Enums.LogType.LogType_Effect, defending_player, "is dodging normal attacks!")
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
	if attacking_player.strike_stat_boosts.calculate_range_from_space != -1:
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
			min_range -= attacking_player.get_total_min_range_bonus(card, active_strike.extra_attack_data.extra_attack_previous_attack_range_effects)
			max_range -= attacking_player.get_total_max_range_bonus(card, active_strike.extra_attack_data.extra_attack_previous_attack_range_effects)
		var range_string = str(min_range)
		if min_range != max_range:
			range_string += "-%s" % str(max_range)
		var include_str = ""
		if attacking_player.strike_stat_boosts.attack_includes_ranges:
			include_str = " (including range(s) %s)" % ", ".join(attacking_player.strike_stat_boosts.attack_includes_ranges)
		var invert_str = ""
		if attacking_player.strike_stat_boosts.invert_range:
			invert_str = ", but inverted"
		_append_log_full(Enums.LogType.LogType_Strike, attacking_player, "has range %s%s%s." % [range_string, include_str, invert_str])

	# Apply special late calculation range dodges
	if defending_player.strike_stat_boosts.dodge_at_range_late_calculate_with == "OVERDRIVE_COUNT":
		var overdrive_count = defending_player.overdrive.size()
		defending_player.strike_stat_boosts.dodge_at_range_min[-2] = overdrive_count
		defending_player.strike_stat_boosts.dodge_at_range_max[-2] = overdrive_count

	# Range dodge
	if defending_player.strike_stat_boosts.dodge_at_range_min:
		for dodge_key in defending_player.strike_stat_boosts.dodge_at_range_min:
			var dodge_range_min = defending_player.strike_stat_boosts.dodge_at_range_min[dodge_key]
			var dodge_range_max = defending_player.strike_stat_boosts.dodge_at_range_max[dodge_key]

			var dodge_range_string = str(dodge_range_min)
			if dodge_range_max != dodge_range_min:
				dodge_range_string += "-%s" % str(dodge_range_max)

			if defending_player.strike_stat_boosts.dodge_at_range_from_buddy:
				var buddy_location = defending_player.get_buddy_location()
				var buddy_attack_source_location = attack_source_location
				if standard_source:
					buddy_attack_source_location = attacking_player.get_closest_occupied_space_to(buddy_location)
				var buddy_distance = abs(buddy_attack_source_location - buddy_location)
				if dodge_range_min <= buddy_distance and buddy_distance <= dodge_range_max:
					if combat_logging:
						_append_log_full(Enums.LogType.LogType_Effect, defending_player, "is dodging attacks at range %s from %s!" % [dodge_range_string, defending_player.get_buddy_name()])
					return false
			else:
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

func handle_advanced_through(performing_player : Player, other_player : Player):
	var effects = get_all_effects_for_timing("moved_past", performing_player, null, false)
	# Assume no decisions.
	for effect in effects:
		if effect['timing'] == "moved_past":
			if is_effect_condition_met(performing_player, effect, null):
				do_effect_if_condition_met(performing_player, effect["card_id"], effect, null)
		elif effect['timing'] == "opponent_moved_past":
			if is_effect_condition_met(other_player, effect, null):
				do_effect_if_condition_met(other_player, effect["card_id"], effect, null)

func get_total_power(performing_player : Player, ignore_swap : bool = false, card : GameCard = null):
	if performing_player.strike_stat_boosts.swap_power_speed and not ignore_swap:
		return get_total_speed(performing_player, true)

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
	var positive_boosted_power = performing_player.strike_stat_boosts.power_positive_only
	if performing_player.strike_stat_boosts.power_modify_per_buddy_between:
		# NOTE: This does not interact with the positive power multiplier.
		# If someone ever needs that, this needs to be updated.
		var buddy_count = performing_player.count_buddies_between_opponent()
		boosted_power += buddy_count * performing_player.strike_stat_boosts.power_modify_per_buddy_between

	if performing_player.strike_stat_boosts.power_armor_up_if_sealed_or_transformed_copy_of_attack:
		if performing_player.has_card_name_in_zone(card, "sealed") or performing_player.has_card_name_in_zone(card, "transform"):
			boosted_power += 1
			positive_boosted_power += 1

	if performing_player.strike_stat_boosts.powerup_per_sealed_amount_divisor:
		var sealed_count : int = performing_player.sealed.size()
		@warning_ignore('integer_division')
		var sealed_powerup : int = sealed_count / performing_player.strike_stat_boosts.powerup_per_sealed_amount_divisor
		sealed_powerup = min(sealed_powerup, performing_player.strike_stat_boosts.powerup_per_sealed_amount_max)
		boosted_power += sealed_powerup
		positive_boosted_power += sealed_powerup

	# account for passive bonus from hand size
	if performing_player.strike_stat_boosts.passive_powerup_per_card_in_hand != 0:
		var hand_size = len(performing_player.hand)
		var hand_size_power_bonus = hand_size * performing_player.strike_stat_boosts.passive_powerup_per_card_in_hand
		boosted_power += hand_size_power_bonus
		if hand_size_power_bonus > 0:
			positive_boosted_power += hand_size_power_bonus

	# Multiply all power bonuses.
	var power_modifier = boosted_power * performing_player.strike_stat_boosts.power_bonus_multiplier

	# Multiply positive power bonuses and add that in.
	var positive_multiplier_bonus = positive_boosted_power
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

	if performing_player.strike_stat_boosts.power_armor_up_if_sealed_or_transformed_copy_of_attack:
		if performing_player.has_card_name_in_zone(card, "sealed") or performing_player.has_card_name_in_zone(card, "transform"):
			armor_modifier += 1

	return max(0, armor + armor_modifier)

func get_total_guard(performing_player : Player):
	if performing_player.strike_stat_boosts.overwrite_total_guard:
		return performing_player.strike_stat_boosts.overwritten_total_guard

	var card = active_strike.get_player_card(performing_player)
	var guard = get_card_stat(performing_player, card, 'guard')
	var guard_modifier = performing_player.strike_stat_boosts.guard

	if performing_player.strike_stat_boosts.guardup_per_gauge:
		guard_modifier += len(performing_player.gauge)

	if performing_player.strike_stat_boosts.guardup_per_two_cards_in_hand:
		var hand_size = len(performing_player.hand)
		guard_modifier += floor(hand_size / 2.0)

	if performing_player.strike_stat_boosts.guardup_if_copy_of_opponent_attack_in_sealed_modifier:
		var opposing_player = _get_player(get_other_player(performing_player.my_id))
		var opponent_attack = active_strike.get_player_card(opposing_player)
		if performing_player.has_card_name_in_zone(opponent_attack, "sealed"):
			guard_modifier += performing_player.strike_stat_boosts.guardup_if_copy_of_opponent_attack_in_sealed_modifier

	return guard + guard_modifier

func get_total_min_range(performing_player : Player):
	assert(active_strike)
	var card = active_strike.get_player_card(performing_player)
	if active_strike.extra_attack_in_progress:
		card = active_strike.extra_attack_data.extra_attack_card

	var min_range = get_card_stat(performing_player, card, 'range_min')
	var min_range_modifier = performing_player.get_total_min_range_bonus(card)
	if performing_player.strike_stat_boosts.rangeup_min_per_boost_modifier > 0:
		var boosts_in_play = performing_player.get_boosts().size()
		if performing_player.strike_stat_boosts.rangeup_per_boost_modifier_all_boosts:
			var opposing_player = _get_player(get_other_player(performing_player.my_id))
			boosts_in_play += opposing_player.get_boosts().size()
		if boosts_in_play > 0:
			min_range_modifier += performing_player.strike_stat_boosts.rangeup_min_per_boost_modifier * boosts_in_play
	if performing_player.strike_stat_boosts.rangeup_min_if_ex_modifier > 0:
		if active_strike.will_be_ex(performing_player):
			min_range_modifier += performing_player.strike_stat_boosts.rangeup_min_if_ex_modifier
	return min_range + min_range_modifier

func get_total_max_range(performing_player : Player):
	assert(active_strike)
	var card = active_strike.get_player_card(performing_player)
	if active_strike.extra_attack_in_progress:
		card = active_strike.extra_attack_data.extra_attack_card

	var max_range = get_card_stat(performing_player, card, 'range_max')
	var max_range_modifier = performing_player.get_total_max_range_bonus(card)
	if performing_player.strike_stat_boosts.rangeup_max_per_boost_modifier > 0:
		var boosts_in_play = performing_player.get_boosts().size()
		if performing_player.strike_stat_boosts.rangeup_per_boost_modifier_all_boosts:
			var opposing_player = _get_player(get_other_player(performing_player.my_id))
			boosts_in_play += opposing_player.get_boosts().size()
		if boosts_in_play > 0:
			max_range_modifier += performing_player.strike_stat_boosts.rangeup_max_per_boost_modifier * boosts_in_play
	if performing_player.strike_stat_boosts.rangeup_max_if_ex_modifier > 0:
		if active_strike.will_be_ex(performing_player):
			max_range_modifier += performing_player.strike_stat_boosts.rangeup_max_if_ex_modifier
	return max_range + max_range_modifier

func get_attack_origin(performing_player : Player, target_location : int):
	var origin = performing_player.get_closest_occupied_space_to(target_location)
	if performing_player.strike_stat_boosts.calculate_range_from_buddy:
		origin = performing_player.get_buddy_location(performing_player.strike_stat_boosts.calculate_range_from_buddy_id)
	elif performing_player.strike_stat_boosts.calculate_range_from_space != -1:
		origin = performing_player.strike_stat_boosts.calculate_range_from_space
	return origin

func calculate_damage(offense_player : Player, defense_player : Player) -> int:
	var power = get_total_power(offense_player)
	var armor = get_total_armor(defense_player)
	if offense_player.strike_stat_boosts.ignore_armor:
		armor = 0
	var damage_after_armor = max(power - armor, 0)
	return damage_after_armor

func check_for_stun(check_player : Player, ignore_guard : bool):

	if active_strike.is_player_stunned(check_player):
		# If they're already stunned, can't stun again.
		return

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
			create_event(Enums.EventType.EventType_Strike_Stun_Immunity, check_player.my_id, defense_card.id)
		else:
			_append_log_full(Enums.LogType.LogType_Strike, check_player, "is stunned!")
			create_event(Enums.EventType.EventType_Strike_Stun, check_player.my_id, defense_card.id)
			active_strike.set_player_stunned(check_player)

			# Assumes non-decision effects only
			var effects = check_player.get_character_effects_at_timing("on_stunned")
			for effect in effects:
				do_effect_if_condition_met(check_player, -1, effect, null)

func apply_damage(offense_player : Player, defense_player : Player):
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
	if defense_player.strike_stat_boosts.cap_attack_damage_taken != -1:
		_append_log_full(Enums.LogType.LogType_Health, offense_player, "'s attack capped at %s damage." % [str(defense_player.strike_stat_boosts.cap_attack_damage_taken)])
		damage_after_armor = min(damage_after_armor, defense_player.strike_stat_boosts.cap_attack_damage_taken)

	var consumed_armor = power - damage_after_armor
	if defense_player.has_passive("discard_2x_topdeck_instead_of_damage"):
		var cards_to_discard = 2 * damage_after_armor
		damage_after_armor = 0
		for i in range(cards_to_discard):
			defense_player.discard_topdeck()

	# Decrease life.
	defense_player.life -= damage_after_armor
	if defense_player.strike_stat_boosts.cannot_go_below_life > 0:
		defense_player.life = max(defense_player.life, defense_player.strike_stat_boosts.cannot_go_below_life)
	if armor > 0:
		defense_player.strike_stat_boosts.consumed_armor += consumed_armor
	create_event(Enums.EventType.EventType_Strike_TookDamage, defense_player.my_id, damage_after_armor, "", defense_player.life)

	_append_log_full(Enums.LogType.LogType_Health, defense_player, "takes %s damage, bringing them to %s life!" % [str(damage_after_armor), str(defense_player.life)])

	active_strike.add_damage_taken(defense_player, damage_after_armor)
	if offense_player.strike_stat_boosts.cannot_stun:
		_append_log_full(Enums.LogType.LogType_Strike, offense_player, "'s attack cannot stun!")
	else:
		check_for_stun(defense_player, offense_player.strike_stat_boosts.ignore_guard)

	if defense_player.life <= 0:
		_append_log_full(Enums.LogType.LogType_Default, defense_player, "has no life remaining!")
		on_death(defense_player)

func on_death(performing_player):
	if 'on_death' in performing_player.deck_def:
		do_effect_if_condition_met(performing_player, -1, performing_player.deck_def['on_death'], null)
	if performing_player.life <= 0:
		trigger_game_over(performing_player.my_id, Enums.GameOverReason.GameOverReason_Life)

func get_gauge_cost(performing_player : Player, card, check_if_card_in_hand = false):
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
			"per_boost_in_play":
				var boosts_in_play = performing_player.get_boosts().size()
				gauge_cost = max(0, gauge_cost - boosts_in_play)
			"free_if_ex":
				if is_ex:
					gauge_cost = 0
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
			"free_if_wild":
				if active_strike.get_player_wild_strike(performing_player):
					gauge_cost = 0
			"set_to_range_to_opponent":
				var range_to_opponent = performing_player.distance_to_opponent()
				gauge_cost = range_to_opponent

	return gauge_cost

func get_alternative_life_cost(performing_player : Player, card):
	var alternative_life_cost = card.definition.get("alternative_life_cost", 0)
	if alternative_life_cost:
		var alternative_cost_requirement = card.definition.get("alternative_cost_requirement")
		if alternative_cost_requirement:
			match alternative_cost_requirement:
				"was_wild_swing":
					if not active_strike.get_player_wild_strike(performing_player):
						alternative_life_cost = 0
	return alternative_life_cost

func ask_for_cost(performing_player, card, next_state):
	var gauge_cost = get_gauge_cost(performing_player, card)
	var force_cost = card.definition['force_cost']
	var alternative_life_cost = get_alternative_life_cost(performing_player, card)
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

	if performing_player.can_pay_cost_with([], force_cost, gauge_cost, false, 0) and not card_forced_invalid and not can_invalidate_anyway:
		if active_strike.extra_attack_in_progress:
			active_strike.extra_attack_data.extra_attack_state = next_state
		else:
			active_strike.strike_state = next_state
	else:
		if not card_forced_invalid and performing_player.can_pay_cost(force_cost, gauge_cost, alternative_life_cost):
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.player = performing_player.my_id
			if was_wild_swing or can_invalidate_anyway:
				decision_info.type = Enums.DecisionType.DecisionType_PayStrikeCost_CanWild
			else:
				decision_info.type = Enums.DecisionType.DecisionType_PayStrikeCost_Required

			var still_use_gauge = card.definition['gauge_cost'] > 0 and not performing_player.strike_stat_boosts.may_generate_gauge_with_force
			if gauge_cost > 0 or still_use_gauge:
				decision_info.limitation = "gauge"
				decision_info.cost = gauge_cost
				create_event(Enums.EventType.EventType_Strike_PayCost_Gauge, performing_player.my_id, card.id, "", gauge_discard_reminder, is_ex, alternative_life_cost)
			elif force_cost > 0:
				decision_info.limitation = "force"
				decision_info.cost = force_cost
				create_event(Enums.EventType.EventType_Strike_PayCost_Force, performing_player.my_id, card.id, "", false, is_ex)
			else:
				assert(false, "ERROR: Expected card to have a force to pay")
			_append_log_full(Enums.LogType.LogType_Strike, performing_player, "is selecting cards to pay the %s cost." % decision_info.limitation)
		else:
			# Failed to pay the cost by default.
			_append_log_full(Enums.LogType.LogType_Strike, performing_player, "cannot validate %s, so they wild swing." % card.definition['display_name'])
			performing_player.invalidate_card(card)
			if performing_player == active_strike.initiator:
				if active_strike.initiator_ex_card != null:
					performing_player.add_to_discards(active_strike.initiator_ex_card)
					active_strike.initiator_ex_card = null
					performing_player.strike_stat_boosts.remove_ex()
			else:
				if active_strike.defender_ex_card != null:
					performing_player.add_to_discards(active_strike.defender_ex_card)
					active_strike.defender_ex_card = null
					performing_player.strike_stat_boosts.remove_ex()
			var new_wild_card = null
			while new_wild_card == null:
				performing_player.wild_strike(true);
				if game_over:
					return
				new_wild_card = active_strike.get_player_card(performing_player)
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "wild swings %s!" % new_wild_card.definition['display_name'])
				is_special = new_wild_card.definition['type'] == "special"
				card_forced_invalid = (is_special and performing_player.specials_invalid)
				if card_forced_invalid:
					_append_log_full(Enums.LogType.LogType_Strike, performing_player, "'s specials are invalid, so they wild swing.")
					performing_player.invalidate_card(new_wild_card)
					new_wild_card = null
			create_event(Enums.EventType.EventType_Strike_PayCost_Unable, performing_player.my_id, new_wild_card.id)

func do_hit_response_effects(offense_player : Player, defense_player : Player, incoming_damage : int, hit_response_state : Dictionary, next_state):
	# If more of these are added, need to sequence them to ensure all handled correctly.

	var defender_card = active_strike.get_player_card(defense_player)

	if not hit_response_state:
		hit_response_state['effects'] = get_all_effects_for_timing("when_hit", defense_player, defender_card)
		hit_response_state['effect_index'] = 0
	var effects = hit_response_state['effects']
	var effect_index = hit_response_state['effect_index']
	while effect_index < len(effects):
		var effect = effects[effect_index]
		effect_index += 1 # So it goes to the next effect when returning

		var first_time_only = 'first_time_only' in effect and effect['first_time_only']
		if first_time_only and effect in active_strike.when_hit_effects_processed:
			continue
		active_strike.when_hit_effects_processed.append(effect)
		var card_id = -1
		if 'card_id' in effect:
			card_id = effect['card_id']
		do_effect_if_condition_met(defense_player, card_id, effect, null)
		if game_state == Enums.GameState.GameState_PlayerDecision:
			hit_response_state['effect_index'] = effect_index
			return

		if game_over:
			change_game_state(Enums.GameState.GameState_GameOver)
			return

	hit_response_state.clear()
	if active_strike.extra_attack_in_progress:
		active_strike.extra_attack_data.extra_attack_state = next_state
	else:
		active_strike.strike_state = next_state

	if defense_player.strike_stat_boosts.when_hit_force_for_armor:
		change_game_state(Enums.GameState.GameState_PlayerDecision)
		decision_info.clear()
		decision_info.player = defense_player.my_id
		decision_info.type = Enums.DecisionType.DecisionType_ForceForArmor
		decision_info.choice_card_id = defender_card.id
		decision_info.limitation = defense_player.strike_stat_boosts.when_hit_force_for_armor
		decision_info.amount = 2
		create_event(Enums.EventType.EventType_Strike_ForceForArmor, defense_player.my_id, incoming_damage, "", offense_player.strike_stat_boosts.ignore_armor)

func log_boosts_in_play():
	var card_names = "None"
	var initiator_boosts = active_strike.initiator.get_boosts(false, true)
	if initiator_boosts.size() > 0:
		card_names = card_db.get_card_name(initiator_boosts[0].id)
		for i in range(1, initiator_boosts.size()):
			var card = initiator_boosts[i]
			card_names += ", " + card_db.get_card_name(card.id)
		_append_log_full(Enums.LogType.LogType_Strike, active_strike.initiator, "has active continuous boosts: %s" % _log_card_name(card_names))

	card_names = "None"
	var defender_boosts = active_strike.defender.get_boosts(false, true)
	if defender_boosts.size() > 0:
		card_names = card_db.get_card_name(defender_boosts[0].id)
		for i in range(1, defender_boosts.size()):
			var card = defender_boosts[i]
			card_names += ", " + card_db.get_card_name(card.id)
		_append_log_full(Enums.LogType.LogType_Strike, active_strike.defender, "has active continuous boosts: %s" % _log_card_name(card_names))

func continue_resolve_strike():
	if active_strike.in_setup:
		continue_setup_strike()
		return
	elif active_strike.extra_attack_in_progress:
		continue_extra_attack()
		return

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
				do_remaining_effects(active_strike.initiator, StrikeState.StrikeState_Defender_RevealEffects)
				if active_strike.strike_state == StrikeState.StrikeState_Defender_RevealEffects:
					active_strike.remaining_effect_list = get_all_effects_for_timing("on_strike_reveal", active_strike.defender, active_strike.defender_card)
			StrikeState.StrikeState_Defender_RevealEffects:
				do_remaining_effects(active_strike.defender, StrikeState.StrikeState_Initiator_PayCosts)
			StrikeState.StrikeState_Initiator_PayCosts:
				# Discard any EX cards
				if active_strike.initiator_ex_card != null:
					active_strike.initiator.add_to_discards(active_strike.initiator_ex_card)
				# Ask player to pay for this card if applicable.
				ask_for_cost(active_strike.initiator, active_strike.initiator_card, StrikeState.StrikeState_Defender_PayCosts)
			StrikeState.StrikeState_Defender_PayCosts:
				# Discard any EX cards
				if active_strike.defender_ex_card != null:
					active_strike.defender.add_to_discards(active_strike.defender_ex_card)
				# Ask player to pay for this card if applicable.
				ask_for_cost(active_strike.defender, active_strike.defender_card, StrikeState.StrikeState_DuringStrikeBonuses)
			StrikeState.StrikeState_DuringStrikeBonuses:
				active_strike.cards_in_play += [active_strike.initiator_card, active_strike.defender_card]
				_append_log_full(Enums.LogType.LogType_Strike, active_strike.initiator, "initiated with %s; %s responded with %s." % [active_strike.initiator_card.definition['display_name'], active_strike.defender.name, active_strike.defender_card.definition['display_name']])
				log_boosts_in_play()
				var during_strike_failed_effects_initiator = []
				var during_strike_failed_effects_defender = []
				do_effects_for_timing(
					"during_strike",
					active_strike.initiator,
					active_strike.initiator_card,
					StrikeState.StrikeState_DuringStrikeBonuses,
					false,
					during_strike_failed_effects_initiator
				)
				# Should never be interrupted by player decisions.
				do_effects_for_timing(
					"during_strike",
					active_strike.defender,
					active_strike.defender_card,
					StrikeState.StrikeState_DuringStrikeBonuses,
					false,
					during_strike_failed_effects_defender
				)

				# Retry any effects that the condition failed but they might be true now!
				var check_failed_effects = true
				while check_failed_effects:
					# As long as there are effects being resolved, keep resolving them.
					check_failed_effects = false
					# Iterate through during_strike_failed_effects in reverse as we're removing items.
					for i in range(len(during_strike_failed_effects_initiator)-1, -1, -1):
						var effect = during_strike_failed_effects_initiator[i]
						if is_effect_condition_met(active_strike.initiator, effect, null):
							handle_strike_effect(active_strike.initiator_card.id, effect, active_strike.initiator)
							during_strike_failed_effects_initiator.erase(effect)
							check_failed_effects = true

					for i in range(len(during_strike_failed_effects_defender)-1, -1, -1):
						var effect = during_strike_failed_effects_defender[i]
						if is_effect_condition_met(active_strike.defender, effect, null):
							handle_strike_effect(active_strike.defender_card.id, effect, active_strike.defender)
							during_strike_failed_effects_defender.erase(effect)
							check_failed_effects = true

				active_strike.strike_state = StrikeState.StrikeState_Card1_Activation

				strike_determine_order()
			StrikeState.StrikeState_Card1_Activation:
				var card_name = card_db.get_card_name(card1.id)
				_append_log_full(Enums.LogType.LogType_Strike, player1, "strikes first with %s!" % _log_card_name(card_name))
				create_event(Enums.EventType.EventType_Strike_CardActivation, active_strike.get_player(1).my_id, card1.id)
				active_strike.strike_state = StrikeState.StrikeState_Card1_Before
				active_strike.remaining_effect_list = get_all_effects_for_timing("before", player1, card1)
			StrikeState.StrikeState_Card1_Before:
				do_remaining_effects(player1, StrikeState.StrikeState_Card1_DetermineHit)
			StrikeState.StrikeState_Card1_DetermineHit:
				var hit = determine_if_attack_hits(player1, player2, card1)
				if hit:
					active_strike.player1_hit = true
					active_strike.strike_state = StrikeState.StrikeState_Card1_Hit
					active_strike.remaining_effect_list = get_all_effects_for_timing("hit", player1, card1)
				else:
					active_strike.strike_state = StrikeState.StrikeState_Card1_After
					active_strike.remaining_effect_list = get_all_effects_for_timing("after", player1, card1)
			StrikeState.StrikeState_Card1_Hit:
				do_remaining_effects(player1, StrikeState.StrikeState_Card1_Hit_Response)
			StrikeState.StrikeState_Card1_Hit_Response:
				var incoming_damage = calculate_damage(player1, player2)
				do_hit_response_effects(player1, player2, incoming_damage, active_strike.hit_response_state, StrikeState.StrikeState_Card1_ApplyDamage)
			StrikeState.StrikeState_Card1_ApplyDamage:
				apply_damage(player1, player2)
				active_strike.strike_state = StrikeState.StrikeState_Card1_After
				active_strike.remaining_effect_list = get_all_effects_for_timing("after", player1, card1)
				if game_over:
					active_strike.strike_state = StrikeState.StrikeState_Cleanup
			StrikeState.StrikeState_Card1_After:
				do_remaining_effects(player1, StrikeState.StrikeState_Card2_Activation)
			StrikeState.StrikeState_Card2_Activation:
				var card_name = card_db.get_card_name(card2.id)
				if active_strike.player2_stunned:
					_append_log_full(Enums.LogType.LogType_Strike, player2, "is stunned, so %s does not activate!" % _log_card_name(card_name))
					active_strike.strike_state = StrikeState.StrikeState_Cleanup
				else:
					_append_log_full(Enums.LogType.LogType_Strike, player2, "responds with %s!" % _log_card_name(card_name))
					create_event(Enums.EventType.EventType_Strike_CardActivation, active_strike.get_player(2).my_id, card2.id)
					active_strike.strike_state = StrikeState.StrikeState_Card2_Before
					active_strike.remaining_effect_list = get_all_effects_for_timing("before", player2, card2)
			StrikeState.StrikeState_Card2_Before:
				do_remaining_effects(player2, StrikeState.StrikeState_Card2_DetermineHit)
			StrikeState.StrikeState_Card2_DetermineHit:
				var hit = determine_if_attack_hits(player2, player1, card2)
				if hit:
					active_strike.player2_hit = true
					active_strike.strike_state = StrikeState.StrikeState_Card2_Hit
					active_strike.remaining_effect_list = get_all_effects_for_timing("hit", player2, card2)
				else:
					active_strike.strike_state = StrikeState.StrikeState_Card2_After
					active_strike.remaining_effect_list = get_all_effects_for_timing("after", player2, card2)
			StrikeState.StrikeState_Card2_Hit:
				do_remaining_effects(player2, StrikeState.StrikeState_Card2_Hit_Response)
			StrikeState.StrikeState_Card2_Hit_Response:
				var incoming_damage = calculate_damage(player2, player1)
				do_hit_response_effects(player2, player1, incoming_damage, active_strike.hit_response_state, StrikeState.StrikeState_Card2_ApplyDamage)
			StrikeState.StrikeState_Card2_ApplyDamage:
				apply_damage(player2, player1)
				active_strike.strike_state = StrikeState.StrikeState_Card2_After
				active_strike.remaining_effect_list = get_all_effects_for_timing("after", player2, card2)
				if game_over:
					active_strike.strike_state = StrikeState.StrikeState_Cleanup
			StrikeState.StrikeState_Card2_After:
				do_remaining_effects(player2, StrikeState.StrikeState_Cleanup)
			StrikeState.StrikeState_Cleanup:
				_append_log_full(Enums.LogType.LogType_Strike, null, "Starting strike cleanup.")
				active_strike.strike_state = StrikeState.StrikeState_Cleanup_Player1Effects
				active_strike.remaining_effect_list = get_all_effects_for_timing("cleanup", active_strike.initiator, active_strike.initiator_card)
				strike_add_transform_option(active_strike.initiator, active_strike.initiator_card)
			StrikeState.StrikeState_Cleanup_Player1Effects:
				do_remaining_effects(active_strike.initiator, StrikeState.StrikeState_Cleanup_Player1EffectsComplete)
			StrikeState.StrikeState_Cleanup_Player1EffectsComplete:
				active_strike.strike_state = StrikeState.StrikeState_Cleanup_Player2Effects
				active_strike.remaining_effect_list = get_all_effects_for_timing("cleanup", active_strike.defender, active_strike.defender_card)
				strike_add_transform_option(active_strike.defender, active_strike.defender_card)
			StrikeState.StrikeState_Cleanup_Player2Effects:
				do_remaining_effects(active_strike.defender, StrikeState.StrikeState_EndOfStrike)
			StrikeState.StrikeState_EndOfStrike:
				_append_log_full(Enums.LogType.LogType_Strike, null, "Starting end of strike effects.")
				active_strike.strike_state = StrikeState.StrikeState_EndOfStrike_Player1Effects
				active_strike.remaining_effect_list = get_all_effects_for_timing("endofstrike", active_strike.initiator, active_strike.initiator_card)
			StrikeState.StrikeState_EndOfStrike_Player1Effects:
				do_remaining_effects(active_strike.initiator, StrikeState.StrikeState_EndOfStrike_Player1EffectsComplete)
			StrikeState.StrikeState_EndOfStrike_Player1EffectsComplete:
				active_strike.strike_state = StrikeState.StrikeState_EndOfStrike_Player2Effects
				active_strike.remaining_effect_list = get_all_effects_for_timing("endofstrike", active_strike.defender, active_strike.defender_card)
			StrikeState.StrikeState_EndOfStrike_Player2Effects:
				do_remaining_effects(active_strike.defender, StrikeState.StrikeState_Cleanup_Complete)
			StrikeState.StrikeState_Cleanup_Complete:
				# Handle cleanup effects that cause attack cards to leave play before the standard timing
				handle_strike_attack_cleanup(active_strike.initiator, active_strike.initiator_card)
				handle_strike_attack_cleanup(active_strike.defender, active_strike.defender_card)

				# Remove any Reading effects
				player1.reading_card_id = ""
				player2.reading_card_id = ""

				# Cleanup any continuous boosts.
				active_strike.initiator.cleanup_continuous_boosts()
				active_strike.defender.cleanup_continuous_boosts()

				# Cleanup attacks, if hit, move card to gauge, otherwise move to discard.
				if active_strike.initiator_card in active_strike.cards_in_play:
					strike_send_attack_to_discard_or_gauge(active_strike.initiator, active_strike.initiator_card)
				if active_strike.defender_card in active_strike.cards_in_play:
					strike_send_attack_to_discard_or_gauge(active_strike.defender, active_strike.defender_card)
				assert(active_strike.cards_in_play.size() == 0,
						"ERROR: %s still in play after strike should have been cleaned up" %
								", ".join(active_strike.cards_in_play.map(
										func (card): return "%s" % card)))

				# Remove all stat boosts.
				player.strike_stat_boosts.clear()
				opponent.strike_stat_boosts.clear()
				player.gauge_spent_this_strike = 0
				opponent.gauge_spent_this_strike = 0
				player.gauge_cards_spent_this_strike = []
				opponent.gauge_cards_spent_this_strike = []

				# Cleanup UI
				create_event(Enums.EventType.EventType_Strike_Cleanup, player1.my_id, -1)

				active_strike = null
				if game_over:
					change_game_state(Enums.GameState.GameState_GameOver)
				else:
					start_end_turn()
				break

	if game_state == Enums.GameState.GameState_PlayerDecision and decision_info.type == Enums.DecisionType.DecisionType_ForceBoostSustainTopdeck:
		do_topdeck_boost()
	elif game_state == Enums.GameState.GameState_PlayerDecision and decision_info.type == Enums.DecisionType.DecisionType_ForceBoostSustainTopDiscard:
		do_discard_boost()

func strike_add_transform_option(performing_player : Player, card : GameCard):
	assert(active_strike)

	if performing_player.has_card_name_in_zone(card, "transform"):
		return

	var hit = active_strike.player1_hit
	if active_strike.get_player(2) == performing_player:
		hit = active_strike.player2_hit

	if hit and card.definition['boost']['boost_type'] == "transform":
		var added_effect = {
			"card_id": -1,
			"effect_type": "choice",
			"choice": [
				{
					"effect_type": "transform_attack",
					"card_name": card.definition['display_name'],
					"card_id": card.id
				},
				{ "effect_type": "pass" }
			]
		}
		add_remaining_effect(added_effect)

func handle_strike_attack_immediate_removal(performing_player : Player):
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
		performing_player.add_to_discards(card)
		active_strike.cards_in_play.erase(card)
	elif performing_player.strike_stat_boosts.move_strike_to_opponent_gauge:
		_append_log_full(Enums.LogType.LogType_CardInfo, other_player, "adds the opponent's attack %s to their Gauge!" % _log_card_name(card_name))
		other_player.add_to_gauge(card)
		active_strike.cards_in_play.erase(card)
	elif performing_player.strike_stat_boosts.return_attack_to_hand:
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "returns their attack %s to their hand." % _log_card_name(card_name))
		performing_player.add_to_hand(card, true)
		active_strike.cards_in_play.erase(card)
	elif performing_player.strike_stat_boosts.move_strike_to_opponent_boosts:
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "'s attack %s is set as a continuous boost for %s." % [_log_card_name(card_name), other_player.name])
		other_player.add_to_continuous_boosts(card)
		other_player.sustained_boosts.append(card.id)
		active_strike.cards_in_play.erase(card)
	elif performing_player.strike_stat_boosts.move_strike_to_boosts:
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "'s attack %s is set as a continuous boost." % _log_card_name(card_name))
		performing_player.add_to_continuous_boosts(card)
		if performing_player.strike_stat_boosts.move_strike_to_boosts_sustain:
			performing_player.sustained_boosts.append(card.id)
		active_strike.cards_in_play.erase(card)
	elif performing_player.strike_stat_boosts.attack_to_topdeck_on_cleanup:
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "returns their attack %s to the top of their deck." % _log_card_name(card_name))
		performing_player.add_to_top_of_deck(card, true)
		active_strike.cards_in_play.erase(card)
	elif performing_player.strike_stat_boosts.always_add_to_overdrive:
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds their attack %s to overdrive." % _log_card_name(card_name))
		performing_player.add_to_overdrive(card)
		active_strike.cards_in_play.erase(card)
	else:
		assert(false, "ERROR: Unexpected call to attack removal but state doesn't match.")

func handle_strike_attack_cleanup(performing_player : Player, card):
	var card_name = card.definition['display_name']

	if card not in active_strike.cards_in_play:
		# Already removed from play mid-strike
		return

	if performing_player.is_set_aside_card(card.id):
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "sets aside their attack %s." % _log_card_name(card_name))
		create_event(Enums.EventType.EventType_SetCardAside, performing_player.my_id, card.id)
		active_strike.cards_in_play.erase(card)
	elif performing_player.strike_stat_boosts.seal_attack_on_cleanup:
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "seals their attack %s." % _log_card_name(card_name))
		do_seal_effect(performing_player, card.id, "")
		active_strike.cards_in_play.erase(card)
	elif performing_player.strike_stat_boosts.discard_attack_on_cleanup:
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards their attack %s." % _log_card_name(card_name))
		performing_player.add_to_discards(card)
		active_strike.cards_in_play.erase(card)
	elif performing_player.strike_stat_boosts.return_attack_to_hand:
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "returns their attack %s to their hand." % _log_card_name(card_name))
		performing_player.add_to_hand(card, true)
		active_strike.cards_in_play.erase(card)

func strike_send_attack_to_discard_or_gauge(performing_player : Player, card):
	var hit = active_strike.player1_hit
	var stat_boosts = performing_player.strike_stat_boosts
	if active_strike.get_player(2) == performing_player:
		hit = active_strike.player2_hit
	var card_name = card.definition['display_name']

	if performing_player.strike_stat_boosts.move_strike_to_transforms:
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "transforms their attack %s." % _log_card_name(card_name))
		performing_player.add_to_transforms(card)
	elif hit or stat_boosts.always_add_to_gauge:
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds their attack %s to gauge." % _log_card_name(card_name))
		performing_player.add_to_gauge(card)
	else:
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards their attack %s." % _log_card_name(card_name))
		performing_player.add_to_discards(card)
	active_strike.cards_in_play.erase(card)

func begin_extra_attack(performing_player : Player, card_id : int):
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
	active_strike.extra_attack_data.extra_attack_previous_attack_range_effects = performing_player.strike_stat_boosts.range_effects
	active_strike.extra_attack_data.extra_attack_state = ExtraAttackState.ExtraAttackState_PayCosts
	active_strike.extra_attack_data.extra_attack_hit = false

	# Other relevant passives that need to be undone.
	# If other extra attack characters are added, consider what else might be needed.
	# For example: If an extra attack character can have positive power bonus boosts, those need to be removed too.
	performing_player.strike_stat_boosts.ignore_armor = false
	performing_player.strike_stat_boosts.ignore_guard = false

	# Extra attacks are unaffected by the attack_does_not_hit effect from hitting Nirvana or the effect on Block.
	performing_player.strike_stat_boosts.attack_does_not_hit = false
	performing_player.strike_stat_boosts.overwrite_total_power = false

	# This can happen with more After effects to resolve.
	# This should be fine as we use a different remaining effects list.
	# Also, nothing that uses active_strike.effects_resolved_in_timing should be active.
	# If a new timing is added for extra attacks, then more state may need to be preserved.
	active_strike.effects_resolved_in_timing = 0
	active_strike.extra_attack_data.extra_attack_remaining_effects = []

	# Remove the card from the hand, it is now in the striking area.
	# Notify via an event.
	performing_player.remove_card_from_hand(card_id, true, false)
	create_event(Enums.EventType.EventType_Strike_Started_ExtraAttack, performing_player.my_id, card_id, "")

	var card_name = card_db.get_card_name(card_id)
	_append_log_full(Enums.LogType.LogType_Strike, performing_player, "performs an extra attack with %s." % [_log_card_name(card_name)])

	continue_resolve_strike()

func continue_extra_attack():
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
				ask_for_cost(attacker_player, attacker_card, ExtraAttackState.ExtraAttackState_DuringStrikeBonuses)
			ExtraAttackState.ExtraAttackState_DuringStrikeBonuses:
				do_effects_for_timing("during_strike", attacker_player, attacker_card, ExtraAttackState.ExtraAttackState_Activation, true)
			ExtraAttackState.ExtraAttackState_Activation:
				# Gain armor/guard from the card.
				attacker_player.strike_stat_boosts.armor += get_card_stat(attacker_player, attacker_card, "armor")
				attacker_player.strike_stat_boosts.guard += get_card_stat(attacker_player, attacker_card, "guard")
				# Do the attack starting at Before.
				active_strike.extra_attack_data.extra_attack_state = ExtraAttackState.ExtraAttackState_Before
				active_strike.extra_attack_data.extra_attack_remaining_effects = get_all_effects_for_timing("before", attacker_player, attacker_card, true, true)
			ExtraAttackState.ExtraAttackState_Before:
				do_remaining_effects(attacker_player, ExtraAttackState.ExtraAttackState_DetermineHit)
			ExtraAttackState.ExtraAttackState_DetermineHit:
				var hit = determine_if_attack_hits(attacker_player, defender_player, attacker_card)
				if hit:
					active_strike.extra_attack_data.extra_attack_hit = true
					active_strike.extra_attack_data.extra_attack_state = ExtraAttackState.ExtraAttackState_Hit
					active_strike.extra_attack_data.extra_attack_remaining_effects = get_all_effects_for_timing("hit", attacker_player, attacker_card, true, true)
				else:
					active_strike.extra_attack_data.extra_attack_state = ExtraAttackState.ExtraAttackState_After
					active_strike.extra_attack_data.extra_attack_remaining_effects = get_all_effects_for_timing("after", attacker_player, attacker_card, true, true)
			ExtraAttackState.ExtraAttackState_Hit:
				do_remaining_effects(attacker_player, ExtraAttackState.ExtraAttackState_Hit_Response)
			ExtraAttackState.ExtraAttackState_Hit_Response:
				var incoming_damage = calculate_damage(attacker_player, defender_player)
				do_hit_response_effects(attacker_player, defender_player, incoming_damage, active_strike.extra_attack_data.extra_attack_hit_response_state, ExtraAttackState.ExtraAttackState_Hit_ApplyDamage)
			ExtraAttackState.ExtraAttackState_Hit_ApplyDamage:
				apply_damage(attacker_player, defender_player)
				active_strike.extra_attack_data.extra_attack_state = ExtraAttackState.ExtraAttackState_After
				active_strike.extra_attack_data.extra_attack_remaining_effects = get_all_effects_for_timing("after", attacker_player, attacker_card, true, true)
				if game_over:
					active_strike.strike_state = ExtraAttackState.ExtraAttackState_Cleanup
			ExtraAttackState.ExtraAttackState_After:
				do_remaining_effects(attacker_player, ExtraAttackState.ExtraAttackState_Cleanup)
			ExtraAttackState.ExtraAttackState_Cleanup:
				active_strike.extra_attack_data.extra_attack_state = ExtraAttackState.ExtraAttackState_CleanupEffects
				active_strike.extra_attack_data.extra_attack_remaining_effects = get_all_effects_for_timing("cleanup", attacker_player, attacker_card, true, true)
			ExtraAttackState.ExtraAttackState_CleanupEffects:
				do_remaining_effects(attacker_player, ExtraAttackState.ExtraAttackState_Complete)
			ExtraAttackState.ExtraAttackState_Complete:
				var card_name = attacker_card.definition['display_name']
				if active_strike.extra_attack_data.extra_attack_hit or active_strike.extra_attack_data.extra_attack_always_go_to_gauge:
					_append_log_full(Enums.LogType.LogType_CardInfo, attacker_player, "adds their extra attack %s to gauge." % _log_card_name(card_name))
					attacker_player.add_to_gauge(attacker_card)
				else:
					_append_log_full(Enums.LogType.LogType_CardInfo, attacker_player, "discards their extra attack %s." % _log_card_name(card_name))
					attacker_player.add_to_discards(attacker_card)

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
						continue_resolve_strike()
				break

func determine_if_attack_hits(attacker_player : Player, defender_player : Player, card : GameCard):
	var card_name = card_db.get_card_name(card.id)
	if attacker_player.strike_stat_boosts.calculate_range_from_buddy:
		var buddy_location = attacker_player.get_buddy_location(attacker_player.strike_stat_boosts.calculate_range_from_buddy_id)
		var buddy_name = attacker_player.get_buddy_name(attacker_player.strike_stat_boosts.calculate_range_from_buddy_id)
		_append_log_full(Enums.LogType.LogType_Strike, null, "Range check: attacking from %s's %s (space %s) to %s (space %s)." % [attacker_player.name, buddy_name, buddy_location, defender_player.name, defender_player.arena_location])
	elif attacker_player.strike_stat_boosts.calculate_range_from_space != -1:
		_append_log_full(Enums.LogType.LogType_Strike, null, "Range check: %s attacking from space %s to %s (space %s)." % [attacker_player.name, attacker_player.strike_stat_boosts.calculate_range_from_space, defender_player.name, defender_player.arena_location])
	else:
		_append_log_full(Enums.LogType.LogType_Strike, null, "Range check: attacking from %s (space %s) to %s (space %s)." % [attacker_player.name, attacker_player.arena_location, defender_player.name, defender_player.arena_location])

	if in_range(attacker_player, defender_player, card, true) and not card.definition['id'] in attacker_player.cards_that_will_not_hit:
		_append_log_full(Enums.LogType.LogType_Strike, attacker_player, "hits with %s!" % _log_card_name(card_name))
		return true
	else:
		var extra_details = ""
		if card.definition['id'] in attacker_player.cards_that_will_not_hit:
			extra_details = "the named card "
		_append_log_full(Enums.LogType.LogType_Strike, attacker_player, "misses with %s%s!" % [extra_details, _log_card_name(card_name)])
		create_event(Enums.EventType.EventType_Strike_Miss, attacker_player.my_id, 0)
		return false

func do_topdeck_boost():
	var performing_player = _get_player(active_strike.remaining_forced_boosts_player_id)
	performing_player.sustain_next_boost = active_strike.remaining_forced_boosts_sustaining
	active_strike.remaining_forced_boosts -= 1

	performing_player.draw(1, true)
	change_game_state(Enums.GameState.GameState_PlayerDecision)
	decision_info.type = Enums.DecisionType.DecisionType_BoostNow
	do_boost(performing_player, performing_player.hand[performing_player.hand.size()-1].id)

func do_discard_boost():
	var performing_player = _get_player(active_strike.remaining_forced_boosts_player_id)
	performing_player.sustain_next_boost = active_strike.remaining_forced_boosts_sustaining
	active_strike.remaining_forced_boosts -= 1

	var boost_card_id = performing_player.get_top_continuous_boost_in_discard()
	performing_player.move_card_from_discard_to_hand(boost_card_id)
	change_game_state(Enums.GameState.GameState_PlayerDecision)
	decision_info.type = Enums.DecisionType.DecisionType_BoostNow
	do_boost(performing_player, boost_card_id)

func begin_resolve_boost(performing_player : Player, card_id : int, additional_boost_ids = [], shuffle_discard_after : bool = false):

	# If boosting multiple cards, treat as parent boosts to "queue" them
	var more_boosts_to_play = true
	while more_boosts_to_play:
		var new_boost = Boost.new()
		if active_boost:
			new_boost.parent_boost = active_boost

		active_boost = new_boost
		active_boost.playing_player = performing_player
		active_boost.card = card_db.get_card(card_id)
		active_boost.shuffle_discard_on_cleanup = shuffle_discard_after
		active_boost.boosted_from_gauge = performing_player.is_card_in_gauge(card_id)

		var secret = active_boost.card.definition["boost"].get("facedown", false)
		performing_player.remove_card_from_hand(card_id, not secret, false)
		performing_player.remove_card_from_gauge(card_id)
		performing_player.remove_card_from_discards(card_id)
		performing_player.remove_card_from_set_aside(card_id)
		var facedown = active_boost.card.definition["boost"].get("facedown")
		create_event(Enums.EventType.EventType_Boost_Played, performing_player.my_id, card_id, "", facedown)

		if additional_boost_ids:
			card_id = additional_boost_ids.pop_front()
			# Must offset effects_resolved because the boost-chaining functionality assumes that
			#  boost_aditional will be an effect of the boost itself
			active_boost.effects_resolved -= 1
		else:
			more_boosts_to_play = false

	# Resolve all immediate/now effects
	# If continuous, put it into continous boost tracking.
	continue_resolve_boost()

func continue_resolve_boost():
	if game_state == Enums.GameState.GameState_WaitForStrike or game_state == Enums.GameState.GameState_Strike_Opponent_Set_First:
		active_boost.strike_after_boost = true
		if game_state == Enums.GameState.GameState_Strike_Opponent_Set_First:
			active_boost.strike_after_boost_opponent_first = true
	change_game_state(Enums.GameState.GameState_Boost_Processing)

	var effects = card_db.get_card_boost_effects_now_immediate(active_boost.card)
	var character_effects = active_boost.playing_player.get_on_boost_effects(active_boost.card)
	var other_player = _get_player(get_other_player(active_boost.playing_player.my_id))
	var counter_effects = other_player.get_counter_boost_effects()
	while true:
		if game_state == Enums.GameState.GameState_WaitForStrike or game_state == Enums.GameState.GameState_Strike_Opponent_Set_First:
			active_boost.strike_after_boost = true
			if game_state == Enums.GameState.GameState_Strike_Opponent_Set_First:
				active_boost.strike_after_boost_opponent_first = true

		if not active_boost.checked_counter and not active_boost.boost_negated:
			if active_boost.counters_resolved < len(counter_effects):
				var effect = counter_effects[active_boost.counters_resolved]
				do_effect_if_condition_met(other_player, -1, effect, null)
				if game_state == Enums.GameState.GameState_PlayerDecision:
					break

				active_boost.counters_resolved += 1
			else:
				active_boost.checked_counter = true
		if active_boost.boost_negated and active_boost.effects_resolved < len(effects) + len(character_effects):
			active_boost.effects_resolved = len(effects) + len(character_effects)

		if active_boost.effects_resolved < len(effects):
			var effect = effects[active_boost.effects_resolved]
			do_effect_if_condition_met(active_boost.playing_player, active_boost.card.id, effect, null)
			if game_state == Enums.GameState.GameState_PlayerDecision:
				break

			active_boost.effects_resolved += 1
		elif active_boost.effects_resolved < len(effects) + len(character_effects):
			# Resolve character effects.
			var character_effect_index = active_boost.effects_resolved - len(effects)
			var effect = character_effects[character_effect_index]
			do_effect_if_condition_met(active_boost.playing_player, active_boost.card.id, effect, null)
			if game_state == Enums.GameState.GameState_PlayerDecision:
				break

			active_boost.effects_resolved += 1
		elif active_boost.effects_resolved < len(effects) + len(character_effects) + 1:
			# After all effects are resolved, discard/move the card then check for cancel.
			boost_finish_resolving_card(active_boost.playing_player)
			active_boost.effects_resolved += 1
			if not active_boost.boost_negated:
				if active_boost.playing_player.can_cancel(active_boost.card) and not active_boost.strike_after_boost:
					var cancel_cost = card_db.get_card_cancel_cost(active_boost.card.id)
					change_game_state(Enums.GameState.GameState_PlayerDecision)
					decision_info.type = Enums.DecisionType.DecisionType_BoostCancel
					decision_info.player = active_boost.playing_player.my_id
					decision_info.choice = cancel_cost
					create_event(Enums.EventType.EventType_Boost_CancelDecision, active_boost.playing_player.my_id, cancel_cost)
					break
		else:
			boost_play_cleanup(active_boost.playing_player)
			break

		if game_over:
			break

func boost_finish_resolving_card(performing_player : Player):
	# All boost immediate/now effects are done.
	# If continuous, add to player.
	# If immediate, add to discard.
	if active_boost.card.definition['boost']['boost_type'] == "continuous" and not active_boost.discard_on_cleanup:
		performing_player.add_to_continuous_boosts(active_boost.card)
		if active_strike:
			# Do the during_strike effects and add any before effects to the remaining effects list.
			for effect in active_boost.card.definition['boost']['effects']:
				if effect['timing'] == "during_strike":
					do_effect_if_condition_met(performing_player, active_boost.card.id, effect, null)

		if performing_player.sustain_next_boost:
			performing_player.sustained_boosts.append(active_boost.card.id)
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "set and sustained %s as a continuous boost." % _get_boost_and_card_name(active_boost.card))
		else:
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "set %s as a continuous boost." % _get_boost_and_card_name(active_boost.card))
	elif not active_boost.discarded_already:
		if active_boost.seal_on_cleanup:
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "seals the boosted card %s." % active_boost.card.definition['display_name'])
			do_seal_effect(performing_player, active_boost.card.id, "")
		elif active_boost.card.id in active_boost.cleanup_to_gauge_card_ids:
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds the boosted card %s to gauge." % active_boost.card.definition['display_name'])
			performing_player.add_to_gauge(active_boost.card)
		elif active_boost.card.id in active_boost.cleanup_to_hand_card_ids:
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "returns the boosted card %s to hand." % active_boost.card.definition['display_name'])
			performing_player.add_to_hand(active_boost.card, true)
		else:
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards the boosted card %s." % active_boost.card.definition['display_name'])
			performing_player.add_to_discards(active_boost.card)

	performing_player.sustain_next_boost = false
	if game_state == Enums.GameState.GameState_WaitForStrike or game_state == Enums.GameState.GameState_Strike_Opponent_Set_First:
		active_boost.strike_after_boost = true
		if game_state == Enums.GameState.GameState_Strike_Opponent_Set_First:
			active_boost.strike_after_boost_opponent_first = true

func boost_play_cleanup(performing_player : Player):
	decision_info.clear()
	# Account for boosts that played other boosts
	if active_boost.parent_boost:
		if active_strike:
			_boost_play_cleanup_update_effects(performing_player)

		# Pass on any relevant fields.
		active_boost.parent_boost.action_after_boost = active_boost.parent_boost.action_after_boost or active_boost.action_after_boost
		active_boost.parent_boost.strike_after_boost = active_boost.parent_boost.strike_after_boost or active_boost.strike_after_boost
		active_boost.parent_boost.strike_after_boost_opponent_first = active_boost.parent_boost.strike_after_boost_opponent_first or active_boost.strike_after_boost_opponent_first

		# Go back to the parent boost.
		active_boost = active_boost.parent_boost
		active_boost.effects_resolved += 1
		continue_resolve_boost()
		return

	if active_boost.shuffle_discard_on_cleanup:
		var shuffle_effect = { "effect_type": "shuffle_discard_in_place" }
		handle_strike_effect(-1, shuffle_effect, performing_player)

	var preparing_strike = false
	if performing_player.strike_on_boost_cleanup and not active_boost.strike_after_boost and not active_strike:
		if performing_player.wild_strike_on_boost_cleanup:
			var wild_effect = { "effect_type": "strike_wild" }
			handle_strike_effect(-1, wild_effect, performing_player)
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
				create_event(Enums.EventType.EventType_Strike_FromGauge, performing_player.my_id, 0)
			elif performing_player.next_strike_from_gauge:
				decision_info.source = "gauge"
				create_event(Enums.EventType.EventType_Strike_FromGauge, performing_player.my_id, 0)
			else:
				create_event(Enums.EventType.EventType_ForceStartStrike, performing_player.my_id, 0)
		active_boost = null
		preparing_strike = true
	elif active_boost.action_after_boost and not active_strike:
		_append_log_full(Enums.LogType.LogType_Action, performing_player, "takes an additional action!")
		create_event(Enums.EventType.EventType_Boost_ActionAfterBoost, performing_player.my_id, 0)
		change_game_state(Enums.GameState.GameState_PickAction)
		active_boost = null
	else:
		if active_strike:
			_boost_play_cleanup_update_effects(performing_player)

			# Continue resolving the strike (or doing another boost if you're doing Faust things...)
			var handled_weird_boost = false
			if active_strike.remaining_forced_boosts > 0:
				if active_strike.remaining_forced_boosts_source == "topdeck" and performing_player.deck.size() > 0:
					handled_weird_boost = true
					active_boost = null
					do_topdeck_boost()
				elif active_strike.remaining_forced_boosts_source == "topdiscard":
					var boost_card_id = performing_player.get_top_continuous_boost_in_discard()
					if boost_card_id != -1:
						handled_weird_boost = true
						active_boost = null
						do_discard_boost()

			if not handled_weird_boost:
				active_strike.remaining_forced_boosts = 0
				active_boost = null
				active_strike.effects_resolved_in_timing += 1
				continue_resolve_strike()
		else:
			active_boost = null
			if not preparing_strike and not active_overdrive:
				check_hand_size_advance_turn(performing_player)

func _boost_play_cleanup_update_effects(performing_player : Player):
	# Add this boost's effects to the current effect list if the taming matches.
	var current_strike_timing = get_current_strike_timing()
	var is_current_timing_player = true
	if current_strike_timing in ['before', 'hit', 'after', 'cleanup']:
		is_current_timing_player = performing_player.my_id == get_current_strike_timing_player_id()
	for effect in active_boost.card.definition['boost']['effects']:
		var matches_timing = false
		if effect['timing'] == current_strike_timing and is_current_timing_player:
			matches_timing = true
		elif current_strike_timing == "before" and effect['timing'] == "both_players_before":
			matches_timing = true
		elif current_strike_timing == "after" and effect['timing'] == "both_players_after":
			matches_timing = true

		if matches_timing:
			effect['card_id'] = active_boost.card.id
			active_strike.remaining_effect_list.append(effect)

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

func can_do_ex_transform(performing_player : Player):
	if game_state != Enums.GameState.GameState_PickAction:
		return false
	if active_turn_player != performing_player.my_id:
		return false

	var transform_options = []
	for card in performing_player.hand:
		if card.definition['boost']['boost_type'] != "transform":
			continue
		var card_name = card.definition['display_name']
		if card_name in transform_options:
			return true
		transform_options.append(card_name)

	return false

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

func check_post_action_effects(performing_player : Player):

	# Queue any end of turn character effects
	var post_action_effects = performing_player.get_character_effects_at_timing("after_non_strike_action")
	# Queue any end of turn boost effects.
	var boost_list = performing_player.get_continuous_boosts_and_transforms()
	for i in range(len(boost_list) - 1, -1, -1):
		var card = boost_list[i]
		for effect in card.definition['boost']['effects']:
			if effect['timing'] == "after_non_strike_action":
				effect['card_id'] = card.id
				post_action_effects.append(effect)

	# process effects, break if in choice state
	while true:
		if post_action_effects_resolved < len(post_action_effects):
			var effect = post_action_effects[post_action_effects_resolved]
			do_effect_if_condition_met(performing_player, -1, effect, null)
			if game_state == Enums.GameState.GameState_PlayerDecision:
				break
			post_action_effects_resolved += 1
		else:
			active_post_action_effect = false
			performing_player.checked_post_action_effects = true
			if not post_action_interruption:
				check_hand_size_advance_turn(performing_player)
			break

		if game_over:
			break

	# after out of effects

func check_hand_size_advance_turn(performing_player : Player):

	assert(not active_strike)

	if not performing_player.checked_post_action_effects:
		active_post_action_effect = true
		post_action_effects_resolved = 0
		post_action_interruption = false
		check_post_action_effects(performing_player)
		return

	if performing_player.bonus_actions > 0:
		change_game_state(Enums.GameState.GameState_PickAction)
		performing_player.bonus_actions -= 1
		performing_player.checked_post_action_effects = false
		if performing_player.bonus_actions == 0:
			_append_log_full(Enums.LogType.LogType_Action, performing_player, "takes an additional action!")
		else:
			_append_log_full(Enums.LogType.LogType_Action, performing_player, "takes an additional action! (%s left)" % performing_player.bonus_actions)
		create_event(Enums.EventType.EventType_Boost_ActionAfterBoost, performing_player.my_id, performing_player.bonus_actions)
	elif performing_player.dan_draw_choice and not active_special_draw_effect and not performing_player.skip_end_of_turn_draw:
		var choice_effect = {
			"effect_type": "choice",
			"choice": [
				{ "effect_type": "set_dan_draw_choice_INTERNAL", "from_bottom": false },
				{ "effect_type": "set_dan_draw_choice_INTERNAL", "from_bottom": true }
			]
		}
		handle_strike_effect(-1, choice_effect, performing_player)
		active_special_draw_effect = true
	elif performing_player.enchantress_draw_choice and not active_special_draw_effect and not performing_player.skip_end_of_turn_draw:
		var choice_effect = {
			"effect_type": "choice",
			"choice": [
				{ "effect_type": "draw_to", "amount": 7 },
				{ "effect_type": "draw", "amount": 1 }
			]
		}
		handle_strike_effect(-1, choice_effect, performing_player)
		active_special_draw_effect = true
	else:
		if performing_player.skip_end_of_turn_draw or performing_player.has_passive("skip_eot_draw_and_discard"):
			performing_player.skip_end_of_turn_draw = false
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "skips drawing for end of turn. Their hand size is %s." % len(performing_player.hand))
		else:
			# Set this regardless so characters that don't draw at end of turn know to do something else
			performing_player.did_end_of_turn_draw = true
			if performing_player.draw_at_end_of_turn:
				var from_bottom_str = ""
				if active_special_draw_effect and performing_player.dan_draw_choice_from_bottom:
					performing_player.draw(1, false, true)
					from_bottom_str = " from bottom of deck"
				else:
					performing_player.draw(1)
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "draws %sfor end of turn. Their hand size is now %s." % [from_bottom_str, len(performing_player.hand)])

		active_special_draw_effect = false
		if len(performing_player.hand) > performing_player.max_hand_size and not performing_player.has_passive("skip_eot_draw_and_discard"):
			change_game_state(Enums.GameState.GameState_DiscardDownToMax)
			create_event(Enums.EventType.EventType_HandSizeExceeded, performing_player.my_id, len(performing_player.hand) - performing_player.max_hand_size)
		else:
			start_end_turn()

func do_prepare(performing_player) -> bool:
	printlog("MainAction: PREPARE by %s" % [performing_player.name])
	if not can_do_prepare(performing_player):
		printlog("ERROR: Tried to Prepare but can't.")
		return false

	create_event(Enums.EventType.EventType_Prepare, performing_player.my_id, 0)
	_append_log_full(Enums.LogType.LogType_Action, performing_player, "Turn Action: Prepare")
	_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "draws a card.")
	performing_player.draw(1)

	active_prepare = true
	prepare_effects_resolved = 0
	continue_resolve_prepare(performing_player)
	return true

func continue_resolve_prepare(performing_player : Player):
	# Assuming that a strike can't be started in here
	change_game_state(Enums.GameState.GameState_Boost_Processing)

	var boost_effects = get_boost_effects_at_timing("on_prepare", performing_player)
	var character_effects = performing_player.get_character_effects_at_timing("on_prepare")
	for effect in character_effects:
		effect['card_id'] = -1
	var prepare_effects = boost_effects + character_effects

	while true:
		if prepare_effects_resolved < len(prepare_effects):
			var effect = prepare_effects[prepare_effects_resolved]
			do_effect_if_condition_met(performing_player, -1, effect, null)
			if game_state == Enums.GameState.GameState_PlayerDecision:
				break
			prepare_effects_resolved += 1
		else:
			active_prepare = false
			check_hand_size_advance_turn(performing_player)
			break

		if game_over:
			break

func handle_spend_life_for_force(performing_player : Player, spent_life : int) -> bool:
	if spent_life > performing_player.life:
		printlog("ERROR: Tried to spend more life than player had.")
		return false

	if spent_life > 0:
		performing_player.spend_life(spent_life)
		#if active_strike:
			#active_strike.add_damage_taken(damaged_player, unmitigated_damage)
			#check_for_stun(damaged_player, false)
	return true

func handle_spend_life_cost(performing_player : Player, spent_life : int) -> bool:
	if spent_life > performing_player.life:
		printlog("ERROR: Tried to spend more life than player had.")
		return false

	if spent_life > 0:
		performing_player.spend_life(spent_life)
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
	_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards down to their max hand size: %s." % _log_card_name(card_names))

	performing_player.discard(card_ids)
	start_end_turn()
	return true

func do_reshuffle(performing_player : Player) -> bool:
	printlog("MainAction: RESHUFFLE by %s" % [performing_player.name])
	if not can_do_reshuffle(performing_player):
		printlog("ERROR: Tried to reshuffle but can't.")
		return false

	_append_log_full(Enums.LogType.LogType_Action, performing_player, "Turn Action: Manual Reshuffle")
	performing_player.reshuffle_discard(true)
	check_hand_size_advance_turn(performing_player)
	return true

func do_move(performing_player : Player, card_ids, new_arena_location, use_free_force : bool = false, spent_life_for_force : int = 0) -> bool:
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
	var generated_force = performing_player.get_force_with_cards(card_ids, "MOVE", false, use_free_force)
	generated_force += performing_player.get_force_from_spent_life(spent_life_for_force)

	if generated_force < required_force:
		printlog("ERROR: Not enough force with these cards to move there.")
		return false
	performing_player.total_force_spent_this_turn += required_force

	performing_player.discard(card_ids, 0, true)
	if not handle_spend_life_for_force(performing_player, spent_life_for_force):
		return false
	if game_over:
		return true

	# Move the player.
	var old_location = performing_player.arena_location
	performing_player.move_to(new_arena_location)

	# Logging.
	var card_names = ""
	if card_ids.size() > 0:
		card_names = card_db.get_card_name(card_ids[0])
		for i in range(1, card_ids.size()):
			card_names += ", " + card_db.get_card_name(card_ids[i])
	else:
		card_names = "passive bonus"
	_append_log_full(Enums.LogType.LogType_Action, performing_player, "Turn Action: Move")
	if len(card_ids) > 0:
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "generates force to move by discarding %s." % _log_card_name(card_names))
	_append_log_full(Enums.LogType.LogType_CharacterMovement, performing_player, "moves from space %s to %s." % [str(old_location), str(new_arena_location)])

	# On move effects, treat same as character action.
	var effects = get_all_effects_for_timing("on_move_action", performing_player, null)
	remaining_character_action_effects = effects
	active_character_action = true
	continue_player_action_resolution(performing_player)
	return true

func do_change(performing_player : Player, card_ids, treat_ultras_as_single_force : bool, use_free_force : bool = false, spent_life_for_force : int = 0) -> bool:
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

	create_event(Enums.EventType.EventType_ChangeCards, performing_player.my_id, 0)
	var force_generated = performing_player.get_force_with_cards(card_ids, "CHANGE_CARDS", treat_ultras_as_single_force, use_free_force)
	performing_player.discard(card_ids, 0, true)

	force_generated += performing_player.get_force_from_spent_life(spent_life_for_force)
	if not handle_spend_life_for_force(performing_player, spent_life_for_force):
		return false
	if game_over:
		return true

	# Handle Guile's Change Cards strike bonus
	var can_strike_after_change = false
	if performing_player.guile_change_cards_bonus and has_card_from_gauge and performing_player.exceeded:
		can_strike_after_change = true

	_append_log_full(Enums.LogType.LogType_Action, performing_player, "Turn Action: Change Cards")
	if len(card_ids) > 0:
		var card_names = card_db.get_card_names(card_ids)
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "generates force by discarding %s." % _log_card_name(card_names))
	else:
		_append_log_full(Enums.LogType.LogType_Effect, performing_player, "generates %s force." % force_generated)
	_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "draws %s card(s)." % force_generated)
	performing_player.draw(force_generated)
	performing_player.total_force_spent_this_turn += force_generated

	# Handle Guile's Exceed strike bonus
	# Otherwise just end the turn.
	if can_strike_after_change:
		# Need to give the player a choice to strike.
		handle_strike_effect(
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
		check_hand_size_advance_turn(performing_player)

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
	if performing_player.has_overdrive:
		performing_player.move_cards_to_overdrive(card_ids, "gauge")
	else:
		var card_names = card_db.get_card_names(card_ids)
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "spends %s card(s) from gauge: %s" % [len(card_ids), _log_card_name(card_names)])
		performing_player.discard(card_ids, 0, true)

	performing_player.exceed()
	if game_state == Enums.GameState.GameState_AutoStrike:
		# Draw the set aside card.
		var card = performing_player.get_set_aside_card(decision_info.effect_type)
		performing_player.add_to_hand(card, false)
		# Strike with it
		change_game_state(Enums.GameState.GameState_PickAction)
		performing_player.next_strike_faceup = true
		do_strike(performing_player, card.id, false, -1)
	elif game_state != Enums.GameState.GameState_WaitForStrike and game_state != Enums.GameState.GameState_PlayerDecision:
		check_hand_size_advance_turn(performing_player)
	elif game_state == Enums.GameState.GameState_PlayerDecision:
		# Some other player action will result in the end turn finishing.
		# Striking is the end of an exceed so don't set this to true.
		active_exceed = true
	return true

func do_boost(performing_player : Player, card_id : int, payment_card_ids : Array = [], use_free_force = false, spent_life_for_force : int = 0, additional_boost_ids : Array = []) -> bool:
	printlog("MainAction: BOOST by %s - %s" % [get_player_name(performing_player.my_id), card_db.get_card_id(card_id)])
	if game_state != Enums.GameState.GameState_PickAction or performing_player.my_id != active_turn_player:
		if not wait_for_mid_strike_boost():
			printlog("ERROR: Tried to boost but not your turn")
			assert(false)
			return false

	var card = card_db.get_card(card_id)
	# Redirection to transform handler
	if card.definition['boost']['boost_type'] == "transform":
		if len(payment_card_ids) == 1 or decision_info.limitation == "transform":
			var ex_card_id = -1
			if len(payment_card_ids) > 0:
				ex_card_id = payment_card_ids[0]
			return do_ex_transform(performing_player, card_id, ex_card_id)
		else:
			printlog("ERROR: Tried to transform as action without a second copy")
			assert(false)
			return false

	if card.definition['boost']['boost_type'] == "overload":
		printlog("ERROR: Tried to boost a card with an overload")
		assert(false)
		return false

	if not decision_info.ignore_costs:
		var force_cost = card.definition['boost']['force_cost']
		if not performing_player.can_pay_cost_with(payment_card_ids, force_cost, 0, use_free_force, spent_life_for_force):
			printlog("ERROR: Tried to boost action but can't pay force cost with these cards.")
			return false
		performing_player.total_force_spent_this_turn += force_cost

	if additional_boost_ids:
		if decision_info.amount <= 1:
			printlog("ERROR: Tried to boost with multiple cards when not allowed.")
			return false

	if game_state == Enums.GameState.GameState_PickAction:
		_append_log_full(Enums.LogType.LogType_Action, performing_player, "Turn Action: Boost")

	_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "boosts %s." % _get_boost_and_card_name(card))

	if payment_card_ids.size() > 0:
		var card_names = card_db.get_card_name(payment_card_ids[0])
		for i in range(1, payment_card_ids.size()):
			card_names += ", " + card_db.get_card_name(payment_card_ids[i])
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards cards to pay for the boost: %s." % _log_card_name(card_names))
		performing_player.discard(payment_card_ids, 0, true)
	if not handle_spend_life_for_force(performing_player, spent_life_for_force):
		return false
	if game_over:
		return true

	var shuffle_discard_on_boost_cleanup = false or decision_info.extra_info

	# Bonus effects for playing a boost, assumed to be non-blocking
	if decision_info.bonus_effect:
		do_effect_if_condition_met(performing_player, -1, decision_info.bonus_effect, null)

	begin_resolve_boost(performing_player, card_id, additional_boost_ids, shuffle_discard_on_boost_cleanup)
	return true

func do_ex_transform(performing_player : Player, card_id : int, ex_card_id : int):
	printlog("Redirected to EX Transform")
	if not (game_state == Enums.GameState.GameState_PickAction and performing_player.my_id == active_turn_player) and \
	   not (decision_info.limitation == "transform" and performing_player.my_id == decision_info.player):
		printlog("ERROR: Tried to EX transform but not your turn")
		assert(false)
		return false

	var card = card_db.get_card(card_id)
	if card.definition['boost']['boost_type'] != "transform":
		printlog("ERROR: Tried to transform a card without a transform")
		assert(false)
		return false

	if ex_card_id == -1:
		if decision_info.limitation != "transform":
			printlog("ERROR: Tried to transform without a second card with invalid effect")
			assert(false)
			return false
	else:
		var ex_card = card_db.get_card(ex_card_id)
		if card.definition['display_name'] != ex_card.definition['display_name']:
			printlog("ERROR: Tried to EX transform with mismatching cards")
			assert(false)
			return false

	if performing_player.has_card_name_in_zone(card, "transform"):
		printlog("ERROR: Tried to transform a previously-transformed card")
		assert(false)
		return false

	if game_state == Enums.GameState.GameState_PickAction:
		_append_log_full(Enums.LogType.LogType_Action, performing_player, "Turn Action: EX Transform")
	_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "transforms %s." % _get_boost_and_card_name(card))

	var card_name = card.definition['display_name']
	if ex_card_id != -1:
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards another copy of %s." % _log_card_name(card_name))
		performing_player.discard([ex_card_id])

	performing_player.remove_card_from_hand(card_id, true, false)
	create_event(Enums.EventType.EventType_Boost_Played, performing_player.my_id, card_id, "Transform")
	performing_player.add_to_transforms(card)

	# Handling immediate effects; expected to be non-blocking, mostly to establish toggles e.g.
	var effects = card_db.get_card_boost_effects_now_immediate(card)
	for effect in effects:
		do_effect_if_condition_met(performing_player, card_id, effect, null)

	if game_state == Enums.GameState.GameState_PickAction:
		check_hand_size_advance_turn(performing_player)
	else:
		change_game_state(Enums.GameState.GameState_Boost_Processing)
		continue_player_action_resolution(performing_player)

	return true

func do_strike(
	performing_player : Player,
	card_id : int,
	wild_strike: bool,
	ex_card_id : int,
	opponent_sets_first : bool = false,
	use_face_attack : bool = false
) -> bool:
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

	# ex_card_id being non -1 means it is an extra strike option.
	var ex_strike = not wild_strike and ex_card_id != -1
	if str(decision_info.limitation) == "EX":
		if not ex_strike and not performing_player.has_ex_boost():
			printlog("ERROR: Tried to strike without an EX when one was required.")
			return false

	if use_face_attack:
		# Find the face attack and update the card id
		var face_attack_card = performing_player.get_face_attack_card()
		if face_attack_card:
			card_id = face_attack_card.id
			performing_player.add_to_hand(face_attack_card, false)
			performing_player.next_strike_faceup = true
		else:
			printlog("ERROR: Could not find face attack to strike with.")
			return false

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
		if wild_strike and ex_card_id != -1:
			# This is an extra strike option and the id is the extra strike index.
			if ex_card_id >= performing_player.get_extra_strike_options_count():
				printlog("ERROR: Tried to strike with an invalid extra strike id.")
				return false
		elif not wild_strike and not performing_player.is_card_in_hand(card_id):
			if performing_player.is_card_in_continuous_boosts(card_id):
				strike_from_boosts = true
				var card = card_db.get_card(card_id)
				var must_set_from_boost = 'must_set_from_boost' in card.definition and card.definition['must_set_from_boost']
				var may_set_from_boost = 'may_set_from_boost' in card.definition and card.definition['may_set_from_boost']
				if not must_set_from_boost and not may_set_from_boost:
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
		if card_db.get_card(card_id).definition['type'] == "normal" and \
				card_db.get_card(ex_card_id).definition['boost']['boost_type'] != "overload":
			printlog("ERROR: Tried to strike with a ex card that doesn't match.")
			return false

	# Begin the strike
	var delayed_wild_strike = wild_strike and performing_player.delayed_wild_strike

	# Lay down the strike
	match game_state:
		Enums.GameState.GameState_PickAction, Enums.GameState.GameState_WaitForStrike:
			if not opponent_sets_first:
				initialize_new_strike(performing_player, opponent_sets_first)
				if game_state == Enums.GameState.GameState_PickAction:
					_append_log_full(Enums.LogType.LogType_Action, performing_player, "Turn Action: Strike")
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "initiates a strike!")

			if wild_strike and ex_card_id != -1:
				# This is striking with an extra strike option.
				var strike_option = performing_player.get_extra_strike_option(ex_card_id)
				_append_log_full(Enums.LogType.LogType_Strike, performing_player,
					"sets their attack from %s." % [strike_option["option_name"]])
				match strike_option["effect_type"]:
					"strike_with_buddy_card":
						# This effect assumes there is 1 card in the set aside zone.
						for effect in strike_option["special_effects"]:
							handle_strike_effect(-1, effect, performing_player)
						performing_player.strike_with_set_aside_card(0)
						card_id = active_strike.initiator_card.id
			elif wild_strike:
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "wild swings!")
				if delayed_wild_strike:
					performing_player.wild_strike_delayed()
				else:
					performing_player.wild_strike()
					if game_over:
						return true
					card_id = active_strike.initiator_card.id
			elif performing_player.next_strike_random_gauge:
				performing_player.random_gauge_strike()
				performing_player.next_strike_random_gauge = false
				if game_over:
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
					if card_id in performing_player.boost_id_locations:
						active_strike.initiator_set_from_boost_space = performing_player.get_boost_location(card_id)
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
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "sets %s as a face-up attack!" % _log_card_name(card_name))

			# Send the EX first as that is visual and logic is triggered off the regular one.
			if not delayed_wild_strike:
				if ex_strike:
					create_event(Enums.EventType.EventType_Strike_Started_Ex, performing_player.my_id, ex_card_id, "", reveal_immediately)
				create_event(Enums.EventType.EventType_Strike_Started, performing_player.my_id, card_id, "", reveal_immediately, ex_strike)
			continue_setup_strike()

		Enums.GameState.GameState_Strike_Opponent_Set_First:
			if opponent_sets_first: # should always be true
				initialize_new_strike(performing_player, opponent_sets_first)
				var opponent_name = _get_player(get_other_player(performing_player.my_id)).name
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "initiates a strike! %s will set their attack first." % opponent_name)
				continue_setup_strike()

		Enums.GameState.GameState_Strike_Opponent_Response:
			if active_strike.waiting_for_reading_response:
				active_strike.waiting_for_reading_response = false
				# Reset effect counter due to reading card choice
				active_strike.effects_resolved_in_timing = 0

			if wild_strike and ex_card_id != -1:
				# This is striking with an extra strike option.
				var strike_option = performing_player.get_extra_strike_option(ex_card_id)
				_append_log_full(Enums.LogType.LogType_Strike, performing_player,
					"sets their attack from %s." % [strike_option["option_name"]])
				match strike_option["effect_type"]:
					"strike_with_buddy_card":
						# This effect assumes there is 1 card in the set aside zone.
						for effect in strike_option["special_effects"]:
							handle_strike_effect(-1, effect, performing_player)
						performing_player.strike_with_set_aside_card(0)
						card_id = active_strike.defender_card.id
			elif wild_strike:
				_append_log_full(Enums.LogType.LogType_Strike, performing_player, "wild swings!")
				if delayed_wild_strike:
					performing_player.wild_strike_delayed()
				else:
					performing_player.wild_strike()
					if game_over:
						return true
					card_id = active_strike.defender_card.id
			else:
				active_strike.defender_card = card_db.get_card(card_id)
				if strike_from_boosts:
					if card_id in performing_player.boost_id_locations:
						active_strike.defender_set_from_boost_space = performing_player.get_boost_location(card_id)
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

			if not delayed_wild_strike:
				# Send the EX first as that is visual and logic is triggered off the regular one.
				if ex_strike:
					create_event(Enums.EventType.EventType_Strike_Response_Ex, performing_player.my_id, ex_card_id)
				create_event(Enums.EventType.EventType_Strike_Response, performing_player.my_id, card_id, "", strike_from_boosts, ex_strike)
			continue_setup_strike()
	return true

func do_pay_strike_cost(
	performing_player : Player,
	card_ids : Array,
	wild_strike : bool,
	discard_ex_first : bool = true,
	use_free_force = false,
	spent_life_for_force : int = 0,
	pay_alternative_life_cost : bool = false
	) -> bool:
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

	if wild_strike:
		var invalid_by_choice = decision_info.type == Enums.DecisionType.DecisionType_PayStrikeCost_CanWild
		_append_log_full(Enums.LogType.LogType_Strike, performing_player, "chooses to wild swing instead of validating %s." % card.definition['display_name'])
		# Replace existing card with a wild strike
		var current_card = active_strike.get_player_card(performing_player)
		performing_player.invalidate_card(current_card, invalid_by_choice)
		performing_player.wild_strike(true)
		var new_card = active_strike.get_player_card(performing_player)
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "wild swings %s!" % new_card.definition['display_name'])
	else:
		var force_cost = card.definition['force_cost']
		var gauge_cost = get_gauge_cost(performing_player, card)
		var alternative_life_cost = get_alternative_life_cost(performing_player, card)
		if alternative_life_cost == 0 and pay_alternative_life_cost:
			printlog("ERROR: Tried to pay alternative cost but there isn't one.")
			return false
		if performing_player.strike_stat_boosts.may_generate_gauge_with_force:
			# Convert the gauge cost to a force cost.
			force_cost = gauge_cost
			gauge_cost = 0

		if not pay_alternative_life_cost:
			# If they aren't paying the alternate cost, zero it out so it isn't considered.
			alternative_life_cost = 0

		if performing_player.can_pay_cost_with(
			card_ids,
			force_cost,
			gauge_cost,
			use_free_force,
			spent_life_for_force,
			alternative_life_cost
			):
			performing_player.strike_stat_boosts.strike_payment_card_ids = card_ids
			if card_ids.size() > 0:
				var card_names = card_db.get_card_name(card_ids[0])
				for i in range(1, card_ids.size()):
					card_names += ", " + card_db.get_card_name(card_ids[i])
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "validates by discarding %s." % _log_card_name(card_names))
			else:
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "validates with passive bonus.")

			if not handle_spend_life_for_force(performing_player, spent_life_for_force):
				return false
			if pay_alternative_life_cost and not handle_spend_life_cost(performing_player, alternative_life_cost):
				return false

			if game_over:
				return true

			var where_to_discard = 0
			if not discard_ex_first and active_strike.get_player_ex_card(performing_player) != null:
				where_to_discard = 1
			performing_player.discard(card_ids, where_to_discard, true)
			performing_player.total_force_spent_this_turn += force_cost

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
	continue_resolve_strike()
	return true

func do_force_for_armor(performing_player : Player, card_ids : Array, use_free_force : bool = false, spent_life_for_force : int = 0) -> bool:
	printlog("SubAction: FORCEARMOR by %s cards %s" % [performing_player.name, card_ids])
	if game_state != Enums.GameState.GameState_PlayerDecision or decision_info.type != Enums.DecisionType.DecisionType_ForceForArmor:
		printlog("ERROR: Tried to force for armor but not in decision state.")
		return false
	if decision_info.player != performing_player.my_id:
		printlog("ERROR: Tried to force for armor for wrong player.")
		return false

	var use_gauge_instead = decision_info.limitation == "gauge"
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
		force_generated = performing_player.get_force_with_cards(card_ids, "FORCE_FOR_ARMOR", false, use_free_force)
	force_generated += performing_player.get_force_from_spent_life(spent_life_for_force)
	if not handle_spend_life_for_force(performing_player, spent_life_for_force):
		return false
	if game_over:
		return true
	performing_player.total_force_spent_this_turn += force_generated

	if force_generated > 0:
		var card_names = ""
		if card_ids.size() > 0:
			card_names = card_db.get_card_name(card_ids[0])
			for i in range(1, card_ids.size()):
				card_names += ", " + card_db.get_card_name(card_ids[i])
		else:
			card_names = "passive bonus"
		if use_gauge_instead:
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "spends gauge for armor: %s." % _log_card_name(card_names))
		else:
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards cards as force for armor: %s." % _log_card_name(card_names))
		var armor_per_force = decision_info.amount
		performing_player.discard(card_ids)
		handle_strike_effect(decision_info.choice_card_id, {'effect_type': 'armorup', 'amount': force_generated * armor_per_force}, performing_player)
	continue_resolve_strike()
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

	if doing_cancel:
		var card_names = card_db.get_card_name(gauge_card_ids[0])
		for i in range(1, gauge_card_ids.size()):
			card_names += ", " + card_db.get_card_name(gauge_card_ids[i])
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "spends gauge to Cancel, discarding %s." % _log_card_name(card_names))
		performing_player.discard(gauge_card_ids, 0, true)
		performing_player.on_cancel_boost()
		active_boost.action_after_boost = true

	# Ky, for example, has a choice after canceling the first time.
	if game_state != Enums.GameState.GameState_PlayerDecision:
		boost_play_cleanup(performing_player)
	return true

## Select cards from `performing_player`'s hand to be moved. The destination of
## the move is not specified, and is instead defined by the currently active
## decision.
func do_relocate_card_from_hand(performing_player : Player, card_ids : Array) -> bool:
	printlog("SubAction: RELOCATE_CARD_FROM_HAND by %s: %s" % [get_player_name(performing_player.my_id), card_ids])
	if decision_info.player != performing_player.my_id:
		printlog("ERROR: Tried to do_relocate_card_from_hand for wrong player.")
		return false
	if game_state != Enums.GameState.GameState_PlayerDecision or decision_info.type != Enums.DecisionType.DecisionType_CardFromHandToGauge:
		printlog("ERROR: Tried to do_relocate_card_from_hand but not in decision state.")
		return false
	for card_id in card_ids:
		var restricted_to_card_ids = decision_info.effect.get("restricted_to_card_ids", [])
		if restricted_to_card_ids:
			if not card_id in restricted_to_card_ids:
				printlog("ERROR: Tried to do_relocate_card_from_hand with card not in restricted list.")
				return false
		if not performing_player.is_card_in_hand(card_id):
			printlog("ERROR: Tried to do_relocate_card_from_hand with card not in hand.")
			return false

	if card_ids.size() > 0:
		for card_id in card_ids:
			if decision_info.destination == "gauge":
				performing_player.move_card_from_hand_to_gauge(card_id)
			elif decision_info.destination == "topdeck":
				performing_player.move_card_from_hand_to_deck(card_id)
			elif decision_info.destination == "bottomdeck":
				performing_player.move_card_from_hand_to_deck(card_id, 0, true)
			elif decision_info.destination == "deck":
				performing_player.shuffle_card_from_hand_to_deck(card_id)
			elif decision_info.destination == "stored_cards":
				var secret = performing_player.is_stored_zone_facedown()
				performing_player.move_card_from_hand_to_stored_cards(card_id, secret)
			else:
				assert(false, "Unhandled destination %s for do_relocate_card_from_hand" % decision_info.destination)

	# Log message
	if decision_info.destination == "gauge":
		var card_names = card_db.get_card_names(card_ids)
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "moves %s card(s) from hand to gauge: %s" % [str(card_ids.size()), _log_card_name(card_names)])
	elif decision_info.destination == "topdeck":
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "moves %s card(s) from hand to top of deck." % str(card_ids.size()))
	elif decision_info.destination == "bottomdeck":
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "moves %s card(s) from hand to bottom of deck." % str(card_ids.size()))
	elif decision_info.destination == "deck":
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "shuffles %s card(s) from hand into deck." % str(card_ids.size()))
	elif decision_info.destination == "stored_cards":
		var stored_zone_name = performing_player.get_stored_zone_name()
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "moves %s card(s) from hand to %s." % [str(card_ids.size()), stored_zone_name])

	set_player_action_processing_state()

	if decision_info.bonus_effect and card_ids.size() > 0:
		var per_card_effect = decision_info.bonus_effect.duplicate()
		per_card_effect['amount'] = card_ids.size() * per_card_effect.get("amount", 1)
		do_effect_if_condition_met(performing_player, decision_info.choice_card_id, per_card_effect, null)

	continue_player_action_resolution(performing_player)
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
	_append_log_full(Enums.LogType.LogType_Effect, performing_player, "names %s." % _log_card_name(card_name))
	set_player_action_processing_state()
	handle_strike_effect(decision_info.choice_card_id, effect, performing_player)
	continue_player_action_resolution(performing_player)
	return true

func do_choice(performing_player : Player, choice_index : int) -> bool:
	printlog("SubAction: CHOICE by %s card %s" % [performing_player.name, str(choice_index)])
	if decision_info.player != performing_player.my_id:
		printlog("ERROR: Tried to name card for wrong player.")
		return false
	if game_state != Enums.GameState.GameState_PlayerDecision:
		printlog("ERROR: Tried to make a choice but not in decision state.")
		return false
	if decision_info.choice == null or choice_index >= len(decision_info.choice):
		printlog("ERROR: Tried to make a choice that doesn't exist.")
		return false

	var card_id = decision_info.choice_card_id
	var effect = decision_info.choice[choice_index].duplicate()
	if 'card_id' in effect:
		card_id = effect['card_id']
	var copying_effect = false
	if decision_info.effect_type:
		copying_effect = decision_info.effect_type == "copy_other_hit_effect"
	if decision_info.multiple_choice_amount > 1:
		# This is a "choose multiple" effect, so the player can choose again
		# from the remaining effects.
		# Add an "and" to the effect the player chose.
		# Only include choices from the original that weren't chosen.
		# NOTE: This assumes that none of the effects have "and" on them already.
		var remaining_choices = decision_info.multiple_choice_amount - 1
		var choice_list = []
		for i in range(decision_info.choice.size()):
			if i != choice_index:
				choice_list.append(decision_info.choice[i])
		var and_choice_effect = {
			"effect_type": "choice",
				"choice": choice_list,
				"multiple_amount": remaining_choices
		}
		effect['and'] = and_choice_effect

	set_player_action_processing_state()

	if decision_info.type == Enums.DecisionType.DecisionType_ChooseSimultaneousEffect:
		if copying_effect:
			# If we're duplicating an effect, no need to remove it yet
			decision_info.effect_type = ""
		else:
			# This was the player choosing what to do next.
			# Remove this effect from the remaining effects.
			erase_remaining_effect(get_base_remaining_effect(effect))

	do_effect_if_condition_met(performing_player, card_id, effect, null)
	continue_player_action_resolution(performing_player)
	return true

func set_player_action_processing_state():
	if active_start_of_turn_effects or active_end_of_turn_effects or active_overdrive or active_boost \
	or active_character_action or active_exceed or active_change_cards or active_prepare \
	or active_special_draw_effect or active_post_action_effect:
		game_state = Enums.GameState.GameState_Boost_Processing
	elif active_strike:
		game_state = Enums.GameState.GameState_Strike_Processing
	else:
		printlog("ERROR: Unexpected game state - no active thing to be resolving?")
		assert(false)

func continue_player_action_resolution(performing_player : Player):
	# This function is intended to be called at the end of the various do_* functions
	# that are called by the game wrapper to resolve player actions/decisions.

	# Handle the wacky forced boost cases (Faust/Platinum/Hazama),
	# then, if the player has a decision it just returns.
	# If they don't, call the appropriate continue/do_remaining function
	# depending on what is active.
	if game_state == Enums.GameState.GameState_PlayerDecision and decision_info.type == Enums.DecisionType.DecisionType_ForceBoostSustainTopdeck:
		# Handle stupid Faust case.
		do_topdeck_boost()
	elif game_state == Enums.GameState.GameState_PlayerDecision and decision_info.type == Enums.DecisionType.DecisionType_ForceBoostSustainTopDiscard:
		do_discard_boost()
	else:
		if game_state != Enums.GameState.GameState_PlayerDecision:
			if active_special_draw_effect:
				check_hand_size_advance_turn(performing_player)
			elif active_post_action_effect:
				post_action_effects_resolved += 1
				check_post_action_effects(performing_player)
			elif active_end_of_turn_effects:
				continue_end_turn()
			elif active_start_of_turn_effects:
				continue_begin_turn()
			elif active_overdrive:
				do_remaining_overdrive(performing_player)
			elif active_boost:
				if active_boost.checked_counter:
					active_boost.effects_resolved += 1
				else:
					active_boost.counters_resolved += 1
				continue_resolve_boost()
			elif active_strike:
				active_strike.effects_resolved_in_timing += 1
				continue_resolve_strike()
			elif active_character_action:
				do_remaining_character_action(performing_player)
			elif active_exceed:
				active_exceed = false
				if game_state != Enums.GameState.GameState_WaitForStrike:
					check_hand_size_advance_turn(performing_player)
			elif active_change_cards:
				active_change_cards = false
				if game_state != Enums.GameState.GameState_WaitForStrike:
					check_hand_size_advance_turn(performing_player)
			elif active_prepare:
				prepare_effects_resolved += 1
				continue_resolve_prepare(performing_player)
			else:
				# End of turn states (pick action for next player or discard down for current) or strikes are expected.
				if game_state == Enums.GameState.GameState_PickAction or game_state == Enums.GameState.GameState_DiscardDownToMax or game_state == Enums.GameState.GameState_WaitForStrike:
					pass
				else:
					assert(false, "ERROR: Unexpected game state - no active action resolution")

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

	performing_player.mulligan(card_ids)
	_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "mulligans %s card(s)." % str(len(card_ids)))
	if player.mulligan_complete and opponent.mulligan_complete:
		change_game_state(Enums.GameState.GameState_PickAction)
		_append_log_full(Enums.LogType.LogType_Default, _get_player(active_turn_player), "'s Turn Start!")
		create_event(Enums.EventType.EventType_AdvanceTurn, active_turn_player, 0)
	else:
		create_event(Enums.EventType.EventType_MulliganDecision, get_other_player(performing_player.my_id), 0)
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
	for card_id in card_ids:
		create_event(Enums.EventType.EventType_SustainBoost, performing_player.my_id, card_id)
		performing_player.sustained_boosts.append(int(card_id))
		var boost_name = _get_boost_and_card_name(card_db.get_card(card_id))
		_append_log_full(Enums.LogType.LogType_Effect, performing_player, "sustains their continuous boost %s." % boost_name)

	set_player_action_processing_state()
	continue_player_action_resolution(performing_player)
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
		elif decision_info.source == "gauge":
			if not performing_player.is_card_in_gauge(card_id):
				printlog("ERROR: Tried to choose from gauge with card not in gauge.")
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
			"normal":
				if card.definition['type'] != "normal":
					printlog("ERROR: Tried to choose from discard with card that doesn't meet limitation normal.")
					return false
			"special":
				if card.definition['type'] != "special":
					printlog("ERROR: Tried to choose from discard with card that doesn't meet limitation special.")
					return false
			"ultra":
				if card.definition['type'] != "ultra":
					printlog("ERROR: Tried to choose from discard with card that doesn't meet limitation ultra.")
					return false
			"normal/special":
				if card.definition['type'] not in ["normal", "special"]:
					printlog("ERROR: Tried to choose from discard with card that doesn't meet limitation normal/special.")
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
	var secret_zones = false
	for card_id in card_ids:
		var destination = decision_info.destination
		if decision_info.source == "discard":
			match destination:
				"deck":
					performing_player.move_card_from_discard_to_deck(card_id)
				"deck_noshuffle":
					performing_player.move_card_from_discard_to_deck(card_id, false)
				"gauge":
					performing_player.move_card_from_discard_to_gauge(card_id)
				"hand":
					performing_player.move_card_from_discard_to_hand(card_id)
				"lightningrod_any_space":
					# Bring this card to the top of the discard pile.
					# The discard_effect will place it as a lightning rod from there.
					performing_player.bring_card_to_top_of_discard(card_id)
				"overdrive":
					performing_player.move_cards_to_overdrive([card_id], "discard")
				"sealed":
					do_seal_effect(performing_player, card_id, "discard")
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
		elif decision_info.source == "gauge":
			match destination:
				"discard":
					performing_player.discard([card_id])
				_:
					printlog("ERROR: Choose from gauge destination not implemented.")
					assert(false, "Choose from gauge destination not implemented.")
					return false
		elif decision_info.source == "sealed":
			match destination:
				"hand":
					performing_player.move_card_from_sealed_to_hand(card_id)
					secret_zones = performing_player.sealed_area_is_secret
				_:
					printlog("ERROR: Choose from sealed destination not implemented.")
					assert(false, "Choose from sealed destination not implemented.")
					return false

		elif decision_info.source == "overdrive":
			match destination:
				"discard":
					performing_player.discard([card_id])
				"hand":
					# Drop the discard event because we really just want the add to hand event.
					performing_player.discard([card_id])
					performing_player.move_card_from_discard_to_hand(card_id)
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
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "plays %s from %s." % [_log_card_name(card_names), decision_info.source])
	elif secret_zones:
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "moves %s card(s) from %s to %s." % [str(len(card_ids)), decision_info.source, dest_name])
	else:
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "moves card(s) from %s to %s: %s." % [decision_info.source, dest_name, _log_card_name(card_names)])

	set_player_action_processing_state()

	# Do any bonus effect.
	if decision_info.bonus_effect:
		var effect = decision_info.bonus_effect
		effect['discarded_card_ids'] = card_ids
		do_effect_if_condition_met(performing_player, decision_info.choice_card_id, effect, null)

	continue_player_action_resolution(performing_player)
	return true

func do_force_for_effect(performing_player : Player, card_ids : Array, treat_ultras_as_single_force : bool, cancel : bool = false, use_free_force : bool = false, spent_life_for_force : int = 0) -> bool:
	printlog("SubAction: FORCE_FOR_EFFECT by %s cards %s" % [performing_player.name, card_ids])
	if game_state != Enums.GameState.GameState_PlayerDecision or decision_info.type != Enums.DecisionType.DecisionType_ForceForEffect:
		printlog("ERROR: Tried to force for effect but not in decision state.")
		return false
	if decision_info.player != performing_player.my_id:
		printlog("ERROR: Tried to force for armor for wrong player.")
		return false

	for card_id in card_ids:
		if not performing_player.is_card_in_hand(card_id) and not performing_player.is_card_in_gauge(card_id):
			printlog("ERROR: Tried to force for effect with card not in hand or gauge.")
			return false

	var force_generated = performing_player.get_force_with_cards(card_ids, "FORCE_FOR_EFFECT", treat_ultras_as_single_force, use_free_force)
	force_generated += performing_player.get_force_from_spent_life(spent_life_for_force)
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

	if performing_player.force_cost_reduction > decision_info.effect['force_max']:
		if decision_info.effect['force_max'] == -1:
			force_generated += performing_player.force_cost_reduction
		else:
			force_generated = decision_info.effect['force_max']

	if decision_info.effect['force_max'] != -1 and force_generated > decision_info.effect['force_max']:
		if force_generated - ultras <= decision_info.effect['force_max']:
			force_generated = decision_info.effect['force_max']
		else:
			printlog("ERROR: Tried to force for effect with too much force.")
			return false
	performing_player.total_force_spent_this_turn += force_generated

	var continuation_player = performing_player
	if 'continuation_switch_player_control' in decision_info.effect and decision_info.effect['continuation_switch_player_control']:
		continuation_player = _get_player(get_other_player(performing_player.my_id))

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
			var interval = 1.0
			if 'force_effect_interval' in decision_info.effect:
				interval = decision_info.effect['force_effect_interval']
			effect_times = floor(force_generated / interval)
			if force_generated > 0 and decision_effect.get('combine_multiple_into_one'):
				# This will work on a single nested "and" that has an amount.
				# If it doesn't have an amount, this won't work as expected.
				decision_effect = decision_effect.duplicate(true)
				decision_effect['amount'] = effect_times * decision_effect['amount']
				var and_effect = decision_effect.get('and')
				if and_effect and and_effect.get("amount"):
					and_effect['amount'] = effect_times * and_effect['amount']
				effect_times = 1
		elif decision_info.effect['overall_effect']:
			decision_effect = decision_info.effect['overall_effect']
			effect_times = 1

		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "generates force by discarding %s." % _log_card_name(card_names))
		performing_player.discard(card_ids)
		for i in range(0, effect_times):
			handle_strike_effect(decision_info.choice_card_id, decision_effect, performing_player)

		if not handle_spend_life_for_force(performing_player, spent_life_for_force):
			return false
		if game_over:
			return true

	continue_player_action_resolution(continuation_player)
	return true

func do_gauge_for_effect(performing_player : Player, card_ids : Array) -> bool:
	printlog("SubAction: GAUGE_FOR_EFFECT by %s cards %s" % [performing_player.name, card_ids])
	if game_state != Enums.GameState.GameState_PlayerDecision or decision_info.type != Enums.DecisionType.DecisionType_GaugeForEffect:
		printlog("ERROR: Tried to gauge for effect but not in decision state.")
		return false
	if decision_info.player != performing_player.my_id:
		printlog("ERROR: Tried to gauge for armor for wrong player.")
		return false

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

	if 'valid_card_types' in decision_info.effect:
		for card_id in card_ids:
			if card_db.get_card(card_id).definition['type'] not in decision_info.effect['valid_card_types']:
				printlog("ERROR: Invalid card type selected for type-specific gauge for effect.")
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
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "returns card(s) from gauge to hand: %s." % _log_card_name(card_names))
		else:
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "spends %s gauge, discarding %s." % [str(gauge_generated), _log_card_name(card_names)])

		# Move the spent cards to the right place.
		if to_hand:
			for card_id in card_ids:
				performing_player.move_card_from_gauge_to_hand(card_id)
		else:
			performing_player.discard(card_ids, 0, true)
		for i in range(0, effect_times):
			handle_strike_effect(decision_info.choice_card_id, decision_effect, performing_player)

	if decision_info.bonus_effect:
		handle_strike_effect(decision_info.choice_card_id, decision_info.bonus_effect, performing_player)

	continue_player_action_resolution(performing_player)
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

	var target_opponent = false
	var target_player = performing_player
	var other_player = _get_player(get_other_player(performing_player.my_id))
	if decision_info.effect['effect_type'] == "choose_opponent_card_to_discard":
		target_opponent = true
		target_player = other_player

	var amount = decision_info.effect['amount']
	var allow_fewer = 'allow_fewer' in decision_info.effect and decision_info.effect['allow_fewer']
	if not (decision_info.can_pass or amount == -1 or allow_fewer):
		if len(card_ids) != amount and target_player.hand.size() >= amount:
			printlog("ERROR: Tried to choose to discard wrong number of cards.")
			return false

	for card_id in card_ids:
		if not target_opponent:
			if not performing_player.is_card_in_hand(card_id):
				printlog("ERROR: Tried to choose to discard with card not in hand.")
				return false
		else:
			if not other_player.is_card_in_hand(card_id):
				printlog("ERROR: Tried to discard opponent card not in their hand.")
				return false

		if decision_info.limitation and decision_info.limitation not in ["can_pay_cost", "from_array", "same-named", "range_to_opponent"]:
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
	var repeat_bonus_times = 0
	var repeat_bonus_effect = null
	if not skip_effect and decision_info.bonus_effect:
		var per_discard_effect = 'per_discard' in decision_info.bonus_effect and decision_info.bonus_effect['per_discard']
		if per_discard_effect:
			repeat_bonus_effect = decision_info.bonus_effect.duplicate()
			repeat_bonus_times = len(card_ids)
		else:
			effect['and'] = decision_info.bonus_effect.duplicate()
			effect['and']['discarded_card_ids'] = card_ids
	if len(card_ids) < decision_info.effect['amount'] and 'smaller_discard_effect' in decision_info.effect:
		effect['and'] = decision_info.effect['smaller_discard_effect'].duplicate()

	set_player_action_processing_state()

	do_effect_if_condition_met(performing_player, decision_info.choice_card_id, effect, null)
	if repeat_bonus_effect:
		for i in range(repeat_bonus_times):
			handle_strike_effect(decision_info.choice_card_id, repeat_bonus_effect, performing_player)
	continue_player_action_resolution(performing_player)
	return true

func do_character_action(performing_player : Player, card_ids, action_idx : int = 0, use_free_force = false, spent_life_for_force : int = 0):
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
	if not performing_player.can_pay_cost_with(card_ids, force_cost, gauge_cost, use_free_force, spent_life_for_force):
		printlog("ERROR: Tried to character action but can't pay cost with these cards.")
		return false

	var action_name = "Character Action"
	if 'action_name' in action:
		action_name = action['action_name']
	_append_log_full(Enums.LogType.LogType_Action, performing_player, "Turn Action: %s" % action_name)
	# Spend the cards used to pay the cost.
	if card_ids.size() > 0:
		var card_names = card_db.get_card_name(card_ids[0])
		for i in range(1, card_ids.size()):
			card_names += ", " + card_db.get_card_name(card_ids[0])
		_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "pays for the action by discarding %s." % _log_card_name(card_names))
		performing_player.discard(card_ids)
	if not handle_spend_life_for_force(performing_player, spent_life_for_force):
		return false
	if game_over:
		return true
	performing_player.total_force_spent_this_turn += force_cost

	# Do the character action effects.
	create_event(Enums.EventType.EventType_CharacterAction, performing_player.my_id, 0)
	performing_player.used_character_action = true
	var exceed_detail = "exceed" if performing_player.exceeded else "default"
	performing_player.used_character_action_details.append([exceed_detail, action_idx])
	remaining_character_action_effects = []
	active_character_action = true
	do_effect_if_condition_met(performing_player, -1, action['effect'], null)
	if game_state not in [
			Enums.GameState.GameState_WaitForStrike,
			Enums.GameState.GameState_PlayerDecision,
			Enums.GameState.GameState_Strike_Opponent_Set_First,
			Enums.GameState.GameState_Strike_Opponent_Response
	] and not wait_for_mid_strike_boost():
		check_hand_size_advance_turn(performing_player)
	if game_state != Enums.GameState.GameState_PlayerDecision:
		active_character_action = false
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
	continue_player_action_resolution(performing_player)
	return true

func do_choose_from_topdeck(performing_player : Player, chosen_card_id : int, action : String):
	printlog("SubAction: CHOOSE_FROM_TOPDECK by %s" % [get_player_name(performing_player.my_id)])
	if game_state != Enums.GameState.GameState_PlayerDecision or decision_info.type != Enums.DecisionType.DecisionType_ChooseFromTopDeck:
		printlog("ERROR: Tried to choose from topdeck but not in correct game state.")
		return false

	var destination = decision_info.destination
	var look_amount = decision_info.amount

	var passed = false
	if action == "pass":
		passed = true
		chosen_card_id = -1

	var leftover_card_ids = []
	for i in range(look_amount):
		var id = performing_player.deck[i].id
		if chosen_card_id != id:
			leftover_card_ids.append(id)

	var will_replace_leftovers = false
	if destination == "topdeck":
		will_replace_leftovers = true
	performing_player.draw(look_amount, false, false, not will_replace_leftovers)
	var leftover_card_names = card_db.get_card_names(leftover_card_ids)
	match destination:
		"discard":
			performing_player.discard(leftover_card_ids)
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards the unchosen cards: %s." % _log_card_name(leftover_card_names))
		"topdeck":
			for card_id in leftover_card_ids:
				performing_player.move_card_from_hand_to_deck(card_id)
			if decision_info.effect and decision_info.effect.get("shuffle_after"):
				performing_player.random_shuffle_deck()
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
		continue_resolve_boost()

	# Now the boost is done and we are in the pick action state.
	match action:
		"boost":
			change_game_state(Enums.GameState.GameState_PlayerDecision)
			decision_info.type = Enums.DecisionType.DecisionType_BoostNow
			do_boost(performing_player, chosen_card_id)
			did_strike_or_boost = true
		"strike":
			change_game_state(Enums.GameState.GameState_PickAction)
			do_strike(performing_player, chosen_card_id, false, -1)
			did_strike_or_boost = true
		"add_to_hand":
			# We've already drawn the cards we looked at
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds one of the cards to their hand.")
		"add_to_gauge":
			performing_player.move_card_from_hand_to_gauge(chosen_card_id)
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds one of the cards to gauge: %s." % _log_card_name(card_db.get_card_name(chosen_card_id)))
		"add_to_overdrive":
			performing_player.move_cards_to_overdrive([chosen_card_id], "hand")
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds one of the cards to overdrive: %s." % _log_card_name(card_db.get_card_name(chosen_card_id)))
		"add_to_sealed":
			do_seal_effect(performing_player, chosen_card_id, "hand")
			if performing_player.sealed_area_is_secret:
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds one of the cards to sealed facedown.")
			else:
				_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds one of the cards to sealed: %s." % _log_card_name(card_db.get_card_name(chosen_card_id)))
		"add_to_topdeck_under":
			assert(leftover_card_ids.size() == 1 or leftover_card_ids.size() == 0)
			# If this was the last card in deck, leftover_card_ids.size is 0, so this card goes on top.
			var destination_index = leftover_card_ids.size()
			performing_player.move_card_from_hand_to_deck(chosen_card_id, destination_index)
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds the remaining cards back to the top of their deck.")
		"add_to_topdeck_under_2":
			# The assumption for this ability is that the player returned 2 cards
			# to the top of their deck and this goes under them.
			assert(leftover_card_ids.size() == 2)
			var destination_index = leftover_card_ids.size()
			performing_player.move_card_from_hand_to_deck(chosen_card_id, destination_index)
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "adds the remaining cards back to the top of their deck.")
		"discard":
			performing_player.discard([chosen_card_id])
			_append_log_full(Enums.LogType.LogType_CardInfo, performing_player, "discards one of the cards: %s." % _log_card_name(card_db.get_card_name(chosen_card_id)))
		"pass":
			if not active_strike:
				check_hand_size_advance_turn(performing_player)
		_:
			assert(false, "Unknown action for choose from topdeck.")

	# If it wasn't a "real" action, clean up the boost now
	if action not in real_actions and active_boost:
		active_boost.effects_resolved += 1
		continue_resolve_boost()
	else:
		# If this choose started a strike or boost, don't try to continue the player action resolution.
		if not did_strike_or_boost:
			if not passed:
				if decision_info.bonus_effect:
					handle_strike_effect(decision_info.choice_card_id, decision_info.bonus_effect, performing_player)

			# Came from somewhere else (maybe exceed or character action?)
			continue_player_action_resolution(performing_player)
	return true

func do_quit(player_id : Enums.PlayerId, reason : Enums.GameOverReason):
	printlog("InitialAction: QUIT by %s" % [get_player_name(player_id)])
	var performing_player = _get_player(player_id)
	_append_log_full(Enums.LogType.LogType_Default, performing_player, "left the game.")
	if game_state == Enums.GameState.GameState_GameOver:
		printlog("ERROR: Game already over.")
		return false

	create_event(Enums.EventType.EventType_GameOver, player_id, reason)
	return true

func do_clock_ran_out(player_id : Enums.PlayerId):
	printlog("InitialAction: CLOCK RAN OUT by %s" % [get_player_name(player_id)])
	var performing_player = _get_player(player_id)
	_append_log_full(Enums.LogType.LogType_Default, performing_player, "clock ran out.")
	if game_state == Enums.GameState.GameState_GameOver:
		printlog("ERROR: Game already over.")
		return false

	create_event(Enums.EventType.EventType_GameOver, player_id, Enums.GameOverReason.GameOverReason_ClockRanOut)
	return true

func do_emote(performing_player : Player, is_image_emote : bool, emote : String):
	printlog("Emote by %s: %s" % [get_player_name(performing_player.my_id), emote])
	create_event(Enums.EventType.EventType_Emote, performing_player.my_id, is_image_emote, emote)
	return true

func do_match_result(_player_clock_remaining, _opponent_clock_remaining):
	return true
