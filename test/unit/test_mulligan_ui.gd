extends GutTest

var game_ui : Game

func _drain_latest_events():
	var saved_fast_forward = game_ui.restore_fast_forwarding
	game_ui.restore_fast_forwarding = true
	while true:
		var events = game_ui.game_wrapper.current_game.get_latest_events()
		if events.size() == 0 and game_ui.events_to_process.size() == 0:
			break
		if events.size() > 0:
			game_ui._handle_events(events)
		elif game_ui.events_to_process.size() > 0:
			var remaining_events = game_ui.events_to_process
			game_ui.events_to_process = []
			game_ui._handle_events(remaining_events)
	game_ui.restore_fast_forwarding = saved_fast_forward

func setup_game_ui():
	var game_scene = load("res://scenes/game/game.tscn")
	game_ui = game_scene.instantiate()
	game_ui.set_not_started_directly()
	add_child(game_ui)
	await get_tree().process_frame
	game_ui.image_loader.test_mode = true
	var image_loader = game_ui.image_loader
	var game_logic = LocalGame.new(image_loader)
	var seed_value = randi()
	var deck = CardDataManager.get_deck_from_str_id("solbadguy")
	game_logic.initialize_game(
		deck,
		deck,
		"p1",
		"p2",
		Enums.PlayerId.PlayerId_Player,
		seed_value
	)
	game_logic.draw_starting_hands_and_begin()
	game_ui.player_deck = deck
	game_ui.opponent_deck = deck
	game_ui.game_wrapper.current_game = game_logic
	await game_ui.setup_characters()
	await game_ui.spawn_all_cards()
	game_ui.first_run()
	_drain_latest_events()

func before_each() -> void:
	await setup_game_ui()

func after_each():
	if game_ui:
		game_ui.queue_free()
		game_ui = null

func test_mulligan_selection_persists_when_opponent_mulligans():
	var game_logic = game_ui.game_wrapper.current_game
	assert_eq(game_logic.game_state, Enums.GameState.GameState_Mulligan)

	# Enter local mulligan selection state.
	_drain_latest_events()
	assert_eq(game_ui.ui_state, game_ui.UIState.UIState_SelectCards)
	assert_eq(game_ui.ui_sub_state, game_ui.UISubState.UISubState_SelectCards_Mulligan)

	var player_hand_cards = game_ui.get_node("AllCards/PlayerHand").get_children()
	assert_gt(player_hand_cards.size(), 0)
	var selected_card = player_hand_cards[0]
	game_ui.on_card_clicked(selected_card)
	assert_eq(game_ui.get_selected_card_ids(), [selected_card.card_id])

	# Opponent mulligans while local player is still selecting.
	assert_true(game_logic.do_mulligan(game_logic.opponent, []))
	_drain_latest_events()
	assert_eq(game_ui.ui_state, game_ui.UIState.UIState_SelectCards)
	assert_eq(game_ui.ui_sub_state, game_ui.UISubState.UISubState_SelectCards_Mulligan)

	var selected_after = game_ui.get_selected_card_ids()
	assert_eq(selected_after, [selected_card.card_id])
