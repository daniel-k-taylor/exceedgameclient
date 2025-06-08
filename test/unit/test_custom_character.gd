extends ExceedGutTest

func who_am_i():
	return "test_custom"

##
## Tests start here
##

# Testing a character being loaded with a face-attack set.
func test_set_starting_face_attack():
	position_players(player1, 3, player2, 7)
	player1.discard_hand()
	player2.discard_hand()

	var strike_cards = execute_strike(player1, player2, -1, "standard_normal_grasp", false, false,
		[], [], false, "", "", true, false) # Player 1 strikes with face attack

	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 25)
