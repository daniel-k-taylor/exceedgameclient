extends GutTest

# Leave at 1 checked in so someone doesn't accidentally run all tests at 100.
const RandomIterations = 1

const LocalGame = preload("res://scenes/game/local_game.gd")
const GameCard = preload("res://scenes/game/game_card.gd")
const Enums = preload("res://scenes/game/enums.gd")
const AIPlayer = preload("res://scenes/game/ai_player.gd")
const AIPolicyRandom = preload("res://scenes/game/ai/ai_policy_random.gd")
const AIPolicyRules = preload("res://scenes/game/ai/ai_policy_rules.gd")

var game_logic : LocalGame
var default_deck = CardDefinitions.get_deck_from_str_id("solbadguy")

var player1 : LocalGame.Player
var player2 : LocalGame.Player
var ai1 : AIPlayer
var ai2 : AIPlayer
var ai_policy

func game_setup(policy = AIPolicyRules.new()):
	ai_policy = policy
	game_logic = LocalGame.new()
	var seed_value = randi()
	game_logic.initialize_game(default_deck, default_deck, "p1", "p2", Enums.PlayerId.PlayerId_Player, seed_value)
	game_logic.draw_starting_hands_and_begin()
	game_logic.get_latest_events()
	player1 = game_logic.player
	player2 = game_logic.opponent
	ai1 = AIPlayer.new()
	ai1.ai_policy.free()
	ai1.set_ai_policy(ai_policy)
	ai1.game_player = player1
	ai2 = AIPlayer.new()
	ai2.ai_policy.free()
	ai2.set_ai_policy(ai_policy)
	ai2.game_player = player2

func game_teardown():
	game_logic.teardown()
	game_logic.free()
	ai_policy.free()
	ai1.free()
	ai2.free()

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
	game_setup()

	gut.p("ran setup", 2)

func after_each():
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

func handle_discard_event(events, game : LocalGame, aiplayer : AIPlayer, gameplayer : LocalGame.Player):
	if game.game_state == Enums.GameState.GameState_DiscardDownToMax:
		var event = get_event(events, Enums.EventType.EventType_HandSizeExceeded)
		var discard_required_count = event['number']
		var discard_action = aiplayer.pick_discard_to_max(game, gameplayer.my_id, discard_required_count)
		assert_true(game.do_discard_to_max(gameplayer, discard_action.card_ids), "do discard failed")
		events += game.get_latest_events()

func handle_prepare(game : LocalGame, gameplayer : LocalGame.Player):
	assert_true(game.do_prepare(gameplayer), "do prepare failed")
	return game.get_latest_events()

func handle_move(game: LocalGame, gameplayer : LocalGame.Player, action : AIPlayer.MoveAction):
	var location = action.location
	var card_ids = action.force_card_ids
	var use_free_force = action.use_free_force
	assert_true(game.do_move(gameplayer, card_ids, location, use_free_force), "do move failed")
	return game.get_latest_events()

func handle_change_cards(game: LocalGame, gameplayer : LocalGame.Player, action : AIPlayer.ChangeCardsAction):
	var card_ids = action.card_ids
	var use_free_force = action.use_free_force
	assert_true(game.do_change(gameplayer, card_ids, false, use_free_force), "do change failed")
	return game.get_latest_events()

func handle_exceed(game: LocalGame, otherai, gameplayer : LocalGame.Player, action : AIPlayer.ExceedAction):
	var card_ids = action.card_ids
	var events = []
	assert_true(game.do_exceed(gameplayer, card_ids), "do exceed failed")
	events += game.get_latest_events()

	if game.game_state == Enums.GameState.GameState_Strike_Opponent_Response:
		var otherplayer = otherai.game_player
		var response_action = otherai.pick_strike_response(game, otherplayer.my_id)
		assert_true(game.do_strike(otherplayer, response_action.card_id, response_action.wild_swing, response_action.ex_card_id), "do strike resp failed")

	events += handle_decisions(game)
	return events

func handle_reshuffle(game: LocalGame, gameplayer : LocalGame.Player):
	assert_true(game.do_reshuffle(gameplayer), "do reshuffle failed")
	return game.get_latest_events()

func handle_boost(game: LocalGame, aiplayer : AIPlayer, otherai : AIPlayer, gameplayer : LocalGame.Player, action : AIPlayer.BoostAction):
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
				var cancel_action = decision_ai.pick_cancel(game, decision_player.my_id, 1)
				assert_true(game.do_boost_cancel(decision_player, cancel_action.card_ids, cancel_action.cancel), "do boost cancel failed")
			Enums.DecisionType.DecisionType_NameCard_OpponentDiscards:
				var pick_action = decision_ai.pick_name_opponent_card(game, decision_player.my_id, false)
				assert_true(game.do_boost_name_card_choice_effect(decision_player, pick_action.card_id), "do boost name failed")
				#TODO: Do something with EventType_RevealHand so AI can consume new info.
			Enums.DecisionType.DecisionType_ReadingNormal:
				var pick_action = decision_ai.pick_name_opponent_card(game, decision_player.my_id, true)
				assert_true(game.do_boost_name_card_choice_effect(decision_player, pick_action.card_id), "do boost name failed")
				#TODO: Do something with EventType_RevealHand so AI can consume new info.
			Enums.DecisionType.DecisionType_Sidestep:
				var pick_action = decision_ai.pick_name_opponent_card(game, decision_player.my_id, true)
				assert_true(game.do_boost_name_card_choice_effect(decision_player, pick_action.card_id), "do boost name failed")
			Enums.DecisionType.DecisionType_ZeroVector:
				var pick_action = decision_ai.pick_name_opponent_card(game, decision_player.my_id, false, game.decision_info.bonus_effect)
				assert_true(game.do_boost_name_card_choice_effect(decision_player, pick_action.card_id), "do boost name failed")
			Enums.DecisionType.DecisionType_PayStrikeCost_Required, Enums.DecisionType.DecisionType_PayStrikeCost_CanWild:
				var can_wild = game.decision_info.type == Enums.DecisionType.DecisionType_PayStrikeCost_CanWild
				var cost = game.decision_info.cost
				var is_gauge = game.decision_info.limitation == "gauge"
				var pay_action
				if is_gauge:
					pay_action = decision_ai.pay_strike_gauge_cost(game, decision_player.my_id, cost, can_wild)
				else:
					pay_action = decision_ai.pay_strike_force_cost(game, decision_player.my_id, cost, can_wild)
				assert_true(game.do_pay_strike_cost(decision_player, pay_action.card_ids, pay_action.wild_swing, true, pay_action.use_free_force), "do pay failed")
			Enums.DecisionType.DecisionType_EffectChoice, Enums.DecisionType.DecisionType_ChooseSimultaneousEffect:
				var effect_action = decision_ai.pick_effect_choice(game, decision_player.my_id)
				assert_true(game.do_choice(decision_ai.game_player, effect_action.choice), "do strike choice failed")
			Enums.DecisionType.DecisionType_ForceForArmor:
				var use_gauge_instead = game.decision_info.limitation == "gauge"
				var forceforarmor_action = decision_ai.pick_force_for_armor(game, decision_player.my_id, use_gauge_instead)
				assert_true(game.do_force_for_armor(decision_ai.game_player, forceforarmor_action.card_ids, forceforarmor_action.use_free_force), "do force armor failed")
			Enums.DecisionType.DecisionType_CardFromHandToGauge:
				var cardfromhandtogauge_action = decision_ai.pick_card_hand_to_gauge(game, decision_player.my_id, game.decision_info.effect['min_amount'], game.decision_info.effect['max_amount'])
				assert_true(game.do_card_from_hand_to_gauge(decision_ai.game_player, cardfromhandtogauge_action.card_ids), "do card hand strike failed")
			Enums.DecisionType.DecisionType_ForceForEffect:
				var effect = game.decision_info.effect
				var options = []
				if effect['per_force_effect'] != null:
					for i in range(effect['force_max'] + 1):
						options.append(i)
				else:
					options.append(0)
					options.append(effect['force_max'])
				var forceforeffect_action = decision_ai.pick_force_for_effect(game, decision_player.my_id, options)
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
				var gauge_action = decision_ai.pick_gauge_for_effect(game, decision_player.my_id, options, required_card_id)
				assert_true(game.do_gauge_for_effect(decision_ai.game_player, gauge_action.card_ids), "do gauge effect failed")
			Enums.DecisionType.DecisionType_ChooseFromBoosts:
				var chooseaction = decision_ai.pick_choose_from_boosts(game, decision_player.my_id, game.decision_info.amount)
				assert_true(game.do_choose_from_boosts(decision_ai.game_player, chooseaction.card_ids), "do choose from boosts failed")
			Enums.DecisionType.DecisionType_ChooseFromDiscard:
				var chooseaction = decision_ai.pick_choose_from_discard(game, decision_player.my_id, game.decision_info.amount)
				var success = game.do_choose_from_discard(decision_ai.game_player, chooseaction.card_ids)
				assert(success)
				assert_true(success, "do choose from discard failed")
			Enums.DecisionType.DecisionType_ChooseToDiscard:
				var chooseaction
				if game.decision_info.effect['effect_type'] == "choose_opponent_card_to_discard":
					var card_ids = game.decision_info.choice
					chooseaction = decision_ai.pick_choose_opponent_card_to_discard(game,  decision_player.my_id, card_ids)
				else:
					var amount = game.decision_info.effect['amount']
					var limitation = game.decision_info.limitation
					var can_pass = game.decision_info.can_pass
					var allow_fewer = 'allow_fewer' in game.decision_info.effect and game.decision_info.effect['allow_fewer']
					chooseaction = decision_ai.pick_choose_to_discard(game, decision_player.my_id, amount, limitation, can_pass, allow_fewer)
				assert_true(game.do_choose_to_discard(decision_ai.game_player, chooseaction.card_ids), "do choose to discard failed")
			Enums.DecisionType.DecisionType_ChooseDiscardOpponentGauge:
				var decision_action = decision_ai.pick_discard_opponent_gauge(game, decision_player.my_id)
				assert_true(game.do_boost_name_card_choice_effect(decision_player, decision_action.card_id), "do discard opponent gauge failed")
			Enums.DecisionType.DecisionType_BoostNow:
				var boostnow_action = decision_ai.take_boost(game, decision_player.my_id, game.decision_info.valid_zones, game.decision_info.limitation, game.decision_info.ignore_costs)
				assert_true(game.do_boost(decision_player, boostnow_action.card_id, boostnow_action.payment_card_ids, boostnow_action.use_free_force), "do boost now failed")
			Enums.DecisionType.DecisionType_ChooseFromTopDeck:
				var decision_info = game.decision_info
				var action_choices = decision_info.action
				var look_amount = decision_info.amount
				var can_pass = decision_info.can_pass
				var decision_action = decision_ai.pick_choose_from_topdeck(game, decision_player.my_id, action_choices, look_amount, can_pass)
				assert_true(game.do_choose_from_topdeck(decision_player, decision_action.card_id, decision_action.action), "do choose from topdeck failed")
			Enums.DecisionType.DecisionType_ChooseArenaLocationForEffect:
				var decision_info = game.decision_info
				var decision_action = decision_ai.pick_choose_arena_location_for_effect(game, decision_player.my_id, decision_info.limitation)
				var choice_index = 0
				for i in range(len(decision_info.limitation)):
					if decision_info.limitation[i] == decision_action.location:
						choice_index = i
						break
				assert_true(game.do_choice(decision_player, choice_index), "do arena location for effect failed")
			Enums.DecisionType.DecisionType_PickNumberFromRange:
				var decision_info = game.decision_info
				var decision_action = decision_ai.pick_number_from_range_for_effect(game, decision_player.my_id, decision_info.limitation, decision_info.choice)
				var choice_index = 0
				for i in range(len(decision_info.limitation)):
					if decision_info.limitation[i] == decision_action.number:
						choice_index = i
						break
				assert_true(game.do_choice(decision_player, choice_index), "do pick number from range failed")
			Enums.DecisionType.DecisionType_ChooseDiscardContinuousBoost:
				var limitation = game.decision_info.limitation
				var can_pass = game.decision_info.can_pass
				var choose_action = decision_ai.pick_discard_continuous(game, decision_player.my_id, limitation, can_pass)
				assert_true(game.do_boost_name_card_choice_effect(decision_player, choose_action.card_id), "do boost name strike s2 failed")
			_:
				assert(false, "Unimplemented decision type")

		if game.game_state == Enums.GameState.GameState_Strike_Opponent_Response:
			var defender_id = game.active_strike.defender.my_id
			var defender_ai = ai1
			if defender_id != ai1.game_player.my_id:
				defender_ai = ai2
			var response_action = defender_ai.pick_strike_response(game, defender_id)
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
		var response_action = otherai.pick_strike_response(game, otherplayer.my_id)
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

	var mulligan_action = ai1.pick_mulligan(game_logic, player1.my_id)
	assert_true(game_logic.do_mulligan(player1, mulligan_action.card_ids), "mull failed")
	events += game_logic.get_latest_events()
	mulligan_action = ai2.pick_mulligan(game_logic, player2.my_id)
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
			var turn_action = current_ai.take_turn(game_logic, current_player.my_id)
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
				strike_action = current_ai.pick_strike(game_logic, current_player.my_id, "gauge")
			elif current_player.next_strike_from_sealed:
				strike_action = current_ai.pick_strike(game_logic, current_player.my_id, "sealed")
			else:
				strike_action = current_ai.pick_strike(game_logic, current_player.my_id)
			turn_events += handle_strike(game_logic, current_ai, other_ai, strike_action)
		elif game_logic.game_state == Enums.GameState.GameState_Strike_Opponent_Set_First:
			var success = game_logic.do_strike(current_ai.game_player, -1, false, -1, true)
			assert(success)
			var strike_action = current_ai.pick_strike(game_logic, current_player.my_id)
			turn_events += handle_strike(game_logic, current_ai, other_ai, strike_action, false, true)

		if game_logic.active_strike:
			turn_events += handle_strike(game_logic, current_ai, other_ai, null, true)

		handle_discard_event(turn_events, game_logic, current_ai, current_player)
		if game_logic.active_end_of_turn_effects:
			turn_events += handle_decisions(game_logic) #Handles end of turn

		events += turn_events

	assert_true(events.size() > 0, "no events")
	return events

func test_random_ai_players():
	game_teardown()
	game_setup(AIPolicyRandom.new())
	var events = run_ai_game()

	print("!!! GAME OVER !!!")
	for event in events:
		print(event)
	pass_test("Finished match")

func run_iterations_with_deck(deck_id : String):
	default_deck = CardDefinitions.get_deck_from_str_id(deck_id)
	game_teardown()
	game_setup()
	for i in range(RandomIterations):
		print("==== RUNNING TEST %d ====" % i)
		run_ai_game()
		game_teardown()
		game_setup()
	pass_test("Finished match")

func test_sol_100():
	for i in range(RandomIterations):
		print("==== RUNNING TEST %d ====" % i)
		run_ai_game()
		game_teardown()
		game_setup()
	pass_test("Finished match")

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
