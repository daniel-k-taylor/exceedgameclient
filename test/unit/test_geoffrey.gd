extends ExceedGutTest

func who_am_i():
	return "geoffrey"

## Both players are Geoffrey (mirror match). Geoffrey ability:
## If opponent's printed speed > your printed speed → +1 Armor +1 Guard
## Exceed ability replaces starting ability:
## When hit (first time): draw 1, force(max1) → +2 Power
##
## Standard normals (for damage math):
## Grasp: R1 P3 S7 G0. Hit: choice[push1, push2, pull1, pull2].
## Cross: R1-2 P3 S6 G0. After: retreat 3.
## Assault: R1 P4 S5 G0. Before: close 2.
## Dive: R1 P5 S4 G0. Before: advance 3.
## Spike: R2-3 P5 S3 G4. Ignore armor.
## Sweep: R1-3 P6 S2 G6. Hit: opponent_discard_random 1.
## Block: R-1(miss) P0 S0 A2 G3. During: when_hit_force_for_armor(2).
##
## Note: Block's ForceForArmor always fires when Block user is hit.
## Block with Geoffrey ability (opp speed > 0): A3, G4.
## Transform choice only offered if card HIT and boost_type is "transform".

func handle_discard_to_max(player):
	if player.hand.size() > player.max_hand_size:
		var cards = []
		var to_discard = player.hand.size() - player.max_hand_size
		for i in range(to_discard):
			cards.append(player.hand[i].id)
		assert_true(game_logic.do_discard_to_max(player, cards))

## ===== ABILITY TESTS =====

func test_ability_opponent_higher_speed():
	position_players(player1, 4, player2, 5)
	# Spike(S3) vs Assault(S5). p1 ability: opp S5>S3 → +1A+1G.
	# Spike: A1, G5. Assault first. P4 vs A1=3. G5≥3, not stunned.
	# Spike: R2-3, dist1 <2, MISS.
	execute_strike(player1, player2, "standard_normal_spike", "standard_normal_assault")
	validate_life(player1, 27, player2, 30)

func test_ability_same_speed_no_bonus():
	position_players(player1, 4, player2, 5)
	# Both Assault(S5). No ability for either. Initiator first. P4 stuns p2.
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault")
	validate_life(player1, 30, player2, 26)

func test_ability_opponent_lower_speed():
	position_players(player1, 4, player2, 5)
	# Assault(S5) vs Spike(S3). p2 ability: opp S5>S3 → Spike A1, G5.
	# Assault first. P4 vs A1=3. G5≥3, not stunned.
	# Spike: R2-3, dist1 <2, MISS.
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_spike")
	validate_life(player1, 30, player2, 27)

## ===== BASTION STANCE: R1-2 P3 S1 A1 G5 =====
## Before: was_hit→+2P. After: retreat 2.
## Transform "Untainted"

func test_bastion_stance_was_hit_power_boost():
	position_players(player1, 4, player2, 5)
	# Bastion(S1) vs Assault(S5). p1 ability: opp S5>S1 → A2, G6.
	# Assault first. P4 vs A2=2. G6≥2, not stunned. was_hit.
	# Bastion Before: +2P→5. R1-2 dist1, P5. After: retreat 2→pos 2.
	execute_strike(player1, player2, "geoffrey_bastionstance", "standard_normal_assault",
		false, false,
		[0]) # accept transform
	validate_life(player1, 28, player2, 25)
	validate_positions(player1, 2, player2, 5)

func test_bastion_stance_not_hit_vs_block():
	position_players(player1, 4, player2, 5)
	# Bastion(S1) vs Block(S0). p2 ability: opp S1>S0 → Block A3, G4.
	# Bastion first(S1>S0). was_hit=false. P3 vs A3=0. Hit (in range). ForceForArmor.
	# After: retreat 2→pos 2.
	execute_strike(player1, player2, "geoffrey_bastionstance", "standard_normal_block",
		false, false,
		[0], # accept transform
		[[]]) # p2 declines ForceForArmor
	validate_life(player1, 30, player2, 30)
	validate_positions(player1, 2, player2, 5)

func test_bastion_stance_decline_transform():
	position_players(player1, 4, player2, 5)
	var strike_cards = execute_strike(player1, player2, "geoffrey_bastionstance", "standard_normal_block",
		false, false,
		[1], # decline → gauge
		[[]]) # p2 ForceForArmor
	assert_true(player1.is_card_in_gauge(strike_cards[0]))
	validate_life(player1, 30, player2, 30)

## ===== GOLDEN ARROW: R3-7 P5 S4 A0 G3 =====
## Hit: push 1. (No transform - boost is continuous "Golden Chains")

func test_golden_arrow_hit_push():
	position_players(player1, 2, player2, 7)
	# GA(S4) vs Block(S0). p2 ability: opp S4>S0 → Block A3, G4.
	# Dist 5. GA R3-7, in range. P5 vs A3=2. G4≥2, not stunned. Hit: push 1→p2 to 8.
	# No transform (Golden Arrow boost is continuous, not transform).
	execute_strike(player1, player2, "geoffrey_goldenarrow", "standard_normal_block",
		false, false,
		[], # no transform choice
		[[]]) # p2 ForceForArmor
	validate_life(player1, 30, player2, 28)
	validate_positions(player1, 2, player2, 8)

## ===== GOLDEN CHAINS BOOST: [+1] Continuous. -2S +2A. Now: draw 2. =====

func test_golden_chains_boost_draw():
	position_players(player1, 4, player2, 5)
	player1.discard_hand()
	var card_id = give_player_specific_card(player1, "geoffrey_goldenarrow")
	var pay_id = give_player_specific_card(player1, "standard_normal_grasp")
	var hand_before_boost = player1.hand.size()
	assert_true(game_logic.do_boost(player1, card_id, [pay_id]))
	# Card to boost area (-1), force payment (-1), draw 2 (+2), end-of-turn draw (+1). Net: +1.
	assert_eq(player1.hand.size(), hand_before_boost + 1)
	handle_discard_to_max(player1)

func test_golden_chains_speed_armor_effect():
	position_players(player1, 4, player2, 5)
	player1.discard_hand()
	player1.draw(3) # Keep hand small to avoid discard issues
	var card_id = give_player_specific_card(player1, "geoffrey_goldenarrow")
	var pay_id = give_player_specific_card(player1, "standard_normal_grasp")
	assert_true(game_logic.do_boost(player1, card_id, [pay_id]))
	handle_discard_to_max(player1)
	advance_turn(player2)

	# Assault(S5) with Chains: effective S3, A2. vs Assault(S5).
	# Printed speeds both S5 → ability doesn't trigger for either player.
	# p2 faster (S5>S3). P4 vs A2=2. G0. 2>0→stunned! p1 doesn't attack.
	# Demonstrates Chains: -2S makes p1 slower, +2A reduces damage from 4 to 2.
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault")
	validate_life(player1, 28, player2, 30)

## ===== INQUISITION: R1 P5 S4 A0 G1. Ignore Armor. =====
## Hit: +2 Armor. Transform "Compulsive Purification"

func test_inquisition_ignore_armor():
	position_players(player1, 4, player2, 5)
	# Inquisition(S4) vs Spike(S3). p2 ability: opp S4>S3 → Spike A1, G5.
	# Inq first(S4>S3). R1 dist1, P5, ignore armor→p2 takes 5. 5>G5→stunned.
	execute_strike(player1, player2, "geoffrey_inquisition", "standard_normal_spike",
		false, false,
		[0]) # accept transform
	validate_life(player1, 30, player2, 25)

func test_inquisition_stunned_by_faster():
	position_players(player1, 4, player2, 5)
	# Inq(S4) vs Assault(S5). p1 ability: opp S5>S4 → Inq A1, G2.
	# Assault first(S5). P4 vs A1=3. G2<3→stunned!
	execute_strike(player1, player2, "geoffrey_inquisition", "standard_normal_assault")
	validate_life(player1, 27, player2, 30)

func test_inquisition_hit_gives_armor():
	position_players(player1, 4, player2, 5)
	# Inq(S4) vs Dive(S4). Same speed, initiator first.
	# P5 ignore armor. 5>G0→stunned. Hit: +2A on self.
	execute_strike(player1, player2, "geoffrey_inquisition", "standard_normal_dive",
		false, false,
		[0]) # accept transform
	validate_life(player1, 30, player2, 25)

## ===== COMPULSIVE PURIFICATION TRANSFORM: counter_boost =====
## force_for_effect with force_effect_interval:2, force_max:2
## per_force_effect: negate_boost (spend 2 cards → negate)

func test_compulsive_purification_negate_boost():
	position_players(player1, 4, player2, 6)
	add_transform(player1, "geoffrey_inquisition")
	advance_turn(player1)

	var force1 = give_player_specific_card(player1, "standard_normal_sweep")
	var force2 = give_player_specific_card(player1, "standard_normal_cross")
	var boost_id = give_player_specific_card(player2, "standard_normal_grasp")
	assert_true(game_logic.do_boost(player2, boost_id, []))
	# Counter fires: ForceForEffect for p1
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ForceForEffect)
	assert_true(game_logic.do_force_for_effect(player1, [force1, force2], false))
	# Boost should be negated. Card should end up in discard (not continuous boosts).
	assert_true(player2.is_card_in_discards(boost_id))
	assert_eq(player2.get_boosts(false, true).size(), 0)
	advance_turn(player1)

func test_compulsive_purification_decline():
	position_players(player1, 4, player2, 6)
	add_transform(player1, "geoffrey_inquisition")
	advance_turn(player1)

	var boost_id = give_player_specific_card(player2, "standard_normal_grasp")
	assert_true(game_logic.do_boost(player2, boost_id, []))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ForceForEffect)
	assert_true(game_logic.do_force_for_effect(player1, [], false))
	# Boost goes through - Grasp boost "Fierce" (+2P continuous) should be active
	assert_true(player2.get_boosts(false, true).size() > 0)
	advance_turn(player1)

func test_compulsive_purification_no_force():
	position_players(player1, 4, player2, 6)
	add_transform(player1, "geoffrey_inquisition")
	player1.discard_hand()
	advance_turn(player1)

	var boost_id = give_player_specific_card(player2, "standard_normal_grasp")
	assert_true(game_logic.do_boost(player2, boost_id, []))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ForceForEffect)
	assert_true(game_logic.do_force_for_effect(player1, [], false))
	advance_turn(player1)

## ===== SACRAMENT OF BLADES: R2-6 P3 S3 A0 G4 =====
## Hit: gain 2 life. Transform "Ministry of Saints"

func test_sacrament_hit_gain_life():
	position_players(player1, 2, player2, 5)
	player1.life = 25
	# Sacrament(S3) vs Block(S0). p2 ability: opp S3>S0 → Block A3, G4.
	# Sacrament first. R2-6, dist3, in range. P3 vs A3=0. Hit. ForceForArmor.
	# Hit: gain 2 life. p1: 25→27.
	execute_strike(player1, player2, "geoffrey_sacramentofblades", "standard_normal_block",
		false, false,
		[0], # accept transform
		[[]]) # p2 ForceForArmor
	validate_life(player1, 27, player2, 30)

func test_sacrament_out_of_range():
	position_players(player1, 1, player2, 9)
	player1.life = 25
	# Dist 8. Sacrament R2-6, OUT OF RANGE. MISS.
	# No transform choice (miss). No ForceForArmor (Block not hit).
	execute_strike(player1, player2, "geoffrey_sacramentofblades", "standard_normal_block")
	validate_life(player1, 25, player2, 30)

## ===== MINISTRY OF SAINTS TRANSFORM: set_strike force(max1)→guard_up 2 =====

func test_ministry_guard_spend_force():
	position_players(player1, 4, player2, 5)
	add_transform(player1, "geoffrey_sacramentofblades")
	advance_turn(player1)
	advance_turn(player2)

	var force_card = give_player_specific_card(player1, "standard_normal_assault")
	# Assault(S5) vs Assault(S5). Same speed, initiator first. No ability bonus.
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault",
		false, false,
		[[force_card]]) # spend 1 force for +2 guard
	validate_life(player1, 30, player2, 26)

func test_ministry_guard_helps_survive():
	position_players(player1, 4, player2, 5)
	add_transform(player1, "geoffrey_sacramentofblades")
	advance_turn(player1)
	advance_turn(player2)

	var force_card = give_player_specific_card(player1, "standard_normal_assault")
	# Assault(S5) vs Grasp(S7). p1 ability: opp S7>S5 → +1A+1G. Assault: A1, G1.
	# Ministry +2G: G1+2=3.
	# Grasp first(S7). R1 dist1, P3 vs A1=2. G3≥2, not stunned.
	# p1 Assault: P4→p2 takes 4.
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_grasp",
		false, false,
		[[force_card]], # spend 1 force for +2 guard
		[0]) # p2 Grasp hit choice (push 1)
	validate_life(player1, 28, player2, 26)

func test_ministry_decline_force():
	position_players(player1, 4, player2, 5)
	add_transform(player1, "geoffrey_sacramentofblades")
	advance_turn(player1)
	advance_turn(player2)

	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault",
		false, false,
		[[]]) # decline force
	validate_life(player1, 30, player2, 26)

## ===== SOLEMN EXORCISM: R1 P4 S3 A0 G4 =====
## Before: was_hit→close 3.

func test_solemn_exorcism_close_after_hit():
	position_players(player1, 3, player2, 6)
	# SE(S3) vs Assault(S5). p1 ability: opp S5>S3 → SE A1, G5.
	# Assault first. Before close 2: p2 6→5→4. R1 dist1, P4 vs A1=3. G5≥3, not stunned. was_hit.
	# SE Before: close 3. p1 at 3, p2 at 4, already adjacent. Can't get closer.
	# SE: R1 dist1, P4→p2 takes 4.
	execute_strike(player1, player2, "geoffrey_solemnexorcism", "standard_normal_assault")
	validate_life(player1, 27, player2, 26)
	validate_positions(player1, 3, player2, 4)

func test_solemn_exorcism_both_miss():
	position_players(player1, 2, player2, 7)
	# SE(S3) vs Grasp(S7). Grasp first. R1, dist5, MISS. was_hit=false.
	# SE Before: no close (not hit). R1, dist5, MISS.
	execute_strike(player1, player2, "geoffrey_solemnexorcism", "standard_normal_grasp")
	validate_life(player1, 30, player2, 30)

func test_solemn_exorcism_not_hit():
	position_players(player1, 4, player2, 5)
	# SE(S3) vs Block(S0). p2 ability: opp S3>S0 → Block A3, G4.
	# SE first(S3>S0). was_hit=false. R1 P4 vs A3=1. G4≥1, not stunned. ForceForArmor.
	execute_strike(player1, player2, "geoffrey_solemnexorcism", "standard_normal_block",
		false, false,
		[], # no init choices
		[[]]) # p2 ForceForArmor
	validate_life(player1, 30, player2, 29)

## ===== INVIOLABILITY BOOST: [+0] Continuous. Block opponent move. Now: draw 1. =====

func test_inviolability_draw():
	position_players(player1, 4, player2, 5)
	player1.discard_hand()
	player1.draw(2)
	var card_id = give_player_specific_card(player1, "geoffrey_solemnexorcism")
	var hand_before = player1.hand.size() # 3 (2 drawn + 1 given)
	assert_true(game_logic.do_boost(player1, card_id, []))
	# Card to boost area (-1), draw 1 (+1), end-of-turn draw (+1). Net: +1.
	assert_eq(player1.hand.size(), hand_before + 1)
	handle_discard_to_max(player1)

func test_inviolability_block_opponent_close():
	position_players(player1, 3, player2, 7)
	var card_id = give_player_specific_card(player1, "geoffrey_solemnexorcism")
	assert_true(game_logic.do_boost(player1, card_id, []))
	# Boost done → end of p1's turn → advance to p2's turn
	handle_discard_to_max(player1)
	advance_turn(player2)
	advance_turn(player1)
	# Now it's p2's turn

	# p2 uses Assault (before: close 2) vs p1 Grasp. Inviolability blocks p2's close.
	# p2 at 7, p1 at 3. Dist 4. Without close, Assault R1 misses (dist 4).
	# p2 ability: opp S7 > my S5 → no. p1 ability: opp S5 < my S7 → no.
	# Wait - printed S: Grasp=7, Assault=5. p2 ability: opp S7>S5 → Assault A1, G1.
	# p1 ability: opp S5<S7 → no bonus.
	# p2 Assault(S5) vs Grasp(S7). p1 Grasp faster.
	# Grasp: R1, dist 4, MISS. p2 Assault: Before close 2 → BLOCKED (cannot_move).
	# Assault: R1, dist 4, MISS. Nobody takes damage.
	execute_strike(player2, player1, "standard_normal_assault", "standard_normal_grasp")
	validate_life(player1, 30, player2, 30)
	validate_positions(player1, 3, player2, 7)

## ===== CRUSADER'S OATH: R1-2 P4 S3 A0 G0 (gauge 2) =====
## During: higher_speed_misses. Hit: gain_advantage.

func test_crusaders_oath_higher_speed_misses():
	position_players(player1, 4, player2, 5)
	var p1_gauge = give_gauge(player1, 2)
	# CO(S3) vs Assault(S5). p1 ability: opp S5>S3 → CO A1, G1.
	# higher_speed_misses: Assault S5>S3 → MISSES.
	# CO: R1-2 dist1, P4→p2 takes 4.
	execute_strike(player1, player2, "geoffrey_crusadersoath", "standard_normal_assault",
		false, false,
		[p1_gauge])
	validate_life(player1, 30, player2, 26)

func test_crusaders_oath_same_speed_hits():
	position_players(player1, 4, player2, 5)
	var p1_gauge = give_gauge(player1, 2)
	# CO(S3) vs Spike(S3). Same speed, initiator first. P4 stuns p2.
	execute_strike(player1, player2, "geoffrey_crusadersoath", "standard_normal_spike",
		false, false,
		[p1_gauge])
	validate_life(player1, 30, player2, 26)

func test_crusaders_oath_gain_advantage():
	position_players(player1, 4, player2, 5)
	var p1_gauge = give_gauge(player1, 2)
	# CO(S3) vs Block(S0). p2 ability: opp S3>S0 → Block A3, G4.
	# CO first(S3>S0). R1-2 dist1, P4 vs A3=1. G4≥1, not stunned. Hit: gain_advantage.
	execute_strike(player1, player2, "geoffrey_crusadersoath", "standard_normal_block",
		false, false,
		[p1_gauge],
		[[]]) # p2 ForceForArmor
	validate_life(player1, 30, player2, 29)
	assert_eq(game_logic.active_turn_player, player1.my_id)

## ===== SOLEMN OATH BOOST: [+0] Continuous. +5 Armor. =====
## Now: choice[spend 5 life→transform from hand, discard this]

func test_solemn_oath_transform():
	position_players(player1, 4, player2, 5)
	var oath_id = give_player_specific_card(player1, "geoffrey_crusadersoath")
	var transform_id = give_player_specific_card(player1, "geoffrey_bastionstance")
	assert_true(game_logic.do_boost(player1, oath_id, []))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)
	assert_true(game_logic.do_choice(player1, 0)) # spend 5 life → boost_additional(transform)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_BoostNow)
	assert_true(game_logic.do_boost(player1, transform_id))
	assert_eq(player1.life, 25)
	assert_true(player1.is_card_in_transforms(transform_id))
	handle_discard_to_max(player1)
	advance_turn(player2)

	# +5A from Solemn Oath. Assault(S5) vs Assault(S5). Same speed, initiator first.
	# No ability (printed S5 = S5). p1 A0+5(Oath)=5. P4 vs A5=0. Hit but 0 dmg.
	# p2 takes P4-A0=4.
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault")
	validate_life(player1, 25, player2, 26)

func test_solemn_oath_discard():
	position_players(player1, 4, player2, 5)
	var oath_id = give_player_specific_card(player1, "geoffrey_crusadersoath")
	assert_true(game_logic.do_boost(player1, oath_id, []))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)
	assert_true(game_logic.do_choice(player1, 1)) # discard
	assert_true(player1.is_card_in_discards(oath_id))
	assert_eq(player1.life, 30)
	handle_discard_to_max(player1)

## ===== INVIOLABLE JUDGMENT (Ultra): R1 P10 S0 A2 G0 (gauge 3) =====
## During: stun_immunity, opponent_cant_move_past.

func test_inviolable_judgment_stun_immunity():
	position_players(player1, 4, player2, 5)
	var p1_gauge = give_gauge(player1, 3)
	# IJ(S0) vs Assault(S5). p1 ability: opp S5>S0 → IJ A3, G1.
	# Assault first. P4 vs A3=1. G1≥1, not stunned (+stun_immunity).
	# IJ: R1 dist1, P10→p2 takes 10.
	execute_strike(player1, player2, "geoffrey_inviolablejudgment", "standard_normal_assault",
		false, false,
		[p1_gauge])
	validate_life(player1, 29, player2, 20)

func test_inviolable_judgment_vs_block():
	position_players(player1, 4, player2, 5)
	var p1_gauge = give_gauge(player1, 3)
	# IJ(S0) vs Block(S0). Same speed, initiator first. No ability bonus.
	# IJ: R1 P10 vs A2=8. G3<8→stunned. ForceForArmor.
	execute_strike(player1, player2, "geoffrey_inviolablejudgment", "standard_normal_block",
		false, false,
		[p1_gauge],
		[[]]) # p2 ForceForArmor
	validate_life(player1, 30, player2, 22)

## ===== HOLY WINGS BOOST: [+1] Immediate. Move to any space. Gauge(1)→return to hand. =====

func test_holy_wings_move_and_return():
	position_players(player1, 2, player2, 7)
	var card_id = give_player_specific_card(player1, "geoffrey_inviolablejudgment")
	var pay_id = give_player_specific_card(player1, "standard_normal_grasp")
	var gauge_ids = give_gauge(player1, 1)
	assert_true(game_logic.do_boost(player1, card_id, [pay_id]))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseArenaLocationForEffect)
	var target_idx = game_logic.decision_info.limitation.find(6)
	assert_true(game_logic.do_choice(player1, target_idx))
	assert_eq(player1.arena_location, 6)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_GaugeForEffect)
	assert_true(game_logic.do_gauge_for_effect(player1, gauge_ids))
	assert_true(player1.is_card_in_hand(card_id))
	handle_discard_to_max(player1)

func test_holy_wings_move_no_gauge():
	position_players(player1, 2, player2, 7)
	var card_id = give_player_specific_card(player1, "geoffrey_inviolablejudgment")
	var pay_id = give_player_specific_card(player1, "standard_normal_grasp")
	assert_true(game_logic.do_boost(player1, card_id, [pay_id]))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseArenaLocationForEffect)
	var target_idx = game_logic.decision_info.limitation.find(5)
	assert_true(game_logic.do_choice(player1, target_idx))
	assert_eq(player1.arena_location, 5)
	# No gauge → gauge_for_effect auto-skipped. Card goes to discard (immediate boost).
	assert_true(player1.is_card_in_discards(card_id))
	handle_discard_to_max(player1)

## ===== UNTAINTED TRANSFORM: passive: if life≤5 and no strike → choice =====
## Choice: gain 1 life (skip draw) OR normal draw

func test_untainted_gain_life():
	position_players(player1, 4, player2, 5)
	add_transform(player1, "geoffrey_bastionstance")
	player1.passive_effects["gain_life_instead_of_draw"] = 1
	advance_turn(player1) # p1 turn done, p2's turn
	advance_turn(player2) # p2 turn done, p1's turn
	player1.life = 5

	assert_true(game_logic.do_prepare(player1))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)
	assert_true(game_logic.do_choice(player1, 0)) # gain life instead of draw
	assert_eq(player1.life, 6)
	# Turn already advanced to p2 after choice - no need for handle_discard_to_max

func test_untainted_choose_draw():
	position_players(player1, 4, player2, 5)
	add_transform(player1, "geoffrey_bastionstance")
	player1.passive_effects["gain_life_instead_of_draw"] = 1
	advance_turn(player1)
	advance_turn(player2)
	player1.life = 5

	assert_true(game_logic.do_prepare(player1))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)
	assert_true(game_logic.do_choice(player1, 1)) # normal draw
	assert_eq(player1.life, 5)
	handle_discard_to_max(player1)

func test_untainted_high_life_no_choice():
	position_players(player1, 4, player2, 5)
	player1.life = 10
	add_transform(player1, "geoffrey_bastionstance")
	player1.passive_effects["gain_life_instead_of_draw"] = 1
	advance_turn(player1) # Untainted doesn't fire (life 10 > 5)
	assert_eq(player1.life, 10)

func test_untainted_after_strike_no_trigger():
	position_players(player1, 4, player2, 5)
	add_transform(player1, "geoffrey_bastionstance")
	player1.passive_effects["gain_life_instead_of_draw"] = 1
	player1.life = 4

	# Strike → did_strike_this_turn is true → Untainted doesn't trigger
	# Both Assault(S5). Same speed, initiator first. P4 stuns p2.
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault")
	validate_life(player1, 4, player2, 26)

## ===== EXCEED ABILITY: when_hit first_time_only: draw 1, force(max1)→+2P =====
## Replaces starting ability (no +1A+1G when exceeded)

func test_exceed_ability_spend_force():
	position_players(player1, 4, player2, 5)
	player1.exceeded = true
	# Bastion(S1) vs Assault(S5). EXCEEDED: no starting ability bonus!
	# Bastion: A1, G5. Assault first. P4 vs A1=3. G5≥3, not stunned. was_hit.
	# Exceed when_hit: draw 1, force(max1)→+2P.
	var force_card = give_player_specific_card(player1, "standard_normal_sweep")
	# Bastion Before: was_hit→+2P. P3+2(exceed)+2(was_hit)=7.
	# After: retreat 2→pos 2.
	execute_strike(player1, player2, "geoffrey_bastionstance", "standard_normal_assault",
		false, false,
		[[force_card], 0]) # force for +2P, accept transform
	validate_life(player1, 27, player2, 23)
	validate_positions(player1, 2, player2, 5)

func test_exceed_ability_decline_force():
	position_players(player1, 4, player2, 5)
	player1.exceeded = true
	# Same but decline force. P3+0+2(was_hit)=5.
	execute_strike(player1, player2, "geoffrey_bastionstance", "standard_normal_assault",
		false, false,
		[[], 0]) # decline force, accept transform
	validate_life(player1, 27, player2, 25)
	validate_positions(player1, 2, player2, 5)

func test_exceed_ability_not_hit():
	position_players(player1, 4, player2, 5)
	player1.exceeded = true
	# Assault(S5) vs Block(S0). EXCEEDED: no starting ability.
	# Block: A2, G3 (no ability bonus for p2 since p2 isn't exceeded... wait)
	# p2 also has Geoffrey. p2's ability is still active (not exceeded).
	# p2 ability: opp S5>S0 → Block A3, G4. But p1 is exceeded so p1 has no starting ability.
	# Assault first(S5). P4 vs A3=1. G4≥1, not stunned.
	# p1 not hit (Block can't hit). Exceed ability doesn't trigger.
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_block",
		false, false,
		[], # no init choices
		[[]]) # p2 ForceForArmor
	validate_life(player1, 30, player2, 29)

## ===== TRANSFORM SYSTEM TESTS =====

func test_ex_transform():
	position_players(player1, 4, player2, 5)
	player1.discard_hand()
	var card1_id = give_player_specific_card(player1, "geoffrey_inquisition")
	var card2_id = give_player_specific_card(player1, "geoffrey_inquisition")
	assert_true(game_logic.do_boost(player1, card1_id, [card2_id]))
	assert_true(player1.is_card_in_transforms(card1_id))
	assert_true(player1.is_card_in_discards(card2_id))
	handle_discard_to_max(player1)

func test_transform_on_hit_accept():
	position_players(player1, 4, player2, 5)
	var strike_cards = execute_strike(player1, player2, "geoffrey_bastionstance", "standard_normal_block",
		false, false,
		[0], # accept transform
		[[]]) # p2 ForceForArmor
	assert_true(player1.is_card_in_transforms(strike_cards[0]))

func test_transform_on_hit_decline():
	position_players(player1, 4, player2, 5)
	var strike_cards = execute_strike(player1, player2, "geoffrey_bastionstance", "standard_normal_block",
		false, false,
		[1], # decline → gauge
		[[]]) # p2 ForceForArmor
	assert_true(player1.is_card_in_gauge(strike_cards[0]))

## ===== EXCEED COST REDUCTION =====

func test_exceed_with_transforms_discount():
	position_players(player1, 4, player2, 5)
	add_transform(player1, "geoffrey_bastionstance")
	add_transform(player1, "geoffrey_inquisition")
	# Exceed cost 5 - 2*2 = 1
	give_gauge(player1, 1)
	var gauge_card = player1.gauge[0].id
	assert_true(game_logic.do_exceed(player1, [gauge_card]))
	assert_true(player1.exceeded)

func test_exceed_full_cost_no_transforms():
	position_players(player1, 4, player2, 5)
	give_gauge(player1, 5)
	var gauge_cards = []
	for card in player1.gauge:
		gauge_cards.append(card.id)
	assert_true(game_logic.do_exceed(player1, gauge_cards))
	assert_true(player1.exceeded)

func test_exceed_insufficient_gauge():
	position_players(player1, 4, player2, 5)
	give_gauge(player1, 4)
	var gauge_cards = []
	for card in player1.gauge:
		gauge_cards.append(card.id)
	assert_false(game_logic.do_exceed(player1, gauge_cards))
	assert_false(player1.exceeded)
