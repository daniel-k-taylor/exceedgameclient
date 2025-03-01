extends ExceedGutTest

func who_am_i():
	return "morathi"

##
## Tests start here
##

func test_morathi_ua():
	position_players(player1, 5, player2, 7)
	set_player_topdeck(player1, "standard_normal_assault")
	set_player_topdeck(player1, "standard_normal_dive")
	execute_strike(player1, player2, -1, "standard_normal_assault", false, false,
		[0], [])
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 26)
	advance_turn(player1)

func test_morathi_ua_2ndoption():
	position_players(player1, 5, player2, 7)
	set_player_topdeck(player1, "standard_normal_assault")
	set_player_topdeck(player1, "standard_normal_dive")
	execute_strike(player1, player2, -1, "standard_normal_assault", false, false,
		[1], [])
	validate_positions(player1, 5, player2, 6)
	validate_life(player1, 26, player2, 30)
	advance_turn(player2)


func test_morathi_ua_p2():
	position_players(player1, 4, player2, 7)
	set_player_topdeck(player2, "standard_normal_dive")
	set_player_topdeck(player2, "standard_normal_assault")
	execute_strike(player1, player2, "standard_normal_dive", -1, false, false,
		[], [0])
	validate_positions(player1, 8, player2, 7)
	validate_life(player1, 30, player2, 25)
	advance_turn(player2)

func test_morathi_ua_2ndoption_p2():
	position_players(player1, 4, player2, 7)
	set_player_topdeck(player2, "standard_normal_dive")
	set_player_topdeck(player2, "standard_normal_assault")
	execute_strike(player1, player2, "standard_normal_dive", -1, false, false,
		[], [1])
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 26, player2, 30)
	advance_turn(player2)


func test_morathi_ua_fakeout():
	position_players(player1, 5, player2, 7)
	give_player_specific_card(player1, "akuma_hyakkishu")
	assert_true(game_logic.do_boost(player1, player1.hand[-1].id, []))
	# P2 sets attack first.
	set_player_topdeck(player2, "standard_normal_cross")
	var top = set_player_topdeck(player2, "standard_normal_dive")
	# Set first initiate
	assert_true(game_logic.do_strike(player1, -1, false, -1, true))
	# P2 wild swing
	assert_true(game_logic.do_strike(player2, -1, true, -1, true))
	# P2 choose draw or just strike
	assert_true(game_logic.do_choice(player2, 0))
	assert_eq(player2.hand[-1].id, top)
	# P1 Strike
	var p1attack = give_player_specific_card(player1, "standard_normal_assault")
	assert_true(game_logic.do_strike(player1, p1attack, false, -1, true))
	validate_positions(player1, 5, player2, 9)
	validate_life(player1, 27, player2, 30)
	advance_turn(player2)


func test_morathi_ua_fakeout_option2():
	position_players(player1, 5, player2, 7)
	give_player_specific_card(player1, "akuma_hyakkishu")
	assert_true(game_logic.do_boost(player1, player1.hand[-1].id, []))
	# P2 sets attack first.
	set_player_topdeck(player2, "standard_normal_cross")
	set_player_topdeck(player2, "standard_normal_dive")
	# Set first initiate
	assert_true(game_logic.do_strike(player1, -1, false, -1, true))
	# P2 wild swing
	assert_true(game_logic.do_strike(player2, -1, true, -1, true))
	# P2 choose draw or just strike
	assert_true(game_logic.do_choice(player2, 1))
	# P1 Strike
	var p1attack = give_player_specific_card(player1, "standard_normal_assault")
	assert_true(game_logic.do_strike(player1, p1attack, false, -1, true))
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 26)
	advance_turn(player1)
