extends GutTest

# The main menu BGM should stay silent in dev builds (editor runs and headless
# test runs) unless the player explicitly turned it on.

var _saved_bgm_enabled : bool
var _saved_bgm_preference_set : bool

func before_each():
	_saved_bgm_enabled = GlobalSettings.BGMEnabled
	_saved_bgm_preference_set = GlobalSettings._bgm_preference_set

func after_each():
	GlobalSettings.BGMEnabled = _saved_bgm_enabled
	GlobalSettings._bgm_preference_set = _saved_bgm_preference_set
	GlobalSettings.save_persistent_settings()

func test_dev_builds_default_to_music_off():
	# The test runner is a debug build, so the default must be silence.
	assert_true(OS.is_debug_build(), "tests are expected to run in a dev build")
	assert_false(GlobalSettings.default_bgm_enabled(),
			"dev builds should not play the main menu BGM by default")

func test_settings_without_an_explicit_preference_use_the_build_default():
	GlobalSettings.BGMEnabled = true
	GlobalSettings._bgm_preference_set = false
	GlobalSettings.save_persistent_settings()

	GlobalSettings.BGMEnabled = true
	GlobalSettings.load_persistent_settings()

	assert_eq(GlobalSettings.BGMEnabled, GlobalSettings.default_bgm_enabled(),
			"a stored value the player never chose should not re-enable the BGM")

func test_an_explicit_preference_is_remembered():
	GlobalSettings.set_bgm(true)
	assert_true(GlobalSettings._bgm_preference_set)

	GlobalSettings.BGMEnabled = false
	GlobalSettings.load_persistent_settings()
	assert_true(GlobalSettings.BGMEnabled,
			"an explicit opt-in should survive a reload even in a dev build")

	GlobalSettings.set_bgm(false)
	GlobalSettings.BGMEnabled = true
	GlobalSettings.load_persistent_settings()
	assert_false(GlobalSettings.BGMEnabled,
			"an explicit opt-out should survive a reload")

# ===== Migration from settings files written before BGMPreferenceSet existed =====
# Those files have no BGMPreferenceSet key. The old default was "on", so a stored
# `false` must have come from the player turning the music off, while a stored
# `true` is indistinguishable from the old default.

func test_a_legacy_opt_out_is_still_honoured():
	GlobalSettings._apply_loaded_bgm_settings({
		"HasExplicitBGMPreference": true,
		"BGMEnabled": false,
	})
	assert_false(GlobalSettings.BGMEnabled,
			"a player who turned the music off before the patch must stay muted")
	assert_true(GlobalSettings._bgm_preference_set,
			"the legacy opt-out should be migrated so it persists on the next save")

func test_a_legacy_on_value_falls_back_to_the_build_default():
	GlobalSettings._apply_loaded_bgm_settings({
		"HasExplicitBGMPreference": true,
		"BGMEnabled": true,
	})
	assert_eq(GlobalSettings.BGMEnabled, GlobalSettings.default_bgm_enabled(),
			"a legacy `true` is just the old default, not a deliberate opt-in")
	assert_false(GlobalSettings._bgm_preference_set)

func test_a_new_preference_key_wins_over_the_legacy_value():
	GlobalSettings._apply_loaded_bgm_settings({
		"BGMPreferenceSet": true,
		"BGMEnabled": true,
	})
	assert_true(GlobalSettings.BGMEnabled,
			"an explicit opt-in must be honoured even in a dev build")
	assert_true(GlobalSettings._bgm_preference_set)

func test_a_settings_file_with_no_bgm_keys_uses_the_build_default():
	GlobalSettings._apply_loaded_bgm_settings({ "DefaultPlayerName": "someone" })
	assert_eq(GlobalSettings.BGMEnabled, GlobalSettings.default_bgm_enabled())
	assert_false(GlobalSettings._bgm_preference_set)

func test_main_menu_stays_silent_while_bgm_is_disabled():
	var menu = load("res://scenes/menu/main_menu.tscn").instantiate()
	add_child_autofree(menu)
	await wait_frames(2)
	var bgm : AudioStreamPlayer = menu.get_node("BGM")
	bgm.volume_db = -80.0  # keep the test run silent while still exercising playback

	GlobalSettings.BGMEnabled = false
	menu.start_music()
	assert_false(bgm.playing, "the menu must not play music when BGM is disabled")

	GlobalSettings.BGMEnabled = true
	menu.start_music()
	assert_true(bgm.playing, "the menu should still play music when BGM is enabled")
	menu.stop_music()
