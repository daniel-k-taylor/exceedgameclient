extends ExceedGutTest

func who_am_i():
	return "astryda"

##
## Tests start here
##

## Exceed mode - When you Exceed, name a card and Strike. That card is invalid for both players. Hit: The opponent discards a card. Cleanup: Revert.

func test_astryda_exceed():
	position_players(player1, 3, player2, 5)
	
	var p1_gauge = give_gauge(player1, 2)
	
	# stack decks so wild swings can be tested
	var p1_deckassault = give_player_specific_card(player1, "standard_normal_assault")
	player1.move_card_from_hand_to_deck(p1_deckassault)
	var p2_deckdive = give_player_specific_card(player2, "standard_normal_dive")
	player2.move_card_from_hand_to_deck(p2_deckdive)
	
	var cross = give_player_specific_card(player1, "standard_normal_cross")
	var p1_starting_hand_size = player1.hand.size()
	var p2_starting_hand_size = player2.hand.size()
	
	
	# Exceed and name cross
	assert_true(game_logic.do_exceed(player1, p1_gauge))
	assert_true(game_logic.do_boost_name_card_choice_effect(player1, cross))
	
	# Both strike with cross; should end up with the assault into dive
	var strike_cards = execute_strike(player1, player2, "standard_normal_cross", "standard_normal_cross",
		false, false, [0], [[player2.hand[0].id]]) 
		
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 30, player2, 26)
	
	assert_true(player1.is_card_in_discards(strike_cards[0]))
	assert_true(player2.is_card_in_discards(strike_cards[1]))
	assert_true(player1.is_card_in_gauge(p1_deckassault))
	assert_true(player2.is_card_in_discards(p2_deckdive))
	assert_eq(player2.hand.size(), p2_starting_hand_size - 1)
	assert_false(player1.exceeded)

	advance_turn(player1)


## Drown - 1/5/3; Infused, Before: Close 2; Hit: The opponent discards all but 1 card from hand, then draws a card.

# normal case

func test_astryda_drown_discard():
	position_players(player1, 4, player2, 5)
	
	player2.draw(5)
	var keep_card = player2.hand[3].id
	var other_cards = []
	for card in player2.hand:
		if card.id != keep_card:
			other_cards.append(card.id)
	
	var strike_cards = execute_strike(player1, player2, "astryda_drown", "standard_normal_spike",
		false, false, [], [other_cards])
	
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 30, player2, 25)
	
	assert_true(player2.is_card_in_hand(keep_card))
	assert_eq(player2.hand.size(), 2)

	advance_turn(player2)

# empty hand case

func test_astryda_drown_empty_hand():
	position_players(player1, 4, player2, 5)
	
	player2.discard_hand()
	
	var strike_cards = execute_strike(player1, player2, "astryda_drown", "standard_normal_spike",
		false, false, [], [])
	
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 30, player2, 25)
	
	assert_eq(player2.hand.size(), 1) # TODO: this actually is bugged, since control never swaps over; maybe add some handling if discard amount is 0

	advance_turn(player2)

## Lust For Power (boost on Bewitching Song) - +2 Power, +2 Guard.
##     Infused, Hit: The opponent discards a card from their Gauge.
