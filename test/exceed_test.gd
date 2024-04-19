class_name ExceedGutTest
extends GutTest

var game_logic : LocalGame
var next_test_card_id = 50000

var player1 : LocalGame.Player
var player2 : LocalGame.Player

### !!! IMPORTANT
# Subclasses must override this function to return a character name
func who_am_i():
	return "override-who_am_i()-with-a-character-name-pls"

func next_id():
	next_test_card_id += 1
	return next_test_card_id - 1

func default_game_setup(alt_opponent : String = ""):
	var default_deck = CardDefinitions.get_deck_from_str_id(who_am_i())
	var opponent_deck = default_deck
	if alt_opponent:
		opponent_deck = CardDefinitions.get_deck_from_str_id(alt_opponent)
	game_logic = LocalGame.new()
	var seed_value = randi()
	game_logic.initialize_game(default_deck, opponent_deck, "p1", "p2",
			Enums.PlayerId.PlayerId_Player, seed_value)
	game_logic.draw_starting_hands_and_begin()
	game_logic.do_mulligan(game_logic.player, [])
	game_logic.do_mulligan(game_logic.opponent, [])
	player1 = game_logic.player
	player2 = game_logic.opponent
	game_logic.get_latest_events()  # just to clear the event queue

func give_player_specific_card(player, def_id):
	var card_def = CardDefinitions.get_card(def_id)
	var card_id = next_id()
	var card = GameCard.new(card_id, card_def, "image", player.my_id)
	var card_db = game_logic.get_card_database()
	card_db._test_insert_card(card)
	player.hand.append(card)
	return card_id

func give_specific_cards(p1, id1, p2, id2):
	var test_ids = []
	if p1 and id1:
		test_ids.append(give_player_specific_card(p1, id1))
	if p2 and id2:
		test_ids.append(give_player_specific_card(p2, id2))
	return test_ids

func position_players(p1, loc1, p2, loc2):
	p1.arena_location = loc1
	p2.arena_location = loc2

func give_gauge(player, amount):
	var card_ids = []
	for i in range(amount):
		player.add_to_gauge(player.deck[0])
		card_ids.append(player.deck[0].id)
		player.deck.remove_at(0)
	return card_ids

func validate_has_event(events, event_type, target_player, number = null):
	for event in events:
		if event['event_type'] == event_type:
			if event['event_player'] == target_player.my_id:
				if number == null or event['number'] == number:
					pass_test("Found event %s" % event_type)
					return
	fail_test("Event not found: %s" % event_type)

func validate_not_has_event(events, event_type, target_player, number = null):
	for event in events:
		if event['event_type'] == event_type:
			if event['event_player'] == target_player.my_id:
				if number == null or event['number'] == number:
					fail_test("Event found: %s" % event_type)
					return

func before_each():
	default_game_setup()

	gut.p("ran setup", 2)

func after_each():
	game_logic.teardown()
	game_logic.free()
	gut.p("ran teardown", 2)

func before_all():
	gut.p("ran run setup", 2)

func after_all():
	gut.p("ran run teardown", 2)

func do_and_validate_strike(player, card_id, ex_card_id = -1):
	assert_true(game_logic.can_do_strike(player),
			"Player %s is unable to perform a strike" % player)
	if card_id != -1:
		assert_true(game_logic.do_strike(player, card_id, false, ex_card_id),
				"Unsuccessful attempt to initiate strike with %s%s" % [
						"EX " if ex_card_id >= 0 else "",
						game_logic.get_card_database().get_card_name(card_id)])
	else:
		var ws_card_id = player.deck[0].id
		assert_true(game_logic.do_strike(player, card_id, true, ex_card_id),
				"Unsuccessful attempt to initiate with wild swing (%s)" % [
						game_logic.get_card_database().get_card_name(ws_card_id)])
		card_id = ws_card_id

	if game_logic.game_state == Enums.GameState.GameState_Strike_Opponent_Response or \
			game_logic.game_state == Enums.GameState.GameState_PlayerDecision:
		pass
	else:
		fail_test("Unexpected game state after initiating strike")
		## TODO: Figure out if the test should terminate early here
	return card_id

func do_strike_response(player, card_id, ex_card_id = -1):
	if card_id != -1:
		assert_true(game_logic.do_strike(player, card_id, false, ex_card_id),
				"Unsuccessful attempt to initiate strike with %s%s" % [
						"EX " if ex_card_id >= 0 else "",
						game_logic.get_card_database().get_card_name(card_id)])
	else:
		var ws_card_id = player.deck[0].id
		assert_true(game_logic.do_strike(player, card_id, true, ex_card_id),
				"Unsuccessful attempt to initiate with wild swing (%s)" % [
						game_logic.get_card_database().get_card_name(ws_card_id)])
		card_id = ws_card_id
	return card_id

func advance_turn(player):
	assert_true(game_logic.do_prepare(player),
			"Player %s tried to prepare but could not." % (player.my_id))
	if player.hand.size() > 7:
		var cards = []
		var to_discard = player.hand.size() - 7
		for i in range(to_discard):
			cards.append(player.hand[i].id)
		assert_true(game_logic.do_discard_to_max(player, cards))

func validate_gauge(player, amount, id):
	assert_eq(len(player.gauge), amount)
	if amount == 0 or len(player.gauge) != amount:
		return
	assert_true(
		player.gauge.any(func (card): return card.id == id),
		"Didn't find card %s in gauge." % id)

func validate_discard(player, amount, id):
	assert_eq(len(player.discards), amount)
	if amount == 0 or len(player.discards) != amount:
		return
	assert_true(
		player.discard.any(func (card): return card.id == id),
		"Didn't find card %s in discard." % id)

func process_decisions(player, strike_state, decisions):
	while game_logic.game_state == Enums.GameState.GameState_PlayerDecision and \
			game_logic.active_strike.strike_state == strike_state and \
			game_logic.decision_info.player == player.my_id:
		var content = decisions.pop_front()
		if content == null:
			fail_test("Player %s needed to decide on %s during %s but wasn't told how to" % [
					player.my_id, Enums.DecisionType.keys()[game_logic.decision_info.type],
					LocalGame.StrikeState.keys()[strike_state]])
			return
		match game_logic.decision_info.type:
			Enums.DecisionType.DecisionType_ForceForEffect:
				assert_true(game_logic.do_force_for_effect(player, content, false),
						"%s failed to perform a Force effect using %s" % [player, content])
			Enums.DecisionType.DecisionType_GaugeForEffect:
				assert_true(game_logic.do_gauge_for_effect(player, content),
						"%s failed to perform a Gauge effect using %s" % [player, content])
			Enums.DecisionType.DecisionType_PayStrikeCost_Required, Enums.DecisionType.DecisionType_PayStrikeCost_CanWild:
				# There is sometimes an init_extra_cost here
				# TODO: See if anyone needs it to be more than 0
				assert_true(game_logic.do_pay_strike_cost(player, content, false),
						"%s failed to pay a Strike cost using %s" % [player, content])
			var decision_type:  # Unknown decision type, just roll with it
				assert_true(game_logic.do_choice(player, content),
						"Decision of type %s unhandled by test harness (attempted by player %s, content %s)" % [
								decision_type, player, content])

func process_remaining_decisions(initiator, defender, init_choices, def_choices):
	var empty_loop_count = 0
	while init_choices.size() + def_choices.size() >= 1:
		# empty_loop_count is used to detect when there are still prescribed choices in
		# the input, but the game is not actually making additional decision points available.
		empty_loop_count += 1
		if empty_loop_count >= 3:
			fail_test("Game is not providing decision points to process initiator" +
					" choices %s or defender choices %s" % [init_choices, def_choices])
			return
		while game_logic.game_state == Enums.GameState.GameState_PlayerDecision:
				## TODO: Figure out if it's really necessary to limit ourselves to this game state
				# and game_logic.decision_info.type == Enums.DecisionType.DecisionType_ChooseSimultaneousEffect:
			empty_loop_count = 0  # reset the count each time we actually get into this loop; it is not empty
			var decision = game_logic.decision_info
			var player = initiator
			var player_choices = init_choices
			if decision.player == defender.my_id:
				player = defender
				player_choices = def_choices
			var choice = player_choices.pop_front()
			if choice == null:
				fail_test("Insufficient decisions defined for player %s during strike" % (player.my_id))
				return
			match game_logic.decision_info.type:
				Enums.DecisionType.DecisionType_ChooseSimultaneousEffect:
					assert_true(game_logic.do_choice(player, choice),
							"%s failed to perform a choice with value %s" % [player, choice])
				Enums.DecisionType.DecisionType_ChooseToDiscard:
					assert_true(game_logic.do_choose_to_discard(player, choice),
							"%s failed to discard cards %s" % [player, choice])
				Enums.DecisionType.DecisionType_ForceForArmor:
					assert_true(game_logic.do_force_for_armor(player, choice),
							"%s failed to discard cards %s for armor" % [player, choice])
				var decision_type:  # Unknown decision type, just roll with it?
					if typeof(choice) == Variant.Type.TYPE_ARRAY:
						fail_test("Attempting to apply array choice %s to a decision of type %s" % [
								choice, Enums.DecisionType.keys()[decision_type]])
						return
					assert_true(game_logic.do_choice(player, choice),
							"Decision of type %s unhandled by test harness (attempted by player %s, content %s)" % [
									decision_type, player, choice])
		## TODO: Does the loop need to wait a tick or two here for the game engine to
		##     present another decision?
		# wait_seconds(0.01)
	if game_logic.game_state == Enums.GameState.GameState_PlayerDecision:
		fail_test("Insufficient decisions defined for player %s during strike" % game_logic.decision_info.player)
		return

func execute_strike(initiator, defender, init_card: String, def_card: String,
		init_ex = false, def_ex = false, init_choices = [], def_choices = []):
	var init_card_id = -1
	var init_card_ex_id = -1
	var def_card_id = -1
	var def_card_ex_id = -1
	## TODO: Figure out what to do if one of the *_choices needs to use a card
	##   ID that will not be assigned until the `give_player_specific_card`
	##   calls below.
	if init_card:
		init_card_id = give_player_specific_card(initiator, init_card)
		if init_ex:
			init_card_ex_id = give_player_specific_card(initiator, init_card)
		do_and_validate_strike(initiator, init_card_id, init_card_ex_id)
	else:
		init_card_id = do_and_validate_strike(initiator, -1)  # wild swing
	## TODO: Why no all_events modification in the initiator block? Is it
	## because `validate` handles the only part we care about?
	process_decisions(initiator, game_logic.StrikeState.StrikeState_Initiator_SetEffects, init_choices)

	if def_card:
		def_card_id = give_player_specific_card(defender, def_card)
		if def_ex:
			def_card_ex_id = give_player_specific_card(defender, def_card)
		do_strike_response(defender, def_card_id, def_card_ex_id)
	else:
		def_card_id = do_strike_response(defender, -1)  # wild swing
	process_decisions(defender, game_logic.StrikeState.StrikeState_Defender_SetEffects, def_choices)

	process_decisions(initiator, game_logic.StrikeState.StrikeState_Initiator_PayCosts, init_choices)
	process_decisions(defender, game_logic.StrikeState.StrikeState_Defender_PayCosts, def_choices)

	process_remaining_decisions(initiator, defender, init_choices, def_choices)

	return [init_card_id, def_card_id, init_card_ex_id, def_card_ex_id]


func validate_positions(p1, l1, p2, l2):
	assert_eq(p1.arena_location, l1)
	assert_eq(p2.arena_location, l2)

func validate_life(p1, l1, p2, l2):
	assert_eq(p1.life, l1)
	assert_eq(p2.life, l2)

func get_cards_from_hand(player : LocalGame.Player, amount : int):
	var card_ids = []
	for i in range(amount):
		card_ids.append(player.hand[i].id)
	return card_ids

func get_cards_from_gauge(player : LocalGame.Player, amount : int):
	var card_ids = []
	for i in range(amount):
		card_ids.append(player.gauge[i].id)
	return card_ids
