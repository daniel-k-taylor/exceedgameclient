extends ExceedGutTest

func who_am_i():
	return "iaquis"

##
## Tests start here
##

func test_iaquis_dragonsfire_boost_no_cards():
	position_players(player1, 5, player2, 7)
	player1.discard_hand()
	assert_eq(player1.hand.size(), 0)
	var testcard = give_player_specific_card(player1, "iaquis_dragonsfire")
	assert_true(game_logic.do_boost(player1, testcard, []))
	assert_eq(player1.hand.size(), 1)
	advance_turn(player2)


func test_iaquis_dragonsfire_boost():
	position_players(player1, 5, player2, 7)
	assert_eq(player1.hand.size(), 5)
	var testcard = give_player_specific_card(player1, "iaquis_dragonsfire")
	var p1initialhand = player1.hand.duplicate()
	var p2initialhand = player2.hand.duplicate()
	assert_true(game_logic.do_boost(player1, testcard, []))
	assert_true(game_logic.do_relocate_card_from_hand(player1, [p1initialhand[0].id]))
	assert_true(game_logic.do_choice(player2, 0))
	assert_true(game_logic.do_relocate_card_from_hand(player2, [p2initialhand[0].id]))
	assert_true(game_logic.do_choice(player1, 0))
	assert_true(game_logic.do_relocate_card_from_hand(player1, [p1initialhand[1].id]))
	assert_true(game_logic.do_choice(player2, 0))
	assert_true(game_logic.do_relocate_card_from_hand(player2, [p2initialhand[1].id]))
	assert_true(game_logic.do_choice(player1, 0))
	assert_true(game_logic.do_relocate_card_from_hand(player1, [p1initialhand[2].id]))
	assert_true(game_logic.do_choice(player2, 0))
	assert_true(game_logic.do_relocate_card_from_hand(player2, [p2initialhand[2].id]))
	assert_true(game_logic.do_choice(player1, 1))
	assert_eq(player1.hand.size(), 3)
	assert_eq(player2.hand.size(), 3)
	assert_eq(player1.gauge.size(), 3)
	assert_eq(player2.gauge.size(), 3)
	advance_turn(player2)


func test_iaquis_dragonsfire_boost_until_out():
	position_players(player1, 5, player2, 7)
	assert_eq(player1.hand.size(), 5)
	var testcard = give_player_specific_card(player1, "iaquis_dragonsfire")
	var p1initialhand = player1.hand.duplicate()
	var p2initialhand = player2.hand.duplicate()
	assert_true(game_logic.do_boost(player1, testcard, []))
	assert_true(game_logic.do_relocate_card_from_hand(player1, [p1initialhand[0].id]))
	assert_true(game_logic.do_choice(player2, 0))
	assert_true(game_logic.do_relocate_card_from_hand(player2, [p2initialhand[0].id]))
	assert_true(game_logic.do_choice(player1, 0))
	assert_true(game_logic.do_relocate_card_from_hand(player1, [p1initialhand[1].id]))
	assert_true(game_logic.do_choice(player2, 0))
	assert_true(game_logic.do_relocate_card_from_hand(player2, [p2initialhand[1].id]))
	assert_true(game_logic.do_choice(player1, 0))
	assert_true(game_logic.do_relocate_card_from_hand(player1, [p1initialhand[2].id]))
	assert_true(game_logic.do_choice(player2, 0))
	assert_true(game_logic.do_relocate_card_from_hand(player2, [p2initialhand[2].id]))
	assert_true(game_logic.do_choice(player1, 0))
	assert_true(game_logic.do_relocate_card_from_hand(player1, [p1initialhand[3].id]))
	assert_true(game_logic.do_choice(player2, 0))
	assert_true(game_logic.do_relocate_card_from_hand(player2, [p2initialhand[3].id]))
	assert_true(game_logic.do_choice(player1, 0))
	assert_true(game_logic.do_relocate_card_from_hand(player1, [p1initialhand[4].id]))
	assert_true(game_logic.do_choice(player2, 0))
	assert_true(game_logic.do_relocate_card_from_hand(player2, [p2initialhand[4].id]))
	# Back to p1 but hand is empty so effect stops and they draw for end of turn.
	assert_eq(player1.hand.size(), 1)
	assert_eq(player2.hand.size(), 1)
	assert_eq(player1.gauge.size(), 5)
	assert_eq(player2.gauge.size(), 5)
	advance_turn(player2)



func test_iaquis_dragonsfire_hit_no_cards():
	position_players(player1, 5, player2, 7)
	player1.discard_hand()
	assert_eq(player1.hand.size(), 0)
	execute_strike(player1, player2, "iaquis_dragonsfire", "standard_normal_grasp", false, false,
		[0], []) # Set face up
	validate_life(player1, 30, player2, 25)
	assert_eq(player1.hand.size(), 0)
	assert_eq(player1.gauge.size(), 1)
	advance_turn(player2)

func test_iaquis_dragonsfire_hit_return_attack():
	position_players(player1, 5, player2, 7)
	assert_eq(player1.hand.size(), 5)
	execute_strike(player1, player2, "iaquis_dragonsfire", "standard_normal_grasp", false, false,
		[0, 0], []) # Set face up, do random card to gauge
	validate_life(player1, 30, player2, 30)
	assert_eq(player1.hand.size(), 5)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player1.hand[-1].definition["id"], "iaquis_dragonsfire")
	advance_turn(player2)


func test_iaquis_dragonsfire_hit_say_no_to_return_attack():
	position_players(player1, 5, player2, 7)
	assert_eq(player1.hand.size(), 5)
	execute_strike(player1, player2, "iaquis_dragonsfire", "standard_normal_grasp", false, false,
		[0, 1], []) # Set face up, pass random card to gauge
	validate_life(player1, 30, player2, 25)
	assert_eq(player1.hand.size(), 5)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player1.gauge[0].definition["id"], "iaquis_dragonsfire")
	advance_turn(player2)


func test_iaquis_dragonsflight_transform():
	position_players(player1, 5, player2, 7)
	assert_eq(player1.hand.size(), 5)
	add_transform(player1, "iaquis_dragonsflight")
	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_assault", false, false,
		[0, 0], []) # Set face up, add to gauge
	validate_life(player1, 26, player2, 30)
	assert_eq(player1.hand.size(), 5)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player1.gauge[0].definition["id"], "standard_normal_grasp")
	advance_turn(player2)


func test_iaquis_dragonsflight_transform_dontadd():
	position_players(player1, 5, player2, 7)
	assert_eq(player1.hand.size(), 5)
	add_transform(player1, "iaquis_dragonsflight")
	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_assault", false, false,
		[0, 1], []) # Set face up, dont add to gauge
	validate_life(player1, 26, player2, 30)
	assert_eq(player1.hand.size(), 5)
	assert_eq(player1.gauge.size(), 0)
	assert_eq(player1.discards[0].definition["id"], "standard_normal_grasp")
	advance_turn(player2)


func test_iaquis_dragonsspine_transform():
	position_players(player1, 5, player2, 7)
	assert_eq(player1.hand.size(), 5)
	add_transform(player1, "iaquis_dragonsspine")
	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_assault", false, false,
		[0, 0], []) # Set face up, draw
	validate_life(player1, 26, player2, 30)
	assert_eq(player1.hand.size(), 6)
	assert_eq(player1.gauge.size(), 0)
	assert_eq(player1.discards[0].definition["id"], "standard_normal_grasp")
	advance_turn(player2)


func test_iaquis_dragonsspine_transform_dontdraw():
	position_players(player1, 5, player2, 7)
	assert_eq(player1.hand.size(), 5)
	add_transform(player1, "iaquis_dragonsspine")
	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_assault", false, false,
		[0, 1], []) # Set face up, no draw
	validate_life(player1, 26, player2, 30)
	assert_eq(player1.hand.size(), 5)
	assert_eq(player1.gauge.size(), 0)
	assert_eq(player1.discards[0].definition["id"], "standard_normal_grasp")
	advance_turn(player2)



func test_iaquis_dragonstail_transform():
	position_players(player1, 5, player2, 7)
	assert_eq(player1.hand.size(), 5)
	add_transform(player1, "iaquis_dragonstail")
	advance_turn(player1)
	var boost = give_player_specific_card(player2, "standard_normal_sweep")
	assert_true(game_logic.do_boost(player2, boost, []))
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault", false, false,
		[0], []) # Set face up
	validate_life(player1, 26, player2, 22)
	assert_eq(player1.gauge.size(), 1)
	advance_turn(player1)


func test_iaquis_dragonstongue_boost_not_r1():
	position_players(player1, 5, player2, 7)
	assert_eq(player1.hand.size(), 5)
	var boost = give_player_specific_card(player1, "iaquis_dragonstongue")
	assert_true(game_logic.do_boost(player1, boost, []))
	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id], true))
	advance_turn(player1)

func test_iaquis_dragonstongue_boost_r1():
	position_players(player1, 6, player2, 7)
	assert_eq(player1.hand.size(), 5)
	var boost = give_player_specific_card(player1, "iaquis_dragonstongue")
	assert_true(game_logic.do_boost(player1, boost, []))
	validate_positions(player1, 6, player2, 9)
	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id], true))
	advance_turn(player1)


func test_iaquis_dragonstongue_boost_r1_noextra():
	position_players(player1, 6, player2, 7)
	assert_eq(player1.hand.size(), 5)
	var boost = give_player_specific_card(player1, "iaquis_dragonstongue")
	assert_true(game_logic.do_boost(player1, boost, []))
	validate_positions(player1, 6, player2, 9)
	assert_true(game_logic.do_force_for_effect(player1, [], false))
	advance_turn(player2)


func test_iaquis_dragonsdescent_boost():
	position_players(player1, 5, player2, 7)
	assert_eq(player1.hand.size(), 5)
	var boost = give_player_specific_card(player1, "iaquis_dragonsdescent")
	assert_true(game_logic.do_boost(player1, boost, []))
	assert_eq(player1.hand.size(), 10)
	advance_turn(player2)
	assert_true(game_logic.do_prepare(player1))
	assert_eq(player1.hand.size(), 11)
	advance_turn(player2)
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault", false, false,
		[0], []) # Set face up
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 24)
	assert_eq(player1.continuous_boosts.size(), 0)
	assert_eq(player1.discards.size(), 1)
	assert_true(game_logic.do_prepare(player1))
	assert_eq(player1.hand.size(), 13)
	var discard_ids = []
	for i in range(6):
		discard_ids.append(player1.hand[i].id)
	assert_true(game_logic.do_discard_to_max(player1, discard_ids))
	assert_eq(player1.hand.size(), 7)
	advance_turn(player2)


func test_iaquis_dragonsdescent_boost_twice_works():
	position_players(player1, 5, player2, 7)
	assert_eq(player1.hand.size(), 5)
	var boost = give_player_specific_card(player1, "iaquis_dragonsdescent")
	assert_true(game_logic.do_boost(player1, boost, []))
	assert_eq(player1.hand.size(), 10)
	advance_turn(player2)
	var boost2 = give_player_specific_card(player1, "iaquis_dragonsdescent")
	assert_true(game_logic.do_boost(player1, boost2, []))
	assert_eq(player1.hand.size(), 15)
	advance_turn(player2)
	assert_true(game_logic.do_prepare(player1))
	assert_eq(player1.hand.size(), 16)
	advance_turn(player2)
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault", false, false,
		[0], []) # Set face up
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 24)
	assert_eq(player1.continuous_boosts.size(), 0)
	assert_eq(player1.discards.size(), 2)
	assert_true(game_logic.do_prepare(player1))
	assert_eq(player1.hand.size(), 18)
	var discard_ids = []
	for i in range(11):
		discard_ids.append(player1.hand[i].id)
	assert_true(game_logic.do_discard_to_max(player1, discard_ids))
	assert_eq(player1.hand.size(), 7)
	advance_turn(player2)


func test_iaquis_dragonsdescent_boost_twice_tech_still_works():
	position_players(player1, 5, player2, 7)
	assert_eq(player1.hand.size(), 5)
	var boost = give_player_specific_card(player1, "iaquis_dragonsdescent")
	assert_true(game_logic.do_boost(player1, boost, []))
	assert_eq(player1.hand.size(), 10)
	
	var tech = give_player_specific_card(player2, "standard_normal_dive")
	assert_true(game_logic.do_boost(player2, tech, []))
	assert_true(game_logic.do_boost_name_card_choice_effect(player2, player1.continuous_boosts[0].id))
	# P1 turn again
	var boost2 = give_player_specific_card(player1, "iaquis_dragonsdescent")
	assert_true(game_logic.do_boost(player1, boost2, []))
	assert_eq(player1.hand.size(), 15)
	advance_turn(player2)
	assert_true(game_logic.do_prepare(player1))
	assert_eq(player1.hand.size(), 16)
	advance_turn(player2)
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault", false, false,
		[0], []) # Set face up
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 24)
	assert_eq(player1.continuous_boosts.size(), 0)
	assert_eq(player1.discards.size(), 2)
	assert_true(game_logic.do_prepare(player1))
	assert_eq(player1.hand.size(), 18)
	var discard_ids = []
	for i in range(11):
		discard_ids.append(player1.hand[i].id)
	assert_true(game_logic.do_discard_to_max(player1, discard_ids))
	assert_eq(player1.hand.size(), 7)
	advance_turn(player2)


func test_iaquis_dragonsdescent_once_tech_works_as_expected():
	position_players(player1, 5, player2, 7)
	assert_eq(player1.hand.size(), 5)
	var boost = give_player_specific_card(player1, "iaquis_dragonsdescent")
	assert_true(game_logic.do_boost(player1, boost, []))
	assert_eq(player1.hand.size(), 10)
	
	var tech = give_player_specific_card(player2, "standard_normal_dive")
	assert_true(game_logic.do_boost(player2, tech, []))
	assert_true(game_logic.do_boost_name_card_choice_effect(player2, player1.continuous_boosts[0].id))
	# P1 turn again
	assert_true(game_logic.do_prepare(player1))
	assert_eq(player1.hand.size(), 12)
	var discard_ids = []
	for i in range(5):
		discard_ids.append(player1.hand[i].id)
	assert_true(game_logic.do_discard_to_max(player1, discard_ids))
	assert_eq(player1.hand.size(), 7)
	advance_turn(player2)

func test_iaquis_dragonsdescent_copy_in_gauge():
	position_players(player1, 5, player2, 7)
	assert_eq(player1.hand.size(), 5)
	var p1gauge = give_gauge(player1, 3)
	give_player_specific_card(player1, "iaquis_dragonsdescent")
	player1.gauge.append(player1.hand[-1])
	player1.hand.remove_at(player1.hand.size() - 1)
	execute_strike(player1, player2, "iaquis_dragonsdescent", "standard_normal_dive", false, false,
		[0, p1gauge], []) # faceup
	validate_life(player1, 30, player2, 17)
	advance_turn(player2)


func test_iaquis_exceed_discard_descent_boosted_card():
	position_players(player1, 5, player2, 7)
	player1.exceed()
	assert_eq(player1.hand.size(), 5)
	var descent = give_player_specific_card(player1, "iaquis_dragonsdescent")
	var sweep = give_player_specific_card(player1, "standard_normal_sweep")
	assert_true(game_logic.do_boost(player1, sweep, []))
	advance_turn(player2)
	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_dive", false, false,
		[[descent], 0], []) # exceed ua, resolve simul hit effects
	validate_life(player1, 30, player2, 20)
	advance_turn(player2)



func test_iaquis_exceed_discard_descent_transformed_card():
	position_players(player1, 5, player2, 7)
	player1.exceed()
	add_transform(player1, "iaquis_dragonsflight")
	assert_eq(player1.hand.size(), 5)
	var descent = give_player_specific_card(player1, "iaquis_dragonsdescent")
	execute_strike(player1, player2, "iaquis_dragonsflight", "standard_normal_dive", false, false,
		[[descent], 0], []) # exceed ua, add to gauge transform
	validate_life(player1, 30, player2, 23)
	advance_turn(player2)
