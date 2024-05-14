## Tests for the underlying AIPlayer data structures and functions

extends GutTest

const LocalGame = preload("res://scenes/game/local_game.gd")
const GameCard = preload("res://scenes/game/game_card.gd")
const Enums = preload("res://scenes/game/enums.gd")

var game_logic : LocalGame
var default_deck = CardDefinitions.get_deck_from_str_id("solbadguy")

var player1 : LocalGame.Player
var player2 : LocalGame.Player
var ai1 : AIPlayer
var ai2 : AIPlayer

func game_setup(policy_type = AIPolicyRules):
	game_logic = LocalGame.new()
	var seed_value = randi()
	game_logic.initialize_game(default_deck, default_deck, "p1", "p2", Enums.PlayerId.PlayerId_Player, seed_value)
	game_logic.draw_starting_hands_and_begin()
	game_logic.get_latest_events()
	player1 = game_logic.player
	player2 = game_logic.opponent
	ai1 = AIPlayer.new(game_logic, player1, policy_type.new())
	ai2 = AIPlayer.new(game_logic, player2, policy_type.new())

func game_teardown():
	# TODO: Move this logic into the real game so that it doesn't memory leak
	game_logic.teardown()
	game_logic.free()
	ai1.ai_policy.free()
	ai2.ai_policy.free()

func before_each():
	gut.p("ran setup", 2)

func after_each():
	if is_instance_valid(game_logic):
		game_teardown()
	gut.p("ran teardown", 2)

func before_all():
	gut.p("ran run setup", 2)

func after_all():
	gut.p("ran run teardown", 2)

### Actual tests

func test_list_cards():
	default_deck = CardDefinitions.get_deck_from_str_id('ryu')
	game_setup()
	ai1.game_state.update()
	var card_ids = ai1.generate_distinct_opponent_card_ids(ai1.game_state, false, false)
	assert_eq(card_ids.size(), 15,  # 8 Normals, 5 Specials, 2 Ultras
			'Card-naming thinks Ryu has %s distinct cards' % card_ids.size())

	var card_db = game_logic.card_db
	var card_names = card_ids.map(func (card_id): return card_db.get_card_id(card_id))
	card_names.sort()
	for i in range(card_names.size() - 1):
		assert_ne(card_names[i], card_names[i+1],
				'Card %s was duplicated in the list of possible cards to pick' % card_names[i])
	game_teardown()

func test_list_cards_chaos():
	default_deck = CardDefinitions.get_deck_from_str_id('happychaos')
	game_setup()
	ai1.game_state.update()
	var card_ids = ai1.generate_distinct_opponent_card_ids(ai1.game_state, false, false)
	assert_eq(card_ids.size(), 14,  # 8 Normals, 2 Specials, 3 Ultras, Deus Ex
			'Card-naming thinks Happy Chaos has %s distinct cards' % card_ids.size())

	var card_db = game_logic.card_db
	var card_names = card_ids.map(func (card_id): return card_db.get_card_id(card_id))
	card_names.sort()
	for i in range(card_names.size() - 1):
		assert_ne(card_names[i], card_names[i+1],
				'Card %s was duplicated in the list of possible cards to pick' % card_names[i])
	game_teardown()

func test_name_opponent_card():
	default_deck = CardDefinitions.get_deck_from_str_id('happychaos')
	game_setup()
	ai1.game_state.update()
	var name_card_action = ai1.pick_name_opponent_card(false, false)
	assert_true(name_card_action is AIPlayer.NameCardAction)
	game_teardown()

func test_duplicate_game_state():
	default_deck = CardDefinitions.get_deck_from_str_id('ryu')
	game_setup()
	ai1.game_state.update()

	var new_game_state = ai1.game_state.copy(true)
	assert_true(new_game_state is AIPlayer.AIGameState)
	assert_not_same(ai1.game_state, new_game_state)
	assert_true(AIResource.equals(ai1.game_state, new_game_state))
	assert_not_same(ai1.game_state.my_state, new_game_state.my_state)
	assert_same(ai1.game_state.player, new_game_state.player)
	
	new_game_state.my_state.arena_location -= 1
	assert_false(AIResource.equals(ai1.game_state, new_game_state),
			'Changing new self-location to %s also changed original self-location to %s' % [
					new_game_state.my_state.arena_location, ai1.game_state.my_state.arena_location
			])
