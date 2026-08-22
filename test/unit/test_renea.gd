extends ExceedGutTest

func who_am_i():
	return "renea"

func before_each():
	default_game_setup("ryu")
	gut.p("ran setup", 2)

func _place_facedown_boost(player, def_id):
	var card_id = give_player_specific_card(player, def_id)
	var card = game_logic.get_card_database().get_card(card_id)
	player.remove_card_from_hand(card_id, true, false)
	card.definition["boost"]["facedown"] = true
	player.add_to_continuous_boosts(card)
	return card_id

# --- Ported tests (translated to English) ---

func test_do_boost_with_facedown_override_adds_hidden_continuous_boost():
	var boost_id = give_player_specific_card(player1, "renea_called_shot")

	assert_true(game_logic.do_boost(player1, boost_id, [], false, 0, [], true))
	assert_true(player1.is_card_in_continuous_boosts(boost_id))
	assert_true(game_logic.get_card_database().get_card(boost_id).definition["boost"].get("facedown", false))

	var events = game_logic.get_latest_events()
	var added_events = validate_has_event(events, Enums.EventType.EventType_Boost_Continuous_Added, player1, boost_id)
	assert_true(added_events[-1]["extra_info"])

func test_do_boost_with_faceup_override_keeps_boost_visible():
	var boost_id = give_player_specific_card(player1, "renea_called_shot")

	assert_true(game_logic.do_boost(player1, boost_id, [], false, 0, [], false))
	assert_true(player1.is_card_in_continuous_boosts(boost_id))
	assert_false(game_logic.get_card_database().get_card(boost_id).definition["boost"].get("facedown", false))

	var events = game_logic.get_latest_events()
	var added_events = validate_has_event(events, Enums.EventType.EventType_Boost_Continuous_Added, player1, boost_id)
	assert_eq(added_events[-1]["extra_info"], null)

func test_facedown_boost_order_ignores_grasp_without_now_effect():
	var grasp_id = give_player_specific_card(player1, "standard_normal_grasp")
	var flare_id = give_player_specific_card(player1, "renea_flare")

	assert_false(game_logic._renea_boost_has_now_effect(game_logic.get_card_database().get_card(grasp_id)))
	assert_true(game_logic._renea_boost_has_now_effect(game_logic.get_card_database().get_card(flare_id)))

func test_renea_ua_reveals_all_facedown_boosts_before_resolving_now_effects():
	var grasp_id = _place_facedown_boost(player1, "standard_normal_grasp")
	var flare_id = _place_facedown_boost(player1, "renea_flare")
	var anticipation_id = _place_facedown_boost(player1, "renea_anticipation")
	game_logic.get_latest_events()

	game_logic._renea_begin_pre_strike_reveal(player1)

	for card_id in [grasp_id, flare_id, anticipation_id]:
		assert_false(game_logic.get_card_database().get_card(card_id).definition["boost"].get("facedown", false))
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_RevealCard, player1, grasp_id)
	validate_has_event(events, Enums.EventType.EventType_RevealCard, player1, flare_id)
	validate_has_event(events, Enums.EventType.EventType_RevealCard, player1, anticipation_id)
	assert_eq(game_logic.decision_info.player, player1.my_id)
	# Only flare and anticipation have "now" effects, so 2 order choices are offered.
	assert_eq(game_logic.decision_info.choice.size(), 2)

# --- New tests ---

func test_facedown_continuous_boost_is_inactive_until_revealed():
	var boost_id = give_player_specific_card(player1, "renea_called_shot")
	assert_true(game_logic.do_boost(player1, boost_id, [], false, 0, [], true))

	# Face-down: Tactical Training's during_strike power/speed effects are skipped.
	var effects = game_logic.get_boost_effects_at_timing("during_strike", player1)
	assert_eq(effects.size(), 0)

	# Reveal it: the effects become active.
	game_logic.get_card_database().get_card(boost_id).definition["boost"].erase("facedown")
	var effects_after = game_logic.get_boost_effects_at_timing("during_strike", player1)
	assert_eq(effects_after.size(), 2)

func test_set_strike_reveal_fires_facedown_now_effect():
	var flare_id = _place_facedown_boost(player1, "renea_flare")
	assert_true(player1.is_card_in_continuous_boosts(flare_id))
	position_players(player1, 3, player2, 5)
	var attack_id = give_player_specific_card(player1, "standard_normal_cross")
	game_logic.get_latest_events()

	assert_true(game_logic.do_strike(player1, attack_id, false, -1))

	# On set_strike, Renea revealed the face-down Flare (Fakeout), returning it to
	# hand and drawing a card.
	assert_false(player1.is_card_in_continuous_boosts(flare_id))
	assert_true(player1.is_card_in_hand(flare_id))
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_RevealCard, player1, flare_id)

func test_flare_faceup_boost_returns_itself_to_hand_and_draws():
	# Flare is a continuous boost, but its Now effect bounces it back to hand
	# before it ever settles into the continuous boost zone.
	var flare_id = give_player_specific_card(player1, "renea_flare")
	var hand_before = player1.hand.size()
	var deck_before = player1.deck.size()

	assert_true(game_logic.do_boost(player1, flare_id, [], false, 0, [], false))

	assert_false(player1.is_card_in_continuous_boosts(flare_id))
	assert_true(player1.is_card_in_hand(flare_id))
	assert_false(player1.is_card_in_discards(flare_id))
	# One draw from the boost, one from the normal end-of-turn draw.
	assert_eq(player1.deck.size(), deck_before - 2)
	# Flare came back to hand plus both draws.
	assert_eq(player1.hand.size(), hand_before + 2)

func test_flare_facedown_reveal_returns_to_hand_and_draws_exactly_one():
	var flare_id = _place_facedown_boost(player1, "renea_flare")
	var hand_before = player1.hand.size()
	var deck_before = player1.deck.size()

	game_logic._renea_reveal_facedown(player1)

	assert_false(player1.is_card_in_continuous_boosts(flare_id))
	assert_true(player1.is_card_in_hand(flare_id))
	assert_eq(player1.deck.size(), deck_before - 1, "should draw exactly one card")
	assert_eq(player1.hand.size(), hand_before + 2, "Flare returns to hand plus the drawn card")

func test_defensive_ua_reveals_facedown_before_defender_responds():
	var flare_id = _place_facedown_boost(player1, "renea_flare")
	game_logic.active_turn_player = player2.my_id
	game_logic.game_state = Enums.GameState.GameState_PickAction
	position_players(player1, 3, player2, 5)
	var attack_id = give_player_specific_card(player2, "standard_normal_cross")
	game_logic.get_latest_events()

	assert_true(game_logic.do_strike(player2, attack_id, false, -1))

	# Renea's defensive UA revealed the face-down Flare before responding.
	assert_false(player1.is_card_in_continuous_boosts(flare_id))
	assert_true(player1.is_card_in_hand(flare_id))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_Strike_Opponent_Response)
	assert_eq(game_logic.decision_info.player, player1.my_id)

func test_briefcase_add_is_card_in_and_remove():
	var card_id = give_player_specific_card(player1, "renea_flare")
	var card = game_logic.get_card_database().get_card(card_id)
	player1.remove_card_from_hand(card_id, true, false)
	player1.add_to_briefcase(card)

	assert_true(player1.is_card_in_briefcase(card_id))
	assert_true(player1.is_card_in_set_aside(card_id))

	player1.remove_card_from_briefcase(card_id)
	assert_false(player1.is_card_in_briefcase(card_id))
	assert_false(player1.is_card_in_set_aside(card_id))

func test_briefcase_hit_pulls_boosted_card_from_bottom_of_opponent_discard():
	player1.exceeded = true
	var boosted_id = give_player_specific_card(player2, "standard_normal_grasp")
	player2.discard([boosted_id])
	assert_true(player2.is_card_in_discards(boosted_id))
	game_logic.get_latest_events()

	game_logic.handle_strike_effect(-1, {"effect_type": "renea_briefcase_hit"}, player1)

	assert_true(player1.is_card_in_briefcase(boosted_id))
	assert_false(player2.is_card_in_discards(boosted_id))

func test_on_exceed_moves_boosted_cards_from_opponent_discard_to_briefcase():
	var boosted_ids = []
	for def_id in ["standard_normal_grasp", "standard_normal_cross", "standard_normal_spike"]:
		var card_id = give_player_specific_card(player2, def_id)
		player2.discard([card_id])
		boosted_ids.append(card_id)
	game_logic.get_latest_events()

	game_logic.handle_strike_effect(-1, {"effect_type": "renea_on_exceed"}, player1)

	for card_id in boosted_ids:
		assert_true(player1.is_card_in_briefcase(card_id))
		assert_false(player2.is_card_in_discards(card_id))

func test_boosting_from_briefcase_while_exceeded_grants_bonus_action():
	player1.exceeded = true
	var boost_id = give_player_specific_card(player1, "renea_called_shot")
	var card = game_logic.get_card_database().get_card(boost_id)
	player1.remove_card_from_hand(boost_id, true, false)
	player1.add_to_briefcase(card)
	assert_true(player1.is_card_in_briefcase(boost_id))
	game_logic.get_latest_events()

	assert_true(game_logic.do_boost(player1, boost_id))
	assert_true(player1.is_card_in_continuous_boosts(boost_id))
	assert_false(player1.is_card_in_briefcase(boost_id))
	# Boosting from the briefcase while exceeded grants a bonus action, so the
	# turn does not pass to the opponent (the granted action is consumed
	# immediately, leaving bonus_actions back at 0 but the turn still ours).
	assert_true(player1.renea_boost_from_briefcase_used)
	assert_eq(game_logic.active_turn_player, player1.my_id)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)

func test_conspiracy_unearthed_now_effect_adds_opponent_card_to_their_gauge():
	var boost_id = give_player_specific_card(player1, "renea_neutralizer")
	var opp_hand_before = player2.hand.size()
	var opp_gauge_before = player2.gauge.size()
	var targeted_card_id = player2.hand[0].id

	assert_true(game_logic.do_boost(player1, boost_id, [], false, 0, [], false))
	# Conspiracy Unearthed reveals the opponent's hand and lets Renea choose a
	# card to add to the opponent's gauge.
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_eq(game_logic.decision_info.player, player1.my_id)
	assert_true(game_logic.do_choice(player1, 0))

	assert_eq(player2.gauge.size(), opp_gauge_before + 1)
	assert_eq(player2.hand.size(), opp_hand_before - 1)
	assert_true(player2.is_card_in_gauge(targeted_card_id))

# ===== FAQ RULING R1 =====
# "If Renea uses her Exceed action, what happens to any face-down Continuous
#  Boosts she has in play? A: They are flipped as well. Resolve their Now:
#  effects."
func test_faq_r1_exceed_action_flips_facedown_boosts_and_resolves_now():
	var flare_id = _place_facedown_boost(player1, "renea_flare")  # Now: return to hand + draw
	assert_true(player1.is_card_in_continuous_boosts(flare_id))
	assert_true(game_logic.get_card_database().get_card(flare_id).definition["boost"].get("facedown", false))
	var gauge_ids = give_gauge(player1, player1.get_exceed_cost())
	assert_true(game_logic.do_exceed(player1, gauge_ids))
	assert_true(player1.exceeded)
	# The face-down Fakeout was flipped and its Now effect resolved: it returned to
	# hand (leaving the continuous boost zone).
	assert_false(player1.is_card_in_continuous_boosts(flare_id),
			"exceeding flips face-down boosts and resolves their Now effects")
	assert_true(player1.is_card_in_hand(flare_id))

# ===== FAQ RULING R2 =====
# "When exactly does Renea flip cards for her regular ability? A: Before she sets
#  her card(s) for a Strike. If she is the attacker, it is the first thing that
#  happens. If she is the defender, it happens after the opponent has set their
#  attack."
func test_faq_r2_attacker_flips_when_setting_attack():
	var flare_id = _place_facedown_boost(player1, "renea_flare")  # Now: return to hand + draw
	position_players(player1, 3, player2, 5)
	var attack_id = give_player_specific_card(player1, "standard_normal_cross")
	game_logic.get_latest_events()
	# Renea is the attacker; the flip is the first thing that happens when she
	# sets her attack, before the opponent responds.
	assert_true(game_logic.do_strike(player1, attack_id, false, -1))
	assert_false(game_logic.get_card_database().get_card(flare_id).definition["boost"].get("facedown", false),
			"attacker Renea flips her face-down boosts as she sets her attack")
	assert_false(player1.is_card_in_continuous_boosts(flare_id))
	assert_true(player1.is_card_in_hand(flare_id))
	# The opponent has not yet responded to the strike.
	assert_eq(game_logic.game_state, Enums.GameState.GameState_Strike_Opponent_Response)

func test_faq_r2_defender_flips_after_opponent_sets_attack():
	var flare_id = _place_facedown_boost(player1, "renea_flare")
	game_logic.active_turn_player = player2.my_id
	game_logic.game_state = Enums.GameState.GameState_PickAction
	position_players(player1, 3, player2, 5)
	var attack_id = give_player_specific_card(player2, "standard_normal_cross")
	game_logic.get_latest_events()
	# The opponent sets their attack first; only then does defender Renea flip.
	assert_true(game_logic.do_strike(player2, attack_id, false, -1))
	assert_false(game_logic.get_card_database().get_card(flare_id).definition["boost"].get("facedown", false),
			"defender Renea flips her face-down boosts after the opponent sets their attack")
	assert_true(player1.is_card_in_hand(flare_id))
	# Now Renea (the defender) is being asked to set her response.
	assert_eq(game_logic.game_state, Enums.GameState.GameState_Strike_Opponent_Response)
	assert_eq(game_logic.decision_info.player, player1.my_id)

# --- Face-down placement restrictions (UI offers the choice only where legal) ---

func test_immediate_boost_cannot_be_forced_facedown():
	var boost_id = give_player_specific_card(player1, "standard_normal_dive")
	var card = game_logic.get_card_database().get_card(boost_id)
	assert_ne(card.definition["boost"]["boost_type"], "continuous",
			"this test needs a non-continuous boost")

	assert_true(game_logic.do_boost(player1, boost_id, [], false, 0, [], true))
	assert_false(card.definition["boost"].get("facedown", false),
			"only continuous boosts may be placed face-down")

func test_facedown_override_is_per_card_and_does_not_leak_to_copies():
	var first_id = give_player_specific_card(player1, "renea_called_shot")
	var second_id = give_player_specific_card(player1, "renea_called_shot")
	var card_db = game_logic.get_card_database()

	assert_true(game_logic.do_boost(player1, first_id, [], false, 0, [], true))
	assert_true(card_db.get_card(first_id).definition["boost"].get("facedown", false))
	assert_false(card_db.get_card(second_id).definition["boost"].get("facedown", false),
			"marking one copy face-down must not affect other copies")

func test_exceeded_renea_places_boosts_faceup():
	player1.exceeded = true
	var boost_id = give_player_specific_card(player1, "renea_called_shot")

	assert_true(game_logic.do_boost(player1, boost_id, [], false, 0, [], false))
	assert_false(game_logic.get_card_database().get_card(boost_id).definition["boost"].get("facedown", false))

func _add_continuous_boost(player, def_id):
	var boost_id = give_player_specific_card(player, def_id)
	var boost_card = game_logic.get_card_database().get_card(boost_id)
	player.add_to_continuous_boosts(boost_card)
	player.hand.erase(boost_card)
	return boost_id

func test_lethal_force_retreats_when_a_continuous_boost_is_in_play():
	# Lethal Force hit: push 2, then retreat 1 only if a continuous boost is in play.
	# Grasp is faster but whiffs at distance 2, so it cannot interfere.
	position_players(player1, 3, player2, 5)
	_add_continuous_boost(player1, "renea_anticipation")

	# [1] declines Lethal Force's transform-attack offer.
	execute_strike(player1, player2, "renea_lethal_force", "standard_normal_grasp",
		false, false, [1], [])

	# Opponent pushed 5 -> 7, then Renea retreats 3 -> 2.
	validate_positions(player1, 2, player2, 7)
	# Power 5 + 1 from Jujitsu (Anticipation's continuous boost) = 6.
	validate_life(player1, 30, player2, 24)

func test_lethal_force_does_not_retreat_without_a_continuous_boost():
	position_players(player1, 3, player2, 5)

	# [1] declines Lethal Force's transform-attack offer.
	execute_strike(player1, player2, "renea_lethal_force", "standard_normal_grasp",
		false, false, [1], [])

	# Opponent still pushed 5 -> 7, but Renea holds her ground.
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 25)

func test_neutralizer_hit_makes_exceeded_opponent_discard_two_gauge():
	position_players(player1, 4, player2, 5)
	player2.exceeded = true
	give_gauge(player2, 3)
	var gauge_before = player2.gauge.size()

	give_gauge(player1, 2)
	var attack_id = give_player_specific_card(player1, "renea_neutralizer")
	assert_true(game_logic.do_strike(player1, attack_id, false, -1))
	var response_id = give_player_specific_card(player2, "standard_normal_focus")
	assert_true(game_logic.do_strike(player2, response_id, false, -1))

	# Ryu declines to spend gauge for a critical.
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_GaugeForEffect)
	assert_true(game_logic.do_gauge_for_effect(player2, []))
	# Neutralizer is an ultra; pay its gauge cost.
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_PayStrikeCost_Required)
	assert_true(game_logic.do_pay_strike_cost(player1, get_cards_from_gauge(player1, 2), false))

	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseFromDiscard)
	assert_eq(game_logic.decision_info.player, player2.my_id)
	assert_eq(game_logic.decision_info.amount, 2)
	var to_discard = [player2.gauge[0].id, player2.gauge[1].id]
	assert_true(game_logic.do_choose_from_discard(player2, to_discard))

	assert_eq(player2.gauge.size(), gauge_before - 2)

func test_neutralizer_does_not_touch_gauge_when_opponent_is_not_exceeded():
	position_players(player1, 4, player2, 5)
	give_gauge(player2, 3)
	var gauge_before = player2.gauge.size()

	give_gauge(player1, 2)
	var attack_id = give_player_specific_card(player1, "renea_neutralizer")
	assert_true(game_logic.do_strike(player1, attack_id, false, -1))
	var response_id = give_player_specific_card(player2, "standard_normal_focus")
	assert_true(game_logic.do_strike(player2, response_id, false, -1))

	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_GaugeForEffect)
	assert_true(game_logic.do_gauge_for_effect(player2, []))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_PayStrikeCost_Required)
	assert_true(game_logic.do_pay_strike_cost(player1, get_cards_from_gauge(player1, 2), false))

	assert_ne(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseFromDiscard)
	assert_eq(player2.gauge.size(), gauge_before)
