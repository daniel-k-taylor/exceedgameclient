extends ExceedGutTest

func who_am_i():
	return "taokaka"

## Taokaka Exceed ability: When you initiate a strike, your attack has "Before:
##     Advance 2; then, you may Retreat 2."

func test_taokaka_exceed_dodge():
	position_players(player1, 2, player2, 6)
	player1.exceed()
	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_sweep",
			false, false, [0], [])  # Retreat with Before: effect
	validate_positions(player1, 2, player2, 6)
	validate_life(player1, 30, player2, 30)

func test_taokaka_exceed_no_dodge_on_defense():
	position_players(player1, 7, player2, 6)
	player1.exceed()
	advance_turn(player1)
	execute_strike(player2, player1, "standard_normal_sweep", "standard_normal_sweep",
			false, false, [], [])  # No choices presented
	validate_positions(player1, 7, player2, 6)
	validate_life(player1, 24, player2, 24)

## Taokaka ability: When you initiate a strike with a Wild Swing, your attack has
##     "Before: Advance 2; then, you may spend 1 Force to Retreat 2."

func test_taokaka_wild_dodge():
	position_players(player1, 2, player2, 6)
	var grasp_id = give_player_specific_card(player1, "standard_normal_grasp")
	player1.move_card_from_hand_to_deck(grasp_id)
	assert_eq(player1.deck[0].id, grasp_id)

	execute_strike(player1, player2, "", "standard_normal_sweep",
			false, false, [[player1.hand[0].id]], [])  # Pay force for optional retreat
	var move_events = validate_has_event(game_logic.get_latest_events(),
			Enums.EventType.EventType_Move, player1)
	assert_eq(move_events[0]['number'], 4)  # Found advance to space 4
	assert_eq(move_events[1]['number'], 2)  # Found retreat to space 2
	validate_positions(player1, 2, player2, 6)
	validate_life(player1, 30, player2, 30)

## Hexa Edge boost: Now: Place a card from your hand on top of your deck, then
##     Strike with a Wild Swing.
##     Hit: Gain Advantage.

func test_taokaka_hexaedge_becomingtwo():
	position_players(player1, 2, player2, 6)
	var hexaedge_id = give_player_specific_card(player1, "taokaka_hexaedge")
	var cross_id = give_player_specific_card(player1, "standard_normal_cross")
	assert_true(game_logic.do_boost(player1, hexaedge_id, [player1.hand[0].id]))
	assert_true(game_logic.do_relocate_card_from_hand(player1, [cross_id]))  # to topdeck

	execute_strike(player1, player2, "", "standard_normal_sweep",
			false, false, [[]], [])  # Decline force payment for retreat
	# Expected: Taokaka advances to 4, declines a retreat, hits with Cross, then
	#     retreats to 1.
	validate_positions(player1, 1, player2, 6)
	validate_life(player1, 30, player2, 27)
	assert_eq(game_logic.active_turn_player, player1.my_id)  # Advantage
