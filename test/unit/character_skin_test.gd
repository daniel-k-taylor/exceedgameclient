extends GutTest

# Tests for the cosmetic character-skin system.
#
# This project imports the skin SYSTEM and cosmetic-only skin deck JSON, but does
# NOT import skin art (character animations / skin portraits). Every skin therefore
# degrades to its base character's visuals, which these tests assert directly.
#
# The CharSkinManager is intended to be an autoload. That autoload registration is
# handled as a separate integration step, so this test registers the manager at
# /root/CharSkinManager itself, which also mirrors how CardDataManager resolves it.

const CharSkinManagerScript = preload("res://globals/char_skin_manager.gd")

var _owns_skin_manager := false

func before_all():
	if not get_tree().root.has_node("CharSkinManager"):
		var manager = CharSkinManagerScript.new()
		manager.name = "CharSkinManager"
		get_tree().root.add_child(manager)
		_owns_skin_manager = true

func after_all():
	if _owns_skin_manager and get_tree().root.has_node("CharSkinManager"):
		get_tree().root.get_node("CharSkinManager").free()

func _skin_manager() -> Node:
	return get_tree().root.get_node("CharSkinManager")

# --- Deck id <-> base character <-> skin index ---

func test_skin_deck_id_composition():
	var manager = _skin_manager()
	assert_eq(manager.get_skin_deck_id("ryu", 1), "ryu_1")
	assert_eq(manager.get_skin_deck_id("ryu", 0), "ryu")
	assert_eq(manager.get_skin_deck_id("ryu", 5), "ryu")  # index beyond count
	assert_eq(manager.get_skin_deck_id("random", 1), "random")
	assert_eq(manager.get_skin_deck_id("custom_deck", 1), "custom_deck")

func test_base_character_id_resolution():
	var manager = _skin_manager()
	assert_eq(manager.get_base_character_id("ryu_1"), "ryu")
	assert_eq(manager.get_base_character_id("ryu"), "ryu")
	assert_eq(manager.get_base_character_id("unknown_9"), "unknown_9")

func test_skin_index_and_counts():
	var manager = _skin_manager()
	assert_eq(manager.get_skin_index_for_deck_id("ryu_1"), 1)
	assert_eq(manager.get_skin_index_for_deck_id("ryu"), 0)
	assert_eq(manager.get_skin_count("ryu"), 1)
	assert_eq(manager.get_total_button_count("ryu"), 2)
	assert_eq(manager.get_skin_count("nonexistent"), 0)

func test_button_labels_are_english():
	var manager = _skin_manager()
	assert_eq(manager.get_button_label("ryu", 0), "Original")
	assert_eq(manager.get_button_label("ryu", 1), "Skin 1")

# --- Portrait resolution & graceful degradation ---

func test_skin_without_portrait_override_uses_base_character_portrait():
	assert_eq(
		_skin_manager().get_portrait_path_for_deck_id("ryu_1"),
		"res://assets/portraits/ryu.png")

func test_missing_character_portrait_uses_global_fallback():
	assert_eq(
		_skin_manager().get_portrait_path_for_deck_id("missing_portrait_character"),
		"res://assets/portraits/custom.png")
	assert_not_null(_skin_manager().load_portrait_texture_for_deck_id("missing_portrait_character"))

func test_missing_skin_portrait_override_uses_base_character_portrait():
	var manager = _skin_manager()
	var skin_config = manager.CHARACTER_SKINS["ryu"]["skins"][1]
	var original_portraits_skin = skin_config.get("portraits_skin")
	var original_url = skin_config.get("portraits_url", "")
	skin_config["portraits_skin"] = true
	skin_config["portraits_url"] = "res://assets/portraits_skin/does_not_exist.png"

	assert_eq(manager.get_portrait_path_for_deck_id("ryu_1"), "res://assets/portraits/ryu.png")

	skin_config["portraits_skin"] = original_portraits_skin
	skin_config["portraits_url"] = original_url

# --- Animation resolution & graceful degradation (no skin art imported) ---

func test_skin_animation_degrades_to_base_when_art_absent():
	var manager = _skin_manager()
	# ryu's skin declares animations_skin, but no skin art is imported, so it
	# must fall back to the base character animation folder.
	assert_true(manager.uses_skin_animation_for_deck_id("ryu_1"))
	assert_eq(
		manager.get_animation_path_for_deck_id("ryu_1"),
		"res://assets/character_animations/ryu/animations.tres")

func test_animations_skin_false_uses_base_character_folder():
	assert_eq(
		_skin_manager().get_animation_path_for_deck_id("cammy_1"),
		"res://assets/character_animations/cammy/animations.tres")

func test_exceed_change_skin_defaults_off_for_imported_skins():
	assert_false(_skin_manager().exceed_changes_skin_for_deck_id("ryu_1"))

func test_non_skin_deck_uses_official_animation_folder():
	assert_eq(
		_skin_manager().get_animation_path_for_deck_and_animation_id("ryu", "ryu"),
		"res://assets/character_animations/ryu/animations.tres")

func test_buddy_graphics_degrade_to_base_folder_without_skin_art():
	# Even if a skin enables buddy_skin, missing skin art falls back to the base
	# buddy animation folder (using a real buddy graphics id).
	var manager = _skin_manager()
	var skin_config = manager.CHARACTER_SKINS["ryu"]["skins"][1]
	var original_animations = skin_config.get("animations_skin")
	var original_buddy = skin_config.get("buddy_skin")
	skin_config["animations_skin"] = true
	skin_config["buddy_skin"] = true

	assert_eq(
		manager.get_animation_path_for_deck_and_animation_id("ryu_1", "rachel_georgexiii"),
		"res://assets/character_animations/rachel_georgexiii/animations.tres")

	skin_config["animations_skin"] = original_animations
	skin_config["buddy_skin"] = original_buddy

# --- Skin deck JSON loading & validation ---

func test_imported_skin_deck_loads_with_base_id():
	var skin_deck = CardDataManager.get_deck_from_str_id("ryu_1")
	assert_not_null(skin_deck)
	if not skin_deck:
		return
	assert_eq(skin_deck["id"], "ryu_1")
	assert_eq(skin_deck["base_id"], "ryu")

func test_imported_skin_deck_is_mechanically_identical_to_base():
	var skin_deck = CardDataManager.get_deck_from_str_id("ryu_1")
	var base_deck = CardDataManager.get_deck_from_str_id("ryu")
	assert_not_null(skin_deck)
	assert_not_null(base_deck)
	if not skin_deck or not base_deck:
		return
	assert_eq(skin_deck["exceed_cost"], base_deck["exceed_cost"])
	assert_eq(skin_deck["cards"], base_deck["cards"])
	assert_eq(skin_deck["ability_effects"], base_deck["ability_effects"])
	assert_eq(skin_deck["exceed_ability_effects"], base_deck["exceed_ability_effects"])
	assert_eq(skin_deck["character_action_default"], base_deck["character_action_default"])
	assert_eq(skin_deck.get("starting_life"), base_deck.get("starting_life"))

func test_skin_filename_validation_rules():
	# Valid: filename prefix matches JSON id + positive integer index.
	assert_true(CardDataManager._is_valid_skin_deck_file("ryu_1.json", {"id": "ryu"}, false))
	# Prefix must match the JSON id.
	assert_false(CardDataManager._is_valid_skin_deck_file("ino_1.json", {"id": "ryu"}, false))
	# Index must be a positive integer.
	assert_false(CardDataManager._is_valid_skin_deck_file("ryu_0.json", {"id": "ryu"}, false))
	assert_false(CardDataManager._is_valid_skin_deck_file("ryu_01.json", {"id": "ryu"}, false))
	# Base character deck must exist.
	assert_false(CardDataManager._is_valid_skin_deck_file("missingcharacter_1.json", {"id": "missingcharacter"}, false))

func test_random_selection_excludes_skin_decks():
	assert_true(CardDataManager._is_random_selectable_deck(CardDataManager.get_deck_from_str_id("ryu")))
	assert_false(CardDataManager._is_random_selectable_deck(CardDataManager.get_deck_from_str_id("ryu_1")))
	assert_true(CardDataManager._is_random_selectable_deck(CardDataManager.get_deck_from_str_id("cammy")))
	assert_false(CardDataManager._is_random_selectable_deck(CardDataManager.get_deck_from_str_id("cammy_1")))

func test_rejected_rebalanced_skins_not_loaded():
	# These skins baked in gameplay changes in the source fork and were rejected;
	# they must not exist as loadable decks here.
	assert_false(CardDataManager.decks.has("specter_1"))
	assert_false(CardDataManager.decks.has("tinker_1"))
	assert_false(CardDataManager.decks.has("mika_1"))
	assert_false(CardDataManager.decks.has("taokaka_1"))
