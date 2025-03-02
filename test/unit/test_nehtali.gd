extends ExceedGutTest

func who_am_i():
	return "nehtali"

##
## Tests start here
##

func test_nehtali_heavenspunishment_poweruppergauge_opponent_none():
	position_players(player1, 4, player2, 7)
	var p1gauge = give_gauge(player1, 3)
	execute_strike(player1, player2, "nehtali_heavenspunishment", "standard_normal_assault", false, false,
		[p1gauge, 1], [])
	validate_life(player1, 30, player2, 30)
	validate_positions(player1, 3, player2, 5)
	advance_turn(player2)


func test_nehtali_heavenspunishment_poweruppergauge_opponent():
	position_players(player1, 4, player2, 7)
	var p1gauge = give_gauge(player1, 3)
	give_gauge(player2, 5)
	execute_strike(player1, player2, "nehtali_heavenspunishment", "standard_normal_assault", false, false,
		[p1gauge, 0], [])
	validate_life(player1, 30, player2, 20)
	validate_positions(player1, 5, player2, 7)
	advance_turn(player2)


func test_nehtali_hellfire():
	position_players(player1, 4, player2, 7)
	give_gauge(player1, 9)
	give_gauge(player2, 5)
	execute_strike(player1, player2, "nehtali_hellfire", "standard_normal_dive", false, false,
		[], [])
	validate_life(player1, 30, player2, 21)
	validate_positions(player1, 4, player2, 7)
	advance_turn(player2)


func test_nehtali_azazelstorment_mincardsgauge_opponent_fail():
	position_players(player1, 1, player2, 3)
	give_gauge(player1, 9)
	give_gauge(player2, 2)
	execute_strike(player1, player2, "nehtali_azazelstorment", "standard_normal_assault", false, false,
		[], [])
	validate_life(player1, 30, player2, 27)
	validate_positions(player1, 1, player2, 6)
	advance_turn(player2)


func test_nehtali_azazelstorment_mincardsgauge_opponent_success():
	position_players(player1, 1, player2, 3)
	give_gauge(player1, 9)
	give_gauge(player2, 3)
	execute_strike(player1, player2, "nehtali_azazelstorment", "standard_normal_assault", false, false,
		[], [])
	validate_life(player1, 30, player2, 24)
	validate_positions(player1, 1, player2, 6)
	advance_turn(player2)


func test_nehtali_hellssalvation_boost():
	position_players(player1, 1, player2, 3)
	assert_eq(player1.hand.size(), 5)
	assert_eq(player1.gauge.size(), 0)
	give_player_specific_card(player1, "nehtali_hellssalvation")
	assert_true(game_logic.do_boost(player1, player1.hand[-1].id, []))
	assert_eq(player1.hand.size(), 7)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_CardFromHandToGauge)
	var c1 = player1.hand[-2].id
	var c2 = player1.hand[-1].id
	assert_eq(game_logic.decision_info.effect['restricted_to_card_ids'][1], c1)
	assert_eq(game_logic.decision_info.effect['restricted_to_card_ids'][0], c2)
	assert_true(game_logic.do_relocate_card_from_hand(player1, [c1]))
	assert_eq(player1.hand.size(), 7)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player1.gauge[0].id, c1)

	advance_turn(player2)
