extends ExceedGutTest

func who_am_i():
	return "akimo"

##
## Tests start here
##

## Akimo can infuse by spending 2 life, and has +1 Power when initiating while infused (+2 on back side).

func test_infused_prepare_action():
	position_players(player1, 3, player2, 7)
	
	var p1_handsize = len(player1.hand)
	var gauge_card = give_gauge(player1, 1)
	
	assert_true(game_logic.do_prepare(player1, InfusionCost.new(gauge_card[0])))
	assert_eq(len(player1.hand), p1_handsize + 2)
	assert_true(player1.is_card_in_discards(gauge_card[0]))
	
	advance_turn(player2)

func test_infused_reshuffle_action():
	position_players(player1, 3, player2, 7)
	
	player1.discard_topdeck()
	var gauge_card = give_gauge(player1, 1)
	
	assert_true(game_logic.do_reshuffle(player1, InfusionCost.new(gauge_card[0])))
	assert_eq(len(player1.discards), 0)
	assert_false(player1.is_card_in_gauge(gauge_card[0]))
	
	advance_turn(player2)

func test_infused_move_action():
	position_players(player1, 3, player2, 7)
	
	var gauge_card = give_gauge(player1, 1)
	
	assert_true(game_logic.do_move(player1, [player1.hand[0].id], 4, false, 0, InfusionCost.new(gauge_card[0])))
	validate_positions(player1, 4, player2, 7)
	assert_true(player1.is_card_in_discards(gauge_card[0]))
	
	advance_turn(player2)

func test_infused_change_action():
	position_players(player1, 3, player2, 7)
	
	var p1_handsize = len(player1.hand)
	var gauge_card = give_gauge(player1, 1)
	
	assert_true(game_logic.do_change(player1, [player1.hand[0].id], true, false, 0, InfusionCost.new(gauge_card[0])))
	assert_eq(len(player1.hand), p1_handsize + 1)
	assert_true(player1.is_card_in_discards(gauge_card[0]))
	
	advance_turn(player2)

func test_infused_exceed_action():
	position_players(player1, 3, player2, 7)
	
	var gauge_card = give_gauge(player1, 4)
	
	assert_true(game_logic.do_exceed(player1, gauge_card.slice(0, 3), 0, InfusionCost.new(gauge_card[-1])))
	assert_true(player1.exceeded)
	assert_true(player1.is_card_in_discards(gauge_card[0]))
	
	advance_turn(player2)

# Exalting the Rose: Now: Draw 2. Infused, Now: Draw 2. Hit: Gain Advantage.
func test_infused_boost_action():
	position_players(player1, 3, player2, 7)
	
	player1.discard_hand()
	var gauge_card = give_gauge(player1, 1)
	var p1_handsize = len(player1.hand)
	
	var boost_card = give_player_specific_card(player1, "akimo_scorchingrush")
	assert_true(game_logic.do_boost(player1, boost_card, [], false, 0, [], null, InfusionCost.new(gauge_card[0])))
	assert_eq(len(player1.hand), p1_handsize + 5)
	assert_true(player1.is_card_in_continuous_boosts(boost_card))
	assert_true(player1.is_card_in_discards(gauge_card[0]))
	
	advance_turn(player2)

# Astryda: Action: Pull 1. If you are infused, Draw 2.
func test_infused_character_action():
	game_logic.teardown()
	game_logic.free()
	default_game_setup("astryda")
	
	position_players(player1, 3, player2, 7)
	
	advance_turn(player1)
	player2.discard_hand()
	var gauge_card = give_gauge(player2, 1)
	var p2_handsize = len(player2.hand)
	
	assert_true(game_logic.do_character_action(player2, [], 0, false, 0, InfusionCost.new(gauge_card[0])))
	validate_positions(player1, 4, player2, 7)
	assert_eq(len(player2.hand), p2_handsize + 3)
	assert_true(player2.is_card_in_discards(gauge_card[0]))

	advance_turn(player1)

# Rage: has an action on it that reads "Close 2 and Discard This"
func test_infused_bonus_action():
	position_players(player1, 3, player2, 7)
	
	player1.discard_hand()
	var gauge_card = give_gauge(player1, 1)
	var p1_handsize = len(player1.hand)
	
	var boost_card = give_player_specific_card(player1, "gulbjarn_feralfrenzy")
	assert_true(game_logic.do_boost(player1, boost_card, [player1.hand[0].id], false, 0, [], null))
	assert_eq(len(player1.hand), p1_handsize)
	assert_true(player1.is_card_in_continuous_boosts(boost_card))
	advance_turn(player2)
	
	assert_true(game_logic.do_bonus_turn_action(player1, 0, InfusionCost.new(gauge_card[0])))
	assert_eq(len(player1.hand), p1_handsize + 1)
	assert_true(player1.is_card_in_discards(boost_card))
	assert_true(player1.is_card_in_discards(gauge_card[0]))
	
	
