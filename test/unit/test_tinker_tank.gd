extends GutTest

const LocalGame = preload("res://scenes/game/local_game.gd")
const GameCard = preload("res://scenes/game/game_card.gd")
const Enums = preload("res://scenes/game/enums.gd")
var game_logic : LocalGame
var image_loader : CardImageLoader
var default_deck = CardDefinitions.get_deck_from_str_id("tinker")
const TestCardId1 = 50001
const TestCardId2 = 50002
const TestCardId3 = 50003
const TestCardId4 = 50004
const TestCardId5 = 50005

var player1 : LocalGame.Player
var player2 : LocalGame.Player

func default_game_setup(opponent_deck="tinker"):
	opponent_deck = CardDefinitions.get_deck_from_str_id(opponent_deck)
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

func handle_simultaneous_effects(initiator, defender):
	while game_logic.game_state == Enums.GameState.GameState_PlayerDecision and game_logic.decision_info.type == Enums.DecisionType.DecisionType_ChooseSimultaneousEffect:
		var decider = initiator
		if game_logic.decision_info.player == defender.my_id:
			decider = defender
		assert_true(game_logic.do_choice(decider, 0), "Failed simuleffect choice")

func execute_strike(initiator, defender, init_card : String, def_card : String, init_choices, def_choices, init_ex = false, def_ex = false,
		init_force_discard = [], def_force_discard = [], init_extra_cost = 0, init_force_special = false):
	var all_events = []
	give_specific_cards(initiator, init_card, defender, def_card)
	if init_ex:
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

	# Pay any costs from gauge or hand
	if game_logic.active_strike and game_logic.active_strike.strike_state == game_logic.StrikeState.StrikeState_Initiator_PayCosts:
		if init_force_special:
			var cost = game_logic.active_strike.initiator_card.definition['force_cost'] + init_extra_cost
			var cards = []
			for i in range(cost):
				cards.append(initiator.hand[i].id)
			game_logic.do_pay_strike_cost(initiator, cards, false)
		else:
			var cost = game_logic.active_strike.initiator_card.definition['gauge_cost'] + init_extra_cost
			if 'gauge_cost_reduction' in game_logic.active_strike.initiator_card.definition and game_logic.active_strike.initiator_card.definition['gauge_cost_reduction'] == 'per_sealed_normal':
				cost -= initiator.get_sealed_count_of_type("normal")
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
		assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
		assert_true(game_logic.do_choice(initiator, init_choices[i]))
		handle_simultaneous_effects(initiator, defender)
	handle_simultaneous_effects(initiator, defender)

	for i in range(def_choices.size()):
		assert_eq(game_logic.game_state, Enums.GameState.GameState_PlayerDecision)
		assert_true(game_logic.do_choice(defender, def_choices[i]))
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

##
## Tests start here
##

func _setup_tank():
	default_game_setup()

	validate_life(player1, 15, player2, 15)
	give_gauge(player1, 5)
	player1.life = 1
	position_players(player1, 3, player2, 5)
	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_assault", [], [], false, false)

	assert_eq(player1.extra_width, 1)
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 20, player2, 15)
	advance_turn(player2)

func test_tinker_tank_setup():
	_setup_tank()

func test_tinker_tank_in_bounds_retreat():
	_setup_tank()
	execute_strike(player1, player2, "standard_normal_cross", "standard_normal_assault", [], [], false, false)
	validate_positions(player1, 2, player2, 5)
	validate_life(player1, 20, player2, 15)

func test_tinker_tank_no_space_advance():
	_setup_tank()
	position_players(player1, 4, player2, 7)
	execute_strike(player1, player2, "standard_normal_dive", "standard_normal_sweep", [], [], false, false)
	validate_positions(player1, 5, player2, 7)
	validate_life(player1, 14, player2, 10)

func test_tinker_tank_with_space_advance():
	_setup_tank()
	position_players(player1, 3, player2, 6)
	execute_strike(player1, player2, "standard_normal_dive", "standard_normal_sweep", [], [], false, false)
	validate_positions(player1, 8, player2, 6)
	validate_life(player1, 20, player2, 10)

func test_tinker_tank_close():
	_setup_tank()
	position_players(player1, 4, player2, 7)
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_sweep", [], [], false, false)
	validate_positions(player1, 5, player2, 7)
	validate_life(player1, 14, player2, 11)

func test_tinker_tank_pull_opponent():
	_setup_tank()
	position_players(player1, 4, player2, 6)
	# pull 1
	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_assault", [2], [], false, false)
	validate_positions(player1, 4, player2, 2)
	validate_life(player1, 20, player2, 12)

func test_tinker_tank_get_pulled():
	_setup_tank()
	advance_turn(player1)
	position_players(player1, 4, player2, 6)
	# pull 2; should have no space for second part
	execute_strike(player2, player1, "standard_normal_grasp", "standard_normal_assault", [3], [], false, false)
	validate_positions(player1, 8, player2, 6)
	validate_life(player1, 17, player2, 15)

func test_tinker_tank_big_sweep():
	_setup_tank()
	validate_positions(player1, 3, player2, 7)
	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_sweep", [], [], false, false)
	validate_life(player1, 14, player2, 9)

func test_tinker_tank_spiked():
	_setup_tank()
	position_players(player1, 3, player2, 6)
	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_spike", [], [], false, false)
	validate_life(player1, 15, player2, 15)

func test_tinker_tank_range_one_spiked():
	_setup_tank()
	position_players(player1, 3, player2, 5)
	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_spike", [], [], false, false)
	validate_life(player1, 15, player2, 15)

func test_tinker_tank_force_to_move_past():
	_setup_tank()
	position_players(player1, 3, player2, 6)

	player1.discard_hand()
	give_player_specific_card(player1, "standard_normal_grasp", TestCardId1)
	give_player_specific_card(player1, "standard_normal_grasp", TestCardId2)
	give_player_specific_card(player1, "standard_normal_grasp", TestCardId3)

	assert_true(game_logic.do_move(player1, [TestCardId1, TestCardId2, TestCardId3], 8))
	validate_positions(player1, 8, player2, 6)

func test_tinker_tank_force_to_be_moved_past():
	_setup_tank()
	advance_turn(player1)
	position_players(player1, 3, player2, 6)

	player2.discard_hand()
	give_player_specific_card(player2, "standard_normal_grasp", TestCardId1)
	# skipping 2 because it's in their gauge already
	give_player_specific_card(player2, "standard_normal_grasp", TestCardId3)
	give_player_specific_card(player2, "standard_normal_grasp", TestCardId4)

	assert_true(game_logic.do_move(player2, [TestCardId1, TestCardId2, TestCardId3, TestCardId4], 1))
	validate_positions(player1, 3, player2, 1)


func _setup_double_tank():
	default_game_setup()

	validate_life(player1, 15, player2, 15)
	give_gauge(player1, 5)
	give_gauge(player2, 5)
	player1.life = 1
	player2.life = 1
	position_players(player1, 3, player2, 5)
	execute_strike(player1, player2, "standard_normal_focus", "standard_normal_focus", [], [], false, false)

	assert_eq(player1.extra_width, 1)
	assert_eq(player2.extra_width, 1)
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 20, player2, 20)
	advance_turn(player2)

func test_tinker_double_tank_setup():
	_setup_double_tank()

func test_tinker_double_tank_no_space_advance():
	_setup_double_tank()
	position_players(player1, 3, player2, 6)
	execute_strike(player1, player2, "standard_normal_dive", "standard_normal_sweep", [], [], false, false)
	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 14, player2, 15)

func test_tinker_double_tank_with_space_advance():
	_setup_double_tank()
	position_players(player1, 2, player2, 5)
	execute_strike(player1, player2, "standard_normal_dive", "standard_normal_sweep", [], [], false, false)
	validate_positions(player1, 8, player2, 5)
	validate_life(player1, 20, player2, 15)

func test_tinker_double_tank_pull():
	_setup_double_tank()
	position_players(player1, 5, player2, 8)
	# pull 1
	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_assault", [2], [], false, false)
	validate_positions(player1, 5, player2, 2)
	validate_life(player1, 20, player2, 17)

func test_tinker_double_tank_max_range():
	_setup_double_tank()
	position_players(player1, 2, player2, 8)
	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_sweep", [], [], false, false)
	validate_life(player1, 20, player2, 20)

func test_tinker_double_tank_double_sweep():
	_setup_double_tank()
	position_players(player1, 3, player2, 8)
	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_sweep", [], [], false, false)
	validate_life(player1, 14, player2, 14)

func test_tinker_double_tank_double_spike():
	_setup_double_tank()
	position_players(player1, 4, player2, 7)
	execute_strike(player1, player2, "standard_normal_spike", "standard_normal_spike", [], [], false, false)
	validate_life(player1, 20, player2, 15)



func _setup_tank_vs(other_deck):
	default_game_setup(other_deck)

	validate_life(player1, 15, player2, 30)
	give_gauge(player1, 5)
	player1.life = 1
	position_players(player1, 1, player2, 3)
	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_assault", [], [], false, false)

	assert_eq(player1.extra_width, 1)
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 20, player2, 30)
	advance_turn(player2)

func test_tinker_tank_vs_other():
	_setup_tank_vs("shovelshield")

func test_tinker_tank_vs_buddy_between_opponent():
	_setup_tank_vs("shovelshield")
	position_players(player1, 3, player2, 6)
	player2.set_buddy_location("shieldknight", 8)
	advance_turn(player1)
	give_gauge(player2, 3)

	player2.discard_hand() # to avoid end of turn discard
	assert_true(game_logic.do_exceed(player2, [player2.gauge[0].id, player2.gauge[1].id, player2.gauge[2].id]))
	assert_true(game_logic.do_choice(player2, 4))
	assert_eq(player2.get_buddy_location("shieldknight"), 5)

	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_sweep", [], [], false, false)
	validate_life(player1, 14, player2, 26)

func test_tinker_tank_vs_not_buddy_between_opponent():
	_setup_tank_vs("shovelshield")
	position_players(player1, 3, player2, 6)
	player2.set_buddy_location("shieldknight", 8)
	advance_turn(player1)
	give_gauge(player2, 3)

	player2.discard_hand() # to avoid end of turn discard
	assert_true(game_logic.do_exceed(player2, [player2.gauge[0].id, player2.gauge[1].id, player2.gauge[2].id]))
	assert_true(game_logic.do_choice(player2, 3))
	assert_eq(player2.get_buddy_location("shieldknight"), 4)

	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_sweep", [], [], false, false)
	validate_life(player1, 14, player2, 24)

func test_tinker_tank_vs_buddy_on_opponent():
	_setup_tank_vs("carlclover")
	position_players(player1, 3, player2, 6)
	player2.set_buddy_location("nirvana_active", 3)

	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_sweep", [0], [], false, false, [], [], 0, [])
	validate_life(player1, 14, player2, 30)
	assert_eq(player1.gauge.size(), 6)
	assert_eq(player2.gauge.size(), 2)
	assert_eq(player2.get_buddy_location("nirvana_active"), -1)
	assert_eq(player2.get_buddy_location("nirvana_disabled"), 3)

func test_tinker_tank_vs_buddy_also_on_opponent():
	_setup_tank_vs("carlclover")
	position_players(player1, 3, player2, 6)
	player2.set_buddy_location("nirvana_active", 4)

	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_sweep", [0], [], false, false, [], [], 0, [])
	validate_life(player1, 14, player2, 30)
	assert_eq(player1.gauge.size(), 6)
	assert_eq(player2.gauge.size(), 2)
	assert_eq(player2.get_buddy_location("nirvana_active"), -1)
	assert_eq(player2.get_buddy_location("nirvana_disabled"), 4)

func test_tinker_tank_vs_is_between_buddy():
	_setup_tank_vs("carlclover")
	position_players(player1, 3, player2, 6)
	player2.set_buddy_location("nirvana_active", 1)

	execute_strike(player1, player2, "standard_normal_sweep", "carlclover_conanima", [], [], false, false, [], [], 0, [])
	validate_life(player1, 14, player2, 30)
	assert_eq(player1.gauge.size(), 5)
	assert_eq(player2.gauge.size(), 2)

func test_tinker_tank_vs_is_also_between_buddy():
	_setup_tank_vs("carlclover")
	position_players(player1, 3, player2, 6)
	player2.set_buddy_location("nirvana_active", 4)

	execute_strike(player1, player2, "standard_normal_sweep", "carlclover_conanima", [], [], false, false, [], [], 0, [])
	validate_life(player1, 14, player2, 30)
	assert_eq(player1.gauge.size(), 5)
	assert_eq(player2.gauge.size(), 2)

func test_tinker_tank_vs_buddy_in_range():
	_setup_tank_vs("carlclover")
	position_players(player1, 3, player2, 6)
	player2.set_buddy_location("nirvana_active", 7)

	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_sweep", [0], [], false, false, [], [], 0, [])
	validate_life(player1, 14, player2, 30)
	assert_eq(player1.gauge.size(), 6)
	assert_eq(player2.gauge.size(), 2)
	assert_eq(player2.get_buddy_location("nirvana_active"), -1)
	assert_eq(player2.get_buddy_location("nirvana_disabled"), 7)

func test_tinker_tank_vs_buddy_not_in_range():
	_setup_tank_vs("carlclover")
	position_players(player1, 3, player2, 6)
	player2.set_buddy_location("nirvana_active", 8)

	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_sweep", [], [], false, false, [], [], 0, [])
	validate_life(player1, 14, player2, 24)
	assert_eq(player1.gauge.size(), 6)
	assert_eq(player2.gauge.size(), 2)
