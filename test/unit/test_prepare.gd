extends GutTest

const GameLogic = preload("res://scenes/game/gamelogic.gd")
var game_logic : GameLogic

func default_game_setup():
	game_logic = GameLogic.new()
	var chosen_deck = CardDefinitions.decks[0]
	game_logic.initialize_game(chosen_deck, chosen_deck)
	game_logic.draw_starting_hands_and_begin()
	game_logic.do_mulligan(game_logic.active_turn_player, [])
	game_logic.do_mulligan(game_logic.next_turn_player, [])

func before_each():
	default_game_setup()
	gut.p("ran setup", 2)

func after_each():
	game_logic.free()
	gut.p("ran teardown", 2)

func before_all():
	gut.p("ran run setup", 2)

func after_all():
	gut.p("ran run teardown", 2)

func validate_draw_event_for_player(event, player, expected_card):
	assert_eq(event['event_type'], game_logic.EventType.EventType_Draw)
	assert_eq(event['event_player'], player)
	assert_eq(event['number'], expected_card.id)

func validate_advance_turn(event, player):
	assert_eq(event['event_type'], game_logic.EventType.EventType_AdvanceTurn)
	assert_eq(event['event_player'], player)

func validate_hand_exceeded(event, player, by_amount):
	assert_eq(event['event_type'], game_logic.EventType.EventType_HandSizeExceeded)
	assert_eq(event['event_player'], player)
	assert_eq(event['number'], by_amount)

func validate_discard_card(event, player, card_id):
	assert_eq(event['event_type'], game_logic.EventType.EventType_Discard)
	assert_eq(event['event_player'], player)
	assert_eq(event['number'], card_id)

func test_prepare_action():
	var current_player = game_logic.active_turn_player
	var other_player = game_logic.next_turn_player
	var hand_cards = []
	for card in game_logic.active_turn_player.hand:
		hand_cards.append(card)

	# Do the prepare action.
	assert_true(game_logic.can_do_prepare(current_player))
	var expected_cards = []
	expected_cards.append(current_player.deck[0])
	expected_cards.append(current_player.deck[1])
	var events = game_logic.do_prepare(current_player)

	# Validate
	assert_eq(len(events), 4)
	if len(events) != 4: return
	validate_draw_event_for_player(events[1], current_player, expected_cards[0])
	validate_draw_event_for_player(events[2], current_player, expected_cards[1])
	validate_advance_turn(events[3], game_logic.other_player(current_player))
	assert_eq(game_logic.game_state, game_logic.GameState.GameState_PickAction)
	assert_ne(current_player, game_logic.active_turn_player)
	assert_eq(len(current_player.hand), len(hand_cards) + 2)
	for card in expected_cards:
		assert_true(card in current_player.hand)
	for card in hand_cards:
		assert_true(card in current_player.hand)

	# Do prepare with other player
	hand_cards = []
	for card in game_logic.active_turn_player.hand:
		hand_cards.append(card)
	assert_true(game_logic.can_do_prepare(other_player))
	expected_cards = []
	expected_cards.append(other_player.deck[0])
	expected_cards.append(other_player.deck[1])
	events = game_logic.do_prepare(other_player)
	assert_eq(len(events), 4)
	if len(events) != 4: return
	validate_draw_event_for_player(events[1], other_player, expected_cards[0])
	validate_draw_event_for_player(events[2], other_player, expected_cards[1])
	assert_eq(game_logic.game_state, game_logic.GameState.GameState_DiscardDownToMax)
	validate_hand_exceeded(events[3], other_player, 1)
	for card in expected_cards:
		assert_true(card in other_player.hand)
	for card in hand_cards:
		assert_true(card in other_player.hand)

	# Discard down to max
	events = game_logic.do_discard_to_max(other_player, [expected_cards[0].id])
	assert_eq(len(events), 2)
	if len(events) != 2: return
	validate_discard_card(events[0], other_player, expected_cards[0].id)
	validate_advance_turn(events[1], current_player)
	assert_false(expected_cards[0] in other_player.hand)
	assert_true(expected_cards[1] in other_player.hand)
	for card in hand_cards:
		assert_true(card in other_player.hand)
	assert_eq(game_logic.game_state, game_logic.GameState.GameState_PickAction)
	assert_eq(game_logic.active_turn_player, current_player)

	# Prepare again with original player, will have to discard 2
	hand_cards = []
	for card in game_logic.active_turn_player.hand:
		hand_cards.append(card)
	assert_true(game_logic.can_do_prepare(current_player))
	assert_false(game_logic.can_do_prepare(other_player))
	expected_cards = []
	expected_cards.append(current_player.deck[0])
	expected_cards.append(current_player.deck[1])
	events = game_logic.do_prepare(current_player)
	assert_eq(len(events), 4)
	if len(events) != 4: return
	validate_draw_event_for_player(events[1], current_player, expected_cards[0])
	validate_draw_event_for_player(events[2], current_player, expected_cards[1])
	assert_eq(game_logic.game_state, game_logic.GameState.GameState_DiscardDownToMax)
	validate_hand_exceeded(events[3], current_player, 2)
	for card in expected_cards:
		assert_true(card in current_player.hand)
	for card in hand_cards:
		assert_true(card in current_player.hand)

	# Discard down to max
	events = game_logic.do_discard_to_max(current_player, [expected_cards[0].id, expected_cards[1].id])
	assert_eq(len(events), 3)
	if len(events) != 3: return
	validate_discard_card(events[0], current_player, expected_cards[0].id)
	validate_discard_card(events[1], current_player, expected_cards[1].id)
	validate_advance_turn(events[2], other_player)
	assert_false(expected_cards[0] in current_player.hand)
	assert_false(expected_cards[1] in current_player.hand)
	for card in hand_cards:
		assert_true(card in current_player.hand)
	assert_eq(game_logic.game_state, game_logic.GameState.GameState_PickAction)
	assert_eq(game_logic.active_turn_player, other_player)
