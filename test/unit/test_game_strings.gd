extends GutTest

# Ability and card text is generated at runtime from the deck/card JSON. A
# renderer branch that is only reached by one character (Mei Lien's
# copy_of_attack_in_zones) can sit broken indefinitely, because nothing else
# exercises it. Rendering the whole roster catches those the moment a
# character or card is added.

const BAD_MARKERS = [
	"<null>",
	"Nil",
	"MISSING TIMING",
	"MISSING CONDITION",
	"MISSING_EXCEED_EFFECT",
]

# Effect types that have no written description yet. This is a pre-existing
# backlog, not an intentional state: every entry renders as "MISSING EFFECT"
# wherever the game shows generated rules text. It is pinned here so the list
# can only ever shrink -- a new unwritten effect fails the test, and so does a
# stale entry once someone writes its text.
const KNOWN_UNWRITTEN_EFFECTS = [
	"add_boost_to_gauge_on_move",
	"add_recursive_choice_for_opponent",
	"armorup_per_continuous_boost",
	"armorup_times_gauge",
	"attack_copy_gauge_or_transform_becomes_ex",
	"boost_applies_if_on_buddy",
	"boost_as_overdrive",
	"boost_discarded_overdrive",
	"boost_from_extra",
	"boost_from_gauge",
	"bottomdeck_from_hand",
	"buddy_immune_to_flip",
	"can_spend_life_for_force",
	"cap_attack_damage_taken",
	"choose_cards_from_top_deck",
	"discard_boost_in_opponent_space",
	"discard_hand",
	"discard_stored_cards",
	"discard_to",
	"dodge_normals",
	"draw_cards_under_boost_and_remove",
	"draw_for_card_in_hand",
	"draw_or_discard_to",
	"enable_boost_from_gauge",
	"enable_end_of_turn_draw",
	"exceed_end_of_turn",
	"exceed_opponent_now",
	"generate_free_force_cc_only",
	"give_to_player",
	"guardup_if_copy_of_opponent_attack_in_sealed",
	"higher_speed_misses",
	"immediate_force_for_armor",
	"increase_gauge_spent_before_strike",
	"may_generate_gauge_with_force",
	"may_ignore_movement_limit",
	"may_invalidate_ultras",
	"minato_hellraiser",
	"minato_one_more_ride",
	"move_any_boost",
	"move_to_lightningrods",
	"multiply_speed_bonuses",
	"name_range",
	"only_hits_if_opponent_on_any_buddy",
	"opponent_cant_move_if_in_range",
	"opponent_cant_move_past_buddy",
	"opponent_discard_normals_or_reveal",
	"passive_powerup_per_card_in_hand",
	"passive_speedup_per_card_in_hand",
	"place_buddy_onto_opponent",
	"play_boost_with_cards_under",
	"power_armor_up_if_sealed_or_transformed_copy_of_attack",
	"power_modify_per_buddy_between",
	"powerup_per_sealed_amount",
	"powerup_per_transform",
	"pull_not_past",
	"range_includes_lightningrods",
	"reading_normal",
	"remove_force_costs_reduced_passive",
	"remove_generate_free_force",
	"remove_opponent_cant_move_past_buddy",
	"repeat_printed_triggers_on_ex_attack",
	"return_all_copies_of_top_discard_to_hand",
	"seal_discard",
	"seal_hand",
	"seal_instead_of_discarding",
	"set_dan_draw_choice",
	"set_enchantress_draw_choice",
	"set_end_of_turn_boost_delay",
	"set_face_attack",
	"set_life_per_gauge",
	"set_max_hand_size",
	"shuffle_deck",
	"shuffle_discard_in_place",
	"shuffle_into_deck_from_hand",
	"sidestep_transparent_foe",
	"specials_invalid",
	"specific_card_discard_to_hand",
	"specific_card_seal_from_gauge",
	"speedup_amount_in_gauge",
	"speedup_by_spaces_modifier",
	"speedup_per_unique_sealed_normals",
	"strike_effect_after_opponent_sets",
	"strike_effect_after_setting",
	"strike_from_gauge",
	"strike_from_sealed",
	"strike_with_deus_ex_machina",
	"switch_spaces_with_buddy",
	"zero_vector",
]

func _collect_effect_types(effects, found : Dictionary):
	if effects is Array:
		for entry in effects:
			_collect_effect_types(entry, found)
	elif effects is Dictionary:
		if 'effect_type' in effects and effects['effect_type'] is String:
			# Keep a real effect dictionary: some renderer branches read sibling
			# keys, so a synthetic {"effect_type": x} would crash rather than
			# report a missing description.
			if not (effects['effect_type'] in found):
				found[effects['effect_type']] = effects
		for key in effects:
			_collect_effect_types(effects[key], found)

func _complain_about(text : String, where : String, problems : Array):
	for marker in BAD_MARKERS:
		if marker in text:
			problems.append("%s -> %s in %s" % [where, marker, text])

func test_meilien_ability_text_names_the_zones_it_checks():
	var deck = CardDataManager.get_deck_from_str_id("meilien")
	var text = GameStrings.get_effects_text(deck['ability_effects'])
	assert_string_contains(text, "If copy of attack in discard,")
	assert_string_contains(text, "If copy of attack in gauge,")

func test_meilien_exceed_ability_text_names_the_zones_it_checks():
	var deck = CardDataManager.get_deck_from_str_id("meilien")
	var text = GameStrings.get_effects_text(deck['exceed_ability_effects'])
	assert_string_contains(text, "If copy of attack in discard,")
	assert_string_contains(text, "If copy of attack in gauge,")

func test_multi_zone_conditions_are_joined_for_reading():
	var text = GameStrings.get_condition_text({
		"condition": "copy_of_attack_in_zones",
		"condition_zones": ["gauge", "transform", "sealed"],
	}, 0, 0, "")
	assert_eq(text, "If copy of attack in gauge/transform/sealed, ")

func test_every_character_ability_renders_cleanly():
	var problems = []
	for deck_id in CardDataManager.decks:
		var deck = CardDataManager.decks[deck_id]
		for label in ["ability_effects", "exceed_ability_effects"]:
			if not (label in deck):
				continue
			var text = GameStrings.get_effects_text(deck[label])
			_complain_about(text, "%s/%s" % [deck_id, label], problems)
	assert_eq(problems, [], "character ability text should be readable")

func test_every_character_action_renders_cleanly():
	var problems = []
	for deck_id in CardDataManager.decks:
		var deck = CardDataManager.decks[deck_id]
		for label in ["character_action_default", "character_action_exceeded"]:
			if not (label in deck):
				continue
			for action in deck[label]:
				if not (action is Dictionary) or not ('effects' in action):
					continue
				var text = GameStrings.get_effects_text(action['effects'])
				_complain_about(text, "%s/%s" % [deck_id, label], problems)
	assert_eq(problems, [], "character action text should be readable")

func test_every_card_definition_renders_cleanly():
	var problems = []
	for definition_id in CardDataManager.card_data:
		var card = CardDataManager.card_data[definition_id]
		if 'effects' in card:
			_complain_about(GameStrings.get_effects_text(card['effects']),
				"%s/effects" % definition_id, problems)
		if 'boost' in card and 'effects' in card['boost']:
			_complain_about(GameStrings.get_effects_text(card['boost']['effects']),
				"%s/boost" % definition_id, problems)
	assert_eq(problems, [], "card text should be readable")

func _all_effect_types() -> Dictionary:
	# Read the shipped data straight from disk. Other test scripts register
	# custom decks into CardDataManager, and that leaked state would otherwise
	# change this list depending on which tests ran first.
	var found = {}
	_collect_effect_types(
		CardDataManager.load_json_file(CardDataManager.card_definitions_path), found)
	for path in [CardDataManager.decks_path, CardDataManager.skin_decks_path]:
		for deck_file in DirAccess.get_files_at(path):
			if deck_file[0] == "_":
				continue
			_collect_effect_types(
				CardDataManager.load_json_file(path + "/" + deck_file), found)
	return found

func test_unwritten_effect_descriptions_match_the_known_backlog():
	var found = _all_effect_types()
	var effect_types = found.keys()
	effect_types.sort()
	var unwritten = []
	for effect_type in effect_types:
		var text = GameStrings.get_effect_type_text(found[effect_type])
		if "MISSING EFFECT" in text:
			unwritten.append(effect_type)
	var expected = KNOWN_UNWRITTEN_EFFECTS.duplicate()
	expected.sort()
	var newly_missing = []
	for effect_type in unwritten:
		if effect_type not in expected:
			newly_missing.append(effect_type)
	var now_written = []
	for effect_type in expected:
		if effect_type not in unwritten:
			now_written.append(effect_type)
	assert_eq(newly_missing, [],
		"these effects newly lack rules text and need a GameStrings entry")
	assert_eq(now_written, [],
		"these effects now have rules text; remove them from KNOWN_UNWRITTEN_EFFECTS")
