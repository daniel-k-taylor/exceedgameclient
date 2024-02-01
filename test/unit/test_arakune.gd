extends GutTest

const LocalGame = preload("res://scenes/game/local_game.gd")
const GameCard = preload("res://scenes/game/game_card.gd")
const Enums = preload("res://scenes/game/enums.gd")
var game_logic : LocalGame
var default_deck = CardDefinitions.get_deck_from_str_id("arakune")
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
func test_arakune_exceed_and_strike_with_bonus():
	position_players(player1, 3, player2, 4)
	give_gauge(player1, 3)
	give_player_specific_card(player1, "standard_normal_assault", TestCardId3)
	player1.move_cards_to_overdrive([TestCardId3], "hand")
	var card_ids_gauge = []
	for i in range(3):
		card_ids_gauge.append(player1.gauge[i].id)
	player1.move_cards_to_overdrive([player1.deck[0].id], "deck")
	player1.move_cards_to_overdrive([player1.deck[0].id], "deck")
	player1.move_cards_to_overdrive([player1.deck[0].id], "deck")
	player1.move_cards_to_overdrive([player1.deck[0].id], "deck")
	assert_eq(player1.overdrive.size(), 5)
	assert_eq(player1.hand.size(), 5)
	assert_true(game_logic.do_exceed(player1, card_ids_gauge))
	assert_eq(player1.hand.size(), 7)
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_cross", [], [], false, false, [], [], 0, [])
	# Reveal effect
	assert_true(game_logic.do_choose_from_discard(player1, [TestCardId3]))
	# Do overdrive effect
	var topdeck_id = player1.deck[0].id
	assert_true(game_logic.do_choice(player1, 0))
	assert_eq(player1.sealed[0].id, topdeck_id)
	validate_life(player1, 30, player2, 24)
	# Next turn, overdrive effect
	assert_true(game_logic.do_choose_from_discard(player1, [player1.overdrive[0].id]))
	topdeck_id = player1.deck[0].id
	assert_true(game_logic.do_choice(player1, 0))
	assert_eq(player1.sealed[1].id, topdeck_id)
	# Check that I can end my turn from assault.
	advance_turn(player1)

func test_arakune_exceed_and_strike_with_bonus_finverse_range1():
	position_players(player1, 3, player2, 4)
	give_player_specific_card(player1, "standard_normal_grasp", TestCardId3)
	player1.move_cards_to_overdrive([TestCardId3], "hand")
	give_gauge(player1, 6)
	var card_ids_gauge = []
	for i in range(3):
		card_ids_gauge.append(player1.gauge[i].id)
	player1.move_cards_to_overdrive([player1.deck[0].id], "deck")
	player1.move_cards_to_overdrive([player1.deck[0].id], "deck")
	player1.move_cards_to_overdrive([player1.deck[0].id], "deck")
	player1.move_cards_to_overdrive([player1.deck[0].id], "deck")
	assert_eq(player1.overdrive.size(), 5)
	assert_eq(player1.hand.size(), 5)
	assert_true(game_logic.do_exceed(player1, card_ids_gauge))
	assert_eq(player1.gauge.size(), 3)
	assert_eq(player1.hand.size(), 7)
	execute_strike(player1, player2, "arakune_finverse", "standard_normal_cross", [], [], false, false, [], [], 0, [])
	# Reveal effect
	assert_true(game_logic.do_choose_from_discard(player1, [TestCardId3]))
	# Do overdrive effect
	var topdeck_id = player1.deck[0].id
	assert_true(game_logic.do_choice(player1, 0))
	assert_eq(player1.sealed[0].id, topdeck_id)
	# Pay cost
	assert_true(game_logic.do_pay_strike_cost(player1, [player1.gauge[0].id, player1.gauge[1].id, player1.gauge[2].id], false))
	# After effect
	assert_true(game_logic.do_choice(player1, 0))
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 30, player2, 22)
	advance_turn(player2)
	# Next turn, overdrive effect
	assert_true(game_logic.do_choose_from_discard(player1, [player1.overdrive[0].id]))
	topdeck_id = player1.deck[0].id
	assert_true(game_logic.do_choice(player1, 0))
	assert_eq(player1.sealed[1].id, topdeck_id)
	# Check that I can end my turn from assault.
	advance_turn(player1)

func test_arakune_exceed_and_strike_with_bonus_wildswing_finverse_wildswing():
	position_players(player1, 3, player2, 4)
	give_player_specific_card(player1, "standard_normal_grasp", TestCardId3)
	player1.move_cards_to_overdrive([TestCardId3], "hand")
	give_gauge(player1, 6)
	var card_ids_gauge = []
	for i in range(3):
		card_ids_gauge.append(player1.gauge[i].id)
	player1.move_cards_to_overdrive([player1.deck[0].id], "deck")
	player1.move_cards_to_overdrive([player1.deck[0].id], "deck")
	player1.move_cards_to_overdrive([player1.deck[0].id], "deck")
	player1.move_cards_to_overdrive([player1.deck[0].id], "deck")
	assert_eq(player1.overdrive.size(), 5)
	assert_eq(player1.hand.size(), 5)
	assert_true(game_logic.do_exceed(player1, card_ids_gauge))
	assert_eq(player1.gauge.size(), 3)
	assert_eq(player1.hand.size(), 7)
	give_player_specific_card(player1, "standard_normal_assault", TestCardId4)
	give_player_specific_card(player1, "arakune_finverse", TestCardId5)
	player1.move_card_from_hand_to_deck(TestCardId4, 0)
	player1.move_card_from_hand_to_deck(TestCardId5, 0)
	# Do a wild swing into finverse
	execute_strike(player1, player2, "", "standard_normal_grasp", [], [], false, false, [], [], 0, [])
	# Reveal effect
	assert_true(game_logic.do_choose_from_discard(player1, [TestCardId3]))
	# Do overdrive effect, don't seal
	var topdeck_id = player1.deck[0].id
	assert_true(game_logic.do_choice(player1, 1))
	assert_eq(player1.sealed.size(), 0)
	# Pay cost wild swing into assault
	assert_true(game_logic.do_pay_strike_cost(player1, [], true))
	# p2 hits with grasp
	assert_true(game_logic.do_choice(player2, 1))
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 30, player2, 24)
	# GAIN ADVANTAGE, Next turn, overdrive effect
	assert_true(game_logic.do_choose_from_discard(player1, [player1.overdrive[0].id]))
	topdeck_id = player1.deck[0].id
	assert_true(game_logic.do_choice(player1, 0))
	assert_eq(player1.sealed[0].id, topdeck_id)
	# Check that I can end my turn from assault.
	advance_turn(player1)

func test_arakune_exceed_and_strike_without_bonus():
	position_players(player1, 3, player2, 4)
	give_gauge(player1, 3)
	give_player_specific_card(player1, "standard_normal_dive", TestCardId3)
	player1.move_cards_to_overdrive([TestCardId3], "hand")
	var card_ids_gauge = []
	for i in range(3):
		card_ids_gauge.append(player1.gauge[i].id)
	player1.move_cards_to_overdrive([player1.deck[0].id], "deck")
	player1.move_cards_to_overdrive([player1.deck[0].id], "deck")
	player1.move_cards_to_overdrive([player1.deck[0].id], "deck")
	player1.move_cards_to_overdrive([player1.deck[0].id], "deck")
	assert_eq(player1.overdrive.size(), 5)
	assert_eq(player1.hand.size(), 5)
	assert_true(game_logic.do_exceed(player1, card_ids_gauge))
	assert_eq(player1.hand.size(), 7)
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_cross", [], [], false, false, [], [], 0, [])
	# Reveal effect
	assert_true(game_logic.do_choose_from_discard(player1, [TestCardId3]))
	# Do overdrive effect
	var topdeck_id = player1.deck[0].id
	assert_true(game_logic.do_choice(player1, 0))
	assert_eq(player1.sealed[0].id, topdeck_id)
	validate_life(player1, 27, player2, 30)
	validate_positions(player1, 3, player2, 7)
	advance_turn(player2)
	# Next turn, overdrive effect
	assert_true(game_logic.do_choose_from_discard(player1, [player1.overdrive[0].id]))
	topdeck_id = player1.deck[0].id
	assert_true(game_logic.do_choice(player1, 0))
	assert_eq(player1.sealed[1].id, topdeck_id)
	# Check that I can end my turn correctly.
	advance_turn(player1)

func test_arakune_disjointunion_nodiscards():
	position_players(player1, 3, player2, 4)
	execute_strike(player1, player2, "arakune_disjointunion", "standard_normal_sweep", [0], [], false, false, [], [], 0, [])
	validate_positions(player1, 3, player2, 7)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player1.overdrive.size(), 0)
	validate_life(player1, 30, player2, 27)
	advance_turn(player2)

func test_arakune_ability_disjointunion_notstunned():
	player1.discard_hand()
	var top_discard_id = player1.discards[player1.discards.size() - 1].id
	position_players(player1, 3, player2, 4)
	execute_strike(player1, player2, "arakune_disjointunion", "standard_normal_sweep", [0, 0], [], false, false, [], [], 0, [])
	validate_positions(player1, 3, player2, 7)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player1.overdrive.size(), 1)
	assert_eq(player1.overdrive[0].id, top_discard_id)
	validate_life(player1, 30, player2, 27)

func test_arakune_ability_disjointunion_stunned():
	player1.discard_hand()
	var top_discard_id = player1.discards[player1.discards.size() - 1].id
	var top_2nd_discard_id = player1.discards[player1.discards.size() - 2].id
	position_players(player1, 3, player2, 4)
	execute_strike(player1, player2, "arakune_disjointunion", "standard_normal_assault", [0, 0], [], false, false, [], [], 0, [])
	validate_positions(player1, 3, player2, 7)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player1.overdrive.size(), 2)
	assert_eq(player1.overdrive[0].id, top_discard_id)
	assert_eq(player1.overdrive[1].id, top_2nd_discard_id)
	validate_life(player1, 30, player2, 27)

func test_arakune_disjointunion_boost():
	give_player_specific_card(player1, "arakune_disjointunion", TestCardId3)
	position_players(player1, 3, player2, 4)
	assert_eq(player1.hand.size(), 6)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault", [], [], false, false, [], [], 0, [])
	assert_eq(player1.hand.size(), 6)
	validate_positions(player1, 3, player2, 4)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player1.overdrive.size(), 1)
	assert_eq(player1.overdrive[0].id, TestCardId3)
	validate_life(player1, 30, player2, 26)

func test_arakune_ifpthenq_boost():
	give_player_specific_card(player1, "arakune_ifpthenq", TestCardId3)
	player1.move_cards_to_overdrive([player1.hand[0].id], "hand")
	position_players(player1, 3, player2, 4)
	assert_eq(player1.hand.size(), 5)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	assert_eq(player1.hand.size(), 6)
	advance_turn(player2)
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_grasp", [], [], false, false, [], [], 0, [])
	validate_positions(player1, 3, player2, 4)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player1.overdrive.size(), 1)
	validate_life(player1, 30, player2, 26)

func test_arakune_ifpthenq_go_to_overdrive():
	position_players(player1, 3, player2, 1)
	var card_discarded_for_force = player1.hand[0].id
	execute_strike(player1, player2, "arakune_ifpthenq", "standard_normal_cross", [0, 0, 0], [], false, false, [], [], 0, [])
	validate_positions(player1, 2, player2, 1)
	assert_eq(player1.gauge.size(), 0)
	assert_eq(player1.overdrive.size(), 2)
	assert_eq(player1.overdrive[0].id, card_discarded_for_force)
	assert_eq(player1.overdrive[1].id, TestCardId1)
	validate_life(player1, 30, player2, 30)
	advance_turn(player2)

func test_arakune_ifpthenq_go_to_overdrive_miss():
	position_players(player1, 3, player2, 1)
	execute_strike(player1, player2, "arakune_ifpthenq", "standard_normal_cross", [1, 0], [], false, false, [], [], 0, [])
	validate_positions(player1, 3, player2, 1)
	assert_eq(player1.gauge.size(), 0)
	assert_eq(player1.overdrive.size(), 1)
	assert_eq(player1.overdrive[0].id, TestCardId1)
	validate_life(player1, 30, player2, 30)
	advance_turn(player2)

func test_arakune_ytwodash_boostandattack():
	position_players(player1, 2, player2, 3)
	give_player_specific_card(player1, "arakune_ytwodash", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	advance_turn(player2)
	execute_strike(player1, player2, "arakune_ytwodash", "standard_normal_grasp", [1], [], false, false, [], [], 0, [])
	validate_positions(player1, 6, player2, 3)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player1.overdrive.size(), 0)
	validate_life(player1, 30, player2, 25)
	advance_turn(player2)

func test_arakune_permutationnr_attack():
	position_players(player1, 2, player2, 1)
	execute_strike(player1, player2, "arakune_permutationnr", "standard_normal_cross", [], [], false, false, [], [], 0, [])
	# permutation force for effect
	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id, player1.hand[1].id, player1.hand[2].id], false))
	# on hit simultaneous, card first
	assert_true(game_logic.do_choice(player1, 0))
	assert_eq(player1.overdrive.size(), 1)
	# char effect choice, has force paid in discard
	assert_true(game_logic.do_choice(player1, 0))
	validate_positions(player1, 2, player2, 1)
	assert_eq(player1.gauge.size(), 1)
	# 1 card from discarded opponent, 1 from discard force
	assert_eq(player1.overdrive.size(), 2)
	validate_life(player1, 28, player2, 25)
	advance_turn(player2)

func test_arakune_permutationnr_attack_far_pay_ultra():
	position_players(player1, 2, player2, 4)
	execute_strike(player1, player2, "arakune_permutationnr", "standard_normal_cross", [], [], false, false, [], [], 0, [])
	validate_positions(player1, 2, player2, 7)
	# permutation force for effect - needs to pay only 1 force to bring 7 down to 5
	give_player_specific_card(player1, "arakune_ntoinfinity", TestCardId4)
	assert_true(game_logic.do_force_for_effect(player1, [TestCardId4], true))
	# on hit simultaneous, card first
	assert_true(game_logic.do_choice(player1, 0))
	assert_eq(player1.overdrive.size(), 1)
	# char effect choice, has force paid in discard
	assert_true(game_logic.do_choice(player1, 0))
	validate_positions(player1, 2, player2, 7)
	assert_eq(player1.gauge.size(), 1)
	# 1 card from discarded opponent, 1 from discard force
	assert_eq(player1.overdrive.size(), 2)
	validate_life(player1, 28, player2, 25)
	advance_turn(player2)

func test_arakune_permutationnr_boost_give_card():
	position_players(player1, 2, player2, 1)
	give_player_specific_card(player1, "arakune_permutationnr", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	# Opponent chooses 0 - add card from hand to opponent's OD, 1 - reveal hand/topdeck
	assert_true(game_logic.do_choice(player2, 0))
	var discarded_id = player2.hand[0].id
	assert_true(game_logic.do_choose_to_discard(player2, [discarded_id]))
	assert_eq(player2.hand.size(), 5)
	advance_turn(player2)
	assert_eq(player1.overdrive.size(), 1)
	assert_eq(player1.overdrive[0].id, discarded_id)

func test_arakune_permutationnr_boost_reveal():
	position_players(player1, 2, player2, 1)
	give_player_specific_card(player1, "arakune_permutationnr", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	# Opponent chooses 0 - add card from hand to opponent's OD, 1 - reveal hand/topdeck
	assert_true(game_logic.do_choice(player2, 1))
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_RevealHand, player2)
	validate_has_event(events, Enums.EventType.EventType_RevealTopDeck, player2)
	advance_turn(player2)

func test_arakune_piecewise_odd_miss():
	position_players(player1, 2, player2, 3)
	execute_strike(player1, player2, "arakune_fpiecewise", "standard_normal_sweep", [], [], false, false, [], [], 0, [])
	# fpiecewise range effect
	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id], false))
	# miss, after advance/retreat
	assert_true(game_logic.do_choice(player1, 0))
	validate_positions(player1, 5, player2, 3)
	assert_eq(player1.gauge.size(), 0)
	assert_eq(player2.gauge.size(), 1)
	validate_life(player1, 24, player2, 30)
	advance_turn(player2)

func test_arakune_piecewise_even_hit():
	position_players(player1, 2, player2, 4)
	execute_strike(player1, player2, "arakune_fpiecewise", "standard_normal_sweep", [], [], false, false, [], [], 0, [])
	# fpiecewise range effect
	give_player_specific_card(player1, "standard_normal_assault", TestCardId4)
	var discarded_id = TestCardId4
	assert_true(game_logic.do_force_for_effect(player1, [discarded_id], false))
	# hit, discarded force to OD
	assert_true(game_logic.do_choice(player1, 0))
	assert_eq(player1.overdrive.size(), 1)
	assert_eq(player1.overdrive[0].id, discarded_id)
	#advance/retreat
	assert_true(game_logic.do_choice(player1, 0))
	validate_positions(player1, 5, player2, 4)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player2.gauge.size(), 1)
	validate_life(player1, 24, player2, 24)
	advance_turn(player2)

func test_arakune_piecewise_boost():
	position_players(player1, 2, player2, 4)
	give_player_specific_card(player1, "arakune_fpiecewise", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	var id_of_assault = -1
	for card in player1.deck_list:
		if card.definition['display_name'] == "Assault":
			id_of_assault = card.id
			break
	assert_true(game_logic.do_boost_name_card_choice_effect(player1, id_of_assault))
	# Prep top decks
	give_player_specific_card(player1, "standard_normal_sweep", TestCardId4)
	give_player_specific_card(player2, "standard_normal_spike", TestCardId5)
	player1.move_card_from_hand_to_deck(TestCardId4, 0)
	player2.move_card_from_hand_to_deck(TestCardId5, 0)
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault", [], [], false, false, [], [], 0, [])
	# Assaults are invalid, so the wild swings both happen
	validate_positions(player1, 2, player2, 4)
	assert_eq(player1.gauge.size(), 0)
	assert_eq(player2.gauge.size(), 1)
	# Noa fter effect because stunned.
	assert_eq(player1.overdrive.size(), 0)
	validate_life(player1, 25, player2, 30)
	advance_turn(player2)

func test_arakune_finverse_boost():
	position_players(player1, 2, player2, 4)
	give_player_specific_card(player1, "arakune_finverse", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	var cards_on_topdeck = []
	for i in range(5):
		cards_on_topdeck.append(player1.deck[i].id)
	assert_true(game_logic.do_choose_from_topdeck(player1, cards_on_topdeck[3], "add_to_sealed"))
	assert_true(game_logic.do_choose_from_topdeck(player1, cards_on_topdeck[0], "add_to_gauge"))
	assert_true(game_logic.do_choose_from_topdeck(player1, cards_on_topdeck[2], "add_to_overdrive"))
	assert_true(game_logic.do_choose_from_topdeck(player1, cards_on_topdeck[4], "add_to_topdeck_under"))
	advance_turn(player2)
	assert_eq(player1.sealed[0].id, cards_on_topdeck[3])
	assert_eq(player1.gauge[0].id, cards_on_topdeck[0])
	assert_eq(player1.overdrive[0].id, cards_on_topdeck[2])
	assert_eq(player1.deck[0].id, cards_on_topdeck[4])
	assert_eq(player1.hand[player1.hand.size()-1].id, cards_on_topdeck[1])

func test_arakune_finverse_boost_4_in_deck():
	position_players(player1, 2, player2, 4)
	player1.discards = player1.deck
	player1.deck = []
	# Get 4 cards exactly in deck
	player1.move_card_from_discard_to_deck(player1.discards[0].id)
	player1.move_card_from_discard_to_deck(player1.discards[0].id)
	player1.move_card_from_discard_to_deck(player1.discards[0].id)
	player1.move_card_from_discard_to_deck(player1.discards[0].id)
	give_player_specific_card(player1, "arakune_finverse", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	var cards_on_topdeck = []
	for i in range(4):
		cards_on_topdeck.append(player1.deck[i].id)
	assert_true(game_logic.do_choose_from_topdeck(player1, cards_on_topdeck[0], "add_to_sealed"))
	assert_true(game_logic.do_choose_from_topdeck(player1, cards_on_topdeck[3], "add_to_gauge"))
	assert_true(game_logic.do_choose_from_topdeck(player1, cards_on_topdeck[2], "add_to_overdrive"))
	assert_true(game_logic.do_choose_from_topdeck(player1, cards_on_topdeck[1], "add_to_topdeck_under"))
	advance_turn(player2)
	assert_eq(player1.sealed[0].id, cards_on_topdeck[0])
	assert_eq(player1.gauge[0].id, cards_on_topdeck[3])
	assert_eq(player1.overdrive[0].id, cards_on_topdeck[2])
	assert_eq(player1.hand[player1.hand.size()-1].id, cards_on_topdeck[1])

func test_arakune_finverse_boost_3_in_deck():
	position_players(player1, 2, player2, 4)
	player1.discards = player1.deck
	player1.deck = []
	# Get 4 cards exactly in deck
	player1.move_card_from_discard_to_deck(player1.discards[0].id)
	player1.move_card_from_discard_to_deck(player1.discards[0].id)
	player1.move_card_from_discard_to_deck(player1.discards[0].id)
	give_player_specific_card(player1, "arakune_finverse", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	var cards_on_topdeck = []
	for i in range(3):
		cards_on_topdeck.append(player1.deck[i].id)
	assert_true(game_logic.do_choose_from_topdeck(player1, cards_on_topdeck[2], "add_to_sealed"))
	assert_true(game_logic.do_choose_from_topdeck(player1, cards_on_topdeck[0], "add_to_gauge"))
	assert_true(game_logic.do_choose_from_topdeck(player1, cards_on_topdeck[1], "add_to_overdrive"))
	advance_turn(player2)
	assert_eq(player1.sealed[0].id, cards_on_topdeck[2])
	assert_eq(player1.gauge[0].id, cards_on_topdeck[0])
	assert_eq(player1.overdrive[0].id, cards_on_topdeck[1])
	# Reshuffle
	assert_eq(player1.discards.size(), 0)

func test_arakune_n_uberdeath():
	position_players(player1, 2, player2, 6)
	give_gauge(player1, 4)
	execute_strike(player1, player2, "arakune_ntoinfinity", "standard_normal_dive", [0], [], false, false, [], [], 0, [])
	validate_life(player1, 30, player2, 30-(5 + 99))
	assert_true(game_logic.game_over)
