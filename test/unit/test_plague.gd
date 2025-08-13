extends ExceedGutTest

func who_am_i():
	return "plague"

func test_plague_bait_bomb_topdeck_choices():
	# Ensure p1 has Chain Reaction in hand
	var boost_card = give_player_specific_card(player1, "plague_chainreaction")
	# Pay force cost 1 from hand to boost
	assert_true(game_logic.do_boost(player1, boost_card, [player1.hand[0].id]))
	# First choose-cards-from-top-deck (look 3) - choose action add_to_gauge
	var top3 := []
	for i in range(min(3, player1.deck.size())):
		top3.append(player1.deck[i].id)
	var gauge_choice = top3[0]
	var hand_choice = top3[1]
	# Pick the 2nd option add_to_gauge: choose the first of the looked cards to go to gauge
	assert_true(game_logic.do_choose_from_topdeck(player1, gauge_choice, "add_to_gauge"))
	# Second effect triggers (look 2). Since we chose add_to_hand condition false, the base effect does add_to_gauge
	# Choose add_to_hand for the second; this uses the negative_condition_effect path
	assert_true(game_logic.do_choose_from_topdeck(player1, hand_choice, "add_to_hand"))
	# Verify destinations
	var went_to_gauge = gauge_choice
	var went_to_hand = hand_choice
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player1.gauge[0].id, went_to_gauge)
	# Last card added to hand should be at end of hand, but then we draw 1 end of turn.
	assert_eq(player1.hand[player1.hand.size()-2].id, went_to_hand)
	# Opponent just advances turn without actions
	advance_turn(player2)
	# It should be p1's turn again
	assert_eq(game_logic.get_active_player(), player1.my_id)
