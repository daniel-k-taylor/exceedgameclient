extends ExceedGutTest

func who_am_i():
	return "waldstein"

## Ferzen Volf (1~3/4/1|1/2) -- You cannot be pushed or pulled.
##     Before, Range 1: Push 2 and +2 Power.
##     Hit: Push 2.

func test_waldstein_ferzen_volf_range_one():
	position_players(player1, 4, player2, 5)

	execute_strike(player1, player2, "waldstein_ferzenvolf", "uni_normal_grasp",
			false, false, [], [1])
	# Expected: Grasp fails to push Waldstein, so the Range 1 effects of Ferzen Volf kick in.
	validate_positions(player1, 4, player2, 9)
	validate_life(player1, 28, player2, 24)

func test_waldstein_ferzen_volf_range_two():
	position_players(player1, 4, player2, 6)

	execute_strike(player1, player2, "waldstein_ferzenvolf", "uni_normal_grasp")
	# Expected: Grasp misses, Ferzen Volf just hits with its printed stats.
	validate_positions(player1, 4, player2, 8)
	validate_life(player1, 30, player2, 26)

## Sturmangriff (1/5/2|1/2) -- Before: Close 4. Hit: Push or pull 3.
## Sturmangriff boost -- At the start of your turn, Strike. If you do, your attack has
##     +2 Speed and +2 Armor. Now: Draw 2.

func test_waldstein_face_me_opponent_strikes():
	position_players(player1, 4, player2, 6)
	player1.hand = []
	var boost_id = give_player_specific_card(player1, "waldstein_sturmangriff")
	assert_true(game_logic.do_boost(player1, boost_id, []))
	# Expected: Waldstein draws 2 from the boost and 1 from end of turn.
	assert_eq(len(player1.hand), 3)

	execute_strike(player2, player1, "uni_normal_sweep", "waldstein_sturmangriff")
	# Expected: Sweep connects for 6; in particular, the boost buffs don't apply
	#     on the opponent strike, so Sturmangriff is both slower than Sweep and
	#     gets stunned by it.
	validate_positions(player1, 4, player2, 6)
	validate_life(player1, 25, player2, 30)

func test_waldstein_face_me_opponent_doesnt_strike():
	position_players(player1, 4, player2, 7)
	player1.hand = []
	var boost_id = give_player_specific_card(player1, "waldstein_sturmangriff")
	assert_true(game_logic.do_boost(player1, boost_id, []))
	assert_eq(len(player1.hand), 3)

	# Give the opponent a speed boost (EX) so that Sturmangriff needs its
	# Speed buff to go first.
	var cross_id = give_player_specific_card(player2, "uni_normal_cross")
	assert_true(game_logic.do_boost(player2, cross_id, []))
	# Expected: Game to automatically initiates a strike on Waldstein's behalf
	assert_eq(game_logic.game_state, Enums.GameState.GameState_WaitForStrike)

	# Expected: Sturmangriff outspeeds EX Sweep (2 + 2 > 2 + 1), closes to 6,
	#     hits for 5 - 1 (EX) = 4, failing to stun. EX Sweep retaliates for
	#     6 + 1 (EX) - 1 (Sturmangriff) - 2 (boost) = 4.
	execute_strike(player1, player2, "waldstein_sturmangriff", "uni_normal_sweep",
			false, false, [0], [])  # Waldstein chooses to push 3
	validate_positions(player1, 6, player2, 9)
	validate_life(player1, 26, player2, 26)

## Katastrophe boost -- For each card in your hand, draw 1.

func test_waldstein_hecatoncheir_no_cards():
	position_players(player1, 4, player2, 6)
	player1.hand = []
	var boost_id = give_player_specific_card(player1, "waldstein_katastrophe")
	assert_true(game_logic.do_boost(player1, boost_id, []))
	# Expected: Waldstein only ends up with the one card from end of turn.
	assert_eq(len(player1.hand), 1)

func test_waldstein_hecatoncheir_one_card():
	position_players(player1, 4, player2, 6)
	player1.hand = []
	var boost_id = give_player_specific_card(player1, "waldstein_katastrophe")
	give_player_specific_card(player1, "uni_normal_grasp")
	assert_true(game_logic.do_boost(player1, boost_id, []))
	# Expected: Waldstein draws 1 from the boost and 1 from end of turn.
	assert_eq(len(player1.hand), 3)

func test_waldstein_hecatoncheir_several_cards():
	position_players(player1, 4, player2, 6)
	var hand_size = len(player1.hand)  # Should be five but that's a test suite detail
	var boost_id = give_player_specific_card(player1, "waldstein_katastrophe")
	assert_true(game_logic.do_boost(player1, boost_id, []))
	# Expected: Hand size is now doubled plus 1 from end of turn
	var events = game_logic.get_latest_events()
	validate_has_event(events, Enums.EventType.EventType_HandSizeExceeded, player1)
	assert_eq(len(player1.hand), (hand_size*2) + 1)

	var to_discard = player1.hand.size() - 7
	var cards = player1.hand.slice(0, to_discard).map(func (card): return card.id)
	assert_true(game_logic.do_discard_to_max(player1, cards))

## Werfen Erschlagen boost -- Your Normal attacks has +2~2 Range and +2 Power.
##     After: If your attack did not hit, return this to your hand.

func test_waldstein_the_destroyers_normal_hit():
	position_players(player1, 3, player2, 6)
	var boost_id = give_player_specific_card(player1, "waldstein_werfenerschlagen")
	assert_true(game_logic.do_boost(player1, boost_id, []))
	advance_turn(player2)

	execute_strike(player1, player2, "uni_normal_grasp", "uni_normal_assault",
			false, false, [3], [])  # Pull 2 with Grasp
	# Expected: Grasp hits at range 3 for 3 + 2.
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 30, player2, 25)
	# Expected: Boost does not recur
	assert_true(player1.is_card_in_discards(boost_id))

func test_waldstein_the_destroyers_normal_miss():
	position_players(player1, 3, player2, 4)
	var boost_id = give_player_specific_card(player1, "waldstein_werfenerschlagen")
	assert_true(game_logic.do_boost(player1, boost_id, []))
	advance_turn(player2)

	execute_strike(player1, player2, "uni_normal_grasp", "uni_normal_assault")
	# Expected: Grasp misses at range 1
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 26, player2, 30)
	# Expected: Boost recurs because Grasp missed
	assert_true(player1.is_card_in_hand(boost_id))

func test_waldstein_the_destroyers_stunned():
	position_players(player1, 3, player2, 4)
	var boost_id = give_player_specific_card(player1, "waldstein_werfenerschlagen")
	assert_true(game_logic.do_boost(player1, boost_id, []))
	advance_turn(player2)

	execute_strike(player1, player2, "uni_normal_dive", "uni_normal_assault")
	# Expected: Waldstein gets stunned out of the boost's After: effect
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 26, player2, 30)
	assert_true(player1.is_card_in_discards(boost_id))
	
func test_waldstein_the_destroyers_special():
	position_players(player1, 3, player2, 4)
	var boost_id = give_player_specific_card(player1, "waldstein_werfenerschlagen")
	assert_true(game_logic.do_boost(player1, boost_id, []))
	advance_turn(player2)
	# Expected: Wirbelwind is not a Normal and hits at its normal range of 1~2 for its normal amount of damage.
	#     It goes first and hits for 6, and Sweep retaliates for 6 - 1 (Wirbelwind) = 5.
	execute_strike(player1, player2, "waldstein_wirbelwind", "uni_normal_sweep",
			false, false, [0], [])  # Choose the ordering of After: effects
	validate_positions(player1, 5, player2, 7)
	validate_life(player1, 25, player2, 24)
	# Expected: Boost is still discarded because the attack did hit
	assert_true(player1.is_card_in_discards(boost_id))

func test_waldstein_the_destroyers_special_miss():
	position_players(player1, 3, player2, 6)
	var boost_id = give_player_specific_card(player1, "waldstein_werfenerschlagen")
	assert_true(game_logic.do_boost(player1, boost_id, []))
	advance_turn(player2)
	# Expected: Wirbelwind is not a Normal and misses (its 1~2 is not expanded to 3~4).
	#     Waldstein advances into Focus's range and gets hit for 4 - 1 (Wirbelwind) = 3.
	execute_strike(player1, player2, "waldstein_wirbelwind", "uni_normal_focus",
			false, false, [0], [])  # Choose the ordering of After: effects
	validate_positions(player1, 5, player2, 6)
	validate_life(player1, 27, player2, 30)
	# Expected: Boost is recurs due to the miss (even though the card wasn't a Normal).
	assert_true(player1.is_card_in_hand(boost_id))

func test_waldstein_the_destroyers_ultra():
	position_players(player1, 3, player2, 4)
	var p1_gauge = give_gauge(player1, 2)
	var boost_id = give_player_specific_card(player1, "waldstein_werfenerschlagen")
	assert_true(game_logic.do_boost(player1, boost_id, []))
	advance_turn(player2)
	# Expected: Katastrophe is not a Normal and hits at its normal range of 1~2.
	execute_strike(player1, player2, "waldstein_katastrophe", "uni_normal_dive",
			false, false, [p1_gauge], [])  # Pay for Ultra
	validate_positions(player1, 3, player2, 9)
	validate_life(player1, 30, player2, 23)
	# Expected: Boost is still discarded
	assert_true(player1.is_card_in_discards(boost_id))

func test_waldstein_the_destroyers_ultra_miss():
	position_players(player1, 3, player2, 6)
	var p1_gauge = give_gauge(player1, 2)
	var boost_id = give_player_specific_card(player1, "waldstein_werfenerschlagen")
	assert_true(game_logic.do_boost(player1, boost_id, []))
	advance_turn(player2)
	# Expected: Katastrophe is not a Normal and misses at its normal range of 1~2.
	execute_strike(player1, player2, "waldstein_katastrophe", "uni_normal_dive",
			false, false, [p1_gauge], [])  # Pay for Ultra
	validate_positions(player1, 3, player2, 2)
	validate_life(player1, 25, player2, 30)
	# Expected: Boost is recurs due to the miss
	assert_true(player1.is_card_in_hand(boost_id))

## Verderben (3~4/10/1|4/0) -- Stun Immunity. This attack must be set face-up.
##     (Otherwise, it becomes invalid.)
	
func test_waldstein_verderben_faceup_initiate():
	position_players(player1, 3, player2, 6)
	var p1_gauge = give_gauge(player1, 4)
	var wild_swing_id = give_player_specific_card(player1, "uni_normal_assault")
	player1.move_card_from_hand_to_deck(wild_swing_id)

	execute_strike(player1, player2, "waldstein_verderben", "uni_normal_sweep",
		false, false, [0, p1_gauge], [])  # Set attack face-up, pay gauge cost
	# Sweep hits first for 6 - 4 (Verderben) = 2, fails to stun (Verderben).
	# Verderben retaliates for 10.
	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 28, player2, 20)

func test_waldstein_verderben_faceup_response():
	position_players(player1, 3, player2, 6)
	var p1_gauge = give_gauge(player1, 4)
	var wild_swing_id = give_player_specific_card(player1, "uni_normal_assault")
	player1.move_card_from_hand_to_deck(wild_swing_id)
	advance_turn(player1)

	execute_strike(player2, player1, "uni_normal_sweep", "waldstein_verderben",
		false, false, [], [0, p1_gauge])  # Set attack face-up, pay gauge cost
	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 28, player2, 20)

func test_waldstein_verderben_facedown():
	position_players(player1, 3, player2, 6)
	var p1_gauge = give_gauge(player1, 4)
	var wild_swing_id = give_player_specific_card(player1, "uni_normal_assault")
	player1.move_card_from_hand_to_deck(wild_swing_id)

	var cards_used = execute_strike(player1, player2, "waldstein_verderben", "uni_normal_sweep",
			false, false, [1], [])  # Set attack face-down
	# Expected: Verderben is invalidated and Waldstein swings with Assault into Sweep
	validate_positions(player1, 5, player2, 6)
	validate_life(player1, 24, player2, 26)
	assert_true(player1.is_card_in_discards(cards_used[0]))  # Initiator's attack, i.e. Verderben
	assert_true(player1.is_card_in_gauge(wild_swing_id))
	assert_eq(player1.gauge.size(), 5)  # Did not have to pay for the invalid ultra

func test_waldstein_verderben_wildswung():
	position_players(player1, 3, player2, 6)
	var p1_gauge = give_gauge(player1, 4)
	var assault_id = give_player_specific_card(player1, "uni_normal_assault")
	player1.move_card_from_hand_to_deck(assault_id)
	var verderben_id = give_player_specific_card(player1, "waldstein_verderben")
	player1.move_card_from_hand_to_deck(verderben_id)

	execute_strike(player1, player2, "", "uni_normal_sweep")
	# Expected: Waldstein is not offered the chance to wild swing Verderben face-up
	#         (If he is, you will get an error about "needed to decide on ... but wasn't told how to)
	#     Waldstein wild swings Assault into Sweep
	validate_positions(player1, 5, player2, 6)
	validate_life(player1, 24, player2, 26)
	assert_true(player1.is_card_in_discards(verderben_id))
	assert_true(player1.is_card_in_gauge(assault_id))
	assert_eq(player1.gauge.size(), 5)  # Did not have to pay for the invalid ultra

