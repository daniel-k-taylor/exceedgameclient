extends ExceedGutTest

func who_am_i():
	return "sydney"

##
## Tests start here
##

func test_sydney_blossomhaze():
	position_players(player1, 3, player2, 7)

	# Land a hit with a card that has a transform
	var strike_cards = execute_strike(player1, player2, "sydney_blossomhaze", "standard_normal_assault",
		false, false, [0]) # Accept choice to transform
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 27)

	# The transformed card went to the transform area rather than gauge
	assert_false(player1.is_card_in_gauge(strike_cards[0]))
	assert_true(player1.is_card_in_transforms(strike_cards[0]))

	advance_turn(player2)


func test_sydney_blossomhaze_fromselfwhenexceeded():
	position_players(player1, 3, player2, 7)
	player1.life = 10
	player1.exceed()
	assert_eq(player1.life, 15)

	# Land a hit with a card that has a transform
	var strike_cards = execute_strike(player1, player2, "sydney_blossomhaze", "standard_normal_assault",
		false, false)
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 15, player2, 30)

	# The transformed card went to the transform area rather than gauge
	assert_false(player1.is_card_in_gauge(strike_cards[0]))
	assert_false(player1.is_card_in_transforms(strike_cards[0]))

	advance_turn(player2)


func test_sydney_exceed_bonus():
	position_players(player1, 3, player2, 7)
	player1.discard_hand()

	give_player_specific_card(player1, "sydney_blossomhaze")
	give_player_specific_card(player1, "sydney_venomlash")
	player1.add_to_transforms(player1.hand[1])
	player1.add_to_transforms(player1.hand[0])

	assert_eq(player1.get_exceed_cost(), 3)
	position_players(player1, 5, player2, 7)
	assert_eq(player1.get_exceed_cost(), 0)
	assert_true(game_logic.do_exceed(player1, []))
	advance_turn(player2)



func test_sydney_verdantslaughter_pulltosource():
	position_players(player1, 1, player2, 6)
	var p1_gauge = give_gauge(player1, 6)
	var pay_with = [p1_gauge[0], p1_gauge[1]]
	# Attack with Verdant Slaughter and have just enough gauge to not get stunned from assault.
	execute_strike(player1, player2, "sydney_verdantslaughter", "standard_normal_assault",
		false, false, [pay_with]) # pay gauge cost
	validate_positions(player1, 1, player2, 5)
	validate_life(player1, 30, player2, 22)

	advance_turn(player2)

func test_sydney_verdantslaughter_guardup_per_gauge_stunned_empty():
	position_players(player1, 2, player2, 1)
	player1.exceed()

	var p1_gauge = give_gauge(player1, 2)
	var pay_with = [p1_gauge[0], p1_gauge[1]]
	# Attack with Verdant Slaughter and have just enough gauge to not get stunned from assault.
	execute_strike(player1, player2, "sydney_verdantslaughter", "standard_normal_assault",
		false, false, [[], pay_with]) # Exceed effect pass, then pay gauge cost
	validate_positions(player1, 2, player2, 1)
	validate_life(player1, 26, player2, 30)

	advance_turn(player2)

func test_sydney_verdantslaughter_guardup_per_gauge():
	position_players(player1, 2, player2, 1)
	player1.exceed()

	var p1_gauge = give_gauge(player1, 3)
	var pay_with = [p1_gauge[0], p1_gauge[1]]
	# Attack with Verdant Slaughter and have just enough gauge to not get stunned from assault.
	execute_strike(player1, player2, "sydney_verdantslaughter", "standard_normal_assault",
		false, false, [[], pay_with]) # Exceed effect pass, then pay gauge cost
	validate_positions(player1, 2, player2, 1)
	validate_life(player1, 26, player2, 22)

	advance_turn(player2)


func test_sydney_verdantslaughter_drawpergauge():
	position_players(player1, 2, player2, 1)

	give_gauge(player1, 3)
	player1.discard_hand()
	assert_eq(player1.hand.size(), 0)
	var boostcard = give_player_specific_card(player1, "sydney_verdantslaughter")
	assert_true(game_logic.do_boost(player1, boostcard, []))
	assert_eq(player1.hand.size(), 3)
	# Don't transform
	assert_true(game_logic.do_gauge_for_effect(player1, []))
	assert_eq(player1.hand.size(), 4)
	advance_turn(player2)


func test_sydney_verdantslaughter_drawpergauge_transform_noneavailable():
	position_players(player1, 2, player2, 1)

	var p1gauge = give_gauge(player1, 3)
	player1.discard_hand()
	assert_eq(player1.hand.size(), 0)
	var boostcard = give_player_specific_card(player1, "sydney_verdantslaughter")
	assert_true(game_logic.do_boost(player1, boostcard, []))
	assert_eq(player1.hand.size(), 3)
	# Check what happens if no transform
	player1.discard_hand()
	assert_true(game_logic.do_gauge_for_effect(player1, [p1gauge[0]]))
	assert_eq(player1.hand.size(), 1)
	advance_turn(player2)


func test_sydney_verdantslaughter_drawpergauge_transform():
	position_players(player1, 2, player2, 1)

	var p1gauge = give_gauge(player1, 3)
	player1.discard_hand()
	assert_eq(player1.hand.size(), 0)
	var boostcard = give_player_specific_card(player1, "sydney_verdantslaughter")
	assert_true(game_logic.do_boost(player1, boostcard, []))
	assert_eq(player1.hand.size(), 3)
	# Make sure you have a transform.
	var transformcard = give_player_specific_card(player1, "sydney_venomlash")
	assert_true(game_logic.do_gauge_for_effect(player1, [p1gauge[0]]))
	assert_true(game_logic.do_boost(player1, transformcard))
	assert_eq(player1.hand.size(), 4)
	assert_true(player1.is_card_in_transforms(transformcard))
	advance_turn(player2)


func test_sydney_aluraunekiss_opponentdiscardgauge():
	position_players(player1, 2, player2, 4)

	var p1gauge = give_gauge(player1, 3)
	var pay_with = [p1gauge[0], p1gauge[1]]
	var p2gauge = give_gauge(player2, 3)
	player1.discard_hand()
	execute_strike(player1, player2, "sydney_alurauneskiss", "standard_normal_assault",
		false, false, [pay_with], [p2gauge[0]]) # p1 pay for ultra, p2 discard card
	validate_life(player1, 30, player2, 26)
	assert_eq(player1.gauge.size(), 4) # Went down to 1 to play, then ultra and 2 hit cards go in.
	assert_eq(player2.gauge.size(), 2)

	advance_turn(player2)

func test_sydney_spentgauge_transform():
	position_players(player1, 3, player2, 8)

	give_player_specific_card(player1, "sydney_blossomhaze")
	player1.add_to_transforms(player1.hand[-1])
	give_player_specific_card(player1, "sydney_sporeburst")
	player1.add_to_transforms(player1.hand[-1])
	var p1gauge = give_gauge(player1, 4)
	execute_strike(player1, player2, "sydney_peashooter", "standard_normal_assault",
		false, false, [[p1gauge[0], p1gauge[1]], 2, 0]) # Pay for spore transform to add armor, pull pea shooter, then push transform
	validate_positions(player1, 3, player2, 6) # Pea shooter pulls 3 to 5, then push 1 to go to 6
	validate_life(player1, 30, player2, 29)


func test_sydney_spentgauge_transform_dontspend():
	position_players(player1, 3, player2, 8)

	give_player_specific_card(player1, "sydney_blossomhaze")
	player1.add_to_transforms(player1.hand[-1])
	give_player_specific_card(player1, "sydney_sporeburst")
	player1.add_to_transforms(player1.hand[-1])
	give_gauge(player1, 4)
	execute_strike(player1, player2, "sydney_peashooter", "standard_normal_assault",
		false, false, [[], 2]) # Don't pay, pull pea shooter, no more choices
	validate_positions(player1, 3, player2, 5) # Pea shooter pulls 3 to 5, then push 1 to go to 6
	validate_life(player1, 30, player2, 29)
