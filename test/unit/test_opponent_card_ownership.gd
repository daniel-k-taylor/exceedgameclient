extends ExceedGutTest

# Rulings coverage: a card owned by the opponent can never enter your hand or
# your deck. Effects that would put it there discard it instead (it goes to its
# owner's discard pile). Gauge, sealed, and character-specific zones such as
# Umina's Dreamlands may legally hold an opponent's card.
#
# Bug report that motivated this: an Umina player ended up holding the
# opponent's Low Tiger Shot. Umina can legally steal an opponent card into her
# Dreamlands or gauge, and a later "gauge to hand" / "to top of deck" effect
# leaked it into her own hand.

func who_am_i():
	return "umina"

# Builds a card owned by `owner` without placing it in any zone.
func _make_card_owned_by(owner : Player, def_id : String) -> GameCard:
	var card_id = give_player_specific_card(owner, def_id)
	owner.remove_card_from_hand(card_id, false, false)
	return game_logic.get_card_database().get_card(card_id)

func _assert_went_to_owners_discard(card : GameCard):
	assert_true(player2.is_card_in_discards(card.id),
		"the opponent's card should end up in their own discard pile")
	assert_false(player1.is_card_in_hand(card.id), "it must not be in the thief's hand")
	assert_false(player1.is_card_in_deck(card.id), "it must not be in the thief's deck")
	assert_false(player1.is_card_in_discards(card.id),
		"it must not be in the thief's discard pile")

func test_opponent_card_cannot_be_added_to_your_hand():
	var stolen = _make_card_owned_by(player2, "standard_normal_focus")

	player1.add_to_hand(stolen, true)

	_assert_went_to_owners_discard(stolen)

func test_opponent_card_cannot_be_put_on_top_of_your_deck():
	var stolen = _make_card_owned_by(player2, "standard_normal_focus")
	var deck_size_before = player1.deck.size()

	player1.add_to_top_of_deck(stolen, true)

	_assert_went_to_owners_discard(stolen)
	assert_eq(player1.deck.size(), deck_size_before, "the thief's deck should be untouched")

func test_stolen_card_in_gauge_is_discarded_instead_of_returning_to_hand():
	# The reported leak: Umina legally holds an opponent card in gauge, then a
	# "return gauge to hand" effect moves it into her hand.
	var stolen = _make_card_owned_by(player2, "standard_normal_focus")
	player1.gauge.append(stolen)

	player1.move_card_from_gauge_to_hand(stolen.id)

	assert_false(player1.is_card_in_gauge(stolen.id), "the card should leave the gauge")
	_assert_went_to_owners_discard(stolen)

func test_returning_all_gauge_to_hand_leaves_stolen_cards_behind():
	var stolen = _make_card_owned_by(player2, "standard_normal_focus")
	var own_card = _make_card_owned_by(player1, "standard_normal_grasp")
	player1.gauge.append(stolen)
	player1.gauge.append(own_card)

	player1.return_all_cards_gauge_to_hand()

	assert_true(player1.is_card_in_hand(own_card.id), "your own gauge cards still return to hand")
	_assert_went_to_owners_discard(stolen)

func test_stolen_card_in_sealed_is_not_shuffled_into_your_deck():
	var stolen = _make_card_owned_by(player2, "standard_normal_focus")
	var own_card = _make_card_owned_by(player1, "standard_normal_grasp")
	player1.sealed.append(stolen)
	player1.sealed.append(own_card)

	player1.shuffle_sealed_to_deck()

	assert_true(player1.is_card_in_deck(own_card.id), "your own sealed cards still shuffle in")
	_assert_went_to_owners_discard(stolen)

func test_stolen_card_in_sealed_cannot_be_moved_to_your_hand():
	var stolen = _make_card_owned_by(player2, "standard_normal_focus")
	player1.sealed.append(stolen)

	player1.move_card_from_sealed_to_hand(stolen.id)

	assert_false(player1.is_card_in_sealed(stolen.id))
	_assert_went_to_owners_discard(stolen)

func test_stolen_card_in_sealed_cannot_be_moved_to_your_top_deck():
	var stolen = _make_card_owned_by(player2, "standard_normal_focus")
	player1.sealed.append(stolen)

	player1.move_card_from_sealed_to_top_deck(stolen.id)

	assert_false(player1.is_card_in_sealed(stolen.id))
	_assert_went_to_owners_discard(stolen)

func test_stolen_card_in_dreamlands_cannot_be_sent_to_your_deck():
	# Umina's Dreamlands is a set-aside zone, so it may hold an opponent card,
	# but an effect that puts a set-aside card on top of the deck must not let it
	# be drawn.
	var stolen = _make_card_owned_by(player2, "standard_normal_focus")
	player1.set_aside_cards.append(stolen)
	var deck_size_before = player1.deck.size()

	player1.add_set_aside_card_to_deck(stolen.definition['id'])

	_assert_went_to_owners_discard(stolen)
	assert_eq(player1.deck.size(), deck_size_before)

func test_stolen_card_may_still_be_held_in_gauge_and_dreamlands():
	var gauge_card = _make_card_owned_by(player2, "standard_normal_focus")
	var dreamlands_card = _make_card_owned_by(player2, "standard_normal_grasp")

	player1.add_to_gauge(gauge_card)
	player1.add_to_set_aside(dreamlands_card)

	assert_true(player1.is_card_in_gauge(gauge_card.id),
		"gauge may legally hold an opponent's card")
	assert_eq(player1.set_aside_cards[-1].id, dreamlands_card.id,
		"Dreamlands may legally hold an opponent's card")
	assert_false(player2.is_card_in_discards(gauge_card.id))
	assert_false(player2.is_card_in_discards(dreamlands_card.id))

func test_stolen_card_may_still_be_sealed():
	var stolen = _make_card_owned_by(player2, "standard_normal_focus")

	player1.add_to_sealed(stolen)

	assert_true(player1.is_card_in_sealed(stolen.id),
		"the sealed zone may legally hold an opponent's card")
	assert_false(player2.is_card_in_discards(stolen.id))

func test_returning_a_stolen_card_to_its_owners_hand_is_still_allowed():
	# Umina evicting a stolen Dreamlands card back to its owner's hand is legal.
	var stolen = _make_card_owned_by(player2, "standard_normal_focus")

	player2.add_to_hand(stolen, true)

	assert_true(player2.is_card_in_hand(stolen.id))
	assert_false(player2.is_card_in_discards(stolen.id))

func test_your_own_cards_are_unaffected():
	var own_card = _make_card_owned_by(player1, "standard_normal_focus")

	player1.add_to_hand(own_card, true)
	assert_true(player1.is_card_in_hand(own_card.id))

	player1.move_card_from_hand_to_deck(own_card.id)
	assert_true(player1.is_card_in_deck(own_card.id))

	var second_card = _make_card_owned_by(player1, "standard_normal_grasp")
	player1.add_to_hand(second_card, true)
	player1.shuffle_card_from_hand_to_deck(second_card.id)
	assert_true(player1.is_card_in_deck(second_card.id))

#
# A card can legally sit in the opponent's boost zone (Faust's Snip Snip Snip
# gives the attack to the opponent as a continuous boost). When that boost
# leaves play it must go to its owner's discard pile, not the holder's.
#

# Player 1 (the owner) strikes with Snip Snip Snip, which hits and moves to
# player 2's boost zone. Returns the boost card.
func _give_snip_boost_to_opponent() -> GameCard:
	position_players(player1, 3, player2, 4)
	execute_strike(player1, player2, "faust_snipsnipsnip", "standard_normal_assault", false, false,
		[], [])
	assert_eq(player2.continuous_boosts.size(), 1,
		"Snip Snip Snip should have moved to the opponent's boost zone")
	return player2.continuous_boosts[0]

func _assert_boost_went_to_owners_discard(card : GameCard):
	assert_false(player2.is_card_in_continuous_boosts(card.id), "it should leave the boost zone")
	assert_true(player1.is_card_in_discards(card.id),
		"the boost should be discarded to its owner's discard pile")
	assert_false(player2.is_card_in_discards(card.id),
		"it must not land in the holder's discard pile")

func test_stolen_boost_discarded_from_play_goes_to_owners_discard():
	var snip = _give_snip_boost_to_opponent()

	player2.remove_from_continuous_boosts(snip)

	_assert_boost_went_to_owners_discard(snip)

func test_stolen_boost_discarded_at_cleanup_goes_to_owners_discard():
	var snip = _give_snip_boost_to_opponent()

	player2.cleanup_continuous_boosts()

	_assert_boost_went_to_owners_discard(snip)

func test_stolen_boost_returned_to_hand_goes_to_its_owners_hand():
	# "owner_hand" boost destinations already target the owner, and that stays
	# legal because it is the owner's own hand.
	var snip = _give_snip_boost_to_opponent()

	player2.remove_from_continuous_boosts(snip, "hand")

	assert_false(player2.is_card_in_continuous_boosts(snip.id))
	assert_true(player1.is_card_in_hand(snip.id))
	assert_false(player2.is_card_in_hand(snip.id))

func test_stolen_boost_sent_to_gauge_or_sealed_stays_with_the_holder():
	var snip = _give_snip_boost_to_opponent()
	player2.remove_from_continuous_boosts(snip, "gauge")
	assert_true(player2.is_card_in_gauge(snip.id),
		"gauge may legally hold an opponent's card")

	var snip2 = _make_card_owned_by(player1, "faust_snipsnipsnip")
	player2.add_to_continuous_boosts(snip2)
	player2.remove_from_continuous_boosts(snip2, "sealed")
	assert_true(player2.is_card_in_sealed(snip2.id),
		"the sealed zone may legally hold an opponent's card")
