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
