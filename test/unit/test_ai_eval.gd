extends GutTest

const AIRules = preload("res://scenes/game/ai/ai_policy_rules.gd")

var ai_rules : AIRules

func before_each():
	ai_rules = AIRules.new()

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
	assert_eq(0.1, ai_rules._probability_of_drawing(cards_to_find, 1, deck))
	assert_eq(0.3, ai_rules._probability_of_drawing(cards_to_find, 3, deck))
	assert_eq(1.0, ai_rules._probability_of_drawing(cards_to_find, 10, deck))
	print("%s" % ai_rules._probability_of_drawing([1, 2], 7, deck))



