extends ExceedGutTest

## ==========================================================================
## Eugenia (Alice / Wonderland, Season 2) test suite.
##
## Character summary
## -----------------
## Exceed cost: 6, reduced by 2 per transform (transform_discount). Difficulty ***.
## Buddy/set-aside zone: "Wonderland". On exceed, a Wonderland card is placed in
## the set-aside zone and marked as Eugenia's face attack.
##
## Default ability (non-exceeded passive):
##   Once per turn, when one of Eugenia's effects makes the opponent discard, she
##   may reveal a card in her hand whose PRINTED speed matches a discarded card's
##   printed speed. If she does, she deals 2 non-lethal damage.
##   (local_game.gd _on_player_discard; RevealSingleCard + nonlethal TakeDamage.)
##
## Exceeded ability:
##   When an Eugenia effect makes the opponent discard, she may add one of the
##   discarded cards to Wonderland (set-aside). (The normal reveal passive does
##   NOT fire while exceeded.)
##
## Wonderland face attack:
##   While exceeded, Eugenia may strike with the Wonderland face attack (only once
##   at least one real card has been added to Wonderland). It gains +1 Power and
##   +1 Speed (WonderlandPowerBonus / WonderlandSpeedBonus). The Wonderland card
##   itself also has during_strike +1P/+1S, so the exceeded face attack is P2/S2.
##
## Cards (data/decks/eugenia.json / card_definitions.json):
##   Shimmer of Madness R1-2 P2 S6. hit: reveal opp hand, choose 1 opp card to discard.
##   Absinthin Arrow    R3-6 P2 S5. hit: opp draws 1, then discards 2 random.
##   Plot Hook          R1-5 P3 S4 G3. hit: gain advantage, pull 5.
##   Werelight          R2-4 P4 S3 G5. hit: opp chooses (discard 2 random / reveal+Eugenia discards 1).
##   Color Spray        R1-3 P6 S2. during: stun immunity if hand<=2. hit: opp draw-or-discard to 2 (random).
##   Queen of Hearts    R1-1 P1 S7 (ultra, gauge 3). hit: opp discards hand, opp draws 1, +Power.
##   Cat's Cradle       R1-3 P9 S1 (ultra, gauge 3). during: stun immunity, -1 Power per card in opp hand.
##                                    hit: opp draws 1, discards 2 random.
##
## Transforms (boost side):
##   Hanging by a Thread (Shimmer, transform)  set_strike: add hit effect
##                                             "if opponent has <=2 cards: +2 Power".
##   We're All Mad Here (Absinthin, immediate) now: both players draw X then discard 1 random.
##   Time for Tea (Plot Hook, transform)       action: pay 1 Force -> opponent discards 1 random.
##   Off With Her Head (Werelight, immediate)  immediate: if range 1, opp chooses discard2 / push3.
##   Unhinged (Color Spray, transform)         set_strike: if EX or wild swing, add hit opp discard 1.
##   Wanderlust (Queen, immediate)             now: search deck for a transform / add to hand.
##   Edge of Sanity (Cat's Cradle, continuous) now: opp discards 1 random + reduce opp prepare draw.
##
## NOTE: The opponent is Ryu (a non-Eugenia character) so the opponent never
## triggers Eugenia's passives. When an Eugenia attack makes Ryu discard, her
## normal passive fires exactly once (Pass = choice index 0).
## ==========================================================================

func who_am_i():
	return "eugenia"

func before_each():
	default_game_setup("ryu")
	gut.p("ran setup", 2)

# ===== BASIC / SETUP =====

func test_starting_life():
	assert_eq(player1.life, 30)
	assert_eq(player2.life, 30)

func test_exceed_cost_default():
	assert_eq(player1.get_exceed_cost(), 6)

func test_exceed_cost_with_one_transform():
	add_transform(player1, "eugenia_plot_hook")
	assert_eq(player1.get_exceed_cost(), 4)  # 6 - 2*1

func test_exceed_cost_with_two_transforms():
	add_transform(player1, "eugenia_plot_hook")
	add_transform(player1, "eugenia_shimmer_of_madness")
	assert_eq(player1.get_exceed_cost(), 2)  # 6 - 2*2

# ===== PLOT HOOK: hit gain advantage + pull 5 (no discard -> no passive) =====

func test_plot_hook_pull_and_advantage():
	position_players(player1, 3, player2, 8)
	# Plot Hook R1-5 P3 S4 G3 vs Dive(S4). Tie -> initiator first. dist5 within R1-5 -> hit.
	# P3 vs Dive G0 -> stun, Dive skipped. p2: 30-3=27.
	# hit: gain advantage; pull 5 overshoots through Eugenia's space (8 -> skips 3 -> 2).
	# Plot Hook has a transform boost (Time for Tea) and it hit -> transform offer: pass (idx1).
	execute_strike(player1, player2, "eugenia_plot_hook", "standard_normal_dive",
		false, false,
		[1],  # transform offer: pass
		[])
	validate_positions(player1, 3, player2, 2)
	validate_life(player1, 30, player2, 27)
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_Strike_GainAdvantage, player1)

# ===== ABSINTHIN ARROW: hit opp draws 1 then discards 2 (triggers passive) =====

func test_absinthin_arrow_damage_and_discard():
	position_players(player1, 1, player2, 5)
	# Absinthin R3-6 P2 S5 at dist4 vs Grasp(R1). Grasp misses at dist4 (no counter).
	# Absinthin hits: p2 30-2=28. hit: opp draws 1, discards 2 random -> normal passive fires.
	# Absinthin boost is immediate (no transform offer). Passive: Pass (idx0).
	execute_strike(player1, player2, "eugenia_absinthin_arrow", "standard_normal_grasp",
		false, false,
		[0],  # normal passive: pass (don't reveal)
		[])
	validate_life(player1, 30, player2, 28)
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_AddToDiscard, player2)

# ===== SHIMMER OF MADNESS: choose an opponent card to discard =====

func test_shimmer_choose_discard():
	position_players(player1, 4, player2, 5)
	# Give the opponent a known card so we can direct the discard deterministically.
	var target = give_player_specific_card(player2, "standard_normal_spike")
	# Shimmer R1-2 P2 S6 vs Dive(S4). Shimmer faster. dist1 hit. P2 vs G0 -> stun. p2: 30-2=28.
	# hit: reveal opp hand + choose 1 opp card to discard (ChooseToDiscard -> [target]).
	# The discard triggers the normal passive: Pass (idx0).
	# Shimmer boost is a transform (Hanging by a Thread) and it hit -> transform offer: pass (idx1).
	execute_strike(player1, player2, "eugenia_shimmer_of_madness", "standard_normal_dive",
		false, false,
		[[target], 0, 1],  # choose opp card to discard; passive pass; transform pass
		[])
	validate_life(player1, 30, player2, 28)
	# The chosen card is now in the opponent's discard.
	var found = false
	for c in player2.discards:
		if c.id == target:
			found = true
	assert_true(found, "Target card should be in opponent discard")

# ===== WERELIGHT: opponent chooses discard mode =====

func test_werelight_opponent_discards():
	position_players(player1, 2, player2, 5)
	# Werelight R2-4 P4 S3 G5 at dist3 vs Grasp(R1). Grasp misses at dist3 (no counter).
	# Werelight hits: p2 30-4=26. hit: OPPONENT chooses discard 2 random (idx0) vs reveal.
	# Opponent picks discard 2 (def choice idx0) -> normal passive fires for Eugenia: pass (idx0).
	# Werelight boost is immediate (no transform offer).
	execute_strike(player1, player2, "eugenia_werelight", "standard_normal_grasp",
		false, false,
		[0],   # Eugenia normal passive: pass
		[0])   # opponent chooses discard 2 random
	validate_life(player1, 30, player2, 26)

# ===== COLOR SPRAY: hit opp draw-or-discard to 2 (random) =====

func test_color_spray_damage():
	position_players(player1, 3, player2, 5)
	# Color Spray R1-3 P6 S2 at dist2 vs Grasp(R1). Grasp misses at dist2 (no counter).
	# Color Spray hits: p2 30-6=24. hit: opp discards down to 2 random -> passive: pass (idx0).
	# Color Spray boost is a transform (Unhinged) and it hit -> transform offer: pass (idx1).
	execute_strike(player1, player2, "eugenia_color_spray", "standard_normal_grasp",
		false, false,
		[0, 1],  # passive pass; transform pass
		[])
	validate_life(player1, 30, player2, 24)

# ===== QUEEN OF HEARTS (ultra): opp discards hand =====

func test_queen_of_hearts_discard_hand():
	position_players(player1, 4, player2, 5)
	var gauge_ids = give_gauge(player1, 3)
	# Queen R1-1 P1 S7 (gauge 3) vs Dive(S4). Queen faster. dist1 hit. P1 vs G0 -> stun. p2: 30-1=29.
	# hit: opp discards hand -> passive fires: pass (idx0). Queen boost is immediate (no transform offer).
	execute_strike(player1, player2, "eugenia_queen_of_hearts", "standard_normal_dive",
		false, false,
		[gauge_ids, 0],  # pay gauge; passive pass
		[])
	validate_life(player1, 30, player2, 29)
	# The hit discards the opponent's hand (they then draw 1 fresh card).
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_AddToDiscard, player2)
	assert_eq(player2.hand.size(), 1)  # discarded hand, then drew 1

# ===== CAT'S CRADLE (ultra): power reduced per card in opponent hand =====

func test_cats_cradle_power_scales_with_opponent_hand():
	position_players(player1, 3, player2, 5)
	# Control the opponent's hand: exactly the Grasp defender, so after they set it,
	# their hand is empty and Cat's Cradle power is not reduced.
	player2.hand.clear()
	var def_id = give_player_specific_card(player2, "standard_normal_grasp")
	# Cat's Cradle R1-3 P9 S1 (gauge 3) at dist2 vs Grasp(R1) -> Grasp misses (no counter).
	# during: -1 Power per card in opp hand. Opp hand is 0 at damage time -> Power 9.
	# hit: opp draws 1, discards 2 random -> passive: pass (idx0).
	var gauge_ids = give_gauge(player1, 3)
	execute_strike(player1, player2, "eugenia_cats_cradle", def_id,
		false, false,
		[gauge_ids, 0],  # pay gauge; passive pass
		[])
	validate_life(player1, 30, player2, 21)  # 30 - 9

# ===== NORMAL PASSIVE: reveal matching printed speed -> 2 non-lethal damage =====

func test_normal_passive_reveal_deals_nonlethal_damage():
	position_players(player1, 4, player2, 5)
	# Control both hands so the passive is deterministic.
	# Opponent: a Dive defender + a Spike (printed speed 3) that Eugenia will discard.
	player2.hand.clear()
	give_player_specific_card(player2, "standard_normal_dive")  # defender
	var target = give_player_specific_card(player2, "standard_normal_spike")  # printed S3, in hand
	# Eugenia hand: the Shimmer strike card + exactly one card of printed speed 3 (Werelight S3).
	player1.hand.clear()
	var strike_card = give_player_specific_card(player1, "eugenia_shimmer_of_madness")
	give_player_specific_card(player1, "eugenia_werelight")  # printed S3 -> matches Spike
	# Shimmer R1-2 P2 S6 vs Dive(S4). Shimmer faster, dist1 hit. P2 vs G0 -> stun. p2: 30-2=28.
	# hit: choose to discard the Spike (S3). Passive: reveal Werelight (S3) -> 2 non-lethal: p2 28-2=26.
	execute_strike(player1, player2, strike_card, "standard_normal_dive",
		false, false,
		[[target], 1, 1],  # choose Spike to discard; passive: reveal match (idx1); transform: pass
		[])
	validate_life(player1, 30, player2, 26)

func test_normal_passive_pass_declines():
	position_players(player1, 4, player2, 5)
	# Same setup but Eugenia declines (Pass) -> no bonus damage. p2: 30-2=28.
	player2.hand.clear()
	give_player_specific_card(player2, "standard_normal_dive")  # defender
	var target = give_player_specific_card(player2, "standard_normal_spike")
	player1.hand.clear()
	var strike_card = give_player_specific_card(player1, "eugenia_shimmer_of_madness")
	give_player_specific_card(player1, "eugenia_werelight")
	execute_strike(player1, player2, strike_card, "standard_normal_dive",
		false, false,
		[[target], 0, 1],  # choose Spike; passive: pass; transform: pass
		[])
	validate_life(player1, 30, player2, 28)

# ===== EXCEED =====

func test_exceed_places_wonderland_and_ends_turn():
	var gauge_ids = give_gauge(player1, 6)
	assert_true(game_logic.do_exceed(player1, gauge_ids))
	assert_true(player1.exceeded)
	# On exceed, a Wonderland card is added to the set-aside zone (as the face attack).
	assert_eq(player1.set_aside_cards.size(), 1)
	# Exceeding ends Eugenia's turn.
	assert_eq(game_logic.active_turn_player, player2.my_id)

# ===== EXCEEDED PASSIVE: add a discarded card to Wonderland =====

func test_exceeded_passive_adds_card_to_wonderland():
	var gauge_ids = give_gauge(player1, 6)
	assert_true(game_logic.do_exceed(player1, gauge_ids))
	advance_turn(player2)  # back to Eugenia's turn
	position_players(player1, 4, player2, 5)
	var target = give_player_specific_card(player2, "standard_normal_spike")
	# Wonderland currently holds only the placeholder card.
	assert_eq(player1.set_aside_cards[0].definition.get("id"), "wonderland")
	# Shimmer R1-2 P2 S6 vs Dive stun. hit: choose the opponent's Spike to discard.
	# While exceeded, the exceeded passive then offers to add that discarded card
	# to Wonderland (idx1). wonderland_add_card REPLACES the placeholder (size stays 1).
	execute_strike(player1, player2, "eugenia_shimmer_of_madness", "standard_normal_dive",
		false, false,
		[[target], 1, 1],  # choose Spike; exceeded passive: add to Wonderland; transform pass
		[])
	validate_life(player1, 30, player2, 28)
	assert_eq(player1.set_aside_cards.size(), 1)
	assert_eq(player1.set_aside_cards[0].id, target)

# ===== WONDERLAND FACE ATTACK: +1 Power / +1 Speed while exceeded =====

func test_wonderland_face_attack_bonus():
	var gauge_ids = give_gauge(player1, 6)
	assert_true(game_logic.do_exceed(player1, gauge_ids))
	advance_turn(player2)  # back to Eugenia's turn
	# Add a real card to Wonderland so the face attack becomes available (size > 1).
	var extra = player1.hand[0]
	player1.hand.remove_at(0)
	player1.set_aside_cards.append(extra)
	position_players(player1, 4, player2, 6)
	# Wonderland face attack R1-3 at dist2 vs Grasp(R1) which misses (Grasp does not move).
	# Wonderland P0 base + during_strike +1P + exceeded face bonus +1P = P2. p2 30-2=28.
	execute_strike(player1, player2, "", "standard_normal_grasp",
		false, false,
		[], [],
		false,
		"", "",
		true)  # init_use_face_attack
	validate_life(player1, 30, player2, 28)

# ===== TRANSFORMS =====

func test_hanging_by_a_thread_bonus_power():
	# Hanging by a Thread (Shimmer transform) set_strike: if opponent has <=2 cards, +2 Power.
	add_transform(player1, "eugenia_shimmer_of_madness")
	position_players(player1, 4, player2, 6)
	# Empty the opponent's hand so the <=2 condition is satisfied at hit.
	player2.hand.clear()
	# Strike with Plot Hook (P3) at dist2 vs Grasp(R1) which misses. The standing
	# transform adds +2 Power -> P5. p2 30-5=25. (Plot Hook hit also pulls; position ignored.)
	execute_strike(player1, player2, "eugenia_plot_hook", "standard_normal_grasp",
		false, false,
		[0, 1],  # order the simultaneous hit effects; then decline transform-attack
		[])
	validate_life(player1, 30, player2, 25)

func test_time_for_tea_action_discards():
	# Time for Tea (Plot Hook transform) is a bonus action: pay 1 Force -> opponent
	# discards 1 random. That discard also triggers Eugenia's normal passive (pass).
	add_transform(player1, "eugenia_plot_hook")
	var force_ids = give_gauge(player1, 1)  # 1 Force available to pay
	var before = player2.hand.size()
	var actions = player1.get_bonus_actions()
	assert_gt(actions.size(), 0, "Time for Tea should be an available bonus action")
	assert_true(game_logic.do_bonus_turn_action(player1, 0))
	process_remaining_decisions(player1, player2, [[force_ids[0]], 0], [])
	# Opponent discarded a card as a result of the action.
	assert_lt(player2.hand.size(), before)

func test_off_with_her_head_boost_discards():
	# Off With Her Head (Werelight immediate boost): at range 1, opponent chooses
	# discard 2 random or push Eugenia 3.
	position_players(player1, 4, player2, 5)
	var boost_id = give_player_specific_card(player1, "eugenia_werelight")
	var before = player2.hand.size()
	assert_true(game_logic.do_boost(player1, boost_id))
	# Opponent chooses discard 2 (idx0); that discard triggers Eugenia's passive (pass idx0).
	process_remaining_decisions(player1, player2, [0], [0])
	assert_eq(player2.hand.size(), before - 2)

func test_edge_of_sanity_boost_discards():
	# Edge of Sanity (Cat's Cradle continuous boost): now -> opponent discards 1 random
	# (+ reduce opponent's prepare draw, a lasting passive).
	var boost_id = give_player_specific_card(player1, "eugenia_cats_cradle")
	var before = player2.hand.size()
	assert_true(game_logic.do_boost(player1, boost_id))
	# The discard triggers Eugenia's normal passive (pass idx0).
	process_remaining_decisions(player1, player2, [0], [])
	assert_eq(player2.hand.size(), before - 1)

func test_unhinged_adds_discard_on_ex_strike():
	# Unhinged (Color Spray transform) set_strike: on an EX strike, add hit -> opponent
	# discards 1 random. Grasp R1 EX at dist1 hits Dive (stun); the added effect discards.
	add_transform(player1, "eugenia_color_spray")
	position_players(player1, 4, player2, 5)
	player2.hand.clear()
	give_player_specific_card(player2, "standard_normal_spike")  # a card to be discarded
	var before = player2.hand.size()
	# EX strike with Grasp (no innate discard); Unhinged adds the opponent discard on hit.
	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_dive",
		true, false,
		[0, 0, 0],  # order simultaneous hit effects; Grasp push/pull choice; passive pass
		[])
	# Opponent lost a card to the Unhinged-added discard.
	assert_lt(player2.hand.size(), before)
