extends GutTest

const LocalGame = preload("res://scenes/game/local_game.gd")
const GameCard = preload("res://scenes/game/game_card.gd")
const Enums = preload("res://scenes/game/enums.gd")
var game_logic : LocalGame
var default_deck = CardDefinitions.get_deck_from_str_id("enchantress")
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

func give_player_specific_discard(player, def_id, card_id):
	var card_def = CardDefinitions.get_card(def_id)
	var card = GameCard.new(card_id, card_def, "image", player.my_id)
	var card_db = game_logic.get_card_database()
	card_db._test_insert_card(card)
	player.discards.append(card)

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

func test_enchantress_no_end_of_turn_draw():
	position_players(player1, 3, player2, 7)
	var hand_size = len(player1.hand)
	assert_true(game_logic.do_prepare(player1))
	assert_eq(len(player1.hand), hand_size + 1)
	advance_turn(player2)

func test_enchantress_empty_hand_end_of_turn():
	position_players(player1, 3, player2, 7)
	player1.hand = [player1.hand[0]]
	assert_true(game_logic.do_move(player1, [player1.hand[0].id], 2))
	assert_eq(len(player1.hand), 6)
	advance_turn(player2)

func test_enchantress_empty_hand_cleanup():
	position_players(player1, 3, player2, 7)
	player1.hand = []
	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_grasp", [], [], false, false)
	assert_eq(len(player1.hand), 6)
	advance_turn(player2)

func test_enchantress_end_of_turn_discard():
	position_players(player1, 3, player2, 7)
	player1.draw(8 - len(player1.hand))
	assert_true(game_logic.do_prepare(player1))
	assert_true(game_logic.do_discard_to_max(player1, [player1.hand[0].id, player1.hand[1].id]))
	assert_eq(len(player1.hand), 7)
	advance_turn(player2)

func test_enchantress_exceed():
	position_players(player1, 3, player2, 7)
	give_gauge(player1, 4)
	player1.draw(10)

	assert_true(game_logic.do_exceed(player1, [player1.gauge[0].id, player1.gauge[1].id, player1.gauge[2].id, player1.gauge[3].id]))
	assert_eq(len(player1.deck), 30)
	assert_true(game_logic.do_choice(player1, 1))
	assert_eq(len(player1.hand), 1)
	advance_turn(player2)

func test_enchantress_exceed_draw():
	position_players(player1, 3, player2, 7)
	give_gauge(player1, 4)
	player1.draw(10)

	assert_true(game_logic.do_exceed(player1, [player1.gauge[0].id, player1.gauge[1].id, player1.gauge[2].id, player1.gauge[3].id]))
	assert_eq(len(player1.deck), 30)
	assert_true(game_logic.do_choice(player1, 0))
	assert_eq(len(player1.hand), 7)
	advance_turn(player2)

func test_enchantress_exceed_no_empty_hand_cleanup():
	position_players(player1, 3, player2, 7)
	give_gauge(player1, 4)
	player1.draw(10)

	assert_true(game_logic.do_exceed(player1, [player1.gauge[0].id, player1.gauge[1].id, player1.gauge[2].id, player1.gauge[3].id]))
	assert_true(game_logic.do_choice(player1, 1))
	advance_turn(player2)

	player1.hand = []
	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_grasp", [], [], false, false)
	assert_eq(len(player1.hand), 0)
	advance_turn(player2)

func test_enchantress_flying_charge_empty_hand():
	position_players(player1, 3, player2, 7)
	player1.hand = []
	player1.draw(3)

	execute_strike(player1, player2, "enchantress_flyingcharge", "standard_normal_grasp", [], [], false, false)
	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id, player1.hand[1].id, player1.hand[2].id], true))
	validate_life(player1, 30, player2, 26)
	validate_positions(player1, 6, player2, 7)
	advance_turn(player2)

func test_enchantress_flying_charge_big_hand():
	position_players(player1, 1, player2, 3)
	player1.hand = []
	player1.draw(6)

	execute_strike(player1, player2, "enchantress_flyingcharge", "standard_normal_grasp", [], [], false, false)
	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id], true))
	validate_life(player1, 30, player2, 26)
	validate_positions(player1, 8, player2, 3)
	advance_turn(player2)

func test_enchantress_mind_control():
	position_players(player1, 3, player2, 7)
	give_player_specific_card(player1, "enchantress_flyingcharge", TestCardId1)
	give_player_specific_card(player2, "standard_normal_grasp", TestCardId2)
	give_player_specific_card(player2, "standard_normal_cross", TestCardId3)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId4)

	assert_true(game_logic.do_boost(player1, TestCardId1, []))
	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id, player1.hand[1].id, player1.hand[2].id], true))
	assert_true(game_logic.do_choose_to_discard(player2, [TestCardId2, TestCardId3, TestCardId4]))
	assert_true("standard_normal_grasp" in player2.public_hand)
	assert_true("standard_normal_cross" in player2.public_hand)
	assert_true("standard_normal_assault" in player2.public_hand)

	assert_true(game_logic.do_choose_to_discard(player1, [TestCardId2]))
	assert_true(player2.is_card_in_discards(TestCardId2))
	assert_true(player2.is_card_in_hand(TestCardId3))
	assert_true(player2.is_card_in_hand(TestCardId4))
	advance_turn(player2)

func test_enchantress_mind_control_no_force():
	position_players(player1, 3, player2, 7)
	give_player_specific_card(player1, "enchantress_flyingcharge", TestCardId1)
	give_player_specific_card(player2, "standard_normal_grasp", TestCardId2)
	give_player_specific_card(player2, "standard_normal_cross", TestCardId3)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId4)

	assert_true(game_logic.do_boost(player1, TestCardId1, []))
	assert_true(game_logic.do_force_for_effect(player1, [], true))
	assert_true(game_logic.do_choose_to_discard(player2, []))
	assert_false("standard_normal_grasp" in player2.public_hand)
	assert_false("standard_normal_cross" in player2.public_hand)
	assert_false("standard_normal_assault" in player2.public_hand)
	assert_true(player2.is_card_in_hand(TestCardId2))
	assert_true(player2.is_card_in_hand(TestCardId3))
	assert_true(player2.is_card_in_hand(TestCardId4))
	advance_turn(player2)

func test_enchantress_mind_control_opponent_hand_empty():
	position_players(player1, 3, player2, 7)
	give_player_specific_card(player1, "enchantress_flyingcharge", TestCardId1)
	player2.hand = []

	assert_true(game_logic.do_boost(player1, TestCardId1, []))
	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id], true))
	advance_turn(player2)

func test_enchantress_mind_control_more_force_than_hand():
	position_players(player1, 3, player2, 7)
	give_player_specific_card(player1, "enchantress_flyingcharge", TestCardId1)
	player2.hand = []
	give_player_specific_card(player2, "standard_normal_grasp", TestCardId2)
	give_player_specific_card(player2, "standard_normal_cross", TestCardId3)

	assert_true(game_logic.do_boost(player1, TestCardId1, []))
	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id, player1.hand[1].id, player1.hand[2].id], true))
	assert_true("standard_normal_grasp" in player2.public_hand)
	assert_true("standard_normal_cross" in player2.public_hand)

	assert_true(game_logic.do_choose_to_discard(player1, [TestCardId2]))
	assert_true(player2.is_card_in_discards(TestCardId2))
	assert_true(player2.is_card_in_hand(TestCardId3))
	advance_turn(player2)

func test_enchantress_homing_orb_hit():
	position_players(player1, 3, player2, 7)
	player1.hand = []
	player1.draw(4)

	execute_strike(player1, player2, "enchantress_homingorb", "standard_normal_grasp", [0], [], false, false)
	validate_life(player1, 30, player2, 27)
	validate_positions(player1, 3, player2, 8)
	advance_turn(player2)

func test_enchantress_homing_orb_miss():
	position_players(player1, 3, player2, 7)
	player1.hand = []
	player1.draw(3)

	execute_strike(player1, player2, "enchantress_homingorb", "standard_normal_grasp", [], [], false, false)
	validate_life(player1, 30, player2, 30)
	validate_positions(player1, 3, player2, 7)
	advance_turn(player2)

func test_enchantress_homing_orb_over_maximum():
	position_players(player1, 1, player2, 8)
	player1.hand = []
	player1.draw(9)

	execute_strike(player1, player2, "enchantress_homingorb", "standard_normal_grasp", [1], [], false, false)
	validate_life(player1, 30, player2, 27)
	validate_positions(player1, 1, player2, 7)
	advance_turn(player2)

func test_enchantress_ground_break_opponent_moves_enough():
	position_players(player1, 3, player2, 6)
	give_player_specific_card(player1, "enchantress_homingorb", TestCardId1)
	player2.hand = []

	assert_true(game_logic.do_boost(player1, TestCardId1, []))
	assert_true(game_logic.do_choice(player2, 3))
	validate_life(player1, 30, player2, 30)
	validate_positions(player1, 3, player2, 8)
	advance_turn(player2)

func test_enchantress_ground_break_opponent_doesnt_move_enough():
	position_players(player1, 3, player2, 6)
	give_player_specific_card(player1, "enchantress_homingorb", TestCardId1)
	player2.hand = []

	assert_true(game_logic.do_boost(player1, TestCardId1, []))
	assert_true(game_logic.do_choice(player2, 0))
	validate_life(player1, 30, player2, 25)
	validate_positions(player1, 3, player2, 5)
	advance_turn(player2)

func test_enchantress_ground_break_opponent_moves_through():
	position_players(player1, 4, player2, 5)
	give_player_specific_card(player1, "enchantress_homingorb", TestCardId1)
	player2.hand = []

	assert_true(game_logic.do_boost(player1, TestCardId1, []))
	assert_true(game_logic.do_choice(player2, 0))
	validate_life(player1, 30, player2, 25)
	validate_positions(player1, 4, player2, 3)
	advance_turn(player2)

func test_enchantress_ground_break_opponent_moves_to_border():
	position_players(player1, 4, player2, 1)
	give_player_specific_card(player1, "enchantress_homingorb", TestCardId1)
	player2.hand = []

	assert_true(game_logic.do_boost(player1, TestCardId1, []))
	assert_true(game_logic.do_choice(player2, 3))
	validate_life(player1, 30, player2, 25)
	validate_positions(player1, 4, player2, 1)
	advance_turn(player2)

func test_enchantress_rebirth():
	position_players(player1, 3, player2, 7)
	player1.hand = []
	give_player_specific_card(player1, "enchantress_magicshot", TestCardId1)
	give_player_specific_card(player1, "standard_normal_grasp", TestCardId2)
	give_player_specific_card(player1, "standard_normal_grasp", TestCardId3)
	give_player_specific_card(player1, "standard_normal_grasp", TestCardId4)

	assert_true(game_logic.do_boost(player1, TestCardId1, []))
	assert_true(game_logic.do_relocate_card_from_hand(player1, [TestCardId2, TestCardId3, TestCardId4]))
	assert_eq(len(player1.hand), 4)
	assert_eq(player1.deck[len(player1.deck)-1].id, TestCardId4)
	assert_eq(player1.deck[len(player1.deck)-2].id, TestCardId3)
	assert_eq(player1.deck[len(player1.deck)-3].id, TestCardId2)
	advance_turn(player2)

func test_enchantress_destructive_force_discard_enough():
	position_players(player1, 3, player2, 6)
	give_player_specific_card(player1, "enchantress_spiralorb", TestCardId3)

	assert_true(game_logic.do_boost(player1, TestCardId3, []))
	advance_turn(player2)

	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_sweep", [], [], false, false)
	assert_true(game_logic.do_choose_to_discard(player2, [player2.hand[0].id, player2.hand[1].id]))
	validate_life(player1, 24, player2, 26)
	validate_positions(player1, 5, player2, 6)
	advance_turn(player1)

func test_enchantress_destructive_force_dont_discard_enough():
	position_players(player1, 3, player2, 6)
	give_player_specific_card(player1, "enchantress_spiralorb", TestCardId3)

	assert_true(game_logic.do_boost(player1, TestCardId3, []))
	advance_turn(player2)

	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_sweep", [], [], false, false)
	assert_true(game_logic.do_choose_to_discard(player2, [player2.hand[0].id]))
	validate_life(player1, 30, player2, 23)
	validate_positions(player1, 5, player2, 6)
	advance_turn(player1)

func test_enchantress_destructive_force_cant_discard_enough():
	position_players(player1, 3, player2, 6)
	give_player_specific_card(player1, "enchantress_spiralorb", TestCardId3)

	assert_true(game_logic.do_boost(player1, TestCardId3, []))
	advance_turn(player2)
	player2.hand = []

	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_sweep", [], [], false, false)
	validate_life(player1, 30, player2, 23)
	validate_positions(player1, 5, player2, 6)
	advance_turn(player1)

func test_enchantress_rapid_beam_no_cards():
	position_players(player1, 2, player2, 8)
	give_gauge(player1, 3)
	player1.hand = []

	execute_strike(player1, player2, "enchantress_rapidbeam", "standard_normal_grasp", [], [], false, false)
	validate_life(player1, 30, player2, 26)
	validate_positions(player1, 2, player2, 8)
	advance_turn(player2)

func test_enchantress_rapid_beam_several_cards():
	position_players(player1, 2, player2, 8)
	give_gauge(player1, 3)
	player1.hand = []
	player1.draw(4)

	execute_strike(player1, player2, "enchantress_rapidbeam", "standard_normal_grasp", [], [], false, false)
	validate_life(player1, 30, player2, 22)
	validate_positions(player1, 2, player2, 8)
	advance_turn(player2)

func test_enchantress_rapid_beam_over_max_cards():
	position_players(player1, 2, player2, 8)
	give_gauge(player1, 3)
	player1.hand = []
	player1.draw(12)

	execute_strike(player1, player2, "enchantress_rapidbeam", "standard_normal_grasp", [], [], false, false)
	validate_life(player1, 30, player2, 19)
	validate_positions(player1, 2, player2, 8)
	advance_turn(player2)

func test_enchantress_shattering_scream_hit_no_cards():
	position_players(player1, 2, player2, 3)
	give_gauge(player1, 3)
	player1.hand = []

	execute_strike(player1, player2, "enchantress_shatteringscream", "standard_normal_spike", [], [], false, false)
	validate_life(player1, 30, player2, 24)
	validate_positions(player1, 2, player2, 3)
	advance_turn(player2)

func test_enchantress_shattering_scream_miss_no_cards():
	position_players(player1, 2, player2, 4)
	give_gauge(player1, 3)
	player1.hand = []

	execute_strike(player1, player2, "enchantress_shatteringscream", "standard_normal_grasp", [], [], false, false)
	validate_life(player1, 30, player2, 30)
	validate_positions(player1, 2, player2, 4)
	advance_turn(player2)

func test_enchantress_shattering_scream_hit_several_cards():
	position_players(player1, 2, player2, 8)
	give_gauge(player1, 3)
	player1.hand = []
	player1.draw(5)

	execute_strike(player1, player2, "enchantress_shatteringscream", "standard_normal_grasp", [], [], false, false)
	validate_life(player1, 30, player2, 24)
	validate_positions(player1, 2, player2, 8)
	advance_turn(player2)

func test_enchantress_shattering_scream_miss_several_cards():
	position_players(player1, 2, player2, 9)
	give_gauge(player1, 3)
	player1.hand = []
	player1.draw(5)

	execute_strike(player1, player2, "enchantress_shatteringscream", "standard_normal_grasp", [], [], false, false)
	validate_life(player1, 30, player2, 30)
	validate_positions(player1, 2, player2, 9)
	advance_turn(player2)

func test_enchantress_critical_attack_same_number():
	position_players(player1, 3, player2, 6)
	give_player_specific_card(player1, "enchantress_shatteringscream", TestCardId3)

	assert_true(game_logic.do_boost(player1, TestCardId3, [player1.hand[0].id, player1.hand[1].id]))
	advance_turn(player2)

	player1.hand = []
	player1.draw(3)
	player2.hand = []
	player2.draw(3)

	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_sweep", [], [], false, false)
	validate_life(player1, 24, player2, 26)
	validate_positions(player1, 5, player2, 6)
	assert_eq(len(player2.hand), 3)
	advance_turn(player1)

func test_enchantress_critical_attack_discard():
	position_players(player1, 3, player2, 6)
	give_player_specific_card(player1, "enchantress_shatteringscream", TestCardId3)

	assert_true(game_logic.do_boost(player1, TestCardId3, [player1.hand[0].id, player1.hand[1].id]))
	advance_turn(player2)

	player1.hand = []
	player1.draw(2)
	player2.hand = []
	player2.draw(5)

	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_sweep", [], [], false, false)
	assert_true(game_logic.do_choose_to_discard(player2, [player2.hand[0].id, player2.hand[1].id, player2.hand[2].id]))
	validate_life(player1, 24, player2, 26)
	validate_positions(player1, 5, player2, 6)
	assert_eq(len(player2.hand), 2)
	advance_turn(player1)

func test_enchantress_critical_attack_draw():
	position_players(player1, 3, player2, 6)
	give_player_specific_card(player1, "enchantress_shatteringscream", TestCardId3)

	assert_true(game_logic.do_boost(player1, TestCardId3, [player1.hand[0].id, player1.hand[1].id]))
	advance_turn(player2)

	player1.hand = []
	player1.draw(5)
	player2.hand = []
	player2.draw(2)

	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_sweep", [], [], false, false)
	validate_life(player1, 30, player2, 23)
	validate_positions(player1, 5, player2, 6)
	assert_eq(len(player2.hand), 5)
	advance_turn(player1)
