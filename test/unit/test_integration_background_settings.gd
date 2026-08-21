extends GutTest

# Integration checks for the background/skin display preferences that the
# integration wiring adds to GlobalSettings, and that the background manager
# degrades gracefully when an asset is absent (only `classic` and `BG1` ship art).

const BackgroundManager = preload("res://globals/game_background_manager.gd")

var _saved_arena_style : String
var _saved_menu_style : String

func before_each():
	_saved_arena_style = GlobalSettings.ArenaStyle
	_saved_menu_style = GlobalSettings.MainMenuBackgroundStyle

func after_each():
	GlobalSettings.ArenaStyle = _saved_arena_style
	GlobalSettings.MainMenuBackgroundStyle = _saved_menu_style
	GlobalSettings.save_persistent_settings()

func test_default_styles():
	assert_eq(GlobalSettings.DefaultArenaStyle, "classic")
	# The default arena style keeps the classic board look.
	assert_true(BackgroundManager.uses_classic_arena(GlobalSettings.DefaultArenaStyle))

func test_arena_style_round_trips_through_persistence():
	GlobalSettings.set_arena_style("BG1")
	GlobalSettings.ArenaStyle = "classic"
	GlobalSettings.load_persistent_settings()
	assert_eq(GlobalSettings.ArenaStyle, "BG1")

func test_menu_background_style_round_trips_through_persistence():
	GlobalSettings.set_main_menu_background_style("MP7")
	GlobalSettings.MainMenuBackgroundStyle = "MP1"
	GlobalSettings.load_persistent_settings()
	assert_eq(GlobalSettings.MainMenuBackgroundStyle, "MP7")

func test_present_background_loads_but_absent_one_degrades_to_null():
	# BG1 art is imported; render it.
	assert_not_null(BackgroundManager.get_background_texture("BG1"))
	# BG5 art is not imported: metadata resolves, texture degrades to null.
	assert_eq(BackgroundManager.normalize_background_id("BG5"), "BG5")
	assert_null(BackgroundManager.get_background_texture("BG5"))
	# The classic style also has no full-screen image and keeps the board look.
	assert_null(BackgroundManager.get_background_texture("classic"))

func test_main_menu_scene_paints_the_selected_solid_color():
	# The menu's ColorRect is what actually renders a solid-colour background.
	var instance = load("res://scenes/menu/main_menu.tscn").instantiate()
	add_child_autofree(instance)
	await wait_frames(2)
	var color_rect : ColorRect = instance.get_node("Background")

	GlobalSettings.MainMenuBackgroundStyle = "MP7"
	instance._apply_main_menu_background()
	assert_eq(color_rect.color, BackgroundManager.get_main_menu_background_color("MP7"))
	assert_false(instance.menu_background_image.visible)

	GlobalSettings.MainMenuBackgroundStyle = "MP1"
	instance._apply_main_menu_background()
	assert_eq(color_rect.color, BackgroundManager.get_main_menu_background_color("MP1"))

func test_main_menu_backgrounds_render_as_solid_colors():
	# The offered menu backgrounds are flat colours, so no art is needed and the
	# texture lookup stays null.
	var offered_ids = BackgroundManager.get_main_menu_background_ids()
	assert_eq(offered_ids, ["MP1", "MP7"])
	for background_id in offered_ids:
		assert_null(BackgroundManager.get_main_menu_background_texture(background_id),
			"Expected null menu texture for %s" % background_id)
		assert_ne(BackgroundManager.get_main_menu_background_color(background_id), Color(0, 0, 0, 0),
			"Expected a menu colour for %s" % background_id)
