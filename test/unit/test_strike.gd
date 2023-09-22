extends GutTest

const GameLogic = preload("res://scenes/game/gamelogic.gd")
var game_logic : GameLogic

func before_each():
	game_logic = GameLogic.new()
	var chosen_deck = CardDefinitions.decks[0]
	game_logic.initialize_game(chosen_deck, chosen_deck)
	
	gut.p("ran setup", 2)

func after_each():
	game_logic.free()
	gut.p("ran teardown", 2)

func before_all():
	gut.p("ran run setup", 2)

func after_all():
	gut.p("ran run teardown", 2)

func test_game_setup():
	assert_eq(game_logic.active_turn_player, game_logic.player)
	assert_eq(game_logic.next_turn_player, game_logic.opponent)
