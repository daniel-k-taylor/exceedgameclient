extends GutTest

const LocalGame = preload("res://scenes/game/local_game.gd")
const GameCard = preload("res://scenes/game/game_card.gd")
const Enums = preload("res://scenes/game/enums.gd")
var game_logic : LocalGame
var default_deck = CardDefinitions.get_deck_from_str_id("ramlethal")
const TestCardId1 = 50001
const TestCardId2 = 50002
const TestCardId3 = 50003
const TestCardId4 = 50004
const TestCardId5 = 50005

var player1 : LocalGame.Player
var player2 : LocalGame.Player

func default_game_setup():
	game_logic = LocalGame.new()
	var seed_value = randi()
	game_logic.initialize_game(default_deck, default_deck, "p1", "p2", Enums.PlayerId.PlayerId_Player, seed_value)
	game_logic.draw_starting_hands_and_begin()
	game_logic.do_mulligan(game_logic.player, [])
	game_logic.do_mulligan(game_logic.opponent, [])
	player1 = game_logic.player
	player2 = game_logic.opponent
	game_logic.get_latest_events()

func give_player_specific_card(player, def_id, card_id):
	var card_def = CardDefinitions.get_card(def_id)
	var card = GameCard.new(card_id, card_def, "image", player.my_id)
	var card_db = game_logic.get_card_database()
	card_db._test_insert_card(card)
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

func validate_has_event(events, event_type, target_player, number = null):
	for event in events:
		if event['event_type'] == event_type:
			if event['event_player'] == target_player.my_id:
				if number != null and event['number'] == number:
					return
				elif number == null:
					return
	fail_test("Event not found: %s" % event_type)

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

func do_and_validate_strike(player, card_id, ex_card_id = -1):
	assert_true(game_logic.can_do_strike(player))
	assert_true(game_logic.do_strike(player, card_id, false, ex_card_id))
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_Strike_Started, player, card_id)
	if game_logic.game_state == Enums.GameState.GameState_Strike_Opponent_Response or game_logic.game_state == Enums.GameState.GameState_PlayerDecision:
		pass
	else:
		fail_test("Unexpected game state after strike")

func do_strike_response(player, card_id, ex_card = -1):
	assert_true(game_logic.do_strike(player, card_id, false, ex_card))
	var events = game_logic.get_latest_events()
	return events

func advance_turn(player):
	assert_true(game_logic.do_prepare(player))
	if player.hand.size() > 7:
		var cards = []
		var to_discard = player.hand.size() - 7
		for i in range(to_discard):
			cards.append(player.hand[i].id)
		assert_true(game_logic.do_discard_to_max(player, cards))

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

func handle_simultaneous_effects(initiator, defender):
	while game_logic.game_state == Enums.GameState.GameState_PlayerDecision and game_logic.decision_info.type == Enums.DecisionType.DecisionType_ChooseSimultaneousEffect:
		var decider = initiator
		if game_logic.decision_info.player == defender.my_id:
			decider = defender
		assert_true(game_logic.do_choice(decider, 0), "Failed simuleffect choice")
		
func execute_strike(initiator, defender, init_card : String, def_card : String, init_choices, def_choices, init_ex = false, def_ex = false, init_force_discard = [], def_force_discard = []):
	var all_events = []
	give_specific_cards(initiator, init_card, defender, def_card)
	if init_ex:
		give_player_specific_card(initiator, init_card, TestCardId3)
		do_and_validate_strike(initiator, TestCardId1, TestCardId3)
	else:
		do_and_validate_strike(initiator, TestCardId1)

	if game_logic.game_state == Enums.GameState.GameState_PlayerDecision and game_logic.active_strike.strike_state == game_logic.StrikeState.StrikeState_Initiator_SetEffects:
		game_logic.do_force_for_effect(initiator, init_force_discard)
		
	if def_ex:
		give_player_specific_card(defender, def_card, TestCardId4)
		all_events += do_strike_response(defender, TestCardId2, TestCardId4)
	else:
		all_events += do_strike_response(defender, TestCardId2)

	if game_logic.game_state == Enums.GameState.GameState_PlayerDecision and game_logic.active_strike.strike_state == game_logic.StrikeState.StrikeState_Defender_SetEffects:
		game_logic.do_force_for_effect(defender, def_force_discard)
		
	# Pay any costs from gauge
	if game_logic.active_strike and game_logic.active_strike.strike_state == game_logic.StrikeState.StrikeState_Initiator_PayCosts:
		var cost = game_logic.active_strike.initiator_card.definition['gauge_cost']
		var cards = []
		for i in range(cost):
			cards.append(initiator.gauge[i].id)
		game_logic.do_pay_strike_cost(initiator, cards, false)

	# Pay any costs from gauge
	if game_logic.active_strike and game_logic.active_strike.strike_state == game_logic.StrikeState.StrikeState_Defender_PayCosts:
		var cost = game_logic.active_strike.defender_card.definition['gauge_cost']
		var cards = []
		for i in range(cost):
			cards.append(defender.gauge[i].id)
		game_logic.do_pay_strike_cost(defender, cards, false)

	handle_simultaneous_effects(initiator, defender)

	for i in range(init_choices.size()):
		assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
		assert_true(game_logic.do_choice(initiator, init_choices[i]))
		handle_simultaneous_effects(initiator, defender)
	handle_simultaneous_effects(initiator, defender)

	for i in range(def_choices.size()):
		assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
		assert_true(game_logic.do_choice(defender, def_choices[i]))
		handle_simultaneous_effects(initiator, defender)

	var events = game_logic.get_latest_events()
	all_events += events
	return all_events

func validate_positions(p1, l1, p2, l2):
	assert_eq(p1.arena_location, l1)
	assert_eq(p2.arena_location, l2)

func validate_life(p1, l1, p2, l2):
	assert_eq(p1.life, l1)
	assert_eq(p2.life, l2)

func test_ram_ability_basic_no_use():
	position_players(player1, 3, player2, 7)
	var events = execute_strike(player1, player2, "gg_normal_slash","gg_normal_grasp", [], [], false, false)
	validate_has_event(events, Enums.EventType.EventType_Strike_Miss, player1)
	validate_has_event(events, Enums.EventType.EventType_Strike_Miss, player2)
	validate_positions(player1, 5, player2, 7)
	validate_life(player1, 30, player2, 30)
	
func test_ram_ability_basic():
	position_players(player1, 3, player2, 7)
	give_player_specific_card(player1, "ramlethal_calvados", TestCardId3)
	var events = execute_strike(player1, player2, "gg_normal_slash","gg_normal_grasp", [], [], false, false, [TestCardId3], [])
	validate_has_event(events, Enums.EventType.EventType_Strike_Miss, player2)
	validate_has_event(events, Enums.EventType.EventType_Strike_TookDamage, player2, 4)
	validate_positions(player1, 5, player2, 7)
	validate_life(player1, 30, player2, 26)

func test_ram_ability_basic_player2():
	position_players(player1, 4, player2, 7)
	give_player_specific_card(player1, "ramlethal_calvados", TestCardId3)
	give_player_specific_card(player2, "gg_normal_slash", TestCardId4)
	give_player_specific_card(player2, "gg_normal_block", TestCardId5)
	var events = execute_strike(player1, player2, "gg_normal_slash","gg_normal_cross", [], [], false, false, [TestCardId3], [TestCardId4, TestCardId5])
	validate_has_event(events, Enums.EventType.EventType_Strike_Stun, player1)
	validate_has_event(events, Enums.EventType.EventType_Strike_TookDamage, player1, 3)
	validate_positions(player1, 4, player2, 9)
	validate_life(player1, 27, player2, 30)

func test_ram_ability_basic_player2_exceed():
	position_players(player1, 4, player2, 7)
	player2.exceed()
	give_player_specific_card(player1, "ramlethal_calvados", TestCardId3)
	give_player_specific_card(player2, "gg_normal_slash", TestCardId4)
	give_player_specific_card(player2, "gg_normal_block", TestCardId5)
	var events = execute_strike(player1, player2, "gg_normal_slash","gg_normal_cross", [], [], false, false, [TestCardId3], [TestCardId4, TestCardId5])
	validate_has_event(events, Enums.EventType.EventType_Strike_Stun, player1)
	validate_has_event(events, Enums.EventType.EventType_Strike_TookDamage, player1, 4)
	validate_positions(player1, 4, player2, 9)
	validate_life(player1, 26, player2, 30)

func test_mortobato_boost():
	position_players(player1, 3, player2, 4)
	give_gauge(player1, 3)
	var gauge_cards = []
	for card in player1.gauge:
		gauge_cards.append(card)

	give_player_specific_card(player1, "ramlethal_mortobato", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	var events = game_logic.get_latest_events()
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)
	for card in gauge_cards:
		validate_has_event(events, Enums.EventType.EventType_AddToHand, player1, card.id)
		var found = false
		for hand_card in player1.hand:
			if card == hand_card:
				found = true
				break
		if not found:
			fail_test("Card was not in hand from gauge after Mortobato boost")
	pass_test("test passed")

func test_calvados_initiated_hit():
	position_players(player1, 3, player2, 4)
	give_gauge(player1, 2)
	give_player_specific_card(player1, "gg_normal_grasp", TestCardId3)
	player1.discard([TestCardId3])
	var events = execute_strike(player1, player2, "ramlethal_calvados","gg_normal_cross", [], [], false, false)
	validate_has_event(events, Enums.EventType.EventType_ChooseFromDiscard, player1)
	assert_true(game_logic.do_choose_from_discard(player1, [TestCardId3]))
	events = game_logic.get_latest_events()
	validate_positions(player1, 3, player2, 9)
	validate_life(player1, 28, player2, 26)
	assert_true(player1.is_card_in_gauge(TestCardId3))

func test_calvados_boost():
	position_players(player1, 3, player2, 4)
	give_player_specific_card(player1, "ramlethal_calvados", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_Move, player2, 6)
	validate_positions(player1, 3, player2, 6)
	advance_turn(player2)

	events = execute_strike(player1, player2, "gg_normal_slash","gg_normal_dive", [], [], false, false)
	validate_positions(player1, 5, player2, 6)
	validate_life(player1, 30, player2, 26)
	assert_eq(player1.gauge.size(), 2)

func test_dauro_boost_no_specials():
	position_players(player1, 3, player2, 4)
	give_player_specific_card(player1, "gg_normal_grasp", TestCardId4)
	player1.discard([TestCardId4])
	give_player_specific_card(player1, "ramlethal_dauro", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_ForceStartStrike, player1)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_StrikeNow)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_WaitForStrike)
	events = execute_strike(player1, player2, "gg_normal_slash","gg_normal_dive", [], [], false, false)
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 30, player2, 26)

func test_dauro_boost_with_specials():
	position_players(player1, 3, player2, 4)
	give_player_specific_card(player1, "gg_normal_grasp", TestCardId4)
	give_player_specific_card(player1, "ramlethal_bajoneto", TestCardId5)
	player1.discard([TestCardId4, TestCardId5])
	give_player_specific_card(player1, "ramlethal_dauro", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_ChooseFromDiscard, player1)
	assert_true(game_logic.do_choose_from_discard(player1, [TestCardId5]))
	events = game_logic.get_latest_events()
	assert_true(player1.is_card_in_hand(TestCardId5))
	validate_has_event(events, Enums.EventType.EventType_ForceStartStrike, player1)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_StrikeNow)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_WaitForStrike)
	events = execute_strike(player1, player2, "gg_normal_slash","gg_normal_dive", [], [], false, false)
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 30, player2, 26)

func test_erarlumo_hit():
	position_players(player1, 3, player2, 4)
	var events = execute_strike(player1, player2, "ramlethal_erarlumo","gg_normal_dive", [], [], false, false)
	validate_has_event(events, Enums.EventType.EventType_CardFromHandToGauge_Choice, player1)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	var card_to_choose = player1.hand[0]
	assert_true(game_logic.do_card_from_hand_to_gauge(player1, [card_to_choose.id]))
	events = game_logic.get_latest_events()
	assert_true(player1.is_card_in_gauge(card_to_choose.id))
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 30, player2, 27)

func test_agresaordono_hit():
	position_players(player1, 3, player2, 4)
	var card_on_top_deck = player1.deck[0]
	var events = execute_strike(player1, player2, "ramlethal_agresaordono","gg_normal_cross", [0], [], false, false)
	validate_has_event(events, Enums.EventType.EventType_Move, player1)
	assert_true(player1.is_card_in_gauge(card_on_top_deck.id))
	validate_positions(player1, 4, player2, 7)
	validate_life(player1, 27, player2, 26)

func test_agresaordono_boost_no_force():
	position_players(player1, 3, player2, 4)
	give_player_specific_card(player1, "ramlethal_agresaordono", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_ForceForEffect, player1)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ForceForEffect)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_true(game_logic.do_force_for_effect(player1, []))
	events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_Draw, player1)
	validate_has_event(events, Enums.EventType.EventType_AdvanceTurn, player2)
	assert_eq(player1.hand.size(), 6)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)
	assert_eq(game_logic.active_turn_player, player2.my_id)

func test_agresaordono_boost_1_force():
	position_players(player1, 3, player2, 4)
	give_player_specific_card(player1, "ramlethal_agresaordono", TestCardId3)
	give_player_specific_card(player1, "gg_normal_cross", TestCardId4)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_ForceForEffect, player1)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ForceForEffect)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_true(game_logic.do_force_for_effect(player1, [TestCardId4]))
	events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_Draw, player1)
	assert_eq(player1.hand.size(), 8)
	validate_has_event(events, Enums.EventType.EventType_HandSizeExceeded, player1)

func test_agresaordono_boost_2_force_normals():
	position_players(player1, 3, player2, 4)
	give_player_specific_card(player1, "ramlethal_agresaordono", TestCardId3)
	give_player_specific_card(player1, "gg_normal_cross", TestCardId4)
	give_player_specific_card(player1, "gg_normal_block", TestCardId5)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_ForceForEffect, player1)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ForceForEffect)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_true(game_logic.do_force_for_effect(player1, [TestCardId4, TestCardId5]))
	events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_Draw, player1)
	assert_eq(player1.hand.size(), 10)
	validate_has_event(events, Enums.EventType.EventType_HandSizeExceeded, player1)
	
func test_agresaordono_boost_2_force_ultra():
	position_players(player1, 3, player2, 4)
	give_player_specific_card(player1, "ramlethal_agresaordono", TestCardId3)
	give_player_specific_card(player1, "ramlethal_calvados", TestCardId4)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_ForceForEffect, player1)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ForceForEffect)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_true(game_logic.do_force_for_effect(player1, [TestCardId4]))
	events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_Draw, player1)
	assert_eq(player1.hand.size(), 10)
	validate_has_event(events, Enums.EventType.EventType_HandSizeExceeded, player1)
