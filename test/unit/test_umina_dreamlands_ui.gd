extends GutTest

# Umina's Dreamlands is a turn one mechanic: her default character action puts
# cards there and stored_zone_info marks it can_set_for_attack even before she
# exceeds. The Dreamlands buddy card is also the button that opens the zone
# popout (see the PlayerBuddyCharacterCard connection in game.tscn), so if it
# is hidden the player can neither see nor inspect the zone.

var game_ui : Game

func setup_game_ui(player_id : String, opponent_id : String = "ryu"):
	var game_scene = load("res://scenes/game/game.tscn")
	game_ui = game_scene.instantiate()
	game_ui.set_not_started_directly()
	add_child(game_ui)
	var game_logic = LocalGame.new(game_ui.image_loader)
	game_logic.initialize_game(
		CardDataManager.get_deck_from_str_id(player_id),
		CardDataManager.get_deck_from_str_id(opponent_id),
		"p1",
		"p2",
		Enums.PlayerId.PlayerId_Player,
		randi()
	)
	game_logic.draw_starting_hands_and_begin()
	assert_true(game_logic.do_mulligan(game_logic.player, []))
	assert_true(game_logic.do_mulligan(game_logic.opponent, []))
	game_logic.get_latest_events()
	game_ui.game_wrapper.current_game = game_logic

func after_each():
	if game_ui:
		game_ui.queue_free()
		game_ui = null

func _setup_buddy_card(deck_id : String):
	setup_game_ui(deck_id)
	var deck = CardDataManager.get_deck_from_str_id(deck_id)
	game_ui.player_deck = deck
	game_ui.opponent_deck = CardDataManager.get_deck_from_str_id("ryu")
	var buddy_card = game_ui.player_buddy_character_card
	await game_ui.setup_character_card(game_ui.player_character_card, deck, buddy_card)
	return buddy_card

func test_umina_deck_declares_a_dreamlands_buddy_visible_before_exceeding():
	var deck = CardDataManager.get_deck_from_str_id("umina")
	assert_eq(deck.get("buddy_card"), "umina_dreamlands")
	assert_true(deck.get("buddy_exceeds", false),
		"the Dreamlands has separate exceeded art")
	assert_true(deck.get("buddy_visible_before_exceed", false),
		"the Dreamlands exists from turn one, so it cannot wait for exceed")

func test_dreamlands_buddy_card_is_visible_before_exceeding():
	var buddy_card = await _setup_buddy_card("umina")
	assert_true(buddy_card.visible,
		"the Dreamlands buddy card is also its clickable zone button")

func test_dreamlands_buddy_card_stays_visible_after_reverting():
	var buddy_card = await _setup_buddy_card("umina")
	game_ui._on_exceed_event({ "event_player": Enums.PlayerId.PlayerId_Player })
	assert_true(buddy_card.visible)
	game_ui._on_exceed_revert_event({ "event_player": Enums.PlayerId.PlayerId_Player })
	assert_true(buddy_card.visible,
		"reverting does not remove the Dreamlands")

func test_a_buddy_that_only_exists_while_exceeded_still_hides():
	# Eugenia gains Wonderland by exceeding, so her buddy card must not be
	# shown up front. This pins that the fix is opt in.
	var buddy_card = await _setup_buddy_card("eugenia")
	assert_false(buddy_card.visible)
	game_ui._on_exceed_event({ "event_player": Enums.PlayerId.PlayerId_Player })
	assert_true(buddy_card.visible)
	game_ui._on_exceed_revert_event({ "event_player": Enums.PlayerId.PlayerId_Player })
	assert_false(buddy_card.visible)

func test_dreamlands_button_opens_the_set_aside_zone_popout():
	setup_game_ui("umina")
	game_ui.player_deck = CardDataManager.get_deck_from_str_id("umina")
	game_ui.opponent_deck = CardDataManager.get_deck_from_str_id("ryu")
	game_ui._on_player_buddy_button_pressed()
	assert_eq(game_ui.popout_type_showing, game_ui.CardPopoutType.CardPopoutType_BuddyPlayer)
	assert_eq(game_ui.card_popout_parent.get_child_count(), 1,
		"pressing the Dreamlands buddy card must open its zone")
