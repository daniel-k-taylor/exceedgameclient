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

func _find_ui_card(card_id : int):
	for node in game_ui.get_tree().get_nodes_in_group("cards"):
		if node.card_id == card_id:
			return node
	return null

# Puts a real card into the Dreamlands (set_aside) and returns its id.
func _put_in_dreamlands(def_id : String) -> int:
	var player = game_ui.game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
	var card_def = CardDataManager.get_card(def_id)
	var card_id = 71000 + player.set_aside_cards.size()
	var card = GameCard.new(card_id, card_def, player.my_id)
	game_ui.game_wrapper.current_game.get_card_database()._test_insert_card(card)
	player.set_aside_cards.append(card)
	return card_id

func _begin_strike_selection():
	game_ui.ui_state = game_ui.UIState.UIState_SelectCards
	game_ui.ui_sub_state = game_ui.UISubState.UISubState_SelectCards_StrikeCard
	game_ui.selected_cards = []

func test_a_dreamlands_card_can_be_selected_when_setting_a_strike():
	setup_game_ui("umina")
	var dreamlands_id = _put_in_dreamlands("standard_normal_sweep")
	_begin_strike_selection()

	assert_true(game_ui.game_wrapper.can_strike_with_set_aside_card(
		Enums.PlayerId.PlayerId_Player, dreamlands_id),
		"the engine already allows striking from the Dreamlands")
	assert_true(game_ui.can_select_card(_FakeCard.new(dreamlands_id)),
		"so the card must be clickable when picking a strike")

func test_a_selected_dreamlands_card_can_be_confirmed():
	setup_game_ui("umina")
	var dreamlands_id = _put_in_dreamlands("standard_normal_sweep")
	_begin_strike_selection()
	game_ui.selected_cards = [_FakeCard.new(dreamlands_id)]
	assert_true(game_ui.can_press_ok(),
		"one Dreamlands card is a complete strike")

func test_a_dreamlands_card_cannot_be_paired_into_an_ex_strike():
	# FAQ: a Dreamlands card may not be EXed with a copy from hand.
	setup_game_ui("umina")
	var dreamlands_id = _put_in_dreamlands("standard_normal_sweep")
	_begin_strike_selection()
	game_ui.instructions_ex_allowed = true

	var player = game_ui.game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
	var hand_copy_id = player.hand[0].id
	game_ui.selected_cards = [_FakeCard.new(dreamlands_id)]
	assert_false(game_ui.can_select_card(_FakeCard.new(hand_copy_id)),
		"nothing may be added alongside a Dreamlands card")

	game_ui.selected_cards = [_FakeCard.new(dreamlands_id), _FakeCard.new(hand_copy_id)]
	assert_false(game_ui.can_press_ok(),
		"an EX strike from the Dreamlands is illegal")

func test_hand_cards_are_still_selectable_for_strikes():
	setup_game_ui("umina")
	_put_in_dreamlands("standard_normal_sweep")
	_begin_strike_selection()
	var player = game_ui.game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
	assert_true(game_ui.can_select_card(_FakeCard.new(player.hand[0].id)),
		"the normal case must keep working")

func test_a_character_without_a_stored_zone_cannot_strike_from_set_aside():
	# Galdred stages his face attack in set-aside but has no stored zone, so
	# those cards must not become selectable strike targets.
	setup_game_ui("galdred")
	var player = game_ui.game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
	if player.set_aside_cards.is_empty():
		pass_test("Galdred has no set-aside cards at game start")
		return
	assert_false(game_ui.game_wrapper.can_strike_with_set_aside_card(
		Enums.PlayerId.PlayerId_Player, player.set_aside_cards[0].id))

# can_select_card only reads card_id, so this stands in for a real card node.
class _FakeCard:
	var card_id : int
	func _init(id : int):
		card_id = id

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
