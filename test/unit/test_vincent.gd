extends ExceedGutTest

func who_am_i():
	return "vincent"

##
## Tests start here
##

func test_vincent_nationalguard_closedamagetaken_basic():
	position_players(player1, 4, player2, 5)
	execute_strike(player1, player2, "vincent_nationalguard", "standard_normal_cross", false, false,
		[[player1.hand[0].id, player1.hand[1].id, true, false, false]], [[]]) # use ultras as 1 for simplicity

	# P1 gets 4 guard, takes 3 from cross, closes 3, and hits for 6
	validate_life(player1, 27, player2, 24)
	validate_positions(player1, 7, player2, 8)
	advance_turn(player2)

func test_vincent_nationalguard_closedamagetaken_armorcheck():
	position_players(player1, 4, player2, 5)
	player1.exceed()
	execute_strike(player1, player2, "vincent_nationalguard", "standard_normal_cross", false, false,
		[[player1.hand[0].id, true, false, false]], [[]]) # use ultras as 1 for simplicity

	# P1 gets 1 armor 2 guard, takes 2 from cross, closes 2, and misses
	validate_life(player1, 28, player2, 30)
	validate_positions(player1, 6, player2, 8)
	advance_turn(player2)


func test_vincent_nationalguard_closedamagetaken_armorcheck_twice():
	position_players(player1, 4, player2, 6)
	player1.exceed()
	advance_turn(player1)
	give_player_specific_card(player2, "standard_normal_grasp")
	assert_true(game_logic.do_boost(player2, player2.hand[-1].id, []))
	execute_strike(player1, player2, "vincent_nationalguard", "standard_normal_cross", false, true,
		[[player1.hand[0].id, player1.hand[1].id, true, false, false]], [[]]) # use ultras as 1 for simplicity

	# P1 gets 2 armor 4 guard, takes 4 from ex cross (+2 power), closes 4, and hits
	validate_life(player1, 26, player2, 25)
	validate_positions(player1, 8, player2, 9)
	advance_turn(player2)


func test_vincent_crimsonbarrage_boost_name2():
	position_players(player1, 1, player2, 5)
	var p2cardsdiscarded = []
	p2cardsdiscarded.append(give_player_specific_card(player2, "vincent_phoenixrevival"))
	p2cardsdiscarded.append(give_player_specific_card(player2, "vincent_phoenixrevival"))
	p2cardsdiscarded.append(give_player_specific_card(player2, "standard_normal_focus"))

	execute_strike(player1, player2, "vincent_crimsonbarrage", "standard_normal_spike", false, false,
		[[], p2cardsdiscarded[0], p2cardsdiscarded[2]], [[]])

	validate_life(player1, 30, player2, 26)
	validate_positions(player1, 1, player2, 5)

	# 3 discards + the strike
	assert_true(player2.discards.size() >= 4)
	for id in p2cardsdiscarded:
		var found = false
		for card in player2.discards:
			if card.id == id:
				found = true
				break
		assert_true(found, "Missing expected discard %s" % id)
	advance_turn(player2)
