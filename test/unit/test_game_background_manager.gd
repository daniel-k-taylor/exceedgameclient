extends GutTest

# Tests for the local (non-networked) arena background / map system.
# This project ships only the `classic` and `BG1` art plus the shared
# `standard_arena` track tiles; every other registered background has no art and
# must degrade gracefully (null texture, but still resolvable metadata).

const BackgroundManager = preload("res://globals/game_background_manager.gd")

func test_background_entries_drive_labels_and_order():
	# Only backgrounds whose art ships are offered; the rest stay registered.
	assert_eq(BackgroundManager.get_background_ids(), ["random", "classic", "BG1"])
	assert_eq(BackgroundManager.get_all_background_ids(), ["random", "classic", "BG1", "BG2", "BG3", "BG4", "BG5", "BG6", "BG7", "BG8", "BG9", "BG10", "BG11", "BG22", "BG12", "BG13", "BG14", "BG15", "BG16", "BG17", "BG18", "BG19", "BG20", "BG21"])
	assert_eq(BackgroundManager.get_background_label("random"), "Random Each Match")
	assert_eq(BackgroundManager.get_background_label("classic"), "BG0 Classic")
	assert_eq(BackgroundManager.get_background_label("BG1"), "BG1 Forest")
	assert_eq(BackgroundManager.get_background_label("BG2"), "BG2 Ruins")

func test_random_background_only_picks_available_backgrounds():
	assert_eq(BackgroundManager.get_randomizable_background_ids(), ["classic", "BG1"])
	for _i in range(20):
		var resolved_background_id := BackgroundManager.resolve_background_id("random")
		assert_ne(resolved_background_id, "random")
		assert_true(BackgroundManager.is_background_available(resolved_background_id), resolved_background_id)

func test_unavailable_saved_background_resolves_to_default():
	# A background saved before its art was pulled must not render as a blank arena.
	assert_eq(BackgroundManager.normalize_background_id("BG5"), "BG5")
	assert_false(BackgroundManager.is_background_available("BG5"))
	assert_eq(BackgroundManager.resolve_background_id("BG5"), "classic")

func test_background_path_uses_url_and_image_ids():
	assert_eq(BackgroundManager.get_background_resource_path("BG1"), "res://assets/ui/BG1/BG1.jpg")
	assert_eq(BackgroundManager.get_background_resource_path("BG2"), "res://assets/ui/BG2/BG2.jpg")

func test_present_background_texture_loads():
	# BG1 art is imported in this project.
	assert_not_null(BackgroundManager.get_background_texture("BG1"))

func test_missing_background_texture_degrades_to_null():
	# BG2 is registered for forward-compatibility but its art is not imported.
	assert_eq(BackgroundManager.get_background_resource_path("BG2"), "res://assets/ui/BG2/BG2.jpg")
	assert_null(BackgroundManager.get_background_texture("BG2"))

func test_classic_background_uses_classic_arena_and_has_no_texture():
	assert_true(BackgroundManager.uses_classic_arena("classic"))
	assert_eq(BackgroundManager.get_background_resource_path("classic"), "")
	assert_null(BackgroundManager.get_background_texture("classic"))

func test_standard_arena_uses_shared_track_directory():
	var resource_path := BackgroundManager.get_arena_resource_path("BG2", "B", 9)
	assert_eq(resource_path, "res://assets/ui/standard_arena/B9.png")
	# The shared standard_arena tiles are imported, so this resolves even though
	# BG2's full-screen art is not present.
	assert_not_null(BackgroundManager.get_arena_texture("BG2", "B", 9))
	# Arena tiles are intentionally not kept in the static cache.
	assert_false(BackgroundManager._texture_cache.has(resource_path))

func test_nonstandard_arena_uses_background_track_directory():
	assert_eq(BackgroundManager.get_arena_resource_path("BG1", "R", 1), "res://assets/ui/BG1/arena/R1.png")
	# BG1 ships its own arena tiles.
	assert_not_null(BackgroundManager.get_arena_texture("BG1", "R", 1))

func test_wide_character_neighbor_track_paths_resolve_for_standard_arena():
	var center_location = 5
	var mapped_locations = [center_location - 1, center_location, center_location + 1]
	for board_location in mapped_locations:
		var path = BackgroundManager.get_arena_resource_path("BG2", "B", 10 - board_location)
		assert_true(path.ends_with(".png"))
		assert_not_null(BackgroundManager.get_arena_texture("BG2", "B", 10 - board_location), str(board_location))

func test_invalid_arena_prefix_or_location_returns_empty():
	assert_eq(BackgroundManager.get_arena_resource_path("BG1", "X", 1), "")
	assert_eq(BackgroundManager.get_arena_resource_path("BG1", "B", 0), "")
	assert_eq(BackgroundManager.get_arena_resource_path("BG1", "B", 10), "")

func test_unknown_background_id_uses_default():
	assert_eq(BackgroundManager.normalize_background_id("missing"), "classic")

func test_unknown_main_menu_background_id_uses_default():
	assert_eq(BackgroundManager.normalize_main_menu_background_id("missing"), "MP1")

func test_main_menu_offers_only_the_two_solid_colors():
	assert_eq(BackgroundManager.get_main_menu_background_ids(), ["MP1", "MP7"])
	assert_eq(BackgroundManager.get_main_menu_background_label("MP1"), "Solid Color 1")
	assert_eq(BackgroundManager.get_main_menu_background_label("MP7"), "Solid Color 2")
	# Hidden entries stay registered but fall back to the default.
	assert_true(BackgroundManager.get_all_main_menu_background_ids().has("MP2"))
	assert_eq(BackgroundManager.normalize_main_menu_background_id("MP2"), "MP1")

func test_main_menu_backgrounds_are_solid_colors():
	# Both offered menu backgrounds paint a colour and need no art.
	assert_eq(BackgroundManager.get_main_menu_background_color("MP1"), Color(0, 0.482353, 0.482353))
	assert_eq(BackgroundManager.get_main_menu_background_color("MP7"), Color(0.305882, 0.305882, 0.305882))
	assert_eq(BackgroundManager.get_main_menu_background_resource_path("MP1"), "")
	assert_eq(BackgroundManager.get_main_menu_background_resource_path("MP7"), "")
	# An unknown id falls back to the default colour rather than erroring.
	assert_eq(BackgroundManager.get_main_menu_background_color("missing"), BackgroundManager.DEFAULT_MAIN_MENU_BACKGROUND_COLOR)

func test_missing_main_menu_background_texture_degrades_to_null():
	# Main-menu pictures are not imported in this project.
	assert_null(BackgroundManager.get_main_menu_background_texture("MP1"))

func test_clear_match_texture_cache_preserves_main_menu_textures():
	var match_path := "res://assets/ui/test_match_texture.png"
	var menu_path := "res://assets/mainmenu_picture/test_menu_texture.jpg"
	BackgroundManager._texture_cache[match_path] = null
	BackgroundManager._texture_cache[menu_path] = null

	BackgroundManager.clear_match_texture_cache()

	assert_false(BackgroundManager._texture_cache.has(match_path))
	assert_true(BackgroundManager._texture_cache.has(menu_path))
	BackgroundManager._texture_cache.erase(menu_path)
