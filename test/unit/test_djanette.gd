extends ExceedGutTest

func who_am_i():
	return "djanette"

##
## Tests start here
##

func test_djanette_spellcircle_strike_circlecard():
	position_players(player1, 1, player2, 7)
	var spellcard = give_player_specific_card(player1, "djanette_affliction")
	assert_eq(player1.hand.size(), 6)
	assert_true(game_logic.do_character_action(player1, []))
	assert_true(game_logic.do_relocate_card_from_hand(player1, [spellcard]))
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(6)))
	assert_eq(player1.hand.size(), 7)
	assert_eq(player1.set_aside_cards.size(), 1)
	advance_turn(player2)
	# Forced strike.
	assert_eq(game_logic.game_state, Enums.GameState.GameState_WaitForStrike)
	# Strike with either a hand card or the spell circle card.
	assert_true(game_logic.do_strike(player1, -1, true, 0))
	give_player_specific_card(player2, "standard_normal_assault")
	assert_true(game_logic.do_strike(player2, player2.hand[-1].id, false, -1))

	# P1 hits first, does choice (boost hand or advantage)
	assert_true(game_logic.do_choice(player1, 1))
	# Transform choice
	assert_true(game_logic.do_choice(player1, 1))
	# Strike over.
	validate_positions(player1, 1, player2, 7)
	validate_life(player1, 30, player2, 27)
	assert_eq(player1.gauge.size(), 1)

	advance_turn(player1)


func test_djanette_spellcircle_p2_stirkes_circlecard():
	position_players(player1, 1, player2, 7)
	var spellcard = give_player_specific_card(player1, "djanette_affliction")
	assert_eq(player1.hand.size(), 6)
	assert_true(game_logic.do_character_action(player1, []))
	assert_true(game_logic.do_relocate_card_from_hand(player1, [spellcard]))
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(6)))
	assert_eq(player1.hand.size(), 7)
	assert_eq(player1.set_aside_cards.size(), 1)
	give_player_specific_card(player2, "standard_normal_assault")
	assert_true(game_logic.do_strike(player2, player2.hand[-1].id, false, -1))
	# Strike with either a hand card or the spell circle card.
	assert_true(game_logic.do_strike(player1, -1, true, 0))

	# P1 hits first, does choice (boost hand or advantage)
	assert_true(game_logic.do_choice(player1, 1))
	# Transform choice
	assert_true(game_logic.do_choice(player1, 1))
	# Strike over.
	validate_positions(player1, 1, player2, 7)
	validate_life(player1, 30, player2, 27)
	assert_eq(player1.gauge.size(), 1)

	advance_turn(player1)

func test_djanette_spellcircle_p2_strikes_normal():
	position_players(player1, 1, player2, 7)
	var spellcard = give_player_specific_card(player1, "djanette_affliction")
	assert_eq(player1.hand.size(), 6)
	assert_true(game_logic.do_character_action(player1, []))
	assert_true(game_logic.do_relocate_card_from_hand(player1, [spellcard]))
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(6)))
	assert_eq(player1.hand.size(), 7)
	assert_eq(player1.set_aside_cards.size(), 1)

	# P2 strikes
	give_player_specific_card(player2, "standard_normal_assault")
	assert_true(game_logic.do_strike(player2, player2.hand[-1].id, false, -1))
	# Strike with either a hand card or the spell circle card.
	give_player_specific_card(player1, "standard_normal_assault")
	assert_true(game_logic.do_strike(player1, player1.hand[-1].id, false, -1))

	# Strike over.
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 30, player2, 30)
	assert_eq(player1.gauge.size(), 0)
	assert_eq(player1.discards.size(), 2)
	assert_eq(player1.discards[0].id, spellcard)

	advance_turn(player1)

func test_djanette_spellcircle_strike_normal_instead():
	position_players(player1, 1, player2, 7)
	var spellcard = give_player_specific_card(player1, "djanette_affliction")
	assert_eq(player1.hand.size(), 6)
	assert_true(game_logic.do_character_action(player1, []))
	assert_true(game_logic.do_relocate_card_from_hand(player1, [spellcard]))
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(6)))
	assert_eq(player1.hand.size(), 7)
	assert_eq(player1.set_aside_cards.size(), 1)
	advance_turn(player2)
	# Forced strike.
	assert_eq(game_logic.game_state, Enums.GameState.GameState_WaitForStrike)
	# Strike with either a hand card or the spell circle card.
	give_player_specific_card(player1, "standard_normal_assault")
	assert_true(game_logic.do_strike(player1, player1.hand[-1].id, false, -1))
	give_player_specific_card(player2, "standard_normal_assault")
	assert_true(game_logic.do_strike(player2, player2.hand[-1].id, false, -1))

	# Strike over.
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 30, player2, 30)
	assert_eq(player1.gauge.size(), 0)
	assert_eq(player1.discards.size(), 2)
	assert_eq(player1.discards[0].id, spellcard)

	advance_turn(player2)


func test_djanette_blackdeath_transform_boost_pass():
	position_players(player1, 1, player2, 7)
	add_transform(player1, "djanette_blackdeath")
	give_player_specific_card(player1, "standard_normal_grasp")
	assert_true(game_logic.do_boost(player1, player1.hand[-1].id))
	assert_true(game_logic.do_force_for_effect(player1, [], false))
	advance_turn(player2)

func test_djanette_blackdeath_transform_boost_strike():
	position_players(player1, 3, player2, 7)
	add_transform(player1, "djanette_blackdeath")
	give_player_specific_card(player1, "standard_normal_grasp")
	assert_true(game_logic.do_boost(player1, player1.hand[-1].id))
	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id], true))
	execute_strike(player1, player2, "standard_normal_dive", "standard_normal_sweep", false, false,
		[], [])
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 23)
	advance_turn(player2)


func test_djanette_blackdeath_transform_diabolic_pass():
	player1.exceed()
	position_players(player1, 1, player2, 7)
	add_transform(player1, "djanette_blackdeath")
	assert_true(game_logic.do_character_action(player1, [], 0))
	assert_true(game_logic.do_relocate_card_from_hand(player1, [player1.hand[0].id]))
	assert_true(game_logic.do_force_for_effect(player1, [], false))
	advance_turn(player2)

func test_djanette_blackdeath_transform_diabolic_strike():
	player1.exceed()
	position_players(player1, 3, player2, 7)
	add_transform(player1, "djanette_blackdeath")
	assert_true(game_logic.do_character_action(player1, [], 0))
	assert_true(game_logic.do_relocate_card_from_hand(player1, [player1.hand[0].id]))
	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id], true))
	execute_strike(player1, player2, "standard_normal_dive", "standard_normal_sweep", false, false,
		[], [])
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 22)
	advance_turn(player2)


func test_djanette_diabolic_many_in_range():
	player1.exceed()
	give_player_specific_card(player1, "standard_normal_grasp")
	give_player_specific_card(player1, "standard_normal_grasp")
	give_player_specific_card(player1, "standard_normal_grasp")
	give_player_specific_card(player1, "standard_normal_grasp")
	give_player_specific_card(player1, "standard_normal_spike")
	player1.set_aside_cards = player1.hand.slice(5)
	player1.hand = player1.hand.slice(0, 6)

	position_players(player1, 3, player2, 7)
	execute_strike(player1, player2, "standard_normal_dive", "standard_normal_sweep", false, false,
		[], [])
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 30-5-(4*3))
	advance_turn(player2)
	assert_eq(player1.discards.size(), 5)


func test_djanette_charnelblast_transform_armor():
	position_players(player1, 4, player2, 7)
	add_transform(player1, "djanette_affliction")
	add_transform(player1, "djanette_blackdeath")
	add_transform(player1, "djanette_bloodthorns")
	add_transform(player1, "djanette_profanesanctuary")

	execute_strike(player1, player2, "djanette_charnelblast", "standard_normal_assault", false, false,
		[], [])
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 30, player2, 24)
	advance_turn(player2)


func test_djanette_profanesanctuary_transform():
	position_players(player1, 4, player2, 7)
	add_transform(player1, "djanette_profanesanctuary")
	player1.discard_hand()
	give_player_specific_card(player1, "djanette_blackdeath")
	assert_true(game_logic.do_bonus_turn_action(player1, 0))
	assert_true(game_logic.do_choose_to_discard(player1, [player1.hand[0].id]))
	validate_life(player1, 30, player2, 29)
	assert_eq(player1.hand.size(), 2)
	advance_turn(player2)


func test_djanette_rangeup_transforms_special_attack():
	position_players(player1, 3, player2, 7)
	add_transform(player1, "djanette_affliction")
	add_transform(player1, "djanette_carmineoffering")
	player1.discard_hand()
	execute_strike(player1, player2, "djanette_affliction", "standard_normal_assault", false, false,
		[1], [])
	# At range 4, 0-1 special will hit 0-4.
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 27)
	advance_turn(player1)


func test_djanette_rangeup_transforms_normal_attack_miss():
	position_players(player1, 3, player2, 7)
	add_transform(player1, "djanette_affliction")
	add_transform(player1, "djanette_carmineoffering")
	player1.discard_hand()
	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_assault", false, false,
		[], [])
	# At range 4, 1 normal is 1-3.
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 30, player2, 30)
	advance_turn(player2)

func test_djanette_rangeup_transforms_normal_attack_hit():
	position_players(player1, 4, player2, 7)
	add_transform(player1, "djanette_affliction")
	add_transform(player1, "djanette_carmineoffering")
	player1.discard_hand()
	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_assault", false, false,
		[0], [])
	# At range 3, 1 normal is 1-3.
	validate_positions(player1, 4, player2, 8)
	validate_life(player1, 30, player2, 27)
	advance_turn(player2)


func test_djanette_rangeup_transforms_diabolic():
	player1.exceed()
	# Range 4 for htis test with 0-2 all and 0-1 for specials (so 3 total)
	give_player_specific_card(player1, "djanette_affliction")
	give_player_specific_card(player1, "standard_normal_grasp")
	player1.set_aside_cards = player1.hand.slice(5)
	player1.hand = player1.hand.slice(0, 5)
	
	position_players(player1, 3, player2, 7)
	add_transform(player1, "djanette_affliction")
	add_transform(player1, "djanette_carmineoffering")
	player1.discard_hand()
	execute_strike(player1, player2, "djanette_affliction", "standard_normal_assault", false, false,
		[0, 1], [])
	# At range 4, 0-1 special will hit 0-4.
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 24)
	advance_turn(player1)


func test_djanette_rangeup_transforms_diabolic_veryclose():
	player1.exceed()
	# Range 4 for htis test with 0-2 all and 0-1 for specials (so 3 total)
	give_player_specific_card(player1, "djanette_affliction")
	give_player_specific_card(player1, "standard_normal_grasp")
	give_player_specific_card(player1, "djanette_blackdeath")
	player1.set_aside_cards = player1.hand.slice(5)
	player1.hand = player1.hand.slice(0, 5)
	
	position_players(player1, 6, player2, 7)
	add_transform(player1, "djanette_affliction")
	add_transform(player1, "djanette_carmineoffering")
	player1.discard_hand()
	execute_strike(player1, player2, "djanette_affliction", "standard_normal_assault", false, false,
		[0, 1], [])
	# At range 4, 0-1 special will hit 0-4.
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 21)
	advance_turn(player1)


func test_djanette_deathknell_boost():
	position_players(player1, 6, player2, 7)
	give_player_specific_card(player1, "djanette_deathknell")
	give_player_specific_card(player1, "djanette_deathknell")
	assert_true(game_logic.do_boost(player1, player1.hand[-1].id, [player1.hand[-2].id]))
	execute_strike(player2, player1, "standard_normal_grasp", "standard_normal_grasp", false, false,
		[], [1])
	validate_positions(player1, 6, player2, 9)
	validate_life(player1, 30, player2, 27)
	advance_turn(player1)


func test_djanette_deathknell_boost_diabolic():
	position_players(player1, 5, player2, 7)
	give_player_specific_card(player1, "djanette_deathknell")
	give_player_specific_card(player1, "djanette_deathknell")
	assert_true(game_logic.do_boost(player1, player1.hand[-1].id, [player1.hand[-2].id]))
	
	# P2 is going to have -1 min and max range, so range 2 diabolic black death still helps +damage
	player2.exceed()
	give_player_specific_card(player2, "djanette_blackdeath")
	player2.set_aside_cards = player2.hand.slice(6)
	player2.hand = player2.hand.slice(0, 6)
	
	execute_strike(player2, player1, "standard_normal_spike", "standard_normal_sweep", false, false,
		[], [])
	validate_positions(player1, 5, player2, 7)
	validate_life(player1, 22, player2, 30)
	advance_turn(player1)


func test_djanette_deathknell_boost_profaneability():
	position_players(player1, 6, player2, 7)
	player2.discard_hand()
	give_player_specific_card(player1, "djanette_deathknell")
	give_player_specific_card(player1, "djanette_deathknell")
	assert_true(game_logic.do_boost(player1, player1.hand[-1].id, [player1.hand[-2].id]))
	
	# P2 has profane transform to deal damage
	add_transform(player2, "djanette_profanesanctuary")
	give_player_specific_card(player2, "standard_normal_spike")
	# Spike works because -1 range.
	assert_true(game_logic.do_bonus_turn_action(player2, 0))
	assert_true(game_logic.do_choose_to_discard(player2, [player2.hand[-1].id]))
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 29, player2, 30)
	advance_turn(player1)


func test_djanette_deathknell_boost_profaneability_rangeup_both_players():
	position_players(player1, 3, player2, 7)
	player2.discard_hand()
	give_player_specific_card(player1, "arakune_ytwodash")
	assert_true(game_logic.do_boost(player1, player1.hand[-1].id))
	
	# P2 has profane transform to deal damage
	add_transform(player2, "djanette_profanesanctuary")
	give_player_specific_card(player2, "standard_normal_spike")
	# Spike works because +1 range.
	assert_true(game_logic.do_bonus_turn_action(player2, 0))
	assert_true(game_logic.do_choose_to_discard(player2, [player2.hand[-1].id]))
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 29, player2, 30)
	advance_turn(player1)
