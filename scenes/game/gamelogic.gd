extends Node2D

const StartingHandFirstPlayer = 5
const StartingHandSecondPlayer = 6
const MaxLife = 30
const MaxHandSize = 7
const MaxReshuffle = 1

var NextCardId = 1
var all_cards : Array = []
var game_over : bool = false

enum {
	GameState_NotStarted,
	GameState_PickAction,
	GameState_DiscardDownToMax,
}
var game_state = GameState_NotStarted

enum {
	EventType_AdvanceTurn,
	EventType_Move,
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
	var exceeded : bool
	var exceed_cost : int

	func _init(player_name, parent_ref, chosen_deck, card_start_id):
		name = player_name
		parent = parent_ref
		life = MaxLife
		hand = []
		deck_def = chosen_deck
		exceed_cost = deck_def['character']['exceed_cost']
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
		exceeded = false

	func is_card_in_hand(id):
		for card in hand:
			if card.id == id:
				return true
		return false
		
	func is_card_in_gauge(id):
		for card in gauge:
			if card.id == id:
				return true
		return false

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
				if not parent.game_over:
					var card = deck[0]
					hand.append(card)
					deck.remove_at(0)
					events += [parent.create_event(EventType_Draw, self, card.id)]
		return events

	func reshuffle_discard():
		var events : Array = []
		if reshuffle_remaining == 0:
			# Game Over
			events += [parent.create_event(EventType_GameOver, self, 0)]
			parent.game_over = true
		else:
			# Put discard into deck, shuffle, subtract reshuffles
			deck += discards
			discards = []
			deck.shuffle()
			reshuffle_remaining -= 1
			events += [parent.create_event(EventType_ReshuffleDiscard, self, reshuffle_remaining)]
		return events

	func discard(card_ids : Array):
		var events = []
		for discard_id in card_ids:
			# From hand
			for i in range(len(hand)-1, -1, -1):
				var card = hand[i]
				if card.id == discard_id:
					discards.append(card)
					hand.remove_at(i)
					events += [parent.create_event(EventType_Discard, self, card.id)]
					break

			# From gauge
			for i in range(len(gauge)-1, -1, -1):
				var card = gauge[i]
				if card.id == discard_id:
					discards.append(card)
					gauge.remove_at(i)
					events += [parent.create_event(EventType_Discard, self, card.id)]
					break
		return events
		
	func get_available_force():
		var force = 0
		for card in hand:
			force += parent.get_card_force(card.id)
		for card in gauge:
			force += parent.get_card_force(card.id)
		return force
		
	func can_move_to(new_arena_location):
		if new_arena_location == arena_location: return false
		var other_player_loc = parent.other_player(self).arena_location
		if  other_player_loc == new_arena_location: return false
		var required_force = get_force_to_move_to(new_arena_location)
		return required_force <= get_available_force()

	func get_force_to_move_to(new_arena_location):
		var other_player_loc = parent.other_player(self).arena_location
		var required_force = abs(arena_location - new_arena_location)
		if ((arena_location < other_player_loc and new_arena_location > other_player_loc)
			or (new_arena_location < other_player_loc and arena_location > other_player_loc)):
			# No additional force needed because of abs calculation.
			#required_force += 1
			pass
		return required_force
		
	func move_to(new_arena_location):
		var events = []
		arena_location = new_arena_location
		events += [parent.create_event(EventType_Move, self, new_arena_location)]
		return events

var player : Player
var opponent : Player

var active_turn_player
var next_turn_player

func initialize_game(player_deck, opponent_deck):
	player = Player.new("Player", self, player_deck, 100)
	opponent = Player.new("Opponent", self, opponent_deck, 200)

	for card in player.deck:
		all_cards.append(card)
	for card in opponent.deck:
		all_cards.append(card)
		
	active_turn_player = player
	player.arena_location = 3
	next_turn_player = opponent
	opponent.arena_location = 7

	player.draw(StartingHandFirstPlayer)
	opponent.draw(StartingHandSecondPlayer)

	game_state = GameState_PickAction

func get_card(id):
	for card in all_cards:
		if card.id == id:
			return card
	return null

func get_card_force(id):
	var card = get_card(id)
	if card.definition['type'] == 'ultra':
		return 2
	return 1

func can_do_prepare(performing_player : Player):
	if game_state != GameState_PickAction:
		return false
	if active_turn_player != performing_player:
		return false
	return true

func can_do_move(performing_player : Player):
	if game_state != GameState_PickAction:
		return false
	if active_turn_player != performing_player:
		return false
		
	# Check if the player can generate force (2 if cornered)
	var force_needed = 1
	if ((performing_player.arena_location == 1 and other_player(performing_player).arena_location == 2)
		or (performing_player.arena_location == 9 and other_player(performing_player).arena_location == 8)):
		force_needed = 2
		pass
	
	var force_available = performing_player.get_available_force()
	if force_available >= force_needed:
		return true
	return false

func can_do_change(performing_player : Player):
	if game_state != GameState_PickAction:
		return false
	if active_turn_player != performing_player:
		return false
	
	var force_available = performing_player.get_available_force()
	return force_available > 0

func can_do_exceed(performing_player : Player):
	if game_state != GameState_PickAction:
		return false
	if active_turn_player != performing_player:
		return false
	if performing_player.exceeded:
		return false
		
	var gauge_available = len(performing_player.gauge)
	return gauge_available >= performing_player.exceed_cost

func can_do_reshuffle(performing_player : Player):
	if game_state != GameState_PickAction:
		return false
	if active_turn_player != performing_player:
		return false
	if len(performing_player.discards) == 0:
		return false
	return performing_player.reshuffle_remaining > 0

func can_do_boost(performing_player : Player):
	if game_state != GameState_PickAction:
		return false
	if active_turn_player != performing_player:
		return false

	var force_available = performing_player.get_available_force()
	for card in performing_player.hand:
		if card.definition['boost']['force_cost'] <= force_available:
			return true

	return false

func can_do_strike(performing_player : Player):
	if game_state != GameState_PickAction:
		return false
	if active_turn_player != performing_player:
		return false

	# Can always wild swing!

	return true

func do_prepare(performing_player):
	if not can_do_prepare(performing_player):
		print("ERROR: Tried to Prepare but can't.")
		return []

	var events : Array = performing_player.draw(2)
	if len(performing_player.hand) > MaxHandSize:
		game_state = GameState_DiscardDownToMax
		events += [create_event(EventType_HandSizeExceeded, performing_player, len(performing_player.hand) - MaxHandSize)]
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

	for id in card_ids:
		if not performing_player.is_card_in_hand(id):
			# Card not found, error
			print("ERROR: Tried to discard cards that aren't in hand.")
			return []

	if len(performing_player.hand) - len(card_ids) > MaxHandSize:
		print("ERROR: Not discarding enough cards")
		return []

	var events = performing_player.discard(card_ids)
	events += advance_to_next_turn()

	return events

func do_move(performing_player : Player, card_ids, new_arena_location):
	if not can_do_move(performing_player):
		print("ERROR: Cannot perform the move action for this player.")
		return []

	if not performing_player.can_move_to(new_arena_location):
		print("ERROR: Unable to move to that arena location.")
		return []
		
	# Ensure cards are in hand/gauge
	for id in card_ids:
		if not performing_player.is_card_in_hand(id) and not performing_player.is_card_in_gauge(id):
			# Card not found, error
			print("ERROR: Tried to discard cards that aren't in hand/gauge.")
			return []

	# Ensure cards generate enough force.
	var required_force = performing_player.get_force_to_move_to(new_arena_location)
	var generated_force = 0
	for id in card_ids:
		generated_force += get_card_force(id)

	if generated_force < required_force:
		print("ERROR: Not enough force with these cards to move there.")
		return []

	var events = performing_player.discard(card_ids)
	events += performing_player.move_to(new_arena_location)
	events += performing_player.draw(1)
	events += advance_to_next_turn()
	return events

func do_change(performing_player : Player, card_ids):
	if not can_do_change(performing_player):
		print("ERROR: Cannot do change action for this player.")
		return []

	for id in card_ids:
		if not performing_player.is_card_in_hand(id) and not performing_player.is_card_in_gauge(id):
			# Card not found, error
			print("ERROR: Tried to discard cards that aren't in hand or gauge.")
			return []

	var num_cards = len(card_ids)
	var events = performing_player.discard(card_ids)
	events += performing_player.draw(num_cards + 1)
	if len(performing_player.hand) > MaxHandSize:
		game_state = GameState_DiscardDownToMax
		events += [create_event(EventType_HandSizeExceeded, performing_player, len(performing_player.hand) - MaxHandSize)]
	else:
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


