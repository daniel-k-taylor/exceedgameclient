extends ExceedGutTest

func who_am_i():
	return "zacoal"

##
## Tests start here
##

## Redeemed - (1F) Add a card from your sealed area to your Gauge. Close 2.

func test_zacoal_redeemed_seal():
	position_players(player1, 3, player2, 7)
	var sealed_card = player1.hand[0].id
	player1.seal_from_location(sealed_card, 'hand')
	
	var boost_card = give_player_specific_card(player1, "zacoal_boulder")
	assert_true(game_logic.do_boost(player1, boost_card, [player1.hand[0].id]))
	assert_true(game_logic.do_choose_from_discard(player1, [sealed_card]))
	
	validate_positions(player1, 5, player2, 7)
	assert_true(player1.is_card_in_gauge(sealed_card))
	
	advance_turn(player2)

# Ensure it doesn't lock up if nothing is sealed

func test_zacoal_redeemed_no_seal():
	position_players(player1, 3, player2, 7)
	
	var boost_card = give_player_specific_card(player1, "zacoal_boulder")
	assert_true(game_logic.do_boost(player1, boost_card, [player1.hand[0].id]))
	
	validate_positions(player1, 5, player2, 7)
	
	advance_turn(player2)
