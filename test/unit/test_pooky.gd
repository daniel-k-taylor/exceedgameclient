extends ExceedGutTest

func who_am_i():
	return "pooky"

func get_custom_cards():
	return [
		{
			"id": "custom_immediate_noeffect",
			"type": "special",
			"display_name": "Test Tipple",
			"force_cost": 0,
			"gauge_cost": 0,
			"range_min": 1,
			"range_max": 1,
			"power": 1,
			"speed": 1,
			"armor": 0,
			"guard": 0,
			"effects": [],
			"boost": {
				"boost_type": "immediate",
				"force_cost": 0,
				"cancel_cost": -1,
				"display_name": "Test Tipple",
				"effects": []
			}
		}
	]

func add_continuous_boost(player, def_id):
	var boost_id = give_player_specific_card(player, def_id)
	var boost_card = game_logic.get_card_database().get_card(boost_id)
	player.add_to_continuous_boosts(boost_card)
	player.hand.erase(boost_card)
	return boost_id

func test_pooky_dragon_breath_ale_extends_range_outside_strike():
	position_players(player1, 3, player2, 6)
	var boost_id = give_player_specific_card(player1, "pooky_snackattack")
	var attack_id = give_player_specific_card(player1, "pooky_snackattack")
	var attack_card = game_logic.get_card_database().get_card(attack_id)

	assert_false(player1.does_card_contain_range_to_opponent(attack_id))
	assert_true(game_logic.do_boost(player1, boost_id))
	assert_eq(player1.continuous_boosts.size(), 1)
	assert_eq(player1.build_outside_strike_range_effect_list().size(), 1)
	assert_eq(player1.get_total_max_range_bonus(attack_card), 1)
	assert_true(player1.does_card_contain_range_to_opponent(attack_id))

func test_pooky_gambling_reveal_chains_into_second_gambling():
	position_players(player1, 3, player2, 6)
	var first_gambling_id = give_player_specific_card(player1, "pooky_gamblingimin")
	set_player_topdeck(player1, "standard_normal_spike")
	set_player_topdeck(player1, "pooky_gamblingimin")

	execute_strike(player1, player2, first_gambling_id, "standard_normal_sweep", false, false, [], [])

	validate_life(player1, 30, player2, 23)

func test_pooky_long_intooth_with_boost_applies_range_bonus_without_crash():
	position_players(player1, 3, player2, 6)
	var boost_id = give_player_specific_card(player1, "pooky_snackattack")
	var boost_card = game_logic.get_card_database().get_card(boost_id)
	player1.add_to_continuous_boosts(boost_card)
	player1.hand.erase(boost_card)

	execute_strike(player1, player2, "pooky_longintooth", "standard_normal_block", false, false, [], [[]])

	validate_life(player1, 30, player2, 27)

func test_pooky_speedup_with_continuous_boost_wins_speed_tie():
	# Long in the Tooth base speed 2; with a continuous boost the base ability
	# grants +1 Speed, tying the opponent's Spike (speed 3). Initiator wins ties
	# and stuns Spike before it can retaliate.
	position_players(player1, 3, player2, 6)
	add_continuous_boost(player1, "pooky_pookycheats")

	execute_strike(player1, player2, "pooky_longintooth", "standard_normal_spike", false, false, [], [])

	# Player 1 struck first (25 damage to opponent), took none in return.
	validate_life(player1, 30, player2, 25)

func test_pooky_range_per_cb_extends_to_distance_four_with_two_boosts():
	# Long in the Tooth gains +0-1 max range per continuous boost. With two
	# continuous boosts it reaches r1-4 and connects at distance 4.
	position_players(player1, 1, player2, 5)
	add_continuous_boost(player1, "pooky_pookycheats")
	add_continuous_boost(player1, "pooky_pookycheats")

	execute_strike(player1, player2, "pooky_longintooth", "standard_normal_block", false, false, [0], [[]])

	# Power 5 minus Block armor 2 = 3 damage; would be 0 (miss) without range boost.
	validate_life(player1, 30, player2, 27)

func test_pooky_power_per_cb_drunken_rampage():
	# Drunken Rampage gains +2 Power per continuous boost on hit.
	position_players(player1, 1, player2, 5)
	add_continuous_boost(player1, "pooky_snackattack")
	add_continuous_boost(player1, "pooky_snackattack")
	var gauge_ids = give_gauge(player1, 2)

	execute_strike(player1, player2, "pooky_drunkenrampage", "standard_normal_block", false, false, [gauge_ids, 1], [[]])

	# Base power 1 + (2 boosts * 2) = 5, minus Block armor 2 = 3 damage.
	validate_life(player1, 30, player2, 27)

func test_pooky_exceeded_powerup_armorup_with_two_boosts():
	# When exceeded with two or more continuous boosts, Specials/Ultras gain
	# +2 Power and +1 Armor.
	position_players(player1, 3, player2, 6)
	player1.exceeded = true
	add_continuous_boost(player1, "pooky_pookycheats")
	add_continuous_boost(player1, "pooky_pookycheats")

	# Opponent Pooky Cheats (speed 3) strikes first and hits for 3 - 1 armor = 2.
	# Long in the Tooth (power 5 + 2 = 7, range extended to r1-4) then hits for 7.
	execute_strike(player1, player2, "pooky_longintooth", "pooky_pookycheats", false, false, [0], [1])

	validate_life(player1, 28, player2, 23)

func test_pooky_stunned_draw_on_exceed():
	# Exceed passive: the first time Pooky is stunned each strike, draw a card.
	position_players(player1, 3, player2, 6)
	player1.exceeded = true
	var hand_before = player1.hand.size()

	# Spike (ignore_armor + ignore_guard) strikes first and stuns Pooky Drinks.
	execute_strike(player1, player2, "pooky_pookydrinks", "standard_normal_spike", false, false, [], [])

	validate_life(player1, 25, player2, 30)
	assert_eq(player1.hand.size(), hand_before + 1)

func test_pooky_drunken_fury_boost_enters_strike():
	# Drunken Fury transform: first immediate boost each turn, may pay 1 force to strike.
	add_transform(player1, "pooky_drunkenrampage")
	var gauge_ids = give_gauge(player1, 1)
	var boost_id = give_player_specific_card(player1, "custom_immediate_noeffect")

	assert_true(game_logic.do_boost(player1, boost_id))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ForceForEffect)
	assert_true(game_logic.do_force_for_effect(player1, gauge_ids, false))

	assert_eq(game_logic.game_state, Enums.GameState.GameState_WaitForStrike)

func test_pooky_zols_recipe_redirects_boost_to_facedown_continuous():
	# Zol's Secret Recipe transform: first immediate boost each turn, may pay 1
	# force to place it into play as a facedown continuous boost.
	add_transform(player1, "pooky_hattrick")
	var gauge_ids = give_gauge(player1, 1)
	var boost_id = give_player_specific_card(player1, "custom_immediate_noeffect")

	assert_true(game_logic.do_boost(player1, boost_id))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ForceForEffect)
	assert_true(game_logic.do_force_for_effect(player1, gauge_ids, false))

	assert_eq(player1.continuous_boosts.size(), 1)
	assert_true(player1.is_card_in_continuous_boosts(boost_id))
	var boost_card = game_logic.get_card_database().get_card(boost_id)
	assert_eq(boost_card.definition['boost']['display_name'], "Zol's Brew")
	assert_true(boost_card.definition['boost']['facedown'])
