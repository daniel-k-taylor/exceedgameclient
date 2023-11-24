extends Node

var card_data = []

var card_definitions_path = "res://data/card_definitions.json"
var decks_path = "res://data/decks"
var decks = []

func get_deck_test_deck():
	for deck in decks:
		if deck['id'] == "millia":
			return deck
	return get_random_deck()

func get_random_deck():
	# Randomize
	var random_index = randi() % len(decks)
	return decks[random_index]

func get_deck_from_str_id(str_id : String):
	if str_id == "random":
		return get_random_deck()
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
		"before":
			text += "[b]Before:[/b] "
		"cleanup":
			text += "[b]Cleanup:[/b] "
		"during_strike":
			text += ""
		"hit":
			text += "[b]Hit:[/b] "
		"immediate":
			text += ""
		"now":
			text += "[b]Now:[/b] "
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
		_:
			text += "MISSING TIMING"
	return text

func get_condition_text(condition):
	var text = ""
	match condition:
		"advanced_through":
			text += "If advanced past opponent, "
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
		"not_canceled_this_turn":
			text += "If not canceled this turn, "
		"not_full_push":
			text += "If not full push, "
		"not_full_close":
			text += "If not full close, "
		"not_initiated_strike":
			text += "If opponent initiated strike, "
		"not_stunned":
			text += "If not stunned, "
		"opponent_stunned":
			text += "If opponent stunned, "
		"pulled_past":
			text += "If pulled opponent past you, "
		"used_character_action":
			text += ""
		"is_special_attack":
			text += ""
		"is_normal_attack":
			text += ""
		"was_wild_swing":
			text += "If this was a wild swing, "
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
		"advance":
			effect_str += "Advance " + str(effect['amount'])
		"armorup":
			effect_str += "+" + str(effect['amount']) + " Armor"
		"attack_is_ex":
			effect_str += "Next Strike is EX"
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
		"choice":
			effect_str += "Choose: " + get_choice_summary(effect['choice'], card_name_source)
		"choose_discard":
			if effect['limitation']:
				effect_str += "Choose a %s card from discard to move to %s" % [effect['limitation'], effect['destination']]
			else:
				effect_str += "Choose a card from discard to move to %s" % [effect['destination']]
		"choose_sustain_boost":
			effect_str += "Choose a boost to sustain."
		"close":
			effect_str += "Close " + str(effect['amount'])
		"discard_this":
			effect_str += "Discard this"
		"discard_continuous_boost":
			effect_str += "Discard a continuous boost"
		"discard_opponent_gauge":
			effect_str += "Discard a card from opponent's gauge."
		"discard_opponent_topdeck":
			effect_str += "Discard a card from the top of the opponent's deck"
		"dodge_at_range":
			if effect['range_min'] == effect['range_max']:
				effect_str += "Opponent attacks miss at range %s." % effect['range_min']
			else:
				effect_str += "Opponent attacks miss at range %s-%s." % [effect['range_min'], effect['range_max']]
		"dodge_attacks":
			effect_str += "Opponent misses."
		"draw":
			effect_str += "Draw " + str(effect['amount'])
		"exceed_now":
			effect_str += "Exceed"
		"force_for_effect":
			effect_str += get_force_for_effect_summary(effect, card_name_source)
		"gauge_for_effect":
			effect_str += get_gauge_for_effect_summary(effect, card_name_source)
		"gain_advantage":
			effect_str += "Gain Advantage"
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
		"lose_all_armor":
			effect_str += "Lose all armor"
		"name_card_opponent_discards":
			effect_str += "Name a card. Opponent discards it or reveals not in hand."
		"nothing":
			effect_str += ""
		"opponent_discard_choose":
			effect_str += "Opponent discards " + str(effect['amount']) + " cards."
		"opponent_discard_random":
			effect_str += "Opponent discards " + str(effect['amount']) + " random cards."
		"opponent_wild_swings":
			effect_str += "Opponent wild swings."
		"pass":
			effect_str += "Pass"
		"powerup":
			if effect['amount'] > 0:
				effect_str += "+"
			effect_str += str(effect['amount']) + " Power"
		"powerup_per_boost_in_play":
			effect_str += "+" + str(effect['amount']) + " Power per boost in play."
		"powerup_damagetaken":
			effect_str += "+" + str(effect['amount']) + " Power per damage taken this strike."
		"powerup_opponent":
			effect_str += "+" + str(effect['amount']) + " Opponent's Power"
		"pull":
			effect_str += "Pull " + str(effect['amount'])
		"push":
			effect_str += "Push " + str(effect['amount'])
		"rangeup":
			effect_str += "+" + str(effect['amount']) + "-" + str(effect['amount2']) + " Range"
		"rangeup_per_boost_in_play":
			effect_str += "+" + str(effect['amount']) + "-" + str(effect['amount2']) + " Range per boost in play."
		"retreat":
			effect_str += "Retreat " + str(effect['amount'])
		"return_attack_to_hand":
			effect_str += "Return the attack to your hand"
		"return_this_to_hand":
			effect_str += "Return this card to hand."
		"return_all_cards_gauge_to_hand":
			effect_str += "Return all cards in gauge to hand."
		"reveal_hand":
			effect_str += "Reveal your hand"
		"self_discard_choose":
			effect_str += "Discard " + str(effect['amount']) + " cards."
		"speedup":
			if effect['amount'] > 0:
				effect_str += "+"
			#else: str() converts it to - already.
				#effect_str += "-"
			effect_str += str(effect['amount']) + " Speed"
		"stun_immunity":
			effect_str += "Stun Immunity"
		"sustain_this":
			if card_name_source:
				effect_str += "Sustain %s" % card_name_source
			else:
				effect_str += "Sustain this"
		"take_bonus_actions":
			var amount = effect['amount']
			effect_str += "Take %s actions. Cannot cancel and striking ends turn." % str(amount)
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

	if 'condition' in effect and not skip_condition:
		effect_str += get_condition_text(effect['condition'])

	effect_str += get_effect_type_text(effect, card_name_source)

	if not short and 'bonus_effect' in effect:
		effect_str += "; " + get_effect_text(effect['bonus_effect'], skip_timing, false, card_name_source)
	if 'and' in effect:
		effect_str += ", " + get_effect_text(effect['and'], short, skip_timing, false, card_name_source)
	return effect_str

func get_effects_text(effects):
	var effects_str = ""
	for effect in effects:
		effects_str += get_effect_text(effect) + "\n"
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
