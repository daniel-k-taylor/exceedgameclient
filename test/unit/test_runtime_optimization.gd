extends GutTest

const CardBaseScene = preload("res://scenes/card/card_base.tscn")
const CardPopoutScene = preload("res://scenes/game/card_popout.tscn")
const GameScene = preload("res://scenes/game/game.tscn")

# NOTE: This is the mobile-web port of the China fork's test_runtime_optimization.gd.
# Sub-tests that exercised the combat-log incremental read (LocalGame.get_combat_log
# with a start cursor / get_combat_log_size) and GameCard.get_image_url_index_data
# atlas-metadata pass-through are intentionally omitted here: those live in
# scenes/core/local_game.gd and scenes/core/game_card.gd, which are owned by other
# workstreams. See impl_mobile.md ("open issues") for the re-integration seam.

class TestMobileCardImageLoader extends CardImageLoader:
	func _is_mobile_web() -> bool:
		return true

class TestMobileCharacter extends Character:
	func _is_mobile_web() -> bool:
		return true

func _make_test_shared_atlas(columns: int, rows: int, cell_size: int) -> Image:
	var atlas = Image.create(columns * cell_size, rows * cell_size, false, Image.FORMAT_RGBA8)
	for y in range(rows):
		for x in range(columns):
			var index = y * columns + x
			var color = Color(
				float((index * 37) % 255) / 255.0,
				float((index * 67) % 255) / 255.0,
				float((index * 97) % 255) / 255.0,
				1.0)
			atlas.fill_rect(Rect2i(x * cell_size, y * cell_size, cell_size, cell_size), color)
	return atlas

func _get_texture_center_color(texture) -> Color:
	if texture is AtlasTexture:
		var atlas_image = texture.atlas.get_image()
		var region = texture.region
		var atlas_center = Vector2i(
			int(round(region.position.x + region.size.x * 0.5)),
			int(round(region.position.y + region.size.y * 0.5)))
		return atlas_image.get_pixelv(atlas_center)
	var image = texture.get_image()
	var center = Vector2i(image.get_width() >> 1, image.get_height() >> 1)
	return image.get_pixelv(center)

func _assert_color_close(actual: Color, expected: Color):
	assert_almost_eq(actual.r, expected.r, 0.02)
	assert_almost_eq(actual.g, expected.g, 0.02)
	assert_almost_eq(actual.b, expected.b, 0.02)

func _make_reference_source_card(card_id: int, label: String = "") -> CardBase:
	var card : CardBase = CardBaseScene.instantiate()
	add_child_autofree(card)
	card.initialize_simple(card_id, null, null, "Card %d" % card_id, "Boost %d" % card_id)
	card.flip_card_to_front(true)
	if label != "":
		card.set_label(label)
	else:
		card.set_remaining_count(card_id)
	return card

func test_web_runtime_animation_delay_only_shrinks_for_backlog():
	assert_eq(Game.get_runtime_animation_delay(1.0, 20, false), 1.0)
	assert_eq(Game.get_runtime_animation_delay(1.0, 8, true), 1.0)
	assert_eq(Game.get_runtime_animation_delay(1.0, 9, true), 0.25)
	assert_eq(Game.get_runtime_animation_delay(0.2, 20, true), 0.1)

func test_runtime_batch_yield_only_on_web_runtime_thresholds():
	assert_false(Game.should_yield_runtime_batch(4, Game.WebRuntimeLoadYieldBatchSize, false))
	assert_false(Game.should_yield_runtime_batch(3, Game.WebRuntimeLoadYieldBatchSize, true))
	assert_true(Game.should_yield_runtime_batch(4, Game.WebRuntimeLoadYieldBatchSize, true))
	assert_false(Game.should_yield_runtime_batch(5, Game.WebRuntimeLoadYieldBatchSize, true))
	assert_true(Game.should_yield_runtime_batch(6, Game.WebRuntimeEventYieldBatchSize, true))
	assert_eq(Game.WebRuntimeArenaVisualYieldFrames, 1)
	assert_eq(Game.WebRuntimeRotationSettleFrames, 2)
	assert_eq(Game.WebRuntimeMaximumInvalidViewportRetries, 8)
	assert_true(Game.is_rotation_layout_request_current(4, 4))
	assert_false(Game.is_rotation_layout_request_current(4, 5))
	assert_false(Game.is_rotation_viewport_size_valid(Vector2(319, 720)))
	assert_false(Game.is_rotation_viewport_size_valid(Vector2(1280, 239)))
	assert_true(Game.is_rotation_viewport_size_valid(Vector2(320, 240)))
	assert_eq(
		Game.get_rotation_safe_position(Vector2(2000, -900), Vector2(150, 100), Vector2(800, 600)),
		Vector2(800, -100))
	assert_eq(
		Game.get_rotation_safe_position(Vector2(300, 200), Vector2(150, 100), Vector2(800, 600)),
		Vector2(300, 200))

func test_mobile_character_sprite_frames_scale_shared_atlas_and_preserve_animation():
	var character := TestMobileCharacter.new()
	add_child_autofree(character)
	var source_image := Image.create(200, 100, false, Image.FORMAT_RGBA8)
	source_image.fill(Color.WHITE)
	var source_atlas := ImageTexture.create_from_image(source_image)
	var first_frame := AtlasTexture.new()
	first_frame.atlas = source_atlas
	first_frame.region = Rect2(0, 0, 100, 100)
	var second_frame := AtlasTexture.new()
	second_frame.atlas = source_atlas
	second_frame.region = Rect2(100, 0, 100, 100)
	var source_frames := SpriteFrames.new()
	source_frames.rename_animation(&"default", &"idle")
	source_frames.set_animation_loop(&"idle", false)
	source_frames.set_animation_speed(&"idle", 7.0)
	source_frames.add_frame(&"idle", first_frame, 1.5)
	source_frames.add_frame(&"idle", second_frame, 0.5)
	source_frames.set_meta("scaling", 0.75)

	var optimized_frames := await character._prepare_sprite_frames_for_runtime(source_frames, false)
	var optimized_first := optimized_frames.get_frame_texture(&"idle", 0) as AtlasTexture
	var optimized_second := optimized_frames.get_frame_texture(&"idle", 1) as AtlasTexture

	assert_eq(optimized_first.atlas.get_size(), Vector2(100, 50))
	assert_same(optimized_first.atlas, optimized_second.atlas)
	assert_eq(optimized_first.region, Rect2(0, 0, 50, 50))
	assert_eq(optimized_second.region, Rect2(50, 0, 50, 50))
	assert_false(optimized_frames.get_animation_loop(&"idle"))
	assert_eq(optimized_frames.get_animation_speed(&"idle"), 7.0)
	assert_eq(optimized_frames.get_frame_duration(&"idle", 0), 1.5)
	assert_eq(optimized_frames.get_meta("scaling"), 0.75)
	assert_eq(Character.get_mobile_web_character_texture_size(Vector2i(1, 3)), Vector2i(1, 2))

func test_web_runtime_backlog_budget_only_engages_for_real_backlog():
	assert_eq(Game.get_runtime_backlog_level(11, true), 0)
	assert_eq(Game.get_runtime_backlog_level(12, true), 1)
	assert_eq(Game.get_runtime_backlog_level(24, true), 2)
	assert_eq(Game.get_runtime_backlog_level(24, false), 0)
	assert_eq(Game.get_runtime_event_budget(11, true), Game.WebRuntimeEventBudgetUnlimited)
	assert_eq(Game.get_runtime_event_budget(12, true), Game.WebRuntimeEventBudgetModerate)
	assert_eq(Game.get_runtime_event_budget(24, true), Game.WebRuntimeEventBudgetSevere)
	assert_eq(Game.get_runtime_event_budget(24, false), Game.WebRuntimeEventBudgetUnlimited)

func test_web_runtime_health_state_warns_degrades_and_recovers():
	assert_eq(Game.get_runtime_health_state(0, 0, 0, Game.WebRuntimeRecoveryStableFrames, false), 0)
	assert_eq(Game.get_runtime_health_state(0, 12, 0, Game.WebRuntimeRecoveryStableFrames, true), 1)
	assert_eq(Game.get_runtime_health_state(0, 24, 0, Game.WebRuntimeRecoveryStableFrames, true), 2)
	assert_eq(Game.get_runtime_frame_pressure_level(0, true), 0)
	assert_eq(Game.get_runtime_frame_pressure_level(Game.WebRuntimeSlowFrameWarningCount, true), 1)
	assert_eq(Game.get_runtime_frame_pressure_level(Game.WebRuntimeSlowFrameSevereCount, true), 2)
	assert_eq(Game.get_runtime_health_state(0, 0, Game.WebRuntimeSlowFrameWarningCount, 0, true), 1)
	assert_eq(Game.get_runtime_health_state(0, 0, Game.WebRuntimeSlowFrameSevereCount, 0, true), 2)
	assert_eq(Game.get_runtime_health_state(1, 0, 0, Game.WebRuntimeRecoveryStableFrames - 1, true), 3)
	assert_eq(Game.get_runtime_health_state(2, 0, 0, Game.WebRuntimeRecoveryStableFrames - 1, true), 3)
	assert_eq(Game.get_runtime_health_state(3, 12, 0, Game.WebRuntimeRecoveryStableFrames, true), 1)
	assert_eq(Game.get_runtime_health_state(3, 0, 0, Game.WebRuntimeRecoveryStableFrames, true), 0)
	assert_eq(Game.get_runtime_event_budget_for_health_state(0), Game.WebRuntimeEventBudgetUnlimited)
	assert_eq(Game.get_runtime_event_budget_for_health_state(1), Game.WebRuntimeEventBudgetModerate)
	assert_eq(Game.get_runtime_event_budget_for_health_state(2), Game.WebRuntimeEventBudgetSevere)
	assert_eq(Game.get_runtime_event_budget_for_health_state(3), Game.WebRuntimeEventBudgetModerate)

func test_card_popout_repeated_show_cards_replaces_old_slots_instead_of_stacking():
	var popout : CardPopout = CardPopoutScene.instantiate()
	add_child_autofree(popout)
	await get_tree().process_frame

	var first_batch = []
	for card_id in range(1, 5):
		first_batch.append(_make_reference_source_card(card_id))
	popout.show_cards(first_batch)

	var second_batch = []
	for card_id in range(1, 9):
		second_batch.append(_make_reference_source_card(card_id))
	popout.show_cards(second_batch)
	await get_tree().process_frame

	assert_eq(popout.used_slots, 8)
	assert_eq(int(popout.total_cols), 4)
	for row in popout.rows.get_children():
		for col in row.get_children():
			assert_true(col.get_child_count() <= 1)

	var first_bottom_slot : CardBase = popout.rows.get_child(1).get_child(0).get_child(0)
	assert_eq(first_bottom_slot.card_id, 5)
	assert_eq(first_bottom_slot.get_remaining_count(), 5)

func test_card_popout_partial_fill_uses_final_slot_layout():
	var popout : CardPopout = CardPopoutScene.instantiate()
	add_child_autofree(popout)
	await get_tree().process_frame

	var partial_batch = []
	for card_id in range(1, 5):
		partial_batch.append(_make_reference_source_card(card_id))
	popout.show_cards(partial_batch, 8)

	assert_eq(popout.used_slots, 8)
	assert_eq(int(popout.total_cols), 4)
	assert_true(popout.rows.get_child(0).get_child(3).visible)
	assert_true(popout.rows.get_child(1).get_child(3).visible)
	assert_eq(popout.rows.get_child(1).get_child(0).get_child_count(), 0)

func test_guided_selection_refreshes_matching_existing_popout():
	var game_ui : Game = GameScene.instantiate()
	add_child_autofree(game_ui)
	await get_tree().process_frame

	assert_false(game_ui._should_open_or_refresh_popout(false, game_ui.CardPopoutType.CardPopoutType_ReferenceOpponent))

	var existing_popout := Node2D.new()
	game_ui.card_popout_parent.add_child(existing_popout)
	game_ui.popout_type_showing = game_ui.CardPopoutType.CardPopoutType_ReferenceOpponent

	assert_true(game_ui._should_open_or_refresh_popout(false, game_ui.CardPopoutType.CardPopoutType_ReferenceOpponent))
	assert_false(game_ui._should_open_or_refresh_popout(false, game_ui.CardPopoutType.CardPopoutType_GaugeOpponent))

func test_card_popout_does_not_connect_click_for_character_and_buddy_reference_cards():
	var popout : CardPopout = CardPopoutScene.instantiate()
	add_child_autofree(popout)
	await get_tree().process_frame

	var batch = [
		_make_reference_source_card(CardBase.CharacterCardReferenceId),
		_make_reference_source_card(CardBase.BuddyCardReferenceId),
		_make_reference_source_card(50001),
	]
	popout.show_cards(batch)

	for row in popout.rows.get_children():
		for col in row.get_children():
			if col.get_child_count() == 0:
				continue
			var rendered_card : CardBase = col.get_child(0)
			var is_placeholder = rendered_card.card_id in [CardBase.CharacterCardReferenceId, CardBase.BuddyCardReferenceId]
			assert_eq(rendered_card.clicked_card.get_connections().size(), 0 if is_placeholder else 1)

func test_can_select_card_rejects_character_and_buddy_reference_cards():
	var game_ui : Game = GameScene.instantiate()
	add_child_autofree(game_ui)
	await get_tree().process_frame

	var character_card = _make_reference_source_card(CardBase.CharacterCardReferenceId)
	var buddy_card = _make_reference_source_card(CardBase.BuddyCardReferenceId)

	assert_false(game_ui.can_select_card(character_card))
	assert_false(game_ui.can_select_card(buddy_card))

func test_card_image_loader_tracks_requested_atlas_indices():
	var loader = CardImageLoader.new(false)
	add_child_autofree(loader)
	var atlas = {"url": "http://example.com/cards.png"}

	loader.load_image_page_indexed(atlas, 2)
	loader.load_image_page_indexed(atlas, 5)

	var normalized_url = "https://example.com/cards.png"
	assert_true(loader.image_load_requested_indices[normalized_url].has(2))
	assert_true(loader.image_load_requested_indices[normalized_url].has(5))
	assert_false(loader.image_load_requested_indices[normalized_url].has(-1))
	assert_true(CardImageLoader.should_create_atlas_texture({2: true, 5: true}, 2))
	assert_false(CardImageLoader.should_create_atlas_texture({2: true, 5: true}, 3))
	assert_true(CardImageLoader.should_create_atlas_texture({-1: true}, 3))
	loader.teardown()

func test_card_image_loader_merges_later_atlas_metadata_for_same_url():
	var merged = CardImageLoader.merge_image_atlas_details(
		{
			"url": "https://example.com/cards.png",
			"multiple_cards": false,
			"season": 0,
			"deck_id": ""
		},
		{
			"url": "https://example.com/cards.png",
			"multiple_cards": true,
			"season": 7,
			"deck_id": "ino"
		})

	assert_true(merged["multiple_cards"])
	assert_eq(merged["season"], 7)
	assert_eq(merged["deck_id"], "ino")

func test_mobile_web_multi_card_atlas_materializes_full_texture_set():
	assert_true(CardImageLoader.should_materialize_all_multi_card_textures(true, {"multiple_cards": true}))
	assert_false(CardImageLoader.should_materialize_all_multi_card_textures(false, {"multiple_cards": true}))
	assert_false(CardImageLoader.should_materialize_all_multi_card_textures(true, {"multiple_cards": false}))

func test_mobile_web_prefers_scaled_atlas_texture_when_within_limit():
	var loader = TestMobileCardImageLoader.new(false)
	add_child_autofree(loader)
	var atlas = _make_test_shared_atlas(6, 4, 12)
	assert_true(loader._should_use_scaled_mobile_atlas_texture({"multiple_cards": true}, atlas))
	loader.teardown()

func test_mobile_web_normals_force_cropped_textures_avoid_atlas_texture():
	var loader = TestMobileCardImageLoader.new(false)
	add_child_autofree(loader)
	var atlas_url = "https://example.com/normals_force_cropped_test.png"
	var atlas_image = _make_test_shared_atlas(4, 2, 12)
	ImageCache.cache_image(atlas_url, atlas_image)

	loader.load_image_page_indexed({
		"url": atlas_url,
		"multiple_cards": true,
		"season": 1,
		"force_cropped_textures": true
	}, 0)

	await loader._process_request_queue()

	var textures = loader.loaded_images[atlas_url]
	assert_eq(textures.size(), 8)
	assert_false(textures[0] is AtlasTexture)
	assert_true(textures[0] is ImageTexture)
	loader.teardown()

func test_mobile_web_scaled_atlas_layout_keeps_normal_regions_integral():
	var loader = TestMobileCardImageLoader.new(false)
	add_child_autofree(loader)
	var layout = loader._get_scaled_mobile_atlas_layout(4, 2, 750.0, 1024.0, 0, 0)
	assert_eq(layout["atlas_size"], Vector2i(1800, 1228))
	assert_eq(layout["card_width"], 450)
	assert_eq(layout["card_height"], 614)
	loader.teardown()

func test_shared_url_multi_card_atlas_keeps_correct_textures_across_late_requests():
	var loader = TestMobileCardImageLoader.new(false)
	add_child_autofree(loader)
	var atlas_url = "https://example.com/shared_atlas_runtime_test.png"
	var atlas_image = _make_test_shared_atlas(6, 4, 12)
	ImageCache.cache_image(atlas_url, atlas_image)

	loader.load_image_page_indexed({
		"url": atlas_url,
		"multiple_cards": true
	}, 1)
	loader.load_image_page({
		"url": atlas_url,
		"multiple_cards": true,
		"season": 7,
		"deck_id": "ino"
	})

	await loader._process_request_queue()

	var textures = loader.loaded_images[atlas_url]
	assert_eq(textures.size(), 24)
	assert_true(textures.all(func(texture): return texture != null))

	var expected_index_1 = Color(float((1 * 37) % 255) / 255.0, float((1 * 67) % 255) / 255.0, float((1 * 97) % 255) / 255.0, 1.0)
	var expected_index_15 = Color(float((15 * 37) % 255) / 255.0, float((15 * 67) % 255) / 255.0, float((15 * 97) % 255) / 255.0, 1.0)
	_assert_color_close(_get_texture_center_color(textures[1]), expected_index_1)
	_assert_color_close(_get_texture_center_color(textures[15]), expected_index_15)

	var late_texture = await loader.get_card_image(atlas_url, 15)
	assert_not_null(late_texture)
	_assert_color_close(_get_texture_center_color(late_texture), expected_index_15)
	loader.teardown()
