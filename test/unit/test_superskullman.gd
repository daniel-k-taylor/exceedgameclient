extends ExceedGutTest

func who_am_i():
	return "superskullman"

##
## Tests start here
##

func test_superskullman_kaplow_boost_takedamage_discard():
	position_players(player1, 5, player2, 7)
	give_player_specific_card(player1, "superskullman_kaplow")
	assert_true(game_logic.do_boost(player1, player1.hand[-1].id))
	add_transform(player2, "djanette_profanesanctuary")
	player2.discard_hand()
	give_player_specific_card(player2, "standard_normal_focus")
	assert_true(game_logic.do_bonus_turn_action(player2, 0))
	assert_true(game_logic.do_choose_to_discard(player2, [player2.hand[-1].id]))
	validate_life(player1, 30, player2, 30)
	assert_eq(player1.discards.size(), 2)
	advance_turn(player1)


func test_superskullman_kaplow_boost_strikedamage_discard():
	position_players(player1, 5, player2, 7)
	give_player_specific_card(player1, "superskullman_kaplow")
	assert_true(game_logic.do_boost(player1, player1.hand[-1].id))
	execute_strike(player2, player1, "standard_normal_assault", "standard_normal_dive", false, false,
		[], [])
	validate_life(player1, 30, player2, 30)
	validate_positions(player1, 9, player2, 6)
	assert_eq(player1.discards.size(), 10) # 4 damage + boost discarded after strike + strike itself
	advance_turn(player2)


func test_superskullman_zingzingzing_freeifwild():
	position_players(player1, 6, player2, 7)
	give_player_specific_card(player1, "superskullman_zingzingzing")
	player1.move_card_from_hand_to_deck(player1.hand[-1].id)
	execute_strike(player1, player2, -1, "standard_normal_assault", false, false,
		[[], 3], []) # Don't wild swing, pull 2
	validate_life(player1, 30, player2, 22)
	validate_positions(player1, 6, player2, 4)
	advance_turn(player2)


func test_superskullman_slamevil_boost_moveaction():
	position_players(player1, 6, player2, 7)
	give_player_specific_card(player1, "superskullman_slamevil")
	assert_true(game_logic.do_boost(player1, player1.hand[-1].id))
	assert_true(game_logic.do_move(player2, [player2.hand[0].id, player2.hand[1].id], 5))
	validate_positions(player1, 6, player2, 5)
	assert_eq(player1.continuous_boosts.size(), 0)
	assert_eq(player1.discards.size(), 1)
	advance_turn(player1)


func test_superskullman_slamevil_boost_move_with_cross():
	position_players(player1, 6, player2, 7)
	give_player_specific_card(player1, "superskullman_slamevil")
	assert_true(game_logic.do_boost(player1, player1.hand[-1].id))
	give_player_specific_card(player2, "standard_normal_cross")
	assert_true(game_logic.do_boost(player2, player2.hand[-1].id))
	assert_true(game_logic.do_choice(player2, 2))
	validate_positions(player1, 6, player2, 3)
	assert_eq(player1.continuous_boosts.size(), 0)
	assert_eq(player1.discards.size(), 1)
	advance_turn(player1)


func test_superskullman_slamevil_boost_move_with_continuous():
	position_players(player1, 6, player2, 7)
	give_player_specific_card(player1, "superskullman_slamevil")
	assert_true(game_logic.do_boost(player1, player1.hand[-1].id))
	give_player_specific_card(player2, "may_mrdolphin")
	assert_true(game_logic.do_boost(player2, player2.hand[-1].id))
	validate_positions(player1, 6, player2, 5)
	assert_eq(player1.continuous_boosts.size(), 0)
	assert_eq(player1.discards.size(), 1)
	assert_eq(player2.continuous_boosts.size(), 1)
	advance_turn(player1)


func test_superskullman_slamevil_boost_move_with_strike():
	position_players(player1, 4, player2, 7)
	give_player_specific_card(player1, "superskullman_slamevil")
	assert_true(game_logic.do_boost(player1, player1.hand[-1].id))
	execute_strike(player2, player1, "standard_normal_dive", "standard_normal_sweep", false, false, 
		[], [])
	validate_positions(player1, 4, player2, 3)
	validate_life(player1, 25, player2, 30) # Didn't get the armor
	assert_eq(player1.continuous_boosts.size(), 0)
	assert_eq(player1.discards.size(), 2) 
	advance_turn(player1)


func test_superskullman_zap_boost_skips_discard():
	# Bug report: Zaaaap boost draws 3, topdecks 1, and skips end of turn draw.
	# According to FAQ, it should also skip discarding down to max hand size.
	position_players(player1, 4, player2, 7)
	
	# Player1 starts with 5 cards (first player)
	# Give extra cards to end up over max after boost
	# Boost: draw 3, topdeck 1 = net +2 cards
	# If we give 2 extra cards: 5 + 2 = 7, then +2 from boost = 9, topdeck 1 = 8 (over max of 7)
	give_player_specific_card(player1, "standard_normal_grasp")
	give_player_specific_card(player1, "standard_normal_grasp")
	var zap_id = give_player_specific_card(player1, "superskullman_zap")
	assert_eq(player1.hand.size(), 8) # 5 starting + 3 given
	
	# Boost Zaaaap (goes to discard, not counted in hand)
	assert_true(game_logic.do_boost(player1, zap_id))
	# Hand is now 7 (boost card went to processing)
	# Draw 3 cards = 10 cards
	# Topdeck 1 card = 9 cards (over max of 7)
	assert_true(game_logic.do_relocate_card_from_hand(player1, [player1.hand[0].id]))
	
	# Hand should be 9 cards now (over max of 7)
	assert_eq(player1.hand.size(), 9)
	
	# The boost should skip discarding, so it should be opponent's turn now
	# BUG: Currently the game asks to discard down to max
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction,
		"BUG: Zaaaap boost should skip discard to max, but game is asking to discard")
	assert_eq(game_logic.active_turn_player, player2.my_id,
		"Should be player2's turn after Zaaaap boost")
	
	# Verify hand is still over max (wasn't forced to discard)
	assert_eq(player1.hand.size(), 9)
