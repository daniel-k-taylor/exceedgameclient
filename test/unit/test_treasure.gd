extends ExceedGutTest

func who_am_i():
	return "treasure"

##
## Tests start here
##

## Treasure Knight Normal UA: When spending Force during a Strike, you may generate 1 Force for free.

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

## Treasure Knight Exceed UA: When you Exceed, pull up to 3.
##     When spending Force, you may generate 1 Force for free.

func setup_exceeded_treasure_knight():
	var p1_gauge = give_gauge(player1, 3)
	assert_true(game_logic.do_exceed(player1, p1_gauge))
	assert_true(game_logic.do_choice(player1, 3))  # no pull
	advance_turn(player2)

func test_treasure_pull_on_exceed():
	position_players(player1, 4, player2, 7)
	var p1_gauge = give_gauge(player1, 3)
	assert_true(game_logic.do_exceed(player1, p1_gauge))
	assert_true(game_logic.do_choice(player1, 2))  # pull 3
	validate_positions(player1, 4, player2, 3)

func test_treasure_exceed_move_discount():
	setup_exceeded_treasure_knight()
	position_players(player1, 4, player2, 7)
	assert_true(game_logic.do_move(player1, [player1.hand[0].id], 6, true))
	validate_positions(player1, 6, player2, 7)

func test_treasure_anchor_zip_exceed_boost_discount():
	setup_exceeded_treasure_knight()
	position_players(player1, 4, player2, 7)
	player1.hand = []

	# Anchor Launch boost (Cost 1): Move up to 4, then draw 2.
	var anchor_id = give_player_specific_card(player1, "treasure_anchorlaunch")
	assert_true(game_logic.do_boost(player1, anchor_id, [], true))
	assert_true(game_logic.do_choice(player1, select_space(9)))
	validate_positions(player1, 9, player2, 7)
	assert_eq(len(player1.hand), 3)  # Two cards from boost, one card from turn end
	advance_turn(player2)

func test_treasure_exceed_change_cards_discard():
	setup_exceeded_treasure_knight()
	position_players(player1, 4, player2, 7)

	player1.hand = []
	assert_true(game_logic.do_change(player1, [], false, true))
	assert_eq(len(player1.hand), 2)
	advance_turn(player2)

## Anchor Launch (3~6/6/2|2/5) -- (1 Force) Hit: The opponent discards a card at
##     random. Then, pull until they're at range 2.
##     After: If this attack did not hit, advance 4, 5, or 6.

func test_treasure_anchor_launch_miss():
	position_players(player1, 1, player2, 3)

	execute_strike(player1, player2, "treasure_anchorlaunch", "standard_normal_grasp",
			false, false, [[true], 1], [])  # Use free Force; advance 5
	validate_positions(player1, 7, player2, 3)
	validate_life(player1, 30, player2, 30)
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

func test_treasure_anchor_launch_pull_tinker_tank_to_range_2():
	setup_exceeded_tinker_knight()
	position_players(player1, 8, player2, 1)
	execute_strike(player1, player2, "treasure_anchorlaunch", "standard_normal_grasp",
			false, false, [[true]], [])
	validate_positions(player1, 8, player2, 5)
	validate_life(player1, 30, player2, 14)
	advance_turn(player2)

func test_treasure_anchor_launch_pull_tinker_tank_at_range_2():
	setup_exceeded_tinker_knight()
	position_players(player1, 5, player2, 8)
	execute_strike(player1, player2, "treasure_anchorlaunch", "standard_normal_grasp",
			false, false, [[true]], [])
	validate_positions(player1, 5, player2, 8)
	validate_life(player1, 30, player2, 14)
	advance_turn(player2)

func test_treasure_anchor_launch_pull_tinker_tank_at_range_1():
	setup_exceeded_tinker_knight()
	position_players(player1, 5, player2, 7)
	execute_strike(player1, player2, "treasure_anchorlaunch", "standard_normal_spike",
			false, false, [[true]], [])
	validate_positions(player1, 5, player2, 2)
	validate_life(player1, 30, player2, 14)
	advance_turn(player2)

func test_treasure_anchor_launch_pull_tinker_tank_blocked():
	setup_exceeded_tinker_knight()
	position_players(player1, 3, player2, 5)
	execute_strike(player1, player2, "treasure_anchorlaunch", "standard_normal_spike",
			false, false, [[true]], [])
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 30, player2, 14)
	advance_turn(player2)

func test_treasure_anchor_launch_pull_tinker_tank_boundary():
	setup_exceeded_tinker_knight()
	position_players(player1, 6, player2, 4)
	execute_strike(player1, player2, "treasure_anchorlaunch", "standard_normal_spike",
			false, false, [[true]], [])
	validate_positions(player1, 6, player2, 8)
	validate_life(player1, 30, player2, 14)
	advance_turn(player2)

## Dive Charge (1/3/4|0/3) -- B: Close 2. H: Push 3; +1 for each space the
##     opponent could not be pushed.

func test_treasure_dive_charge_full_push():
	position_players(player1, 2, player2, 5)

	execute_strike(player1, player2, "treasure_divecharge", "standard_normal_grasp")
	validate_positions(player1, 4, player2, 8)
	validate_life(player1, 30, player2, 27)
	advance_turn(player2)

func test_treasure_dive_charge_focus():
	position_players(player1, 2, player2, 5)
	execute_strike(player1, player2, "treasure_divecharge", "standard_normal_focus")
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 26, player2, 26)
	advance_turn(player2)

func test_treasure_dive_charge_wall():
	position_players(player1, 5, player2, 8)

	execute_strike(player1, player2, "treasure_divecharge", "standard_normal_grasp")
	validate_positions(player1, 7, player2, 9)
	validate_life(player1, 30, player2, 25)
	advance_turn(player2)

## Dive Charge boost (1 Force) -- +2 POW. At the start of the opponent's turn,
##     place the top card of your deck face down under this boost. When this
##     boost leaves play, add all cards under it to your hand.

func test_treasure_redistribute_simple():
	position_players(player1, 3, player2, 7)
	var dive_charge_id = give_player_specific_card(player1, "treasure_divecharge")

	var start_of_turn_tuck = give_player_specific_card(player1, "standard_normal_grasp")
	player1.move_card_from_hand_to_deck(start_of_turn_tuck)
	var end_of_turn_draw = give_player_specific_card(player1, "standard_normal_grasp")
	player1.move_card_from_hand_to_deck(end_of_turn_draw)

	assert_true(game_logic.do_boost(player1, dive_charge_id, [player1.hand[0].id]))
	assert_true(player1.is_card_in_hand(end_of_turn_draw))

	execute_strike(player2, player1, "standard_normal_grasp", "standard_normal_grasp")
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 30)
	assert_true(dive_charge_id not in player1.underboost_map)
	assert_true(player1.is_card_in_hand(start_of_turn_tuck))
	assert_true(player1.is_card_in_discards(dive_charge_id))
	advance_turn(player1)

func test_treasure_redistribute_multiple_turns():
	position_players(player1, 3, player2, 7)

	var topdeck_ids = [player1.deck[1].id, player1.deck[3].id, player1.deck[5].id]
	var dummy_card_id = player1.deck[0].id

	var dive_charge_id = give_player_specific_card(player1, "treasure_divecharge")

	assert_true(game_logic.do_boost(player1, dive_charge_id, [player1.hand[0].id]))
	for turn in range(3):
		assert_true(player1.is_card_in_hand(dummy_card_id))
		assert_false(player1.is_card_in_hand(topdeck_ids[turn]))
		advance_turn(player2)
		player1.move_card_from_hand_to_deck(dummy_card_id)
		if turn != 2:
			advance_turn(player1)

	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_grasp")
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 30)
	assert_true(dive_charge_id not in player1.underboost_map)
	for topdeck_id in topdeck_ids:
		assert_true(player1.is_card_in_hand(topdeck_id))
	assert_true(player1.is_card_in_discards(dive_charge_id))

func test_treasure_redistribute_teched():
	position_players(player1, 3, player2, 7)
	var dive_charge_id = give_player_specific_card(player1, "treasure_divecharge")
	var dive_id = give_player_specific_card(player2, "standard_normal_dive")
	var topdeck_id = player1.deck[1].id

	assert_true(game_logic.do_boost(player1, dive_charge_id, [player1.hand[0].id]))
	assert_true(game_logic.do_boost(player2, dive_id, []))
	assert_true(game_logic.do_boost_name_card_choice_effect(player2, dive_charge_id))
	assert_true(player1.is_card_in_hand(topdeck_id))
	assert_true(player1.is_card_in_discards(dive_charge_id))
	advance_turn(player1)

## Treasure Coin (2/3/3|0/3) -- B: You may spend up to 3 Force. For each Force spent,
##     +0~1 RNG and +1 POW.
##     H: Add a Treasure Coin from your discard to your Gauge.

func test_treasure_treasure_coin_use_free_force():
	position_players(player1, 2, player2, 5)

	execute_strike(player1, player2, "treasure_treasurecoin", "standard_normal_grasp",
			false, false, [[true]], [])
	validate_positions(player1, 2, player2, 5)
	validate_life(player1, 30, player2, 26)
	assert_eq(len(player1.gauge), 1)
	advance_turn(player2)

func test_treasure_treasure_coin_coin_discard():
	position_players(player1, 2, player2, 5)

	execute_strike(player1, player2, "treasure_treasurecoin", "standard_normal_grasp",
			true, false, [[true]], [])  # EX strike should discard a copy of Treasure Coin after validation
	validate_positions(player1, 2, player2, 5)
	validate_life(player1, 30, player2, 25)
	assert_eq(len(player1.gauge), 2)
	advance_turn(player2)

## Angler Call boost (1 Force) -- H: Spend up to 2 Force. For each Force spent, add the top
##     card of your discard to your Gauge, then draw one card for every 2 Gauge you have.
##   (Note: The draw effect is also per Force spent.)

func test_treasure_secure_vault_no_gauge():
	position_players(player1, 2, player2, 5)
	var boost_cost_id = player1.hand[0].id
	var angler_call_id = give_player_specific_card(player1, "treasure_anglercall")

	assert_true(game_logic.do_boost(player1, angler_call_id, [boost_cost_id]))
	advance_turn(player2)
	assert_eq(len(player1.hand), 5)
	var effect_cost_id = player1.hand[0].id

	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_grasp",
			false, false, [0, [effect_cost_id, true]], [])  # Choose effect ordering before selecting discards
	validate_positions(player1, 2, player2, 5)
	validate_life(player1, 30, player2, 24)
	assert_eq(len(player1.gauge), 3)  # Two cards from discard plus the attack itself
	assert_true(player1.is_card_in_gauge(boost_cost_id))
	assert_true(player1.is_card_in_gauge(effect_cost_id))
	assert_eq(len(player1.hand), 5 - 1 + 1)  # Discarded effect_cost_id, drew 0 + 1 cards from effect
	advance_turn(player2)

func test_treasure_secure_vault_big_gauge():
	position_players(player1, 2, player2, 5)
	give_gauge(player1, 5)
	var boost_cost_id = player1.hand[0].id
	var angler_call_id = give_player_specific_card(player1, "treasure_anglercall")

	assert_true(game_logic.do_boost(player1, angler_call_id, [boost_cost_id]))
	advance_turn(player2)
	assert_eq(len(player1.hand), 5)
	var effect_cost_id = player1.hand[0].id

	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_grasp",
			false, false, [0, [effect_cost_id, true]], [])  # Choose effect ordering before selecting discards
	validate_positions(player1, 2, player2, 5)
	validate_life(player1, 30, player2, 24)
	assert_eq(len(player1.gauge), 5 + 3)  # Gained two cards from discard plus the attack itself
	assert_true(player1.is_card_in_gauge(boost_cost_id))
	assert_true(player1.is_card_in_gauge(effect_cost_id))
	assert_eq(len(player1.hand), 5 - 1 + 6)  # Discarded effect_cost_id, drew 3 + 3 cards from effect
	advance_turn(player2)

## Maelstrom Chest (3 Gauge) (0~1/4/5) -- Calculate Range from the center of the arena.
##     H: Spend up to 4 Force. For each Force spent, +1 POW.

func test_treasure_maelstrom_chest_miss_from_self():
	position_players(player1, 2, player2, 1)
	var p1_gauge = give_gauge(player1, 3)

	execute_strike(player1, player2, "treasure_maelstromchest", "standard_normal_sweep",
			false, false, [p1_gauge], [])
	validate_positions(player1, 2, player2, 1)
	validate_life(player1, 24, player2, 30)
	advance_turn(player2)

func test_treasure_maelstrom_chest_hit_from_center():
	position_players(player1, 2, player2, 5)
	var p1_gauge = give_gauge(player1, 3)
	var effect_cost_ids = player1.hand.slice(0, 3).map(func (card): return card.id)

	execute_strike(player1, player2, "treasure_maelstromchest", "standard_normal_sweep",
			false, false, [p1_gauge, effect_cost_ids + [true]], [])
	validate_positions(player1, 2, player2, 5)
	validate_life(player1, 30, player2, 22)
	advance_turn(player2)

## Maelstrom Chest boost (1 Force) -- When you are hit (after all H: effects),
##     you may spend 2 Force. If you did, +3 ARM.

func test_treasure_diving_suit_not_hit():
	position_players(player1, 3, player2, 7)
	var chest_id = give_player_specific_card(player1, "treasure_maelstromchest")

	assert_true(game_logic.do_boost(player1, chest_id, [player1.hand[0].id]))
	advance_turn(player2)

	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_sweep",
			false, false, [], [])
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 30)
	advance_turn(player2)

func test_treasure_diving_suit_hit():
	position_players(player1, 3, player2, 5)
	var chest_id = give_player_specific_card(player1, "treasure_maelstromchest")

	assert_true(game_logic.do_boost(player1, chest_id, [player1.hand[0].id]))
	advance_turn(player2)

	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_focus",
			false, false, [[player1.hand[0].id, true]], [])
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 29, player2, 30)
	advance_turn(player2)

func test_treasure_diving_suit_plus_block():
	position_players(player1, 3, player2, 6)
	var chest_id = give_player_specific_card(player1, "treasure_maelstromchest")

	assert_true(game_logic.do_boost(player1, chest_id, [player1.hand[0].id]))
	advance_turn(player2)

	execute_strike(player1, player2, "standard_normal_block", "standard_normal_sweep",
			false, true, [[player1.hand[0].id, true], [true]], [])
	# Blocking 7 damage from EX Sweep with 3 Armor from Boost (for 1 + 1 free Force) and
	# 2 + 2 Armor from Block (for 0 + 1 free Force).
	# Unlike other simultaneous trigger situations, no reordering decision is offered.
	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 30, player2, 30)
	advance_turn(player2)
