extends GutTest

var ai_rules : AIPolicyRules

func before_each():
	ai_rules = AIPolicyRules.new()

	gut.p("ran setup", 2)

func after_each():
	ai_rules.free()
	gut.p("ran teardown", 2)

func before_all():
	gut.p("ran run setup", 2)

func after_all():
	gut.p("ran run teardown", 2)

func test_ai_validation_test():
	var deck = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	var cards_to_find = [3]

	# Have to use almost_eq due to floating point imprecision
	var EPSILON := 0.000001
	assert_almost_eq(0.1, ai_rules._probability_of_drawing(cards_to_find, 1, deck), EPSILON)
	assert_almost_eq(0.3, ai_rules._probability_of_drawing(cards_to_find, 3, deck), EPSILON)
	assert_almost_eq(0.3, ai_rules._probability_of_drawing([6, 9, 4, -1], 1, deck), EPSILON)
	assert_almost_eq(1.0, ai_rules._probability_of_drawing(cards_to_find, 10, deck), EPSILON)
	assert_almost_eq(1.0, ai_rules._probability_of_drawing(cards_to_find, 50, deck), EPSILON)
	assert_almost_eq(17.0 / 45.0, ai_rules._probability_of_drawing([2, 5], 2, deck), EPSILON)

func helper(events : Array):
	events.append_array([6,7])
	return events

func test_array():
	var events = [1,2,3,4,5]
	helper(events)
	assert_eq(events.size(), 7)
