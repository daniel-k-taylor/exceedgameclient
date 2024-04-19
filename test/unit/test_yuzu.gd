extends ExceedGutTest

func who_am_i():
	return "yuzu"

## Character action: Add a card from your hand to your Gauge. If you have 4+ cards in
##     your Gauge after this, Exceed (at no cost).

func test_yuzu_ua_under_four_gauge():
	position_players(player1, 3, player2, 5)
	give_gauge(player1, 1)
	assert_true(game_logic.do_character_action(player1, []))
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_CardFromHandToGauge_Choice, player1)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	var card_to_choose = player1.hand[0]
	assert_true(game_logic.do_relocate_card_from_hand(player1, [card_to_choose.id]))
	events = game_logic.get_latest_events()
	assert_true(player1.is_card_in_gauge(card_to_choose.id))

	if player1.exceeded:
		fail_test("Should not have exceeded after character action")
	pass_test("test passed")

func test_yuzu_ua_four_gauge():
	position_players(player1, 3, player2, 5)
	give_gauge(player1, 3)
	assert_true(game_logic.do_character_action(player1, []))
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_CardFromHandToGauge_Choice, player1)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	var card_to_choose = player1.hand[0]
	assert_true(game_logic.do_relocate_card_from_hand(player1, [card_to_choose.id]))
	events = game_logic.get_latest_events()
	assert_true(player1.is_card_in_gauge(card_to_choose.id))

	if not player1.exceeded:
		fail_test("Should have exceeded after character action")
	pass_test("test passed")

## Exceed mode passive: Your attacks have "Cleanup: Discard your attack."

func test_yuzu_discard_block_while_exceeded():
	position_players(player1, 3, player2, 5)
	var p1_gauge = give_gauge(player1, 1)
	assert_true(game_logic.do_exceed(player1, p1_gauge))

	var strike_cards = execute_strike(player2, player1, "uni_normal_assault", "uni_normal_block",
		false, false, [], [[]])  # player 1 declines to pay force for block
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_Strike_ForceForArmor, player1)

	assert_true(player2.is_card_in_gauge(strike_cards[0]))
	assert_true(player1.is_card_in_discards(strike_cards[1]))
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 28, player2, 30)

## Inochi Kurenai Cleanup: If you were stunned, you may add this card to your
## boost area as a continuous boost and sustain it.

func test_yuzu_kurenai_stunned_while_exceeded():
	# Should be able to stack the two cleanup triggers advantageously.
	position_players(player1, 3, player2, 5)
	var p1_gauge = give_gauge(player1, 2)
	assert_true(game_logic.do_exceed(player1, [p1_gauge[0]]))

	var strike_cards = execute_strike(player2, player1, "uni_normal_assault", "yuzu_kurenai",
			false, false, [],
			[[p1_gauge[1]], 1, 0]  # Pay gauge with remaining card;
								   # then choose to discard the strike first (effect ordering);
								   # then choose to add it to the boost area and sustain it
		)

	assert_true(player2.is_card_in_gauge(strike_cards[0]))
	assert_true(player1.is_card_in_continuous_boosts(strike_cards[1]))
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 26, player2, 30)

## Exceed character action: Strike with a random card from your Gauge face-up.
##     If you did, your attack has +2 Power and +1 Speed. The opponent sets
##     their attack first.

func test_yuzu_strike_from_gauge_assault():
	position_players(player1, 3, player2, 5)
	var assault_id = give_player_specific_card(player1, "uni_normal_assault")
	player1.move_card_from_hand_to_gauge(assault_id)
	player1.exceed()
	# Expected: Yuzuriha uses her character action to set Assault from her gauge.
	#     It has speed 5 + 1 and hits for 4 + 2 and wins a speed tie against Cross.
	assert_true(game_logic.do_character_action(player1, [], 0))
	assert_true(game_logic.do_strike(player1, -1, false, -1, true))
	var cross_id = give_player_specific_card(player2, "uni_normal_cross")
	assert_true(game_logic.do_strike(player2, cross_id, false, -1, true))
	validate_life(player1, 30, player2, 24)
	validate_positions(player1, 4, player2, 5)
	assert_eq(game_logic.active_turn_player, player1.my_id)
