extends GutTest

# Buddies whose base and exceeded forms share one piece of art (Renea's
# Briefcase) used to be listed twice in the deck reference, because the
# de-duplication compared buddy ids rather than the artwork those ids resolve
# to. The player saw the same card side by side with nothing to tell them apart.

var game_ui : Game

func setup_game_ui(player_id : String, opponent_id : String = "ryu"):
	var game_scene = load("res://scenes/game/game.tscn")
	game_ui = game_scene.instantiate()
	game_ui.set_not_started_directly()
	add_child(game_ui)
	game_ui.player_deck = CardDataManager.get_deck_from_str_id(player_id)
	game_ui.opponent_deck = CardDataManager.get_deck_from_str_id(opponent_id)

func after_each():
	if game_ui:
		game_ui.queue_free()
		game_ui = null

func _buddy_graphics_for_deck(deck) -> Array:
	# Mirrors how spawn_all_cards collects the ids it hands to the reference.
	var graphics = []
	if deck.get('hide_buddy_reference'):
		return graphics
	elif 'buddy_card' in deck:
		graphics.append(deck['buddy_card'])
		if deck.get('buddy_exceeds'):
			graphics.append(deck['buddy_card'] + "_exceeded")
	elif 'buddy_card_graphic_override' in deck:
		for buddy_card in deck['buddy_card_graphic_override']:
			graphics.append(buddy_card)
	elif 'buddy_cards' in deck:
		for buddy_card in deck['buddy_cards']:
			graphics.append(buddy_card)
			if deck.get('buddy_exceeds'):
				graphics.append(buddy_card + "_exceeded")
	return graphics

func test_renea_briefcase_is_listed_once_when_both_forms_share_art():
	setup_game_ui("renea")
	var deck = game_ui.player_deck
	var resources = deck['image_resources']
	assert_eq(resources['briefcase']['url'], resources['briefcase_exceeded']['url'],
		"this test only means anything while the two forms share one image")

	var graphics = _buddy_graphics_for_deck(deck)
	assert_eq(graphics.size(), 2, "both forms should reach the de-duplication step")

	var unique = game_ui._unique_buddy_graphics(graphics, resources)
	assert_eq(unique.size(), 1, "one piece of art should produce one reference card")
	assert_eq(unique[0], "briefcase", "the base form is the one worth showing")

func test_buddies_with_distinct_art_are_all_kept():
	setup_game_ui("renea")
	var resources = {
		"first": {"url": "https://example.test/a.jpeg"},
		"first_exceeded": {"url": "https://example.test/b.jpeg"},
	}
	var unique = game_ui._unique_buddy_graphics(["first", "first_exceeded"], resources)
	assert_eq(unique.size(), 2, "genuinely different art should still be listed separately")

func test_unknown_buddy_ids_fall_back_to_the_id_itself():
	setup_game_ui("renea")
	var unique = game_ui._unique_buddy_graphics(["missing", "missing", "other"], {})
	assert_eq(unique, ["missing", "other"],
		"a buddy with no image entry should not crash or duplicate")

func test_no_deck_lists_the_same_buddy_art_twice():
	setup_game_ui("renea")
	var offenders = []
	for deck_id in CardDataManager.decks:
		var deck = CardDataManager.decks[deck_id]
		var resources = deck.get('image_resources', {})
		var graphics = _buddy_graphics_for_deck(deck)
		if graphics.is_empty():
			continue
		var unique = game_ui._unique_buddy_graphics(graphics, resources)
		var urls = []
		for buddy_id in unique:
			if buddy_id in resources and 'url' in resources[buddy_id]:
				var url = resources[buddy_id]['url']
				if url in urls:
					offenders.append("%s: %s" % [deck_id, buddy_id])
				urls.append(url)
	assert_eq(offenders, [], "buddy reference lists must not repeat one image")
