extends ExceedGutTest

func who_am_i():
	return "waldstein"

# func test_waldstein_ferzen_volf_range_one():
# 	position_players(player1, 4, player2, 5)

# 	execute_strike(player1, player2, "waldstein_ferzenvolf", "uni_normal_grasp", [], [1], false, false)
# 	validate_positions(player1, 4, player2, 9)
# 	validate_life(player1, 28, player2, 24)
# 	advance_turn(player2)

# func test_waldstein_ferzen_volf_range_two():
# 	position_players(player1, 4, player2, 6)

# 	execute_strike(player1, player2, "waldstein_ferzenvolf", "uni_normal_grasp", [], [], false, false)
# 	validate_positions(player1, 4, player2, 8)
# 	validate_life(player1, 30, player2, 26)
# 	advance_turn(player2)

# func test_waldstein_face_me_opponent_strikes():
# 	position_players(player1, 4, player2, 6)
# 	player1.hand = []
# 	give_player_specific_card(player1, "waldstein_sturmangriff", TestCardId3)
# 	assert_true(game_logic.do_boost(player1, TestCardId3, []))
# 	assert_eq(len(player1.hand), 3)

# 	execute_strike(player2, player1, "uni_normal_sweep", "waldstein_sturmangriff", [], [], false, false)
# 	validate_positions(player1, 4, player2, 6)
# 	validate_life(player1, 25, player2, 30)
# 	advance_turn(player1)

# func test_waldstein_face_me_opponent_doesnt_strike():
# 	position_players(player1, 4, player2, 7)
# 	player1.hand = []
# 	give_player_specific_card(player1, "waldstein_sturmangriff", TestCardId3)
# 	assert_true(game_logic.do_boost(player1, TestCardId3, []))
# 	assert_eq(len(player1.hand), 3)

# 	advance_turn(player2)
# 	assert_eq(game_logic.game_state, Enums.GameState.GameState_WaitForStrike)

# 	execute_strike(player1, player2, "waldstein_sturmangriff", "uni_normal_sweep", [0], [], false, false)
# 	validate_positions(player1, 6, player2, 9)
# 	validate_life(player1, 27, player2, 25)
# 	advance_turn(player2)

# func test_waldstein_hecatoncheir_no_cards():
# 	position_players(player1, 4, player2, 6)
# 	player1.hand = []
# 	give_player_specific_card(player1, "waldstein_katastrophe", TestCardId3)
# 	assert_true(game_logic.do_boost(player1, TestCardId3, []))
# 	assert_eq(len(player1.hand), 1)
# 	advance_turn(player2)

# func test_waldstein_hecatoncheir_one_card():
# 	position_players(player1, 4, player2, 6)
# 	player1.hand = []
# 	give_player_specific_card(player1, "waldstein_katastrophe", TestCardId3)
# 	give_player_specific_card(player1, "uni_normal_grasp", TestCardId4)
# 	assert_true(game_logic.do_boost(player1, TestCardId3, []))
# 	assert_eq(len(player1.hand), 3)
# 	advance_turn(player2)

# func test_waldstein_hecatoncheir_several_cards():
# 	position_players(player1, 4, player2, 6)
# 	var hand_size = len(player1.hand)
# 	give_player_specific_card(player1, "waldstein_katastrophe", TestCardId3)
# 	assert_true(game_logic.do_boost(player1, TestCardId3, []))
# 	assert_eq(len(player1.hand), (hand_size*2) + 1)
# 	var cards = []
# 	var to_discard = player1.hand.size() - 7
# 	for i in range(to_discard):
# 		cards.append(player1.hand[i].id)
# 	assert_true(game_logic.do_discard_to_max(player1, cards))
# 	advance_turn(player2)

# func test_waldstein_the_destroyers_normal_hit():
# 	position_players(player1, 3, player2, 6)
# 	give_player_specific_card(player1, "waldstein_werfenerschlagen", TestCardId3)
# 	assert_true(game_logic.do_boost(player1, TestCardId3, []))
# 	advance_turn(player2)

# 	execute_strike(player1, player2, "uni_normal_grasp", "uni_normal_assault", [3], [], false, false)
# 	validate_positions(player1, 3, player2, 4)
# 	validate_life(player1, 30, player2, 25)
# 	assert_true(player1.is_card_in_discards(TestCardId3))
# 	advance_turn(player2)

# func test_waldstein_the_destroyers_normal_miss():
# 	position_players(player1, 3, player2, 4)
# 	give_player_specific_card(player1, "waldstein_werfenerschlagen", TestCardId3)
# 	assert_true(game_logic.do_boost(player1, TestCardId3, []))
# 	advance_turn(player2)

# 	execute_strike(player1, player2, "uni_normal_grasp", "uni_normal_assault", [], [], false, false)
# 	validate_positions(player1, 3, player2, 4)
# 	validate_life(player1, 26, player2, 30)
# 	assert_true(player1.is_card_in_hand(TestCardId3))
# 	advance_turn(player2)

# func test_waldstein_the_destroyers_special():
# 	position_players(player1, 3, player2, 4)
# 	give_player_specific_card(player1, "waldstein_werfenerschlagen", TestCardId3)
# 	assert_true(game_logic.do_boost(player1, TestCardId3, []))
# 	advance_turn(player2)

# 	execute_strike(player1, player2, "waldstein_wirbelwind", "uni_normal_sweep", [], [], false, false)
# 	validate_positions(player1, 5, player2, 7)
# 	validate_life(player1, 25, player2, 24)
# 	assert_true(player1.is_card_in_discards(TestCardId3))
# 	advance_turn(player2)

# func test_waldstein_verderben_faceup_initiate():
# 	position_players(player1, 3, player2, 6)
# 	give_gauge(player1, 4)
# 	give_player_specific_card(player1, "uni_normal_assault", TestCardId3)
# 	player1.move_card_from_hand_to_deck(TestCardId3)

# 	execute_strike(player1, player2, "waldstein_verderben", "uni_normal_sweep", [], [], false, false,
# 		[], [], 0, false, false, [], 0)
# 	validate_positions(player1, 3, player2, 6)
# 	validate_life(player1, 28, player2, 20)
# 	advance_turn(player2)

# func test_waldstein_verderben_faceup_response():
# 	position_players(player1, 3, player2, 6)
# 	give_gauge(player1, 4)
# 	give_player_specific_card(player1, "uni_normal_assault", TestCardId3)
# 	player1.move_card_from_hand_to_deck(TestCardId3)
# 	advance_turn(player1)

# 	execute_strike(player2, player1, "uni_normal_sweep", "waldstein_verderben", [], [], false, false,
# 		[], [], 0, false, false, [], 0)
# 	validate_positions(player1, 3, player2, 6)
# 	validate_life(player1, 28, player2, 20)
# 	advance_turn(player1)

# func test_waldstein_verderben_facedown():
# 	position_players(player1, 3, player2, 6)
# 	give_gauge(player1, 4)
# 	give_player_specific_card(player1, "uni_normal_assault", TestCardId3)
# 	player1.move_card_from_hand_to_deck(TestCardId3)

# 	execute_strike(player1, player2, "waldstein_verderben", "uni_normal_sweep", [], [], false, false,
# 		[], [], 0, false, false, [], 1)
# 	validate_positions(player1, 5, player2, 6)
# 	validate_life(player1, 24, player2, 26)
# 	assert_true(player1.is_card_in_discards(TestCardId1))
# 	assert_true(player1.is_card_in_gauge(TestCardId3))
# 	advance_turn(player1)

# func test_waldstein_verderben_wildswung():
# 	position_players(player1, 3, player2, 6)
# 	give_gauge(player1, 4)
# 	give_player_specific_card(player1, "uni_normal_assault", TestCardId3)
# 	player1.move_card_from_hand_to_deck(TestCardId3)
# 	give_player_specific_card(player1, "waldstein_verderben", TestCardId4)
# 	player1.move_card_from_hand_to_deck(TestCardId4)

# 	execute_strike(player1, player2, "", "uni_normal_sweep", [], [], false, false)
# 	validate_positions(player1, 5, player2, 6)
# 	validate_life(player1, 24, player2, 26)
# 	assert_true(player1.is_card_in_discards(TestCardId4))
# 	assert_true(player1.is_card_in_gauge(TestCardId3))
# 	advance_turn(player1)
