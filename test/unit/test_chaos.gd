extends ExceedGutTest

func who_am_i():
	return "chaos"


## Chaos Normal UA -- Action: Strike, placing your attack in any space
##     face-down. Your Special and Ultra attacks set in a space calculate Range
##     from that space.

func test_chaos_ua_special():
	position_players(player1, 2, player2, 7)
	assert_true(game_logic.do_character_action(player1, []))
	validate_has_event(game_logic.get_latest_events(),
			Enums.EventType.EventType_ForceStartStrike, player1)

	execute_strike(player1, player2, "chaos_spewout", "uni_normal_sweep",
			false, false, [5, 1], [])  # Set attack in space 5, Retreat 1 during After:
	validate_positions(player1, 1, player2, 7)
	validate_life(player1, 30, player2, 26)

func test_chaos_ua_normal():
	position_players(player1, 2, player2, 7)
	assert_true(game_logic.do_character_action(player1, []))

	execute_strike(player1, player2, "uni_normal_sweep", "uni_normal_sweep",
			false, false, [5], [])  # Set attack in space 5 (no real effect)
	validate_positions(player1, 2, player2, 7)
	validate_life(player1, 30, player2, 30)

## Cold Reflection (1~2/2/4) -- If this was not set in a space, +2 Speed.
##     Hit: Push 3 (from Chaos).

func test_chaos_cold_reflection_slow():
	position_players(player1, 2, player2, 4)
	assert_true(game_logic.do_character_action(player1, []))
	execute_strike(player1, player2, "chaos_coldreflection", "uni_normal_cross",
			false, false, [3], [])  # Set attack in space 3
	# Expected: Cold Reflection has 4 Speed when set in a space (and gets
	#     stunned by Cross on initiation)
	validate_positions(player1, 2, player2, 7)
	validate_life(player1, 27, player2, 30)

func test_chaos_cold_reflection_push_from_chaos():
	position_players(player1, 2, player2, 4)
	assert_true(game_logic.do_character_action(player1, []))
	execute_strike(player1, player2, "chaos_coldreflection", "uni_normal_spike",
			false, false, [5], [])  # Set attack in space 5
	# Expected: Cold Reflection pushes from space 4 to space 7 (from Chaos), not
	#     from space 4 to space 1 (from attack origin)
	validate_positions(player1, 2, player2, 7)
	validate_life(player1, 30, player2, 28)

func test_chaos_cold_reflection_fast():
	position_players(player1, 2, player2, 4)
	execute_strike(player1, player2, "chaos_coldreflection", "uni_normal_cross")
	# Expected: Cold Reflection has 6 Speed when not set in a space (outspeeds
	#     Cross on initiation)
	validate_positions(player1, 2, player2, 7)
	validate_life(player1, 30, player2, 28)

## Conceal (1~2/5/2) -- Attacks with Speed 5+ do not hit you. After: Retreat 1.

func test_chaos_conceal_dodge():
	position_players(player1, 2, player2, 5)
	execute_strike(player1, player2, "chaos_conceal", "uni_normal_assault")
	# Expected: Conceal auto-dodges Assault
	validate_positions(player1, 1, player2, 3)
	validate_life(player1, 30, player2, 25)

func test_chaos_conceal_no_dodge():
	position_players(player1, 2, player2, 5)
	execute_strike(player1, player2, "chaos_conceal", "uni_normal_spike")
	# Expected: Conceal does not auto-dodge Spike
	validate_positions(player1, 2, player2, 5)
	validate_life(player1, 25, player2, 30)

func test_chaos_conceal_ex_dodge():
	position_players(player1, 2, player2, 6)
	execute_strike(player1, player2, "chaos_conceal", "uni_normal_dive", false, true)
	# Expected: Conceal auto-dodges EX Dive (hits for 5 - 1)
	validate_positions(player1, 1, player2, 3)
	validate_life(player1, 30, player2, 26)

func test_chaos_conceal_boosted_dodge():
	position_players(player1, 2, player2, 6)
	advance_turn(player1)
	var sweep_id = give_player_specific_card(player2, "standard_normal_sweep")
	assert_true(game_logic.do_boost(player2, sweep_id))  # +2 Speed
	execute_strike(player1, player2, "chaos_conceal", "uni_normal_dive")
	# Expected: Conceal auto-dodges Dive + Light
	validate_positions(player1, 1, player2, 3)
	validate_life(player1, 30, player2, 25)

## Repel (0/5/3) -- If this was set in a space, the opponent cannot advance or
##     retreat into that space.
##     Hit: Push 2 (from Chaos).

func test_chaos_repel_null():
	position_players(player1, 3, player2, 5)
	execute_strike(player1, player2, "chaos_repel", "uni_normal_dive")
	validate_positions(player1, 3, player2, 1)
	validate_life(player1, 30, player2, 30)

func test_chaos_repel_block_advance():
	position_players(player1, 2, player2, 6)
	assert_true(game_logic.do_character_action(player1, []))
	execute_strike(player1, player2, "chaos_repel", "uni_normal_dive", false, false, [4], [])
	validate_positions(player1, 2, player2, 5)
	validate_life(player1, 30, player2, 30)

func test_chaos_repel_block_close():
	position_players(player1, 2, player2, 5)
	assert_true(game_logic.do_character_action(player1, []))
	execute_strike(player1, player2, "chaos_repel", "uni_normal_assault", false, false, [4], [])
	validate_positions(player1, 2, player2, 5)
	validate_life(player1, 30, player2, 30)

func test_chaos_repel_block_retreat():
	position_players(player1, 2, player2, 4)
	assert_true(game_logic.do_character_action(player1, []))
	execute_strike(player1, player2, "chaos_repel", "uni_normal_cross", false, false, [5], [])
	validate_positions(player1, 2, player2, 4)
	validate_life(player1, 27, player2, 30)

# func test_chaos_repel_no_block_own_space():
# 	position_players(player1, 2, player2, 5)
# 	assert_true(game_logic.do_character_action(player1, []))
# 	execute_strike(player1, player2, "chaos_repel", "uni_normal_dive", false, false, [2], [])
# 	validate_positions(player1, 2, player2, 1)
# 	validate_life(player1, 25, player2, 30)

func test_chaos_repel_no_block_opponent_space():
	position_players(player1, 2, player2, 5)
	assert_true(game_logic.do_character_action(player1, []))
	execute_strike(player1, player2, "chaos_repel", "uni_normal_assault", false, false, [5], [])
	validate_positions(player1, 2, player2, 3)
	validate_life(player1, 26, player2, 30)

func test_chaos_repel_no_block_sandwich():
	position_players(player1, 2, player2, 5)
	assert_true(game_logic.do_character_action(player1, []))
	execute_strike(player1, player2, "chaos_repel", "uni_normal_assault", false, false, [7], [])
	validate_positions(player1, 2, player2, 3)
	validate_life(player1, 26, player2, 30)

## Dissect Barrage [2] (1~2/5/5) -- Calculate Range from Chaos (even if this was set in space).
##     After: If this was set in a space, Advance or Retreat to that space.

func test_chaos_dissect_barrage_from_chaos():
	position_players(player1, 2, player2, 4)
	var p1_gauge = give_gauge(player1, 2)
	assert_true(game_logic.do_character_action(player1, []))
	execute_strike(player1, player2, "chaos_dissectbarrage", "uni_normal_sweep",
			false, false, [8, p1_gauge], [])  # Set attack in space 8
	# Expected: Dissect Barrage still hits, and the After: advances out of range of Sweep
	validate_positions(player1, 8, player2, 4)
	validate_life(player1, 30, player2, 25)

func test_chaos_dissect_barrage_on_opponent():
	position_players(player1, 2, player2, 4)
	var p1_gauge = give_gauge(player1, 2)
	assert_true(game_logic.do_character_action(player1, []))
	execute_strike(player1, player2, "chaos_dissectbarrage", "uni_normal_assault",
			false, false, [4, p1_gauge], [])
	# Expected: Attempting to advance to an occupied space is just like Closing.
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 30, player2, 25)

func test_chaos_dissect_barrage_on_self():
	position_players(player1, 2, player2, 4)
	var p1_gauge = give_gauge(player1, 2)
	assert_true(game_logic.do_character_action(player1, []))
	execute_strike(player1, player2, "chaos_dissectbarrage", "uni_normal_assault",
			false, false, [2, p1_gauge], [])
	# Expected: No movement
	validate_positions(player1, 2, player2, 4)
	validate_life(player1, 30, player2, 25)

func test_chaos_dissect_barrage_without_ua():
	position_players(player1, 2, player2, 4)
	var p1_gauge = give_gauge(player1, 2)
	execute_strike(player1, player2, "chaos_dissectbarrage", "uni_normal_assault",
			false, false, [p1_gauge], [])
	# Expected: No movement
	validate_positions(player1, 2, player2, 4)
	validate_life(player1, 30, player2, 25)

## Deep Revenance Boost -- (1 Force) Now: Strike, placing your attack in any
##     space-face-down. If you reveal a Normal attack, calculate Range from that
##     space.

func test_chaos_chaos_code_normal():
	position_players(player1, 2, player2, 7)
	var boost_id = give_player_specific_card(player1, "chaos_deeprevenance")
	assert_true(game_logic.do_boost(player1, boost_id, [player1.hand[0].id]))
	execute_strike(player1, player2, "uni_normal_sweep", "uni_normal_sweep",
				false, false, [5], [])
	# Expected: Sweep measures range from space 5
	validate_positions(player1, 2, player2, 7)
	validate_life(player1, 30, player2, 24)

func test_chaos_chaos_code_special():
	position_players(player1, 2, player2, 7)
	var boost_id = give_player_specific_card(player1, "chaos_deeprevenance")
	assert_true(game_logic.do_boost(player1, boost_id, [player1.hand[0].id]))
	execute_strike(player1, player2, "chaos_spewout", "uni_normal_sweep",
			false, false, [5, 1], [])  # Set attack in space 5, After: Retreat 1
	# Expected: Spew Out measures range from Chaos
	validate_positions(player1, 1, player2, 7)
	validate_life(player1, 30, player2, 30)
