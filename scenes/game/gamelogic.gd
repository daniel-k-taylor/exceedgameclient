extends Node2D

const StartingHandFirstPlayer = 5
const StartingHandSecondPlayer = 6
const MaxLife = 30
const MaxHandSize = 7
const MaxReshuffle = 1

var NextCardId = 1

enum {
	GameState_NotStarted,
	GameState_PickAction,
	GameState_DiscardDownToMax,
}
var game_state = GameState_NotStarted

enum {
	EventType_AdvanceTurn,
	EventType_Discard,
	EventType_Draw,
	EventType_GameOver,
	EventType_HandSizeExceeded,
	EventType_ReshuffleDiscard,
}

func create_event(event_type, event_player, num):
	return {
		"event_type": event_type,
		"event_player": event_player,
		"number": num,
		"early_exit": event_type == EventType_GameOver
	}

func should_exit(events):
	return events[len(events) - 1]['early_exit']

class Card:
	var id
	var definition
	var image

	func _init(card_id, card_def, card_image):
		id = card_id
		definition = card_def
		image = card_image



class Player:
	var parent

	var name : String
	var life : int
	var hand : Array
	var deck : Array
	var discards : Array
	var deck_def : Dictionary
	var gauge : Array
	var boosts : Array
	var arena_location : int
	var reshuffle_remaining : int

	func _init(player_name, parent_ref, chosen_deck, card_start_id):
		name = player_name
		parent = parent_ref
		life = MaxLife
		hand = []
		deck_def = chosen_deck
		deck = []
		for deck_card_def in deck_def['cards']:
			var card_def = CardDefinitions.get_card(deck_card_def['definition_id'])
			var card = Card.new(card_start_id, card_def, deck_card_def['image'])
			deck.append(card)
			card_start_id += 1
		deck.shuffle()
		gauge = []
		boosts = []
		discards = []
		reshuffle_remaining = MaxReshuffle

	func draw(num_to_draw):
		var events : Array = []
		for i in range(num_to_draw):
			if len(deck) > 0:
				var card = deck[0]
				hand.append(card)
				deck.remove_at(0)
				events += [parent.create_event(EventType_Draw, self, card.id)]
			else:
				events += reshuffle_discard()
		return events

	func reshuffle_discard():
		var events : Array = []
		if reshuffle_remaining == 0:
			# Game Over
			events += [parent.create_event(EventType_GameOver, self, 0)]
		else:
			# Put discard into deck, shuffle, subtract reshuffles
			deck += discards
			discards = []
			deck.shuffle()
			reshuffle_remaining -= 1
			events += [parent.create_event(EventType_ReshuffleDiscard, self, reshuffle_remaining)]
		return events

	func discard(card_ids : Array):
		var discard_cards = []
		var events = []
		for discard_id in card_ids:
			for i in range(len(hand)-1, -1, -1):
				var card = hand[i]
				if card.id == discard_id:
					discards.append(card)
					hand.remove_at(i)
					events += [parent.create_event(EventType_Discard, self, card.id)]
					break
		return events


var player : Player
var opponent : Player

var active_turn_player
var next_turn_player

func initialize_game(player_deck, opponent_deck):
	player = Player.new("Player", self, player_deck, 100)
	opponent = Player.new("Opponent", self, opponent_deck, 200)

	active_turn_player = player
	player.arena_location = 3
	next_turn_player = opponent
	opponent.arena_location = 7

	player.draw(StartingHandFirstPlayer)
	opponent.draw(StartingHandSecondPlayer)

	game_state = GameState_PickAction

func can_do_prepare(performing_player):
	if game_state != GameState_PickAction:
		return false
	if active_turn_player != performing_player:
		return false
	return true

func can_do_move(performing_player):
	return false

func can_do_change(performing_player):
	return false

func can_do_exceed(performing_player):
	return false

func can_do_reshuffle(performing_player):
	return false

func can_do_boost(performing_player):
	return false

func can_do_strike(performing_player):
	return false

func do_prepare(performing_player):
	if not can_do_prepare(performing_player):
		print("ERROR: Tried to Prepare but can't.")
		return []

	var events : Array = performing_player.draw(2)
	if len(player.hand) > MaxHandSize:
		game_state = GameState_DiscardDownToMax
		events += [create_event(EventType_HandSizeExceeded, active_turn_player, len(active_turn_player.hand) - MaxHandSize)]
	else:
		events += advance_to_next_turn()

	return events

func do_discard_to_max(performing_player : Player, card_ids):
	if performing_player != active_turn_player:
		print("ERROR: Tried to discard for wrong player.")
		return []
	if game_state != GameState_DiscardDownToMax:
		print("ERROR: Tried to discard wrong game state.")
		return []

	var events = performing_player.discard(card_ids)
	events += advance_to_next_turn()

	return events

func other_player(test_player):
	if test_player == player:
		return opponent
	return player

func advance_to_next_turn():
	active_turn_player = next_turn_player
	next_turn_player = other_player(active_turn_player)
	game_state = GameState_PickAction
	return [create_event(EventType_AdvanceTurn, active_turn_player, 0)]


