extends ExceedGutTest

func who_am_i():
	return "umina"

func _prepare_terror_whispers_transform() -> void:
	var tf1 = give_player_specific_card(player1, "umina_terror_whispers")
	var tf2 = give_player_specific_card(player1, "umina_terror_whispers")
	assert_true(game_logic.do_ex_transform(player1, tf1, tf2))
	# Transform action ends the current turn. Advance opponent turn to get back to p1.
	advance_turn(player2)

func _find_twh_action_index() -> int:
	var actions = player1.get_bonus_actions()
	for i in range(actions.size()):
		if "wild swing" in actions[i].get("text", ""):
			return i
	return -1

func test_terror_whispers_action_requires_2_gauge():
	_prepare_terror_whispers_transform()
	var action_idx = _find_twh_action_index()
	assert_ne(action_idx, -1)
	assert_eq(player1.get_available_gauge(), 0)
	assert_false(game_logic.do_bonus_turn_action(player1, action_idx))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)

func test_terror_whispers_action_pay_then_force_opponent_wild_swing():
	_prepare_terror_whispers_transform()
	var action_idx = _find_twh_action_index()
	assert_ne(action_idx, -1)

	var gauge_ids = give_gauge(player1, 2)
	assert_true(game_logic.do_bonus_turn_action(player1, action_idx))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_GaugeForEffect)
	assert_eq(game_logic.decision_info.effect.get("gauge_max", -1), 2)
	assert_true(game_logic.do_gauge_for_effect(player1, gauge_ids))

	assert_eq(game_logic.game_state, Enums.GameState.GameState_WaitForStrike)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_StrikeNow)

	# Stabilize opponent wild swing to a known normal card to avoid cost-side branches.
	set_player_topdeck(player2, "standard_normal_assault")
	var strike_id = give_player_specific_card(player1, "standard_normal_assault")
	assert_true(game_logic.do_strike(player1, strike_id, false, -1))
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_Strike_ForceWildSwing, player1)
	assert_false(player1.opponent_next_strike_forced_wild_swing)

func test_terror_whispers_action_opponent_really_wild_swings():
	_prepare_terror_whispers_transform()
	var action_idx = _find_twh_action_index()
	assert_ne(action_idx, -1)
	position_players(player1, 4, player2, 5)

	var gauge_ids = give_gauge(player1, 2)
	assert_true(game_logic.do_bonus_turn_action(player1, action_idx))
	assert_true(game_logic.do_gauge_for_effect(player1, gauge_ids))

	var wild_id = set_player_topdeck(player2, "standard_normal_cross")
	var held_id = give_player_specific_card(player2, "standard_normal_grasp")
	var strike_id = give_player_specific_card(player1, "standard_normal_assault")
	assert_true(game_logic.do_strike(player1, strike_id, false, -1))

	# The opponent gets no say: their attack is the top card of their deck.
	assert_false(player2.is_card_in_deck(wild_id),
		"the opponent should have wild swung with their top card")
	assert_true(player2.is_card_in_hand(held_id),
		"the opponent's hand should be untouched by the forced wild swing")

func test_terror_whispers_action_cancel_gauge_payment_returns_without_strike():
	_prepare_terror_whispers_transform()
	var action_idx = _find_twh_action_index()
	assert_ne(action_idx, -1)

	give_gauge(player1, 2)
	assert_eq(game_logic.active_turn_player, player1.my_id)
	assert_true(game_logic.do_bonus_turn_action(player1, action_idx))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_GaugeForEffect)

	# Cancel/Pass from the gauge payment step.
	assert_true(game_logic.do_gauge_for_effect(player1, []))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_None)
	assert_eq(game_logic.active_turn_player, player1.my_id)


# ===== Dark Thoughts hit: optional Dreamlands placement (2026-08-06) =====

func has_def_in_zone(_player, def_id, zone):
	for card in zone:
		if card.definition.get("id", "") == def_id:
			return true
	return false

func test_dark_thoughts_choose_to_place():
	position_players(player1, 3, player2, 5)  # distance 2, Dark Thoughts R2-5 hits
	player2.hand.clear()
	give_player_specific_card(player2, "standard_normal_spike")
	# Dark Thoughts R2-5 P6 S2 vs Grasp(R1) at dist2 -> Grasp misses.
	# hit: opponent discards the only card (Spike) -> choice:
	#   idx0 = put into Dreamlands, idx1 = don't put.
	# Dark Thoughts is a transform (Spiraling Descent) so a transform offer
	# follows the hit choice: pass (idx1).
	execute_strike(player1, player2, "umina_dark_thoughts", "standard_normal_grasp",
		false, false,
		[0, 1],  # hit choice: put into Dreamlands; transform offer: pass
		[])
	assert_true(has_def_in_zone(player1, "standard_normal_spike", player1.set_aside_cards),
		"Chosen card should be in Dreamlands")
	assert_false(has_def_in_zone(player2, "standard_normal_spike", player2.discards),
		"Chosen card should be removed from opponent discard")

func test_dark_thoughts_choose_not_to_place():
	position_players(player1, 3, player2, 5)
	player2.hand.clear()
	give_player_specific_card(player2, "standard_normal_spike")
	execute_strike(player1, player2, "umina_dark_thoughts", "standard_normal_grasp",
		false, false,
		[1, 1],  # hit choice: don't put (Pass); transform offer: pass
		[])
	assert_eq(player1.set_aside_cards.size(), 0,
		"Not chosen: Dreamlands must stay empty")
	assert_true(has_def_in_zone(player2, "standard_normal_spike", player2.discards),
		"Not chosen: card should remain in opponent discard")

func test_dark_thoughts_cannot_place_shadow_chorus():
	# Opponent is Umina too; the discarded card is a Shadow Chorus, which can
	# never enter Dreamlands. The choice must only offer "don't put" (idx0).
	default_game_setup("umina")
	position_players(player1, 3, player2, 5)
	player2.hand.clear()
	give_player_specific_card(player2, "umina_shadow_chorus")
	execute_strike(player1, player2, "umina_dark_thoughts", "standard_normal_grasp",
		false, false,
		[0, 1],  # hit choice: only Pass available; transform offer: pass
		[])
	assert_eq(player1.set_aside_cards.size(), 0,
		"Shadow Chorus must not be placed into Dreamlands")
	assert_true(has_def_in_zone(player2, "umina_shadow_chorus", player2.discards),
		"Shadow Chorus should remain in opponent discard")

func test_reading_named_sweep_ignores_dreamlands_and_reveals_hand():
	position_players(player1, 3, player2, 6)
	advance_turn(player1)

	player1.discard_hand()
	var dreamlands_sweep_id = give_player_specific_card(player1, "standard_normal_sweep")
	var dreamlands_sweep_card = game_logic.get_card_database().get_card(dreamlands_sweep_id)
	var shadow_chorus_id = give_player_specific_card(player1, "umina_shadow_chorus")
	player1.remove_card_from_hand(dreamlands_sweep_id, false, false)
	player1.add_to_set_aside(dreamlands_sweep_card)

	assert_true(player1.is_card_in_set_aside(dreamlands_sweep_id))
	assert_false(has_def_in_zone(player1, "standard_normal_sweep", player1.hand))
	assert_true(has_def_in_zone(player1, "umina_shadow_chorus", player1.hand))

	var reading_id = give_player_specific_card(player2, "standard_normal_focus")
	var assault_id = give_player_specific_card(player2, "standard_normal_assault")
	assert_true(game_logic.do_boost(player2, reading_id))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ReadingNormal)
	assert_true(game_logic.do_boost_name_card_choice_effect(player2, dreamlands_sweep_id))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_WaitForStrike)

	assert_true(game_logic.do_strike(player2, assault_id, false, -1))
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_RevealHand, player1)
	validate_not_has_event(events, Enums.EventType.EventType_Strike_EffectChoice, player1)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_Strike_Opponent_Response)
	assert_eq(game_logic.decision_info.player, player1.my_id)
	assert_true(game_logic.do_strike(player1, shadow_chorus_id, false, -1))


# ===== Official FAQ rulings =====

func _put_card_in_dreamlands(player, def_id):
	var card_id = give_player_specific_card(player, def_id)
	var card = game_logic.get_card_database().get_card(card_id)
	player.remove_card_from_hand(card_id, false, false)
	player.add_to_set_aside(card)
	return card_id

func _add_dream_telling_boost(player):
	var boost_id = give_player_specific_card(player, "umina_unknown_khadath")
	var boost_card = game_logic.get_card_database().get_card(boost_id)
	player.remove_card_from_hand(boost_id, false, false)
	player.add_to_continuous_boosts(boost_card)
	game_logic.get_latest_events()
	return boost_id

func test_faq_u1_spiraling_descent_boost_ban_requires_face_up_dreamlands():
	add_transform(player1, "umina_dark_thoughts")
	_put_card_in_dreamlands(player1, "standard_normal_spike")
	advance_turn(player1)

	var boost_id = give_player_specific_card(player2, "standard_normal_spike")
	assert_false(game_logic.do_boost(player2, boost_id),
		"Face-up Dreamlands should ban boosting a matching card")
	assert_true(player2.is_card_in_hand(boost_id))

	player1.umina_dreamlands_facedown = true
	assert_true(game_logic.do_boost(player2, boost_id),
		"Face-down Dreamlands should not ban boosting a matching card")

func test_faq_u2_dreamlands_card_cannot_be_used_for_ex_attack():
	var dreamlands_id = _put_card_in_dreamlands(player1, "standard_normal_spike")
	var ex_copy_id = give_player_specific_card(player1, "standard_normal_spike")

	assert_false(game_logic.do_strike(player1, dreamlands_id, false, ex_copy_id),
		"A physical Dreamlands card cannot be paired with a hand copy for EX")
	assert_true(player1.is_card_in_set_aside(dreamlands_id))
	assert_true(player1.is_card_in_hand(ex_copy_id))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)

func test_faq_u3_ex_shadow_chorus_copies_dreamlands_card_as_ex():
	position_players(player1, 3, player2, 5)
	_put_card_in_dreamlands(player1, "standard_normal_sweep")

	execute_strike(player1, player2, "umina_shadow_chorus", "standard_normal_focus",
		true, false,
		[], [],
		false,
		"umina_shadow_chorus")

	validate_life(player1, 27, player2, 25)
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_RevealCard, player1)
	validate_has_event(events, Enums.EventType.EventType_Strike_TookDamage, player2, 5)

func test_faq_u4_dream_telling_gets_no_power_when_striking_with_dreamlands_card():
	position_players(player1, 3, player2, 5)
	_add_dream_telling_boost(player1)
	var dreamlands_id = _put_card_in_dreamlands(player1, "standard_normal_sweep")

	execute_strike(player1, player2, dreamlands_id, "standard_normal_focus",
		false, false,
		[], [],
		true)

	var events = game_logic.get_latest_events()
	validate_not_has_event(events, Enums.EventType.EventType_Strike_PowerUp, player1, 5)
	validate_has_event(events, Enums.EventType.EventType_Strike_TookDamage, player2, 4)
	validate_life(player1, 26, player2, 26)

func test_faq_u4_dream_telling_gets_power_when_dreamlands_card_remains():
	position_players(player1, 3, player2, 5)
	_add_dream_telling_boost(player1)
	_put_card_in_dreamlands(player1, "standard_normal_sweep")

	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_focus",
		false, false,
		[], [],
		true)

	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_Strike_PowerUp, player1, 5)
	validate_has_event(events, Enums.EventType.EventType_Strike_TookDamage, player2, 7)
	validate_life(player1, 30, player2, 23)

func test_faq_u5_dreamlands_stun_immunity_applies_to_copy_of_card():
	position_players(player1, 3, player2, 6)
	_put_card_in_dreamlands(player1, "standard_normal_spike")

	execute_strike(player1, player2, "standard_normal_spike", "standard_normal_dive",
		false, false,
		[], [])

	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_Strike_Stun_Immunity, player1)
	validate_not_has_event(events, Enums.EventType.EventType_Strike_Stun, player1)
	validate_life(player1, 25, player2, 30)
