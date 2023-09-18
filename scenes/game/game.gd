extends Node2D

const DesiredCardSize = Vector2(125, 175)
const ActualCardSize = Vector2(250,350)
const HandCardScale = DesiredCardSize / ActualCardSize
const CardBaseScene = preload("res://scenes/card/card_base.tscn")
const CardBase = preload("res://scenes/card/card_base.gd")
const GameLogic = preload("res://scenes/game/gamelogic.gd")


var chosen_deck = null
var NextCardId = 1

var first_run_done = false
var select_card_require_min = 0
var select_card_require_max = 0
var select_card_cancel_allowed = false
var selected_cards = []

enum {
	UIState_Initializing,
	UIState_PickTurnAction,
	UIState_SelectCards,
	UIState_WaitingOnOpponent,
}

var ui_state = UIState_Initializing

@onready var game_logic : GameLogic = $GameLogic

@onready var CenterCardOval = Vector2(get_viewport().size) * Vector2(0.5, 1.25)
@onready var HorizontalRadius = get_viewport().size.x * 0.45
@onready var VerticalRadius = get_viewport().size.y * 0.4

# Called when the node enters the scene tree for the first time.
func _ready():
	chosen_deck = CardDefinitions.decks[0]
	game_logic.initialize_game(chosen_deck, chosen_deck)

	for card in game_logic.player.hand:
		draw_card(card)
	$PlayerLife.set_life(game_logic.player.life)
	$OpponentLife.set_life(game_logic.opponent.life)
	_on_advance_turn()
	$OpponentHand/OpponentHandBox/OpponentNumCards.text = str(len(game_logic.opponent.hand))


func first_run():
	move_character_to_arena_square($PlayerCharacter, game_logic.player.arena_location)
	move_character_to_arena_square($OpponentCharacter, game_logic.opponent.arena_location)
	_update_buttons()

func move_character_to_arena_square(character, arena_square):
	var arena = $StaticUI/StaticUIVBox/Arena
	var target_square = arena.get_child(arena_square - 1)
	character.position = target_square.global_position + target_square.size/2

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if not first_run_done:
		first_run()
		first_run_done = true
	pass

func _input(event):
	if event is InputEventMouseButton:
		if event is InputEventMouseButton and event.is_released():
			pass

func discard_card(card):
	var discard_pos = $PlayerDeck/Discard.global_position + $PlayerDeck/Discard.size * $PlayerDeck/Discard.scale /2
	card.discard_to(discard_pos, $PlayerDeck/Discard.scale)
	$PlayerHand.remove_child(card)
	$PlayerDeck/DiscardedCards.add_child(card)
	layout_player_hand()
	
	# TODO: Update discard pile info

func draw_card(card):
	var new_card = add_new_card_to_hand(card.id, card.definition, card.image)

	# Start the card at the deck.
	var deck_position = $PlayerDeck/DeckButton.position + DesiredCardSize/2
	new_card.position = deck_position

	layout_player_hand()
	update_card_counts()

func update_card_counts():
	$PlayerDeck/DeckButton/CardCountContainer/CardCount.text = str(len(game_logic.player.deck))
	$OpponentDeck/DeckButton/CardCountContainer/CardCount.text = str(len(game_logic.opponent.deck))

func add_new_card_to_hand(id, card_def, image) -> CardBase:
	var new_card : CardBase = CardBaseScene.instantiate()
	$PlayerHand.add_child(new_card)
	$PlayerHand.move_child(new_card, $PlayerHand.get_child_count() - 1)
	new_card.initialize_card(
		id,
		card_def['display_name'],
		HandCardScale,
		image,
		card_def['range_min'],
		card_def['range_max'],
		card_def['speed'],
		card_def['power'],
		card_def['armor'],
		card_def['guard'],
		CardDefinitions.get_effect_text(card_def['effects']),
		card_def['boost']['cost'],
		CardDefinitions.get_boost_text(card_def['effects'])
	)
	new_card.name = "Card_" + str(id)
	new_card.raised_card.connect(on_card_raised)
	new_card.lowered_card.connect(on_card_lowered)
	new_card.clicked_card.connect(on_card_clicked)
	return new_card

func on_card_raised(card):
	# Get card's position in the PlayerHand node's children.
	if card.get_parent() == $PlayerHand:
		card.saved_hand_index = card.get_index()

		# Move card to the end of the children list.
		$PlayerHand.move_child(card, $PlayerHand.get_child_count() - 1)

func on_card_lowered(card):
	if card.saved_hand_index != -1:
		# Move card back to its saved position.
		$PlayerHand.move_child(card, card.saved_hand_index)
		card.saved_hand_index = -1

func on_card_clicked(card):
	# If in selection mode, select/deselect card.
	if ui_state == UIState_SelectCards:
		var index = -1
		for i in range(len(selected_cards)):
			if selected_cards[i].card_id == card.card_id:
				index = i
				break
				
		if index == -1:
			# Selected, add to cards.
			if len(selected_cards) < select_card_require_max:
				selected_cards.append(card)
				card.set_selected(true)
		else:
			# Deselect
			selected_cards.remove_at(index)
			card.set_selected(false)
		_update_buttons()
			
func layout_player_hand():
	var num_cards = len($PlayerHand.get_children())
	var angle = deg_to_rad(90)
	var HandAngleChange = 0.2
	var angle_change_amount = 0.2
	if num_cards > 7:
		var normal_total_angle = 0.2 * 7
		angle_change_amount  = normal_total_angle / num_cards
	angle += HandAngleChange * (num_cards - 1)/2
	for i in range(num_cards):
		var card : CardBase = $PlayerHand.get_child(i)

		var ovalAngleVector = Vector2(HorizontalRadius * cos(angle), -VerticalRadius * sin(angle))
		var dst_pos = CenterCardOval + ovalAngleVector # - size/2
		var dst_rot = (90 - rad_to_deg(angle)) / 4
		card.set_resting_position(dst_pos, dst_rot)

		angle -= angle_change_amount

func _log_event(event):
	print("Event ", event['event_type'], " number=", event['number'])

func get_card_in_hand_from_id(id):
	var cards = $PlayerHand.get_children()
	for card in cards:
		if card.card_id == id:
			return card

func _on_advance_turn():
	$PlayerLife.set_turn_indicator(game_logic.active_turn_player == game_logic.player)
	$OpponentLife.set_turn_indicator(game_logic.active_turn_player == game_logic.opponent)
	
	if game_logic.active_turn_player == game_logic.player:
		change_ui_state(UIState_PickTurnAction)
	else:
		change_ui_state(UIState_WaitingOnOpponent)
	_update_buttons()

func _on_discard_event(event):
	if event['event_player'] == game_logic.player:
		var discard_id = event['number']
		var card = get_card_in_hand_from_id(discard_id)
		discard_card(card)
	else:
		# Discard card visual for opponent.
		pass

func _on_draw_event(event):
	if event['event_player'] == game_logic.player:
		var card_drawn_id = event['number']
		for card in game_logic.player.hand:
			if card.id == card_drawn_id:
				draw_card(card)
				break
	else:
		# Draw card visual for opponent.
		pass
		
func _on_game_over(event):
	print("GAME OVER for ", event['event_player'].name)
	# TODO: Do something useful

func _on_hand_size_exceeded(event):
	if game_logic.active_turn_player != game_logic.player:
		# Just wait for the other player
		return
	
	begin_discard_selection(event['number'])

func change_ui_state(new_state):
	ui_state = new_state
	
func set_select_instructions(text):
	$StaticUI/StaticUIVBox/SelectCardsUI/SelectInstructions.text = text

func update_discard_selection_message():
	var num_remaining = select_card_require_min - len(selected_cards)
	set_select_instructions("Select %s more card(s) from your hand to discard." % num_remaining)

func begin_discard_selection(number_to_discard):
	selected_cards = []
	select_card_require_min = number_to_discard
	select_card_require_max = number_to_discard
	select_card_cancel_allowed = false

	change_ui_state(UIState_SelectCards)
	_update_buttons()
	
		
func _on_reshuffle_discard(event):
	# TODO: Play a cool animation of discard shuffling into deck
	#       Clear discard visuals (delete those card nodes)
	print(event)

func _handle_events(events):
	for event in events:
		_log_event(event)
		match event['event_type']:
			game_logic.EventType_AdvanceTurn:
				_on_advance_turn()
			game_logic.EventType_Discard:
				_on_discard_event(event)
			game_logic.EventType_Draw:
				_on_draw_event(event)
			game_logic.EventType_GameOver:
				_on_game_over(event)
			game_logic.EventType_HandSizeExceeded:
				_on_hand_size_exceeded(event)
			game_logic.EventType_ReshuffleDiscard:
				_on_reshuffle_discard(event)

func _update_buttons():
	$StaticUI/StaticUIVBox/ButtonGrid/PrepareButton.disabled = not game_logic.can_do_prepare(game_logic.player)
	$StaticUI/StaticUIVBox/ButtonGrid/MoveButton.disabled = not game_logic.can_do_move(game_logic.player)
	$StaticUI/StaticUIVBox/ButtonGrid/ChangeButton.disabled = not game_logic.can_do_change(game_logic.player)
	$StaticUI/StaticUIVBox/ButtonGrid/ExceedButton.disabled = not game_logic.can_do_exceed(game_logic.player)
	$StaticUI/StaticUIVBox/ButtonGrid/ReshuffleButton.disabled = not game_logic.can_do_reshuffle(game_logic.player)
	$StaticUI/StaticUIVBox/ButtonGrid/BoostButton.disabled = not game_logic.can_do_boost(game_logic.player)
	$StaticUI/StaticUIVBox/ButtonGrid/StrikeButton.disabled = not game_logic.can_do_strike(game_logic.player)
	
	var action_buttons_visible = ui_state == UIState_PickTurnAction
	$StaticUI/StaticUIVBox/ButtonGrid.visible = action_buttons_visible
	
	var select_cards_ui_visible = ui_state == UIState_SelectCards
	$StaticUI/StaticUIVBox/SelectCardsUI.visible = select_cards_ui_visible
	
	$StaticUI/StaticUIVBox/SelectCardsUI/ButtonContainer/OkButton.disabled = not can_press_ok()
	$StaticUI/StaticUIVBox/SelectCardsUI/ButtonContainer/CancelButton.visible = select_card_cancel_allowed

	if ui_state == UIState_SelectCards and game_logic.GameState_DiscardDownToMax:
		update_discard_selection_message()
	

func can_press_ok():
	if ui_state == UIState_SelectCards:
		var selected_count = len(selected_cards)
		if  selected_count >= select_card_require_min && selected_count <= select_card_require_max:
			return true
	return false

func _on_prepare_button_pressed():
	var events = game_logic.do_prepare(game_logic.player)
	_handle_events(events)
	
	_update_buttons()

func _on_move_button_pressed():
	pass # Replace with function body.


func _on_change_button_pressed():
	pass # Replace with function body.


func _on_exceed_button_pressed():
	pass # Replace with function body.


func _on_reshuffle_button_pressed():
	pass # Replace with function body.


func _on_boost_button_pressed():
	pass # Replace with function body.


func _on_strike_button_pressed():
	pass # Replace with function body.


func _on_select_cards_cancel_button_pressed():
	pass # Replace with function body.


func _on_select_cards_ok_button_pressed():
	if game_logic.game_state == game_logic.GameState_DiscardDownToMax:
		var selected_card_ids = []
		for card in selected_cards:
			selected_card_ids.append(card.card_id)
		var events = game_logic.do_discard_to_max(game_logic.player, selected_card_ids)
		_handle_events(events)
