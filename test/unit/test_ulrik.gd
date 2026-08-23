extends "res://test/exceed_test.gd"

func who_am_i():
	return "ulrik"

func _prepare_lightning_javelin_boost(gauge_amount: int) -> Array:
	position_players(player1, 3, player2, 7)
	var lightning_id = give_player_specific_card(player1, "ulrik_lightningjavelin")
	assert_true(game_logic.do_boost(player1, lightning_id, []))
	advance_turn(player2)
	return give_gauge(player1, gauge_amount)

func _run_lightning_javelin_payment_test(gauge_amount: int):
	var gauge_ids = _prepare_lightning_javelin_boost(gauge_amount)
	var choices = [0]
	if gauge_amount > 0:
		choices.append(gauge_ids)
	execute_strike(player1, player2, "ulrik_lightningjavelin", "standard_normal_assault",
		false, false, choices, [])
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player2.life, 30 - 3 - gauge_amount * 2)
	advance_turn(player2)

func test_lightning_javelin_pays_zero_gauge():
	_run_lightning_javelin_payment_test(0)

func test_lightning_javelin_pays_one_gauge():
	_run_lightning_javelin_payment_test(1)

func test_lightning_javelin_pays_two_gauge():
	_run_lightning_javelin_payment_test(2)

func test_lightning_javelin_pays_three_gauge():
	_run_lightning_javelin_payment_test(3)

func test_atomic_bolt_closes_then_advances_past_the_opponent():
	# Before: Close 8, then Advance 1, which carries Ulrik past the opponent.
	position_players(player1, 2, player2, 6)
	give_gauge(player1, 3)

	execute_strike(player1, player2, "ulrik_atomicbolt", "standard_normal_focus",
		false, false, [get_cards_from_gauge(player1, 3)], [])

	validate_positions(player1, 7, player2, 6)

func test_atomic_bolt_stops_when_the_opponent_is_against_the_wall():
	# Close 8 puts Ulrik next to the opponent, but the Advance 1 has nowhere to
	# go because the opponent is on the last space.
	position_players(player1, 3, player2, 9)
	give_gauge(player1, 3)

	execute_strike(player1, player2, "ulrik_atomicbolt", "standard_normal_focus",
		false, false, [get_cards_from_gauge(player1, 3)], [])

	validate_positions(player1, 8, player2, 9)
