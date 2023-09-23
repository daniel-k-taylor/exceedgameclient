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
var select_card_require_force = 0
var instructions_ok_allowed = false
var instructions_cancel_allowed = false
var selected_cards = []
var arena_locations_clickable = []
var selected_arena_location = 0

enum UIState {
	UIState_Initializing,
	UIState_PickTurnAction,
	UIState_SelectCards,
	UIState_SelectArenaLocation,
	UIState_WaitingOnOpponent,
}

enum UISubState {
	UISubState_None,
	UISubState_SelectCards_MoveActionGenerateForce,
	UISubState_SelectCards_DiscardCards,
	UISubState_SelectCards_ForceForChange,
	UISubState_SelectCards_StrikeCard,
	UISubState_SelectCards_StrikeResponseCard,
	UISubState_SelectCards_ForceForArmor,
	UISubState_SelectArena_MoveResponse,
}

var ui_state : UIState = UIState.UIState_Initializing
var ui_sub_state : UISubState = UISubState.UISubState_None

@onready var game_logic : GameLogic = $GameLogic

@onready var CenterCardOval = Vector2(get_viewport().content_scale_size) * Vector2(0.5, 1.25)
@onready var HorizontalRadius = get_viewport().content_scale_size.x * 0.45
@onready var VerticalRadius = get_viewport().content_scale_size.y * 0.4

func printlog(text):
	print("UI: %s" % text)

# Called when the node enters the scene tree for the first time.
func _ready():
	chosen_deck = CardDefinitions.decks[0]
	game_logic.initialize_game(chosen_deck, chosen_deck)

	$PlayerLife.set_life(game_logic.player.life)
	$OpponentLife.set_life(game_logic.opponent.life)

	finish_initialization()

func finish_initialization():
	spawn_all_cards()
	draw_and_begin()

func first_run():
	move_character_to_arena_square($PlayerCharacter, game_logic.player.arena_location)
	move_character_to_arena_square($OpponentCharacter, game_logic.opponent.arena_location)
	_update_buttons()

func spawn_all_cards():
	const OffScreen = Vector2(-1000, -1000)
	for card in game_logic.player.deck:
		var new_card = create_card(card.id, $AllCards/PlayerDeck)
		new_card.position = OffScreen
	for card in game_logic.opponent.deck:
		var new_card = create_card(card.id, $AllCards/OpponentDeck)
		new_card.position = OffScreen

func draw_and_begin():
	game_logic.draw_starting_hands_and_begin()
	for card in game_logic.player.hand:
		draw_card(card.id, true)
	for card in game_logic.opponent.hand:
		draw_card(card.id, false)
	_on_advance_turn()

func get_arena_location_button(arena_location):
	var arena = $StaticUI/StaticUIVBox/Arena
	var target_square = arena.get_child(arena_location - 1)
	return target_square.get_node("Border")

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

func discard_card(card, discard_location, new_parent, is_player : bool):
	var discard_pos = discard_location.global_position + discard_location.size * discard_location.scale /2
	if not is_player:
		# Make sure the card is faceup.
		card.flip_card_to_front(true)
	card.discard_to(discard_pos, discard_location.scale, CardBase.CardState.CardState_Discarded)
	reparent_to_zone(card, new_parent)
	layout_player_hand(is_player)

	# TODO: Update discard pile info

func get_deck_button(is_player : bool):
	if is_player:
		return $PlayerDeck/DeckButton
	else:
		return $OpponentDeck/DeckButton

func get_hand_zone(is_player : bool):
	if is_player:
		return $AllCards/PlayerHand
	else:
		return $AllCards/OpponentHand

func draw_card(card_id : int, is_player : bool):
	var card = add_card_to_hand(card_id, is_player)

	# Start the card at the deck.
	var deck_button = get_deck_button(is_player)
	var deck_position = deck_button.position + DesiredCardSize/2
	card.position = deck_position

	layout_player_hand(is_player)

func update_card_counts():
	$OpponentHand/OpponentHandBox/OpponentNumCards.text = str(len(game_logic.opponent.hand))

	$PlayerDeck/DeckButton/CardCountContainer/CardCount.text = str(len(game_logic.player.deck))
	$OpponentDeck/DeckButton/CardCountContainer/CardCount.text = str(len(game_logic.opponent.deck))

func get_card_node_name(id):
	return "Card_" + str(id)

func create_card(id, parent) -> CardBase:
	var logic_card : GameLogic.Card = game_logic.get_card(id)
	var card_def = logic_card.definition
	var new_card : CardBase = CardBaseScene.instantiate()
	parent.add_child(new_card)
	new_card.initialize_card(
		id,
		card_def['display_name'],
		HandCardScale,
		logic_card.image,
		card_def['range_min'],
		card_def['range_max'],
		card_def['speed'],
		card_def['power'],
		card_def['armor'],
		card_def['guard'],
		CardDefinitions.get_effect_text(card_def['effects']),
		card_def['boost']['force_cost'],
		CardDefinitions.get_boost_text(card_def['effects'])
	)
	new_card.name = get_card_node_name(id)
	new_card.raised_card.connect(on_card_raised)
	new_card.lowered_card.connect(on_card_lowered)
	new_card.clicked_card.connect(on_card_clicked)
	return new_card

func add_card_to_hand(id : int, is_player : bool) -> CardBase:
	var card = find_card_on_board(id)
	if not is_player: card.manual_flip_needed = true
	var hand_zone = get_hand_zone(is_player)
	card.get_parent().remove_child(card)
	hand_zone.add_child(card)
	hand_zone.move_child(card, hand_zone.get_child_count() - 1)
	return card

func on_card_raised(card):
	# Get card's position in the PlayerHand node's children.
	var parent = card.get_parent()
	if parent == $AllCards/PlayerHand or parent == $AllCards/Striking:
		card.saved_hand_index = card.get_index()

		# Move card to the end of the children list.
		parent.move_child(card, parent.get_child_count() - 1)

func on_card_lowered(card):
	if card.saved_hand_index != -1:
		# Move card back to its saved position.
		var parent = card.get_parent()
		parent.move_child(card, card.saved_hand_index)
		card.saved_hand_index = -1

func can_select_card(_card):
	match ui_sub_state:
		UISubState.UISubState_SelectCards_DiscardCards:
			return len(selected_cards) < select_card_require_max
		UISubState.UISubState_SelectCards_MoveActionGenerateForce, UISubState.UISubState_SelectCards_ForceForChange:
			return true
		UISubState.UISubState_SelectCards_StrikeCard, UISubState.UISubState_SelectCards_StrikeResponseCard:
			return true

func deselect_all_cards():
	for card in selected_cards:
		card.set_selected(false)
	selected_cards = []

func on_card_clicked(card):
	# If in selection mode, select/deselect card.
	if ui_state == UIState.UIState_SelectCards:
		var index = -1
		for i in range(len(selected_cards)):
			if selected_cards[i].card_id == card.card_id:
				index = i
				break

		if index == -1:
			# Selected, add to cards.
			if can_select_card(card):
				selected_cards.append(card)
				card.set_selected(true)
		else:
			# Deselect
			selected_cards.remove_at(index)
			card.set_selected(false)
		_update_buttons()

func layout_player_hand(is_player : bool):
	var hand_zone = get_hand_zone(is_player)
	var num_cards = len(hand_zone.get_children())
	if is_player:
		var angle = deg_to_rad(90)
		var HandAngleChange = 0.2
		var angle_change_amount = 0.2
		if num_cards > 7:
			var normal_total_angle = 0.2 * 7
			angle_change_amount  = normal_total_angle / num_cards
		angle += HandAngleChange * (num_cards - 1)/2
		for i in range(num_cards):
			var card : CardBase = hand_zone.get_child(i)

			var ovalAngleVector = Vector2(HorizontalRadius * cos(angle), -VerticalRadius * sin(angle))
			var dst_pos = CenterCardOval + ovalAngleVector # - size/2
			var dst_rot = (90 - rad_to_deg(angle)) / 4
			card.set_resting_position(dst_pos, dst_rot)

			angle -= angle_change_amount
	else:
		# Opponent cards just chill in one spot for now.
		var spawn_spot = $OpponentHand/HandSpawn
		var hand_center = spawn_spot.global_position + spawn_spot.size * spawn_spot.scale /2
		var min_x = hand_center.x - 200
		var max_x = hand_center.x + 200
		var step = (max_x - min_x) / (num_cards - 1)
		for i in range(num_cards):
			var pos = Vector2(min_x + step * i, hand_center.y)
			var card : CardBase = hand_zone.get_child(i)
			card.set_resting_position(pos, 0)

	update_card_counts()

func _log_event(event):
	var num = event['number']
	var card_name = game_logic.get_card_name(num)
	printlog("Event %s num=%s (card=%s)" % [game_logic.EventType.keys()[event['event_type']], event['number'], card_name])

func _on_advance_turn():
	$PlayerLife.set_turn_indicator(game_logic.active_turn_player == game_logic.player)
	$OpponentLife.set_turn_indicator(game_logic.active_turn_player == game_logic.opponent)

	if game_logic.active_turn_player == game_logic.player:
		change_ui_state(UIState.UIState_PickTurnAction)
	else:
		change_ui_state(UIState.UIState_WaitingOnOpponent)

func _on_discard_event(event):
	var discard_id = event['number']
	var card = find_card_on_board(discard_id)
	if event['event_player'] == game_logic.player:
		discard_card(card, $PlayerDeck/Discard, $AllCards/PlayerDiscards, true)
	else:
		discard_card(card, $OpponentDeck/Discard, $AllCards/OpponentDiscards, false)
	update_card_counts()

func find_card_on_board(card_id) -> CardBase:
	# Find a given card among the Hand, Strike, Gauge, Boost, and Discard areas.
	var zones = $AllCards.get_children()
	for zone in zones:
		var zone_cards = zone.get_children()
		for zone_card in zone_cards:
			if zone_card.card_id == card_id:
				return zone_card
	assert(false, "ERROR: Unable to find card %s on board." % card_id)
	return null

func reparent_to_zone(card, zone):
	card.get_parent().remove_child(card)
	zone.add_child(card)

func _on_add_to_discard(event):
	_on_discard_event(event)

func _on_add_to_gauge(event):
	pass

func _on_draw_event(event):
	var card_drawn_id = event['number']
	var is_player = event['event_player'] == game_logic.player
	draw_card(card_drawn_id, is_player)
	update_card_counts()

func _on_game_over(event):
	printlog("GAME OVER for %s" % event['event_player'].name)
	# TODO: Do something useful

func _on_hand_size_exceeded(event):
	if game_logic.active_turn_player == game_logic.player:
		begin_discard_cards_selection(event['number'])
	else:
		# AI or other player wait
		ai_discard(event)

func change_ui_state(new_state):
	ui_state = new_state
	update_card_counts()
	_update_buttons()

func set_instructions(text):
	$StaticUI/StaticUIVBox/InstructionsWithButtonsUI/Instructions.text = text

func update_discard_selection_message():
	var num_remaining = select_card_require_min - len(selected_cards)
	set_instructions("Select %s more card(s) from your hand to discard." % num_remaining)

func get_force_in_selected_cards():
	var force_selected = 0
	for card in selected_cards:
		force_selected += game_logic.get_card_force(card.card_id)
	return force_selected

func update_force_generation_message():
	var force_selected = get_force_in_selected_cards()
	match ui_sub_state:
		UISubState.UISubState_SelectCards_MoveActionGenerateForce:
			set_instructions("Select cards to generate %s force.\n%s force generated." % [select_card_require_force, force_selected])
		UISubState.UISubState_SelectCards_ForceForChange:
			set_instructions("Select cards to generate force to draw new cards.\n%s force generated." % [force_selected])

func enable_instructions_ui(message, can_ok, can_cancel):
	set_instructions(message)
	instructions_ok_allowed = can_ok
	instructions_cancel_allowed = can_cancel


func begin_discard_cards_selection(number_to_discard):
	selected_cards = []
	select_card_require_min = number_to_discard
	select_card_require_max = number_to_discard
	enable_instructions_ui("", true, false)
	ui_sub_state = UISubState.UISubState_SelectCards_DiscardCards
	change_ui_state(UIState.UIState_SelectCards)

func begin_generate_force_selection(amount):
	selected_cards = []
	select_card_require_force = amount
	enable_instructions_ui("", true, true)

	change_ui_state(UIState.UIState_SelectCards)


func begin_strike_choosing(strike_response : bool):
	selected_cards = []
	select_card_require_min = 1
	select_card_require_max = 1
	enable_instructions_ui("Select a card to strike with.", true, not strike_response)
	if strike_response:
		ui_sub_state = UISubState.UISubState_SelectCards_StrikeResponseCard
	else:
		ui_sub_state = UISubState.UISubState_SelectCards_StrikeCard
	change_ui_state(UIState.UIState_SelectCards)

func complete_strike_choosing(card_id : int):
	var events = game_logic.do_strike(game_logic.player, card_id, false)
	_handle_events(events)

func _on_move_event(event):
	if event['event_player'] == game_logic.player:
		move_character_to_arena_square($PlayerCharacter, event['number'])
	else:
		move_character_to_arena_square($OpponentCharacter, event['number'])

func _on_reshuffle_discard(event):
	# TODO: Play a cool animation of discard shuffling into deck
	#       Clear discard visuals (delete those card nodes)
	printlog("Unimplemented event: %s" % event)

func _move_card_to_strike_area(card, strike_area, new_parent, is_player : bool):
	var pos = strike_area.global_position + strike_area.size * strike_area.scale /2
	card.discard_to(pos, strike_area.scale, CardBase.CardState.CardState_InStrike)
	card.get_parent().remove_child(card)
	new_parent.add_child(card)
	layout_player_hand(is_player)

func _on_strike_started(event):
	var card = find_card_on_board(event['number'])
	if event['event_player'] == game_logic.player:
		_move_card_to_strike_area(card, $PlayerStrike/StrikeZone, $AllCards/Striking, true)
		ai_strike_response()
	else:
		_move_card_to_strike_area(card, $OpponentStrike/StrikeZone, $AllCards/Striking, false)
		begin_strike_choosing(true)

func _on_strike_reveal(_event):
	var strike_cards = $AllCards/Striking.get_children()
	for card in strike_cards:
		card.flip_card_to_front(true)

func _on_effect_choice(event):
	if event['event_player'] == game_logic.player:
		printlog("TODO: UI to select effect")
	else:
		ai_effect_choice(event)

func _on_pay_cost(event):
	if event['event_player'] == game_logic.player:
		printlog("TODO: UI to pay costs")
	else:
		ai_pay_cost(event)

func _on_force_for_armor(event):
	if event['event_player'] == game_logic.player:
		# UI to select cards to use force for armor
		printlog("TODO: Force for armor")
	else:
		ai_force_for_armor(event)

func _on_damage(event):
	printlog("TODO: Took damage %s. Use damage number in event to play animation." % event['number'])
	if event['event_player'] == game_logic.player:
		$PlayerLife.set_life(game_logic.player.life)
	else:
		$OpponentLife.set_life(game_logic.opponent.life)

func _handle_events(events):
	for event in events:
		_log_event(event)
		match event['event_type']:
			game_logic.EventType.EventType_AddToGauge:
				_on_add_to_gauge(event)
			game_logic.EventType.EventType_AddToDiscard:
				_on_add_to_discard(event)
			game_logic.EventType.EventType_AdvanceTurn:
				_on_advance_turn()
			game_logic.EventType.EventType_Discard:
				_on_discard_event(event)
			game_logic.EventType.EventType_Draw:
				_on_draw_event(event)
			game_logic.EventType.EventType_GameOver:
				_on_game_over(event)
			game_logic.EventType.EventType_HandSizeExceeded:
				_on_hand_size_exceeded(event)
			game_logic.EventType.EventType_Move:
				_on_move_event(event)
			game_logic.EventType.EventType_ReshuffleDiscard:
				_on_reshuffle_discard(event)
			game_logic.EventType.EventType_Strike_ArmorUp:
				printlog("TODO: Animate strike armor up")
			game_logic.EventType.EventType_Strike_DodgeAttacks:
				printlog("TODO: Animate strike dodge attacks")
			game_logic.EventType.EventType_Strike_EffectChoice:
				_on_effect_choice(event)
			game_logic.EventType.EventType_Strike_ForceForArmor:
				_on_force_for_armor(event)
			game_logic.EventType.EventType_Strike_GainAdvantage:
				printlog("TODO: Animate strike gain advantage")
			game_logic.EventType.EventType_Strike_GuardUp:
				printlog("TODO: Animate strike guard up")
			game_logic.EventType.EventType_Strike_IgnoredPushPull:
				printlog("TODO: Animate strike ignored push/pull")
			game_logic.EventType.EventType_Strike_Miss:
				printlog("TODO: Animate strike miss")
			game_logic.EventType.EventType_Strike_PayCost:
				_on_pay_cost(event)
			game_logic.EventType.EventType_Strike_PowerUp:
				printlog("TODO: Animate strike power up")
			game_logic.EventType.EventType_Strike_Response:
				_on_strike_started(event)
			game_logic.EventType.EventType_Strike_Reveal:
				_on_strike_reveal(event)
			game_logic.EventType.EventType_Strike_Started:
				_on_strike_started(event)
			game_logic.EventType.EventType_Strike_Stun:
				printlog("TODO: Animate strike stun")
			game_logic.EventType.EventType_Strike_TookDamage:
				_on_damage(event)
			game_logic.EventType.EventType_Strike_WildStrike:
				printlog("TODO: Animate strike wild strike")

func _update_buttons():
	# Update main action selection UI
	$StaticUI/StaticUIVBox/ButtonGrid/PrepareButton.disabled = not game_logic.can_do_prepare(game_logic.player)
	$StaticUI/StaticUIVBox/ButtonGrid/MoveButton.disabled = not game_logic.can_do_move(game_logic.player)
	$StaticUI/StaticUIVBox/ButtonGrid/ChangeButton.disabled = not game_logic.can_do_change(game_logic.player)
	$StaticUI/StaticUIVBox/ButtonGrid/ExceedButton.disabled = not game_logic.can_do_exceed(game_logic.player)
	$StaticUI/StaticUIVBox/ButtonGrid/ReshuffleButton.disabled = not game_logic.can_do_reshuffle(game_logic.player)
	$StaticUI/StaticUIVBox/ButtonGrid/BoostButton.disabled = not game_logic.can_do_boost(game_logic.player)
	$StaticUI/StaticUIVBox/ButtonGrid/StrikeButton.disabled = not game_logic.can_do_strike(game_logic.player)

	var action_buttons_visible = ui_state == UIState.UIState_PickTurnAction
	$StaticUI/StaticUIVBox/ButtonGrid.visible = action_buttons_visible

	# Update instructions UI visibility
	var select_cards_ui_visible = ui_state == UIState.UIState_SelectCards or ui_state == UIState.UIState_SelectArenaLocation
	$StaticUI/StaticUIVBox/InstructionsWithButtonsUI.visible = select_cards_ui_visible

	# Update instructions UI Buttons
	$StaticUI/StaticUIVBox/InstructionsWithButtonsUI/ButtonContainer/OkButton.disabled = not can_press_ok()
	$StaticUI/StaticUIVBox/InstructionsWithButtonsUI/ButtonContainer/OkButton.visible = instructions_ok_allowed
	$StaticUI/StaticUIVBox/InstructionsWithButtonsUI/ButtonContainer/CancelButton.visible = instructions_cancel_allowed

	# Update instructions message
	if ui_state == UIState.UIState_SelectCards:
		match ui_sub_state:
			UISubState.UISubState_SelectCards_DiscardCards:
				update_discard_selection_message()
			UISubState.UISubState_SelectCards_MoveActionGenerateForce:
				update_force_generation_message()
			UISubState.UISubState_SelectCards_ForceForChange:
				update_force_generation_message()

	# Update arena location selection buttons
	for i in range(1, 10):
		var arena_button = get_arena_location_button(i)
		arena_button.visible = (ui_state == UIState.UIState_SelectArenaLocation and i in arena_locations_clickable)

func can_press_ok():
	if ui_state == UIState.UIState_SelectCards:
		match ui_sub_state:
			UISubState.UISubState_SelectCards_DiscardCards:
				var selected_count = len(selected_cards)
				if  selected_count >= select_card_require_min && selected_count <= select_card_require_max:
					return true
			UISubState.UISubState_SelectCards_MoveActionGenerateForce:
				var force_selected = get_force_in_selected_cards()
				return force_selected == select_card_require_force
			UISubState.UISubState_SelectCards_ForceForChange:
				var force_selected = get_force_in_selected_cards()
				return force_selected > 0
			UISubState.UISubState_SelectCards_StrikeCard, UISubState.UISubState_SelectCards_StrikeResponseCard:
				return len(selected_cards) == 1
	return false

func begin_select_arena_location(valid_moves):
	arena_locations_clickable = valid_moves
	enable_instructions_ui("Select a location", false, true)
	ui_sub_state = UISubState.UISubState_SelectCards_MoveActionGenerateForce
	change_ui_state(UIState.UIState_SelectArenaLocation)

##
## Button Handlers
##

func _on_prepare_button_pressed():
	var events = game_logic.do_prepare(game_logic.player)
	_handle_events(events)

	_update_buttons()

func _on_move_button_pressed():
	var valid_moves = []
	for i in range(1, 10):
		if game_logic.player.can_move_to(i):
			valid_moves.append(i)

	begin_select_arena_location(valid_moves)

func _on_change_button_pressed():
	ui_sub_state = UISubState.UISubState_SelectCards_ForceForChange
	begin_generate_force_selection(-1)

func _on_exceed_button_pressed():
	pass # Replace with function body.


func _on_reshuffle_button_pressed():
	pass # Replace with function body.


func _on_boost_button_pressed():
	pass # Replace with function body.

func _on_strike_button_pressed():
	begin_strike_choosing(false)


func _on_instructions_ok_button_pressed():
	if ui_state == UIState.UIState_SelectCards and can_press_ok():
		match ui_sub_state:
			UISubState.UISubState_SelectCards_DiscardCards:
				var selected_card_ids = []
				for card in selected_cards:
					selected_card_ids.append(card.card_id)
				var events = game_logic.do_discard_to_max(game_logic.player, selected_card_ids)
				_handle_events(events)
			UISubState.UISubState_SelectCards_MoveActionGenerateForce:
				var selected_card_ids = []
				for card in selected_cards:
					selected_card_ids.append(card.card_id)
				var events = game_logic.do_move(game_logic.player, selected_card_ids, selected_arena_location)
				_handle_events(events)
			UISubState.UISubState_SelectCards_ForceForChange:
				var selected_card_ids = []
				for card in selected_cards:
					selected_card_ids.append(card.card_id)
				var events = game_logic.do_change(game_logic.player, selected_card_ids)
				_handle_events(events)
			UISubState.UISubState_SelectCards_StrikeCard, UISubState.UISubState_SelectCards_StrikeResponseCard:
				var card = selected_cards[0]
				complete_strike_choosing(card.card_id)

func _on_instructions_cancel_button_pressed():
	if ui_state == UIState.UIState_SelectArenaLocation and instructions_cancel_allowed:
		change_ui_state(UIState.UIState_PickTurnAction)
	if ui_state == UIState.UIState_SelectCards and instructions_cancel_allowed:
		deselect_all_cards()
		change_ui_state(UIState.UIState_PickTurnAction)


func _on_arena_location_pressed(location):
	selected_arena_location = location
	if ui_state == UIState.UIState_SelectArenaLocation:
		if ui_sub_state == UISubState.UISubState_SelectCards_MoveActionGenerateForce:
			begin_generate_force_selection(game_logic.player.get_force_to_move_to(location))



#
# AI Functions
#
func _on_ai_move_button_pressed():
	if game_logic.active_turn_player != game_logic.player and game_logic.game_state == game_logic.GameState.GameState_PickAction:
		ai_take_turn()
	elif game_logic.game_state == game_logic.GameState.GameState_Strike_Opponent_Response and game_logic.active_strike.defender == game_logic.opponent:
		ai_strike_response()

func ai_take_turn():
	var events = game_logic.do_prepare(game_logic.opponent)
	_handle_events(events)

func ai_pay_cost(_event):
	var events = game_logic.do_pay_cost(game_logic.opponent, [], true)
	_handle_events(events)

func ai_effect_choice(_event):
	var events = game_logic.do_choice(game_logic.opponent, 0)
	_handle_events(events)

func ai_force_for_armor(_event):
	var events = game_logic.do_force_for_armor(game_logic.opponent, [])
	_handle_events(events)

func ai_strike_response():
	var card = game_logic.opponent.hand[0]
	var events = game_logic.do_strike(game_logic.opponent, card.id, false)
	_handle_events(events)

func ai_discard(event):
	var to_discard = []
	for i in range(event['number']):
		to_discard.append(game_logic.opponent.hand[i].id)
	var events = game_logic.do_discard_to_max(game_logic.opponent, to_discard)
	_handle_events(events)

