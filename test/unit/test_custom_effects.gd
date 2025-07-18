extends ExceedGutTest


func get_custom_cards():
	return [
		{
			"id": "custom_stealgauge",
			"type": "special",
			"display_name": "this is mine too",
			"force_cost": 0,
			"gauge_cost": 0,
			"range_min": 1,
			"range_max": 1,
			"power": 1,
			"speed": 7,
			"armor": 1,
			"guard": 0,
			"effects": [
				{
					"timing": "during_strike",
					"effect_type": "ignore_armor"
				},
				{
					"timing": "after",
					"condition": "opponent_stunned",
					"effect_type": "add_opponent_strike_to_gauge"
				}
			],
			"boost": {
				"boost_type": "continuous",
				"force_cost": 0,
				"cancel_cost": -1,
				"display_name": "here i come",
				"effects": [
					{
						"timing": "now",
						"effect_type": "strike"
					},
					{
						"timing": "before",
						"effect_type": "close",
						"amount": 4,
						"save_spaces_not_closed_as_strike_x": true,
						"and": {
							"effect_type": "powerup",
							"amount": "strike_x",
							"multiplier": 1
						}
					}
				]
			}
		},
		{
			"id": "custom_notfullpull",
			"type": "special",
			"display_name": "everybody get in here",
			"force_cost": 0,
			"gauge_cost": 0,
			"range_min": 1,
			"range_max": 3,
			"power": 2,
			"speed": 4,
			"armor": 0,
			"guard": 0,
			"effects": [
				{
					"timing": "before",
					"effect_type": "pull",
					"amount": 1,
					"bonus_effect": {
						"condition": "not_full_pull",
						"effect_type": "powerup",
						"amount": 5
					}
				}
			],
			"boost": {
				"boost_type": "continuous",
				"force_cost": 0,
				"cancel_cost": -1,
				"display_name": "i promise these stats are real",
				"effects": [
					{
						"timing": "now",
						"effect_type": "strike"
					},
					{
						"timing": "during_strike",
						"effect_type": "powerup",
						"amount": 3,
						"and": {
							"effect_type": "armorup",
							"amount": 3
						}
					},
					{
						"timing": "hit",
						"effect_type": "add_boost_to_gauge_on_strike_cleanup",
						"not_immediate": true
					}
				]
			}
		},
		{
			"id": "custom_reducecostperboost",
			"type": "ultra",
			"display_name": "Cheapskate",
			"force_cost": 0,
			"gauge_cost": 3,
			"gauge_cost_reduction": "per_boost_in_play",
			"range_min": 1,
			"range_max": 8,
			"power": 5,
			"speed": 6,
			"armor": 0,
			"guard": 0,
			"effects": [
				{
					"timing": "before",
					"effect_type": "close",
					"amount": 1
				}
			],
			"boost": {
				"boost_type": "continuous",
				"force_cost": 0,
				"cancel_cost": -1,
				"display_name": "what if i just don't care",
				"effects": [
					{
						"timing": "during_strike",
						"effect_type": "stun_immunity"
					}
				]
			}
		},
		{
			"id": "custom_powerupperarmor",
			"type": "special",
			"display_name": "Offense and Defense in Equal Measures",
			"force_cost": 0,
			"gauge_cost": 0,
			"range_min": 1,
			"range_max": 8,
			"power": 2,
			"speed": 6,
			"armor": 3,
			"guard": 0,
			"effects": [
				{
					"timing": "before",
					"effect_type": "powerup_per_armor",
					"amount": 1
				}
			],
			"boost": {
				"boost_type": "continuous",
				"force_cost": 0,
				"cancel_cost": -1,
				"display_name": "what if i just don't care",
				"effects": [
					{
						"timing": "during_strike",
						"effect_type": "stun_immunity"
					}
				]
			}
		},
		{
			"id": "custom_powerupperspeed",
			"type": "special",
			"display_name": "Where I'm from, Speed Equals Strength",
			"force_cost": 0,
			"gauge_cost": 0,
			"range_min": 1,
			"range_max": 8,
			"power": 2,
			"speed": 8,
			"armor": 0,
			"guard": 0,
			"effects": [
				{
					"timing": "before",
					"effect_type": "powerup_per_speed",
					"amount": 1
				}
			],
			"boost": {
				"boost_type": "continuous",
				"force_cost": 0,
				"cancel_cost": -1,
				"display_name": "what if i just don't care",
				"effects": [
					{
						"timing": "during_strike",
						"effect_type": "stun_immunity"
					}
				]
			}
		},
		{
			"id": "custom_powerupperpower",
			"type": "special",
			"display_name": "double it and give it to the next person",
			"force_cost": 0,
			"gauge_cost": 0,
			"range_min": 1,
			"range_max": 8,
			"power": 5,
			"speed": 6,
			"armor": 0,
			"guard": 0,
			"effects": [
				{
					"timing": "before",
					"effect_type": "powerup_per_power",
					"amount": 1
				}
			],
			"boost": {
				"boost_type": "continuous",
				"force_cost": 0,
				"cancel_cost": -1,
				"display_name": "what if i just don't care",
				"effects": [
					{
						"timing": "during_strike",
						"effect_type": "stun_immunity"
					}
				]
			}
		},
		{
			"id": "custom_opponentprintedspeedgreater",
			"type": "special",
			"display_name": "Patience is a virtue",
			"force_cost": 0,
			"gauge_cost": 0,
			"range_min": 1,
			"range_max": 8,
			"power": 5,
			"speed": 2,
			"armor": 0,
			"guard": 0,
			"effects": [
				{
					"timing": "during_strike",
					"condition": "opponent_printed_speed_greater",
					"effect_type": "powerup",
					"amount": 5
				}
			],
			"boost": {
				"boost_type": "continuous",
				"force_cost": 0,
				"cancel_cost": -1,
				"display_name": "what if i just don't care",
				"effects": [
					{
						"timing": "during_strike",
						"effect_type": "stun_immunity"
					}
				]
			}
		},
		{
			"id": "custom_opponentprintedspeedless",
			"type": "special",
			"display_name": "Patience? What's that",
			"force_cost": 0,
			"gauge_cost": 0,
			"range_min": 1,
			"range_max": 8,
			"power": 5,
			"speed": 8,
			"armor": 0,
			"guard": 0,
			"effects": [
				{
					"timing": "during_strike",
					"condition": "opponent_printed_speed_less",
					"effect_type": "powerup",
					"amount": 5
				}
			],
			"boost": {
				"boost_type": "continuous",
				"force_cost": 0,
				"cancel_cost": -1,
				"display_name": "what if i just don't care",
				"effects": [
					{
						"timing": "during_strike",
						"effect_type": "stun_immunity"
					}
				]
			}
		},
		{
			"id": "custom_opponentprintedspeedgreater",
			"type": "special",
			"display_name": "Patience is a virtue",
			"force_cost": 0,
			"gauge_cost": 0,
			"range_min": 1,
			"range_max": 8,
			"power": 5,
			"speed": 2,
			"armor": 0,
			"guard": 0,
			"effects": [
				{
					"timing": "during_strike",
					"condition": "opponent_printed_speed_greater",
					"effect_type": "powerup",
					"amount": 5
				}
			],
			"boost": {
				"boost_type": "continuous",
				"force_cost": 0,
				"cancel_cost": -1,
				"display_name": "what if i just don't care",
				"effects": [
					{
						"timing": "during_strike",
						"effect_type": "stun_immunity"
					}
				]
			}
		},
		{
			"id": "custom_opponentprintedspeedless",
			"type": "special",
			"display_name": "Patience? What's that",
			"force_cost": 0,
			"gauge_cost": 0,
			"range_min": 1,
			"range_max": 8,
			"power": 5,
			"speed": 8,
			"armor": 0,
			"guard": 0,
			"effects": [
				{
					"timing": "during_strike",
					"condition": "opponent_printed_speed_less",
					"effect_type": "powerup",
					"amount": 5
				}
			],
			"boost": {
				"boost_type": "continuous",
				"force_cost": 0,
				"cancel_cost": -1,
				"display_name": "what if i just don't care",
				"effects": [
					{
						"timing": "during_strike",
						"effect_type": "stun_immunity"
					}
				]
			}
		},
		{
			"id": "custom_opponentatminrange_plus_namespeedopponentdiscardspeedorreveal",
			"type": "special",
			"display_name": "Up Close and Personal",
			"force_cost": 0,
			"gauge_cost": 0,
			"range_min": 1,
			"range_max": 3,
			"power": 3,
			"speed": 8,
			"armor": 0,
			"guard": 0,
			"effects": [
				{
					"timing": "before",
					"effect_type": "close",
					"amount": 3
				},
				{
					"timing": "hit",
					"condition": "opponent_at_min_range",
					"effect_type": "powerup",
					"amount": 2
				}
			],
			"boost": {
				"boost_type": "immediate",
				"force_cost": 0,
				"cancel_cost": -1,
				"display_name": "I know exactly when you'll strike!",
				"effects": [
					{
						"timing": "immediate",
						"effect_type": "name_speed",
						"target_effect": "opponent_discard_speed_or_reveal"
					}
				]
			}
		},
		{
			"id": "custom_opponentpushedorpulled",
			"type": "special",
			"display_name": "Opponent push or pull checker",
			"force_cost": 0,
			"gauge_cost": 0,
			"range_min": 1,
			"range_max": 8,
			"power": 5,
			"speed": 7,
			"armor": 0,
			"guard": 0,
			"effects": [
				{
					"timing": "hit",
					"effect_type": "push",
					"amount": 8,
					"and": 
					{
						"condition": "opponent_was_moved_during_strike",
						"condition_amount": 4,
						"effect_type": "draw",
						"amount": 8
					}
				}
			],
			"boost": {
				"boost_type": "continuous",
				"force_cost": 0,
				"cancel_cost": -1,
				"display_name": "whatever",
				"effects": [
					{
						"timing": "during_strike",
						"effect_type": "stun_immunity"
					}
				]
			}
		},
		{
			"id": "custom_playerpushedorpulled",
			"type": "special",
			"display_name": "Player push or pull checker",
			"force_cost": 0,
			"gauge_cost": 0,
			"range_min": 1,
			"range_max": 8,
			"power": 5,
			"speed": 1,
			"armor": 0,
			"guard": 9,
			"effects": [
				{
					"timing": "hit",
					"condition": "was_moved_during_strike",
					"condition_amount": 3,
					"effect_type": "draw",
					"amount": 8
				}
			],
			"boost": {
				"boost_type": "continuous",
				"force_cost": 0,
				"cancel_cost": -1,
				"display_name": "whatever",
				"effects": [
					{
						"timing": "during_strike",
						"effect_type": "stun_immunity"
					}
				]
			}
		}
	]

func who_am_i():
	return "ryu"

##
## Tests start here
##

# Testing adding opponent's attack to gauge
func test_custom_opponent_strike_to_gauge():
	position_players(player1, 3, player2, 4)
	player1.discard_hand()
	player2.discard_hand()

	var strike_cards = execute_strike(player1, player2, "custom_stealgauge", "standard_normal_cross")

	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 30, player2, 29)
	assert_true(player1.is_card_in_gauge(strike_cards[0]))
	assert_true(player1.is_card_in_gauge(strike_cards[1]))
	advance_turn(player2)

	# should return to original awner's discard
	game_logic.do_change(player1, [strike_cards[0], strike_cards[1]], false)
	assert_true(player1.is_card_in_discards(strike_cards[0]))
	assert_true(player2.is_card_in_discards(strike_cards[1]))
	advance_turn(player2)

# Testing conditioning on not pulling a full amount
func test_custom_not_full_pull_fail():
	position_players(player1, 1, player2, 4)

	execute_strike(player1, player2, "custom_notfullpull", "standard_normal_sweep")

	validate_positions(player1, 1, player2, 3)
	validate_life(player1, 24, player2, 28)
	advance_turn(player2)

func test_custom_not_full_pull_succeed():
	position_players(player1, 1, player2, 2)

	execute_strike(player1, player2, "custom_notfullpull", "standard_normal_sweep")

	validate_positions(player1, 1, player2, 2)
	validate_life(player1, 30, player2, 23)
	advance_turn(player2)

# Testing storage of the number of spaces a close effect doesn't move
func test_custom_bonus_per_not_closed_no_power():
	position_players(player1, 2, player2, 7)

	var boost_id = give_player_specific_card(player1, "custom_stealgauge")
	game_logic.do_boost(player1, boost_id)

	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_sweep",
		false, false, [0])

	validate_positions(player1, 6, player2, 8)
	validate_life(player1, 24, player2, 27)
	advance_turn(player2)

func test_custom_bonus_per_not_closed_some_power():
	position_players(player1, 4, player2, 7)

	var boost_id = give_player_specific_card(player1, "custom_stealgauge")
	game_logic.do_boost(player1, boost_id)

	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_sweep",
		false, false, [0])

	validate_positions(player1, 6, player2, 8)
	validate_life(player1, 24, player2, 25)
	advance_turn(player2)

func test_custom_bonus_per_not_closed_big_power():
	position_players(player1, 6, player2, 7)

	var boost_id = give_player_specific_card(player1, "custom_stealgauge")
	game_logic.do_boost(player1, boost_id)

	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_sweep",
		false, false, [0])

	validate_positions(player1, 6, player2, 8)
	validate_life(player1, 30, player2, 23)
	advance_turn(player2)

# Testing boosts not adding themselves to gauge immediately
func test_custom_boost_add_to_gauge_at_strike_end():
	position_players(player1, 3, player2, 6)

	var boost_id = give_player_specific_card(player1, "custom_notfullpull")
	game_logic.do_boost(player1, boost_id)

	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_focus",
		false, false, [0])

	validate_positions(player1, 5, player2, 6)
	validate_life(player1, 29, player2, 25)
	assert_true(player1.is_card_in_gauge(boost_id))
	advance_turn(player1)
	
# Testing gauge cost reduction per boosts in play
func test_custom_gauge_reduction_per_boost_in_play():
	position_players(player1, 3, player2, 6)

	# Give 3 gauge to Player 1.
	var gauge_ids = give_gauge(player1, 2)
	# Player 1 boosts Fierce
	var boost_id = give_player_specific_card (player1, "standard_normal_grasp")
	game_logic.do_boost(player1, boost_id)

	# Player 1 strikes with an ultra that reducces cost by boost in play - should only need to pay 2 gauge here despite 3 gauge cost.
	execute_strike (player2, player1, "standard_normal_assault", "custom_reducecostperboost", false, false, [], [[], gauge_ids])

	advance_turn(player1) 

# Testing powerup per armor
func test_custom_powerup_per_armor():
	position_players(player1, 3, player2, 6)

	# Player 1 strikes with an special with 2 power, 3 armor, and before: powerup_per_armor, amount: 1.
	execute_strike (player1, player2, "custom_powerupperarmor", "standard_normal_dive", false, false, [], [])

	# Validate that player 1 is still at max life, and player 2 is at 25.
	validate_life(player1, 30, player2, 25)
	
# Testing powerup per speed
func test_custom_powerup_per_speed():
	position_players(player1, 3, player2, 6)

	# Player 1 strikes with an special with 2 power, 8 speed, and before: powerup_per_speed, amount: 1.
	execute_strike (player1, player2, "custom_powerupperspeed", "standard_normal_dive", false, false, [], [])

	# Validate that player 1 is still at max life, and player 2 is at 20.
	validate_life(player1, 30, player2, 20)

# Testing powerup per power
func test_custom_powerup_per_power():
	position_players(player1, 3, player2, 6)

	# Player 1 strikes with an special with 5 power and before: powerup_per_power, amount: 1.
	execute_strike (player1, player2, "custom_powerupperpower", "standard_normal_dive", false, false, [], [])

	# Validate that player 1 is still at max life, and player 2 is at 20.
	validate_life(player1, 30, player2, 20)

# Testing opponent printed speed greater
func test_custom_opponent_printed_speed_greater():
	position_players(player1, 3, player2, 6)

	# Player 1 strikes with an special with 5 power, 2 speed, and +5 power if opponent's attack has greater printed speed.
	# Player 2 responds with a printed Speed 7 Grasp.
	execute_strike (player1, player2, "custom_opponentprintedspeedgreater", "standard_normal_grasp", false, false, [], [])

	# Validate that player 1 is still at max life, and player 2 is at 20.
	validate_life(player1, 30, player2, 20)

# Testing opponent printed speed less
func test_custom_opponent_printed_speed_less():
	position_players(player1, 3, player2, 6)

	# Player 1 strikes with an special with 5 power, 8 speed, and +5 power if opponent's attack has less printed speed.
	# Player 2 responds with a printed Speed 7 Grasp.
	execute_strike (player1, player2, "custom_opponentprintedspeedless", "standard_normal_grasp", false, false, [], [])

	# Validate that player 1 is still at max life, and player 2 is at 20.
	validate_life(player1, 30, player2, 20)

# Testing opponent at min range
func test_custom_opponent_at_min_range():
	position_players(player1, 3, player2, 6)

	# Player 1 strikes with an special with 1-3 range, 3 power, before: close 3, and +2 power if opponent is at minimum range.
	# Player 2 responds with a printed Speed 7 Grasp.
	execute_strike (player1, player2, "custom_opponentatminrange_plus_namespeedopponentdiscardspeedorreveal", "standard_normal_grasp", false, false, [], [])

	# Validate that player 1 is still at max life, and player 2 is at 25.
	validate_life(player1, 30, player2, 25)

# Testing condition that checks if opponent / player was pushed or pulled by the other player.
func test_custom_condition_opponent_was_moved():
	position_players(player1, 1, player2, 4)

	# P1 strikes with an attack that pushes 8.  If P2 was pushed, P1 draws 8.
	# P2 responds with an attack that draws 8 if they were pushed.
	execute_strike(player1, player2, "custom_opponentpushedorpulled", "custom_playerpushedorpulled")

	validate_positions(player1, 1, player2, 9)
	assert_eq(player1.hand.size(), 13)
	assert_eq(player2.hand.size(), 14)
	validate_life(player1, 25, player2, 25)

## Testing of name_speed + opponent_discard_speed_or_reveal boost:
## The below 6 tests are modified from the Zangief tests for his Intimidate boost.
##   Name a speed; the opponent must discard a card with that that speed or reveal a hand that
##   doesn't contain such a card.
## (Reminder: both players are Ryu here.

func test_name_speed_opponent_discard_speed_boost_reveal():
	position_players(player1, 4, player2, 7)
	var card_id = give_player_specific_card(player1, "custom_opponentatminrange_plus_namespeedopponentdiscardspeedorreveal")
	assert_true(game_logic.do_boost(player1, card_id))

	# Name the speed 0-9 are real speeds, 10 is a valid choice but doesn't exist, 11 is X
	assert_true(game_logic.do_choice(player1, 11)) # Ryu has no X cards.
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_RevealHand, player2)
	advance_turn(player2)

func test_name_speed_opponent_discard_speed_boost_reveal2():
	position_players(player1, 4, player2, 7)
	var card_id = give_player_specific_card(player1, "custom_opponentatminrange_plus_namespeedopponentdiscardspeedorreveal")
	assert_true(game_logic.do_boost(player1, card_id))

	# Name the speed 0-9 are real speeds, 10 is a valid choice but doesn't exist, 11 is X
	assert_true(game_logic.do_choice(player1, 8)) # Ryu has no 8
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_RevealHand, player2)
	advance_turn(player2)

func test_name_speed_opponent_discard_speed_boost_discard_X():
	position_players(player1, 4, player2, 7)
	var boost_id = give_player_specific_card(player1, "custom_opponentatminrange_plus_namespeedopponentdiscardspeedorreveal")
	assert_true(game_logic.do_boost(player1, boost_id))
	player2.discard_hand()
	var inksplash_id = give_player_specific_card(player2, "seijun_inksplash")
	# Speed X; Ryu calls "X" as the speed
	assert_true(game_logic.do_choice(player1, 11))
	assert_true(game_logic.do_choose_to_discard(player2, [inksplash_id]))
	advance_turn(player2)

func test_name_speed_opponent_discard_speed_boost_discard_1_with_X_eval():
	position_players(player1, 4, player2, 7)
	var boost_id = give_player_specific_card(player1, "custom_opponentatminrange_plus_namespeedopponentdiscardspeedorreveal")
	assert_true(game_logic.do_boost(player1, boost_id))

	player2.discard_hand()
	var inksplash_id = give_player_specific_card(player2, "seijun_inksplash")
	# Speed where X is the amount of cards the player has in hand; Ryu calls "1"
	assert_true(game_logic.do_choice(player1, 1))
	assert_true(game_logic.do_choose_to_discard(player2, [inksplash_id]))
	advance_turn(player2)

func test_name_speed_opponent_discard_speed_boost_discard_2_with_X_eval_fails():
	position_players(player1, 4, player2, 7)
	var boost_id = give_player_specific_card(player1, "custom_opponentatminrange_plus_namespeedopponentdiscardspeedorreveal")
	assert_true(game_logic.do_boost(player1, boost_id))
	player2.discard_hand()
	give_player_specific_card(player2, "seijun_inksplash")
	# Speed where X is the amount of cards the player has in hand
	# Ryu calls "2", which whiffs because the other player only has 1 card in hand
	assert_true(game_logic.do_choice(player1, 2))
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_RevealHand, player2)
	advance_turn(player2)

func test_name_speed_opponent_discard_speed_boost_discard_3():
	position_players(player1, 4, player2, 7)
	var boost_id = give_player_specific_card(player1, "custom_opponentatminrange_plus_namespeedopponentdiscardspeedorreveal")
	assert_true(game_logic.do_boost(player1, boost_id))

	player2.discard_hand()
	var spike_id = give_player_specific_card(player2, "standard_normal_spike")
	# Name the speed 0-9 are real speeds, 10 is a valid choice but doesn't exist, 11 is X
	assert_true(game_logic.do_choice(player1, 3))
	assert_true(game_logic.do_choose_to_discard(player2, [spike_id]))
	advance_turn(player2)
