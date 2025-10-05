extends Node

const CardHighlightColor = "#7DF9FF" # Light blue

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
		if effect_summary.min_value != null and effect_summary.effect['effect_type'] not in [StrikeEffects.SpendLife, StrikeEffects.MoveRandomCards]:
			if effect_summary.min_value == effect_summary.max_value:
				if str(effect_summary.min_value) == "strike_x":
					effect_summary.min_value = "X"
				elif str(effect_summary.min_value) == "TOTAL_POWER":
					effect_summary.min_value = "your Total Power"
				summary_text += get_effect_type_heading(effect_summary.effect) + str(effect_summary.min_value)
			else:
				summary_text += get_effect_type_heading(effect_summary.effect) + str(effect_summary.min_value) + "-" + str(effect_summary.max_value)
		else:
			# No amount, so just use the full effect text
			summary_text += get_effect_type_text(effect_summary.effect, card_name_source)
		if "and" in effect_summary.effect:
			summary_text += "; " + get_effect_text(effect_summary.effect["and"], false, false, false, card_name_source)
	return summary_text

func get_force_for_effect_summary(effect, card_name_source : String) -> String:
	var effect_str = ""
	var force_limit = effect['force_max']
	if "per_force_effect" in effect and effect['per_force_effect'] != null:
		var per_effect = effect['per_force_effect']
		if 'combine_multiple_into_one' in per_effect and per_effect['combine_multiple_into_one']:
			effect_str += "Spend up to %s force. %s" % [str(force_limit), get_effect_text(per_effect, false, true, true, card_name_source)]
		else:
			var each_every_str = "each"
			if 'force_effect_interval' in effect:
				each_every_str = "every %s" % effect['force_effect_interval']
			effect_str += "Spend up to %s force. For %s, %s" % [str(force_limit), each_every_str, get_effect_text(effect['per_force_effect'], false, true, true, card_name_source)]
	elif 'overall_effect' in effect and effect['overall_effect'] != null:
		effect_str += "You may spend %s force to %s" % [str(force_limit), get_effect_text(effect['overall_effect'], false, true, true, card_name_source)]
	return effect_str

func get_gauge_for_effect_summary(effect, card_name_source : String) -> String:
	var required = 'required' in effect and effect['required']
	var maymust_str = "may"
	if required:
		maymust_str = "must"
	var effect_str = ""
	var to_hand = 'spent_cards_to_hand' in effect and effect['spent_cards_to_hand']
	var gauge_limit = effect['gauge_max']
	var gauge_card_str = "gauge"
	if 'require_specific_card_name' in effect:
		gauge_card_str = "copies of %s from gauge" % effect['require_specific_card_name']
	elif 'valid_card_types' in effect:
		gauge_card_str = "%s(s) from gauge" % '/'.join(effect['valid_card_types'])

	if "per_gauge_effect" in effect and effect['per_gauge_effect'] != null:
		if to_hand:
			effect_str += "Return up to %s %s to your hand. For each, %s" % [str(gauge_limit), gauge_card_str, get_effect_text(effect['per_gauge_effect'], false, true, true, card_name_source)]
		else:
			effect_str += "Spend up to %s %s. For each, %s" % [str(gauge_limit), gauge_card_str, get_effect_text(effect['per_gauge_effect'], false, true, true, card_name_source)]
	elif 'overall_effect' in effect and effect['overall_effect'] != null:
		if to_hand:
			effect_str += "You %s return %s %s to your hand to %s" % [maymust_str, str(gauge_limit), gauge_card_str, get_effect_text(effect['overall_effect'], false, true, true, card_name_source)]
		else:
			effect_str += "You %s spend %s %s to %s" % [maymust_str, str(gauge_limit), gauge_card_str, get_effect_text(effect['overall_effect'], false, true, true, card_name_source)]
	return effect_str

func get_timing_text(timing):
	var text = ""
	match timing:
		"action":
			text += "[b]Action:[/b] "
		"opponent_action":
			text += "[b]Opponent Action:[/b] "
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
		"on_seal":
			text += ""
		"start_of_next_turn":
			text += "At start of next turn: "
		"opponent_start_of_next_turn":
			text += "At start of opponent's turn: "
		"set_strike":
			text += "When you set a strike, "
		"opponent_set_strike":
			text += ""
		"opponent_moved_past":
			text += "If opponent moves past you, "
		"when_hit":
			text += "When hit, "
		"on_stop_on_space":
			text += "When boost entered during strike, stop movement; "
		"on_spend_life":
			text += "When you spend life, "
		_:
			text += "MISSING TIMING"
	return text

func get_condition_text(effect, amount, amount2, detail):
	var condition = effect['condition']
	var text = ""
	match condition:
		"advanced_through":
			text += "If advanced past opponent, "
		"not_advanced_through":
			text += "If didn't advance past opponent, "
		"not_advanced_through_buddy":
			text += "If didn't advance through %s, " % detail
		"any_buddy_in_play":
			text += "If %s is in play, " % detail
		"any_buddy_in_opponent_space":
			text += "If opponent is on %s, " % detail
		"any_buddy_adjacent_opponent_space":
			text += "If opponent is adjacent to %s, " % detail
		"any_buddy_in_or_adjacent_opponent_space":
			text += "If opponent is on or adjacent to %s, " % detail
		"not_any_buddy_in_opponent_space":
			text += "If %s is not in opponent's space, " % detail
		"at_edge_of_arena":
			text += "If at arena edge, "
		"attack_still_in_play":
			text += "If your attack is still in play, "
		"attacks_match_printed_speed":
			text += "If your attack's printed speed matches the printed speed of the opponent's attack, "
		"opponent_printed_speed_greater":
			text += "If the printed speed of the opponent's attack is greater than the printed speed of your attack, "
		"opponent_printed_speed_less":
			text += "If the printed speed of the opponent's attack is less than the printed speed of your attack, "
		"boost_in_play":
			text += "If a boost is in play, "
		"canceled_this_turn":
			text += "If canceled this turn, "
		"copy_of_attack_in_zones":
			var zones = effect['condition_zones'].join("/")
			text += "If copy of attack in %s, " % zones
		"discarded_matches_attack_speed":
			text += "If discarded card matches attack speed, "
		"initiated_strike":
			text += "If %sinitiated strike, " % detail
		"hit_opponent":
			text += "If hit opponent, "
		"not_hit_opponent":
			text += "If did not hit opponent, "
		"last_turn_was_strike":
			text += "If last turn was a strike, "
		"not_last_turn_was_strike":
			text += "If last turn was not a strike, "
		"life_equals":
			text += "If your life is exactly %s, " % amount
		"life_equal_or_below":
			text += "If your life is %s or less, " % amount
		"life_less_than_opponent":
			text += "If your life is less than opponent's, "
		"not_canceled_this_turn":
			text += "If not canceled this turn, "
		"not_full_push":
			text += "If not full push, "
		"not_full_pull":
			text += "If not full pull, "
		"pushed_min_spaces":
			text += "If pushed %s or more spaces, " % amount
		"not_full_close":
			text += "If not full close, "
		"moved_less_than":
			text += "If moved fewer than %s spaces, " % amount
		"moved_at_least":
			text += "If moved at least %s spaces," % amount
		"not_initiated_strike":
			text += "If opponent initiated strike, "
		"not_moved_self_this_strike":
			text += "If you have not moved yourself this strike, "
		"opponent_not_moved_this_strike":
			text += "If the opponent did not move themselves this strike, "
		"moved_during_strike":
			text += "If you moved at least %s space(s) this strike, " % amount
		"was_moved_during_strike":
			text += "If you were moved at least %s space(s) this strike, " % amount
		"opponent_was_moved_during_strike":
			text += "If the opponent was moved at least %s space(s) this strike, "  % amount
		"moved_past":
			text += "If you moved past the opponent, "
		"min_cards_in_deck":
			text += "If you have at least %s card(s) in deck, " % amount
		"min_cards_in_discard":
			text += "If you have at least %s card(s) in discard, " % amount
		"min_cards_in_hand":
			text += "If you have at least %s card(s) in hand, " % amount
		"max_cards_in_hand":
			var amount_str = "%s or fewer" % amount
			if amount == 0:
				amount_str = "no"
			text += "If you have %s card(s) in hand, " % amount_str
		"max_cards_in_gauge":
			var amount_str = "%s or fewer" % amount
			if amount == 0:
				amount_str = "no"
			text += "If you have %s card(s) in Gauge, " % amount_str
		"min_cards_in_gauge":
			if effect.get("condition_opponent"):
				text += "If your opponent has at least %s card(s) in gauge, " % amount
			else:
				text += "If you have at least %s card(s) in gauge, " % amount
		"min_spaces_behind_opponent":
			text += "If there are %s or more spaces behind the opponent, " % amount
		"no_strike_caused":
			text += "If no strike caused, "
		"stunned":
			text += "If stunned, "
		"not_stunned":
			text += "If not stunned, "
		"no_active_strike":
			text += ""
		"opponent_stunned":
			text += "If opponent stunned, "
		"pulled_past":
			text += "If pulled opponent past you, "
		"used_character_action":
			text += ""
		"used_character_bonus":
			text += ""
		"not_used_character_bonus":
			text += ""
		"boost_caused_start_of_turn_strike":
			text += "If this boost makes you strike, "
		"range":
			text += "If opponent at range %s from attack, " % amount
		"range_from_self":
			text += "If opponent at range %s from you, " % amount
		"range_greater_or_equal":
			text += "If opponent at range %s+ from attack, " % amount
		"range_multiple":
			text += "If opponent at range %s-%s from attack, " % [amount, amount2]
		"exceeded":
			text += "If in Exceed Mode: "
		"opponent_exceeded":
			text += "If opponent in Exceed Mode: "
		"is_special_attack":
			text += ""
		"is_special_or_ultra_attack":
			text += "For specials/ultras, "
		"opponent_is_special_attack":
			text += "If opponent strikes with a special, "
		"is_normal_attack":
			text += "If you strike with a normal, "
		"deck_not_empty":
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
		"opponent_on_buddy_space":
			text += "If opponent on %s's space, " % detail
		"buddy_between_attack_source":
			text += "If %s is between you and attack source, " % detail
		"buddy_between_opponent":
			text += "If %s is between you and opponent, " % detail
		"boost_space_between_opponent":
			text += "If %s is between you and opponent, " % detail
		"less_cards_than_opponent":
			text += "If the opponent has more cards in hand than you, "
		"more_cards_than_opponent":
			text += "If you have more cards in hand than opponent, "
		"opponent_at_edge_of_arena":
			text += "If opponent at arena edge, "
		"opponent_at_location":
			text += "If opponent is at %s, " % detail
		"opponent_at_max_range":
			text += "If opponent at attack's max range, "
		"opponent_at_min_range":
			text += "If opponent at attack's min range, "
		"opponent_between_buddy":
			if 'include_buddy_space' in effect and effect['include_buddy_space']:
				text += "If opponent is on %s or between you, " % detail
			else:
				text += "If opponent is between you and %s, " % detail
		"opponent_buddy_in_range":
			text += "If you can hit %s, " % detail
		"opponent_in_boost_space":
			text += "If opponent on %s, " % detail
		"boost_space_in_range_towards_opponent":
			text += "If %s in range towards opponent, " % detail
		"opponent_moved_or_was_moved":
			text += "If opponent moved or was moved, "
		"is_buddy_special_attack":
			text += ""
		"speed_greater_than":
			if amount == "OPPONENT_SPEED":
				text += "If your speed is greater than opponent's, "
			else:
				text += "If your speed is greater than %s, " % amount
		"opponent_speed_less_or_equal":
			text += "If the opponent's speed is %s or lower, " % amount
		"was_wild_swing":
			if effect.get("timing") == "opponent_set_strike":
				text += "If opponent wild swung, "
			else:
				text += "If this was a wild swing, "
		"was_strike_from_gauge":
			text += "If set from gauge, "
		"was_set_from_boosts":
			text += "If set from boosts, "
		"was_hit":
			text += "If you were hit, "
		"was_not_hit":
			text += "If you were not hit, "
		"matches_named_card":
			text += "If your next attack is %s, " % detail
		"is_critical":
			var crit_name = "Crit"
			if 'alt_crit_name' in condition:
				crit_name = condition['alt_crit_name']
			text += "%s: " % crit_name
		"no_sealed_copy_of_attack":
			text += "If there is no sealed copy of your attack, "
		"total_powerup_greater_or_equal":
			text += "If you have %s or more bonus power, " % amount
		"opponent_total_guard_greater_or_equal":
			text += "If the opponent has %s or more guard, " % amount
		"discarded_copy_of_attack":
			text += "If there is a discarded copy of your attack, "
		"not_sustained":
			text += ""
		"boost_in_play_or_parents":
			text += "If a \"%s\" boost is in play, " % detail
		"is_ex_strike":
			text += "If attack is EX, "
		"same_card_as_boost_in_hand":
			text += ""
		"spent_gauge_this_strike":
			text += "If you spent gauge this strike, "
		"has_once_per_game_resource":
			text += ""
		_:
			text += "MISSING CONDITION"
	return text

func get_effect_type_heading(effect):
	var effect_str = ""
	var effect_type = effect['effect_type']
	match effect_type:
		StrikeEffects.Advance:
			effect_str += "Advance "
		StrikeEffects.Close:
			effect_str += "Close "
		StrikeEffects.Draw:
			effect_str += "Draw "
		StrikeEffects.SelfDiscardChoose:
			effect_str += "Discard "
		StrikeEffects.Pass:
			effect_str += ""
		StrikeEffects.Pull:
			effect_str += "Pull "
		StrikeEffects.PullNotPast:
			effect_str += "Pull without pulling past "
		StrikeEffects.Push:
			effect_str += "Push "
		StrikeEffects.Retreat:
			effect_str += "Retreat "
		StrikeEffects.MoveBuddy:
			effect_str += "Move %s " % effect['buddy_name']
		StrikeEffects.OpponentDiscardRandom:
			effect_str += "Opponent randomly discards "
		_:
			effect_str += "MISSING EFFECT HEADING"
	return effect_str

func get_effect_type_text(effect, card_name_source : String = "", char_effect_panel : bool = false):
	var effect_str = ""
	var effect_type = effect['effect_type']
	match effect_type:
		StrikeEffects.AddAttackEffect:
			if 'description' in effect:
				effect_str += effect['description']
			else:
				if char_effect_panel:
					effect_str += get_effect_text(effect['added_effect'], false, false, false, card_name_source, false)
				else:
					effect_str += "Add effect - " + get_effect_text(effect['added_effect'], false, false, false, card_name_source, false)
		StrikeEffects.AddAttackTriggers:
			effect_str += "Add Before/Hit/After effects on that card to attack"
		StrikeEffects.AddBoostToGaugeOnStrikeCleanup:
			if card_name_source:
				effect_str += "Add %s to gauge" % card_name_source
			else:
				effect_str += "Add card to gauge"
		StrikeEffects.AddBoostToOverdriveDuringStrikeImmediately:
			if 'card_name' in effect:
				effect_str += "Add %s to overdrive" % effect['card_name']
			else:
				effect_str += "Add card to overdrive"
		StrikeEffects.AddHandToGauge:
			effect_str += "Add your hand to your gauge"
		StrikeEffects.AddOpponentStrikeToGauge:
			effect_str += "Add opponent's attack to gauge"
		StrikeEffects.AddStrikeToGaugeAfterCleanup:
			effect_str += "Add card to gauge after strike."
		StrikeEffects.AddStrikeToOverdriveAfterCleanup:
			effect_str += "Add card to overdrive after strike."
		StrikeEffects.AddToGaugeBoostPlayCleanup:
			effect_str += "Add card to gauge"
		StrikeEffects.AddToGaugeImmediately:
			effect_str += "Add card to gauge"
		StrikeEffects.AddToGaugeImmediatelyMidStrikeUndoEffects:
			effect_str += "Add card to gauge (and cancel its effects)."
		StrikeEffects.AddBottomDiscardToGauge:
			var card_str = ""
			if 'card_name' in effect:
				card_str = "([color=%s]%s[/color]) " % [CardHighlightColor, effect['card_name']]
			effect_str += "Add bottom card of discard pile %sto gauge" % card_str
		StrikeEffects.AddBottomDiscardToHand:
			var card_str = ""
			if 'card_name' in effect:
				card_str = "([color=%s]%s[/color]) " % [CardHighlightColor, effect['card_name']]
			effect_str += "Add bottom card of discard pile %sto hand" % card_str
		StrikeEffects.AddTopDeckToGauge:
			var player_str = "Add"
			if 'opponent' in effect and effect['opponent']:
				player_str = "Opponent adds"
			var amount_str = "top card"
			if 'amount' in effect:
				amount_str = "top %s card(s)" % effect['amount']
				if str(effect['amount']) == 'num_discarded_card_ids':
					amount_str = "that many top cards"
				elif str(effect['amount']) == 'force_spent_this_turn':
					amount_str = "a card per force spent this turn from top"
			var topdeck_card = ""
			if 'card_name' in effect:
				topdeck_card = "([color=%s]%s[/color]) " % [CardHighlightColor, effect['card_name']]
			effect_str += "%s %s of deck %sto gauge" % [player_str, amount_str, topdeck_card]
		StrikeEffects.AddTopDeckToBottom:
			effect_str = "Move top card of deck to bottom of deck"
		StrikeEffects.AddTopDiscardToGauge:
			if 'amount' in effect:
				effect_str += "Add top %s card(s) of discard pile to gauge" % effect['amount']
			else:
				effect_str += "Add top card of discard pile to gauge"
		StrikeEffects.AddTopDiscardToOverdrive:
			if 'card_name' in effect:
				effect_str += "Add %s from top of discard pile to overdrive" % effect['card_name']
			else:
				effect_str += "Add top card of discard pile to overdrive"
		StrikeEffects.AddPassive:
			var passive_id = effect['passive']
			match passive_id:
				"discard_2x_topdeck_instead_of_damage":
					effect_str += "Ignore damage, instead discard 2x that from top of deck"
				"skip_eot_draw_and_discard":
					effect_str += "Skip end of turn draw and discard"
		StrikeEffects.Advance:
			if 'description' in effect:
				effect_str += effect['description']
			else:
				if 'combine_multiple_into_one' in effect and effect['combine_multiple_into_one']:
					effect_str += "Advance that much."
				else:
					effect_str += "Advance "
					if str(effect['amount']) == "strike_x":
						effect_str += "X"
					else:
						effect_str += str(effect['amount'])
		StrikeEffects.AdvanceInternal:
			effect_str += "Advance "
			if str(effect['amount']) == "strike_x":
				effect_str += "X"
			else:
				effect_str += str(effect['amount'])
		StrikeEffects.Armorup:
			effect_str += "+" + str(effect['amount']) + " Armor"
		StrikeEffects.ArmorupDamageDealt:
			effect_str += "+ Armor per damage dealt"
		StrikeEffects.ArmorupCurrentPower:
			effect_str += "+ Armor equal to power"
		StrikeEffects.ArmorupOpponentPerForceSpentThisTurn:
			if effect['amount'] >= 0:
				effect_str += "+"
			effect_str += str(effect['amount']) + " to opponent's Armor per force spent this turn."
		StrikeEffects.AttackDoesNotHit:
			if 'opponent' in effect and effect['opponent']:
				effect_str += "Opponent's attack does not hit."
			else:
				effect_str += "Attack does not hit."
		StrikeEffects.AttackIncludesRange:
			effect_str += "Attack includes Range %s" % effect['amount']
		StrikeEffects.AttackIsEx:
			effect_str += "Next Strike is EX"
		StrikeEffects.BecomeWide:
			var description = "3 spaces wide"
			if 'description' in effect:
				description = effect['description']
			effect_str = "Become %s" % description
		StrikeEffects.BlockOpponentMove:
			effect_str += "Opponent cannot move"
		StrikeEffects.RemoveBlockOpponentMove:
			effect_str += ""
		StrikeEffects.BonusAction:
			effect_str += "Take another action"
		StrikeEffects.BoostAdditional:
			var limitation_str = "boost"
			if 'limitation' in effect and effect['limitation']:
				limitation_str = effect['limitation'] + " boost"
			var ignore_costs_str = ""
			if 'ignore_costs' in effect and effect['ignore_costs']:
				ignore_costs_str = " (ignoring costs)"
			if 'valid_zones' in effect:
				var zone_string = "/".join(effect['valid_zones'])
				effect_str += "Play a %s from %s%s." % [limitation_str, zone_string, ignore_costs_str]
			else:
				effect_str += "Play a %s from hand%s." % [limitation_str, ignore_costs_str]
		StrikeEffects.BoostMultiple:
			var amount_str = "1-%s" % effect['amount']
			if effect['amount'] == 1:
				amount_str = 1
			var limitation_str = "boost(s)"
			if 'limitation' in effect and effect['limitation']:
				limitation_str = effect['limitation'] + " boost(s)"
			var ignore_costs_str = ""
			if 'ignore_costs' in effect and effect['ignore_costs']:
				ignore_costs_str = " (ignoring costs)"
			if 'valid_zones' in effect:
				var zone_string = "/".join(effect['valid_zones'])
				effect_str += "Play %s %s from %s%s." % [amount_str, limitation_str, zone_string, ignore_costs_str]
			else:
				effect_str += "Play %s %s from hand%s." % [amount_str, limitation_str, ignore_costs_str]
		StrikeEffects.BoostOrRevealHand:
			var alternative = "Reveal hand"
			if 'strike_instead_of_reveal' in effect and effect['strike_instead_of_reveal']:
				alternative = "Strike"
			effect_str += "Boost (%s if you cannot)" % alternative
		StrikeEffects.BoostSpecificCard:
			effect_str += "Play a \"%s\" boost from hand" % effect['boost_name']
		StrikeEffects.BoostThenStrike:
			var wild_str = ""
			if 'wild_strike' in effect and effect['wild_strike']:
				wild_str = "Wild "
			effect_str += "Boost, then %sStrike if you weren't caused to Strike" % wild_str
		StrikeEffects.BoostThisThenSustain:
			var sustain_str = "and sustain "
			if 'dont_sustain' in effect and effect['dont_sustain']:
				sustain_str = ""
			if card_name_source:
				effect_str += "Boost %s%s" % [sustain_str, card_name_source]
			else:
				effect_str += "Boost %sthis" % sustain_str
		StrikeEffects.BoostThenSustain:
			var sustain_str = " and sustain"
			if 'sustain' in effect and not effect['sustain']:
				sustain_str = ""
			var limitation_str = "boost"
			if 'limitation' in effect and effect['limitation']:
				if effect['limitation'] == "transform":
					limitation_str = "transformation"
				else:
					limitation_str = effect['limitation'] + " boost"
			var ignore_costs_str = ""
			if 'ignore_costs' in effect and effect['ignore_costs']:
				ignore_costs_str = " (ignoring costs)"
			if 'valid_zones' in effect:
				var zone_string = "/".join(effect['valid_zones'])
				effect_str += "Play%s a %s from %s%s." % [sustain_str, limitation_str, zone_string, ignore_costs_str]
			else:
				effect_str += "Play%s a %s from hand%s." % [sustain_str, limitation_str, ignore_costs_str]
			if 'play_boost_effect' in effect:
				effect_str += " If you do, %s" % get_effect_text(effect['play_boost_effect'])
		StrikeEffects.BoostThenSustainTopdeck:
			if 'description' in effect:
				effect_str += effect['description']
			else:
				effect_str += "Play and sustain %s card(s) from the top of your deck." % effect['amount']
		StrikeEffects.BoostThenSustainTopdiscard:
			var limitation_str = "card(s)"
			if 'limitation' in effect and effect['limitation'] == "continuous":
				limitation_str = "continuous boost(s)"
			effect_str += "Play and sustain the top %s %s from your discard pile" % [effect['amount'], limitation_str]
		StrikeEffects.BoostAsOverdriveInternal:
			effect_str += "Overdrive Effect: Play a continuous boost from hand."
		StrikeEffects.CannotGoBelowLife:
			effect_str += "Life cannot go below %s" % effect['amount']
		StrikeEffects.CannotStun:
			effect_str += "Attack does not stun"
		StrikeEffects.Choice:
			var multiple_str = ""
			if 'mulitple_amount' in effect:
				multiple_str = " " + str(effect['mulitple_amount'])
			if 'opponent' in effect and effect['opponent']:
				effect_str += "Opponent "
			if 'special_choice_name' in effect:
				effect_str += effect['special_choice_name']
			else:
				effect_str += "Choose" + multiple_str + ": " + get_choice_summary(effect[StrikeEffects.Choice], card_name_source)
		StrikeEffects.ChoiceAlteredValues:
			if 'opponent' in effect and effect['opponent']:
				effect_str += "Opponent "
			if 'special_choice_name' in effect:
				effect_str += effect['special_choice_name']
			else:
				effect_str += "Choose: " + get_choice_summary(effect[StrikeEffects.Choice], card_name_source)
		StrikeEffects.ChooseCalculateRangeFromBuddy:
			var optional_str = "Choose"
			if 'optional' in effect and effect['optional']:
				optional_str = "You may choose"
			effect_str += optional_str + " a %s to calculate range from" % effect['buddy_name']
		StrikeEffects.ChooseDiscard:
			var destination = effect['destination']
			if destination == "lightningrod_any_space":
				effect_str += "Choose a card from your discard pile to place as a Lightning Rod"
			else:
				var destination_str = destination
				var amount_str = str(effect.get("amount", "1"))
				if destination == "deck_noshuffle":
					destination_str = "top deck"
				var source = "discard"
				if 'source' in effect:
					source = effect['source']
				if effect['limitation']:
					effect_str += "Choose %s %s card(s) from %s to move to %s" % [amount_str, effect['limitation'], source, destination_str]
				else:
					effect_str += "Choose %s card(s) from %s to move to %s" % [amount_str, source, destination]
				if effect.get("opponent"):
					effect_str = "Opponent must: " + effect_str
		StrikeEffects.ChooseOpponentCardToDiscard:
			var opponent = effect['opponent'] if 'opponent' in effect else false
			var use_discarded_card_ids = effect['use_discarded_card_ids'] if 'use_discarded_card_ids' in effect else false
			if opponent:
				if use_discarded_card_ids:
					effect_str += "Opponent chooses one to discard"
				else:
					effect_str += "Opponent chooses a card in your hand to discard"
			else:
				if use_discarded_card_ids:
					effect_str += "Choose one to discard"
				else:
					effect_str += "Choose a card in the opponent's hand to discard"
		StrikeEffects.ChooseSustainBoost:
			effect_str += "Choose a boost to sustain."
		StrikeEffects.Close:
			if 'combine_multiple_into_one' in effect and effect['combine_multiple_into_one']:
				effect_str += "Close that much."
			else:
				effect_str += "Close " + str(effect['amount'])
		StrikeEffects.CloseDamageTaken:
			effect_str += "Close %s per damage taken this strike" % effect['amount']
		StrikeEffects.CloseInternal:
			effect_str += "Close " + str(effect['amount'])
		StrikeEffects.CopyOtherHitEffect:
			effect_str += "Copy another Hit effect"
		StrikeEffects.Critical:
			var crit_name = "Critical"
			if 'alt_crit_name' in effect:
				crit_name = effect['alt_crit_name']
			effect_str += "%s Strike" % crit_name
		StrikeEffects.DiscardThis:
			effect_str += "Discard this"
		StrikeEffects.DiscardSameCardAsBoost:
			effect_str += "Discard a copy of the boosted card"
		StrikeEffects.DiscardStrikeAfterCleanup:
			effect_str += "Discard attack on cleanup"
		StrikeEffects.DiscardContinuousBoost:
			if 'destination' in effect and effect['destination'] == "owner_hand":
				effect_str += "Return a continuous boost to its owner's hand."
			else:
				if 'limitation' in effect and effect['limitation'] == 'mine' and 'overall_effect' in effect:
					effect_str += "You may discard one of your continuous boosts for %s" % [get_effect_text(effect['overall_effect'])]
				else:
					effect_str += "Discard a continuous boost"
		StrikeEffects.DiscardOpponentGauge:
			effect_str += "Discard a card from opponent's gauge."
		StrikeEffects.DiscardOpponentTopdeck:
			effect_str += "Discard a card from the top of the opponent's deck"
		StrikeEffects.DiscardTopdeck:
			if 'card_name' in effect:
				effect_str += "Discard [color=%s]%s[/color] from the top of your deck" % [CardHighlightColor, effect['card_name']]
			else:
				effect_str += "Discard a card from the top of your deck"
		StrikeEffects.DiscardRandom:
			effect_str += "Discard %s at random" % effect['amount']
		StrikeEffects.DiscardRandomAndAddTriggers:
			effect_str += "Discard a random card; add before/hit/after triggers to attack"
		StrikeEffects.DodgeAtRange:
			var buddy_string = ""
			if 'from_buddy' in effect and effect['from_buddy']:
				buddy_string = " from %s" % effect['buddy_name']
			if 'special_range' in effect and effect['special_range'] == "OVERDRIVE_COUNT":
				effect_str += "Opponent attacks miss at range X where X is # of cards in your overdrive."
			elif effect['range_min'] == effect['range_max']:
				effect_str += "Opponent attacks miss at range %s%s." % [effect['range_min'], buddy_string]
			else:
				effect_str += "Opponent attacks miss at range %s-%s%s." % [effect['range_min'], effect['range_max'], buddy_string]
		StrikeEffects.DodgeAttacks:
			effect_str += "Opponent misses."
		StrikeEffects.DodgeFromOppositeBuddy:
			effect_str += "Opponents on other side of %s miss." % effect['buddy_name']
		StrikeEffects.DoNotRemoveBuddy:
			effect_str += "Do not remove %s from play." % effect['buddy_name']
		StrikeEffects.RemoveBuddy:
			effect_str += "Remove %s from play" % effect['buddy_name']
		StrikeEffects.PlaceBuddyInAnySpace:
			effect_str += "Place %s in any space." % effect['buddy_name']
		StrikeEffects.PlaceBuddyInAttackRange:
			effect_str += "Place %s in the attack's range." % effect['buddy_name']
		StrikeEffects.PlaceNextBuddy:
			var unoccupied_str = ""
			if effect['require_unoccupied']:
				unoccupied_str = " in an unoccupied space"
			var where_str = ""
			match effect['destination']:
				"attack_range":
					where_str = "in the attack's range"
				"anywhere":
					where_str = "anywhere"
				"adjacent_self":
					where_str = "adjacent to you"
				"self":
					where_str = "on your space"
				_:
					where_str = "<MISSING DESTINATION STRING>"
			effect_str += "Place %s %s%s." % [effect['buddy_name'], where_str, unoccupied_str]
		StrikeEffects.PlaceLightningrod:
			var card_str = ""
			match effect['source']:
				"this_attack_card":
					card_str = "this attack"
				"top_discard":
					card_str = "the top card of your discard pile"
			var where_str = ""
			match effect['limitation']:
				"attack_range":
					where_str = "in the attack's range"
				"any":
					where_str = "anywhere"
			effect_str += "Place %s as a Lightning Rod %s" % [card_str, where_str]
		StrikeEffects.PlaceTopdeckUnderBoost:
			effect_str += "Place top of deck under %s; draw all when discarded" % effect['card_name']
		StrikeEffects.PlayAttackFromHand:
			effect_str += "Play an attack from your hand, paying its costs."
		StrikeEffects.CalculateRangeFromBuddy:
			effect_str += "Calculate range from %s." % effect['buddy_name']
		StrikeEffects.CalculateRangeFromBuddyCurrentLocation:
			effect_str += "Calculate range from %s's current location" % effect['buddy_name']
		StrikeEffects.CalculateRangeFromCenter:
			effect_str += "Calculate range from the center of the arena."
		StrikeEffects.CalculateRangeFromSetFromBoostSpace:
			effect_str += "Calculate range from the space it was in."
		StrikeEffects.Draw:
			var amount = effect['amount']
			var amount_str = str(amount)
			var bottom_str = ""
			if amount_str == "strike_x":
				amount_str = "X"
			elif amount_str == "GAUGE_COUNT":
				amount_str = "equal to your Gauge"
			elif amount_str == "SPACES_BETWEEN":
				amount_str = "1 for each space between you and the opponent"
			if 'from_bottom' in effect:
				bottom_str = " from bottom of deck"
			if 'opponent' in effect and effect['opponent']:
				if 'hide_opponent_in_description' in effect and effect['hide_opponent_in_description']:
					effect_str += "Draw " + amount_str + bottom_str
				else:
					effect_str += "Opponent Draw " + amount_str + bottom_str
			else:
				effect_str += "Draw " + amount_str + bottom_str
		StrikeEffects.DrawForCardInGauge:
			var every_str = "every card"
			if 'per_gauge' in effect:
				every_str = "every %s card(s)" % effect['per_gauge']
			effect_str += "Draw for %s in your gauge" % every_str
		StrikeEffects.DrawAnyNumber:
			effect_str += "Draw any number of cards."
		StrikeEffects.DrawTo:
			effect_str += "Draw until you have %s cards in hand" % str(effect['amount'])
		StrikeEffects.OpponentDrawOrDiscardTo:
			var amount_str = "%s cards in hand" % str(effect['amount'])
			if str(effect['amount']) == 'other_player_hand_size':
				amount_str = "the same number of cards as you"
			effect_str += "Opponent draws or discards until they have %s" % amount_str
			if 'per_draw_effect' in effect:
				effect_str += "\nIf they draw: per card drawn, " + get_effect_text(effect['per_draw_effect'], false, false, false)
		StrikeEffects.EffectPerCardInZone:
			var per_effect = get_effect_text(effect["per_card_effect"], false, false, false)
			var limitation_str = ""
			var zone_name = effect['zone']
			if effect.get("zone_name"):
				zone_name = effect['zone_name']
			if effect.get("limitation") == "range_to_opponent":
				limitation_str = " with Range to Opponent"
			effect_str += "%s per card in %s%s" % [per_effect, zone_name, limitation_str]
		StrikeEffects.ExceedNow:
			effect_str += "Exceed"
		StrikeEffects.ExtraTriggerResolutions:
			effect_str += "Before/Hit/After triggers resolve %s extra time(s)" % effect['amount']
		StrikeEffects.FlipBuddyMissGetGauge:
			effect_str += effect['description']
		StrikeEffects.ForceCostsReducedPassive:
			effect_str += "Force costs reduced by %s" % effect['amount']
		StrikeEffects.ForceForEffect:
			effect_str += get_force_for_effect_summary(effect, card_name_source)
		StrikeEffects.GaugeForEffect:
			effect_str += get_gauge_for_effect_summary(effect, card_name_source)
		StrikeEffects.GainAdvantage:
			effect_str += "Gain Advantage"
		StrikeEffects.GainLife:
			var amount = effect['amount']
			if str(amount) == "LAST_SPENT_LIFE":
				amount = "that much"
			effect_str += "Gain " + str(amount) + " life"
		StrikeEffects.GaugeFromHand:
			var last_cards_req = ""
			var destination = "Gauge"
			if effect.get("destination_name"):
				destination = effect['destination_name']
			if effect.get("from_last_cards"):
				last_cards_req = " from the last %s drawn cards" % effect['from_last_cards']
			effect_str += "Add a card from hand to %s%s" % [destination, last_cards_req]
		StrikeEffects.GenerateFreeForce:
			effect_str += "Generate %s force for free" % effect['amount']
		StrikeEffects.Guardup:
			if str(effect['amount']) == "strike_x":
				effect_str += "+X Guard"
			else:
				if effect['amount'] > 0:
					effect_str += "+"
				effect_str += str(effect['amount']) + " Guard"
		StrikeEffects.GuardupPerForceSpentThisTurn:
			effect_str += "+" + str(effect['amount']) + " Guard per force spent this turn."
		StrikeEffects.GuardupPerTwoCardsInHand:
			effect_str += "+1 Guard per 2 cards in hand"
		StrikeEffects.GuardupPerGauge:
			effect_str += "+" + str(effect['amount']) + " Guard per card in gauge."
		StrikeEffects.IgnoreArmor:
			if 'opponent' in effect and effect['opponent']:
				effect_str += "Opponent ignores armor"
			else:
				effect_str += "Ignore armor"
		StrikeEffects.IgnoreGuard:
			if 'opponent' in effect and effect['opponent']:
				effect_str += "Opponent ignores guard"
			else:
				effect_str += "Ignore guard"
		StrikeEffects.IgnorePushAndPull:
			effect_str += "Ignore Push and Pull"
		StrikeEffects.IgnorePushAndPullPassiveBonus:
			effect_str += "Ignore Push and Pull"
		StrikeEffects.IncreaseDrawEffects:
			effect_str += "Increase draw effects by %s" % effect['amount']
		StrikeEffects.IncreaseForceSpentBeforeStrike:
			effect_str += get_effect_text(effect['linked_effect'], false, false, false)
		StrikeEffects.IncreaseMovementEffects:
			effect_str += "Increase advance/retreat effects by %s" % effect['amount']
		StrikeEffects.IncreaseMove_OpponentEffects:
			effect_str += "Increase push/pull effects by %s" % effect['amount']
		StrikeEffects.InvertRange:
			effect_str += "Attack Range is inverted"
		StrikeEffects.LightningrodStrike:
			effect_str += "Return %s to hand to deal 2 nonlethal damage" % effect['card_name']
		StrikeEffects.ResetCharacterPositions:
			effect_str += "Move both players to starting positions"
		StrikeEffects.RemoveIgnorePushAndPullPassiveBonus:
			effect_str += ""
		StrikeEffects.LoseAllArmor:
			effect_str += "Lose all armor"
		StrikeEffects.NameCardOpponentDiscards:
			effect_str += "Name a card. Opponent discards it or reveals not in hand."
		StrikeEffects.NegateBoost:
			effect_str += "Discard opponent's boost without effect"
		StrikeEffects.MayAdvanceBonusSpaces:
			effect_str = "You may Advance/Close %s extra space(s)" % effect['amount']
		StrikeEffects.MoveAnyBuddy:
			if 'to_opponent' in effect and effect['to_opponent']:
				effect_str += "Move %s to opponent's space" % effect['buddy_name']
			else:
				var move_min = effect['amount_min']
				var move_max = effect['amount_max']
				effect_str += "Move %s %s-%s spaces" % [effect['buddy_name'], move_min, move_max]
		StrikeEffects.MoveBuddy:
			var strike_str = ""
			if 'strike_after' in effect and effect['strike_after']:
				strike_str = " and strike"
			var movement_str = "%s" % effect['amount']
			if effect['amount'] != effect['amount2']:
				movement_str += "-%s" % effect['amount2']
			effect_str += "Move %s %s space(s)%s" % [effect['buddy_name'], movement_str, strike_str]
		StrikeEffects.MoveToBuddy:
			effect_str += "Move to %s" % effect['buddy_name']
		StrikeEffects.MoveToAnySpace:
			if 'move_min' in effect:
				var move_min = effect['move_min']
				var move_max = effect['move_max']
				effect_str += "Advance or Retreat %s-%s" % [move_min, move_max]
			else:
				effect_str += "Move to any space."
		StrikeEffects.MoveRandomCards:
			var card_count = effect['amount']
			var from_zone = effect['from_zone']
			var to_zone = effect['to_zone']
			var opponent_str = ""
			if effect.get("opponent", false):
				opponent_str = "Opponent: "
			var action_word = "Discard"
			var destination_str = ""
			match to_zone:
				"gauge":
					action_word = "Move"
					destination_str = " to Gauge"
				# Add other zones here when refactoring other effects.
			var from_str = ""
			match from_zone:
				"gauge":
					from_str = " from Gauge"
				# Add other zones here when refactoring other effects.
			effect_str += "%s%s %s random card(s)%s%s" % [opponent_str, action_word, card_count, from_str, destination_str]
		StrikeEffects.MultiplyPowerBonuses:
			if effect['amount'] == 2:
				effect_str += "Double power bonuses"
			else:
				effect_str += "Multiply power bonuses by %s" % effect['amount']
		StrikeEffects.MultiplyPositivePowerBonuses:
			if effect['amount'] == 2:
				effect_str += "Double positive power bonuses"
			else:
				effect_str += "Multiply power bonuses by %s" % effect['amount']
		StrikeEffects.NonlethalAttack:
			effect_str += "Deal non-lethal damage"
		StrikeEffects.Nothing:
			if 'description' in effect:
				effect_str += effect['description']
			else:
				effect_str += ""
		StrikeEffects.RegainOncePerGameResource:
			var resource_name = "1PG Mechanic"
			if 'resource_name' in effect:
				resource_name = effect['resource_name']
			effect_str += "Regain %s usage" % resource_name
		StrikeEffects.OpponentCantMovePast:
			effect_str += "Opponent cannot Advance past you"
		StrikeEffects.RemoveOpponentCantMovePast:
			effect_str += ""
		StrikeEffects.OpponentDiscardChoose:
			var destination_str = "discards"
			if 'destination' in effect:
				if effect['destination'] == "reveal":
					destination_str = "reveals"

			var cards_str = " card(s)"
			var amount_str = str(effect['amount'])
			if amount_str == "force_spent_before_strike":
				amount_str = "that many"
			elif amount_str == "CARDS_DISCARDED_THIS_STRIKE":
				amount_str = "1 card per card discarded this strike"
				cards_str = ""

			var allow_fewer = 'allow_fewer' in effect and effect['allow_fewer']
			var up_to_text = ""
			if allow_fewer:
				up_to_text = " up to"
			effect_str += "Opponent " + destination_str + up_to_text + " " + amount_str + cards_str
			if 'smaller_discard_effect' in effect:
				effect_str += "\nIf they discard less: " + get_effect_text(effect['smaller_discard_effect'], false, false, false)
		StrikeEffects.OpponentDiscardRandom:
			var dest_str = ""
			if 'destination' in effect:
				dest_str = " to your " + effect['destination']
			effect_str += "Opponent discards " + str(effect['amount']) + " random cards" + dest_str + "."
		"opponent_wild_swings":
			effect_str += "Opponent wild swings."
		StrikeEffects.Pass:
			effect_str += "Pass"
			if 'description' in effect:
				effect_str += " (%s)" % effect['description']
		StrikeEffects.PlaceBoostInSpace:
			var place_str = "Place"
			if 'boost_already_placed' in effect and effect['boost_already_placed']:
				place_str = "Move"
			var boost_str = "boost"
			if 'boost_name' in effect:
				boost_str = effect['boost_name']

			effect_str += "%s %s." % [place_str, boost_str]
		StrikeEffects.PlaceBuddyAtRange:
			if effect['range_min'] == effect['range_max']:
				effect_str += "Place %s at range %s" % [effect['buddy_name'], effect['range_min']]
			else:
				effect_str += "Place %s at range %s-%s" % [effect['buddy_name'], effect['range_min'], effect['range_max']]
		StrikeEffects.PlaceBuddyOntoSelf:
			effect_str += "Place %s onto your space" % effect['buddy_name']
		StrikeEffects.PowerupPerArmorUsed:
			var amount = str(effect['amount'])
			if effect['amount'] > 0:
				amount = "+%s" % amount
			effect_str += "%s Power per card armor consumed." % amount
		StrikeEffects.Powerup:
			var multiplier_string = ""
			if 'multiplier' in effect and effect['multiplier'] != 1:
				multiplier_string += " (x%s)" % str(effect['multiplier'])

			if str(effect['amount']) == "strike_x":
				effect_str += "+X%s Power" % multiplier_string
			elif str(effect['amount']) == "DISCARDED_COUNT":
				effect_str += "+1%s Power for each card in your discard pile." % multiplier_string
			else:
				if effect['amount'] > 0:
					effect_str += "+"
				effect_str += str(effect['amount'])
				effect_str += "%s Power" % multiplier_string
		StrikeEffects.PowerupBothPlayers:
			effect_str += "Both players "
			if effect['amount'] > 0:
				effect_str += "+"
			effect_str += str(effect['amount'])
			effect_str += " Power"
		StrikeEffects.PowerupPerBoostInPlay:
			effect_str += "+" + str(effect['amount']) + " Power per boost in play."
		StrikeEffects.PowerupPerCardInHand:
			effect_str += "+" + str(effect['amount']) + " Power per card in hand up to " + str(effect['amount_max']) + "."
		StrikeEffects.PowerupPerCardInOpponentHand:
			var every_str = "card"
			if 'per_card' in effect:
				every_str = "%s cards" % effect['per_card']
			effect_str += "+" + str(effect['amount']) + " Power for every " + every_str + " in opponent's hand."
		StrikeEffects.PowerupPerForceSpentThisTurn:
			effect_str += "+" + str(effect['amount']) + " Power per force spent this turn."
		StrikeEffects.PowerupPerGuard:
			var max_text = ""
			if 'maximum' in effect:
				max_text = " (max %s)" % effect['maximum']
			effect_str += "+" + str(effect['amount']) + " Power per guard%s." % max_text
		StrikeEffects.PowerupPerArmor:
			var max_text = ""
			if 'maximum' in effect:
				max_text = " (max %s)" % effect['maximum']
			effect_str += "+" + str(effect['amount']) + " Power per armor%s." % max_text
		StrikeEffects.PowerupPerSpeed:
			var max_text = ""
			if 'maximum' in effect:
				max_text = " (max %s)" % effect['maximum']
			effect_str += "+" + str(effect['amount']) + " Power per speed%s." % max_text
		StrikeEffects.PowerupPerPower:
			var max_text = ""
			if 'maximum' in effect:
				max_text = " (max %s)" % effect['maximum']
			effect_str += "+" + str(effect['amount']) + " Power per power%s." % max_text
		StrikeEffects.PowerupPerGauge:
			var opponent_str = ""
			if effect.get("count_opponent"):
				opponent_str = "opponent's "
			effect_str += "+" + str(effect['amount']) + " Power per card in " + opponent_str + "gauge up to " + str(effect['amount_max']) + "."
		StrikeEffects.PowerupPerSpentGaugeMatchingRangeToOpponent:
			effect_str += "+" + str(effect['amount']) + " Power per spent gauge matching range to opponent."
		StrikeEffects.PowerupPerSealedNormal:
			var max_text = ""
			if 'maximum' in effect:
				max_text = " (max %s)" % effect['maximum']
			effect_str += "+" + str(effect['amount']) + " Power per sealed normal%s." % max_text
		StrikeEffects.PowerupDamageTaken:
			effect_str += "+" + str(effect['amount']) + " Power per damage taken this strike."
		StrikeEffects.PowerupOpponent:
			if effect['amount'] > 0:
				effect_str += "+"
			if 'describe_as_self' in effect and effect['describe_as_self']:
				effect_str += str(effect['amount']) + " Power"
			else:
				effect_str += str(effect['amount']) + " Opponent's Power"
		StrikeEffects.Pull:
			if 'combine_multiple_into_one' in effect and effect['combine_multiple_into_one']:
				effect_str += "Pull that much."
			elif str(effect['amount']) == "TOTAL_POWER":
				effect_str += "Pull X. X is the total Power of the attack"
			else:
				effect_str += "Pull " + str(effect['amount'])
		StrikeEffects.PullAnyNumberOfSpacesAndGainPower:
			effect_str += "Pull any amount and +1 Power per space pulled."
		StrikeEffects.PullToRange:
			effect_str += "Pull to range %s" % str(effect['amount'])
		StrikeEffects.PullToBuddy:
			effect_str += "Pull %s to %s" % [str(effect['amount']), effect['buddy_name']]
		StrikeEffects.PullToSpaceAndGainPower:
			effect_str += "Pull to space " + str(effect['amount']) + " and +1 Power per space pulled."
		StrikeEffects.Push:
			if 'combine_multiple_into_one' in effect and effect['combine_multiple_into_one']:
				effect_str += "Push that much."
			elif str(effect['amount']) == "OPPONENT_SPEED":
				effect_str += "Push X. X is the opponent's Speed"
			elif str(effect['amount']) == "TOTAL_POWER":
				effect_str += "Push X. X is the total Power of the attack"
			else:
				var extra_info = ""
				if 'save_buddy_spaces_entered_as_strike_x' in effect and effect['save_buddy_spaces_entered_as_strike_x']:
					extra_info = "\nSet X to the number of %s the opponent is pushed onto" % effect['buddy_name']
				if 'save_unpushed_spaces_as_strike_x' in effect and effect['save_unpushed_spaces_as_strike_x']:
					extra_info = "\nSet X to the number of spaces they couldn't be pushed"
				effect_str += "Push " + str(effect['amount']) + extra_info
		StrikeEffects.PushFromSource:
			effect_str += "Push " + str(effect['amount']) + " from attack source"
		StrikeEffects.PullFromSource:
			effect_str += "Pull " + str(effect['amount']) + " towards attack source"
			if effect.get("skip_if_on_source"):
				effect_str += " (skip if on source)"
		StrikeEffects.PushOrPullToAnySpace:
			effect_str += "Push or pull to any space."
		StrikeEffects.PushOrPullToSpace:
			effect_str += "Push or pull to space " + str(effect['amount']) + "."
		StrikeEffects.PushToAttackMaxRange:
			effect_str += "Push to attack's max range"
		StrikeEffects.PushToRange:
			effect_str += "Push to range %s" % effect['amount']
		StrikeEffects.RangeIncludesIfMovedPast:
			effect_str += "If you move past the opponent, your range includes them"
		StrikeEffects.Rangeup:
			if effect.get("opponent"):
				effect_str += "Opponent "
			if effect.get("special_only"):
				effect_str += "Specials "
			if str(effect['amount']) != str(effect['amount2']):
				# Skip the first one if they're the same.
				if str(effect['amount']) == "strike_x":
					effect_str += "+X - "
				else:
					if effect['amount'] >= 0:
						effect_str += "+"
					effect_str += str(effect['amount']) + " - "
			if str(effect['amount2']) == "strike_x":
				effect_str += "+X"
			else:
				if effect['amount2'] >= 0:
					effect_str += "+"
				effect_str += str(effect['amount2'])
			effect_str += " Range"
		StrikeEffects.RangeupBothPlayers:
			effect_str += "Both players "
			if effect['amount'] != effect['amount2']:
				# Skip the first one if they're the same.
				if effect['amount'] >= 0:
					effect_str += "+"
				effect_str += str(effect['amount']) + " - "
			if effect['amount2'] >= 0:
				effect_str += "+"
			effect_str += str(effect['amount2']) + " Range"
		StrikeEffects.RangeupIfExModifier:
			effect_str += "If EX, +" + str(effect['amount']) + "-" + str(effect['amount2']) + " Range."
		StrikeEffects.RangeupPerBoostInPlay:
			if 'all_boosts' in effect and effect['all_boosts']:
				effect_str += "+" + str(effect['amount']) + "-" + str(effect['amount2']) + " Range per EVERY boost in play."
			else:
				effect_str += "+" + str(effect['amount']) + "-" + str(effect['amount2']) + " Range per boost in play."
		StrikeEffects.RangeupPerBoostModifier:
			if 'all_boosts' in effect and effect['all_boosts']:
				effect_str += "+" + str(effect['amount']) + "-" + str(effect['amount2']) + " Range per EVERY boost in play."
			else:
				effect_str += "+" + str(effect['amount']) + "-" + str(effect['amount2']) + " Range per boost in play."
		StrikeEffects.RangeupPerCardInHand:
			effect_str += "+" + str(effect['amount']) + "-" + str(effect['amount2']) + " Range per card in hand."
		StrikeEffects.RangeupPerForceSpentThisTurn:
			effect_str += "+" + str(effect['amount']) + "-" + str(effect['amount2']) + " Range per force spent this turn."
		StrikeEffects.RangeupPerSealedNormal:
			effect_str += "+" + str(effect['amount']) + "-" + str(effect['amount2']) + " Range per sealed normal."
		StrikeEffects.RemoveBuddyNearOpponent:
			var offset_allowed = effect['offset_allowed']
			var same_space_allowed = effect['same_space_allowed']
			var optional = 'optional' in effect and effect['optional']
			var location_str = ""
			if same_space_allowed:
				location_str = "on"
			if offset_allowed == 1:
				if same_space_allowed:
					location_str += " or "
				location_str += "adjacent to"
			var begin_str = ""
			if optional:
				begin_str = "You may: "
			effect_str += "%sRemove %s %s opponent's space" % [begin_str, effect['buddy_name'], location_str]
		StrikeEffects.ReduceDiscardAmount:
			effect_str += "Reduce discard effects by %s" % effect['amount']
		StrikeEffects.RemoveXBuddies:
			effect_str += "Remove X %ss" % [effect['buddy_name']]
		StrikeEffects.RepeatEffectOptionally:
			effect_str += get_effect_text(effect['linked_effect'], false, false, false)
			var repeats = str(effect['amount'])
			if repeats != '0':
				if repeats == "every_two_sealed_normals":
					repeats = "once for every 2 sealed normals"
				elif repeats == "GAUGE_COUNT":
					repeats = "once for each gauge"
				else:
					repeats += " time(s)"
				effect_str += "; you may repeat this %s." % repeats
		StrikeEffects.ReplaceWildSwing:
			var previous_attack_to = effect.get("previous_attack_to", "discard")
			if previous_attack_to == "gauge":
				effect_str += "Add to Gauge and wild swing next card"
			else:
				effect_str += "Discard and wild swing next card"
		StrikeEffects.ReshuffleDiscardIntoDeck:
			effect_str += "Reshuffle discard pile into deck"
		StrikeEffects.Retreat:
			if 'combine_multiple_into_one' in effect and effect['combine_multiple_into_one']:
				effect_str += "Retreat that much."
			else:
				effect_str += "Retreat "
				if str(effect['amount']) == "strike_x":
					effect_str += "X"
				else:
					effect_str += str(effect['amount'])
		StrikeEffects.RetreatInternal:
			effect_str += "Retreat "
			if str(effect['amount']) == "strike_x":
				effect_str += "X"
			else:
				effect_str += str(effect['amount'])
		StrikeEffects.ReturnAttackToHand:
			if 'card_name' in effect:
				effect_str += "Return %s to hand" % effect['card_name']
			else:
				effect_str += "Return the attack to your hand"
		StrikeEffects.ReturnAttackToTopOfDeck:
			effect_str += "Return the attack to the top of your deck"
		StrikeEffects.ReturnThisBoostToHandStrikeEffect:
			if 'card_name' in effect:
				effect_str += "Return %s to hand" % effect['card_name']
			else:
				effect_str += "Return this to hand"
		StrikeEffects.ReturnThisToHandImmediateBoost:
			if 'card_name' in effect:
				effect_str += "Return %s to hand" % effect['card_name']
			else:
				effect_str += "Return this to hand"
		StrikeEffects.ReturnAllCardsGaugeToHand:
			effect_str += "Return all cards in gauge to hand."
		StrikeEffects.ReturnSealedWithSameSpeed:
			effect_str += "Return a sealed card with the same speed to hand."
		StrikeEffects.RevealCopyForAdvantage:
			effect_str += "Reveal a copy of this attack to Gain Advantage"
		StrikeEffects.RevealHand:
			if 'opponent' in effect and effect['opponent']:
				effect_str += "Reveal opponent hand"
			else:
				effect_str += "Reveal your hand"
		StrikeEffects.RevealHandAndTopdeck:
			if 'opponent' in effect and effect['opponent']:
				effect_str += "Reveal opponent hand and top card of deck"
			else:
				effect_str += "Reveal your hand and top card of deck"
		StrikeEffects.RevealTopdeck:
			if 'opponent' in effect and effect['opponent']:
				effect_str += "Reveal top card of opponent's deck"
			else:
				effect_str += "Reveal top card of deck"
		StrikeEffects.RevealStrike:
			effect_str += "Initiate face-up"
		StrikeEffects.Revert:
			effect_str += "Revert"
		StrikeEffects.SavePower:
			effect_str += "Your printed power becomes its Power"
		StrikeEffects.SkipEndOfTurnDraw:
			effect_str += "Skip your end of turn draw"
		StrikeEffects.UseSavedPowerAsPrintedPower:
			effect_str += "Your printed power is the revealed card's power"
		StrikeEffects.UseTopDiscardAsPrintedPower:
			effect_str += "Your printed power is the top discard's power"
		StrikeEffects.Say:
			pass
		StrikeEffects.SetDanDrawChoiceInternal:
			if effect['from_bottom']:
				effect_str += "Draw from bottom of deck"
			else:
				effect_str += "Draw from top of deck"
		StrikeEffects.SetStrikeX:
			if 'description' in effect:
				effect_str += effect['description']
			else:
				effect_str += "Set X to "
				match effect['source']:
					'random_gauge_power':
						effect_str += "power of random gauge card"
					'top_discard_power':
						effect_str += "power of top card of discards"
					'top_deck_power':
						effect_str += "power of top card of deck"
					'opponent_speed':
						effect_str += "opponent's speed"
					'cards_in_hand':
						effect_str += "number of cards in hand"
					'force_spent_before_strike':
						effect_str += "force spent"
					'gauge_spent_before_strike':
						effect_str += "gauge spent"
					'ultras_used_to_pay_gauge_cost':
						effect_str += "number of ultras used to pay cost"
					_:
						effect_str += "(UNKNOWN)"
		StrikeEffects.SetTotalPower:
			effect_str += "Your total power is %s" % effect['amount']
		StrikeEffects.SealAttackOnCleanup:
			effect_str += "Seal your attack on cleanup"
		StrikeEffects.SealThis:
			if card_name_source:
				effect_str += "Seal %s" % card_name_source
			else:
				effect_str += "Seal this"
		StrikeEffects.SealThisBoost:
			if card_name_source:
				effect_str += "Seal %s" % card_name_source
			else:
				effect_str += "Seal this"
		StrikeEffects.SealTopdeck:
			if 'card_name' in effect:
				effect_str += "Seal [color=%s]%s[/color] from the top of your deck" % [CardHighlightColor, effect['card_name']]
			else:
				effect_str += "Seal the top card of your deck"
		StrikeEffects.SelfDiscardChoose:
			var destination = effect['destination'] if 'destination' in effect else "discard"
			var limitation_str = ""
			var limitation = effect.get("limitation")
			if limitation:
				match limitation:
					"last_drawn_cards":
						limitation_str = " from last drawn"
					_:
						limitation_str = " " + effect['limitation']
			var bonus = ""
			var optional = 'optional' in effect and effect['optional']
			var optional_text = ""
			if optional:
				optional_text = "You may: "

			var amount_str = str(effect['amount'])
			if amount_str == "force_spent_before_strike":
				amount_str = "that many"
			if 'discard_effect' in effect:
				bonus= "\nfor: " + get_effect_text(effect['discard_effect'], false, false, false)
				if 'per_discard' in effect['discard_effect'] and effect['discard_effect']['per_discard']:
					bonus += " for each"
			if destination == "sealed":
				effect_str += optional_text + "Seal " + amount_str + limitation_str + " card(s)" + bonus
			elif destination == "reveal":
				effect_str += optional_text + "Reveal " + amount_str + limitation_str + " card(s)" + bonus
			elif destination == "opponent_overdrive":
				effect_str += optional_text + "Add " + amount_str + limitation_str + " card(s) from hand to your opponent's overdrive" + bonus
			else:
				effect_str += optional_text + "Discard " + amount_str + limitation_str + " card(s)" + bonus
		StrikeEffects.SetUsedCharacterBonus:
			if 'linked_effect' in effect:
				effect_str += ": " + get_effect_text(effect['linked_effect'], false, false, false)
		StrikeEffects.ShuffleHandToDeck:
			effect_str += "Shuffle hand into deck"
		StrikeEffects.ShuffleSealedToDeck:
			effect_str += "Shuffle sealed cards into deck"
		StrikeEffects.SidestepDialogue:
			effect_str += "Named card will not hit this strike"
		StrikeEffects.SpecificCardDiscardToGauge:
			effect_str += "Add a copy of %s from discard to Gauge" % effect['card_name']
		StrikeEffects.Speedup:
			if str(effect['amount']) == "strike_x":
				effect_str += "+X Speed"
			else:
				if effect['amount'] > 0:
					effect_str += "+"
				#else: str() converts it to - already.
					#effect_str += "-"
				effect_str += str(effect['amount']) + " Speed"
		StrikeEffects.SpeedupPerBoostInPlay:
			if 'all_boosts' in effect and effect['all_boosts']:
				effect_str += "+" + str(effect['amount']) + " Speed per EVERY boost in play."
			else:
				effect_str += "+" + str(effect['amount']) + " Speed per boost in play."
		StrikeEffects.SpeedupPerBoostModifier:
			if 'all_boosts' in effect and effect['all_boosts']:
				effect_str += "+" + str(effect['amount']) + " Speed per EVERY boost in play."
			else:
				effect_str += "+" + str(effect['amount']) + " Speed per boost in play."
		StrikeEffects.SpeedupPerForceSpentThisTurn:
			effect_str += "+" + str(effect['amount']) + " Speed per force spent this turn."
		StrikeEffects.SpendAllForceAndSaveAmount:
			effect_str += "Spend all hand/gauge as force"
		StrikeEffects.SpendAllGaugeAndSaveAmount:
			effect_str += "Discard all cards in gauge"
		StrikeEffects.SpendLife:
			effect_str += "Spend " + str(effect['amount']) + " life"
		StrikeEffects.StartOfTurnStrike:
			effect_str += "Strike"
		StrikeEffects.Strike:
			effect_str += "Strike"
		StrikeEffects.StrikeWild:
			effect_str += "Wild swing"
			if 'card_name' in effect:
				effect_str += " ([color=%s]%s[/color] on top of deck)" % [CardHighlightColor, effect['card_name']]
		"strike_with_buddy_card":
			effect_str += "%s ([color=%s]%s[/color])" % [effect["buddy_name"], CardHighlightColor, effect.get('card_name', "")]
		StrikeEffects.StrikeFaceup:
			effect_str += "Strike face-up"
		StrikeEffects.StrikeOpponentSetsFirst:
			effect_str += "Strike (opponent sets first)"
		StrikeEffects.StrikeRandomFromGauge:
			effect_str += "Strike with random card from gauge (opponent sets first)"
		StrikeEffects.StrikeResponseReading:
			if 'ex_card_id' in effect:
				effect_str += "EX Strike"
				if 'overload_name' in effect:
					effect_str += " (Overload: %s)" % effect['overload_name']
			else:
				effect_str += "Strike"
		StrikeEffects.StrikeWithEx:
			effect_str += "Strike with EX"
		StrikeEffects.StunImmunity:
			effect_str += "Stun Immunity"
		StrikeEffects.SustainAllBoosts:
			effect_str += "Sustain all boosts"
		StrikeEffects.SustainThis:
			if card_name_source:
				effect_str += "Sustain %s" % card_name_source
			else:
				effect_str += "Sustain this"
		StrikeEffects.SwapBuddy:
			effect_str += effect['description']
		StrikeEffects.SwapDeckAndSealed:
			effect_str += "Swap all sealed cards with deck"
		StrikeEffects.SwapPowerSpeed:
			effect_str += "Swap Power and Speed"
		StrikeEffects.TakeBonusActions:
			if 'use_simple_description' in effect and effect['use_simple_description']:
				effect_str += "Take another action."
			else:
				var amount = effect['amount']
				effect_str += "Take %s actions. Cannot cancel and striking ends turn." % str(amount)
		StrikeEffects.TakeDamage:
			var who_str = "Take"
			if 'opponent' in effect and effect['opponent']:
				who_str = "Deal"
			var nonlethal_str = ""
			if 'nonlethal' in effect and effect['nonlethal']:
				nonlethal_str = " nonlethal"
			effect_str += "%s %s%s damage" % [who_str, str(effect['amount']), nonlethal_str]
		StrikeEffects.TransformAttack:
			if 'card_name' in effect:
				effect_str += "Transform %s" % effect['card_name']
			else:
				effect_str += "Transform attack"
		StrikeEffects.TopdeckFromHand:
			effect_str += "Put a card from your hand on top of your deck"
		StrikeEffects.WhenHitForceForArmor:
			effect_str += ("When hit, generate %s for %s armor each." % [
					"gauge" if effect.get("use_gauge_instead", false) else "force",
					effect["amount"]])
		StrikeEffects.ZeroVectorDialogue:
			effect_str += "Named card is invalid for both players."
		_:
			effect_str += "MISSING EFFECT"
	return effect_str

func get_effect_text(effect, short = false, skip_timing = false, skip_condition = false, card_name_source : String = "", char_effect_panel : bool = false):
	if not card_name_source:
		if 'card_name' in effect:
			card_name_source = effect['card_name']
	var effect_str = ""
	if 'hide_effect' in effect and effect['hide_effect']:
		return effect_str
	if 'override_description' in effect:
		return effect['override_description']

	if 'timing' in effect and not skip_timing:
		effect_str += get_timing_text(effect['timing'])
	var effect_separator = ", "
	if char_effect_panel:
		effect_separator = "\n"

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

		effect_str += get_effect_type_text(effect, card_name_source, char_effect_panel)

	var suppress_and_description = 'suppress_and_description' in effect and effect['suppress_and_description']
	if 'and' in effect and effect['and'] and not suppress_and_description:
		if effect_str != "":
			if "use_semicolon_for_and" in effect and effect['use_semicolon_for_and']:
				effect_str += "; "
			else:
				effect_str += effect_separator
		effect_str += get_effect_text(effect['and'], short, false, false, card_name_source, char_effect_panel)
	if 'negative_condition_effect' in effect:
		if not 'suppress_negative_description' in effect or not effect['suppress_negative_description']:
			effect_str += "; otherwise " + get_effect_text(effect['negative_condition_effect'], short, skip_timing, false, card_name_source)

	# Remove unnecessary starting colons, e.g. from character_bonus effects
	if len(effect_str) >= 2 and effect_str.substr(0, 2) == ": ":
		effect_str = effect_str.substr(2)
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
		StrikeEffects.Strike:
			return "When you Exceed: Strike\n"
		StrikeEffects.Draw:
			return "When you Exceed: Draw %s" % on_exceed_ability['amount'] + "\n"
		_:
			return "MISSING_EXCEED_EFFECT\n"

func get_boost_text(effects):
	return get_effects_text(effects)
