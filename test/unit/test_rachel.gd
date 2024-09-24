extends GutTest


var game_logic : LocalGame
var image_loader : CardImageLoader
var default_deck = CardDefinitions.get_deck_from_str_id("rachel")
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
func test_rachel_ua_exceed_pull2():
	position_players(player1, 4, player2, 5)
	player1.exceed()
	assert_true(game_logic.do_character_action(player1, [], 0))
	# Choice
	assert_true(game_logic.do_choice(player1, 3)) # Pull
	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id, player1.hand[1].id], false))
	validate_positions(player1, 4, player2, 2)
	assert_eq(game_logic.active_turn_player, player1.my_id)
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)

func test_rachel_ua_exceed_overdrive():
	position_players(player1, 4, player2, 5)
	give_gauge(player1, 3)
	player1.discard_hand()
	give_player_specific_card(player1, "standard_normal_sweep", TestCardId1)
	assert_true(game_logic.do_exceed(player1, player1.get_card_ids_in_gauge()))
	advance_turn(player2)
	assert_true(game_logic.do_choose_from_discard(player1, [player1.overdrive[0].id]))
	assert_true(game_logic.do_choice(player1, 0)) # Do it
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_ForceStartBoost, player1)
	
	assert_true(game_logic.do_boost(player1, TestCardId1))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)
	advance_turn(player1)

func test_rachel_ua_exceed_overdrive_nocontinuousboosts():
	position_players(player1, 4, player2, 5)
	give_gauge(player1, 3)
	assert_true(game_logic.do_exceed(player1, player1.get_card_ids_in_gauge()))
	# Draw for end of turn
	player1.discard_hand()
	give_player_specific_card(player1, "standard_normal_dive", TestCardId1)
	advance_turn(player2)
	assert_true(game_logic.do_choose_from_discard(player1, [player1.overdrive[0].id]))
	assert_true(game_logic.do_choice(player1, 0)) # Do it
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)
	advance_turn(player1)

func test_rachel_ua_exceed_overdrive_pass():
	position_players(player1, 4, player2, 5)
	give_gauge(player1, 3)
	player1.discard_hand()
	give_player_specific_card(player1, "standard_normal_sweep", TestCardId1)
	assert_true(game_logic.do_exceed(player1, player1.get_card_ids_in_gauge()))
	advance_turn(player2)
	assert_true(game_logic.do_choose_from_discard(player1, [player1.overdrive[0].id]))
	assert_true(game_logic.do_choice(player1, 1))
	assert_eq(game_logic.game_state, Enums.GameState.GameState_PickAction)
	advance_turn(player1)

func test_rachel_lobelia_ex_discardex_1st():
	position_players(player1, 2, player2, 5)
	give_player_specific_card(player1, "rachel_flyinglobelia", TestCardId1)
	give_player_specific_card(player1, "rachel_flyinglobelia", TestCardId2)
	give_player_specific_card(player1, "standard_normal_dive", TestCardId4)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId3)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, TestCardId2))
	assert_true(game_logic.do_strike(player2, TestCardId3, false, -1))
	# Pay for it
	assert_true(game_logic.do_pay_strike_cost(player1, [TestCardId4], false, true))
	validate_positions(player1, 2, player2, 6)
	validate_life(player1, 30, player2, 26)
	# On cleanup, set lightning rod
	assert_true(game_logic.do_choice(player1, 0)) # Place rod (should be lobelia ex copy
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(4)))
	assert_eq(player1.lightningrod_zones[3].size(), 1)
	assert_eq(player1.lightningrod_zones[3][0].id, TestCardId4)
	advance_turn(player2)

func test_rachel_lobelia_ex_discardex_last():
	position_players(player1, 2, player2, 5)
	give_player_specific_card(player1, "rachel_flyinglobelia", TestCardId1)
	give_player_specific_card(player1, "rachel_flyinglobelia", TestCardId2)
	give_player_specific_card(player1, "standard_normal_dive", TestCardId4)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId3)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, TestCardId2))
	assert_true(game_logic.do_strike(player2, TestCardId3, false, -1))
	# Pay for it
	assert_true(game_logic.do_pay_strike_cost(player1, [TestCardId4], false, false))
	validate_positions(player1, 2, player2, 6)
	validate_life(player1, 30, player2, 26)
	# On cleanup, set lightning rod
	assert_true(game_logic.do_choice(player1, 0)) # Place rod (should be lobelia ex copy
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(4)))
	assert_eq(player1.lightningrod_zones[3].size(), 1)
	assert_eq(player1.lightningrod_zones[3][0].id, TestCardId2)
	advance_turn(player2)

func test_rachel_dahlia_discard_ex_first():
	position_players(player1, 2, player2, 5)
	give_gauge(player1, 2)
	give_player_specific_card(player1, "rachel_tempestdahlia", TestCardId1)
	give_player_specific_card(player1, "rachel_tempestdahlia", TestCardId2)
	give_player_specific_card(player1, "standard_normal_dive", TestCardId4)
	player1.move_card_from_hand_to_gauge(TestCardId4)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId3)
	assert_eq(player1.hand.size(), 7)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, TestCardId2))
	assert_true(game_logic.do_strike(player2, TestCardId3, false, -1))
	# Pay for it
	assert_true(game_logic.do_pay_strike_cost(player1, player1.get_card_ids_in_gauge(), false, true))
	# Hit, draw2, push up to 2, then close 2
	assert_eq(player1.hand.size(), 7)
	assert_true(game_logic.do_choice(player1, 0)) # Push 1
	validate_positions(player1, 4, player2, 6)
	validate_life(player1, 30, player2, 24)
	assert_eq(player1.get_top_discard_card().id, TestCardId4)
	assert_eq(player1.gauge.size(), 1)
	advance_turn(player2)

func test_rachel_dahlia_discard_ex_last():
	position_players(player1, 2, player2, 5)
	give_gauge(player1, 2)
	give_player_specific_card(player1, "rachel_tempestdahlia", TestCardId1)
	give_player_specific_card(player1, "rachel_tempestdahlia", TestCardId2)
	give_player_specific_card(player1, "standard_normal_dive", TestCardId4)
	player1.move_card_from_hand_to_gauge(TestCardId4)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId3)
	assert_eq(player1.hand.size(), 7)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, TestCardId2))
	assert_true(game_logic.do_strike(player2, TestCardId3, false, -1))
	# Pay for it
	assert_true(game_logic.do_pay_strike_cost(player1, player1.get_card_ids_in_gauge(), false, false))
	# Hit, draw2, push up to 2, then close 2
	assert_eq(player1.hand.size(), 7)
	assert_true(game_logic.do_choice(player1, 1)) # Push 2
	validate_positions(player1, 4, player2, 7)
	validate_life(player1, 30, player2, 24)
	assert_eq(player1.get_top_discard_card().id, TestCardId2)
	assert_eq(player1.gauge.size(), 1)
	advance_turn(player2)


func test_rachel_whirlwind_boost():
	position_players(player1, 2, player2, 5)
	give_player_specific_card(player1, "rachel_whirlwind", TestCardId1)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId1))
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(5)))
	assert_eq(player1.hand.size(), 7)
	advance_turn(player2)
	assert_eq(player1.boost_id_locations[TestCardId1], 5)
	give_player_specific_card(player1, "rachel_whirlwind", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId2, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId3, false, -1))
	# Hit effects: whirl sustain, boost hit +1 and push/pull 1
	assert_true(game_logic.do_choice(player1, 1))
	assert_true(game_logic.do_choice(player1, 1)) # Pull 1
	# Sustain
	assert_true(game_logic.do_choose_from_boosts(player1, [TestCardId1]))
	validate_positions(player1, 2, player2, 4)
	validate_life(player1, 30, player2, 26)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player1.boost_id_locations[TestCardId1], 5)
	advance_turn(player2)

func test_rachel_spikedrop_boost():
	position_players(player1, 2, player2, 5)
	player1.discard_hand()
	give_player_specific_card(player1, "rachel_spikedrop", TestCardId1)
	assert_true(game_logic.do_boost(player1, TestCardId1))
	var discard_id = player1.discards[2].id
	assert_true(game_logic.do_choose_from_discard(player1, [discard_id]))
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(2)))
	assert_eq(player1.lightningrod_zones[1].size(), 1)
	assert_eq(player1.lightningrod_zones[1][0].id, discard_id)
	assert_false(player1.is_card_in_discards(discard_id))
	advance_turn(player2)

func test_rachel_tinylobelia():
	position_players(player1, 1, player2, 4)
	player1.discard_hand()
	give_player_specific_card(player1, "rachel_tinylobelia", TestCardId1)
	give_player_specific_card(player2, "standard_normal_grasp", TestCardId2)
	var discard_id = player1.get_top_discard_card().id
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	assert_false(player1.is_card_in_discards(discard_id))
	assert_eq(player1.gauge[0].id, discard_id)
	validate_life(player1, 30, player2, 27)
	validate_positions(player1, 1, player2, 4)
	assert_true(game_logic.do_choice(player1, 0)) # Place rod
	assert_true(3 not in game_logic.decision_info.limitation)
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(7)))
	assert_eq(player1.lightningrod_zones[6].size(), 1)
	assert_eq(player1.lightningrod_zones[6][0].id, TestCardId1)
	assert_false(player1.is_card_in_discards(TestCardId1))
	advance_turn(player2)


func test_rachel_electricchair():
	position_players(player1, 1, player2, 4)
	give_player_specific_card(player1, "rachel_electricchair", TestCardId1)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)
	assert_eq(player1.hand.size(), 6)
	assert_true(game_logic.do_boost(player1, TestCardId1))
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(4)))
	assert_eq(player1.hand.size(), 7)
	advance_turn(player2)
	give_player_specific_card(player1, "standard_normal_assault", TestCardId3)
	assert_true(game_logic.do_strike(player1, TestCardId3, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	validate_life(player1, 30, player2, 25)
	validate_positions(player1, 3, player2, 4)
	advance_turn(player1)
	assert_eq(player1.continuous_boosts.size(), 1)
	assert_eq(player1.continuous_boosts[0].id, TestCardId1)
	advance_turn(player2)
	give_player_specific_card(player1, "standard_normal_dive", TestCardId4)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId5)
	assert_true(game_logic.do_strike(player1, TestCardId4, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId5, false, -1))
	validate_life(player1, 26, player2, 24)
	validate_positions(player1, 3, player2, 4)
	assert_eq(player1.continuous_boosts.size(), 1)
	assert_eq(player1.continuous_boosts[0].id, TestCardId1)
	advance_turn(player2)


func test_rachel_dahliageorge():
	position_players(player1, 1, player2, 4)
	give_player_specific_card(player1, "rachel_tempestdahlia", TestCardId1)
	give_player_specific_card(player2, "standard_normal_sweep", TestCardId2)
	assert_eq(player1.hand.size(), 6)
	assert_true(game_logic.do_boost(player1, TestCardId1, [player1.hand[0].id]))
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(4)))
	assert_eq(player1.hand.size(), 6) # Discarded one to pay
	advance_turn(player2)
	give_player_specific_card(player1, "standard_normal_assault", TestCardId3)
	assert_true(game_logic.do_strike(player1, TestCardId3, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	validate_life(player1, 30, player2, 23)
	validate_positions(player1, 3, player2, 4)
	advance_turn(player1)
	assert_eq(player1.continuous_boosts.size(), 0)
	advance_turn(player2)

func test_rachel_badenbadenlily_crossmaphit():
	position_players(player1, 1, player2, 9)
	player1.discard_hand()
	var discard1 = player1.get_top_discard_card().id
	var discard2 = player1.get_top_discard_card().id
	player1.place_top_discard_as_lightningrod(9)
	player1.place_top_discard_as_lightningrod(9)
	give_gauge(player1, 2)
	give_player_specific_card(player1, "rachel_badenbadenlily", TestCardId1)
	give_player_specific_card(player2, "standard_normal_sweep", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	assert_true(game_logic.do_pay_strike_cost(player1, player1.get_card_ids_in_gauge(), false))
	validate_life(player1, 30, player2, 25)
	# After - lily, rod, rod
	assert_true(game_logic.do_choice(player1, 0)) #Lily
	# After advance/retreat up to 2
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(3)))
	validate_positions(player1, 3, player2, 9)
	# Rod 1
	assert_true(game_logic.do_choice(player1, 0))
	assert_true(game_logic.do_choice(player1, 0)) # Rod hit
	validate_life(player1, 30, player2, 23)
	# Rod 2
	assert_true(game_logic.do_choice(player1, 0)) # Rod hit
	validate_life(player1, 30, player2, 21)
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_Strike_Stun, player2)
	assert_eq(player1.gauge.size(), 1)
	assert_true(player1.is_card_in_hand(discard1))
	assert_true(player1.is_card_in_hand(discard2))
	advance_turn(player2)


func test_rachel_badenbadenlily_hit0():
	position_players(player1, 8, player2, 7)
	player1.discard_hand()
	var discard1 = player1.get_top_discard_card().id
	var discard2 = player1.get_top_discard_card().id
	player1.place_top_discard_as_lightningrod(9)
	player1.place_top_discard_as_lightningrod(9)
	give_gauge(player1, 2)
	give_player_specific_card(player1, "rachel_badenbadenlily", TestCardId1)
	give_player_specific_card(player2, "standard_normal_sweep", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	assert_true(game_logic.do_pay_strike_cost(player1, player1.get_card_ids_in_gauge(), false))
	validate_life(player1, 30, player2, 27)
	# After - lily, rod, rod
	assert_true(game_logic.do_choice(player1, 0)) #Lily
	# After advance/retreat up to 2
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(5)))
	validate_positions(player1, 5, player2, 7)
	# Rod 1 and 2 auto fail
	validate_life(player1, 24, player2, 27)
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_Strike_Stun, player1)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player2.gauge.size(), 1)
	assert_false(player1.is_card_in_hand(discard1))
	assert_false(player1.is_card_in_hand(discard2))
	assert_false(player1.is_card_in_discards(discard1))
	assert_false(player1.is_card_in_discards(discard2))
	advance_turn(player2)


func test_rachel_badenbadenlily_boost():
	position_players(player1, 1, player2, 7)
	player1.discard_hand()
	player1.place_top_discard_as_lightningrod(3)
	player1.place_top_discard_as_lightningrod(5)
	player1.place_top_discard_as_lightningrod(7)
	player1.place_top_discard_as_lightningrod(9)
	give_player_specific_card(player1, "rachel_badenbadenlily", TestCardId1)
	give_player_specific_card(player1, "rachel_badenbadenlily", TestCardId2)
	assert_true(game_logic.do_boost(player1, TestCardId1, [TestCardId2]))
	# Valid choices are 3,5,6
	assert_eq(game_logic.decision_info.limitation.size(), 4)
	assert_true(3 in game_logic.decision_info.limitation)
	assert_true(5 in game_logic.decision_info.limitation)
	assert_true(6 in game_logic.decision_info.limitation)
	assert_true(9 in game_logic.decision_info.limitation)
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(6)))
	validate_positions(player1, 6, player2, 7)
	advance_turn(player1)
	advance_turn(player2)


func test_rachel_badenbadenlily_boost2():
	position_players(player1, 1, player2, 7)
	player1.discard_hand()
	player1.place_top_discard_as_lightningrod(3)
	player1.place_top_discard_as_lightningrod(5)
	player1.place_top_discard_as_lightningrod(7)
	player1.place_top_discard_as_lightningrod(9)
	give_player_specific_card(player1, "rachel_badenbadenlily", TestCardId1)
	give_player_specific_card(player1, "rachel_badenbadenlily", TestCardId2)
	assert_true(game_logic.do_boost(player1, TestCardId1, [TestCardId2]))
	# Valid choices are 3,5,6, 9
	assert_eq(game_logic.decision_info.limitation.size(), 4)
	assert_true(3 in game_logic.decision_info.limitation)
	assert_true(5 in game_logic.decision_info.limitation)
	assert_true(6 in game_logic.decision_info.limitation)
	assert_true(9 in game_logic.decision_info.limitation)
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(9)))
	validate_positions(player1, 9, player2, 7)
	advance_turn(player1)
	advance_turn(player2)

func test_rachel_badenbadenlily_boost_none():
	position_players(player1, 1, player2, 7)
	player1.discard_hand()
	give_player_specific_card(player1, "rachel_badenbadenlily", TestCardId1)
	give_player_specific_card(player1, "rachel_badenbadenlily", TestCardId2)
	assert_true(game_logic.do_boost(player1, TestCardId1, [TestCardId2]))
	validate_positions(player1, 1, player2, 7)
	advance_turn(player1)
	advance_turn(player2)


func test_rachel_badenbadenlily_boost_cantmove():
	position_players(player1, 1, player2, 7)
	player1.discard_hand()
	player1.place_top_discard_as_lightningrod(3)
	player1.place_top_discard_as_lightningrod(5)
	player1.place_top_discard_as_lightningrod(7)
	player1.place_top_discard_as_lightningrod(9)
	player1.cannot_move = true
	give_player_specific_card(player1, "rachel_badenbadenlily", TestCardId1)
	give_player_specific_card(player1, "rachel_badenbadenlily", TestCardId2)
	assert_true(game_logic.do_boost(player1, TestCardId1, [TestCardId2]))
	validate_positions(player1, 1, player2, 7)
	advance_turn(player1)
	advance_turn(player2)

func test_rachel_badenbadenlily_boost_cantmove_past():
	position_players(player1, 7, player2, 5)
	player1.discard_hand()
	player1.place_top_discard_as_lightningrod(3)
	player1.place_top_discard_as_lightningrod(5)
	player1.place_top_discard_as_lightningrod(7)
	player1.place_top_discard_as_lightningrod(9)
	player1.cannot_move_past_opponent = true
	give_player_specific_card(player1, "rachel_badenbadenlily", TestCardId1)
	give_player_specific_card(player1, "rachel_badenbadenlily", TestCardId2)
	assert_true(game_logic.do_boost(player1, TestCardId1, [TestCardId2]))
	# Valid choices are 6, 9
	assert_eq(game_logic.decision_info.limitation.size(), 2)
	assert_true(6 in game_logic.decision_info.limitation)
	assert_true(9 in game_logic.decision_info.limitation)
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(6)))
	validate_positions(player1, 6, player2, 5)
	advance_turn(player1)
	advance_turn(player2)

func test_rachel_spikedrop_george():
	position_players(player1, 7, player2, 5)
	
	give_player_specific_card(player1, "rachel_tempestdahlia", TestCardId2)
	assert_true(game_logic.do_boost(player1, TestCardId2, [player1.hand[0].id]))
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(5)))
	advance_turn(player2)
	give_player_specific_card(player1, "rachel_spikedrop", TestCardId1)
	give_player_specific_card(player2, "standard_normal_focus", TestCardId3)
	give_player_specific_card(player2, "standard_normal_focus", TestCardId4)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId3, false, TestCardId4))
	# Spike drop hits for 5 ignoring armor
	# After George does 3 blocked by armor
	validate_positions(player1, 7, player2, 5)
	validate_life(player1, 25, player2, 25)
	advance_turn(player2)
