extends ExceedGutTest

func who_am_i():
	return "celinka"

##
## Tests start here
##

func test_celinka_ua_test_prepare_and_exceed_effects():
	position_players(player1, 5, player2, 7)
	var p1gauge = give_gauge(player1, 5)
	assert_true(game_logic.do_exceed(player1, p1gauge))
	assert_eq(player1.hand.size(), 6)
	assert_eq(player1.discards.size(), 0)
	assert_eq(player1.sealed.size(), 5)
	# P2's turn.
	assert_true(game_logic.do_prepare(player2))
	# on prepare effect.
	assert_true(game_logic.do_choose_to_discard(player2, [player2.hand[0].id, player2.hand[1].id, player2.hand[2].id]))
	assert_eq(player2.continuous_boosts.size(), 3)
	assert_eq(player2.hand.size(), 5)
	# P1's turn
	execute_strike(player1, player2, "standard_normal_sweep", "celinka_dispellinghorn", false, false,
		[], [])
	# This strike, P2 hits first, for 3 power + 3 continuous boosts, then seals them via the after effect for 6 armor,
	# then p1 hits for 6 + 1 for the 5 sealed cards, dealing 1.
	validate_life(player1, 24, player2, 29)
	assert_eq(player2.sealed.size(), 3)
	assert_eq(player2.hand.size(), 4) # Hit by sweep

	# P2's turn.
	assert_true(game_logic.do_prepare(player2))
	# on prepare effect.
	assert_eq(player2.hand.size(), 5)
	assert_true(game_logic.do_choose_to_discard(player2, []))
	assert_eq(player2.continuous_boosts.size(), 0)
	assert_eq(player2.hand.size(), 6)
	assert_eq(player1.hand.size(), 6)

func test_celinka_exceed_big_discard():
	position_players(player1, 5, player2, 7)
	var p1gauge = give_gauge(player1, 5)
	assert_true(game_logic.do_exceed(player1, p1gauge))
	assert_eq(player1.hand.size(), 6)
	assert_eq(player1.discards.size(), 0)
	assert_eq(player1.sealed.size(), 5)
	# P2's turn.
	assert_true(game_logic.do_prepare(player2))
	# on prepare effect.
	assert_true(game_logic.do_choose_to_discard(player2, [player2.hand[0].id, player2.hand[1].id, player2.hand[2].id]))
	assert_eq(player2.continuous_boosts.size(), 3)
	assert_eq(player2.hand.size(), 5)
	# P1's turn
	# Hack in way more cards to the sealed area.
	while (player1.deck.size() > 1):
		player1.add_to_sealed(player1.deck.pop_back())
	assert_eq(player1.sealed.size(), 23)
	execute_strike(player1, player2, "standard_normal_sweep", "celinka_dispellinghorn", false, false,
		[], [])
	# This strike, P2 hits first, for 3 power + 3 continuous boosts, then seals them via the after effect for 6 armor,
	# then p1 hits for 6 + 3 for the 5 sealed cards, dealing 3.
	validate_life(player1, 24, player2, 27)
	assert_eq(player2.sealed.size(), 3)
	assert_eq(player2.hand.size(), 4) # Hit by sweep


func test_celinka_tech_facedown():
	position_players(player1, 5, player2, 7)
	var p1gauge = give_gauge(player1, 5)
	assert_eq(player1.hand.size(), 5)

	# P1 turn
	assert_true(game_logic.do_prepare(player1))
	assert_true(game_logic.do_choose_to_discard(player1, [player1.hand[0].id, player1.hand[1].id, player1.hand[2].id]))
	assert_eq(player1.continuous_boosts.size(), 3)
	assert_eq(player1.hand.size(), 4)

	# P2's turn.
	assert_true(game_logic.do_prepare(player2))
	assert_true(game_logic.do_choose_to_discard(player2, [player2.hand[0].id, player2.hand[1].id, player2.hand[2].id]))
	assert_eq(player2.continuous_boosts.size(), 3)
	assert_eq(player2.hand.size(), 5)

	# P1's turn
	assert_true(game_logic.do_exceed(player1, p1gauge))
	assert_eq(player1.sealed.size(), 5)
	assert_eq(player1.hand.size(), 5)
	assert_eq(player1.continuous_boosts.size(), 3)

	# P2 turn
	var tech = give_player_specific_card(player2, "standard_normal_dive")
	assert_true(game_logic.do_boost(player2, tech, []))
	var discarded_id = player1.continuous_boosts[0].id
	assert_true(game_logic.do_boost_name_card_choice_effect(player2, discarded_id))

	# This should discard that boost and it gets sealed.
	assert_eq(player1.sealed[-1].id, discarded_id)
	assert_eq(player1.sealed.size(), 6)
	assert_eq(player1.continuous_boosts.size(), 2)
	assert_eq(player2.hand.size(), 6)
