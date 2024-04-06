extends ExceedGutTest

func who_am_i():
	return "zangief"

# UA
# Exceed and UA
# Flying power bomb choices

func test_zangief_crit_power():
	position_players(player1, 6, player2, 7)
	var p1_gauge = give_gauge(player1, 1)
	var p2_gauge = give_gauge(player2, 2)
	execute_strike(player1, player2, "zangief_flyingpowerbomb", "zangief_atomicsuplex",
			false, false, [p1_gauge], [[p2_gauge[0]]])
	# Expected: Atomic Suplex swings for 4 + 1 (crit), push 3, close 3 (crit)
	#           Flying Power Bomb swings (crit stun immune) for 6 + 1 (crit)
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 25, player2, 23)

func test_zangief_exceed_crit():
	position_players(player1, 4, player2, 7)
	var p1_gauge = give_gauge(player1, 4)
	assert_true(game_logic.do_exceed(player1, p1_gauge.slice(1)))
	assert_true(game_logic.do_choice(player1, 1))  # When you Exceed, pull up to 2
	validate_positions(player1, 4, player2, 5)
	# P2 turn
	execute_strike(player2, player1, "standard_normal_cross", "zangief_atomicsuplex", 
			false, false, [], [[p1_gauge[0]]])
	# Expected: Atomic Suplex outspeeds Cross (6 + 1 (crit)), hits for 4 + 3 (crit), push 3, close 3 (crit)
	validate_positions(player1, 7, player2, 8)
	validate_life(player1, 30, player2, 23)

## Tests of Flying Power Bomb's boost:
##   Name a range; the opponent must discard a card that includes that range or reveal a hand that
##   doesn't contain such a card.
## (Reminder: All test setups are mirror matches.)

func test_zangief_flyingpowerbomb_boost_reveal():
	position_players(player1, 4, player2, 7)
	var card_id = give_player_specific_card(player1, "zangief_flyingpowerbomb")
	assert_true(game_logic.do_boost(player1, card_id))

	# Name the range 0-8 are real ranges, 9 is a valid choice but doesn't exist, 10 is X, 11 is -
	assert_true(game_logic.do_choice(player1, 10)) # Zangief has no X cards.
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_RevealHand, player2)
	advance_turn(player2)

func test_zangief_flyingpowerbomb_boost_reveal2():
	position_players(player1, 4, player2, 7)
	var card_id = give_player_specific_card(player1, "zangief_flyingpowerbomb")
	assert_true(game_logic.do_boost(player1, card_id))

	# Name the range 0-8 are real ranges, 9 is a valid choice but doesn't exist, 10 is X, 11 is -
	assert_true(game_logic.do_choice(player1, 4)) # Zangief has no 4
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_RevealHand, player2)
	advance_turn(player2)

func test_zangief_flyingpowerbomb_boost_discard_block():
	position_players(player1, 4, player2, 7)
	var power_bomb_id = give_player_specific_card(player1, "zangief_flyingpowerbomb")
	assert_true(game_logic.do_boost(player1, power_bomb_id))
	player2.discard_hand()
	var block_id = give_player_specific_card(player2, "standard_normal_block")
	# Name the range 0-8 are real ranges, 9 is a valid choice but doesn't exist, 10 is X, 11 is -
	assert_true(game_logic.do_choice(player1, 11))
	assert_true(game_logic.do_choose_to_discard(player2, [block_id]))
	advance_turn(player2)

func test_zangief_flyingpowerbomb_boost_discard_X():
	position_players(player1, 4, player2, 7)
	var power_bomb_id = give_player_specific_card(player1, "zangief_flyingpowerbomb")
	assert_true(game_logic.do_boost(player1, power_bomb_id))
	player2.discard_hand()
	var frustration_id = give_player_specific_card(player2, "phonon_impulsivefrustration")
	# Range 2~X; Zangief calls "X" as the range
	assert_true(game_logic.do_choice(player1, 10))
	assert_true(game_logic.do_choose_to_discard(player2, [frustration_id]))
	advance_turn(player2)

func test_zangief_flyingpowerbomb_boost_discard_3_with_X_eval():
	position_players(player1, 4, player2, 7)
	var power_bomb_id = give_player_specific_card(player1, "zangief_flyingpowerbomb")
	assert_true(game_logic.do_boost(player1, power_bomb_id))

	player2.discard_hand()
	var frustration_id = give_player_specific_card(player2, "phonon_impulsivefrustration")
	# Range 2~X where X is the attack's Power (printed 3); Zangief calls "3"
	assert_true(game_logic.do_choice(player1, 3))
	assert_true(game_logic.do_choose_to_discard(player2, [frustration_id]))
	advance_turn(player2)

func test_zangief_flyingpowerbomb_boost_discard_4_with_X_eval_fails():
	position_players(player1, 4, player2, 7)
	advance_turn(player1)
	var tuning_id = give_player_specific_card(player2, "phonon_turningsatisfaction")
	assert_true(game_logic.do_boost(player2, tuning_id))
	# Continuous boost: +1 Power
	advance_turn(player2)
	player1.discard_hand()
	var power_bomb_id = give_player_specific_card(player1, "zangief_flyingpowerbomb")
	assert_true(game_logic.do_boost(player1, power_bomb_id))

	player2.discard_hand()
	var frustration_id = give_player_specific_card(player2, "phonon_impulsivefrustration")
	# Range 2~X where X is the attack's Power (printed 3)
	# Zangief calls "4", which whiffs because the continuous boost only applies during a strike or something
	assert_true(game_logic.do_choice(player1, 4))
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_RevealHand, player2)
	advance_turn(player2)

func test_zangief_flyingpowerbomb_boost_discard_3():
	position_players(player1, 4, player2, 7)
	var power_bomb_id = give_player_specific_card(player1, "zangief_flyingpowerbomb")
	assert_true(game_logic.do_boost(player1, power_bomb_id))

	player2.discard_hand()
	var sweep_id = give_player_specific_card(player2, "standard_normal_sweep")
	# Name the range 0-8 are real ranges, 9 is a valid choice but doesn't exist, 10 is X, 11 is -
	assert_true(game_logic.do_choice(player1, 3))
	assert_true(game_logic.do_choose_to_discard(player2, [sweep_id]))
	advance_turn(player2)

func test_zangief_flyingpowerbomb_boost_discard_kunzite():
	position_players(player1, 1, player2, 3)
	var power_bomb_id = give_player_specific_card(player1, "zangief_flyingpowerbomb")
	assert_true(game_logic.do_boost(player1, power_bomb_id))

	player2.discard_hand()
	var kunzite_id = give_player_specific_card(player2, "nine_kunzite")
	# Range X, where X is your range to the opponent
	assert_true(game_logic.do_choice(player1, 2))
	assert_true(game_logic.do_choose_to_discard(player2, [kunzite_id]))
	advance_turn(player2)

## Test Siberian Blizzard passive effect: Opponents can't move past you.

func test_zangief_siberian_move():
	position_players(player1, 3, player2, 6)
	var p1_gauge = give_gauge(player1, 3)

	assert_eq(player1.hand.size(), 5)
	execute_strike(player1, player2, "zangief_siberianblizzard", "standard_normal_dive",
			false, false,
			[[], p1_gauge],  # Pass on critical payment; pay all gauge for the Ultra
			[])
	assert_eq(player1.hand.size(), 7)  # Original 5 + Blizzard - Blizzard + Draw 2 on Hit
	# Expected: Dive goes first but can't cross over; hits for 5, doesn't stun
	#           Blizzard hits back for 8
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 25, player2, 22)

	# Verify that player 2 can still cross over outside of the strike
	assert_true(game_logic.do_move(player2, [player2.hand[0].id, player2.hand[1].id], 2))
	validate_positions(player1, 3, player2, 2)

	# Verify that the movement block doesn't persist to the next strike
	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_dive",
			false, false, [[]], [[]])  # Empty options to decline critical
	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 25, player2, 22)
	advance_turn(player2)
