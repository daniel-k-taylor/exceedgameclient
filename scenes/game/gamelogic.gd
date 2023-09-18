extends Node2D

const StartingHandFirstPlayer = 5
const StartingHandSecondPlayer = 6
const MaxLife = 30

var NextCardId = 1

class Card:
	var id
	var definition
	var image

	func _init(card_id, card_def, card_image):
		id = card_id
		definition = card_def
		image = card_image


class Player:
	var life
	var hand
	var deck
	var deck_def
	var gauge
	var boosts

	func _init(chosen_deck, card_start_id):
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

	func draw(num_to_draw):
		for i in range(num_to_draw):
			if len(deck) > 0:
				hand.append(deck[0])
				deck.remove_at(0)


var player : Player
var opponent : Player

var active_turn_player
var next_turn_player

func initialize_game(player_deck, opponent_deck):
	player = Player.new(player_deck, 100)
	opponent = Player.new(opponent_deck, 200)

	active_turn_player = player
	next_turn_player = opponent

	player.draw(StartingHandFirstPlayer)
	opponent.draw(StartingHandSecondPlayer)


