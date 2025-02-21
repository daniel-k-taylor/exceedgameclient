extends ExceedGutTest

func who_am_i():
	return "iaquis"

##
## Tests start here
##

func test_iaquis_dragonsfire_boost_no_cards():
	position_players(player1, 5, player2, 7)
	player1.discard_hand()
	assert_eq(player1.hand.size(), 0)
	var testcard = give_player_specific_card(player1, "iaquis_dragonsfire")
	assert_true(game_logic.do_boost(player1, testcard, []))
	assert_eq(player1.hand.size(), 1)
	advance_turn(player2)


func test_iaquis_dragonsfire_boost():
	position_players(player1, 5, player2, 7)
	assert_eq(player1.hand.size(), 5)
	var testcard = give_player_specific_card(player1, "iaquis_dragonsfire")
	var p1initialhand = player1.hand.duplicate()
	var p2initialhand = player2.hand.duplicate()
	assert_true(game_logic.do_boost(player1, testcard, []))
	assert_true(game_logic.do_relocate_card_from_hand(player1, [p1initialhand[0].id]))
	assert_true(game_logic.do_choice(player2, 0))
	assert_true(game_logic.do_relocate_card_from_hand(player2, [p2initialhand[0].id]))
	assert_true(game_logic.do_choice(player1, 0))
	assert_true(game_logic.do_relocate_card_from_hand(player1, [p1initialhand[1].id]))
	assert_true(game_logic.do_choice(player2, 0))
	assert_true(game_logic.do_relocate_card_from_hand(player2, [p2initialhand[1].id]))
	assert_true(game_logic.do_choice(player1, 0))
	assert_true(game_logic.do_relocate_card_from_hand(player1, [p1initialhand[2].id]))
	assert_true(game_logic.do_choice(player2, 0))
	assert_true(game_logic.do_relocate_card_from_hand(player2, [p2initialhand[2].id]))
	assert_true(game_logic.do_choice(player1, 1))
	assert_eq(player1.hand.size(), 3)
	assert_eq(player2.hand.size(), 3)
	assert_eq(player1.gauge.size(), 3)
	assert_eq(player2.gauge.size(), 3)
	advance_turn(player2)


func test_iaquis_dragonsfire_boost_until_out():
	position_players(player1, 5, player2, 7)
	assert_eq(player1.hand.size(), 5)
	var testcard = give_player_specific_card(player1, "iaquis_dragonsfire")
	var p1initialhand = player1.hand.duplicate()
	var p2initialhand = player2.hand.duplicate()
	assert_true(game_logic.do_boost(player1, testcard, []))
	assert_true(game_logic.do_relocate_card_from_hand(player1, [p1initialhand[0].id]))
	assert_true(game_logic.do_choice(player2, 0))
	assert_true(game_logic.do_relocate_card_from_hand(player2, [p2initialhand[0].id]))
	assert_true(game_logic.do_choice(player1, 0))
	assert_true(game_logic.do_relocate_card_from_hand(player1, [p1initialhand[1].id]))
	assert_true(game_logic.do_choice(player2, 0))
	assert_true(game_logic.do_relocate_card_from_hand(player2, [p2initialhand[1].id]))
	assert_true(game_logic.do_choice(player1, 0))
	assert_true(game_logic.do_relocate_card_from_hand(player1, [p1initialhand[2].id]))
	assert_true(game_logic.do_choice(player2, 0))
	assert_true(game_logic.do_relocate_card_from_hand(player2, [p2initialhand[2].id]))
	assert_true(game_logic.do_choice(player1, 0))
	assert_true(game_logic.do_relocate_card_from_hand(player1, [p1initialhand[3].id]))
	assert_true(game_logic.do_choice(player2, 0))
	assert_true(game_logic.do_relocate_card_from_hand(player2, [p2initialhand[3].id]))
	assert_true(game_logic.do_choice(player1, 0))
	assert_true(game_logic.do_relocate_card_from_hand(player1, [p1initialhand[4].id]))
	assert_true(game_logic.do_choice(player2, 0))
	assert_true(game_logic.do_relocate_card_from_hand(player2, [p2initialhand[4].id]))
	# Back to p1 but hand is empty so effect stops and they draw for end of turn.
	assert_eq(player1.hand.size(), 1)
	assert_eq(player2.hand.size(), 1)
	assert_eq(player1.gauge.size(), 5)
	assert_eq(player2.gauge.size(), 5)
	advance_turn(player2)
	
