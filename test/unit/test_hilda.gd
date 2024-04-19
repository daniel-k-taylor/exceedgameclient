extends GutTest

const LocalGame = preload("res://scenes/game/local_game.gd")
const GameCard = preload("res://scenes/game/game_card.gd")
const Enums = preload("res://scenes/game/enums.gd")
var game_logic : LocalGame
var default_deck = CardDefinitions.get_deck_from_str_id("hilda")
const TestCardId1 = 50001
const TestCardId2 = 50002
const TestCardId3 = 50003
const TestCardId4 = 50004
const TestCardId5 = 50005

var player1 : LocalGame.Player
var player2 : LocalGame.Player

func default_game_setup():
	game_logic = LocalGame.new()
	var seed_value = randi()
	game_logic.initialize_game(default_deck, default_deck, "p1", "p2", Enums.PlayerId.PlayerId_Player, seed_value)
	game_logic.draw_starting_hands_and_begin()
	game_logic.do_mulligan(game_logic.player, [])
	game_logic.do_mulligan(game_logic.opponent, [])
	player1 = game_logic.player
	player2 = game_logic.opponent
	game_logic.get_latest_events()

func give_player_specific_card(player, def_id, card_id):
	var card_def = CardDefinitions.get_card(def_id)
	var card = GameCard.new(card_id, card_def, "image", player.my_id)
	var card_db = game_logic.get_card_database()
	card_db._test_insert_card(card)
	player.hand.append(card)

func give_specific_cards(p1, id1, p2, id2):
	if p1:
		give_player_specific_card(p1, id1, TestCardId1)
	if p2:
		give_player_specific_card(p2, id2, TestCardId2)

func position_players(p1, loc1, p2, loc2):
	p1.arena_location = loc1
	p2.arena_location = loc2

func give_gauge(player, amount):
	for i in range(amount):
		player.add_to_gauge(player.deck[0])
		player.deck.remove_at(0)

func validate_has_event(events, event_type, target_player, number = null):
	for event in events:
		if event['event_type'] == event_type:
			if event['event_player'] == target_player.my_id:
				if number != null and event['number'] == number:
					return
				elif number == null:
					return
	fail_test("Event not found: %s" % event_type)

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
	assert_true(game_logic.can_do_strike(player))
	assert_true(game_logic.do_strike(player, card_id, false, ex_card_id))
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_Strike_Started, player, card_id)
	if game_logic.game_state == Enums.GameState.GameState_Strike_Opponent_Response or game_logic.game_state == Enums.GameState.GameState_PlayerDecision:
		pass
	else:
		fail_test("Unexpected game state after strike")

func do_strike_response(player, card_id, ex_card = -1):
	assert_true(game_logic.do_strike(player, card_id, false, ex_card))
	var events = game_logic.get_latest_events()
	return events

func advance_turn(player, skip_prepare = false):
	if not skip_prepare:
		assert_true(game_logic.do_prepare(player))
	if player.hand.size() > 7:
		var cards = []
		var to_discard = player.hand.size() - 7
		for i in range(to_discard):
			cards.append(player.hand[i].id)
		assert_true(game_logic.do_discard_to_max(player, cards))

func validate_gauge(player, amount, id):
	assert_eq(len(player.gauge), amount)
	if len(player.gauge) != amount: return
	if amount == 0: return
	for card in player.gauge:
		if card.id == id:
			return
	fail_test("Didn't have required card in gauge.")

func validate_discard(player, amount, id):
	assert_eq(len(player.discards), amount)
	if len(player.discards) != amount: return
	if amount == 0: return
	for card in player.discards:
		if card.id == id:
			return
	fail_test("Didn't have required card in discard.")

func handle_simultaneous_effects(initiator, defender):
	while game_logic.game_state == Enums.GameState.GameState_PlayerDecision and game_logic.decision_info.type == Enums.DecisionType.DecisionType_ChooseSimultaneousEffect:
		var decider = initiator
		if game_logic.decision_info.player == defender.my_id:
			decider = defender
		assert_true(game_logic.do_choice(decider, 0), "Failed simuleffect choice")

func execute_strike(initiator, defender, init_card : String, def_card : String, init_choices, def_choices,
		init_ex = false, def_ex = false, init_force_discard = [], def_force_discard = [], init_extra_cost = 0, give_cards = true):
	var all_events = []
	if give_cards:
		give_specific_cards(initiator, init_card, defender, def_card)
	if init_ex:
		if give_cards:
			give_player_specific_card(initiator, init_card, TestCardId3)
		do_and_validate_strike(initiator, TestCardId1, TestCardId3)
	else:
		do_and_validate_strike(initiator, TestCardId1)

	if game_logic.game_state == Enums.GameState.GameState_PlayerDecision and game_logic.active_strike.strike_state == game_logic.StrikeState.StrikeState_Initiator_SetEffects:
		game_logic.do_force_for_effect(initiator, init_force_discard, false)

	if def_ex:
		give_player_specific_card(defender, def_card, TestCardId4)
		all_events += do_strike_response(defender, TestCardId2, TestCardId4)
	elif def_card:
		all_events += do_strike_response(defender, TestCardId2)

	if game_logic.game_state == Enums.GameState.GameState_PlayerDecision and game_logic.active_strike.strike_state == game_logic.StrikeState.StrikeState_Defender_SetEffects:
		game_logic.do_force_for_effect(defender, def_force_discard, false)

	# Pay any costs from gauge
	if game_logic.active_strike and game_logic.active_strike.strike_state == game_logic.StrikeState.StrikeState_Initiator_PayCosts:
		var cost = game_logic.active_strike.initiator_card.definition['gauge_cost'] + init_extra_cost
		var cards = []
		for i in range(cost):
			cards.append(initiator.gauge[i].id)
		game_logic.do_pay_strike_cost(initiator, cards, false)

	# Pay any costs from gauge
	if game_logic.active_strike and game_logic.active_strike.strike_state == game_logic.StrikeState.StrikeState_Defender_PayCosts:
		var cost = game_logic.active_strike.defender_card.definition['gauge_cost']
		var cards = []
		for i in range(cost):
			cards.append(defender.gauge[i].id)
		game_logic.do_pay_strike_cost(defender, cards, false)

	handle_simultaneous_effects(initiator, defender)

	for i in range(init_choices.size()):
		assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision, "not in decision for choice 1")
		assert_true(game_logic.do_choice(initiator, init_choices[i]), "choice 1 failed")
		handle_simultaneous_effects(initiator, defender)
	handle_simultaneous_effects(initiator, defender)

	for i in range(def_choices.size()):
		assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision, "not in decision for choice 2")
		assert_true(game_logic.do_choice(defender, def_choices[i]), "choice 2 failed")
		handle_simultaneous_effects(initiator, defender)

	var events = game_logic.get_latest_events()
	all_events += events
	return all_events

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


func get_choice_index_for_position(pos):
	for i in range(game_logic.decision_info.limitation.size()):
		var choice_pos = game_logic.decision_info.limitation[i]
		if pos == choice_pos:
			return i
	assert(false, "Unable to find choice index")
	fail_test("Unable to find choice index")
	return 0

##
## Tests start here
##

func test_hilda_inthedarkness_boost_and_interference():
	position_players(player1, 8, player2, 9)
	give_player_specific_card(player1, "hilda_inthedarkness", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	give_player_specific_card(player2, "standard_normal_sweep", TestCardId4)
	assert_true(game_logic.do_boost(player2, TestCardId4))
	advance_turn(player2, true)
	assert_eq(player2.hand.size(), 7)
	execute_strike(player1, player2, "standard_normal_sweep", "hilda_interference", [], [], false, false)
	# P1 sweep is now speed 6 power 2
	# P2 is speed 4 because light
	# P1 hits for 2 and discards p2 card
	# P2 hits back and pushs 6
	validate_life(player1, 26, player2, 28)
	assert_eq(player2.hand.size(), 6)
	validate_positions(player1, 2, player2, 9)

func test_hilda_impalement_attack_ex_max_bonus():
	position_players(player1, 2, player2, 5)
	give_player_specific_card(player1, "hilda_skewer", TestCardId3)
	give_player_specific_card(player1, "hilda_skewer", TestCardId4)
	player1.move_card_from_hand_to_gauge(TestCardId3)
	player1.move_card_from_hand_to_gauge(TestCardId4)
	give_player_specific_card(player1, "hilda_impalement", TestCardId1)
	give_player_specific_card(player1, "hilda_impalement", TestCardId5)
	give_player_specific_card(player2, "standard_normal_sweep", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, TestCardId5))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	assert_true(game_logic.do_pay_strike_cost(player1, player1.get_card_ids_in_gauge(), false))
	validate_life(player1, 30, player2, 23)
	validate_positions(player1, 2, player2, 5)

func test_hilda_impalement_attack_ex_1_bonus():
	position_players(player1, 2, player2, 5)
	give_player_specific_card(player1, "hilda_skewer", TestCardId3)
	give_player_specific_card(player1, "hilda_trifurket", TestCardId4)
	player1.move_card_from_hand_to_gauge(TestCardId3)
	player1.move_card_from_hand_to_gauge(TestCardId4)
	give_player_specific_card(player1, "hilda_impalement", TestCardId1)
	give_player_specific_card(player1, "hilda_impalement", TestCardId5)
	give_player_specific_card(player2, "standard_normal_sweep", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, TestCardId5))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	assert_true(game_logic.do_pay_strike_cost(player1, player1.get_card_ids_in_gauge(), false))
	validate_life(player1, 25, player2, 25)
	validate_positions(player1, 2, player2, 5)


func test_hilda_impalement_invertrange():
	position_players(player1, 2, player2, 5)
	give_player_specific_card(player1, "hilda_impalement", TestCardId5)
	assert_true(game_logic.do_boost(player1, TestCardId5, [player1.hand[0].id]))
	advance_turn(player2)
	give_player_specific_card(player1, "standard_normal_grasp", TestCardId1)
	give_player_specific_card(player2, "standard_normal_sweep", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	assert_true(game_logic.do_choice(player1, 0))
	validate_life(player1, 30, player2, 28)
	validate_positions(player1, 2, player2, 6)

func test_hilda_ua_grasp():
	position_players(player1, 2, player2, 4)
	assert_true(game_logic.do_character_action(player1, [], 0))
	give_player_specific_card(player1, "standard_normal_grasp", TestCardId1)
	give_player_specific_card(player2, "standard_normal_sweep", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	assert_true(game_logic.do_choice(player1, 1))
	validate_life(player1, 30, player2, 28)
	validate_positions(player1, 2, player2, 6)

func test_hilda_ua_grasp_min_range_miss():
	position_players(player1, 2, player2, 3)
	assert_true(game_logic.do_character_action(player1, [], 0))
	give_player_specific_card(player1, "standard_normal_grasp", TestCardId1)
	give_player_specific_card(player2, "standard_normal_sweep", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	validate_life(player1, 24, player2, 30)
	validate_positions(player1, 2, player2, 3)

func test_hilda_trifurket_bottom_to_gauge():
	position_players(player1, 2, player2, 3)
	player1.discard_hand()
	give_player_specific_card(player1, "hilda_trifurket", TestCardId1)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	var bottom_discard_id = player1.discards[0].id
	assert_true(game_logic.do_choice(player1, 0)) # Gauge

	validate_life(player1, 27, player2, 26)
	validate_positions(player1, 2, player2, 3)
	assert_eq(player1.gauge.size(), 2)
	assert_eq(player1.gauge[0].id, bottom_discard_id)
	assert_eq(player1.gauge[1].id, TestCardId1)

func test_hilda_trifurket_bottom_to_hand():
	position_players(player1, 2, player2, 3)
	player1.discard_hand()
	give_player_specific_card(player1, "hilda_trifurket", TestCardId1)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	var bottom_discard_id = player1.discards[0].id
	assert_true(game_logic.do_choice(player1, 1)) # Hand

	validate_life(player1, 27, player2, 26)
	validate_positions(player1, 2, player2, 3)
	assert_eq(player1.hand.size(), 1)
	assert_eq(player1.hand[0].id, bottom_discard_id)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player1.gauge[0].id, TestCardId1)

func test_hilda_trifurket_bottom_to_gauge_empty():
	position_players(player1, 2, player2, 3)
	give_player_specific_card(player1, "hilda_trifurket", TestCardId1)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	assert_true(game_logic.do_choice(player1, 0)) # Gauge

	validate_life(player1, 27, player2, 26)
	validate_positions(player1, 2, player2, 3)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player1.gauge[0].id, TestCardId1)



func test_hilda_trifurket_boost():
	position_players(player1, 2, player2, 3)
	player2.discard_hand()
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)
	give_player_specific_card(player1, "hilda_trifurket", TestCardId1)
	assert_true(game_logic.do_boost(player1, TestCardId1))

	assert_true(game_logic.do_relocate_card_from_hand(player2, [TestCardId2]))
	var p1cards = []
	for i in range(3):
		p1cards.append(player1.hand[i].id)
	assert_true(game_logic.do_relocate_card_from_hand(player1, p1cards))

	validate_positions(player1, 2, player2, 3)
	assert_eq(player1.gauge.size(), 3)
	assert_eq(player1.gauge[0].id, p1cards[0])
	assert_eq(player1.gauge[1].id, p1cards[1])
	assert_eq(player1.gauge[2].id, p1cards[2])
	assert_eq(player2.gauge.size(), 1)
	assert_eq(player2.gauge[0].id, TestCardId2)
	advance_turn(player2)

func test_hilda_revenantpillar_choosemultiple():
	position_players(player1, 2, player2, 5)
	assert_eq(player1.hand.size(), 5)
	give_player_specific_card(player1, "hilda_revenantpillar", TestCardId1)
	give_player_specific_card(player2, "standard_normal_sweep", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# Choose 2, push, pull, draw, discard opp random, advantage
	assert_eq(game_logic.decision_info.choice.size(), 5)
	assert_true(game_logic.do_choice(player1, 0)) # Push 1
	validate_positions(player1, 2, player2, 6)
	assert_eq(player1.hand.size(), 5)
	assert_eq(game_logic.decision_info.choice.size(), 4)
	assert_true(game_logic.do_choice(player1, 1)) # Draw 1
	assert_eq(player1.hand.size(), 6)
	validate_positions(player1, 2, player2, 6)
	validate_life(player1, 30, player2, 25)
	advance_turn(player2)

func test_hilda_revenantpillar_choosemultiple2():
	position_players(player1, 2, player2, 5)
	assert_eq(player1.hand.size(), 5)
	give_player_specific_card(player1, "hilda_revenantpillar", TestCardId1)
	give_player_specific_card(player2, "standard_normal_sweep", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# Choose 2, push, pull, draw, discard opp random, advantage
	assert_eq(game_logic.decision_info.choice.size(), 5)
	assert_true(game_logic.do_choice(player1, 4)) # advantage
	validate_positions(player1, 2, player2, 5)
	assert_eq(player1.hand.size(), 5)
	assert_eq(game_logic.decision_info.choice.size(), 4)
	assert_true(game_logic.do_choice(player1, 0)) # push 1
	assert_eq(player1.hand.size(), 5)
	validate_positions(player1, 2, player2, 6)
	validate_life(player1, 30, player2, 25)
	advance_turn(player1)


func test_hilda_revenantpillar_choosemultiple3():
	position_players(player1, 2, player2, 5)
	assert_eq(player1.hand.size(), 5)
	give_player_specific_card(player1, "hilda_revenantpillar", TestCardId1)
	give_player_specific_card(player2, "standard_normal_sweep", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# Choose 2, push, pull, draw, discard opp random, advantage
	assert_eq(game_logic.decision_info.choice.size(), 5)
	assert_true(game_logic.do_choice(player1, 2)) # draw
	validate_positions(player1, 2, player2, 5)
	assert_eq(player1.hand.size(), 6)
	assert_eq(game_logic.decision_info.choice.size(), 4)
	assert_true(game_logic.do_choice(player1, 2)) # discard
	assert_eq(player1.hand.size(), 5)
	validate_positions(player1, 2, player2, 5)
	validate_life(player1, 24, player2, 25)
	advance_turn(player2)


func test_hilda_ua_exceed():
	position_players(player1, 2, player2, 3)
	give_gauge(player1, 5)
	player1.exceeded = true
	assert_true(game_logic.do_character_action(player1, [player1.gauge[0].id], 0))
	assert_true(game_logic.do_choice(player1, 0)) # Push
	assert_true(game_logic.do_character_action(player1, [player1.gauge[0].id], 0))
	assert_true(game_logic.do_choice(player1, 0)) # Push
	assert_true(game_logic.do_character_action(player1, [player1.gauge[0].id], 0))
	assert_true(game_logic.do_choice(player1, 0)) # Push
	validate_positions(player1, 2, player2, 6)
	assert_eq(player1.hand.size(), 5)
	assert_eq(player2.hand.size(), 6)
	give_player_specific_card(player1, "hilda_interference", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	assert_eq(player1.hand.size(), 8)
	assert_eq(player2.hand.size(), 9)
	execute_strike(player1, player2, "standard_normal_dive", "standard_normal_dive", [], [], false, false)
	validate_life(player1, 30, player2, 25)
	advance_turn(player2)


func test_hilda_condensity_ex_space():
	position_players(player1, 2, player2, 6)
	give_player_specific_card(player1, "hilda_condensitygloom", TestCardId1)
	give_player_specific_card(player1, "hilda_condensitygloom", TestCardId5)
	give_player_specific_card(player2, "standard_normal_sweep", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, TestCardId5))
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(5)))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# After, you can go to it
	assert_true(game_logic.do_choice(player1, 0))
	validate_life(player1, 26, player2, 24)
	validate_positions(player1, 5, player2, 6)
	advance_turn(player2)


func test_hilda_condensity_notinspace():
	position_players(player1, 2, player2, 5)
	give_player_specific_card(player1, "hilda_condensitygloom", TestCardId1)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_choice(player1, 0)) # Pass
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	validate_life(player1, 27, player2, 25)
	validate_positions(player1, 2, player2, 3)
	advance_turn(player2)


func test_hilda_condensity_wild():
	position_players(player1, 2, player2, 5)
	give_player_specific_card(player1, "hilda_condensitygloom", TestCardId1)
	player1.move_card_from_hand_to_deck(TestCardId1, 0)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)
	assert_true(game_logic.do_strike(player1, -1, true, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	validate_life(player1, 27, player2, 25)
	validate_positions(player1, 2, player2, 3)
	advance_turn(player2)
