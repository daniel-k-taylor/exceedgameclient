extends GutTest

const LocalGame = preload("res://scenes/game/local_game.gd")
const GameCard = preload("res://scenes/game/game_card.gd")
const Enums = preload("res://scenes/game/enums.gd")
var game_logic : LocalGame
var image_loader : CardImageLoader
var default_deck = CardDefinitions.get_deck_from_str_id("bang")
const TestCardId1 = 50001
const TestCardId2 = 50002
const TestCardId3 = 50003
const TestCardId4 = 50004
const TestCardId5 = 50005
const TestCardId6 = 50006
const TestCardId7 = 50007

var player1 : LocalGame.Player
var player2 : LocalGame.Player

func default_game_setup(alt_opponent : String = ""):
	var opponent_deck = default_deck
	if alt_opponent:
		opponent_deck = CardDefinitions.get_deck_from_str_id(alt_opponent)
	image_loader = CardImageLoader.new(true)
	game_logic = LocalGame.new(image_loader)
	var seed_value = randi()
	game_logic.initialize_game(default_deck, opponent_deck, "p1", "p2", Enums.PlayerId.PlayerId_Player, seed_value)
	game_logic.draw_starting_hands_and_begin()
	game_logic.do_mulligan(game_logic.player, [])
	game_logic.do_mulligan(game_logic.opponent, [])
	player1 = game_logic.player
	player2 = game_logic.opponent
	game_logic.get_latest_events()

func give_player_specific_card(player, def_id, card_id):
	var card_def = CardDefinitions.get_card(def_id)
	var card = GameCard.new(card_id, card_def, player.my_id)
	var card_db = game_logic.get_card_database()
	card_db._test_insert_card(card)
	player.hand.append(card)

func give_specific_cards(p1, id1, p2, id2):
	if p1 and id1:
			give_player_specific_card(p1, id1, TestCardId1)
	if p2 and id2:
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
	var wild_swing = card_id == -1
	assert_true(game_logic.do_strike(player, card_id, wild_swing, ex_card_id))
	var events = game_logic.get_latest_events()
	if card_id == -1:
		card_id = null
	validate_has_event(events, Enums.EventType.EventType_Strike_Started, player, card_id)
	if game_logic.game_state == Enums.GameState.GameState_Strike_Opponent_Response or game_logic.game_state == Enums.GameState.GameState_PlayerDecision:
		pass
	else:
		fail_test("Unexpected game state after strike")

func do_strike_response(player, card_id, ex_card = -1):
	var wild_swing = card_id == -1
	assert_true(game_logic.do_strike(player, card_id, wild_swing, ex_card))
	var events = game_logic.get_latest_events()
	return events

func advance_turn(player):
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

func handle_simultaneous_effects(initiator, defender, simul_effect_choices : Array):
	while game_logic.game_state == Enums.GameState.GameState_PlayerDecision and game_logic.decision_info.type == Enums.DecisionType.DecisionType_ChooseSimultaneousEffect:
		var decider = initiator
		if game_logic.decision_info.player == defender.my_id:
			decider = defender
		var choice = 0
		if len(simul_effect_choices) > 0:
			choice = simul_effect_choices[0]
			simul_effect_choices.remove_at(0)
		assert_true(game_logic.do_choice(decider, choice), "Failed simuleffect choice")

func execute_strike(initiator, defender, init_card : String, def_card : String, init_choices, def_choices, init_ex = false, def_ex = false, init_force_discard = [], def_force_discard = [], init_extra_cost = 0, simul_effect_choices = []):
	var all_events = []
	give_specific_cards(initiator, init_card, defender, def_card)
	if init_ex:
		give_player_specific_card(initiator, init_card, TestCardId3)
		do_and_validate_strike(initiator, TestCardId1, TestCardId3)
	else:
		if init_card:
			do_and_validate_strike(initiator, TestCardId1)
		else:
			# Wild swing
			do_and_validate_strike(initiator, -1)

	if game_logic.game_state == Enums.GameState.GameState_PlayerDecision and game_logic.active_strike.strike_state == game_logic.StrikeState.StrikeState_Initiator_SetEffects:
		if game_logic.decision_info.type == Enums.DecisionType.DecisionType_GaugeForEffect:
			assert_true(game_logic.do_gauge_for_effect(initiator, init_force_discard), "failed gauge for effect in execute_strike")
		elif game_logic.decision_info.type == Enums.DecisionType.DecisionType_ForceForEffect:
			assert_true(game_logic.do_force_for_effect(initiator, init_force_discard, false), "failed force for effect in execute_strike")

	if def_ex:
		give_player_specific_card(defender, def_card, TestCardId4)
		all_events += do_strike_response(defender, TestCardId2, TestCardId4)
	elif def_card:
		all_events += do_strike_response(defender, TestCardId2)

	if game_logic.game_state == Enums.GameState.GameState_PlayerDecision and game_logic.active_strike.strike_state == game_logic.StrikeState.StrikeState_Defender_SetEffects:
		game_logic.do_force_for_effect(defender, def_force_discard, false)

	# Pay any costs from gauge
	if game_logic.active_strike and game_logic.active_strike.strike_state == game_logic.StrikeState.StrikeState_Initiator_PayCosts:
		if game_logic.active_strike.initiator_card.definition['force_cost']:
			var cost = game_logic.active_strike.initiator_card.definition['force_cost'] + init_extra_cost
			var cards = []
			for i in range(cost):
				cards.append(initiator.hand[i].id)
			game_logic.do_pay_strike_cost(initiator, cards, false)
		else:
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

	handle_simultaneous_effects(initiator, defender, simul_effect_choices)

	for i in range(init_choices.size()):
		assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision, "Passed in choice but not in player decision state")
		assert_true(game_logic.do_choice(initiator, init_choices[i]), "Failed init choice")
		handle_simultaneous_effects(initiator, defender, simul_effect_choices)
	handle_simultaneous_effects(initiator, defender, simul_effect_choices)

	for i in range(def_choices.size()):
		assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision, "Passed in choice but not in p2 player decision state")
		assert_true(game_logic.do_choice(defender, def_choices[i]), "Failed init choice")
		handle_simultaneous_effects(initiator, defender, simul_effect_choices)

	var events = game_logic.get_latest_events()
	all_events += events
	return all_events

func validate_positions(p1, l1, p2, l2):
	assert_eq(p1.arena_location, l1)
	assert_eq(p2.arena_location, l2)

func validate_life(p1, l1, p2, l2):
	assert_eq(p1.life, l1)
	assert_eq(p2.life, l2)

func get_card_ids_from_cards(cards):
	var ids = []
	for card in cards:
		ids.append(card.id)
	return ids
##
## Tests start here
##
func test_bang_prep():
	position_players(player1, 3, player2, 5)
	player1.discard_hand()
	var top1 = player1.deck[0].id
	var top2 = player1.deck[1].id
	var top3 = player1.deck[2].id
	assert_true(game_logic.do_character_action(player1, [], 0))
	assert_true(game_logic.do_choose_from_topdeck(player1, top2, "add_to_hand"))
	assert_eq(player1.hand.size(), 2)
	assert_eq(player1.hand[0].id, top2)
	assert_eq(player1.hand[1].id, top3)
	assert_eq(player1.get_top_discard_card().id, top1)
	advance_turn(player2)


func test_bang_exceed_ex_powerup_and_overdrive():
	position_players(player1, 3, player2, 5)
	give_gauge(player1, 4)
	assert_true(game_logic.do_exceed(player1, get_card_ids_from_cards(player1.gauge)))
	give_player_specific_card(player1, "standard_normal_assault", TestCardId1)
	give_player_specific_card(player1, "standard_normal_assault", TestCardId2)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId3)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, TestCardId2))
	assert_true(game_logic.do_strike(player2, TestCardId3, false, -1))
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 30, player2, 24)

	# Advantage!
	# Overdrive effect.
	# Put something in overdrive we know is in discard.
	give_player_specific_card(player1, "standard_normal_assault", TestCardId4)
	player1.move_cards_to_overdrive([TestCardId4], "hand")
	assert_true(game_logic.do_choose_from_discard(player1, [TestCardId4]))
	assert_true(player1.is_card_in_hand(TestCardId4))
	assert_true(player1.is_card_in_hand(TestCardId2)) # Discarded ex copy
	advance_turn(player1)


func test_bang_ultimatebang():
	position_players(player1, 3, player2, 5)
	give_gauge(player1, 4)
	execute_strike(player1, player2, "bang_theultimatebang", "standard_normal_sweep", [0], [], false, false, [], [], 0, [])
	# Chose to retreat 1 before.
	validate_positions(player1, 2, player2, 5)
	assert_eq(player1.discards.size(), 5) # Sweeped and gauge
	validate_life(player1, 24, player2, 30 - (2 + 5))
	advance_turn(player2)

func test_bang_hypershadowstep():
	position_players(player1, 2, player2, 7)
	give_player_specific_card(player1, "bang_bangstyleshuriken", TestCardId3)
	give_player_specific_card(player1, "bang_unstoppablepalmthrust", TestCardId4)
	give_player_specific_card(player1, "bang_voidtempestkick", TestCardId5)
	give_player_specific_card(player1, "bang_pulverizingblastjutsu", TestCardId6)
	player1.move_card_from_hand_to_gauge(TestCardId3)
	player1.move_card_from_hand_to_gauge(TestCardId4)
	player1.move_card_from_hand_to_gauge(TestCardId5)
	player1.move_card_from_hand_to_gauge(TestCardId6)
	assert_true(game_logic.do_exceed(player1, [TestCardId3, TestCardId4, TestCardId5, TestCardId6]))
	execute_strike(player1, player2, "bang_hypershadowstepstrike", "standard_normal_sweep", [], [], false, false, [], [], 0, [])
	validate_positions(player1, 8, player2, 7)
	validate_life(player1, 30, player2, 22)

func test_bang_hypershadowstep_notfree():
	position_players(player1, 2, player2, 7)
	give_player_specific_card(player1, "bang_bangstyleshuriken", TestCardId3)
	give_player_specific_card(player1, "bang_unstoppablepalmthrust", TestCardId4)
	give_player_specific_card(player1, "bang_voidtempestkick", TestCardId5)
	give_player_specific_card(player1, "standard_normal_assault", TestCardId6)
	player1.move_card_from_hand_to_gauge(TestCardId3)
	player1.move_card_from_hand_to_gauge(TestCardId4)
	player1.move_card_from_hand_to_gauge(TestCardId5)
	player1.move_card_from_hand_to_gauge(TestCardId6)
	assert_true(game_logic.do_exceed(player1, [TestCardId3, TestCardId4, TestCardId5, TestCardId6]))
	give_player_specific_card(player1, "standard_normal_assault", TestCardId7)
	player1.move_card_from_hand_to_deck(TestCardId7)
	execute_strike(player1, player2, "bang_hypershadowstepstrike", "standard_normal_sweep", [], [], false, false, [], [], 0, [])
	# Wild swings assault because can't pay.
	validate_positions(player1, 4, player2, 7)
	validate_life(player1, 24, player2, 30)
	advance_turn(player2)

func test_bang_shuriken_remove_ex():
	position_players(player1, 3, player2, 5)
	advance_turn(player1)
	give_player_specific_card(player2, "gg_normal_sweep", TestCardId3)
	assert_true(game_logic.do_boost(player2, TestCardId3, []))
	give_player_specific_card(player1, "standard_normal_dive", TestCardId4)
	assert_eq(player1.hand.size(), 8)
	execute_strike(player1, player2, "bang_bangstyleshuriken", "standard_normal_assault", [], [], false, false, [], [], 0, [])
	assert_eq(player1.hand.size(), 8) # Had to pay the force cost.
	assert_true(game_logic.do_choice(player1, 0)) # Choose to play a boost.
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_ForceStartBoost, player1)
	# Bang before effect.
	assert_true(game_logic.do_boost(player1, TestCardId4))
	assert_true(game_logic.do_boost_name_card_choice_effect(player1, TestCardId3))
	# Now they get stunned and take 1 damage
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 30, player2, 29)
	advance_turn(player2)


func test_bang_shuriken_remove_spike():
	position_players(player1, 3, player2, 5)
	advance_turn(player1)
	give_player_specific_card(player2, "standard_normal_spike", TestCardId3)
	assert_true(game_logic.do_boost(player2, TestCardId3, []))
	give_player_specific_card(player1, "standard_normal_dive", TestCardId4)
	assert_eq(player1.hand.size(), 8)
	execute_strike(player1, player2, "bang_bangstyleshuriken", "standard_normal_assault", [], [], false, false, [], [], 0, [])
	assert_eq(player1.hand.size(), 8) # Had to pay the force cost.
	assert_true(game_logic.do_choice(player1, 0)) # Choose to play a boost.
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_ForceStartBoost, player1)
	# Bang before effect.
	assert_true(game_logic.do_boost(player1, TestCardId4))
	assert_true(game_logic.do_boost_name_card_choice_effect(player1, TestCardId3))
	# Now they get stunned and take 1 damage
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 30, player2, 29)
	advance_turn(player2)

func test_bang_shuriken_boost_infinite():
	position_players(player1, 3, player2, 5)
	give_player_specific_card(player1, "bang_infinitechaosfistofthevoid", TestCardId4)
	execute_strike(player1, player2, "bang_bangstyleshuriken", "standard_normal_spike", [], [], false, false, [], [], 0, [])
	assert_true(game_logic.do_choice(player1, 0)) # Choose to play a boost.
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_ForceStartBoost, player1)
	# Bang before effect.
	assert_true(game_logic.do_boost(player1, TestCardId4))
	# This does a now advance 2 and strike (ignored)
	validate_positions(player1, 6, player2, 5)
	validate_life(player1, 30, player2, 29)
	advance_turn(player2)
	assert_eq(player1.continuous_boosts.size(), 0)

func test_bang_shuriken_boost_return_own():
	position_players(player1, 3, player2, 5)
	give_player_specific_card(player1, "bang_bangstyleshuriken", TestCardId1)
	give_player_specific_card(player1, "standard_normal_grasp", TestCardId2)
	assert_true(game_logic.do_boost(player1, TestCardId2))
	advance_turn(player2)
	assert_true(game_logic.do_boost(player1, TestCardId1))
	# Choose a boost to return
	assert_true(game_logic.do_boost_name_card_choice_effect(player1, TestCardId2))
	# Choice draw 1 or action
	assert_true(game_logic.do_choice(player1, 1))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)
	assert_true(player1.is_card_in_hand(TestCardId2))

func test_bang_shuriken_boost_return_other():
	position_players(player1, 3, player2, 5)
	give_player_specific_card(player1, "bang_bangstyleshuriken", TestCardId1)
	give_player_specific_card(player2, "standard_normal_grasp", TestCardId2)
	advance_turn(player1)
	assert_true(game_logic.do_boost(player2, TestCardId2))

	assert_true(game_logic.do_boost(player1, TestCardId1))
	# Choose a boost to return
	assert_true(game_logic.do_boost_name_card_choice_effect(player1, TestCardId2))
	# Choice draw 1 or action
	var hand_size = player1.hand.size()
	assert_true(game_logic.do_choice(player1, 0))
	assert_eq(player1.hand.size(), hand_size + 2) #end of turn draw and bonus card
	assert_true(player2.is_card_in_hand(TestCardId2))

