extends ExceedGutTest

func who_am_i():
	return "wagner"

## Character ability -- Action: Close or Retreat 1. Play a Continuous Boost from
## your hand or reveal a hand with none.

func test_wagner_ua_with_boost():
	position_players(player1, 3, player2, 6)
	player1.hand = []
	var cross_id = give_player_specific_card(player1, "uni_normal_cross")

	assert_true(game_logic.do_character_action(player1, []))
	assert_true(game_logic.do_choice(player1, 0))  # Close 1
	assert_true(game_logic.do_boost(player1, cross_id, []))
	var events = game_logic.get_latest_events()

	assert_true(player1.is_card_in_continuous_boosts(cross_id))
	validate_positions(player1, 4, player2, 6)
	validate_not_has_event(events, Enums.EventType.EventType_RevealHand, player1, 0)
	assert_eq(game_logic.get_active_player(), player2.my_id)

func test_wagner_ua_with_no_boost():
	position_players(player1, 3, player2, 6)
	player1.hand = []
	var dive_id = give_player_specific_card(player1, "uni_normal_dive")

	assert_true(game_logic.do_character_action(player1, []))
	assert_true(game_logic.do_choice(player1, 1))  # Retreat 1
	var events = game_logic.get_latest_events()

	validate_positions(player1, 2, player2, 6)
	# Hand revealed due to lack of continuous boosts
	validate_has_event(events, Enums.EventType.EventType_RevealHand, player1, 0)

## Exceed character ability -- Action: Close or Retreat 1. Play a Continuous
## Boost from your Gauge; if you did, and if it did not cause a strike, take
## another action other than Strike.

func test_wagner_exceed_ua_with_boost_no_strike():
	position_players(player1, 3, player2, 6)
	player1.exceed()
	player1.hand = []
	var cross_id = give_player_specific_card(player1, "uni_normal_cross")
	player1.move_card_from_hand_to_gauge(cross_id)

	assert_true(game_logic.do_character_action(player1, []))
	assert_true(game_logic.do_choice(player1, 0))
	# Note: The enforcement of the "from Gauge" portion of the action is done
	# from the UI. It is not checked in this test.
	assert_true(game_logic.do_boost(player1, cross_id, []))
	assert_false(game_logic.can_do_strike(player1))
	assert_eq(game_logic.get_active_player(), player1.my_id)
	assert_true(game_logic.do_prepare(player1))

	assert_true(player1.is_card_in_continuous_boosts(cross_id))
	validate_positions(player1, 4, player2, 6)

func test_wagner_exceed_ua_with_boost_strike():
	position_players(player1, 3, player2, 6)
	player1.exceed()
	player1.hand = []
	var sweep_id = give_player_specific_card(player1, "uni_normal_sweep")
	player1.move_card_from_hand_to_gauge(sweep_id)

	assert_true(game_logic.do_character_action(player1, []))
	assert_true(game_logic.do_choice(player1, 0))
	assert_true(game_logic.do_boost(player1, sweep_id, []))
	execute_strike(player1, player2, "uni_normal_sweep", "uni_normal_assault")
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 29, player2, 24)

func test_wagner_exceed_ua_with_no_boost():
	position_players(player1, 3, player2, 6)
	player1.exceed()
	player1.hand = []
	var cross_id = give_player_specific_card(player1, "uni_normal_cross")
	player1.move_card_from_hand_to_gauge(cross_id)

	assert_true(game_logic.do_character_action(player1, []))
	assert_true(game_logic.do_choice(player1, 0))
	assert_true(game_logic.do_boost(player1, cross_id, []))

	assert_true(game_logic.do_character_action(player1, []))
	assert_true(game_logic.do_choice(player1, 0))

	assert_eq(game_logic.get_active_player(), player2.my_id)
	assert_true(player1.is_card_in_continuous_boosts(cross_id))
	validate_positions(player1, 5, player2, 6)

## Filthy Dog! boost -- Advance up to 3. If you advanced past the opponent, add
## a Special or Ultra from your discard pile to your hand.

func test_wagner_recover_no_crossup():
	position_players(player1, 3, player2, 6)
	var boost_id = give_player_specific_card(player1, "wagner_filthydog")
	var discard_id = give_player_specific_card(player1, "wagner_megiddo")
	player1.discard([discard_id])

	assert_true(game_logic.do_boost(player1, boost_id, []))
	assert_true(game_logic.do_choice(player1, 1))  # Advance 2

	validate_positions(player1, 5, player2, 6)
	assert_ne(game_logic.game_state, Enums.GameState.GameState_PlayerDecision,
			"Wagner is offered a Recover choice despite lack of crossup")
	assert_eq(game_logic.get_active_player(), player2.my_id)

func test_wagner_recover_crossup():
	position_players(player1, 3, player2, 6)
	var boost_id = give_player_specific_card(player1, "wagner_filthydog")
	var special_id = give_player_specific_card(player1, "wagner_megiddo")
	var normal_id = give_player_specific_card(player1, "uni_normal_dive")
	player1.discard([special_id, normal_id])

	assert_true(game_logic.do_boost(player1, boost_id, []))
	assert_true(game_logic.do_choice(player1, 2))  # Advance 3
	assert_false(game_logic.do_choose_from_discard(player1, [normal_id]),
			"Wagner was permitted to recur a non-Special/Ultra from discard.")
	assert_true(game_logic.do_choose_from_discard(player1, [special_id]),
			"Wagner failed to recover a Special from discard.")

	validate_positions(player1, 7, player2, 6)
	assert_true(player1.is_card_in_hand(special_id))
	assert_eq(game_logic.get_active_player(), player2.my_id)

## Kugel Blitz (1/4/5) -- Before: Close 2.
##     After: Advance 2. If this did not hit, you may add it to your Boost area
##       as a Continuous Boost (+1 POW, Before: Close 1) and sustain it.

func test_wagner_kugel_blitz_hit():
	position_players(player1, 3, player2, 6)

	var strike_cards = execute_strike(player1, player2, "wagner_kugelblitz", "uni_normal_assault")
	validate_positions(player1, 8, player2, 6)
	validate_life(player1, 30, player2, 26)
	assert_true(player1.is_card_in_gauge(strike_cards[0]))

func test_wagner_kugel_blitz_miss():
	position_players(player1, 2, player2, 6)

	var strike_cards = execute_strike(player1, player2, "wagner_kugelblitz", "uni_normal_assault",
			false, false, [0], [])  # Confirm After: effect
	validate_positions(player1, 7, player2, 6)
	validate_life(player1, 26, player2, 30)
	assert_true(player1.is_card_in_continuous_boosts(strike_cards[0]))

## Schild Zack (2/5/6) -- After: If this did not hit, you may add it to your
##     Boost area as a Continuous Boost (+1 ARM, +3 GRD) and sustain it.

func test_wagner_schild_zack_hit():
	position_players(player1, 4, player2, 6)

	var strike_cards = execute_strike(player1, player2, "wagner_schildzack", "uni_normal_assault")
	validate_positions(player1, 4, player2, 6)
	validate_life(player1, 30, player2, 25)
	assert_true(player1.is_card_in_gauge(strike_cards[0]))

func test_wagner_schild_zack_miss():
	position_players(player1, 3, player2, 6)

	var strike_cards = execute_strike(player1, player2, "wagner_schildzack", "uni_normal_assault",
			false, false, [0], [])  # Confirm After: effect
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 27, player2, 30)  # +1 ARM from boost applies during current strike
	assert_true(player1.is_card_in_continuous_boosts(strike_cards[0]))

## Sturm Brecher (1~2/5/4) -- Hit: Push 3. After: If this did not hit, you may
##     add this to your Boost area as a Continuous Boost (+1 SPD, Now: Move 1)
##     and sustain it.

func test_wagner_sturm_brecher_hit():
	position_players(player1, 4, player2, 6)

	var strike_cards = execute_strike(player1, player2, "wagner_sturmbrecher", "uni_normal_dive")
	validate_positions(player1, 4, player2, 9)
	validate_life(player1, 30, player2, 25)
	assert_true(player1.is_card_in_gauge(strike_cards[0]))
	advance_turn(player2)

func test_wagner_sturm_brecher_miss():
	position_players(player1, 3, player2, 7)

	var strike_cards = execute_strike(player1, player2, "wagner_sturmbrecher", "uni_normal_dive",
			false, false, [0, 1], [])  # Confirm After: effect; retreat with Now: on boost
	validate_positions(player1, 2, player2, 4)
	validate_life(player1, 30, player2, 30)
	assert_true(player1.is_card_in_continuous_boosts(strike_cards[0]))
	advance_turn(player2)

## Wacken Roder boost -- +1 POW. Hit: Gain ARM equal to your POW.

func test_wagner_deflection():
	position_players(player1, 3, player2, 6)
	var wackenroder_id = give_player_specific_card(player1, "wagner_wackenroder")
	assert_true(game_logic.do_boost(player1, wackenroder_id, []))
	advance_turn(player2)

	execute_strike(player1, player2, "uni_normal_assault", "uni_normal_sweep",
			true, false, [0], [])  # EX assault; must specify Hit: trigger ordering
	validate_positions(player1, 5, player2, 6)
	validate_life(player1, 30, player2, 24)  # EX Assault + Boost = 6 POW -> 6 ARM
	advance_turn(player1)  # Advantage turn

## Hitze Falke (3~4/7/1|3/3) -- You may set this attack face-up from your Boost
##     area. If this attack is set in any other way, it is invalid.
##     After: Seal this.

# ## strike_boost_id gets used because Wagner's Ultras must be set from her Boost area or be invalid.

func test_wagner_hitze_falke_invalid_from_hand():
	position_players(player1, 3, player2, 7)
	give_gauge(player1, 2)
	var dive_id = give_player_specific_card(player1, "uni_normal_dive")
	player1.move_card_from_hand_to_deck(dive_id)

	var strike_cards = execute_strike(player1, player2, "wagner_hitzefalke", "uni_normal_sweep")
	# Expected: Wagner invalidates Hitze Falke and wild swings Dive
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 24, player2, 25)
	assert_true(player1.is_card_in_discards(strike_cards[0]))
	assert_true(player1.is_card_in_gauge(dive_id))
	advance_turn(player2)

func test_wagner_hitze_falke_valid_from_boosts():
	position_players(player1, 3, player2, 7)
	var p1_gauge = give_gauge(player1, 2)
	var hitzefalke_id = give_player_specific_card(player1, "wagner_hitzefalke")
	assert_true(game_logic.do_boost(player1, hitzefalke_id, []))
	advance_turn(player2)

	execute_strike(player1, player2, hitzefalke_id, "uni_normal_sweep",
		false, false, [p1_gauge], [])  # Pay for Ultra
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 23)
	assert_true(player1.is_card_in_sealed(hitzefalke_id))
	advance_turn(player2)

## Megiddo (1~2/6/6) -- You may set this attack face-up from your Boost area. If
##     this attack is set in any other way, it is invalid.
##     After: Seal this.

func test_wagner_megiddo_invalid_from_hand():
	position_players(player1, 3, player2, 5)
	give_gauge(player1, 2)
	var assault_id = give_player_specific_card(player1, "uni_normal_assault")
	player1.move_card_from_hand_to_deck(assault_id)

	var strike_cards = execute_strike(player1, player2, "wagner_megiddo", "uni_normal_sweep")
	# Expected: Wagner invalidates Megiddo and wild swings Assault
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 24, player2, 26)
	assert_true(player1.is_card_in_discards(strike_cards[0]))
	assert_true(player1.is_card_in_gauge(assault_id))
	advance_turn(player1)

func test_wagner_megiddo_valid_from_boosts():
	position_players(player1, 3, player2, 5)
	var p1_gauge = give_gauge(player1, 2)
	var megiddo_id = give_player_specific_card(player1, "wagner_megiddo")
	assert_true(game_logic.do_boost(player1, megiddo_id, []))
	advance_turn(player2)

	execute_strike(player1, player2, megiddo_id, "uni_normal_sweep",
			false, false, [p1_gauge], [])  # Pay for Ultra
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 24, player2, 24)
	assert_true(player1.is_card_in_sealed(megiddo_id))
	advance_turn(player2)
