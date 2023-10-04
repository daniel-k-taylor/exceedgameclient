extends GutTest

const GameLogic = preload("res://scenes/game/gamelogic.gd")
var game_logic : GameLogic
var default_deck = CardDefinitions.decks[0]
const TestCardId1 = 50001
const TestCardId2 = 50002
const TestCardId3 = 50003
const TestCardId4 = 50004

var player1 : GameLogic.Player
var player2 : GameLogic.Player

func default_game_setup():
	game_logic = GameLogic.new()
	game_logic.initialize_game(default_deck, default_deck)
	game_logic.draw_starting_hands_and_begin()
	game_logic.do_mulligan(game_logic.active_turn_player, [])
	game_logic.do_mulligan(game_logic.next_turn_player, [])
	player1 = game_logic.player
	player2 = game_logic.opponent

func give_player_specific_card(player, def_id, card_id):
	var card_def = CardDefinitions.get_card(def_id)
	var card = game_logic.Card.new(card_id, card_def, "image")
	game_logic._test_insert_card(card)
	player.hand.append(card)

func give_specific_cards(p1, id1, p2, id2):
	if p1:
		give_player_specific_card(p1, id1, TestCardId1)
	if p2:
		give_player_specific_card(p2, id2, TestCardId2)

func position_players(p1, loc1, p2, loc2):
	p1.arena_location = loc1
	p2.arena_location = loc2

func give_gauge(player, amount):
	for i in range(amount):
		player.add_to_gauge(player.deck[0])
		player.deck.remove_at(0)

func validate_has_event(events, event_type, event_player, number = null):
	for event in events:
		if event['event_type'] == event_type:
			if event['event_player'] == event_player:
				if number != null:
					assert_eq(event['number'], number)
				return
	fail_test("Event not found: %s" % event_type)

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

func do_and_validate_strike(player, card_id, ex_card_id = -1):
	assert_true(game_logic.can_do_strike(player))
	var events = game_logic.do_strike(player, card_id, false, ex_card_id)
	validate_has_event(events, game_logic.EventType.EventType_Strike_Started, player, card_id)
	assert_eq(game_logic.game_state, game_logic.GameState.GameState_Strike_Opponent_Response)

func do_strike_response(player, card_id, ex_card = -1):
	var events = game_logic.do_strike(player, card_id, false, ex_card)
	return events

func validate_gauge(player, amount, id):
	assert_eq(len(player.gauge), amount)
	if len(player.gauge) != amount: return
	if amount == 0: return
	for card in player.gauge:
		if card.id == id:
			return
	fail_test("Didn't have required card in gauge.")

func validate_discard(player, amount, id):
	assert_eq(len(player.discards), amount)
	if len(player.discards) != amount: return
	if amount == 0: return
	for card in player.discards:
		if card.id == id:
			return
	fail_test("Didn't have required card in discard.")

func execute_strike(initiator, defender, init_card, def_card, init_choices, def_choices, init_ex = false, def_ex = false):
	var all_events = []
	give_specific_cards(initiator, init_card, defender, def_card)
	if init_ex:
		give_player_specific_card(initiator, init_card, TestCardId3)
		do_and_validate_strike(initiator, TestCardId1, TestCardId3)
	else:
		do_and_validate_strike(initiator, TestCardId1)

	if def_ex:
		give_player_specific_card(defender, def_card, TestCardId4)
		all_events += do_strike_response(defender, TestCardId2, TestCardId4)
	else:
		all_events += do_strike_response(defender, TestCardId2)
	for i in range(init_choices.size()):
		assert_eq(game_logic.game_state, game_logic.GameState.GameState_PlayerDecision)
		all_events = game_logic.do_choice(initiator, init_choices[i])
	for i in range(def_choices.size()):
		assert_eq(game_logic.game_state, game_logic.GameState.GameState_PlayerDecision)
		all_events = game_logic.do_choice(defender, def_choices[i])

	return all_events

func validate_positions(p1, l1, p2, l2):
	assert_eq(p1.arena_location, l1)
	assert_eq(p2.arena_location, l2)

func validate_life(p1, l1, p2, l2):
	assert_eq(p1.life, l1)
	assert_eq(p2.life, l2)

func test_grasp_v_wildthrow():
	position_players(player1, 3, player2, 4)
	var events = execute_strike(player1, player2, "gg_normal_grasp", "solbadguy_wildthrow", [0], [])
	validate_has_event(events, game_logic.EventType.EventType_Strike_IgnoredPushPull, player2)
	validate_positions(player1, 5, player2, 4)
	validate_life(player1, 25, player2, 27)

func test_boost_nr_and_grasp_vs_wildthrow():
	var initiator = game_logic.player
	var defender = game_logic.opponent
	give_specific_cards(initiator, "gg_normal_grasp", defender, "solbadguy_wildthrow")
	give_player_specific_card(initiator, "solbadguy_nightraidvortex", TestCardId3)
	give_gauge(initiator, 1)
	position_players(initiator, 3, defender, 4)

	# Boost night raid
	var events = game_logic.do_boost(initiator, TestCardId3)
	assert_eq(game_logic.game_state, game_logic.GameState.GameState_PlayerDecision)
	# Draw to 8 because had 7 to start and used one.
	assert_eq(initiator.hand.size(), 8)
	game_logic.do_discard_to_max(initiator, [initiator.hand[0].id])
	events = game_logic.do_boost_cancel(initiator, [initiator.gauge[0].id], true)
	assert_eq(initiator.gauge.size(), 0)
	assert_eq(game_logic.game_state, game_logic.GameState.GameState_PickAction)
	do_and_validate_strike(initiator, TestCardId1)
	events = do_strike_response(defender, TestCardId2)

	# Grasp decision happens but is ignored.
	events = game_logic.do_choice(initiator, 0)
	validate_has_event(events, game_logic.EventType.EventType_Strike_Stun, defender)
	validate_has_event(events, game_logic.EventType.EventType_Strike_IgnoredPushPull, defender)
	assert_eq(game_logic.game_state, game_logic.GameState.GameState_PickAction)
	assert_eq(initiator.arena_location, 3)
	assert_eq(defender.arena_location, 4)

	validate_life(initiator, 30, defender, 26)

func test_ex_wildthrow_vs_focus():
	position_players(player1, 3, player2, 4)
	var events = execute_strike(player1, player2, "solbadguy_wildthrow", "gg_normal_focus", [], [], true, false)
	validate_has_event(events, game_logic.EventType.EventType_Strike_IgnoredPushPull, player2)
	validate_has_event(events, game_logic.EventType.EventType_Strike_Stun, player2)
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 30, player2, 24)
