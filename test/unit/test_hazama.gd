extends GutTest

const LocalGame = preload("res://scenes/game/local_game.gd")
const GameCard = preload("res://scenes/game/game_card.gd")
const Enums = preload("res://scenes/game/enums.gd")
var game_logic : LocalGame
var default_deck = CardDefinitions.get_deck_from_str_id("hazama")
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
		do_and_validate_strike(initiator, TestCardId1)

	if game_logic.game_state == Enums.GameState.GameState_PlayerDecision and game_logic.active_strike.strike_state == game_logic.StrikeState.StrikeState_Initiator_SetEffects:
		if game_logic.decision_info.type == Enums.DecisionType.DecisionType_GaugeForEffect:
			assert_true(game_logic.do_gauge_for_effect(initiator, init_force_discard), "failed gauge for effect in execute_strike")
		elif game_logic.decision_info.type == Enums.DecisionType.DecisionType_ForceForEffect:
			assert_true(game_logic.do_force_for_effect(initiator, init_force_discard), "failed force for effect in execute_strike")

	if def_ex:
		give_player_specific_card(defender, def_card, TestCardId4)
		all_events += do_strike_response(defender, TestCardId2, TestCardId4)
	elif def_card:
		all_events += do_strike_response(defender, TestCardId2)

	if game_logic.game_state == Enums.GameState.GameState_PlayerDecision and game_logic.active_strike.strike_state == game_logic.StrikeState.StrikeState_Defender_SetEffects:
		game_logic.do_force_for_effect(defender, def_force_discard)

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

func test_hazama_ua():
	position_players(player1, 3, player2, 7)
	give_specific_cards(player1, "standard_normal_assault", player2, "standard_normal_assault")
	do_and_validate_strike(player1, TestCardId1)
	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id]), "failed force for effect")
	assert_true(game_logic.do_choice(player1, 1)) # Use move snake
	assert_true(game_logic.do_choice(player1, 1)) # Place at the 2nd option (+1 range)
	assert_eq(player1.get_buddy_location("ouroboros_move"), 4)
	do_strike_response(player2, TestCardId2)
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 26)

func test_hazama_exceed_ua():
	player1.exceed()
	position_players(player1, 2, player2, 7)
	give_specific_cards(player1, "standard_normal_assault", player2, "standard_normal_assault")
	do_and_validate_strike(player1, TestCardId1)
	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id]), "failed force for effect")
	assert_true(game_logic.do_choice(player1, 1)) # Place move snake first
	assert_true(game_logic.do_choice(player1, 3)) # Place at the 4th option [1,2,3,4]
	assert_true(game_logic.do_choice(player1, 1)) # Place at the 2nd option (0 range)
	assert_eq(player1.get_buddy_location("ouroboros_nothing"), 2)
	assert_eq(player1.get_buddy_location("ouroboros_move"), 4)
	do_strike_response(player2, TestCardId2)
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 26)
	advance_turn(player1)

func test_hazama_exceed_ua_nothing_first():
	player1.exceed()
	position_players(player1, 6, player2, 7)
	give_specific_cards(player1, "standard_normal_dive", player2, "standard_normal_sweep")
	do_and_validate_strike(player1, TestCardId1)
	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id]), "failed force for effect")
	assert_true(game_logic.do_choice(player1, 0)) # Place nothing snake first
	assert_true(game_logic.do_choice(player1, 2)) # Place nothing at the 3rd option [4,5,6,7,8]
	assert_true(game_logic.do_choice(player1, 0)) # Place move at the 1st option
	assert_eq(player1.get_buddy_location("ouroboros_nothing"), 6)
	assert_eq(player1.get_buddy_location("ouroboros_move"), 4)
	do_strike_response(player2, TestCardId2)
	validate_positions(player1, 8, player2, 7)
	validate_life(player1, 30, player2, 25)

func test_hazama_venomsword_hit_end_right():
	position_players(player1, 6, player2, 7)
	execute_strike(player1, player2, "hazama_venomsword", "hazama_venomsword", [], [], false, false, [], [], 0, [])
	validate_positions(player1, 6, player2, 9)
	validate_life(player1, 30, player2, 26)

func test_hazama_venomsword_hit_end_left():
	position_players(player1, 4, player2, 3)
	execute_strike(player1, player2, "hazama_venomsword", "hazama_venomsword", [], [], false, false, [], [], 0, [])
	validate_positions(player1, 4, player2, 1)
	validate_life(player1, 30, player2, 26)

func test_hazama_venomsword_hit_mid():
	position_players(player1, 3, player2, 6)
	execute_strike(player1, player2, "hazama_venomsword", "hazama_venomsword", [], [], false, false, [], [], 0, [])
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 26)

func test_hazama_risingfang_boost_then_sustain_topdiscard_no_discard():
	position_players(player1, 3, player2, 6)
	give_player_specific_card(player1, "hazama_risingfang", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	advance_turn(player2)
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault", [0], [], false, false, [], [], 0, [])
	validate_positions(player1, 5, player2, 6)
	validate_life(player1, 30, player2, 26)

func test_hazama_risingfang_boost_then_sustain_topdiscard_no_choice():
	position_players(player1, 3, player2, 6)
	player1.discard_hand()
	give_player_specific_card(player1, "standard_normal_dive", TestCardId4)
	give_player_specific_card(player1, "hazama_devouringfang", TestCardId5) # boost now draw 1, after if stunned draw 2
	player1.discard([TestCardId5])
	player1.discard([TestCardId4])
	give_player_specific_card(player1, "hazama_risingfang", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	assert_eq(player1.hand.size(), 1)
	advance_turn(player2)
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault", [0], [], false, false, [], [], 0, [])
	validate_positions(player1, 5, player2, 6)
	validate_life(player1, 30, player2, 26)
	assert_eq(player1.continuous_boosts[0].id, TestCardId5)
	assert_eq(player1.hand.size(), 4)

func test_hazama_risingfang_boost_then_sustain_topdiscard_boost_with_choice():
	position_players(player1, 3, player2, 6)
	player1.discard_hand()
	give_player_specific_card(player1, "standard_normal_dive", TestCardId4)
	give_player_specific_card(player1, "hazama_hungrycoils", TestCardId5)
	player1.discard([TestCardId4])
	player1.discard([TestCardId5])
	give_player_specific_card(player1, "hazama_risingfang", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	assert_eq(player1.hand.size(), 1)
	advance_turn(player2)
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault", [0, 0], [], false, false, [], [], 0, [])
	validate_positions(player1, 5, player2, 6)
	validate_life(player1, 30, player2, 26)
	advance_turn(player1)
	assert_eq(player1.continuous_boosts[0].id, TestCardId5)
	assert_eq(player1.hand.size(), 3)


func test_hazama_hungrydarkness_repeatoptionally():
	position_players(player1, 3, player2, 4)
	player1.discard_hand()
	assert_eq(player1.hand.size(), 0)
	give_gauge(player1, 4)
	assert_eq(player2.hand.size(), 6)
	# Should have 6 choices, 1 for each draw
	execute_strike(player1, player2, "hazama_hungrydarkness", "standard_normal_sweep", [0, 0, 0, 0 ,0 ,0], [], false, false, [], [], 0, [])
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 30, player2, 20)
	assert_eq(player1.hand.size(), 6)

func test_hazama_hungrydarkness_repeatoptionally_three():
	position_players(player1, 3, player2, 4)
	player1.discard_hand()
	assert_eq(player1.hand.size(), 0)
	give_gauge(player1, 4)
	assert_eq(player2.hand.size(), 6)
	# Do the effect 3 times then pass
	execute_strike(player1, player2, "hazama_hungrydarkness", "standard_normal_sweep", [0, 0, 0, 1], [], false, false, [], [], 0, [])
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 30, player2, 20)
	assert_eq(player1.hand.size(), 3)

func test_hazama_hungrydarkness_repeatoptionally_1():
	position_players(player1, 3, player2, 4)
	player1.discard_hand()
	assert_eq(player1.hand.size(), 0)
	give_gauge(player1, 4)
	player2.discard_hand()
	give_player_specific_card(player2, "standard_normal_assault", TestCardId3)
	assert_eq(player2.hand.size(), 1)
	# Should still get 1 choice
	execute_strike(player1, player2, "hazama_hungrydarkness", "standard_normal_sweep", [0], [], false, false, [], [], 0, [])
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 30, player2, 25)
	assert_eq(player1.hand.size(), 1)

func test_hazama_hungrycoils_force_reduce_strike():
	position_players(player1, 3, player2, 7)
	give_player_specific_card(player1, "hazama_hungrycoils", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	assert_true(game_logic.do_choice(player1, 0)) # Do the strike
	give_player_specific_card(player2, "standard_normal_assault", TestCardId4)
	give_player_specific_card(player1, "standard_normal_assault", TestCardId5)
	# Set first initiate
	assert_true(game_logic.do_strike(player1, -1, false, -1, true))
	# Opponent sets
	assert_true(game_logic.do_strike(player2, TestCardId4, false, -1, true))
	# Player sets
	assert_true(game_logic.do_strike(player1, TestCardId5, false, -1, true))
	# Ouroboros choice to spend (but force is free)
	assert_true(game_logic.do_force_for_effect(player1, []))
	# Move Ouroboros
	assert_true(game_logic.do_choice(player1, 1))
	# Position it (-1 or +1 range)
	assert_true(game_logic.do_choice(player1, 1))

	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 26)

func test_hazama_hungrycoils_force_reduce_strike_dont_ouro():
	position_players(player1, 3, player2, 7)
	give_player_specific_card(player1, "hazama_hungrycoils", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	assert_true(game_logic.do_choice(player1, 0)) # Do the strike
	give_player_specific_card(player2, "standard_normal_assault", TestCardId4)
	give_player_specific_card(player1, "standard_normal_assault", TestCardId5)
	# Set first initiate
	assert_true(game_logic.do_strike(player1, -1, false, -1, true))
	# Opponent sets
	assert_true(game_logic.do_strike(player2, TestCardId4, false, -1, true))
	# Player sets
	assert_true(game_logic.do_strike(player1, TestCardId5, false, -1, true))
	# Ouroboros choice to spend (but force is free) - cancel it
	assert_true(game_logic.do_force_for_effect(player1, [], true))

	validate_positions(player1, 5, player2, 6)
	validate_life(player1, 26, player2, 30)

func test_hazama_hungrycoils_force_reduce_dont_strike_move():
	position_players(player1, 3, player2, 7)
	give_player_specific_card(player1, "hazama_hungrycoils", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	assert_true(game_logic.do_choice(player1, 1)) # Skip striking
	advance_turn(player2)
	player1.discard_hand()
	assert_true(game_logic.do_move(player1, [], 4))
	advance_turn(player2)

func test_hazama_hungrycoils_force_reduce_dont_strike_move_2():
	position_players(player1, 3, player2, 7)
	give_player_specific_card(player1, "hazama_hungrycoils", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	assert_true(game_logic.do_choice(player1, 1)) # Skip striking
	advance_turn(player2)
	give_player_specific_card(player1, "standard_normal_assault", TestCardId4)
	assert_true(game_logic.do_move(player1, [TestCardId4], 5))
	advance_turn(player2)

func test_hazama_hungrycoils_force_reduce_dont_strike_cc():
	position_players(player1, 3, player2, 7)
	give_player_specific_card(player1, "hazama_hungrycoils", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	assert_true(game_logic.do_choice(player1, 1)) # Skip striking
	advance_turn(player2)
	player1.discard_hand()
	assert_true(game_logic.do_change(player1, []))
	assert_eq(player1.hand.size(), 2)
	advance_turn(player2)

func test_hazama_hungrycoils_force_reduce_dont_strike_cc1():
	position_players(player1, 3, player2, 7)
	give_player_specific_card(player1, "hazama_hungrycoils", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	assert_true(game_logic.do_choice(player1, 1)) # Skip striking
	advance_turn(player2)
	give_player_specific_card(player1, "standard_normal_assault", TestCardId4)
	assert_eq(player1.hand.size(), 7)
	assert_true(game_logic.do_change(player1, [TestCardId4]))
	assert_eq(player1.hand.size(), 9)

func test_hazama_hungrycoils_force_reduce_dont_strike_cc_ultra():
	position_players(player1, 3, player2, 7)
	give_player_specific_card(player1, "hazama_hungrycoils", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	assert_true(game_logic.do_choice(player1, 1)) # Skip striking
	advance_turn(player2)
	give_player_specific_card(player1, "hazama_serpentsinfernalrapture", TestCardId4)
	assert_eq(player1.hand.size(), 7)
	assert_true(game_logic.do_change(player1, [TestCardId4]))
	assert_eq(player1.hand.size(), 10)

func test_hazama_block_with_force_reduced():
	position_players(player1, 5, player2, 7)
	give_player_specific_card(player1, "hazama_hungrycoils", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	assert_true(game_logic.do_choice(player1, 0)) # Do the strike
	give_player_specific_card(player2, "standard_normal_sweep", TestCardId4)
	give_player_specific_card(player1, "standard_normal_block", TestCardId5)
	# Set first initiate
	assert_true(game_logic.do_strike(player1, -1, false, -1, true))
	# Opponent sets
	assert_true(game_logic.do_strike(player2, TestCardId4, false, -1, true))
	# Player sets
	assert_true(game_logic.do_strike(player1, TestCardId5, false, -1, true))
	# Ouroboros choice to spend (but force is free) - cancel it
	assert_true(game_logic.do_force_for_effect(player1, [], true))
	assert_true(game_logic.do_force_for_armor(player1, []))
	# Should be 4 armor
	validate_positions(player1, 5, player2, 7)
	validate_life(player1, 28, player2, 30)
	advance_turn(player2)

func test_hazama_eternalcoils_with_force_reduced():
	position_players(player1, 3, player2, 7)
	give_gauge(player1, 3)
	give_player_specific_card(player1, "hazama_hungrycoils", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	assert_true(game_logic.do_choice(player1, 0)) # Do the strike
	give_player_specific_card(player2, "standard_normal_assault", TestCardId4)
	give_player_specific_card(player1, "hazama_eternalcoils", TestCardId5)
	# Set first initiate
	assert_true(game_logic.do_strike(player1, -1, false, -1, true))
	# Opponent sets
	assert_true(game_logic.do_strike(player2, TestCardId4, false, -1, true))
	# Player sets
	assert_true(game_logic.do_strike(player1, TestCardId5, false, -1, true))
	# Ouroboros choice to spend (but force is free) - cancel it
	assert_true(game_logic.do_force_for_effect(player1, [], true))
	# Pay gauge
	var cards = []
	for i in range(3):
		cards.append(player1.gauge[i].id)
	assert_true(game_logic.do_pay_strike_cost(player1, cards, false))
	# Hit, force for effect up to 5
	# Do just the free, for powerup 1 and pull 8
	assert_true(game_logic.do_force_for_effect(player1, [], false))
	validate_positions(player1, 3, player2, 1)
	validate_life(player1, 30, player2, 26)

func test_hazama_eternalcoils_with_force_reduced_full5():
	position_players(player1, 3, player2, 7)
	give_gauge(player1, 3)
	give_player_specific_card(player1, "hazama_hungrycoils", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	assert_true(game_logic.do_choice(player1, 0)) # Do the strike
	give_player_specific_card(player2, "standard_normal_assault", TestCardId4)
	give_player_specific_card(player1, "hazama_eternalcoils", TestCardId5)
	# Set first initiate
	assert_true(game_logic.do_strike(player1, -1, false, -1, true))
	# Opponent sets
	assert_true(game_logic.do_strike(player2, TestCardId4, false, -1, true))
	# Player sets
	assert_true(game_logic.do_strike(player1, TestCardId5, false, -1, true))
	# Ouroboros choice to spend (but force is free) - cancel it
	assert_true(game_logic.do_force_for_effect(player1, [], true))
	# Pay gauge
	var cards = []
	for i in range(3):
		cards.append(player1.gauge[i].id)
	assert_true(game_logic.do_pay_strike_cost(player1, cards, false))
	# Hit, force for effect up to 5
	# Do just the full 5, paying with 4 normals
	var card_ids = []
	for i in range(4):
		var id = i + TestCardId5 + 1
		give_player_specific_card(player1, "standard_normal_grasp", id)
		card_ids.append(id)
	assert_true(game_logic.do_force_for_effect(player1, card_ids, false))
	validate_positions(player1, 3, player2, 1)
	validate_life(player1, 30, player2, 22)

func test_hazama_v_sagat_crit_mid_opponent_sets_first():
	game_logic.teardown()
	game_logic.free()
	default_game_setup("sagat")
	position_players(player1, 3, player2, 6)
	give_gauge(player2, 1)
	give_player_specific_card(player1, "hazama_hungrycoils", TestCardId1)
	give_player_specific_card(player1, "hazama_devouringfang", TestCardId2)
	give_player_specific_card(player2, "sagat_lowstepkick", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId1))
	# Choose to strike
	assert_true(game_logic.do_choice(player1, 0))
	assert_true(game_logic.do_strike(player1, -1, false, -1, true))
	assert_true(game_logic.do_strike(player2, TestCardId3, false, -1, true))
	assert_true(game_logic.do_gauge_for_effect(player2, [player2.gauge[0].id]))
	assert_true(game_logic.do_strike(player1, TestCardId2, false, -1, true))
	# Pay free effect
	assert_true(game_logic.do_force_for_effect(player1, [], false))
	# Do snake choice to move
	assert_true(game_logic.do_choice(player1, 1))
	# Choose location
	assert_true(game_logic.do_choice(player1, 1))
	# Attack should now play out
	# Pay for devouring fang
	assert_true(game_logic.do_pay_strike_cost(player1, [player1.hand[0].id], false))
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 28, player2, 30)

