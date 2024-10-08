extends ExceedGutTest

func who_am_i():
	return "carlswangee"

##
## Tests start here
##

## Overload functionality:
## - You may place this face-down with any Normal attack to form an EX attack.

func test_overload_ex_attack():
	position_players(player1, 3, player2, 6)

	var strike_cards = execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_spike",
		true, false, [], [], false,
		"carlswangee_authorizedforce") # Use overdrive to form an ex attack

	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 30, player2, 23)

	# Overload was discarded as an ex card
	assert_true(player1.is_card_in_gauge(strike_cards[0]))
	assert_true(player1.is_card_in_discards(strike_cards[2]))

	advance_turn(player2)

func test_overload_reading_response():
	position_players(player1, 3, player2, 6)
	advance_turn(player1)
	player1.discard_hand()
	var p1_sweep_id = give_player_specific_card(player1, "standard_normal_sweep")
	var p1_overload_id = give_player_specific_card(player1, "carlswangee_autonomicresponse")

	var p2_reading_id = give_player_specific_card(player2, "standard_normal_focus")
	var p2_sweep_id = give_player_specific_card(player2, "standard_normal_sweep")
	assert_true(game_logic.do_boost(player2, p2_reading_id))
	assert_true(game_logic.do_boost_name_card_choice_effect(player2, p1_sweep_id))
	assert_true(game_logic.do_strike(player2, p2_sweep_id, false, -1))
	game_logic.get_latest_events() # clear event queue for next check

	# Player 2 read sweep; player 1 can use their overload to EX it (third option, since 2nd is greyed out normal EX)
	assert_true(game_logic.do_choice(player1, 2))
	# Handling the strike generated by the reading choice
	var events = game_logic.get_latest_events()
	var reading_response_event = validate_has_event(events, Enums.EventType.EventType_Strike_EffectDoStrike, player1)[0]
	var rr_strike_info = reading_response_event.extra_info
	assert_true(game_logic.do_strike(player1, rr_strike_info['card_id'], rr_strike_info['wild_swing'], rr_strike_info['ex_card_id']))

	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 30, player2, 23)

	# Overload was discarded as an ex card
	assert_true(player1.is_card_in_gauge(p1_sweep_id))
	assert_true(player1.is_card_in_discards(p1_overload_id))

	advance_turn(player1)


## Swangee Normal UA: If the opponent's attack is a Special, +1 Armor.
func test_swangee_ua_against_normal():
	position_players(player1, 3, player2, 5)

	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_cross",
		false, false, [], []) # Clean hit with cross; 3 power

	validate_positions(player1, 3, player2, 8)
	validate_life(player1, 27, player2, 30)
	advance_turn(player2)

func test_swangee_ua_against_special():
	position_players(player1, 3, player2, 5)

	execute_strike(player1, player2, "standard_normal_grasp", "carlswangee_powershort",
		false, false, [], []) # Clean hit with power short; 7 power - 1 armor

	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 24, player2, 30)
	advance_turn(player2)

## Swangee Exceed UA: (in addition to above) Your normals have +2 Power.

func test_swangee_exceed_ua_with_normal():
	position_players(player1, 3, player2, 5)

	var p1_gauge = give_gauge(player1, 4)
	assert_true(game_logic.do_exceed(player1, p1_gauge))
	advance_turn(player2)

	execute_strike(player1, player2, "standard_normal_focus", "carlswangee_powershort",
		false, false, [], []) # power short hits for 7 - 2+1; focus hits for 4 + 2

	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 26, player2, 24)
	advance_turn(player2)

func test_swangee_exceed_ua_with_special():
	position_players(player1, 3, player2, 5)

	var p1_gauge = give_gauge(player1, 4)
	assert_true(game_logic.do_exceed(player1, p1_gauge))
	advance_turn(player2)

	execute_strike(player1, player2, "carlswangee_powershort", "carlswangee_powershort",
		false, false, [], []) # p1 wins speed tie; 7 power - 2 + 1 armor

	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 30, player2, 26)
	advance_turn(player2)


## Improvised Weapon (3-6/1/6) -- Hit: If opponent initiated return this to your hand (after the strike);
##     otherwise, gain Advantage.
func test_swangee_improvisedweapon_opponent_initiates():
	position_players(player1, 3, player2, 8)
	advance_turn(player1)

	# Outspeeds dive; does no damage because of Carl's UA
	var strike_cards = execute_strike(player2, player1, "standard_normal_dive", "carlswangee_improvisedweapon",
		false, false)
	var improv_weapon_id = strike_cards[1]

	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 30, player2, 30)
	# Returned to hand
	assert_true(player1.is_card_in_hand(improv_weapon_id))
	advance_turn(player1)

func test_swangee_improvisedweapon_player_initiates():
	position_players(player1, 3, player2, 8)

	# Outspeeds dive; does no damage because of Carl's UA
	var strike_cards = execute_strike(player1, player2, "carlswangee_improvisedweapon", "standard_normal_dive",
		false, false)
	var improv_weapon_id = strike_cards[0]

	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 30, player2, 30)
	# Not returned to hand
	assert_true(player1.is_card_in_gauge(improv_weapon_id))
	# Gained advantage
	advance_turn(player1)


## Cease & Desist (1-3/3/3/3/3) -- When you would discard during this strike, discard 1 fewer.
##     After: Draw a card and lose all armor.

func test_swangee_ceaseanddesist_sweep():
	position_players(player1, 3, player2, 6)
	var initial_hand_size = len(player1.hand)

	execute_strike(player1, player2, "carlswangee_ceaseanddesist", "standard_normal_sweep",
		false, false)
	# C&D outspeeds; draws, loses armor and does 3-1 from swangee's UA
	# Sweep hits back for 6, but does not discard a card

	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 24, player2, 28)
	assert_eq(len(player1.hand), initial_hand_size + 1)
	advance_turn(player2)

func test_swangee_ceaseanddesist_gordeau():
	game_logic.teardown()
	game_logic.free()
	default_game_setup("gordeau")

	position_players(player1, 3, player2, 6)
	advance_turn(player1)
	var initial_hand_size = len(player1.hand)

	assert_true(game_logic.do_character_action(player2, []))
	execute_strike(player2, player1, "uni_normal_sweep", "carlswangee_ceaseanddesist",
		false, false, [0]) # arbitrary choice for which discard effect happens first
	# C&D outspeeds; draws, loses armor and does 3
	# Sweep hits back for 6, but does not discard a card
	# Gordeau's UA also forces a non-random discard, but this is also blocked as a separate instance

	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 24, player2, 27)
	assert_eq(len(player1.hand), initial_hand_size + 1)
	advance_turn(player1)

func test_swangee_ceaseanddesist_full_hand_discard():
	game_logic.teardown()
	game_logic.free()
	default_game_setup("ino")

	position_players(player1, 3, player2, 5)
	var keep_card = player1.hand[0]
	var p2_gauge = give_gauge(player2, 5)

	# Megalomania goes first; full hand discard is reduced by 1, so must discard all but 1
	execute_strike(player1, player2, "carlswangee_ceaseanddesist", "ino_megalomania",
		false, false, [player1.get_card_ids_in_hand().slice(1)], [p2_gauge])
	# Megalomania hits for 4 - 3; C&D draws and hits back for 3

	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 29, player2, 27)
	assert_eq(len(player1.hand), 2)
	assert_true(player1.is_card_in_hand(keep_card.id))
	advance_turn(player2)


## Power Short (1-2/7/2/2/3) -- Cannot be pushed/pulled;
##    After: Lose all armor; if you did not hit, take 3 damage

func test_swangee_powershort_hit():
	position_players(player1, 3, player2, 4)

	execute_strike(player1, player2, "carlswangee_powershort", "standard_normal_grasp",
		false, false, [], [1]) # attempts to push 2 on grasp
	# Grasp hits for 3 - 2; Power Short hits back for 7 - 1 from UA, does not self-damage

	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 29, player2, 24)
	advance_turn(player2)

func test_swangee_powershort_missed():
	position_players(player1, 3, player2, 6)

	execute_strike(player1, player2, "carlswangee_powershort", "standard_normal_grasp",
		false, false, [], []) # attempts to push 2 on grasp
	# Mutual whiff; player 1 takes 3 self-damage

	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 27, player2, 30)
	advance_turn(player2)

func test_swangee_powershort_missed_lethal():
	position_players(player1, 3, player2, 6)
	player1.life = 2

	execute_strike(player1, player2, "carlswangee_powershort", "standard_normal_grasp",
		false, false, [], []) # attempts to push 2 on grasp
	# Mutual whiff; player 1 takes 3 self-damage and loses
	assert_true(game_logic.game_over)
	assert_eq(game_logic.game_over_winning_player, player2)


## Autonomic Response (2 Gauge) (1-3/6/1) -- Normal attacks do not hit you.

func test_swangee_autonomicresponse_normals_miss():
	position_players(player1, 3, player2, 6)
	var p1_gauge = give_gauge(player1, 2)

	execute_strike(player1, player2, "carlswangee_autonomicresponse", "standard_normal_assault",
		false, false, [p1_gauge], [])
	# Assault misses, AR hits back for 6

	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 30, player2, 24)
	advance_turn(player2)

func test_swangee_autonomicresponse_specials_hit():
	position_players(player1, 3, player2, 5)
	var p1_gauge = give_gauge(player1, 2)

	execute_strike(player1, player2, "carlswangee_autonomicresponse", "carlswangee_powershort",
		false, false, [p1_gauge], [])
	# Power short hits for 7 - 1 from UA, stuns AR

	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 24, player2, 30)
	advance_turn(player2)


## Improvised Weapon boost (1 Force) -- Opponent discards a card at random.
##    If it is a Special, they must discard an additional card of choice.

func test_swangee_investigate_normal_discarded():
	player2.discard_hand()
	var normal1 = give_player_specific_card(player2, "standard_normal_grasp")
	var normal2 = give_player_specific_card(player2, "standard_normal_focus")

	var boost_card = give_player_specific_card(player1, "carlswangee_improvisedweapon")
	assert_true(game_logic.do_boost(player1, boost_card, [player1.hand[0].id]))
	# Player 2 discards one of their normals, so the additional discard does not activate

	assert_eq(len(player2.hand), 1)
	assert_true(player2.is_card_in_hand(normal1) or player2.is_card_in_hand(normal2))
	assert_true(player2.is_card_in_discards(normal1) or player2.is_card_in_discards(normal2))
	advance_turn(player2)

func test_swangee_investigate_special_discarded():
	player2.discard_hand()
	var special1 = give_player_specific_card(player2, "carlswangee_powershort")
	var special2 = give_player_specific_card(player2, "carlswangee_ceaseanddesist")
	var special3 = give_player_specific_card(player2, "carlswangee_improvisedweapon")

	var boost_card = give_player_specific_card(player1, "carlswangee_improvisedweapon")
	assert_true(game_logic.do_boost(player1, boost_card, [player1.hand[0].id]))
	# Player 2 discards one of their specials, so they are forced to discard another afterwards
	assert_true(game_logic.do_choose_to_discard(player2, [player2.hand[0].id]))

	assert_eq(len(player2.hand), 1)
	var num_in_hand = 0
	var num_in_discards = 0
	for check_card in [special1, special2, special3]:
		if player2.is_card_in_hand(check_card):
			num_in_hand += 1
		if player2.is_card_in_discards(check_card):
			num_in_discards += 1
	assert_eq(num_in_hand, 1)
	assert_eq(num_in_discards, 2)
	advance_turn(player2)


## Power Short boost -- Return a normal from Gauge to hand.
##    If you did, add this card to Gauge.

func test_swangee_precisionengineering_returned_normal():
	player1.discard_hand()
	var gauge_normal = give_player_specific_card(player1, "standard_normal_grasp")
	player1.move_card_from_hand_to_gauge(gauge_normal)

	var boost_card = give_player_specific_card(player1, "carlswangee_powershort")
	assert_true(game_logic.do_boost(player1, boost_card, []))
	assert_true(game_logic.do_gauge_for_effect(player1, [gauge_normal]))

	assert_true(player1.is_card_in_hand(gauge_normal))
	assert_true(player1.is_card_in_gauge(boost_card))
	advance_turn(player2)

func test_swangee_precisionengineering_didnt_return_normal():
	player1.discard_hand()
	var gauge_special = give_player_specific_card(player1, "carlswangee_ceaseanddesist")
	player1.move_card_from_hand_to_gauge(gauge_special)

	var boost_card = give_player_specific_card(player1, "carlswangee_powershort")
	assert_true(game_logic.do_boost(player1, boost_card, []))
	# No normals in gauge, so can't fulfill condition
	assert_true(game_logic.do_gauge_for_effect(player1, []))

	assert_true(player1.is_card_in_gauge(gauge_special))
	assert_true(player1.is_card_in_discards(boost_card))
	advance_turn(player2)
