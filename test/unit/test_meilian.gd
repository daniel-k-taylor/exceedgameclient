extends ExceedGutTest

func who_am_i():
	return "meilian"

func _zone_has_card(zone, card_id: int) -> bool:
	return zone.any(func(card): return card.id == card_id)

func test_kuangfengbaoyu_swaps_deck_and_discard():
	var discard_id_1 = give_player_specific_card(player1, "standard_normal_assault")
	var discard_id_2 = give_player_specific_card(player1, "standard_normal_dive")
	player1.discard([discard_id_1, discard_id_2])

	var boost_id = give_player_specific_card(player1, "meilian_fujingu")
	var pay_id = give_player_specific_card(player1, "standard_normal_grasp")
	assert_true(game_logic.do_boost(player1, boost_id, [pay_id]))

	var events = game_logic.get_latest_events()
	var reveal_hand_event = Enums.EventType.keys().find("EventType_RevealHand")
	validate_has_event(events, reveal_hand_event, player1)
	var swap_event = Enums.EventType.keys().find("EventType_SwapDeckAndDiscard")
	var swap_events = validate_has_event(events, swap_event, player1)
	assert_gt(swap_events[0]["extra_info"].size(), 0)
	assert_true(_zone_has_card(player1.deck, discard_id_1) or _zone_has_card(player1.hand, discard_id_1))
	assert_true(_zone_has_card(player1.deck, discard_id_2) or _zone_has_card(player1.hand, discard_id_2))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)
	assert_eq(game_logic.get_active_player(), player2.my_id)

func test_jiji_blocks_opponent_advance_and_close():
	position_players(player1, 3, player2, 5)

	execute_strike(
		player1,
		player2,
		"meilian_jiji",
		"meilian_yunqishi"
	)

	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 27, player2, 30)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)
	assert_eq(game_logic.get_active_player(), player2.my_id)
	assert_false(player2.cannot_advance_or_close)

func test_jiji_block_does_not_persist_into_later_strikes():
	position_players(player1, 3, player2, 5)

	execute_strike(
		player1,
		player2,
		"meilian_jiji",
		"meilian_yunqishi"
	)

	assert_false(player2.cannot_advance_or_close)
	assert_eq(game_logic.get_active_player(), player2.my_id)

	execute_strike(player2, player1, "standard_normal_assault", "standard_normal_focus")

	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 25, player2, 26)

func test_liuxingzhiyuan_supports_topdeck_choice():
	var chosen_topdeck_id = set_player_topdeck(player1, "standard_normal_spike")
	set_player_topdeck(player1, "standard_normal_dive")
	set_player_topdeck(player1, "standard_normal_assault")

	var boost_id = give_player_specific_card(player1, "meilian_leishenshiyan")
	var pay_id = give_player_specific_card(player1, "standard_normal_cross")
	assert_true(game_logic.do_boost(player1, boost_id, [pay_id]))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseFromTopDeck)
	assert_eq(game_logic.decision_info.action.size(), 3)
	assert_eq(game_logic.decision_info.action[2], "topdeck")

	assert_true(game_logic.do_choose_from_topdeck(player1, chosen_topdeck_id, "topdeck"))
	assert_true(_zone_has_card(player1.hand, chosen_topdeck_id))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)
	assert_eq(game_logic.get_active_player(), player2.my_id)

func test_yunqishi_boost_draws_and_discards_for_each_card_in_hand():
	player1.discard_hand()
	var boost_id = give_player_specific_card(player1, "meilian_yunqishi")
	give_player_specific_card(player1, "standard_normal_assault")
	give_player_specific_card(player1, "standard_normal_cross")
	give_player_specific_card(player1, "standard_normal_dive")

	assert_true(game_logic.do_boost(player1, boost_id, []))
	assert_eq(player1.hand.size(), 6)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseToDiscard)
	assert_eq(game_logic.decision_info.effect.amount, 3)

	var discard_ids = [player1.hand[0].id, player1.hand[1].id, player1.hand[2].id]
	assert_true(game_logic.do_choose_to_discard(player1, discard_ids))
	assert_eq(player1.hand.size(), 4)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)
	assert_eq(game_logic.get_active_player(), player2.my_id)

func test_meilian_ua_rechecks_range_after_sweep_discards_same_name():
	game_logic.teardown()
	game_logic.free()
	default_game_setup("solbadguy")
	player1.discard_hand()
	position_players(player1, 3, player2, 6)

	var spare_focus_id = give_player_specific_card(player1, "standard_normal_focus")
	var strike_focus_id = give_player_specific_card(player1, "standard_normal_focus")
	execute_strike(player1, player2, strike_focus_id, "standard_normal_sweep")

	assert_true(_zone_has_card(player1.discards, spare_focus_id))
	assert_true(_zone_has_card(player1.gauge, strike_focus_id))
	validate_life(player1, 26, player2, 26)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)
	assert_eq(game_logic.get_active_player(), player2.my_id)

func test_meilian_opening_turn_prepare_move_and_strike_flow():
	position_players(player1, 3, player2, 7)

	var initial_hand_size = player1.hand.size()
	assert_true(game_logic.do_prepare(player1))
	assert_gt(player1.hand.size(), initial_hand_size)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)
	assert_eq(game_logic.get_active_player(), player2.my_id)

	advance_turn(player2)

	var move_card_id = player1.hand[0].id
	assert_true(game_logic.do_move(player1, [move_card_id], 4))
	validate_positions(player1, 4, player2, 7)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)
	assert_eq(game_logic.get_active_player(), player2.my_id)

	advance_turn(player2)

	execute_strike(player1, player2, "standard_normal_spike", "standard_normal_focus")
	validate_positions(player1, 4, player2, 7)
	validate_life(player1, 30, player2, 25)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)
	assert_eq(game_logic.get_active_player(), player2.my_id)