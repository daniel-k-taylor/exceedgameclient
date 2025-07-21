extends GutTest

# Leave at 1 checked in so someone doesn't accidentally run all tests at 100.
const RandomIterations = 1



var game_logic : LocalGame
var image_loader : CardImageLoader
var default_deck = CardDataManager.get_deck_from_str_id("solbadguy")
var opponent_deck = CardDataManager.get_deck_from_str_id("solbadguy")

var player1 : Player
var player2 : Player
var ai1 : AIPlayer
var ai2 : AIPlayer

func game_setup(policy_type = AIPolicyRules):
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
	ai2 = AIPlayer.new(game_logic, player2, policy_type.new())

func game_teardown():
	# TODO: Move this logic into the real game so that it doesn't memory leak
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

func before_each():
	gut.p("ran setup", 2)

func after_each():
	if is_instance_valid(game_logic):
		game_teardown()
	gut.p("ran teardown", 2)

func before_all():
	gut.p("ran run setup", 2)

func after_all():
	gut.p("ran run teardown", 2)


func do_and_validate_strike(player, card_id):
	assert_true(game_logic.can_do_strike(player), "Expected to be able to strike")
	assert_true(game_logic.do_strike(player, card_id, false, -1), "Do strike error")
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_Strike_Started, player, card_id)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_Strike_Opponent_Response, "Strike wrong state")

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
	if not do_prepare:
		# This is here just to help debug if this issue becomes more common.
		assert_true(do_prepare, "do prepare failed")
		do_prepare = game.do_prepare(gameplayer)
	assert_true(do_prepare, "do prepare failed")
	return game.get_latest_events()

func handle_move(game: LocalGame, gameplayer : Player, action : AIPlayer.MoveAction):
	var location = action.location
	var card_ids = action.force_card_ids
	var use_free_force = action.use_free_force
	var do_move = game.do_move(gameplayer, card_ids, location, use_free_force)
	if not do_move:
		# This is here just to help debug if this issue becomes more common.
		assert_true(do_move, "do move failed")
		do_move = game.do_move(gameplayer, card_ids, location, use_free_force)
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
				#TODO: Do something with EventType_RevealHand so AI can consume new info.
			Enums.DecisionType.DecisionType_ReadingNormal:
				var pick_action = decision_ai.pick_name_opponent_card(true)
				assert_true(game.do_boost_name_card_choice_effect(decision_player, pick_action.card_id), "do boost name failed")
				#TODO: Do something with EventType_RevealHand so AI can consume new info.
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
				var use_gauge_instead = game.decision_info.limitation == "gauge"
				var forceforarmor_action = decision_ai.pick_force_for_armor(use_gauge_instead)
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
				if not result:
					# Handy for debugging.
					breakpoint
					gauge_action = decision_ai.pick_gauge_for_effect(options, required_card_id)
					result = game.do_gauge_for_effect(decision_ai.game_player, gauge_action.card_ids)
				assert_true(result, "do gauge effect failed")
			Enums.DecisionType.DecisionType_ChooseFromBoosts:
				var chooseaction = decision_ai.pick_choose_from_boosts(game.decision_info.amount)
				assert_true(game.do_choose_from_boosts(decision_ai.game_player, chooseaction.card_ids), "do choose from boosts failed")
			Enums.DecisionType.DecisionType_ChooseFromDiscard:
				var chooseaction = decision_ai.pick_choose_from_discard(game.decision_info.amount)
				var success = game.do_choose_from_discard(decision_ai.game_player, chooseaction.card_ids)
				assert(success)
				assert_true(success, "do choose from discard failed")
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
				var action_choices = decision_info.action
				var look_amount = decision_info.amount
				var can_pass = decision_info.can_pass
				var decision_action = decision_ai.pick_choose_from_topdeck(action_choices, look_amount, can_pass)
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
		var card_id = action.card_id
		var ex_card_id = action.ex_card_id
		var wild_swing = action.wild_swing

		var success = game.do_strike(gameplayer, card_id, wild_swing, ex_card_id)
		assert_true(success, "do strike failed")
		assert(success, "Strike failed")
		events += game.get_latest_events()

	if game.game_state == Enums.GameState.GameState_Strike_Opponent_Response:
		var response_action = otherai.pick_strike_response()
		var success = game.do_strike(otherplayer, response_action.card_id, response_action.wild_swing, response_action.ex_card_id)
		assert_true(success, "do strike resp failed")
		assert(success, "Strike response failed")
		# Could have critical decision here.
		events += handle_decisions(game)


	if game.game_state == Enums.GameState.GameState_WaitForStrike and opponent_sets_first:
		var card_id = action.card_id
		var ex_card_id = action.ex_card_id
		var wild_swing = action.wild_swing

		assert_true(game.do_strike(gameplayer, card_id, wild_swing, ex_card_id, opponent_sets_first), "do strike failed")
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

func run_ai_game():
	var events = []

	var mulligan_action = ai1.pick_mulligan()
	assert_true(game_logic.do_mulligan(player1, mulligan_action.card_ids), "mull failed")
	events += game_logic.get_latest_events()
	mulligan_action = ai2.pick_mulligan()
	assert_true(game_logic.do_mulligan(player2, mulligan_action.card_ids), "mull 2 failed")
	events += game_logic.get_latest_events()

	while not game_logic.game_over:
		var current_ai = ai1
		var other_ai = ai2
		var current_player = game_logic._get_player(game_logic.active_turn_player)
		if game_logic.active_turn_player == player2.my_id:
			current_ai = ai2
			other_ai = ai1

		var turn_events = []
		turn_events += handle_decisions(game_logic) #Handles overdrives

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
			# Can theoretically get here after a boost or an exceed.
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
			turn_events += handle_decisions(game_logic) #Handles end of turn

		events += turn_events

	assert_true(events.size() > 0, "no events")
	return events

### Actual tests

func test_random_ai_players():
	game_setup(AIPolicyRandom)
	var events = run_ai_game()

	print("!!! GAME OVER !!!")
	for event in events:
		print(event)
	pass_test("Finished match")
	game_teardown()

func run_iterations_with_deck(deck_id : String):
	default_deck = CardDataManager.get_deck_from_str_id(deck_id)
	for i in range(RandomIterations):
		opponent_deck = CardDataManager.get_deck_from_str_id(
				"random" if i > 0 else deck_id)
		game_setup()
		print("==== RUNNING TEST %d vs %s ====" % [i + 1, opponent_deck['id']])
		run_ai_game()
		game_teardown()
	pass_test("Finished match")

func test_sol_100():
	run_iterations_with_deck("solbadguy")

func test_ky_100():
	run_iterations_with_deck("kykisuke")

func test_ram_100():
	run_iterations_with_deck("ramlethal")

func test_anji_100():
	run_iterations_with_deck("anji")

func test_pot_100():
	run_iterations_with_deck("potemkin")

func test_may_100():
	run_iterations_with_deck("may")

func test_millia_100():
	run_iterations_with_deck("millia")

func test_baiken_100():
	run_iterations_with_deck("baiken")

func test_giovanna_100():
	run_iterations_with_deck("giovanna")

func test_nago_100():
	run_iterations_with_deck("nago")

func test_goldlewis_100():
	run_iterations_with_deck("goldlewis")

func test_ino_100():
	run_iterations_with_deck("ino")

func test_chipp_100():
	run_iterations_with_deck("chipp")

func test_jacko_100():
	run_iterations_with_deck("jacko")

func test_leo_100():
	run_iterations_with_deck("leo")

func test_testament_100():
	run_iterations_with_deck("testament")

func test_axl_100():
	run_iterations_with_deck("axl")

func test_zato_100():
	run_iterations_with_deck("zato")

func test_faust_100():
	run_iterations_with_deck("faust")

func test_happychaos_100():
	run_iterations_with_deck("happychaos")

func test_arakune_100():
	run_iterations_with_deck("arakune")

func test_bang_100():
	run_iterations_with_deck("bang")

func test_carlclover_100():
	run_iterations_with_deck("carlclover")

func test_hakumen_100():
	run_iterations_with_deck("hakumen")

func test_jin_100():
	run_iterations_with_deck("jin")

func test_kokonoe_100():
	run_iterations_with_deck("kokonoe")

func test_platinum_100():
	run_iterations_with_deck("platinum")

func test_ragna_100():
	run_iterations_with_deck("ragna")

func test_noel_100():
	run_iterations_with_deck("noel")

func test_hazama_100():
	run_iterations_with_deck("hazama")

func test_nu13_100():
	run_iterations_with_deck("nu13")

func test_litchi_100():
	run_iterations_with_deck("litchi")

func test_tager_100():
	run_iterations_with_deck("tager")

func test_taokaka_100():
	run_iterations_with_deck("taokaka")

func test_yuzu_100():
	run_iterations_with_deck("yuzu")

func test_hilda_100():
	run_iterations_with_deck("hilda")

func test_hyde_100():
	run_iterations_with_deck("hyde")

func test_linne_100():
	run_iterations_with_deck("linne")

func test_nanase_100():
	run_iterations_with_deck("nanase")

func test_phonon_100():
	run_iterations_with_deck("phonon")

func test_akuma_100():
	run_iterations_with_deck("akuma")

func test_ryu_100():
	run_iterations_with_deck("ryu")

func test_sagat_100():
	run_iterations_with_deck("sagat")

func test_guile_100():
	run_iterations_with_deck("guile")

func test_ken_100():
	run_iterations_with_deck("ken")

func test_zangief_100():
	run_iterations_with_deck("zangief")

func test_shovelshield_100():
	run_iterations_with_deck("shovelshield")

func test_plague_100():
	run_iterations_with_deck("plague")

func test_nine_100():
	run_iterations_with_deck("nine")

func test_rachel_100():
	run_iterations_with_deck("rachel")

func test_specter_100():
	run_iterations_with_deck("specter")

func test_mika_100():
	run_iterations_with_deck("mika")

func test_chaos_100():
	run_iterations_with_deck("chaos")

func test_polar_100():
	run_iterations_with_deck("polar")

func test_tinker_100():
	run_iterations_with_deck("tinker")

func test_cviper_100():
	run_iterations_with_deck("cviper")

func test_propeller_100():
	run_iterations_with_deck("propeller")

func test_mole_100():
	run_iterations_with_deck("mole")

func test_seth_100():
	run_iterations_with_deck("seth")

func test_enkidu_100():
	run_iterations_with_deck("enkidu")

func test_dan_100():
	run_iterations_with_deck("dan")

func test_bison_100():
	run_iterations_with_deck("bison")

func test_cammy_100():
	run_iterations_with_deck("cammy")

func test_chunli_100():
	run_iterations_with_deck("chunli")

func test_vega_100():
	run_iterations_with_deck("vega")

func test_londrekia_100():
	run_iterations_with_deck("londrekia")

func test_orie_100():
	run_iterations_with_deck("orie")

func test_waldstein_100():
	run_iterations_with_deck("waldstein")

func test_wagner_100():
	run_iterations_with_deck("wagner")

func test_vatista_100():
	run_iterations_with_deck("vatista")

func test_king_100():
	run_iterations_with_deck("king")

func test_treasure_100():
	run_iterations_with_deck("treasure")

func test_enchantress_100():
	run_iterations_with_deck("enchantress")

func test_gordeau_100():
	run_iterations_with_deck("gordeau")

func test_beheaded_100():
	run_iterations_with_deck("beheaded")

func test_fight_100():
	run_iterations_with_deck("fight")

func test_byakuya_100():
	run_iterations_with_deck("byakuya")

func test_merkava_100():
	run_iterations_with_deck("merkava")

func test_carmine_100():
	run_iterations_with_deck("carmine")

func test_seijun_100():
	run_iterations_with_deck("seijun")

func test_carlswangee_100():
	run_iterations_with_deck("carlswangee")

func test_galdred_100():
	run_iterations_with_deck("galdred")

func test_sydney_100():
	run_iterations_with_deck("sydney")

func test_celinka_100():
	run_iterations_with_deck("celinka")

func test_iaquis_100():
	run_iterations_with_deck("iaquis")

func test_emogine_100():
	run_iterations_with_deck("emogine")

func test_morathi_100():
	run_iterations_with_deck("morathi")

func test_nehtali_100():
	run_iterations_with_deck("nehtali")

func test_remiliss_100():
	run_iterations_with_deck("remiliss")

func test_vincent_100():
	run_iterations_with_deck("vincent")

func test_djanette_100():
	run_iterations_with_deck("djanette")

func test_superskullman_100():
	run_iterations_with_deck("superskullman")

func test_shovelknight_100():
	run_iterations_with_deck("shovelknight")
