extends Node

var card_data = []

var card_definitions_path = "res://data/card_definitions.json"
var decks_path = "res://data/decks"
var decks = []

func get_deck_test_deck():
	for deck in decks:
		if deck['id'] == "millia":
			return deck
	return get_random_deck(-1)

func get_random_deck(season : int):
	# Randomize
	if season == -1:
		var random_index = randi() % len(decks)
		return decks[random_index]
	else:
		var season_decks = []
		for deck in decks:
			if deck['season'] == season:
				season_decks.append(deck)
		var random_index = randi() % len(season_decks)
		return season_decks[random_index]


func get_deck_from_str_id(str_id : String):
	if str_id == "random_s7":
		return get_random_deck(7)
	if str_id == "random_s6":
		return get_random_deck(6)
	if str_id == "random_s5":
		return get_random_deck(5)
	if str_id == "random_s4":
		return get_random_deck(4)
	if str_id == "random_s3":
		return get_random_deck(3)
	if str_id == "random":
		return get_random_deck(-1)
	for deck in decks:
		if deck['id'] == str_id:
			return deck

func load_json_file(file_path : String):
	if FileAccess.file_exists(file_path):
		var data = FileAccess.open(file_path, FileAccess.READ)
		var json = JSON.parse_string(data.get_as_text())
		return json
	else:
		print("Card definitions file doesn't exist")

# Called when the node enters the scene tree for the first time.
func _ready():
	card_data = load_json_file(card_definitions_path)
	var deck_files = DirAccess.get_files_at(decks_path)
	for deck_file in deck_files:
		if deck_file[0] == "_":
			continue
		var deck_data = load_json_file(decks_path + "/" + deck_file)
		if deck_data:
			decks.append(deck_data)

func get_card(definition_id):
	for card in card_data:
		if card['id'] == definition_id:
			return card
	assert(false, "Missing card definition: " + definition_id)
	return null

class EffectSummary:
	var effect
	var min_value = null
	var max_value = null

func get_choice_summary(choice, card_name_source : String):
	var summary_text = ""
	var effect_summaries = []
	for effect in choice:
		var current_summary = null
		for effect_summary in effect_summaries:
			if effect_summary.effect['effect_type'] == effect['effect_type']:
				current_summary = effect_summary
				break
		if not current_summary:
			current_summary = EffectSummary.new()
			current_summary.effect = effect
			effect_summaries.append(current_summary)

		if 'amount' in effect and not 'UI_skip_summary' in effect:
			if current_summary.min_value == null:
				current_summary.min_value = effect['amount']
				current_summary.max_value = effect['amount']
			else:
				if effect['amount'] < current_summary.min_value:
					current_summary.min_value = effect['amount']
				if effect['amount'] > current_summary.max_value:
					current_summary.max_value = effect['amount']


	for i in range(len(effect_summaries)):
		var effect_summary = effect_summaries[i]
		if i > 0:
			summary_text += " or "
		if effect_summary.min_value != null:
			if effect_summary.min_value == effect_summary.max_value:
				summary_text += get_effect_type_heading(effect_summary.effect) + str(effect_summary.min_value)
			else:
				summary_text += get_effect_type_heading(effect_summary.effect) + str(effect_summary.min_value) + "-" + str(effect_summary.max_value)
		else:
			# No amount, so just use the full effect text
			summary_text += get_effect_type_text(effect_summary.effect, card_name_source)
		if 'bonus_effect' in effect_summary.effect:
			summary_text += "; " + get_effect_text(effect_summary.effect['bonus_effect'], false, false, false, card_name_source)
	return summary_text

func get_force_for_effect_summary(effect, card_name_source : String) -> String:
	var effect_str = ""
	var force_limit = effect['force_max']
	if "per_force_effect" in effect and effect['per_force_effect'] != null:
		effect_str += "Spend up to %s force. For each, %s" % [str(force_limit), get_effect_text(effect['per_force_effect'], false, true, true, card_name_source)]
	elif 'overall_effect' in effect and effect['overall_effect'] != null:
		effect_str += "You may spend %s force to %s" % [str(force_limit), get_effect_text(effect['overall_effect'], false, true, true, card_name_source)]
	return effect_str

func get_gauge_for_effect_summary(effect, card_name_source : String) -> String:
	var effect_str = ""
	var to_hand = 'spent_cards_to_hand' in effect and effect['spent_cards_to_hand']
	var gauge_limit = effect['gauge_max']
	if "per_gauge_effect" in effect and effect['per_gauge_effect'] != null:
		if to_hand:
			effect_str += "Return up to %s gauge to your hand. For each, %s" % [str(gauge_limit), get_effect_text(effect['per_gauge_effect'], false, true, true, card_name_source)]
		else:
			effect_str += "Spend up to %s gauge. For each, %s" % [str(gauge_limit), get_effect_text(effect['per_gauge_effect'], false, true, true, card_name_source)]
	elif 'overall_effect' in effect and effect['overall_effect'] != null:
		if to_hand:
			effect_str += "You may return %s gauge to your hand to %s" % [str(gauge_limit), get_effect_text(effect['overall_effect'], false, true, true, card_name_source)]
		else:
			effect_str += "You may spend %s gauge to %s" % [str(gauge_limit), get_effect_text(effect['overall_effect'], false, true, true, card_name_source)]
	return effect_str

func get_timing_text(timing):
	var text = ""
	match timing:
		"action":
			text += "[b]Action:[/b] "
		"after":
			text += "[b]After:[/b] "
		"both_players_after":
			text += "[b]Both players after:[/b] "
		"both_players_before":
			text += "[b]Both players before:[/b] "
		"before":
			text += "[b]Before:[/b] "
		"cleanup":
			text += "[b]Cleanup:[/b] "
		"discarded":
			text += ""
		"during_strike":
			text += ""
		"end_of_turn":
			text += "At end of your turn: "
		"hit":
			text += "[b]Hit:[/b] "
		"immediate":
			text += ""
		"now":
			text += "[b]Now:[/b] "
		"on_advance_or_close":
			text += "When you advance or close, "
		"on_cancel":
			text += "When you cancel, "
		"on_initiate_strike":
			text += "When you initiate a strike, "
		"on_reveal":
			text += ""
		"start_of_next_turn":
			text += "At start of next turn: "
		"set_strike":
			text += "When you set a strike, "
		"when_hit":
			text += "When hit, "
		_:
			text += "MISSING TIMING"
	return text

func get_condition_text(effect, amount, amount2, detail):
	var condition = effect['condition']
	var text = ""
	match condition:
		"advanced_through":
			text += "If advanced past opponent, "
		"not_advanced_through_buddy":
			text += "If didn't advance through %s, " % detail
		"at_edge_of_arena":
			text += "If at arena edge, "
		"boost_in_play":
			text += "If a boost is in play, "
		"canceled_this_turn":
			text += "If canceled this turn, "
		"initiated_strike":
			text += "If initiated strike, "
		"hit_opponent":
			text += "If hit opponent, "
		"last_turn_was_strike":
			text += "If last turn was a strike, "
		"not_last_turn_was_strike":
			text += "If last turn was not a strike, "
		"life_equals":
			text += "If your life is exactly %s, " % amount
		"not_canceled_this_turn":
			text += "If not canceled this turn, "
		"not_full_push":
			text += "If not full push, "
		"pushed_min_spaces":
			text += "If pushed %s or more spaces, " % amount
		"not_full_close":
			text += "If not full close, "
		"not_initiated_strike":
			text += "If opponent initiated strike, "
		"not_moved_self_this_strike":
			text += "If you have not moved yourself this strike, "
		"no_strike_caused":
			text += "If no strike caused, "
		"stunned":
			text += "If stunned, "
		"not_stunned":
			text += "If not stunned, "
		"opponent_stunned":
			text += "If opponent stunned, "
		"pulled_past":
			text += "If pulled opponent past you, "
		"used_character_action":
			text += ""
		"used_character_bonus":
			text += ""
		"range":
			text += "If the opponent is at range %s, " % amount
		"range_greater_or_equal":
			text += "If the opponent is at range %s+, " % amount
		"range_multiple":
			text += "If the opponent is at range %s-%s, " % [amount, amount2]
		"is_special_attack":
			text += ""
		"is_normal_attack":
			text += ""
		"top_deck_is_normal_attack":
			text += "If the top card of your deck is a normal, "
		"is_buddy_special_or_ultra_attack":
			text += ""
		"buddy_in_opponent_space":
			text += "If %s is in opponent's space, " % detail
		"buddy_in_play":
			text += "If %s is in play, " % detail
		"buddy_space_unoccupied":
			text += "If %s's space is unoccupied, " % detail
		"on_buddy_space":
			text += "If on %s's space, " % detail
		"buddy_between_attack_source":
			text += "If %s is between you and attack source, " % detail
		"buddy_between_opponent":
			text += "If %s is between you and opponent, " % detail
		"more_cards_than_opponent":
			text += "If you have more cards in hand than opponent, "
		"opponent_at_edge_of_arena":
			text += "If opponent at arena edge, "
		"opponent_between_buddy":
			if 'include_buddy_space' in effect and effect['include_buddy_space']:
				text += "If opponent is on %s or between you, " % detail
			else:
				text += "If opponent is between you and %s, " % detail
		"is_buddy_special_attack":
			text += ""
		"was_wild_swing":
			text += "If this was a wild swing, "
		"was_strike_from_gauge":
			text += "If set from gauge, "
		"was_hit":
			text += "If you were hit, "
		"matches_named_card":
			text += "If your next attack is %s, " % detail
		"is_critical":
			text += "Crit: "
		"no_sealed_copy_of_attack":
			text += "If there is no sealed copy of your attack, "
		_:
			text += "MISSING CONDITION"
	return text

func get_effect_type_heading(effect):
	var effect_str = ""
	var effect_type = effect['effect_type']
	match effect_type:
		"advance":
			effect_str += "Advance "
		"close":
			effect_str += "Close "
		"draw":
			effect_str += "Draw "
		"pass":
			effect_str += ""
		"pull":
			effect_str += "Pull "
		"pull_not_past":
			effect_str += "Pull without pulling past "
		"push":
			effect_str += "Push "
		"retreat":
			effect_str += "Retreat "
		_:
			effect_str += "MISSING EFFECT HEADING"
	return effect_str

func get_effect_type_text(effect, card_name_source : String = ""):
	var effect_str = ""
	var effect_type = effect['effect_type']
	match effect_type:
		"add_boost_to_gauge_on_strike_cleanup":
			if card_name_source:
				effect_str += "Add %s to gauge" % card_name_source
			else:
				effect_str += "Add card to gauge"
		"add_hand_to_gauge":
			effect_str += "Add your hand to your gauge"
		"add_strike_to_gauge_after_cleanup":
			effect_str += "Add card to gauge after strike."
		"add_to_gauge_boost_play_cleanup":
			effect_str += "Add card to gauge"
		"add_to_gauge_immediately":
			effect_str += "Add card to gauge"
		"add_to_gauge_immediately_mid_strike_undo_effects":
			effect_str += "Add card to gauge (and cancel its effects)."
		"add_top_deck_to_gauge":
			effect_str += "Add top card of deck to gauge"
		"add_top_discard_to_gauge":
			effect_str += "Add top card of discard pile to gauge"
		"advance":
			effect_str += "Advance "
			if str(effect['amount']) == "strike_x":
				effect_str += "X"
			else:
				effect_str += str(effect['amount'])
		"advance_INTERNAL":
			effect_str += "Advance "
			if str(effect['amount']) == "strike_x":
				effect_str += "X"
			else:
				effect_str += str(effect['amount'])
		"armorup":
			effect_str += "+" + str(effect['amount']) + " Armor"
		"armorup_damage_dealt":
			effect_str += "+ Armor per damage dealt"
		"attack_does_not_hit":
			effect_str += "Attack does not hit."
		"attack_is_ex":
			effect_str += "Next Strike is EX"
		"block_opponent_move":
			effect_str += "Opponent cannot move"
		"remove_block_opponent_move":
			effect_str += ""
		"bonus_action":
			effect_str += "Take another action"
		"boost_this_then_sustain":
			if card_name_source:
				effect_str += "Boost and sustain %s" % card_name_source
			else:
				effect_str += "Boost and sustain this"
		"boost_then_sustain":
			var limitation_str = "boost"
			if effect['limitation']:
				limitation_str = effect['limitation'] + " boost"
			if effect['allow_gauge']:
				effect_str += "Play and sustain a %s from hand or gauge." % limitation_str
			else:
				effect_str += "Play and sustain a %s from hand." % limitation_str
		"boost_then_sustain_topdeck":
			effect_str += "Play and sustain %s card(s) from the top of your deck." % effect['amount']
		"boost_then_sustain_topdiscard":
			var limitation_str = "card(s)"
			if 'limitation' in effect and effect['limitation'] == "continuous":
				limitation_str = "continuous boost(s)"
			effect_str += "Play and sustain the top %s %s from your discard pile." % [effect['amount'], limitation_str]
		"cannot_stun":
			effect_str += "Attack does not stun."
		"choice":
			if 'special_choice_name' in effect:
				effect_str += effect['special_choice_name']
			else:
				effect_str += "Choose: " + get_choice_summary(effect['choice'], card_name_source)
		"choose_discard":
			var source = "discard"
			if 'source' in effect:
				source = effect['source']
			if effect['limitation']:
				effect_str += "Choose a %s card from %s to move to %s" % [effect['limitation'], source, effect['destination']]
			else:
				effect_str += "Choose a card from %s to move to %s" % [source, effect['destination']]
		"choose_sustain_boost":
			effect_str += "Choose a boost to sustain."
		"close":
			effect_str += "Close " + str(effect['amount'])
		"close_INTERNAL":
			effect_str += "Close " + str(effect['amount'])
		"copy_other_hit_effect":
			effect_str += "Copy another Hit effect"
		"critical":
			effect_str += "Critical Strike"
		"discard_this":
			effect_str += "Discard this"
		"discard_strike_after_cleanup":
			effect_str += "Discard attack on cleanup"
		"discard_continuous_boost":
			if 'limitation' in effect and effect['limitation'] == 'mine' and 'overall_effect' in effect:
				effect_str += "You may discard one of your continuous boosts for %s" % [get_effect_text(effect['overall_effect'])]
			else:
				effect_str += "Discard a continuous boost"
		"discard_opponent_gauge":
			effect_str += "Discard a card from opponent's gauge."
		"discard_opponent_topdeck":
			effect_str += "Discard a card from the top of the opponent's deck"
		"discard_topdeck":
			if 'card_name' in effect:
				effect_str += "Discard %s from the top of your deck" % effect['card_name']
			else:
				effect_str += "Discard a card from the top of your deck"
		"discard_random_and_add_triggers":
			effect_str += "Discard a random card; add before/hit/after triggers to attack"
		"dodge_at_range":
			var buddy_string = ""
			if 'from_buddy' in effect and effect['from_buddy']:
				buddy_string = " from %s" % effect['buddy_name']
			if effect['range_min'] == effect['range_max']:
				effect_str += "Opponent attacks miss at range %s%s." % [effect['range_min'], buddy_string]
			else:
				effect_str += "Opponent attacks miss at range %s-%s%s." % [effect['range_min'], effect['range_max'], buddy_string]
		"dodge_attacks":
			effect_str += "Opponent misses."
		"dodge_from_opposite_buddy":
			effect_str += "Opponents on other side of %s miss." % effect['buddy_name']
		"do_not_remove_buddy":
			effect_str += "Do not remove %s from play." % effect['buddy_name']
		"remove_buddy":
			effect_str += "Remove %s from play" % effect['buddy_name']
		"place_buddy_in_any_space":
			effect_str += "Place %s in any space." % effect['buddy_name']
		"place_buddy_in_attack_range":
			effect_str += "Place %s in the attack's range." % effect['buddy_name']
		"calculate_range_from_buddy":
			effect_str += "Calculate range from %s." % effect['buddy_name']
		"draw":
			if 'opponent' in effect and effect['opponent']:
				effect_str += "Opponent Draw " + str(effect['amount'])
			else:
				effect_str += "Draw " + str(effect['amount'])
		"draw_to":
			effect_str += "Draw until you have %s cards in hand" % str(effect['amount'])
		"exceed_now":
			effect_str += "Exceed"
		"extra_trigger_resolutions":
			effect_str += "Before/Hit/After triggers resolve %s extra time(s)" % effect['amount']
		"flip_buddy_miss_get_gauge":
			effect_str += effect['description']
		"force_costs_reduced_passive":
			effect_str += "Force costs reduced by %s" % effect['amount']
		"force_for_effect":
			effect_str += get_force_for_effect_summary(effect, card_name_source)
		"gauge_for_effect":
			effect_str += get_gauge_for_effect_summary(effect, card_name_source)
		"gain_advantage":
			effect_str += "Gain Advantage"
		"gain_life":
			effect_str += "Gain " + str(effect['amount']) + " life"
		"gauge_from_hand":
			effect_str += "Add a card from hand to gauge"
		"guardup":
			if effect['amount'] > 0:
				effect_str += "+"
			effect_str += str(effect['amount']) + " Guard"
		"ignore_armor":
			effect_str += "Ignore armor"
		"ignore_guard":
			effect_str += "Ignore guard"
		"ignore_push_and_pull":
			effect_str += "Ignore Push and Pull"
		"ignore_push_and_pull_passive_bonus":
			effect_str += "Ignore Push and Pull"
		"increase_force_spent_before_strike":
			effect_str += get_effect_text(effect['linked_effect'], false, false, false)
		"remove_ignore_push_and_pull_passive_bonus":
			effect_str += ""
		"lose_all_armor":
			effect_str += "Lose all armor"
		"name_card_opponent_discards":
			effect_str += "Name a card. Opponent discards it or reveals not in hand."
		"may_advance_bonus_spaces":
			effect_str = "You may Advance/Close %s extra space(s)" % effect['amount']
		"move_buddy":
			var strike_str = ""
			if 'strike_after' in effect and effect['strike_after']:
				strike_str = " and strike"
			var movement_str = "%s" % effect['amount']
			if effect['amount'] != effect['amount2']:
				movement_str += "-%s" % effect['amount2']
			effect_str += "Move %s %s space(s)%s" % [effect['buddy_name'], movement_str, strike_str]
		"move_to_buddy":
			effect_str += "Move to %s" % effect['buddy_name']
		"multiply_power_bonuses":
			if effect['amount'] == 2:
				effect_str += "Double power bonuses"
			else:
				effect_str += "Multiply power bonuses by %s" % effect['amount']
		"nothing":
			effect_str += ""
		"opponent_cant_move_past":
			effect_str += "Opponent cannot Advance past you"
		"remove_opponent_cant_move_past":
			effect_str += ""
		"opponent_discard_choose":
			effect_str += "Opponent discards " + str(effect['amount']) + " cards."
		"opponent_discard_random":
			effect_str += "Opponent discards " + str(effect['amount']) + " random cards."
		"opponent_wild_swings":
			effect_str += "Opponent wild swings."
		"pass":
			effect_str += "Pass"
		"place_buddy_at_range":
			if effect['range_min'] == effect['range_max']:
				effect_str += "Place %s at range %s" % [effect['buddy_name'], effect['range_min']]
			else:
				effect_str += "Place %s at range %s-%s" % [effect['buddy_name'], effect['range_min'], effect['range_max']]
		"place_buddy_onto_self":
			effect_str += "Place %s onto your space" % effect['buddy_name']
		"powerup":
			if str(effect['amount']) == "strike_x":
				effect_str += "+X"
			else:
				if effect['amount'] > 0:
					effect_str += "+"
				effect_str += str(effect['amount'])
			effect_str += " Power"
		"powerup_per_boost_in_play":
			effect_str += "+" + str(effect['amount']) + " Power per boost in play."
		"powerup_per_sealed_normal":
			var max_text = ""
			if 'maximum' in effect:
				max_text = " (max %s)" % effect['maximum']
			effect_str += "+" + str(effect['amount']) + " Power per sealed normal%s." % max_text
		"powerup_damagetaken":
			effect_str += "+" + str(effect['amount']) + " Power per damage taken this strike."
		"powerup_opponent":
			effect_str += "+" + str(effect['amount']) + " Opponent's Power"
		"pull":
			effect_str += "Pull " + str(effect['amount'])
		"push":
			effect_str += "Push " + str(effect['amount'])
		"push_from_source":
			effect_str += "Push " + str(effect['amount']) + " from attack source"
		"push_to_attack_max_range":
			effect_str += "Push to attack's max range"
		"rangeup":
			if effect['amount'] >= 0:
				effect_str += "+"
			effect_str += str(effect['amount']) + " - "
			if effect['amount2'] >= 0:
				effect_str += "+"
			effect_str += str(effect['amount2']) + " Range"
		"rangeup_per_boost_in_play":
			if 'all_boosts' in effect and effect['all_boosts']:
				effect_str += "+" + str(effect['amount']) + "-" + str(effect['amount2']) + " Range per EVERY boost in play."
			else:
				effect_str += "+" + str(effect['amount']) + "-" + str(effect['amount2']) + " Range per boost in play."
		"rangeup_per_sealed_normal":
			effect_str += "+" + str(effect['amount']) + "-" + str(effect['amount2']) + " Range per sealed normal."
		"repeat_effect_optionally":
			effect_str += get_effect_text(effect['linked_effect'], false, false, false)
			var repeats = str(effect['amount'])
			if repeats != '0':
				if repeats == "every_two_sealed_normals":
					repeats = "once for every 2 sealed normals"
				else:
					repeats += " time(s)"
				effect_str += "; you may repeat this %s." % repeats
		"retreat":
			effect_str += "Retreat "
			if str(effect['amount']) == "strike_x":
				effect_str += "X"
			else:
				effect_str += str(effect['amount'])
		"return_attack_to_hand":
			effect_str += "Return the attack to your hand"
		"return_attack_to_top_of_deck":
			effect_str += "Return the attack to the top of your deck"
		"return_this_attack_to_hand_after_attack":
			if 'card_name' in effect:
				effect_str += "Return %s to hand" % effect['card_name']
			else:
				effect_str += "Return this to hand"
		"return_this_boost_to_hand_strike_effect":
			if 'card_name' in effect:
				effect_str += "Return %s to hand" % effect['card_name']
			else:
				effect_str += "Return this to hand"
		"return_this_to_hand_immediate_boost":
			if 'card_name' in effect:
				effect_str += "Return %s to hand" % effect['card_name']
			else:
				effect_str += "Return this to hand"
		"return_all_cards_gauge_to_hand":
			effect_str += "Return all cards in gauge to hand."
		"reveal_copy_for_advantage":
			effect_str += "Reveal a copy of this attack to Gain Advantage"
		"reveal_hand":
			if 'opponent' in effect and effect['opponent']:
				effect_str += "Reveal opponent hand"
			else:
				effect_str += "Reveal your hand"
		"reveal_strike":
			effect_str += "Initiate face-up"
		"save_power":
			effect_str += "Your printed power becomes its Power"
		"use_saved_power_as_printed_power":
			effect_str += "Your printed power is the revealed card's power"
		"set_strike_x":
			effect_str += "Set X to "
			match effect['source']:
				'random_gauge_power':
					effect_str += "power of random gauge card"
				'top_discard_power':
					effect_str += "power of top card of discards"
				'opponent_speed':
					effect_str += "opponent's speed"
				'force_spent_before_strike':
					effect_str += "force spent before strike"
				_:
					effect_str += "(UNKNOWN)"
		"seal_attack_on_cleanup":
			effect_str += "Seal your attack on cleanup"
		"seal_this":
			if card_name_source:
				effect_str += "Seal %s" % card_name_source
			else:
				effect_str += "Seal this"
		"self_discard_choose":
			var destination = effect['destination'] if 'destination' in effect else "discard"
			var limitation = ""
			if 'limitation' in effect:
				limitation = " " + effect['limitation']
			var bonus = ""
			var optional = 'optional' in effect and effect['optional']
			var optional_text = ""
			if optional:
				optional_text = "You may: "
			if 'discard_effect' in effect:
				bonus= "\nfor: " + get_effect_text(effect['discard_effect'], false, false, false)
			if destination == "sealed":
				effect_str += optional_text + "Seal " + str(effect['amount']) + limitation + " card(s)" + bonus
			elif destination == "reveal":
				effect_str += optional_text + "Reveal " + str(effect['amount']) + limitation + " card(s)" + bonus
			else:
				effect_str += optional_text + "Discard " + str(effect['amount']) + limitation + " card(s)" + bonus
		"set_used_character_bonus":
			effect_str += ": " + get_effect_text(effect['linked_effect'], false, false, false)
		"shuffle_hand_to_deck":
			effect_str += "Shuffle hand into deck"
		"shuffle_sealed_to_deck":
			effect_str += "Shuffle sealed cards into deck"
		"sidestep_dialogue":
			effect_str += "Named card will not hit this strike"
		"speedup":
			if effect['amount'] > 0:
				effect_str += "+"
			#else: str() converts it to - already.
				#effect_str += "-"
			effect_str += str(effect['amount']) + " Speed"
		"speedup_per_boost_in_play":
			if 'all_boosts' in effect and effect['all_boosts']:
				effect_str += "+" + str(effect['amount']) + " Speed per EVERY boost in play."
			else:
				effect_str += "+" + str(effect['amount']) + " Speed per boost in play."
		"spend_life":
			effect_str += "Spend " + str(effect['amount']) + " life"
		"strike":
			effect_str += "Strike"
		"strike_wild":
			effect_str += "Wild swing"
		"strike_faceup":
			effect_str += "Strike face-up"
		"strike_opponent_sets_first":
			effect_str += "Strike (opponent sets first)"
		"strike_random_from_gauge":
			effect_str += "Strike with random card from gauge (opponent sets first)"
		"strike_response_reading":
			if 'ex_card_id' in effect:
				effect_str += "EX Strike"
			else:
				effect_str += "Strike"
		"stun_immunity":
			effect_str += "Stun Immunity"
		"sustain_this":
			if card_name_source:
				effect_str += "Sustain %s" % card_name_source
			else:
				effect_str += "Sustain this"
		"swap_buddy":
			effect_str += effect['description']
		"take_bonus_actions":
			if 'use_simple_description' in effect and effect['use_simple_description']:
				effect_str += "Take another action."
			else:
				var amount = effect['amount']
				effect_str += "Take %s actions. Cannot cancel and striking ends turn." % str(amount)
		"take_nonlethal_damage":
			effect_str += "Take %s nonlethal damage" % str(effect['amount'])
		"topdeck_from_hand":
			effect_str += "Put a card from your hand on top of your deck"
		"when_hit_force_for_armor":
			effect_str += "When hit, generate force for " + str(effect['amount']) + " armor each."
		_:
			effect_str += "MISSING EFFECT"
	return effect_str

func get_effect_text(effect, short = false, skip_timing = false, skip_condition = false, card_name_source : String = ""):
	if not card_name_source:
		if 'card_name' in effect:
			card_name_source = effect['card_name']
	var effect_str = ""
	if 'timing' in effect and not skip_timing:
		effect_str += get_timing_text(effect['timing'])

	var silent_effect = false
	if 'silent_effect' in effect and effect['silent_effect']:
		silent_effect = true
	if not silent_effect:
		if 'condition' in effect and not skip_condition:
			var amount = 0
			var amount2 = 0
			var detail = ""
			if 'condition_amount' in effect:
				amount = effect['condition_amount']
			if 'condition_amount_min' in effect:
				amount = effect['condition_amount_min']
			if 'condition_amount_max' in effect:
				amount2 = effect['condition_amount_max']
			if 'condition_amount2' in effect:
				amount2 = effect['condition_amount2']
			if 'condition_detail' in effect:
				detail = effect['condition_detail']
			effect_str += get_condition_text(effect, amount, amount2, detail)

		effect_str += get_effect_type_text(effect, card_name_source)

	if not short and 'bonus_effect' in effect:
		effect_str += "; " + get_effect_text(effect['bonus_effect'], skip_timing, false, card_name_source)
	if 'and' in effect:
		if not 'suppress_and_description' in effect or not effect['suppress_and_description']:
			if effect_str != "":
				effect_str += ", "
			effect_str += get_effect_text(effect['and'], short, skip_timing, false, card_name_source)
	if 'negative_condition_effect' in effect:
		effect_str += ", otherwise " + get_effect_text(effect['negative_condition_effect'], short, skip_timing, false, card_name_source)
	return effect_str

func get_effects_text(effects):
	var effects_str = ""
	for effect in effects:
		var effect_text = get_effect_text(effect)
		if effect_text:
			effects_str += effect_text + "\n"
	return effects_str

func get_on_exceed_text(on_exceed_ability):
	if not on_exceed_ability:
		return ""
	var effect_type = on_exceed_ability['effect_type']
	match effect_type:
		"strike":
			return "When you Exceed: Strike\n"
		"draw":
			return "When you Exceed: Draw %s" % on_exceed_ability['amount'] + "\n"
		_:
			return "MISSING_EXCEED_EFFECT\n"

func get_boost_text(effects):
	return get_effects_text(effects)
