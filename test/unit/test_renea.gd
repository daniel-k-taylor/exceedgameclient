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

	# On set_strike, Renea revealed the face-down Flare (Pakout), returning it to
	# hand and drawing a card.
	assert_false(player1.is_card_in_continuous_boosts(flare_id))
	assert_true(player1.is_card_in_hand(flare_id))
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_RevealCard, player1, flare_id)

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
	# The face-down Pakout was flipped and its Now effect resolved: it returned to
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
