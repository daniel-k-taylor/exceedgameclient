extends ExceedGutTest

func who_am_i():
	return "yuzu"

func test_yuzu_ua_under_four_gauge():
	position_players(player1, 3, player2, 5)
	give_gauge(player1, 1)
	assert_true(game_logic.do_character_action(player1, []))
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_CardFromHandToGauge_Choice, player1)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	var card_to_choose = player1.hand[0]
	assert_true(game_logic.do_card_from_hand_to_gauge(player1, [card_to_choose.id]))
	events = game_logic.get_latest_events()
	assert_true(player1.is_card_in_gauge(card_to_choose.id))

	if player1.exceeded:
		fail_test("Should not have exceeded after character action")
	pass_test("test passed")

func test_yuzu_ua_four_gauge():
	position_players(player1, 3, player2, 5)
	give_gauge(player1, 3)
	assert_true(game_logic.do_character_action(player1, []))
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_CardFromHandToGauge_Choice, player1)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	var card_to_choose = player1.hand[0]
	assert_true(game_logic.do_card_from_hand_to_gauge(player1, [card_to_choose.id]))
	events = game_logic.get_latest_events()
	assert_true(player1.is_card_in_gauge(card_to_choose.id))

	if not player1.exceeded:
		fail_test("Should have exceeded after character action")
	pass_test("test passed")

func test_yuzu_discard_block_while_exceeded():
	position_players(player1, 3, player2, 5)
	give_gauge(player1, 1)
	assert_true(game_logic.do_exceed(player1, [player1.gauge[0].id]))

	var events = execute_strike(player2, player1, "uni_normal_assault", "uni_normal_block", [], [], false, false)
	validate_has_event(events, Enums.EventType.EventType_Strike_ForceForArmor, player1)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_true(game_logic.do_force_for_armor(player1, []))

	events = game_logic.get_latest_events()
	assert_true(player1.is_card_in_discards(TestCardId2))
	assert_true(player2.is_card_in_gauge(TestCardId1))
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 28, player2, 30)

func test_yuzu_kurenai_stunned_while_exceeded():
	position_players(player1, 3, player2, 5)
	give_gauge(player1, 2)
	assert_true(game_logic.do_exceed(player1, [player1.gauge[0].id]))

	execute_strike(player2, player1, "uni_normal_assault", "yuzu_kurenai", [], [0], false, false)

	assert_true(player1.is_card_in_continuous_boosts(TestCardId2))
	assert_true(player2.is_card_in_gauge(TestCardId1))
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 26, player2, 30)

func test_yuzu_strike_from_gauge_assault():
	position_players(player1, 3, player2, 5)
	give_player_specific_card(player1, "uni_normal_assault", TestCardId3)
	player1.move_card_from_hand_to_gauge(TestCardId3)
	player1.exceed()
	assert_true(game_logic.do_character_action(player1, [], 0))
	assert_true(game_logic.do_strike(player1, -1, false, -1, true))
	give_player_specific_card(player2, "uni_normal_cross", TestCardId4)
	assert_true(game_logic.do_strike(player2, TestCardId4, false, -1, true))
	validate_life(player1, 30, player2, 24)
	validate_positions(player1, 4, player2, 5)
	assert_eq(game_logic.active_turn_player, player1.my_id)
