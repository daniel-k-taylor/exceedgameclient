extends ExceedGutTest

func who_am_i():
	return "miyuki"

##
## Tests start here
##

## General Infusion functionality:

## control case

func test_no_infusion():
	position_players(player1, 3, player2, 5)
	player1.discard_hand()
	player2.discard_hand()
	
	var strike_cards = execute_strike(player1, player2, "miyuki_cripplingsparks", "standard_normal_sweep",
		false, false, [1]) # Pull 2
		
	validate_positions(player1, 3, player2, 2)
	validate_life(player1, 24, player2, 26)

	advance_turn(player2)

## - Infusing as an action

func test_infusion_before_action():
	position_players(player1, 3, player2, 5)
	player1.discard_hand()
	player2.discard_hand()
	
	var gauge_cards = give_gauge(player1, 2)

	# Infusion action
	assert_true(game_logic.do_character_action(player1, [gauge_cards[0]], 1))
	
	# Strike; attack becomes IG if infused, should not offer a choice to infuse again after setting
	var strike_cards = execute_strike(player1, player2, "miyuki_cripplingsparks", "standard_normal_sweep",
		false, false, [1]) # Pull 2
		
	validate_positions(player1, 3, player2, 2)
	validate_life(player1, 30, player2, 26)

	advance_turn(player2)

## - Infusing when initiating

func test_infusion_when_initiating():
	position_players(player1, 3, player2, 5)
	player1.discard_hand()
	player2.discard_hand()
	
	var gauge_cards = give_gauge(player1, 1)
	
	# Strike; attack becomes IG if infused, should allow you to infuse when setting
	var strike_cards = execute_strike(player1, player2, "miyuki_cripplingsparks", "standard_normal_sweep",
		false, false, [gauge_cards, 1]) # Pull 2
		
	validate_positions(player1, 3, player2, 2)
	validate_life(player1, 30, player2, 26)

	advance_turn(player2)

## - Infusing when defending

func test_infusion_when_defending():
	position_players(player1, 3, player2, 5)
	advance_turn(player1)
	player1.discard_hand()
	player2.discard_hand()
	
	var gauge_cards = give_gauge(player1, 1)
	
	# Strike; attack becomes IG if infused, should allow you to infuse when setting
	var strike_cards = execute_strike(player2, player1, "standard_normal_sweep", "miyuki_cripplingsparks",
		false, false, [], [gauge_cards, 1]) # Pull 2
		
	validate_positions(player1, 3, player2, 2)
	validate_life(player1, 30, player2, 26)

	advance_turn(player1)
	
	
## Exceed UA - Boosting from Gauge granting infusion and causing a strike

func test_miyuki_exceed_strike():
	position_players(player1, 3, player2, 5)
	
	var gauge_cards = give_gauge(player1, 3)
	assert_true(game_logic.do_exceed(player1, gauge_cards))
	advance_turn(player2)
	player1.discard_hand()
	player2.discard_hand()
	
	var fierce_card = give_player_specific_card(player1, "standard_normal_grasp")
	player1.move_card_from_hand_to_gauge(fierce_card)

	# Boost Fierce from Gauge
	assert_true(game_logic.do_character_action(player1, [], 0))
	assert_true(game_logic.do_boost(player1, fierce_card, []))
	
	# Accept option to Strike
	assert_true(game_logic.do_choice(player1, 0))
	
	# Strike; should be infused and ignore guard
	var strike_cards = execute_strike(player1, player2, "miyuki_cripplingsparks", "standard_normal_sweep",
		false, false, [1]) # Pull 2
		
	validate_positions(player1, 3, player2, 2)
	validate_life(player1, 30, player2, 24)

	advance_turn(player2)

## Exceed UA - Boosting from Gauge giving another action (and infusion)

func test_miyuki_exceed_bonus_action():
	position_players(player1, 3, player2, 6)
	
	var gauge_cards = give_gauge(player1, 3)
	assert_true(game_logic.do_exceed(player1, gauge_cards))
	advance_turn(player2)
	player1.discard_hand()
	player2.discard_hand()
	
	player1.draw(1)
	var kindle_card = give_player_specific_card(player1, "miyuki_lifestealtouch")
	player1.move_card_from_hand_to_gauge(kindle_card)

	# Boost Kindle from Gauge
	assert_true(game_logic.do_character_action(player1, [], 0))
	assert_true(game_logic.do_boost(player1, kindle_card, [player1.hand[0].id]))
	
	# Decline option to strike; takes another action
	assert_true(game_logic.do_choice(player1, 1))
	
	# Additional boost to prove that you're not forced to strike here
	var foxfire_card = give_player_specific_card(player1, "miyuki_spiritheal")
	assert_true(game_logic.do_boost(player1, foxfire_card, []))
	assert_true(game_logic.do_choice(player1, 0)) # spend 2 life for another action; also have +0~1 range
	
	# Strike; should be infused and ignore guard
	var strike_cards = execute_strike(player1, player2, "miyuki_cripplingsparks", "standard_normal_sweep",
		false, false, [1]) # Pull 2
		
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 28, player2, 25)

	advance_turn(player2)

## Spirit Guide - Look at the opponent's hand. Add a card from their hand to Gauge.

func test_miyuki_spirit_guide():
	position_players(player1, 3, player2, 7)
	
	var spiritguide_card = give_player_specific_card(player1, "miyuki_firelight")

	assert_true(game_logic.do_boost(player1, spiritguide_card, []))
	
	# Opponent's hand is revealed
	assert_eq(player2.public_hand.size(), player2.hand.size())
	for card in player2.public_hand:
		assert_true(card in player2.public_hand)
	
	# Choose a card from their hand to add to gauge
	var discard_target = player2.hand[0].id
	assert_true(game_logic.do_choose_to_discard(player1, [discard_target]))
	
	assert_true(player2.is_card_in_gauge(discard_target))
	assert_false(player2.is_card_in_hand(discard_target))
	assert_eq(player2.gauge.size(), 1)

	advance_turn(player2)
	
## Healing Light - At the start of your turn, you may draw 1 or gain 1 life.

func test_miyuki_healing_light():
	position_players(player1, 3, player2, 7)
	player1.life = 20
	player1.discard_hand()
	player2.discard_hand()
	
	player1.draw(1)
	var healinglight_card = give_player_specific_card(player1, "miyuki_uncagedsoul")

	assert_true(game_logic.do_boost(player1, healinglight_card, [player1.hand[0].id]))
	
	# end of turn draw - 1 card in hand
	assert_eq(player1.hand.size(), 1)
	advance_turn(player2)
	
	# choose to draw, then prepare - total of 4 cards in hand
	assert_true(game_logic.do_choice(player1, 0))
	assert_true(game_logic.do_prepare(player1))
	assert_eq(player1.hand.size(), 4)
	advance_turn(player2)
	
	# choose to heal, then prepare - total of 6 cards in hand
	assert_true(game_logic.do_choice(player1, 1))
	assert_true(game_logic.do_prepare(player1))
	assert_eq(player1.hand.size(), 6)
	assert_eq(player1.life, 21)
	advance_turn(player2)
