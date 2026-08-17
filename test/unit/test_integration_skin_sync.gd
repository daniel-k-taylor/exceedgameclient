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
