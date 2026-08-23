extends GutTest

# Every test in this file exercises the game UI scene (scenes/game/game.gd) for
# Minato's "seal cards to pay costs" ability. The required UI hooks are now
# implemented in game.gd: can_seal_for_force / can_seal_for_gauge, the seal-aware
# get_gauge_generated()/can_press_ok(), the outrun-before-strike trigger in
# _on_strike_button_pressed(), _sync_ui_state_after_restore(), the pending
# power-bonus boost-box text, and the syrus_dredge_fury_keep_choice /
# allow_partial_gauge_selection / number_picker_step handling. The underlying
# engine support lives in local_game.gd / player.gd / remote_game.gd and is
# additionally covered by test_minato.gd.

var game_ui : Game
var next_test_card_id = 60000

func next_id() -> int:
	next_test_card_id += 1
	return next_test_card_id - 1

func give_player_specific_card(player : Player, def_id : String) -> int:
	var card_def = CardDataManager.get_card(def_id)
	var card_id = next_id()
	var card = GameCard.new(card_id, card_def, player.my_id)
	var card_db = game_ui.game_wrapper.current_game.get_card_database()
	card_db._test_insert_card(card)
	player.hand.append(card)
	return card_id

func add_transform(player : Player, def_id : String):
	give_player_specific_card(player, def_id)
	player.add_to_transforms(player.hand[-1])
	player.hand.remove_at(player.hand.size() - 1)

func setup_game_ui(opponent_id : String = "minato"):
	var game_scene = load("res://scenes/game/game.tscn")
	game_ui = game_scene.instantiate()
	game_ui.set_not_started_directly()
	add_child(game_ui)
	var image_loader = game_ui.image_loader
	var game_logic = LocalGame.new(image_loader)
	var seed_value = randi()
	game_logic.initialize_game(
		CardDataManager.get_deck_from_str_id("minato"),
		CardDataManager.get_deck_from_str_id(opponent_id),
		"p1",
		"p2",
		Enums.PlayerId.PlayerId_Player,
		seed_value
	)
	game_logic.draw_starting_hands_and_begin()
	assert_true(game_logic.do_mulligan(game_logic.player, []))
	assert_true(game_logic.do_mulligan(game_logic.opponent, []))
	game_logic.get_latest_events()
	game_ui.game_wrapper.current_game = game_logic

func before_each():
	setup_game_ui()

func after_each():
	if game_ui:
		game_ui.queue_free()
		game_ui = null

func test_force_for_change_ok_counts_sealed_force():
	var player = game_ui.game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
	player.discard([player.hand[0].id])

	game_ui.ui_state = game_ui.UIState.UIState_SelectCards
	game_ui.ui_sub_state = game_ui.UISubState.UISubState_SelectCards_ForceForChange
	game_ui.selected_cards = []
	game_ui.can_seal_for_force = true
	game_ui.action_menu.number_panel_current_number = 1
	game_ui.use_free_force = false

	assert_true(game_ui.can_press_ok())

func test_shortcut_change_enables_seal_force_for_minato():
	var player = game_ui.game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
	player.discard([player.hand[0].id])

	game_ui._on_shortcut_change_pressed()

	assert_true(game_ui.can_seal_for_force)
	assert_eq(game_ui.ui_sub_state, game_ui.UISubState.UISubState_SelectCards_ForceForChange)

func test_strike_button_triggers_outrun_before_attack_selection():
	var player = game_ui.game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
	add_transform(player, "minato_flight_13")
	player.discard([player.hand[0].id])

	game_ui._on_strike_button_pressed()
	var game_logic = game_ui.game_wrapper.current_game

	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseFromDiscard)
	assert_eq(game_logic.decision_info.source, "outrun_seal")
	assert_true(player.minato_outrun_triggered_before_strike)


func test_restore_sync_reopens_player_decision_ui_from_wait_state():
	var player = game_ui.game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
	add_transform(player, "minato_flight_13")
	player.discard([player.hand[0].id])
	game_ui._on_strike_button_pressed()
	var game_logic = game_ui.game_wrapper.current_game

	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseFromDiscard)

	game_ui.change_ui_state(game_ui.UIState.UIState_WaitForGameServer, game_ui.UISubState.UISubState_None)
	game_ui._sync_ui_state_after_restore()

	assert_eq(game_ui.ui_state, game_ui.UIState.UIState_SelectCards)
	assert_eq(game_ui.ui_sub_state, game_ui.UISubState.UISubState_SelectCards_ChooseDiscardToDestination)

func test_seal_for_gauge_uses_floor_division_and_step_three():
	var player = game_ui.game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
	for _i in range(7):
		var card_id = give_player_specific_card(player, "standard_normal_grasp")
		player.discard([card_id])

	game_ui.ui_state = game_ui.UIState.UIState_SelectCards
	game_ui.ui_sub_state = game_ui.UISubState.UISubState_SelectCards_StrikeGauge
	game_ui.select_card_require_min = 3
	game_ui.select_card_require_max = 3
	game_ui.selected_cards = []
	game_ui.can_seal_for_gauge = true
	game_ui.action_menu.number_panel_current_number = 7

	assert_eq(game_ui.get_gauge_generated(), 2)
	game_ui._update_buttons(true)
	assert_eq(game_ui.action_menu.number_picker_step, 3)
	assert_eq(game_ui.instructions_number_picker_max, 7)

func test_dredge_fury_allows_partial_gauge_selection_for_optional_effect():
	var game_logic = game_ui.game_wrapper.current_game
	game_logic.decision_info.clear()
	game_logic.decision_info.player = Enums.PlayerId.PlayerId_Player
	game_logic.decision_info.type = Enums.DecisionType.DecisionType_GaugeForEffect
	game_logic.decision_info.effect = {
		"gauge_max": 3,
		"min_gauge": 0,
		"per_gauge_effect": {"effect_type": "powerup", "amount": 2},
		"overall_effect": {"effect_type": "syrus_dredge_fury_keep_choice"},
		"allow_partial_gauge_selection": true
	}

	game_ui._on_gauge_for_effect({"event_player": Enums.PlayerId.PlayerId_Player})
	game_ui.selected_cards = [1]

	assert_true(game_ui.can_press_ok())

func test_sealed_gauge_payment_is_one_shot():
	var player = game_ui.game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
	var game_logic = game_ui.game_wrapper.current_game
	for _i in range(3):
		var discard_id = give_player_specific_card(player, "standard_normal_grasp")
		player.discard([discard_id])
	game_logic.game_state = Enums.GameState.GameState_PlayerDecision
	game_logic.active_exceed = true
	game_logic.decision_info.clear()
	game_logic.decision_info.player = player.my_id
	game_logic.decision_info.type = Enums.DecisionType.DecisionType_GaugeForEffect
	game_logic.decision_info.effect = {
		"gauge_max": 1,
		"min_gauge": 1,
		"per_gauge_effect": {"effect_type": "pass"},
		"overall_effect": null
	}

	game_ui.ui_state = game_ui.UIState.UIState_SelectCards
	game_ui.ui_sub_state = game_ui.UISubState.UISubState_SelectCards_GaugeForEffect
	game_ui.select_card_require_min = 1
	game_ui.select_card_require_max = 1
	game_ui.selected_cards = []
	game_ui.can_seal_for_gauge = true
	game_ui.action_menu.number_panel_current_number = 3

	assert_true(game_ui.can_press_ok())
	game_ui._on_instructions_ok_button_pressed(0)

	assert_eq(player.free_gauge, 0)
	assert_eq(player.gauge.size(), 0)
	assert_eq(player.sealed.size(), 3)
	assert_false(player.can_pay_cost(0, 1))

func test_streetcar_disaster_pays_three_gauge_by_sealing_nine_discards_against_taisei_block():
	game_ui.queue_free()
	game_ui = null
	setup_game_ui("taisei")
	var player = game_ui.game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
	var opponent = game_ui.game_wrapper._get_player(Enums.PlayerId.PlayerId_Opponent)
	var game_logic = game_ui.game_wrapper.current_game
	player.arena_location = 3
	opponent.arena_location = 7
	for _i in range(11):
		var discard_id = give_player_specific_card(player, "standard_normal_grasp")
		player.discard([discard_id])
	var ultra_id = give_player_specific_card(player, "minato_streetcar_disaster")
	var response_id = give_player_specific_card(opponent, "standard_normal_block")

	assert_true(game_logic.do_strike(player, ultra_id, false, -1))
	assert_true(game_logic.do_strike(opponent, response_id, false, -1))
	assert_true(game_logic.do_choice(opponent, 0))
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_PayStrikeCost_Required)
	assert_eq(game_logic.decision_info.cost, 3)

	game_ui.ui_state = game_ui.UIState.UIState_SelectCards
	game_ui.ui_sub_state = game_ui.UISubState.UISubState_SelectCards_StrikeGauge
	game_ui.select_card_require_min = 3
	game_ui.select_card_require_max = 3
	game_ui.selected_cards = []
	game_ui.can_seal_for_gauge = true
	game_ui.action_menu.number_panel_current_number = 9
	assert_true(game_ui.can_press_ok())
	game_ui._on_instructions_ok_button_pressed(0)

	assert_eq(player.sealed.size(), 9)

func test_exceed_ok_enabled_when_sealed_discards_generate_enough_gauge():
	var player = game_ui.game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
	for _i in range(6):
		var discard_id = give_player_specific_card(player, "standard_normal_grasp")
		player.discard([discard_id])

	game_ui.ui_state = game_ui.UIState.UIState_SelectCards
	game_ui.ui_sub_state = game_ui.UISubState.UISubState_SelectCards_Exceed
	game_ui.select_card_require_min = 2
	game_ui.select_card_require_max = 2
	game_ui.selected_cards = []
	game_ui.can_seal_for_gauge = true
	game_ui.action_menu.number_panel_current_number = 6

	assert_eq(game_ui.get_gauge_generated(), 2)
	assert_true(game_ui.can_press_ok())

func test_exceed_pending_power_bonus_text_shows_in_boost_box():
	var player = game_ui.game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
	player.exceeded = true
	player.minato_seal_power_bonus = 4

	game_ui._update_buttons(true)
	var boost_text = game_ui.get_node("PlayerBoostZone/OuterMargin/BoostPanel/InnerMargin/BoostVBox/BoostEffects").text
	assert_true(boost_text.find("gains +4 Power on next attack") != -1)
