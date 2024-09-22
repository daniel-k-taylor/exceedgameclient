extends ExceedGutTest

func who_am_i():
	return "seijun"

##
## Tests start here
##

## General Transform functionality:
## - If a card with a transform hits, you may transform it instead of sending it to gauge

func test_transforms_attack_hit():
	position_players(player1, 3, player2, 5)
	player1.discard_hand()

	# Land a hit with a card that has a transform
	var strike_cards = execute_strike(player1, player2, "seijun_foxfire", "standard_normal_grasp",
		false, false, [0]) # Accept choice to transform
	#     Foxfire has After: Push 2
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 24)

	# The transformed card went to the transform area rather than gauge
	assert_false(player1.is_card_in_gauge(strike_cards[0]))
	assert_true(player1.is_card_in_transforms(strike_cards[0]))

	advance_turn(player2)

func test_transforms_attack_hit_dont_transform():
	position_players(player1, 3, player2, 5)
	player1.discard_hand()

	# Land a hit with a card that has a transform
	var strike_cards = execute_strike(player1, player2, "seijun_foxfire", "standard_normal_grasp",
		false, false, [1]) # Decline choice to transform
	#     Foxfire has After: Push 2
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 24)

	# The transformed card went to the transform area rather than gauge
	assert_true(player1.is_card_in_gauge(strike_cards[0]))
	assert_false(player1.is_card_in_transforms(strike_cards[0]))

	advance_turn(player2)

func test_transforms_attack_misses():
	position_players(player1, 3, player2, 6)
	player1.discard_hand()

	# Miss with a card that has a transform
	var strike_cards = execute_strike(player1, player2, "seijun_foxfire", "standard_normal_grasp",
		false, false, []) # Not given option to transform
	#     Foxfire has After: Push 2
	validate_positions(player1, 3, player2, 8)
	validate_life(player1, 30, player2, 30)

	# The transformed card was discarded
	assert_true(player1.is_card_in_discards(strike_cards[0]))

	advance_turn(player2)

## - As an action, you may discard a copy of a card with a transform to transform it
func test_transforms_ex_transform():
	position_players(player1, 3, player2, 7)
	player1.discard_hand()

	var foxfire1_id = give_player_specific_card(player1, "seijun_foxfire")
	var foxfire2_id = give_player_specific_card(player1, "seijun_foxfire")

	assert_true(game_logic.do_boost(player1, foxfire1_id, [foxfire2_id]))

	# One copy is transformed, the other is discarded
	assert_true(player1.is_card_in_transforms(foxfire1_id))
	assert_true(player1.is_card_in_discards(foxfire2_id))

	advance_turn(player2)

## - Exceed costs are discounted by 2 for each transform in play
func test_transforms_exceed_without_transforms():
	position_players(player1, 3, player2, 7)
	var p1_gauge = give_gauge(player1, 5)

	assert_eq(player1.get_exceed_cost(), 5)
	assert_true(game_logic.do_exceed(player1, p1_gauge))
	advance_turn(player2)

func test_transforms_exceed_some_transforms():
	position_players(player1, 3, player2, 7)
	var p1_gauge = give_gauge(player1, 1)
	player1.discard_hand()

	give_player_specific_card(player1, "seijun_foxfire")
	give_player_specific_card(player1, "seijun_inksplash")
	player1.add_to_transforms(player1.hand[1])
	player1.add_to_transforms(player1.hand[0])

	assert_eq(player1.get_exceed_cost(), 1)
	assert_true(game_logic.do_exceed(player1, p1_gauge))
	advance_turn(player2)

func test_transforms_exceed_free():
	position_players(player1, 3, player2, 7)
	player1.discard_hand()

	give_player_specific_card(player1, "seijun_foxfire")
	give_player_specific_card(player1, "seijun_inksplash")
	give_player_specific_card(player1, "seijun_inkspike")
	player1.add_to_transforms(player1.hand[2])
	player1.add_to_transforms(player1.hand[1])
	player1.add_to_transforms(player1.hand[0])

	assert_eq(player1.get_exceed_cost(), 0)
	assert_true(game_logic.do_exceed(player1, []))
	advance_turn(player2)


## Seijun Normal UA: Your maximum hand size is 9. Draw 2 additional cards in your starting hand.
func test_seijun_ua_starting_hand():
	position_players(player1, 3, player2, 7)
	assert_eq(len(player1.hand), 7)

	advance_turn(player1)
	advance_turn(player2)
	advance_turn(player1)
	assert_eq(len(player1.hand), 9)

## Seijun Normal UA: Your attacks have +1 Guard for every 2 cards in your hand.
func test_seijun_ua_guard_no_cards():
	position_players(player1, 3, player2, 6)
	player1.discard_hand()

	# no cards in hand, so no guard
	execute_strike(player1, player2, "standard_normal_dive", "standard_normal_assault", false, false)

	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 26, player2, 30)
	advance_turn(player2)

func test_seijun_ua_guard_odd_cards():
	position_players(player1, 3, player2, 6)
	player1.discard_hand()
	player1.draw(7)

	# 7 cards in hand gives 3 guard; still stunned
	execute_strike(player1, player2, "standard_normal_dive", "standard_normal_assault", false, false)

	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 26, player2, 30)
	advance_turn(player2)

func test_seijun_ua_guard_even_cards():
	position_players(player1, 3, player2, 6)
	player1.discard_hand()
	player1.draw(8)

	# 8 cards in hand gives 4 guard; not stunned
	execute_strike(player1, player2, "standard_normal_dive", "standard_normal_assault", false, false)

	validate_positions(player1, 7, player2, 4)
	validate_life(player1, 26, player2, 30)
	advance_turn(player2)

## Seijun Exceed UA: When you exceed, draw 3.
##   Your maximum hand size is unlimited. At the start of each of your turns, draw a card.
func test_seijun_exceed_ua_big_hand():
	position_players(player1, 3, player2, 7)
	player1.draw(7)
	assert_eq(len(player1.hand), 14)

	# Exceeds; draws 3, does not have to discard at end of turn
	var p1_gauge = give_gauge(player1, 5)
	assert_true(game_logic.do_exceed(player1, p1_gauge))
	assert_eq(len(player1.hand), 18)

	advance_turn(player2)
	# Draws at start of turn
	assert_eq(len(player1.hand), 19)

	# Can prepare again without discarding
	advance_turn(player1)
	assert_eq(len(player1.hand), 21)

func test_seijun_exceed_ua_start_of_turn_deck_out():
	position_players(player1, 3, player2, 7)

	var p1_gauge = give_gauge(player1, 5)
	assert_true(game_logic.do_exceed(player1, p1_gauge))

	player1.deck = []
	player1.discards = []
	advance_turn(player2)
	# Player 1 attempts to draw at start of turn; cannot, so the game ends
	assert_true(game_logic.game_over)
	assert_eq(game_logic.game_over_winning_player, player2)

## Ink Splash (1~3/4/X) -- X is the number of cards in your hand (up to a maximum of 7).
func test_seijun_inksplash_slow():
	position_players(player1, 3, player2, 6)
	player1.discard_hand()
	player2.discard_hand()
	player1.draw(3)

	# Outsped by assault, doesn't hit
	execute_strike(player1, player2, "seijun_inksplash", "standard_normal_assault", false, false)

	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 26, player2, 30)
	advance_turn(player2)

func test_seijun_inksplash_fast():
	position_players(player1, 3, player2, 6)
	player1.discard_hand()
	player2.discard_hand()
	player1.draw(6)

	# Outspeeds and hits assault
	execute_strike(player1, player2, "seijun_inksplash", "standard_normal_assault",
		false, false, [1]) # don't transform

	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 30, player2, 26)
	advance_turn(player2)

func test_seijun_inksplash_limit():
	position_players(player1, 3, player2, 4)
	advance_turn(player1)
	player1.discard_hand()
	player2.discard_hand()
	player1.draw(10)

	# Can't get faster than speed 7, hit by grasp
	# But UA prevents it from being stunned
	execute_strike(player2, player1, "standard_normal_grasp", "seijun_inksplash",
		false, false, [0], [1]) # p2 pushes 1; p1 doesn't transform

	validate_positions(player1, 2, player2, 4)
	validate_life(player1, 27, player2, 26)
	advance_turn(player1)

## Ink Spike (1~3/X/4) -- X is the number of cards in your hand (up to a maximum of 7).
func test_seijun_inkspike_weak():
	position_players(player1, 3, player2, 6)
	player1.discard_hand()
	player2.discard_hand()
	player1.draw(3)

	execute_strike(player1, player2, "seijun_inkspike", "standard_normal_grasp",
		false, false, [0]) # don't transform

	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 30, player2, 27)
	advance_turn(player2)

func test_seijun_inkspike_strong():
	position_players(player1, 3, player2, 6)
	player1.discard_hand()
	player2.discard_hand()
	player1.draw(6)

	execute_strike(player1, player2, "seijun_inkspike", "standard_normal_grasp",
		false, false, [0]) # don't transform

	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 30, player2, 24)
	advance_turn(player2)

func test_seijun_inkspike_limit():
	position_players(player1, 3, player2, 6)
	player1.discard_hand()
	player2.discard_hand()
	player1.draw(10)

	execute_strike(player1, player2, "seijun_inkspike", "standard_normal_grasp",
		false, false, [0]) # don't transform

	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 30, player2, 23)
	advance_turn(player2)

## Tale of Seven Trials (4 Gauge) (1~7/X/2) -- X is the number of cards in your hand (up to a maximum of 15).
func test_seijun_taleofseventrials_average():
	position_players(player1, 2, player2, 8)
	player1.discard_hand()
	player2.discard_hand()
	player1.draw(8)
	var p1_gauge = give_gauge(player1, 4)

	execute_strike(player1, player2, "seijun_taleofseventrials", "standard_normal_grasp",
		false, false, [p1_gauge])

	validate_positions(player1, 2, player2, 8)
	validate_life(player1, 30, player2, 22)
	advance_turn(player2)

func test_seijun_taleofseventrials_limit():
	position_players(player1, 2, player2, 8)
	player2.discard_hand()
	player1.draw(16)
	var p1_gauge = give_gauge(player1, 4)

	execute_strike(player1, player2, "seijun_taleofseventrials", "standard_normal_grasp",
		false, false, [p1_gauge])

	validate_positions(player1, 2, player2, 8)
	validate_life(player1, 30, player2, 15)
	advance_turn(player2)

## Ink Splash transform -- After you use the "Prepare" action, you may spend 1 Force. If you do, Move 1.
func test_seijun_watchfulguardian():
	position_players(player1, 3, player2, 7)

	give_player_specific_card(player1, "seijun_inksplash")
	player1.add_to_transforms(player1.hand[-1])
	var original_hand_size = len(player1.hand)

	assert_true(game_logic.do_prepare(player1))
	assert_true(game_logic.do_force_for_effect(player1, [player1.hand[0].id], false))
	assert_true(game_logic.do_choice(player1, 1)) # retreat

	assert_eq(len(player1.hand), original_hand_size + 1)
	validate_positions(player1, 2, player2, 7)
	advance_turn(player2)

## Yokai Banishing transform -- When an opponent plays a Boost, you may discard a copy of that card.
##     If you do, their card is discarded with no effect.
func test_seijun_meddlesome_no_matching_card():
	position_players(player1, 3, player2, 7)
	advance_turn(player1)

	give_player_specific_card(player1, "seijun_yokaibanishing")
	player1.add_to_transforms(player1.hand[-1])
	player1.discard_hand()

	var cross_id = give_player_specific_card(player2, "standard_normal_cross")
	assert_true(game_logic.do_boost(player2, cross_id, []))
	# p1's hand is empty, so they can't match the cross
	# the UI still shows up so that information isn't revealed to the opponent
	assert_true(game_logic.do_choice(player1, 0)) # attempt to use effect, but fail
	assert_true(game_logic.do_choice(player2, 2)) # run: advance 3

	validate_positions(player1, 3, player2, 4)
	advance_turn(player1)

func test_seijun_meddlesome_decline():
	position_players(player1, 3, player2, 7)
	advance_turn(player1)

	give_player_specific_card(player1, "seijun_yokaibanishing")
	player1.add_to_transforms(player1.hand[-1])
	player1.discard_hand()

	var p1_cross_id = give_player_specific_card(player1, "standard_normal_cross")
	var p2_cross_id = give_player_specific_card(player2, "standard_normal_cross")
	assert_true(game_logic.do_boost(player2, p2_cross_id, []))
	# p1 can match the cross, but chooses not to
	assert_true(game_logic.do_choice(player1, 1))
	assert_true(game_logic.do_choice(player2, 2)) # run: advance 3

	validate_positions(player1, 3, player2, 4)
	assert_false(player1.is_card_in_discards(p1_cross_id))
	advance_turn(player1)

func test_seijun_meddlesome_negate():
	position_players(player1, 3, player2, 7)
	advance_turn(player1)

	give_player_specific_card(player1, "seijun_yokaibanishing")
	player1.add_to_transforms(player1.hand[-1])
	player1.discard_hand()

	var p1_cross_id = give_player_specific_card(player1, "standard_normal_cross")
	var p2_cross_id = give_player_specific_card(player2, "standard_normal_cross")
	assert_true(game_logic.do_boost(player2, p2_cross_id, []))
	# p1 has a copy of cross
	assert_true(game_logic.do_choice(player1, 0)) # discard, preventing p2 from using effect

	validate_positions(player1, 3, player2, 7)
	assert_true(player1.is_card_in_discards(p1_cross_id))
	advance_turn(player1)

func test_seijun_meddlesome_negate_with_multiple_matches():
	position_players(player1, 3, player2, 7)
	advance_turn(player1)

	give_player_specific_card(player1, "seijun_yokaibanishing")
	player1.add_to_transforms(player1.hand[-1])
	player1.discard_hand()

	var p1_cross1_id = give_player_specific_card(player1, "standard_normal_cross")
	var p1_cross2_id = give_player_specific_card(player1, "standard_normal_cross")
	var p2_cross_id = give_player_specific_card(player2, "standard_normal_cross")
	assert_true(game_logic.do_boost(player2, p2_cross_id, []))
	# p1 has several
	assert_true(game_logic.do_choice(player1, 0)) # discard one, preventing p2 from using effect

	validate_positions(player1, 3, player2, 7)
	assert_true(player1.is_card_in_discards(p1_cross1_id) or player1.is_card_in_discards(p1_cross2_id))
	assert_true(player1.is_card_in_hand(p1_cross1_id) or player1.is_card_in_hand(p1_cross2_id))
	advance_turn(player1)

func test_seijun_meddlesome_negate_uni_normal():
	position_players(player1, 3, player2, 7)
	advance_turn(player1)

	give_player_specific_card(player1, "seijun_yokaibanishing")
	player1.add_to_transforms(player1.hand[-1])
	player1.discard_hand()

	var p1_cross_id = give_player_specific_card(player1, "standard_normal_cross")
	var p2_cross_id = give_player_specific_card(player2, "uni_normal_cross")
	assert_true(game_logic.do_boost(player2, p2_cross_id, []))
	# p1 has a copy of cross; counts despite different boost
	assert_true(game_logic.do_choice(player1, 0)) # discard, preventing p2 from using effect

	validate_positions(player1, 3, player2, 7)
	assert_true(player1.is_card_in_discards(p1_cross_id))
	advance_turn(player1)

func test_seijun_meddlesome_negate_gg_normal():
	position_players(player1, 3, player2, 7)
	advance_turn(player1)

	give_player_specific_card(player1, "seijun_yokaibanishing")
	player1.add_to_transforms(player1.hand[-1])
	player1.discard_hand()
	give_gauge(player2, 1)

	var p1_spike_id = give_player_specific_card(player1, "standard_normal_spike")
	var p2_spike_id = give_player_specific_card(player2, "gg_normal_dust")
	assert_true(game_logic.do_boost(player2, p2_spike_id, []))
	# p1 has a copy of spike; counts despite different card name
	assert_true(game_logic.do_choice(player1, 0)) # discard, preventing p2 from using effect
	# p2 also is not given an opportunity to cancel

	validate_positions(player1, 3, player2, 7)
	assert_true(player1.is_card_in_discards(p1_spike_id))
	advance_turn(player1)
