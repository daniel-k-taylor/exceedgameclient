extends ExceedGutTest

func who_am_i():
	return "ryu"

func test_life_payment_cannot_be_lethal_or_negative():
	player1.life = 3
	assert_false(player1.spend_life(3))
	assert_false(player1.spend_life(4))
	assert_false(player1.spend_life(-1))
	assert_eq(player1.life, 3)
	assert_eq(player1.last_spent_life, 0)
	assert_false(game_logic.game_over)
	assert_true(player1.spend_life(2))
	assert_eq(player1.life, 1)
	assert_eq(player1.last_spent_life, 2)

func test_unaffordable_effect_does_not_grant_chained_benefit():
	player1.life = 3
	var hand_size = player1.hand.size()
	game_logic.handle_strike_effect(-1, {
		"effect_type": "spend_life", "amount": 3,
		"and": {"effect_type": "draw", "amount": 3}
	}, player1)
	assert_eq(player1.life, 3)
	assert_eq(player1.hand.size(), hand_size)
	assert_false(game_logic.game_over)

func test_draw_choices_reject_lethal_payments_and_keep_indices():
	player1.life = 3
	player1.discard_hand()
	var boost_id = give_player_specific_card(player1, "akuma_gohadoken")
	assert_true(game_logic.do_boost(player1, boost_id))
	for choice_index in [2, 3, 4]:
		assert_false(game_logic.do_choice(player1, choice_index))
		assert_eq(player1.life, 3)
		assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)
	assert_true(game_logic.do_choice(player1, 1))
	assert_eq(player1.life, 1)
	assert_eq(player1.hand.size(), 3, "Draw two from the effect and one at end of turn")

func test_force_and_gauge_payments_must_leave_one_life():
	player1.life = 2
	player1.spend_life_for_force_amount = 1
	player1.spend_life_for_gauge_amount = 1
	player1.discard_hand()
	assert_eq(player1.get_available_force(), 1)
	assert_false(player1.can_pay_cost_with([], 2, 0, false, 2))
	assert_false(player1.can_pay_cost_with([], 0, 2, false, 0, 0, 2))
	assert_false(player1.can_pay_cost_with([], 0, 0, false, 0, 2))
	assert_false(game_logic.handle_spend_life_for_force(player1, 2))
	assert_false(game_logic.handle_spend_life_cost(player1, 2))
	assert_eq(player1.life, 2)
	assert_true(player1.can_pay_cost_with([], 1, 0, false, 1))
	assert_true(player1.can_pay_cost_with([], 0, 1, false, 0, 0, 1))

func test_exceed_cannot_pay_with_last_life():
	player1.life = 3
	player1.spend_life_for_gauge_amount = 1
	assert_false(game_logic.do_exceed(player1, [], 3))
	assert_eq(player1.life, 3)
	assert_false(player1.exceeded)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)

func test_infusion_cannot_pay_with_last_life():
	player1.life = 2
	assert_false(game_logic.handle_infusion(player1, InfusionCost.new(-1, 2)))
	assert_eq(player1.life, 2)
	assert_false(player1.is_infused())

func test_rejected_change_does_not_discard_payment_cards():
	player1.life = 2
	player1.spend_life_for_force_amount = 1
	var card_id = give_player_specific_card(player1, "standard_normal_grasp")
	assert_false(game_logic.do_change(player1, [card_id], false, false, 2))
	assert_true(player1.is_card_in_hand(card_id))
	assert_eq(player1.life, 2)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)

func test_rejected_move_does_not_discard_payment_cards():
	player1.life = 2
	player1.spend_life_for_force_amount = 1
	position_players(player1, 3, player2, 7)
	var card_id = give_player_specific_card(player1, "standard_normal_grasp")
	assert_false(game_logic.do_move(player1, [card_id], 4, false, 2))
	assert_true(player1.is_card_in_hand(card_id))
	assert_eq(player1.life, 2)
	assert_eq(player1.arena_location, 3)

func test_mandatory_boost_payment_does_not_grant_unpaid_gauge():
	player1.life = 3
	var card_id = give_player_specific_card(player1, "enkidu_threepreceptstrike")
	assert_true(game_logic.do_boost(player1, card_id))
	assert_eq(player1.life, 3)
	assert_true(player1.is_card_in_discards(card_id))
	assert_false(player1.is_card_in_gauge(card_id))
	assert_false(game_logic.game_over)

func test_ai_does_not_offer_lethal_life_choices():
	player1.life = 2
	var boost_id = give_player_specific_card(player1, "akuma_gohadoken")
	assert_true(game_logic.do_boost(player1, boost_id))
	var ai = AIPlayer.new(game_logic, player1)
	var choices = ai.determine_effect_choice_actions().map(func(action): return action.choice)
	assert_eq(choices, [0, 5], "Spend one or pass, with the original choice indices")
	ai.ai_policy.free()
