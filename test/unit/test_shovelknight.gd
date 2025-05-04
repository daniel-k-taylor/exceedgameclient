extends ExceedGutTest

const TestCardId1 = 50001
const TestCardId2 = 50002

func who_am_i():
	return "shovelknight"

##
## Tests start here
##

func test_shovelknight_ua():
	position_players(player1, 5, player2, 7)
	assert_eq(player1.hand.size(), 5)
	assert_true(game_logic.do_move(player1, [player1.hand[0].id], 4))
	assert_eq(player1.hand.size(), 6) # UA and end of turn draw
	validate_positions(player1, 4, player2, 7)
	advance_turn(player2)


func test_shovelknight_ua_exceed():
	player1.exceed()
	position_players(player1, 5, player2, 7)
	assert_eq(player1.hand.size(), 5)
	assert_true(game_logic.do_move(player1, [player1.hand[0].id], 6))
	validate_positions(player1, 6, player2, 7)
	assert_eq(player1.hand.size(), 5) # UA bonus then choice
	assert_true(game_logic.do_choice(player1, 0)) # Advance
	validate_positions(player1, 8, player2, 7)
	assert_eq(player1.hand.size(), 6) # End of turn draw
	advance_turn(player2)



func test_shovelknight_alchemycoin_draw_spaces_between_0():
	position_players(player1, 6, player2, 9)
	assert_eq(player1.hand.size(), 5)
	execute_strike(player1, player2, "shovelknight_alchemycoin", "standard_normal_assault", false, false,
		[], [])
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 26, player2, 26)
	assert_eq(player1.hand.size(), 5)
	advance_turn(player2)


func test_shovelknight_alchemycoin_draw_spaces_between_4():
	position_players(player1, 1, player2, 6)
	assert_eq(player1.hand.size(), 5)
	execute_strike(player1, player2, "shovelknight_alchemycoin", "standard_normal_sweep", false, false,
		[], [])
	validate_positions(player1, 1, player2, 6)
	validate_life(player1, 30, player2, 26)
	assert_eq(player1.hand.size(), 9)
	advance_turn(player2)


func test_shovelknight_propellerdagger_returntohand():
	position_players(player1, 5, player2, 7)
	var p1gauge = give_gauge(player1, 3)
	assert_eq(player1.hand.size(), 5)
	var attack = give_player_specific_card(player1, "shovelknight_propellerdagger")
	execute_strike(player1, player2, attack, "standard_normal_cross", false, false,
		[[p1gauge[0]], [p1gauge[1]], [p1gauge[2]], 1], [])
	validate_positions(player1, 2, player2, 7)
	validate_life(player1, 30, player2, 26)
	assert_eq(player1.gauge.size(), 0)
	assert_eq(player1.hand[-1].id, attack)
	advance_turn(player2)


func test_shovelknight_propellerdagger_skip_returntohand():
	position_players(player1, 5, player2, 7)
	var p1gauge = give_gauge(player1, 3)
	assert_eq(player1.hand.size(), 5)
	var attack = give_player_specific_card(player1, "shovelknight_propellerdagger")
	execute_strike(player1, player2, attack, "standard_normal_cross", false, false,
		[[p1gauge[0]], [], [p1gauge[2]], 0], [])
	validate_positions(player1, 9, player2, 7)
	validate_life(player1, 30, player2, 26)
	assert_eq(player1.gauge.size(), 2)
	assert_ne(player1.hand[-1].id, attack)
	advance_turn(player2)

func test_shovelknight_justiceinspades_auto_discard_self():
	position_players(player1, 3, player2, 6)
	assert_eq(player1.hand.size(), 5)
	var boost = give_player_specific_card(player1, "shovelknight_troupplechalice")
	assert_true(game_logic.do_boost(player1, boost, []))
	assert_eq(player1.hand.size(), 7)
	
func test_shovelknight_justiceinspades_choice_discard_self():
	position_players(player1, 3, player2, 6)
	assert_eq(player1.hand.size(), 5)
	var boost1 = give_player_specific_card(player1, "standard_normal_grasp")
	var boost2 = give_player_specific_card(player1, "shovelknight_troupplechalice")
	assert_true(game_logic.do_boost(player1, boost1, []))
	assert_true(player1.is_card_in_continuous_boosts(boost1))
	advance_turn(player2)
	assert_true(game_logic.do_boost(player1, boost2, []))
	assert_true(game_logic.do_choice(player1, 0))
	assert_true(player1.is_card_in_continuous_boosts(boost1))
	assert_false(player1.is_card_in_continuous_boosts(boost2))
	assert_eq(player1.hand.size(), 8)

func test_shovelknight_justiceinspades_choice_discard_other():
	position_players(player1, 3, player2, 6)
	assert_eq(player1.hand.size(), 5)
	var boost1 = give_player_specific_card(player1, "standard_normal_grasp")
	var boost2 = give_player_specific_card(player1, "shovelknight_troupplechalice")
	assert_true(game_logic.do_boost(player1, boost1, []))
	assert_true(player1.is_card_in_continuous_boosts(boost1))
	advance_turn(player2)
	assert_true(game_logic.do_boost(player1, boost2, []))
	assert_true(game_logic.do_choice(player1, 1))
	assert_true(game_logic.do_boost_name_card_choice_effect(player1, boost1))
	assert_false(player1.is_card_in_continuous_boosts(boost1))
	assert_true(player1.is_card_in_continuous_boosts(boost2))
	assert_eq(player1.hand.size(), 8)
	
