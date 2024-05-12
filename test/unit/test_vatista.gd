extends ExceedGutTest

func who_am_i():
	return "vatista"


## Note: When converting execute_strike, the integer after the pair of arrays is
## init_extra_cost which is an extra gauge cost

## Character ability: Action: Strike. Push, Pull, and Draw effects on your
## attacks are increased by 1.
##     Note: In-game, the options are displayed unmodified, and instead there is
##       a pop-up in the lower left indicating the presence of the buff.

func test_vatista_ua_pull():
	position_players(player1, 5, player2, 6)

	assert_true(game_logic.do_character_action(player1, [], 0))
	execute_strike(player1, player2, "uni_normal_grasp", "uni_normal_grasp",
			false, false, [3], [])  # Pull 3 (listed as "pull 2")
	validate_positions(player1, 5, player2, 2)
	validate_life(player1, 30, player2, 27)
	advance_turn(player2)

func test_vatista_ua_push_draw():
	position_players(player1, 2, player2, 5)
	var hand_size = len(player1.hand)

	assert_true(game_logic.do_character_action(player1, [], 0))
	execute_strike(player1, player2, "vatista_lumenstella", "uni_normal_grasp")
	validate_positions(player1, 2, player2, 7)  # Expected: Push 1 -> Push 2
	validate_life(player1, 30, player2, 25)
	assert_eq(len(player1.hand), hand_size+2)   # Expected: Draw 1 -> Draw 2
	advance_turn(player2)

## Exceed ability: (2 Gauge) Action: Strike. Push, Pull, Advance, Retreat, and
## Draw effects on your attacks are increased by 2.

func test_vatista_exceed_ua_pull():
	position_players(player1, 5, player2, 6)
	player1.exceed()
	var p1_gauge = give_gauge(player1, 2)

	assert_true(game_logic.do_character_action(player1, p1_gauge, 0))
	execute_strike(player1, player2, "uni_normal_grasp", "uni_normal_grasp",
			false, false, [3], [])  # Pull 2 -> Pull 4
	validate_positions(player1, 5, player2, 1)
	validate_life(player1, 30, player2, 27)
	advance_turn(player2)

func test_vatista_exceed_ua_push_draw():
	position_players(player1, 2, player2, 5)
	var hand_size = len(player1.hand)
	player1.exceed()
	var p1_gauge = give_gauge(player1, 2)

	assert_true(game_logic.do_character_action(player1, p1_gauge, 0))
	execute_strike(player1, player2, "vatista_lumenstella", "uni_normal_grasp")
	validate_positions(player1, 2, player2, 8)  # Push 1 -> Push 3
	validate_life(player1, 30, player2, 25)
	assert_eq(len(player1.hand), hand_size+3)   # Draw 1 -> Draw 3
	advance_turn(player2)

func test_vatista_exceed_ua_dive():
	# Dive still benefits from the extra movement
	position_players(player1, 2, player2, 7)
	player1.exceed()
	var p1_gauge = give_gauge(player1, 2)

	assert_true(game_logic.do_character_action(player1, p1_gauge, 0))
	execute_strike(player1, player2, "uni_normal_dive", "uni_normal_sweep")
	validate_positions(player1, 8, player2, 7)  # Advance 3 -> Advance 5
	validate_life(player1, 30, player2, 25)
	advance_turn(player2)

func test_vatista_exceed_ua_close():
	# Close effects should be treated as a subtype of Advance
	position_players(player1, 2, player2, 7)
	player1.exceed()
	var p1_gauge = give_gauge(player1, 2)

	assert_true(game_logic.do_character_action(player1, p1_gauge, 0))
	execute_strike(player1, player2, "uni_normal_assault", "uni_normal_sweep")
	validate_positions(player1, 6, player2, 7)  # Close 2 -> Close 4
	validate_life(player1, 24, player2, 26)
	advance_turn(player1)

func test_vatista_exceed_ua_retreat():
	position_players(player1, 7, player2, 8)
	player1.exceed()
	var p1_gauge = give_gauge(player1, 2)

	assert_true(game_logic.do_character_action(player1, p1_gauge, 0))
	execute_strike(player1, player2, "uni_normal_cross", "uni_normal_sweep")
	validate_positions(player1, 2, player2, 8)  # Retreat 3 -> Retreat 5
	validate_life(player1, 30, player2, 27)
	advance_turn(player2)

func test_vatista_exceed_ua_affects_boosts():
	position_players(player1, 4, player2, 5)
	player1.exceed()
	var p1_gauge = give_gauge(player1, 2)
	var thrust_id = give_player_specific_card(player2, "faust_thrust")

	advance_turn(player1)
	# Thrust boost: Both Players have "B: Advance 1." and "A: Discard this."
	assert_true(game_logic.do_boost(player2, thrust_id, []))

	assert_true(game_logic.do_character_action(player1, p1_gauge, 0))
	execute_strike(player1, player2, "uni_normal_cross", "uni_normal_sweep",
			false, false, [0], [])  # Explicitly choose A: effect order
	validate_positions(player1, 9, player2, 5)  # Advance 3, then Retreat 5
	validate_life(player1, 30, player2, 30)
	advance_turn(player2)

## Lumen Stella boost -- (1 Force) Before: Reveal the top card of your deck.
##     Advance or Retreat X, where X is the revealed card's Power.

func test_vatista_instant_flight():
	position_players(player1, 2, player2, 7)
	var lumen_id = give_player_specific_card(player1, "vatista_lumenstella")
	assert_true(game_logic.do_boost(player1, lumen_id, [player1.hand[0].id]))
	advance_turn(player2)

	var assault_id = give_player_specific_card(player1, "uni_normal_assault")
	player1.move_card_from_hand_to_deck(assault_id)
	execute_strike(player1, player2, "uni_normal_grasp", "uni_normal_grasp",
			false, false, [0, 2], [])  # B: Advance 4, H: Pull 1
	validate_positions(player1, 6, player2, 5)
	validate_life(player1, 30, player2, 27)
	advance_turn(player2)

func test_vatista_instant_flight_power_boost():
	# Bonus Power from boosts should not apply to the revealed attack
	position_players(player1, 2, player2, 7)
	var lumen_id = give_player_specific_card(player1, "vatista_lumenstella")
	assert_true(game_logic.do_boost(player1, lumen_id, [player1.hand[0].id]))
	advance_turn(player2)
	var grasp_id = give_player_specific_card(player1, "standard_normal_grasp")
	assert_true(game_logic.do_boost(player1, grasp_id, []))
	advance_turn(player2)

	var assault_id = give_player_specific_card(player1, "uni_normal_grasp")
	player1.move_card_from_hand_to_deck(assault_id)
	execute_strike(player1, player2, "uni_normal_grasp", "uni_normal_grasp",
			false, false, [0], [])  # B: Advance 3, mutual whiff
	validate_positions(player1, 5, player2, 7)
	validate_life(player1, 30, player2, 30)
	advance_turn(player2)

func test_vatista_exceed_ua_instant_flight():
	position_players(player1, 2, player2, 9)
	player1.exceed()
	var p1_gauge = give_gauge(player1, 2)
	var lumen_id = give_player_specific_card(player1, "vatista_lumenstella")
	assert_true(game_logic.do_boost(player1, lumen_id, [player1.hand[0].id]))
	advance_turn(player2)

	var assault_id = give_player_specific_card(player1, "uni_normal_assault")
	player1.move_card_from_hand_to_deck(assault_id)
	assert_true(game_logic.do_character_action(player1, p1_gauge, 0))
	execute_strike(player1, player2, "uni_normal_grasp", "uni_normal_grasp",
			false, false, [0, 2], [])  # B: Advance 6, H: Pull 3
	validate_positions(player1, 8, player2, 5)
	validate_life(player1, 30, player2, 27)
	advance_turn(player2)

func test_vatista_instant_flight_empty_deck():
	# Revealing the top of an empty deck does nothing; only a wild swing or a
	# proper draw can cause a reshuffle.
	position_players(player1, 3, player2, 5)
	var lumen_id = give_player_specific_card(player1, "vatista_lumenstella")
	assert_true(game_logic.do_boost(player1, lumen_id, [player1.hand[0].id]))
	advance_turn(player2)

	player1.deck = []
	execute_strike(player1, player2, "uni_normal_grasp", "uni_normal_focus",
			false, false, [1], [])
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 26, player2, 30)
	advance_turn(player2)

## Armabellum (1 Gauge, 1~3/2/2|0/5) -- H: Add up to 3 cards from your hand to
##     your Gauge. For each card added this way, +1 Power.
##     A: Close or Retreat 1.

func test_vatista_armabellum_no_cards():
	position_players(player1, 3, player2, 5)
	var p1_gauge = give_gauge(player1, 1)

	execute_strike(player1, player2, "vatista_armabellum", "uni_normal_grasp",
			false, false, [p1_gauge, [], 1], [])  # Decline adding cards; Retreat 1
	validate_positions(player1, 2, player2, 5)
	validate_life(player1, 30, player2, 28)
	advance_turn(player2)

func test_vatista_armabellum_add_cards():
	position_players(player1, 3, player2, 5)
	var p1_gauge = give_gauge(player1, 1)

	execute_strike(player1, player2, "vatista_armabellum", "uni_normal_grasp",
			false, false,
			[p1_gauge, player1.hand.slice(0, 3).map(func (card): return card.id), 0],
			[])  # Add 3 cards; Close 1
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 30, player2, 25)
	advance_turn(player2)

## Lateus Orbis (3 Gauge, 3~8/6/3|0/5) -- H: Spend all cards in your hand and
##     Gauge as Force. For each Force spent, +1 Power. The opponent may spend
##     any amount of Force for +1 Armor each.

func test_vatista_lateus_orbis_boneless():
	position_players(player1, 3, player2, 7)
	var p1_gauge = give_gauge(player1, 3)
	player1.hand = []

	execute_strike(player1, player2, "vatista_lateusorbis", "uni_normal_grasp",
			false, false, [p1_gauge], [[]])  # Pay for Ultra; opponent spends nothing
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 24)
	advance_turn(player2)

func test_vatista_lateus_orbis_opponent_blocks():
	position_players(player1, 3, player2, 7)
	var p1_gauge = give_gauge(player1, 3)
	player1.hand = []
	player2.hand = []
	var p2_hand = []
	for card in ["uni_normal_grasp", "uni_normal_grasp", "vatista_lateusorbis"]:
		p2_hand.append(give_player_specific_card(player2, card))

	execute_strike(player1, player2, "vatista_lateusorbis", "uni_normal_grasp",
			false, false, [p1_gauge], [p2_hand])
	# P1 pays for Ultra, spends no Force from hand
	# P2 pays 3 cards from hand; 4 Force total
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 28)
	advance_turn(player2)

func test_vatista_lateus_orbis_hand_force():
	position_players(player1, 3, player2, 7)
	var p1_gauge = give_gauge(player1, 3)
	player1.hand = []
	for card in ["uni_normal_grasp", "uni_normal_grasp", "vatista_lateusorbis"]:
		give_player_specific_card(player1, card)

	execute_strike(player1, player2, "vatista_lateusorbis", "uni_normal_grasp",
			false, false, [p1_gauge], [[]])
	# P1 pays for Ultra, pays 3 cards for 4 Force and hits for 6 + 4 = 10
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 20)
	assert_eq(len(player1.hand), 0)
	advance_turn(player2)

func test_vatista_lateus_orbis_extra_gauge():
	position_players(player1, 3, player2, 7)
	var p1_gauge = give_gauge(player1, 3)
	player1.hand = []
	for card in ["uni_normal_grasp", "uni_normal_grasp", "vatista_lateusorbis"]:
		player1.move_card_from_hand_to_gauge(give_player_specific_card(player1, card))

	execute_strike(player1, player2, "vatista_lateusorbis", "uni_normal_grasp",
			false, false, [p1_gauge], [[]])
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 20)
	assert_eq(len(player1.gauge), 1)  # Attack added to Gauge
	advance_turn(player2)

func test_vatista_lateus_orbis_die():
	position_players(player1, 3, player2, 7)
	var p1_gauge = []
	for _i in range(3):
		p1_gauge.append(give_player_specific_card(player1, "uni_normal_grasp"))
		player1.move_card_from_hand_to_gauge(p1_gauge[-1])
	give_gauge(player1, 10)
	var available_force = player1.get_available_force() - 3

	execute_strike(player1, player2, "vatista_lateusorbis", "uni_normal_grasp",
			false, false, [p1_gauge], [[]])
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 24 - available_force)
	assert_eq(len(player1.hand), 0)
	assert_eq(len(player1.gauge), 1)
	advance_turn(player2)

## Lateus Orbis boost -- Hit: Spend up to 6 Gauge for +1 Power each, then add
##     this to your Gauge.
	
func test_vatista_autonomic_nerve_no_gauge():
	position_players(player1, 5, player2, 6)
	var lateus_id = give_player_specific_card(player1, "vatista_lateusorbis")
	assert_true(game_logic.do_boost(player1, lateus_id, []))
	advance_turn(player2)

	execute_strike(player1, player2, "uni_normal_grasp", "uni_normal_grasp",
			false, false, [0, 0], [])  # Choose effect ordering; push 1
	validate_positions(player1, 5, player2, 7)
	validate_life(player1, 30, player2, 27)
	assert_true(player1.is_card_in_gauge(lateus_id))
	advance_turn(player2)

func test_vatista_autonomic_nerve_big_gauge():
	position_players(player1, 5, player2, 6)
	var lateus_id = give_player_specific_card(player1, "vatista_lateusorbis")
	assert_true(game_logic.do_boost(player1, lateus_id, []))
	advance_turn(player2)

	var p1_gauge = give_gauge(player1, 6)
	execute_strike(player1, player2, "uni_normal_grasp", "uni_normal_grasp",
			false, false, [0, 0, p1_gauge], [])  # Choose effect ordering; push 1; spend [6] for +6 Power
	validate_positions(player1, 5, player2, 7)
	validate_life(player1, 30, player2, 21)
	assert_true(player1.is_card_in_gauge(lateus_id))
	advance_turn(player2)

## Zahhishio (2 Gauge; 1~2/2/6) -- B: Add all the cards in your hand to your Gauge. Gain Advantage.
##     H: Push 3.
	
func test_vatista_zahhishio_no_hand():
	position_players(player1, 3, player2, 5)
	var p1_gauge = give_gauge(player1, 2)
	player1.hand = []

	execute_strike(player1, player2, "vatista_zahhishio", "uni_normal_grasp",
			false, false, [p1_gauge], [])
	validate_positions(player1, 3, player2, 8)
	validate_life(player1, 30, player2, 28)
	assert_eq(len(player1.hand), 0)
	assert_eq(len(player1.gauge), 1)
	advance_turn(player1)

func test_vatista_zahhishio_with_hand_hit():
	position_players(player1, 3, player2, 5)
	var p1_gauge = give_gauge(player1, 2)
	var hand_size = len(player1.hand)

	execute_strike(player1, player2, "vatista_zahhishio", "uni_normal_grasp",
			false, false, [p1_gauge], [])
	validate_positions(player1, 3, player2, 8)
	validate_life(player1, 30, player2, 28)
	assert_eq(len(player1.hand), 0)
	assert_eq(len(player1.gauge), 1 + hand_size)
	advance_turn(player1)

func test_vatista_zahhishio_with_hand_miss():
	position_players(player1, 3, player2, 6)
	var p1_gauge = give_gauge(player1, 2)
	var hand_size = len(player1.hand)

	execute_strike(player1, player2, "vatista_zahhishio", "uni_normal_grasp",
			false, false, [p1_gauge], [])
	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 30, player2, 30)
	assert_eq(len(player1.hand), 0)
	assert_eq(len(player1.gauge), hand_size)
	advance_turn(player1)

## Zahhishio boost -- +3 Power. Now: Strike with a card from your Gauge, face-up.

func test_vatista_curse_commandment():
	position_players(player1, 3, player2, 4)
	var boost_id = give_player_specific_card(player1, "vatista_zahhishio")
	var grasp_id = give_player_specific_card(player1, "uni_normal_grasp")
	player1.move_card_from_hand_to_gauge(grasp_id)

	assert_true(game_logic.do_boost(player1, boost_id, []))
	execute_strike(player1, player2, grasp_id, "uni_normal_grasp",
			false, false, [0], [])  # Push 1
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 30, player2, 24)
	advance_turn(player2)

func test_vatista_curse_commandment_empty_gauge():
	# When failing to Strike with a face-up card from Gauge (because Gauge is
	# empty), wild swing instead.
	position_players(player1, 3, player2, 4)
	var boost_id = give_player_specific_card(player1, "vatista_zahhishio")
	var grasp_id = give_player_specific_card(player1, "uni_normal_grasp")
	player1.move_card_from_hand_to_deck(grasp_id)

	assert_true(game_logic.do_boost(player1, boost_id, []))
	execute_strike(player1, player2, "", "uni_normal_grasp", false, false, [0], [])  # wild swing
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 30, player2, 24)
	advance_turn(player2)

## Armabellum and Transvoranse boosts have "When you advance or retreat, add
##     this to your Gauge."
	
func test_vatista_double_gauge_boost_on_move():
	position_players(player1, 3, player2, 4)
	var arma_id = give_player_specific_card(player1, "vatista_armabellum")
	var trans_id = give_player_specific_card(player1, "vatista_transvoranse")

	assert_true(game_logic.do_boost(player1, arma_id, []))
	advance_turn(player2)
	assert_true(game_logic.do_boost(player1, trans_id, []))
	advance_turn(player2)

	assert_true(game_logic.do_move(player1, [player1.hand[0].id], 2))
	validate_positions(player1, 2, player2, 4)
	assert_true(player1.is_card_in_gauge(arma_id))
	assert_true(player1.is_card_in_gauge(trans_id))
	advance_turn(player2)

func test_vatista_double_gauge_boost_on_attack():
	position_players(player1, 2, player2, 4)
	var arma_id = give_player_specific_card(player1, "vatista_armabellum")
	var trans_id = give_player_specific_card(player1, "vatista_transvoranse")

	assert_true(game_logic.do_boost(player1, arma_id, []))
	advance_turn(player2)
	assert_true(game_logic.do_boost(player1, trans_id, []))
	advance_turn(player2)

	execute_strike(player1, player2, "uni_normal_assault", "uni_normal_cross")
	validate_positions(player1, 3, player2, 4)
	# Speed boost lets Assault outspeed Cross, but the Power boost goes away before
	# damage is assessed.
	assert_true(player1.is_card_in_gauge(arma_id))
	assert_true(player1.is_card_in_gauge(trans_id))
	validate_life(player1, 30, player2, 26)
	advance_turn(player1)

func test_vatista_double_gauge_boost_on_null_move():
	position_players(player1, 3, player2, 4)
	var arma_id = give_player_specific_card(player1, "vatista_armabellum")
	var trans_id = give_player_specific_card(player1, "vatista_transvoranse")

	assert_true(game_logic.do_boost(player1, arma_id, []))
	advance_turn(player2)
	assert_true(game_logic.do_boost(player1, trans_id, []))
	advance_turn(player2)

	execute_strike(player1, player2, "uni_normal_assault", "uni_normal_cross")
	validate_positions(player1, 3, player2, 4)
	# Speed boost lets Assault outspeed Cross; Power boost does not go away
	# because no actual movement occurs.
	assert_false(player1.is_card_in_gauge(arma_id))
	assert_false(player1.is_card_in_gauge(trans_id))
	validate_life(player1, 30, player2, 24)
	advance_turn(player1)
