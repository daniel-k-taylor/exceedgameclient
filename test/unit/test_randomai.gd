extends GutTest

const LocalGame = preload("res://scenes/game/local_game.gd")
const GameCard = preload("res://scenes/game/game_card.gd")
const Enums = preload("res://scenes/game/enums.gd")
const AIPlayer = preload("res://scenes/game/ai_player.gd")

var game_logic : LocalGame
var default_deck = CardDefinitions.get_deck_from_selector_index(0)

var player1 : LocalGame.Player
var player2 : LocalGame.Player
var ai1 : AIPlayer
var ai2 : AIPlayer

func default_game_setup():
	game_logic = LocalGame.new()
	game_logic.initialize_game(default_deck, default_deck)
	game_logic.draw_starting_hands_and_begin()
	game_logic.get_latest_events()
	player1 = game_logic.player
	player2 = game_logic.opponent
	ai1 = AIPlayer.new()
	ai1.game_player = player1
	ai2 = AIPlayer.new()
	ai2.game_player = player2

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
	default_game_setup()

	gut.p("ran setup", 2)

func after_each():
	game_logic.teardown()
	game_logic.free()
	ai1.ai_policy.free()
	ai1.free()
	ai2.ai_policy.free()
	ai2.free()
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
	assert_true(game.do_move(gameplayer, card_ids, location), "do move failed")
	return game.get_latest_events()

func handle_change_cards(game: LocalGame, gameplayer : LocalGame.Player, action : AIPlayer.ChangeCardsAction):
	var card_ids = action.card_ids
	assert_true(game.do_change(gameplayer, card_ids), "do change failed")
	return game.get_latest_events()

func handle_exceed(game: LocalGame, gameplayer : LocalGame.Player, action : AIPlayer.ExceedAction):
	var card_ids = action.card_ids
	assert_true(game.do_exceed(gameplayer, card_ids), "do exceed failed")
	return game.get_latest_events()

func handle_reshuffle(game: LocalGame, gameplayer : LocalGame.Player):
	assert_true(game.do_reshuffle(gameplayer), "do reshuffle failed")
	return game.get_latest_events()

func handle_boost_reponse(events, aiplayer : AIPlayer, game : LocalGame, gameplayer : LocalGame.Player, otherplayer : LocalGame.Player, choice_index):
	while game.game_state == Enums.GameState.GameState_PlayerDecision:
		if game.decision_info.type == Enums.DecisionType.DecisionType_EffectChoice:
			assert_true(game.do_choice(gameplayer, choice_index), "do choice failed")
			events += game.get_latest_events()
		elif game.decision_info.type == Enums.DecisionType.DecisionType_CardFromHandToGauge:
			assert_true(game.do_card_from_hand_to_gauge(gameplayer, gameplayer.hand[choice_index].id), "do card gauge failed")
			events += game.get_latest_events()
		elif game.decision_info.type == Enums.DecisionType.DecisionType_NameCard_OpponentDiscards:
			var index = choice_index * 2
			var card_id = otherplayer.deck_list[index].id
			assert_true(game.do_boost_name_card_choice_effect(gameplayer, card_id), "do boost name failed")
			events += game.get_latest_events()
			#TODO: Do something with EventType_RevealHand so AI can consume new info.
		elif game.decision_info.type == Enums.DecisionType.DecisionType_ChooseDiscardContinuousBoost:
			var card_id = otherplayer.continuous_boosts[choice_index].id
			assert_true(game.do_boost_name_card_choice_effect(gameplayer, card_id), "do boost name 2 failed")
			events += game.get_latest_events()
		elif game.decision_info.type == Enums.DecisionType.DecisionType_BoostCancel:
			var event = get_event(events, Enums.EventType.EventType_Boost_CancelDecision)
			var cost = event['number']
			var cancel_action = aiplayer.pick_cancel(game, gameplayer.my_id, cost)
			assert_true(game.do_boost_cancel(gameplayer, cancel_action.card_ids, cancel_action.cancel), "do boost cancel failed")
			events += game.get_latest_events()

	return events

func handle_boost(game: LocalGame, aiplayer : AIPlayer, gameplayer : LocalGame.Player, otherplayer : LocalGame.Player, action : AIPlayer.BoostAction):
	var events = []
	var card_id = action.card_id
	var boost_choice_index = action.boost_choice_index
	assert_true(game.do_boost(gameplayer, card_id), "do boost failed")
	events += game.get_latest_events()
	events = handle_boost_reponse(events, aiplayer, game, gameplayer, otherplayer, boost_choice_index)
	return events

func handle_strike(game: LocalGame, aiplayer : AIPlayer, otherai : AIPlayer, action : AIPlayer.StrikeAction):
	var events = []
	var card_id = action.card_id
	var ex_card_id = action.ex_card_id
	var wild_swing = action.wild_swing

	var gameplayer = aiplayer.game_player
	var otherplayer = otherai.game_player

	assert_true(game.do_strike(gameplayer, card_id, wild_swing, ex_card_id), "do strike failed")
	events += game.get_latest_events()
	if game.game_state == Enums.GameState.GameState_Strike_Opponent_Response:
		var response_action = otherai.pick_strike_response(game, otherplayer.my_id)
		assert_true(game.do_strike(otherplayer, response_action.card_id, response_action.wild_swing, response_action.ex_card_id), "do strike resp failed")
		events += game.get_latest_events()

	# Pay costs
	while game.game_state == Enums.GameState.GameState_PlayerDecision:
		var decision_ai = aiplayer
		var decision_player = game._get_player(game.decision_info.player)
		if decision_player == otherplayer:
			decision_ai = otherai
		match game.decision_info.type:
			Enums.DecisionType.DecisionType_PayStrikeCost_Required, Enums.DecisionType.DecisionType_PayStrikeCost_CanWild:
				var can_wild = game.decision_info.type == Enums.DecisionType.DecisionType_PayStrikeCost_CanWild
				var card = game.active_strike.get_player_card(decision_player)
				var cost = game.card_db.get_card_gauge_cost(card.id)
				var pay_action = decision_ai.pay_strike_gauge_cost(game, decision_player.my_id, cost, can_wild)
				assert_true(game.do_pay_strike_cost(decision_player, pay_action.card_ids, pay_action.wild_swing), "do pay failed")
				events += game.get_latest_events()
			Enums.DecisionType.DecisionType_EffectChoice:
				var effect_action = decision_ai.pick_effect_choice(game, decision_player.my_id)
				assert_true(game.do_choice(decision_ai.game_player, effect_action.choice), "do strike choice failed")
				events += game.get_latest_events()
			Enums.DecisionType.DecisionType_ForceForArmor:
				var forceforarmor_action = decision_ai.pick_force_for_armor(game, decision_player.my_id)
				assert_true(game.do_force_for_armor(decision_ai.game_player, forceforarmor_action.card_ids), "do force armor failed")
				events += game.get_latest_events()
			Enums.DecisionType.DecisionType_CardFromHandToGauge:
				var cardfromhandtogauge_action = decision_ai.pick_card_hand_to_gauge(game, decision_player.my_id)
				assert_true(game.do_card_from_hand_to_gauge(decision_ai.game_player, cardfromhandtogauge_action.card_id), "do card hand strike failed")
				events += game.get_latest_events()

	assert_true(game.game_state == Enums.GameState.GameState_PickAction or game.game_state == Enums.GameState.GameState_GameOver, "Unexpected game state %s" % str(game.game_state))

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
		var other_player = game_logic._get_player(game_logic.get_other_player(game_logic.active_turn_player))
		if game_logic.active_turn_player == player2.my_id:
			current_ai = ai2
			other_ai = ai1

		var turn_events = []
		var turn_action = current_ai.take_turn(game_logic, current_player.my_id)
		if turn_action is AIPlayer.PrepareAction:
			turn_events += handle_prepare(game_logic, current_player)
		elif turn_action is AIPlayer.MoveAction:
			turn_events += handle_move(game_logic, current_player, turn_action)
		elif turn_action is AIPlayer.ChangeCardsAction:
			turn_events += handle_change_cards(game_logic, current_player, turn_action)
		elif turn_action is AIPlayer.ExceedAction:
			turn_events += handle_exceed(game_logic, current_player, turn_action)
		elif turn_action is AIPlayer.ReshuffleAction:
			turn_events += handle_reshuffle(game_logic, current_player)
		elif turn_action is AIPlayer.BoostAction:
			turn_events += handle_boost(game_logic, current_ai, current_player, other_player, turn_action)
		elif turn_action is AIPlayer.StrikeAction:
			turn_events += handle_strike(game_logic, current_ai, other_ai, turn_action)
		else:
			fail_test("Unknown turn action: %s" % turn_action)
			assert(false, "Unknown turn action: %s" % turn_action)

		if game_logic.game_state == Enums.GameState.GameState_WaitForStrike:
			# Can theoretically get here after a boost or an exceed.
			var strike_action = current_ai.pick_strike(game_logic, current_player.my_id)
			turn_events += handle_strike(game_logic, current_ai, other_ai, strike_action)

		handle_discard_event(turn_events, game_logic, current_ai, current_player)

		events += turn_events

	assert_true(events.size() > 0, "no events")
	return events

func test_random_ai_players():
	var events = run_ai_game()

	print("!!! GAME OVER !!!")
	for event in events:
		print(event)
	pass_test("Finished match")

func test_random_ai_100():
	for i in range(100):
		print("==== RUNNING TEST %d ====" % i)
		run_ai_game()
		after_each()
		before_each()


	pass_test("Finished match")
