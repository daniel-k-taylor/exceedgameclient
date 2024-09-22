extends ExceedGutTest

func who_am_i():
	return "hilda"

##
## Tests start here
##

func test_hilda_inthedarkness_boost_and_interference():
	position_players(player1, 8, player2, 9)
	var darknessId = give_player_specific_card(player1, "hilda_inthedarkness")
	assert_true(game_logic.do_boost(player1, darknessId))
	var sweepId = give_player_specific_card(player2, "standard_normal_sweep")
	assert_true(game_logic.do_boost(player2, sweepId))

	assert_eq(player2.hand.size(), 7)
	execute_strike(player1, player2, "standard_normal_sweep", "hilda_interference", false, false, [], [])
	# P1 sweep is now speed 6 power 2
	# P2 is speed 4 because light
	# P1 hits for 2 and discards p2 card
	# P2 hits back and pushs 6
	validate_life(player1, 26, player2, 28)
	assert_eq(player2.hand.size(), 6)
	validate_positions(player1, 2, player2, 9)

func test_hilda_impalement_attack_ex_max_bonus():
	position_players(player1, 2, player2, 5)
	var skewerId1 = give_player_specific_card(player1, "hilda_skewer")
	var skewerId2 = give_player_specific_card(player1, "hilda_skewer")
	player1.move_card_from_hand_to_gauge(skewerId1)
	player1.move_card_from_hand_to_gauge(skewerId2)
	var impalementId1 = give_player_specific_card(player1, "hilda_impalement")
	var impalementId2 = give_player_specific_card(player1, "hilda_impalement")
	var sweepId = give_player_specific_card(player2, "standard_normal_sweep")
	assert_true(game_logic.do_strike(player1, impalementId1, false, impalementId2))
	assert_true(game_logic.do_strike(player2, sweepId, false, -1))
	assert_true(game_logic.do_pay_strike_cost(player1, player1.get_card_ids_in_gauge(), false))
	validate_life(player1, 30, player2, 23)
	validate_positions(player1, 2, player2, 5)

func test_hilda_impalement_attack_ex_1_bonus():
	position_players(player1, 2, player2, 5)
	var skewerId = give_player_specific_card(player1, "hilda_skewer")
	var trifurketId = give_player_specific_card(player1, "hilda_trifurket")
	player1.move_card_from_hand_to_gauge(skewerId)
	player1.move_card_from_hand_to_gauge(trifurketId)
	var impalementId1 = give_player_specific_card(player1, "hilda_impalement")
	var impalementId2 = give_player_specific_card(player1, "hilda_impalement")
	var sweepId = give_player_specific_card(player2, "standard_normal_sweep")
	assert_true(game_logic.do_strike(player1, impalementId1, false, impalementId2))
	assert_true(game_logic.do_strike(player2, sweepId, false, -1))
	assert_true(game_logic.do_pay_strike_cost(player1, player1.get_card_ids_in_gauge(), false))
	validate_life(player1, 25, player2, 25)
	validate_positions(player1, 2, player2, 5)


func test_hilda_impalement_invertrange():
	position_players(player1, 2, player2, 5)
	var impalementId = give_player_specific_card(player1, "hilda_impalement")
	assert_true(game_logic.do_boost(player1, impalementId, [player1.hand[0].id]))
	advance_turn(player2)
	var graspId = give_player_specific_card(player1, "standard_normal_grasp")
	var sweepId = give_player_specific_card(player2, "standard_normal_sweep")
	assert_true(game_logic.do_strike(player1, graspId, false, -1))
	assert_true(game_logic.do_strike(player2, sweepId, false, -1))
	assert_true(game_logic.do_choice(player1, 0))
	validate_life(player1, 30, player2, 28)
	validate_positions(player1, 2, player2, 6)

func test_hilda_ua_grasp():
	position_players(player1, 2, player2, 4)
	assert_true(game_logic.do_character_action(player1, [], 0))
	var graspId = give_player_specific_card(player1, "standard_normal_grasp")
	var sweepId = give_player_specific_card(player2, "standard_normal_sweep")
	assert_true(game_logic.do_strike(player1, graspId, false, -1))
	assert_true(game_logic.do_strike(player2, sweepId, false, -1))
	assert_true(game_logic.do_choice(player1, 1))
	validate_life(player1, 30, player2, 28)
	validate_positions(player1, 2, player2, 6)

func test_hilda_ua_grasp_min_range_miss():
	position_players(player1, 2, player2, 3)
	assert_true(game_logic.do_character_action(player1, [], 0))
	var graspId = give_player_specific_card(player1, "standard_normal_grasp")
	var sweepId = give_player_specific_card(player2, "standard_normal_sweep")
	assert_true(game_logic.do_strike(player1, graspId, false, -1))
	assert_true(game_logic.do_strike(player2, sweepId, false, -1))
	validate_life(player1, 24, player2, 30)
	validate_positions(player1, 2, player2, 3)

func test_hilda_trifurket_bottom_to_gauge():
	position_players(player1, 2, player2, 3)
	player1.discard_hand()
	var trifurketId = give_player_specific_card(player1, "hilda_trifurket")
	var sweepId = give_player_specific_card(player2, "standard_normal_assault")
	assert_true(game_logic.do_strike(player1, trifurketId, false, -1))
	assert_true(game_logic.do_strike(player2, sweepId, false, -1))
	var bottom_discard_id = player1.discards[0].id
	assert_true(game_logic.do_choice(player1, 0)) # Gauge

	validate_life(player1, 27, player2, 26)
	validate_positions(player1, 2, player2, 3)
	assert_eq(player1.gauge.size(), 2)
	assert_eq(player1.gauge[0].id, bottom_discard_id)
	assert_eq(player1.gauge[1].id, trifurketId)

func test_hilda_trifurket_bottom_to_hand():
	position_players(player1, 2, player2, 3)
	player1.discard_hand()
	var trifurketId = give_player_specific_card(player1, "hilda_trifurket")
	var assaultId = give_player_specific_card(player2, "standard_normal_assault")
	assert_true(game_logic.do_strike(player1, trifurketId, false, -1))
	assert_true(game_logic.do_strike(player2, assaultId, false, -1))
	var bottom_discard_id = player1.discards[0].id
	assert_true(game_logic.do_choice(player1, 1)) # Hand

	validate_life(player1, 27, player2, 26)
	validate_positions(player1, 2, player2, 3)
	assert_eq(player1.hand.size(), 1)
	assert_eq(player1.hand[0].id, bottom_discard_id)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player1.gauge[0].id, trifurketId)

func test_hilda_trifurket_bottom_to_gauge_empty():
	position_players(player1, 2, player2, 3)
	var trifurketId = give_player_specific_card(player1, "hilda_trifurket")
	var assaultId = give_player_specific_card(player2, "standard_normal_assault")
	assert_true(game_logic.do_strike(player1, trifurketId, false, -1))
	assert_true(game_logic.do_strike(player2, assaultId, false, -1))
	assert_true(game_logic.do_choice(player1, 0)) # Gauge

	validate_life(player1, 27, player2, 26)
	validate_positions(player1, 2, player2, 3)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player1.gauge[0].id, trifurketId)



func test_hilda_trifurket_boost():
	position_players(player1, 2, player2, 3)
	player2.discard_hand()
	var assaultId = give_player_specific_card(player2, "standard_normal_assault")
	var trifurketId = give_player_specific_card(player1, "hilda_trifurket")
	assert_true(game_logic.do_boost(player1, trifurketId))

	assert_true(game_logic.do_relocate_card_from_hand(player2, [assaultId]))
	var p1cards = []
	for i in range(3):
		p1cards.append(player1.hand[i].id)
	assert_true(game_logic.do_relocate_card_from_hand(player1, p1cards))

	validate_positions(player1, 2, player2, 3)
	assert_eq(player1.gauge.size(), 3)
	assert_eq(player1.gauge[0].id, p1cards[0])
	assert_eq(player1.gauge[1].id, p1cards[1])
	assert_eq(player1.gauge[2].id, p1cards[2])
	assert_eq(player2.gauge.size(), 1)
	assert_eq(player2.gauge[0].id, assaultId)
	advance_turn(player2)

func test_hilda_revenantpillar_choosemultiple():
	position_players(player1, 2, player2, 5)
	assert_eq(player1.hand.size(), 5)
	var revenantId = give_player_specific_card(player1, "hilda_revenantpillar")
	var sweepId = give_player_specific_card(player2, "standard_normal_sweep")
	assert_true(game_logic.do_strike(player1, revenantId, false, -1))
	assert_true(game_logic.do_strike(player2, sweepId, false, -1))
	# Choose 2, push, pull, draw, discard opp random, advantage
	assert_eq(game_logic.decision_info.choice.size(), 5)
	assert_true(game_logic.do_choice(player1, 0)) # Push 1
	validate_positions(player1, 2, player2, 6)
	assert_eq(player1.hand.size(), 5)
	assert_eq(game_logic.decision_info.choice.size(), 4)
	assert_true(game_logic.do_choice(player1, 1)) # Draw 1
	assert_eq(player1.hand.size(), 6)
	validate_positions(player1, 2, player2, 6)
	validate_life(player1, 30, player2, 25)
	advance_turn(player2)

func test_hilda_revenantpillar_choosemultiple2():
	position_players(player1, 2, player2, 5)
	assert_eq(player1.hand.size(), 5)
	var revenantId = give_player_specific_card(player1, "hilda_revenantpillar")
	var sweepId = give_player_specific_card(player2, "standard_normal_sweep")
	assert_true(game_logic.do_strike(player1, revenantId, false, -1))
	assert_true(game_logic.do_strike(player2, sweepId, false, -1))
	# Choose 2, push, pull, draw, discard opp random, advantage
	assert_eq(game_logic.decision_info.choice.size(), 5)
	assert_true(game_logic.do_choice(player1, 4)) # advantage
	validate_positions(player1, 2, player2, 5)
	assert_eq(player1.hand.size(), 5)
	assert_eq(game_logic.decision_info.choice.size(), 4)
	assert_true(game_logic.do_choice(player1, 0)) # push 1
	assert_eq(player1.hand.size(), 5)
	validate_positions(player1, 2, player2, 6)
	validate_life(player1, 30, player2, 25)
	advance_turn(player1)


func test_hilda_revenantpillar_choosemultiple3():
	position_players(player1, 2, player2, 5)
	assert_eq(player1.hand.size(), 5)
	var revenantId = give_player_specific_card(player1, "hilda_revenantpillar")
	var sweepId = give_player_specific_card(player2, "standard_normal_sweep")
	assert_true(game_logic.do_strike(player1, revenantId, false, -1))
	assert_true(game_logic.do_strike(player2, sweepId, false, -1))
	# Choose 2, push, pull, draw, discard opp random, advantage
	assert_eq(game_logic.decision_info.choice.size(), 5)
	assert_true(game_logic.do_choice(player1, 2)) # draw
	validate_positions(player1, 2, player2, 5)
	assert_eq(player1.hand.size(), 6)
	assert_eq(game_logic.decision_info.choice.size(), 4)
	assert_true(game_logic.do_choice(player1, 2)) # discard
	assert_eq(player1.hand.size(), 5)
	validate_positions(player1, 2, player2, 5)
	validate_life(player1, 24, player2, 25)
	advance_turn(player2)


func test_hilda_ua_exceed():
	position_players(player1, 2, player2, 3)
	give_gauge(player1, 5)
	player1.exceeded = true
	assert_true(game_logic.do_character_action(player1, [player1.gauge[0].id], 0))
	assert_true(game_logic.do_choice(player1, 0)) # Push
	assert_true(game_logic.do_character_action(player1, [player1.gauge[0].id], 0))
	assert_true(game_logic.do_choice(player1, 0)) # Push
	assert_true(game_logic.do_character_action(player1, [player1.gauge[0].id], 0))
	assert_true(game_logic.do_choice(player1, 0)) # Push
	validate_positions(player1, 2, player2, 6)
	assert_eq(player1.hand.size(), 5)
	assert_eq(player2.hand.size(), 6)
	var interferenceId = give_player_specific_card(player1, "hilda_interference")
	assert_true(game_logic.do_boost(player1, interferenceId))
	assert_eq(player1.hand.size(), 8)
	assert_eq(player2.hand.size(), 9)
	execute_strike(player1, player2, "standard_normal_dive", "standard_normal_dive", false, false, [], [])
	validate_life(player1, 30, player2, 25)
	advance_turn(player2)


func test_hilda_condensity_ex_space():
	position_players(player1, 2, player2, 6)
	var condensityId1 = give_player_specific_card(player1, "hilda_condensitygloom")
	var condensityId2 = give_player_specific_card(player1, "hilda_condensitygloom")
	var sweepId = give_player_specific_card(player2, "standard_normal_sweep")
	assert_true(game_logic.do_strike(player1, condensityId1, false, condensityId2))
	assert_true(game_logic.do_choice(player1, select_space(5)))
	assert_true(game_logic.do_strike(player2, sweepId, false, -1))
	# After, you can go to it
	assert_true(game_logic.do_choice(player1, 0))
	validate_life(player1, 26, player2, 24)
	validate_positions(player1, 5, player2, 6)
	advance_turn(player2)


func test_hilda_condensity_notinspace():
	position_players(player1, 2, player2, 5)
	var condensityId = give_player_specific_card(player1, "hilda_condensitygloom")
	var assaultId = give_player_specific_card(player2, "standard_normal_assault")
	assert_true(game_logic.do_strike(player1, condensityId, false, -1))
	assert_true(game_logic.do_choice(player1, 0)) # Pass
	assert_true(game_logic.do_strike(player2, assaultId, false, -1))
	validate_life(player1, 27, player2, 25)
	validate_positions(player1, 2, player2, 3)
	advance_turn(player2)


func test_hilda_condensity_wild():
	position_players(player1, 2, player2, 5)
	var condensityId = give_player_specific_card(player1, "hilda_condensitygloom")
	player1.move_card_from_hand_to_deck(condensityId, 0)
	var assaultId = give_player_specific_card(player2, "standard_normal_assault")
	assert_true(game_logic.do_strike(player1, -1, true, -1))
	assert_true(game_logic.do_strike(player2, assaultId, false, -1))
	validate_life(player1, 27, player2, 25)
	validate_positions(player1, 2, player2, 3)
	advance_turn(player2)


func setup_exceeded_tinker_knight():
	game_logic.teardown()
	game_logic.free()
	default_game_setup("tinker")

	give_gauge(player2, 5)
	player2.life = 1
	position_players(player1, 3, player2, 4)
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault")
	assert_eq(player2.extra_width, 1)
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 20)
	player1.gauge = []
	# Don't need to advance_turn(player2) due to advantage from Assault

# Reproduced bug; impalement gauge cards should properly account for tinker tank's full size
func test_hilda_impalement_pay_revenant_darkness_vs_tinker():
	setup_exceeded_tinker_knight()
	position_players(player1, 3, player2, 7)
	var darknessId = give_player_specific_card(player1, "hilda_inthedarkness")
	var revenantId = give_player_specific_card(player1, "hilda_revenantpillar")
	player1.move_card_from_hand_to_gauge(darknessId)
	player1.move_card_from_hand_to_gauge(revenantId)
	var impalementId1 = give_player_specific_card(player1, "hilda_impalement")
	var impalementId2 = give_player_specific_card(player1, "hilda_impalement")
	var sweepId = give_player_specific_card(player2, "standard_normal_sweep")
	assert_true(game_logic.do_strike(player1, impalementId1, false, impalementId2))
	assert_true(game_logic.do_strike(player2, sweepId, false, -1))
	assert_true(game_logic.do_pay_strike_cost(player1, player1.get_card_ids_in_gauge(), false))
	validate_life(player1, 30, player2, 13)
	validate_positions(player1, 3, player2, 7)

func test_hilda_impalement_pay_revenant_darkness_vs_not_tinker():
	position_players(player1, 3, player2, 6)
	var darknessId = give_player_specific_card(player1, "hilda_inthedarkness")
	var revenantId = give_player_specific_card(player1, "hilda_revenantpillar")
	player1.move_card_from_hand_to_gauge(darknessId)
	player1.move_card_from_hand_to_gauge(revenantId)
	var impalementId1 = give_player_specific_card(player1, "hilda_impalement")
	var impalementId2 = give_player_specific_card(player1, "hilda_impalement")
	var sweepId = give_player_specific_card(player2, "standard_normal_sweep")
	assert_true(game_logic.do_strike(player1, impalementId1, false, impalementId2))
	assert_true(game_logic.do_strike(player2, sweepId, false, -1))
	assert_true(game_logic.do_pay_strike_cost(player1, player1.get_card_ids_in_gauge(), false))
	validate_life(player1, 25, player2, 25)
	validate_positions(player1, 3, player2, 6)
