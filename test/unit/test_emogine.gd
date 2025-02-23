extends ExceedGutTest

func who_am_i():
	return "emogine"

##
## Tests start here
##

func test_emogine_bloodforblood_transform_and_attack():
	position_players(player1, 3, player2, 7)
	add_transform(player1, "emogine_bloodforblood")
	player1.life = 20
	set_player_topdeck(player1, "emogine_bloodforblood")
	set_player_topdeck(player2, "standard_normal_dive")
	execute_strike(player1, player2, -1, -1, false, false,
		[1, 1], [1]) # Both need to decide not to pay 1 life to flip next card
	# Both wild swing, p1 goes up to 21 life and gets +1 power
	# P2 hits for 5
	# P1 gets +5 power
	# P1 hit spend life choice 1, 2, pass - +1 power each
	# P1 hits back
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 14, player2, 21)
