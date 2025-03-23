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
