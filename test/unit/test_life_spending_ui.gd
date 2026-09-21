extends GutTest

var game_ui : Game

func before_each():
	game_ui = load("res://scenes/game/game.tscn").instantiate()
	game_ui.set_not_started_directly()
	add_child(game_ui)
	var game_logic = LocalGame.new(game_ui.image_loader)
	var deck = CardDataManager.get_deck_from_str_id("taisei")
	game_logic.initialize_game(deck, deck, "p1", "p2", Enums.PlayerId.PlayerId_Player, randi())
	game_logic.draw_starting_hands_and_begin()
	assert_true(game_logic.do_mulligan(game_logic.player, []))
	assert_true(game_logic.do_mulligan(game_logic.opponent, []))
	game_logic.get_latest_events()
	game_ui.game_wrapper.current_game = game_logic
	game_ui.ChoiceTagRegex.compile("\\[.*\\]")

func after_each():
	game_ui.queue_free()

func test_life_choices_disable_exactly_the_unaffordable_amounts():
	var logic = game_ui.game_wrapper.current_game
	var choices = CardDataManager.get_card("akuma_gohadoken").boost.effects[0].choice
	logic.handle_strike_effect(-1, {"effect_type": "choice", "choice": choices}, logic.player)
	for life in range(1, 7):
		logic.player.life = life
		game_ui.begin_effect_choice(logic.decision_info.choice, "Select an effect:", [])
		game_ui._update_buttons(true)
		for i in range(5):
			assert_eq(game_ui.current_action_menu_choices[i].disabled, i + 1 >= life,
				"At %s life, spending %s must leave at least one" % [life, i + 1])
		assert_false(game_ui.current_action_menu_choices[5].disabled)

func test_taisei_choices_disable_lethal_payment():
	var logic = game_ui.game_wrapper.current_game
	logic.player.life = 1
	logic.handle_strike_effect(-1, logic.player.deck_def.ability_effects[0], logic.player)
	game_ui.begin_effect_choice(logic.decision_info.choice, "Select an effect:", [])
	game_ui._update_buttons(true)
	assert_false(game_ui.current_action_menu_choices[0].disabled)
	assert_true(game_ui.current_action_menu_choices[1].disabled)
	assert_true(game_ui.current_action_menu_choices[2].disabled)

func test_life_number_pickers_stop_at_one_remaining():
	var player = game_ui.game_wrapper.current_game.player
	player.life = 5
	game_ui.ui_state = game_ui.UIState.UIState_SelectCards
	game_ui.ui_sub_state = game_ui.UISubState.UISubState_SelectCards_ForceForChange
	game_ui.can_spend_life_for_force = true
	game_ui._update_buttons(true)
	assert_eq(game_ui.instructions_number_picker_max, 4)
	assert_eq(game_ui.action_menu.number_panel_max, 4)
	game_ui.can_spend_life_for_force = false
	game_ui.can_spend_life_for_gauge = true
	game_ui.ui_sub_state = game_ui.UISubState.UISubState_SelectCards_Exceed
	game_ui._update_buttons(true)
	assert_eq(game_ui.instructions_number_picker_max, 4)
	assert_eq(game_ui.action_menu.number_panel_max, 4)

func test_alternative_life_cost_button_is_disabled_when_lethal():
	game_ui.game_wrapper.current_game.player.life = 3
	game_ui.ui_state = game_ui.UIState.UIState_MakeChoice
	game_ui.instructions_pay_alternative_life_cost = 3
	game_ui._update_buttons(true)
	assert_true(game_ui.current_action_menu_choices[0].get("disabled", false))

func test_stale_life_payment_cannot_be_confirmed():
	var player = game_ui.game_wrapper.current_game.player
	player.life = 2
	player.spend_life_for_force_amount = 1
	game_ui.ui_state = game_ui.UIState.UIState_SelectCards
	game_ui.ui_sub_state = game_ui.UISubState.UISubState_SelectCards_ForceForChange
	game_ui.can_spend_life_for_force = true
	game_ui.action_menu.number_panel_current_number = 2
	assert_false(game_ui.can_press_ok())
	game_ui.action_menu.number_panel_current_number = 1
	assert_true(game_ui.can_press_ok())
