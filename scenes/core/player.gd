class_name Player


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
var spaces_forced_moved_this_strike : int
var moved_past_this_strike : bool
var spaces_moved_this_strike : int
var spaces_moved_or_forced_this_strike : int
var sustained_boosts : Array
var sustain_next_boost : bool
var set_starting_face_attack : bool
var starting_face_attack_id : String
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
var once_per_game_resource : int
var once_per_game_resource_name : String

func _init(id, player_name, parent_ref, card_db_ref, chosen_deck, card_start_id):
	my_id = id
	name = player_name
	parent = parent_ref
	card_database = card_db_ref
	hand = []
	deck_def = chosen_deck
	life = Enums.MaxLife
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
		var reference_only = 'reference_only' in deck_card_def and deck_card_def['reference_only']
		var definition_id = ""
		if reference_only:
			definition_id = 'null_reference'
		else:
			definition_id = deck_card_def['definition_id']
		
		var card_def = CardDataManager.get_card(definition_id)
		var image_atlas = deck_def['image_resources'][deck_card_def['image_name']]
		var image_index = deck_card_def['image_index']
		var card = GameCard.new(card_start_id, card_def, id, image_atlas, image_index)
		card_database.add_card(card)
		card.reference_only = reference_only
		if 'set_aside' in deck_card_def and deck_card_def['set_aside']:
			card.set_aside = true
			card.hide_from_reference = 'hide_from_reference' in deck_card_def and deck_card_def['hide_from_reference']
			set_aside_cards.append(card)
		elif 'start_sealed' in deck_card_def and deck_card_def['start_sealed']:
			sealed.append(card)
			parent.create_event(Enums.EventType.EventType_Seal, my_id, card.id, "", false)
		elif !reference_only:
			deck.append(card)
		deck_list.append(card)
		card_start_id += 1
	gauge = []
	continuous_boosts = []
	transforms = []
	lightningrod_zones = []
	for i in range(Enums.MinArenaLocation, Enums.MaxArenaLocation + 1):
		lightningrod_zones.append([])
	underboost_map = {}
	discards = []
	overdrive = []
	sealed_area_is_secret = 'sealed_area_is_secret' in deck_def and deck_def['sealed_area_is_secret']
	has_overdrive = 'exceed_to_overdrive' in deck_def and deck_def['exceed_to_overdrive']
	reshuffle_remaining =Enums. MaxReshuffle
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
	set_starting_face_attack = false
	starting_face_attack_id = ""
	buddy_starting_offset = Enums.BuddyStartsOutOfArena
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
	once_per_game_resource = 1
	once_per_game_resource_name = ""
	if "once_per_game_mechanic" in deck_def:
		once_per_game_resource_name = deck_def['once_per_game_mechanic']

	if "buddy_cards" in deck_def:
		var buddy_index = 0
		for buddy_card in deck_def['buddy_cards']:
			buddy_id_to_index[buddy_card] = buddy_index
			buddy_locations.append(-1)
			buddy_index += 1
	elif 'buddy_card' in deck_def:
		buddy_id_to_index[deck_def['buddy_card']] = 0
		buddy_locations.append(-1)

	movement_limit = Enums.MaxArenaLocation
	if 'movement_limit' in deck_def:
		movement_limit = deck_def['movement_limit']

	movement_limit_optional_exceeded = false
	if 'movement_limit_optional_exceeded' in deck_def:
		movement_limit_optional_exceeded = deck_def['movement_limit_optional_exceeded']

	max_hand_size = Enums.MaxHandSize
	if 'alt_hand_size' in deck_def:
		max_hand_size = deck_def['alt_hand_size']

	starting_hand_size_bonus = 0
	if 'bonus_starting_hand' in deck_def:
		starting_hand_size_bonus = deck_def['bonus_starting_hand']

	draw_at_end_of_turn = true
	if 'disable_end_of_turn_draw' in deck_def:
		draw_at_end_of_turn = not deck_def['disable_end_of_turn_draw']


	if 'set_starting_face_attack' in deck_def:
		set_starting_face_attack = deck_def['set_starting_face_attack']
		if 'starting_face_attack_id' in deck_def:
			starting_face_attack_id = deck_def['starting_face_attack_id']

	if 'buddy_starting_offset' in deck_def:
		buddy_starting_offset = deck_def['buddy_starting_offset']
		if 'buddy_starting_id' in deck_def:
			buddy_starting_id = deck_def['buddy_starting_id']

	if 'guile_change_cards_bonus' in deck_def:
		guile_change_cards_bonus = deck_def['guile_change_cards_bonus']

	if 'delayed_wild_strike' in deck_def:
		delayed_wild_strike = deck_def['delayed_wild_strike']

func initial_shuffle():
	if Enums.ShuffleEnabled:
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
					if arena_location == Enums.CenterArenaLocation:
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
		if ability_effect['timing'] == "set_strike" and ability_effect['effect_type'] == StrikeEffects.AddAttackEffect:
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
		if exceed_ability_effect['timing'] == "set_strike" and exceed_ability_effect['effect_type'] == StrikeEffects.AddAttackEffect:
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
	if Enums.ShuffleEnabled:
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
	for i in range(Enums.MinArenaLocation, Enums.MaxArenaLocation + 1):
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
				var force_cost = parent.get_force_cost(self, card)
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
	return arena_location - extra_width == Enums.MinArenaLocation or arena_location + extra_width == Enums.MaxArenaLocation

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
	for location in range(Enums.MinArenaLocation, Enums.MaxArenaLocation + 1):
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
			if effect['effect_type'] == StrikeEffects.AttackIsEx:
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

	if 'requires_once_per_game_resource' in action and action['requires_once_per_game_resource']:
		if once_per_game_resource <= 0: return false

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
	if (new_arena_location - extra_width < Enums.MinArenaLocation) or (new_arena_location + extra_width > Enums.MaxArenaLocation): return false

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
		else:
			spaces_forced_moved_this_strike += spaces_moved

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
				var test_location = clamp(target_location + direction, Enums.MinArenaLocation + extra_width, Enums.MaxArenaLocation - extra_width)
				var no_open_space = false
				while is_overlapping_opponent(test_location):
					var updated_test_location = clamp(test_location + direction, Enums.MinArenaLocation + extra_width, Enums.MaxArenaLocation - extra_width)
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

		var updated_new_location = clamp(target_location, Enums.MinArenaLocation + extra_width, Enums.MaxArenaLocation - extra_width)
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
		move_in_direction_by_amount(false, amount, true, -1, StrikeEffects.Close)
	else:
		move_in_direction_by_amount(true, amount, true, -1, StrikeEffects.Close)

func advance(amount, stop_on_space):
	if not (exceeded and movement_limit_optional_exceeded):
		amount = min(amount, movement_limit)
	var other_location = parent._get_player(parent.get_other_player(my_id)).arena_location
	if arena_location < other_location:
		move_in_direction_by_amount(false, amount, false, stop_on_space, StrikeEffects.Advance)
	else:
		move_in_direction_by_amount(true, amount, false, stop_on_space, StrikeEffects.Advance)

func retreat(amount):
	if not (exceeded and movement_limit_optional_exceeded):
		amount = min(amount, movement_limit)
	var other_location = parent._get_player(parent.get_other_player(my_id)).arena_location
	if arena_location < other_location:
		move_in_direction_by_amount(true, amount, false, -1, StrikeEffects.Retreat)
	else:
		move_in_direction_by_amount(false, amount, false, -1, StrikeEffects.Retreat)

func push(amount, set_x_to_buddy_spaces_entered : bool = false):
	var other_player = parent._get_player(parent.get_other_player(my_id))
	var other_location = other_player.arena_location
	if arena_location < other_location:
		other_player.move_in_direction_by_amount(false, amount, false, -1, StrikeEffects.Push, false, 0, set_x_to_buddy_spaces_entered)
	else:
		other_player.move_in_direction_by_amount(true, amount, false, -1, StrikeEffects.Push, false, 0, set_x_to_buddy_spaces_entered)

func pull(amount):
	var other_player = parent._get_player(parent.get_other_player(my_id))
	var other_location = other_player.arena_location
	if arena_location < other_location:
		other_player.move_in_direction_by_amount(true, amount, false, -1, StrikeEffects.Pull, false)
	else:
		other_player. move_in_direction_by_amount(false, amount, false, -1, StrikeEffects.Pull, false)

func pull_not_past(amount):
	var other_player = parent._get_player(parent.get_other_player(my_id))
	var other_location = other_player.arena_location
	if arena_location < other_location:
		other_player.move_in_direction_by_amount(true, amount, true, -1, StrikeEffects.Pull, false)
	else:
		other_player.move_in_direction_by_amount(false, amount, true, -1, StrikeEffects.Pull, false)

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
					StrikeEffects.Rangeup:
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
					StrikeEffects.Rangeup:
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
					StrikeEffects.RangeupBothPlayers:
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
				StrikeEffects.IgnorePushAndPullPassiveBonus:
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
				StrikeEffects.AttackIsEx:
					strike_stat_boosts.set_ex()
				StrikeEffects.DodgeAtRange:
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
				StrikeEffects.Powerup:
					add_power_bonus(effect['amount'])
				StrikeEffects.PowerupBothPlayers:
					add_power_bonus(effect['amount'])
					opposing_player.add_power_bonus(effect['amount'])
				StrikeEffects.Speedup:
					strike_stat_boosts.speed += effect['amount']
				StrikeEffects.Armorup:
					strike_stat_boosts.armor += effect['amount']
				StrikeEffects.Guardup:
					strike_stat_boosts.guard += effect['amount']
				StrikeEffects.Rangeup:
					var target_player = self
					if effect.get("opponent"):
						target_player = opposing_player
					var special_only = effect.get("special_only", false)
					target_player.add_range_bonus(effect['amount'], effect['amount2'], special_only)
				StrikeEffects.RangeupBothPlayers:
					add_range_bonus(effect['amount'], effect['amount2'], false)
					opposing_player.add_range_bonus(effect['amount'], effect['amount2'], false)

func disable_boost_effects(card : GameCard, buddy_ignore_condition : bool = false, being_discarded : bool = true):
	# Undo timing effects and passive bonuses.
	var current_timing = parent.get_current_strike_timing()
	for effect in card.definition['boost']['effects']:
		if effect['timing'] == "now":
			match effect['effect_type']:
				StrikeEffects.IgnorePushAndPullPassiveBonus:
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
		StrikeEffects.AttackIsEx:
			strike_stat_boosts.remove_ex()
		StrikeEffects.DodgeAtRange:
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
		StrikeEffects.Powerup:
			remove_power_bonus(effect['amount'])
		StrikeEffects.PowerupBothPlayers:
			remove_power_bonus(effect['amount'])
			opposing_player.remove_power_bonus(effect['amount'])
		StrikeEffects.Speedup:
			strike_stat_boosts.speed -= effect['amount']
		StrikeEffects.Armorup:
			strike_stat_boosts.armor -= effect['amount']
		StrikeEffects.Guardup:
			strike_stat_boosts.guard -= effect['amount']
		StrikeEffects.Rangeup:
			var target_player = self
			if effect.get("opponent"):
				target_player = opposing_player
			var special_only = effect.get("special_only", false)
			target_player.remove_range_bonus(effect['amount'], effect['amount2'], special_only)
		StrikeEffects.RangeupBothPlayers:
			remove_range_bonus(effect['amount'], effect['amount2'], false)
			opposing_player.remove_range_bonus(effect['amount'], effect['amount2'], false)
		StrikeEffects.RangeupIfExModifier:
			strike_stat_boosts.rangeup_min_if_ex_modifier -= effect['amount']
			strike_stat_boosts.rangeup_max_if_ex_modifier -= effect['amount2']
		StrikeEffects.GuardupPerTwoCardsInHand:
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
			elif destination == StrikeEffects.Strike:
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
				StrikeEffects.AddPassive:
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
					"effect_type": StrikeEffects.Choice,
					StrikeEffects.Choice: [
						{
							"effect_type": StrikeEffects.LightningrodStrike,
							"card_name": card_name,
							"card_id": card.id,
							"location": location,
						},
						{ "effect_type": StrikeEffects.Pass }
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
