extends GutTest

# The reconnect overlay lives in scenes/main.tscn as a Control parented to a
# Node2D. It is easy for it to end up collapsed in the top-left corner instead
# of covering the screen, which makes the reconnect UI unreadable.

var main_scene : Node

func before_each():
	main_scene = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main_scene)

func after_each():
	# main.gd opens a socket in _ready; make sure we do not leave it dialing.
	NetworkManager.cancel_reconnect()

func _overlay() -> Control:
	return main_scene.get_node("ReconnectLayer/ReconnectOverlay")

func test_overlay_covers_the_whole_viewport():
	var overlay = _overlay()
	main_scene._show_waiting_for_opponent_overlay(5)
	await wait_frames(4)

	var viewport_size = get_tree().root.get_visible_rect().size
	assert_true(overlay.visible, "the overlay should be visible while waiting")
	assert_almost_eq(overlay.size.x, viewport_size.x, 1.0,
		"the overlay should span the viewport width")
	assert_almost_eq(overlay.size.y, viewport_size.y, 1.0,
		"the overlay should span the viewport height")
	assert_almost_eq(overlay.global_position.x, 0.0, 1.0, "the overlay should start at the left edge")
	assert_almost_eq(overlay.global_position.y, 0.0, 1.0, "the overlay should start at the top edge")

func test_dim_blocker_covers_the_whole_viewport():
	var blocker = _overlay().get_node("CloseBlocker")
	main_scene._show_waiting_for_opponent_overlay(5)
	await wait_frames(4)

	var viewport_size = get_tree().root.get_visible_rect().size
	assert_almost_eq(blocker.size.x, viewport_size.x, 1.0, "the dim layer should span the width")
	assert_almost_eq(blocker.size.y, viewport_size.y, 1.0, "the dim layer should span the height")

func test_panel_is_centred_and_fully_on_screen():
	var panel = _overlay().get_node("PanelContainer")
	main_scene._show_waiting_for_opponent_overlay(5)
	await wait_frames(4)

	var viewport_size = get_tree().root.get_visible_rect().size
	assert_gt(panel.size.x, 0.0, "the panel should have a width")
	assert_gt(panel.size.y, 0.0, "the panel should have a height")

	var panel_centre = panel.global_position + panel.size / 2.0
	assert_almost_eq(panel_centre.x, viewport_size.x / 2.0, 2.0, "the panel should be horizontally centred")
	assert_almost_eq(panel_centre.y, viewport_size.y / 2.0, 2.0, "the panel should be vertically centred")

	assert_gte(panel.global_position.x, 0.0, "the panel should not run off the left edge")
	assert_gte(panel.global_position.y, 0.0, "the panel should not run off the top edge")
	assert_lte(panel.global_position.x + panel.size.x, viewport_size.x,
		"the panel should not run off the right edge")
	assert_lte(panel.global_position.y + panel.size.y, viewport_size.y,
		"the panel should not run off the bottom edge")

func test_overlay_is_hidden_when_not_reconnecting():
	var overlay = _overlay()
	main_scene._on_reconnect_state_changed({
		"is_waiting_for_opponent_reconnect": false,
		"is_manual_reconnect": false,
		"is_auto_reconnecting": false,
		"waiting_for_opponent_reconnect_seconds": 0,
		"reconnect_seconds": 0,
	})
	await wait_frames(2)
	assert_false(overlay.visible, "the overlay should be hidden when nothing is reconnecting")

func test_each_overlay_mode_shows_readable_text():
	var overlay = _overlay()
	var message = overlay.get_node("PanelContainer/MarginContainer/VBoxContainer/MessageLabel")
	var timer = overlay.get_node("PanelContainer/MarginContainer/VBoxContainer/TimerLabel")

	main_scene._show_waiting_for_opponent_overlay(3)
	await wait_frames(2)
	assert_string_contains(message.text, "Opponent disconnected")
	assert_ne(timer.text, "", "the waiting overlay should show a countdown value")

	main_scene._show_auto_reconnect_overlay(2)
	await wait_frames(2)
	assert_string_contains(message.text, "Reconnecting")

	main_scene._show_manual_reconnect_overlay()
	await wait_frames(2)
	assert_string_contains(message.text, "reconnect manually")

func test_timer_text_is_self_describing_rather_than_a_bare_number():
	var timer = _overlay().get_node("PanelContainer/MarginContainer/VBoxContainer/TimerLabel")

	# With a server deadline the overlay counts down towards the seat expiring.
	main_scene._show_waiting_for_opponent_overlay(4, 95)
	await wait_frames(2)
	assert_eq(timer.text, "1:35 left")

	main_scene._show_waiting_for_opponent_overlay(4, 42)
	await wait_frames(2)
	assert_eq(timer.text, "42s left")

	# Without a deadline it falls back to elapsed time, still labelled.
	main_scene._show_waiting_for_opponent_overlay(7, -1)
	await wait_frames(2)
	assert_eq(timer.text, "Waiting 7s")

	main_scene._show_auto_reconnect_overlay(12)
	await wait_frames(2)
	assert_eq(timer.text, "Retrying for 12s")

func test_waiting_overlay_offers_leaving_the_match():
	var cancel = _overlay().get_node("PanelContainer/MarginContainer/VBoxContainer/ButtonRow/CancelButton")
	main_scene._show_waiting_for_opponent_overlay(2, 30)
	await wait_frames(2)
	assert_true(cancel.visible, "the player must be able to stop waiting")
	assert_eq(cancel.text, "Leave Match")

func test_reconnect_state_carries_a_countdown_when_the_server_sends_a_deadline():
	NetworkManager.end_waiting_for_opponent_reconnect()
	var deadline_ms = (Time.get_unix_time_from_system() + 45.0) * 1000.0
	NetworkManager.begin_waiting_for_opponent_reconnect(deadline_ms)

	var state = NetworkManager.get_reconnect_state()
	assert_true(state["is_waiting_for_opponent_reconnect"])
	var remaining = state["waiting_for_opponent_reconnect_remaining_seconds"]
	assert_between(remaining, 43, 46, "the countdown should reflect the server deadline")

	NetworkManager.end_waiting_for_opponent_reconnect()
	assert_eq(NetworkManager.get_reconnect_state()["waiting_for_opponent_reconnect_remaining_seconds"], -1)

func test_reconnect_countdown_ignores_an_implausible_deadline():
	# A wildly skewed client clock must not produce a nonsense countdown.
	NetworkManager.end_waiting_for_opponent_reconnect()
	var far_future_ms = (Time.get_unix_time_from_system() + 60 * 60 * 24) * 1000.0
	NetworkManager.begin_waiting_for_opponent_reconnect(far_future_ms)
	assert_eq(NetworkManager.get_reconnect_state()["waiting_for_opponent_reconnect_remaining_seconds"], -1,
		"an implausible deadline should fall back to elapsed counting")
	NetworkManager.end_waiting_for_opponent_reconnect()

func test_reconnect_countdown_clamps_to_zero_once_the_deadline_passes():
	NetworkManager.end_waiting_for_opponent_reconnect()
	var past_ms = (Time.get_unix_time_from_system() - 10.0) * 1000.0
	NetworkManager.begin_waiting_for_opponent_reconnect(past_ms)
	assert_eq(NetworkManager.get_reconnect_state()["waiting_for_opponent_reconnect_remaining_seconds"], 0,
		"an expired deadline should read as zero, never negative")
	NetworkManager.end_waiting_for_opponent_reconnect()
