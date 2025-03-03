extends ExceedGutTest

func who_am_i():
	return "remiliss"

##
## Tests start here
##

func test_remiliss_exceed_ua():
	position_players(player1, 1, player2, 7)
	player1.exceed()
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault", true, false,
		[0, 0, 0, 0], [[]])
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 25)
	advance_turn(player1)

func test_remiliss_consumption_hit():
	position_players(player1, 5, player2, 7)
	var p1gauge = give_gauge(player1, 4)
	var search_cards = [player1.deck[4].id, player1.deck[13].id, player1.deck[20].id]
	execute_strike(player1, player2, "remiliss_consumption", "standard_normal_assault", false, false,
		[[], p1gauge,
			search_cards[0], "add_to_hand",
			search_cards[1], "add_to_hand",
			search_cards[2], "add_to_hand"
		],
		[[]]
	)
	validate_positions(player1, 5, player2, 7)
	validate_life(player1, 30, player2, 26)
	assert_true(player1.is_card_in_hand(search_cards[0]))
	assert_true(player1.is_card_in_hand(search_cards[1]))
	assert_true(player1.is_card_in_hand(search_cards[2]))
	advance_turn(player2)


func test_remiliss_consumption_hit_pass_after_1():
	position_players(player1, 5, player2, 7)
	var p1gauge = give_gauge(player1, 4)
	var search_cards = [player1.deck[4].id, player1.deck[13].id, player1.deck[20].id]
	execute_strike(player1, player2, "remiliss_consumption", "standard_normal_assault", false, false,
		[[], p1gauge,
			search_cards[0], "add_to_hand",
			-1, "pass"
		],
		[[]]
	)
	validate_positions(player1, 5, player2, 7)
	validate_life(player1, 30, player2, 26)
	assert_true(player1.is_card_in_hand(search_cards[0]))
	assert_false(player1.is_card_in_hand(search_cards[1]))
	assert_false(player1.is_card_in_hand(search_cards[2]))
	advance_turn(player2)


func test_remiliss_nuclearoption_free_if_ex_notfree():
	position_players(player1, 3, player2, 7)
	player1.discard_hand()
	var p1gauge = give_gauge(player1, 1)
	execute_strike(player1, player2, "remiliss_nuclearoption", "standard_normal_assault", false, false,
		[p1gauge,
		],
		[[]]
	)
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 30, player2, 26)
	assert_eq(player1.gauge.size(), 3)
	advance_turn(player2)


func test_remiliss_nuclearoption_free_if_ex_notfree_opponent_faster():
	position_players(player1, 3, player2, 7)
	player1.discard_hand()
	var p1gauge = give_gauge(player1, 1)
	execute_strike(player1, player2, "remiliss_nuclearoption", "remiliss_irradiate", false, false,
		[p1gauge],
		[[], 0]
	)
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 25, player2, 30)
	assert_eq(player1.gauge.size(), 0)
	advance_turn(player2)

func test_remiliss_nuclearoption_free_if_ex_free():
	position_players(player1, 3, player2, 7)
	player1.discard_hand()
	give_gauge(player1, 1)
	execute_strike(player1, player2, "remiliss_nuclearoption", "remiliss_irradiate", true, false,
		[],
		[[]]
	)
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 25)
	assert_eq(player1.gauge.size(), 4)
	advance_turn(player2)


func test_remiliss_groundzero_cc_transform():
	position_players(player1, 3, player2, 7)
	player1.discard_hand()
	var t1 = give_player_specific_card(player1, "remiliss_groundzero")
	var t2 = give_player_specific_card(player1, "remiliss_groundzero")
	assert_true(game_logic.do_boost(player1, t1, [t2]))
	advance_turn(player2)
	assert_eq(player1.hand.size(), 1)
	give_player_specific_card(player1, "standard_normal_assault")
	assert_true(game_logic.do_change(player1, [player1.hand[-1].id], false, true))
	assert_eq(player1.hand.size(), 4)
	advance_turn(player2)


func test_remiliss_groundzero_cc_transform_dontuse():
	position_players(player1, 3, player2, 7)
	player1.discard_hand()
	var t1 = give_player_specific_card(player1, "remiliss_groundzero")
	var t2 = give_player_specific_card(player1, "remiliss_groundzero")
	assert_true(game_logic.do_boost(player1, t1, [t2]))
	advance_turn(player2)
	assert_eq(player1.hand.size(), 1)
	give_player_specific_card(player1, "standard_normal_assault")
	assert_true(game_logic.do_change(player1, [player1.hand[-1].id], false, false))
	assert_eq(player1.hand.size(), 3)
	advance_turn(player2)


func test_remiliss_irradiate_and_toxic_tendrils_transform():
	position_players(player1, 1, player2, 7)
	add_transform(player1, "remiliss_irradiate")
	add_transform(player1, "remiliss_toxictendrils")
	player1.discard_hand()
	execute_strike(player1, player2, "remiliss_irradiate", "standard_normal_dive", false, false,
		[],
		[[]]
	)
	validate_positions(player1, 1, player2, 7)
	validate_life(player1, 30, player2, 24)
	advance_turn(player2)


func test_remiliss_toxic_tendrils_transform_ex_requirement_check():
	position_players(player1, 1, player2, 7)
	add_transform(player1, "remiliss_toxictendrils")
	player1.discard_hand()
	execute_strike(player1, player2, "remiliss_irradiate", "standard_normal_sweep", false, false,
		[],
		[[]]
	)
	validate_positions(player1, 1, player2, 7)
	validate_life(player1, 30, player2, 30)
	advance_turn(player2)



func test_remiliss_napalmstream_cap_attack_damage_taken():
	position_players(player1, 5, player2, 7)
	assert_eq(player1.hand.size(), 5)
	execute_strike(player1, player2, "remiliss_napalmstream", "standard_normal_sweep", true, true,
		[[], 1], # Discard top for +2 power
		[[]]
	)
	# P1 should have taken 6 (7-1 armor) but instead is capped to 5.
	assert_eq(player1.hand.size(), 4)
	validate_positions(player1, 5, player2, 7)
	validate_life(player1, 25, player2, 25)
	advance_turn(player2)


func test_remiliss_napalmstream_cap_attack_damage_taken_drawchoice():
	position_players(player1, 5, player2, 7)
	assert_eq(player1.hand.size(), 5)
	execute_strike(player1, player2, "remiliss_napalmstream", "standard_normal_sweep", true, true,
		[[], 0], # Draw instead
		[[]]
	)
	assert_eq(player1.hand.size(), 5)
	# P1 should have taken 6 (7-1 armor) but instead is capped to 5.
	validate_positions(player1, 5, player2, 7)
	validate_life(player1, 25, player2, 27)
	advance_turn(player2)
