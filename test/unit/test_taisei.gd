extends ExceedGutTest

func who_am_i():
	return "taisei"

## Both players are Taisei (mirror match). Starting life: 15.
##
## Ability (set_strike): choice [pass, spend 1 life→+1P, spend 2 life→+2P]
## On Death (if not exceeded): may_exceed_now_with_cost (auto-spends gauge)
## On Exceed [cost: 5 - 2*transforms]: can_spend_life_for_force(1),
##   can_spend_life_for_gauge(2), choice [gain 10 life, set life to 10]
##
## Standard normals reference:
##   Grasp: R1 P3 S7 G0. Hit: choice[push1/2, pull1/2].
##   Cross: R1-2 P3 S6 G0. After: retreat 3.
##   Assault: R1 P4 S5 G0. Before: close 2. Hit: gain_advantage.
##   Dive: R1 P5 S4 G0. Before: advance 3.
##   Spike: R2-3 P5 S3 G4. Ignore armor and guard.
##   Sweep: R1-3 P6 S2 G6. Hit: opponent_discard_random 1.
##   Block: R-1(miss) P0 S0 A2 G3. During: ForceForArmor(2).

func handle_discard_to_max(player):
	if player.hand.size() > player.max_hand_size:
		var cards = []
		var to_discard = player.hand.size() - player.max_hand_size
		for i in range(to_discard):
			cards.append(player.hand[i].id)
		assert_true(game_logic.do_discard_to_max(player, cards))

## ===== STARTING LIFE TEST =====

func test_starting_life():
	assert_eq(player1.life, 15)
	assert_eq(player2.life, 15)

## ===== ABILITY TESTS (set_strike choice: pass / spend 1 / spend 2) =====

func test_ability_spend_0_life():
	position_players(player1, 4, player2, 5)
	# Both pass (0). Assault(S5) vs Cross(S6). Cross first.
	# Cross R1-2, dist1, P3 hit. Stun: 3>G0→stunned. p1: 15-3=12.
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_cross",
		false, false,
		[0], # p1 ability: pass
		[0]) # p2 ability: pass
	validate_life(player1, 12, player2, 15)

func test_ability_spend_1_life():
	position_players(player1, 4, player2, 5)
	# p1 spends 1 life (choice 1) → +1P. Cross(S6) first.
	# p1: 15-1(ability)-3(Cross)=11. Stunned (3>0).
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_cross",
		false, false,
		[1], # p1 ability: spend 1 life
		[0]) # p2 ability: pass
	validate_life(player1, 11, player2, 15)

func test_ability_spend_2_life():
	position_players(player1, 3, player2, 5)
	# p1 spends 2 life → +2P. Assault(S5) vs Assault(S5). Initiator first.
	# Assault Before: close 2 → p1: 3→4. P4+2=6. Hit. p2: 15-6=9. Stunned.
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault",
		false, false,
		[2], # p1 ability: spend 2 life → +2P
		[0]) # p2 ability: pass
	validate_life(player1, 13, player2, 9)
	validate_positions(player1, 4, player2, 5)

## ===== ON DEATH / EXCEED TESTS =====

func test_on_death_exceed_with_gauge():
	position_players(player1, 4, player2, 5)
	player1.life = 3
	give_gauge(player1, 5)
	# p1=Block(S0), p2=Sweep(S2). Sweep first. R1-3, dist1. P6 vs A2=4 damage.
	# p1: 3-4=-1 → on_death → auto-exceed (5 gauge) → on_exceed choice.
	# Block during: ForceForArmor.
	# Choices flow: ability pass, ForceForArmor [], on_exceed: gain 10 life (0).
	# p1 life: -1+10=9.
	execute_strike(player1, player2, "standard_normal_block", "standard_normal_sweep",
		false, false,
		[0, [], 0], # ability pass, ForceForArmor 0 cards, on_exceed: gain 10 life
		[0],         # ability pass
		false)
	validate_life(player1, 9, player2, 15)
	assert_true(player1.exceeded)

func test_on_death_exceed_set_life():
	position_players(player1, 4, player2, 5)
	player1.life = 3
	give_gauge(player1, 5)
	# Same as above but choose set life to 10 (choice 1).
	execute_strike(player1, player2, "standard_normal_block", "standard_normal_sweep",
		false, false,
		[0, [], 1], # ability pass, ForceForArmor 0, on_exceed: set life to 10
		[0],
		false)
	validate_life(player1, 10, player2, 15)
	assert_true(player1.exceeded)

func test_on_death_no_gauge_game_over():
	position_players(player1, 4, player2, 5)
	player1.life = 3
	# No gauge → can't exceed → game over.
	execute_strike(player1, player2, "standard_normal_block", "standard_normal_sweep",
		false, false,
		[0, []], # ability pass, ForceForArmor 0 cards
		[0])     # ability pass
	assert_eq(game_logic.game_state, Enums.GameState.GameState_GameOver)
	assert_eq(game_logic.game_over_winning_player, player2)

func test_on_death_already_exceeded():
	position_players(player1, 4, player2, 5)
	player1.life = 3
	var gauge = give_gauge(player1, 5)
	assert_true(game_logic.do_exceed(player1, gauge))
	assert_true(game_logic.do_choice(player1, 0)) # gain 10 → life 13
	advance_turn(player2)

	# Already exceeded, kill again → on_death condition not_exceeded fails → game over
	player1.life = 3
	position_players(player1, 4, player2, 5)
	execute_strike(player1, player2, "standard_normal_block", "standard_normal_sweep",
		false, false,
		[[]], # ForceForArmor with no cards (no ability choice when exceeded)
		[0])  # ability pass
	assert_eq(game_logic.game_state, Enums.GameState.GameState_GameOver)
	assert_eq(game_logic.game_over_winning_player, player2)

func test_exceed_with_transforms_discount():
	# Exceed cost = 5 - 2*transforms. With 2 transforms: cost = 1.
	position_players(player1, 4, player2, 5)
	add_transform(player1, "taisei_anathemasurge")
	add_transform(player1, "taisei_ashenclaws")
	var gauge = give_gauge(player1, 1)
	assert_eq(player1.get_exceed_cost(), 1)
	assert_true(game_logic.do_exceed(player1, gauge))
	assert_true(game_logic.do_choice(player1, 0)) # gain 10 life
	validate_life(player1, 25, player2, 15)
	assert_true(player1.exceeded)

## ===== EXCEED ABILITY TESTS =====

func test_exceed_can_spend_life_for_force():
	position_players(player1, 4, player2, 7)
	var gauge = give_gauge(player1, 5)
	assert_true(game_logic.do_exceed(player1, gauge))
	assert_true(game_logic.do_choice(player1, 0)) # gain 10 → 25
	advance_turn(player2)

	# Exceeded: can spend life for force (1 life = 1 force).
	# Discard hand so must use life. Move from 4→6 (costs 2 force).
	player1.discard_hand()
	assert_true(game_logic.do_move(player1, [], 6, false, 2))
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 23, player2, 15)

func test_exceed_can_spend_life_for_gauge():
	position_players(player1, 4, player2, 5)
	var gauge = give_gauge(player1, 5)
	assert_true(game_logic.do_exceed(player1, gauge))
	assert_true(game_logic.do_choice(player1, 0)) # gain 10 → 25
	advance_turn(player2)

	# Play Chaos Scissors (gauge_cost 2). Give 2 gauge to pay.
	var cs_id = give_player_specific_card(player1, "taisei_chaosscissors")
	var gauge_for_cs = give_gauge(player1, 2)
	# CS(S5) vs Assault(S5). Initiator first.
	# CS R1-2, dist1, P8 hit. p2: 15-8=7. Stunned.
	# CS hit: self-damage 3. p1: 25-3=22.
	execute_strike(player1, player2, cs_id, "standard_normal_assault",
		false, false,
		[gauge_for_cs], # pay gauge cost (no ability choice when exceeded)
		[0])            # ability pass
	validate_life(player1, 22, player2, 7)

## ===== ANATHEMA SURGE TESTS =====
## R1-2 P2 S6 A0 G0. Hit: gain 2 life. After: +3 armor.
## Transform: Edge of Death.

func test_anathema_surge_hit():
	position_players(player1, 4, player2, 5)
	# AS(S6) vs Assault(S5). AS first. R1-2, dist1. P2 hit. p2: 15-2=13.
	# Hit: gain 2 life → p1: 17. Stunned (2>G0). After: +3A.
	# Cleanup: transform choice (accept).
	execute_strike(player1, player2, "taisei_anathemasurge", "standard_normal_assault",
		false, false,
		[0, 0], # ability pass, transform: accept
		[0])    # ability pass
	validate_life(player1, 17, player2, 13)

func test_anathema_surge_miss():
	position_players(player1, 3, player2, 7)
	# dist=4. AS R1-2, out of range. Assault Before: close 2→p2: 7→5. dist=2. R1, out of range.
	# Both miss. No transform choice offered on miss.
	execute_strike(player1, player2, "taisei_anathemasurge", "standard_normal_assault",
		false, false,
		[0], # ability pass (no transform on miss)
		[0]) # ability pass
	validate_life(player1, 15, player2, 15)

## ===== EDGE OF DEATH TRANSFORM TESTS =====
## During: if life ≤ 6 → +1P. If also exceeded → +1S.

func test_edge_of_death_low_life_power():
	position_players(player1, 4, player2, 5)
	add_transform(player1, "taisei_anathemasurge") # Edge of Death
	player1.life = 6
	# Life 6 ≤ 6 → +1P. Assault P4+1=5. Initiator first. R1, dist1. Hit.
	# p2: 15-5=10. Stunned.
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault",
		false, false, [0], [0])
	validate_life(player1, 6, player2, 10)

func test_edge_of_death_high_life_no_bonus():
	position_players(player1, 4, player2, 5)
	add_transform(player1, "taisei_anathemasurge") # Edge of Death
	player1.life = 7
	# Life 7 > 6 → no bonus. Assault P4. p2: 15-4=11.
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault",
		false, false, [0], [0])
	validate_life(player1, 7, player2, 11)

func test_edge_of_death_exceeded():
	position_players(player1, 4, player2, 5)
	add_transform(player1, "taisei_anathemasurge") # Edge of Death
	var gauge = give_gauge(player1, 5)
	assert_true(game_logic.do_exceed(player1, gauge))
	assert_true(game_logic.do_choice(player1, 1)) # set life to 10
	advance_turn(player2)

	player1.life = 5
	# Exceeded + life 5 ≤ 6 → +1P, +1S.
	# Assault S5+1=6 vs Cross S6. Same speed, initiator first.
	# Assault P4+1=5. Before: close 2 (adj). R1, dist1. Hit. p2: 15-5=10. Stunned.
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_cross",
		false, false, [], [0]) # no ability choice when exceeded; p2 pass
	validate_life(player1, 5, player2, 10)

## ===== ASHEN CLAWS TESTS =====
## R2-4 P4 S4 A0 G0. After: choice [push1, push2, pull1, pull2, pass].
## Transform: Deathless.

func test_ashen_claws_push():
	position_players(player1, 3, player2, 6)
	# dist=3. AC(S4) vs Block(S0). AC first.
	# AC R2-4, dist3. P4 vs A2=2 damage. Stun: 2>G3? No. Not stunned.
	# AC After: push 2 (index 1). p2: 6→8.
	# Cleanup: transform accept (index 0).
	execute_strike(player1, player2, "taisei_ashenclaws", "standard_normal_block",
		false, false,
		[0, 1, 0], # ability pass, after: push2, transform: accept
		[0, []])    # ability pass, ForceForArmor: 0 cards
	validate_life(player1, 15, player2, 13)
	validate_positions(player1, 3, player2, 8)

func test_ashen_claws_pull():
	position_players(player1, 3, player2, 6)
	# AC After: pull 1 (index 2). p2: 6→5.
	# Cleanup: transform accept.
	execute_strike(player1, player2, "taisei_ashenclaws", "standard_normal_block",
		false, false,
		[0, 2, 0], # ability pass, after: pull1, transform: accept
		[0, []])    # ability pass, ForceForArmor
	validate_life(player1, 15, player2, 13)
	validate_positions(player1, 3, player2, 5)

## ===== DEATHLESS TRANSFORM TESTS =====
## Hit (if is_normal_attack): gain 1 life.

func test_deathless_normal_hit_gain_life():
	position_players(player1, 4, player2, 5)
	add_transform(player1, "taisei_ashenclaws") # Deathless
	player1.life = 10
	# Assault is a normal attack. Initiator first. P4 hit.
	# Deathless hit: gain 1 life (is_normal). Assault hit: gain_advantage.
	# Two hit effects → ChooseSimultaneousEffect.
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault",
		false, false,
		[0, 0], # ability pass, simultaneous hit effect order: 0
		[0])    # ability pass
	validate_life(player1, 11, player2, 11)

func test_deathless_special_no_gain():
	position_players(player1, 4, player2, 5)
	add_transform(player1, "taisei_ashenclaws") # Deathless
	player1.life = 10
	# AS is a special attack → Deathless doesn't trigger (is_normal_attack false).
	# AS(S6) vs Assault(S5). AS first. P2 hit. Hit: gain 2 life → 12.
	execute_strike(player1, player2, "taisei_anathemasurge", "standard_normal_assault",
		false, false,
		[0, 0], # ability pass, transform: accept
		[0])    # ability pass
	validate_life(player1, 12, player2, 13)

## ===== BLACKVOLT TESTS =====
## R1-3 P4 S4 A0 G0. Ignore Guard. Hit: gain 3 life.

func test_blackvolt_ignore_guard_gain_life():
	position_players(player1, 4, player2, 5)
	player1.life = 10
	# BV(S4) vs Block(S0 A2 G3). BV first.
	# R1-3, dist1. Ignore guard. P4 vs A2=2. Hit (guard ignored for stun).
	# Hit: gain 3 life → 13. p2: 15-2=13.
	execute_strike(player1, player2, "taisei_blackvolt", "standard_normal_block",
		false, false,
		[0],     # ability pass
		[0, []]) # ability pass, ForceForArmor 0 cards
	validate_life(player1, 13, player2, 13)

## ===== DEMONHIDE BOOST TESTS =====
## Continuous (from Blackvolt). During: +3 Armor. After: choice [spend 2 life→return, pass].

func test_demonhide_armor():
	position_players(player1, 4, player2, 5)
	var boost_id = give_player_specific_card(player1, "taisei_blackvolt")
	assert_true(game_logic.do_boost(player1, boost_id))
	advance_turn(player2)

	# Sweep(S2) vs Assault(S5). Assault first. Before: close 2 (adj).
	# P4 vs Demonhide(+3A) = 3A. 4-3=1 damage. p1: 15-1=14. Stun: 1>G6? No.
	# Sweep: R1-3, dist1. P6 hit p2: 15-6=9.
	# Only Demonhide after effect → no simultaneous choice.
	# Demonhide after: pass (choice 1).
	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_assault",
		false, false,
		[0, 1], # ability pass, Demonhide after: pass
		[0])    # ability pass
	validate_life(player1, 14, player2, 9)

func test_demonhide_return_to_hand():
	position_players(player1, 4, player2, 5)
	var boost_id = give_player_specific_card(player1, "taisei_blackvolt")
	assert_true(game_logic.do_boost(player1, boost_id))
	advance_turn(player2)

	# Same setup: Sweep vs Assault. Demonhide after: return (choice 0, spend 2 life).
	# p1: 15-1(Assault damage)-2(return cost)=12.
	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_assault",
		false, false,
		[0, 0], # ability pass, Demonhide after: return to hand (spend 2 life)
		[0])    # ability pass
	validate_life(player1, 12, player2, 9)
	var found = false
	for card in player1.hand:
		if card.definition['id'] == "taisei_blackvolt":
			found = true
			break
	assert_true(found, "Demonhide (blackvolt) should be back in hand")

func test_demonhide_no_return():
	position_players(player1, 4, player2, 5)
	var boost_id = give_player_specific_card(player1, "taisei_blackvolt")
	assert_true(game_logic.do_boost(player1, boost_id))
	advance_turn(player2)

	# Decline return (choice 1). Boost discards at cleanup (not sustained).
	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_assault",
		false, false,
		[0, 1], # ability pass, Demonhide after: pass
		[0])    # ability pass
	validate_life(player1, 14, player2, 9)
	# Boost was discarded at cleanup (continuous boosts discard unless sustained).
	assert_eq(player1.continuous_boosts.size(), 0)
	var found_in_discard = false
	for card in player1.discards:
		if card.definition['id'] == "taisei_blackvolt":
			found_in_discard = true
			break
	assert_true(found_in_discard, "Blackvolt (Demonhide) should be in discard after cleanup")

## ===== BLOODTHIRST TESTS =====
## R1-3 P3 S5 A0 G3. Before: force_for_effect(max 2) → +1P each.

func test_bloodthirst_spend_force():
	position_players(player1, 4, player2, 5)
	# BT(S5) vs Block(S0). BT first.
	# Before: spend 1 card for +1P. P3+1=4 vs A2=2 damage. p2: 15-2=13.
	# Stun: 2>G3? No. Block misses (R-1).
	var force_card = give_player_specific_card(player1, "standard_normal_grasp")
	execute_strike(player1, player2, "taisei_bloodthirst", "standard_normal_block",
		false, false,
		[0, [force_card]], # ability pass, before: spend 1 card for force
		[0, []])           # ability pass, ForceForArmor: 0 cards
	validate_life(player1, 15, player2, 13)

func test_bloodthirst_no_force():
	position_players(player1, 4, player2, 5)
	# BT Before: spend 0 force. P3 vs A2=1 damage. p2: 15-1=14. Stun: 1>G3? No.
	execute_strike(player1, player2, "taisei_bloodthirst", "standard_normal_block",
		false, false,
		[0, []], # ability pass, before: spend 0
		[0, []]) # ability pass, ForceForArmor: 0 cards
	validate_life(player1, 15, player2, 14)

## ===== GRAVE AMBITIONS BOOST TESTS =====
## Continuous (from Bloodthirst). Before: close 3.

func test_grave_ambitions_close():
	position_players(player1, 2, player2, 7)
	var boost_id = give_player_specific_card(player1, "taisei_bloodthirst")
	assert_true(game_logic.do_boost(player1, boost_id))
	advance_turn(player2)

	# Assault(S5) vs Assault(S5). Initiator first.
	# Two before effects: Grave Ambitions (close 3) + Assault (close 2).
	# → ChooseSimultaneousEffect. Either order → p1 ends at 6.
	# P4 hit. p2: 15-4=11. Stunned.
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault",
		false, false,
		[0, 0], # ability pass, simultaneous before: order 0
		[0])    # ability pass
	validate_life(player1, 15, player2, 11)
	validate_positions(player1, 6, player2, 7)

## ===== DUST TO DUST TESTS =====
## R1 P3 S7 A0 G0. Hit: choice [push1, pull1] AND gain 2 life.
## Transform: Demonheart.

func test_dust_to_dust_hit_push_gain_life():
	position_players(player1, 4, player2, 5)
	player1.life = 10
	# DtD(S7) vs Assault(S5). DtD first. R1, dist1. P3 hit.
	# Hit choice: push1 (index 0). p2: 5→6. AND gain 2 life → p1: 12.
	# p2: 15-3=12. Stunned. Cleanup: transform accept.
	execute_strike(player1, player2, "taisei_dusttodust", "standard_normal_assault",
		false, false,
		[0, 0, 0], # ability pass, hit: push1, transform: accept
		[0])        # ability pass
	validate_life(player1, 12, player2, 12)
	validate_positions(player1, 4, player2, 6)

func test_dust_to_dust_hit_pull_gain_life():
	position_players(player1, 4, player2, 5)
	player1.life = 10
	# Hit choice: pull1 (index 1). p2 at 5 pulled toward p1 at 4 → passes through to 3.
	# AND gain 2 life → p1: 12. Cleanup: transform accept.
	execute_strike(player1, player2, "taisei_dusttodust", "standard_normal_assault",
		false, false,
		[0, 1, 0], # ability pass, hit: pull1, transform: accept
		[0])        # ability pass
	validate_life(player1, 12, player2, 12)
	validate_positions(player1, 4, player2, 3)

## ===== DEMONHEART TRANSFORM TESTS =====
## on_spend_life: increment_bonus_armor_counters
## during_strike: armorup_bonus_armor_counters
## cleanup: reset_bonus_armor_counters

func test_demonheart_counters_from_ability():
	position_players(player1, 4, player2, 5)
	add_transform(player1, "taisei_dusttodust") # Demonheart
	# p1 spends 2 life via ability (choice 2) → triggers on_spend_life → counter.
	# During: Demonheart armor from counter. Assault P4+2=6. Initiator first.
	# p2: 15-6=9. Stunned.
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault",
		false, false,
		[2], # p1 ability: spend 2 life
		[0]) # p2 ability: pass
	validate_life(player1, 13, player2, 9)

func test_demonheart_counters_reset():
	position_players(player1, 4, player2, 5)
	add_transform(player1, "taisei_dusttodust") # Demonheart
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault",
		false, false, [2], [0])
	assert_eq(player1.bonus_armor_counters, 0) # reset at cleanup

## ===== CHAOS SCISSORS TESTS =====
## R1-2 P8 S5 A0 G0, Gauge cost 2. Stun Immunity. Hit: take 3 self damage.

func test_chaos_scissors_stun_immune_self_damage():
	position_players(player1, 4, player2, 5)
	var gauge_ids = give_gauge(player1, 2)
	# CS(S5) vs Grasp(S7). Grasp first. R1, dist1. P3 hit p1.
	# Stun check: 3>G0→would stun, but CS stun immunity → NOT stunned.
	# Grasp hit: push1 (index 0). p1: 4→3. dist=|3-5|=2.
	# CS: R1-2, dist2. In range. P8 hit. p2: 15-8=7.
	# CS hit: take_damage 3 (self). p1: 15-3-3=9.
	var cs_id = give_player_specific_card(player1, "taisei_chaosscissors")
	execute_strike(player1, player2, cs_id, "standard_normal_grasp",
		false, false,
		[0, gauge_ids], # ability pass, pay gauge cost
		[0, 0])         # ability pass, Grasp hit: push1
	validate_life(player1, 9, player2, 7)

func test_chaos_scissors_self_kill():
	position_players(player1, 4, player2, 5)
	player1.life = 3
	var gauge_ids = give_gauge(player1, 2)
	# CS(S5) vs Assault(S5). Initiator first. CS R1-2, dist1. P8 hit.
	# p2: 15-8=7. Stunned. CS hit: take_damage 3 (self).
	# p1: 3-3=0 → trigger_game_over (bypasses on_death).
	var cs_id = give_player_specific_card(player1, "taisei_chaosscissors")
	execute_strike(player1, player2, cs_id, "standard_normal_assault",
		false, false,
		[0, gauge_ids], # ability pass, pay gauge cost
		[0])            # ability pass
	assert_eq(game_logic.game_state, Enums.GameState.GameState_GameOver)
	assert_eq(game_logic.game_over_winning_player, player2)

## ===== DEMONBLOOD BOOST TESTS =====
## Continuous (from Chaos Scissors).
## Now: choice [spend 3 life→transform from hand/deck, pass]. Hit: gain 2 life.

func test_demonblood_transform_from_hand():
	position_players(player1, 4, player2, 5)
	var transform_target_id = give_player_specific_card(player1, "taisei_anathemasurge")
	var boost_id = give_player_specific_card(player1, "taisei_chaosscissors")
	assert_true(game_logic.do_boost(player1, boost_id))
	# Now choice: spend 3 life + transform (0) or pass (1).
	assert_true(game_logic.do_choice(player1, 0)) # spend 3 life
	# Pick transform card from hand.
	assert_true(game_logic.do_boost(player1, transform_target_id))
	validate_life(player1, 12, player2, 15) # 15-3=12
	var found_transform = false
	for card in player1.transforms:
		if card.definition['id'] == "taisei_anathemasurge":
			found_transform = true
			break
	assert_true(found_transform, "Anathema Surge should be a transform")

func test_demonblood_hit_gain_life():
	position_players(player1, 4, player2, 5)
	player1.life = 10
	var boost_id = give_player_specific_card(player1, "taisei_chaosscissors")
	assert_true(game_logic.do_boost(player1, boost_id))
	assert_true(game_logic.do_choice(player1, 1)) # pass on now choice
	advance_turn(player2)

	# Demonblood hit: gain 2 life. Assault hit: gain_advantage.
	# Two hit effects → ChooseSimultaneousEffect.
	# Assault(S5) vs Assault(S5). Initiator first. P4 hit. p2: 15-4=11. Stunned.
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault",
		false, false,
		[0, 0], # ability pass, simultaneous hit order: 0
		[0])    # ability pass
	validate_life(player1, 12, player2, 11)

## ===== NIGHTMARE TARES TESTS =====
## R2-5 P5 S1 A2 G0, Gauge cost 2. Stun Immunity. Cannot go below 1 life.
## After: gain life equal to damage dealt.

func test_nightmare_tares_stun_immune_life_floor():
	position_players(player1, 3, player2, 5)
	player1.life = 5
	var gauge_ids = give_gauge(player1, 2)
	# NT(S1) vs Sweep(S2). Sweep first. R1-3, dist2. P6 vs NT A2=4 damage.
	# p1: 5-4=1. Stun immunity. Not stunned.
	# NT R2-5, dist2. P5 hit. p2: 15-5=10. After: gain life = 5. p1: 1+5=6.
	var nt_id = give_player_specific_card(player1, "taisei_nightmaretares")
	execute_strike(player1, player2, nt_id, "standard_normal_sweep",
		false, false,
		[0, gauge_ids], # ability pass, pay gauge cost
		[0])            # ability pass
	validate_life(player1, 6, player2, 10)

func test_nightmare_tares_gain_life_damage_dealt():
	position_players(player1, 3, player2, 5)
	player1.life = 15
	var gauge_ids = give_gauge(player1, 2)
	# NT(S1) vs Block(S0). NT first. R2-5, dist2. P5 vs A2=3 damage. Hit.
	# After: gain life = damage dealt = 3. p1: 15+3=18.
	var nt_id = give_player_specific_card(player1, "taisei_nightmaretares")
	execute_strike(player1, player2, nt_id, "standard_normal_block",
		false, false,
		[0, gauge_ids], # ability pass, pay gauge cost
		[0, []])        # ability pass, ForceForArmor
	validate_life(player1, 18, player2, 12)

func test_nightmare_tares_cannot_die_during_strike():
	position_players(player1, 3, player2, 5)
	player1.life = 2
	var gauge_ids = give_gauge(player1, 2)
	# NT cannot_go_below_life 1 during strike.
	# Sweep(S2) first. P6 vs A2=4 damage. p1: 2-4→clamped to 1.
	# Not stunned (stun immunity). NT: P5 hit. After: gain 5 life. p1: 1+5=6.
	var nt_id = give_player_specific_card(player1, "taisei_nightmaretares")
	execute_strike(player1, player2, nt_id, "standard_normal_sweep",
		false, false,
		[0, gauge_ids], # ability pass, pay gauge cost
		[0])            # ability pass
	validate_life(player1, 6, player2, 10)

## ===== FALSE LIFE BOOST TESTS =====
## Continuous (from Nightmare Tares). During: opponent +4 Power. Now: gain 4 life, draw 2.

func test_false_life_opponent_power_gain_life_draw():
	position_players(player1, 4, player2, 5)
	player1.life = 10
	var boost_id = give_player_specific_card(player1, "taisei_nightmaretares")
	assert_true(game_logic.do_boost(player1, boost_id))
	# Now: gain 4 life → 14, draw 2.
	validate_life(player1, 14, player2, 15)
	# Handle discard to max if needed
	if game_logic.game_state == Enums.GameState.GameState_DiscardDownToMax:
		handle_discard_to_max(player1)
	advance_turn(player2)

	# Strike with False Life active. Opponent (p2) gets +4 Power.
	# Block(S0) vs Assault(S5). Assault first. Before: close 2 (adj).
	# p2: P4+4=8 vs Block A2=6 damage. p1: 14-6=8. Stun: 6>G3→yes.
	execute_strike(player1, player2, "standard_normal_block", "standard_normal_assault",
		false, false,
		[0, []], # ability pass, ForceForArmor 0 cards
		[0])     # ability pass
	validate_life(player1, 8, player2, 15)

## ===== INTERACTION TESTS =====

func test_demonheart_with_ability_counters():
	# Demonheart + ability: spending 2 life via ability triggers on_spend_life.
	position_players(player1, 4, player2, 5)
	add_transform(player1, "taisei_dusttodust") # Demonheart
	# p1 ability: spend 2 life (choice 2). Demonheart: counter → +armor during.
	# Assault(S5) vs Assault(S5). Initiator first.
	# P4+2=6. R1, dist1. Hit. p2: 15-6=9. Stunned.
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault",
		false, false,
		[2], # p1 ability: spend 2 life
		[0]) # p2 ability: pass
	validate_life(player1, 13, player2, 9)
	assert_eq(player1.bonus_armor_counters, 0) # reset at cleanup

func test_demonhide_with_demonheart():
	# Demonhide after: spend 2 life triggers Demonheart on_spend_life.
	# Counter increments but armor already applied. Resets at cleanup.
	position_players(player1, 4, player2, 5)
	add_transform(player1, "taisei_dusttodust") # Demonheart
	var boost_id = give_player_specific_card(player1, "taisei_blackvolt")
	assert_true(game_logic.do_boost(player1, boost_id))
	advance_turn(player2)

	# p1 ability: spend 1 life → +1P. Demonheart: +1 counter.
	# During: Demonhide +3A + Demonheart +1A (counter) = +4A total.
	# Sweep(S2) vs Assault(S5). Assault first. Before: close 2 (adj).
	# P4 vs A4=0 damage. Stun: 0>G6? No. Not stunned.
	# Sweep: R1-3, dist1. P6+1=7 hit. p2: 15-7=8.
	# Demonhide after: return to hand (choice 0, spend 2 life).
	# p1: 15-1(ability)-0(Assault blocked)-2(Demonhide return)=12.
	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_assault",
		false, false,
		[1, 0], # ability: spend 1 life, Demonhide after: return to hand
		[0])    # ability pass
	validate_life(player1, 12, player2, 8)
	assert_eq(player1.bonus_armor_counters, 0) # reset at cleanup

## ===== DEMONHIDE ARMOR REVERTED ON RETURN =====
## When Demonhide is returned to hand, the during_strike armorup is reverted
## (disable_boost_effects undoes it). Card2 hits without armor protection.

func test_demonhide_return_reverts_armor():
	# p1 is Card1 (faster). Demonhide gives +3A during_strike.
	# p1 returns Demonhide during Card1_After → armor reverted to 0.
	# Card2 (p2 Sweep) hits without armor.
	position_players(player1, 4, player2, 5)
	var boost_id = give_player_specific_card(player1, "taisei_blackvolt")
	assert_true(game_logic.do_boost(player1, boost_id))
	advance_turn(player2)

	# Assault(S5) vs Sweep(S2). Assault faster → p1 is Card1.
	# Card1 (p1 Assault): Before close 2 (adj). R1, dist1, hits.
	#   P4 vs A0 = 4 dmg. p2: 15-4=11. Stun: 4>G6? No.
	# Card1_After: Demonhide after: return (0, spend 2 life). p1: 15-2=13.
	#   Armor reverted: strike_stat_boosts.armor back to 0.
	# Card2 (p2 Sweep): R1-3, dist1. P6 vs A0 = 6 dmg. p1: 13-6=7.
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_sweep",
		false, false,
		[0, 0], # ability pass, Demonhide after: return to hand
		[0])    # ability pass
	validate_life(player1, 7, player2, 11)
	var found = false
	for card in player1.hand:
		if card.definition['id'] == "taisei_blackvolt":
			found = true
			break
	assert_true(found, "Blackvolt should be back in hand")

## ===== EXCEEDED TAISEI LOSES STARTING ABILITY =====

func test_exceeded_no_ability_choice():
	# When exceeded, Taisei should NOT get the spend-life-for-power choice.
	position_players(player1, 4, player2, 5)
	var gauge = give_gauge(player1, 5)
	assert_true(game_logic.do_exceed(player1, gauge))
	assert_true(game_logic.do_choice(player1, 0)) # gain 10 life → 25
	advance_turn(player2)

	# Strike with no ability choice. If ability still fires, init_choices
	# would need [0] for the choice, and the test would fail.
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault",
		false, false,
		[], # NO ability choice — exceeded Taisei has no set_strike ability
		[0]) # p2 ability pass
	# p1 Assault(S5) vs p2 Assault(S5). Same speed, p1 initiator = Card1.
	# P4 hits p2: 15-4=11. Stun: 4>G0? Yes, stunned.
	validate_life(player1, 25, player2, 11)

## ===== DEMONHEART LATE SPEND: ARMOR REVERTED ON RETURN =====
## The Demonhide return reverts its during_strike armorup. Meanwhile,
## Demonheart counter increments from life spend but was already 0 at DuringStrikeBonuses.
## Net result: no armor protects Card2's damage.

func test_demonheart_late_spend_no_retroactive_armor():
	position_players(player1, 4, player2, 5)
	add_transform(player1, "taisei_dusttodust") # Demonheart
	var boost_id = give_player_specific_card(player1, "taisei_blackvolt")
	assert_true(game_logic.do_boost(player1, boost_id))
	advance_turn(player2)

	# p1 ability: pass (0 life spent). No Demonheart counter.
	# During: Demonhide +3A, Demonheart +0A. Total A=3.
	# Assault(S5) vs Sweep(S2). Assault faster (p1 is Card1).
	# Card1: P4 vs A0 = 4 dmg. p2: 15-4=11. Not stunned (4<G6).
	# Card1_After: Demonhide return (choice 0, spend 2 life). p1: 15-2=13.
	#   Armor reverted: A3 → A0 (disable_boost_effects reverses armorup).
	#   on_spend_life → Demonheart counter = 1 (but armor already reverted).
	# Card2 (Sweep): P6 vs A0 = 6 dmg. p1: 13-6=7.
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_sweep",
		false, false,
		[0, 0], # ability pass, Demonhide after: return
		[0])    # ability pass
	validate_life(player1, 7, player2, 11)
	assert_eq(player1.bonus_armor_counters, 0) # reset at cleanup
