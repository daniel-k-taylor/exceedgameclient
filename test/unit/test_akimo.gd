extends ExceedGutTest

func who_am_i():
	return "akimo"

##
## Tests start here
##

## Akimo is a very straightforward guy

## Duel for the Dome - +3 Armor. You are Infused. Now: If you are in the center 3 spaces, you may strike

func test_akimo_duelforthedome_outside():
	position_players(player1, 3, player2, 5)
	
	# Player 1 in starting position; does not get the option to strike
	
	var dome_card = give_player_specific_card(player1, "akimo_scourgeofpuido")
	assert_true(game_logic.do_boost(player1, dome_card, [player1.hand[0].id]))
	
	# passes turn; player 2 can strike, player 1 should automatically be infused
	
	# Strike; infusion should let player 1 outspeed
	var strike_cards = execute_strike(player2, player1, "standard_normal_assault", "akimo_bloodthirst",
		false, false, [2], []) #player 2 must decline infusion
		
	validate_positions(player1, 3, player2, 1)
	validate_life(player1, 30, player2, 27)

	advance_turn(player1)

func test_akimo_duelforthedome_center():
	position_players(player1, 5, player2, 7)
	
	# Player 1 in center space
	
	var dome_card = give_player_specific_card(player1, "akimo_scourgeofpuido")
	assert_true(game_logic.do_boost(player1, dome_card, [player1.hand[0].id]))
	
	assert_true(game_logic.do_choice(player1, 0)) # accept choice to strike
	
	# Strike; infusion should let player 1 outspeed
	var strike_cards = execute_strike(player1, player2, "akimo_scorchingrush", "standard_normal_cross",
		false, false, [], [2]) #player 2 must decline infusion
		
	validate_positions(player1, 7, player2, 9)
	validate_life(player1, 30, player2, 25) # +1 power from ability

	advance_turn(player1) # player 1 gains advantage from infusion

func test_akimo_duelforthedome_almostcenter():
	position_players(player1, 6, player2, 7)
	
	# Player 1 one off from center space; should be almost identical to the above case
	
	var dome_card = give_player_specific_card(player1, "akimo_scourgeofpuido")
	assert_true(game_logic.do_boost(player1, dome_card, [player1.hand[0].id]))
	
	assert_true(game_logic.do_choice(player1, 0)) # accept choice to strike
	
	# Strike; infusion should let player 1 outspeed
	var strike_cards = execute_strike(player1, player2, "akimo_scorchingrush", "standard_normal_cross",
		false, false, [], [2]) #player 2 must decline infusion
		
	validate_positions(player1, 8, player2, 9)
	validate_life(player1, 30, player2, 25) # +1 power from ability

	advance_turn(player1) # player 1 gains advantage from infusion
