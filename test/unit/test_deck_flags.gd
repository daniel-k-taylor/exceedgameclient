extends GutTest

# Character-specific behavior is driven by flags on the deck definition rather than
# by comparing a deck's id against a hardcoded character name. Two things make the
# id comparison actively wrong:
#   1. Skin decks have their id replaced with the skin filename (e.g. "bison_1"),
#      so every `deck_def.id == "bison"` check silently evaluates false for a skin.
#   2. Flags can be reused or retuned from data; an id check cannot.
# These tests pin both the convention and the inheritance that makes it work.

const SCAN_DIRS = ["res://scenes", "res://globals"]

# Matches deck_def.id == "someone" / deck_def['id'] != 'someone' and the reversed form.
const DECK_ID_COMPARE_PATTERN = "(?:deck_def|deck_data)\\s*(?:\\[\\s*['\"]id['\"]\\s*\\]|\\.id)\\s*(?:==|!=)\\s*['\"][a-z0-9_]+['\"]"
const DECK_ID_COMPARE_PATTERN_REVERSED = "['\"][a-z0-9_]+['\"]\\s*(?:==|!=)\\s*(?:deck_def|deck_data)\\s*(?:\\[\\s*['\"]id['\"]\\s*\\]|\\.id)"

func _gather_scripts(dir_path : String, found : Array) -> void:
	var dir = DirAccess.open(dir_path)
	if not dir:
		return
	for file_name in dir.get_files():
		if file_name.ends_with(".gd"):
			found.append(dir_path + "/" + file_name)
	for sub_dir in dir.get_directories():
		_gather_scripts(dir_path + "/" + sub_dir, found)

func test_engine_has_no_hardcoded_deck_id_comparisons():
	var forward = RegEx.new()
	assert_eq(forward.compile(DECK_ID_COMPARE_PATTERN), OK)
	var reversed = RegEx.new()
	assert_eq(reversed.compile(DECK_ID_COMPARE_PATTERN_REVERSED), OK)

	var scripts = []
	for scan_dir in SCAN_DIRS:
		_gather_scripts(scan_dir, scripts)
	assert_gt(scripts.size(), 0, "Expected to find engine scripts to scan.")

	var offenders = []
	for script_path in scripts:
		var file = FileAccess.open(script_path, FileAccess.READ)
		if not file:
			continue
		var line_number = 0
		while not file.eof_reached():
			var line = file.get_line()
			line_number += 1
			var trimmed = line.strip_edges()
			if trimmed.begins_with("#"):
				continue
			if forward.search(trimmed) or reversed.search(trimmed):
				offenders.append("%s:%d  %s" % [script_path, line_number, trimmed])

	assert_eq(offenders.size(), 0,
		"Use a deck flag instead of comparing a deck id to a character name (breaks for skins):\n" + "\n".join(offenders))

func test_skin_deck_inherits_gameplay_flags_from_base_deck():
	# bison_1 is a reskin of bison. Its id is "bison_1", so any id-based check would
	# miss it; it must still carry bison's gameplay flags.
	var skin_deck = CardDataManager.get_deck(&"bison_1")
	assert_false(skin_deck.is_empty(), "Expected the bison_1 skin deck to be loaded.")
	assert_eq(skin_deck.get("base_id"), "bison", "Skin deck should record its base character.")

	var base_deck = CardDataManager.get_deck(&"bison")
	assert_false(base_deck.is_empty(), "Expected the bison base deck to be loaded.")
	assert_eq(
		skin_deck.get("ai_skip_character_action_above_gauge"),
		base_deck.get("ai_skip_character_action_above_gauge"),
		"Skin deck should inherit gameplay flags added to its base deck.")

func test_every_skin_deck_inherits_all_base_gameplay_flags():
	var skipped_keys = ["id", "base_id"]
	var missing = []
	for deck_id in CardDataManager.decks:
		var deck = CardDataManager.decks[deck_id]
		var base_id = str(deck.get("base_id", ""))
		if base_id == "" or base_id == str(deck_id):
			continue # Not a skin.
		var base_deck = CardDataManager.decks.get(base_id, {})
		for key in base_deck:
			if key in skipped_keys:
				continue
			if not (key in deck):
				missing.append("%s is missing '%s' from base deck %s" % [deck_id, key, base_id])
	assert_eq(missing.size(), 0, "Skin decks must inherit every base deck key:\n" + "\n".join(missing))

func test_character_flags_are_present_on_expected_decks():
	# Spot-check the flags that replaced id comparisons, so a rename or a dropped
	# key fails loudly here instead of silently disabling a character's ability.
	var expected_flags = {
		"minato": ["seal_discards_at_turn_start_when_exceeded", "discards_count_as_force_until_exceed",
			"discards_per_gauge_until_exceed", "can_seal_discards_for_resources"],
		"tournelouse": ["normals_are_transforms_until_exceed"],
		"renea": ["facedown_boosts_delay_effects", "boost_from_stored_zone_grants_action_when_exceeded"],
		"eugenia": ["opponent_discard_passive", "face_attack_bonus_when_exceeded", "face_attack_forbids_ex",
			"transform_zone_rejects_opponent_cards_when_exceeded"],
		"zsolt": ["exceed_extra_attack_limit"],
		"syrus": ["immediate_boosts_become_replacement"],
		"luciya": ["spent_gauge_becomes_boost_when_exceeded"],
		"bison": ["ai_skip_character_action_above_gauge"],
		"umina": ["dreamlands_config"],
		"chaos": ["warn_when_striking_without_character_action"],
	}
	for deck_id in expected_flags:
		var deck = CardDataManager.get_deck(deck_id)
		assert_false(deck.is_empty(), "Expected deck '%s' to exist." % deck_id)
		for flag_name in expected_flags[deck_id]:
			assert_true(flag_name in deck, "Deck '%s' should define flag '%s'." % [deck_id, flag_name])

func test_minato_discards_per_gauge_floors_to_whole_gauge():
	# This flag replaced a hardcoded `int(discards.size() / 3.0)`, so the divisor must
	# still floor rather than round.
	var deck = CardDataManager.get_deck("minato")
	assert_eq(deck.get("discards_per_gauge_until_exceed"), 3)
