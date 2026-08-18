extends ExceedGutTest

## ==========================================================================
## Umina — Shadow Chorus copy regression tests.
##
## Rule: "Shadow Chorus (R1-1 P1 S1). On reveal, it copies a card from your
## Dreamlands. If there is no card in Dreamlands, it uses its own stats."
##
## The copy applies ONLY for the current strike: before being set as an
## attack the card shows itself, and after the strike the card must keep its
## own definition (it must not become a permanent copy of the Dreamlands
## card).
## ==========================================================================

func who_am_i():
	return "umina"

func before_each():
	default_game_setup("ryu")
	gut.p("ran setup", 2)

# Put a card into Umina's Dreamlands (set_aside) directly.
func put_in_dreamlands(player, def_id):
	give_player_specific_card(player, def_id)
	player.set_aside_cards.append(player.hand.pop_back())

func find_card_by_instance_id(_player, card_id, zones):
	for zone in zones:
		for c in zone:
			if c.id == card_id:
				return c
	return null

func has_def_in_zone(_player, def_id, zone):
	for card in zone:
		if card.definition.get("id", "") == def_id:
			return true
	return false

# ===== Baseline: no Dreamlands card -> Shadow Chorus keeps own stats =====

func test_shadow_chorus_without_dreamlands_keeps_own_definition():
	position_players(player1, 4, player2, 5)  # dist1, Shadow R1 hits
	# No card in Dreamlands -> Shadow Chorus uses its own stats (P1 S1).
	# Shadow S1 vs Focus S1 (tie, initiator first): P1 vs Focus G0 -> stun.
	# Shadow hits -> goes to gauge. Focus is stunned and skipped.
	var shadow_id = give_player_specific_card(player1, "umina_shadow_chorus")
	execute_strike(player1, player2, shadow_id, "standard_normal_focus",
		false, false,
		[], [])
	var shadow_card = find_card_by_instance_id(player1, shadow_id, [player1.gauge, player1.discards])
	assert_not_null(shadow_card, "Shadow Chorus should be in gauge or discard after the strike")
	assert_eq(shadow_card.definition.get("id"), "umina_shadow_chorus",
		"Without a Dreamlands card Shadow Chorus must keep its own definition")

# ===== Regression: copy must not permanently pollute the card definition =====

func test_shadow_chorus_copy_restores_own_definition_after_strike():
	position_players(player1, 3, player2, 5)  # dist2
	put_in_dreamlands(player1, "umina_hollow_space")
	var shadow_id = give_player_specific_card(player1, "umina_shadow_chorus")
	# Shadow Chorus R1-1 P1 S1 vs Grasp(R1). Dist2: Grasp misses (no counter).
	# On reveal Shadow Chorus copies Hollow Space (R3-6 P4 S4) from Dreamlands.
	# Dist2 is outside R3-6 -> Shadow misses -> goes to discard. The copied
	# Hollow Space after effect (choice advance 3 / retreat 3) fires: advance (idx0).
	execute_strike(player1, player2, shadow_id, "standard_normal_grasp",
		false, false,
		[0],  # copied Hollow Space after: advance 3
		[])
	var shadow_card = find_card_by_instance_id(player1, shadow_id, [player1.gauge, player1.discards])
	assert_not_null(shadow_card, "Shadow Chorus should be in gauge or discard after the strike")
	assert_eq(shadow_card.definition.get("id"), "umina_shadow_chorus",
		"Shadow Chorus definition must be restored after the strike (copy is temporary)")
	assert_eq(shadow_card.definition.get("type"), "special",
		"Restored Shadow Chorus must be a Special again (not a copied normal) so it never appears in normal-card picks (e.g. Focus Reading)")

func test_shadow_chorus_copy_hit_restores_own_definition():
	# Same regression, hit path: Shadow Chorus copies Hollow Space (R3-6 P4 S4),
	# hits at dist4, goes to gauge, and must still be restored to itself.
	position_players(player1, 3, player2, 7)  # dist4
	put_in_dreamlands(player1, "umina_hollow_space")
	var shadow_id = give_player_specific_card(player1, "umina_shadow_chorus")
	# Shadow copies Hollow Space on reveal: R3-6 hits at dist4. Grasp(R1) misses.
	# Hollow Space P4 -> p2 takes 4. Copied after effect (choice advance/retreat 3)
	# fires: advance (idx0).
	execute_strike(player1, player2, shadow_id, "standard_normal_grasp",
		false, false,
		[0],  # copied Hollow Space after: advance 3
		[])
	validate_life(player1, 30, player2, 26)
	var shadow_card = find_card_by_instance_id(player1, shadow_id, [player1.gauge, player1.discards])
	assert_not_null(shadow_card, "Shadow Chorus should be in gauge (hit) after the strike")
	assert_eq(shadow_card.definition.get("id"), "umina_shadow_chorus",
		"Shadow Chorus definition must be restored after a hit too")

# ===== Carl Swangee synergy: copied non-special must not trigger +1 armor =====

func test_shadow_copying_normal_does_not_trigger_carl_swangee_armor():
	# Carl Swangee (S2) ability: "While your opponent's attack is a Special, +1
	# Armor" (opponent_is_special_attack -> armorup). Shadow Chorus that copied
	# a NORMAL from Dreamlands is not a Special, so Carl's ability must NOT fire.
	# The copied definition must be what the condition sees during the strike.
	default_game_setup("carlswangee")
	position_players(player1, 3, player2, 5)  # dist2
	put_in_dreamlands(player1, "standard_normal_sweep")
	var shadow_id = give_player_specific_card(player1, "umina_shadow_chorus")
	# Shadow copies Sweep (R1-3 P6 S2, normal) on reveal. Dist2: hits.
	# Grasp(R1) misses at dist2 (no counter). Sweep hit: opponent discards 1
	# random (no decision). Carl's armorup condition sees type "normal" -> false.
	execute_strike(player1, player2, shadow_id, "standard_normal_grasp",
		false, false,
		[], [])
	# P6 vs Grasp armor 0 (no Carl armor bonus) -> p2 takes 6.
	validate_life(player1, 30, player2, 24)

func test_shadow_copying_special_does_trigger_carl_swangee_armor():
	# Control test: Shadow Chorus copying a SPECIAL (Hollow Space) IS a Special,
	# so Carl Swangee's +1 Armor must fire. Guards against over-correcting.
	default_game_setup("carlswangee")
	position_players(player1, 3, player2, 6)  # dist3
	put_in_dreamlands(player1, "umina_hollow_space")
	var shadow_id = give_player_specific_card(player1, "umina_shadow_chorus")
	# Shadow copies Hollow Space (R3-6 P4 S4, special) on reveal. Dist3: hits.
	# Grasp(R1) misses at dist3. Carl's armorup fires (special) -> Grasp armor 1.
	# Hollow Space after: choice advance/retreat 3 -> advance (idx0).
	execute_strike(player1, player2, shadow_id, "standard_normal_grasp",
		false, false,
		[0],  # copied Hollow Space after: advance 3
		[])
	# P4 vs Grasp armor 1 (Carl bonus) -> p2 takes 3.
	validate_life(player1, 30, player2, 27)


# ===== v2.5: Dreamlands stun immunity (Shadow copy + same-name hand card) =====

func test_shadow_copy_gets_dreamlands_stun_immunity():
	# Shadow copies a Dreamlands card with S2/G0 while opponent uses a faster hit.
	# Umina should still activate due to Dreamlands stun immunity.
	position_players(player1, 4, player2, 5)  # dist1
	put_in_dreamlands(player1, "vega_rollingcrystalflash")
	var shadow_id = give_player_specific_card(player1, "umina_shadow_chorus")
	execute_strike(player1, player2, shadow_id, "standard_normal_assault",
		false, false,
		[], [])
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_Strike_Stun_Immunity, player1)
	# Copied card resolves hit push 3, proving it was not skipped by stun.
	validate_positions(player1, 4, player2, 8)

func test_hand_same_named_card_gets_dreamlands_stun_immunity():
	# Directly striking with a hand card that matches Dreamlands should also grant
	# stun immunity, allowing the card's effects to resolve.
	position_players(player1, 4, player2, 5)  # dist1
	put_in_dreamlands(player1, "standard_normal_cross")
	execute_strike(player1, player2, "standard_normal_cross", "standard_normal_grasp",
		false, false,
		[], [0])
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_Strike_Stun_Immunity, player1)
	validate_life(player1, 27, player2, 27)
	validate_positions(player1, 1, player2, 5)


# ===== v2.6: defender seal trigger + cross-season normal matching =====

func test_exceeded_defender_can_seal_dreamlands_for_triggers():
	# Exceeded Umina should be able to seal Dreamlands on set_strike as defender.
	# The sealed Sweep contributes a hit trigger (opponent random discard 1).
	player1.exceeded = true
	position_players(player1, 4, player2, 5)  # dist1
	put_in_dreamlands(player1, "standard_normal_sweep")
	advance_turn(player1)
	execute_strike(player2, player1, "standard_normal_spike", "standard_normal_grasp",
		false, false,
		[], [0], true)
	var events = game_logic.get_latest_events()
	assert_eq(player1.set_aside_cards.size(), 0,
		"Dreamlands card should be sealed when defender chooses seal on set_strike")
	assert_true(has_def_in_zone(player1, "standard_normal_sweep", player1.sealed),
		"Chosen Dreamlands card should be in sealed")
	validate_has_event(events, Enums.EventType.EventType_Seal, player1)

func test_cross_season_normals_match_by_speed_for_stun_immunity():
	# Dreamlands Slash (GG normal, S5) should match UNI Assault (S5) for stun
	# immunity even though definition IDs differ.
	position_players(player1, 4, player2, 5)  # dist1
	put_in_dreamlands(player1, "gg_normal_slash")
	execute_strike(player1, player2, "uni_normal_assault", "standard_normal_grasp",
		false, false,
		[], [0])
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_Strike_Stun_Immunity, player1)

func test_is_spiraling_match_cross_season_rules():
	give_player_specific_card(player1, "gg_normal_slash")
	var assault_id = give_player_specific_card(player1, "uni_normal_assault")
	var dive_id = give_player_specific_card(player1, "uni_normal_dive")
	var shadow_id = give_player_specific_card(player1, "umina_shadow_chorus")
	var card_db = game_logic.get_card_database()
	var assault_card = card_db.get_card(assault_id)
	var dive_card = card_db.get_card(dive_id)
	var shadow_card = card_db.get_card(shadow_id)

	assert_true(game_logic._is_spiraling_match("gg_normal_slash", assault_card),
		"Normal-vs-normal should match by speed across seasons")
	assert_false(game_logic._is_spiraling_match("gg_normal_slash", dive_card),
		"Normal-vs-normal should not match when speed differs")
	assert_false(game_logic._is_spiraling_match("gg_normal_slash", shadow_card),
		"Non-normal cards should not speed-match normals")
	assert_true(game_logic._is_spiraling_match("umina_shadow_chorus", shadow_card),
		"Non-normal matching should use exact definition id")


# ===== v2.7: Unknown Khadath swallow/cleanup behavior =====

func test_unknown_khadath_defender_swallows_attack_and_ends_strike():
	# Defender Khadath: initiator acts first on same speed, misses at dist3,
	# then Khadath swallows initiator attack into Dreamlands and moves itself to gauge.
	position_players(player1, 5, player2, 2)  # dist3
	var p1_gauge = give_gauge(player1, 3)
	advance_turn(player1)
	var strike_cards = execute_strike(player2, player1, "uni_normal_cross", "umina_unknown_khadath",
		false, false,
		[], [p1_gauge])
	var init_card_id = strike_cards[0]
	var def_card_id = strike_cards[1]
	assert_not_null(find_card_by_instance_id(player1, init_card_id, [player1.set_aside_cards]),
		"Khadath should move initiator attack into Umina Dreamlands")
	assert_not_null(find_card_by_instance_id(player1, def_card_id, [player1.gauge]),
		"Khadath should move itself to Umina gauge")

func test_unknown_khadath_faster_swallows_attack_and_ends_strike():
	# Initiator Khadath (card1 path) should also swallow attack and end strike immediately.
	position_players(player1, 5, player2, 2)  # dist3
	var p1_gauge = give_gauge(player1, 3)
	var strike_cards = execute_strike(player1, player2, "umina_unknown_khadath", "standard_normal_assault",
		false, false,
		[p1_gauge], [])
	var init_card_id = strike_cards[0]
	var def_card_id = strike_cards[1]
	assert_not_null(find_card_by_instance_id(player1, def_card_id, [player1.set_aside_cards]),
		"Khadath should move defender attack into Umina Dreamlands")
	assert_not_null(find_card_by_instance_id(player1, init_card_id, [player1.gauge]),
		"Khadath should move itself to Umina gauge on card1 path too")
