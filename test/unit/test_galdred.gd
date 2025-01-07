extends ExceedGutTest

func who_am_i():
	return "galdred"

##
## Tests start here
##

## Galdred normal UA: Instead of drawing at end of turn, draw or discard to 3 cards
func test_galdred_ua_discard_to_3():
	position_players(player1, 3, player2, 7)
	assert_eq(len(player1.hand), 5)
	assert_eq(len(player2.hand), 6)

	game_logic.do_prepare(player1)
	game_logic.do_choose_to_discard(player1, get_cards_from_hand(player1, 3))

	game_logic.do_prepare(player2)
	game_logic.do_choose_to_discard(player2, get_cards_from_hand(player2, 4))

	assert_eq(len(player1.hand), 3)
	assert_eq(len(player2.hand), 3)
	advance_turn(player1)

func test_galdred_ua_draw_to_3():
	position_players(player1, 3, player2, 7)
	player1.discard_hand()
	player2.discard(get_cards_from_hand(player2, 5))
	assert_eq(len(player1.hand), 0)
	assert_eq(len(player2.hand), 1)

	game_logic.do_prepare(player1)
	game_logic.do_prepare(player2)

	assert_eq(len(player1.hand), 3)
	assert_eq(len(player2.hand), 3)
	advance_turn(player1)

## Galdred Exceed UA: When you Exceed, Strike. When Striking, you may use the attack on this card.
## 		(1~2/6/6) -- -1 Power and -1 Speed per card in hand. Hit: Add bottom of discard to Gauge.
func test_galdred_exceed_ua_strike_empty_hand():
	position_players(player1, 3, player2, 5)

	var gauge_cards = give_gauge(player1, 6)
	var first_discard = player1.hand[0].id
	player1.discard([first_discard])
	player1.discard_hand()
	assert_eq(len(player1.hand), 0)

	game_logic.do_exceed(player1, gauge_cards)
	execute_strike(player1, player2, -1, "standard_normal_cross", false, false,
		[], [], false, "", "", true, false) # Player 1 strikes with face attack

	validate_positions(player1, 3, player2, 5)
	validate_life(player1, 30, player2, 24)
	validate_gauge(player1, 1, first_discard)
	advance_turn(player2)

func test_galdred_exceed_ua_strike_non_empty_hand():
	position_players(player1, 3, player2, 5)

	var gauge_cards = give_gauge(player1, 6)
	var first_discard = player1.hand[0].id
	player1.discard([first_discard])
	player1.discard_hand()
	player1.draw(2)
	assert_eq(len(player1.hand), 2)

	game_logic.do_exceed(player1, gauge_cards)
	execute_strike(player1, player2, -1, "standard_normal_assault", false, false,
		[], [], false, "", "", true, false) # Player 1 strikes with face attack

	validate_positions(player1, 3, player2, 4)
	validate_life(player1, 26, player2, 30)
	validate_gauge(player1, 0, -1)
	advance_turn(player2)

func test_galdred_exceed_ua_no_draw_discard_to_3():
	position_players(player1, 3, player2, 7)
	assert_eq(len(player1.hand), 5)

	var gauge_cards = give_gauge(player1, 6)
	game_logic.do_exceed(player1, gauge_cards)
	execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_grasp",
		false, false) #mutual whiff

	assert_eq(len(player1.hand), 5)
	advance_turn(player2)

## Blood Frenzy (1~3/2/5) -- Hit: You may transform a card from your hand.
func test_galdred_bloodfrenzy_transform():
	position_players(player1, 3, player2, 6)
	var tfcard = give_player_specific_card(player1, "galdred_eviscerate")

	execute_strike(player1, player2, "galdred_bloodfrenzy", "standard_normal_grasp", false, false,
		[], [], true)
	game_logic.do_choice(player1, 0) # accept prompt to transform a card on hit
	game_logic.do_boost(player1, tfcard)
	game_logic.do_choice(player1, 1) # decline transforming blood frenzy itself

	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 30, player2, 28)
	assert_eq(len(player1.transforms), 1)
	assert_true(player1.is_card_in_transforms(tfcard))
	advance_turn(player2)

func test_galdred_bloodfrenzy_no_transform_in_hand():
	position_players(player1, 3, player2, 6)
	player1.discard_hand()
	give_player_specific_card(player1, "standard_normal_assault")
	give_player_specific_card(player1, "galdred_metamorphosis")

	execute_strike(player1, player2, "galdred_bloodfrenzy", "standard_normal_grasp", false, false,
		[0, 1], []) # hit transform prompt does nothing; decline transforming blood frenzy itself

	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 30, player2, 28)
	assert_eq(len(player1.transforms), 0)
	advance_turn(player2)

func test_galdred_bloodfrenzy_already_transformed_card_in_hand():
	position_players(player1, 3, player2, 6)
	player1.discard_hand()
	var handcard = give_player_specific_card(player1, "galdred_eviscerate")

	var tfcard = give_player_specific_card(player1, "galdred_eviscerate")
	player1.add_to_transforms(player1.hand[-1])

	execute_strike(player1, player2, "galdred_bloodfrenzy", "standard_normal_grasp", false, false,
		[0, 1], []) # hit transform prompt does nothing; decline transforming blood frenzy itself

	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 30, player2, 28)
	assert_eq(len(player1.transforms), 1)
	assert_true(player1.is_card_in_transforms(tfcard))
	assert_true(player1.is_card_in_hand(handcard))
	advance_turn(player2)

## Violent Transgression (2~3/4/5) -- Ignore Armor. Hit: If you have <=1 cards in hand, gain Advantage
func test_galdred_violenttransgression_low_hand():
	position_players(player1, 3, player2, 6)
	player1.discard_hand()
	player1.draw(1)

	execute_strike(player1, player2, "galdred_violenttransgression", "standard_normal_focus", false, false,
		[1], []) # decline transformation

	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 30, player2, 26)
	advance_turn(player1)

func test_galdred_violenttransgression_large_hand():
	position_players(player1, 3, player2, 6)
	player1.discard_hand()
	player1.draw(2)

	execute_strike(player1, player2, "galdred_violenttransgression", "standard_normal_focus", false, false,
		[1], []) # decline transformation

	validate_positions(player1, 3, player2, 6)
	validate_life(player1, 30, player2, 26)
	advance_turn(player2)

## Blood Frenzy transform -- You may boost from gauge. When you do, add top of deck to Gauge.
func test_galdred_secretformula_instant():
	position_players(player1, 3, player2, 7)

	give_player_specific_card(player1, "galdred_bloodfrenzy")
	player1.add_to_transforms(player1.hand[-1])
	player1.discard_hand()

	var boostcard_id = give_player_specific_card(player1, "standard_normal_cross")
	player1.move_card_from_hand_to_gauge(boostcard_id)
	var topdeck_card = player1.deck[0]

	game_logic.do_boost(player1, boostcard_id) # boosting cross from gauge
	assert_eq(len(player1.gauge), 0) # topdeck not added to gauge immediately
	game_logic.do_choice(player1, 2) # choose to advance 3

	assert_eq(len(player1.gauge), 1) # boost resolved, topdeck added to gauge
	assert_true(player1.is_card_in_discards(boostcard_id))
	assert_true(player1.is_card_in_gauge(topdeck_card.id))
	validate_positions(player1, 6, player2, 7)
	advance_turn(player2)

func test_galdred_secretformula_continuous():
	position_players(player1, 3, player2, 7)

	give_player_specific_card(player1, "galdred_bloodfrenzy")
	player1.add_to_transforms(player1.hand[-1])
	player1.discard_hand()

	var boostcard_id = give_player_specific_card(player1, "standard_normal_sweep")
	player1.move_card_from_hand_to_gauge(boostcard_id)
	var topdeck_card = player1.deck[0]

	game_logic.do_boost(player1, boostcard_id) # boosting sweep from gauge

	assert_eq(len(player1.gauge), 1) # boost resolved, topdeck added to gauge
	assert_true(player1.is_card_in_continuous_boosts(boostcard_id))
	assert_true(player1.is_card_in_gauge(topdeck_card.id))
	validate_positions(player1, 3, player2, 7)
	advance_turn(player2)

## Explosive Cocktail transform -- You may generate force by spending 1 life for 1 force.
func test_galdred_hiddenstrength_change_cards():
	position_players(player1, 3, player2, 7)

	player1.discard_hand()
	var tfcard1 = give_player_specific_card(player1, "galdred_explosivecocktail")
	var tfcard2 = give_player_specific_card(player1, "galdred_explosivecocktail")
	game_logic.do_ex_transform(player1, tfcard1, tfcard2)
	player2.discard_hand()
	advance_turn(player2)

	player1.discard_hand()
	assert_eq(len(player1.hand), 0)
	game_logic.do_change(player1, [], false, false, 3) # cc with 3 life

	assert_eq(len(player1.hand), 3)
	validate_life(player1, 27, player2, 30)
	advance_turn(player2)

func test_galdred_hiddenstrength_move():
	position_players(player1, 3, player2, 7)

	player1.discard_hand()
	var tfcard1 = give_player_specific_card(player1, "galdred_explosivecocktail")
	var tfcard2 = give_player_specific_card(player1, "galdred_explosivecocktail")
	game_logic.do_ex_transform(player1, tfcard1, tfcard2)
	player2.discard_hand()
	advance_turn(player2)

	game_logic.do_move(player1, [], 8, false, 5)

	validate_life(player1, 25, player2, 30)
	validate_positions(player1, 8, player2, 7)
	advance_turn(player2)

## Violent Transgression transform -- When setting your attack, you may spend 1 Force for +1 Speed.
func test_galdred_hiddenstrength_fasterthantheeye():
	position_players(player1, 3, player2, 6)

	player1.discard_hand()
	var tfcard1 = give_player_specific_card(player1, "galdred_explosivecocktail")
	var tfcard2 = give_player_specific_card(player1, "galdred_explosivecocktail")
	game_logic.do_ex_transform(player1, tfcard1, tfcard2)
	player2.discard_hand()
	advance_turn(player2)

	give_player_specific_card(player1, "galdred_violenttransgression")
	player1.add_to_transforms(player1.hand[-1])
	player1.discard_hand()

	var p1_card = give_player_specific_card(player1, "standard_normal_dive")
	var p2_card = give_player_specific_card(player2, "standard_normal_assault")
	game_logic.do_strike(player1, p1_card, false, -1, false, false)
	game_logic.do_force_for_effect(player1, [], false, false, false, 1)
	game_logic.do_strike(player2, p2_card, false, -1, false, false)

	validate_life(player1, 29, player2, 25)
	validate_positions(player1, 7, player2, 6)
	advance_turn(player2)

func test_galdred_hiddenstrength_block():
	position_players(player1, 3, player2, 6)

	player1.discard_hand()
	var tfcard1 = give_player_specific_card(player1, "galdred_explosivecocktail")
	var tfcard2 = give_player_specific_card(player1, "galdred_explosivecocktail")
	game_logic.do_ex_transform(player1, tfcard1, tfcard2)
	player2.discard_hand()
	advance_turn(player2)

	execute_strike(player1, player2, "standard_normal_block", "standard_normal_sweep", false, false,
		[], [], true)
	game_logic.do_force_for_armor(player1, [], false, 2)

	validate_life(player1, 28, player2, 30)
	validate_positions(player1, 3, player2, 6)
	advance_turn(player2)

## Withering Toxin transform -- As an action, you may name a card then Strike.
##    That card is invalid for both players during this Strike.
func test_galdred_noescape_opponentcard():
	position_players(player1, 3, player2, 6)

	give_player_specific_card(player1, "galdred_witheringtoxin")
	player1.add_to_transforms(player1.hand[-1])
	player1.discard_hand()

	var wildswing_id = give_player_specific_card(player2, "standard_normal_grasp")
	player2.move_card_from_hand_to_deck(wildswing_id)
	var named_card = give_player_specific_card(player2, "galdred_bloodfrenzy")
	player2.discard([named_card])

	game_logic.do_bonus_turn_action(player1, 0)
	game_logic.do_boost_name_card_choice_effect(player1, named_card)
	var strike_cards = execute_strike(player1, player2, "standard_normal_spike", "galdred_bloodfrenzy")
	# blood frenzy invalidated, grasp should be wild swung

	validate_life(player1, 30, player2, 25)
	validate_positions(player1, 3, player2, 6)
	assert_true(player2.is_card_in_discards(strike_cards[1]))
	assert_true(player2.is_card_in_discards(wildswing_id))
	advance_turn(player2)

func test_galdred_noescape_owncard():
	position_players(player1, 3, player2, 6)

	give_player_specific_card(player1, "galdred_witheringtoxin")
	player1.add_to_transforms(player1.hand[-1])
	player1.discard_hand()

	var wildswing_id = give_player_specific_card(player1, "standard_normal_assault")
	player1.move_card_from_hand_to_deck(wildswing_id)
	var named_card = give_player_specific_card(player1, "galdred_explosivecocktail")
	player1.discard([named_card])

	game_logic.do_bonus_turn_action(player1, 0)
	game_logic.do_boost_name_card_choice_effect(player1, named_card)
	var strike_cards = execute_strike(player1, player2, "galdred_explosivecocktail", "standard_normal_assault")
	# explosive cocktail invalidated, should wild swing assault

	validate_life(player1, 30, player2, 26)
	validate_positions(player1, 5, player2, 6)
	assert_true(player1.is_card_in_discards(strike_cards[0]))
	assert_true(player1.is_card_in_gauge(wildswing_id))
	advance_turn(player1)

func test_galdred_noescape_sharedcard():
	position_players(player1, 3, player2, 6)

	give_player_specific_card(player1, "galdred_witheringtoxin")
	player1.add_to_transforms(player1.hand[-1])
	player1.discard_hand()

	var wildswing_id1 = give_player_specific_card(player1, "standard_normal_assault")
	player1.move_card_from_hand_to_deck(wildswing_id1)
	var wildswing_id2 = give_player_specific_card(player2, "standard_normal_sweep")
	player2.move_card_from_hand_to_deck(wildswing_id2)
	var named_card = give_player_specific_card(player1, "standard_normal_grasp")
	player1.discard([named_card])

	game_logic.do_bonus_turn_action(player1, 0)
	game_logic.do_boost_name_card_choice_effect(player1, named_card)
	var strike_cards = execute_strike(player1, player2, "standard_normal_grasp", "standard_normal_grasp")
	# grasps invalidated, wild swung into assault vs sweep

	validate_life(player1, 24, player2, 26)
	validate_positions(player1, 5, player2, 6)
	assert_true(player1.is_card_in_discards(strike_cards[0]))
	assert_true(player2.is_card_in_discards(strike_cards[1]))
	assert_true(player1.is_card_in_gauge(wildswing_id1))
	assert_true(player2.is_card_in_gauge(wildswing_id2))
	advance_turn(player1)

## Eviscerate transformation -- After resolving an action that doesn't cause a strike,
##    if your hand is empty, you may Strike.
func test_galdred_instinctiveresponse_move_not_empty():
	position_players(player1, 3, player2, 7)

	give_player_specific_card(player1, "galdred_eviscerate")
	player1.add_to_transforms(player1.hand[-1])
	player1.discard_hand()
	player1.draw(2)

	game_logic.do_move(player1, get_cards_from_hand(player1, 1), 4)
	# no prompt to strike if hand not empty

	validate_positions(player1, 4, player2, 7)
	advance_turn(player2)

func test_galdred_instinctiveresponse_move_decline():
	position_players(player1, 3, player2, 7)

	give_player_specific_card(player1, "galdred_eviscerate")
	player1.add_to_transforms(player1.hand[-1])
	player1.discard_hand()
	player1.draw(2)

	game_logic.do_move(player1, get_cards_from_hand(player1, 2), 5)
	game_logic.do_choice(player1, 1) # pass

	validate_positions(player1, 5, player2, 7)
	advance_turn(player2)

func test_galdred_instinctiveresponse_move_strike():
	position_players(player1, 3, player2, 7)

	give_player_specific_card(player1, "galdred_eviscerate")
	player1.add_to_transforms(player1.hand[-1])
	player1.discard_hand()
	player1.draw(2)

	game_logic.do_move(player1, get_cards_from_hand(player1, 2), 5)
	game_logic.do_choice(player1, 0)

	execute_strike(player1, player2, "standard_normal_cross", "standard_normal_assault")

	validate_life(player1, 30, player2, 27)
	validate_positions(player1, 2, player2, 7)
	advance_turn(player2)

func test_galdred_instinctiveresponse_boost_strike():
	position_players(player1, 3, player2, 6)

	give_player_specific_card(player1, "galdred_eviscerate")
	player1.add_to_transforms(player1.hand[-1])
	player1.discard_hand()

	var boost_card = give_player_specific_card(player1, "standard_normal_sweep")

	game_logic.do_boost(player1, boost_card)
	game_logic.do_choice(player1, 0)

	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_dive")

	validate_life(player1, 30, player2, 24)
	validate_positions(player1, 3, player2, 6)
	advance_turn(player2)

func test_galdred_instinctiveresponse_after_transform():
	position_players(player1, 3, player2, 6)

	player1.discard_hand()
	var tfcard1 = give_player_specific_card(player1, "galdred_eviscerate")
	var tfcard2 = give_player_specific_card(player1, "galdred_eviscerate")

	game_logic.do_ex_transform(player1, tfcard1, tfcard2)
	game_logic.do_choice(player1, 0)

	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_grasp")

	validate_life(player1, 30, player2, 24)
	validate_positions(player1, 3, player2, 6)
	advance_turn(player2)

# Hydra Helix boost -- Transform a card from your hand, then discard your hand.
func test_galdred_obsessiveresearch_transform():
	position_players(player1, 3, player2, 6)

	var boostcard = give_player_specific_card(player1, "galdred_hydrahelix")
	var tfcard = give_player_specific_card(player1, "galdred_bloodfrenzy")
	assert_eq(len(player1.hand), 7)
	var previoushand = get_cards_from_hand(player1, 7)

	game_logic.do_boost(player1, boostcard)
	game_logic.do_boost(player1, tfcard)
	# hand discarded, then draws up to 3 for end of turn

	assert_eq(len(player1.hand), 3)
	for handid in previoushand:
		if handid == tfcard:
			assert_true(player1.is_card_in_transforms(handid))
		else:
			assert_true(player1.is_card_in_discards(handid))
	advance_turn(player2)

func test_galdred_obsessiveresearch_no_transforms_in_hand():
	position_players(player1, 3, player2, 6)

	player1.discard_hand()
	var boostcard = give_player_specific_card(player1, "galdred_hydrahelix")
	var card1 = give_player_specific_card(player1, "standard_normal_grasp")
	var card2 = give_player_specific_card(player1, "standard_normal_cross")
	var card3 = give_player_specific_card(player1, "standard_normal_assault")

	game_logic.do_boost(player1, boostcard)
	# no transforms available; hand discarded, then draws up to 3 for end of turn

	assert_eq(len(player1.hand), 3)
	for handid in [card1, card2, card3]:
		assert_true(player1.is_card_in_discards(handid))
	advance_turn(player2)

func test_galdred_obsessiveresearch_instinctiveresponse():
	position_players(player1, 3, player2, 6)

	var boostcard = give_player_specific_card(player1, "galdred_hydrahelix")
	var tfcard = give_player_specific_card(player1, "galdred_eviscerate")

	game_logic.do_boost(player1, boostcard)
	game_logic.do_boost(player1, tfcard)
	# hand discarded; then allows you to strike
	game_logic.do_choice(player1, 0)

	execute_strike(player1, player2, "standard_normal_sweep", "standard_normal_grasp")

	validate_life(player1, 30, player2, 24)
	validate_positions(player1, 3, player2, 6)
	advance_turn(player2)
