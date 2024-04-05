extends ExceedGutTest

func who_am_i():
	return "zangief"

# UA
# Exceed and UA
# Flying power bomb choices

func test_zangief_crit_power():
	position_players(player1, 6, player2, 7)
	give_gauge(player1, 1)
	give_gauge(player2, 2)
	give_player_specific_card(player1, "zangief_flyingpowerbomb", TestCardId1)
	give_player_specific_card(player2, "zangief_atomicsuplex", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_gauge_for_effect(player1, [player1.gauge[0].id]))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	assert_true(game_logic.do_gauge_for_effect(player2, [player2.gauge[0].id]))
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 25, player2, 23)

func test_zangief_exceed_crit():
	position_players(player1, 4, player2, 7)
	give_gauge(player1, 4)
	var card_ids = player1.get_card_ids_in_gauge().slice(1)
	assert_true(game_logic.do_exceed(player1, card_ids))
	assert_true(game_logic.do_choice(player1, 1))
	validate_positions(player1, 4, player2, 5)
	# P2 turn
	give_player_specific_card(player1, "zangief_atomicsuplex", TestCardId1)
	give_player_specific_card(player2, "standard_normal_cross", TestCardId2)
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_gauge_for_effect(player1, [player1.gauge[0].id]))
	validate_positions(player1, 7, player2, 8)
	validate_life(player1, 30, player2, 23)
	advance_turn(player1)

func test_zangief_flyingpowerbomb_boost_reveal():
	position_players(player1, 4, player2, 7)
	give_player_specific_card(player1, "zangief_flyingpowerbomb", TestCardId1)
	assert_true(game_logic.do_boost(player1, TestCardId1))

	# Name the range 0-8 are real ranges, 9 is a valid choice but doesn't exist, 10 is X, 11 is -
	assert_true(game_logic.do_choice(player1, 10)) # Zangief has no X cards.
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_RevealHand, player2)
	advance_turn(player2)

func test_zangief_flyingpowerbomb_boost_reveal2():
	position_players(player1, 4, player2, 7)
	give_player_specific_card(player1, "zangief_flyingpowerbomb", TestCardId1)
	assert_true(game_logic.do_boost(player1, TestCardId1))

	# Name the range 0-8 are real ranges, 9 is a valid choice but doesn't exist, 10 is X, 11 is -
	assert_true(game_logic.do_choice(player1, 4)) # Zangief has no 4
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_RevealHand, player2)
	advance_turn(player2)

func test_zangief_flyingpowerbomb_boost_discard_block():
	position_players(player1, 4, player2, 7)
	give_player_specific_card(player1, "zangief_flyingpowerbomb", TestCardId1)
	assert_true(game_logic.do_boost(player1, TestCardId1))
	player2.discard_hand()
	give_player_specific_card(player2, "standard_normal_block", TestCardId2)
	# Name the range 0-8 are real ranges, 9 is a valid choice but doesn't exist, 10 is X, 11 is -
	assert_true(game_logic.do_choice(player1, 11))
	assert_true(game_logic.do_choose_to_discard(player2, [TestCardId2]))
	advance_turn(player2)

func test_zangief_flyingpowerbomb_boost_discard_X():
	position_players(player1, 4, player2, 7)
	give_player_specific_card(player1, "zangief_flyingpowerbomb", TestCardId1)
	assert_true(game_logic.do_boost(player1, TestCardId1))
	player2.discard_hand()
	give_player_specific_card(player2, "phonon_impulsivefrustration", TestCardId2)
	# Name the range 0-8 are real ranges, 9 is a valid choice but doesn't exist, 10 is X, 11 is -
	assert_true(game_logic.do_choice(player1, 10))
	assert_true(game_logic.do_choose_to_discard(player2, [TestCardId2]))
	advance_turn(player2)

func test_zangief_flyingpowerbomb_boost_discard_3_with_X_eval():
	position_players(player1, 4, player2, 7)
	give_player_specific_card(player1, "zangief_flyingpowerbomb", TestCardId1)
	assert_true(game_logic.do_boost(player1, TestCardId1))

	player2.discard_hand()
	give_player_specific_card(player2, "phonon_impulsivefrustration", TestCardId2)
	# Name the range 0-8 are real ranges, 9 is a valid choice but doesn't exist, 10 is X, 11 is -
	assert_true(game_logic.do_choice(player1, 3))
	assert_true(game_logic.do_choose_to_discard(player2, [TestCardId2]))
	advance_turn(player2)

func test_zangief_flyingpowerbomb_boost_discard_4_with_X_eval_fails():
	position_players(player1, 4, player2, 7)
	advance_turn(player1)
	give_player_specific_card(player2, "phonon_turningsatisfaction", TestCardId3)
	assert_true(game_logic.do_boost(player2, TestCardId3))
	advance_turn(player2)
	player1.discard_hand()
	give_player_specific_card(player1, "zangief_flyingpowerbomb", TestCardId1)
	assert_true(game_logic.do_boost(player1, TestCardId1))

	player2.discard_hand()
	give_player_specific_card(player2, "phonon_impulsivefrustration", TestCardId2)
	# Name the range 0-8 are real ranges, 9 is a valid choice but doesn't exist, 10 is X, 11 is -
	assert_true(game_logic.do_choice(player1, 4))
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_RevealHand, player2)
	advance_turn(player2)

func test_zangief_flyingpowerbomb_boost_discard_3():
	position_players(player1, 4, player2, 7)
	give_player_specific_card(player1, "zangief_flyingpowerbomb", TestCardId1)
	assert_true(game_logic.do_boost(player1, TestCardId1))

	player2.discard_hand()
	give_player_specific_card(player2, "standard_normal_sweep", TestCardId2)
	# Name the range 0-8 are real ranges, 9 is a valid choice but doesn't exist, 10 is X, 11 is -
	assert_true(game_logic.do_choice(player1, 3))
	assert_true(game_logic.do_choose_to_discard(player2, [TestCardId2]))
	advance_turn(player2)

func test_zangief_flyingpowerbomb_boost_discard_kunzite():
	position_players(player1, 1, player2, 3)
	give_player_specific_card(player1, "zangief_flyingpowerbomb", TestCardId1)
	assert_true(game_logic.do_boost(player1, TestCardId1))

	player2.discard_hand()
	give_player_specific_card(player2, "nine_kunzite", TestCardId2)
	# Name the range 0-8 are real ranges, 9 is a valid choice but doesn't exist, 10 is X, 11 is -
	assert_true(game_logic.do_choice(player1, 2)) # We're range 2 so kunzite should be 2
	assert_true(game_logic.do_choose_to_discard(player2, [TestCardId2])) # If this fails, then kunzite didn't match
	advance_turn(player2)

func test_zangief_siberian_move():
	position_players(player1, 3, player2, 6)
	give_gauge(player1, 3)
	give_player_specific_card(player1, "zangief_siberianblizzard", TestCardId1)
	give_player_specific_card(player2, "standard_normal_dive", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_gauge_for_effect(player1, [])) # Skip critical
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	assert_eq(player1.hand.size(), 5)
	assert_true(game_logic.do_pay_strike_cost(player1, player1.get_card_ids_in_gauge(), false))
	assert_eq(player1.hand.size(), 7)
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 25, player2, 22)
	# Player 2, make sure we can move past them.
	assert_true(game_logic.do_move(player2, [player2.hand[0].id, player2.hand[1].id], 2))
	validate_positions(player1, 3, player2, 2)
	give_player_specific_card(player1, "standard_normal_sweep", TestCardId3)
	give_player_specific_card(player2, "standard_normal_dive", TestCardId4)
	assert_true(game_logic.do_strike(player1, TestCardId3, false, -1))
	assert_true(game_logic.do_gauge_for_effect(player1, [])) # Skip critical
	assert_true(game_logic.do_strike(player2, TestCardId4, false, -1))
	assert_true(game_logic.do_gauge_for_effect(player2, [])) # Skip critical
	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 25, player2, 22)
	advance_turn(player2)
