extends GutTest

# Tests for AIPolicyOmniscient (the ported "super" difficulty policy) and its
# helper AICardKnowledge.
#
# The full-game driver below is a self-contained copy of the harness in
# test_randomai.gd, parametrised to run the Omniscient policy. It verifies the
# policy answers every pick_* decision with a legal action across a complete
# game. Additional focused unit tests cover interface conformance, the hidden-
# information gate, _eval_counter_response scoring, and AICardKnowledge.

var game_logic : LocalGame
var image_loader : CardImageLoader
var default_deck = CardDataManager.get_deck_from_str_id("ryu")
var opponent_deck = CardDataManager.get_deck_from_str_id("ryu")

var player1 : Player
var player2 : Player
var ai1 : AIPlayer
var ai2 : AIPlayer

# Stuck-game detection state (reset at the start of each game).
var _stuck_last_signature : String = ""
var _stuck_repeat_count : int = 0
const _STUCK_REPEAT_LIMIT = 300

func game_setup(policy_type = AIPolicyOmniscient, opp_policy_type = AIPolicyOmniscient):
	image_loader = CardImageLoader.new(true)
	game_logic = LocalGame.new(image_loader)
	var seed_value = randi()
	game_logic.initialize_game(
			default_deck, opponent_deck,
			"p1", "p2", Enums.PlayerId.PlayerId_Player, seed_value)
	game_logic.draw_starting_hands_and_begin()
	game_logic.get_latest_events()
	player1 = game_logic.player
	player2 = game_logic.opponent
	ai1 = AIPlayer.new(game_logic, player1, policy_type.new())
	ai2 = AIPlayer.new(game_logic, player2, opp_policy_type.new())

func game_teardown():
	game_logic.teardown()
	game_logic.free()
	ai1.ai_policy.free()
	ai2.ai_policy.free()

func validate_has_event(events, event_type, event_player, number = null):
	for event in events:
		if event['event_type'] == event_type:
			assert_eq(event['event_player'], event_player.my_id, "Wrong player for event %s" % str(event_type))
			if number != null:
				assert_eq(event['number'], number, "Wrong value for event %s value %s" % [str(event_type), str(event['number'])])
			return
	fail_test("Validate Event not found: %s" % str(event_type))
	assert(false, "Validate Event not found: %s" % str(event_type))

func after_each():
	if is_instance_valid(game_logic):
		game_teardown()

func get_event(events, event_type):
	for event in events:
		if event['event_type'] == event_type:
			return event
	fail_test("Get Event not found: %s" % str(event_type))
	assert(false, "Get Event not found: %s" % str(event_type))

func handle_discard_event(events, game : LocalGame, aiplayer : AIPlayer, gameplayer : Player):
	if game.game_state == Enums.GameState.GameState_DiscardDownToMax:
		var event = get_event(events, Enums.EventType.EventType_HandSizeExceeded)
		var discard_required_count = event['number']
		var discard_action = aiplayer.pick_discard_to_max(discard_required_count)
		assert_true(game.do_discard_to_max(gameplayer, discard_action.card_ids), "do discard failed")
		events += game.get_latest_events()

func handle_prepare(game : LocalGame, gameplayer : Player):
	var do_prepare = game.do_prepare(gameplayer)
	assert_true(do_prepare, "do prepare failed")
	return game.get_latest_events()

func handle_move(game: LocalGame, gameplayer : Player, action : AIPlayer.MoveAction):
	var location = action.location
	var card_ids = action.force_card_ids
	var use_free_force = action.use_free_force
	var do_move = game.do_move(gameplayer, card_ids, location, use_free_force)
	assert_true(do_move, "do move failed")
	return game.get_latest_events()

func handle_change_cards(game: LocalGame, gameplayer : Player, action : AIPlayer.ChangeCardsAction):
	var card_ids = action.card_ids
	var use_free_force = action.use_free_force
	assert_true(game.do_change(gameplayer, card_ids, false, use_free_force), "do change failed")
	return game.get_latest_events()

func handle_exceed(game: LocalGame, otherai, gameplayer : Player, action : AIPlayer.ExceedAction):
	var card_ids = action.card_ids
	var events = []
	assert_true(game.do_exceed(gameplayer, card_ids), "do exceed failed")
	events += game.get_latest_events()

	if game.game_state == Enums.GameState.GameState_Strike_Opponent_Response:
		var otherplayer = otherai.game_player
		var response_action = otherai.pick_strike_response()
		assert_true(game.do_strike(otherplayer, response_action.card_id, response_action.wild_swing, response_action.ex_card_id), "do strike resp failed")

	events += handle_decisions(game)
	return events

func handle_reshuffle(game: LocalGame, gameplayer : Player):
	assert_true(game.do_reshuffle(gameplayer), "do reshuffle failed")
	return game.get_latest_events()

func handle_boost(game: LocalGame, aiplayer : AIPlayer, otherai : AIPlayer, gameplayer : Player, action : AIPlayer.BoostAction):
	var events = []
	var card_id = action.card_id
	assert_true(game.do_boost(gameplayer, card_id, action.payment_card_ids, action.use_free_force), "do boost failed")
	events += game.get_latest_events()
	events += handle_decisions(game)

	if game.active_strike:
		events += handle_strike(game, aiplayer, otherai, null, true)
	return events

func handle_decisions(game: LocalGame):
	var events = []
	while game.game_state == Enums.GameState.GameState_PlayerDecision:
		var decision_player = game._get_player(game.decision_info.player)
		var decision_ai = ai1
		if decision_player.my_id != ai1.game_player.my_id:
			decision_ai = ai2
		match game.decision_info.type:
			Enums.DecisionType.DecisionType_BoostCancel:
				var cancel_action = decision_ai.pick_cancel(1)
				assert_true(game.do_boost_cancel(decision_player, cancel_action.card_ids, cancel_action.cancel), "do boost cancel failed")
			Enums.DecisionType.DecisionType_NameCard_OpponentDiscards:
				var pick_action = decision_ai.pick_name_opponent_card(false)
				assert_true(game.do_boost_name_card_choice_effect(decision_player, pick_action.card_id), "do boost name failed")
			Enums.DecisionType.DecisionType_ReadingNormal:
				var pick_action = decision_ai.pick_name_opponent_card(true)
				assert_true(game.do_boost_name_card_choice_effect(decision_player, pick_action.card_id), "do boost name failed")
			Enums.DecisionType.DecisionType_Sidestep:
				var pick_action = decision_ai.pick_name_opponent_card(true)
				assert_true(game.do_boost_name_card_choice_effect(decision_player, pick_action.card_id), "do boost name failed")
			Enums.DecisionType.DecisionType_ZeroVector:
				var pick_action = decision_ai.pick_name_opponent_card(false, game.decision_info.bonus_effect)
				assert_true(game.do_boost_name_card_choice_effect(decision_player, pick_action.card_id), "do boost name failed")
			Enums.DecisionType.DecisionType_PayStrikeCost_Required, Enums.DecisionType.DecisionType_PayStrikeCost_CanWild:
				var can_wild = game.decision_info.type == Enums.DecisionType.DecisionType_PayStrikeCost_CanWild
				var cost = game.decision_info.cost
				var is_gauge = game.decision_info.limitation == "gauge"
				var pay_action
				if is_gauge:
					pay_action = decision_ai.pay_strike_gauge_cost(cost, can_wild, 0)
				else:
					pay_action = decision_ai.pay_strike_force_cost(cost, can_wild, 0)
				assert_true(game.do_pay_strike_cost(decision_player, pay_action.card_ids, pay_action.wild_swing, true, pay_action.use_free_force), "do pay failed")
			Enums.DecisionType.DecisionType_EffectChoice, Enums.DecisionType.DecisionType_ChooseSimultaneousEffect:
				var effect_action = decision_ai.pick_effect_choice()
				assert_true(game.do_choice(decision_ai.game_player, effect_action.choice), "do strike choice failed")
			Enums.DecisionType.DecisionType_ForceForArmor:
				var forceforarmor_action = decision_ai.pick_force_for_armor(game.decision_info.limitation == "gauge")
				assert_true(game.do_force_for_armor(decision_ai.game_player, forceforarmor_action.card_ids, forceforarmor_action.use_free_force), "do force armor failed")
			Enums.DecisionType.DecisionType_CardFromHandToGauge:
				var restricted_to_card_ids = game.decision_info.effect.get('restricted_to_card_ids', [])
				var cardfromhandtogauge_action = decision_ai.pick_card_hand_to_gauge(game.decision_info.effect['min_amount'], game.decision_info.effect['max_amount'], restricted_to_card_ids)
				assert_true(game.do_relocate_card_from_hand(decision_ai.game_player, cardfromhandtogauge_action.card_ids), "do card hand strike failed")
			Enums.DecisionType.DecisionType_ForceForEffect:
				var effect = game.decision_info.effect
				var options = []
				if effect['per_force_effect'] != null:
					for i in range(effect['force_max'] + 1):
						options.append(i)
				else:
					options.append(0)
					options.append(effect['force_max'])
				var forceforeffect_action = decision_ai.pick_force_for_effect(options)
				assert_true(game.do_force_for_effect(decision_ai.game_player, forceforeffect_action.card_ids, false, false, forceforeffect_action.use_free_force), "do force effect failed")
			Enums.DecisionType.DecisionType_GaugeForEffect:
				var effect = game.decision_info.effect
				var options = []
				if effect['per_gauge_effect'] != null:
					for i in range(effect['gauge_max'] + 1):
						options.append(i)
				else:
					if not ('required' in effect and effect['required']):
						options.append(0)
					options.append(effect['gauge_max'])
				var required_card_id = ""
				if 'require_specific_card_id' in effect:
					required_card_id = effect['require_specific_card_id']
				var valid_card_types = []
				if 'valid_card_types' in effect:
					valid_card_types = effect['valid_card_types']
				var gauge_action = decision_ai.pick_gauge_for_effect(options, required_card_id, valid_card_types)
				var result = game.do_gauge_for_effect(decision_ai.game_player, gauge_action.card_ids)
				assert_true(result, "do gauge effect failed")
			Enums.DecisionType.DecisionType_ChooseFromBoosts:
				var chooseaction = decision_ai.pick_choose_from_boosts(game.decision_info.amount)
				assert_true(game.do_choose_from_boosts(decision_ai.game_player, chooseaction.card_ids), "do choose from boosts failed")
			Enums.DecisionType.DecisionType_ChooseFromDiscard:
				var chooseaction = decision_ai.pick_choose_from_discard(game.decision_info.amount)
				assert_true(game.do_choose_from_discard(decision_ai.game_player, chooseaction.card_ids), "do choose from discard failed")
			Enums.DecisionType.DecisionType_ChooseToDiscard:
				var chooseaction
				if game.decision_info.effect['effect_type'] == "choose_opponent_card_to_discard":
					var card_ids = game.decision_info.choice
					chooseaction = decision_ai.pick_choose_opponent_card_to_discard(card_ids)
				else:
					var amount = game.decision_info.effect['amount']
					var limitation = game.decision_info.limitation
					var can_pass = game.decision_info.can_pass
					var allow_fewer = 'allow_fewer' in game.decision_info.effect and game.decision_info.effect['allow_fewer']
					chooseaction = decision_ai.pick_choose_to_discard(amount, limitation, can_pass, allow_fewer)
				assert_true(game.do_choose_to_discard(decision_ai.game_player, chooseaction.card_ids), "do choose to discard failed")
			Enums.DecisionType.DecisionType_ChooseDiscardOpponentGauge:
				var decision_action = decision_ai.pick_discard_opponent_gauge()
				assert_true(game.do_boost_name_card_choice_effect(decision_player, decision_action.card_id), "do discard opponent gauge failed")
			Enums.DecisionType.DecisionType_BoostNow:
				var boostnow_action = decision_ai.take_boost(game.decision_info.valid_zones, game.decision_info.limitation, game.decision_info.ignore_costs, game.decision_info.amount)
				assert_true(game.do_boost(decision_player, boostnow_action.card_id, boostnow_action.payment_card_ids, boostnow_action.use_free_force, 0, boostnow_action.additional_boost_ids), "do boost now failed")
			Enums.DecisionType.DecisionType_ChooseFromTopDeck:
				var decision_info = game.decision_info
				var decision_action = decision_ai.pick_choose_from_topdeck(decision_info.action, decision_info.amount, decision_info.can_pass)
				assert_true(game.do_choose_from_topdeck(decision_player, decision_action.card_id, decision_action.action), "do choose from topdeck failed")
			Enums.DecisionType.DecisionType_ChooseArenaLocationForEffect:
				var decision_info = game.decision_info
				var decision_action = decision_ai.pick_choose_arena_location_for_effect(decision_info.limitation)
				var choice_index = 0
				for i in range(len(decision_info.limitation)):
					if decision_info.limitation[i] == decision_action.location:
						choice_index = i
						break
				assert_true(game.do_choice(decision_player, choice_index), "do arena location for effect failed")
			Enums.DecisionType.DecisionType_PickNumberFromRange:
				var decision_info = game.decision_info
				var decision_action = decision_ai.pick_number_from_range_for_effect(decision_info.limitation, decision_info.choice)
				var choice_index = 0
				for i in range(len(decision_info.limitation)):
					if decision_info.limitation[i] == decision_action.number:
						choice_index = i
						break
				assert_true(game.do_choice(decision_player, choice_index), "do pick number from range failed")
			Enums.DecisionType.DecisionType_ChooseDiscardContinuousBoost:
				var limitation = game.decision_info.limitation
				var can_pass = game.decision_info.can_pass
				var boost_name_restriction = game.decision_info.extra_info
				var choose_action = decision_ai.pick_discard_continuous(limitation, can_pass, boost_name_restriction)
				assert_true(game.do_boost_name_card_choice_effect(decision_player, choose_action.card_id), "do boost name strike s2 failed")
			_:
				assert(false, "Unimplemented decision type")

		if game.game_state == Enums.GameState.GameState_Strike_Opponent_Response:
			var defender_id = game.active_strike.defender.my_id
			var defender_ai = ai1
			if defender_id != ai1.game_player.my_id:
				defender_ai = ai2
			var response_action = defender_ai.pick_strike_response()
			assert_true(game.do_strike(defender_ai.game_player, response_action.card_id, response_action.wild_swing, response_action.ex_card_id), "do strike resp failed")

	events += game.get_latest_events()
	return events

func handle_strike(game: LocalGame, aiplayer : AIPlayer, otherai : AIPlayer, action : AIPlayer.StrikeAction, already_mid_strike : bool = false,
		opponent_sets_first = false):
	var events = []
	var gameplayer = aiplayer.game_player
	var otherplayer = otherai.game_player

	if not already_mid_strike and not opponent_sets_first:
		var success = game.do_strike(gameplayer, action.card_id, action.wild_swing, action.ex_card_id)
		assert_true(success, "do strike failed")
		events += game.get_latest_events()

	if game.game_state == Enums.GameState.GameState_Strike_Opponent_Response:
		var response_action = otherai.pick_strike_response()
		var success = game.do_strike(otherplayer, response_action.card_id, response_action.wild_swing, response_action.ex_card_id)
		assert_true(success, "do strike resp failed")
		events += handle_decisions(game)

	if game.game_state == Enums.GameState.GameState_WaitForStrike and opponent_sets_first:
		assert_true(game.do_strike(gameplayer, action.card_id, action.wild_swing, action.ex_card_id, opponent_sets_first), "do strike failed")
		events += game.get_latest_events()

	events += handle_decisions(game)

	assert_true(game.game_state == Enums.GameState.GameState_PickAction or game.game_state == Enums.GameState.GameState_GameOver, "Unexpected game state %s" % str(game.game_state))
	return events

func handle_character_action(game: LocalGame, aiplayer : AIPlayer, _otherai : AIPlayer, action : AIPlayer.CharacterActionAction):
	assert_true(game.do_character_action(aiplayer.game_player, action.card_ids, action.action_idx, action.use_free_force), "character action failed")
	var events = []
	events += game.get_latest_events()
	events += handle_decisions(game)
	return events

func _detect_stuck_game() -> bool:
	var signature = "%s|%s|%s|%s|%s|%s|%s|%s" % [
		str(game_logic.game_state),
		str(game_logic.active_turn_player),
		str(player1.life), str(player2.life),
		str(player1.hand.size()), str(player2.hand.size()),
		str(player1.arena_location), str(player2.arena_location),
	]
	if signature == _stuck_last_signature:
		_stuck_repeat_count += 1
	else:
		_stuck_last_signature = signature
		_stuck_repeat_count = 0
	return _stuck_repeat_count >= _STUCK_REPEAT_LIMIT

func run_ai_game():
	var events = []
	_stuck_last_signature = ""
	_stuck_repeat_count = 0

	var mulligan_action = ai1.pick_mulligan()
	assert_true(game_logic.do_mulligan(player1, mulligan_action.card_ids), "mull failed")
	events += game_logic.get_latest_events()
	mulligan_action = ai2.pick_mulligan()
	assert_true(game_logic.do_mulligan(player2, mulligan_action.card_ids), "mull 2 failed")
	events += game_logic.get_latest_events()

	while not game_logic.game_over:
		if _detect_stuck_game():
			fail_test("Game appears stuck (no progress) in state %s" % str(game_logic.game_state))
			break

		var current_ai = ai1
		var other_ai = ai2
		var current_player = game_logic._get_player(game_logic.active_turn_player)
		if game_logic.active_turn_player == player2.my_id:
			current_ai = ai2
			other_ai = ai1

		var turn_events = []
		turn_events += handle_decisions(game_logic)

		if game_logic.game_state != Enums.GameState.GameState_WaitForStrike:
			var turn_action = current_ai.take_turn()
			if turn_action is AIPlayer.PrepareAction:
				turn_events += handle_prepare(game_logic, current_player)
			elif turn_action is AIPlayer.MoveAction:
				turn_events += handle_move(game_logic, current_player, turn_action)
			elif turn_action is AIPlayer.ChangeCardsAction:
				turn_events += handle_change_cards(game_logic, current_player, turn_action)
			elif turn_action is AIPlayer.ExceedAction:
				turn_events += handle_exceed(game_logic, other_ai, current_player, turn_action)
			elif turn_action is AIPlayer.ReshuffleAction:
				turn_events += handle_reshuffle(game_logic, current_player)
			elif turn_action is AIPlayer.BoostAction:
				turn_events += handle_boost(game_logic, current_ai, other_ai, current_player, turn_action)
			elif turn_action is AIPlayer.StrikeAction:
				turn_events += handle_strike(game_logic, current_ai, other_ai, turn_action)
			elif turn_action is AIPlayer.CharacterActionAction:
				turn_events += handle_character_action(game_logic, current_ai, other_ai, turn_action)
			else:
				fail_test("Unknown turn action: %s" % turn_action)
				assert(false, "Unknown turn action: %s" % turn_action)

		turn_events += handle_decisions(game_logic)
		if game_logic._get_player(game_logic.active_turn_player) != current_player:
			continue

		if game_logic.game_state == Enums.GameState.GameState_WaitForStrike:
			var strike_action = null
			if current_player.next_strike_from_gauge:
				strike_action = current_ai.pick_strike("gauge")
			elif current_player.next_strike_from_sealed:
				strike_action = current_ai.pick_strike("sealed")
			elif str(game_logic.decision_info.limitation) == "EX":
				strike_action = current_ai.pick_strike("", true, false, true)
			else:
				strike_action = current_ai.pick_strike()
			turn_events += handle_strike(game_logic, current_ai, other_ai, strike_action)
		elif game_logic.game_state == Enums.GameState.GameState_Strike_Opponent_Set_First:
			var success = game_logic.do_strike(current_ai.game_player, -1, false, -1, true)
			assert(success)
			var strike_action = current_ai.pick_strike()
			turn_events += handle_strike(game_logic, current_ai, other_ai, strike_action, false, true)

		if game_logic.active_strike:
			turn_events += handle_strike(game_logic, current_ai, other_ai, null, true)

		handle_discard_event(turn_events, game_logic, current_ai, current_player)
		if game_logic.active_end_of_turn_effects:
			turn_events += handle_decisions(game_logic)

		events += turn_events

	assert_true(events.size() > 0, "no events")
	return events

### Actual tests

func _play_full_game(deck_id : String, opp_deck_id : String):
	default_deck = CardDataManager.get_deck_from_str_id(deck_id)
	opponent_deck = CardDataManager.get_deck_from_str_id(opp_deck_id)
	game_setup(AIPolicyOmniscient, AIPolicyOmniscient)
	var events = run_ai_game()
	assert_true(game_logic.game_over, "Expected game to reach completion")
	assert_true(events.size() > 0, "Expected events from the game")
	game_teardown()

func test_omniscient_full_game_mirror_ryu():
	_play_full_game("ryu", "ryu")

func test_omniscient_full_game_sol_vs_ky():
	_play_full_game("solbadguy", "kykisuke")

func test_omniscient_vs_rules():
	default_deck = CardDataManager.get_deck_from_str_id("ryu")
	opponent_deck = CardDataManager.get_deck_from_str_id("ryu")
	game_setup(AIPolicyOmniscient, AIPolicyRules)
	var events = run_ai_game()
	assert_true(game_logic.game_over, "Expected game to reach completion")
	assert_true(events.size() > 0, "Expected events")
	game_teardown()

func test_omniscient_interface_conformance():
	# The Omniscient policy must implement every pick_* decision method that the
	# reference policies expose, so it is a drop-in replacement.
	var reference = AIPolicyRandom.new()
	var policy = AIPolicyOmniscient.new()
	for method in reference.get_method_list():
		var name : String = method["name"]
		if name.begins_with("pick_"):
			assert_true(policy.has_method(name), "Omniscient missing method %s" % name)
	reference.free()
	policy.free()

func test_omniscient_hidden_info_gate_default_reads_hand():
	# With ALLOW_HIDDEN_INFO true (default), _visible_opponent_hand returns the
	# opponent's real hand; that is the documented cheat.
	game_setup(AIPolicyOmniscient, AIPolicyOmniscient)
	ai1.game_state.update(true)
	var policy = ai1.ai_policy
	assert_true(policy.ALLOW_HIDDEN_INFO, "Default build ships the omniscient (cheating) variant")
	var visible = policy._visible_opponent_hand(ai1.game_state)
	assert_eq(visible, ai1.game_state.opponent_state.hand, "Hidden-info gate should expose the real hand when enabled")
	assert_true(visible.size() > 0, "Opponent should have a starting hand")
	game_teardown()

func _make_def(speed, power, guard, armor, range_min, range_max, effects = []):
	return {
		"id": "test_card",
		"speed": speed,
		"power": power,
		"guard": guard,
		"armor": armor,
		"range_min": range_min,
		"range_max": range_max,
		"effects": effects,
	}

func test_eval_counter_response_favorable_exchange():
	var policy = AIPolicyOmniscient.new()
	# I am faster and stronger; I initiate and stun the opponent for a clean gain.
	var my_def = _make_def(6, 5, 4, 0, 1, 3)
	var opp_def = _make_def(3, 3, 2, 0, 1, 3)
	var result = policy._eval_counter_response(my_def, opp_def, 2, false)
	assert_true(result.has("exchange"), "Result should include exchange")
	assert_gt(result["exchange"], 0, "Faster/stronger card should net positive exchange")
	assert_true(result["my_hit"], "I should land my hit")
	assert_true(result["stunned"], "Opponent should be stunned before responding")
	policy.free()

func test_eval_counter_response_unfavorable_exchange():
	var policy = AIPolicyOmniscient.new()
	# I am slower and weaker; the opponent goes first and stuns me.
	var my_def = _make_def(3, 3, 2, 0, 1, 3)
	var opp_def = _make_def(6, 5, 4, 0, 1, 3)
	var result = policy._eval_counter_response(my_def, opp_def, 2, false)
	assert_lt(result["exchange"], 0, "Slower/weaker card should net negative exchange")
	policy.free()

func test_eval_counter_response_out_of_range_no_damage():
	var policy = AIPolicyOmniscient.new()
	# Both cards have short range and the distance is far: nobody hits.
	var my_def = _make_def(6, 5, 4, 0, 1, 2)
	var opp_def = _make_def(3, 3, 2, 0, 1, 2)
	var result = policy._eval_counter_response(my_def, opp_def, 5, false)
	assert_false(result["my_hit"], "No hit expected out of range")
	assert_false(result["opp_hit"], "No hit expected out of range")
	assert_eq(result["exchange"], 0, "No damage means zero exchange")
	policy.free()

func test_card_knowledge_classify():
	var knowledge = AICardKnowledge.new()
	assert_eq(knowledge.classify(CardDataManager.card_data["standard_normal_block"]), "block")
	assert_eq(knowledge.classify(CardDataManager.card_data["standard_normal_focus"]), "focus")
	assert_eq(knowledge.classify(CardDataManager.card_data["standard_normal_sweep"]), "sweep")
	assert_eq(knowledge.classify(CardDataManager.card_data["standard_normal_cross"]), "cross")
	assert_eq(knowledge.classify(CardDataManager.card_data["standard_normal_assault"]), "assault")
	# Empty definition falls back to "unknown".
	assert_eq(knowledge.classify({}), "unknown")

func test_card_knowledge_classify_effect_fallback():
	var knowledge = AICardKnowledge.new()
	# A card with both ignore effects but no keyword id is classified spike-like.
	var spike_like = {
		"id": "mystery_card",
		"speed": 3, "power": 5, "guard": 4, "armor": 0,
		"effects": [{"effect_type": "ignore_armor", "and": {"effect_type": "ignore_guard"}}],
	}
	assert_eq(knowledge.classify(spike_like), "spike")

func test_card_knowledge_counter_relation_ignore_guard_wins():
	var knowledge = AICardKnowledge.new()
	# Faster ignore-guard card first-strike stuns a slow high-guard card.
	var my_def = {"id": "a", "speed": 5, "power": 5, "guard": 2, "armor": 0,
		"effects": [{"effect_type": "ignore_guard"}]}
	var opp_def = {"id": "b", "speed": 2, "power": 4, "guard": 6, "armor": 0, "effects": []}
	var rel = knowledge.counter_relation(my_def, opp_def)
	assert_eq(rel["label"], "counter", "Faster ignore-guard card should counter")
	assert_true(rel["my_first"], "Higher speed should strike first")
	assert_true(rel["my_stuns"], "Should stun through ignored guard")

func test_card_knowledge_counter_relation_even():
	var knowledge = AICardKnowledge.new()
	var a = {"id": "a", "speed": 4, "power": 3, "guard": 3, "armor": 0, "effects": []}
	var b = {"id": "b", "speed": 4, "power": 3, "guard": 3, "armor": 0, "effects": []}
	var rel = knowledge.counter_relation(a, b)
	assert_eq(rel["label"], "even", "Identical cards should be an even matchup")

func test_card_knowledge_best_counter_in_pool_returns_card():
	var knowledge = AICardKnowledge.new()
	var block_def = CardDataManager.card_data["standard_normal_block"]
	var best = knowledge.best_counter_in_pool(block_def)
	assert_true(best is Dictionary, "Should return a card definition dictionary")
	assert_true(best.size() > 0, "Should find some counter in the pool")
