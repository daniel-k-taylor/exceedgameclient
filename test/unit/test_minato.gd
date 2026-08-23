extends ExceedGutTest

const RemoteGameScript = preload("res://scenes/core/remote_game.gd")

class CaptureRemoteGame extends RemoteGameScript:
	var last_action_message = {}

	func _init():
		super(null)

	func _submit_game_message(action_message):
		_add_pending_minato_seal_payment(action_message)
		last_action_message = action_message

func who_am_i():
	return "minato"

func spawn_card_to_zone(player : Player, def_id : String, zone : String) -> int:
	var card_id = give_player_specific_card(player, def_id)
	var card = player.hand[player.hand.size() - 1]
	match zone:
		"gauge":
			player.add_to_gauge(card)
			player.hand.remove_at(player.hand.size() - 1)
		"sealed":
			player.add_to_sealed(card)
			player.hand.remove_at(player.hand.size() - 1)
		"discard":
			player.discard([card_id])
		_:
			assert(false, "Unknown zone: %s" % zone)
	return card_id

func test_change_works_with_only_seal_force_bonus():
	var hand_before = player1.hand.size()
	player1.seal_force_bonus_tmp = 1

	assert_true(game_logic.do_change(player1, [], false))

	assert_eq(player1.seal_force_bonus_tmp, 0)
	assert_eq(player1.hand.size(), hand_before + 2)

func test_change_works_with_mixed_seal_force_and_card_force():
	var hand_before = player1.hand.size()
	var payment_id = give_player_specific_card(player1, "standard_normal_grasp")
	player1.seal_force_bonus_tmp = 1

	assert_true(game_logic.do_change(player1, [payment_id], false))

	assert_eq(player1.seal_force_bonus_tmp, 0)
	assert_true(player1.is_card_in_discards(payment_id))
	assert_eq(player1.hand.size(), hand_before + 3)

func test_move_range_counts_force_available_from_sealing_discards():
	position_players(player1, 3, player2, 7)
	player1.hand.clear()
	player1.gauge.clear()
	player1.free_force = 0
	player1.force_cost_reduction = 0
	for _i in range(3):
		spawn_card_to_zone(player1, "standard_normal_grasp", "discard")
	assert_eq(player1.get_force_to_move_to(6), 3)
	assert_true(player1.can_move_to(6, false))

	player1.seal_top_n_discards(3)
	player1.seal_force_bonus_tmp = 3
	assert_true(game_logic.do_move(player1, [], 6))
	assert_eq(player1.arena_location, 6)
	assert_eq(player1.discards.size(), 0)
	assert_eq(player1.sealed.size(), 3)


func test_remote_pay_strike_cost_processes_minato_sealed_gauge_before_validation():
	game_logic.teardown()
	game_logic.free()
	default_game_setup("taisei")
	position_players(player1, 3, player2, 7)
	for _i in range(11):
		spawn_card_to_zone(player1, "standard_normal_grasp", "discard")
	var ultra_id = give_player_specific_card(player1, "minato_streetcar_disaster")
	var response_id = give_player_specific_card(player2, "standard_normal_block")
	assert_true(game_logic.do_strike(player1, ultra_id, false, -1))
	assert_true(game_logic.do_strike(player2, response_id, false, -1))
	assert_true(game_logic.do_choice(player2, 0))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_eq(game_logic.decision_info.player, player1.my_id)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_PayStrikeCost_Required)

	var remote_game = CaptureRemoteGame.new()
	remote_game.local_game = game_logic
	remote_game._player_info = {'id': 1}
	remote_game._opponent_info = {'id': 2}
	remote_game._process_game_message({
		'action_type': 'action_pay_strike_cost',
		'player_id': 1,
		'card_ids': [],
		'wild_strike': false,
		'discard_ex_first': false,
		'use_free_force': false,
		'spent_life_for_force': 0,
		'pay_alternative_life_cost': false,
		'spent_life_for_gauge': 0,
		'minato_sealed_gauge': 3,
	})

	assert_eq(player1.sealed.size(), 9)
	assert_eq(player1.free_gauge, 0)
	assert_false(game_logic.game_state == Enums.GameState.GameState_PlayerDecision and game_logic.decision_info.player == player1.my_id and game_logic.decision_info.type == Enums.DecisionType.DecisionType_PayStrikeCost_Required)
	remote_game.free()

func test_remote_pay_strike_cost_serializes_minato_sealed_gauge():
	var remote_game = CaptureRemoteGame.new()
	remote_game.local_game = game_logic
	remote_game._player_info = {'id': 1}
	remote_game._opponent_info = {'id': 2}

	remote_game.set_pending_minato_seal_payment(0, 3)
	assert_true(remote_game.do_pay_strike_cost(player1, [], false, false, false, 0, false, 0))
	assert_false(remote_game.last_action_message.has('minato_sealed_force'))
	assert_eq(remote_game.last_action_message['minato_sealed_gauge'], 3)
	assert_eq(remote_game.last_action_message['spent_life_for_gauge'], 0)
	remote_game.free()

func test_remote_move_processes_minato_sealed_force_before_validation():
	position_players(player1, 3, player2, 7)
	player1.hand.clear()
	player1.gauge.clear()
	player1.discards.clear()
	player1.sealed.clear()
	player1.free_force = 0
	player1.force_cost_reduction = 0
	for _i in range(3):
		spawn_card_to_zone(player1, "standard_normal_grasp", "discard")

	var remote_game = CaptureRemoteGame.new()
	remote_game.local_game = game_logic
	remote_game._player_info = {'id': 1}
	remote_game._opponent_info = {'id': 2}
	remote_game._process_game_message({
		'action_type': 'action_move',
		'player_id': 1,
		'card_ids': [],
		'new_arena_location': 6,
		'use_free_force': false,
		'spent_life_for_force': 0,
		'minato_sealed_force': 3,
	})

	assert_eq(player1.arena_location, 6)
	assert_eq(player1.sealed.size(), 3)
	assert_eq(player1.discards.size(), 0)
	assert_eq(player1.seal_force_bonus_tmp, 0)
	remote_game.free()

func test_cleared_minato_seal_payment_does_not_leak_to_next_remote_action():
	var remote_game = CaptureRemoteGame.new()
	remote_game.local_game = game_logic
	remote_game._player_info = {'id': 1}
	remote_game._opponent_info = {'id': 2}
	remote_game.set_pending_minato_seal_payment(2, 1)
	remote_game.clear_pending_minato_seal_payment()

	assert_true(remote_game.do_prepare(player1))
	assert_false(remote_game.last_action_message.has('minato_sealed_force'))
	assert_false(remote_game.last_action_message.has('minato_sealed_gauge'))
	remote_game.free()

func test_set_strike_payment_permissions_do_not_emit_character_bonus():
	position_players(player1, 3, player2, 7)

	execute_strike(player1, player2, "standard_normal_cross", "standard_normal_focus")
	var events = game_logic.get_latest_events()

	validate_not_has_event(events, Enums.EventType.EventType_Strike_CharacterEffect, player1)
	assert_eq(player1.strike_stat_boosts.active_character_effects.size(), 0)

func test_exceed_seal_power_bonus_emits_character_effect_text_when_strike_starts():
	position_players(player1, 3, player2, 7)
	player1.exceeded = true
	player1.minato_seal_power_bonus = 3

	assert_true(game_logic.do_strike(player1, give_player_specific_card(player1, "standard_normal_cross"), false, -1))
	assert_true(game_logic.do_strike(player2, give_player_specific_card(player2, "standard_normal_focus"), false, -1))
	var events = game_logic.get_latest_events()

	var found_char_effect = false
	for event in events:
		if event['event_type'] == Enums.EventType.EventType_Strike_CharacterEffect and event['event_player'] == player1.my_id:
			var effect = event.get('extra_info', {})
			if effect.get('override_description', '').find("gains +3 Power on next attack") != -1:
				found_char_effect = true
				break
	assert_true(found_char_effect)

func test_fractured_memories_attack_is_ex_with_copy_in_sealed():
	position_players(player1, 1, player2, 4)
	add_transform(player1, "minato_bus_stop")
	spawn_card_to_zone(player1, "minato_jump_the_shark", "sealed")

	execute_strike(player1, player2, "minato_jump_the_shark", "standard_normal_focus")
	var events = game_logic.get_latest_events()

	validate_has_event(events, Enums.EventType.EventType_Strike_ExUp, player1)

func test_fractured_memories_does_not_check_gauge_copy():
	position_players(player1, 1, player2, 4)
	add_transform(player1, "minato_bus_stop")
	spawn_card_to_zone(player1, "minato_jump_the_shark", "gauge")

	execute_strike(player1, player2, "minato_jump_the_shark", "standard_normal_focus")
	var events = game_logic.get_latest_events()

	validate_not_has_event(events, Enums.EventType.EventType_Strike_ExUp, player1)

func test_weight_of_regret_returns_missed_attack_to_hand():
	position_players(player1, 1, player2, 5)
	add_transform(player1, "minato_barnstorming")

	var strike_cards = execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_focus", false, false, [0], [])

	assert_true(player1.is_card_in_hand(strike_cards[0]))

func test_outrun_the_past_seals_discard_and_gauge_then_draws():
	var discard_id = spawn_card_to_zone(player1, "standard_normal_grasp", "discard")
	var gauge_id = spawn_card_to_zone(player1, "standard_normal_cross", "gauge")
	var hand_before = player1.hand.size()
	game_logic.get_latest_events()

	game_logic.handle_strike_effect(-1, {"effect_type": "minato_outrun_the_past"}, player1)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseFromDiscard)
	assert_eq(game_logic.decision_info.source, "outrun_seal")

	assert_true(game_logic.do_choose_from_discard(player1, [discard_id, gauge_id]))
	var events = game_logic.get_latest_events()

	assert_true(player1.is_card_in_sealed(discard_id))
	assert_true(player1.is_card_in_sealed(gauge_id))
	assert_eq(player1.hand.size(), hand_before + 1)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)
	validate_has_event(events, Enums.EventType.EventType_ForceStartStrike, player1)

func test_outrun_the_past_cancel_still_returns_to_strike_flow():
	spawn_card_to_zone(player1, "standard_normal_grasp", "discard")
	var hand_before = player1.hand.size()
	game_logic.get_latest_events()

	game_logic.handle_strike_effect(-1, {"effect_type": "minato_outrun_the_past"}, player1)
	assert_true(game_logic.do_choose_from_discard(player1, []))
	var events = game_logic.get_latest_events()

	assert_eq(player1.hand.size(), hand_before)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)
	validate_has_event(events, Enums.EventType.EventType_ForceStartStrike, player1)

func test_outrun_the_past_defender_triggers_before_setting_response():
	position_players(player1, 3, player2, 5)
	add_transform(player2, "minato_flight_13")
	spawn_card_to_zone(player2, "standard_normal_cross", "discard")
	var attack_id = give_player_specific_card(player1, "standard_normal_assault")
	var response_id = give_player_specific_card(player2, "standard_normal_block")

	assert_true(game_logic.do_strike(player1, attack_id, false, -1))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_eq(game_logic.decision_info.player, player2.my_id)
	assert_eq(game_logic.decision_info.source, "outrun_seal")

	assert_true(game_logic.do_choose_from_discard(player2, []))
	assert_true(game_logic.do_strike(player2, response_id, false, -1))

func test_one_more_ride_returns_sealed_instead_of_end_draw():
	var sealed_id = spawn_card_to_zone(player1, "standard_normal_sweep", "sealed")
	var boost_id = give_player_specific_card(player1, "minato_cabstand")
	var hand_before = player1.hand.size()

	assert_true(game_logic.do_boost(player1, boost_id, []))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)
	assert_true(game_logic.do_choice(player1, 0))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseFromDiscard)
	assert_eq(game_logic.decision_info.source, "sealed")

	assert_true(game_logic.do_choose_from_discard(player1, [sealed_id]))

	assert_true(player1.is_card_in_hand(sealed_id))
	assert_eq(player1.hand.size(), hand_before)

func test_one_more_ride_triggers_again_next_turn_while_boost_remains():
	var sealed_id_1 = spawn_card_to_zone(player1, "standard_normal_sweep", "sealed")
	var sealed_id_2 = spawn_card_to_zone(player1, "standard_normal_grasp", "sealed")
	var boost_id = give_player_specific_card(player1, "minato_cabstand")

	assert_true(game_logic.do_boost(player1, boost_id, []))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)
	assert_true(game_logic.do_choice(player1, 0))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseFromDiscard)
	assert_eq(game_logic.decision_info.source, "sealed")
	assert_true(game_logic.do_choose_from_discard(player1, [sealed_id_1]))
	assert_true(player1.is_card_in_hand(sealed_id_1))
	assert_eq(player1.continuous_boosts.size(), 1)

	advance_turn(player2)
	advance_turn(player1)

	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_eq(game_logic.decision_info.player, player1.my_id)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)
	assert_true(game_logic.do_choice(player1, 0))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseFromDiscard)
	assert_eq(game_logic.decision_info.source, "sealed")
	assert_true(game_logic.do_choose_from_discard(player1, [sealed_id_2]))
	assert_true(player1.is_card_in_hand(sealed_id_2))

func test_one_more_ride_does_not_stack_with_two_boosts():
	spawn_card_to_zone(player1, "standard_normal_sweep", "sealed")
	var boost_id_1 = give_player_specific_card(player1, "minato_cabstand")

	assert_true(game_logic.do_boost(player1, boost_id_1, []))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_true(game_logic.do_choice(player1, 1))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)

	advance_turn(player2)
	var boost_id_2 = give_player_specific_card(player1, "minato_cabstand")

	assert_true(game_logic.do_boost(player1, boost_id_2, []))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_eq(player1.continuous_boosts.size(), 2)
	assert_eq(game_logic.decision_info.player, player1.my_id)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_EffectChoice)
	assert_eq(game_logic.decision_info.choice.size(), 2)
	assert_true(game_logic.do_choice(player1, 1))

func test_daredevil_multiple_boosts_stack_per_card_instance():
	position_players(player1, 2, player2, 5)
	var boost_id_1 = give_player_specific_card(player1, "minato_streetcar_disaster")
	var boost_id_2 = give_player_specific_card(player1, "minato_streetcar_disaster")

	assert_true(game_logic.do_boost(player1, boost_id_1, []))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_true(game_logic.do_choice(player1, 1))
	assert_eq(player1.continuous_boosts.size(), 1)
	assert_eq(int(player1.continuous_boosts[0].get_meta("speedup_counter", 0)), 2)

	game_logic.game_state = Enums.GameState.GameState_PickAction
	game_logic.active_turn_player = player1.my_id

	assert_true(game_logic.do_boost(player1, boost_id_2, []))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_true(game_logic.do_choice(player1, 3))
	assert_eq(player1.continuous_boosts.size(), 2)
	assert_eq(int(player1.continuous_boosts[1].get_meta("speedup_counter", 0)), 4)
	assert_eq(player1.sealed.size(), 6)

	var attack_id = give_player_specific_card(player1, "standard_normal_sweep")
	assert_true(game_logic.do_strike(player1, attack_id, false, -1))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_Strike_Opponent_Response)

	assert_eq(game_logic.get_total_speed(player1), 8)

func test_exceed_begin_turn_seals_discards_and_next_attack_gets_power():
	position_players(player1, 4, player2, 5)
	spawn_card_to_zone(player1, "standard_normal_grasp", "discard")
	spawn_card_to_zone(player1, "standard_normal_cross", "discard")
	player1.exceed()
	game_logic.get_latest_events()

	game_logic.start_begin_turn()

	assert_eq(player1.discards.size(), 0)
	assert_eq(player1.minato_seal_power_bonus, 2)
	assert_eq(player1.sealed.size(), 2)

	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_focus")

	assert_eq(player1.minato_seal_power_bonus, 0)
	validate_life(player1, 26, player2, 26)

func test_exceed_bonus_persists_during_strike_and_clears_after_cleanup():
	position_players(player1, 4, player2, 5)
	player1.exceeded = true
	player1.minato_seal_power_bonus = 2

	assert_true(game_logic.do_strike(player1, give_player_specific_card(player1, "standard_normal_assault"), false, -1))
	assert_eq(player1.minato_seal_power_bonus, 2)
	assert_true(game_logic.do_strike(player2, give_player_specific_card(player2, "standard_normal_focus"), false, -1))
	assert_eq(player1.minato_seal_power_bonus, 0)

func test_exceed_clears_free_gauge_after_payment():
	position_players(player1, 4, player2, 5)
	var gauge_ids = give_gauge(player1, 3)
	player1.free_gauge = 2

	assert_true(game_logic.do_exceed(player1, gauge_ids))
	assert_eq(player1.free_gauge, 0)

func test_ultra_cost_counts_gauge_available_from_sealing_discards():
	position_players(player1, 3, player2, 7)
	var gauge_ids = give_gauge(player1, 1)
	for _i in range(6):
		spawn_card_to_zone(player1, "standard_normal_grasp", "discard")
	var ultra_id = give_player_specific_card(player1, "minato_streetcar_disaster")
	var response_id = give_player_specific_card(player2, "standard_normal_focus")

	assert_true(game_logic.do_strike(player1, ultra_id, false, -1))
	assert_true(game_logic.do_strike(player2, response_id, false, -1))

	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_eq(game_logic.decision_info.player, player1.my_id)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_PayStrikeCost_Required)
	assert_eq(game_logic.decision_info.limitation, "gauge")
	assert_eq(game_logic.decision_info.cost, 3)

	player1.seal_top_n_discards(6)
	player1.free_gauge += 2
	assert_true(game_logic.do_pay_strike_cost(player1, gauge_ids, false))
	assert_eq(player1.discards.size(), 2)
	assert_eq(player1.gauge.size(), 0)
	assert_eq(player1.sealed.size(), 6)

func test_can_pay_cost_counts_seal_gauge_potential():
	position_players(player1, 4, player2, 5)
	give_gauge(player1, 3)
	for i in range(9):
		spawn_card_to_zone(player1, "standard_normal_grasp", "discard")
	assert_true(player1.can_pay_cost(0, 6))

func test_can_do_exceed_counts_seal_gauge_potential():
	position_players(player1, 4, player2, 5)
	game_logic.game_state = Enums.GameState.GameState_PickAction
	game_logic.active_turn_player = player1.my_id
	player1.gauge.clear()
	player1.free_gauge = 0
	player1.exceed_cost = 2
	for i in range(6):
		spawn_card_to_zone(player1, "standard_normal_grasp", "discard")

	assert_true(game_logic.can_do_exceed(player1))

func test_can_pay_cost_rejects_when_seal_gauge_insufficient():
	position_players(player1, 4, player2, 5)
	give_gauge(player1, 3)
	for i in range(3):
		spawn_card_to_zone(player1, "standard_normal_grasp", "discard")
	assert_false(player1.can_pay_cost(0, 6))

func test_can_pay_cost_counts_seal_force_potential():
	position_players(player1, 4, player2, 5)
	player1.hand = []
	for i in range(3):
		spawn_card_to_zone(player1, "standard_normal_grasp", "discard")
	assert_true(player1.can_pay_cost(3, 0))

func test_can_move_to_counts_seal_force_potential():
	position_players(player1, 4, player2, 5)
	player1.hand = []
	spawn_card_to_zone(player1, "standard_normal_grasp", "discard")
	spawn_card_to_zone(player1, "standard_normal_cross", "discard")
	assert_true(player1.can_move_to(3, false))

func test_can_move_to_rejects_without_seal_force():
	position_players(player1, 4, player2, 5)
	player1.hand = []
	assert_false(player1.can_move_to(3, false))

func test_can_do_move_counts_seal_force_potential():
	position_players(player1, 4, player2, 5)
	player1.hand = []
	spawn_card_to_zone(player1, "standard_normal_grasp", "discard")
	spawn_card_to_zone(player1, "standard_normal_cross", "discard")
	assert_true(game_logic.can_do_move(player1))

func seal_all_other_cards(player, keep_id = -1):
	for card in player.hand.duplicate():
		if card.id != keep_id:
			player.add_to_sealed(card)
			player.hand.erase(card)
	for card in player.deck.duplicate():
		if card.id != keep_id:
			player.add_to_sealed(card)
			player.deck.erase(card)
	for card in player.discards.duplicate():
		if card.id != keep_id:
			player.add_to_sealed(card)
			player.discards.erase(card)

func test_hellward_bound_free_when_all_other_cards_sealed():
	position_players(player1, 2, player2, 5)
	var hb_id = give_player_specific_card(player1, "minato_hellward_bound")
	seal_all_other_cards(player1, hb_id)
	do_and_validate_strike(player1, hb_id)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_Strike_Opponent_Response)
	var hb_card = game_logic.active_strike.get_player_card(player1)
	assert_eq(game_logic.get_gauge_cost(player1, hb_card), 0)

func test_hellward_bound_not_free_when_discard_has_cards():
	position_players(player1, 2, player2, 5)
	give_gauge(player1, 6)
	var hb_id = give_player_specific_card(player1, "minato_hellward_bound")
	seal_all_other_cards(player1, hb_id)
	spawn_card_to_zone(player1, "standard_normal_grasp", "discard")
	var gauge_cards = []
	for c in player1.gauge:
		gauge_cards.append(c.id)
	execute_strike(player1, player2, hb_id, "standard_normal_dive", false, false,
		[gauge_cards],
		[[]],
		true)
	assert_eq(player1.gauge.size(), 0)

# ===== FAQ RULING M1 =====
# "Can Minato spend Gauge and then seal that same card from his discard as part
#  of a Gauge cost? Or discard a card and then seal it as part of a Force cost?
#  A: No. Costs are paid simultaneously and in full, so he cannot double-spend
#  the same card."
# Minato converts sealed discards into resources (1 Force per discard, or 1
# Gauge per 3 discards). A card he spends (Gauge -> discard, or hand -> discard)
# during a cost cannot ALSO be counted as a sealed discard for that same cost.

func test_faq_m1_cannot_double_count_spent_gauge_as_sealed_discard():
	position_players(player1, 4, player2, 5)
	player1.gauge.clear()
	player1.free_gauge = 0
	player1.discards.clear()
	# 1 real Gauge card + only 2 discards (not enough for a seal, which needs 3).
	spawn_card_to_zone(player1, "standard_normal_grasp", "gauge")
	spawn_card_to_zone(player1, "standard_normal_cross", "discard")
	spawn_card_to_zone(player1, "standard_normal_dive", "discard")
	# Available Gauge = 1 (real) + floor(2/3) (seals) = 1. A Gauge cost of 2 is
	# NOT payable: the single spent Gauge card cannot then be re-sealed from the
	# discard to cover the shortfall.
	assert_false(player1.can_pay_cost(0, 2),
			"Minato cannot double-count the spent Gauge card as a sealed discard")
	# Positive control: with 3 SEPARATE discards, sealing them yields 1 Gauge, so
	# 1 real + 1 sealed = 2, each card counted exactly once.
	spawn_card_to_zone(player1, "standard_normal_spike", "discard")
	assert_true(player1.can_pay_cost(0, 2),
			"distinct cards each counted once can legitimately pay a Gauge cost of 2")

func test_faq_m1_cannot_double_count_discarded_force_card_as_sealed():
	position_players(player1, 4, player2, 5)
	player1.hand.clear()
	player1.gauge.clear()
	player1.free_gauge = 0
	player1.discards.clear()
	# 1 Force from a single hand card, 0 discards.
	give_player_specific_card(player1, "standard_normal_grasp")
	# Available Force = 1 (hand) + 0 (seals). A Force cost of 2 is NOT payable:
	# discarding the hand card to pay Force does not let it also be sealed from
	# the discard for the same cost.
	assert_false(player1.can_pay_cost(2, 0),
			"Minato cannot double-count the discarded Force card as a sealed discard")
	# Positive control: one hand card (1 Force) plus one SEPARATE discard sealed
	# for 1 Force = 2, each card counted exactly once.
	spawn_card_to_zone(player1, "standard_normal_cross", "discard")
	assert_true(player1.can_pay_cost(2, 0),
			"distinct cards each counted once can legitimately pay a Force cost of 2")

func test_jump_the_shark_powerup_scales_per_four_sealed():
	# Jump the Shark (power 2) at distance 3. Grasp is faster but only reaches
	# range 1, so it whiffs and cannot retaliate, isolating the power bonus.
	# 8 sealed -> +2 Power -> 4 damage.
	position_players(player1, 1, player2, 4)
	for i in range(8):
		spawn_card_to_zone(player1, "standard_normal_focus", "sealed")

	execute_strike(player1, player2, "minato_jump_the_shark", "standard_normal_grasp")

	validate_life(player1, 30, player2, 26)

func test_jump_the_shark_powerup_rounds_down_and_caps_at_five():
	# 23 sealed -> 23/4 rounds down to 5, which is also the cap -> 7 damage.
	position_players(player1, 1, player2, 4)
	for i in range(23):
		spawn_card_to_zone(player1, "standard_normal_focus", "sealed")

	execute_strike(player1, player2, "minato_jump_the_shark", "standard_normal_grasp")

	validate_life(player1, 30, player2, 23)

func test_jump_the_shark_no_powerup_below_four_sealed():
	# 3 sealed -> no bonus, so only the base power 2 lands.
	position_players(player1, 1, player2, 4)
	for i in range(3):
		spawn_card_to_zone(player1, "standard_normal_focus", "sealed")

	execute_strike(player1, player2, "minato_jump_the_shark", "standard_normal_grasp")

	validate_life(player1, 30, player2, 28)

func test_flight_13_discards_topdeck_and_retreats_one_per_card():
	position_players(player1, 5, player2, 6)
	var deck_before = player1.deck.size()

	# Choice index 2 discards 3 cards from the top of the deck and retreats 3.
	execute_strike(player1, player2, "minato_flight_13", "standard_normal_sweep", false, false, [2], [])

	assert_eq(player1.deck.size(), deck_before - 3)
	validate_positions(player1, 2, player2, 6)

func test_flight_13_can_decline_the_topdeck_discard():
	position_players(player1, 5, player2, 6)
	var deck_before = player1.deck.size()

	# Choice index 3 is the Pass option.
	execute_strike(player1, player2, "minato_flight_13", "standard_normal_sweep", false, false, [3], [])

	assert_eq(player1.deck.size(), deck_before)
	validate_positions(player1, 5, player2, 6)


func test_cabstand_before_effect_closes_one_per_force_spent():
	# Cabstand's "before" effect is a force_for_effect whose per_force_effect
	# closes 1. Its definition omitted the usual "overall_effect": null, which
	# crashed the UI when the decision was presented.
	position_players(player1, 4, player2, 6)
	var force_cards = get_cards_from_hand(player1, 1)

	# Spend 1 force: close 1 (4 -> 5) puts Cabstand's range 1-1 on target, so it
	# hits for 3 power - 2 Focus armor = 1, then its "after" advance 3 runs.
	execute_strike(player1, player2, "minato_cabstand", "standard_normal_focus",
		false, false, [force_cards], [])

	validate_life(player1, 30, player2, 29)
	validate_positions(player1, 9, player2, 6)

func test_cabstand_before_effect_can_spend_no_force():
	# Spending no force is legal (force_min is 0); without the close, Cabstand
	# stays at range 2 and misses.
	position_players(player1, 4, player2, 6)

	execute_strike(player1, player2, "minato_cabstand", "standard_normal_focus",
		false, false, [[]], [])

	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_Strike_Miss, player1)
	validate_life(player1, 26, player2, 30)
	validate_positions(player1, 8, player2, 6)

# ===== Hellraiser (Hellward Bound boost) =====
# Composed entirely from generic effects: discard_topdeck(4) ->
# discard_opponent_topdeck(4) -> choose_discard from sealed to hand.

func test_hellraiser_discards_top_four_from_both_decks():
	var hb_id = give_player_specific_card(player1, "minato_hellward_bound")
	var p1_deck_before = player1.deck.size()
	var p2_deck_before = player2.deck.size()
	var p1_discards_before = player1.discards.size()
	var p2_discards_before = player2.discards.size()

	assert_true(game_logic.do_boost(player1, hb_id, []))

	# Boosting also ends the turn, which draws a card and puts the spent boost
	# into the discard pile, hence the extra one on each of Minato's counts.
	assert_eq(player1.deck.size(), p1_deck_before - 5)
	assert_eq(player2.deck.size(), p2_deck_before - 4)
	assert_eq(player1.discards.size(), p1_discards_before + 5)
	assert_eq(player2.discards.size(), p2_discards_before + 4)
	# No sealed cards, so the return step is skipped entirely.
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)

func test_hellraiser_returns_up_to_two_sealed_cards_to_hand():
	var sealed_a = spawn_card_to_zone(player1, "standard_normal_grasp", "sealed")
	var sealed_b = spawn_card_to_zone(player1, "standard_normal_dive", "sealed")
	spawn_card_to_zone(player1, "standard_normal_cross", "sealed")
	var hb_id = give_player_specific_card(player1, "minato_hellward_bound")

	assert_true(game_logic.do_boost(player1, hb_id, []))

	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
	assert_eq(game_logic.decision_info.type, Enums.DecisionType.DecisionType_ChooseFromDiscard)
	assert_eq(game_logic.decision_info.source, "sealed")
	assert_eq(game_logic.decision_info.destination, "hand")
	assert_eq(game_logic.decision_info.amount, 2)
	assert_eq(game_logic.decision_info.amount_min, 0, "returning sealed cards is optional")

	assert_true(game_logic.do_choose_from_discard(player1, [sealed_a, sealed_b]))
	assert_true(player1.is_card_in_hand(sealed_a))
	assert_true(player1.is_card_in_hand(sealed_b))
	assert_eq(player1.sealed.size(), 1)

func test_hellraiser_sealed_return_can_be_declined():
	spawn_card_to_zone(player1, "standard_normal_grasp", "sealed")
	var hb_id = give_player_specific_card(player1, "minato_hellward_bound")

	assert_true(game_logic.do_boost(player1, hb_id, []))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)

	assert_true(game_logic.do_choose_from_discard(player1, []))
	assert_eq(player1.sealed.size(), 1, "declining leaves the sealed card alone")

func test_hellraiser_handles_a_deck_shorter_than_four_cards():
	var hb_id = give_player_specific_card(player1, "minato_hellward_bound")
	while player1.deck.size() > 2:
		player1.deck.remove_at(player1.deck.size() - 1)
	var reshuffles_before = player1.reshuffle_remaining

	assert_true(game_logic.do_boost(player1, hb_id, []))

	# Running the deck out mid-effect must reshuffle rather than error out.
	assert_lt(player1.reshuffle_remaining, reshuffles_before)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)
