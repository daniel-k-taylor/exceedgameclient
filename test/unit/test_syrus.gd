extends ExceedGutTest

func who_am_i():
	return "syrus"

func before_each():
	default_game_setup("ryu")
	gut.p("ran setup", 2)

func test_starting_life():
	assert_eq(player1.life, 30)
	assert_eq(player2.life, 30)

func test_exceed_cost_default():
	assert_eq(player1.get_exceed_cost(), 6)

func test_exceed_cost_with_one_transform():
	add_transform(player1, "syrus_tidal_whirl")
	assert_eq(player1.get_exceed_cost(), 4)

func test_exceed_cost_with_two_transforms():
	add_transform(player1, "syrus_tidal_whirl")
	add_transform(player1, "syrus_aria_of_the_winds")
	assert_eq(player1.get_exceed_cost(), 2)

func test_tidal_whirl_card_loaded():
	var card = CardDataManager.get_card("syrus_tidal_whirl")
	assert_not_null(card)
	if card:
		assert_eq(card['display_name'], "Tidal Whirl")
		assert_eq(card['power'], 3)
		assert_eq(card['speed'], 6)

func test_symphony_of_the_deep_card_loaded():
	var card = CardDataManager.get_card("syrus_symphony_of_the_deep")
	assert_not_null(card)
	if card:
		assert_eq(card['display_name'], "Symphony of the Deep")
		assert_eq(card['gauge_cost'], 2)

func test_dredge_fury_card_loaded():
	var card = CardDataManager.get_card("syrus_dredge_fury")
	assert_not_null(card)
	if card:
		assert_eq(card['display_name'], "Dredge Fury")
		assert_eq(card['gauge_cost'], 1)

func test_treasure_hunter_hit_discards_opponent_gauge_without_returning_it():
	position_players(player1, 3, player2, 5)
	var discarded_gauge_id = give_gauge(player2, 1)[0]

	execute_strike(player1, player2, "syrus_treasure_hunter", "standard_normal_focus",
		false, false, [], [[discarded_gauge_id]])

	assert_false(player2.is_card_in_gauge(discarded_gauge_id))
	assert_true(player2.is_card_in_discards(discarded_gauge_id))

func test_treasure_hunter_hit_adds_top_of_own_discard_to_gauge():
	# Hit: Push 3 and the opponent discards a card from their gauge. Add the top
	# card of your discard pile to your gauge.
	position_players(player1, 3, player2, 5)
	var discarded_gauge_id = give_gauge(player2, 1)[0]
	var top_discard_id = give_player_specific_card(player1, "standard_normal_cross")
	player1.discard([top_discard_id])
	assert_true(player1.is_card_in_discards(top_discard_id))

	execute_strike(player1, player2, "syrus_treasure_hunter", "standard_normal_focus",
		false, false, [], [[discarded_gauge_id]])

	assert_true(player1.is_card_in_gauge(top_discard_id))
	assert_false(player1.is_card_in_discards(top_discard_id))

func test_exceed_moves_continuous_boosts_to_gauge():
	var test_card = player1.deck[0]
	var test_card_id = test_card.id
	player1.add_to_continuous_boosts(test_card)
	player1.deck.remove_at(0)
	assert_eq(player1.continuous_boosts.size(), 1)

	var gauge_ids = give_gauge(player1, 6)
	assert_true(game_logic.do_exceed(player1, gauge_ids), "Syrus should be able to exceed with 6 gauge")
	assert_eq(player1.continuous_boosts.size(), 0, "Continuous boosts should be moved to gauge after exceed")

	var found_in_gauge = false
	for gc in player1.gauge:
		if gc.id == test_card_id:
			found_in_gauge = true
			break
	assert_true(found_in_gauge, "The continuous boost card should be in gauge after exceed")

func test_instant_boost_replays_as_facedown_continuous_boost():
	position_players(player1, 3, player2, 6)
	var boost_id = give_player_specific_card(player1, "syrus_tidal_whirl")

	assert_true(game_logic.do_boost(player1, boost_id, []))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)
	assert_true(game_logic.do_choice(player1, 0))

	var boost_card = game_logic.get_card_database().get_card(boost_id)
	assert_true(player1.is_card_in_continuous_boosts(boost_id))
	assert_false(player1.is_card_in_discards(boost_id))
	assert_true(boost_card.definition.has("replaced_boost"))
	assert_eq(boost_card.definition["replaced_boost"]["boost_type"], "immediate")
	assert_eq(boost_card.definition["boost"]["boost_type"], "continuous")
	assert_true(boost_card.definition["boost"].get("facedown", false))
	assert_eq(boost_card.definition["boost"]["effects"][0]["effect_type"], "add_to_gauge_immediately")
	validate_positions(player1, 4, player2, 6)

func test_exceeded_instant_boost_replacement_moves_and_adds_power():
	position_players(player1, 3, player2, 6)
	player1.exceed()
	var boost_id = give_player_specific_card(player1, "syrus_tidal_whirl")

	assert_true(game_logic.do_boost(player1, boost_id, []))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)
	assert_true(game_logic.do_choice(player1, 0))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)
	assert_true(game_logic.do_choice(player1, 0))

	var boost_card = game_logic.get_card_database().get_card(boost_id)
	assert_true(player1.is_card_in_continuous_boosts(boost_id))
	assert_eq(boost_card.definition["boost"]["effects"][0]["effect_type"], "choice")
	assert_eq(boost_card.definition["boost"]["effects"][1]["effect_type"], "powerup")
	validate_positions(player1, 5, player2, 6)

	advance_turn(player2)
	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_cross",
		false, false, [0], [])
	validate_life(player1, 30, player2, 26)

func test_dredge_fury_spent_gauge_choice_returns_one_card_to_hand():
	position_players(player1, 3, player2, 7)
	var gauge_ids = give_gauge(player1, 4)
	var cost_id = gauge_ids[0]
	var spent_ids = [gauge_ids[1], gauge_ids[2], gauge_ids[3]]
	var kept_id = spent_ids[1]
	var kept_def_id = game_logic.get_card_database().get_card(kept_id).definition["id"]

	execute_strike(player1, player2, "syrus_dredge_fury", "standard_normal_focus",
		false, false, [[cost_id], spent_ids, 1], [])

	assert_true(player1.is_card_in_hand(kept_id))
	assert_true(kept_def_id in player1.get_public_hand_info()["known"])
	assert_false(player1.is_card_in_discards(kept_id))
	assert_true(player1.is_card_in_discards(spent_ids[0]))
	assert_true(player1.is_card_in_discards(spent_ids[2]))
	validate_life(player1, 30, player2, 24)

func test_dredge_fury_zero_gauge_confirms_without_keep_choice():
	# gauge_for_effect supports min_gauge=0, so choosing 0 should confirm
	# and skip both keep-choice and per-gauge powerup.
	position_players(player1, 3, player2, 7)
	var gauge_ids = give_gauge(player1, 4)
	var cost_id = gauge_ids[0]

	execute_strike(player1, player2, "syrus_dredge_fury", "standard_normal_focus",
		false, false, [[cost_id], []], [])

	assert_false(player1.is_card_in_hand(cost_id))
	assert_true(player1.is_card_in_discards(cost_id))
	# Focus has armor 2, so Dredge Fury base power 2 deals 0 with no spent gauge.
	validate_life(player1, 30, player2, 30)

func test_silver_shadow_uses_move_to_space_with_range_3_limit():
	position_players(player1, 3, player2, 5)
	var boost_id = give_player_specific_card(player1, "syrus_symphony_of_the_deep")

	assert_true(game_logic.do_boost(player1, boost_id, []))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseArenaLocationForEffect)
	assert_eq(game_logic.decision_info.effect_type, StrikeEffects.MoveToSpace)
	assert_eq(game_logic.decision_info.limitation, [2, 8])
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(8)))
	validate_positions(player1, 8, player2, 5)

func test_talon_only_boosts_immediate_from_gauge_and_seals_before_syrus_replay():
	position_players(player1, 3, player2, 6)
	add_transform(player1, "syrus_albatross_talon", true)

	var continuous_boost_id = give_player_specific_card(player1, "standard_normal_grasp")
	player1.move_card_from_hand_to_gauge(continuous_boost_id)
	assert_false(player1.can_boost_something(["gauge"], ""))

	var immediate_boost_id = give_player_specific_card(player1, "syrus_tidal_whirl")
	player1.move_card_from_hand_to_gauge(immediate_boost_id)
	assert_true(player1.can_boost_something(["gauge"], ""))
	assert_true(game_logic.do_boost(player1, immediate_boost_id, []))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)
	assert_true(game_logic.do_choice(player1, 0))

	var boosted_card = game_logic.get_card_database().get_card(immediate_boost_id)
	assert_true(player1.is_card_in_sealed(immediate_boost_id))
	assert_false(player1.is_card_in_continuous_boosts(immediate_boost_id))
	assert_false(player1.is_card_in_discards(immediate_boost_id))
	assert_false(boosted_card.definition.has("replaced_boost"))
	validate_positions(player1, 4, player2, 6)

func test_talon_rejects_boosting_a_continuous_boost_out_of_gauge():
	position_players(player1, 3, player2, 6)
	add_transform(player1, "syrus_albatross_talon", true)
	assert_true(player1.can_boost_from_gauge)
	assert_eq(player1.boost_from_gauge_limitation, "immediate")

	# Grasp is a continuous boost, so it is not playable out of gauge.
	var continuous_boost_id = give_player_specific_card(player1, "standard_normal_grasp")
	player1.move_card_from_hand_to_gauge(continuous_boost_id)

	var wrapper = GameWrapper.new()
	wrapper.current_game = game_logic
	assert_false(wrapper.can_player_boost(player1.my_id, continuous_boost_id, ["gauge"], "", false),
			"the UI should not offer a continuous boost from gauge")
	wrapper.free()
	assert_false(game_logic.do_boost(player1, continuous_boost_id, []),
			"the game should reject boosting a continuous boost out of gauge")

	# Nothing happened: the card stays in gauge and it is still the player's turn.
	assert_true(player1.is_card_in_gauge(continuous_boost_id))
	assert_false(player1.is_card_in_continuous_boosts(continuous_boost_id))
	assert_false(player1.is_card_in_sealed(continuous_boost_id))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)
	assert_eq(game_logic.get_active_player(), player1.my_id)

func test_boosting_from_gauge_is_rejected_without_memories_from_the_deep():
	position_players(player1, 3, player2, 6)
	assert_false(player1.can_boost_from_gauge)

	var immediate_boost_id = give_player_specific_card(player1, "syrus_tidal_whirl")
	player1.move_card_from_hand_to_gauge(immediate_boost_id)

	assert_false(game_logic.do_boost(player1, immediate_boost_id, []))
	assert_true(player1.is_card_in_gauge(immediate_boost_id))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)

func test_talon_still_allows_the_same_continuous_boost_from_hand():
	# The restriction is only on the gauge zone; hand boosts are unaffected.
	position_players(player1, 3, player2, 6)
	add_transform(player1, "syrus_albatross_talon", true)

	var continuous_boost_id = give_player_specific_card(player1, "standard_normal_grasp")
	assert_true(game_logic.do_boost(player1, continuous_boost_id, []))
	assert_true(player1.is_card_in_continuous_boosts(continuous_boost_id))
	assert_false(player1.is_card_in_sealed(continuous_boost_id),
			"boosts played from hand are not sealed by Memories from the Deep")

# ===== FAQ RULING S1 =====
# "If Syrus has Memories From the Deep in play (may play Instant Boosts from
#  Gauge - then Seal them) can he keep those Boosts in play as face-down Boosts
#  by resolving his Character Ability first? A: No. The boosts will be Sealed
#  even if they were turned face-down."
# Albatross Talon's transform IS "Memories from the Deep". Syrus's character
# ability would normally re-play an immediate boost as a face-down continuous
# boost, but the Memories seal takes priority.
func test_faq_s1_memories_from_the_deep_seals_boost_despite_character_ability():
	position_players(player1, 3, player2, 6)
	add_transform(player1, "syrus_albatross_talon", true)  # transform: Memories from the Deep

	var immediate_boost_id = give_player_specific_card(player1, "syrus_tidal_whirl")
	player1.move_card_from_hand_to_gauge(immediate_boost_id)
	assert_true(player1.can_boost_something(["gauge"], ""))

	assert_true(game_logic.do_boost(player1, immediate_boost_id, []))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)
	assert_true(game_logic.do_choice(player1, 0))

	# The boost is Sealed, NOT kept in play as a face-down continuous boost.
	var boosted_card = game_logic.get_card_database().get_card(immediate_boost_id)
	assert_true(player1.is_card_in_sealed(immediate_boost_id),
			"Memories from the Deep seals the boost even though the character ability turned it face-down")
	assert_false(player1.is_card_in_continuous_boosts(immediate_boost_id),
			"the boost cannot be kept in play face-down instead of sealing it")
	assert_false(player1.is_card_in_discards(immediate_boost_id))
	assert_false(boosted_card.definition.has("replaced_boost"))

func test_siren_call_pulls_stunned_opponent_to_range_2():
	position_players(player1, 1, player2, 6)

	# Grasp is faster but whiffs at range 5, so Siren Call hits a 0-guard card and stuns it.
	# [1] declines Siren Call's transform-attack offer.
	execute_strike(player1, player2, "syrus_siren_call", "standard_normal_grasp", false, false, [1], [])

	# Stunned, so the opponent is pulled to exactly range 2.
	validate_positions(player1, 1, player2, 3)

func test_siren_call_does_not_pull_when_opponent_is_not_stunned():
	position_players(player1, 1, player2, 6)

	# Focus has 2 armor and 5 guard, so 4 power leaves only 2 damage and no stun.
	execute_strike(player1, player2, "syrus_siren_call", "standard_normal_focus", false, false, [1], [])

	validate_positions(player1, 1, player2, 6)

func test_treasure_hunter_boost_moves_a_chosen_card_from_hand_to_gauge():
	var boost_id = give_player_specific_card(player1, "syrus_treasure_hunter")
	var gauge_target = give_player_specific_card(player1, "standard_normal_cross")
	var gauge_before = player1.gauge.size()
	var hand_before = player1.hand.size()

	assert_true(game_logic.do_boost(player1, boost_id, []))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_CardFromHandToGauge)
	assert_true(game_logic.do_relocate_card_from_hand(player1, [gauge_target]))

	assert_eq(player1.gauge.size(), gauge_before + 1)
	assert_true(player1.is_card_in_gauge(gauge_target))
	assert_false(player1.is_card_in_hand(gauge_target))
	assert_false(player1.is_card_in_hand(boost_id))
	# Boosting ends the turn, so the two cards that left hand are offset by the
	# end-of-turn draw.
	assert_eq(player1.hand.size(), hand_before - 1)
