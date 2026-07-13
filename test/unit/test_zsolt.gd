extends ExceedGutTest

## ==========================================================================
## Zsolt (Seventh Cross, Season 2) test suite.
##
## Character summary
## -----------------
## Exceed cost: 5, reduced by 2 per transform in the transform zone
##   (transform_discount). Difficulty ****.
##
## Default ability (non-exceeded passive):
##   Whenever a Zsolt *normal* attack hits, he may Advance 1, Retreat 1, or
##   Pass (ZsoltNormalChoice, appended to the normal's hit effects).
##
## Exceeded ability ("Awakening" / extra attack):
##   After a strike in which Zsolt hit, he may pay 1 Force to perform an extra
##   attack from hand. That extra attack deals at most 1 damage (before armor)
##   and its cost is skipped. Up to two extra attacks per turn.
##
## Cards (see data/decks/zsolt.json / card_definitions.json):
##   Fatal Eye    R1-3 P1 S7. before: +1 Power per transform (max 5). hit: gain advantage.
##   Cross Up     R1-2 P4 S6. after: advance 4.
##   Blaze        R2-4 P4 S5. hit: advance 3; if advanced-through, gain advantage.
##   Whip Crack   R2-4 P3 S4. hit: choice push/pull 1. after: choice advance/retreat 1.
##   Gunblaze     R1-4 P3 S2 G6. before(if was_hit): choice +2 Power / draw 2. hit: close 3.
##   Fanatical P. R1-1 P6 S4 (ultra, gauge 3). before: close 3. hit: push 2 + gain advantage.
##   Wild Hunt    R1-1 P5 S3 (ultra, gauge 3). before: close 8 (save spaces as X), +X Power. after: advance 9.
##
## Transforms (the boost side of each special):
##   Somersault (Fatal Eye)          immediate: choice advance/retreat 2, then draw 1.
##   Battle Fugue (Cross Up)         first time gaining Advantage each combat: draw 1.
##   Mad Dog (Blaze)                 set_strike(initiated): pay up to 1 Force -> +1 Power each.
##   Press the Attack (Whip Crack)   set_strike(initiated): pay up to 1 Force -> +1 Speed each.
##   Seeing Red (Gunblaze)           immediate: life-based draw + bonus action if life<=5.
##   Battle Instinct (Fanatical P.)  continuous (now): +2 Force pool + reduce gauge costs by 2 (tested).
##   Heightened Reflexes (Wild Hunt) immediate: choice advance/retreat 1, then bonus action.
##
## NOTE: The opponent for this suite is Ryu (a non-Zsolt character) so that the
## opponent never triggers Zsolt's own normal-hit passive. Ryu's set_strike
## ability requires gauge to fire; with 0 gauge it produces no decisions.
##
## Standard normals reference (shared deck):
##   Grasp R1 P3 S7. hit: choice push/pull 1-2.
##   Cross R1-2 P3 S6. after: retreat 3.
##   Assault R1 P4 S5. before: close 2. hit: gain advantage.
##   Dive R1 P5 S4. before: advance 3 (dodge if advanced through).
##   Spike R2-3 P5 S3 G4. during: ignore armor and guard.
##   Sweep R1-3 P6 S2 G6. hit: opponent discards 1 random.
##   Focus R1-2 P4 S1 A2 G5. during: ignore push/pull. after: draw 1.
##   Block R-1(miss) P0 S0 A2 G3. during: ForceForArmor(2).
## ==========================================================================

func who_am_i():
	return "zsolt"

func before_each():
	default_game_setup("ryu")
	gut.p("ran setup", 2)

# ===== BASIC / SETUP =====

func test_starting_life():
	assert_eq(player1.life, 30)
	assert_eq(player2.life, 30)

func test_exceed_cost_default():
	assert_eq(player1.get_exceed_cost(), 5)

func test_exceed_cost_with_one_transform():
	add_transform(player1, "zsolt_blaze_of_fervour")
	# 5 - 2*1 = 3
	assert_eq(player1.get_exceed_cost(), 3)

func test_exceed_cost_with_two_transforms():
	add_transform(player1, "zsolt_blaze_of_fervour")
	add_transform(player1, "zsolt_whip_crack")
	# 5 - 2*2 = 1
	assert_eq(player1.get_exceed_cost(), 1)

func test_battle_instinct_force_pool():
	# Battle Instinct (Fanatical Purification continuous boost, active from transform):
	#   now -> generate_free_force +2 (zsolt_force_pool)
	#   now -> gauge_costs_reduced_passive +2 (free_gauge)
	# Play it as a continuous boost (from hand) — same "now" effects as transform.
	var boost_id = give_player_specific_card(player1, "zsolt_fanatical_purification")
	var force_ids = give_gauge(player1, 1)
	assert_true(game_logic.do_boost(player1, boost_id, force_ids))
	# zsolt_force_pool should be 2.
	assert_eq(player1.zsolt_force_pool, 2,
		"Battle Instinct should create 2 force pool")
	# Exceed cost: 5 (base) - 2 (free_gauge from Battle Instinct) = 3
	assert_eq(player1.get_exceed_cost(), 3,
		"Battle Instinct should reduce exceed cost by 2 (free_gauge)")
	# free_gauge = 2 (from gauge_costs_reduced_passive) reduces gauge costs.
	assert_eq(player1.free_gauge, 2,
		"Battle Instinct should set free_gauge to 2")
	# The 2 force pool (zsolt_force_pool) is consumed via UI popup during
	# PickAction or auto-set to free_force during strike resolution (game.gd).

# ===== DEFAULT PASSIVE: normal hit -> advance/retreat/pass =====

func test_normal_passive_advance():
	position_players(player1, 6, player2, 8)
	# Zsolt Cross(S6) vs Dive(S4). Cross first. dist2, R1-2 hit. P3>G0 -> stun, Dive skipped.
	# Cross hit: only Zsolt passive choice. Advance 1: p1 6->7. Cross after retreat 3: 7->4.
	execute_strike(player1, player2, "standard_normal_cross", "standard_normal_dive",
		false, false,
		[0],  # passive: advance 1
		[])
	validate_positions(player1, 4, player2, 8)
	validate_life(player1, 30, player2, 27)

func test_normal_passive_retreat():
	position_players(player1, 6, player2, 8)
	# Retreat 1: p1 6->5. Cross after retreat 3: 5->2.
	execute_strike(player1, player2, "standard_normal_cross", "standard_normal_dive",
		false, false,
		[1],  # passive: retreat 1
		[])
	validate_positions(player1, 2, player2, 8)
	validate_life(player1, 30, player2, 27)

func test_normal_passive_pass():
	position_players(player1, 6, player2, 8)
	# Pass. Cross after retreat 3: 6->3.
	execute_strike(player1, player2, "standard_normal_cross", "standard_normal_dive",
		false, false,
		[2],  # passive: pass
		[])
	validate_positions(player1, 3, player2, 8)
	validate_life(player1, 30, player2, 27)

func test_normal_passive_not_on_special():
	position_players(player1, 2, player2, 5)
	# Zsolt Whip Crack (special) at dist3 (R2-4) hits. No Zsolt normal-passive choice appears.
	# WC(S4) vs Spike(S3). WC first. P3 vs G4 not stunned. WC hit dmg 3 -> p2 27.
	# hit: pull 1 (idx1): p2 5->4. after: retreat 1 (idx1): p1 2->1.
	# WC has a transform boost (Press the Attack) and it hit -> transform_attack offer: pass (idx1).
	# Spike(S3) then R2-3 from p1@1 p2@4 dist3 -> hit. p1: 30-5=25.
	execute_strike(player1, player2, "zsolt_whip_crack", "standard_normal_spike",
		false, false,
		[1, 1, 1],  # WC hit pull 1; WC after retreat 1; transform offer: pass (NO normal passive)
		[])
	validate_positions(player1, 1, player2, 4)
	validate_life(player1, 25, player2, 27)

# ===== FATAL EYE: +1 Power per transform (max 5), hit gain advantage =====

func test_fatal_eye_no_transforms():
	position_players(player1, 4, player2, 5)
	# Fatal Eye R1-3 P1 S7. before +0. FE(S7) vs Dive(S4). FE first. dist1 hit. P1>G0 stun.
	# p2: 30-1=29. hit: gain advantage.
	execute_strike(player1, player2, "zsolt_fatal_eye", "standard_normal_dive",
		false, false,
		[],
		[])
	validate_life(player1, 30, player2, 29)
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_Strike_GainAdvantage, player1)

func test_fatal_eye_three_transforms():
	position_players(player1, 4, player2, 5)
	# Safe transforms (no set_strike decision).
	add_transform(player1, "zsolt_cross_up")
	add_transform(player1, "zsolt_gunblaze")
	add_transform(player1, "zsolt_wild_hunt")
	# before: +3 Power. P1+3=4. p2: 30-4=26.
	execute_strike(player1, player2, "zsolt_fatal_eye", "standard_normal_dive",
		false, false,
		[],
		[])
	validate_life(player1, 30, player2, 26)

func test_fatal_eye_three_transforms_max():
	position_players(player1, 4, player2, 5)
	# Zsolt's transform zone can hold at most 3 different cards (same-name
	# transforms are not allowed). With 3 transforms, Fatal Eye gets +3P.
	add_transform(player1, "zsolt_cross_up")    # Battle Fugue
	add_transform(player1, "zsolt_gunblaze")    # Seeing Red
	add_transform(player1, "zsolt_wild_hunt")   # Heightened Reflexes
	# Cross Up and Wild Hunt have no set_strike cost, Gunblaze neither.
	# 3 transforms → before: +3P. P1+3=4. p2: 30-4=26.
	execute_strike(player1, player2, "zsolt_fatal_eye", "standard_normal_dive",
		false, false,
		[],
		[])
	validate_life(player1, 30, player2, 26)

# ===== CROSS UP: after advance 4 =====

func test_cross_up_after_advance():
	position_players(player1, 3, player2, 5)
	# CU R1-2 P4 S6 vs Dive(S4). CU first. dist2 hit. P4 vs G0 -> stun, Dive skipped.
	# p2: 30-4=26. CU after: advance 4 moves THROUGH opponent, landing at space 8.
	# CU has a transform boost (Battle Fugue) and it hit -> transform_attack offer: pass (idx0 order? pass=idx1).
	execute_strike(player1, player2, "zsolt_cross_up", "standard_normal_dive",
		false, false,
		[1],  # transform offer: pass
		[])
	validate_positions(player1, 8, player2, 5)
	validate_life(player1, 30, player2, 26)

# ===== BLAZE OF FERVOUR: hit advance 3; advanced-through -> gain advantage =====

func test_blaze_advance_no_advantage():
	position_players(player1, 1, player2, 5)
	# Blaze R2-4 P4 S5 vs Spike(S3). Blaze first. dist4 hit. P4 vs G4 not stunned.
	# hit: advance 3 toward opp: 1->4, stops adjacent (NOT through) -> no advantage. p2: 30-4=26.
	# Blaze is a transform boost (Mad Dog) and it hit -> transform offer: pass.
	# Spike responds from p1@4 p2@5 dist1: Spike R2-3 -> MISS. p1 stays 30.
	execute_strike(player1, player2, "zsolt_blaze_of_fervour", "standard_normal_spike",
		false, false,
		[1],  # transform offer: pass
		[])
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 30, player2, 26)
	var events = game_logic.get_latest_events()
	validate_not_has_event(events, Enums.EventType.EventType_Strike_GainAdvantage, player1)

func test_blaze_advance_through_gains_advantage():
	position_players(player1, 3, player2, 5)
	# Blaze R2-4 vs Dive(S4). Blaze first. dist2 hit. P4 vs G0 -> stun, Dive skipped.
	# hit: advance 3 passes THROUGH opponent (3->4->skip5->7) -> gain advantage. p2: 30-4=26.
	# transform offer: pass.
	execute_strike(player1, player2, "zsolt_blaze_of_fervour", "standard_normal_dive",
		false, false,
		[1],  # transform offer: pass
		[])
	validate_positions(player1, 7, player2, 5)
	validate_life(player1, 30, player2, 26)
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_Strike_GainAdvantage, player1)

# ===== WHIP CRACK: hit push/pull 1, after advance/retreat 1 =====

func test_whip_crack_push_and_advance():
	position_players(player1, 2, player2, 5)
	# WC(S4) vs Spike(S3). WC first. dist3 R2-4 hit. P3 vs G4 not stunned.
	# hit: push 1 (idx0): p2 5->6. after: advance 1 (idx0): p1 2->3.
	# Spike R2-3 from p1@3 p2@6 dist3 hit. p1: 30-5=25.
	execute_strike(player1, player2, "zsolt_whip_crack", "standard_normal_spike",
		false, false,
		[0, 0, 1],  # hit push 1, after advance 1, transform offer: pass
		[])
	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 25, player2, 27)

# ===== GUNBLAZE: before(if was_hit) choice +2P/draw2, hit close 3 =====

func test_gunblaze_before_power_when_was_hit():
	position_players(player1, 4, player2, 5)
	# Gunblaze R1-4 P3 S2 G6 vs Ryu Grasp(R1 P3 S7). Grasp faster -> card1.
	# Grasp hits Zsolt first: p1 not stunned (G6). Grasp hit push 1: p2's choice.
	# p1: 30-3=27. p2 grasp push 1: p1 4->3.
	# Gunblaze before: was_hit -> +2 Power (idx0). hit: close 3. dist now 2.
	# Gunblaze R1-4 hit p2: P3+2=5. p2: 30-5=25.
	execute_strike(player1, player2, "zsolt_gunblaze", "standard_normal_grasp",
		false, false,
		[0],   # Gunblaze before: +2 Power
		[0])   # Grasp hit: push 1
	validate_life(player1, 27, player2, 25)

func test_gunblaze_before_draw_when_was_hit():
	position_players(player1, 4, player2, 5)
	var hand_before = player1.hand.size()
	# Same as above but Gunblaze before: draw 2 (idx1). Power stays 3. p2: 30-3=27.
	execute_strike(player1, player2, "zsolt_gunblaze", "standard_normal_grasp",
		false, false,
		[1],   # Gunblaze before: draw 2
		[0])   # Grasp hit: push 1
	validate_life(player1, 27, player2, 27)
	# +2 from draw; gunblaze itself is added then played (net 0 for that card).
	assert_eq(player1.hand.size(), hand_before + 2)

# ===== ULTRAS =====

func test_fanatical_purification():
	position_players(player1, 1, player2, 5)
	var gauge_ids = give_gauge(player1, 3)
	# FP R1-1 P6 S4 (gauge 3) vs Spike(S3). FP first. before: close 3: p1 1->4 (adjacent).
	# dist1 hit. P6 vs G4 -> stunned. p2: 30-6=24. hit: push 2 + advantage.
	execute_strike(player1, player2, "zsolt_fanatical_purification", "standard_normal_spike",
		false, false,
		[gauge_ids],   # pay 3 gauge
		[])
	validate_life(player1, 30, player2, 24)
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_Strike_GainAdvantage, player1)

func test_wild_hunt_power_scales_with_distance():
	position_players(player1, 1, player2, 9)
	var gauge_ids = give_gauge(player1, 3)
	# WH R1-1 P5 S3 (gauge 3) vs Spike(S3) tie -> initiator first.
	# before: close 8: p1 1->8 (moved 7, adjacent), +7 Power. dist1 hit. P5+7=12.
	# p2: 30-12=18. Stunned. after: advance 9.
	execute_strike(player1, player2, "zsolt_wild_hunt", "standard_normal_spike",
		false, false,
		[gauge_ids],   # pay 3 gauge
		[])
	validate_life(player1, 30, player2, 18)

# ===== SEEING RED (Gunblaze immediate boost): life-based draw + bonus action =====

func test_seeing_red_draw_low_life():
	# Seeing Red (Gunblaze immediate boost, 0 Force): life 1 → draw 6 cards.
	position_players(player1, 4, player2, 5)
	player1.life = 1
	var hand_before = player1.hand.size()
	var boost_id = give_player_specific_card(player1, "zsolt_gunblaze")
	assert_true(game_logic.do_boost(player1, boost_id))
	# Life 1 → draw 6 cards. boost consumed. hand = before + 6
	assert_eq(player1.hand.size(), hand_before + 6,
		"Life 1 should draw 6 cards from Seeing Red")

func test_seeing_red_draw_mid_life():
	# Seeing Red at life 16 → draw 2 cards.
	position_players(player1, 4, player2, 5)
	player1.life = 16
	var hand_before = player1.hand.size()
	var boost_id = give_player_specific_card(player1, "zsolt_gunblaze")
	assert_true(game_logic.do_boost(player1, boost_id))
	# Life 16 hand increased significantly (draw based on life condition).
	assert_gt(player1.hand.size(), hand_before,
		"Hand should increase after Seeing Red at life 16")

# ===== TRANSFORMS (boost side, active while in transform zone) =====

func test_mad_dog_powerup():
	position_players(player1, 4, player2, 5)
	add_transform(player1, "zsolt_blaze_of_fervour")  # Mad Dog: set_strike(initiated) pay 1F -> +1P
	var force_card = give_player_specific_card(player1, "standard_normal_grasp")
	# Zsolt Cross(S6) vs Dive(S4). Cross first. Mad Dog: spend 1 force -> +1P.
	# dist1 hit. P3+1=4 > G0 -> stun. p2: 30-4=26. Cross hit: passive (pass). after retreat 3.
	execute_strike(player1, player2, "standard_normal_cross", "standard_normal_dive",
		false, false,
		[[force_card], 2],  # Mad Dog: spend 1 force; passive: pass
		[])
	validate_life(player1, 30, player2, 26)
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_Strike_PowerUp, player1)

func test_press_the_attack_speedup():
	position_players(player1, 4, player2, 5)
	add_transform(player1, "zsolt_whip_crack")  # Press the Attack: set_strike(initiated) pay 1F -> +1 Speed
	var force_card = give_player_specific_card(player1, "standard_normal_grasp")
	# Zsolt Cross(S6, +1 = S7) vs Dive(S4). Cross first. dist1 hit. P3>G0 stun. p2: 30-3=27.
	execute_strike(player1, player2, "standard_normal_cross", "standard_normal_dive",
		false, false,
		[[force_card], 2],  # Press: spend 1 force; passive: pass
		[])
	validate_life(player1, 30, player2, 27)
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_Strike_SpeedUp, player1)

func test_battle_fugue_draw_on_first_advantage():
	position_players(player1, 4, player2, 5)
	add_transform(player1, "zsolt_cross_up")  # Battle Fugue: first advantage per combat -> draw 1
	var hand_before = player1.hand.size()
	# Zsolt Fatal Eye (special, so no normal passive). before +1P (1 transform). hit: gain advantage.
	# FE(S7) vs Dive(S4). FE first. P1+1=2 > G0 -> stun. p2: 30-2=28.
	# Gaining advantage triggers Battle Fugue draw 1.
	execute_strike(player1, player2, "zsolt_fatal_eye", "standard_normal_dive",
		false, false,
		[],
		[])
	# Net: fatal_eye added(+1) then played(-1); Battle Fugue draw(+1). => +1.
	assert_eq(player1.hand.size(), hand_before + 1)
	validate_life(player1, 30, player2, 28)

# ===== EXCEEDED: extra attack (Awakening) =====

func test_exceed_extra_attack_hits():
	position_players(player1, 4, player2, 5)
	player1.exceeded = true
	var extra_atk = give_player_specific_card(player1, "standard_normal_cross")
	var gauge_ids = give_gauge(player1, 1)
	# Zsolt Assault(S5) vs Dive(S4). Assault first, hits (P4>G0), Dive stunned/skipped.
	# Exceeded -> no normal passive. p2: 30-4=26. Assault hit: gain advantage (auto).
	# Awakening #1: pay 1 force (ForceForEffect) -> play an attack from hand (ChooseToDiscard).
	# Extra Cross deals max 1 damage: p2 26-1=25. Then Awakening #2 offered: decline.
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_dive",
		false, false,
		[[gauge_ids[0]], [extra_atk], []],  # awaken1 pay force, choose Cross, awaken2 decline
		[])
	validate_life(player1, 30, player2, 25)

func test_exceed_two_extra_attacks():
	position_players(player1, 4, player2, 5)
	player1.exceeded = true
	var extra1 = give_player_specific_card(player1, "standard_normal_assault")
	var extra2 = give_player_specific_card(player1, "standard_normal_assault")
	var gauge_ids = give_gauge(player1, 2)
	# Two Awakening attacks (Assault: R1, close-2 keeps adjacent, no self-move on hit),
	# each dealing max 1. p2: 30-4 (Assault) -1 -1 = 24.
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_dive",
		false, false,
		[[gauge_ids[0]], [extra1], [gauge_ids[1]], [extra2]],  # awaken1, choose; awaken2, choose
		[])
	validate_life(player1, 30, player2, 24)

func test_exceed_extra_attack_declined():
	position_players(player1, 4, player2, 5)
	player1.exceeded = true
	give_gauge(player1, 1)
	# Decline the extra attack (spend no force).
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_dive",
		false, false,
		[[]],  # awaken: decline
		[])
	validate_life(player1, 30, player2, 26)

# ===== TRANSFORMING AN ATTACK (choosing transform_attack) =====

func test_transform_attack_adds_to_transform_zone():
	position_players(player1, 3, player2, 5)
	assert_eq(player1.transforms.size(), 0)
	assert_eq(player1.get_exceed_cost(), 5)
	# Cross Up hits Dive (stun). On hit with a transform boost, choose transform_attack (idx0).
	execute_strike(player1, player2, "zsolt_cross_up", "standard_normal_dive",
		false, false,
		[0],  # transform offer: transform the attack
		[])
	assert_eq(player1.transforms.size(), 1)
	# Exceed cost drops by 2 per transform: 5 - 2 = 3.
	assert_eq(player1.get_exceed_cost(), 3)
	validate_life(player1, 30, player2, 26)
