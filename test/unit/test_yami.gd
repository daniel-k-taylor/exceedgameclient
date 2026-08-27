extends ExceedGutTest

func who_am_i():
	return "yami"

## Death Looms - (1F) +0~1 Range, +1 Power.
##		Now: Strike; you may spend 2 Force. If you do, the opponent must Wild Swing.

func test_yami_death_looms_force_wild_swing():
	position_players(player1, 3, player2, 7)
	var deathlooms_id = give_player_specific_card(player1, "yami_vengeance")
	var sweep_id = give_player_specific_card(player1, "standard_normal_sweep")
	
	# Assault in hand, Dive on deck
	var hand_assault_id = give_player_specific_card(player2, "standard_normal_assault")
	var deck_dive_id = give_player_specific_card(player2, "standard_normal_dive")
	player2.move_card_from_hand_to_deck(deck_dive_id)
	
	assert_true(game_logic.do_boost(player1, deathlooms_id, [player1.hand[0].id]))
	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id, player1.hand[1].id], true))
	
	assert_true(game_logic.do_strike(player1, sweep_id, false, -1)) # player 1 sets sweep
	# player 2 is forced to wild swing dive

	validate_life(player1, 25, player2, 23)
	validate_positions(player1, 3, player2, 4)
	assert_true(player2.is_card_in_gauge(deck_dive_id))
	
	advance_turn(player2)

func test_yami_death_looms_no_force_wild_swing():
	position_players(player1, 3, player2, 7)
	var deathlooms_id = give_player_specific_card(player1, "yami_vengeance")
	var sweep_id = give_player_specific_card(player1, "standard_normal_sweep")
	
	# Assault in hand, Dive on deck
	var hand_assault_id = give_player_specific_card(player2, "standard_normal_assault")
	var deck_dive_id = give_player_specific_card(player2, "standard_normal_dive")
	player2.move_card_from_hand_to_deck(deck_dive_id)
	
	assert_true(game_logic.do_boost(player1, deathlooms_id, [player1.hand[0].id]))
	assert_true(game_logic.do_force_for_effect(player1, [], false))
	
	assert_true(game_logic.do_strike(player1, sweep_id, false, -1)) # player 1 sets sweep
	assert_true(game_logic.do_strike(player2, hand_assault_id, false, -1)) # player 2 is allowed to set assault

	validate_life(player1, 30, player2, 23)
	validate_positions(player1, 3, player2, 5)
	assert_true(player2.is_card_in_deck(deck_dive_id))
	
	advance_turn(player2)
