extends GutTest

const LocalGame = preload("res://scenes/game/local_game.gd")
const GameCard = preload("res://scenes/game/game_card.gd")
const Enums = preload("res://scenes/game/enums.gd")

var game_logic : LocalGame
var image_loader : CardImageLoader
var default_deck = CardDefinitions.get_deck_from_str_id("solbadguy")

func default_game_setup():
	image_loader = CardImageLoader.new(true)
	game_logic = LocalGame.new(image_loader)
	var seed_value = randi()
	game_logic.initialize_game(default_deck, default_deck, "p1", "p2", Enums.PlayerId.PlayerId_Player, seed_value)
	game_logic.draw_starting_hands_and_begin()
	game_logic.do_mulligan(game_logic.player, [])
	game_logic.do_mulligan(game_logic.opponent, [])
	game_logic.get_latest_events()

func before_each():
	default_game_setup()
	gut.p("ran setup", 2)

func after_each():
	game_logic.teardown()
	game_logic.free()
	gut.p("ran teardown", 2)

func before_all():
	gut.p("ran run setup", 2)

func after_all():
	gut.p("ran run teardown", 2)

func validate_draw_event_for_player(event, player, expected_card):
	assert_eq(event['event_type'], Enums.EventType.EventType_Draw)
	assert_eq(event['event_player'], player.my_id)
	assert_eq(event['number'], expected_card.id)

func validate_advance_turn(event, player):
	assert_eq(event['event_type'], Enums.EventType.EventType_AdvanceTurn)
	assert_eq(event['event_player'], player.my_id)

func validate_hand_exceeded(event, player, by_amount):
	assert_eq(event['event_type'], Enums.EventType.EventType_HandSizeExceeded)
	assert_eq(event['event_player'], player.my_id)
	assert_eq(event['number'], by_amount)

func validate_discard_card(event, player, card_id):
	assert_eq(event['event_type'], Enums.EventType.EventType_AddToDiscard)
	assert_eq(event['event_player'], player.my_id)
	assert_eq(event['number'], card_id)

func test_prepare_action():
	var current_player = game_logic._get_player(game_logic.active_turn_player)
	var other_player = game_logic._get_player(game_logic.next_turn_player)
	var hand_cards = []
	for card in current_player.hand:
		hand_cards.append(card)

	# Do the prepare action.
	assert_true(game_logic.can_do_prepare(current_player))
	var expected_cards = []
	expected_cards.append(current_player.deck[0])
	expected_cards.append(current_player.deck[1])
	assert_true(game_logic.do_prepare(current_player))
	var events = game_logic.get_latest_events()

	# Validate
	assert_eq(len(events), 4)
	if len(events) != 4: return
	validate_draw_event_for_player(events[1], current_player, expected_cards[0])
	validate_draw_event_for_player(events[2], current_player, expected_cards[1])
	validate_advance_turn(events[3], game_logic._get_player(game_logic.get_other_player(current_player.my_id)))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)
	assert_ne(current_player.my_id, game_logic.active_turn_player)
	assert_eq(len(current_player.hand), len(hand_cards) + 2)
	for card in expected_cards:
		assert_true(card in current_player.hand)
	for card in hand_cards:
		assert_true(card in current_player.hand)

	# Do prepare with other player
	hand_cards = []
	for card in other_player.hand:
		hand_cards.append(card)
	assert_true(game_logic.can_do_prepare(other_player))
	expected_cards = []
	expected_cards.append(other_player.deck[0])
	expected_cards.append(other_player.deck[1])
	assert_true(game_logic.do_prepare(other_player))
	events = game_logic.get_latest_events()
	assert_eq(len(events), 4)
	if len(events) != 4: return
	validate_draw_event_for_player(events[1], other_player, expected_cards[0])
	validate_draw_event_for_player(events[2], other_player, expected_cards[1])
	assert_eq(game_logic.game_state, Enums.GameState.GameState_DiscardDownToMax)
	validate_hand_exceeded(events[3], other_player, 1)
	for card in expected_cards:
		assert_true(card in other_player.hand)
	for card in hand_cards:
		assert_true(card in other_player.hand)

	# Discard down to max
	assert_true(game_logic.do_discard_to_max(other_player, [expected_cards[0].id]))
	events = game_logic.get_latest_events()
	assert_eq(len(events), 2)
	if len(events) != 2: return
	validate_discard_card(events[0], other_player, expected_cards[0].id)
	validate_advance_turn(events[1], current_player)
	assert_false(expected_cards[0] in other_player.hand)
	assert_true(expected_cards[1] in other_player.hand)
	for card in hand_cards:
		assert_true(card in other_player.hand)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)
	assert_eq(game_logic.active_turn_player, current_player.my_id)

	# Prepare again with original player, will have to discard 2
	hand_cards = []
	for card in current_player.hand:
		hand_cards.append(card)
	assert_true(game_logic.can_do_prepare(current_player))
	assert_false(game_logic.can_do_prepare(other_player))
	expected_cards = []
	expected_cards.append(current_player.deck[0])
	expected_cards.append(current_player.deck[1])
	assert_true(game_logic.do_prepare(current_player))
	events = game_logic.get_latest_events()
	assert_eq(len(events), 4)
	if len(events) != 4: return
	validate_draw_event_for_player(events[1], current_player, expected_cards[0])
	validate_draw_event_for_player(events[2], current_player, expected_cards[1])
	assert_eq(game_logic.game_state, Enums.GameState.GameState_DiscardDownToMax)
	validate_hand_exceeded(events[3], current_player, 2)
	for card in expected_cards:
		assert_true(card in current_player.hand)
	for card in hand_cards:
		assert_true(card in current_player.hand)

	# Discard down to max
	assert_true(game_logic.do_discard_to_max(current_player, [expected_cards[0].id, expected_cards[1].id]))
	events = game_logic.get_latest_events()
	assert_eq(len(events), 3)
	if len(events) != 3: return
	validate_discard_card(events[0], current_player, expected_cards[0].id)
	validate_discard_card(events[1], current_player, expected_cards[1].id)
	validate_advance_turn(events[2], other_player)
	assert_false(expected_cards[0] in current_player.hand)
	assert_false(expected_cards[1] in current_player.hand)
	for card in hand_cards:
		assert_true(card in current_player.hand)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)
	assert_eq(game_logic.active_turn_player, other_player.my_id)
