extends ExceedGutTest

func who_am_i():
	return "gulbjarn"

## Rage (Feral Frenzy boost) - You cannot draw cards.
##		Action: Close 2. Discard this.
##W		Hit: +3 Power. Sustain this.

func test_gulbjarn_rage_ends_with_action():
	position_players(player1, 4, player2, 6)
	var hand_size = len(player1.hand)
	
	var boost_id = give_player_specific_card(player1, "gulbjarn_feralfrenzy")
	assert_true(game_logic.do_boost(player1, boost_id, [player1.hand[0].id]))

	# spent 1 card, no end of turn draw
	assert_eq(len(player1.hand), hand_size - 1)
	advance_turn(player2)
	
	# prepare action does nothing
	assert_true(game_logic.do_prepare(player1))
	assert_eq(len(player1.hand), hand_size - 1)
	advance_turn(player2)
	
	# focus does not give cards
	execute_strike(player1, player2, "standard_normal_focus", "standard_normal_grasp")
	validate_life(player1, 30, player2, 23)
	validate_positions(player1, 4, player2, 6)
	assert_eq(len(player1.hand), hand_size - 1)
	assert_true(player1.is_card_in_continuous_boosts(boost_id))
	advance_turn(player2)
	
	# take action so things return to normal
	assert_true(game_logic.do_bonus_turn_action(player1, 0))
	validate_positions(player1, 5, player2, 6)
	assert_true(player1.is_card_in_discards(boost_id))
	# drew for end of turn
	assert_eq(len(player1.hand), hand_size)
	advance_turn(player2)
	
	# can prepare again
	assert_true(game_logic.do_prepare(player1))
	assert_eq(len(player1.hand), hand_size + 2)
	advance_turn(player2)

func test_gulbjarn_rage_ends_during_strike():
	position_players(player1, 4, player2, 7)
	var hand_size = len(player1.hand)
	
	var boost_id = give_player_specific_card(player1, "gulbjarn_feralfrenzy")
	assert_true(game_logic.do_boost(player1, boost_id, [player1.hand[0].id]))

	# spent 1 card, no end of turn draw
	assert_eq(len(player1.hand), hand_size - 1)
	advance_turn(player2)
	
	# prepare action does nothing
	assert_true(game_logic.do_prepare(player1))
	assert_eq(len(player1.hand), hand_size - 1)
	advance_turn(player2)
	
	# focus does not give cards and misses so it does not sustain
	execute_strike(player1, player2, "standard_normal_focus", "standard_normal_grasp")
	validate_life(player1, 30, player2, 30)
	validate_positions(player1, 4, player2, 7)
	assert_eq(len(player1.hand), hand_size - 1)
	assert_true(player1.is_card_in_discards(boost_id))
	advance_turn(player2)
	
	# can prepare again
	assert_true(game_logic.do_prepare(player1))
	assert_eq(len(player1.hand), hand_size + 1)
	advance_turn(player2)
