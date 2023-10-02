extends Node2D

const CardBaseScene = preload("res://scenes/card/card_base.tscn")
const CardBase = preload("res://scenes/card/card_base.gd")
const GameLogic = preload("res://scenes/game/gamelogic.gd")
const CardPopout = preload("res://scenes/game/card_popout.gd")
const GaugePanel = preload("res://scenes/game/gauge_panel.gd")
const CharacterCardBase = preload("res://scenes/card/character_card_base.gd")
const AIPlayer = preload("res://scenes/game/ai_player.gd")
const DamagePopup = preload("res://scenes/game/damage_popup.gd")
const Character = preload("res://scenes/game/character.gd")

@onready var damage_popup_template = preload("res://scenes/game/damage_popup.tscn")
@onready var arena_layout = $ArenaNode/RowButtons

const OffScreen = Vector2(-1000, -1000)
const ReferenceScreenIdRangeStart = 90000
const NoticeOffsetY = 50

const StrikeRevealDelay : float = 3.0
const MoveDelay : float = 1.0
const BoostDelay : float = 3.0
const SmallNoticeDelay : float = 1.0
var remaining_delay = 0
var events_to_process = []

var damage_popup_pool:Array[DamagePopup] = []

const PlayerHandFocusYPos = 720 - (CardBase.DesiredCardSize.y + 20)
const OpponentHandFocusYPos = CardBase.DesiredCardSize.y

var chosen_deck = null
var NextCardId = 1

const Test_StartWithGauge = false

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
	UIState_GameOver,
	UIState_PickTurnAction,
	UIState_MakeChoice,
	UIState_SelectCards,
	UIState_SelectArenaLocation,
	UIState_WaitingOnOpponent,
	UIState_PlayingAnimation,
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
	UISubState_SelectCards_Mulligan, # 10
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
@onready var player_character_card : CharacterCardBase  = $PlayerDeck/PlayerCharacterCard
@onready var opponent_character_card : CharacterCardBase  = $OpponentDeck/OpponentCharacterCard
@onready var player_card_count = $PlayerDeck/DeckButton/CardCountContainer/VBoxContainer/CardCount
@onready var opponent_card_count = $OpponentDeck/DeckButton/CardCountContainer/VBoxContainer/CardCount
@onready var game_over_stuff = $GameOverStuff
@onready var game_over_label = $GameOverStuff/GameOverLabel
@onready var ai_player : AIPlayer = $AIPlayer

@onready var CenterCardOval = Vector2(get_viewport().content_scale_size) * Vector2(0.5, 1.25)
@onready var HorizontalRadius = get_viewport().content_scale_size.x * 0.45
@onready var VerticalRadius = get_viewport().content_scale_size.y * 0.4

func printlog(text):
	print("UI: %s" % text)


var _socket = null #WebSocketPeer.new()
var sent_message = false

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_socket.close()

func _handle_sockets():
	if _socket:
		_socket.poll()
		var state = _socket.get_ready_state()
		match state:
			WebSocketPeer.STATE_OPEN:
				while _socket.get_available_packet_count():
					var packet = _socket.get_packet()
					print("Packet: ", packet)
					if _socket.was_string_packet():
						var strpacket = packet.get_string_from_utf8()
						print("Strpacket: ", strpacket)
				if not sent_message:
					var res2 = _socket.send_text("SUPER COOL TEST")
					sent_message = true
					print("  send result: ", res2)
			WebSocketPeer.STATE_CLOSING:
				pass
			WebSocketPeer.STATE_CLOSED:
				var code = _socket.get_close_code()
				var reason = _socket.get_close_reason()
				print("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
				_socket = null


# Called when the node enters the scene tree for the first time.
func _ready():
	if _socket:
		_socket.connect_to_url("ws://localhost:8765")
	chosen_deck = CardDefinitions.decks[0]
	game_logic.initialize_game(chosen_deck, chosen_deck)

	$PlayerLife.set_life(game_logic.player.life)
	$OpponentLife.set_life(game_logic.opponent.life)
	game_over_stuff.visible = false

	setup_character_cards(chosen_deck, chosen_deck)

func setup_character_cards(player_deck, opponent_deck):
	setup_character_card(player_character_card, player_deck['character'])
	setup_character_card(opponent_character_card, opponent_deck['character'])

func setup_character_card(character_card, character):
	character_card.set_name_text(character['display_name'])
	character_card.set_image(character['image'], character['exceed_image'])
	var on_exceed_text = CardDefinitions.get_on_exceed_text(character['on_exceed'])
	var effect_text = on_exceed_text + CardDefinitions.get_effects_text(character['ability_effects'])
	var exceed_text = CardDefinitions.get_effects_text(character['exceed_ability_effects'])
	character_card.set_effect(effect_text, exceed_text)
	character_card.set_cost(character['exceed_cost'])

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
	if Test_StartWithGauge:
		for i in range(4):
			test_draw_and_add()
		layout_player_hand(true)
		_update_buttons()

func first_run():
	move_character_to_arena_square($PlayerCharacter, game_logic.player.arena_location, true, Character.CharacterAnim.CharacterAnim_None)
	move_character_to_arena_square($OpponentCharacter, game_logic.opponent.arena_location, true, Character.CharacterAnim.CharacterAnim_None)
	_update_buttons()

	finish_initialization()

func spawn_deck(deck, deck_copy, deck_card_zone, copy_zone, card_back_image, hand_focus_y_pos):
	for card in deck:
		var logic_card : GameLogic.Card = game_logic.get_card(card.id)
		var new_card = create_card(card.id, logic_card.definition, logic_card.image, card_back_image, deck_card_zone, hand_focus_y_pos)
		new_card.position = OffScreen

	var previous_def_id = ""
	for card in deck_copy:
		var logic_card : GameLogic.Card = game_logic.get_card(card.id)
		if previous_def_id != logic_card.definition['id']:
			var copy_card = create_card(card.id + ReferenceScreenIdRangeStart, logic_card.definition, logic_card.image, card_back_image, copy_zone, 0)
			copy_card.position = OffScreen
			copy_card.resting_scale = CardBase.SmallCardScale
			copy_card.scale = CardBase.SmallCardScale
			copy_card.change_state(CardBase.CardState.CardState_Offscreen)
			copy_card.flip_card_to_front(true)
			previous_def_id = card.definition['id']

func spawn_damage_popup(value:String, notice_player : GameLogic.Player):
	var popup = get_damage_popup()
	var pos = get_notice_position(notice_player)
	pos.y -= NoticeOffsetY
	var height = NoticeOffsetY
	add_child(popup)
	popup.set_values_and_animate(value, pos, height)

func get_damage_popup() -> DamagePopup:
	if damage_popup_pool.size() > 0:
		return damage_popup_pool.pop_front()
	else:
		var new_popup = damage_popup_template.instantiate()
		new_popup.tree_exiting.connect(
			func():damage_popup_pool.append(new_popup))
		return new_popup

func spawn_all_cards():
	var card_back_image = "res://assets/character_images/" + game_logic.player.deck_def['character']['image']
	spawn_deck(game_logic.player.deck, game_logic.player.deck_copy, $AllCards/PlayerDeck, $AllCards/PlayerAllCopy, card_back_image, PlayerHandFocusYPos)
	spawn_deck(game_logic.opponent.deck, game_logic.opponent.deck_copy, $AllCards/OpponentDeck, $AllCards/OpponentAllCopy, card_back_image, OpponentHandFocusYPos)

func draw_and_begin():
	var events = game_logic.draw_starting_hands_and_begin()
	_handle_events(events)

func get_arena_location_button(arena_location):
	var target_square = arena_layout.get_child(arena_location - 1)
	var button = target_square.get_node("Button")
	return button

func move_character_to_arena_square(character, arena_location, immediate: bool, move_anim : Character.CharacterAnim):
	var target_square = arena_layout.get_child(arena_location - 1)
	var target_position = target_square.global_position + target_square.size/2
	var offset_y = $ArenaNode/RowButtons.position.y
	target_position.y -= character.get_size().y * character.scale.y / 2 + offset_y
	if immediate:
		character.position = target_position
		update_character_facing()
	else:
		character.move_to(target_position, move_anim)

func update_character_facing():
	var character = $PlayerCharacter
	var other_character = $OpponentCharacter
	var to_left = character.position.x < other_character.position.x
	character.set_facing(to_left)
	other_character.set_facing(not to_left)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	_handle_sockets()
	if not first_run_done:
		first_run()
		first_run_done = true
	if ui_state == UIState.UIState_PlayingAnimation:
		remaining_delay -= delta
		if remaining_delay <= 0:
			# Animation is finished playing.
			update_character_facing()
			remaining_delay = 0
			if len(events_to_process) > 0:
				var temp_events = events_to_process
				events_to_process = []
				_handle_events(temp_events)
			else:
				change_ui_state(UIState.UIState_PickTurnAction, UISubState.UISubState_None)

func begin_delay(delay : float, remaining_events : Array):
	change_ui_state(UIState.UIState_PlayingAnimation, UISubState.UISubState_None)
	remaining_delay = delay
	events_to_process = remaining_events

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

func get_deck_button_position(is_player : bool):
	var button = get_deck_button(is_player)
	var deck_position = button.position + (button.size * button.scale)/2
	return deck_position

func get_hand_zone(is_player : bool):
	if is_player:
		return $AllCards/PlayerHand
	else:
		return $AllCards/OpponentHand

func draw_card(card_id : int, is_player : bool):
	var card = add_card_to_hand(card_id, is_player)

	# Start the card at the deck.
	card.position = get_deck_button_position(is_player)

	layout_player_hand(is_player)

func update_card_counts():
	$OpponentHand/OpponentHandBox/OpponentNumCards.text = str(len(game_logic.opponent.hand))

	$PlayerLife.set_deck_size(len(game_logic.player.deck))
	$OpponentLife.set_deck_size(len(game_logic.opponent.deck))

	$PlayerLife.set_discard_size(len(game_logic.player.discards), game_logic.player.reshuffle_remaining)
	$OpponentLife.set_discard_size(len(game_logic.opponent.discards), game_logic.player.reshuffle_remaining)

	$PlayerGauge.set_details(len(game_logic.player.gauge))
	$OpponentGauge.set_details(len(game_logic.opponent.gauge))

func get_card_node_name(id):
	return "Card_" + str(id)

func create_card(id, card_def, image, card_back_image, parent, hand_focus_y_pos) -> CardBase:
	var new_card : CardBase = CardBaseScene.instantiate()
	parent.add_child(new_card)
	var strike_cost = card_def['gauge_cost']
	if strike_cost == 0:
		strike_cost = card_def['force_cost']
	new_card.initialize_card(
		id,
		card_def['display_name'],
		image,
		card_back_image,
		card_def['range_min'],
		card_def['range_max'],
		card_def['speed'],
		card_def['power'],
		card_def['armor'],
		card_def['guard'],
		CardDefinitions.get_effects_text(card_def['effects']),
		card_def['boost']['force_cost'],
		CardDefinitions.get_boost_text(card_def['boost']['effects']),
		strike_cost,
		card_def['boost']['cancel_cost'],
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
		UISubState.UISubState_SelectCards_StrikeCard, UISubState.UISubState_SelectCards_StrikeResponseCard, UISubState.UISubState_SelectCards_Mulligan:
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
		if num_cards == 1:
			var pos = Vector2(hand_center.x, hand_center.y)
			var card : CardBase = hand_zone.get_child(0)
			card.set_resting_position(pos, 0)
		elif num_cards > 1:
			var step = (max_x - min_x) / (num_cards - 1)
			step = min(step, 100)
			var new_diff = step * (num_cards - 1)
			max_x = hand_center.x + new_diff / 2
			min_x = hand_center.x - new_diff / 2
			for i in range(num_cards):
				var pos = Vector2(min_x + step * i, hand_center.y)
				var card : CardBase = hand_zone.get_child(i)
				card.set_resting_position(pos, 0)

	update_card_counts()

func _log_event(event):
	var num = event['number']
	var card_name = game_logic.get_card_name(num)
	printlog("Event %s num=%s (card=%s)" % [game_logic.EventType.keys()[event['event_type']], event['number'], card_name])

func get_notice_position(notice_player):
	if notice_player == game_logic.player:
		return $PlayerCharacter.position
	else:
		return $OpponentCharacter.position

func _stat_notice_event(event):
	var player = event['event_player']
	var number = event['number']
	var notice_text = ""
	match event['event_type']:
		GameLogic.EventType.EventType_Strike_ArmorUp:
			notice_text = "%d Armor" % number
		GameLogic.EventType.EventType_Strike_DodgeAttacks:
			notice_text = "Dodge Attacks!"
		GameLogic.EventType.EventType_Strike_ExUp:
			notice_text = "EX Strike!"
		GameLogic.EventType.EventType_Strike_GainAdvantage:
			notice_text = "Advantage!"
		GameLogic.EventType.EventType_Strike_GuardUp:
			notice_text = "%d Guard" % number
		GameLogic.EventType.EventType_Strike_IgnoredPushPull:
			notice_text = "Unmoved!"
		GameLogic.EventType.EventType_Strike_Miss:
			notice_text = "Miss!"
		GameLogic.EventType.EventType_Strike_PowerUp:
			notice_text = "%d Power" % number
		GameLogic.EventType.EventType_Strike_Stun:
			notice_text = "Stunned!"
		GameLogic.EventType.EventType_Strike_WildStrike:
			notice_text = "Wild Swing!"

	spawn_damage_popup(notice_text, player)
	return SmallNoticeDelay

func _on_stunned(event):
	var card = find_card_on_board(event['number'])
	var player = event['event_player']
	var is_player = player == game_logic.player
	card.set_stun(true)
	if is_player:
		$PlayerCharacter.play_stunned()
	else:
		$OpponentCharacter.play_stunned()
	return _stat_notice_event(event)

func _on_advance_turn():
	$PlayerLife.set_turn_indicator(game_logic.active_turn_player == game_logic.player)
	$OpponentLife.set_turn_indicator(game_logic.active_turn_player == game_logic.opponent)

	if game_logic.active_turn_player == game_logic.player:
		change_ui_state(UIState.UIState_PickTurnAction, UISubState.UISubState_None)
	else:
		change_ui_state(UIState.UIState_WaitingOnOpponent, UISubState.UISubState_None)

	clear_selected_cards()
	close_popout()
	for zone in $AllCards.get_children():
		for card in zone.get_children():
			card.set_backlight_visible(false)
			card.set_stun(false)

	spawn_damage_popup("Ready!", game_logic.active_turn_player)

func _on_post_boost_action(event):
	var player = event['event_player']
	spawn_damage_popup("Bonus Action", player)
	if player == game_logic.player:
		change_ui_state(UIState.UIState_PickTurnAction, UISubState.UISubState_None)
		clear_selected_cards()
		close_popout()
	else:
		ai_take_turn()

func _on_boost_cancel_decision(event):
	var player = event['event_player']
	var gauge_cost = event['number']
	spawn_damage_popup("Cancel?", player)
	if player == game_logic.player:
		begin_gauge_selection(gauge_cost, false, UISubState.UISubState_SelectCards_BoostCancel)
	else:
		ai_boost_cancel_decision(gauge_cost)

func _on_boost_canceled(event):
	var player = event['event_player']
	spawn_damage_popup("Cancel!", player)
	return SmallNoticeDelay

func _on_continuous_boost_added(event):
	var player = event['event_player']
	var card = find_card_on_board(event['number'])
	var boost_zone = $PlayerBoostZone
	var boost_card_loc = $AllCards/PlayerBoosts

	if player == game_logic.opponent:
		boost_zone = $OpponentBoostZone
		boost_card_loc = $AllCards/OpponentBoosts

	var pos = get_boost_zone_center(boost_zone)
	card.discard_to(pos, CardBase.CardState.CardState_InBoost)
	reparent_to_zone(card, boost_card_loc)
	spawn_damage_popup("+ Continuous Boost", player)
	return SmallNoticeDelay

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
	var player = event['event_player']
	spawn_damage_popup("Naming Card", player)
	if player == game_logic.player:
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
	if not is_player:
		target_zone = $OpponentStrike/StrikeZone
		card.flip_card_to_front(true)
	_move_card_to_strike_area(card, target_zone, $AllCards/Striking, is_player, false)
	spawn_damage_popup("Boost!", player)
	return BoostDelay

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
	var player = event['event_player']
	var discard_id = event['number']
	var card = find_card_on_board(discard_id)
	if player == game_logic.player:
		discard_card(card, $PlayerDeck/Discard, $AllCards/PlayerDiscards, true)
	else:
		discard_card(card, $OpponentDeck/Discard, $AllCards/OpponentDiscards, false)
	update_card_counts()
	#spawn_damage_popup("Discard", player)

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
	var player = event['event_player']
	var card = find_card_on_board(event['number'])
	card.flip_card_to_front(true)
	var gauge_panel = $PlayerGauge
	var gauge_card_loc = $AllCards/PlayerGauge
	if player == game_logic.opponent:
		gauge_panel = $OpponentGauge
		gauge_card_loc = $AllCards/OpponentGauge

	var pos = gauge_panel.get_center_pos()
	card.discard_to(pos, CardBase.CardState.CardState_InGauge)
	reparent_to_zone(card, gauge_card_loc)
	spawn_damage_popup("+ Gauge", player)
	return SmallNoticeDelay

func get_deck_zone(is_player : bool):
	if is_player:
		return $AllCards/PlayerDeck
	else:
		return $AllCards/OpponentDeck

func _on_add_to_deck(event):
	var is_player = event['event_player'] == game_logic.player
	var card = find_card_on_board(event['number'])
	card.flip_card_to_front(false)
	var deck_position = get_deck_button_position(is_player)
	card.discard_to(deck_position, CardBase.CardState.CardState_InDeck)
	reparent_to_zone(card, get_deck_zone(is_player))
	layout_player_hand(is_player)

func _on_draw_event(event):
	var player = event['event_player']
	var card_drawn_id = event['number']
	var is_player = player == game_logic.player
	draw_card(card_drawn_id, is_player)
	update_card_counts()
	#spawn_damage_popup("Draw", player)

func _on_exceed_event(event):
	var player = event['event_player']
	if player == game_logic.player:
		$PlayerCharacter.set_exceed(true)
		player_character_card.exceed(true)

	else:
		$OpponentCharacter.set_exceed(true)
		$OpponentCharacterCard.exceed(true)

	spawn_damage_popup("Exceed!", player)
	return SmallNoticeDelay

func _on_force_start_strike(event):
	var player = event['event_player']
	spawn_damage_popup("Strike!", player)
	if player == game_logic.player:
		begin_strike_choosing(false, false)
	else:
		ai_forced_strike()

func _on_force_wild_swing(event):
	var player = event['event_player']
	spawn_damage_popup("Wild Swing!", player)
	return SmallNoticeDelay

func _on_game_over(event):
	printlog("GAME OVER for %s" % event['event_player'].name)
	game_over_stuff.visible = true
	change_ui_state(UIState.UIState_GameOver, UISubState.UISubState_None)
	_update_buttons()
	if event['event_player'] == game_logic.player:
		game_over_label.text = "DEFEAT"
	else:
		game_over_label.text = "WIN!"

func _on_prepare(event):
	var player = event['event_player']
	spawn_damage_popup("Prepare!", player)
	return SmallNoticeDelay

func _on_change_cards(event):
	var player = event['event_player']
	spawn_damage_popup("Change Cards!", player)
	return SmallNoticeDelay

func _on_hand_size_exceeded(event):
	if game_logic.active_turn_player == game_logic.player:
		begin_discard_cards_selection(event['number'], UISubState.UISubState_SelectCards_DiscardCards)
	else:
		# AI or other player wait
		ai_discard(event)

func change_ui_state(new_state, new_sub_state = null):
	if ui_state == UIState.UIState_GameOver:
		return

	if new_state != null:
		printlog("UI: State change %s to %s" % [UIState.keys()[ui_state], UIState.keys()[new_state]])
		ui_state = new_state
	else:
		printlog("UI: State = %s" % UIState.keys()[ui_state])

	if new_sub_state != null:
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
	var player = event['event_player']
	var other_player = game_logic.other_player(player)
	var move_amount = event['extra_info']
	var destination = event['number']
	var move_anim = Character.CharacterAnim.CharacterAnim_WalkForward
	var original_position = event['extra_info2']
	var is_far = abs(original_position - destination) >= 2
	var is_forward = ((destination > original_position and other_player.arena_location > original_position)
		or (destination < original_position and other_player.arena_location < original_position))
	match event['reason']:
		"advance":
			spawn_damage_popup("Advance %s" % str(move_amount), player)
			move_anim = Character.CharacterAnim.CharacterAnim_WalkForward
			if is_far:
				move_anim = Character.CharacterAnim.CharacterAnim_Run
		"close":
			spawn_damage_popup("Close %s" % str(move_amount), player)
			move_anim = Character.CharacterAnim.CharacterAnim_WalkForward
			if is_far:
				move_anim = Character.CharacterAnim.CharacterAnim_Run
		"move":
			spawn_damage_popup("Move", player)
			if is_forward:
				move_anim = Character.CharacterAnim.CharacterAnim_WalkForward
				if is_far:
					move_anim = Character.CharacterAnim.CharacterAnim_Run
			else:
				move_anim = Character.CharacterAnim.CharacterAnim_WalkBackward
				if is_far:
					move_anim = Character.CharacterAnim.CharacterAnim_DashBack
		"push":
			spawn_damage_popup("Pushed %s" % str(move_amount), player)
			move_anim = Character.CharacterAnim.CharacterAnim_Pushed
		"pull":
			spawn_damage_popup("Pulled %s" % str(move_amount), player)
			move_anim = Character.CharacterAnim.CharacterAnim_Pulled
		"retreat":
			spawn_damage_popup("Retreat %s" % str(move_amount), player)
			move_anim = Character.CharacterAnim.CharacterAnim_WalkBackward
			if is_far:
				move_anim = Character.CharacterAnim.CharacterAnim_DashBack

	#spawn_damage_popup("Move", player)
	if player == game_logic.player:
		move_character_to_arena_square($PlayerCharacter, destination, false,  move_anim)
	else:
		move_character_to_arena_square($OpponentCharacter, destination, false, move_anim)
	return MoveDelay

func _on_mulligan_decision(event):
	if event['event_player'] == game_logic.player:
		selected_cards = []
		select_card_require_min = 1
		select_card_require_max = len(game_logic.player.hand)
		var can_cancel = true
		enable_instructions_ui("Select cards to mulligan.", true, can_cancel)
		change_ui_state(UIState.UIState_SelectCards, UISubState.UISubState_SelectCards_Mulligan)
	else:
		ai_mulligan_decision()

func _on_reshuffle_discard(event):
	var player = event['event_player']
	spawn_damage_popup("Reshuffle!", player)
	if player == game_logic.player:
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
			card.flip_card_to_front(false)
			card.position = OffScreen
			card.reset()
	close_popout()
	update_card_counts()
	return SmallNoticeDelay

func _on_reshuffle_deck_mulligan(_event):
	#printlog("UI: TODO: In place reshuffle deck. No cards actually move though.")
	pass

func _on_reveal_hand(event):
	var player = event['event_player']
	spawn_damage_popup("Hand Revealed!", player)
	if player == game_logic.opponent:
		var cards = $AllCards/OpponentHand.get_children()
		for card in cards:
			card.flip_card_to_front(true)
	else:
		# Nothing for AI here.
		pass
	return SmallNoticeDelay

func _move_card_to_strike_area(card, strike_area, new_parent, is_player : bool, is_ex : bool):
	if card.position == OffScreen:
		# Position it at the appropriate deck.
		card.position = get_deck_button_position(is_player)

	var pos = strike_area.global_position + strike_area.size * strike_area.scale /2
	if is_ex:
		pos.x += CardBase.DesiredCardSize.x
	card.discard_to(pos, CardBase.CardState.CardState_InStrike)
	card.get_parent().remove_child(card)
	new_parent.add_child(card)
	layout_player_hand(is_player)

func _on_strike_started(event, is_ex : bool):
	var card = find_card_on_board(event['number'])
	var reveal_immediately = event['event_type'] == game_logic.EventType.EventType_Strike_PayCost_Unable
	if reveal_immediately:
		card.flip_card_to_front(true)
	if event['event_player'] == game_logic.player:
		_move_card_to_strike_area(card, $PlayerStrike/StrikeZone, $AllCards/Striking, true, is_ex)
		if not is_ex and game_logic.game_state == game_logic.GameState.GameState_Strike_Opponent_Response:
			ai_strike_response()
	else:
		# Opponent started strike, player has to respond.
		_move_card_to_strike_area(card, $OpponentStrike/StrikeZone, $AllCards/Striking, false, is_ex)
		if not is_ex and game_logic.game_state == game_logic.GameState.GameState_Strike_Opponent_Response:
			begin_strike_choosing(true, false)

func _on_strike_reveal(_event):
	var strike_cards = $AllCards/Striking.get_children()
	for card in strike_cards:
		card.flip_card_to_front(true)
	return StrikeRevealDelay

func _on_strike_card_activation(event):
	var strike_cards = $AllCards/Striking.get_children()
	var card_id = event['number']
	for card in strike_cards:
		card.set_backlight_visible(card.card_id == card_id)
	return SmallNoticeDelay

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

func _on_pay_cost_failed(event):
	# Do the wild swing deal.
	return _on_strike_started(event, false)

func _on_force_for_armor(event):
	if event['event_player'] == game_logic.player:
		change_ui_state(null, UISubState.UISubState_SelectCards_ForceForArmor)
		begin_generate_force_selection(-1)
	else:
		ai_force_for_armor(event)

func _on_damage(event):
	var player = event['event_player']
	var damage_taken = event['number']
	if player == game_logic.player:
		$PlayerLife.set_life(game_logic.player.life)
		$PlayerCharacter.play_hit()
	else:
		$OpponentLife.set_life(game_logic.opponent.life)
		$OpponentCharacter.play_hit()
	spawn_damage_popup("%s Damage" % str(damage_taken), player)
	return SmallNoticeDelay

func _handle_events(events):
	var delay = 0
	for event_index in range(events.size()):
		var event = events[event_index]
		_log_event(event)
		match event['event_type']:
			game_logic.EventType.EventType_AddToGauge:
				delay = _on_add_to_gauge(event)
			game_logic.EventType.EventType_AddToDeck:
				_on_add_to_deck(event)
			game_logic.EventType.EventType_AddToDiscard:
				_on_discard_event(event)
			game_logic.EventType.EventType_AdvanceTurn:
				_on_advance_turn()
			game_logic.EventType.EventType_Boost_ActionAfterBoost:
				_on_post_boost_action(event)
			game_logic.EventType.EventType_Boost_CancelDecision:
				_on_boost_cancel_decision(event)
			game_logic.EventType.EventType_Boost_Canceled:
				delay = _on_boost_canceled(event)
			game_logic.EventType.EventType_Boost_Continuous_Added:
				delay = _on_continuous_boost_added(event)
			game_logic.EventType.EventType_Boost_DiscardContinuousChoice:
				_on_discard_continuous_boost_begin(event)
			game_logic.EventType.EventType_Boost_NameCardOpponentDiscards:
				_on_name_opponent_card_begin(event)
			game_logic.EventType.EventType_Boost_Played:
				delay = _on_boost_played(event)
			game_logic.EventType.EventType_CardFromHandToGauge_Choice:
				_on_choose_card_hand_to_gauge(event)
			game_logic.EventType.EventType_ChangeCards:
				delay = _on_change_cards(event)
			game_logic.EventType.EventType_Discard:
				_on_discard_event(event)
			game_logic.EventType.EventType_Draw:
				_on_draw_event(event)
			game_logic.EventType.EventType_Exceed:
				delay = _on_exceed_event(event)
			game_logic.EventType.EventType_ForceStartStrike:
				_on_force_start_strike(event)
			game_logic.EventType.EventType_Strike_ForceWildSwing:
				delay = _on_force_wild_swing(event)
			game_logic.EventType.EventType_GameOver:
				_on_game_over(event)
			game_logic.EventType.EventType_HandSizeExceeded:
				_on_hand_size_exceeded(event)
			game_logic.EventType.EventType_Move:
				delay = _on_move_event(event)
			game_logic.EventType.EventType_MulliganDecision:
				_on_mulligan_decision(event)
			game_logic.EventType.EventType_Prepare:
				delay = _on_prepare(event)
			game_logic.EventType.EventType_ReshuffleDiscard:
				delay = _on_reshuffle_discard(event)
			game_logic.EventType.EventType_ReshuffleDeck_Mulligan:
				_on_reshuffle_deck_mulligan(event)
			game_logic.EventType.EventType_RevealHand:
				delay = _on_reveal_hand(event)
			game_logic.EventType.EventType_Strike_ArmorUp:
				delay = _stat_notice_event(event)
			game_logic.EventType.EventType_Strike_CardActivation:
				delay = _on_strike_card_activation(event)
			game_logic.EventType.EventType_Strike_DodgeAttacks:
				delay = _stat_notice_event(event)
			game_logic.EventType.EventType_Strike_EffectChoice:
				_on_effect_choice(event)
			game_logic.EventType.EventType_Strike_ExUp:
				delay = _stat_notice_event(event)
			game_logic.EventType.EventType_Strike_ForceForArmor:
				_on_force_for_armor(event)
			game_logic.EventType.EventType_Strike_GainAdvantage:
				delay = _stat_notice_event(event)
			game_logic.EventType.EventType_Strike_GuardUp:
				delay = _stat_notice_event(event)
			game_logic.EventType.EventType_Strike_IgnoredPushPull:
				delay = _stat_notice_event(event)
			game_logic.EventType.EventType_Strike_Miss:
				delay = _stat_notice_event(event)
			game_logic.EventType.EventType_Strike_PayCost_Gauge:
				_on_pay_cost_gauge(event)
			game_logic.EventType.EventType_Strike_PayCost_Force:
				printlog("TODO: UI Pay force costs on card")
				assert(false)
			game_logic.EventType.EventType_Strike_PayCost_Unable:
				_on_pay_cost_failed(event)
			game_logic.EventType.EventType_Strike_PowerUp:
				delay = _stat_notice_event(event)
			game_logic.EventType.EventType_Strike_Response:
				_on_strike_started(event, false)
			game_logic.EventType.EventType_Strike_Response_Ex:
				_on_strike_started(event, true)
			game_logic.EventType.EventType_Strike_Reveal:
				delay = _on_strike_reveal(event)
			game_logic.EventType.EventType_Strike_Started:
				_on_strike_started(event, false)
			game_logic.EventType.EventType_Strike_Started_Ex:
				_on_strike_started(event, true)
			game_logic.EventType.EventType_Strike_Stun:
				delay = _on_stunned(event)
			game_logic.EventType.EventType_Strike_TookDamage:
				delay = _on_damage(event)
			game_logic.EventType.EventType_Strike_WildStrike:
				delay = _stat_notice_event(event)
			_:
				printlog("ERROR: UNHANDLED EVENT")
				assert(false)

		# If a UI animation needs to play or pause events,
		# break off the remaining events and handle them later.
		if delay != 0:
			var remaining_events = events.slice(event_index + 1)
			begin_delay(delay, remaining_events)
			break


func _update_buttons():
	# Update main action selection UI
	$StaticUI/StaticUIVBox/ButtonGrid/PrepareButton.disabled = not game_logic.can_do_prepare(game_logic.player)
	$StaticUI/StaticUIVBox/ButtonGrid/MoveButton.disabled = not game_logic.can_do_move(game_logic.player)
	$StaticUI/StaticUIVBox/ButtonGrid/ChangeButton.disabled = not game_logic.can_do_change(game_logic.player)
	$StaticUI/StaticUIVBox/ButtonGrid/ExceedButton.disabled = not game_logic.can_do_exceed(game_logic.player)
	$StaticUI/StaticUIVBox/ButtonGrid/ReshuffleButton.visible = game_logic.can_do_reshuffle(game_logic.player)
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
		UISubState.UISubState_SelectCards_BoostCancel, UISubState.UISubState_SelectCards_Mulligan:
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
			UISubState.UISubState_SelectCards_DiscardCardsToGauge, UISubState.UISubState_SelectCards_Mulligan:
				return selected_cards_between_min_and_max()
			UISubState.UISubState_SelectCards_MoveActionGenerateForce:
				var force_selected = get_force_in_selected_cards()
				return force_selected == select_card_require_force
			UISubState.UISubState_SelectCards_ForceForChange:
				var force_selected = get_force_in_selected_cards()
				return force_selected >= 0
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
		var selected_card_ids : Array[int] = []
		for card in selected_cards:
			selected_card_ids.append(card.card_id)
		var single_card_id = -1
		var ex_card_id = -1
		if len(selected_card_ids) == 1:
			single_card_id = selected_card_ids[0]
		if len(selected_card_ids) == 2:
			single_card_id = selected_card_ids[0]
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
			UISubState.UISubState_SelectCards_Mulligan:
				events = game_logic.do_mulligan(game_logic.player, selected_card_ids)
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
			deselect_all_cards()
			close_popout()
			var events = game_logic.do_force_for_armor(game_logic.player, [])
			_handle_events(events)
			return
		UISubState.UISubState_SelectCards_Mulligan:
			deselect_all_cards()
			close_popout()
			var events = game_logic.do_mulligan(game_logic.player, [])
			_handle_events(events)
			return

	if ui_state == UIState.UIState_SelectArenaLocation and instructions_cancel_allowed:
		change_ui_state(UIState.UIState_PickTurnAction, UISubState.UISubState_None)
	if ui_state == UIState.UIState_SelectCards and instructions_cancel_allowed:
		deselect_all_cards()
		close_popout()
		if ui_sub_state == UISubState.UISubState_SelectCards_BoostCancel:
			var events = game_logic.do_boost_cancel(game_logic.player, [], false)
			_handle_events(events)
		else:
			change_ui_state(UIState.UIState_PickTurnAction, UISubState.UISubState_None)

func _on_wild_swing_button_pressed():
	if ui_state == UIState.UIState_SelectCards:
		if ui_sub_state == UISubState.UISubState_SelectCards_StrikeCard or ui_sub_state == UISubState.UISubState_SelectCards_StrikeResponseCard:
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

func ai_handle_prepare(game : GameLogic, gameplayer : GameLogic.Player):
	var events = game.do_prepare(gameplayer)
	return events

func ai_handle_move(game: GameLogic, gameplayer : GameLogic.Player, action : AIPlayer.MoveAction):
	var events = []
	var location = action.location
	var card_ids = action.force_card_ids
	events += game.do_move(gameplayer, card_ids, location)
	return events

func ai_handle_change_cards(game: GameLogic, gameplayer : GameLogic.Player, action : AIPlayer.ChangeCardsAction):
	var events = []
	var card_ids = action.card_ids
	events += game.do_change(gameplayer, card_ids)
	return events

func ai_handle_exceed(game: GameLogic, gameplayer : GameLogic.Player, action : AIPlayer.ExceedAction):
	var events = []
	var card_ids = action.card_ids
	events += game.do_exceed(gameplayer, card_ids)
	return events

func ai_handle_reshuffle(game: GameLogic, gameplayer : GameLogic.Player):
	var events = []
	events += game.do_reshuffle(gameplayer)
	return events

func ai_handle_boost_reponse(_events, aiplayer : AIPlayer, game : GameLogic, gameplayer : GameLogic.Player, otherplayer : GameLogic.Player, choice_index):
	while game.game_state == GameLogic.GameState.GameState_PlayerDecision:
		if game.decision_type == GameLogic.DecisionType.DecisionType_EffectChoice:
			_events += game.do_choice(gameplayer, choice_index)
		elif game.decision_type == GameLogic.DecisionType.DecisionType_CardFromHandToGauge:
			_events += game.do_card_from_hand_to_gauge(gameplayer, gameplayer.hand[choice_index].id)
		elif game.decision_type == GameLogic.DecisionType.DecisionType_NameCard_OpponentDiscards:
			var index = choice_index * 2
			var card_id = otherplayer.deck_copy[index].id
			_events += game.do_boost_name_card_choice_effect(gameplayer, card_id)
			#TODO: Do something with EventType_RevealHand so AI can consume new info.
		elif game.decision_type == GameLogic.DecisionType.DecisionType_ChooseDiscardContinuousBoost:
			var card_id = otherplayer.continuous_boosts[choice_index].id
			_events += game.do_boost_name_card_choice_effect(gameplayer, card_id)
		elif game.decision_type == GameLogic.DecisionType.DecisionType_BoostCancel:
			var cost = game.decision_choice
			var cancel_action = aiplayer.pick_cancel(game, gameplayer, otherplayer, cost)
			_events += game.do_boost_cancel(gameplayer, cancel_action.card_ids, cancel_action.cancel)

func ai_handle_boost(game: GameLogic, _aiplayer : AIPlayer, gameplayer : GameLogic.Player, _otherplayer : GameLogic.Player, action : AIPlayer.BoostAction):
	var events = []
	var card_id = action.card_id
	#var boost_choice_index = action.boost_choice_index
	events += game.do_boost(gameplayer, card_id)
	#TODO: Should this be grouped somehow? Save the choice from the original decision instead of asking again?
	#ai_handle_boost_reponse(events, aiplayer, game, gameplayer, otherplayer, boost_choice_index)
	return events

func ai_handle_strike(game: GameLogic, gameplayer : GameLogic.Player, action : AIPlayer.StrikeAction):
	var events = []
	var card_id = action.card_id
	var ex_card_id = action.ex_card_id
	var wild_swing = action.wild_swing
	events += game.do_strike(gameplayer, card_id, wild_swing, ex_card_id)
	return events

func ai_take_turn():
	var events = []
	var turn_action = ai_player.take_turn(game_logic, game_logic.opponent, game_logic.player)
	if turn_action is AIPlayer.PrepareAction:
		events += ai_handle_prepare(game_logic, game_logic.opponent)
	elif turn_action is AIPlayer.MoveAction:
		events += ai_handle_move(game_logic, game_logic.opponent, turn_action)
	elif turn_action is AIPlayer.ChangeCardsAction:
		events += ai_handle_change_cards(game_logic, game_logic.opponent, turn_action)
	elif turn_action is AIPlayer.ExceedAction:
		events += ai_handle_exceed(game_logic, game_logic.opponent, turn_action)
	elif turn_action is AIPlayer.ReshuffleAction:
		events += ai_handle_reshuffle(game_logic, game_logic.opponent)
	elif turn_action is AIPlayer.BoostAction:
		events += ai_handle_boost(game_logic, ai_player, game_logic.opponent, game_logic.player, turn_action)
	elif turn_action is AIPlayer.StrikeAction:
		events += ai_handle_strike(game_logic, game_logic.opponent, turn_action)
	else:
		assert(false, "Unknown turn action: %s" % turn_action)

	_handle_events(events)

func ai_pay_cost(event):
	var events = []
	var can_wild = game_logic.decision_type == GameLogic.DecisionType.DecisionType_PayStrikeCost_CanWild
	var cost = game_logic.get_card_gauge_cost(event['number'])
	var pay_action = ai_player.pay_strike_gauge_cost(game_logic, game_logic.opponent, game_logic.player, cost, can_wild)
	events += game_logic.do_pay_strike_cost(game_logic.decision_player, pay_action.card_ids, pay_action.wild_swing)
	_handle_events(events)

func ai_effect_choice(_event):
	var effect_action = ai_player.pick_effect_choice(game_logic, game_logic.opponent, game_logic.player)
	var events = game_logic.do_choice(game_logic.opponent, effect_action.choice)
	_handle_events(events)

func ai_force_for_armor(_event):
	var forceforarmor_action = ai_player.pick_force_for_armor(game_logic, game_logic.opponent, game_logic.player)
	var events = game_logic.do_force_for_armor(game_logic.opponent, forceforarmor_action.card_ids)
	_handle_events(events)

func ai_strike_response():
	var response_action = ai_player.pick_strike_response(game_logic, game_logic.opponent, game_logic.player)
	var events = game_logic.do_strike(game_logic.opponent, response_action.card_id, response_action.wild_swing, response_action.ex_card_id)
	_handle_events(events)

func ai_discard(event):
	var discard_action = ai_player.pick_discard_to_max(game_logic, game_logic.opponent, game_logic.player, event['number'])
	var events = game_logic.do_discard_to_max(game_logic.opponent, discard_action.card_ids)
	_handle_events(events)

func ai_forced_strike():
	var strike_action = ai_player.pick_strike(game_logic, game_logic.opponent, game_logic.player)
	var events = ai_handle_strike(game_logic, game_logic.opponent, strike_action)
	_handle_events(events)

func ai_boost_cancel_decision(gauge_cost):
	var cancel_action = ai_player.pick_cancel(game_logic, game_logic.opponent, game_logic.player, gauge_cost)
	var events = game_logic.do_boost_cancel(game_logic.opponent, cancel_action.card_ids, cancel_action.cancel)
	_handle_events(events)

func ai_discard_continuous_boost():
	var pick_action = ai_player.pick_discard_continuous(game_logic, game_logic.opponent, game_logic.player)
	var events = game_logic.do_boost_name_card_choice_effect(game_logic.opponent, pick_action.card_id)
	_handle_events(events)

func ai_name_opponent_card():
	var pick_action = ai_player.pick_name_opponent_card(game_logic, game_logic.opponent, game_logic.player)
	var events = game_logic.do_boost_name_card_choice_effect(game_logic.opponent, pick_action.card_id)
	_handle_events(events)

func ai_choose_card_hand_to_gauge():
	var cardfromhandtogauge_action = ai_player.pick_card_hand_to_gauge(game_logic, game_logic.opponent, game_logic.player)
	var events = game_logic.do_card_from_hand_to_gauge(game_logic.opponent, cardfromhandtogauge_action.card_id)
	_handle_events(events)

func ai_mulligan_decision():
	var mulligan_action = ai_player.pick_mulligan(game_logic, game_logic.opponent, game_logic.player)
	var events = game_logic.do_mulligan(game_logic.opponent, mulligan_action.card_ids)
	_handle_events(events)

# Popout Functions
func card_in_selected_cards(card):
	for selected_card in selected_cards:
		if selected_card.card_id == card.card_id:
			return true
	return false

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
	pos.x += CardBase.DesiredCardSize.x / 2
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

func _on_exit_to_menu_pressed():
	queue_free()
