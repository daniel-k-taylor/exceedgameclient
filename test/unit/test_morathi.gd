extends ExceedGutTest

func who_am_i():
	return "morathi"

##
## Tests start here
##

func test_morathi_ua():
	position_players(player1, 5, player2, 7)
	set_player_topdeck(player1, "standard_normal_assault")
	set_player_topdeck(player1, "standard_normal_dive")
	execute_strike(player1, player2, -1, "standard_normal_assault", false, false,
		[0], [])
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 26)
	advance_turn(player1)

func test_morathi_ua_2ndoption():
	position_players(player1, 5, player2, 7)
	set_player_topdeck(player1, "standard_normal_assault")
	set_player_topdeck(player1, "standard_normal_dive")
	execute_strike(player1, player2, -1, "standard_normal_assault", false, false,
		[1], [])
	validate_positions(player1, 5, player2, 6)
	validate_life(player1, 26, player2, 30)
	advance_turn(player2)


func test_morathi_ua_p2():
	position_players(player1, 4, player2, 7)
	set_player_topdeck(player2, "standard_normal_dive")
	set_player_topdeck(player2, "standard_normal_assault")
	execute_strike(player1, player2, "standard_normal_dive", -1, false, false,
		[], [0])
	validate_positions(player1, 8, player2, 7)
	validate_life(player1, 30, player2, 25)
	advance_turn(player2)

func test_morathi_ua_2ndoption_p2():
	position_players(player1, 4, player2, 7)
	set_player_topdeck(player2, "standard_normal_dive")
	set_player_topdeck(player2, "standard_normal_assault")
	execute_strike(player1, player2, "standard_normal_dive", -1, false, false,
		[], [1])
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 26, player2, 30)
	advance_turn(player2)


func test_morathi_ua_fakeout():
	position_players(player1, 5, player2, 7)
	give_player_specific_card(player1, "akuma_hyakkishu")
	assert_true(game_logic.do_boost(player1, player1.hand[-1].id, []))
	# P2 sets attack first.
	set_player_topdeck(player2, "standard_normal_cross")
	var top = set_player_topdeck(player2, "standard_normal_dive")
	# Set first initiate
	assert_true(game_logic.do_strike(player1, -1, false, -1, true))
	# P2 wild swing
	assert_true(game_logic.do_strike(player2, -1, true, -1, true))
	# P2 choose draw or just strike
	assert_true(game_logic.do_choice(player2, 0))
	assert_eq(player2.hand[-1].id, top)
	# P1 Strike
	var p1attack = give_player_specific_card(player1, "standard_normal_assault")
	assert_true(game_logic.do_strike(player1, p1attack, false, -1, true))
	validate_positions(player1, 5, player2, 9)
	validate_life(player1, 27, player2, 30)
	advance_turn(player2)


func test_morathi_ua_fakeout_option2():
	position_players(player1, 5, player2, 7)
	give_player_specific_card(player1, "akuma_hyakkishu")
	assert_true(game_logic.do_boost(player1, player1.hand[-1].id, []))
	# P2 sets attack first.
	set_player_topdeck(player2, "standard_normal_cross")
	set_player_topdeck(player2, "standard_normal_dive")
	# Set first initiate
	assert_true(game_logic.do_strike(player1, -1, false, -1, true))
	# P2 wild swing
	assert_true(game_logic.do_strike(player2, -1, true, -1, true))
	# P2 choose draw or just strike
	assert_true(game_logic.do_choice(player2, 1))
	# P1 Strike
	var p1attack = give_player_specific_card(player1, "standard_normal_assault")
	assert_true(game_logic.do_strike(player1, p1attack, false, -1, true))
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 26)
	advance_turn(player1)

func test_morathi_exceed_ua():
	position_players(player1, 5, player2, 7)
	player1.exceeded = true
	var t3 = set_player_topdeck(player1, "standard_normal_assault")
	var t2 = set_player_topdeck(player1, "standard_normal_dive")
	var t1 = set_player_topdeck(player1, "standard_normal_spike")
	execute_strike(player1, player2, -1, "standard_normal_assault", false, false,
		[t1, "discard", t2, "add_to_hand"], [])
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 26)
	assert_eq(player1.hand[-1].id, t2)
	assert_eq(player1.discards[0].id, t1)
	assert_eq(player1.gauge[0].id, t3)
	advance_turn(player1)


func test_morathi_exceed_ua_no_deck():
	position_players(player1, 5, player2, 7)
	player1.exceeded = true
	var assault = give_player_specific_card(player1, "standard_normal_assault")
	player1.discard([assault])
	assert_eq(player1.discards[0].id, assault)
	assert_eq(player1.discards.size(), 1)
	assert_eq(player1.hand.size(), 5)
	player1.deck = []
	assert_eq(player1.deck.size(), 0)
	execute_strike(player1, player2, -1, "standard_normal_assault", false, false,
		[], [])
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 26)
	assert_eq(player1.hand.size(), 5)
	assert_eq(player1.discards.size(), 0)
	assert_eq(player1.gauge[0].id, assault)


func test_morathi_exceed_ua_no_deck_gameover():
	position_players(player1, 5, player2, 7)
	player1.exceeded = true
	player1.reshuffle_remaining = 0
	var assault = give_player_specific_card(player1, "standard_normal_assault")
	player1.discard([assault])
	assert_eq(player1.discards[0].id, assault)
	assert_eq(player1.discards.size(), 1)
	assert_eq(player1.hand.size(), 5)
	player1.deck = []
	assert_eq(player1.deck.size(), 0)
	execute_strike(player1, player2, -1, "standard_normal_assault", false, false,
		[], [])
	assert_true(game_logic.game_over)
	validate_positions(player1, 5, player2, 7)

func test_morathi_exceed_ua_no_deck_1_left():
	position_players(player1, 5, player2, 7)
	player1.exceeded = true
	assert_eq(player1.discards.size(), 0)
	assert_eq(player1.hand.size(), 5)
	player1.deck = []
	var t3 = set_player_topdeck(player1, "standard_normal_assault")
	assert_eq(player1.deck.size(), 1)
	execute_strike(player1, player2, -1, "standard_normal_assault", false, false,
		[], [])
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 26)
	assert_eq(player1.hand.size(), 5)
	assert_eq(player1.discards.size(), 0)
	assert_eq(player1.gauge[0].id, t3)


func test_morathi_exceed_ua_no_deck_2_left():
	position_players(player1, 5, player2, 7)
	player1.exceeded = true
	assert_eq(player1.discards.size(), 0)
	assert_eq(player1.hand.size(), 5)
	player1.deck = []
	var t3 = set_player_topdeck(player1, "standard_normal_assault")
	var t2 = set_player_topdeck(player1, "standard_normal_dive")
	assert_eq(player1.deck.size(), 2)
	execute_strike(player1, player2, -1, "standard_normal_assault", false, false,
		[t2, "add_to_hand"], [])
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 26)
	assert_eq(player1.hand.size(), 6)
	assert_eq(player1.hand[-1].id, t2)
	assert_eq(player1.discards.size(), 0)
	assert_eq(player1.gauge[0].id, t3)


func test_morathi_exceed_ua_no_deck_3_left():
	position_players(player1, 5, player2, 7)
	player1.exceeded = true
	assert_eq(player1.discards.size(), 0)
	assert_eq(player1.hand.size(), 5)
	player1.deck = []
	var t3 = set_player_topdeck(player1, "standard_normal_assault")
	var t2 = set_player_topdeck(player1, "standard_normal_dive")
	var t1 = set_player_topdeck(player1, "standard_normal_dive")
	assert_eq(player1.deck.size(), 3)
	execute_strike(player1, player2, -1, "standard_normal_assault", false, false,
		[t1, "discard", t2, "add_to_hand"], [])
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 26)
	assert_eq(player1.hand.size(), 6)
	assert_eq(player1.hand[-1].id, t2)
	assert_eq(player1.discards.size(), 1)
	assert_eq(player1.discards[0].id, t1)
	assert_eq(player1.gauge[0].id, t3)
	assert_eq(player1.deck.size(), 0)

func test_morathi_gyrochaingash_discard_3():
	position_players(player1, 4, player2, 7)

	assert_eq(player1.hand.size(), 5)
	assert_eq(player2.hand.size(), 6)

	var p2discards = [
		player2.hand[0].id,
		player2.hand[1].id,
		player2.hand[2].id,
	]
	execute_strike(player1, player2, "morathi_gyrochaingash", "standard_normal_spike", false, false,
		[2], [p2discards])
	validate_life(player1, 30, player2, 25)
	validate_positions(player1, 6, player2, 7)

	assert_eq(player1.hand.size(), 2)
	assert_eq(player2.hand.size(), 3)

	assert_eq(player2.discards.size(), 4)
	assert_eq(player2.discards[0].id, p2discards[0])
	assert_eq(player2.discards[1].id, p2discards[1])
	assert_eq(player2.discards[2].id, p2discards[2])

	advance_turn(player2)


func test_morathi_gyrochaingash_discard_3_opponent_has_1():
	position_players(player1, 4, player2, 7)

	assert_eq(player1.hand.size(), 5)
	assert_eq(player2.hand.size(), 6)
	player2.hand = player2.hand.slice(0, 1)

	var p2discards = [
		player2.hand[0].id,
	]
	execute_strike(player1, player2, "morathi_gyrochaingash", "standard_normal_spike", false, false,
		[2], [])
	validate_life(player1, 30, player2, 25)
	validate_positions(player1, 6, player2, 7)

	assert_eq(player1.hand.size(), 2)
	assert_eq(player2.hand.size(), 0)

	assert_eq(player2.discards.size(), 2)
	assert_eq(player2.discards[0].id, p2discards[0])

	advance_turn(player2)



func test_morathi_gyrochaingash_discard_onlyhas_2_pass():
	position_players(player1, 4, player2, 7)

	player1.hand = player1.hand.slice(0, 2)
	assert_eq(player1.hand.size(), 2)
	assert_eq(player2.hand.size(), 6)

	execute_strike(player1, player2, "morathi_gyrochaingash", "standard_normal_spike", false, false,
		[2], [])
	validate_life(player1, 30, player2, 28)
	validate_positions(player1, 6, player2, 7)

	assert_eq(player1.hand.size(), 2)
	assert_eq(player2.hand.size(), 6)

	assert_eq(player2.discards.size(), 1)

	advance_turn(player2)


func test_morathi_gyrochaingash_nohand():
	position_players(player1, 4, player2, 7)
	player1.discard_hand()
	var gash = give_player_specific_card(player1, "morathi_gyrochaingash")
	var p2strike = give_player_specific_card(player2, "standard_normal_spike")
	assert_true(game_logic.do_strike(player1, gash, false, -1))
	assert_true(game_logic.do_strike(player2, p2strike, false, -1))
	# Choice should not come up because no cards!
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 28)
	advance_turn(player2)

func test_morathi_gyrochaingash_1hand_pass():
	position_players(player1, 4, player2, 7)
	player1.discard_hand()
	give_player_specific_card(player1, "standard_normal_assault")
	var gash = give_player_specific_card(player1, "morathi_gyrochaingash")
	var p2strike = give_player_specific_card(player2, "standard_normal_spike")
	assert_true(game_logic.do_strike(player1, gash, false, -1))
	assert_true(game_logic.do_strike(player2, p2strike, false, -1))
	# P1 has choice between discard 1 and pass.
	assert_true(game_logic.do_choice(player1, 1))
	assert_eq(player1.hand.size(), 1)
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 28)
	advance_turn(player2)


func test_morathi_gyrochaingash_2hand_pass():
	position_players(player1, 4, player2, 7)
	player1.discard_hand()
	give_player_specific_card(player1, "standard_normal_assault")
	give_player_specific_card(player1, "standard_normal_assault")
	var gash = give_player_specific_card(player1, "morathi_gyrochaingash")
	var p2strike = give_player_specific_card(player2, "standard_normal_spike")
	assert_true(game_logic.do_strike(player1, gash, false, -1))
	assert_true(game_logic.do_strike(player2, p2strike, false, -1))
	# P1 has choice between discard 1 and pass.
	assert_true(game_logic.do_choice(player1, 2))
	assert_eq(player1.hand.size(), 2)
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 28)
	advance_turn(player2)

func test_morathi_gyrochaingash_1hand_discard():
	position_players(player1, 4, player2, 7)
	player1.discard_hand()
	give_player_specific_card(player1, "standard_normal_assault")
	var gash = give_player_specific_card(player1, "morathi_gyrochaingash")
	var p2strike = give_player_specific_card(player2, "standard_normal_spike")
	assert_true(game_logic.do_strike(player1, gash, false, -1))
	assert_true(game_logic.do_strike(player2, p2strike, false, -1))
	# P1 has choice between discard 1 and pass.
	assert_true(game_logic.do_choice(player1, 0))
	assert_eq(player1.hand.size(), 0)
	assert_true(game_logic.do_choose_to_discard(player2, [player2.hand[0].id]))
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 27)
	advance_turn(player2)
	
	
func test_morathi_gyrochaingash_2hand_discard():
	position_players(player1, 4, player2, 7)
	player1.discard_hand()
	give_player_specific_card(player1, "standard_normal_assault")
	give_player_specific_card(player1, "standard_normal_assault")
	var gash = give_player_specific_card(player1, "morathi_gyrochaingash")
	var p2strike = give_player_specific_card(player2, "standard_normal_spike")
	assert_true(game_logic.do_strike(player1, gash, false, -1))
	assert_true(game_logic.do_strike(player2, p2strike, false, -1))
	# P1 has choice between discard 1 and pass.
	assert_true(game_logic.do_choice(player1, 1))
	assert_eq(player1.hand.size(), 0)
	assert_true(game_logic.do_choose_to_discard(player2, [player2.hand[0].id, player2.hand[1].id]))
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 26)
	advance_turn(player2)
	
func test_morathi_gyrochaingash_discard_onlyhas_2_doit():
	position_players(player1, 4, player2, 7)

	player1.hand = player1.hand.slice(0, 2)
	assert_eq(player1.hand.size(), 2)
	assert_eq(player2.hand.size(), 6)

	var p2discards = [
		player2.hand[0].id,
		player2.hand[1].id,
	]
	execute_strike(player1, player2, "morathi_gyrochaingash", "standard_normal_spike", false, false,
		[1], [p2discards])
	validate_life(player1, 30, player2, 26)
	validate_positions(player1, 6, player2, 7)

	assert_eq(player1.hand.size(), 0)
	assert_eq(player2.hand.size(), 4)

	assert_eq(player2.discards.size(), 3)

	advance_turn(player2)


func test_morathi_necksnapper_discard_3():
	position_players(player1, 4, player2, 7)

	assert_eq(player1.hand.size(), 5)
	assert_eq(player2.hand.size(), 6)

	var p2discards = [
		player2.hand[0].id,
		player2.hand[1].id,
		player2.hand[2].id,
	]
	execute_strike(player1, player2, "morathi_necksnapper", "standard_normal_assault", false, false,
		[2], [p2discards])
	validate_life(player1, 30, player2, 26)
	validate_positions(player1, 6, player2, 7)

	assert_eq(player1.hand.size(), 2)
	assert_eq(player2.hand.size(), 3)

	assert_eq(player2.discards.size(), 4)
	assert_eq(player2.discards[0].id, p2discards[0])
	assert_eq(player2.discards[1].id, p2discards[1])
	assert_eq(player2.discards[2].id, p2discards[2])

	advance_turn(player2)


func test_morathi_necksnapper_discard_3_force_special_up_discards():
	position_players(player1, 3, player2, 7)

	assert_eq(player1.hand.size(), 5)
	assert_eq(player2.hand.size(), 6)

	var p2discards = [
		player2.hand[0].id,
		player2.hand[1].id,
		player2.hand[2].id,
		player2.hand[3].id,
	]
	execute_strike(player1, player2, "morathi_necksnapper", "hazama_fallingfang", false, false,
		[2], [[player2.hand[4].id], p2discards])
	validate_life(player1, 30, player2, 26)
	validate_positions(player1, 6, player2, 7)

	assert_eq(player1.hand.size(), 2)
	assert_eq(player2.hand.size(), 1)

	assert_eq(player2.discards.size(), 6)
	assert_eq(player2.discards[1].id, p2discards[0])
	assert_eq(player2.discards[2].id, p2discards[1])
	assert_eq(player2.discards[3].id, p2discards[2])
	assert_eq(player2.discards[4].id, p2discards[3])

	advance_turn(player2)


func test_morathi_shadowofdeath_invalid():
	position_players(player1, 5, player2, 7)
	give_gauge(player1, 7)
	player1.discard_hand()
	assert_eq(player1.hand.size(), 0)
	set_player_topdeck(player1, "standard_normal_assault")
	var shadow = set_player_topdeck(player1, "morathi_shadowofdeath")
	execute_strike(player1, player2, -1, "standard_normal_assault", false, false,
		[1], [])
	assert_eq(player1.hand.size(), 1)
	assert_eq(player1.hand[0].id, shadow)
	for card in player1.discards:
		assert_ne(card.id, shadow)
	assert_eq(player1.gauge.size(), 10)
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 26)
	advance_turn(player1)


func test_morathi_shadowofdeath_invalid_after_other_ws():
	position_players(player1, 5, player2, 7)
	give_gauge(player1, 7)
	player1.discard_hand()
	assert_eq(player1.hand.size(), 0)
	set_player_topdeck(player1, "standard_normal_assault")
	var sod_inhand = set_player_topdeck(player1, "morathi_shadowofdeath")
	set_player_topdeck(player1, "morathi_godofwar")
	execute_strike(player1, player2, -1, "standard_normal_assault", false, false,
		[1, [true, true, false]], [])
	assert_eq(player1.hand.size(), 1)
	assert_eq(player1.hand[0].id, sod_inhand)
	assert_eq(player1.gauge.size(), 10)
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 26)
	advance_turn(player1)

func test_morathi_shadowofdeath_not_invalid_ws_anyway():
	position_players(player1, 6, player2, 7)
	give_gauge(player1, 8)
	player1.discard_hand()
	assert_eq(player1.hand.size(), 0)
	set_player_topdeck(player1, "standard_normal_assault")
	set_player_topdeck(player1, "morathi_shadowofdeath")
	execute_strike(player1, player2, -1, "standard_normal_assault", false, false,
		[1, [true, true, false]], [])
	assert_eq(player1.hand.size(), 0)
	assert_eq(player1.gauge.size(), 9)
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 26)
	advance_turn(player1)


func test_morathi_shadowofdeath_not_invalid_pay():
	position_players(player1, 6, player2, 7)
	var p1gauge = give_gauge(player1, 8)
	player1.discard_hand()
	assert_eq(player1.hand.size(), 0)
	set_player_topdeck(player1, "standard_normal_assault")
	set_player_topdeck(player1, "morathi_shadowofdeath")
	execute_strike(player1, player2, -1, "standard_normal_grasp", false, false,
		[1, p1gauge], [])
	assert_eq(player1.hand.size(), 0)
	assert_eq(player1.gauge.size(), 1)
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 15)
	advance_turn(player2)

func test_morathi_revenger_boost():
	position_players(player1, 4, player2, 7)
	give_player_specific_card(player1, "morathi_revenger")
	set_player_topdeck(player1, "standard_normal_assault")
	set_player_topdeck(player2, "standard_normal_sweep")
	assert_true(game_logic.do_boost(player1, player1.hand[-1].id, [player1.hand[0].id,player1.hand[1].id, player1.hand[2].id]))
	assert_true(game_logic.do_strike(player1, -1, true, -1))
	assert_true(game_logic.do_choice(player1, 1))
	assert_true(game_logic.do_strike(player2, -1, true, -1))
	assert_true(game_logic.do_choice(player2, 1))
	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 24, player2, 26)
	advance_turn(player1)
