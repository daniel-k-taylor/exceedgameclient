extends ExceedGutTest

func who_am_i():
	return "doomies"
	
## Legion - [2G] 1-3/1/1/1/6; Hit: +1 Power per card in your hand.
# Primarily tested because this hit effect existed but previously expected a maximum value.

func test_doomies_legion_huge_hand():
	position_players(player1, 2, player2, 6)
	var gauge_cards = give_gauge(player1, 2)
	player1.draw(10)
	var hand_size = len(player1.hand)
	
	execute_strike(player1, player2, "doomies_legion", "standard_normal_dive",
		false, false, [[], gauge_cards]) # decline infusion and pay gauge

	validate_life(player1, 27, player2, 29 - hand_size)
	validate_positions(player1, 2, player2, 3)
	
	advance_turn(player2)

## Boom! - [3G] 1/3/3/0/3; Before: Close 5. For each space you couldn't move, +1 Power.
##		After: Push 1 per damage dealt.

func test_doomies_boom_small_push():
	position_players(player1, 1, player2, 5)
	var gauge_cards = give_gauge(player1, 3)
	
	execute_strike(player1, player2, "doomies_boom", "standard_normal_block",
		false, false, [[], gauge_cards], [[]]) # decline infusion and pay gauge, don't spend for block
	
	# P1 closes 3 spaces from 1 to 4, so gains 2 power -> 5 total, so p2 takes 3 and is pushed from 5 to 8

	validate_life(player1, 30, player2, 27)
	validate_positions(player1, 4, player2, 8)
	
	advance_turn(player2)

func test_doomies_boom_huge_push():
	position_players(player1, 1, player2, 2)
	var gauge_cards = give_gauge(player1, 3)
	
	execute_strike(player1, player2, "doomies_boom", "standard_normal_sweep",
		false, false, [[], gauge_cards]) # decline infusion and pay gauge
	
	# P1 doesn't move, so gains 5 power -> 8 total, so p2 takes 3 and is pushed from 2 to 9

	validate_life(player1, 30, player2, 22)
	validate_positions(player1, 1, player2, 9)
	
	advance_turn(player2)
