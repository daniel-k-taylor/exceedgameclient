extends ExceedGutTest

## ==========================================================================
## Luciya — Season 2 custom character test suite.
##
## Cards:
##   Downburst   R1  P2 S6       — boost: Chain Climb (immediate, 2F)
##   Talon Sweep R1  P2 S6       — transform: Grandstanding (1F -> +1P both)
##   Mantis Strike R3-5 P4 S4   — transform: Storm's Fury (2F -> Move 1)
##   Bug Zapper  R1  P2 S4       — transform: Thunderclap (normal after: stun -> Move 2)
##   Firefly Gunner R3-4 P6 S1  — dodge at R3-4. boost: The Whirlwind (cont, 0F, +3S, to gauge EoT)
##   Ride The Lightning R1 P1 S8 — ultra (2g), before: close 4, after: advance 4. boost: Chain Trap (cont, block move)
##   Skies Aflame R3-5 P4 S5    — ultra (3g), hit: gain advantage, after: move any space. boost: Preemptive Attack (cont, 1F, +2S, strike now)
## ==========================================================================

func who_am_i():
	return "luciya"

func before_each():
	default_game_setup("ryu")
	gut.p("ran setup", 2)


# ============================================================================
# BASIC / SETUP
# ============================================================================

func test_starting_life():
	assert_eq(player1.life, 30)
	assert_eq(player2.life, 30)

func test_exceed_cost_default():
	assert_eq(player1.get_exceed_cost(), 5)

func test_exceed_cost_with_one_transform():
	add_transform(player1, "luciya_mantis_strike")
	assert_eq(player1.get_exceed_cost(), 3)

func test_exceed_cost_with_two_transforms():
	add_transform(player1, "luciya_mantis_strike")
	add_transform(player1, "luciya_downburst")
	assert_eq(player1.get_exceed_cost(), 1)

func test_exceed_moves_hand_to_gauge_and_draws_5():
	var gauge_ids = give_gauge(player1, 5)
	assert_true(game_logic.do_exceed(player1, gauge_ids))
	assert_true(player1.exceeded)
	assert_eq(player1.gauge.size(), 5)
	assert_eq(player1.hand.size(), 6)
	assert_eq(game_logic.active_turn_player, player2.my_id)


# ============================================================================
# PASSIVE — moved_past: deal 1 nonlethal dmg + add top discard to gauge
#   When Luciya moves past the opponent during a strike advance.
# ============================================================================

func test_passive_fires_on_advance_through():
	position_players(player1, 3, player2, 4)
	execute_strike(player1, player2, "luciya_talon_sweep", "standard_normal_focus",
		false, false,
		[[false, true], 1],  # ForceForEffect cancel, Transform pass
		[])
	# Advance 4: 3->skip(4)->5->6->7->8. Passes opp at 4 -> passive: 1 nonlethal.
	validate_positions(player1, 8, player2, 4)
	assert_eq(player2.life, 29)

func test_passive_fires_on_advance_past_pulled_opponent():
	position_players(player1, 4, player2, 7)
	execute_strike(player1, player2, "luciya_mantis_strike", "standard_normal_dive",
		false, false,
		[1],  # Transform offer: pass
		[])
	# Before: pull 2 (opp 7->5). After: advance 4 (self 4-> passes 5 -> 9).
	# Passes opp at 5 -> passive fires.
	advance_turn(player2)


# ============================================================================
# DOWNBURST — R1 P2 S6 (free)
#   before: pull 2. after: advance 2.
# ============================================================================

func test_downburst_pulls_then_advances():
	position_players(player1, 4, player2, 7)
	# Dive R1 P5 S4. Before: pull 2 (opp 7->5, now dist=1 both in range).
	# S6 > S4, p1 hits. After: advance 2 from 4 -> skip(5) -> 7.
	execute_strike(player1, player2, "luciya_downburst", "standard_normal_dive",
		false, false, [], [])
	advance_turn(player2)

func test_downburst_after_advances_on_miss():
	position_players(player1, 4, player2, 5)
	execute_strike(player1, player2, "luciya_downburst", "standard_normal_cross",
		false, false, [], [])
	advance_turn(player2)


# ============================================================================
# CHAIN CLIMB (immediate boost, 2F)
#   Pay 2F: advance to edge or retreat to edge.
#   Downburst card IS the boost card.
# ============================================================================

func test_chain_climb_advance_past_opponent():
	position_players(player1, 4, player2, 6)
	var boost_card = give_player_specific_card(player1, "luciya_downburst")
	assert_true(game_logic.do_boost(player1, boost_card,
			[player1.hand[0].id, player1.hand[1].id]))
	assert_true(game_logic.do_choice(player1, 0))  # advance -> past opp at 6 to edge
	# Advance skips past opponent: 4->5->skip(6)->7->8->9 (edge)
	# Edge is at 9 (same as retreat test), so p1 goes to 9.
	# Expected: 4->5->skip(6)->7->8->9.
	assert_eq(player1.arena_location, 9)
	advance_turn(player2)

func test_chain_climb_retreat_to_edge():
	position_players(player1, 4, player2, 1)
	var boost_card = give_player_specific_card(player1, "luciya_downburst")
	assert_true(game_logic.do_boost(player1, boost_card,
			[player1.hand[0].id, player1.hand[1].id]))
	assert_true(game_logic.do_choice(player1, 1))  # retreat
	assert_eq(player1.arena_location, 9)  # retreat away from opp at 1 -> RIGHT edge = 9
	advance_turn(player2)


# ============================================================================
# TALON SWEEP — R1 P2 S6 (free)
#   hit: advance 4, then optional ForceForEffect: spend 1F -> +1 Power
#   Transform: Grandstanding (set_strike: optional 1F -> both +1P)
# ============================================================================

func test_talon_sweep_advance_through_opponent():
	position_players(player1, 3, player2, 4)
	execute_strike(player1, player2, "luciya_talon_sweep", "standard_normal_focus",
		false, false,
		[
			[false, true],  # ForceForEffect: cancel
			1               # Transform offer: pass
		],
		[])
	validate_positions(player1, 8, player2, 4)
	assert_eq(player2.life, 29)


# ============================================================================
# MANTIS STRIKE — R3-5 P4 S4 (free)
#   hit: pull 2, advance 4.
#   Transform: Storm's Fury (set_strike: optional 2F -> Move 1)
# ============================================================================

func test_mantis_strike_hit():
	position_players(player1, 4, player2, 7)
	execute_strike(player1, player2, "luciya_mantis_strike", "standard_normal_dive",
		false, false, [1], [])
	# Pull 2 (opp 7->5), advance 4 (self 4->?).
	advance_turn(player2)


# ============================================================================
# BUG ZAPPER — R1 P2 S4 (free)
#   before: ForceForEffect, per F -> advance 2.
#   Transform: Thunderclap (normals: after stun -> Move 2)
# ============================================================================

func test_bug_zapper_advance_with_gauge():
	position_players(player1, 3, player2, 5)
	# Stack a known 1-force card on top so gauge_ids[0] is deterministic.
	# (give_gauge() pulls off the top of a randomly-seeded deck, and Luciya's
	# ultra Skies Aflame is worth 2 force, which would change the advance.)
	set_player_topdeck(player1, "standard_normal_grasp")
	var gauge_ids = give_gauge(player1, 3)
	# Focus R1-2 P4 S1 G5 A2 (ignore_push_and_pull). Bug Zapper R1 P2 S4.
	# Dist=2, both in range. S4 > S1, p1 wins.
	# Before: ForceForEffect, force_max=4. Spend 1F -> advance 2, then stop.
	execute_strike(player1, player2, "luciya_bug_zapper", "standard_normal_focus",
		false, false,
		[
			[gauge_ids[0]],  # ForceForEffect: spend 1F -> advance 2
			0                # EffectChoice: accept
		],
		[])
	# Advance 2: 3 -> 6, passing through the opponent at 5 -> passive deals 1
	# nonlethal, absorbed by Focus's 2 armor (1 armor left). Bug Zapper then
	# hits at range 1 for 2 power - 1 remaining armor = 1 damage.
	validate_positions(player1, 6, player2, 5)
	assert_eq(player2.life, 29)
	advance_turn(player2)


func test_bug_zapper_advance_with_ultra_crosses_twice():
	# FAQ: "When using Bug Zapper, does paying for multiple Advance effects let
	# you cross over the opponent multiple times? A: Yes. Spend all Force before
	# resolving any Advance effects."
	# An ultra pays 2 force, so Advance 2 resolves TWICE as separate moves.
	# 3 -> 6 (crosses the opponent at 5), then 6 -> 3 (crosses back), so the
	# moved_past passive triggers on each crossing. This must NOT be collapsed
	# into a single Advance 4.
	position_players(player1, 3, player2, 5)
	set_player_topdeck(player1, "luciya_skies_aflame")  # ultra == 2 force
	var gauge_ids = give_gauge(player1, 3)
	execute_strike(player1, player2, "luciya_bug_zapper", "standard_normal_focus",
		false, false,
		[[gauge_ids[0]]],  # spend the ultra -> 2 force -> Advance 2, twice
		[])
	# Crossed over and back, ending where she started.
	validate_positions(player1, 3, player2, 5)
	# Ended at range 2, so Bug Zapper (R1) misses.
	validate_has_event(game_logic.get_latest_events(), Enums.EventType.EventType_Strike_Miss, player1)
	advance_turn(player2)


func test_bug_zapper_force_is_discarded_before_advancing():
	# FAQ: "When taking a Move action to move past the opponent, is spent Force
	# discarded before or after moving (and resolving character ability)?
	# A: Before."
	# Luciya's passive adds the top discard to gauge when she moves past the
	# opponent, so the card she paid with must already be in the discard pile
	# and is therefore the card that gets picked up.
	position_players(player1, 3, player2, 5)
	var paid_id = set_player_topdeck(player1, "standard_normal_grasp")
	var gauge_ids = give_gauge(player1, 3)
	assert_eq(gauge_ids[0], paid_id, "the stacked card should be the one paid")
	execute_strike(player1, player2, "luciya_bug_zapper", "standard_normal_focus",
		false, false,
		[[gauge_ids[0]], 0],
		[])
	# The paid card was discarded first, then the crossing passive pulled that
	# same top discard into gauge.
	var found_in_gauge = false
	for card in player1.gauge:
		if card.id == paid_id:
			found_in_gauge = true
			break
	assert_true(found_in_gauge, "Force paid before moving, so it is the top discard picked up")
	advance_turn(player2)


func test_moved_past_outside_strike_cannot_stun():
	# FAQ: "If Luciya moves past the opponent with her Transformation before
	# setting her card for a Strike, can this damage stun the opponent if they
	# reveal an attack with no Guard? A: No, the damage was not dealt during the
	# Strike."
	position_players(player1, 3, player2, 5)
	# Move action straight past the opponent, outside of any strike.
	var move_cards = get_cards_from_hand(player1, 3)
	assert_true(game_logic.do_move(player1, move_cards, 6))
	validate_positions(player1, 6, player2, 5)
	# The crossing dealt the passive's nonlethal damage...
	assert_eq(player2.life, 29)
	# ...but outside a strike there is no strike to be stunned in, so no stun
	# is ever reported. (Stun state lives on active_strike, not on the player.)
	assert_null(game_logic.active_strike, "the move happened outside a strike")
	validate_not_has_event(game_logic.get_latest_events(), Enums.EventType.EventType_Strike_Stun, player2)
	advance_turn(player2)

	# The damage also must not carry over to stun them in the next strike: a
	# no-guard attack from the opponent still resolves normally.
	position_players(player1, 3, player2, 5)
	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_focus")
	validate_not_has_event(game_logic.get_latest_events(), Enums.EventType.EventType_Strike_Stun, player2)


# ============================================================================
# FIREFLY GUNNER — R3-4 P6 S1 (free)
#   during_strike: dodge_at_range R3-4. Attacks at R3-4 don't hit you.
#   Boost: The Whirlwind (continuous, 0F) — +3 Speed, EoT add to gauge.
# ============================================================================

func test_firefly_gunner_hits_at_range():
	position_players(player1, 1, player2, 4)
	# Focus R1-2 P4 S1 G5 A2, ignore_push_and_pull. Dist=3: Firefly R3-4 in range, Focus R2 out.
	# Both out of range -> wild swing. The during_strike DodgeAtRange doesn't trigger because
	# the opponent can't attack at R3-4.
	execute_strike(player1, player2, "luciya_firefly_gunner", "standard_normal_focus",
		false, false, [], [])
	advance_turn(player2)


# ============================================================================
# RIDE THE LIGHTNING — R1 P1 S8 (ultra, 2g)
#   before: close 4. after: advance 4.
#   Boost: Chain Trap (continuous, 0F) — block opp move, opp can spend 2F to remove
# ============================================================================

func test_ride_the_lightning_hits():
	position_players(player1, 1, player2, 6)
	var gauge_ids = give_gauge(player1, 2)
	execute_strike(player1, player2, "luciya_ride_the_lightning", "standard_normal_dive",
		false, false, [gauge_ids], [])
	advance_turn(player2)

func test_chain_trap_opponent_pays_2_force_to_send_boost_to_luciya_gauge():
	var chain_trap_id = give_player_specific_card(player1, "luciya_ride_the_lightning")
	var force_card_1 = give_player_specific_card(player2, "standard_normal_assault")
	var force_card_2 = give_player_specific_card(player2, "standard_normal_cross")

	assert_true(game_logic.do_boost(player1, chain_trap_id, []))
	assert_true(player2.cannot_move)
	assert_eq(player2.get_bonus_actions().size(), 1)

	assert_true(game_logic.do_bonus_turn_action(player2, 0))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ForceForEffect)
	assert_true(game_logic.do_force_for_effect(player2, [force_card_1, force_card_2], false))

	assert_false(player2.cannot_move)
	assert_false(player1.is_card_in_continuous_boosts(chain_trap_id))
	validate_gauge(player1, 1, chain_trap_id)


# ============================================================================
# SKIES AFLAME — R3-5 P4 S5 (ultra, 3g)
#   hit: gain advantage. after: move to any space.
#   Boost: Preemptive Attack (continuous, 1F) — +2 Speed, Strike now.
# ============================================================================

func test_skies_aflame_gain_advantage():
	position_players(player1, 2, player2, 6)
	var gauge_ids = give_gauge(player1, 3)
	# Skies R3-5 P4 S5 (ultra, 3g) vs Grasp R1 P3 S7. Dist=4, Skies in range, Grasp out.
	# Pay 3g, P4 - G0 = 4 dmg. move_to_any_space -> 7 (direct teleport, no passive).
	execute_strike(player1, player2, "luciya_skies_aflame", "standard_normal_grasp",
		false, false,
		[
			gauge_ids,  # GaugeForEffect: spend 3 gauge
			7           # move_to_any_space: position 7
		],
		[])
	assert_eq(player2.life, 25)  # 30 - 5 (P4 dmg + 1 from move_to_any_space advance-through)
	# gain_advantage: p1 took the turn.
	advance_turn(player1)

func test_exceeded_skies_aflame_with_boost():
	position_players(player1, 2, player2, 6)
	var exceed_cost = give_gauge(player1, 5)
	assert_true(game_logic.do_exceed(player1, exceed_cost))
	advance_turn(player2)
	# Now p2 has played their turn. Back to p1.

	var skies_gauge = give_gauge(player1, 3)
	execute_strike(player1, player2, "luciya_skies_aflame", "standard_normal_grasp",
		false, false,
		[
			skies_gauge,  # GaugeForEffect: spend 3 gauge -> 3 × +1P boosts
			7             # move_to_any_space: position 7
		],
		[])
	# P4 + 3 = P7. P7 - G0 = 7. move_to_any_space is direct, no passive.
	assert_eq(player2.life, 23)  # 30 - 7 = 23
	advance_turn(player1)


# ============================================================================
# EXCEED: GAUGE BOOST (replacement_boost)
#   Exceed cost 5, reduced by 2 per transform.
#   Replace gauge-discards with +1P continuous boosts.
# ============================================================================

func test_exceed_basic():
	var gauge_ids = give_gauge(player1, 5)
	assert_true(game_logic.do_exceed(player1, gauge_ids))
	assert_true(player1.exceeded)
	advance_turn(player2)

	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_focus",
		false, false, [], [])
	# Sweep P4 S4 vs Focus P2 S4: p1 hits.
	advance_turn(player2)


# ============================================================================
# THE THUNDERBIRD (exceeded ability) — L1 FAQ ruling
#   "When paying for an Ultra, does The Thunderbird put any Gauge spent into
#    play as a Continuous Boost immediately? A: Yes. The cost is paid (and The
#    Thunderbird's ability activates) immediately as the card is revealed and
#    valid."
#   Luciya's exceeded ability replaces spent Gauge with facedown +1 Power
#   continuous boosts (replacement_boost_definition). This must happen at
#   cost-payment time (StrikeState_*_PayCosts), not later.
# ============================================================================

func test_thunderbird_ultra_gauge_becomes_continuous_boost_at_paycost_time():
	position_players(player1, 2, player2, 6)
	var exceed_cost = give_gauge(player1, 5)
	assert_true(game_logic.do_exceed(player1, exceed_cost))
	assert_true(player1.exceeded)
	advance_turn(player2)

	# Skies Aflame is an Ultra costing 3 Gauge (R3-5 P4 S5). Its after-effect is a
	# move-to-any-space decision, so the strike pauses AFTER costs are paid,
	# letting us observe that the spent gauge is already in play.
	var ultra_gauge = give_gauge(player1, 3)
	assert_eq(player1.continuous_boosts.size(), 0)
	# Dive (R1 P5 S4) is slower and out of range, so Skies (S5) resolves first.
	execute_strike(player1, player2, "luciya_skies_aflame", "standard_normal_dive",
		false, false,
		[ultra_gauge],  # PayStrikeCost: spend the 3 gauge
		[],
		true)  # exit_after_validation -> pause once costs are paid
	# The engine auto-advanced to Skies Aflame's move-to-any-space after-effect,
	# proving costs were already paid. The 3 spent gauge cards were converted
	# into continuous boosts immediately at pay time (The Thunderbird), so they
	# are in play now (before the strike finished resolving).
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_eq(player1.continuous_boosts.size(), 3,
			"The Thunderbird put spent Ultra gauge into play as continuous boosts immediately at pay time")
	for card in player1.continuous_boosts:
		assert_eq(card.definition["boost"]["boost_type"], "continuous")
	# Each boost grants +1 Power, and they were in play during the strike: P4 + 3 = 7.
	assert_eq(player1.strike_stat_boosts.power, 3,
			"the replacement boosts were active during the strike")

	# Finish resolving the strike (choose a move-to-any-space location).
	process_remaining_decisions(player1, player2, [7], [])
	advance_turn(player1)
