extends Node

var card_data = []

var card_definitions_path = "res://data/card_definitions.json"
var decks_path = "res://data/decks"
var decks = []

const SelectorIndexToDeckId = {
	0: "ramlethal",
	1: "kykisuke",
	2: "solbadguy",
	3: "random",
}

func get_deck_from_selector_index(index : int):
	for deck in decks:
		if deck['id'] == SelectorIndexToDeckId[index]:
			return deck

	# Randomize
	var random_index = randi() % len(decks)
	return decks[random_index]

func get_deck_from_str_id(str_id : String):
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
		var deck_data = load_json_file(decks_path + "/" + deck_file)
		if deck_data:
			decks.append(deck_data)

func get_card(definition_id):
	for card in card_data:
		if card['id'] == definition_id:
			return card
	return null

class EffectSummary:
	var effect
	var min_value = null
	var max_value = null

func get_choice_summary(choice):
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

		if 'amount' in effect:
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
			summary_text += get_effect_type_text(effect_summary.effect)
		if 'bonus_effect' in effect_summary.effect:
			summary_text += "; " + get_effect_text(effect_summary.effect['bonus_effect'])
	return summary_text

func get_timing_text(timing):
	var text = ""
	match timing:
		"after":
			text += "[b]After:[/b] "
		"before":
			text += "[b]Before:[/b] "
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
		_:
			text += "MISSING TIMING"
	return text

func get_condition_text(condition):
	var text = ""
	match condition:
		"advanced_through":
			text += "If advanced past opponent, "
		"canceled_this_turn":
			text += "If canceled this turn, "
		"initiated_strike":
			text += "If initiated strike, "
		"not_canceled_this_turn":
			text += "If not canceled this turn, "
		"not_full_push":
			text += "If not full push, "
		"not_full_close":
			text += "If not full close, "
		"not_initiated_strike":
			text += "If opponent initiated strike, "
		"opponent_stunned":
			text += "If opponent stunned, "
		"pulled_past":
			text += "If pulled opponent past you, "
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
		"push":
			effect_str += "Push "
		"retreat":
			effect_str += "Retreat "
		_:
			effect_str += "MISSING EFFECT HEADING"
	return effect_str

func get_effect_type_text(effect):
	var effect_str = ""
	var effect_type = effect['effect_type']
	match effect_type:
		"add_boost_to_gauge_on_strike_cleanup":
			effect_str += "Add card to gauge."
		"add_strike_to_gauge_after_cleanup":
			effect_str += "Add card to gauge after strike."
		"add_to_gauge_boost_play_cleanup":
			effect_str += "Add card to gauge."
		"add_to_gauge_immediately":
			effect_str += "Add card to gauge."
		"advance":
			effect_str += "Advance " + str(effect['amount'])
		"armorup":
			effect_str += "+" + str(effect['amount']) + " Armor"
		"attack_is_ex":
			effect_str += "Next Strike is EX."
		"bonus_action":
			effect_str += "Take another action."
		"choice":
			effect_str += "Choose: " + get_choice_summary(effect['choice'])
		"close":
			effect_str += "Close " + str(effect['amount'])
		"discard_continuous_boost":
			effect_str += "Discard a continuous boost."
		"dodge_attacks":
			effect_str += "Opponent misses."
		"draw":
			effect_str += "Draw " + str(effect['amount'])
		"gain_advantage":
			effect_str += "Gain Advantage."
		"gauge_from_hand":
			effect_str += "Add a card from hand to gauge."
		"guardup":
			effect_str += "+" + str(effect['amount']) + " Guard"
		"ignore_armor":
			effect_str += "Ignore armor."
		"ignore_guard":
			effect_str += "Ignore guard."
		"ignore_push_and_pull":
			effect_str += "Ignore Push and Pull."
		"name_card_opponent_discards":
			effect_str += "Name a card. Opponent discards it or reveals not in hand."
		"opponent_discard_random":
			effect_str += "Opponent discards " + str(effect['amount']) + " random cards."
		"opponent_wild_swings":
			effect_str += "Opponent wild swings."
		"pass":
			effect_str += "Pass"
		"powerup":
			effect_str += "+" + str(effect['amount']) + " Power"
		"pull":
			effect_str += "Pull " + str(effect['amount'])
		"push":
			effect_str += "Push " + str(effect['amount'])
		"rangeup":
			effect_str += "+" + str(effect['amount']) + "-" + str(effect['amount2']) + " Range"
		"retreat":
			effect_str += "Retreat " + str(effect['amount'])
		"speedup":
			effect_str += "+" + str(effect['amount']) + " Speed"
		"when_hit_force_for_armor":
			effect_str += "When hit, generate force for " + str(effect['amount']) + " armor each."
		_:
			effect_str += "MISSING EFFECT"
	return effect_str

func get_effect_text(effect, short = false):
	var effect_str = ""
	if 'timing' in effect:
		effect_str += get_timing_text(effect['timing'])

	if 'condition' in effect:
		effect_str += get_condition_text(effect['condition'])

	effect_str += get_effect_type_text(effect)

	if not short and 'bonus_effect' in effect:
		effect_str += "; " + get_effect_text(effect['bonus_effect'])
	if 'and' in effect:
		effect_str += ", " + get_effect_text(effect['and'], short)
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
