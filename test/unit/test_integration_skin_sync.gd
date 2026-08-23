extends GutTest

# Verifies the "implicit skin sync" property that T3 must preserve: selecting a
# cosmetic skin resolves to a deck id ("<char>_<index>") that both loads as a real
# deck AND flows through the normal game-start payload unchanged (no protocol
# change). Missing skin art degrades to the base character.

func _skin_manager() -> Node:
	return get_node_or_null("/root/CharSkinManager")

func test_char_skin_manager_is_autoloaded():
	assert_not_null(_skin_manager(), "CharSkinManager must be registered as an autoload")

func test_base_selection_resolves_to_base_deck_id():
	var manager = _skin_manager()
	# Index 0 is always the base look.
	assert_eq(manager.get_skin_deck_id("ryu", 0), "ryu")

func test_skin_selection_resolves_to_skin_deck_id():
	var manager = _skin_manager()
	if manager.get_skin_count("ryu") <= 0:
		pass_test("No ryu skins registered; nothing to resolve")
		return
	assert_eq(manager.get_skin_deck_id("ryu", 1), "ryu_1")

func test_resolved_skin_deck_id_loads_a_real_deck():
	var manager = _skin_manager()
	if manager.get_skin_count("ryu") <= 0:
		pass_test("No ryu skins registered")
		return
	var skin_deck_id = manager.get_skin_deck_id("ryu", 1)
	# This is exactly what main_menu feeds into the game-start payload, so it must
	# resolve to a loadable deck object.
	var deck = CardDataManager.get_deck_from_str_id(skin_deck_id)
	assert_not_null(deck, "Skin deck id %s must load a deck" % skin_deck_id)
	assert_eq(deck["id"], skin_deck_id)

func test_random_and_custom_selections_are_never_skinned():
	var manager = _skin_manager()
	assert_eq(manager.get_skin_deck_id("random", 1), "random")
	assert_eq(manager.get_skin_deck_id("custom_mydeck", 1), "custom_mydeck")

func test_skin_portrait_degrades_to_base_when_art_absent():
	var manager = _skin_manager()
	if manager.get_skin_count("ryu") <= 0:
		pass_test("No ryu skins registered")
		return
	# No skin art is imported, so the portrait resolves (base character or fallback)
	# and never returns null / crashes.
	var texture = manager.load_portrait_texture_for_deck_id(manager.get_skin_deck_id("ryu", 1))
	assert_not_null(texture)

# --- Skin selection UI is hidden until skin art ships ---

func test_skin_selection_is_disabled_while_no_skin_art_is_imported():
	# Every registered skin currently degrades to its base character art, so
	# offering the picker would just be a confusing no-op.
	assert_false(_skin_manager().is_skin_selection_enabled(),
		"flip SKIN_SELECTION_ENABLED once skin art is imported")

func test_main_menu_hides_the_skin_picker_while_selection_is_disabled():
	var menu = load("res://scenes/menu/main_menu.tscn").instantiate()
	add_child_autofree(menu)
	await wait_frames(2)
	var picker = menu.get_node("PlayerChooser/MarginContainer/VBoxContainer/PlayerSkinSelection")

	menu.player_selected_character = "ryu"
	menu.player_selected_skin_index = 1
	menu._refresh_player_skin_selection()
	await wait_frames(2)

	assert_false(picker.visible, "the skin picker should stay hidden")
	assert_eq(picker.item_count, 0, "no skin entries should be populated")
	assert_eq(menu.player_selected_skin_index, 0, "a stale skin index must be reset")

func test_disabled_skin_selection_never_sends_a_skin_deck_id():
	var menu = load("res://scenes/menu/main_menu.tscn").instantiate()
	add_child_autofree(menu)
	await wait_frames(2)

	# Even with a skin index somehow set, the game-start payload uses the base id.
	menu.player_selected_skin_index = 1
	assert_eq(menu._get_effective_player_character_id("ryu"), "ryu")

func test_char_select_ignores_a_skin_index_while_selection_is_disabled():
	var char_select = load("res://scenes/menu/char_select.tscn").instantiate()
	add_child_autofree(char_select)
	await wait_frames(2)

	char_select.show_char_select("ryu", 1)
	assert_eq(char_select.default_skin_index, 0, "hover art should use the base character")

func test_skin_decks_are_not_offered_as_selectable_characters():
	# Skin decks share their base character's cards, so they must never show up
	# as extra entries in the character grid.
	for deck in CardDataManager.decks.values():
		if str(deck.get("id", "")).begins_with("ryu_"):
			assert_false(CardDataManager._is_random_selectable_deck(deck),
				"skin deck %s must not be selectable" % deck["id"])
