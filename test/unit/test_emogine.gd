extends ExceedGutTest

func who_am_i():
	return "emogine"

##
## Tests start here
##

func test_emogine_bloodforblood_transform_and_attack():
	position_players(player1, 3, player2, 7)
	add_transform(player1, "emogine_bloodforblood")
	player1.life = 20
	set_player_topdeck(player1, "emogine_bloodforblood")
	set_player_topdeck(player2, "standard_normal_dive")
	execute_strike(player1, player2, -1, -1, false, false,
		[1, 1], [1]) # Both need to decide not to pay 1 life to flip next card
	# Both wild swing, p1 goes up to 21 life and gets +1 power
	# P2 hits for 5
	# P1 gets +5 power
	# P1 hit spend life choice 1, 2, pass - +1 power each
	# P1 hits back
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 14, player2, 21)

func test_emogine_bloodforblood_transform_and_attack_opponent_notwild():
	position_players(player1, 3, player2, 7)
	add_transform(player1, "emogine_bloodforblood")
	player1.life = 20
	set_player_topdeck(player1, "emogine_bloodforblood")
	execute_strike(player1, player2, -1, "standard_normal_dive", false, false,
		[1, 2], []) # Only p1 is wilding
	# p1 goes up to 21 life
	# P2 hits for 5
	# P1 gets +5 power
	# P1 hit spend life choice 1, 2, pass - +1 power each
	# P1 hits back
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 16, player2, 24)

func test_emogine_guiltypaean_transform():
	position_players(player1, 3, player2, 6)
	add_transform(player1, "emogine_guiltypaean")
	player1.life = 20
	set_player_topdeck(player1, "standard_normal_assault")
	var expected_gauge = set_player_topdeck(player1, "standard_normal_dive")
	execute_strike(player1, player2, -1, "standard_normal_assault", false, false,
		[0, 0, [expected_gauge]], []) # Char ability, then transform ability
		# P1 pay life to get wild to gauge, then pay 1 for +2 power
	validate_positions(player1, 5, player2, 6)
	validate_life(player1, 19, player2, 24)


func test_emogine_guiltypaean_transform_hit_holywarding():
	position_players(player1, 3, player2, 6)
	add_transform(player1, "emogine_guiltypaean")
	player1.life = 20
	set_player_topdeck(player1, "emogine_holywarding")
	var expected_gauge = set_player_topdeck(player1, "standard_normal_dive")
	execute_strike(player1, player2, -1, "standard_normal_dive", false, false,
		[0, 0, [expected_gauge], 1], []) # char ability, then transform ability
		# Pay 1 life to wild to gauge
		# Then simul effect between transform hit and attack hit, automatically resolved though not through choice.
		# Total +4 power
		# After strike can transform, don't
	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 19, player2, 22)


func test_emogine_holywarding_transform_exceed_get_life():
	position_players(player1, 3, player2, 6)
	add_transform(player1, "emogine_holywarding")
	player1.life = 20
	var gauge = give_gauge(player1, 4)
	assert_true(game_logic.do_exceed(player1, gauge))
	validate_life(player1, 21, player2, 30)
	advance_turn(player2)


func test_emogine_holywarding_transform_cc_gain_life():
	position_players(player1, 3, player2, 6)
	add_transform(player1, "emogine_holywarding")
	player1.life = 20
	player1.discard_hand()
	var gauge = give_gauge(player1, 2)
	assert_true(game_logic.do_change(player1, gauge, true))
	validate_life(player1, 21, player2, 30)
	assert_eq(player1.hand.size(), 3)
	advance_turn(player2)


func test_emogine_holywarding_transform_move_gain_life():
	position_players(player1, 3, player2, 6)
	add_transform(player1, "emogine_holywarding")
	player1.life = 20
	player1.discard_hand()
	var gauge = give_gauge(player1, 2)
	assert_true(game_logic.do_move(player1, gauge, 1))
	validate_life(player1, 21, player2, 30)
	validate_positions(player1, 1, player2, 6)
	advance_turn(player2)


func test_emogine_holywarding_transform_payboost_gain_life():
	position_players(player1, 3, player2, 6)
	add_transform(player1, "emogine_holywarding")
	player1.life = 20
	player1.discard_hand()
	var gauge = give_gauge(player1, 2)
	give_player_specific_card(player1, "emogine_martyrslash")
	assert_true(game_logic.do_boost(player1, player1.hand[-1].id, [gauge[0]]))
	validate_life(player1, 21, player2, 30)

func test_emogine_holywarding_transform_guiltypaean_transform_gain_life():
	position_players(player1, 3, player2, 6)
	add_transform(player1, "emogine_holywarding")
	add_transform(player1, "emogine_guiltypaean")
	player1.life = 20
	set_player_topdeck(player1, "standard_normal_assault")
	var expected_gauge = set_player_topdeck(player1, "standard_normal_dive")
	execute_strike(player1, player2, -1, "standard_normal_assault", false, false,
		[0, 0, [expected_gauge]], []) # Char ability, then transform ability
		# P1 pay life to get wild to gauge, then pay 1 for +2 power
	validate_positions(player1, 5, player2, 6)
	validate_life(player1, 20, player2, 24)


func test_emogine_holywarding_transform_ultra_gain_life():
	position_players(player1, 3, player2, 5)
	add_transform(player1, "emogine_holywarding")
	add_transform(player1, "emogine_guiltypaean")
	player1.life = 20
	var gauge = give_gauge(player1, 2)
	execute_strike(player1, player2, "emogine_handofjudgment", "standard_normal_assault", false, false,
		[gauge], [])
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 21, player2, 23)


func test_emogine_exceed_startturn_effect():
	position_players(player1, 3, player2, 5)
	player1.exceed()
	advance_turn(player1)
	advance_turn(player2)
	var topdeck = player1.deck[0].id
	assert_true(game_logic.do_choice(player1, 0))
	assert_ne(player1.deck[0].id, topdeck)
	assert_eq(player1.deck[-1].id, topdeck)


func test_emogine_exceed_startturn_effect_pass():
	position_players(player1, 3, player2, 5)
	player1.exceed()
	advance_turn(player1)
	advance_turn(player2)
	var topdeck = player1.deck[0].id
	assert_true(game_logic.do_choice(player1, 1))
	assert_eq(player1.deck[0].id, topdeck)


func test_emogine_martyrslash_boost():
	position_players(player1, 2, player2, 5)
	player1.life = 20
	give_gauge(player1, 5)
	var boost_card = give_player_specific_card(player1, "emogine_martyrslash")
	assert_true(game_logic.do_boost(player1, boost_card, [player1.hand[0].id]))
	assert_true(game_logic.do_choice(player1, 1))
	validate_positions(player1, 7, player2, 5)
	advance_turn(player2)
	var boost_card2 = give_player_specific_card(player1, "emogine_martyrslash")
	assert_true(game_logic.do_boost(player1, boost_card2, [player1.hand[0].id]))
	assert_true(game_logic.do_choice(player1, 0))
	validate_positions(player1, 3, player2, 5)
	advance_turn(player2)
	set_player_topdeck(player1, "emogine_handofjudgment")
	execute_strike(player1, player2, -1, "standard_normal_assault", false, false,
		[1, "alt_cost"], []) # Pass emo's ability, pay 3 life to wild pay cost
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 23, player2, 23)


func test_emogine_purifyingchime_transform():
	position_players(player1, 2, player2, 5)
	player1.life = 20
	add_transform(player1, "emogine_purifyingchime")
	set_player_topdeck(player1, "standard_normal_assault")
	execute_strike(player1, player2, -1, "standard_normal_assault", false, false,
		[1, 0], []) # Pass emo's ability, simul effects assault and hit gain life
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 22, player2, 26)
	advance_turn(player1)

func test_emogine_purifyingchime_transform_opp_lower_life():
	position_players(player1, 2, player2, 5)
	player1.life = 20
	player2.life = 10
	add_transform(player1, "emogine_purifyingchime")
	set_player_topdeck(player1, "standard_normal_assault")
	execute_strike(player1, player2, -1, "standard_normal_assault", false, false,
		[1, 0], []) # Pass emo's ability, simul
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 20, player2, 6)
	advance_turn(player1)


func test_emogine_touchofdivinity_invalid():
	position_players(player1, 2, player2, 5)
	player1.life = 20
	set_player_topdeck(player1, "standard_normal_assault")
	set_player_topdeck(player1, "emogine_touchofdivinity")
	execute_strike(player1, player2, -1, "standard_normal_assault", false, false,
		[1], []) # Pass emo's ability
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 20, player2, 23)
	advance_turn(player1)


func test_emogine_touchofdivinity_boost():
	position_players(player1, 2, player2, 5)
	player1.life = 20
	player1.discard_hand()
	var gauged_transform = give_player_specific_card(player1, "emogine_holywarding")
	player1.gauge.append(player1.hand[-1])
	player1.hand.remove_at(player1.hand.size() -1)
	give_player_specific_card(player1, "emogine_touchofdivinity")
	assert_true(game_logic.do_boost(player1, player1.hand[-1].id, []))
	var top3 = player1.deck.slice(0, 3)
	assert_true(game_logic.do_choose_from_topdeck(player1, top3[1].id, "add_to_topdeck_under_2"))
	assert_true(game_logic.do_choose_from_topdeck(player1, top3[0].id, "add_to_topdeck_under"))
	assert_eq(player1.deck[0].id, top3[2].id)
	assert_eq(player1.deck[1].id, top3[0].id)
	assert_eq(player1.deck[2].id, top3[1].id)
	assert_true(game_logic.do_boost(player1, gauged_transform, []))
	
	assert_eq(player1.hand[-1].id, top3[2].id)
	assert_eq(player1.deck[0].id, top3[0].id)
	assert_eq(player1.deck[1].id, top3[1].id)
	advance_turn(player2)
