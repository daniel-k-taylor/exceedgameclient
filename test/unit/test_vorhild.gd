extends ExceedGutTest

func who_am_i():
	return "vorhild"

## Character ability -- Action: Retreat 1. If you are Infused, you may play a Boost from your hand.

func test_vorhild_ua_with_boost():
	position_players(player1, 3, player2, 6)
	var fierce_id = give_player_specific_card(player1, "standard_normal_grasp")
	
	var gauge_cards = give_gauge(player1, 1)
	# Infusion action
	assert_true(game_logic.do_character_action(player1, [gauge_cards[0]], 1))

	assert_true(game_logic.do_character_action(player1, []))
	assert_true(game_logic.do_choice(player1, 0)) # accept choice to boost
	assert_true(game_logic.do_boost(player1, fierce_id, []))
	var events = game_logic.get_latest_events()

	assert_true(player1.is_card_in_continuous_boosts(fierce_id))
	validate_positions(player1, 2, player2, 6)
	validate_not_has_event(events, Enums.EventType.EventType_RevealHand, player1, 0)
	assert_eq(game_logic.get_active_player(), player2.my_id)

func test_vorhild_ua_with_no_boost():
	position_players(player1, 3, player2, 6)
	player1.discard_hand()
	
	var gauge_cards = give_gauge(player1, 1)
	# Infusion action
	assert_true(game_logic.do_character_action(player1, [gauge_cards[0]], 1))

	assert_true(game_logic.do_character_action(player1, []))
	assert_true(game_logic.do_choice(player1, 0)) # accept choice to boost, but it gets skipped
	var events = game_logic.get_latest_events()

	validate_positions(player1, 2, player2, 6)
	validate_not_has_event(events, Enums.EventType.EventType_RevealHand, player1, 0)
	assert_eq(game_logic.get_active_player(), player2.my_id)
