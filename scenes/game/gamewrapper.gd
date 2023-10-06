extends Node

const LocalGame = preload("res://scenes/game/localgame.gd")
const Enums = preload("res://scenes/game/enums.gd")
const CardDatabase = preload("res://scenes/game/card_database.gd")

class PlayerState:
	var id : int
	var life : int
	var arena_location : int
	var deck_definition
	var deck_list # 1 of each card in the deck definition
	var deck_reference # 1 of each type of card for the reference
	var hand # Sanitized for opponent?
	var deck_size : int # Current deck size
	var discards : Array
	var gauge : Array
	var reshuffle_remaining : int
	var exceed_cost : int
	var exceeded : bool

var active_turn_player : PlayerState
var game_state : Enums.GameState

var decision_type : Enums.DecisionType
var decision_choice : Array
var decision_player : PlayerState

var current_game

var event_queue : Array = []

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func poll_for_events() -> Array:
	var events = []
	events += event_queue
	event_queue = []
	return events

func initialize_local_game(player_deck, opponent_deck):
	current_game = LocalGame.new()
	current_game.initialize_game(player_deck, opponent_deck)
	var events = current_game.draw_starting_hands_and_begin()
	event_queue += events

func get_player():
	return current_game.player

func get_opponent():
	return current_game.opponent

func get_active_player():
	return current_game.active_player

func other_player(check_player):
	if check_player == get_player():
		return get_opponent()
	else:
		return get_player()

func get_card_database() -> CardDatabase:
	return current_game.get_card_database()

func is_card_in_zone(zone : Enums.CardZone, card_id : int) -> bool:
	match zone:
		Enums.CardZone.CardZone_PlayerHand:
			pass
		Enums.CardZone.CardZone_OpponentHand:
			pass
		Enums.CardZone.CardZone_PlayerGauge:
			pass
		Enums.CardZone.CardZone_OpponentGauge:
			pass
		Enums.CardZone.CardZone_PlayerBoosts:
			pass
		Enums.CardZone.CardZone_OpponentBoosts:
			pass
	assert(false, "Unexpected zone")
	return false

func can_player_boost(performing_player : PlayerState, card_id : int) -> bool:
	return false

# The 7 can_do functions

#get_all_non_immediate_continuous_boost_effects
# Player can_move_to
# do_choice
# all do_ functions in ok press



