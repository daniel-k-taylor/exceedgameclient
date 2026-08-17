extends GutTest

# Verifies the AI difficulty preference (GlobalSettings.AIMode) round-trips
# through persistence and that invalid values fall back to the default.

var _saved_ai_mode : String

func before_each():
	_saved_ai_mode = GlobalSettings.AIMode

func after_each():
	GlobalSettings.AIMode = _saved_ai_mode
	GlobalSettings.save_persistent_settings()

func test_default_ai_mode_is_the_fair_rules_policy():
	assert_eq(GlobalSettings.DefaultAIMode, "rules")
	assert_true("rules" in GlobalSettings.ValidAIModes)
	assert_true("omniscient" in GlobalSettings.ValidAIModes)

func test_set_ai_mode_accepts_valid_values():
	GlobalSettings.set_ai_mode("omniscient")
	assert_eq(GlobalSettings.AIMode, "omniscient")
	GlobalSettings.set_ai_mode("rules")
	assert_eq(GlobalSettings.AIMode, "rules")

func test_set_ai_mode_rejects_invalid_values():
	GlobalSettings.set_ai_mode("cheater9000")
	assert_eq(GlobalSettings.AIMode, GlobalSettings.DefaultAIMode)

func test_ai_mode_round_trips_through_persistence():
	GlobalSettings.set_ai_mode("omniscient")
	# Clobber the in-memory value, then reload from disk.
	GlobalSettings.AIMode = "rules"
	GlobalSettings.load_persistent_settings()
	assert_eq(GlobalSettings.AIMode, "omniscient")
