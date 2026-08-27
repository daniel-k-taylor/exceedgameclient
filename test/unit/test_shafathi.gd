extends ExceedGutTest

func who_am_i():
	return "shafathi"

##
## Tests start here
##

## Dematerialize - 1-2/3/4; Ignore Guard. Before: Activate one of your After effects.

## Shafathi Ability: After: You may spend 1 Force to return an Ultra from discard to hand.

func test_shafathi_dematerialize_character_after():
	position_players(player1, 3, player2, 5)
	var ultra1 = give_player_specific_card(player1, "shafathi_flashback")
	var ultra2 = give_player_specific_card(player1, "shafathi_timetwist")
	player1.discard([ultra1, ultra2])
	
	var strike_cards = execute_strike(player1, player2, "shafathi_dematerialize", "standard_normal_sweep",
		false, false, [
			0, 					# Choose to duplicate character ability
			[player1.hand[0].id],	# On before, pay 1 Force
			ultra1,			# to return first ultra to hand
			[player1.hand[1].id],	# On after, pay 1 Force
			ultra2])			# To return second ultra to hand
		
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 30, player2, 27)
	assert_true(player1.is_card_in_hand(ultra1))
	assert_true(player1.is_card_in_hand(ultra2))

	advance_turn(player2)
	
## Walk The Worlds (Dematerialize boost): (2F) When you would draw at the end of your turn,
##			you may instead return an Ultra from your discard pile to hand.
##			After: Advance or Retreat 1.

# Case where no cards can be, primarily testing dematerialize interaction

func test_shafathi_dematerialize_boost_after():
	position_players(player1, 3, player2, 6)
	var walkworld_boost = give_player_specific_card(player1, "shafathi_dematerialize")
	
	var p1_handsize = len(player1.hand)
	assert_true(game_logic.do_boost(player1, walkworld_boost, [player1.hand[0].id, player1.hand[1].id]))
	# Draw choice is skipped because there are no ultras in discard
	assert_eq(len(player1.hand), p1_handsize - 2) # spent 3 cards from hand, then drew for end of turn
	advance_turn(player2)
	
	
	var strike_cards = execute_strike(player1, player2, "shafathi_dematerialize", "standard_normal_sweep",
		false, false, [
			0, 					# Choose to duplicate boost's after effect
			0,					# On before, advance 1 to hit opponent
			0,					# Resolve boost on after
			1,					# Retreat 1
			[]])					# Decline to pay for ability
		
	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 30, player2, 27)

	advance_turn(player2)

func test_shafathi_walk_the_world_decline():
	position_players(player1, 3, player2, 6)
	var walkworld_boost = give_player_specific_card(player1, "shafathi_dematerialize")
	var test_ultra = give_player_specific_card(player1, "shafathi_flashback")
	player1.discard([test_ultra])
	
	var p1_handsize = len(player1.hand)
	assert_true(game_logic.do_boost(player1, walkworld_boost, [player1.hand[0].id, player1.hand[1].id]))
	# Choose to do normal end of turn draw
	assert_true(game_logic.do_choice(player1, 1))
	
	assert_true(player1.is_card_in_discards(test_ultra))
	assert_eq(len(player1.hand), p1_handsize - 2) # spent 3 cards from hand, then drew for end of turn
	
	advance_turn(player2)

func test_shafathi_walk_the_world_return():
	position_players(player1, 3, player2, 6)
	var walkworld_boost = give_player_specific_card(player1, "shafathi_dematerialize")
	var test_ultra = give_player_specific_card(player1, "shafathi_flashback")
	player1.discard([test_ultra])
	
	var p1_handsize = len(player1.hand)
	assert_true(game_logic.do_boost(player1, walkworld_boost, [player1.hand[0].id, player1.hand[1].id]))
	# Choose to do return the ultra
	assert_true(game_logic.do_choice(player1, 0))
	assert_true(game_logic.do_choose_from_discard(player1, [test_ultra]))
	
	assert_true(player1.is_card_in_hand(test_ultra))
	assert_eq(len(player1.hand), p1_handsize - 2) # spent 3 cards from hand, then drew for end of turn
	
	advance_turn(player2)

## Scheme (Penumbra boost): Now: Place this in any space. Draw 1.
##		After: If this is at exactly Range 3 from you, Draw 1, then Move up to 1.

func test_shafathi_scheme_range_3():
	position_players(player1, 3, player2, 6)
	var scheme_boost = give_player_specific_card(player1, "shafathi_penumbra")
	
	assert_true(game_logic.do_boost(player1, scheme_boost, []))
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(4)))
	advance_turn(player2)
	
	
	var p1_handsize = len(player1.hand)
	var strike_cards = execute_strike(player1, player2, "standard_normal_dive", "standard_normal_sweep",
		false, false, [
			0, 					# Choose to resolve boost after first
			1,					# Retreat 1
			[]], [[]])			# Decline to pay for ability (for both players)
		
	assert_eq(len(player1.hand), p1_handsize + 1)
	validate_positions(player1, 8, player2, 6)
	validate_life(player1, 30, player2, 25)

	advance_turn(player2)

func test_shafathi_scheme_not_range_3():
	position_players(player1, 3, player2, 6)
	var scheme_boost = give_player_specific_card(player1, "shafathi_penumbra")
	
	assert_true(game_logic.do_boost(player1, scheme_boost, []))
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(6)))
	advance_turn(player2)
	
	
	var p1_handsize = len(player1.hand)
	var strike_cards = execute_strike(player1, player2, "standard_normal_dive", "standard_normal_sweep",
		false, false, [
			0, 					# Choose to resolve boost after first; should fail
			[]], [[]])			# Decline to pay for ability (for both players)
		
	assert_eq(len(player1.hand), p1_handsize)
	validate_positions(player1, 7, player2, 6)
	validate_life(player1, 30, player2, 25)

	advance_turn(player2)

## Stasis: 0/0/1/0/4; Before: You may Reveal an attack from your hand to gain its
##			printed Range, Power, and effects.
##			After: You may spend 1 Gauge to Move 1.

func test_shafathi_stasis_no_reveal():
	position_players(player1, 4, player2, 5)
	
	var strike_cards = execute_strike(player1, player2, "shafathi_stasis", "standard_normal_focus",
		false, false, [
			[], 				# Do not reveal a card
			0,					# Resolve Gauge to Move first; skips since gauge is empty
			[]], [0, []])		# Decline to pay for ability (for both players)
		
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 26, player2, 30)
	assert_true(player1.is_card_in_discards(strike_cards[0]))

	advance_turn(player2)

func test_shafathi_stasis_reveal_attack():
	position_players(player1, 4, player2, 5)
	var reveal_card = give_player_specific_card(player1, "standard_normal_cross")
	
	var strike_cards = execute_strike(player1, player2, "shafathi_stasis", "standard_normal_focus",
		false, false, [
			[reveal_card], 		# Reveal Cross
			0,					# Resolve After: Retreat 3
			0,					# Resolve Gauge to Move; skips since gauge is empty
			[]], [0, []])		# Decline to pay for ability (for both players)
		
	validate_positions(player1, 1, player2, 5)
	validate_life(player1, 30, player2, 29)
	
	assert_true(player1.is_card_in_gauge(strike_cards[0]))
	assert_true(player1.is_card_in_hand(reveal_card))
	assert_true("standard_normal_cross" in player1.public_hand)

	advance_turn(player2)

func test_shafathi_stasis_reveal_spike():
	position_players(player1, 4, player2, 6)
	var reveal_card = give_player_specific_card(player1, "standard_normal_spike")
	
	var strike_cards = execute_strike(player1, player2, "shafathi_stasis", "standard_normal_focus",
		false, false, [
			[reveal_card], 		# Reveal Spike; gain IA/IG
			0,					# Resolve Gauge to Move; skips since gauge is empty
			[]])				# Decline to pay for ability (opponent is stunned)
		
	validate_positions(player1, 4, player2, 6)
	validate_life(player1, 30, player2, 25)
	
	assert_true(player1.is_card_in_gauge(strike_cards[0]))
	assert_true(player1.is_card_in_hand(reveal_card))
	assert_true("standard_normal_spike" in player1.public_hand)

	advance_turn(player2)

func test_shafathi_stasis_reveal_block():
	position_players(player1, 4, player2, 5)
	var reveal_card = give_player_specific_card(player1, "standard_normal_block")
	var force_card = give_player_specific_card(player1, "standard_normal_grasp")
	
	var strike_cards = execute_strike(player1, player2, "shafathi_stasis", "standard_normal_focus",
		false, false, [
			[reveal_card], 		# Reveal Block
			0,					# Resolve After: Add to Gauge thing
			0,					# Resolve Gauge to Move; skips since gauge is empty
			[],					# Decline to pay for ability
			[force_card]		# When hit, spend to block
			], [0, []])
		
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 28, player2, 30)
	
	assert_true(player1.is_card_in_gauge(strike_cards[0]))
	assert_true(player1.is_card_in_hand(reveal_card))
	assert_true("standard_normal_block" in player1.public_hand)

	advance_turn(player2)


func test_shafathi_stasis_reveal_timetwist():
	position_players(player1, 3, player2, 8)
	var reveal_card = give_player_specific_card(player1, "shafathi_timetwist")
	
	var strike_cards = execute_strike(player1, player2, "shafathi_stasis", "standard_normal_focus",
		false, false, [
			[reveal_card], 		# Reveal Time Twist
			0,					# Choose to resolve Stasis After on Before, skips because no gauge
			0,					# Resolve Gauge to Move; skips since gauge is empty
			[]					# Decline to pay for ability
			], [0, []])
		
	validate_positions(player1, 3, player2, 8)
	validate_life(player1, 30, player2, 27)
	
	assert_true(player1.is_card_in_gauge(strike_cards[0]))
	assert_true(player1.is_card_in_hand(reveal_card))
	assert_true("shafathi_timetwist" in player1.public_hand)

	advance_turn(player2)


## Monologue (Split Second boost): (2F) Search your deck for up to 2 cards
##		and add them to your hand.

# note - should look similar to consumption tests, just not mid-strike

func test_shafathi_monologue_pass():
	position_players(player1, 3, player2, 6)
	var monologue_boost = give_player_specific_card(player1, "shafathi_splitsecond")
	
	assert_true(game_logic.do_boost(player1, monologue_boost, [player1.hand[0].id, player1.hand[1].id]))
	assert_true(game_logic.do_choose_from_topdeck(player1, -1, "pass"))
	# Does not ask for further selections
	
	advance_turn(player2)

func test_shafathi_monologue_single_card():
	position_players(player1, 3, player2, 6)
	var monologue_boost = give_player_specific_card(player1, "shafathi_splitsecond")
	
	var return_card = give_player_specific_card(player1, "standard_normal_grasp")
	player1.shuffle_card_from_hand_to_deck(return_card)
	
	assert_true(game_logic.do_boost(player1, monologue_boost, [player1.hand[0].id, player1.hand[1].id]))
	assert_true(game_logic.do_choose_from_topdeck(player1, return_card, "add_to_hand"))
	assert_true(game_logic.do_choose_from_topdeck(player1, -1, "pass"))
	
	assert_true(player1.is_card_in_hand(return_card))
	
	advance_turn(player2)

func test_shafathi_monologue_two_cards():
	position_players(player1, 3, player2, 6)
	var monologue_boost = give_player_specific_card(player1, "shafathi_splitsecond")
	
	var return_card1 = give_player_specific_card(player1, "standard_normal_grasp")
	var return_card2 = give_player_specific_card(player1, "standard_normal_cross")
	player1.shuffle_card_from_hand_to_deck(return_card1)
	player1.shuffle_card_from_hand_to_deck(return_card2)
	
	assert_true(game_logic.do_boost(player1, monologue_boost, [player1.hand[0].id, player1.hand[1].id]))
	assert_true(game_logic.do_choose_from_topdeck(player1, return_card1, "add_to_hand"))
	assert_true(game_logic.do_choose_from_topdeck(player1, return_card2, "add_to_hand"))
	
	assert_true(player1.is_card_in_hand(return_card1))
	assert_true(player1.is_card_in_hand(return_card2))
	
	advance_turn(player2)

## Flashback - [2G] 2-3/2/7; Before: Discard any number of your Boosts from play.
##		+2 Power for each Boost discarded.
##		After: Advance 3.

func test_shafathi_flashback_no_boosts():
	position_players(player1, 3, player2, 5)
	var gauge_cards = give_gauge(player1, 2)
	
	var strike_cards = execute_strike(player1, player2, "shafathi_flashback", "standard_normal_sweep",
		false, false, [
			[],					# Decline infusion
			gauge_cards,		# Validate ultra
			[],					# No boosts discarded
			0,					# Resolve Advance 3 first
			[]], [[]])			# Decline to pay for ability (for both players)
		
	validate_positions(player1, 7, player2, 5)
	validate_life(player1, 24, player2, 28)

	advance_turn(player2)

func test_shafathi_flashback_some_boosts():
	position_players(player1, 3, player2, 5)
	var gauge_cards = give_gauge(player1, 2)
	player1.discard_hand()
	
	var fierce_boost = give_player_specific_card(player1, "standard_normal_grasp")
	assert_true(game_logic.do_boost(player1, fierce_boost, []))
	advance_turn(player2)
	
	var light_boost = give_player_specific_card(player1, "standard_normal_sweep")
	assert_true(game_logic.do_boost(player1, light_boost, []))
	advance_turn(player2)
	
	var defend_boost = give_player_specific_card(player1, "standard_normal_spike")
	assert_true(game_logic.do_boost(player1, defend_boost, []))
	advance_turn(player2)
	
	var strike_cards = execute_strike(player1, player2, "shafathi_flashback", "standard_normal_sweep",
		false, false, [
			[],					# Decline infusion
			gauge_cards,		# Validate ultra
			[fierce_boost, light_boost, defend_boost],		# Many boosts discarded
			0,					# Resolve Advance 3 first
			[]])			# Decline to pay for ability (for both players)
		
	validate_positions(player1, 7, player2, 5)
	validate_life(player1, 30, player2, 22)

	advance_turn(player2)

## Shadow Over Space (Flashback boost) - (1F) Now: Place this in any space. Draw 1.
##		Infused, After: If this is unoccupied, you may Move here or return this to your hand.

func test_shafathi_shadow_over_space_occupied():
	position_players(player1, 3, player2, 6)
	var gauge_ids = give_gauge(player1, 1)
	var shadow_boost = give_player_specific_card(player1, "shafathi_flashback")
	
	assert_true(game_logic.do_boost(player1, shadow_boost, [player1.hand[0].id]))
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(5)))
	advance_turn(player2)
	
	var strike_cards = execute_strike(player1, player2, "standard_normal_assault", "standard_normal_sweep",
		false, false, [
			gauge_ids,			# Infuse
			0, 					# Choose to resolve boost after first; should fail
			[]], [[]])			# Decline to pay for ability (for both players)
		
	validate_positions(player1, 5, player2, 6)
	validate_life(player1, 24, player2, 26)
	assert_true(player1.is_card_in_discards(shadow_boost))
	
	advance_turn(player1)

func test_shafathi_shadow_over_space_move_there():
	position_players(player1, 3, player2, 6)
	var gauge_ids = give_gauge(player1, 1)
	var shadow_boost = give_player_specific_card(player1, "shafathi_flashback")
	
	assert_true(game_logic.do_boost(player1, shadow_boost, [player1.hand[0].id]))
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(1)))
	advance_turn(player2)
	
	var strike_cards = execute_strike(player1, player2, "standard_normal_assault", "standard_normal_sweep",
		false, false, [
			gauge_ids,			# Infuse
			0, 					# Choose to resolve boost after first
			0,					# Choose to move to its space
			[]], [[]])			# Decline to pay for ability (for both players)
		
	validate_positions(player1, 1, player2, 6)
	validate_life(player1, 30, player2, 26)
	assert_true(player1.is_card_in_discards(shadow_boost))
	
	advance_turn(player1)
	
func test_shafathi_shadow_over_space_return_to_hand():
	position_players(player1, 3, player2, 6)
	var gauge_ids = give_gauge(player1, 1)
	var shadow_boost = give_player_specific_card(player1, "shafathi_flashback")
	
	assert_true(game_logic.do_boost(player1, shadow_boost, [player1.hand[0].id]))
	assert_true(game_logic.do_choice(player1, get_choice_index_for_position(1)))
	advance_turn(player2)
	
	var strike_cards = execute_strike(player1, player2, "standard_normal_assault", "standard_normal_assault",
		false, false, [
			gauge_ids,			# Infuse
			0, 					# Choose to resolve boost after first
			1,					# Choose to return to hand
			[]])				# Decline to pay for ability
		
	validate_positions(player1, 5, player2, 6)
	validate_life(player1, 30, player2, 26)
	assert_true(player1.is_card_in_hand(shadow_boost))
	
	advance_turn(player1)
