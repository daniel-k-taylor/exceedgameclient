extends GutTest


var game_logic : LocalGame
var image_loader : CardImageLoader
var default_deck = CardDataManager.get_deck_from_str_id("platinum")
const TestCardId1 = 50001
const TestCardId2 = 50002
const TestCardId3 = 50003
const TestCardId4 = 50004
const TestCardId5 = 50005
const TestCardId6 = 50006
const TestCardId7 = 50007
const TestCardId8 = 50008

var player1 : Player
var player2 : Player

func default_game_setup(alt_opponent : String = ""):
	var opponent_deck = default_deck
	if alt_opponent:
		opponent_deck = CardDataManager.get_deck_from_str_id(alt_opponent)
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
	var card_def = CardDataManager.get_card(def_id)
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
func test_platinum_mystique_momo():
	position_players(player1, 3, player2, 5)
	give_player_specific_card(player1, "platinum_mystiquemomo", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	advance_turn(player2)
	give_player_specific_card(player1, "platinum_mystiquemomo", TestCardId1)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)

	# This test is going to verify that mystique momo can remove the before effect from
	# the other mystique momo and not pull 2.
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# Simul choice for the card and boost before effects.
	# strike effect should be listed first.
	validate_positions(player1, 3, player2, 5)
	assert_true(game_logic.do_choice(player1, 0))
	# Now we have to pick a continuous boost.
	assert_true(game_logic.do_boost_name_card_choice_effect(player1, player1.continuous_boosts[0].id))
	# With that discarded, there should be no more choices and the strike continues to end.
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 30, player2, 26)
	# Cleanup choice, pass here.
	assert_true(game_logic.do_choice(player1, 1))
	assert_true(game_logic.do_choice(player2, 1))
	advance_turn(player2)

func test_platinum_dramaticsammy_sustain_and_cleanup_testing_too():
	position_players(player1, 3, player2, 5)
	give_player_specific_card(player1, "standard_normal_grasp", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	advance_turn(player2)
	give_player_specific_card(player1, "platinum_dramaticsammy", TestCardId1)
	give_player_specific_card(player2, "standard_normal_sweep", TestCardId2)

	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	assert_true(game_logic.do_choice(player1, 0)) # Advance 1
	validate_positions(player1, 4, player2, 5)

	# Now we have to pick a continuous boost to sustain.
	assert_true(game_logic.do_choose_from_boosts(player1, [player1.continuous_boosts[0].id]))
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 30, player2, 24)

	# Setup for cleanup
	give_player_specific_card(player1, "standard_normal_spike", TestCardId4)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId5)
	player1.move_card_from_hand_to_deck(TestCardId4, 0)
	player2.move_card_from_hand_to_deck(TestCardId5, 0)
	# Cleanup choice, do it in both cases.
	assert_true(game_logic.do_choice(player1, 0))
	assert_true(game_logic.do_choice(player2, 0))
	assert_eq(player1.continuous_boosts.size(), 2)
	assert_eq(player1.continuous_boosts[0].id, TestCardId3)
	assert_eq(player1.continuous_boosts[1].id, TestCardId4)
	assert_eq(player2.continuous_boosts.size(), 0)
	# Advantage
	advance_turn(player1)

func test_platinum_dreamsally_nomove():
	position_players(player1, 3, player2, 5)
	give_player_specific_card(player1, "platinum_mystiquemomo", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	advance_turn(player2)
	give_player_specific_card(player1, "platinum_dreamsally", TestCardId1)
	give_player_specific_card(player2, "standard_normal_focus", TestCardId2)

	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# Focus blocks the momo pull.
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 26, player2, 29)

	# Cleanup choice, do it in both cases.
	# Don't specifically check what was in deck to keep it random,
	# but no boost should possibly interfere with ending the turn.
	assert_true(game_logic.do_choice(player1, 0))
	assert_true(game_logic.do_choice(player2, 0))

	advance_turn(player2)

func test_platinum_dreamsally_move():
	position_players(player1, 3, player2, 5)
	give_player_specific_card(player1, "platinum_mystiquemomo", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	advance_turn(player2)
	give_player_specific_card(player1, "platinum_dreamsally", TestCardId1)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)

	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# Assault to 4, pulled to 1.
	validate_positions(player1, 3, player2, 1)
	validate_life(player1, 26, player2, 25)

	# Cleanup choice, do it in both cases.
	# Don't specifically check what was in deck to keep it random,
	# but no boost should possibly interfere with ending the turn.
	# NOTE: Player 1 goes first because they initiated the strike.
	assert_true(game_logic.do_choice(player1, 0))
	assert_true(game_logic.do_choice(player2, 0))

	advance_turn(player2)

func test_platinum_dreamsally_returnattack_losearmor():
	position_players(player1, 3, player2, 5)
	assert_eq(player1.hand.size(), 5)
	give_player_specific_card(player1, "platinum_dreamsally", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	advance_turn(player2)
	assert_eq(player1.hand.size(), 6)
	give_player_specific_card(player1, "standard_normal_sweep", TestCardId4)
	assert_true(game_logic.do_boost(player1, TestCardId4))
	advance_turn(player2)
	assert_eq(player1.hand.size(), 7) # Keeps going up because we're magically giving them cards.
	assert_eq(player2.hand.size(), 7)
	give_player_specific_card(player1, "platinum_happymagicka", TestCardId1)
	give_player_specific_card(player2, "standard_normal_sweep", TestCardId2)

	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# Happy magicka goes, doesn't discard an opponent card since not hit.
	assert_eq(player2.hand.size(), 7)
	# After dream sally boost draws 1 and puts happy magicka on topdeck.
	# Then sweep hits and discards player1 card.
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 24, player2, 27) # Full damage because happymagicka armor left play.

	# Cleanup choice, do it in both cases.
	assert_true(game_logic.do_choice(player1, 0))
	assert_true(game_logic.do_choice(player2, 0))
	assert_eq(player1.hand.size(), 7)
	assert_eq(player1.gauge.size(), 0)
	assert_eq(player1.discards.size(), 3) # the swept card, sally and sweep boosts
	# Player 1's should be the happy magicka.
	assert_eq(player1.continuous_boosts[0].id, TestCardId1)
	advance_turn(player2)

func test_platinum_dreamsally_returnattack_focusfirst():
	position_players(player1, 3, player2, 5)
	assert_eq(player1.hand.size(), 5)
	give_player_specific_card(player1, "platinum_dreamsally", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	advance_turn(player2)
	assert_eq(player1.hand.size(), 6)
	give_player_specific_card(player1, "standard_normal_focus", TestCardId1)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)

	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# P2 hits with assault for 2, gets hit for 4.
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 28, player2, 26)
	
	# P1 gets a choice to do focus first or sally first or put focus on top deck.
	# Do focus first and go to 8.
	assert_true(game_logic.do_choice(player1, 0))
	assert_eq(player1.hand.size(), 8)

	# Cleanup choice, pass both.
	assert_true(game_logic.do_choice(player1, 1))
	assert_true(game_logic.do_choice(player2, 1))
	
	# Focus is on p1 top deck.
	assert_eq(player1.deck[0].id, TestCardId1)
	advance_turn(player2)

func test_platinum_dreamsally_returnattack_losefocusdraw():
	position_players(player1, 3, player2, 5)
	assert_eq(player1.hand.size(), 5)
	give_player_specific_card(player1, "platinum_dreamsally", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	advance_turn(player2)
	assert_eq(player1.hand.size(), 6)
	give_player_specific_card(player1, "standard_normal_focus", TestCardId1)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)

	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# P2 hits with assault for 2, gets hit for 4.
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 28, player2, 26)
	
	# P1 gets a choice to do focus first or sally first or put focus on top deck.
	# Do sally, expect to stay at 7.
	assert_true(game_logic.do_choice(player1, 1))
	assert_eq(player1.hand.size(), 7)

	# Cleanup choice, pass both.
	assert_true(game_logic.do_choice(player1, 1))
	assert_true(game_logic.do_choice(player2, 1))
	
	# Focus is on p1 top deck.
	assert_eq(player1.deck[0].id, TestCardId1)
	advance_turn(player2)
	
func test_platinum_miracle_jeanne_and_boost_sustain_all():
	position_players(player1, 3, player2, 5)

	# Boost miracle jeanne and sweep.
	# Discard a grasp and spike
	# Attack with Jeanne to boost those from discard.
	# Check that all are sustained.
	give_player_specific_card(player1, "platinum_miraclejeanne", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	advance_turn(player2)
	give_player_specific_card(player1, "standard_normal_sweep", TestCardId4)
	assert_true(game_logic.do_boost(player1, TestCardId4))
	advance_turn(player2)
	give_player_specific_card(player1, "standard_normal_grasp", TestCardId6)
	give_player_specific_card(player1, "standard_normal_spike", TestCardId7)
	player1.discard_hand()
	assert_eq(player1.discards.size(), 9) # 7 card hand after the 2 give+boost, and the 2 new ones.

	# Strike cards
	give_gauge(player1, 4)
	give_player_specific_card(player1, "platinum_miraclejeanne", TestCardId1)
	give_player_specific_card(player2, "standard_normal_focus", TestCardId2)

	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# Pay for miracle
	var card_ids = []
	for card in player1.gauge:
		card_ids.append(card.id)
	assert_true(game_logic.do_pay_strike_cost(player1, card_ids, false))
	assert_eq(player1.discards.size(), 13)
	# Miracle goes first, choose 2 from discard.
	assert_true(game_logic.do_choose_from_discard(player1, [TestCardId6, TestCardId7]))
	# These boost without issue, then attack completes.
	# Jeanne power 3, grasp +2, jeanne boost +2 = 7 power
	# 3 armor - 1 from spike 2 from jeanne boost
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 29, player2, 25)

	# Cleanup choice, just pass.
	assert_true(game_logic.do_choice(player1, 1))
	assert_true(game_logic.do_choice(player2, 1))

	assert_eq(player1.gauge.size(), 1)
	assert_eq(player1.discards.size(), 11) # No boosts went to discard and 2 were pulled out.
	assert_eq(player1.continuous_boosts.size(), 4)
	advance_turn(player2)


func test_platinum_miracle_jeanne_choose1_and_boost_sustain_all():
	position_players(player1, 3, player2, 5)

	# Boost miracle jeanne and sweep.
	# Discard a grasp and spike
	# Attack with Jeanne to boost those from discard.
	# Check that all are sustained.
	give_player_specific_card(player1, "platinum_miraclejeanne", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	advance_turn(player2)
	give_player_specific_card(player1, "standard_normal_sweep", TestCardId4)
	assert_true(game_logic.do_boost(player1, TestCardId4))
	advance_turn(player2)
	give_player_specific_card(player1, "standard_normal_grasp", TestCardId6)
	give_player_specific_card(player1, "standard_normal_spike", TestCardId7)
	player1.discard_hand()
	assert_eq(player1.discards.size(), 9) # 7 card hand after the 2 give+boost, and the 2 new ones.

	# Strike cards
	give_gauge(player1, 4)
	give_player_specific_card(player1, "platinum_miraclejeanne", TestCardId1)
	give_player_specific_card(player2, "standard_normal_focus", TestCardId2)

	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# Pay for miracle
	var card_ids = []
	for card in player1.gauge:
		card_ids.append(card.id)
	assert_true(game_logic.do_pay_strike_cost(player1, card_ids, false))
	assert_eq(player1.discards.size(), 13)
	# Miracle goes first, choose 1 from discard because we feel like it.
	assert_true(game_logic.do_choose_from_discard(player1, [TestCardId6]))
	# These boost without issue, then attack completes.
	# Jeanne power 3, grasp +2, jeanne boost +2 = 7 power
	# 2 armor - 2 from jeanne boost
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 28, player2, 25)

	# Cleanup choice, just pass.
	assert_true(game_logic.do_choice(player1, 1))
	assert_true(game_logic.do_choice(player2, 1))

	assert_eq(player1.gauge.size(), 1)
	assert_eq(player1.discards.size(), 12) # No boosts went to discard and 1 pulled out
	assert_eq(player1.continuous_boosts.size(), 3)
	advance_turn(player2)

func test_platinum_curedottyphoon():
	position_players(player1, 3, player2, 5)

	player1.discard_hand()

	# Strike cards
	give_gauge(player1, 2)
	give_player_specific_card(player1, "platinum_curedottyphoon", TestCardId1)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)

	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	# Pay for curedot
	var card_ids = []
	for card in player1.gauge:
		card_ids.append(card.id)
	assert_true(game_logic.do_pay_strike_cost(player1, card_ids, false))
	# Choice to advance
	assert_true(game_logic.do_choice(player1, 1))

	# After choose from discard for deck.
	var discard_choice = player1.discards[4].id
	assert_true(game_logic.do_choose_from_discard(player1, [discard_choice]))
	validate_positions(player1, 6, player2, 5)
	validate_life(player1, 30, player2, 26)

	# Card should be on top deck.
	assert_eq(player1.deck[0].id, discard_choice)

	# Let it be random, but the discarded card is either a continuous and in play
	# or it is discarded again.
	var is_continuous = player1.deck[0].definition['boost']['boost_type'] == "continuous"

	# Cleanup choice, do it.
	assert_true(game_logic.do_choice(player1, 0))
	assert_true(game_logic.do_choice(player2, 0))

	if is_continuous:
		assert_eq(player1.continuous_boosts.size(), 1)
		assert_eq(player1.continuous_boosts[0].id, discard_choice)
	else:
		assert_eq(player1.continuous_boosts.size(), 0)
		assert_eq(player1.get_top_discard_card().id, discard_choice)

	assert_eq(player1.gauge.size(), 1)
	advance_turn(player2)

func test_platinum_exceed_ua_overdrive():
	position_players(player1, 3, player2, 5)

	give_player_specific_card(player1, "standard_normal_grasp", TestCardId3)
	give_player_specific_card(player1, "standard_normal_dive", TestCardId4)
	give_player_specific_card(player1, "standard_normal_spike", TestCardId5)
	player1.move_card_from_hand_to_gauge(TestCardId3)
	player1.move_card_from_hand_to_gauge(TestCardId4)
	player1.move_card_from_hand_to_gauge(TestCardId5)
	assert_true(game_logic.do_exceed(player1, [TestCardId3, TestCardId4, TestCardId5]))
	advance_turn(player2)
	# Overdrive
	assert_true(game_logic.do_choose_from_discard(player1, [TestCardId3]))
	assert_eq(player1.continuous_boosts.size(), 1)
	assert_eq(player1.continuous_boosts[0].id, TestCardId3)

	# Strike cards
	give_player_specific_card(player1, "standard_normal_assault", TestCardId1)
	give_player_specific_card(player2, "standard_normal_assault", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 30, player2, 24)

	# Prime topdeck
	give_player_specific_card(player1, "standard_normal_sweep", TestCardId6)
	player1.move_card_from_hand_to_deck(TestCardId6, 0)

	# Cleanup choice, p1 do it, p2 pass.
	assert_true(game_logic.do_choice(player1, 0))
	# Because exceeded, it is played but not sustained.
	# Then we choose one to sustain, either our grasp or the new card.
	assert_true(game_logic.do_choose_from_boosts(player1, [TestCardId6]))

	# p2 pass
	assert_true(game_logic.do_choice(player2, 1))

	assert_eq(player1.continuous_boosts.size(), 1)
	assert_eq(player1.continuous_boosts[0].id, TestCardId6)
	# It is p1 turn again from advantage.
	# Overdrive again.
	# Choose dive which does nothing.
	assert_true(game_logic.do_choose_from_discard(player1, [TestCardId4]))
	assert_eq(player1.continuous_boosts.size(), 1)
	assert_eq(player1.continuous_boosts[0].id, TestCardId6)

	# Prime topdeck
	give_player_specific_card(player1, "standard_normal_cross", TestCardId8)
	player1.move_card_from_hand_to_deck(TestCardId8, 0)

	# Strike again.
	player1.move_card_from_gauge_to_hand(TestCardId1)
	give_player_specific_card(player2, "standard_normal_cross", TestCardId7)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId7, false, -1))
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 30, player2, 20)
	# Cleanup choice, p1 will try but see cross, still gets to sustain.
	assert_true(game_logic.do_choice(player1, 0))
	# Cross is not played, but we still get to sustain.
	assert_true(game_logic.do_choose_from_boosts(player1, [TestCardId6]))

	# P2 passes
	assert_true(game_logic.do_choice(player2, 1))
	assert_eq(player1.continuous_boosts.size(), 1) # Still has sweep.

	# Overdrive again.
	assert_true(game_logic.do_choose_from_discard(player1, [TestCardId5]))
	assert_eq(player1.continuous_boosts.size(), 2)
	assert_eq(player1.continuous_boosts[1].id, TestCardId5)
	assert_false(player1.exceeded)
	advance_turn(player1)


func test_platinum_happymagicka_vs_focus():
	position_players(player1, 3, player2, 5)

	# Strike cards
	assert_eq(player2.hand.size(), 6)
	give_player_specific_card(player1, "platinum_happymagicka", TestCardId1)
	give_player_specific_card(player2, "standard_normal_focus", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 28, player2, 29)
	assert_eq(player2.hand.size(), 7)

	# Cleanup choice, just pass
	assert_true(game_logic.do_choice(player1, 1))
	assert_true(game_logic.do_choice(player2, 1))

	advance_turn(player2)

func test_platinum_miraclejeanne_add_mystique_momo_pull():
	position_players(player1, 3, player2, 8)

	# Strike cards
	give_gauge(player1, 4)
	give_player_specific_card(player1, "platinum_mystiquemomo", TestCardId3)
	player1.discard([TestCardId3])
	give_player_specific_card(player1, "platinum_miraclejeanne", TestCardId1)
	give_player_specific_card(player2, "standard_normal_sweep", TestCardId2)
	assert_true(game_logic.do_strike(player1, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player2, TestCardId2, false, -1))
	var card_ids = []
	for card in player1.gauge:
		card_ids.append(card.id)
	assert_true(game_logic.do_pay_strike_cost(player1, card_ids, false))
	# Miracle effect
	# Just do 1.
	assert_true(game_logic.do_choose_from_discard(player1, [TestCardId3]))
	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 24, player2, 27)

	# Cleanup choice, just pass
	assert_true(game_logic.do_choice(player1, 1))
	assert_true(game_logic.do_choice(player2, 1))

	advance_turn(player2)


func test_platinum_exceed_ua_overdrive_variant():
	game_logic.teardown()
	game_logic.free()
	default_game_setup("arakune") # Just pick some random non Platinum character.
	position_players(player1, 3, player2, 7)

	# p1 boost mamicircular, pass turn, then boost mystiquemomo, pass turn again
	give_player_specific_card(player1, "platinum_mamicircular", TestCardId3)
	assert_true(game_logic.do_boost(player1, TestCardId3))
	advance_turn(player2)
	give_player_specific_card(player1, "platinum_mystiquemomo", TestCardId4)
	assert_true(game_logic.do_boost(player1, TestCardId4))
	advance_turn(player2)

	# Give p1 4 gauge and exceed (use first 3 to pay)
	give_gauge(player1, 4)
	var ex_ids = []
	for i in range(3):
		ex_ids.append(player1.gauge[i].id)
	assert_true(game_logic.do_exceed(player1, ex_ids))
	assert_true(game_logic.do_discard_to_max(player1, [player1.hand[0].id]))

	# Prime topdeck with Dive before the opponent strikes
	give_player_specific_card(player1, "standard_normal_dive", TestCardId6)
	player1.move_card_from_hand_to_deck(TestCardId6, 0)

	# p2 initiates strike with Focus; p1 responds with Cross
	give_player_specific_card(player2, "standard_normal_focus", TestCardId1)
	give_player_specific_card(player1, "standard_normal_cross", TestCardId2)
	assert_true(game_logic.do_strike(player2, TestCardId1, false, -1))
	assert_true(game_logic.do_strike(player1, TestCardId2, false, -1))

	validate_positions(player1, 1, player2, 7)
	validate_life(player1, 30, player2, 30)
	# Cleanup choices: p2 has nothing since they aren't Platinum
	# P1 plays topdeck boost
	assert_true(game_logic.do_choice(player1, 0))

	# Verify Dive was played and is now the top of p1's discard
	assert_eq(player1.discards[player1.discards.size() - 1].id, TestCardId6)

	# Choose which boost to sustain; pick mamicircular
	assert_true(game_logic.do_choose_from_boosts(player1, [TestCardId3]))

	# It should be p1's next turn; Overdrive: choose a card from discard (pick Dive again)
	var expected_boosts = 1
	if player1.overdrive[0].definition["boost"]["boost_type"] == "continuous":
		expected_boosts = 2
	assert_true(game_logic.do_choose_from_discard(player1, [player1.overdrive[0].id]))

	# End p1 turn and verify it's p2's turn (heuristic: p2 can strike, p1 cannot)
	advance_turn(player1)

	# Verify the correct sustained boost remains (mamicircular)
	assert_eq(player1.continuous_boosts.size(), expected_boosts)
	assert_eq(player1.continuous_boosts[0].id, TestCardId3)
