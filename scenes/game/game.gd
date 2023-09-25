extends Node2D

const CardBaseScene = preload("res://scenes/card/card_base.tscn")
const CardBase = preload("res://scenes/card/card_base.gd")
const GameLogic = preload("res://scenes/game/gamelogic.gd")
const CardPopout = preload("res://scenes/game/card_popout.gd")
const GaugePanel = preload("res://scenes/game/gauge_panel.gd")

const OffScreen = Vector2(-1000, -1000)
const ReferenceScreenIdRangeStart = 90000

const PlayerHandFocusYPos = 720 - (CardBase.DesiredCardSize.y + 20)
const OpponentHandFocusYPos = CardBase.DesiredCardSize.y

var chosen_deck = null
var NextCardId = 1

var first_run_done = false
var select_card_require_min = 0
var select_card_require_max = 0
var select_card_require_force = 0
var instructions_ok_allowed = false
var instructions_cancel_allowed = false
var instructions_wild_swing_allowed = false
var selected_cards = []
var arena_locations_clickable = []
var selected_arena_location = 0

enum UIState {
	UIState_Initializing,
	UIState_PickTurnAction,
	UIState_MakeChoice,
	UIState_SelectCards,
	UIState_SelectArenaLocation,
	UIState_WaitingOnOpponent,
}

enum UISubState {
	UISubState_None,
	UISubState_SelectCards_BoostCancel,
	UISubState_SelectCards_DiscardContinuousBoost,
	UISubState_SelectCards_DiscardFromReference,
	UISubState_SelectCards_MoveActionGenerateForce,
	UISubState_SelectCards_PlayBoost,
	UISubState_SelectCards_DiscardCards,
	UISubState_SelectCards_DiscardCardsToGauge,
	UISubState_SelectCards_ForceForChange,
	UISubState_SelectCards_Exceed,
	UISubState_SelectCards_StrikeGauge,
	UISubState_SelectCards_StrikeCard,
	UISubState_SelectCards_StrikeResponseCard,
	UISubState_SelectCards_ForceForArmor,
	UISubState_SelectArena_MoveResponse,
}

var ui_state : UIState = UIState.UIState_Initializing
var ui_sub_state : UISubState = UISubState.UISubState_None

@onready var game_logic : GameLogic = $GameLogic
@onready var card_popout : CardPopout = $CardPopout

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
	test_init()

func test_draw_and_add():
	var events = game_logic.player.draw(1)
	_handle_events(events)
	var card = game_logic.player.hand[0]
	game_logic.player.remove_card_from_hand(card.id)
	events = game_logic.player.add_to_gauge(card)
	_handle_events(events)
func test_init():
	for i in range(4):
		test_draw_and_add()
	layout_player_hand(true)
	_update_buttons()
	update_card_counts()

func first_run():
	move_character_to_arena_square($PlayerCharacter, game_logic.player.arena_location)
	move_character_to_arena_square($OpponentCharacter, game_logic.opponent.arena_location)
	_update_buttons()

func spawn_deck(deck, deck_copy, deck_card_zone, copy_zone, hand_focus_y_pos):
	for card in deck:
		var logic_card : GameLogic.Card = game_logic.get_card(card.id)
		var new_card = create_card(card.id, logic_card.definition, logic_card.image, deck_card_zone, hand_focus_y_pos)
		new_card.position = OffScreen

	var previous_def_id = ""
	for card in deck_copy:
		var logic_card : GameLogic.Card = game_logic.get_card(card.id)
		if previous_def_id != logic_card.definition['id']:
			var copy_card = create_card(card.id + ReferenceScreenIdRangeStart, logic_card.definition, logic_card.image, copy_zone, 0)
			copy_card.position = OffScreen
			copy_card.resting_scale = CardBase.SmallCardScale
			copy_card.scale = CardBase.SmallCardScale
			copy_card.change_state(CardBase.CardState.CardState_Offscreen)
			copy_card.flip_card_to_front(true)
			previous_def_id = card.definition['id']

func spawn_all_cards():
	spawn_deck(game_logic.player.deck, game_logic.player.deck_copy, $AllCards/PlayerDeck, $AllCards/PlayerAllCopy, PlayerHandFocusYPos)
	spawn_deck(game_logic.opponent.deck, game_logic.opponent.deck_copy, $AllCards/OpponentDeck, $AllCards/OpponentAllCopy, OpponentHandFocusYPos)

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

func get_discard_location(discard_node):
	var discard_pos = discard_node.global_position + discard_node.size * discard_node.scale /2
	return discard_pos

func discard_card(card, discard_node, new_parent, is_player : bool):
	var discard_pos = get_discard_location(discard_node)
	# Make sure the card is faceup.
	card.flip_card_to_front(true)
	card.discard_to(discard_pos, CardBase.CardState.CardState_Discarded)
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
	var deck_position = deck_button.position + (deck_button.size * deck_button.scale)/2
	card.position = deck_position

	layout_player_hand(is_player)

func update_card_counts():
	$OpponentHand/OpponentHandBox/OpponentNumCards.text = str(len(game_logic.opponent.hand))

	$PlayerDeck/DeckButton/CardCountContainer/CardCount.text = str(len(game_logic.player.deck))
	$OpponentDeck/DeckButton/CardCountContainer/CardCount.text = str(len(game_logic.opponent.deck))

	$PlayerDeck/DiscardCount.text = str(len(game_logic.player.discards))
	$OpponentDeck/DiscardCount.text = str(len(game_logic.opponent.discards))

	$PlayerGauge.set_details(len(game_logic.player.gauge))
	$OpponentGauge.set_details(len(game_logic.opponent.gauge))

func get_card_node_name(id):
	return "Card_" + str(id)

func create_card(id, card_def, image, parent, hand_focus_y_pos) -> CardBase:
	var new_card : CardBase = CardBaseScene.instantiate()
	parent.add_child(new_card)
	var cost = card_def['gauge_cost']
	if cost == 0:
		cost = card_def['force_cost']
	new_card.initialize_card(
		id,
		card_def['display_name'],
		image,
		card_def['range_min'],
		card_def['range_max'],
		card_def['speed'],
		card_def['power'],
		card_def['armor'],
		card_def['guard'],
		CardDefinitions.get_effects_text(card_def['effects']),
		card_def['boost']['force_cost'],
		CardDefinitions.get_boost_text(card_def['boost']['effects']),
		cost,
		hand_focus_y_pos
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

func is_card_in_player_reference(reference_cards, card_id):
	for card in reference_cards:
		if card.card_id == card_id:
			return true
	return false

func can_select_card(card):
	var in_gauge = game_logic.player.is_card_in_gauge(card.card_id)
	var in_hand = game_logic.player.is_card_in_hand(card.card_id)
	var in_opponent_boosts = game_logic.opponent.is_card_in_continuous_boosts(card.card_id)
	var in_opponent_reference = is_card_in_player_reference($AllCards/OpponentAllCopy.get_children(), card.card_id)
	match ui_sub_state:
		UISubState.UISubState_SelectCards_DiscardCards, UISubState.UISubState_SelectCards_DiscardCardsToGauge:
			return in_hand and len(selected_cards) < select_card_require_max
		UISubState.UISubState_SelectCards_StrikeGauge, UISubState.UISubState_SelectCards_Exceed, UISubState.UISubState_SelectCards_BoostCancel:
			return in_gauge and len(selected_cards) < select_card_require_max
		UISubState.UISubState_SelectCards_MoveActionGenerateForce, UISubState.UISubState_SelectCards_ForceForChange, UISubState.UISubState_SelectCards_ForceForArmor:
			return in_gauge or in_hand
		UISubState.UISubState_SelectCards_StrikeCard, UISubState.UISubState_SelectCards_StrikeResponseCard:
			return in_hand
		UISubState.UISubState_SelectCards_PlayBoost:
			return len(selected_cards) == 0 and in_hand and game_logic.can_player_boost(game_logic.player, card.card_id)
		UISubState.UISubState_SelectCards_DiscardContinuousBoost:
			return in_opponent_boosts and len(selected_cards) < select_card_require_max
		UISubState.UISubState_SelectCards_DiscardFromReference:
			return in_opponent_reference and len(selected_cards) < select_card_require_max

func deselect_all_cards():
	for card in selected_cards:
		card.set_selected(false)
	selected_cards = []

func on_card_clicked(card : CardBase):
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

	clear_selected_cards()
	close_popout()

func _on_post_boost_action(event):
	var player = event['event_player']
	if player == game_logic.player:
		change_ui_state(UIState.UIState_PickTurnAction)
		clear_selected_cards()
		close_popout()
	else:
		ai_take_turn()

func _on_boost_cancel_decision(event):
	var player = event['event_player']
	if player == game_logic.player:
		var gauge_cost = event['number']
		begin_gauge_selection(gauge_cost, false, UISubState.UISubState_SelectCards_BoostCancel)
	else:
		ai_boost_cancel_decision()

func _on_continuous_boost_added(event):
	var card = find_card_on_board(event['number'])
	var boost_zone = $PlayerBoostZone
	var boost_card_loc = $AllCards/PlayerBoosts
	if event['event_player'] == game_logic.opponent:
		boost_zone = $OpponentBoostZone
		boost_card_loc = $AllCards/OpponentBoosts

	var pos = get_boost_zone_center(boost_zone)
	card.discard_to(pos, CardBase.CardState.CardState_InBoost)
	reparent_to_zone(card, boost_card_loc)

func _on_discard_continuous_boost_begin(event):
	if event['event_player'] == game_logic.player:
		# Show the boost window.
		_on_opponent_boost_zone_clicked_zone()
		selected_cards = []
		select_card_require_min = 1
		select_card_require_max = 1
		var cancel_allowed = false
		enable_instructions_ui("Select a continuous boost do discard.", true, cancel_allowed, false)

		change_ui_state(UIState.UIState_SelectCards, UISubState.UISubState_SelectCards_DiscardContinuousBoost)
	else:
		ai_discard_continuous_boost()

func _on_name_opponent_card_begin(event):
	if event['event_player'] == game_logic.player:
		# Show the boost window.
		_on_opponent_reference_button_pressed()
		selected_cards = []
		select_card_require_min = 1
		select_card_require_max = 1
		var cancel_allowed = false
		enable_instructions_ui("Name opponent card.", true, cancel_allowed, false)

		change_ui_state(UIState.UIState_SelectCards, UISubState.UISubState_SelectCards_DiscardFromReference)
	else:
		ai_name_opponent_card()

func _on_boost_played(event):
	var player = event['event_player']
	var card = find_card_on_board(event['number'])
	var target_zone = $PlayerStrike/StrikeZone
	var is_player = player == game_logic.player
	if not player:
		target_zone = $OpponentStrike/StrikeZone
		card.flip_card_to_front(true)
	_move_card_to_strike_area(card, target_zone, $AllCards/Striking, is_player, false)

func _on_choose_card_hand_to_gauge(event):
	var player = event['event_player']
	if player == game_logic.player:
		begin_discard_cards_selection(event['number'], UISubState.UISubState_SelectCards_DiscardCardsToGauge)
	else:
		ai_choose_card_hand_to_gauge()

func clear_selected_cards():
	for card in selected_cards:
		card.set_selected(false)
	selected_cards = []

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

func _on_add_to_gauge(event):
	var card = find_card_on_board(event['number'])
	card.flip_card_to_front(true)
	var gauge_panel = $PlayerGauge
	var gauge_card_loc = $AllCards/PlayerGauge
	if event['event_player'] == game_logic.opponent:
		gauge_panel = $OpponentGauge
		gauge_card_loc = $AllCards/OpponentGauge

	var pos = gauge_panel.get_center_pos()
	card.discard_to(pos, CardBase.CardState.CardState_InGauge)
	reparent_to_zone(card, gauge_card_loc)

func _on_draw_event(event):
	var card_drawn_id = event['number']
	var is_player = event['event_player'] == game_logic.player
	draw_card(card_drawn_id, is_player)
	update_card_counts()

func _on_exceed_event(event):
	var player = event['event_player']
	if player == game_logic.player:
		$PlayerCharacter.modulate = Color(float(98)/255, float(250)/255, 0, 1)
	else:
		$OpponentCharacter.modulate = Color(float(66)/255, float(0)/255, float(24)/255, 1)

func _on_force_start_strike(event):
	var player = event['event_player']
	if player == game_logic.player:
		begin_strike_choosing(false, false)
	else:
		ai_do_strike()

func _on_force_wild_swing(_event):
	printlog("UI: TODO: Play something to indicate forced wild swing.")

func _on_game_over(event):
	printlog("GAME OVER for %s" % event['event_player'].name)
	# TODO: Do something useful

func _on_hand_size_exceeded(event):
	if game_logic.active_turn_player == game_logic.player:
		begin_discard_cards_selection(event['number'], UISubState.UISubState_SelectCards_DiscardCards)
	else:
		# AI or other player wait
		ai_discard(event)

func change_ui_state(new_state, new_sub_state = null):
	if new_state:
		printlog("UI: State change %s to %s" % [UIState.keys()[ui_state], UIState.keys()[new_state]])
		ui_state = new_state
	else:
		printlog("UI: State = %s" % UIState.keys()[ui_state])

	if new_sub_state:
		printlog("UI: Sub state change %s to %s" % [UISubState.keys()[ui_sub_state], UISubState.keys()[new_sub_state]])
		ui_sub_state = new_sub_state
	else:
		printlog("UI: Sub state = %s" % UISubState.keys()[ui_sub_state])
	update_card_counts()
	_update_buttons()

func set_instructions(text):
	$StaticUI/StaticUIVBox/InstructionsWithButtonsUI/Instructions.text = text

func update_discard_selection_message():
	var num_remaining = select_card_require_min - len(selected_cards)
	set_instructions("Select %s more card(s) from your hand to discard." % num_remaining)

func update_discard_to_gauge_selection_message():
	var num_remaining = select_card_require_min - len(selected_cards)
	set_instructions("Select %s more card(s) from your hand to put in gauge." % num_remaining)

func update_gauge_selection_message():
	var num_remaining = select_card_require_min - len(selected_cards)
	set_instructions("Select %s more gauge card(s)." % num_remaining)

func update_gauge_selection_for_cancel_message():
	var num_remaining = select_card_require_min - len(selected_cards)
	set_instructions("Select %s gauge card to use Cancel." % num_remaining)

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
		UISubState.UISubState_SelectCards_ForceForArmor:
			set_instructions("Select cards to generate force for +2 Armor each.\n%s force generated." % [force_selected])

func enable_instructions_ui(message, can_ok, can_cancel, can_wild_swing : bool = false, choices = []):
	set_instructions(message)
	instructions_ok_allowed = can_ok
	instructions_cancel_allowed = can_cancel
	instructions_wild_swing_allowed = can_wild_swing
	var choice_buttons = $StaticUI/StaticUIVBox/InstructionsWithButtonsUI/ButtonContainer/ChoiceButtons.get_children()
	for i in len(choice_buttons):
		if i < len(choices):
			choice_buttons[i].visible = true
			choice_buttons[i].text = CardDefinitions.get_effect_text(choices[i], true)
		else:
			choice_buttons[i].visible = false

func begin_discard_cards_selection(number_to_discard, next_sub_state):
	selected_cards = []
	select_card_require_min = number_to_discard
	select_card_require_max = number_to_discard
	enable_instructions_ui("", true, false)
	change_ui_state(UIState.UIState_SelectCards, next_sub_state)

func begin_generate_force_selection(amount):
	selected_cards = []
	select_card_require_force = amount
	enable_instructions_ui("", true, true)

	change_ui_state(UIState.UIState_SelectCards)

func begin_gauge_selection(amount : int, wild_swing_allowed : bool, sub_state : UISubState):
	# Show the gauge window.
	_on_player_gauge_gauge_clicked()
	selected_cards = []
	select_card_require_min = amount
	select_card_require_max = amount
	var cancel_allowed = false
	match sub_state:
		UISubState.UISubState_SelectCards_Exceed, UISubState.UISubState_SelectCards_BoostCancel:
			cancel_allowed = true
	enable_instructions_ui("", true, cancel_allowed, wild_swing_allowed)

	change_ui_state(UIState.UIState_SelectCards, sub_state)

func begin_effect_choice(choices):
	enable_instructions_ui("Select an effect:", false, false, false, choices)
	change_ui_state(UIState.UIState_MakeChoice, UISubState.UISubState_None)

func begin_strike_choosing(strike_response : bool, cancel_allowed : bool):
	selected_cards = []
	select_card_require_min = 1
	select_card_require_max = 1
	var can_cancel = cancel_allowed and not strike_response
	enable_instructions_ui("Select a card to strike with.", true, can_cancel, true)
	var new_sub_state
	if strike_response:
		new_sub_state = UISubState.UISubState_SelectCards_StrikeResponseCard
	else:
		new_sub_state = UISubState.UISubState_SelectCards_StrikeCard
	change_ui_state(UIState.UIState_SelectCards, new_sub_state)

func begin_boost_choosing():
	selected_cards = []
	select_card_require_min = 1
	select_card_require_max = 1
	var can_cancel = true
	enable_instructions_ui("Select a card to boost.", true, can_cancel)
	change_ui_state(UIState.UIState_SelectCards, UISubState.UISubState_SelectCards_PlayBoost)

func _on_move_event(event):
	if event['event_player'] == game_logic.player:
		move_character_to_arena_square($PlayerCharacter, event['number'])
	else:
		move_character_to_arena_square($OpponentCharacter, event['number'])

func _on_reshuffle_discard(event):
	# TODO: Play a cool animation of discard shuffling into deck
	printlog("UI: TODO: Play reshuffle animation and update reshuffle count/icon.")
	if event['event_player'] == game_logic.player:
		var cards = $AllCards/PlayerDiscards.get_children()
		for card in cards:
			card.get_parent().remove_child(card)
			$AllCards/PlayerDeck.add_child(card)
			card.position = OffScreen
			card.reset()
	else:
		var cards = $AllCards/OpponentDiscards.get_children()
		for card in cards:
			card.get_parent().remove_child(card)
			$AllCards/OpponentDeck.add_child(card)
			card.position = OffScreen
			card.reset()
	close_popout()

func _on_reveal_hand(event):
	if event['event_player'] == game_logic.opponent:
		var cards = $AllCards/OpponentHand.get_children()
		for card in cards:
			card.flip_card_to_front(true)
	else:
		# Nothing for AI here.
		pass

func _move_card_to_strike_area(card, strike_area, new_parent, is_player : bool, is_ex : bool):
	var pos = strike_area.global_position + strike_area.size * strike_area.scale /2
	if is_ex:
		pos.x += CardBase.DesiredCardSize.x
	card.discard_to(pos, CardBase.CardState.CardState_InStrike)
	card.get_parent().remove_child(card)
	new_parent.add_child(card)
	layout_player_hand(is_player)

func _on_strike_started(event, is_ex : bool):
	var card = find_card_on_board(event['number'])
	if event['event_player'] == game_logic.player:
		_move_card_to_strike_area(card, $PlayerStrike/StrikeZone, $AllCards/Striking, true, is_ex)
		if not is_ex:
			ai_strike_response()
	else:
		# Opponent started strike, player has to respond.
		_move_card_to_strike_area(card, $OpponentStrike/StrikeZone, $AllCards/Striking, false, is_ex)
		if not is_ex:
			begin_strike_choosing(true, false)

func _on_strike_reveal(_event):
	var strike_cards = $AllCards/Striking.get_children()
	for card in strike_cards:
		card.flip_card_to_front(true)

func _on_effect_choice(event):
	if event['event_player'] == game_logic.player:
		begin_effect_choice(game_logic.decision_choice)
	else:
		ai_effect_choice(event)

func _on_pay_cost_gauge(event):
	if event['event_player'] == game_logic.player:
		var wild_swing_allowed = game_logic.decision_type == game_logic.DecisionType.DecisionType_PayStrikeCost_CanWild
		var gauge_cost = game_logic.get_card_gauge_cost(event['number'])
		begin_gauge_selection(gauge_cost, wild_swing_allowed, UISubState.UISubState_SelectCards_StrikeGauge)
	else:
		ai_pay_cost(event)

func _on_pay_cost_failed(_event):
	printlog("TODO: Animation for pay costs failed")

func _on_force_for_armor(event):
	if event['event_player'] == game_logic.player:
		change_ui_state(null, UISubState.UISubState_SelectCards_ForceForArmor)
		begin_generate_force_selection(-1)
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
				_on_discard_event(event)
			game_logic.EventType.EventType_AdvanceTurn:
				_on_advance_turn()
			game_logic.EventType.EventType_Boost_ActionAfterBoost:
				_on_post_boost_action(event)
			game_logic.EventType.EventType_Boost_CancelDecision:
				_on_boost_cancel_decision(event)
			game_logic.EventType.EventType_Boost_Canceled:
				printlog("UI: TODO: Play a cool cancel animation.")
			game_logic.EventType.EventType_Boost_Continuous_Added:
				_on_continuous_boost_added(event)
			game_logic.EventType.EventType_Boost_DiscardContinuousChoice:
				_on_discard_continuous_boost_begin(event)
			game_logic.EventType.EventType_Boost_NameCardOpponentDiscards:
				_on_name_opponent_card_begin(event)
			game_logic.EventType.EventType_Boost_Played:
				_on_boost_played(event)
			game_logic.EventType.EventType_CardFromHandToGauge_Choice:
				_on_choose_card_hand_to_gauge(event)
			game_logic.EventType.EventType_Discard:
				_on_discard_event(event)
			game_logic.EventType.EventType_Draw:
				_on_draw_event(event)
			game_logic.EventType.EventType_Exceed:
				_on_exceed_event(event)
			game_logic.EventType.EventType_ForceStartStrike:
				_on_force_start_strike(event)
			game_logic.EventType.EventType_Strike_ForceWildSwing:
				_on_force_wild_swing(event)
			game_logic.EventType.EventType_GameOver:
				_on_game_over(event)
			game_logic.EventType.EventType_HandSizeExceeded:
				_on_hand_size_exceeded(event)
			game_logic.EventType.EventType_Move:
				_on_move_event(event)
			game_logic.EventType.EventType_ReshuffleDiscard:
				_on_reshuffle_discard(event)
			game_logic.EventType.EventType_RevealHand:
				_on_reveal_hand(event)
			game_logic.EventType.EventType_Strike_ArmorUp:
				printlog("TODO: Animate strike armor up")
			game_logic.EventType.EventType_Strike_DodgeAttacks:
				printlog("TODO: Animate strike dodge attacks")
			game_logic.EventType.EventType_Strike_EffectChoice:
				_on_effect_choice(event)
			game_logic.EventType.EventType_Strike_ExUp:
				printlog("TODO: Animate Ex up")
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
			game_logic.EventType.EventType_Strike_PayCost_Gauge:
				_on_pay_cost_gauge(event)
			game_logic.EventType.EventType_Strike_PayCost_Force:
				printlog("TODO: UI Pay force costs on card")
				assert(false)
			game_logic.EventType.EventType_Strike_PayCost_Unable:
				_on_pay_cost_failed(event)
			game_logic.EventType.EventType_Strike_PowerUp:
				printlog("TODO: Animate strike power up")
			game_logic.EventType.EventType_Strike_Response:
				_on_strike_started(event, false)
			game_logic.EventType.EventType_Strike_Response_Ex:
				_on_strike_started(event, true)
			game_logic.EventType.EventType_Strike_Reveal:
				_on_strike_reveal(event)
			game_logic.EventType.EventType_Strike_Started:
				_on_strike_started(event, false)
			game_logic.EventType.EventType_Strike_Started_Ex:
				_on_strike_started(event, true)
			game_logic.EventType.EventType_Strike_Stun:
				printlog("TODO: Animate strike stun")
			game_logic.EventType.EventType_Strike_TookDamage:
				_on_damage(event)
			game_logic.EventType.EventType_Strike_WildStrike:
				printlog("TODO: Animate strike wild strike")
			_:
				printlog("ERROR: UNHANDLED EVENT")
				assert(false)

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
	var instructions_visible = false
	match ui_state:
		UIState.UIState_SelectCards, UIState.UIState_SelectArenaLocation, UIState.UIState_MakeChoice:
			instructions_visible = true

	$StaticUI/StaticUIVBox/InstructionsWithButtonsUI.visible = instructions_visible

	# Update instructions UI Buttons
	$StaticUI/StaticUIVBox/InstructionsWithButtonsUI/ButtonContainer/OkButton.disabled = not can_press_ok()
	$StaticUI/StaticUIVBox/InstructionsWithButtonsUI/ButtonContainer/OkButton.visible = instructions_ok_allowed
	$StaticUI/StaticUIVBox/InstructionsWithButtonsUI/ButtonContainer/CancelButton.visible = instructions_cancel_allowed
	$StaticUI/StaticUIVBox/InstructionsWithButtonsUI/ButtonContainer/WildSwingButton.visible = instructions_wild_swing_allowed

	match ui_sub_state:
		UISubState.UISubState_SelectCards_BoostCancel:
			$StaticUI/StaticUIVBox/InstructionsWithButtonsUI/ButtonContainer/CancelButton.text = "Pass"
		_:
			$StaticUI/StaticUIVBox/InstructionsWithButtonsUI/ButtonContainer/CancelButton.text = "Cancel"

	# Update instructions message
	if ui_state == UIState.UIState_SelectCards:
		match ui_sub_state:
			UISubState.UISubState_SelectCards_DiscardCards:
				update_discard_selection_message()
			UISubState.UISubState_SelectCards_DiscardCardsToGauge:
				update_discard_to_gauge_selection_message()
			UISubState.UISubState_SelectCards_MoveActionGenerateForce:
				update_force_generation_message()
			UISubState.UISubState_SelectCards_ForceForChange:
				update_force_generation_message()
			UISubState.UISubState_SelectCards_ForceForArmor:
				update_force_generation_message()
			UISubState.UISubState_SelectCards_StrikeGauge:
				update_gauge_selection_message()
			UISubState.UISubState_SelectCards_BoostCancel:
				update_gauge_selection_for_cancel_message()
			UISubState.UISubState_SelectCards_Exceed:
				update_gauge_selection_message()

	# Update arena location selection buttons
	for i in range(1, 10):
		var arena_button = get_arena_location_button(i)
		arena_button.visible = (ui_state == UIState.UIState_SelectArenaLocation and i in arena_locations_clickable)

	# Update boost zones
	update_boost_summary(game_logic.player, $PlayerBoostZone)
	update_boost_summary(game_logic.opponent, $OpponentBoostZone)

func update_boost_summary(summary_player, zone):
	var player_boost_effects = summary_player.get_all_non_immediate_continuous_boost_effects()
	var boost_summary = ""
	for effect in player_boost_effects:
		boost_summary += CardDefinitions.get_effect_text(effect) + "\n"
	zone.set_text(boost_summary)


func selected_cards_between_min_and_max() -> bool:
	var selected_count = len(selected_cards)
	return selected_count >= select_card_require_min && selected_count <= select_card_require_max

func can_press_ok():
	if ui_state == UIState.UIState_SelectCards:
		match ui_sub_state:
			UISubState.UISubState_SelectCards_DiscardCards, UISubState.UISubState_SelectCards_StrikeGauge, UISubState.UISubState_SelectCards_Exceed:
				return selected_cards_between_min_and_max()
			UISubState.UISubState_SelectCards_BoostCancel, UISubState.UISubState_SelectCards_DiscardContinuousBoost, UISubState.UISubState_SelectCards_DiscardFromReference:
				return selected_cards_between_min_and_max()
			UISubState.UISubState_SelectCards_DiscardCardsToGauge:
				return selected_cards_between_min_and_max()
			UISubState.UISubState_SelectCards_MoveActionGenerateForce:
				var force_selected = get_force_in_selected_cards()
				return force_selected == select_card_require_force
			UISubState.UISubState_SelectCards_ForceForChange:
				var force_selected = get_force_in_selected_cards()
				return force_selected > 0
			UISubState.UISubState_SelectCards_StrikeCard, UISubState.UISubState_SelectCards_StrikeResponseCard:
				# As a special exception, allow 2 cards if exactly 2 cards and they're the same card.
				if len(selected_cards) == 2:
					var card1 = selected_cards[0]
					var card2 = selected_cards[1]
					return game_logic.are_same_card(card1.card_id, card2.card_id)
				return len(selected_cards) == 1
			UISubState.UISubState_SelectCards_ForceForArmor:
				return true
			UISubState.UISubState_SelectCards_PlayBoost:
				return len(selected_cards) == 1
	return false

func begin_select_arena_location(valid_moves):
	arena_locations_clickable = valid_moves
	enable_instructions_ui("Select a location", false, true)
	change_ui_state(UIState.UIState_SelectArenaLocation, UISubState.UISubState_SelectCards_MoveActionGenerateForce)

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
	change_ui_state(null, UISubState.UISubState_SelectCards_ForceForChange)
	begin_generate_force_selection(-1)

func _on_exceed_button_pressed():
	begin_gauge_selection(game_logic.player.exceed_cost, false, UISubState.UISubState_SelectCards_Exceed)

func _on_reshuffle_button_pressed():
	var events = game_logic.do_reshuffle(game_logic.player)
	_handle_events(events)

func _on_boost_button_pressed():
	begin_boost_choosing()

func _on_strike_button_pressed():
	begin_strike_choosing(false, true)

func _on_choice_pressed(choice):
	var events = game_logic.do_choice(game_logic.player, choice)
	_handle_events(events)

func _on_instructions_ok_button_pressed():
	if ui_state == UIState.UIState_SelectCards and can_press_ok():
		var selected_card_ids = []
		for card in selected_cards:
			selected_card_ids.append(card.card_id)
		var single_card_id = -1
		var ex_card_id = -1
		if len(selected_card_ids) == 1:
			single_card_id = selected_card_ids[0]
		if len(selected_card_ids) == 2:
			ex_card_id = selected_card_ids[1]
		deselect_all_cards()
		close_popout()
		var events = []
		match ui_sub_state:
			UISubState.UISubState_SelectCards_BoostCancel:
				events = game_logic.do_boost_cancel(game_logic.player, selected_card_ids, true)
			UISubState.UISubState_SelectCards_DiscardContinuousBoost:
				events = game_logic.do_boost_name_card_choice_effect(game_logic.player, single_card_id)
			UISubState.UISubState_SelectCards_DiscardFromReference:
				events = game_logic.do_boost_name_card_choice_effect(game_logic.player, single_card_id - ReferenceScreenIdRangeStart)
			UISubState.UISubState_SelectCards_DiscardCards:
				events = game_logic.do_discard_to_max(game_logic.player, selected_card_ids)
			UISubState.UISubState_SelectCards_DiscardCardsToGauge:
				events = game_logic.do_card_from_hand_to_gauge(game_logic.player, single_card_id)
			UISubState.UISubState_SelectCards_StrikeGauge:
				events = game_logic.do_pay_strike_cost(game_logic.player, selected_card_ids, false)
			UISubState.UISubState_SelectCards_Exceed:
				events = game_logic.do_exceed(game_logic.player, selected_card_ids)
			UISubState.UISubState_SelectCards_MoveActionGenerateForce:
				events = game_logic.do_move(game_logic.player, selected_card_ids, selected_arena_location)
			UISubState.UISubState_SelectCards_ForceForChange:
				events = game_logic.do_change(game_logic.player, selected_card_ids)
			UISubState.UISubState_SelectCards_StrikeCard, UISubState.UISubState_SelectCards_StrikeResponseCard:
				events = game_logic.do_strike(game_logic.player, single_card_id, false, ex_card_id)
			UISubState.UISubState_SelectCards_ForceForArmor:
				events = game_logic.do_force_for_armor(game_logic.player, selected_card_ids)
			UISubState.UISubState_SelectCards_PlayBoost:
				if game_logic.get_card_boost_force_cost(single_card_id) > 0:
					printlog("ERROR: TODO: Force cost not implemented.")
					assert(false)
				else:
					events = game_logic.do_boost(game_logic.player, single_card_id)
		_handle_events(events)

func _on_instructions_cancel_button_pressed():
	match ui_sub_state:
		UISubState.UISubState_SelectCards_ForceForArmor:
				var selected_card_ids = []
				deselect_all_cards()
				var events = game_logic.do_force_for_armor(game_logic.player, selected_card_ids)
				_handle_events(events)
				return

	if ui_state == UIState.UIState_SelectArenaLocation and instructions_cancel_allowed:
		change_ui_state(UIState.UIState_PickTurnAction)
	if ui_state == UIState.UIState_SelectCards and instructions_cancel_allowed:
		deselect_all_cards()
		close_popout()
		if ui_sub_state == UISubState.UISubState_SelectCards_BoostCancel:
			var events = game_logic.do_boost_cancel(game_logic.player, [], false)
			_handle_events(events)
		else:
			change_ui_state(UIState.UIState_PickTurnAction)

func _on_wild_swing_button_pressed():
	if ui_state == UIState.UIState_SelectCards:
		if ui_sub_state == UISubState.UISubState_SelectCards_StrikeCard:
			var events = game_logic.do_strike(game_logic.player, -1, true, -1)
			_handle_events(events)
		elif ui_sub_state == UISubState.UISubState_SelectCards_StrikeGauge:
			close_popout()
			var events = game_logic.do_pay_strike_cost(game_logic.player, [], true)
			_handle_events(events)

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
	var events = game_logic.do_pay_strike_cost(game_logic.opponent, [], true)
	_handle_events(events)

func ai_effect_choice(_event):
	var events = game_logic.do_choice(game_logic.opponent, 0)
	_handle_events(events)

func ai_force_for_armor(_event):
	var events = game_logic.do_force_for_armor(game_logic.opponent, [])
	_handle_events(events)

func ai_strike_response():
	var card = game_logic.opponent.hand[0]
	var events = game_logic.do_strike(game_logic.opponent, card.id, false, -1)
	_handle_events(events)

func ai_discard(event):
	var to_discard = []
	for i in range(event['number']):
		to_discard.append(game_logic.opponent.hand[i].id)
	var events = game_logic.do_discard_to_max(game_logic.opponent, to_discard)
	_handle_events(events)

func ai_do_strike():
	var hand = game_logic.opponent.hand
	var events = []
	if len(hand) > 0:
		var card = hand[0]
		events = game_logic.do_strike(game_logic.opponent, card.id, false, -1)
	else:
		events = game_logic.do_strike(game_logic.opponent, -1, true, -1)

	_handle_events(events)

func ai_boost_cancel_decision():
	var events = game_logic.do_boost_cancel(game_logic.opponent, [], false)
	_handle_events(events)

func ai_discard_continuous_boost():
	var card_id = game_logic.player.continuous_boosts[0].id
	var events = game_logic.do_boost_name_card_choice_effect(game_logic.opponent, card_id)
	_handle_events(events)

func ai_name_opponent_card():
	var card : CardBase = $AllCards/PlayerAllCopy.get_child(0)
	var real_id = card.card_id - ReferenceScreenIdRangeStart
	var events = game_logic.do_boost_name_card_choice_effect(game_logic.opponent, real_id)
	_handle_events(events)

func ai_choose_card_hand_to_gauge():
	var card_id = game_logic.opponent.hand[0].id
	var events = game_logic.do_card_from_hand_to_gauge(game_logic.opponent, card_id)
	_handle_events(events)

func card_in_selected_cards(card):
	for selected_card in selected_cards:
		if selected_card.card_id == card.card_id:
			return true
	return false

# Popout Functions
func _update_popout_cards(cards_in_popout : Array, not_visible_position : Vector2, card_return_state : CardBase.CardState):
	card_popout.set_amount(len(cards_in_popout))
	if card_popout.visible:
		# Clear first which sets the size/positions correctly.
		await card_popout.clear(len(cards_in_popout))
		for i in range(len(cards_in_popout)):
			var card = cards_in_popout[i]
			card.set_selected(card_in_selected_cards(card))
			# Assign positions
			var pos = card_popout.get_slot_position(i)
			card.position = pos + CardBase.SmallCardScale * CardBase.ActualCardSize / 2
			card.change_state(CardBase.CardState.CardState_InPopout)
			card.set_resting_position(card.position, 0)
	else:
		# When clearing, set the cards first before awaiting.
		for i in range(len(cards_in_popout)):
			var card = cards_in_popout[i]
			card.set_selected(false)
			# Assign back to gauge
			card.position = not_visible_position
			if card.state == CardBase.CardState.CardState_InPopout:
				card.change_state(card_return_state)
			card.set_resting_position(card.position, 0)
		await card_popout.clear(0)

func clear_card_popout():
	# Gauges
	await _update_popout_cards(
		$AllCards/PlayerGauge.get_children(),
		$PlayerGauge.get_center_pos(),
		CardBase.CardState.CardState_InGauge
	)
	await _update_popout_cards(
		$AllCards/OpponentGauge.get_children(),
		$OpponentGauge.get_center_pos(),
		CardBase.CardState.CardState_InGauge
	)

	# Discards
	await _update_popout_cards(
		$AllCards/PlayerDiscards.get_children(),
		get_discard_location($PlayerDeck/Discard),
		CardBase.CardState.CardState_Discarded
	)
	await _update_popout_cards(
		$AllCards/OpponentDiscards.get_children(),
		get_discard_location($OpponentDeck/Discard),
		CardBase.CardState.CardState_Discarded
	)

	# Boosts
	await _update_popout_cards(
		$AllCards/PlayerBoosts.get_children(),
		get_boost_zone_center($PlayerBoostZone),
		CardBase.CardState.CardState_InBoost
	)
	await _update_popout_cards(
		$AllCards/OpponentBoosts.get_children(),
		get_boost_zone_center($OpponentBoostZone),
		CardBase.CardState.CardState_InBoost
	)

	# Reference
	await _update_popout_cards(
		$AllCards/PlayerAllCopy.get_children(),
		OffScreen,
		CardBase.CardState.CardState_Offscreen
	)
	await _update_popout_cards(
		$AllCards/OpponentAllCopy.get_children(),
		OffScreen,
		CardBase.CardState.CardState_Offscreen
	)

func close_popout():
	card_popout.visible = false
	await clear_card_popout()

func show_popout(popout_title : String, card_node, card_rest_position : Vector2, card_rest_state : CardBase.CardState):
	card_popout.set_title(popout_title)
	if card_popout.visible:
		card_popout.visible = false
		await clear_card_popout()
	card_popout.visible = true
	var cards = card_node.get_children()
	_update_popout_cards(cards, card_rest_position, card_rest_state)

func get_boost_zone_center(zone):
	var pos = zone.global_position + CardBase.DesiredCardSize / 2
	return pos

func _on_player_gauge_gauge_clicked():
	await close_popout()
	show_popout("YOUR GAUGE", $AllCards/PlayerGauge, $PlayerGauge.get_center_pos(), CardBase.CardState.CardState_InGauge)

func _on_opponent_gauge_gauge_clicked():
	await close_popout()
	show_popout("THEIR GAUGE", $AllCards/OpponentGauge, $OpponentGauge.get_center_pos(), CardBase.CardState.CardState_InGauge)

func _on_player_discard_button_pressed():
	await close_popout()
	show_popout("YOUR DISCARDS", $AllCards/PlayerDiscards, get_discard_location($PlayerDeck/Discard), CardBase.CardState.CardState_Discarded)

func _on_opponent_discard_button_pressed():
	await close_popout()
	show_popout("THEIR DISCARD", $AllCards/OpponentDiscards, get_discard_location($OpponentDeck/Discard), CardBase.CardState.CardState_Discarded)

func _on_player_boost_zone_clicked_zone():
	await close_popout()
	show_popout("YOUR BOOSTS", $AllCards/PlayerBoosts, get_boost_zone_center($PlayerBoostZone), CardBase.CardState.CardState_InBoost)

func _on_opponent_boost_zone_clicked_zone():
	await close_popout()
	show_popout("THEIR BOOSTS", $AllCards/OpponentBoosts, get_boost_zone_center($OpponentBoostZone), CardBase.CardState.CardState_InBoost)

func _on_popout_close_window():
	await close_popout()

func _on_player_reference_button_pressed():
	await close_popout()
	show_popout("YOUR DECK REFERENCE", $AllCards/PlayerAllCopy, OffScreen, CardBase.CardState.CardState_Offscreen)

func _on_opponent_reference_button_pressed():
	await close_popout()
	show_popout("THEIR DECK REFERENCE", $AllCards/OpponentAllCopy, OffScreen, CardBase.CardState.CardState_Offscreen)
