extends GutTest


var game_logic : LocalGame
var image_loader : CardImageLoader
var default_deck = CardDefinitions.get_deck_from_str_id("polar")
const TestCardId1 = 50001
const TestCardId2 = 50002
const TestCardId3 = 50003
const TestCardId4 = 50004
const TestCardId5 = 50005

var player1 : Player
var player2 : Player

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

##
## Tests start here
##

func validate_spikes(locations, player = player1):
	var buddy_locs = player.buddy_locations.duplicate()
	for loc in locations:
		assert_true(loc in buddy_locs, "validate_spikes() - Missing location %s from buddy locations" % str(loc))
		buddy_locs.erase(loc)

func get_choice_index_for_position(pos):
	for i in range(game_logic.decision_info.limitation.size()):
		var choice_pos = game_logic.decision_info.limitation[i]
		if pos == choice_pos:
			return i
	assert(false, "Unable to find choice index")
	fail_test("Unable to find choice index")
	return 0

func test_polar_exceed_empty_board():
	position_players(player1, 3, player2, 4)
	give_gauge(player1, 3)
	assert_true(game_logic.do_exceed(player1, player1.get_card_ids_in_gauge()))
	# Place spike anywhere, 1-9
	assert_eq(game_logic.decision_info.choice.size(), 9) # All 9 options.
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(3)))
	validate_spikes([3,-1,-1,-1,-1])
	assert_eq(game_logic.decision_info.choice.size(), 9) # All 9 options because you can move them too.
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(4)))
	validate_spikes([3,4,-1,-1,-1])
	assert_eq(game_logic.decision_info.choice.size(), 9) # All 9 options because you can move them too.
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(3)))
	validate_spikes([-1,4,-1,-1,-1])
	assert_eq(game_logic.decision_info.choice.size(), 8) # Only 8 options because you can put it back and 4 is full.
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(2)))
	validate_spikes([2,4,-1,-1,-1])
	advance_turn(player2)

func test_polar_exceed_mostlyfull_board():
	position_players(player1, 3, player2, 4)
	player1.buddy_locations = [1,2,3,4,-1]
	give_gauge(player1, 3)
	assert_true(game_logic.do_exceed(player1, player1.get_card_ids_in_gauge()))
	# Place spike anywhere, 1-9
	assert_eq(game_logic.decision_info.choice.size(), 9) # All 9 options because you can move them too.
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(6)))
	validate_spikes([1,2,3,4,6])
	assert_eq(game_logic.decision_info.choice.size(), 5) # Must remove a spike first
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(4)))
	validate_spikes([1,2,3,6,-1])
	assert_eq(game_logic.decision_info.choice.size(), 5) # Only 5 locations to place it because you can put it back
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(8)))
	validate_spikes([1,2,3,6,8])
	assert_eq(game_logic.decision_info.choice.size(), 5) # Remove a spike again.
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(2)))
	validate_spikes([1,3,6,8,-1])
	assert_eq(game_logic.decision_info.choice.size(), 5) # Only 5 locations to place it.
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(5)))
	validate_spikes([1,3,6,8,5])
	advance_turn(player2)

func test_polar_max_spikes_no_empty():
	position_players(player1, 3, player2, 4)
	player1.buddy_locations = [1,2,3,5,6]
	give_player_specific_card(player1, "standard_normal_assault", TestCardId1)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# Hit, gain advantage and fail place spike
	assert_true(game_logic.do_choice(player1, 0))
	# After no place to place a spike as it is occupied.
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 30, player2, 26)
	advance_turn(player1)

func test_polar_max_spikes_must_move():
	position_players(player1, 3, player2, 4)
	player1.buddy_locations = [1,3,5,6,7]
	give_player_specific_card(player1, "standard_normal_assault", TestCardId1)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# Hit, gain advantage and place spike
	assert_true(game_logic.do_choice(player1, 0)) # Adv
	# Time to place a spike, but we have to move one first, choices are current spike positions
	assert_true(game_logic.do_choice(player1, 3)) # Remove from 6
	# Ice is placed automatically
	#assert_true(game_logic.do_choice(player1, 0)) # Place at only available loc
	validate_spikes([1,2,3,5,7])
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 30, player2, 26)
	advance_turn(player1)

func test_polar_stomp():
	position_players(player1, 3, player2, 5)
	player1.exceeded = true # Set this just to verify the +3 power
	player1.buddy_locations = [-1,-1,-1,6,7]
	give_player_specific_card(player1, "polar_stomp", TestCardId1)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# 2 hit effects, stomp and main ice removal
	assert_true(game_logic.do_choice(player1, 0)) # stomp first
	validate_positions(player1, 3, player2, 7)
	# 0 = pass, 2 choices to remove, 6, and 7
	assert_eq(game_logic.decision_info.choice.size(), 3)
	assert_true(6 in game_logic.decision_info.limitation)
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(6))) # Remove 6 to gain advantage
	assert_true(game_logic.do_choice(player1, 0)) # Remove loc 7 for +power
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 27)
	# Exceeded, so you can pass on placing spike, but do it.
	assert_true(game_logic.do_choice(player1, 0))
	# After effect to place spike, options should be 1,2,4,5 for positions.
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(1)))
	validate_spikes([-1,-1,-1,-1,1])
	# Advantage
	advance_turn(player1)

func test_polar_stomp_no_adjacent():
	position_players(player1, 3, player2, 5)
	player1.exceeded = true # Set this just to verify the +3 power
	player1.buddy_locations = [-1,-1,-1,5,4]
	give_player_specific_card(player1, "polar_stomp", TestCardId1)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# 2 hit effects, stomp and main ice removal
	assert_true(game_logic.do_choice(player1, 1)) # ice removal first
	assert_true(game_logic.do_choice(player1, 0)) # Remove loc 5 for +power
	# Then push happens, no options for the gain advantage effect.
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 27)
	# Exceeded, so you can pass on placing spike, but do it.
	assert_true(game_logic.do_choice(player1, 0))
	# After effect ot place spike, options should be  1,2, 4(move it), 5 for positions.
	assert_eq(game_logic.decision_info.choice.size(), 4)
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(5)))
	validate_spikes([-1,-1,-1,5,4])
	advance_turn(player2)

func test_polar_stomp_no_adjacent_move_spike_at_end():
	position_players(player1, 3, player2, 5)
	player1.exceeded = true # Set this just to verify the +3 power
	player1.buddy_locations = [-1,-1,-1,5,4]
	give_player_specific_card(player1, "polar_stomp", TestCardId1)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# 2 hit effects, stomp and main ice removal
	assert_true(game_logic.do_choice(player1, 1)) # ice removal first
	assert_true(game_logic.do_choice(player1, 0)) # Remove loc 5 for +power
	# Then push happens, no options for the gain advantage effect.
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 27)
	# Exceeded, so you can pass on placing spike, but do it.
	assert_true(game_logic.do_choice(player1, 0))
	# After effect ot place spike, options should be  1,2, 4(move it), 5 for positions.
	assert_eq(game_logic.decision_info.choice.size(), 4)
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(4))) # Move spike 4
	assert_eq(game_logic.decision_info.choice.size(), 4) # Can place it at 1,2,4,5
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(2))) # Place at 2
	validate_spikes([-1,-1,-1,-1,2])
	advance_turn(player2)


func test_polar_shovelcharge():
	position_players(player1, 3, player2, 6)
	player1.buddy_locations = [1,6,7,8,9]
	assert_eq(player1.hand.size(), 5)
	give_player_specific_card(player1, "polar_shovelcharge", TestCardId1)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# 2 hit effects, shovel charge and main ice removal
	assert_true(game_logic.do_choice(player1, 0)) # Charge first
	# Draw and push up to 2. Do 2, drawing for each spike, should draw 3 total here.
	assert_true(game_logic.do_choice(player1, 1)) # Push 2
	assert_eq(player1.hand.size(), 8)
	validate_positions(player1, 5, player2, 8)
	# Now ice removal effect choice
	assert_true(game_logic.do_choice(player1, 0)) # Remove loc 8 for +power
	validate_life(player1, 30, player2, 25)
	# After effect to place spike, options, positions 4,6, but 6 is taken.
	assert_eq(game_logic.decision_info.choice.size(), 5) # can place new at 4 or move 1,6,7,9
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(4))) # Place at 4
	validate_spikes([1,4,6,7,9])
	advance_turn(player2)

func test_polar_shovelcharge_push2_at_edge():
	position_players(player1, 5, player2, 8)
	player1.buddy_locations = [1,6,7,8,9]
	assert_eq(player1.hand.size(), 5)
	give_player_specific_card(player1, "polar_shovelcharge", TestCardId1)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# 2 hit effects, shovel charge and main ice removal
	assert_true(game_logic.do_choice(player1, 0)) # Charge first
	# Draw and push up to 2. Do 2, drawing for each spike, should draw 3 total here.
	assert_true(game_logic.do_choice(player1, 1)) # Push 2
	assert_eq(player1.hand.size(), 7)
	validate_positions(player1, 7, player2, 9)
	# Now ice removal effect choice
	assert_true(game_logic.do_choice(player1, 0)) # Remove loc 9 for +power
	validate_life(player1, 30, player2, 25)
	validate_spikes([1,6,7,8,-1])
	# After effect to place spike, options, no unoccupied at range 1, so it is skipped.
	advance_turn(player2)

func test_polar_shovelcharge_push2_at_edge_draw_0():
	position_players(player1, 5, player2, 8)
	player1.buddy_locations = [1,6,7,8,-1]
	assert_eq(player1.hand.size(), 5)
	give_player_specific_card(player1, "polar_shovelcharge", TestCardId1)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# 2 hit effects, shovel charge and main ice removal
	assert_true(game_logic.do_choice(player1, 0)) # Charge first
	# Draw and push up to 2. Do 2, drawing for each spike, should draw 3 total here.
	assert_true(game_logic.do_choice(player1, 1)) # Push 2
	assert_eq(player1.hand.size(), 6)
	validate_positions(player1, 7, player2, 9)
	# Now ice removal effect choice, but nothing to remove.
	validate_life(player1, 30, player2, 27)
	validate_spikes([1,6,7,8,-1])
	# After effect to place spike, options, no unoccupied at range 1, so it is skipped.
	advance_turn(player2)

func test_polar_shovelcharge_boost_place2():
	position_players(player1, 5, player2, 8)
	give_player_specific_card(player1, "polar_shovelcharge", TestCardId1)
	assert_true(game_logic.do_boost(player1, TestCardId1))
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(4))) # Place at 4
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(9))) # Place at 9
	validate_spikes([9,4,-1,-1,-1])
	advance_turn(player2)

func test_polar_shovelcharge_boost_place1_move1():
	position_players(player1, 5, player2, 8)
	give_player_specific_card(player1, "polar_shovelcharge", TestCardId1)
	assert_true(game_logic.do_boost(player1, TestCardId1))
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(4))) # Place at 4
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(4))) # Move 4 to 5
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(5))) # Move 4 to 5
	validate_spikes([5,-1,-1,-1,-1])
	advance_turn(player2)

func test_polar_shovelslam_fails():
	position_players(player1, 5, player2, 8)
	player1.buddy_locations = [8,4,-1,-1,-1]
	give_player_specific_card(player1, "polar_shovelslam", TestCardId1)
	give_player_specific_card(player2, "standard_normal_spike", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	assert_true(game_logic.do_pay_strike_cost(player1, [player1.hand[0].id], false))
	# 2 hit effects, shovel slam and main ice removal
	assert_true(game_logic.do_choice(player1, 0)) # Slam first
	# Nothing adjacent to opponent, so fails.
	# Now ice removal effect choice, remove it.
	assert_true(game_logic.do_choice(player1, 0)) # Remove loc 8, + power
	validate_life(player1, 30, player2, 23)
	validate_spikes([4,-1,-1,-1,-1])
	# 2 after effects, shovel slam adjacent and main attack range
	assert_true(game_logic.do_choice(player1, 0)) # Slam first
	assert_eq(game_logic.decision_info.limitation.size(), 2) # Place at 6 or move 4
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(6))) # Place at 6
	validate_spikes([4,6,-1,-1,-1])
	# After effect to place/move spike, options, 2,3,4,6,7
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(7))) # Place at 6
	validate_spikes([4,6,7,-1,-1])
	advance_turn(player2)

func test_polar_shovelslam_succeed():
	position_players(player1, 5, player2, 8)
	player1.buddy_locations = [8,4,7,-1,-1]
	give_player_specific_card(player1, "polar_shovelslam", TestCardId1)
	give_player_specific_card(player2, "standard_normal_spike", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	assert_true(game_logic.do_pay_strike_cost(player1, [player1.hand[0].id], false))
	# 2 hit effects, shovel slam and main ice removal
	assert_true(game_logic.do_choice(player1, 0)) # Slam first
	assert_eq(game_logic.decision_info.limitation.size(), 2) # Pass or spot 7.
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(7))) # Remove 7 for push/pull 1
	assert_true(game_logic.do_choice(player1, 1)) # pull 1
	# Now ice removal effect choice fails because nothing is on 7 anymore.
	validate_life(player1, 30, player2, 25)
	validate_spikes([4,8,-1,-1,-1])
	# 2 after effects, shovel slam adjacent and main attack range
	assert_true(game_logic.do_choice(player1, 1)) # Attack range first
	# Options are 2,3,4,6,8
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(6))) # Place at 6
	validate_spikes([4,8,6,-1,-1])
	# Now adjacent place, but there's no spots so it fails.
	advance_turn(player2)

func test_polar_shovelslam_boost():
	position_players(player1, 5, player2, 7)
	player1.buddy_locations = [5,6,7,8,9]
	give_player_specific_card(player1, "polar_shovelslam", TestCardId1)
	assert_true(game_logic.do_boost(player1, TestCardId1))
	# Can move anywhere within 6, so 0 (pass), 1,2,3,4,6,8,9
	assert_eq(game_logic.decision_info.limitation.size(), 8)
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(9)))
	# Go to 9, passing through 6, 8, 9, skipping 7.
	# Expect to remove spikes 6 and 8
	validate_positions(player1, 9, player2, 7)
	validate_spikes([5,7,9,-1,-1])
	advance_turn(player2)

func test_polar_shovelslam_boost_only1_encounter():
	position_players(player1, 5, player2, 7)
	player1.buddy_locations = [5,6,7,1,2]
	give_player_specific_card(player1, "polar_shovelslam", TestCardId1)
	assert_true(game_logic.do_boost(player1, TestCardId1))
	# Can move anywhere within 6, so 0 (pass), 1,2,3,4,6,8,9
	assert_eq(game_logic.decision_info.limitation.size(), 8)
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(9)))
	# Go to 9, passing through 6, 8, 9, skipping 7.
	# Expect to remove spikes 6 and 8
	validate_positions(player1, 9, player2, 7)
	validate_spikes([5,7,-1,1,2])
	advance_turn(player2)

func test_polar_shovelslam_boost_0_encounter():
	position_players(player1, 5, player2, 7)
	player1.buddy_locations = [5,3,7,1,2]
	give_player_specific_card(player1, "polar_shovelslam", TestCardId1)
	assert_true(game_logic.do_boost(player1, TestCardId1))
	# Can move anywhere within 6, so 0 (pass), 1,2,3,4,6,8,9
	assert_eq(game_logic.decision_info.limitation.size(), 8)
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(9)))
	# Go to 9, passing through 6, 8, 9, skipping 7.
	# Expect to remove spikes 6 and 8
	validate_positions(player1, 9, player2, 7)
	validate_spikes([5,7,3,1,2])
	advance_turn(player2)


func test_polar_polarplow():
	position_players(player1, 5, player2, 8)
	player1.buddy_locations = [5,6,8,9,4]
	give_player_specific_card(player1, "polar_polarplow", TestCardId1)
	give_player_specific_card(player2, "standard_normal_grasp", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# P2 places ice
	assert_true(game_logic.do_choice(player2, get_choice_index_for_position(7)))
	validate_spikes([-1,-1,-1,-1,7], player2)
	# Before effect fails
	# Hit effect, can remove ice, but don't just to check power reduction.
	assert_true(game_logic.do_choice(player1, 1))
	validate_life(player1, 30, player2, 26) # Only 1 spike between at 6
	# 2 after effects, place spike and close 3
	validate_positions(player1, 5, player2, 8)
	assert_true(game_logic.do_choice(player1, 0)) # Close 3 first
	validate_positions(player1, 7, player2, 8)
	# First have to remove a spike since we have 5.
	assert_eq(game_logic.decision_info.limitation.size(), 5)
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(8)))
	# Can place in both directions, so expect any open space - what we removed and players, so 1,2,3
	assert_eq(game_logic.decision_info.limitation.size(), 3)
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(1)))
	validate_spikes([1,4,5,6,9])
	advance_turn(player2)


func test_polar_polarplow_edgebonus_cant():
	position_players(player1, 5, player2, 9)
	player1.buddy_locations = [5,6,8,9,4]
	give_player_specific_card(player1, "polar_polarplow", TestCardId1)
	give_player_specific_card(player2, "standard_normal_grasp", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# P2 places ice automatically.
	#assert_true(game_logic.do_choice(player2, get_choice_index_for_position(8)))
	validate_spikes([-1,-1,-1,-1,8], player2)
	# Before effect fails because there is already a spike there
	# Hit effect, can remove ice, but don't just to check power reduction.
	assert_true(game_logic.do_choice(player1, 1))
	validate_life(player1, 30, player2, 27) # 2 spikes 6 and 8
	# 2 after effects, place spike and close 3
	validate_positions(player1, 5, player2, 9)
	assert_true(game_logic.do_choice(player1, 0)) # Close 3 first
	validate_positions(player1, 8, player2, 9)
	# First have to remove a spike since we have 5.
	assert_eq(game_logic.decision_info.limitation.size(), 5)
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(8)))
	# Can place in both directions, so expect any open space - what we removed and players, so 1,2,3,7
	assert_eq(game_logic.decision_info.limitation.size(), 4)
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(1)))
	validate_spikes([1,4,5,6,9])
	advance_turn(player2)

func test_polar_polarplow_edgebonus_get():
	position_players(player1, 5, player2, 9)
	player1.buddy_locations = [-1,6,8,2,4]
	give_player_specific_card(player1, "polar_polarplow", TestCardId1)
	give_player_specific_card(player2, "standard_normal_grasp", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# P2 places ice automatically.
	#assert_true(game_logic.do_choice(player2, get_choice_index_for_position(8)))
	validate_spikes([-1,-1,-1,-1,8], player2)
	# Before effect lets us move a spike
	assert_eq(game_logic.decision_info.limitation.size(), 5) # Pass or any spike
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(6))) # Remove spike at position 6
	# Since we can replace it in the same spot, we have to say where to put it.
	# Put it in position 9.
	assert_eq(game_logic.decision_info.limitation.size(), 2)
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(9)))
	validate_spikes([-1,9,8,2,4]) # Moved 6 to 9
	# Hit effect, go ahead and remove the ice
	assert_true(game_logic.do_choice(player1, 0)) # Remove 9 for +2 power
	validate_life(player1, 30, player2, 24) # 1 spike at 8 and +2 power from removing 9
	# 2 after effects, place spike and close 3
	validate_positions(player1, 5, player2, 9)
	assert_true(game_logic.do_choice(player1, 0)) # Close 3 first
	validate_positions(player1, 8, player2, 9)
	# 2 open spikes, can place or move at 1-8
	validate_spikes([-1,-1,8,2,4])
	assert_eq(game_logic.decision_info.limitation.size(), 8)
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(3)))
	validate_spikes([-1,3,8,2,4])
	advance_turn(player2)


func test_polar_shoveldrop():
	position_players(player1, 7, player2, 8)
	give_player_specific_card(player1, "polar_shoveldrop", TestCardId1)
	give_player_specific_card(player2, "standard_normal_grasp", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# P2 2 hit effects, grasp and ice
	assert_true(game_logic.do_choice(player2, 0)) # Do grasp
	# P2 push/pull but fails to move. Ice fails auto.
	assert_true(game_logic.do_choice(player2, 0))
	# P2 places ice automatically.
	validate_spikes([-1,-1,-1,-1,9], player2)
	# P1 places ice in own space then advance 2/3
	validate_spikes([-1,-1,-1,-1,7])
	assert_true(game_logic.do_choice(player1, 0))
	validate_positions(player1, 9, player2, 8)
	# 2 hit effects, shoveldrop and ice removal
	assert_true(game_logic.do_choice(player1, 0)) # Drop
	assert_true(game_logic.do_choice(player1, 0)) # Push 1
	validate_positions(player1, 9, player2, 7)
	assert_true(game_logic.do_choice(player1, 0)) # Ice remove for +power
	# After place spike at 8 automatically
	validate_spikes([-1,-1,-1,-1,8])
	validate_life(player1, 28, player2, 25)
	advance_turn(player2)

func test_polar_shoveldrop_already_has_one():
	position_players(player1, 7, player2, 8)
	player1.buddy_locations = [7,-1,-1,-1,-1]
	give_player_specific_card(player1, "polar_shoveldrop", TestCardId1)
	give_player_specific_card(player2, "standard_normal_grasp", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# P2 2 hit effects, grasp and ice
	assert_true(game_logic.do_choice(player2, 0)) # Do grasp
	# P2 push/pull but fails to move. Ice fails auto.
	assert_true(game_logic.do_choice(player2, 0))
	# P2 places ice automatically.
	validate_spikes([-1,-1,-1,-1,9], player2)
	# P1 fails to place spike on self but that doens't change anything
	validate_spikes([-1,-1,-1,-1,7])
	assert_true(game_logic.do_choice(player1, 0))
	validate_positions(player1, 9, player2, 8)
	# 2 hit effects, shoveldrop and ice removal
	assert_true(game_logic.do_choice(player1, 0)) # Drop
	assert_true(game_logic.do_choice(player1, 0)) # Push 1
	validate_positions(player1, 9, player2, 7)
	assert_true(game_logic.do_choice(player1, 0)) # Ice remove for +power
	# After place spike at 8 automatically
	validate_spikes([-1,-1,-1,-1,8])
	validate_life(player1, 28, player2, 25)
	advance_turn(player2)

func test_polar_shoveldrop_boost_nospikes():
	position_players(player1, 7, player2, 8)
	give_player_specific_card(player1, "polar_shoveldrop", TestCardId1)
	assert_true(game_logic.do_boost(player1, TestCardId1, [player1.hand[0].id]))
	# Why are you buoosting this with no spikeS? no idea.
	assert_eq(player1.hand.size(), 5)
	advance_turn(player2)

func test_polar_shoveldrop_boost_move_onto_player():
	position_players(player1, 7, player2, 8)
	player1.buddy_locations = [2,5,-1,-1,-1]
	give_player_specific_card(player1, "polar_shoveldrop", TestCardId1)
	assert_true(game_logic.do_boost(player1, TestCardId1, [player1.hand[0].id]))
	# Choose a spike or pass
	assert_eq(game_logic.decision_info.limitation.size(), 3)
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(5)))
	validate_spikes([2,-1,-1,-1,-1])
	# Options are 3,4,5,6,7,8
	assert_eq(game_logic.decision_info.limitation.size(), 6)
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(8)))
	validate_spikes([2,8,-1,-1,-1])
	assert_eq(player1.hand.size(), 5)
	advance_turn(player2)

func test_polar_shoveldrop_boost_move_other_gauge_action():
	position_players(player1, 7, player2, 8)
	give_gauge(player1, 1)
	player1.buddy_locations = [2,5,-1,-1,-1]
	give_player_specific_card(player1, "polar_shoveldrop", TestCardId1)
	assert_true(game_logic.do_boost(player1, TestCardId1, [player1.hand[0].id]))
	# Choose a spike or pass
	assert_eq(game_logic.decision_info.limitation.size(), 3)
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(2)))
	validate_spikes([5,-1,-1,-1,-1])
	# Options are 1,2,3,4
	assert_eq(game_logic.decision_info.limitation.size(), 4)
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(4)))
	validate_spikes([4,5,-1,-1,-1])
	assert_true(game_logic.do_gauge_for_effect(player1, [player1.gauge[0].id]))
	advance_turn(player1) # My turn again


func test_polar_icicle_miss():
	position_players(player1, 6, player2, 9)
	give_gauge(player1, 3)
	give_player_specific_card(player1, "polar_icicledrop", TestCardId1)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	assert_true(game_logic.do_pay_strike_cost(player1, player1.get_card_ids_in_gauge(), false))
	# P2 hits, gain adv and remove ice cohices.
	assert_true(game_logic.do_choice(player2, 0))
	#Place ice at 8 automatically.
	validate_spikes([-1,-1,-1,-1,8], player2)

	# P1 is stun immune, but misses as no spikes
	# After card and place ice effects
	assert_true(game_logic.do_choice(player1, 0)) # Card advance choice
	assert_true(game_logic.do_choice(player1, 1)) #adv 2
	# Place ice next
	assert_eq(game_logic.decision_info.limitation.size(), 7) # Place anywhere non-player
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(6)))
	validate_spikes([-1,-1,-1,-1,6])
	validate_positions(player1, 9, player2, 7)
	validate_life(player1, 28, player2, 30)
	assert_eq(player1.gauge.size(), 0)
	assert_eq(player2.gauge.size(), 1)

	advance_turn(player2)

func test_polar_icicle_hits():
	position_players(player1, 6, player2, 9)
	player1.buddy_locations = [-1,-1,-1,7,8]
	give_gauge(player1, 3)
	give_player_specific_card(player1, "polar_icicledrop", TestCardId1)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	assert_true(game_logic.do_pay_strike_cost(player1, player1.get_card_ids_in_gauge(), false))
	# P2 hits, gain adv and remove ice cohices.
	assert_true(game_logic.do_choice(player2, 0))
	#Place ice at 8 automatically.
	validate_spikes([-1,-1,-1,-1,8], player2)

	# P1 is stun immune, and hits since p2 is at 7 now.
	# On hit can remove ice spike
	assert_true(game_logic.do_choice(player1, 0))
	# After card and place ice effects
	assert_true(game_logic.do_choice(player1, 0)) # Card advance choice
	assert_true(game_logic.do_choice(player1, 0)) #adv 1
	# Place ice next
	validate_positions(player1, 8, player2, 7)
	assert_eq(game_logic.decision_info.limitation.size(), 8) # Place anywhere non-player
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(1)))
	validate_spikes([-1,-1,-1,8,1])
	validate_positions(player1, 8, player2, 7)
	validate_life(player1, 28, player2, 20)
	assert_eq(player1.gauge.size(), 1)
	assert_eq(player2.gauge.size(), 1)
	advance_turn(player2)


func test_polar_icicledrop_boost_remove_all():
	position_players(player1, 6, player2, 9)
	player1.buddy_locations = [1,2,3,4,5]
	assert_eq(player1.hand.size(),5)
	give_player_specific_card(player1, "polar_icicledrop", TestCardId1)
	assert_true(game_logic.do_boost(player1, TestCardId1))
	assert_eq(player1.hand.size(),7)
	# Remove X Buddies
	# Expect pass and 5 buddy removal
	assert_eq(game_logic.decision_info.limitation.size(), 6)
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(3)))
	assert_eq(game_logic.decision_info.limitation.size(), 5)
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(2)))
	assert_eq(game_logic.decision_info.limitation.size(), 4)
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(5)))
	assert_eq(game_logic.decision_info.limitation.size(), 3)
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(4)))
	assert_eq(game_logic.decision_info.limitation.size(), 2)
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(1)))
	# Automatically finish, draw 5 more cards, and 1 for end of turn.
	assert_eq(player1.hand.size(),13)
	validate_spikes([-1,-1,-1,-1,-1])
	assert_eq(player1.gauge.size(), 1)
	var card_ids = []
	for card in player1.hand:
		if len(card_ids) == 6:
			break
		card_ids.append(card.id)
	assert_true(game_logic.do_discard_to_max(player1, card_ids))
	assert_eq(player1.hand.size(),7)
	advance_turn(player2)

func test_polar_icicledrop_boost_only_2inplay():
	position_players(player1, 6, player2, 9)
	player1.buddy_locations = [1,2,-1,-1,-1]
	assert_eq(player1.hand.size(),5)
	give_player_specific_card(player1, "polar_icicledrop", TestCardId1)
	assert_true(game_logic.do_boost(player1, TestCardId1))
	assert_eq(player1.hand.size(),7)
	# Remove X Buddies
	# Expect pass and 2 buddy removal
	assert_eq(game_logic.decision_info.limitation.size(), 3)
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(2)))
	assert_eq(game_logic.decision_info.limitation.size(), 2)
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(1)))
	# Automatically finish, draw 2 more cards, and 1 for end of turn.
	assert_eq(player1.hand.size(),10)
	validate_spikes([-1,-1,-1,-1,-1])
	assert_eq(player1.gauge.size(), 1)
	var card_ids = []
	for card in player1.hand:
		if len(card_ids) == 3:
			break
		card_ids.append(card.id)
	assert_true(game_logic.do_discard_to_max(player1, card_ids))
	assert_eq(player1.hand.size(),7)
	advance_turn(player2)

func test_polar_icicledrop_boost_remove_none():
	position_players(player1, 6, player2, 9)
	player1.buddy_locations = [1,2,3,4,5]
	assert_eq(player1.hand.size(),5)
	give_player_specific_card(player1, "polar_icicledrop", TestCardId1)
	assert_true(game_logic.do_boost(player1, TestCardId1))
	assert_eq(player1.hand.size(),7)
	# Remove X Buddies
	# Expect pass and 5 buddy removal
	assert_eq(game_logic.decision_info.limitation.size(), 6)
	assert_true(game_logic.do_choice(player1, 0))
	# Draw 1 for end of turn
	assert_eq(player1.hand.size(),8)
	validate_spikes([1,2,3,4,5])
	assert_eq(player1.gauge.size(), 0)
	var card_ids = []
	for card in player1.hand:
		if len(card_ids) == 1:
			break
		card_ids.append(card.id)
	assert_true(game_logic.do_discard_to_max(player1, card_ids))
	assert_eq(player1.hand.size(),7)
	advance_turn(player2)


func test_polar_icicledrop_boost_none_to_remove():
	position_players(player1, 6, player2, 9)
	player1.buddy_locations = [-1,-1,-1,-1,-1]
	assert_eq(player1.hand.size(),5)
	give_player_specific_card(player1, "polar_icicledrop", TestCardId1)
	assert_true(game_logic.do_boost(player1, TestCardId1))
	assert_eq(player1.hand.size(),8)
	# Draw 1 end of turn.
	assert_eq(player1.gauge.size(), 0)
	var card_ids = []
	for card in player1.hand:
		if len(card_ids) == 1:
			break
		card_ids.append(card.id)
	assert_true(game_logic.do_discard_to_max(player1, card_ids))
	assert_eq(player1.hand.size(),7)
	advance_turn(player2)

func test_polar_snowslash():
	position_players(player1, 6, player2, 9)
	give_gauge(player1, 2)
	give_player_specific_card(player1, "polar_snowslash", TestCardId1)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	assert_true(game_logic.do_pay_strike_cost(player1, player1.get_card_ids_in_gauge(), false))
	# p2 gain adv and ice effects.
	assert_true(game_logic.do_choice(player2, 0))
	validate_positions(player1, 6, player2, 7)
	# p1 hit response
	assert_true(game_logic.do_force_for_armor(player1, [player1.hand[0].id]))
	# P2 Place ice at 8 automatically.
	validate_spikes([-1,-1,-1,-1,8], player2)

	# p1 hits back and pushes 2 or remove ice
	assert_true(game_logic.do_choice(player1, 0))
	# No ice
	# After, place ice, choices 4,5,7,8
	assert_eq(game_logic.decision_info.limitation.size(), 4)
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(5)))
	validate_spikes([-1,-1,-1,-1,5])
	validate_positions(player1, 6, player2, 9)
	validate_life(player1, 30, player2, 26)
	advance_turn(player2)


func test_polar_snowslash_boost_gaugeblock():
	position_players(player1, 6, player2, 9)
	give_gauge(player1, 2)
	give_player_specific_card(player1, "polar_snowslash", TestCardId1)
	assert_true(game_logic.do_boost(player1, TestCardId1))
	advance_turn(player2)
	give_player_specific_card(player1, "standard_normal_sweep", TestCardId3)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId3, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# p2 gain adv and ice effects.
	assert_true(game_logic.do_choice(player2, 0))
	validate_positions(player1, 6, player2, 7)
	# p1 hit response
	assert_eq(game_logic.decision_info.limitation, "gauge")
	assert_true(game_logic.do_force_for_armor(player1, [player1.gauge[0].id, player1.gauge[1].id]))
	# P2 Place ice at 8 automatically.
	validate_spikes([-1,-1,-1,-1,8], player2)

	# p1 hits back, remove ice fails automatically. Swepe hits, discard or ice first.
	assert_true(game_logic.do_choice(player1, 0))
	# After, place ice, choices 3,4,5,8,9
	assert_eq(game_logic.decision_info.limitation.size(), 5)
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(8)))
	validate_spikes([-1,-1,-1,-1,8])
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 24)
	advance_turn(player2)


func test_polar_snowslash_boost_gaugeblock_with_block_card():
	position_players(player1, 6, player2, 9)
	give_gauge(player1, 2)
	give_player_specific_card(player1, "polar_snowslash", TestCardId1)
	assert_true(game_logic.do_boost(player1, TestCardId1))
	advance_turn(player2)
	give_player_specific_card(player1, "standard_normal_block", TestCardId3)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId3, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# p2 gain adv and ice effects.
	assert_true(game_logic.do_choice(player2, 0))
	validate_positions(player1, 6, player2, 7)
	# p1 hit response
	assert_eq(game_logic.decision_info.limitation, "force")
	assert_true(game_logic.do_force_for_armor(player1, [player1.hand[0].id, player1.hand[1].id]))
	# P2 Place ice at 8 automatically.
	validate_spikes([-1,-1,-1,-1,8], player2)

	# After simul effect block and ice placing
	assert_true(game_logic.do_choice(player1, 0))
	# Can't place ice though.

	validate_spikes([-1,-1,-1,-1,-1])
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 30)
	assert_eq(player1.gauge.size(), 3)
	assert_eq(player2.gauge.size(), 1)
	advance_turn(player2)
