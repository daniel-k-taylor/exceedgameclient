extends ExceedGutTest

func who_am_i():
	return "kohai"

##
## Tests start here
##

## Kohai - When you boost while Infused, Pull up to 2 (before boost effects).

func test_kohai_boost_and_pull():
	position_players(player1, 3, player2, 7)
	var gauge_card = give_gauge(player1, 1)
	
	var boost_card = give_player_specific_card(player1, "standard_normal_grasp")
	assert_true(game_logic.do_character_action(player1, gauge_card)) # infuse
	assert_true(game_logic.do_boost(player1, boost_card, []))
	assert_true(game_logic.do_choice(player1, 1)) # pull 2
	
	validate_positions(player1, 3, player2, 5)
	assert_true(player1.is_card_in_continuous_boosts(boost_card))
	
	advance_turn(player2)
	
func test_kohai_terrifying_pull():
	position_players(player1, 3, player2, 5)
	var gauge_card = give_gauge(player1, 1)
	var p2_hand_size = len(player2.hand)
	
	var boost_card = give_player_specific_card(player1, "kohai_harpoon")
	assert_true(game_logic.do_character_action(player1, gauge_card)) # infuse
	assert_true(game_logic.do_boost(player1, boost_card, [player1.hand[0].id]))
	assert_true(game_logic.do_choice(player1, 0)) # pull 1
	
	validate_positions(player1, 3, player2, 4)
	assert_eq(len(player2.hand), p2_hand_size - 2)
	
	execute_strike(player1, player2, "standard_normal_focus", "standard_normal_focus")
	advance_turn(player2)
	
func test_kohai_boost_pull_negate():
	position_players(player1, 3, player2, 7)
	var gauge_card = give_gauge(player1, 1)

	give_player_specific_card(player2, "seijun_yokaibanishing")
	player2.add_to_transforms(player2.hand[-1])
	player2.discard_hand()

	var p1_cross_id = give_player_specific_card(player1, "standard_normal_cross")
	var p2_cross_id = give_player_specific_card(player2, "standard_normal_cross")
	assert_true(game_logic.do_character_action(player1, gauge_card)) # infuse
	assert_true(game_logic.do_boost(player1, p1_cross_id, []))
	assert_true(game_logic.do_choice(player1, 1)) # pull happens first; pull 2
	# p2 has a copy of cross
	assert_true(game_logic.do_choice(player2, 0)) # discard, preventing p2 from using effect

	validate_positions(player1, 3, player2, 5)
	assert_true(player2.is_card_in_discards(p2_cross_id))
	advance_turn(player2)

## Hunting Grounds - (1F) Now: Draw 2. If the opponent is in the center 3 spaces, Strike.
##			After: Add this to your Gauge.

func test_kohai_hunting_grounds_outside():
	position_players(player1, 5, player2, 7)
	var hand_size = len(player1.hand)
	
	# Player 2 in starting position; does not give the option to strike
	
	var boost_card = give_player_specific_card(player1, "kohai_earthquakestomp")
	assert_true(game_logic.do_boost(player1, boost_card, [player1.hand[0].id]))
	
	# passes turn; player 1 draws 2 + 1 for end of turn, after spending one cards
	assert_eq(len(player1.hand), hand_size + 2)
	validate_positions(player1, 5, player2, 7)
	validate_life(player1, 30, player2, 30)

	advance_turn(player2)

func test_kohai_hunting_grounds_inside():
	position_players(player1, 3, player2, 5)
	var hand_size = len(player1.hand)
	
	var boost_card = give_player_specific_card(player1, "kohai_earthquakestomp")
	assert_true(game_logic.do_boost(player1, boost_card, [player1.hand[0].id]))
	
	# strike caused
	var strike_cards = execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_grasp",
		false, false, []) # Pull 2
	
	assert_eq(len(player1.hand), hand_size + 1) # didn't ddraw for end of turn this time
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 30, player2, 30)
	assert_true(player1.is_card_in_gauge(boost_card))

	advance_turn(player2)

func test_kohai_hunting_grounds_pulled_in():
	position_players(player1, 6, player2, 7)
	var hand_size = len(player1.hand)
	var gauge_card = give_gauge(player1, 1)
	
	var boost_card = give_player_specific_card(player1, "kohai_earthquakestomp")
	assert_true(game_logic.do_character_action(player1, gauge_card)) # infuse
	assert_true(game_logic.do_boost(player1, boost_card, [player1.hand[0].id]))
	assert_true(game_logic.do_choice(player1, 1)) # pull 2; brings opponent to center
	
	# strike caused
	var strike_cards = execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault",
		false, false, []) # Pull 2
	
	assert_eq(len(player1.hand), hand_size + 1) # didn't ddraw for end of turn this time
	validate_positions(player1, 5, player2, 4)
	validate_life(player1, 30, player2, 26)
	assert_true(player1.is_card_in_gauge(boost_card))

	advance_turn(player1)
