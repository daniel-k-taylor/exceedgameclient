extends ExceedGutTest

func who_am_i():
	return "khenui"

## Khenui - When you move past the opponent, you may add the top card of your Deck to Gauge.

func test_khenui_crossup_gauge_from_walk():
	position_players(player1, 3, player2, 5)
	var gauge_card = give_player_specific_card(player1, "standard_normal_grasp")
	player1.move_card_from_hand_to_deck(gauge_card)
	
	assert_true(game_logic.do_move(player1, [player1.hand[0].id, player1.hand[1].id, player1.hand[2].id], 6))
	# triggers choice to gain gauge
	assert_true(game_logic.do_choice(player1, 0))
	
	validate_positions(player1, 6, player2, 5)
	assert_true(player1.is_card_in_gauge(gauge_card))
	
	advance_turn(player2)

func test_khenui_crossup_gauge_from_boost():
	position_players(player1, 3, player2, 5)
	var gauge_card = give_player_specific_card(player1, "standard_normal_grasp")
	player1.move_card_from_hand_to_deck(gauge_card)
	
	var boost_card = give_player_specific_card(player1, "standard_normal_cross")
	assert_true(game_logic.do_boost(player1, boost_card, []))
	assert_true(game_logic.do_choice(player1, 2)) # advance 3
	# triggers choice to gain gauge
	assert_true(game_logic.do_choice(player1, 0))
	
	validate_positions(player1, 7, player2, 5)
	assert_true(player1.is_card_in_gauge(gauge_card))
	
	advance_turn(player2)

func test_khenui_crossup_gauge_during_strike():
	position_players(player1, 3, player2, 6)
	var gauge_card = give_player_specific_card(player1, "standard_normal_grasp")
	player1.move_card_from_hand_to_deck(gauge_card)
	
	execute_strike(player1, player2, "standard_normal_dive", "standard_normal_sweep",
		false, false, [0]) # choose to gain gauge after crossup
	
	validate_positions(player1, 7, player2, 6)
	validate_life(player1, 30, player2, 25)
	assert_true(player1.is_card_in_gauge(gauge_card))
	
	advance_turn(player2)

## [3G] When you Exceed, add 2 cards from your discard pile to your Gauge.
## Infused, After: Spend up to 2 Force. For each Force spent, Move 1 or Draw 1.

func test_khenui_exceed_effect_loop():
	position_players(player1, 1, player2, 5)
	var exceed_gauge = give_gauge(player1, 3)
	assert_true(game_logic.do_exceed(player1, exceed_gauge))
	assert_true(game_logic.do_choose_from_discard(player1, [exceed_gauge[0], exceed_gauge[1]])) # kicker
	advance_turn(player2)
	
	assert_true(game_logic.do_character_action(player1, [exceed_gauge[0]])) # infuse
	execute_strike(player1, player2, "standard_normal_dive", "standard_normal_spike",
		false, false, [
			[player1.hand[0].id, player1.hand[1].id], # generate 2 force
			0, # advance 1; move past opponent
			1 # retreat 1
		])
	
	validate_positions(player1, 7, player2, 5)
	validate_life(player1, 30, player2, 25)
	
	advance_turn(player2)

## Bend Reality - 1-2/3/6; Hit: Draw 1. If you are Infused, Push or Pull 2.
##		After: You may discard this; if you do, return a card from your Gauge to your hand.

func test_khenui_bend_reality_no_gauge():
	position_players(player1, 3, player2, 5)
	
	var strike_cards = execute_strike(player1, player2, "khenui_bendreality", "standard_normal_grasp",
		false, false, [0]) # discard attack for no effect
	
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 30, player2, 27)
	assert_true(player1.is_card_in_discards(strike_cards[0]))
	
	advance_turn(player2)

func test_khenui_bend_reality_return_gauge():
	position_players(player1, 3, player2, 5)
	var gauge_card = give_gauge(player1, 1)
	
	var strike_cards = execute_strike(player1, player2, "khenui_bendreality", "standard_normal_grasp",
		false, false, [[], 0, gauge_card]) # decline infuse, then discard attack to get gauge card back
	
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 30, player2, 27)
	assert_true(player1.is_card_in_discards(strike_cards[0]))
	assert_true(player1.is_card_in_hand(gauge_card[0]))
	
	advance_turn(player2)

## Whirling Sands: 2/4/8; After: Spend up to 4 Force to Push or Pull that many spaces.

func test_khenui_whirling_sands_combined_pull():
	position_players(player1, 4, player2, 2)
	var gauge_cards = give_gauge(player1, 2)
	
	var strike_cards = execute_strike(player1, player2, "khenui_whirlingsands", "standard_normal_grasp",
		false, false, [[], gauge_cards, 1,		# decline infuse, pay for ultra, choose pull
						[player1.hand[0].id, player1.hand[1].id, player1.hand[2].id, player1.hand[3].id]]) # spend 4 force
	
	validate_positions(player1, 4, player2, 7)
	validate_life(player1, 30, player2, 26)
	
	advance_turn(player2)
