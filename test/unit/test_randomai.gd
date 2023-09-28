extends GutTest

const GameLogic = preload("res://scenes/game/gamelogic.gd")
const AIPlayer = preload("res://scenes/game/ai_player.gd")

var game_logic : GameLogic
var default_deck = CardDefinitions.decks[0]

var player1 : GameLogic.Player
var player2 : GameLogic.Player
var ai1 : AIPlayer
var ai2 : AIPlayer

func default_game_setup():
	game_logic = GameLogic.new()
	game_logic.initialize_game(default_deck, default_deck)
	game_logic.draw_starting_hands_and_begin()
	player1 = game_logic.player
	player2 = game_logic.opponent
	ai1 = AIPlayer.new()
	ai1.game_player = player1
	ai2 = AIPlayer.new()
	ai2.game_player = player2

func validate_has_event(events, event_type, event_player, number = null):
	for event in events:
		if event['event_type'] == event_type:
			assert_eq(event['event_player'], event_player)
			if number != null:
				assert_eq(event['number'], number)
			return
	fail_test("Event not found: %s" % event_type)

func before_each():
	default_game_setup()

	gut.p("ran setup", 2)

func after_each():
	game_logic.free()
	ai1.free()
	ai2.free()
	gut.p("ran teardown", 2)

func before_all():
	gut.p("ran run setup", 2)

func after_all():
	gut.p("ran run teardown", 2)


func do_and_validate_strike(player, card_id):
	assert_true(game_logic.can_do_strike(player))
	var events = game_logic.do_strike(player, card_id, false, -1)
	validate_has_event(events, game_logic.EventType.EventType_Strike_Started, player, card_id)
	assert_eq(game_logic.game_state, game_logic.GameState.GameState_Strike_Opponent_Response)


func get_event(events, event_type):
	for event in events:
		if event['event_type'] == event_type:
			return event
	fail_test("Event not found: %s" % event_type)

func handle_discard_event(events, game : GameLogic, aiplayer : AIPlayer, gameplayer : GameLogic.Player, otherplayer : GameLogic.Player):
	if game.game_state == GameLogic.GameState.GameState_DiscardDownToMax:
		var event = get_event(events, GameLogic.EventType.EventType_HandSizeExceeded)
		var discard_required_count = event['number']
		var discard_action = aiplayer.pick_discard_to_max(game, gameplayer, otherplayer, discard_required_count)
		events += game.do_discard_to_max(gameplayer, discard_action.card_ids)

func handle_prepare(game : GameLogic, gameplayer : GameLogic.Player):
	var events = game.do_prepare(gameplayer)
	return events

func handle_move(game: GameLogic, gameplayer : GameLogic.Player, action : AIPlayer.MoveAction):
	var events = []
	var location = action.location
	var card_ids = action.force_card_ids
	events += game.do_move(gameplayer, card_ids, location)
	return events

func handle_change_cards(game: GameLogic, gameplayer : GameLogic.Player, action : AIPlayer.ChangeCardsAction):
	var events = []
	var card_ids = action.card_ids
	events += game.do_change(gameplayer, card_ids)
	return events

func handle_exceed(game: GameLogic, gameplayer : GameLogic.Player, action : AIPlayer.ExceedAction):
	var events = []
	var card_ids = action.card_ids
	events += game.do_exceed(gameplayer, card_ids)
	return events

func handle_reshuffle(game: GameLogic, gameplayer : GameLogic.Player):
	var events = []
	events += game.do_reshuffle(gameplayer)
	return events

func handle_boost_reponse(_events, aiplayer : AIPlayer, game : GameLogic, gameplayer : GameLogic.Player, otherplayer : GameLogic.Player, choice_index):
	while game.game_state == GameLogic.GameState.GameState_PlayerDecision:
		if game.decision_type == GameLogic.DecisionType.DecisionType_EffectChoice:
			_events += game.do_choice(gameplayer, choice_index)
		elif game.decision_type == GameLogic.DecisionType.DecisionType_CardFromHandToGauge:
			_events += game.do_card_from_hand_to_gauge(gameplayer, gameplayer.hand[choice_index].id)
		elif game.decision_type == GameLogic.DecisionType.DecisionType_NameCard_OpponentDiscards:
			var index = choice_index * 2
			var card_id = otherplayer.deck_copy[index].id
			_events += game.do_boost_name_card_choice_effect(gameplayer, card_id)
			#TODO: Do something with EventType_RevealHand so AI can consume new info.
		elif game.decision_type == GameLogic.DecisionType.DecisionType_ChooseDiscardContinuousBoost:
			var card_id = otherplayer.continuous_boosts[choice_index].id
			_events += game.do_boost_name_card_choice_effect(gameplayer, card_id)
		elif game.decision_type == GameLogic.DecisionType.DecisionType_BoostCancel:
			var event = get_event(_events, GameLogic.EventType.EventType_Boost_CancelDecision)
			var cost = event['number']
			var cancel_action = aiplayer.pick_cancel(game, gameplayer, otherplayer, cost)
			_events += game.do_boost_cancel(gameplayer, cancel_action.card_ids, cancel_action.cancel)


func handle_boost(game: GameLogic, aiplayer : AIPlayer, gameplayer : GameLogic.Player, otherplayer : GameLogic.Player, action : AIPlayer.BoostAction):
	var events = []
	var card_id = action.card_id
	var boost_choice_index = action.boost_choice_index
	events += game.do_boost(gameplayer, card_id)
	handle_boost_reponse(events, aiplayer, game, gameplayer, otherplayer, boost_choice_index)
	return events

func handle_strike(game: GameLogic, aiplayer : AIPlayer, otherai : AIPlayer, action : AIPlayer.StrikeAction):
	var events = []
	var card_id = action.card_id
	var ex_card_id = action.ex_card_id
	var wild_swing = action.wild_swing

	var gameplayer = aiplayer.game_player
	var otherplayer = otherai.game_player

	events += game.do_strike(gameplayer, card_id, wild_swing, ex_card_id)
	if game.game_state == GameLogic.GameState.GameState_Strike_Opponent_Response:
		var response_action = otherai.pick_strike_response(game, otherplayer, gameplayer)
		events += game.do_strike(otherplayer, response_action.card_id, response_action.wild_swing, response_action.ex_card_id)

	# Pay costs
	while game.game_state == GameLogic.GameState.GameState_PlayerDecision:
		var decision_ai = aiplayer
		if game.decision_player == otherplayer:
			decision_ai = otherai
		match game.decision_type:
			GameLogic.DecisionType.DecisionType_PayStrikeCost_Required, GameLogic.DecisionType.DecisionType_PayStrikeCost_CanWild:
				var can_wild = game.decision_type == GameLogic.DecisionType.DecisionType_PayStrikeCost_CanWild
				var card = game.active_strike.get_player_card(game.decision_player)
				var cost = game.get_card_gauge_cost(card)
				var pay_action = decision_ai.pay_strike_gauge_cost(game, game.decision_player, game.other_player(game.decision_player), cost, can_wild)
				events += game.do_pay_strike_cost(game.decision_player, pay_action.card_ids, pay_action.wild_swing)
			GameLogic.DecisionType.DecisionType_EffectChoice:
				var effect_action = decision_ai.pick_effect_choice(game, game.decision_player, game.other_player(game.decision_player))
				events += game.do_choice(decision_ai.game_player, effect_action.choice)
			GameLogic.DecisionType.DecisionType_ForceForArmor:
				var forceforarmor_action = decision_ai.pick_force_for_armor(game, game.decision_player, game.other_player(game.decision_player))
				events += game.do_force_for_armor(decision_ai.game_player, forceforarmor_action.card_ids)
			GameLogic.DecisionType.DecisionType_CardFromHandToGauge:
				var cardfromhandtogauge_action = decision_ai.pick_card_hand_to_gauge(game, game.decision_player, game.other_player(game.decision_player))
				events += game.do_card_from_hand_to_gauge(decision_ai.game_player, cardfromhandtogauge_action.card_index)

	assert_eq(game.game_state, GameLogic.GameState.GameState_PickAction)

	return events

func test_random_ai_players():
	var events = []

	var mulligan_action = ai1.pick_mulligan(game_logic, player1, player2)
	events += game_logic.do_mulligan(player1, mulligan_action.card_ids)
	mulligan_action = ai2.pick_mulligan(game_logic, player2, player1)
	events += game_logic.do_mulligan(player2, mulligan_action.card_ids)

	while not game_logic.game_over:
		var current_ai = ai1
		var other_ai = ai2
		var current_player = game_logic.active_turn_player
		var other_player = game_logic.other_player(game_logic.active_turn_player)
		if game_logic.active_turn_player == player2:
			current_ai = ai2
			other_ai = ai1

		var turn_events = []
		var turn_action = current_ai.take_turn(game_logic, current_player, other_player)
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

		if game_logic.game_state == GameLogic.GameState.GameState_WaitForStrike:
			# Can theoretically get here after a boost or an exceed.
			var strike_action = current_ai.pick_strike(game_logic, current_player, other_player)
			turn_events += handle_strike(game_logic, current_ai, other_ai, strike_action)

		handle_discard_event(turn_events, game_logic, current_ai, current_player, other_player)

		events += turn_events

	print("!!! GAME OVER !!!")
	for event in events:
		print(event)
	pass_test("Finished match")
