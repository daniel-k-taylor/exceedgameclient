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

func test_celinka_moonfall_sustain_and_transform():
	position_players(player1, 3, player2, 7)
	# P1 boost
	assert_eq(player1.hand.size(), 5)
	var grasp = give_player_specific_card(player1, "standard_normal_grasp")
	assert_true(game_logic.do_boost(player1, grasp, []))
	assert_eq(player1.hand.size(), 6)
	# P2's turn.
	# P1 goes first and hits with moonfall.
	# Choice to seal a card from hand to sustain.
	# Choice to transform after too.
	var seal_option = player1.hand[0].id
	execute_strike(player2, player1, "standard_normal_dive", "celinka_moonfall", false, false,
		[], [[seal_option], 0])
	validate_life(player1, 30, player2, 25)
	validate_positions(player1, 6, player2, 7)
	assert_eq(player1.continuous_boosts.size(), 1)
	assert_eq(player1.continuous_boosts[0].id, grasp)
	assert_eq(player1.sealed.size(), 1)

	# P1's turn
	assert_eq(player1.hand.size(), 5)
	# Strike, transform choice to seal attack, if so draw 2 and discard 1.
	# P1 hits first, grasp choice, then end of strike choice, then discard a card
	var to_discard = player1.hand[0].id
	execute_strike(player1, player2, "standard_normal_grasp", "celinka_moonfall", false, false,
		[0, 0, [to_discard]], [])
	validate_life(player1, 30, player2, 20)
	validate_positions(player1, 6, player2, 8)
	assert_eq(player1.hand.size(), 6)
	assert_eq(player1.sealed.size(), 2)
	assert_eq(player1.discards.size(), 2)
	assert_eq(player1.continuous_boosts.size(), 0)


func test_celinka_moonflare_transform():
	position_players(player1, 4, player2, 5)

	give_player_specific_card(player1, "celinka_moonflare")
	player1.add_to_transforms(player1.hand[-1])
	var grasp = give_player_specific_card(player1, "standard_normal_grasp")
	player1.add_to_sealed(player1.hand[-1])
	player1.remove_card_from_hand(grasp, false, false)
	# P2 hits with grasp, pushes, but P1 has guard from the transform.
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_grasp", false, false,
		[], [1])
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 27, player2, 26)


func test_celinka_moonflare_transform_no_effect_if_not_sealed():
	position_players(player1, 4, player2, 5)

	give_player_specific_card(player1, "celinka_moonflare")
	player1.add_to_transforms(player1.hand[-1])
	give_player_specific_card(player1, "standard_normal_grasp")
	# P2 hits with grasp, pushes, but P1 has guard from the transform.
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_grasp", false, false,
		[], [1])
	validate_positions(player1, 2, player2, 5)
	validate_life(player1, 27, player2, 30)


func test_celinka_swiftexorcism():
	position_players(player1, 4, player2, 5)

	# P1 hit push 2, no boost so no move 1 and gain advantage
	# Transform choice at end
	execute_strike(player1, player2, "celinka_swiftexorcism", "standard_normal_sweep", false, false,
		[0], [])
	validate_positions(player1, 4, player2, 7)
	validate_life(player1, 24, player2, 28)


func test_celinka_swiftexorcism_withboost():
	position_players(player1, 4, player2, 5)

	var grasp = give_player_specific_card(player1, "standard_normal_grasp")
	assert_true(game_logic.do_boost(player1, grasp, []))

	# P1 hit push 2 move 1 and gain advantage
	# Transform choice at end
	execute_strike(player2, player1, "standard_normal_sweep", "celinka_swiftexorcism", false, false,
		[], [1, 0])
	validate_positions(player1, 3, player2, 7)
	validate_life(player1, 30, player2, 26)


func test_celinka_swiftexorcism_transform_attack_with_transform():
	position_players(player1, 4, player2, 5)

	give_player_specific_card(player1, "celinka_swiftexorcism")
	player1.add_to_transforms(player1.hand[-1])

	# P1 hit push 2, no boost so no move 1 and gain advantage
	# No transform choice at end since already tf'd
	execute_strike(player1, player2, "celinka_swiftexorcism", "standard_normal_sweep", false, false,
		[], [])
	validate_positions(player1, 4, player2, 7)
	validate_life(player1, 25, player2, 27)


func test_celinka_swiftexorcism_transform_attack_with_sealed():
	position_players(player1, 4, player2, 5)

	give_player_specific_card(player1, "celinka_swiftexorcism")
	player1.add_to_transforms(player1.hand[-1])
	var assault = give_player_specific_card(player1, "standard_normal_assault")
	player1.add_to_sealed(player1.hand[-1])
	player1.remove_card_from_hand(assault, false, false)

	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_sweep", false, false,
		[], [])
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 25, player2, 25)


func test_celinka_swiftexorcism_transform_attack_with_not_sealed():
	position_players(player1, 4, player2, 5)

	give_player_specific_card(player1, "celinka_swiftexorcism")
	player1.add_to_transforms(player1.hand[-1])
	execute_strike(player1, player2, "standard_normal_assault", "standard_normal_sweep", false, false,
		[], [])
	validate_positions(player1, 4, player2, 5)
	validate_life(player1, 24, player2, 26)


func seal_card_named(player, card_name):
	var cardid = give_player_specific_card(player, card_name)
	player.add_to_sealed(player.hand[-1])
	player.remove_card_from_hand(cardid, false, false)

func test_celinka_purifyingroar_notfastenough():
	position_players(player1, 3, player2, 5)
	var p1gauge = give_gauge(player1, 3)
	seal_card_named(player1, "standard_normal_grasp")
	seal_card_named(player1, "standard_normal_assault")
	seal_card_named(player1, "celinka_swiftexorcism")

	execute_strike(player1, player2, "celinka_purifyingroar", "standard_normal_assault", false, false,
		[p1gauge], [])
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 26, player2, 30)


func test_celinka_purifyingroar_multiplesnogood():
	position_players(player1, 3, player2, 5)
	var p1gauge = give_gauge(player1, 3)
	seal_card_named(player1, "standard_normal_grasp")
	seal_card_named(player1, "standard_normal_grasp")
	seal_card_named(player1, "standard_normal_assault")
	seal_card_named(player1, "celinka_swiftexorcism")

	execute_strike(player1, player2, "celinka_purifyingroar", "standard_normal_assault", false, false,
		[p1gauge], [])
	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 26, player2, 30)


func test_celinka_purifyingroar_differentwins():
	position_players(player1, 3, player2, 5)
	var p1gauge = give_gauge(player1, 3)
	seal_card_named(player1, "standard_normal_grasp")
	seal_card_named(player1, "standard_normal_grasp")
	seal_card_named(player1, "celinka_swiftexorcism")
	seal_card_named(player1, "standard_normal_assault")
	seal_card_named(player1, "standard_normal_dive")

	execute_strike(player1, player2, "celinka_purifyingroar", "standard_normal_assault", false, false,
		[p1gauge], [])
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 30, player2, 27)


func test_celinka_moonritualdance_nothingtoreturn():
	position_players(player1, 3, player2, 5)
	var p1gauge = give_gauge(player1, 2)
	execute_strike(player1, player2, "celinka_moonritualdance", "standard_normal_assault", false, false,
		[p1gauge], [])
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 30, player2, 28)


func test_celinka_moonritualdance_returnnormalspecial():
	position_players(player1, 3, player2, 5)
	var p1gauge = give_gauge(player1, 2)
	seal_card_named(player1, "standard_normal_grasp")
	seal_card_named(player1, "celinka_swiftexorcism")
	seal_card_named(player1, "celinka_moonritualdance")
	assert_eq(player1.sealed.size(), 3)
	var return_id = player1.sealed[0].id
	execute_strike(player1, player2, "celinka_moonritualdance", "standard_normal_assault", false, false,
		[p1gauge, return_id], [])
	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 30, player2, 28)
	assert_eq(player1.hand[-1].id, return_id)
	assert_eq(player1.sealed.size(), 2)
