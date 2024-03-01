extends GutTest

const LocalGame = preload("res://scenes/game/local_game.gd")
const GameCard = preload("res://scenes/game/game_card.gd")
const Enums = preload("res://scenes/game/enums.gd")
var game_logic : LocalGame
var default_deck = CardDefinitions.get_deck_from_str_id("treasure")
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

func handle_simultaneous_effects(initiator, defender):
	while game_logic.game_state == Enums.GameState.GameState_PlayerDecision and game_logic.decision_info.type == Enums.DecisionType.DecisionType_ChooseSimultaneousEffect:
		var decider = initiator
		if game_logic.decision_info.player == defender.my_id:
			decider = defender
		assert_true(game_logic.do_choice(decider, 0), "Failed simuleffect choice")

func execute_strike(initiator, defender, init_card : String, def_card : String, init_choices, def_choices, init_ex = false, def_ex = false,
		init_use_free_force = false, def_force_discard = [], init_extra_cost = 0, init_force_special = false):
	var all_events = []
	give_specific_cards(initiator, init_card, defender, def_card)
	if init_ex:
		give_player_specific_card(initiator, init_card, TestCardId3)
		do_and_validate_strike(initiator, TestCardId1, TestCardId3)
	else:
		do_and_validate_strike(initiator, TestCardId1)

	if game_logic.game_state == Enums.GameState.GameState_PlayerDecision and game_logic.active_strike.strike_state == game_logic.StrikeState.StrikeState_Initiator_SetEffects:
		assert_true(false, "i dont want to deal with this")

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
			if init_use_free_force and cost > 0:
				cost -= 1
			var cards = []
			for i in range(cost):
				cards.append(initiator.hand[i].id)
			game_logic.do_pay_strike_cost(initiator, cards, false, true, init_use_free_force)
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

func test_treasure_anchor_launch_force_special_discount():
	position_players(player1, 3, player2, 8)
	player1.hand = []
	var other_hand_size = len(player2.hand)

	execute_strike(player1, player2, "treasure_anchorlaunch", "standard_normal_grasp", [], [], false, false, true,
		[], 0, true)
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 30, player2, 24)
	assert_eq(len(player2.hand), other_hand_size-1)
	advance_turn(player2)

func test_treasure_aqua_mine_force_for_effect_discount():
	position_players(player1, 4, player2, 5)

	execute_strike(player1, player2, "treasure_aquamine", "standard_normal_assault", [], [], false, false)
	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id], false, false, true))
	validate_positions(player1, 2, player2, 5)
	validate_life(player1, 26, player2, 25)
	advance_turn(player2)

func test_treasure_block_force_for_armor_discount():
	position_players(player1, 4, player2, 6)

	execute_strike(player1, player2, "standard_normal_block", "standard_normal_sweep", [], [], false, false)
	assert_true(game_logic.do_force_for_armor(player1, [], true))
	validate_positions(player1, 4, player2, 6)
	validate_life(player1, 28, player2, 30)
	advance_turn(player2)

func test_treasure_exceed_move_discount():
	position_players(player1, 4, player2, 7)
	give_gauge(player1, 3)
	assert_true(game_logic.do_exceed(player1, [player1.gauge[0].id, player1.gauge[1].id, player1.gauge[2].id]))
	assert_true(game_logic.do_choice(player1, 3))
	advance_turn(player2)

	assert_true(game_logic.do_move(player1, [player1.hand[0].id], 6, true))
	validate_positions(player1, 6, player2, 7)
	advance_turn(player2)

func test_treasure_anchor_zip_exceed_boost_discount():
	position_players(player1, 4, player2, 7)
	give_gauge(player1, 3)
	player1.hand = []
	assert_true(game_logic.do_exceed(player1, [player1.gauge[0].id, player1.gauge[1].id, player1.gauge[2].id]))
	assert_true(game_logic.do_choice(player1, 3))
	advance_turn(player2)

	give_player_specific_card(player1, "treasure_anchorlaunch", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3, [], true))
	assert_true(game_logic.do_choice(player1, 7))
	validate_positions(player1, 9, player2, 7)
	assert_eq(len(player1.hand), 4)
	advance_turn(player2)

func test_treasure_exceed_change_cards_discard():
	position_players(player1, 4, player2, 7)
	give_gauge(player1, 3)
	assert_true(game_logic.do_exceed(player1, [player1.gauge[0].id, player1.gauge[1].id, player1.gauge[2].id]))
	assert_true(game_logic.do_choice(player1, 3))
	advance_turn(player2)

	player1.hand = []
	assert_true(game_logic.do_change(player1, [], false, true))
	assert_eq(len(player1.hand), 2)
	advance_turn(player2)

func test_treasure_anchor_launch_miss():
	position_players(player1, 1, player2, 3)

	execute_strike(player1, player2, "treasure_anchorlaunch", "standard_normal_grasp", [1], [], false, false, true,
		[], 0, true)
	validate_positions(player1, 7, player2, 3)
	validate_life(player1, 30, player2, 30)
	advance_turn(player2)

func test_treasure_anchor_launch_pull_tinker_tank_to_range_2():
	game_logic.teardown()
	game_logic.free()
	default_game_setup("tinker")

	give_gauge(player2, 5)
	player2.life = 1
	position_players(player1, 3, player2, 4)
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault", [], [], false, false)
	assert_eq(player2.extra_width, 1)
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 20)
	player1.gauge = []

	position_players(player1, 8, player2, 1)
	execute_strike(player1, player2, "treasure_anchorlaunch", "standard_normal_grasp", [], [], false, false, true,
		[], 0, true)
	validate_positions(player1, 8, player2, 5)
	validate_life(player1, 30, player2, 14)
	advance_turn(player2)

func test_treasure_anchor_launch_pull_tinker_tank_at_range_2():
	game_logic.teardown()
	game_logic.free()
	default_game_setup("tinker")

	give_gauge(player2, 5)
	player2.life = 1
	position_players(player1, 3, player2, 4)
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault", [], [], false, false)
	assert_eq(player2.extra_width, 1)
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 20)
	player1.gauge = []

	position_players(player1, 5, player2, 8)
	execute_strike(player1, player2, "treasure_anchorlaunch", "standard_normal_grasp", [], [], false, false, true,
		[], 0, true)
	validate_positions(player1, 5, player2, 8)
	validate_life(player1, 30, player2, 14)
	advance_turn(player2)

func test_treasure_anchor_launch_pull_tinker_tank_at_range_1():
	game_logic.teardown()
	game_logic.free()
	default_game_setup("tinker")

	give_gauge(player2, 5)
	player2.life = 1
	position_players(player1, 3, player2, 4)
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault", [], [], false, false)
	assert_eq(player2.extra_width, 1)
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 20)
	player1.gauge = []

	position_players(player1, 5, player2, 7)
	execute_strike(player1, player2, "treasure_anchorlaunch", "standard_normal_spike", [], [], false, false, true,
		[], 0, true)
	validate_positions(player1, 5, player2, 2)
	validate_life(player1, 30, player2, 14)
	advance_turn(player2)

func test_treasure_anchor_launch_pull_tinker_tank_blocked():
	game_logic.teardown()
	game_logic.free()
	default_game_setup("tinker")

	give_gauge(player2, 5)
	player2.life = 1
	position_players(player1, 3, player2, 4)
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault", [], [], false, false)
	assert_eq(player2.extra_width, 1)
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 20)
	player1.gauge = []

	position_players(player1, 6, player2, 4)
	execute_strike(player1, player2, "treasure_anchorlaunch", "standard_normal_spike", [], [], false, false, true,
		[], 0, true)
	validate_positions(player1, 6, player2, 8)
	validate_life(player1, 30, player2, 14)
	advance_turn(player2)

func test_treasure_dive_charge_full_push():
	position_players(player1, 2, player2, 5)

	execute_strike(player1, player2, "treasure_divecharge", "standard_normal_grasp", [], [], false, false)
	validate_positions(player1, 4, player2, 8)
	validate_life(player1, 30, player2, 27)
	advance_turn(player2)

func test_treasure_dive_charge_focus():
	position_players(player1, 2, player2, 5)

	execute_strike(player1, player2, "treasure_divecharge", "standard_normal_focus", [], [], false, false)
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 26, player2, 26)
	advance_turn(player2)

func test_treasure_dive_charge_wall():
	position_players(player1, 5, player2, 8)

	execute_strike(player1, player2, "treasure_divecharge", "standard_normal_grasp", [], [], false, false)
	validate_positions(player1, 7, player2, 9)
	validate_life(player1, 30, player2, 25)
	advance_turn(player2)

func test_treasure_redistribute_simple():
	position_players(player1, 3, player2, 7)
	give_player_specific_card(player1, "treasure_divecharge", TestCardId3)

	var topdeck_ids = [800001, 800002] # one card drawn at end of turn, one retrieved from boost
	for topdeck_id in topdeck_ids:
		give_player_specific_card(player1, "standard_normal_grasp", topdeck_id)
		player1.move_card_from_hand_to_deck(topdeck_id)

	assert_true(game_logic.do_boost(player1, TestCardId3, [player1.hand[0].id]))
	advance_turn(player2)

	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_grasp", [], [], false, false)
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 30)
	assert_true(TestCardId3 not in player1.underboost_map)
	for topdeck_id in topdeck_ids:
		assert_true(player1.is_card_in_hand(topdeck_id))
	assert_true(player1.is_card_in_discards(TestCardId3))
	advance_turn(player2)

func test_treasure_redistribute_multiple_turns():
	position_players(player1, 3, player2, 7)
	give_player_specific_card(player1, "treasure_divecharge", TestCardId3)

	var topdeck_ids = [800001, 800002, 800003, 800004, 800005, 800006]
	for topdeck_id in topdeck_ids:
		give_player_specific_card(player1, "standard_normal_grasp", topdeck_id)
		player1.move_card_from_hand_to_deck(topdeck_id)

	assert_true(game_logic.do_boost(player1, TestCardId3, [player1.hand[0].id]))
	advance_turn(player2)

	# 2 more cards under boost
	advance_turn(player1)
	advance_turn(player2)
	advance_turn(player1)
	advance_turn(player2)

	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_grasp", [], [], false, false)
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 30)
	assert_true(TestCardId3 not in player1.underboost_map)
	for topdeck_id in topdeck_ids:
		assert_true(player1.is_card_in_hand(topdeck_id))
	assert_true(player1.is_card_in_discards(TestCardId3))
	advance_turn(player2)

func test_treasure_redistribute_teched():
	position_players(player1, 3, player2, 7)
	give_player_specific_card(player1, "treasure_divecharge", TestCardId3)

	var topdeck_ids = [800001, 800002]
	for topdeck_id in topdeck_ids:
		give_player_specific_card(player1, "standard_normal_grasp", topdeck_id)
		player1.move_card_from_hand_to_deck(topdeck_id)

	assert_true(game_logic.do_boost(player1, TestCardId3, [player1.hand[0].id]))

	give_player_specific_card(player2, "standard_normal_dive", TestCardId4)
	assert_true(game_logic.do_boost(player2, TestCardId4, []))
	assert_true(game_logic.do_boost_name_card_choice_effect(player2, TestCardId3))

	for topdeck_id in topdeck_ids:
		assert_true(player1.is_card_in_hand(topdeck_id))
	assert_true(player1.is_card_in_discards(TestCardId3))
	advance_turn(player1)

func test_treasure_treasure_coin_no_discard():
	position_players(player1, 2, player2, 5)

	execute_strike(player1, player2, "treasure_treasurecoin", "standard_normal_grasp", [], [], false, false)
	assert_true(game_logic.do_force_for_effect(player1, [], false, false, true))
	validate_positions(player1, 2, player2, 5)
	validate_life(player1, 30, player2, 26)
	assert_eq(len(player1.gauge), 1)
	advance_turn(player2)

func test_treasure_treasure_coin_coin_discard():
	position_players(player1, 2, player2, 5)
	give_player_specific_card(player1, "treasure_treasurecoin", TestCardId3)
	player1.discard([TestCardId3])

	execute_strike(player1, player2, "treasure_treasurecoin", "standard_normal_grasp", [], [], false, false)
	assert_true(game_logic.do_force_for_effect(player1, [], false, false, true))
	validate_positions(player1, 2, player2, 5)
	validate_life(player1, 30, player2, 26)
	assert_eq(len(player1.gauge), 2)
	advance_turn(player2)

func test_treasure_secure_vault_no_gauge():
	position_players(player1, 2, player2, 5)
	player1.hand = []
	player1.draw(1)
	var old_card_id = player1.hand[0].id
	give_player_specific_card(player1, "treasure_anglercall", TestCardId3)

	assert_true(game_logic.do_boost(player1, TestCardId3, [old_card_id]))
	advance_turn(player2)
	assert_eq(len(player1.hand), 1)
	var hand_card_id = player1.hand[0].id

	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_grasp", [], [], false, false)
	assert_true(game_logic.do_force_for_effect(player1, [hand_card_id], false, false, true))
	validate_positions(player1, 2, player2, 5)
	validate_life(player1, 30, player2, 24)
	assert_eq(len(player1.gauge), 3)
	assert_true(player1.is_card_in_gauge(old_card_id))
	assert_true(player1.is_card_in_gauge(hand_card_id))
	assert_eq(len(player1.hand), 1)
	advance_turn(player2)

func test_treasure_secure_vault_big_gauge():
	position_players(player1, 2, player2, 5)
	give_gauge(player1, 5)
	player1.hand = []
	player1.draw(1)
	var old_card_id = player1.hand[0].id
	give_player_specific_card(player1, "treasure_anglercall", TestCardId3)

	assert_true(game_logic.do_boost(player1, TestCardId3, [old_card_id]))
	advance_turn(player2)
	assert_eq(len(player1.hand), 1)
	var hand_card_id = player1.hand[0].id

	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_grasp", [], [], false, false)
	assert_true(game_logic.do_force_for_effect(player1, [hand_card_id], false, false, true))
	validate_positions(player1, 2, player2, 5)
	validate_life(player1, 30, player2, 24)
	assert_eq(len(player1.gauge), 8)
	assert_true(player1.is_card_in_gauge(old_card_id))
	assert_true(player1.is_card_in_gauge(hand_card_id))
	assert_eq(len(player1.hand), 6)
	advance_turn(player2)

func test_treasure_maelstrom_chest_miss_from_self():
	position_players(player1, 2, player2, 1)
	give_gauge(player1, 3)

	execute_strike(player1, player2, "treasure_maelstromchest", "standard_normal_sweep", [], [], false, false)
	validate_positions(player1, 2, player2, 1)
	validate_life(player1, 24, player2, 30)
	advance_turn(player2)

func test_treasure_maelstrom_chest_hit_from_center():
	position_players(player1, 2, player2, 5)
	give_gauge(player1, 3)

	execute_strike(player1, player2, "treasure_maelstromchest", "standard_normal_sweep", [], [], false, false)
	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id, player1.hand[1].id, player1.hand[2].id], false, false, true))
	validate_positions(player1, 2, player2, 5)
	validate_life(player1, 30, player2, 22)
	advance_turn(player2)

func test_treasure_diving_suit_not_hit():
	position_players(player1, 3, player2, 7)
	give_player_specific_card(player1, "treasure_maelstromchest", TestCardId3)

	assert_true(game_logic.do_boost(player1, TestCardId3, [player1.hand[0].id]))
	advance_turn(player2)

	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_sweep", [], [], false, false)
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 30)
	advance_turn(player2)

func test_treasure_diving_suit_hit():
	position_players(player1, 3, player2, 6)
	give_player_specific_card(player1, "treasure_maelstromchest", TestCardId3)

	assert_true(game_logic.do_boost(player1, TestCardId3, [player1.hand[0].id]))
	advance_turn(player2)

	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_sweep", [], [], false, false)
	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id], false, false, true))
	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 27, player2, 30)
	advance_turn(player2)

func test_treasure_diving_suit_plus_block():
	position_players(player1, 3, player2, 6)
	give_player_specific_card(player1, "treasure_maelstromchest", TestCardId3)

	assert_true(game_logic.do_boost(player1, TestCardId3, [player1.hand[0].id]))
	advance_turn(player2)

	execute_strike(player1, player2, "standard_normal_block", "standard_normal_sweep", [], [], false, true)
	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id], false, false, true))
	assert_true(game_logic.do_force_for_armor(player1, [], true))
	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 30, player2, 30)
	advance_turn(player2)
