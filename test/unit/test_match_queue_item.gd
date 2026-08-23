extends GutTest

const MatchQueueItemScene = preload("res://scenes/menu/match_queue_item.tscn")


func test_waiting_character_display_prefers_waiting_character():
	# waiting_character is only meaningful if it resolves to a known deck id.
	var display = MatchQueueItem.get_waiting_character_display({
		"waiting_character": "ryu",
		"waiting_deck": "solbadguy",
		"waiting_deck_id": "kykisuke",
	})

	assert_eq(display, "Ryu")


func test_waiting_character_display_falls_back_to_waiting_deck():
	var display = MatchQueueItem.get_waiting_character_display({
		"waiting_character": "",
		"waiting_deck": "ryu",
		"waiting_deck_id": "solbadguy",
	})

	assert_eq(display, "Ryu")


func test_waiting_character_display_falls_back_to_waiting_deck_id():
	var display = MatchQueueItem.get_waiting_character_display({
		"waiting_deck_id": "random_s3#ryu",
	})

	assert_eq(display, "Ryu")


func test_waiting_character_display_handles_unresolved_random_without_fake_character():
	var display = MatchQueueItem.get_waiting_character_display({
		"waiting_deck_id": "random_s3",
	})

	assert_eq(display, "Random")


func test_waiting_character_display_handles_missing_fields():
	var display = MatchQueueItem.get_waiting_character_display({
		"match_available": false,
	})

	assert_eq(display, "")


func test_initialize_queue_shows_english_waiting_label():
	var queue_item = MatchQueueItemScene.instantiate()
	add_child_autofree(queue_item)

	queue_item.initialize_queue("all", "All Seasons", true, "Ryu")

	assert_eq(queue_item.waiting_character_label.text, "Waiting: Ryu")
	assert_true(queue_item.waiting_character_label.visible)


func test_waiting_label_hidden_when_no_match_available():
	var queue_item = MatchQueueItemScene.instantiate()
	add_child_autofree(queue_item)

	queue_item.initialize_queue("all", "All Seasons", false, "Ryu")

	assert_false(queue_item.waiting_character_label.visible)
