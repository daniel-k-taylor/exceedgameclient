extends GutTest

const LocalGame = preload("res://scenes/game/local_game.gd")
const GameCard = preload("res://scenes/game/game_card.gd")
const Enums = preload("res://scenes/game/enums.gd")
var game_logic : LocalGame
var default_deck = CardDefinitions.get_deck_from_str_id("kokonoe")
const TestCardId1 = 50001
const TestCardId2 = 50002
const TestCardId3 = 50003
const TestCardId4 = 50004
const TestCardId5 = 50005

var player1 : LocalGame.Player
var player2 : LocalGame.Player

func default_game_setup(alt_opponent : String = ""):
	var opponent_deck = default_deck
	if alt_opponent:
		opponent_deck = CardDefinitions.get_deck_from_str_id(alt_opponent)
	game_logic = LocalGame.new()
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
	var card = GameCard.new(card_id, card_def, "image", player.my_id)
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

func advance_turn(player, do_prepare_action : bool = true):
	if do_prepare_action:
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
		assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
		assert_true(game_logic.do_choice(initiator, init_choices[i]))
		handle_simultaneous_effects(initiator, defender, simul_effect_choices)
	handle_simultaneous_effects(initiator, defender, simul_effect_choices)

	for i in range(def_choices.size()):
		assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
		assert_true(game_logic.do_choice(defender, def_choices[i]))
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

##
## Tests start here
##

func test_kokonoe_boost_pass_gravitron():
	position_players(player1, 3, player2, 7)
	assert_eq(player1.get_buddy_location(), -1)
	give_player_specific_card(player1, "standard_normal_grasp", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	# Don't place gravitron
	assert_true(game_logic.do_choice(player1, 0))
	assert_eq(player1.get_buddy_location(), -1)
	advance_turn(player2)

func test_kokonoe_absolute_zero_gravitron_strike():
	position_players(player1, 3, player2, 7)
	assert_eq(player1.hand.size(), 5)
	give_player_specific_card(player1, "kokonoe_absolutezero", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	# Place gravitron on opponent
	assert_true(game_logic.do_choice(player1, 7))
	assert_eq(player1.get_buddy_location(), 7)
	# Start strike
	give_player_specific_card(player1, "standard_normal_spike", TestCardId1)
	give_player_specific_card(player2, "standard_normal_sweep", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	# Pay for set strike
	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id], false, false))
	assert_eq(player1.hand.size(), 4)
	# Opponent
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# Grav choice
	assert_true(game_logic.do_choice(player1, 0))
	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 30, player2, 25)
	assert_eq(player1.hand.size(), 5)
	advance_turn(player2)

func test_kokonoe_solid_wheel_stop_early():
	position_players(player1, 3, player2, 4)
	player1.set_buddy_location("gravitron", 6)
	# Start strike
	give_player_specific_card(player1, "kokonoe_solidwheel", TestCardId1)
	give_player_specific_card(player2, "standard_normal_sweep", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	# Pay for Gravitron
	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id], false, false))
	# Opponent
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# 2 Before effects, wheel and grav, do grav first
	assert_true(game_logic.do_choice(player1, 1))
	# Then wheel happens.
	validate_positions(player1, 6, player2, 5)
	validate_life(player1, 24, player2, 26)
	# Advantage
	advance_turn(player1)

func test_kokonoe_solid_wheel_stop_early_behind_opponent():
	position_players(player1, 3, player2, 4)
	player1.set_buddy_location("gravitron", 5)
	# Start strike
	give_player_specific_card(player1, "kokonoe_solidwheel", TestCardId1)
	give_player_specific_card(player2, "standard_normal_sweep", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	# Don't pay for Gravitron
	assert_true(game_logic.do_force_for_effect(player1, [], false, false))
	# Opponent
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# Wheel happens.
	validate_positions(player1, 5, player2, 4)
	validate_life(player1, 24, player2, 26)
	# Advantage
	advance_turn(player1)

func test_kokonoe_solid_wheel_pass_because_opponent_on_it_and_miss():
	position_players(player1, 3, player2, 4)
	player1.set_buddy_location("gravitron", 5)
	# Start strike
	give_player_specific_card(player1, "kokonoe_solidwheel", TestCardId1)
	give_player_specific_card(player2, "standard_normal_sweep", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	# Pay for Gravitron
	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id], false, false))
	# Opponent
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# 2 Before effects, wheel and grav, do grav first
	assert_true(game_logic.do_choice(player1, 1))
	# Then wheel happens.
	validate_positions(player1, 8, player2, 5)
	validate_life(player1, 24, player2, 30)
	# No Advantage
	advance_turn(player2)

func test_kokonoe_solid_wheel_pass_because_opponent_on_it():
	position_players(player1, 3, player2, 6)
	player1.set_buddy_location("gravitron", 7)
	# Start strike
	give_player_specific_card(player1, "kokonoe_solidwheel", TestCardId1)
	give_player_specific_card(player2, "standard_normal_sweep", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	# Pay for Gravitron
	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id], false, false))
	# Opponent
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# 2 Before effects, wheel and grav, do grav first
	assert_true(game_logic.do_choice(player1, 1))
	# Then wheel happens.
	validate_positions(player1, 8, player2, 7)
	validate_life(player1, 24, player2, 26)
	# No Advantage
	advance_turn(player2)

func test_kokonoe_flamecage_boost():
	position_players(player1, 3, player2, 6)
	give_player_specific_card(player1, "kokonoe_flamecage", TestCardId1)
	assert_eq(player1.hand.size(), 6)
	assert_true(game_logic.do_boost(player1, TestCardId1))
	# Place gravitron
	assert_true(game_logic.do_choice(player1, 1))
	assert_eq(player1.get_buddy_location(), 1)
	assert_eq(player1.hand.size(), 10)
	advance_turn(player1, false)
	assert_eq(player1.hand.size(), 7)
	advance_turn(player2)
	var card_ids = []
	for card in player1.hand:
		card_ids.append(card.id)
		if len(card_ids) == 3:
			break
	assert_true(game_logic.do_choose_to_discard(player1, card_ids))
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player1.hand.size(), 4)
	advance_turn(player1)

func test_kokonoe_broken_bunker_speedloss():
	position_players(player1, 3, player2, 6)
	player1.set_buddy_location("gravitron", 5)
	# Start strike
	give_player_specific_card(player1, "kokonoe_brokenbunkerassault", TestCardId1)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	# Don't pay for gravitron
	assert_true(game_logic.do_force_for_effect(player1, [], false, true))
	# Opponent
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# Pay strike cost
	assert_true(game_logic.do_pay_strike_cost(player1, [player1.hand[0].id], false))
	# p2's assault is 5 vs our 3.
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 26, player2, 30)
	advance_turn(player2)

func test_kokonoe_broken_bunker_power_bonus():
	position_players(player1, 3, player2, 6)
	player1.set_buddy_location("gravitron", 5)
	# Start strike
	give_player_specific_card(player1, "kokonoe_brokenbunkerassault", TestCardId1)
	give_player_specific_card(player2, "standard_normal_spike", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	# Don't pay for gravitron
	assert_true(game_logic.do_force_for_effect(player1, [], false, true))
	# Opponent
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# Pay strike cost
	assert_true(game_logic.do_pay_strike_cost(player1, [player1.hand[0].id], false))
	validate_positions(player1, 5, player2, 6)
	validate_life(player1, 30, player2, 23)
	advance_turn(player2)

func test_kokonoe_broken_bunker_nograv_fast():
	position_players(player1, 3, player2, 6)
	# Start strike
	give_player_specific_card(player1, "kokonoe_brokenbunkerassault", TestCardId1)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	# Opponent
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# Pay strike cost
	assert_true(game_logic.do_pay_strike_cost(player1, [player1.hand[0].id], false))
	validate_positions(player1, 5, player2, 6)
	validate_life(player1, 30, player2, 25)
	advance_turn(player2)

func test_kokonoe_ultimateimpact_invalid_to_gauge():
	position_players(player1, 3, player2, 5)
	# Start strike
	give_player_specific_card(player1, "standard_normal_cross", TestCardId3)
	player1.move_card_from_hand_to_deck(TestCardId3, 0)
	execute_strike(player1, player2, "kokonoe_ultimateimpact", "standard_normal_sweep", [], [], false, false, [], [], 0, [])
	# Can't pay cost, wild swings cross
	validate_positions(player1, 1, player2, 5)
	validate_life(player1, 30, player2, 27)
	assert_eq(player1.gauge.size(), 2)
	advance_turn(player2)

func test_kokonoe_ultimateimpact_draw_any():
	position_players(player1, 4, player2, 5)
	give_gauge(player1, 4)
	# Start strike
	assert_eq(player1.hand.size(), 5)
	execute_strike(player1, player2, "kokonoe_ultimateimpact", "standard_normal_sweep", [], [], false, false, [], [], 0, [])
	# Draw any choice
	assert_true(game_logic.do_choice(player1, 10))
	assert_eq(player1.hand.size(), 15)
	validate_positions(player1, 4, player2, 8)
	validate_life(player1, 30, player2, 23)
	assert_eq(player1.gauge.size(), 1)
	advance_turn(player2)

func test_kokonoe_banishingrays_boost():
	position_players(player1, 4, player2, 5)
	give_player_specific_card(player1, "kokonoe_banishingrays", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3, [player1.hand[0].id]))
	assert_true(game_logic.do_choice(player1, 0))
	validate_positions(player1, 9, player2, 5)
	advance_turn(player2)

func test_kokonoe_banishingrays_boost_teleport():
	position_players(player1, 1, player2, 2)
	player1.set_buddy_location("gravitron", 9)
	give_player_specific_card(player1, "kokonoe_banishingrays", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3, [player1.hand[0].id]))
	validate_positions(player1, 9, player2, 2)
	advance_turn(player1)

func test_kokonoe_dreadnought_boost_only_1_discard():
	position_players(player1, 4, player2, 5)
	player1.discard_random(1)
	give_player_specific_card(player1, "kokonoe_dreadnoughtexterminator", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	# Place gravitron
	assert_true(game_logic.do_choice(player1, 9))
	assert_eq(player1.get_buddy_location("gravitron"), 9)
	assert_eq(player1.gauge.size(), 1)
	advance_turn(player2)
	execute_strike(player1, player2, "standard_normal_dive", "standard_normal_assault", [], [], false, false, [], [], 0, [])
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 23, player2, 30)
	advance_turn(player2)

func test_kokonoe_dreadnought_reg():
	position_players(player1, 1, player2, 7)
	player1.discard_hand()
	give_gauge(player1, 4)
	assert_eq(player1.gauge.size(), 4)
	give_player_specific_card(player1, "standard_normal_grasp", TestCardId3)
	give_player_specific_card(player1, "kokonoe_flamingbelobog", TestCardId4)
	give_player_specific_card(player1, "standard_normal_grasp", TestCardId5)

	execute_strike(player1, player2, "kokonoe_dreadnoughtexterminator", "standard_normal_assault", [], [], false, false, [], [], 0, [])

	assert_true(game_logic.do_force_for_effect(player1, [TestCardId3, TestCardId4, TestCardId5], false, false))
	validate_positions(player1, 1, player2, 5)
	validate_life(player1, 30, player2, 19)
	advance_turn(player2)

func test_kokonoe_dreadnought_exceeded_cantpay():
	position_players(player1, 1, player2, 7)
	player1.discard_hand()
	give_gauge(player1, 2)
	assert_true(game_logic.do_exceed(player1, [player1.gauge[0].id, player1.gauge[1].id]))
	# Place gravitron
	assert_true(game_logic.do_choice(player1, 8))
	assert_eq(player1.get_buddy_location("gravitron"), 9)
	give_player_specific_card(player1, "standard_normal_grasp", TestCardId3)
	give_player_specific_card(player1, "kokonoe_flamingbelobog", TestCardId4)
	give_player_specific_card(player1, "standard_normal_grasp", TestCardId5)
	give_player_specific_card(player1, "standard_normal_dive", 60000)
	player1.move_card_from_hand_to_deck(60000, 0)
	execute_strike(player1, player2, "kokonoe_dreadnoughtexterminator", "standard_normal_assault", [], [], false, false, [], [], 0, [])

	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 30, player2, 25)
	advance_turn(player2)

func test_kokonoe_dreadnought_exceeded_blastemwithforce():
	position_players(player1, 1, player2, 7)
	player1.discard_hand()
	give_gauge(player1, 2)
	assert_true(game_logic.do_exceed(player1, [player1.gauge[0].id, player1.gauge[1].id]))
	# Place gravitron
	assert_true(game_logic.do_choice(player1, 8))
	assert_eq(player1.get_buddy_location("gravitron"), 9)
	give_player_specific_card(player1, "kokonoe_flamingbelobog", TestCardId3)
	give_player_specific_card(player1, "kokonoe_flamingbelobog", TestCardId4)
	give_player_specific_card(player1, "kokonoe_flamingbelobog", TestCardId5)
	give_player_specific_card(player1, "kokonoe_flamingbelobog", 60000)

	var events = []
	give_player_specific_card(player1, "kokonoe_dreadnoughtexterminator", TestCardId1)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1, false))
	# No Grav
	assert_true(game_logic.do_force_for_effect(player1, [], false, false))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1, false))
	events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_Strike_PayCost_Force, player1)
	var card_ids = []
	for card in player1.hand:
		card_ids.append(card.id)
	assert_true(game_logic.do_pay_strike_cost(player1, card_ids, false))
	# No force for effect since no more cards.
	validate_positions(player1, 1, player2, 5)
	validate_life(player1, 30, player2, 16)
	advance_turn(player2)

func test_kokonoe_dreadnought_exceeded_invalidate_anyway():
	position_players(player1, 1, player2, 7)
	player1.discard_hand()
	give_gauge(player1, 2)
	assert_true(game_logic.do_exceed(player1, [player1.gauge[0].id, player1.gauge[1].id]))
	# Place gravitron
	assert_true(game_logic.do_choice(player1, 8))
	assert_eq(player1.get_buddy_location("gravitron"), 9)
	give_player_specific_card(player1, "kokonoe_flamingbelobog", TestCardId3)
	give_player_specific_card(player1, "kokonoe_flamingbelobog", TestCardId4)
	give_player_specific_card(player1, "kokonoe_flamingbelobog", TestCardId5)
	give_player_specific_card(player1, "kokonoe_flamingbelobog", 60000)
	give_player_specific_card(player1, "standard_normal_dive", 60001)
	player1.move_card_from_hand_to_deck(60001, 0)

	var events = []
	give_player_specific_card(player1, "kokonoe_dreadnoughtexterminator", TestCardId1)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1, false))
	# No Grav
	assert_true(game_logic.do_force_for_effect(player1, [], false, false))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1, false))
	events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_Strike_PayCost_Force, player1)
	# Wild swing
	assert_true(game_logic.do_pay_strike_cost(player1, [], true))
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 30, player2, 25)
	advance_turn(player2)

func test_kokonoe_overdrive():
	position_players(player1, 1, player2, 7)
	player1.discard_hand()
	give_gauge(player1, 2)
	assert_true(game_logic.do_exceed(player1, [player1.gauge[0].id, player1.gauge[1].id]))
	# Place gravitron
	assert_true(game_logic.do_choice(player1, 8))
	assert_eq(player1.get_buddy_location("gravitron"), 9)
	advance_turn(player1)
	advance_turn(player2)
	assert_true(game_logic.do_choose_from_discard(player1, [player1.overdrive[0].id]))
	# Place gravitron
	assert_true(game_logic.do_choice(player1, 6))
	assert_eq(player1.get_buddy_location("gravitron"), 6)
	advance_turn(player1)

func test_kokonoe_overdrive_pass():
	position_players(player1, 1, player2, 7)
	player1.discard_hand()
	give_gauge(player1, 2)
	assert_true(game_logic.do_exceed(player1, [player1.gauge[0].id, player1.gauge[1].id]))
	# Place gravitron
	assert_true(game_logic.do_choice(player1, 8))
	assert_eq(player1.get_buddy_location("gravitron"), 9)
	advance_turn(player1)
	advance_turn(player2)
	assert_true(game_logic.do_choose_from_discard(player1, [player1.overdrive[0].id]))
	# Don't place gravitron
	assert_true(game_logic.do_choice(player1, 0))
	assert_eq(player1.get_buddy_location("gravitron"), 9)
	advance_turn(player1)

func test_kokonoe_flamingbelobog_extraattack_pass():
	position_players(player1, 3, player2, 7)
	give_player_specific_card(player1, "kokonoe_flamingbelobog", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	# Place gravitron
	assert_true(game_logic.do_choice(player1, 5))
	assert_eq(player1.get_buddy_location(), 5)
	advance_turn(player2)

	# Start strike
	give_player_specific_card(player1, "kokonoe_flamecage", TestCardId1)
	give_player_specific_card(player2, "standard_normal_sweep", TestCardId2)
	# Ensure there is a card in our hand we can play later.
	give_player_specific_card(player1, "kokonoe_brokenbunkerassault", TestCardId4)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	# Pay for grav
	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id], false, false))
	# Opponent
	validate_positions(player1, 3, player2, 7)
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# Plan here is push them to 6 with grav, flame cage push back to 7
	# Then extra attack with broken bunker, gravitron pull to 6
	# get the bonus because player closes to 2.

	# Attack hits
	validate_life(player1, 30, player2, 27)
	# Flame cage push to 7
	assert_true(game_logic.do_choice(player1, 0)) # push to 7
	validate_positions(player1, 3, player2, 7)
	# After
	# Extra attack discard choose effect is now automatically triggered
	# Pass on the extra attack.
	assert_true(game_logic.do_choose_to_discard(player1, []))
	validate_life(player1, 30, player2, 27)
	advance_turn(player2)

func test_kokonoe_flamingbelobog_do_extraattack():
	position_players(player1, 3, player2, 7)
	give_player_specific_card(player1, "kokonoe_flamingbelobog", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	# Place gravitron
	assert_true(game_logic.do_choice(player1, 5))
	assert_eq(player1.get_buddy_location(), 5)
	advance_turn(player2)

	# Start strike
	give_player_specific_card(player1, "kokonoe_flamecage", TestCardId1)
	give_player_specific_card(player2, "standard_normal_sweep", TestCardId2)
	give_player_specific_card(player1, "kokonoe_brokenbunkerassault", TestCardId4)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	# Pay for grav
	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id], false, false))
	# Opponent
	validate_positions(player1, 3, player2, 7)
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# Plan here is push them to 6 with grav, flame cage push back to 7
	# Then extra attack with broken bunker, gravitron pull to 6
	# get the bonus because player closes to 2.

	# Attack hits
	validate_life(player1, 30, player2, 27)
	# Flame cage push to 7
	assert_true(game_logic.do_choice(player1, 0)) # push to 7
	validate_positions(player1, 3, player2, 7)
	# After
	# Extra attack discard choose effect is now automatically triggered
	assert_true(game_logic.do_choose_to_discard(player1, [TestCardId4]))
	# The card should no longer be in hand.
	assert_false(player1.is_card_in_hand(TestCardId4))
	# Need to pay for the force cost
	assert_true(game_logic.do_pay_strike_cost(player1, [player1.hand[0].id], false))
	# Before, choose close 2 or gravitron pulls to 6 automatically since we already paid for it.
	# Order is irrelevant here.
	assert_true(game_logic.do_choice(player1, 0))
	# Attack hits, doing 7 more damage since we're in gravitron.
	# Extra attack finishes, regular attack finishes, opponent is stunned and can't hit back.
	validate_positions(player1, 5, player2, 6)
	validate_life(player1, 30, player2, 20)
	assert_true(player1.is_card_in_gauge(TestCardId1))
	assert_true(player1.is_card_in_gauge(TestCardId4))
	advance_turn(player2)


func test_kokonoe_flamingbelobog_after_effect_after_extraattack():
	position_players(player1, 3, player2, 7)
	give_player_specific_card(player1, "kokonoe_flamingbelobog", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	# Place gravitron
	assert_true(game_logic.do_choice(player1, 5))
	assert_eq(player1.get_buddy_location(), 5)
	advance_turn(player2)

	# Start strike
	give_player_specific_card(player1, "kokonoe_flamecage", TestCardId1)
	give_player_specific_card(player2, "standard_normal_sweep", TestCardId2)
	give_player_specific_card(player1, "standard_normal_dive", TestCardId4)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	# Don't pay for grav
	assert_true(game_logic.do_force_for_effect(player1, [], false, true))
	# Opponent
	validate_positions(player1, 3, player2, 7)
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# Plan here is to hit with flame cage, use extra attack effect,
	# then resolve the flame cage after effect

	# Attack hits
	validate_life(player1, 30, player2, 25)
	# Simul choice between choices 0 (flame cage) and 1 (extra attack)
	assert_true(game_logic.do_choice(player1, 1))
	validate_positions(player1, 3, player2, 7)
	# Extra attack discard, play dive
	assert_true(game_logic.do_choose_to_discard(player1, [TestCardId4]))
	# No costs or choices, so dive goes and hits
	validate_life(player1, 30, player2, 20)
	validate_positions(player1, 6, player2, 7)
	# Then flame cage after choice
	assert_true(game_logic.do_choice(player1, 0)) # Push to 8
	validate_positions(player1, 6, player2, 8)
	assert_true(player1.is_card_in_gauge(TestCardId1))
	assert_true(player1.is_card_in_gauge(TestCardId4))
	advance_turn(player2)

func test_kokonoe_flamingbelobog_extraattack_misses():
	position_players(player1, 3, player2, 7)
	give_player_specific_card(player1, "kokonoe_flamingbelobog", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	# Place gravitron
	assert_true(game_logic.do_choice(player1, 5))
	assert_eq(player1.get_buddy_location(), 5)
	advance_turn(player2)

	# Start strike
	give_player_specific_card(player1, "kokonoe_flamecage", TestCardId1)
	give_player_specific_card(player2, "standard_normal_sweep", TestCardId2)
	give_player_specific_card(player1, "standard_normal_spike", TestCardId4)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	# Don't pay for grav
	assert_true(game_logic.do_force_for_effect(player1, [], false, true))
	# Opponent
	validate_positions(player1, 3, player2, 7)
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# Plan here is to hit with flame cage, use extra attack effect,
	# miss with that attack for lulz,
	# then resolve the flame cage after effect

	# Attack hits
	validate_life(player1, 30, player2, 25)
	# Simul choice between choices 0 (flame cage) and 1 (extra attack)
	assert_true(game_logic.do_choice(player1, 1))
	validate_positions(player1, 3, player2, 7)
	# Extra attack discard, play spike
	assert_true(game_logic.do_choose_to_discard(player1, [TestCardId4]))
	# No costs or choices, so dive goes and misses
	validate_life(player1, 30, player2, 25)
	validate_positions(player1, 3, player2, 7)
	# Then flame cage after choice
	assert_true(game_logic.do_choice(player1, 1)) # Pull so sweep hits cause why not.
	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 25, player2, 25)
	assert_true(player1.is_card_in_gauge(TestCardId1))
	assert_true(not player1.is_card_in_gauge(TestCardId4))
	advance_turn(player2)
