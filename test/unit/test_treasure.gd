extends ExceedGutTest

func who_am_i():
	return "treasure"

func original_execute_strike(initiator, defender, init_card : String, def_card : String, init_choices, def_choices, init_ex = false, def_ex = false,
		init_use_free_force = false, def_force_discard = [], init_extra_cost = 0, init_force_special = false):
	pass

##
## Tests start here
##

# Treasure Knight Normal UA: When spending Force during a Strike, you may generate 1 Force for free.

func test_treasure_anchor_launch_force_special_discount():
	position_players(player1, 3, player2, 8)
	var other_hand_size = len(player2.hand)

	# Use free force to pay for Anchor Launch (1-cost Force Special)
	execute_strike(player1, player2, "treasure_anchorlaunch", "standard_normal_grasp",
			false, false, [[true]], [])  # Pay 0 real Force and 1 free Force for Anchor Launch
	# Anchor Launch Hit: The opponent discards a card at random...
	assert_eq(len(player2.hand), other_hand_size-1)
	#     Then, pull until they're at range 2.
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 30, player2, 24)
	advance_turn(player2)

func test_treasure_aqua_mine_force_for_effect_discount():
	position_players(player1, 4, player2, 5)

	# Aqua Mine After: Spend up to 2 Force to retreat that much.
	execute_strike(player1, player2, "treasure_aquamine", "standard_normal_assault",
			false, false, [[player1.hand[0].id, true]], [])  # Pay 1 + 1 free Force for Aqua Mine
	validate_positions(player1, 2, player2, 5)
	# Aqua Mine hits for 5; no +POW because Assault didn't actually move
	validate_life(player1, 26, player2, 25)
	advance_turn(player2)

func test_treasure_aqua_mine_zero_effect_decline_discount():
	position_players(player1, 4, player2, 5)

	# Aqua Mine After: Spend up to 2 Force to retreat that much.
	execute_strike(player1, player2, "treasure_aquamine", "standard_normal_assault",
			false, false, [[true, true]], [])  # Decline the After: effect completely.
	validate_positions(player1, 4, player2, 5)
	# Aqua Mine hits for 5; no +POW because Assault didn't actually move
	validate_life(player1, 26, player2, 25)
	advance_turn(player2)

func test_treasure_block_force_for_armor_discount():
	position_players(player1, 4, player2, 6)

	execute_strike(player1, player2, "standard_normal_block", "standard_normal_sweep",
			false, false, [[true]], [])  # Use only the free force for Block Armor (4 total)
	validate_positions(player1, 4, player2, 6)
	validate_life(player1, 28, player2, 30)
	advance_turn(player2)

func test_treasure_discount_during_strike_only():
	position_players(player1, 4, player2, 6)

	execute_strike(player1, player2, "standard_normal_block", "standard_normal_sweep",
			false, false, [[true]], [])  # Use only the free force for Block Armor (4 total)
	validate_positions(player1, 4, player2, 6)
	validate_life(player1, 28, player2, 30)
	advance_turn(player2)
	# Even though we have set the "use_free_force" bit to `true`, Treasure
	# Knight shouldn't have any free force to use in Normal Mode outside of a
	# Strike.
	assert_false(game_logic.do_move(player1, [], 3, true))

# Treasure Knight Exceed UA: When you Exceed, pull up to 3.
#     When spending Force, you may generate 1 Force for free.

func test_treasure_pull_on_exceed():
	position_players(player1, 4, player2, 7)
	var p1_gauge = give_gauge(player1, 3)
	assert_true(game_logic.do_exceed(player1, p1_gauge))
	assert_true(game_logic.do_choice(player1, 2))  # pull 3
	validate_positions(player1, 4, player2, 3)

func test_treasure_exceed_move_discount():
	position_players(player1, 4, player2, 7)

	# TODO :: Figure out why the engine has a game_state waiting for a player choice
	#     (the pull that happens upon exceed), but doesn't let the choice actually
	#     be made (trips the assertion at local_game.gd:10467).
	# player1.exceed()
	# assert_true(game_logic.do_choice(player1, 3))

	var p1_gauge = give_gauge(player1, 3)
	assert_true(game_logic.do_exceed(player1, p1_gauge))
	assert_true(game_logic.do_choice(player1, 3))  # pull 0
	validate_positions(player1, 4, player2, 7)
	advance_turn(player2)

	assert_true(game_logic.do_move(player1, [player1.hand[0].id], 6, true))
	validate_positions(player1, 6, player2, 7)

func test_treasure_anchor_zip_exceed_boost_discount():
	position_players(player1, 4, player2, 7)
	var p1_gauge = give_gauge(player1, 3)
	player1.hand = []
	assert_true(game_logic.do_exceed(player1, p1_gauge))
	assert_true(game_logic.do_choice(player1, 3))  # pull 0
	advance_turn(player2)

	# Anchor Launch boost (Cost 1): Move up to 4, then draw 2.
	var anchor_id = give_player_specific_card(player1, "treasure_anchorlaunch")
	assert_true(game_logic.do_boost(player1, anchor_id, [], true))
	assert_true(game_logic.do_choice(player1, select_space(9)))
	validate_positions(player1, 9, player2, 7)
	assert_eq(len(player1.hand), 4)  # Two cards from boost, two cards from turn ends
	advance_turn(player2)

# func test_treasure_exceed_change_cards_discard():
# 	position_players(player1, 4, player2, 7)
# 	give_gauge(player1, 3)
# 	assert_true(game_logic.do_exceed(player1, [player1.gauge[0].id, player1.gauge[1].id, player1.gauge[2].id]))
# 	assert_true(game_logic.do_choice(player1, 3))
# 	advance_turn(player2)

# 	player1.hand = []
# 	assert_true(game_logic.do_change(player1, [], false, true))
# 	assert_eq(len(player1.hand), 2)
# 	advance_turn(player2)

# func test_treasure_anchor_launch_miss():
# 	position_players(player1, 1, player2, 3)

# 	execute_strike(player1, player2, "treasure_anchorlaunch", "standard_normal_grasp", [1], [], false, false, true,
# 		[], 0, true)
# 	validate_positions(player1, 7, player2, 3)
# 	validate_life(player1, 30, player2, 30)
# 	advance_turn(player2)

# func test_treasure_anchor_launch_pull_tinker_tank_to_range_2():
# 	game_logic.teardown()
# 	game_logic.free()
# 	default_game_setup("tinker")

# 	give_gauge(player2, 5)
# 	player2.life = 1
# 	position_players(player1, 3, player2, 4)
# 	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault", [], [], false, false)
# 	assert_eq(player2.extra_width, 1)
# 	validate_positions(player1, 3, player2, 7)
# 	validate_life(player1, 30, player2, 20)
# 	player1.gauge = []

# 	position_players(player1, 8, player2, 1)
# 	execute_strike(player1, player2, "treasure_anchorlaunch", "standard_normal_grasp", [], [], false, false, true,
# 		[], 0, true)
# 	validate_positions(player1, 8, player2, 5)
# 	validate_life(player1, 30, player2, 14)
# 	advance_turn(player2)

# func test_treasure_anchor_launch_pull_tinker_tank_at_range_2():
# 	game_logic.teardown()
# 	game_logic.free()
# 	default_game_setup("tinker")

# 	give_gauge(player2, 5)
# 	player2.life = 1
# 	position_players(player1, 3, player2, 4)
# 	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault", [], [], false, false)
# 	assert_eq(player2.extra_width, 1)
# 	validate_positions(player1, 3, player2, 7)
# 	validate_life(player1, 30, player2, 20)
# 	player1.gauge = []

# 	position_players(player1, 5, player2, 8)
# 	execute_strike(player1, player2, "treasure_anchorlaunch", "standard_normal_grasp", [], [], false, false, true,
# 		[], 0, true)
# 	validate_positions(player1, 5, player2, 8)
# 	validate_life(player1, 30, player2, 14)
# 	advance_turn(player2)

# func test_treasure_anchor_launch_pull_tinker_tank_at_range_1():
# 	game_logic.teardown()
# 	game_logic.free()
# 	default_game_setup("tinker")

# 	give_gauge(player2, 5)
# 	player2.life = 1
# 	position_players(player1, 3, player2, 4)
# 	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault", [], [], false, false)
# 	assert_eq(player2.extra_width, 1)
# 	validate_positions(player1, 3, player2, 7)
# 	validate_life(player1, 30, player2, 20)
# 	player1.gauge = []

# 	position_players(player1, 5, player2, 7)
# 	execute_strike(player1, player2, "treasure_anchorlaunch", "standard_normal_spike", [], [], false, false, true,
# 		[], 0, true)
# 	validate_positions(player1, 5, player2, 2)
# 	validate_life(player1, 30, player2, 14)
# 	advance_turn(player2)

# func test_treasure_anchor_launch_pull_tinker_tank_blocked():
# 	game_logic.teardown()
# 	game_logic.free()
# 	default_game_setup("tinker")

# 	give_gauge(player2, 5)
# 	player2.life = 1
# 	position_players(player1, 3, player2, 4)
# 	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault", [], [], false, false)
# 	assert_eq(player2.extra_width, 1)
# 	validate_positions(player1, 3, player2, 7)
# 	validate_life(player1, 30, player2, 20)
# 	player1.gauge = []

# 	position_players(player1, 3, player2, 5)
# 	execute_strike(player1, player2, "treasure_anchorlaunch", "standard_normal_spike", [], [], false, false, true,
# 		[], 0, true)
# 	validate_positions(player1, 3, player2, 5)
# 	validate_life(player1, 30, player2, 14)
# 	advance_turn(player2)

# func test_treasure_anchor_launch_pull_tinker_tank_boundary():
# 	game_logic.teardown()
# 	game_logic.free()
# 	default_game_setup("tinker")

# 	give_gauge(player2, 5)
# 	player2.life = 1
# 	position_players(player1, 3, player2, 4)
# 	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault", [], [], false, false)
# 	assert_eq(player2.extra_width, 1)
# 	validate_positions(player1, 3, player2, 7)
# 	validate_life(player1, 30, player2, 20)
# 	player1.gauge = []

# 	position_players(player1, 6, player2, 4)
# 	execute_strike(player1, player2, "treasure_anchorlaunch", "standard_normal_spike", [], [], false, false, true,
# 		[], 0, true)
# 	validate_positions(player1, 6, player2, 8)
# 	validate_life(player1, 30, player2, 14)
# 	advance_turn(player2)

# func test_treasure_dive_charge_full_push():
# 	position_players(player1, 2, player2, 5)

# 	execute_strike(player1, player2, "treasure_divecharge", "standard_normal_grasp", [], [], false, false)
# 	validate_positions(player1, 4, player2, 8)
# 	validate_life(player1, 30, player2, 27)
# 	advance_turn(player2)

# func test_treasure_dive_charge_focus():
# 	position_players(player1, 2, player2, 5)

# 	execute_strike(player1, player2, "treasure_divecharge", "standard_normal_focus", [], [], false, false)
# 	validate_positions(player1, 4, player2, 5)
# 	validate_life(player1, 26, player2, 26)
# 	advance_turn(player2)

# func test_treasure_dive_charge_wall():
# 	position_players(player1, 5, player2, 8)

# 	execute_strike(player1, player2, "treasure_divecharge", "standard_normal_grasp", [], [], false, false)
# 	validate_positions(player1, 7, player2, 9)
# 	validate_life(player1, 30, player2, 25)
# 	advance_turn(player2)

# func test_treasure_redistribute_simple():
# 	position_players(player1, 3, player2, 7)
# 	give_player_specific_card(player1, "treasure_divecharge", TestCardId3)

# 	var topdeck_ids = [800001, 800002] # one card drawn at end of turn, one retrieved from boost
# 	for topdeck_id in topdeck_ids:
# 		give_player_specific_card(player1, "standard_normal_grasp", topdeck_id)
# 		player1.move_card_from_hand_to_deck(topdeck_id)

# 	assert_true(game_logic.do_boost(player1, TestCardId3, [player1.hand[0].id]))
# 	advance_turn(player2)

# 	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_grasp", [], [], false, false)
# 	validate_positions(player1, 3, player2, 7)
# 	validate_life(player1, 30, player2, 30)
# 	assert_true(TestCardId3 not in player1.underboost_map)
# 	for topdeck_id in topdeck_ids:
# 		assert_true(player1.is_card_in_hand(topdeck_id))
# 	assert_true(player1.is_card_in_discards(TestCardId3))
# 	advance_turn(player2)

# func test_treasure_redistribute_multiple_turns():
# 	position_players(player1, 3, player2, 7)
# 	give_player_specific_card(player1, "treasure_divecharge", TestCardId3)

# 	var topdeck_ids = [800001, 800002, 800003, 800004, 800005, 800006]
# 	for topdeck_id in topdeck_ids:
# 		give_player_specific_card(player1, "standard_normal_grasp", topdeck_id)
# 		player1.move_card_from_hand_to_deck(topdeck_id)

# 	assert_true(game_logic.do_boost(player1, TestCardId3, [player1.hand[0].id]))
# 	advance_turn(player2)

# 	# 2 more cards under boost
# 	advance_turn(player1)
# 	advance_turn(player2)
# 	advance_turn(player1)
# 	advance_turn(player2)

# 	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_grasp", [], [], false, false)
# 	validate_positions(player1, 3, player2, 7)
# 	validate_life(player1, 30, player2, 30)
# 	assert_true(TestCardId3 not in player1.underboost_map)
# 	for topdeck_id in topdeck_ids:
# 		assert_true(player1.is_card_in_hand(topdeck_id))
# 	assert_true(player1.is_card_in_discards(TestCardId3))
# 	advance_turn(player2)

# func test_treasure_redistribute_teched():
# 	position_players(player1, 3, player2, 7)
# 	give_player_specific_card(player1, "treasure_divecharge", TestCardId3)

# 	var topdeck_ids = [800001, 800002]
# 	for topdeck_id in topdeck_ids:
# 		give_player_specific_card(player1, "standard_normal_grasp", topdeck_id)
# 		player1.move_card_from_hand_to_deck(topdeck_id)

# 	assert_true(game_logic.do_boost(player1, TestCardId3, [player1.hand[0].id]))

# 	give_player_specific_card(player2, "standard_normal_dive", TestCardId4)
# 	assert_true(game_logic.do_boost(player2, TestCardId4, []))
# 	assert_true(game_logic.do_boost_name_card_choice_effect(player2, TestCardId3))

# 	for topdeck_id in topdeck_ids:
# 		assert_true(player1.is_card_in_hand(topdeck_id))
# 	assert_true(player1.is_card_in_discards(TestCardId3))
# 	advance_turn(player1)

# func test_treasure_treasure_coin_no_discard():
# 	position_players(player1, 2, player2, 5)

# 	execute_strike(player1, player2, "treasure_treasurecoin", "standard_normal_grasp", [], [], false, false)
# 	assert_true(game_logic.do_force_for_effect(player1, [], false, false, true))
# 	validate_positions(player1, 2, player2, 5)
# 	validate_life(player1, 30, player2, 26)
# 	assert_eq(len(player1.gauge), 1)
# 	advance_turn(player2)

# func test_treasure_treasure_coin_coin_discard():
# 	position_players(player1, 2, player2, 5)
# 	give_player_specific_card(player1, "treasure_treasurecoin", TestCardId3)
# 	player1.discard([TestCardId3])

# 	execute_strike(player1, player2, "treasure_treasurecoin", "standard_normal_grasp", [], [], false, false)
# 	assert_true(game_logic.do_force_for_effect(player1, [], false, false, true))
# 	validate_positions(player1, 2, player2, 5)
# 	validate_life(player1, 30, player2, 26)
# 	assert_eq(len(player1.gauge), 2)
# 	advance_turn(player2)

# func test_treasure_secure_vault_no_gauge():
# 	position_players(player1, 2, player2, 5)
# 	player1.hand = []
# 	player1.draw(1)
# 	var old_card_id = player1.hand[0].id
# 	give_player_specific_card(player1, "treasure_anglercall", TestCardId3)

# 	assert_true(game_logic.do_boost(player1, TestCardId3, [old_card_id]))
# 	advance_turn(player2)
# 	assert_eq(len(player1.hand), 1)
# 	var hand_card_id = player1.hand[0].id

# 	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_grasp", [], [], false, false)
# 	assert_true(game_logic.do_force_for_effect(player1, [hand_card_id], false, false, true))
# 	validate_positions(player1, 2, player2, 5)
# 	validate_life(player1, 30, player2, 24)
# 	assert_eq(len(player1.gauge), 3)
# 	assert_true(player1.is_card_in_gauge(old_card_id))
# 	assert_true(player1.is_card_in_gauge(hand_card_id))
# 	assert_eq(len(player1.hand), 1)
# 	advance_turn(player2)

# func test_treasure_secure_vault_big_gauge():
# 	position_players(player1, 2, player2, 5)
# 	give_gauge(player1, 5)
# 	player1.hand = []
# 	player1.draw(1)
# 	var old_card_id = player1.hand[0].id
# 	give_player_specific_card(player1, "treasure_anglercall", TestCardId3)

# 	assert_true(game_logic.do_boost(player1, TestCardId3, [old_card_id]))
# 	advance_turn(player2)
# 	assert_eq(len(player1.hand), 1)
# 	var hand_card_id = player1.hand[0].id

# 	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_grasp", [], [], false, false)
# 	assert_true(game_logic.do_force_for_effect(player1, [hand_card_id], false, false, true))
# 	validate_positions(player1, 2, player2, 5)
# 	validate_life(player1, 30, player2, 24)
# 	assert_eq(len(player1.gauge), 8)
# 	assert_true(player1.is_card_in_gauge(old_card_id))
# 	assert_true(player1.is_card_in_gauge(hand_card_id))
# 	assert_eq(len(player1.hand), 6)
# 	advance_turn(player2)

# func test_treasure_maelstrom_chest_miss_from_self():
# 	position_players(player1, 2, player2, 1)
# 	give_gauge(player1, 3)

# 	execute_strike(player1, player2, "treasure_maelstromchest", "standard_normal_sweep", [], [], false, false)
# 	validate_positions(player1, 2, player2, 1)
# 	validate_life(player1, 24, player2, 30)
# 	advance_turn(player2)

# func test_treasure_maelstrom_chest_hit_from_center():
# 	position_players(player1, 2, player2, 5)
# 	give_gauge(player1, 3)

# 	execute_strike(player1, player2, "treasure_maelstromchest", "standard_normal_sweep", [], [], false, false)
# 	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id, player1.hand[1].id, player1.hand[2].id], false, false, true))
# 	validate_positions(player1, 2, player2, 5)
# 	validate_life(player1, 30, player2, 22)
# 	advance_turn(player2)

# func test_treasure_diving_suit_not_hit():
# 	position_players(player1, 3, player2, 7)
# 	give_player_specific_card(player1, "treasure_maelstromchest", TestCardId3)

# 	assert_true(game_logic.do_boost(player1, TestCardId3, [player1.hand[0].id]))
# 	advance_turn(player2)

# 	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_sweep", [], [], false, false)
# 	validate_positions(player1, 3, player2, 7)
# 	validate_life(player1, 30, player2, 30)
# 	advance_turn(player2)

# func test_treasure_diving_suit_hit():
# 	position_players(player1, 3, player2, 6)
# 	give_player_specific_card(player1, "treasure_maelstromchest", TestCardId3)

# 	assert_true(game_logic.do_boost(player1, TestCardId3, [player1.hand[0].id]))
# 	advance_turn(player2)

# 	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_sweep", [], [], false, false)
# 	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id], false, false, true))
# 	validate_positions(player1, 3, player2, 6)
# 	validate_life(player1, 27, player2, 30)
# 	advance_turn(player2)

# func test_treasure_diving_suit_plus_block():
# 	position_players(player1, 3, player2, 6)
# 	give_player_specific_card(player1, "treasure_maelstromchest", TestCardId3)

# 	assert_true(game_logic.do_boost(player1, TestCardId3, [player1.hand[0].id]))
# 	advance_turn(player2)

# 	execute_strike(player1, player2, "standard_normal_block", "standard_normal_sweep", [], [], false, true)
# 	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id], false, false, true))
# 	assert_true(game_logic.do_force_for_armor(player1, [], true))
# 	validate_positions(player1, 3, player2, 6)
# 	validate_life(player1, 30, player2, 30)
# 	advance_turn(player2)
