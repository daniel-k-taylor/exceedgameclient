extends ExceedGutTest

func who_am_i():
	return "galdred"

##
## Tests start here
##

## Metamorphosis (2 Gauge) (1/7/6) -- Stun Immunity.
##     Hit: Activate the opponent's Exceed mode without spending their Gauge.

func _setup_metamorphosis_test(opponent_id : String, hand_size : int = 0):
	game_logic.teardown()
	game_logic.free()
	default_game_setup(opponent_id)

	position_players(player1, 4, player2, 5)
	give_gauge(player1, 2)
	player1.discard_hand()
	if hand_size > 0:
		player1.draw(hand_size)

# Galdred mirror - no special effects
func test_galdred_metamorphosis_basic():
	_setup_metamorphosis_test("galdred")

	execute_strike(player1, player2, "galdred_metamorphosis", "standard_normal_focus", false, false,
		[get_cards_from_gauge(player1, 2)])

	assert_true(player2.exceeded)
	validate_life(player1, 26, player2, 25)
	validate_positions(player1, 4, player2, 5)
	advance_turn(player2)

# Testing that kickers aren't repeated if already exceeded
func test_galdred_metamorphosis_already_exceeded():
	_setup_metamorphosis_test("axl")
	advance_turn(player1)
	give_gauge(player2, 3)
	player2.discard_hand()
	game_logic.do_exceed(player2, get_cards_from_gauge(player2, 3))
	game_logic.do_choice(player2, 2) # doesn't retreat
	var initial_hand_size = len(player2.hand)

	execute_strike(player1, player2, "galdred_metamorphosis", "standard_normal_focus", false, false,
		[get_cards_from_gauge(player1, 2)], [])
	# Axl just gets one card from focus, no prompt to retreat

	assert_true(player2.exceeded)
	validate_life(player1, 26, player2, 25)
	validate_positions(player1, 4, player2, 5)
	assert_eq(len(player2.hand), initial_hand_size + 1)
	advance_turn(player2)

# Akuma - critical bonus upgrades
func test_galdred_metamorphosis_akuma():
	_setup_metamorphosis_test("akuma")
	advance_turn(player1)

	give_gauge(player2, 1)
	var defend_card = give_player_specific_card(player2, "standard_normal_spike")
	game_logic.do_boost(player2, defend_card) # plays defend to avoid being stunned

	execute_strike(player1, player2, "galdred_metamorphosis", "standard_normal_focus", false, false,
		[get_cards_from_gauge(player1, 2)], [get_cards_from_gauge(player2, 1)]) # crit focus
	# Exceeding on hit timing gives metamorphosis +3 power, so 10 total - 3 total armor
	# Akuma has 8 total guard, so hits back for 7

	assert_true(player2.exceeded)
	validate_life(player1, 23, player2, 23)
	validate_positions(player1, 4, player2, 5)
	advance_turn(player2)

# Anji - draws a card on exceed; bonus does not change
func test_galdred_metamorphosis_anji():
	_setup_metamorphosis_test("anji")
	var initial_hand_size = len(player2.hand)

	execute_strike(player1, player2, "galdred_metamorphosis", "standard_normal_focus", true, false,
		[get_cards_from_gauge(player1, 2)], [get_cards_from_hand(player2, 1)])
	# EX metamorphosis hits for 8 - 2 armor, doesn't stun 7 guard
	# Hits back for 3 after ex armor
	# Anji spends 1 card for UA, draws 1 for focus and 1 for exceeding - net +1

	assert_true(player2.exceeded)
	validate_life(player1, 27, player2, 24)
	validate_positions(player1, 4, player2, 5)
	assert_eq(len(player2.hand), initial_hand_size + 1)
	advance_turn(player2)

# Arakune - draws 2 cards; specials/ultras lose hit trigger, overdrive UA ignored since attack already revealed
func test_galdred_metamorphosis_arakune():
	_setup_metamorphosis_test("arakune")
	advance_turn(player1)
	var discard_card = get_cards_from_hand(player2, 1)[0]
	player2.discard([discard_card])
	var overdrive_card = give_player_specific_card(player2, "standard_normal_spike")
	player2.move_cards_to_overdrive([overdrive_card], "hand")
	var defend_card = give_player_specific_card(player2, "standard_normal_spike")
	game_logic.do_boost(player2, defend_card)
	var initial_hand_size = len(player2.hand)

	execute_strike(player1, player2, "galdred_metamorphosis", "arakune_permutationnr", false, false,
		[get_cards_from_gauge(player1, 2)], [], true)
	game_logic.do_force_for_effect(player2, get_cards_from_hand(player2, 3), false) # 3 force to hit at r1
	# Metamorphosis hits for 7 - 2 (permutation and defend), does not stun 8 guard
	# Permutation hits back for 5, and moves one of galdred's cards to arakune's overdrive
	# Arakune drew 2 on exceeding and spent 3 force, so net -1 cards in hand
	# Top discard did not go to overdrive, so total 2 cards in there

	assert_true(player2.exceeded)
	validate_life(player1, 25, player2, 25)
	validate_positions(player1, 4, player2, 5)
	assert_eq(len(player2.hand), initial_hand_size - 1)
	assert_eq(len(player2.overdrive), 2)
	assert_true(player2.is_card_in_discards(discard_card))
	# do overdrive effect
	game_logic.do_choose_from_discard(player2, [overdrive_card])
	game_logic.do_choice(player2, 1)
	advance_turn(player2)

# Axl - draws 2 and retreats up to 2; passive changes but likely doesn't matter
func test_galdred_metamorphosis_axl():
	_setup_metamorphosis_test("axl")
	var initial_hand_size = len(player2.hand)

	execute_strike(player1, player2, "galdred_metamorphosis", "standard_normal_focus", false, false,
		[get_cards_from_gauge(player1, 2)], [1]) # retreats 2
	# draws 2 from exceeding and 1 from focus

	assert_true(player2.exceeded)
	validate_life(player1, 26, player2, 25)
	validate_positions(player1, 4, player2, 7)
	assert_eq(len(player2.hand), initial_hand_size + 3)
	advance_turn(player2)

# Baiken - UA does not give power if used
func test_galdred_metamorphosis_baiken():
	_setup_metamorphosis_test("baiken")
	advance_turn(player1)

	position_players(player1, 7, player2, 5)
	var gauge = give_gauge(player2, 1)
	game_logic.do_character_action(player2, gauge)

	execute_strike(player2, player1, "standard_normal_focus", "galdred_metamorphosis", false, false,
		[], [get_cards_from_gauge(player1, 2)])

	assert_true(player2.exceeded)
	validate_life(player1, 26, player2, 25)
	validate_positions(player1, 6, player2, 5)
	advance_turn(player1)

# Bang - EX attacks gain power
func test_galdred_metamorphosis_bang():
	_setup_metamorphosis_test("bang")

	execute_strike(player1, player2, "galdred_metamorphosis", "standard_normal_focus", false, true,
		[get_cards_from_gauge(player1, 2)], [])
	# Metamorphosis does 7 - 3; EX Focus does 4 + 1 + 1

	assert_false(player2.exceeded) # stops being exceeded on turn start due to empty overdrive
	validate_life(player1, 24, player2, 26)
	validate_positions(player1, 4, player2, 5)
	advance_turn(player2)

# Beheaded - gains trait and power/speed, reverts on cleanup
func test_galdred_metamorphosis_beheaded():
	_setup_metamorphosis_test("beheaded")

	var survival_card = null
	for card in player2.set_aside_cards:
		if card.definition['id'] == "beheaded_trait_survival":
			survival_card = card
			break

	execute_strike(player1, player2, "galdred_metamorphosis", "beheaded_assaultshield", false, false,
		[get_cards_from_gauge(player1, 2)], [], true)
	game_logic.do_boost(player2, survival_card.id)
	# Metamorphosis does 7 - 3 damage, does not stun 4 guard
	# Beheaded has 4 Guard and 1 bonus power, so does a total of 6 back

	assert_false(player2.exceeded) # reverted
	validate_life(player1, 24, player2, 26)
	validate_positions(player1, 4, player2, 5)
	advance_turn(player2)

# Byakuya - keeps front side UA bonus if used, EX attacks do not gain power
func test_galdred_metamorphosis_byakuya():
	_setup_metamorphosis_test("byakuya")
	advance_turn(player1)

	var webtrap = give_player_specific_card(player2, "byakuya_becomeapartofme")
	game_logic.do_boost(player2, webtrap)
	game_logic.do_choice(player2, 3) # space 4

	player1.discard_hand()
	advance_turn(player1)
	game_logic.do_character_action(player2, [])

	execute_strike(player2, player1, "standard_normal_focus", "galdred_metamorphosis", true, false,
		[], [get_cards_from_gauge(player1, 2)])
	# Metamorphosis does 7 - 3; ex focus does 4 + 2 + 1 (2 from web trap)

	assert_true(player2.exceeded)
	validate_life(player1, 23, player2, 26)
	validate_positions(player1, 4, player2, 5)
	advance_turn(player1)

# C. Viper - draws 5; attack does not become critical
func test_galdred_metamorphosis_cviper():
	_setup_metamorphosis_test("cviper")
	advance_turn(player1)

	var defend_card1 = give_player_specific_card(player2, "standard_normal_spike")
	game_logic.do_boost(player2, defend_card1)
	game_logic.do_choice(player2, 1) # no strike yet
	player1.discard_hand()
	advance_turn(player1)

	var defend_card2 = give_player_specific_card(player2, "standard_normal_spike")
	game_logic.do_boost(player2, defend_card2)
	game_logic.do_choice(player2, 0) # strike now
	var initial_hand_size = len(player2.hand)
	assert_true(initial_hand_size >= 4)

	execute_strike(player2, player1, "cviper_templemassage", "galdred_metamorphosis", false, false,
		[get_cards_from_hand(player2, 4)], [get_cards_from_gauge(player1, 2)]) # full spend
	# Metamorphosis does 7 - 2, does not stun 6 guard
	# Temple massage does 4 + 4
	# Drew 5 cards for exceeding (but none for crit), so net +1 card

	assert_true(player2.exceeded)
	validate_life(player1, 22, player2, 25)
	validate_positions(player1, 4, player2, 5)
	assert_eq(len(player2.hand), initial_hand_size + 1)
	advance_turn(player1)

# Cammy - gains power and advantage moving past opponent
func test_galdred_metamorphosis_cammy():
	_setup_metamorphosis_test("cammy")
	advance_turn(player1)
	player2.discard_hand()

	var defend_card1 = give_player_specific_card(player2, "standard_normal_spike")
	game_logic.do_boost(player2, defend_card1)
	player1.discard_hand()
	advance_turn(player1)
	var defend_card2 = give_player_specific_card(player2, "standard_normal_spike")
	game_logic.do_boost(player2, defend_card2)
	player1.discard_hand()
	advance_turn(player1)

	execute_strike(player2, player1, "standard_normal_dive", "galdred_metamorphosis", false, false,
		[], [get_cards_from_gauge(player1, 2)]) # full spend
	# Metamorphosis does 7 - 2, does not stun 6 guard
	# Dive does 5 + 1 and gains advantage

	assert_true(player2.exceeded)
	validate_life(player1, 24, player2, 25)
	validate_positions(player1, 4, player2, 1)
	advance_turn(player2)

# Carl Clover - can flip nirvana
func test_galdred_metamorphosis_carlclover():
	_setup_metamorphosis_test("carlclover")
	player2.set_buddy_location("nirvana_active", -1)
	player2.set_buddy_location("nirvana_disabled", 3)
	advance_turn(player1)

	var defend_card1 = give_player_specific_card(player2, "standard_normal_spike")
	game_logic.do_boost(player2, defend_card1)

	execute_strike(player1, player2, "galdred_metamorphosis", "carlclover_conanima", false, false,
		[get_cards_from_gauge(player1, 2)], [])
	# Metamorphosis hits for 7 - 1, does not stun 6 guard
	# con anima just hits for 5, since nirvana wasn't active on set

	assert_false(player2.exceeded) # reverts on cleanup due to empty overdrive
	validate_life(player1, 25, player2, 24)
	validate_positions(player1, 4, player2, 5)
	assert_eq(player2.get_buddy_location("nirvana_active"), 3)
	advance_turn(player2)

# Carl Swangee - normals gain power
func test_galdred_metamorphosis_carlswangee():
	_setup_metamorphosis_test("carlswangee")

	execute_strike(player1, player2, "galdred_metamorphosis", "standard_normal_focus", false, false,
		[get_cards_from_gauge(player1, 2)])

	assert_true(player2.exceeded)
	validate_life(player1, 24, player2, 25)
	validate_positions(player1, 4, player2, 5)
	advance_turn(player2)

# Enchantress - forced to reshuffle, no empty hand draw on cleanup
func test_galdred_metamorphosis_enchantress():
	_setup_metamorphosis_test("enchantress")

	execute_strike(player1, player2, "galdred_metamorphosis", "standard_normal_sweep", false, true,
		[get_cards_from_gauge(player1, 2)])

	assert_true(player2.exceeded)
	validate_life(player1, 23, player2, 24)
	validate_positions(player1, 4, player2, 5)
	assert_eq(len(player2.hand), 0)
	assert_eq(len(player2.deck), 31) # one extra card due to the generated sweep for the EX
	advance_turn(player2)

# Fight - gets to play boosts, keeps existing power bonuses
func test_galdred_metamorphosis_fight():
	_setup_metamorphosis_test("fight")

	var defend_id = give_player_specific_card(player2, "standard_normal_spike")
	var fierce_id = give_player_specific_card(player2, "standard_normal_grasp")
	player2.discard([fierce_id])
	player2.move_card_from_hand_to_gauge(defend_id)

	execute_strike(player1, player2, "galdred_metamorphosis", "standard_normal_sweep", false, false,
		[get_cards_from_gauge(player1, 2)], [get_cards_from_hand(player2, 2)], true)
	game_logic.do_choice(player2, 0) # accept boost choice
	game_logic.do_boost(player2, fierce_id, [], false, 0, [defend_id])
	# Metamorphosis hits for 7 - 1, does not stun 9 guard
	# Sweep hits for 6 + UA 2 + Fierce 2

	assert_true(player2.exceeded)
	validate_life(player1, 20, player2, 24)
	validate_positions(player1, 4, player2, 5)
	assert_true(player2.is_card_in_discards(fierce_id))
	assert_true(player2.is_card_in_discards(defend_id))
	advance_turn(player2)

# Giovanna - can move card from hand to gauge, UA bonus doesn't change
func test_galdred_metamorphosis_giovanna():
	_setup_metamorphosis_test("giovanna")
	advance_turn(player1)

	var gauge_card = give_player_specific_card(player2, "standard_normal_grasp")
	game_logic.do_character_action(player2, [])
	var initial_hand_size = len(player2.hand)

	execute_strike(player2, player1, "standard_normal_focus", "galdred_metamorphosis", false, false,
		[[gauge_card]], [get_cards_from_gauge(player1, 2)])
	# Gio draws 2 but put a card in gauge, so net +1

	assert_true(player2.exceeded)
	validate_life(player1, 26, player2, 25)
	validate_positions(player1, 4, player2, 5)
	assert_eq(len(player2.hand), initial_hand_size + 1)
	assert_true(player2.is_card_in_gauge(gauge_card))
	advance_turn(player1)

# Goldlewis - draws 2, specials gain hit trigger
func test_galdred_metamorphosis_goldlewis():
	_setup_metamorphosis_test("goldlewis")
	var initial_hand_size = len(player2.hand)

	execute_strike(player1, player2, "galdred_metamorphosis", "goldlewis_crush", false, true,
		[get_cards_from_gauge(player1, 2)])
	# Metamorphosis does 7 - 1, doesn't stun 7 guard
	# bt does 6; total of 4 cards drawn

	assert_true(player2.exceeded)
	validate_life(player1, 24, player2, 24)
	validate_positions(player1, 4, player2, 5)
	assert_eq(len(player2.hand), initial_hand_size + 4)
	advance_turn(player2)

# Hakumen - gets discard reshuffle, gauge costs are zero
func test_galdred_metamorphosis_hakumen():
	_setup_metamorphosis_test("hakumen")
	player2.discard_hand()
	assert_true(len(player2.discards) > 0)

	execute_strike(player1, player2, "galdred_metamorphosis", "hakumen_zantetsu", false, true,
		[get_cards_from_gauge(player1, 2)], [[], []])
	# Metamorphosis does 7 - 1, doesn't stun 7 guard
	# zantetsu does 7 + 1 (and ignores armor)

	assert_false(player2.exceeded) # reverts from empty overdrive
	validate_life(player1, 22, player2, 24)
	validate_positions(player1, 4, player2, 5)
	assert_eq(len(player2.discards), 0)
	assert_eq(len(player2.deck), 31) # spawned extra card for EX
	advance_turn(player2)

# Happy Chaos - loses hit trigger, reverts on cleanup
func test_galdred_metamorphosis_happychaos():
	_setup_metamorphosis_test("happychaos")
	give_player_specific_card(player2, "happychaos_steadyaim")

	execute_strike(player1, player2, "galdred_metamorphosis", "standard_normal_focus", false, false,
		[get_cards_from_gauge(player1, 2)])
	# no hit trigger prompt for happy chaos

	assert_false(player2.exceeded) # reverts on cleanup
	validate_life(player1, 26, player2, 25)
	validate_positions(player1, 4, player2, 5)
	advance_turn(player2)

# Tager - loses movement restriction, gains stats
func test_galdred_metamorphosis_tager():
	_setup_metamorphosis_test("tager")
	advance_turn(player1)

	var defend_card1 = give_player_specific_card(player2, "standard_normal_spike")
	game_logic.do_boost(player2, defend_card1)

	execute_strike(player1, player2, "galdred_metamorphosis", "standard_normal_cross", false, false,
		[get_cards_from_gauge(player1, 2)], [0]) # accept movement limit ignore
	# Metamorphosis does 7 - 1, does not stun 7 guard
	# cross does 3 + 1

	assert_false(player2.exceeded) # revert from empty overdrive
	validate_life(player1, 26, player2, 24)
	validate_positions(player1, 4, player2, 8)
	advance_turn(player2)

# Jack-O - draws 3
func test_galdred_metamorphosis_jacko():
	_setup_metamorphosis_test("jacko")
	var initial_hand_size = len(player2.hand)

	execute_strike(player1, player2, "galdred_metamorphosis", "standard_normal_focus", false, false,
		[get_cards_from_gauge(player1, 2)])
	# draws 3 + 1 for focus

	assert_true(player2.exceeded)
	validate_life(player1, 26, player2, 25)
	validate_positions(player1, 4, player2, 5)
	assert_eq(len(player2.hand), initial_hand_size + 4)
	advance_turn(player2)

# Jin - draws 2, keeps old bonus if paid for and gains new ones
func test_galdred_metamorphosis_jin():
	_setup_metamorphosis_test("jin", 2)
	give_gauge(player2, 1)
	var discard_card = get_cards_from_hand(player1, 1)[0]
	var initial_hand_size = len(player2.hand)

	execute_strike(player1, player2, "galdred_metamorphosis", "standard_normal_focus", false, false,
		[get_cards_from_gauge(player1, 2), [discard_card]], # needs to discard one
		[get_cards_from_gauge(player2, 1), 0, 0]) # gain draw effect, choose arbitrary after order
	# Jin draws 2 from frontside after, 2 from exceed, 1 from backside after, and 1 from focus

	assert_false(player2.exceeded) # revert from empty overdrive
	validate_life(player1, 26, player2, 25)
	validate_positions(player1, 4, player2, 5)
	assert_eq(len(player2.hand), initial_hand_size + 6)
	assert_true(player1.is_card_in_discards(discard_card))
	advance_turn(player2)

# King Knight - draws 2
func test_galdred_metamorphosis_king():
	_setup_metamorphosis_test("king")
	var initial_hand_size = len(player2.hand)

	execute_strike(player1, player2, "galdred_metamorphosis", "standard_normal_focus", false, false,
		[get_cards_from_gauge(player1, 2)])
	# draws 2 + 1 for focus

	assert_true(player2.exceeded)
	validate_life(player1, 26, player2, 25)
	validate_positions(player1, 4, player2, 5)
	assert_eq(len(player2.hand), initial_hand_size + 3)
	advance_turn(player2)

# Ken - draws 1 and closes up to 2
func test_galdred_metamorphosis_ken():
	_setup_metamorphosis_test("ken")
	var initial_hand_size = len(player2.hand)

	execute_strike(player1, player2, "galdred_metamorphosis", "standard_normal_focus", false, false,
		[get_cards_from_gauge(player1, 2)], [1]) # chooses to close 2

	assert_true(player2.exceeded)
	validate_life(player1, 26, player2, 25)
	validate_positions(player1, 4, player2, 5)
	assert_eq(len(player2.hand), initial_hand_size + 2)
	advance_turn(player2)

# Kokonoe - can place graviton, can spend force as gauge
func test_galdred_metamorphosis_kokonoe():
	_setup_metamorphosis_test("kokonoe")
	advance_turn(player1)

	player2.set_buddy_location("gravitron", 8)
	var boostcard = give_player_specific_card(player2, "kokonoe_brokenbunkerassault")
	game_logic.do_boost(player2, boostcard)
	game_logic.do_choice(player2, 8) # graviton on space 8
	var forcecards = get_cards_from_hand(player2, 3)

	execute_strike(player1, player2, "galdred_metamorphosis", "standard_normal_focus", false, false,
		[get_cards_from_gauge(player1, 2)],
		[[forcecards[0]], 1, # activates graviton, moves it to space 1,
			[forcecards[1], forcecards[2]]]) # full spends on boost
	# Metamorphosis hits for 7 - 4
	# Focus hits for 4 + 2, and galdred is pushed a total of 3

	assert_false(player2.exceeded) # reverts from empty overdrive
	validate_life(player1, 24, player2, 27)
	validate_positions(player1, 1, player2, 5)
	advance_turn(player2)

# Leo - gains wild swing bonuses
func test_galdred_metamorphosis_leo():
	_setup_metamorphosis_test("leo")
	var focuscard = give_player_specific_card(player2, "standard_normal_focus")
	player2.move_card_from_hand_to_deck(focuscard)

	execute_strike(player1, player2, "galdred_metamorphosis", "", false, false,
		[get_cards_from_gauge(player1, 2)])
	# wild swung focus gains +1 power

	assert_true(player2.exceeded)
	validate_life(player1, 25, player2, 25)
	validate_positions(player1, 4, player2, 5)
	advance_turn(player2)

# Londrekia - keeps frontside bonuses if used, reverts if stunned
func test_galdred_metamorphosis_londrekia_stunned():
	_setup_metamorphosis_test("londrekia")
	give_gauge(player2, 3)
	var initial_hand_size = len(player2.hand)

	execute_strike(player1, player2, "galdred_metamorphosis", "standard_normal_assault", false, false,
		[get_cards_from_gauge(player1, 2)])

	assert_false(player2.exceeded) # stunned and reverted
	validate_life(player1, 30, player2, 23)
	validate_positions(player1, 4, player2, 5)
	assert_eq(len(player2.hand), initial_hand_size + 3)
	assert_eq(len(player2.gauge), 0)
	advance_turn(player2)

func test_galdred_metamorphosis_londrekia_notstunned():
	_setup_metamorphosis_test("londrekia")
	advance_turn(player1)

	give_gauge(player2, 2)
	game_logic.do_character_action(player2, [])
	var initial_hand_size = len(player2.hand)

	execute_strike(player2, player1, "standard_normal_focus", "galdred_metamorphosis", false, false,
		[0, 0, 0], # arbitrary after resolution order, choose to advance
		[get_cards_from_gauge(player1, 2)])
	# draws 2 plus one for focus

	assert_true(player2.exceeded)
	validate_life(player1, 26, player2, 25)
	validate_positions(player1, 4, player2, 3)
	assert_eq(len(player2.hand), initial_hand_size + 3)
	advance_turn(player1)

# M.Bison - gets to use UA
func test_galdred_metamorphosis_bison():
	_setup_metamorphosis_test("bison")
	var initial_hand_size = len(player2.hand)
	var gauge_cards = get_cards_from_hand(player2, 3)

	execute_strike(player1, player2, "galdred_metamorphosis", "standard_normal_focus", false, false,
		[get_cards_from_gauge(player1, 2)], [gauge_cards])

	assert_true(player2.exceeded)
	validate_life(player1, 26, player2, 25)
	validate_positions(player1, 4, player2, 5)
	assert_eq(len(player2.hand), initial_hand_size + 1)
	for card in gauge_cards:
		assert_true(player2.is_card_in_gauge(card))
	advance_turn(player2)

# May - draws 2, keeps original power bonus
func test_galdred_metamorphosis_may():
	_setup_metamorphosis_test("may")
	advance_turn(player1)
	var initial_hand_size = len(player2.hand)

	execute_strike(player2, player1, "standard_normal_focus", "galdred_metamorphosis", false, false,
		[get_cards_from_hand(player2, 1)], [get_cards_from_gauge(player1, 2)])
	# spends 1 force, draws 1 + 2 cards, has +1 power

	assert_true(player2.exceeded)
	validate_life(player1, 25, player2, 25)
	validate_positions(player1, 4, player2, 5)
	assert_eq(len(player2.hand), initial_hand_size + 2)
	advance_turn(player1)

# Mole Knight - does not gain power bonus from burrow
func test_galdred_metamorphosis_mole():
	_setup_metamorphosis_test("mole")
	advance_turn(player1)
	player2.set_buddy_location("burrow", 3)

	execute_strike(player2, player1, "standard_normal_focus", "galdred_metamorphosis", false, false,
		[0], [get_cards_from_gauge(player1, 2)]) # move to burrow

	assert_true(player2.exceeded)
	validate_life(player1, 26, player2, 25)
	validate_positions(player1, 4, player2, 3)
	advance_turn(player1)

# nagoryuki - specials lose cleanup effect, normals gain power and cleanup effect
func test_galdred_metamorphosis_nago_special():
	_setup_metamorphosis_test("nago")
	var initial_hand_size = len(player2.hand)

	execute_strike(player1, player2, "galdred_metamorphosis", "nago_shizuriyuki", false, true,
		[get_cards_from_gauge(player1, 2)], [[]]) # does not spend force
	# metamorphosis does 7 - 1, doesn't stun 6 guard
	# ex shizuriyuki does 3 + 1; no draw or cleanup damage

	assert_true(player2.exceeded)
	validate_life(player1, 26, player2, 24)
	validate_positions(player1, 4, player2, 5)
	assert_eq(len(player2.hand), initial_hand_size)
	advance_turn(player2)

func test_galdred_metamorphosis_nago_normal():
	_setup_metamorphosis_test("nago")
	var initial_hand_size = len(player2.hand)

	execute_strike(player1, player2, "galdred_metamorphosis", "standard_normal_focus", false, false,
		[get_cards_from_gauge(player1, 2)])

	assert_true(player2.exceeded)
	validate_life(player1, 25, player2, 23)
	validate_positions(player1, 4, player2, 5)
	assert_eq(len(player2.hand), initial_hand_size + 1)
	advance_turn(player2)

# Nine - loses hit effect, gains cleanup effect
func test_galdred_metamorphosis_nine_stunned():
	_setup_metamorphosis_test("nine")

	var swap_card = null
	for card in player2.sealed:
		if card.definition['speed'] == 5:
			swap_card = card.id
			break
	var force_card = player2.hand[0].id

	var strike_cards = execute_strike(player1, player2, "galdred_metamorphosis", "standard_normal_assault",
		false, false, [get_cards_from_gauge(player1, 2)], [[force_card]])
	var strike_focus_card = strike_cards[1]

	assert_false(player2.exceeded) # reverts from empty overdrive
	validate_life(player1, 30, player2, 23)
	validate_positions(player1, 4, player2, 5)
	assert_true(player2.is_card_in_discards(force_card))
	assert_true(player2.is_card_in_sealed(strike_focus_card))
	assert_true(player2.is_card_in_hand(swap_card))
	advance_turn(player2)

func test_galdred_metamorphosis_nine_not_stunned():
	_setup_metamorphosis_test("nine")

	var swap_card = null
	for card in player2.sealed:
		if card.definition['speed'] == 1:
			swap_card = card.id
			break
	var force_card = player2.hand[0].id

	var strike_cards = execute_strike(player1, player2, "galdred_metamorphosis", "standard_normal_focus",
		false, false, [get_cards_from_gauge(player1, 2)], [[force_card]])
	var strike_focus_card = strike_cards[1]

	assert_false(player2.exceeded) # reverts from empty overdrive
	validate_life(player1, 26, player2, 25)
	validate_positions(player1, 4, player2, 5)
	assert_true(player2.is_card_in_discards(force_card))
	assert_true(player2.is_card_in_sealed(strike_focus_card))
	assert_true(player2.is_card_in_hand(swap_card))
	advance_turn(player2)

# Noel - keeps frontside bonus if paid for, does not gain backside
func test_galdred_metamorphosis_noel():
	_setup_metamorphosis_test("noel")
	advance_turn(player1)
	give_gauge(player2, 1)

	execute_strike(player2, player1, "standard_normal_focus", "galdred_metamorphosis", false, false,
		[get_cards_from_gauge(player2, 1)], [get_cards_from_gauge(player1, 2)])
	# draws 2 plus one for focus

	assert_true(player2.exceeded) # didn't revert yet because it's not her turn
	validate_life(player1, 26, player2, 25)
	validate_positions(player1, 4, player2, 5)
	player1.discard_hand()
	advance_turn(player1)
	assert_false(player2.exceeded)

# Nu - keeps frontside bonus if paid for, gains backside bonuses
func test_galdred_metamorphosis_nu13_miss():
	_setup_metamorphosis_test("nu13")
	var initial_hand_size = len(player2.hand)

	execute_strike(player1, player2, "galdred_metamorphosis", "standard_normal_focus", false, false,
		[get_cards_from_gauge(player1, 2)], [get_cards_from_hand(player2, 1)])
	# spent 1 force, drew 2

	assert_false(player2.exceeded) # reverts from empty overdrive
	validate_life(player1, 30, player2, 25)
	validate_positions(player1, 4, player2, 5)
	assert_eq(len(player2.hand), initial_hand_size + 1)
	advance_turn(player2)

func test_galdred_metamorphosis_nu13_hit():
	_setup_metamorphosis_test("nu13")
	var initial_hand_size = len(player2.hand)

	execute_strike(player1, player2, "galdred_metamorphosis", "standard_normal_focus", false, false,
		[get_cards_from_gauge(player1, 2)], [[], 0]) # accepts advance 3
	# did not spend force, drew 2

	assert_false(player2.exceeded) # reverts from empty overdrive
	validate_life(player1, 26, player2, 25)
	validate_positions(player1, 4, player2, 1)
	assert_eq(len(player2.hand), initial_hand_size + 2)
	advance_turn(player2)



# for copypaste reference
func test_galdred_metamorphosis_():
	_setup_metamorphosis_test("galdred")
	var initial_hand_size = len(player2.hand)

	execute_strike(player1, player2, "galdred_metamorphosis", "standard_normal_focus", false, false,
		[get_cards_from_gauge(player1, 2)])

	assert_true(player2.exceeded)
	validate_life(player1, 26, player2, 25)
	validate_positions(player1, 4, player2, 5)
	assert_eq(len(player2.hand), initial_hand_size + 4)
	advance_turn(player2)
