extends ExceedGutTest

func who_am_i():
	return "tournelouse"

func test_pre_exceed_normal_can_ex_transform():
	var assault_id = give_player_specific_card(player1, "standard_normal_assault")

	assert_true(game_logic.can_do_ex_transform(player1))
	assert_true(game_logic.do_ex_transform(player1, assault_id, -1))

	assert_eq(player1.transforms.size(), 1)
	assert_eq(player1.transforms[0].id, assault_id)
	assert_true(player1.transforms[0].definition.has("replaced_boost"))
	assert_eq(player1.transforms[0].definition["boost"]["boost_type"], "transform")
	assert_eq(player1.transforms[0].definition["boost"]["effects"][0]["effect_type"], StrikeEffects.Powerup)

func test_normal_cleanup_transform_does_not_trigger_original_boost():
	position_players(player1, 3, player2, 4)

	var strike_cards = execute_strike(player1, player2,
		"standard_normal_focus", "standard_normal_grasp",
		false, false,
		[0], [0, 1])

	assert_true(player1.is_card_in_transforms(strike_cards[0]))
	assert_ne(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_ne(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ReadingNormal)

func test_bargeist_can_pay_gauge_cost_by_sealing_transforms():
	var bargeist_id = give_player_specific_card(player1, "tournelouse_bargeist_fang")
	add_transform(player1, "standard_normal_assault")
	add_transform(player1, "standard_normal_cross")
	var transform_id_1 = player1.transforms[0].id
	var transform_id_2 = player1.transforms[1].id
	var hand_transform_id = give_player_specific_card(player1, "standard_normal_dive")
	var response_id = give_player_specific_card(player2, "standard_normal_grasp")

	position_players(player1, 3, player2, 5)
	assert_true(game_logic.do_strike(player1, bargeist_id, false, -1))
	assert_true(game_logic.do_strike(player2, response_id, false, -1))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_PayStrikeCost_Required)
	assert_true(game_logic.do_pay_strike_cost(player1, [transform_id_1, transform_id_2], false))

	assert_eq(player1.transforms.size(), 0)
	assert_eq(player1.sealed.size(), 2)
	assert_true(player1.is_card_in_sealed(transform_id_1))
	assert_true(player1.is_card_in_sealed(transform_id_2))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)
	assert_true(game_logic.do_choice(player1, 0))
	var transform_choice_index = -1
	for i in range(game_logic.decision_info.choice.size()):
		if game_logic.decision_info.choice[i].get("transform_card_id", -1) == hand_transform_id:
			transform_choice_index = i
			break
	assert_ne(transform_choice_index, -1)
	assert_true(game_logic.do_choice(player1, transform_choice_index))
	assert_true(player1.is_card_in_transforms(hand_transform_id))

func test_bargeist_hit_transform_choice_creates_ai_action_event():
	position_players(player1, 3, player2, 5)
	var gauge_ids = give_gauge(player1, 2)
	give_player_specific_card(player1, "standard_normal_assault")

	execute_strike(player1, player2,
		"tournelouse_bargeist_fang", "standard_normal_grasp",
		false, false,
		[gauge_ids], [],
		true)

	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)
	validate_has_event(game_logic.get_latest_events(), Enums.EventType.EventType_Strike_EffectChoice, player1)

func test_bargeist_hit_choice_can_finish_and_draw_three():
	position_players(player1, 3, player2, 5)
	var gauge_ids = give_gauge(player1, 2)
	give_player_specific_card(player1, "standard_normal_assault")
	var hand_size_before = player1.hand.size()

	execute_strike(player1, player2,
		"tournelouse_bargeist_fang", "standard_normal_grasp",
		false, false,
		[gauge_ids], [],
		true)

	# First prompt is "transform another card?" -- index 1 is the Pass that ends
	# the repeat chain and triggers the trailing draw 3.
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)
	assert_eq(game_logic.decision_info.choice.size(), 2)
	assert_true(game_logic.do_choice(player1, 1))
	assert_eq(player1.hand.size(), hand_size_before + 3)

func test_bargeist_hit_choice_can_transform_then_choose_again():
	position_players(player1, 3, player2, 5)
	var gauge_ids = give_gauge(player1, 2)
	var transform_id = give_player_specific_card(player1, "standard_normal_assault")

	execute_strike(player1, player2,
		"tournelouse_bargeist_fang", "standard_normal_grasp",
		false, false,
		[gauge_ids], [],
		true)

	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)
	assert_true(game_logic.do_choice(player1, 0))

	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)
	var transform_choice_index = -1
	for i in range(game_logic.decision_info.choice.size()):
		if game_logic.decision_info.choice[i].get("transform_card_id", -1) == transform_id:
			transform_choice_index = i
			break
	assert_ne(transform_choice_index, -1)
	assert_true(game_logic.do_choice(player1, transform_choice_index))
	assert_true(player1.is_card_in_transforms(transform_id))

func test_bargeist_hit_choice_can_transform_netherstorm_then_choose_again():
	position_players(player1, 3, player2, 5)
	var gauge_ids = give_gauge(player1, 2)
	var netherstorm_id = give_player_specific_card(player1, "tournelouse_netherstorm")

	execute_strike(player1, player2,
		"tournelouse_bargeist_fang", "standard_normal_grasp",
		false, false,
		[gauge_ids], [],
		true)

	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)
	assert_true(game_logic.do_choice(player1, 0))

	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)
	var netherstorm_choice_index = -1
	for i in range(game_logic.decision_info.choice.size()):
		if game_logic.decision_info.choice[i].get("transform_card_id", -1) == netherstorm_id:
			netherstorm_choice_index = i
			break
	assert_ne(netherstorm_choice_index, -1)
	assert_true(game_logic.do_choice(player1, netherstorm_choice_index))
	assert_true(player1.is_card_in_transforms(netherstorm_id))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)

func test_ouroboros_action_pays_then_transforms_hand_card_then_returns_transform():
	add_transform(player1, "standard_normal_assault")
	var transform_id = player1.transforms[0].id
	var hand_transform_id = give_player_specific_card(player1, "standard_normal_cross")
	var gauge_ids = give_gauge(player1, 1)

	game_logic.handle_strike_effect(-1, { "effect_type": StrikeEffects.TournelouseOuroboros }, player1)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ForceForEffect)
	assert_true(game_logic.do_force_for_effect(player1, [gauge_ids[0]], false))
	assert_false(player1.is_card_in_discards(gauge_ids[0]))
	assert_true(player1.is_card_in_gauge(gauge_ids[0]))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseToDiscard)
	assert_true(game_logic.do_choose_to_discard(player1, [hand_transform_id]))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseFromBoosts)
	assert_true(game_logic.do_choose_from_boosts(player1, [transform_id]))

	assert_true(player1.is_card_in_transforms(hand_transform_id))
	var hand_transform_card = game_logic.get_card_database().get_card(hand_transform_id)
	assert_true(hand_transform_card.definition.has("replaced_boost"))
	assert_eq(hand_transform_card.definition["boost"]["effects"][0]["effect_type"], StrikeEffects.Powerup)
	assert_true(player1.is_card_in_hand(transform_id))
	assert_true(player1.is_card_in_discards(gauge_ids[0]))
	assert_false(player1.is_card_in_gauge(gauge_ids[0]))

func test_ouroboros_action_cannot_transform_card_chosen_for_force_payment():
	add_transform(player1, "standard_normal_assault")
	var paid_hand_transform_id = give_player_specific_card(player1, "standard_normal_cross")
	var other_hand_transform_id = give_player_specific_card(player1, "standard_normal_grasp")

	game_logic.handle_strike_effect(-1, { "effect_type": StrikeEffects.TournelouseOuroboros }, player1)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ForceForEffect)
	assert_true(game_logic.do_force_for_effect(player1, [paid_hand_transform_id], false))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseToDiscard)
	assert_false(paid_hand_transform_id in game_logic.decision_info.choice)
	assert_true(other_hand_transform_id in game_logic.decision_info.choice)
	assert_false(game_logic.do_choose_to_discard(player1, [paid_hand_transform_id]))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseToDiscard)

func test_ouroboros_action_finishes_character_action_resolution():
	add_transform(player1, "standard_normal_assault")
	var transform_id = player1.transforms[0].id
	var hand_transform_id = give_player_specific_card(player1, "standard_normal_cross")
	var gauge_ids = give_gauge(player1, 1)
	game_logic.active_character_action = true

	game_logic.handle_strike_effect(-1, { "effect_type": StrikeEffects.TournelouseOuroboros }, player1)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ForceForEffect)
	assert_true(game_logic.do_force_for_effect(player1, [gauge_ids[0]], false))
	assert_true(game_logic.do_choose_to_discard(player1, [hand_transform_id]))
	assert_true(game_logic.do_choose_from_boosts(player1, [transform_id]))

	assert_false(game_logic.active_character_action)
	assert_ne(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_ne(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseFromBoosts)

func test_ouroboros_action_bargeist_allows_duplicate_normal_but_cannot_return_bargeist():
	add_transform(player1, "standard_normal_assault")
	add_transform(player1, "tournelouse_bargeist_fang")
	var assault_transform_id = player1.transforms[0].id
	var bargeist_transform_id = player1.transforms[1].id
	var hand_assault_id = give_player_specific_card(player1, "standard_normal_assault")
	var gauge_ids = give_gauge(player1, 1)

	game_logic.handle_strike_effect(-1, { "effect_type": StrikeEffects.TournelouseOuroboros }, player1)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ForceForEffect)
	assert_true(game_logic.do_force_for_effect(player1, [gauge_ids[0]], false))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseToDiscard)
	assert_true(hand_assault_id in game_logic.decision_info.choice)
	assert_true(game_logic.do_choose_to_discard(player1, [hand_assault_id]))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseFromBoosts)

	assert_false(game_logic.do_choose_from_boosts(player1, [bargeist_transform_id]))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseFromBoosts)
	assert_true(game_logic.do_choose_from_boosts(player1, [assault_transform_id]))
	assert_true(player1.is_card_in_transforms(hand_assault_id))
	assert_true(player1.is_card_in_transforms(bargeist_transform_id))
	assert_true(player1.is_card_in_hand(assault_transform_id))

func test_ouroboros_action_cannot_pay_last_hand_card():
	add_transform(player1, "standard_normal_assault")
	var pay_card_id = give_player_specific_card(player1, "standard_normal_cross")
	while player1.hand.size() > 1:
		player1.discard([player1.hand[0].id])

	game_logic.handle_strike_effect(-1, { "effect_type": StrikeEffects.TournelouseOuroboros }, player1)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ForceForEffect)
	assert_false(game_logic.do_force_for_effect(player1, [pay_card_id], false))
	assert_true(player1.is_card_in_hand(pay_card_id))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ForceForEffect)

func test_ouroboros_action_can_cancel_force_step_back_to_pick_action():
	add_transform(player1, "standard_normal_assault")
	game_logic.active_character_action = true

	game_logic.handle_strike_effect(-1, { "effect_type": StrikeEffects.TournelouseOuroboros }, player1)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ForceForEffect)
	assert_true(game_logic.do_force_for_effect(player1, [], false, true, false))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)
	assert_false(game_logic.active_character_action)

func test_normal_transform_restores_boost_when_it_leaves_transforms():
	var assault_id = give_player_specific_card(player1, "standard_normal_assault")
	assert_true(game_logic.do_ex_transform(player1, assault_id, -1))
	var assault_card = game_logic.get_card_database().get_card(assault_id)

	player1.remove_from_transforms(assault_card)
	player1.add_to_hand(assault_card, true)

	assert_false(assault_card.definition.has("replaced_boost"))
	assert_ne(assault_card.definition["boost"]["boost_type"], "transform")

func test_exceeded_set_strike_can_choose_transform_to_seal_for_power():
	player1.exceed()
	add_transform(player1, "standard_normal_assault")
	var transform_id = player1.transforms[0].id
	var strike_id = give_player_specific_card(player1, "standard_normal_grasp")

	assert_true(game_logic.do_strike(player1, strike_id, false, -1))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)
	assert_true(game_logic.do_choice(player1, 0))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseFromBoosts)
	assert_true(game_logic.do_choose_from_boosts(player1, [transform_id]))

	assert_true(player1.is_card_in_sealed(transform_id))

func test_exceeded_transform_bonus_choice_can_cancel_back_to_options():
	player1.exceed()
	add_transform(player1, "standard_normal_assault")
	var transform_id = player1.transforms[0].id
	var strike_id = give_player_specific_card(player1, "standard_normal_grasp")

	assert_true(game_logic.do_strike(player1, strike_id, false, -1))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)
	assert_true(game_logic.do_choice(player1, 0))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseFromBoosts)
	assert_true(game_logic.do_cancel_tournelouse_transform_bonus_choice(player1))
	# Cancelling restores the exact choice that was offered, not an invented one.
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)
	assert_eq(game_logic.decision_info.choice.size(), 3)
	assert_eq(game_logic.decision_info.choice[0].get("effect_type"), StrikeEffects.SealTransformForPowerup)
	assert_eq(game_logic.decision_info.choice[1].get("effect_type"), StrikeEffects.SealTransformForArmorup)
	assert_eq(game_logic.decision_info.choice[2].get("effect_type"), StrikeEffects.Pass)
	assert_true(game_logic.do_choice(player1, 1))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseFromBoosts)
	assert_true(game_logic.do_choose_from_boosts(player1, [transform_id]))

	assert_true(player1.is_card_in_sealed(transform_id))

func test_death_omen_hit_effect_triggers_with_transform():
	position_players(player1, 3, player2, 6)
	add_transform(player1, "standard_normal_assault")
	var transform_id = player1.transforms[0].id

	execute_strike(player1, player2,
		"tournelouse_death_omen", "standard_normal_focus",
		false, false,
		[], [],
		true)

	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseSimultaneousEffect)
	assert_true(game_logic.do_choice(player1, 0))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)
	assert_eq(game_logic.decision_info.choice.size(), 2)
	assert_eq(game_logic.decision_info.choice[0].get("effect_type"), StrikeEffects.SealTransformForPowerup)
	assert_true(game_logic.do_choice(player1, 0))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseFromBoosts)
	assert_true(game_logic.do_choose_from_boosts(player1, [transform_id]))
	assert_true(player1.is_card_in_sealed(transform_id))

# ===== Bargeist Fang hit: repeat_effect_optionally + trailing draw 3 =====
# The "and" on a repeat means "once the whole chain is finished", so the draw 3
# must land after every transform, not after the first one.

func _bargeist_transform_choice_index(card_id : int) -> int:
	for i in range(game_logic.decision_info.choice.size()):
		if game_logic.decision_info.choice[i].get("transform_card_id", -1) == card_id:
			return i
	return -1

func _empty_hand(player):
	var discard_ids = []
	for card in player.hand:
		discard_ids.append(card.id)
	player.discard(discard_ids)

func test_bargeist_transforms_two_cards_then_draws_three_at_the_very_end():
	position_players(player1, 3, player2, 5)
	var gauge_ids = give_gauge(player1, 2)
	_empty_hand(player1)
	var first_id = give_player_specific_card(player1, "standard_normal_assault")
	var second_id = give_player_specific_card(player1, "tournelouse_netherstorm")
	var hand_size_before = player1.hand.size()

	execute_strike(player1, player2,
		"tournelouse_bargeist_fang", "standard_normal_grasp",
		false, false,
		[gauge_ids], [],
		true)

	# Repeat 1: opt in, then pick the first card.
	assert_true(game_logic.do_choice(player1, 0))
	assert_true(game_logic.do_choice(player1, _bargeist_transform_choice_index(first_id)))
	assert_true(player1.is_card_in_transforms(first_id))
	assert_eq(player1.hand.size(), hand_size_before - 1,
		"the draw must not have happened yet")

	# Repeat 2: opt in again, then pick the second card.
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)
	assert_true(game_logic.do_choice(player1, 0))
	assert_true(game_logic.do_choice(player1, _bargeist_transform_choice_index(second_id)))
	assert_true(player1.is_card_in_transforms(second_id))

	# Both cards left hand, then the chain ended and drew 3.
	assert_eq(player1.hand.size(), hand_size_before - 2 + 3)
	assert_eq(_bargeist_transform_choice_index(first_id), -1,
		"the repeat chain should be over")

func test_bargeist_stopping_after_one_transform_still_draws_three():
	position_players(player1, 3, player2, 5)
	var gauge_ids = give_gauge(player1, 2)
	var first_id = give_player_specific_card(player1, "standard_normal_assault")
	give_player_specific_card(player1, "tournelouse_netherstorm")
	var hand_size_before = player1.hand.size()

	execute_strike(player1, player2,
		"tournelouse_bargeist_fang", "standard_normal_grasp",
		false, false,
		[gauge_ids], [],
		true)

	assert_true(game_logic.do_choice(player1, 0))
	assert_true(game_logic.do_choice(player1, _bargeist_transform_choice_index(first_id)))

	# Decline the second repeat; the trailing draw still resolves.
	assert_eq(game_logic.decision_info.choice.size(), 2)
	assert_true(game_logic.do_choice(player1, 1))
	assert_eq(player1.hand.size(), hand_size_before - 1 + 3)

func test_bargeist_draws_three_with_nothing_transformable_in_hand():
	position_players(player1, 3, player2, 5)
	var gauge_ids = give_gauge(player1, 2)
	# Clear the hand so there is nothing that can be transformed.
	_empty_hand(player1)
	var hand_size_before = player1.hand.size()

	execute_strike(player1, player2,
		"tournelouse_bargeist_fang", "standard_normal_grasp",
		false, false,
		[gauge_ids], [],
		true)

	# No repeats are possible, so the chain ends immediately and just draws.
	assert_eq(player1.hand.size(), hand_size_before + 3)

func test_bargeist_only_offers_repeats_up_to_transformable_hand_count():
	position_players(player1, 3, player2, 5)
	var gauge_ids = give_gauge(player1, 2)
	_empty_hand(player1)
	var only_id = give_player_specific_card(player1, "standard_normal_assault")
	var hand_size_before = player1.hand.size()

	execute_strike(player1, player2,
		"tournelouse_bargeist_fang", "standard_normal_grasp",
		false, false,
		[gauge_ids], [],
		true)

	assert_true(game_logic.do_choice(player1, 0))
	assert_true(game_logic.do_choice(player1, _bargeist_transform_choice_index(only_id)))

	# The one transformable card is spent, so the chain ends and draws right away.
	assert_true(player1.is_card_in_transforms(only_id))
	assert_eq(player1.hand.size(), hand_size_before - 1 + 3)

# ===== Death Omen "you may Transform a card from your hand" =====
# Tournelouse's normals count as transforms until he exceeds, so the transform
# limitation has to accept them both in the engine and in the UI helper the
# client uses to decide which cards are selectable.

func test_death_omen_before_effect_can_transform_a_normal_from_hand():
	position_players(player1, 3, player2, 6)
	player1.life = 20
	player2.life = 30
	_empty_hand(player1)
	var death_omen_id = give_player_specific_card(player1, "tournelouse_death_omen")
	var normal_id = give_player_specific_card(player1, "standard_normal_grasp")
	var response_id = give_player_specific_card(player2, "standard_normal_focus")

	assert_true(game_logic.do_strike(player1, death_omen_id, false, -1))
	assert_true(game_logic.do_strike(player2, response_id, false, -1))

	# Focus's before effect resolves at the same time, so pick Death Omen first.
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseSimultaneousEffect)
	assert_true(game_logic.do_choice(player1, 0))

	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)
	assert_true(game_logic.do_choice(player1, 0))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_BoostNow)
	assert_eq(game_logic.decision_info.limitation, "transform")

	var wrapper = GameWrapper.new()
	wrapper.current_game = game_logic
	assert_true(wrapper.can_player_boost(player1.my_id, normal_id, ["hand"], "transform", false),
			"the UI should offer Tournelouse's normals when a transform is requested")
	wrapper.free()

	assert_true(game_logic.do_boost(player1, normal_id, []))
	assert_true(player1.is_card_in_transforms(normal_id))
	assert_eq(player1.transforms[0].definition["boost"]["boost_type"], "transform")

func test_death_omen_before_effect_offers_the_boost_when_behind_on_life():
	position_players(player1, 3, player2, 6)
	player1.life = 20
	player2.life = 30
	_empty_hand(player1)
	var death_omen_id = give_player_specific_card(player1, "tournelouse_death_omen")
	give_player_specific_card(player1, "standard_normal_grasp")
	var response_id = give_player_specific_card(player2, "standard_normal_focus")

	assert_true(game_logic.do_strike(player1, death_omen_id, false, -1))
	assert_true(game_logic.do_strike(player2, response_id, false, -1))

	assert_true(player1.can_boost_something(["hand"], "transform"),
			"a normal in hand should count as something transformable")

func test_exceeded_normals_are_not_treated_as_transforms():
	player1.exceed()
	_empty_hand(player1)
	var normal_id = give_player_specific_card(player1, "standard_normal_grasp")

	var wrapper = GameWrapper.new()
	wrapper.current_game = game_logic
	assert_false(wrapper.can_player_boost(player1.my_id, normal_id, ["hand"], "transform", false),
			"once exceeded, normals are just normals again")
	assert_false(wrapper.can_player_ex_transform(player1.my_id, normal_id))
	wrapper.free()

func test_ui_offers_ex_transform_for_a_single_normal_before_exceeding():
	_empty_hand(player1)
	var normal_id = give_player_specific_card(player1, "standard_normal_grasp")

	var wrapper = GameWrapper.new()
	wrapper.current_game = game_logic
	assert_true(game_logic.can_do_ex_transform(player1))
	assert_true(wrapper.can_player_ex_transform(player1.my_id, normal_id),
			"a lone normal can be transformed as a turn action before exceeding")

	assert_true(game_logic.do_ex_transform(player1, normal_id, -1))
	assert_true(player1.is_card_in_transforms(normal_id))

	var duplicate_id = give_player_specific_card(player1, "standard_normal_grasp")
	assert_false(wrapper.can_player_ex_transform(player1.my_id, duplicate_id),
			"a second copy of an already-transformed normal cannot be transformed")
	wrapper.free()

# ===== Netherstorm: seal transforms to pay its gauge cost =====

func test_netherstorm_can_pay_gauge_cost_by_sealing_transforms():
	position_players(player1, 3, player2, 5)
	var netherstorm_id = give_player_specific_card(player1, "tournelouse_netherstorm")
	var gauge_ids = give_gauge(player1, 3)
	add_transform(player1, "standard_normal_assault")
	add_transform(player1, "standard_normal_cross")
	var transform_id_1 = player1.transforms[0].id
	var transform_id_2 = player1.transforms[1].id
	var response_id = give_player_specific_card(player2, "standard_normal_grasp")

	assert_true(game_logic.do_strike(player1, netherstorm_id, false, -1))
	assert_true(game_logic.do_strike(player2, response_id, false, -1))

	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_PayStrikeCost_Required)
	assert_true(player1.tournelouse_may_seal_for_gauge,
			"Netherstorm should allow transforms to be sealed as gauge")
	assert_true(player1.can_pay_cost(0, 5),
			"3 gauge plus 2 transforms should cover the 5 gauge cost")

	var payment = gauge_ids.duplicate()
	payment.append(transform_id_1)
	payment.append(transform_id_2)
	assert_true(game_logic.do_pay_strike_cost(player1, payment, false))

	assert_eq(player1.transforms.size(), 0)
	assert_true(player1.is_card_in_sealed(transform_id_1))
	assert_true(player1.is_card_in_sealed(transform_id_2))
	assert_false(player1.tournelouse_may_seal_for_gauge)

func test_netherstorm_cannot_seal_transforms_for_gauge_outside_its_strike():
	add_transform(player1, "standard_normal_assault")
	assert_false(player1.tournelouse_may_seal_for_gauge)
	assert_false(player1.can_pay_cost(0, 1),
			"transforms only count as gauge while the seal effect is active")

# ===== Ouroboros as a turn action from the Netherstorm transform =====

func test_netherstorm_transform_exposes_a_named_bonus_action():
	add_transform(player1, "tournelouse_netherstorm")

	var bonus_actions = player1.get_bonus_actions()
	assert_eq(bonus_actions.size(), 1)
	# The UI reads this directly to label the button.
	assert_true(bonus_actions[0].has("text"),
			"action-timing boost effects need a 'text' label for the action button")
	assert_eq(bonus_actions[0]["text"], "Pay 1 Force: Swap Card in Hand with Transform")
	assert_eq(bonus_actions[0]["effect_type"], StrikeEffects.TournelouseOuroboros)
	assert_ne(bonus_actions[0].get("card_id", -1), -1)

func test_netherstorm_bonus_turn_action_runs_the_ouroboros_swap():
	add_transform(player1, "tournelouse_netherstorm")
	add_transform(player1, "standard_normal_assault")
	var transform_id = player1.transforms[1].id
	var hand_transform_id = give_player_specific_card(player1, "standard_normal_cross")
	var gauge_ids = give_gauge(player1, 1)

	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)
	assert_true(game_logic.do_bonus_turn_action(player1, 0))

	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ForceForEffect)
	assert_true(game_logic.do_force_for_effect(player1, [gauge_ids[0]], false))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseToDiscard)
	assert_true(game_logic.do_choose_to_discard(player1, [hand_transform_id]))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseFromBoosts)
	assert_true(game_logic.do_choose_from_boosts(player1, [transform_id]))

	assert_true(player1.is_card_in_transforms(hand_transform_id))
	assert_true(player1.is_card_in_hand(transform_id))
	assert_true(player1.is_card_in_discards(gauge_ids[0]))
	assert_false(game_logic.active_character_action)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)

func test_netherstorm_bonus_turn_action_can_be_cancelled_back_to_pick_action():
	add_transform(player1, "tournelouse_netherstorm")
	add_transform(player1, "standard_normal_assault")

	assert_true(game_logic.do_bonus_turn_action(player1, 0))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ForceForEffect)
	assert_true(game_logic.do_force_for_effect(player1, [], false, true, false))

	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)
	assert_false(game_logic.active_character_action)

func test_death_omen_seal_choice_cancel_restores_the_death_omen_choice():
	position_players(player1, 3, player2, 6)
	add_transform(player1, "standard_normal_assault")
	var transform_id = player1.transforms[0].id

	execute_strike(player1, player2,
		"tournelouse_death_omen", "standard_normal_focus",
		false, false,
		[], [],
		true)

	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseSimultaneousEffect)
	assert_true(game_logic.do_choice(player1, 0))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)
	assert_eq(game_logic.decision_info.choice.size(), 2)
	assert_true(game_logic.do_choice(player1, 0))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseFromBoosts)

	assert_true(game_logic.do_cancel_tournelouse_transform_bonus_choice(player1))
	# Death Omen only offers seal-for-power or pass, so cancelling must not
	# conjure up a seal-for-armor option.
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)
	assert_eq(game_logic.decision_info.choice.size(), 2)
	assert_eq(game_logic.decision_info.choice[0].get("effect_type"), StrikeEffects.SealTransformForPowerup)
	assert_eq(game_logic.decision_info.choice[0].get("amount"), 3)
	assert_eq(game_logic.decision_info.choice[1].get("effect_type"), StrikeEffects.Pass)

	# The restored choice is still fully playable.
	assert_true(game_logic.do_choice(player1, 0))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseFromBoosts)
	assert_true(game_logic.do_choose_from_boosts(player1, [transform_id]))
	assert_true(player1.is_card_in_sealed(transform_id))

func test_ouroboros_force_step_offers_the_same_hand_options_before_and_after_cancel():
	add_transform(player1, "tournelouse_netherstorm")
	add_transform(player1, "standard_normal_assault")
	var hand_transform_id = give_player_specific_card(player1, "standard_normal_cross")
	give_gauge(player1, 1)

	assert_true(game_logic.do_bonus_turn_action(player1, 0))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ForceForEffect)
	# The UI needs the legal hand options to validate a hand payment.
	var options_before = game_logic.decision_info.choice.duplicate()
	assert_true(options_before.has(hand_transform_id))

	assert_true(game_logic.do_force_for_effect(player1, [player1.gauge[0].id], false))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseToDiscard)
	assert_true(game_logic.do_cancel_tournelouse_ouroboros_hand_choice(player1))

	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ForceForEffect)
	assert_true(game_logic.decision_info.effect.get("tournelouse_ouroboros_force"))
	assert_eq(game_logic.decision_info.choice, options_before)
