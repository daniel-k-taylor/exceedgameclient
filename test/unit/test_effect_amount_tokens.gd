extends ExceedGutTest

# Effect amounts in the card JSON are sometimes plain numbers and sometimes
# tokens like "strike_x" that can only be resolved at apply time. The dynamic
# during_strike path in player.gd applies and later reverts these effects
# directly, so both halves have to resolve the token identically. When they do
# not, a String reaches a typed int parameter, the engine raises a runtime
# error, and the revert silently never happens.
#
# Runtime errors abort a GUT test method without failing it, so these
# regressions look green. Each case below asserts the stat actually returns to
# its starting value, which is what breaks when the resolution is missing.

func who_am_i():
	return "plague"

func _apply_and_revert(effect, check_applied : Callable):
	player1._apply_strike_bonus_effect(effect, -1)
	check_applied.call()
	player1._revert_strike_bonus_effect(effect, -1, false)

# Range bonuses accumulate as entries in range_effects; removal appends a
# negative entry rather than mutating a scalar, so compare the net total.
func _net_range(player) -> Array:
	var net_min = 0
	var net_max = 0
	for range_effect in player.strike_stat_boosts.range_effects:
		net_min += range_effect["min_range"]
		net_max += range_effect["max_range"]
	return [net_min, net_max]

func test_resolve_effect_amount_plain_number():
	assert_eq(player1.resolve_effect_amount({ "amount": 4 }), 4)
	assert_eq(player1.resolve_effect_amount({ "amount2": 7 }, "amount2"), 7)

func test_resolve_effect_amount_strike_x():
	player1.strike_stat_boosts.strike_x = 3
	assert_eq(player1.resolve_effect_amount({ "amount": "strike_x" }), 3)
	assert_eq(player1.resolve_effect_amount({ "amount2": "strike_x" }, "amount2"), 3)

func test_resolve_effect_amount_discarded_count():
	var starting_discards = player1.discards.size()
	assert_eq(player1.resolve_effect_amount({ "amount": "DISCARDED_COUNT" }), starting_discards)

func test_powerup_strike_x_applies_and_reverts():
	player1.strike_stat_boosts.strike_x = 3
	_apply_and_revert({ "effect_type": "powerup", "amount": "strike_x" },
		func(): assert_eq(player1.strike_stat_boosts.power, 3))
	assert_eq(player1.strike_stat_boosts.power, 0)

func test_guardup_strike_x_applies_and_reverts():
	player1.strike_stat_boosts.strike_x = 2
	_apply_and_revert({ "effect_type": "guardup", "amount": "strike_x" },
		func(): assert_eq(player1.strike_stat_boosts.guard, 2))
	assert_eq(player1.strike_stat_boosts.guard, 0)

func test_speedup_strike_x_applies_and_reverts():
	player1.strike_stat_boosts.strike_x = 5
	_apply_and_revert({ "effect_type": "speedup", "amount": "strike_x" },
		func(): assert_eq(player1.strike_stat_boosts.speed, 5))
	assert_eq(player1.strike_stat_boosts.speed, 0)

func test_armorup_strike_x_applies_and_reverts():
	player1.strike_stat_boosts.strike_x = 4
	_apply_and_revert({ "effect_type": "armorup", "amount": "strike_x" },
		func(): assert_eq(player1.strike_stat_boosts.armor, 4))
	assert_eq(player1.strike_stat_boosts.armor, 0)

func test_rangeup_strike_x_applies_and_reverts():
	player1.strike_stat_boosts.strike_x = 2
	var effect = { "effect_type": "rangeup", "amount": 1, "amount2": "strike_x" }
	_apply_and_revert(effect, func():
		assert_eq(_net_range(player1), [1, 2]))
	assert_eq(_net_range(player1), [0, 0])

func test_rangeup_both_players_strike_x_applies_and_reverts():
	player1.strike_stat_boosts.strike_x = 3
	var effect = { "effect_type": "rangeup_both_players", "amount": "strike_x", "amount2": "strike_x" }
	_apply_and_revert(effect, func():
		assert_eq(_net_range(player1), [3, 3])
		assert_eq(_net_range(player2), [3, 3]))
	assert_eq(_net_range(player1), [0, 0])
	assert_eq(_net_range(player2), [0, 0])

func test_rangeup_if_ex_modifier_strike_x_applies_and_reverts():
	player1.strike_stat_boosts.strike_x = 2
	var effect = { "effect_type": "rangeup_if_ex_modifier", "amount": "strike_x", "amount2": "strike_x" }
	_apply_and_revert(effect, func():
		assert_eq(player1.strike_stat_boosts.rangeup_min_if_ex_modifier, 2)
		assert_eq(player1.strike_stat_boosts.rangeup_max_if_ex_modifier, 2))
	assert_eq(player1.strike_stat_boosts.rangeup_min_if_ex_modifier, 0)
	assert_eq(player1.strike_stat_boosts.rangeup_max_if_ex_modifier, 0)

func test_powerup_both_players_strike_x_applies_and_reverts():
	player1.strike_stat_boosts.strike_x = 2
	_apply_and_revert({ "effect_type": "powerup_both_players", "amount": "strike_x" }, func():
		assert_eq(player1.strike_stat_boosts.power, 2)
		assert_eq(player2.strike_stat_boosts.power, 2))
	assert_eq(player1.strike_stat_boosts.power, 0)
	assert_eq(player2.strike_stat_boosts.power, 0)
