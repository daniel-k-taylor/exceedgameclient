extends ExceedGutTest

func who_am_i():
	return "nantaca"
	
## Nantaca - Infused Action: Draw 2. Put up to 2 cards from your hand into play face-down as Continuous Boosts
##		that read "Hit: +1 Power. Add this to your Gauge."

func test_nantaca_ability():
	position_players(player1, 3, player2, 6)
	var gauge_card = give_gauge(player1, 1)
	var starting_hand_size = len(player1.hand)
	
	assert_true(game_logic.do_character_action(player1, gauge_card, 1)) # infuse
	assert_true(game_logic.do_character_action(player1, [], 0)) # begin character action
	assert_eq(len(player1.hand), starting_hand_size + 2)
	
	var boost1 = player1.hand[0].id
	var boost2 = player1.hand[1].id
	assert_true(game_logic.do_choose_to_discard(player1, [boost1, boost2]))
	assert_true(player1.is_card_in_continuous_boosts(boost1))
	assert_true(player1.is_card_in_continuous_boosts(boost2))
	advance_turn(player2)
	
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_dive",
		false, false, [0, 0]) # arbitrary resolution order

	validate_life(player1, 30, player2, 24)
	validate_positions(player1, 5, player2, 6)
	assert_true(player1.is_card_in_gauge(boost1))
	assert_true(player1.is_card_in_gauge(boost2))
	
	advance_turn(player1)

## 2G Exceed - Infused Action: Draw 2. Put up to 3 cards from your Gauge or hand into play face-down as Continuous Boosts
##		that read "Hit: +1 Power. Add this to your Gauge."

func test_nantaca_exceed_ability():
	position_players(player1, 3, player2, 6)
	player1.discard_hand()
	var exceed_gauge = give_gauge(player1, 2)
	assert_true(game_logic.do_exceed(player1, exceed_gauge))
	advance_turn(player2)
	
	var infuse_gauge = give_gauge(player1, 1)
	var boost_gauge = give_gauge(player1, 2)
	var starting_hand_size = len(player1.hand)
	
	assert_true(game_logic.do_character_action(player1, infuse_gauge, 1)) # infuse
	assert_true(game_logic.do_character_action(player1, [], 0)) # begin character action
	assert_eq(len(player1.hand), starting_hand_size + 2)
	
	var boost1 = boost_gauge[0]
	var boost2 = boost_gauge[1]
	var boost3 = player1.hand[0].id
	assert_true(game_logic.do_choose_to_discard(player1, [boost1, boost2, boost3]))
	assert_true(player1.is_card_in_continuous_boosts(boost1))
	assert_true(player1.is_card_in_continuous_boosts(boost2))
	assert_true(player1.is_card_in_continuous_boosts(boost3))
	advance_turn(player2)
	
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_dive",
		false, false, [0, 0, 0]) # arbitrary resolution order

	validate_life(player1, 30, player2, 23)
	validate_positions(player1, 5, player2, 6)
	assert_true(player1.is_card_in_gauge(boost1))
	assert_true(player1.is_card_in_gauge(boost2))
	assert_true(player1.is_card_in_gauge(boost3))
	
	advance_turn(player1)

## Xotlanian Pillar (Sinkhole boost) - [1F] Your Range includes this space.
##		Now: Place this in any space. Draw 1.
##		After: Add this to your Gauge.

func test_nantaca_xotlanian_pillar_range_included():
	position_players(player1, 3, player2, 6)
	
	var boost_card = give_player_specific_card(player1, "nantaca_sinkhole")
	assert_true(game_logic.do_boost(player1, boost_card, [player1.hand[0].id]))
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(6)))
	advance_turn(player2)
	
	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_sweep",
		false, false, [1]) # push 2

	validate_life(player1, 30, player2, 27)
	validate_positions(player1, 3, player2, 8)
	assert_true(player1.is_card_in_gauge(boost_card))
	
	advance_turn(player2)

func test_nantaca_xotlanian_pillar_range_not_included():
	position_players(player1, 3, player2, 6)
	
	var boost_card = give_player_specific_card(player1, "nantaca_sinkhole")
	assert_true(game_logic.do_boost(player1, boost_card, [player1.hand[0].id]))
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(7)))
	advance_turn(player2)
	
	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_sweep",
		false, false, [])

	validate_life(player1, 24, player2, 30)
	validate_positions(player1, 3, player2, 6)
	assert_true(player1.is_card_in_gauge(boost_card))
	
	advance_turn(player2)

## Sacrificial Rite (Preparatory Rite boost) - [1F] +3 Power. You are Infused.
##		Now: Add one of your Boosts from play to your Gauge.

func test_nantaca_sacrificial_rite_no_other_boosts():
	position_players(player1, 3, player2, 6)
	
	var boost_card = give_player_specific_card(player1, "nantaca_preparatoryrite")
	assert_true(game_logic.do_boost(player1, boost_card, [player1.hand[0].id]))
	assert_true(player1.is_card_in_gauge(boost_card))
	assert_false(player1.is_infused())
	
	advance_turn(player2)

func test_nantaca_sacrificial_rite_gauge_other_boosts_gauge_self():
	position_players(player1, 3, player2, 6)
	player1.discard_hand()
	var fierce_card = give_player_specific_card(player1, "standard_normal_grasp")
	var defend_card = give_player_specific_card(player1, "standard_normal_spike")
	assert_true(game_logic.do_boost(player1, fierce_card, []))
	advance_turn(player2)
	assert_true(game_logic.do_boost(player1, defend_card, []))
	advance_turn(player2)
	
	var boost_card = give_player_specific_card(player1, "nantaca_preparatoryrite")
	assert_true(game_logic.do_boost(player1, boost_card, [player1.hand[0].id]))
	assert_true(game_logic.do_choice(player1, 0)) # choose to add rite to gauge anyway
	assert_true(player1.is_card_in_gauge(boost_card))
	assert_true(player1.is_card_in_continuous_boosts(fierce_card))
	assert_true(player1.is_card_in_continuous_boosts(defend_card))
	assert_false(player1.is_infused())
	
	advance_turn(player2)

func test_nantaca_sacrificial_rite_gauge_other_boosts():
	position_players(player1, 3, player2, 6)
	player1.discard_hand()
	var fierce_card = give_player_specific_card(player1, "standard_normal_grasp")
	var defend_card = give_player_specific_card(player1, "standard_normal_spike")
	assert_true(game_logic.do_boost(player1, fierce_card, []))
	advance_turn(player2)
	assert_true(game_logic.do_boost(player1, defend_card, []))
	advance_turn(player2)
	
	var boost_card = give_player_specific_card(player1, "nantaca_preparatoryrite")
	assert_true(game_logic.do_boost(player1, boost_card, [player1.hand[0].id]))
	assert_true(game_logic.do_choice(player1, 1)) # choose to select a boost in play to gauge
	assert_true(game_logic.do_boost_name_card_choice_effect(player1, defend_card))
	assert_true(player1.is_card_in_gauge(defend_card))
	assert_true(player1.is_card_in_continuous_boosts(fierce_card))
	assert_true(player1.is_card_in_continuous_boosts(boost_card))
	assert_true(player1.is_infused())
	
	advance_turn(player2)
