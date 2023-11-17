extends Node2D

signal returning_from_game

const UseHugeCard = false

const Test_StartWithGauge = false

const CardBaseScene = preload("res://scenes/card/card_base.tscn")
const CardBase = preload("res://scenes/card/card_base.gd")
const Enums = preload("res://scenes/game/enums.gd")
const CardPopout = preload("res://scenes/game/card_popout.gd")
const GaugePanel = preload("res://scenes/game/gauge_panel.gd")
const CharacterCardBase = preload("res://scenes/card/character_card_base.gd")
const AIPlayer = preload("res://scenes/game/ai_player.gd")
const DamagePopup = preload("res://scenes/game/damage_popup.gd")
const Character = preload("res://scenes/game/character.gd")
const GameWrapper = preload("res://scenes/game/game_wrapper.gd")
const GameCard = preload("res://scenes/game/game_card.gd")
const DecisionInfo = preload("res://scenes/game/decision_info.gd")
const ActionMenu = preload("res://scenes/game/action_menu.gd")

@onready var damage_popup_template = preload("res://scenes/game/damage_popup.tscn")
@onready var arena_layout = $ArenaNode/RowButtons

@onready var huge_card : Sprite2D = $HugeCard

const OffScreen = Vector2(-1000, -1000)
const RevealCopyIdRangestart = 80000
const ReferenceScreenIdRangeStart = 90000
const NoticeOffsetY = 50

const StrikeRevealDelay : float = 2.0
const MoveDelay : float = 1.0
const BoostDelay : float = 2.0
const SmallNoticeDelay : float = 1.0
var remaining_delay = 0
var events_to_process = []

var damage_popup_pool:Array[DamagePopup] = []

var insert_ai_pause = false
var popout_instruction_info = null

var PlayerHandFocusYPos = 720 - (CardBase.get_hand_card_size().y + 20)
var OpponentHandFocusYPos = CardBase.get_opponent_hand_card_size().y

var first_run_done = false
var select_card_require_min = 0
var select_card_require_max = 0
var select_card_require_force = 0
var select_card_up_to_force = 0
var instructions_ok_allowed = false
var instructions_cancel_allowed = false
var instructions_wild_swing_allowed = false
var selected_cards = []
var arena_locations_clickable = []
var selected_arena_location = 0
var force_for_armor_incoming_damage = 0

var player_deck
var opponent_deck

enum CardPopoutType {
	CardPopoutType_GaugePlayer,
	CardPopoutType_GaugeOpponent,
	CardPopoutType_DiscardPlayer,
	CardPopoutType_DiscardOpponent,
	CardPopoutType_BoostPlayer,
	CardPopoutType_BoostOpponent,
	CardPopoutType_ReferencePlayer,
	CardPopoutType_ReferenceOpponent,
	CardPopoutType_RevealedOpponent,
}

var popout_type_showing : CardPopoutType = CardPopoutType.CardPopoutType_GaugePlayer

enum UIState {
	UIState_Initializing,
	UIState_GameOver,
	UIState_PickTurnAction,
	UIState_MakeChoice,
	UIState_SelectCards,
	UIState_SelectArenaLocation, # 5
	UIState_WaitingOnOpponent,
	UIState_PlayingAnimation,
	UIState_WaitForGameServer,
}

enum UISubState {
	UISubState_None,
	UISubState_SelectCards_BoostCancel,
	UISubState_SelectCards_CharacterAction_Force,
	UISubState_SelectCards_CharacterAction_Gauge,
	UISubState_SelectCards_ChooseDiscardToDestination,
	UISubState_SelectCards_DiscardContinuousBoost,
	UISubState_SelectCards_DiscardFromReference,
	UISubState_SelectCards_MoveActionGenerateForce,
	UISubState_SelectCards_PlayBoost,
	UISubState_SelectCards_DiscardCards,
	UISubState_SelectCards_DiscardCards_Choose,
	UISubState_SelectCards_DiscardCardsToGauge,
	UISubState_SelectCards_ForceForChange,
	UISubState_SelectCards_Exceed, # 13
	UISubState_SelectCards_Mulligan,
	UISubState_SelectCards_StrikeGauge,
	UISubState_SelectCards_StrikeCard,
	UISubState_SelectCards_StrikeResponseCard,
	UISubState_SelectCards_ForceForArmor,
	UISubState_SelectCards_ForceForEffect,
	UISubState_SelectArena_MoveResponse,
}

var ui_state : UIState = UIState.UIState_Initializing
var ui_sub_state : UISubState = UISubState.UISubState_None

var previous_ui_state : UIState = UIState.UIState_Initializing
var previous_ui_sub_state : UISubState = UISubState.UISubState_None

var game_wrapper : GameWrapper = GameWrapper.new()
@onready var card_popout : CardPopout = $AllCards/CardPopout
@onready var player_character_card : CharacterCardBase  = $PlayerDeck/PlayerCharacterCard
@onready var opponent_character_card : CharacterCardBase  = $OpponentDeck/OpponentCharacterCard
@onready var game_over_stuff = $GameOverStuff
@onready var game_over_label = $GameOverStuff/GameOverLabel
@onready var ai_player : AIPlayer = $AIPlayer
@onready var opponent_name_label : Label = $OpponentDeck/OpponentName
@onready var player_bonus_panel = $PlayerStrike/CharBonusPanel
@onready var opponent_bonus_panel = $OpponentStrike/CharBonusPanel
@onready var player_bonus_label = $PlayerStrike/CharBonusPanel/MarginContainer/VBox/AbilityLabel
@onready var opponent_bonus_label = $OpponentStrike/CharBonusPanel/MarginContainer/VBox/AbilityLabel
@onready var action_menu : ActionMenu = $AllCards/ActionMenu
var current_instruction_text : String = ""
var current_action_menu_choices : Array = []
var current_effect_choices : Array = []
var show_thinking_spinner_in : float = 0
const ThinkingSpinnerWaitBeforeShowTime = 1.0

@onready var CenterCardOval = Vector2(get_viewport().content_scale_size) * Vector2(0.5, 1.35)
@onready var HorizontalRadius = get_viewport().content_scale_size.x * 0.55
@onready var VerticalRadius = get_viewport().content_scale_size.y * 0.4

func printlog(text):
	if GlobalSettings.is_logging_enabled():
		print("UI: %s" % text)

# Called when the node enters the scene tree for the first time.
func _ready():
	if player_deck == null:
		# Started this scene directly.
		var vs_info = {
			'player_deck': CardDefinitions.get_deck_test_deck(),
			'opponent_deck': CardDefinitions.get_deck_test_deck(),
		}
		begin_local_game(vs_info)

	if not game_wrapper.is_ai_game():
		$AIMoveButton.visible = false

	$PlayerLife.set_life(game_wrapper.get_player_life(Enums.PlayerId.PlayerId_Player))
	$OpponentLife.set_life(game_wrapper.get_player_life(Enums.PlayerId.PlayerId_Opponent))
	game_over_stuff.visible = false

	player_bonus_panel.visible = false
	opponent_bonus_panel.visible = false

	setup_characters()

func begin_local_game(vs_info):
	player_deck = vs_info['player_deck']
	opponent_deck = vs_info['opponent_deck']
	game_wrapper.initialize_local_game(player_deck, opponent_deck)

func begin_remote_game(game_start_message):
	var player1_info = {
		'name': game_start_message['player1_name'],
		'id': game_start_message['player1_id'],
		'deck_id': game_start_message['player1_deck_id'],
		'deck': CardDefinitions.get_deck_from_str_id(game_start_message['player1_deck_id']),
	}
	var player2_info = {
		'name': game_start_message['player2_name'],
		'id': game_start_message['player2_id'],
		'deck_id': game_start_message['player2_deck_id'],
		'deck': CardDefinitions.get_deck_from_str_id(game_start_message['player2_deck_id']),
	}
	var seed_value = game_start_message['seed_value']
	var starting_player = Enums.PlayerId.PlayerId_Player
	var my_player_info
	var opponent_player_info
	if game_start_message['your_player_id'] == game_start_message['player1_id']:
		my_player_info = player1_info
		player_deck = player1_info['deck']
		opponent_player_info = player2_info
		opponent_deck = player2_info['deck']
		if game_start_message['starting_player_id'] == game_start_message['player2_id']:
			starting_player = Enums.PlayerId.PlayerId_Opponent
	else:
		my_player_info = player2_info
		player_deck = player2_info['deck']
		opponent_player_info = player1_info
		opponent_deck = player1_info['deck']
		if game_start_message['starting_player_id'] == game_start_message['player1_id']:
			starting_player = Enums.PlayerId.PlayerId_Opponent

	game_wrapper.initialize_remote_game(my_player_info, opponent_player_info, starting_player, seed_value)

func setup_characters():
	$PlayerCharacter.load_character(player_deck['id'])
	$OpponentCharacter.load_character(opponent_deck['id'])
	if player_deck['id'] == opponent_deck['id']:
		$OpponentCharacter.modulate = Color(1, 0.38, 0.55)
	setup_character_card(player_character_card, player_deck)
	setup_character_card(opponent_character_card, opponent_deck)

func setup_character_card(character_card, deck):
	character_card.set_name_text(deck['display_name'])
	var character_default_path = "res://assets/cards/" + deck['id'] + "/character_default.jpg"
	var character_exceeded_path = "res://assets/cards/" + deck['id'] + "/character_exceeded.jpg"
	character_card.set_image(character_default_path, character_exceeded_path)
	var on_exceed_text = ""
	if 'on_exceed' in deck:
		on_exceed_text = CardDefinitions.get_on_exceed_text(deck['on_exceed'])
	var effect_text = on_exceed_text + CardDefinitions.get_effects_text(deck['ability_effects'])
	var exceed_text = CardDefinitions.get_effects_text(deck['exceed_ability_effects'])
	character_card.set_effect(effect_text, exceed_text)
	character_card.set_cost(deck['exceed_cost'])

func finish_initialization():
	opponent_name_label.text = game_wrapper.get_player_name(Enums.PlayerId.PlayerId_Opponent)
	spawn_all_cards()

func test_init():
	if Test_StartWithGauge:
		game_wrapper._test_add_to_gauge(4)
		var events = game_wrapper.poll_for_events()
		_handle_events(events)
		layout_player_hand(true)
		_update_buttons()

func first_run():
	move_character_to_arena_square($PlayerCharacter, game_wrapper.get_player_location(Enums.PlayerId.PlayerId_Player), true, Character.CharacterAnim.CharacterAnim_None)
	move_character_to_arena_square($OpponentCharacter, game_wrapper.get_player_location(Enums.PlayerId.PlayerId_Opponent), true, Character.CharacterAnim.CharacterAnim_None)
	_update_buttons()

	finish_initialization()
	change_ui_state(UIState.UIState_WaitForGameServer)

func create_character_reference_card(path_root : String, exceeded : bool, zone):
	var image_path = path_root + "character_default.jpg"
	if exceeded:
		image_path = path_root + "character_exceeded.jpg"

	var new_card : CardBase = CardBaseScene.instantiate()
	zone.add_child(new_card)
	new_card.initialize_card(
		CardBase.CharacterCardReferenceId,
		"",
		image_path,
		image_path,
		0,
		0,
		0,
		0,
		0,
		0,
		"",
		0,
		"",
		0,
		-1,
		0,
		false
	)
	new_card.name = "Character Card"
	new_card.raised_card.connect(on_card_raised)
	new_card.lowered_card.connect(on_card_lowered)

	new_card.set_card_and_focus(OffScreen, 0, CardBase.ReferenceCardScale)
	new_card.resting_scale = CardBase.ReferenceCardScale
	new_card.change_state(CardBase.CardState.CardState_Offscreen)
	new_card.flip_card_to_front(true)

func spawn_deck(deck_id, deck_list, deck_card_zone, copy_zone, card_back_image, hand_focus_y_pos, is_opponent):
	var card_db = game_wrapper.get_card_database()
	var card_root_path = "res://assets/cards/" + deck_id + "/"
	for card in deck_list:
		var logic_card : GameCard = card_db.get_card(card.id)
		var image_path = card_root_path + logic_card.image
		var new_card = create_card(card.id, logic_card.definition, image_path, card_back_image, deck_card_zone, hand_focus_y_pos, is_opponent)
		new_card.set_card_and_focus(OffScreen, 0, null)

	create_character_reference_card(card_root_path, false, copy_zone)
	create_character_reference_card(card_root_path, true, copy_zone)

	var previous_def_id = ""
	for card in deck_list:
		var logic_card : GameCard = card_db.get_card(card.id)
		var image_path = card_root_path + logic_card.image
		if previous_def_id != logic_card.definition['id']:
			var copy_card = create_card(card.id + ReferenceScreenIdRangeStart, logic_card.definition, image_path, card_back_image, copy_zone, 0, is_opponent)
			copy_card.set_card_and_focus(OffScreen, 0, CardBase.ReferenceCardScale)
			copy_card.resting_scale = CardBase.ReferenceCardScale
			copy_card.change_state(CardBase.CardState.CardState_Offscreen)
			copy_card.flip_card_to_front(true)
			previous_def_id = card.definition['id']

func spawn_damage_popup(value:String, notice_player : Enums.PlayerId):
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
	var player_deck_id = player_deck['id']
	var opponent_deck_id = opponent_deck['id']
	var player_cardback = "res://assets/cardbacks/" + player_deck['cardback']
	var opponent_cardback = "res://assets/cardbacks/" + opponent_deck['cardback']

	spawn_deck(player_deck_id, game_wrapper.get_player_deck_list(Enums.PlayerId.PlayerId_Player), $AllCards/PlayerDeck, $AllCards/PlayerAllCopy, player_cardback, PlayerHandFocusYPos, false)
	spawn_deck(opponent_deck_id, game_wrapper.get_player_deck_list(Enums.PlayerId.PlayerId_Opponent), $AllCards/OpponentDeck, $AllCards/OpponentAllCopy, opponent_cardback, OpponentHandFocusYPos, true)

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
				change_ui_state(previous_ui_state, previous_ui_sub_state)
	else:
		var events = game_wrapper.poll_for_events()
		if events.size() > 0:
			_handle_events(events)
			$CombatLog.set_text(game_wrapper.get_combat_log())
		elif ui_state == UIState.UIState_WaitingOnOpponent:
			# Advance the AI game automatically.
			_on_ai_move_button_pressed()
		elif ui_state == UIState.UIState_WaitForGameServer:
			if game_wrapper.get_game_state() == Enums.GameState.GameState_Strike_Opponent_Response:
				if game_wrapper.get_active_player() == Enums.PlayerId.PlayerId_Opponent:
					# Our turn to respond.
					begin_strike_choosing(true, false)
				else:
					ai_strike_response()

	# Update opponent thinking spinner
	if ui_state == UIState.UIState_WaitingOnOpponent or ui_state == UIState.UIState_WaitForGameServer:
		if not $OpponentDeck/ThinkingIndicator.visible and show_thinking_spinner_in < 0:
			# Start the countdown
			show_thinking_spinner_in = ThinkingSpinnerWaitBeforeShowTime
		else:
			show_thinking_spinner_in -= delta
			if show_thinking_spinner_in < 0:
				$OpponentDeck/ThinkingIndicator.visible = true
				$OpponentDeck/ThinkingIndicator.radial_initial_angle += delta * 360
	else:
		$OpponentDeck/ThinkingIndicator.visible = false

func begin_delay(delay : float, remaining_events : Array):
	if ui_state != UIState.UIState_PlayingAnimation:
		previous_ui_state = ui_state
		previous_ui_sub_state = ui_sub_state
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
	card.set_card_and_focus(get_deck_button_position(is_player), null, null)

	layout_player_hand(is_player)

func update_card_counts():
	$OpponentHand/OpponentHandBox/OpponentNumCards.text = str(game_wrapper.get_player_hand_size(Enums.PlayerId.PlayerId_Opponent))

	$PlayerLife.set_deck_size(game_wrapper.get_player_deck_size(Enums.PlayerId.PlayerId_Player))
	$OpponentLife.set_deck_size(game_wrapper.get_player_deck_size(Enums.PlayerId.PlayerId_Opponent))

	$PlayerLife.set_discard_size(game_wrapper.get_player_discards_size(Enums.PlayerId.PlayerId_Player), game_wrapper.get_player_reshuffle_remaining(Enums.PlayerId.PlayerId_Player))
	$OpponentLife.set_discard_size(game_wrapper.get_player_discards_size(Enums.PlayerId.PlayerId_Opponent), game_wrapper.get_player_reshuffle_remaining(Enums.PlayerId.PlayerId_Opponent))

	$PlayerGauge.set_details($AllCards/PlayerGauge.get_child_count())
	$OpponentGauge.set_details($AllCards/OpponentGauge.get_child_count())

func get_card_node_name(id):
	return "Card_" + str(id)

func create_card(id, card_def, image, card_back_image, parent, hand_focus_y_pos, is_opponent : bool) -> CardBase:
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
		hand_focus_y_pos,
		is_opponent
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
		if UseHugeCard:
			huge_card.visible = true
			huge_card.texture = card.fancy_card.texture
		card.saved_hand_index = card.get_index()

		# Move card to the end of the children list.
		parent.move_child(card, parent.get_child_count() - 1)

func on_card_lowered(card):
	if UseHugeCard:
		huge_card.visible = false
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
	var in_gauge = game_wrapper.is_card_in_gauge(Enums.PlayerId.PlayerId_Player, card.card_id)
	var in_hand = game_wrapper.is_card_in_hand(Enums.PlayerId.PlayerId_Player, card.card_id)
	var in_discard = game_wrapper.is_card_in_discards(Enums.PlayerId.PlayerId_Player, card.card_id)
	var in_opponent_boosts = game_wrapper.is_card_in_boosts(Enums.PlayerId.PlayerId_Opponent, card.card_id)
	var in_opponent_reference = is_card_in_player_reference($AllCards/OpponentAllCopy.get_children(), card.card_id)
	match ui_sub_state:
		UISubState.UISubState_SelectCards_DiscardCards, UISubState.UISubState_SelectCards_DiscardCardsToGauge, UISubState.UISubState_SelectCards_DiscardCards_Choose:
			return in_hand and len(selected_cards) < select_card_require_max
		UISubState.UISubState_SelectCards_StrikeGauge, UISubState.UISubState_SelectCards_Exceed, UISubState.UISubState_SelectCards_BoostCancel:
			return in_gauge and len(selected_cards) < select_card_require_max
		UISubState.UISubState_SelectCards_MoveActionGenerateForce, UISubState.UISubState_SelectCards_ForceForChange, UISubState.UISubState_SelectCards_ForceForArmor:
			return in_gauge or in_hand
		UISubState.UISubState_SelectCards_CharacterAction_Force:
			var new_force = game_wrapper.get_card_database().get_card_force_value(card.card_id)
			return (in_gauge or in_hand) and can_selected_cards_pay_force(select_card_require_force, new_force)
		UISubState.UISubState_SelectCards_CharacterAction_Gauge:
			return in_gauge and len(selected_cards) < select_card_require_max
		UISubState.UISubState_SelectCards_ForceForEffect:
			var force_selected = get_force_in_selected_cards()
			var new_force = game_wrapper.get_card_database().get_card_force_value(card.card_id)
			var total_force = force_selected + new_force
			return (in_gauge or in_hand) and (total_force <= select_card_up_to_force or can_selected_cards_pay_force(select_card_up_to_force, new_force))
		UISubState.UISubState_SelectCards_StrikeCard, UISubState.UISubState_SelectCards_StrikeResponseCard, UISubState.UISubState_SelectCards_Mulligan:
			return in_hand
		UISubState.UISubState_SelectCards_PlayBoost:
			return len(selected_cards) == 0 and in_hand and game_wrapper.can_player_boost(Enums.PlayerId.PlayerId_Player, card.card_id)
		UISubState.UISubState_SelectCards_DiscardContinuousBoost:
			return in_opponent_boosts and len(selected_cards) < select_card_require_max
		UISubState.UISubState_SelectCards_DiscardFromReference:
			return in_opponent_reference and len(selected_cards) < select_card_require_max
		UISubState.UISubState_SelectCards_ChooseDiscardToDestination:
			var card_db = game_wrapper.get_card_database()
			var card_type = card_db.get_card(card.card_id).definition['type']
			var limitation = game_wrapper.get_decision_info().limitation
			var meets_limitation = false
			match limitation:
				"special":
					meets_limitation = card_type == "special"
				_:
					meets_limitation = true
			return in_discard and len(selected_cards) < select_card_require_max and meets_limitation

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
	if num_cards > 0:
		if is_player:
			if num_cards == 1:
				var card : CardBase = hand_zone.get_child(0)
				var angle = deg_to_rad(90)
				var ovalAngleVector = Vector2(HorizontalRadius * cos(angle), -VerticalRadius * sin(angle))
				var dst_pos = CenterCardOval + ovalAngleVector
				card.set_resting_position(dst_pos, 0)
			else:
				var min_angle = deg_to_rad(60)
				var max_angle = deg_to_rad(120)
				var max_angle_diff = deg_to_rad(10)

				var angle_diff = (max_angle - min_angle) / (num_cards - 1)
				if angle_diff > max_angle_diff:
					angle_diff = max_angle_diff
					var total_angle = min_angle + angle_diff * (num_cards - 1)
					var extra_angle = (max_angle - total_angle) / 2
					min_angle += extra_angle
					max_angle -= extra_angle

				# Force lower all the cards so we don't get any weirdness when they reposition
				var cards = []
				for card in hand_zone.get_children():
					cards.append(card)
				for card in cards:
					on_card_lowered(card)

				for i in range(num_cards):
					var card : CardBase = hand_zone.get_child(num_cards - i - 1)

					# Calculate the angle for this card, distributing the cards evenly between min_angle and max_angle
					var angle = min_angle + i * (max_angle - min_angle) / (num_cards - 1)

					var ovalAngleVector = Vector2(HorizontalRadius * cos(angle), -VerticalRadius * sin(angle))
					var dst_pos = CenterCardOval + ovalAngleVector # - size/2
					var dst_rot = (90 - rad_to_deg(angle)) / 4
					card.change_state(CardBase.CardState.CardState_InHand)
					card.set_resting_position(dst_pos, dst_rot)
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
				step = min(step, CardBase.get_opponent_hand_card_size().x / 1.5)
				var new_diff = step * (num_cards - 1)
				max_x = hand_center.x + new_diff / 2
				min_x = hand_center.x - new_diff / 2
				# Shuffle children in hand_zone
				var children = hand_zone.get_children()
				for child in children:
					hand_zone.move_child(child, randi() % num_cards)

				for i in range(num_cards):
					var pos = Vector2(min_x + step * i, hand_center.y)
					var card : CardBase = hand_zone.get_child(i)
					card.change_state(CardBase.CardState.CardState_InHand)
					card.set_resting_position(pos, 0)

	update_card_counts()

func _log_event(event):
	var num = event['number']
	var card_db = game_wrapper.get_card_database()
	var card_name = card_db.get_card_id(num)
	printlog("Event %s num=%s (card=%s)" % [Enums.EventType.keys()[event['event_type']], event['number'], card_name])

func get_notice_position(notice_player : Enums.PlayerId):
	if notice_player == Enums.PlayerId.PlayerId_Player:
		return $PlayerCharacter.position
	else:
		return $OpponentCharacter.position

func _stat_notice_event(event):
	var player = event['event_player']
	var number = event['number']
	var notice_text = ""
	match event['event_type']:
		Enums.EventType.EventType_Strike_ArmorUp:
			notice_text = "+%d Armor" % number
		Enums.EventType.EventType_CharacterAction:
			notice_text = "Character Action"
		Enums.EventType.EventType_Strike_DodgeAttacks:
			notice_text = "Dodge Attacks!"
		Enums.EventType.EventType_Strike_DodgeAttacksAtRange:
			notice_text = "Dodge at range %s-%s" % [number, event['extra_info']]
		Enums.EventType.EventType_Strike_ExUp:
			notice_text = "EX Strike!"
		Enums.EventType.EventType_Strike_GainAdvantage:
			notice_text = "+Advantage!"
		Enums.EventType.EventType_Strike_GuardUp:
			notice_text = "+%d Guard" % number
		Enums.EventType.EventType_Strike_IgnoredPushPull:
			notice_text = "Unmoved!"
		Enums.EventType.EventType_Strike_Miss:
			notice_text = "Miss!"
		Enums.EventType.EventType_Strike_PowerUp:
			notice_text = "+%d Power" % number
		Enums.EventType.EventType_Strike_RangeUp:
			var number2 = event['extra_info']
			notice_text = "+%d-%d Range" % [number, number2]
		Enums.EventType.EventType_Strike_SpeedUp:
			var text = ""
			if number > 0:
				text += "+"
			else:
				text += "-"
			text += "%d Speed" % number
			notice_text = text
		Enums.EventType.EventType_Strike_Stun:
			notice_text = "Stunned!"
		Enums.EventType.EventType_Strike_Stun_Immunity:
			notice_text = "Stun Immune!"
		Enums.EventType.EventType_Strike_WildStrike:
			notice_text = "Wild Swing!"

	spawn_damage_popup(notice_text, player)
	return SmallNoticeDelay

func _on_stunned(event):
	var card = find_card_on_board(event['number'])
	var player = event['event_player']
	var is_player = player == Enums.PlayerId.PlayerId_Player
	card.set_stun(true)
	if is_player:
		$PlayerCharacter.play_stunned()
	else:
		$OpponentCharacter.play_stunned()
	return _stat_notice_event(event)

func _on_advance_turn():
	var active_player : Enums.PlayerId = game_wrapper.get_active_player()
	var is_local_player_active = active_player == Enums.PlayerId.PlayerId_Player
	$PlayerLife.set_turn_indicator(is_local_player_active)
	$OpponentLife.set_turn_indicator(not is_local_player_active)

	player_bonus_panel.visible = false
	opponent_bonus_panel.visible = false

	if is_local_player_active:
		change_ui_state(UIState.UIState_PickTurnAction, UISubState.UISubState_None)
	else:
		change_ui_state(UIState.UIState_WaitingOnOpponent, UISubState.UISubState_None)

	clear_selected_cards()
	close_popout()
	for zone in $AllCards.get_children():
		if zone is Node2D:
			for card in zone.get_children():
				card.set_backlight_visible(false)
				card.set_stun(false)

	spawn_damage_popup("Ready!", active_player)
	return SmallNoticeDelay

func _on_post_boost_action(event):
	var player = event['event_player']
	spawn_damage_popup("Bonus Action", player)
	if player == Enums.PlayerId.PlayerId_Player:
		change_ui_state(UIState.UIState_PickTurnAction, UISubState.UISubState_None)
		clear_selected_cards()
		close_popout()
	else:
		ai_take_turn()
	return SmallNoticeDelay

func _on_boost_cancel_decision(event):
	var player = event['event_player']
	var gauge_cost = event['number']
	spawn_damage_popup("Cancel?", player)
	if player == Enums.PlayerId.PlayerId_Player:
		begin_gauge_selection(gauge_cost, false, UISubState.UISubState_SelectCards_BoostCancel)
	else:
		ai_boost_cancel_decision(gauge_cost)
	return SmallNoticeDelay

func _on_boost_canceled(event):
	var player = event['event_player']
	spawn_damage_popup("Cancel!", player)
	return SmallNoticeDelay

func _on_continuous_boost_added(event):
	var player = event['event_player']
	var card = find_card_on_board(event['number'])
	var boost_zone = $PlayerBoostZone
	var boost_card_loc = $AllCards/PlayerBoosts

	if player == Enums.PlayerId.PlayerId_Opponent:
		boost_zone = $OpponentBoostZone
		boost_card_loc = $AllCards/OpponentBoosts

	var pos = get_boost_zone_center(boost_zone)
	card.discard_to(pos, CardBase.CardState.CardState_InBoost)
	reparent_to_zone(card, boost_card_loc)
	spawn_damage_popup("+ Continuous Boost", player)
	return SmallNoticeDelay

func _on_discard_continuous_boost_begin(event):
	var player = event['event_player']
	if player == Enums.PlayerId.PlayerId_Player:
		# Show the boost window.
		_on_opponent_boost_zone_clicked_zone()
		selected_cards = []
		select_card_require_min = 1
		select_card_require_max = 1
		var cancel_allowed = false
		popout_instruction_info = {
			"popout_type": CardPopoutType.CardPopoutType_BoostOpponent,
			"instruction_text": "Discard a continuous boost.",
			"ok_text": "OK",
			"cancel_text": "",
			"ok_enabled": true,
			"cancel_visible": false,
		}
		enable_instructions_ui("Select a continuous boost do discard.", true, cancel_allowed, false)

		change_ui_state(UIState.UIState_SelectCards, UISubState.UISubState_SelectCards_DiscardContinuousBoost)
	else:
		ai_discard_continuous_boost()

func _on_name_opponent_card_begin(event):
	var player = event['event_player']
	spawn_damage_popup("Naming Card", player)
	var normal_only = event['event_type'] == Enums.EventType.EventType_ReadingNormal
	if player == Enums.PlayerId.PlayerId_Player:
		# Show the boost window.
		_on_opponent_reference_button_pressed()
		selected_cards = []
		select_card_require_min = 1
		select_card_require_max = 1
		var cancel_allowed = false
		popout_instruction_info = {
			"popout_type": CardPopoutType.CardPopoutType_ReferenceOpponent,
			"instruction_text": "Name an opponent card.",
			"ok_text": "OK",
			"cancel_text": "",
			"ok_enabled": true,
			"cancel_visible": false,
			"normal_only": normal_only,
		}
		enable_instructions_ui("Name opponent card.", true, cancel_allowed, false)

		change_ui_state(UIState.UIState_SelectCards, UISubState.UISubState_SelectCards_DiscardFromReference)
	else:
		ai_name_opponent_card(normal_only)

func _on_boost_played(event):
	var player = event['event_player']
	var card = find_card_on_board(event['number'])
	var target_zone = $PlayerStrike/StrikeZone
	var is_player = player == Enums.PlayerId.PlayerId_Player
	if not is_player:
		target_zone = $OpponentStrike/StrikeZone
		card.flip_card_to_front(true)
	_move_card_to_strike_area(card, target_zone, $AllCards/Striking, is_player, false)
	spawn_damage_popup("Boost!", player)
	return BoostDelay

func _on_choose_card_hand_to_gauge(event):
	var player = event['event_player']
	var min_amount = event['number']
	var max_amount = event['extra_info']
	if player == Enums.PlayerId.PlayerId_Player:
		begin_discard_cards_selection(min_amount, max_amount, UISubState.UISubState_SelectCards_DiscardCardsToGauge)
	else:
		ai_choose_card_hand_to_gauge(min_amount, max_amount)

func _on_choose_from_discard(event):
	var player = event['event_player']
	var limitation = game_wrapper.get_decision_info().limitation
	var destination = game_wrapper.get_decision_info().destination
	if player == Enums.PlayerId.PlayerId_Player:
		# Show the discard window.
		_on_player_discard_button_pressed()
		selected_cards = []
		select_card_require_min = 1
		select_card_require_max = 1
		limitation = limitation + " "
		var instruction = "Select %s %scard to move to %s." % [select_card_require_min, limitation, destination]
		popout_instruction_info = {
			"popout_type": CardPopoutType.CardPopoutType_DiscardPlayer,
			"instruction_text": instruction,
			"ok_text": "OK",
			"cancel_text": "",
			"ok_enabled": true,
			"cancel_visible": false,
		}

		enable_instructions_ui(instruction, true, false)
		change_ui_state(UIState.UIState_SelectCards, UISubState.UISubState_SelectCards_ChooseDiscardToDestination)
	else:
		ai_choose_from_discard()

func clear_selected_cards():
	for card in selected_cards:
		card.set_selected(false)
	selected_cards = []

func _on_discard_event(event):
	var player = event['event_player']
	var discard_id = event['number']
	var card = find_card_on_board(discard_id)
	if player == Enums.PlayerId.PlayerId_Player:
		discard_card(card, $PlayerDeck/Discard, $AllCards/PlayerDiscards, true)
	else:
		discard_card(card, $OpponentDeck/Discard, $AllCards/OpponentDiscards, false)
	update_card_counts()

func find_card_on_board(card_id) -> CardBase:
	# Find a given card among the Hand, Strike, Gauge, Boost, and Discard areas.
	var zones = $AllCards.get_children()
	for zone in zones:
		if zone is Node2D:
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
	if player == Enums.PlayerId.PlayerId_Opponent:
		gauge_panel = $OpponentGauge
		gauge_card_loc = $AllCards/OpponentGauge

	var pos = gauge_panel.get_center_pos()
	var is_player = player == Enums.PlayerId.PlayerId_Player
	if card.get_parent() == $AllCards/PlayerDeck or card.get_parent() == $AllCards/OpponentDeck:
		card.set_card_and_focus(get_deck_button_position(is_player), null, null)
	card.discard_to(pos, CardBase.CardState.CardState_InGauge)
	reparent_to_zone(card, gauge_card_loc)
	layout_player_hand(is_player)
	spawn_damage_popup("+ Gauge", player)
	return SmallNoticeDelay

func get_deck_zone(is_player : bool):
	if is_player:
		return $AllCards/PlayerDeck
	else:
		return $AllCards/OpponentDeck

func _on_add_to_deck(event):
	var player = event['event_player']
	var is_player = player == Enums.PlayerId.PlayerId_Player
	var card = find_card_on_board(event['number'])
	card.flip_card_to_front(false)
	var deck_position = get_deck_button_position(is_player)
	card.discard_to(deck_position, CardBase.CardState.CardState_InDeck)
	reparent_to_zone(card, get_deck_zone(is_player))
	layout_player_hand(is_player)

func _on_add_to_hand(event):
	var player = event['event_player']
	var is_player = player == Enums.PlayerId.PlayerId_Player
	var card = find_card_on_board(event['number'])
	card.reset()
	card.flip_card_to_front(is_player)
	add_card_to_hand(card.card_id, is_player)
	layout_player_hand(is_player)

func _on_draw_event(event):
	var player = event['event_player']
	var card_drawn_id = event['number']
	var is_player = player == Enums.PlayerId.PlayerId_Player
	draw_card(card_drawn_id, is_player)
	update_card_counts()
	#spawn_damage_popup("Draw", player)

func _on_exceed_event(event):
	var player = event['event_player']
	if player == Enums.PlayerId.PlayerId_Player:
		$PlayerCharacter.set_exceed(true)
		player_character_card.exceed(true)

	else:
		$OpponentCharacter.set_exceed(true)
		opponent_character_card.exceed(true)

	spawn_damage_popup("Exceed!", player)
	return SmallNoticeDelay

func _on_force_start_strike(event):
	var player = event['event_player']
	spawn_damage_popup("Strike!", player)
	if player == Enums.PlayerId.PlayerId_Player:
		begin_strike_choosing(false, false)
	else:
		ai_forced_strike()

func _on_force_wild_swing(event):
	var player = event['event_player']
	spawn_damage_popup("Force Wild Swing!", player)
	return SmallNoticeDelay

func _on_game_over(event):
	printlog("GAME OVER for %s" % game_wrapper.get_player_name(event['event_player']))
	game_over_stuff.visible = true
	change_ui_state(UIState.UIState_GameOver, UISubState.UISubState_None)
	_update_buttons()
	var player = event['event_player']
	if player == Enums.PlayerId.PlayerId_Player:
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
	var active_player = game_wrapper.get_active_player()
	if active_player == Enums.PlayerId.PlayerId_Player:
		begin_discard_cards_selection(event['number'], event['number'],UISubState.UISubState_SelectCards_DiscardCards)
	else:
		# AI or other player wait
		ai_discard(event)

func _on_choose_to_discard(event, informative_only : bool):
	var player = event['event_player']
	var amount = event['number']
	spawn_damage_popup("Forced Discard %s" % str(amount), player)
	if not informative_only:
		if player == Enums.PlayerId.PlayerId_Player:
			begin_discard_cards_selection(event['number'], event['number'],UISubState.UISubState_SelectCards_DiscardCards_Choose)
		else:
			# AI or other player wait
			ai_choose_to_discard(amount)
	return SmallNoticeDelay


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
	current_instruction_text = text

func update_discard_selection_message():
	var num_remaining = select_card_require_min - len(selected_cards)
	set_instructions("Select %s more card(s) from your hand to discard." % num_remaining)

func update_discard_to_gauge_selection_message():
	if select_card_require_min == select_card_require_max:
		var num_remaining = select_card_require_min - len(selected_cards)
		set_instructions("Select %s more card(s) from your hand to put in gauge." % num_remaining)
	else:
		var num_remaining = select_card_require_max - len(selected_cards)
		set_instructions("Select up to %s more card(s) from your hand to put in gauge." % [num_remaining])

func update_gauge_selection_message():
	var num_remaining = select_card_require_min - len(selected_cards)
	set_instructions("Select %s more gauge card(s)." % num_remaining)

func update_gauge_selection_for_cancel_message():
	var num_remaining = select_card_require_min - len(selected_cards)
	set_instructions("Select %s gauge card to use Cancel." % num_remaining)

func get_force_in_selected_cards():
	var force_selected = 0
	var card_db = game_wrapper.get_card_database()
	for card in selected_cards:
		force_selected += card_db.get_card_force_value(card.card_id)
	return force_selected

func can_selected_cards_pay_force(force_cost : int, bonus_card_force_value : int = 0):
	var max_force_selected = 0
	var ultras = 0
	var card_db = game_wrapper.get_card_database()
	for card in selected_cards:
		var value_of_card = card_db.get_card_force_value(card.card_id)
		max_force_selected += value_of_card
		if value_of_card == 2:
			ultras += 1
	if bonus_card_force_value == 2:
		ultras += 1
	max_force_selected += bonus_card_force_value
	var min_force_selected = max_force_selected - ultras
	for i in range(min_force_selected, max_force_selected + 1):
		if i == force_cost:
			return true
	return false


func update_force_generation_message():
	var force_selected = get_force_in_selected_cards()
	match ui_sub_state:
		UISubState.UISubState_SelectCards_MoveActionGenerateForce, UISubState.UISubState_SelectCards_CharacterAction_Force:
			set_instructions("Select cards to generate %s force.\n%s force generated." % [select_card_require_force, force_selected])
		UISubState.UISubState_SelectCards_ForceForChange:
			set_instructions("Select cards to generate force to draw new cards.\n%s force generated." % [force_selected])
		UISubState.UISubState_SelectCards_ForceForArmor:
			var damage_after_armor = max(0, force_for_armor_incoming_damage - 2 * force_selected)
			set_instructions("Select cards to generate force for +2 Armor each.\n%s force generated.\nYou will take %s damage." % [force_selected, damage_after_armor])
		UISubState.UISubState_SelectCards_ForceForEffect:
			var effect_str = ""
			var decision_effect = game_wrapper.get_decision_info().effect
			if decision_effect['per_force_effect']:
				var effect = decision_effect['per_force_effect']
				var effect_text = CardDefinitions.get_effect_text(effect)
				effect_str = "Generate up to %s force for %s per force." % [decision_effect['force_max'], effect_text]
			elif decision_effect['overall_effect']:
				var effect = decision_effect['overall_effect']
				var effect_text = CardDefinitions.get_effect_text(effect)
				effect_str = "Generate %s force for %s." % [decision_effect['force_max'], effect_text]
			effect_str += "\n%s force generated." % [force_selected]
			set_instructions(effect_str)

func enable_instructions_ui(message, can_ok, can_cancel, can_wild_swing : bool = false, choices = []):
	set_instructions(message)
	instructions_ok_allowed = can_ok
	instructions_cancel_allowed = can_cancel
	instructions_wild_swing_allowed = can_wild_swing
	current_effect_choices = choices

func begin_discard_cards_selection(number_to_discard_min, number_to_discard_max, next_sub_state):
	selected_cards = []
	select_card_require_min = number_to_discard_min
	select_card_require_max = number_to_discard_max
	var cancel_allowed = number_to_discard_min == 0
	enable_instructions_ui("", true, cancel_allowed)
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
		UISubState.UISubState_SelectCards_Exceed, UISubState.UISubState_SelectCards_BoostCancel, UISubState.UISubState_SelectCards_CharacterAction_Gauge:
			cancel_allowed = true
	enable_instructions_ui("", true, cancel_allowed, wild_swing_allowed)

	change_ui_state(UIState.UIState_SelectCards, sub_state)

func begin_effect_choice(choices, instruction_text : String):
	enable_instructions_ui(instruction_text, false, false, false, choices)
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
	var other_player = game_wrapper.other_player(player)
	var other_player_location = game_wrapper.get_player_location(other_player)
	var move_amount = event['extra_info']
	var destination = event['number']
	var move_anim = Character.CharacterAnim.CharacterAnim_WalkForward
	var original_position = event['extra_info2']
	var is_far = abs(original_position - destination) >= 2
	var is_forward = ((destination > original_position and other_player_location > original_position)
		or (destination < original_position and other_player_location < original_position))
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
	if player == Enums.PlayerId.PlayerId_Player:
		move_character_to_arena_square($PlayerCharacter, destination, false,  move_anim)
	else:
		move_character_to_arena_square($OpponentCharacter, destination, false, move_anim)
	return MoveDelay

func _on_mulligan_decision(event):
	var player = event['event_player']
	if player == Enums.PlayerId.PlayerId_Player:
		if not game_wrapper.get_player_mulligan_complete(player) and ui_sub_state != UISubState.UISubState_SelectCards_Mulligan:
			selected_cards = []
			select_card_require_min = 1
			select_card_require_max = game_wrapper.get_player_hand_size(player)
			var can_cancel = true
			enable_instructions_ui("Select cards to mulligan.", true, can_cancel)
			change_ui_state(UIState.UIState_SelectCards, UISubState.UISubState_SelectCards_Mulligan)
	else:
		ai_mulligan_decision()

func _on_reshuffle_discard(event):
	var player = event['event_player']
	spawn_damage_popup("Reshuffle!", player)
	if player == Enums.PlayerId.PlayerId_Player:
		var cards = $AllCards/PlayerDiscards.get_children()
		for card in cards:
			card.get_parent().remove_child(card)
			$AllCards/PlayerDeck.add_child(card)
			card.reset(OffScreen)
	else:
		var cards = $AllCards/OpponentDiscards.get_children()
		for card in cards:
			card.get_parent().remove_child(card)
			$AllCards/OpponentDeck.add_child(card)
			card.flip_card_to_front(false)
			card.reset(OffScreen)
	close_popout()
	update_card_counts()
	return SmallNoticeDelay

func _on_reshuffle_deck_mulligan(_event):
	#printlog("UI: TODO: In place reshuffle deck. No cards actually move though.")
	pass

func _on_reveal_hand(event):
	var player = event['event_player']
	spawn_damage_popup("Hand Revealed!", player)
	if player == Enums.PlayerId.PlayerId_Opponent:
		var current_children = $AllCards/OpponentRevealed.get_children()
		for i in range(len(current_children)-1, -1, -1):
			var card = current_children[i]
			card.get_parent().remove_child(card)
			card.queue_free()
		var card_db = game_wrapper.get_card_database()
		var cards = $AllCards/OpponentHand.get_children()
		for card in cards:
			var logic_card : GameCard = card_db.get_card(card.card_id)
			var copy_card = create_card(card.card_id + RevealCopyIdRangestart, logic_card.definition, card.card_image, card.cardback_image, $AllCards/OpponentRevealed, 0, true)
			copy_card.set_card_and_focus(OffScreen, 0, CardBase.ReferenceCardScale)
			copy_card.resting_scale = CardBase.ReferenceCardScale
			copy_card.change_state(CardBase.CardState.CardState_Offscreen)
			copy_card.flip_card_to_front(true)
	else:
		# Nothing for AI here.
		pass
	return SmallNoticeDelay

func _on_reveal_topdeck(event):
	var player = event['event_player']
	var card_id = event['number']
	spawn_damage_popup("Top Deck Revealed!", player)
	if player == Enums.PlayerId.PlayerId_Opponent:
		var current_children = $AllCards/OpponentRevealed.get_children()
		for i in range(len(current_children)-1, -1, -1):
			var card = current_children[i]
			card.get_parent().remove_child(card)
			card.queue_free()
		var card_db = game_wrapper.get_card_database()
		var logic_card : GameCard = card_db.get_card(card_id)
		var card = find_card_on_board(card_id)
		var copy_card = create_card(card.card_id + RevealCopyIdRangestart, logic_card.definition, card.card_image, card.cardback_image, $AllCards/OpponentRevealed, 0, true)
		copy_card.set_card_and_focus(OffScreen, 0, CardBase.ReferenceCardScale)
		copy_card.resting_scale = CardBase.ReferenceCardScale
		copy_card.change_state(CardBase.CardState.CardState_Offscreen)
		copy_card.flip_card_to_front(true)
	else:
		# Nothing for AI here.
		pass
	return SmallNoticeDelay

func _move_card_to_strike_area(card, strike_area, new_parent, is_player : bool, is_ex : bool):
	card.set_position_if_at_position(OffScreen, get_deck_button_position(is_player))

	var pos = strike_area.global_position + strike_area.size * strike_area.scale /2
	if is_ex:
		pos.x += CardBase.get_hand_card_size().x
	card.discard_to(pos, CardBase.CardState.CardState_InStrike)
	card.get_parent().remove_child(card)
	new_parent.add_child(card)
	layout_player_hand(is_player)

func _on_strike_started(event, is_ex : bool):
	var player = event['event_player']
	var card = find_card_on_board(event['number'])
	var reveal_immediately = event['event_type'] == Enums.EventType.EventType_Strike_PayCost_Unable
	if reveal_immediately:
		card.flip_card_to_front(true)
	if player == Enums.PlayerId.PlayerId_Player:
		_move_card_to_strike_area(card, $PlayerStrike/StrikeZone, $AllCards/Striking, true, is_ex)
	else:
		# Opponent started strike, player has to respond.
		_move_card_to_strike_area(card, $OpponentStrike/StrikeZone, $AllCards/Striking, false, is_ex)

func _on_strike_do_response_now(event):
	var player = event['event_player']
	if player == Enums.PlayerId.PlayerId_Player:
		begin_strike_choosing(true, false)
	else:
		ai_strike_response()

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

func _on_strike_character_effect(event):
	var player = event['event_player']
	var is_player = player == Enums.PlayerId.PlayerId_Player
	var bonus_panel = player_bonus_panel
	var bonus_label = player_bonus_label
	if not is_player:
		bonus_panel = opponent_bonus_panel
		bonus_label = opponent_bonus_label

	bonus_panel.visible = true
	var effect = event['extra_info']
	var label_text = ""
	label_text += CardDefinitions.get_effect_text(effect, false, true, true) + "\n"
	label_text = label_text.replace(",", "\n")
	bonus_label.text = label_text

func _on_effect_choice(event):
	var player = event['event_player']
	if player == Enums.PlayerId.PlayerId_Player:
		var instruction_text = "Select an effect:"
		if event['reason'] == "EffectOrder":
			instruction_text = "Select which effect to resolve first:"
		begin_effect_choice(game_wrapper.get_decision_info().choice, instruction_text)
	else:
		ai_effect_choice(event)

func _on_pay_cost_gauge(event):
	var player = event['event_player']
	if player == Enums.PlayerId.PlayerId_Player:
		var card_db = game_wrapper.get_card_database()
		var wild_swing_allowed = game_wrapper.get_decision_info().type == Enums.DecisionType.DecisionType_PayStrikeCost_CanWild
		var gauge_cost = card_db.get_card_gauge_cost(event['number'])
		begin_gauge_selection(gauge_cost, wild_swing_allowed, UISubState.UISubState_SelectCards_StrikeGauge)
	else:
		ai_pay_cost(event)

func _on_pay_cost_failed(event):
	# Do the wild swing deal.
	return _on_strike_started(event, false)

func _on_force_for_armor(event):
	var player = event['event_player']
	force_for_armor_incoming_damage = event['number']
	if player == Enums.PlayerId.PlayerId_Player:
		change_ui_state(null, UISubState.UISubState_SelectCards_ForceForArmor)
		begin_generate_force_selection(-1)
	else:
		ai_force_for_armor(event)

func _on_force_for_effect(event):
	var player = event['event_player']
	if player == Enums.PlayerId.PlayerId_Player:
		change_ui_state(null, UISubState.UISubState_SelectCards_ForceForEffect)
		var effect = game_wrapper.get_decision_info().effect
		select_card_up_to_force = effect['force_max']
		var require_max = -1
		if effect['overall_effect']:
			require_max = select_card_up_to_force
		begin_generate_force_selection(require_max)
	else:
		ai_force_for_effect(event)

func _on_damage(event):
	var player = event['event_player']
	var life = game_wrapper.get_player_life(player)
	var damage_taken = event['number']
	if player == Enums.PlayerId.PlayerId_Player:
		$PlayerLife.set_life(life)
		$PlayerCharacter.play_hit()
	else:
		$OpponentLife.set_life(life)
		$OpponentCharacter.play_hit()
	spawn_damage_popup("%s Damage" % str(damage_taken), player)
	return SmallNoticeDelay

func _handle_events(events):
	var delay = 0
	for event_index in range(events.size()):
		var event = events[event_index]
		_log_event(event)
		match event['event_type']:
			Enums.EventType.EventType_AddToGauge:
				delay = _on_add_to_gauge(event)
			Enums.EventType.EventType_AddToDeck:
				_on_add_to_deck(event)
			Enums.EventType.EventType_AddToDiscard:
				_on_discard_event(event)
			Enums.EventType.EventType_AddToHand:
				_on_add_to_hand(event)
			Enums.EventType.EventType_AdvanceTurn:
				delay = _on_advance_turn()
			Enums.EventType.EventType_Boost_ActionAfterBoost:
				delay = _on_post_boost_action(event)
			Enums.EventType.EventType_Boost_CancelDecision:
				delay = _on_boost_cancel_decision(event)
			Enums.EventType.EventType_Boost_Canceled:
				delay = _on_boost_canceled(event)
			Enums.EventType.EventType_Boost_Continuous_Added:
				delay = _on_continuous_boost_added(event)
			Enums.EventType.EventType_Boost_DiscardContinuousChoice:
				_on_discard_continuous_boost_begin(event)
			Enums.EventType.EventType_Boost_NameCardOpponentDiscards:
				_on_name_opponent_card_begin(event)
			Enums.EventType.EventType_Boost_Played:
				delay = _on_boost_played(event)
			Enums.EventType.EventType_CardFromHandToGauge_Choice:
				_on_choose_card_hand_to_gauge(event)
			Enums.EventType.EventType_ChangeCards:
				delay = _on_change_cards(event)
			Enums.EventType.EventType_CharacterAction:
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_ChooseFromDiscard:
				_on_choose_from_discard(event)
			Enums.EventType.EventType_Discard:
				_on_discard_event(event)
			Enums.EventType.EventType_Draw:
				_on_draw_event(event)
			Enums.EventType.EventType_Exceed:
				delay = _on_exceed_event(event)
			Enums.EventType.EventType_ForceStartStrike:
				_on_force_start_strike(event)
			Enums.EventType.EventType_ForceForEffect:
				_on_force_for_effect(event)
			Enums.EventType.EventType_Strike_ForceWildSwing:
				delay = _on_force_wild_swing(event)
			Enums.EventType.EventType_GameOver:
				_on_game_over(event)
			Enums.EventType.EventType_HandSizeExceeded:
				_on_hand_size_exceeded(event)
			Enums.EventType.EventType_Move:
				delay = _on_move_event(event)
			Enums.EventType.EventType_MulliganDecision:
				_on_mulligan_decision(event)
			Enums.EventType.EventType_Prepare:
				delay = _on_prepare(event)
			Enums.EventType.EventType_ReadingNormal:
				_on_name_opponent_card_begin(event)
			Enums.EventType.EventType_ReshuffleDiscard:
				delay = _on_reshuffle_discard(event)
			Enums.EventType.EventType_ReshuffleDeck_Mulligan:
				_on_reshuffle_deck_mulligan(event)
			Enums.EventType.EventType_RevealHand:
				delay = _on_reveal_hand(event)
			Enums.EventType.EventType_RevealTopDeck:
				delay = _on_reveal_topdeck(event)
			Enums.EventType.EventType_Strike_ArmorUp:
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_Strike_CardActivation:
				delay = _on_strike_card_activation(event)
			Enums.EventType.EventType_Strike_CharacterEffect:
				_on_strike_character_effect(event)
			Enums.EventType.EventType_Strike_ChooseToDiscard:
				_on_choose_to_discard(event, false)
			Enums.EventType.EventType_Strike_ChooseToDiscard_Info:
				_on_choose_to_discard(event, true)
			Enums.EventType.EventType_Strike_DodgeAttacks, Enums.EventType.EventType_Strike_DodgeAttacksAtRange:
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_Strike_DoResponseNow:
				_on_strike_do_response_now(event)
			Enums.EventType.EventType_Strike_EffectChoice:
				_on_effect_choice(event)
			Enums.EventType.EventType_Strike_ExUp:
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_Strike_ForceForArmor:
				_on_force_for_armor(event)
			Enums.EventType.EventType_Strike_GainAdvantage:
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_Strike_GuardUp:
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_Strike_IgnoredPushPull:
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_Strike_Miss:
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_Strike_PayCost_Gauge:
				_on_pay_cost_gauge(event)
			Enums.EventType.EventType_Strike_PayCost_Force:
				printlog("TODO: UI Pay force costs on card")
				assert(false)
			Enums.EventType.EventType_Strike_PayCost_Unable:
				_on_pay_cost_failed(event)
			Enums.EventType.EventType_Strike_PowerUp:
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_Strike_RangeUp:
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_Strike_Response:
				_on_strike_started(event, false)
			Enums.EventType.EventType_Strike_Response_Ex:
				_on_strike_started(event, true)
			Enums.EventType.EventType_Strike_Reveal:
				delay = _on_strike_reveal(event)
			Enums.EventType.EventType_Strike_SpeedUp:
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_Strike_Started:
				_on_strike_started(event, false)
			Enums.EventType.EventType_Strike_Started_Ex:
				_on_strike_started(event, true)
			Enums.EventType.EventType_Strike_Stun:
				delay = _on_stunned(event)
			Enums.EventType.EventType_Strike_Stun_Immunity:
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_Strike_TookDamage:
				delay = _on_damage(event)
			Enums.EventType.EventType_Strike_WildStrike:
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
	var button_choices = []
	# Update main action selection UI

	var action_buttons_visible = ui_state == UIState.UIState_PickTurnAction
	if action_buttons_visible:
		set_instructions("Choose an action:")
		instructions_ok_allowed = false
		instructions_cancel_allowed = false
		instructions_wild_swing_allowed = false
		button_choices.append({ "text": "Prepare", "action": _on_prepare_button_pressed, "disabled": not game_wrapper.can_do_prepare(Enums.PlayerId.PlayerId_Player) })
		button_choices.append({ "text": "Move", "action": _on_move_button_pressed, "disabled": not game_wrapper.can_do_move(Enums.PlayerId.PlayerId_Player) })
		button_choices.append({ "text": "Change Cards", "action": _on_change_button_pressed, "disabled": not game_wrapper.can_do_change(Enums.PlayerId.PlayerId_Player) })
		var exceed_cost = game_wrapper.get_player_exceed_cost(Enums.PlayerId.PlayerId_Player)
		if exceed_cost >= 0:
			button_choices.append({ "text": "Exceed (%s Gauge)" % exceed_cost, "action": _on_exceed_button_pressed, "disabled": not game_wrapper.can_do_exceed(Enums.PlayerId.PlayerId_Player) })
		if game_wrapper.can_do_reshuffle(Enums.PlayerId.PlayerId_Player):
			button_choices.append({ "text": "Manual Reshuffle", "action": _on_reshuffle_button_pressed, "disabled": false })
		button_choices.append({ "text": "Boost", "action": _on_boost_button_pressed, "disabled": not game_wrapper.can_do_boost(Enums.PlayerId.PlayerId_Player) })
		button_choices.append({ "text": "Strike", "action": _on_strike_button_pressed, "disabled": not game_wrapper.can_do_strike(Enums.PlayerId.PlayerId_Player) })
		if game_wrapper.can_do_character_action(Enums.PlayerId.PlayerId_Player):
			var char_action = game_wrapper.get_player_character_action(Enums.PlayerId.PlayerId_Player)
			var force_cost = char_action['force_cost']
			var gauge_cost = char_action['gauge_cost']
			var additional_text = ""
			if force_cost > 0:
				additional_text += " (%s Force)" % force_cost
			if gauge_cost > 0:
				additional_text += " (%s Gauge)" % gauge_cost
			button_choices.append({ "text": "Character Action%s" % additional_text, "action": _on_character_action_pressed, "disabled": false })

	# Update instructions UI visibility
	var instructions_visible = false
	match ui_state:
		UIState.UIState_SelectCards, UIState.UIState_SelectArenaLocation, UIState.UIState_MakeChoice:
			instructions_visible = true

	# Update instructions UI Buttons
	if popout_instruction_info:
		popout_instruction_info['ok_enabled'] = can_press_ok()
	update_popout_instructions()
	if instructions_ok_allowed:
		button_choices.append({ "text": "OK", "action": _on_instructions_ok_button_pressed, "disabled": not can_press_ok() })

	var cancel_text = "Cancel"
	match ui_sub_state:
		UISubState.UISubState_SelectCards_BoostCancel, UISubState.UISubState_SelectCards_Mulligan, UISubState.UISubState_SelectCards_ForceForEffect, UISubState.UISubState_SelectCards_DiscardCardsToGauge:
			cancel_text = "Pass"
		_:
			cancel_text = "Cancel"

	if instructions_cancel_allowed:
		button_choices.append({ "text": cancel_text, "action": _on_instructions_cancel_button_pressed })
	if instructions_wild_swing_allowed:
		button_choices.append({ "text": "Wild Swing", "action": _on_wild_swing_button_pressed })

	# Update instructions message
	if ui_state == UIState.UIState_SelectCards:
		match ui_sub_state:
			UISubState.UISubState_SelectCards_DiscardCards, UISubState.UISubState_SelectCards_DiscardCards_Choose:
				update_discard_selection_message()
			UISubState.UISubState_SelectCards_DiscardCardsToGauge:
				update_discard_to_gauge_selection_message()
			UISubState.UISubState_SelectCards_MoveActionGenerateForce, UISubState.UISubState_SelectCards_CharacterAction_Force:
				update_force_generation_message()
			UISubState.UISubState_SelectCards_ForceForChange:
				update_force_generation_message()
			UISubState.UISubState_SelectCards_ForceForArmor:
				update_force_generation_message()
			UISubState.UISubState_SelectCards_ForceForEffect:
				update_force_generation_message()
			UISubState.UISubState_SelectCards_StrikeGauge:
				update_gauge_selection_message()
			UISubState.UISubState_SelectCards_BoostCancel:
				update_gauge_selection_for_cancel_message()
			UISubState.UISubState_SelectCards_Exceed, UISubState.UISubState_SelectCards_CharacterAction_Gauge:
				update_gauge_selection_message()

	# Update arena location selection buttons
	for i in range(1, 10):
		var arena_button = get_arena_location_button(i)
		arena_button.visible = (ui_state == UIState.UIState_SelectArenaLocation and i in arena_locations_clickable)

	# Update boost zones
	update_boost_summary($AllCards/PlayerBoosts, $PlayerBoostZone)
	update_boost_summary($AllCards/OpponentBoosts, $OpponentBoostZone)

	for i in range(current_effect_choices.size()):
		var choice = current_effect_choices[i]
		button_choices.append({ "text": CardDefinitions.get_effect_text(choice, false, true), "action": func(): _on_choice_pressed(i) })

	# Set the Action Menu state
	var action_menu_hidden = false
	match ui_state:
		UIState.UIState_PlayingAnimation, UIState.UIState_WaitForGameServer, UIState.UIState_GameOver:
			action_menu_hidden = true
		UIState.UIState_WaitingOnOpponent:
			action_menu_hidden = true
	action_menu.visible = not action_menu_hidden and (button_choices.size() > 0 or instructions_visible)
	action_menu.set_choices(current_instruction_text, button_choices)
	current_action_menu_choices = button_choices

func update_boost_summary(boosts_card_holder, boost_box):
	var card_ids = []
	var card_db = game_wrapper.get_card_database()
	for card in boosts_card_holder.get_children():
		card_ids.append(card.card_id)
	var effects = []
	for card_id in card_ids:
		var card = card_db.get_card(card_id)
		for effect in card.definition['boost']['effects']:
			if effect['timing'] != "now":
				effects.append(effect)
	var boost_summary = ""
	for effect in effects:
		boost_summary += CardDefinitions.get_effect_text(effect) + "\n"
	boost_box.set_text(boost_summary)


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
			UISubState.UISubState_SelectCards_ChooseDiscardToDestination, UISubState.UISubState_SelectCards_DiscardCards_Choose:
				return selected_cards_between_min_and_max()
			UISubState.UISubState_SelectCards_DiscardCardsToGauge, UISubState.UISubState_SelectCards_Mulligan, UISubState.UISubState_SelectCards_CharacterAction_Gauge:
				return selected_cards_between_min_and_max()
			UISubState.UISubState_SelectCards_MoveActionGenerateForce, UISubState.UISubState_SelectCards_CharacterAction_Force:
				return can_selected_cards_pay_force(select_card_require_force)
			UISubState.UISubState_SelectCards_ForceForChange:
				var force_selected = get_force_in_selected_cards()
				return force_selected >= 0
			UISubState.UISubState_SelectCards_StrikeCard, UISubState.UISubState_SelectCards_StrikeResponseCard:
				# As a special exception, allow 2 cards if exactly 2 cards and they're the same card.
				if len(selected_cards) == 2:
					var card_db = game_wrapper.get_card_database()
					var card1 = selected_cards[0]
					var card2 = selected_cards[1]
					return card_db.are_same_card(card1.card_id, card2.card_id)
				return len(selected_cards) == 1
			UISubState.UISubState_SelectCards_ForceForArmor:
				return true
			UISubState.UISubState_SelectCards_ForceForEffect:
				var force_selected = get_force_in_selected_cards()
				if select_card_require_force == -1:
					return force_selected <= select_card_up_to_force or can_selected_cards_pay_force(select_card_up_to_force)
				return can_selected_cards_pay_force(select_card_require_force)
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
	var success = game_wrapper.submit_prepare(Enums.PlayerId.PlayerId_Player)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	_update_buttons()

func _on_move_button_pressed():
	var valid_moves = []
	for i in range(1, 10):
		if game_wrapper.can_move_to(Enums.PlayerId.PlayerId_Player, i):
			valid_moves.append(i)

	begin_select_arena_location(valid_moves)

func _on_change_button_pressed():
	change_ui_state(null, UISubState.UISubState_SelectCards_ForceForChange)
	begin_generate_force_selection(-1)

func _on_exceed_button_pressed():
	begin_gauge_selection(game_wrapper.get_player_exceed_cost(Enums.PlayerId.PlayerId_Player), false, UISubState.UISubState_SelectCards_Exceed)

func _on_reshuffle_button_pressed():
	var success = game_wrapper.submit_reshuffle(Enums.PlayerId.PlayerId_Player)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	_update_buttons()

func _on_boost_button_pressed():
	begin_boost_choosing()

func _on_strike_button_pressed():
	begin_strike_choosing(false, true)

func _on_character_action_pressed():
	var character_action = game_wrapper.get_player_character_action(Enums.PlayerId.PlayerId_Player)
	if not character_action:
		assert(false, "Character action button should not be visible")
		return

	var force_cost = character_action['force_cost']
	var gauge_cost = character_action['gauge_cost']
	if force_cost > 0:
		change_ui_state(null, UISubState.UISubState_SelectCards_CharacterAction_Force)
		begin_generate_force_selection(force_cost)
	elif gauge_cost > 0:
		begin_gauge_selection(gauge_cost, false, UISubState.UISubState_SelectCards_CharacterAction_Gauge)
	else:
		game_wrapper.submit_character_action(Enums.PlayerId.PlayerId_Player, [])

func _on_choice_pressed(choice):
	current_effect_choices = []
	var success = game_wrapper.submit_choice(Enums.PlayerId.PlayerId_Player, choice)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	_update_buttons()

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
		var success = false
		match ui_sub_state:
			UISubState.UISubState_SelectCards_BoostCancel:
				success = game_wrapper.submit_boost_cancel(Enums.PlayerId.PlayerId_Player, selected_card_ids, true)
			UISubState.UISubState_SelectCards_ChooseDiscardToDestination:
				success = game_wrapper.submit_choose_from_discard(Enums.PlayerId.PlayerId_Player, single_card_id)
			UISubState.UISubState_SelectCards_CharacterAction_Force, UISubState.UISubState_SelectCards_CharacterAction_Gauge:
				success = game_wrapper.submit_character_action(Enums.PlayerId.PlayerId_Player, selected_card_ids)
			UISubState.UISubState_SelectCards_DiscardContinuousBoost:
				success = game_wrapper.submit_boost_name_card_choice_effect(Enums.PlayerId.PlayerId_Player, single_card_id)
			UISubState.UISubState_SelectCards_DiscardFromReference:
				success = game_wrapper.submit_boost_name_card_choice_effect(Enums.PlayerId.PlayerId_Player, single_card_id - ReferenceScreenIdRangeStart)
			UISubState.UISubState_SelectCards_DiscardCards:
				success = game_wrapper.submit_discard_to_max(Enums.PlayerId.PlayerId_Player, selected_card_ids)
			UISubState.UISubState_SelectCards_DiscardCards_Choose:
				success = game_wrapper.submit_choose_to_discard(Enums.PlayerId.PlayerId_Player, selected_card_ids)
			UISubState.UISubState_SelectCards_DiscardCardsToGauge:
				success = game_wrapper.submit_card_from_hand_to_gauge(Enums.PlayerId.PlayerId_Player, selected_card_ids)
			UISubState.UISubState_SelectCards_StrikeGauge:
				success = game_wrapper.submit_pay_strike_cost(Enums.PlayerId.PlayerId_Player, selected_card_ids, false)
			UISubState.UISubState_SelectCards_Exceed:
				success = game_wrapper.submit_exceed(Enums.PlayerId.PlayerId_Player, selected_card_ids)
			UISubState.UISubState_SelectCards_ForceForEffect:
				success = game_wrapper.submit_force_for_effect(Enums.PlayerId.PlayerId_Player, selected_card_ids)
			UISubState.UISubState_SelectCards_MoveActionGenerateForce:
				success = game_wrapper.submit_move(Enums.PlayerId.PlayerId_Player, selected_card_ids, selected_arena_location)
			UISubState.UISubState_SelectCards_ForceForChange:
				success = game_wrapper.submit_change(Enums.PlayerId.PlayerId_Player, selected_card_ids)
			UISubState.UISubState_SelectCards_StrikeCard, UISubState.UISubState_SelectCards_StrikeResponseCard:
				success = game_wrapper.submit_strike(Enums.PlayerId.PlayerId_Player, single_card_id, false, ex_card_id)
			UISubState.UISubState_SelectCards_ForceForArmor:
				success = game_wrapper.submit_force_for_armor(Enums.PlayerId.PlayerId_Player, selected_card_ids)
			UISubState.UISubState_SelectCards_Mulligan:
				success = game_wrapper.submit_mulligan(Enums.PlayerId.PlayerId_Player, selected_card_ids)
			UISubState.UISubState_SelectCards_PlayBoost:
				if game_wrapper.get_card_database().get_card_boost_force_cost(single_card_id) > 0:
					printlog("ERROR: TODO: Force cost not implemented.")
					assert(false)
				else:
					success = game_wrapper.submit_boost(Enums.PlayerId.PlayerId_Player, single_card_id)

		if success:
			popout_instruction_info = null
			change_ui_state(UIState.UIState_WaitForGameServer)
		_update_buttons()

func _on_instructions_cancel_button_pressed():
	var success = false
	match ui_sub_state:
		UISubState.UISubState_SelectCards_ForceForArmor:
			deselect_all_cards()
			close_popout()
			success = game_wrapper.submit_force_for_armor(Enums.PlayerId.PlayerId_Player, [])
		UISubState.UISubState_SelectCards_ForceForEffect:
			deselect_all_cards()
			close_popout()
			success = game_wrapper.submit_force_for_effect(Enums.PlayerId.PlayerId_Player, [])
		UISubState.UISubState_SelectCards_Mulligan:
			deselect_all_cards()
			close_popout()
			success = game_wrapper.submit_mulligan(Enums.PlayerId.PlayerId_Player, [])
		UISubState.UISubState_SelectCards_DiscardCardsToGauge:
			deselect_all_cards()
			close_popout()
			success = game_wrapper.submit_card_from_hand_to_gauge(Enums.PlayerId.PlayerId_Player, [])
		_:
			match ui_state:
				UIState.UIState_SelectArenaLocation:
					if instructions_cancel_allowed:
						change_ui_state(UIState.UIState_PickTurnAction, UISubState.UISubState_None)
				UIState.UIState_SelectCards:
					if instructions_cancel_allowed:
						deselect_all_cards()
						close_popout()
						if ui_sub_state == UISubState.UISubState_SelectCards_BoostCancel:
							success = game_wrapper.submit_boost_cancel(Enums.PlayerId.PlayerId_Player, [], false)
						else:
							change_ui_state(UIState.UIState_PickTurnAction, UISubState.UISubState_None)
	if success:
		popout_instruction_info = null
		change_ui_state(UIState.UIState_WaitForGameServer)
	_update_buttons()

func _on_wild_swing_button_pressed():
	var success = false
	if ui_state == UIState.UIState_SelectCards:
		if ui_sub_state == UISubState.UISubState_SelectCards_StrikeCard or ui_sub_state == UISubState.UISubState_SelectCards_StrikeResponseCard:
			success = game_wrapper.submit_strike(Enums.PlayerId.PlayerId_Player, -1, true, -1)
		elif ui_sub_state == UISubState.UISubState_SelectCards_StrikeGauge:
			close_popout()
			success = game_wrapper.submit_pay_strike_cost(Enums.PlayerId.PlayerId_Player, [], true)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	_update_buttons()

func _on_arena_location_pressed(location):
	selected_arena_location = location
	if ui_state == UIState.UIState_SelectArenaLocation:
		if ui_sub_state == UISubState.UISubState_SelectCards_MoveActionGenerateForce:
			begin_generate_force_selection(game_wrapper.get_force_to_move_to(Enums.PlayerId.PlayerId_Player, location))


#
# AI Functions
#
func _on_ai_move_button_pressed():
	if not game_wrapper.is_ai_game(): return
	var game_state = game_wrapper.get_game_state()
	if game_wrapper.get_active_player() == Enums.PlayerId.PlayerId_Opponent and game_state == Enums.GameState.GameState_PickAction:
		ai_take_turn()

func ai_handle_prepare():
	var success = game_wrapper.submit_prepare(Enums.PlayerId.PlayerId_Opponent)
	if not success:
		printlog("FAILED AI PREPARE")
	return success

func ai_handle_move(action : AIPlayer.MoveAction):
	var location = action.location
	var card_ids = action.force_card_ids
	var success = game_wrapper.submit_move(Enums.PlayerId.PlayerId_Opponent, card_ids, location)
	if not success:
		printlog("FAILED AI MOVE")
	return success

func ai_handle_change_cards(action : AIPlayer.ChangeCardsAction):
	var card_ids = action.card_ids
	var success = game_wrapper.submit_change(Enums.PlayerId.PlayerId_Opponent, card_ids)
	if not success:
		printlog("FAILED AI CHANGE CARDS")
	return success

func ai_handle_exceed(action : AIPlayer.ExceedAction):
	var card_ids = action.card_ids
	var success = game_wrapper.submit_exceed(Enums.PlayerId.PlayerId_Opponent, card_ids)
	if not success:
		printlog("FAILED AI EXCEED")
	return success

func ai_handle_reshuffle():
	var success = game_wrapper.submit_reshuffle(Enums.PlayerId.PlayerId_Opponent)
	if not success:
		printlog("FAILED AI RESHUFFLE")
	return success

func ai_handle_boost(action : AIPlayer.BoostAction):
	var card_id = action.card_id
	#var boost_choice_index = action.boost_choice_index
	var success = game_wrapper.submit_boost(Enums.PlayerId.PlayerId_Opponent, card_id)
	# TODO: Should this be grouped somehow? Save the choice from the original decision instead of asking again?
	if not success:
		printlog("FAILED AI BOOST")
	return success

func ai_handle_strike(action : AIPlayer.StrikeAction):
	var card_id = action.card_id
	var ex_card_id = action.ex_card_id
	var wild_swing = action.wild_swing
	var success = game_wrapper.submit_strike(Enums.PlayerId.PlayerId_Opponent, card_id, wild_swing, ex_card_id)
	if not success:
		printlog("FAILED AI STRIKE")
	return success

func ai_handle_character_action(action : AIPlayer.CharacterActionAction):
	var success = game_wrapper.submit_character_action(Enums.PlayerId.PlayerId_Opponent, action.card_ids)
	if not success:
		printlog("FAILED AI CHARACTER ACTION")
	return success

func ai_take_turn():
	if not game_wrapper.is_ai_game(): return
	var success = false
	var turn_action = ai_player.take_turn(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent)
	if turn_action is AIPlayer.PrepareAction:
		success = ai_handle_prepare()
	elif turn_action is AIPlayer.MoveAction:
		success = ai_handle_move(turn_action)
	elif turn_action is AIPlayer.ChangeCardsAction:
		success = ai_handle_change_cards(turn_action)
	elif turn_action is AIPlayer.ExceedAction:
		success = ai_handle_exceed(turn_action)
	elif turn_action is AIPlayer.ReshuffleAction:
		success = ai_handle_reshuffle()
	elif turn_action is AIPlayer.BoostAction:
		success = ai_handle_boost(turn_action)
	elif turn_action is AIPlayer.StrikeAction:
		success = ai_handle_strike(turn_action)
	elif turn_action is AIPlayer.CharacterActionAction:
		success = ai_handle_character_action(turn_action)
	else:
		assert(false, "Unknown turn action: %s" % turn_action)

	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI TURN")

func ai_pay_cost(event):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var can_wild = game_wrapper.get_decision_info().type == Enums.DecisionType.DecisionType_PayStrikeCost_CanWild
	var cost = game_wrapper.get_card_database().get_card_gauge_cost(event['number'])
	var pay_action = ai_player.pay_strike_gauge_cost(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent, cost, can_wild)
	var success = game_wrapper.submit_pay_strike_cost(Enums.PlayerId.PlayerId_Opponent, pay_action.card_ids, pay_action.wild_swing)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI PAY COST")

func ai_effect_choice(_event):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var effect_action = ai_player.pick_effect_choice(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent)
	var success = game_wrapper.submit_choice(Enums.PlayerId.PlayerId_Opponent, effect_action.choice)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI EFFECT CHOICE")

func ai_force_for_armor(_event):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var forceforarmor_action = ai_player.pick_force_for_armor(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent)
	var success = game_wrapper.submit_force_for_armor(Enums.PlayerId.PlayerId_Opponent, forceforarmor_action.card_ids)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI FORCE FOR ARMOR")

func ai_force_for_effect(_event):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var forceforeffect_action = ai_player.pick_force_for_effect(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent)
	var success = game_wrapper.submit_force_for_effect(Enums.PlayerId.PlayerId_Opponent, forceforeffect_action.card_ids)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI FORCE FOR EFFECT")

func ai_strike_response():
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var response_action = ai_player.pick_strike_response(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent)
	var success = game_wrapper.submit_strike(Enums.PlayerId.PlayerId_Opponent, response_action.card_id, response_action.wild_swing, response_action.ex_card_id)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI STRIKE RESPONSE")

func ai_discard(event):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var discard_action = ai_player.pick_discard_to_max(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent, event['number'])
	var success = game_wrapper.submit_discard_to_max(Enums.PlayerId.PlayerId_Opponent, discard_action.card_ids)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI DISCARD")

func ai_forced_strike():
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var strike_action = ai_player.pick_strike(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent)
	ai_handle_strike(strike_action)

func ai_boost_cancel_decision(gauge_cost):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var cancel_action = ai_player.pick_cancel(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent, gauge_cost)
	var success = game_wrapper.submit_boost_cancel(Enums.PlayerId.PlayerId_Opponent, cancel_action.card_ids, cancel_action.cancel)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI BOOST CANCEL")

func ai_discard_continuous_boost():
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var pick_action = ai_player.pick_discard_continuous(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent)
	var success = game_wrapper.submit_boost_name_card_choice_effect(Enums.PlayerId.PlayerId_Opponent, pick_action.card_id)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI DISCARD CONTINUOUS")

func ai_name_opponent_card(normal_only : bool):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var pick_action = ai_player.pick_name_opponent_card(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent, normal_only)
	var success = game_wrapper.submit_boost_name_card_choice_effect(Enums.PlayerId.PlayerId_Opponent, pick_action.card_id)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI NAME OPPONENT CARD")

func ai_choose_card_hand_to_gauge(min_amount, max_amount):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var cardfromhandtogauge_action = ai_player.pick_card_hand_to_gauge(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent, min_amount, max_amount)
	var success = game_wrapper.submit_card_from_hand_to_gauge(Enums.PlayerId.PlayerId_Opponent, cardfromhandtogauge_action.card_ids)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI CHOOSE CARD HAND TO GAUGE")

func ai_choose_from_discard():
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var discard_action = ai_player.pick_choose_from_discard(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent)
	var success = game_wrapper.submit_choose_from_discard(Enums.PlayerId.PlayerId_Opponent, discard_action.card_id)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI CHOOSE FROM DISCARD")

func ai_mulligan_decision():
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var mulligan_action = ai_player.pick_mulligan(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent)
	var success = game_wrapper.submit_mulligan(Enums.PlayerId.PlayerId_Opponent, mulligan_action.card_ids)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI MULLIGAN")
	test_init()

func ai_choose_to_discard(amount):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var discard_action = ai_player.pick_choose_to_discard(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent, amount)
	var success = game_wrapper.submit_choose_to_discard(Enums.PlayerId.PlayerId_Opponent, discard_action.card_ids)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI CHOOSE TO DISCARD")

# Popout Functions
func card_in_selected_cards(card):
	for selected_card in selected_cards:
		if selected_card.card_id == card.card_id:
			return true
	return false

func _update_popout_cards(cards_in_popout : Array, not_visible_position : Vector2, card_return_state : CardBase.CardState, filtering_allowed : bool = false, show_amount : bool = true):
	if show_amount:
		card_popout.set_amount(str(len(cards_in_popout)))
	else:
		card_popout.set_amount("")
	if card_popout.visible:
		# Clear first which sets the size/positions correctly.
		await card_popout.clear(len(cards_in_popout))
		var card_subset = []
		for card in cards_in_popout:
			if filtering_allowed and popout_show_normal_only() and not game_wrapper.get_card_database().is_normal_card(card.card_id - ReferenceScreenIdRangeStart):
				continue
			card_subset.append(card)
		for i in range(len(card_subset)):
			var card = card_subset[i]
			card.set_selected(card_in_selected_cards(card))
			# Assign positions
			var pos = card_popout.get_slot_position(i)
			var adjusted_pos = pos + CardBase.ReferenceCardScale * CardBase.ActualCardSize / 2
			card.set_card_and_focus(adjusted_pos, null, null)
			card.change_state(CardBase.CardState.CardState_InPopout)
			card.set_resting_position(adjusted_pos, 0)
	else:
		# When clearing, set the cards first before awaiting.
		for i in range(len(cards_in_popout)):
			var card = cards_in_popout[i]
			card.set_selected(false)
			# Assign back to hidden area.
			card.set_card_and_focus(not_visible_position, null, null)
			match card.state:
				CardBase.CardState.CardState_InPopout, CardBase.CardState.CardState_Unfocusing, CardBase.CardState.CardState_Focusing:
					card.unfocus()
					card.change_state(card_return_state)
			card.set_resting_position(not_visible_position, 0)
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

	# Revealed
	await _update_popout_cards(
		$AllCards/OpponentRevealed.get_children(),
		OffScreen,
		CardBase.CardState.CardState_Offscreen
	)

func close_popout():
	card_popout.visible = false
	await clear_card_popout()

func update_popout_instructions():
	if popout_instruction_info and popout_type_showing == popout_instruction_info['popout_type']:
		card_popout.set_instructions(popout_instruction_info)
	else:
		card_popout.set_instructions(null)

func popout_show_normal_only() -> bool:
	if popout_instruction_info and 'normal_only' in popout_instruction_info:
		return popout_instruction_info['normal_only']
	return false

func show_popout(popout_type : CardPopoutType, popout_title : String, card_node, card_rest_position : Vector2, card_rest_state : CardBase.CardState, show_amount : bool = true):
	popout_type_showing = popout_type
	update_popout_instructions()
	card_popout.set_title(popout_title)
	if card_popout.visible:
		card_popout.visible = false
		await clear_card_popout()
	card_popout.visible = true
	var cards = card_node.get_children()
	var filtering_allowed = popout_type == CardPopoutType.CardPopoutType_ReferenceOpponent
	_update_popout_cards(cards, card_rest_position, card_rest_state, filtering_allowed, show_amount)

func get_boost_zone_center(zone):
	var pos = zone.global_position + CardBase.get_hand_card_size() / 2
	pos.x += CardBase.get_hand_card_size().x / 2
	return pos

func _on_player_gauge_gauge_clicked():
	await close_popout()
	show_popout(CardPopoutType.CardPopoutType_GaugePlayer, "YOUR GAUGE", $AllCards/PlayerGauge, $PlayerGauge.get_center_pos(), CardBase.CardState.CardState_InGauge)

func _on_opponent_gauge_gauge_clicked():
	await close_popout()
	show_popout(CardPopoutType.CardPopoutType_GaugeOpponent, "THEIR GAUGE", $AllCards/OpponentGauge, $OpponentGauge.get_center_pos(), CardBase.CardState.CardState_InGauge)

func _on_player_discard_button_pressed():
	await close_popout()
	show_popout(CardPopoutType.CardPopoutType_DiscardPlayer, "YOUR DISCARDS", $AllCards/PlayerDiscards, get_discard_location($PlayerDeck/Discard), CardBase.CardState.CardState_Discarded)

func _on_opponent_discard_button_pressed():
	await close_popout()
	show_popout(CardPopoutType.CardPopoutType_DiscardOpponent, "THEIR DISCARD", $AllCards/OpponentDiscards, get_discard_location($OpponentDeck/Discard), CardBase.CardState.CardState_Discarded)

func _on_player_boost_zone_clicked_zone():
	await close_popout()
	show_popout(CardPopoutType.CardPopoutType_BoostPlayer, "YOUR BOOSTS", $AllCards/PlayerBoosts, get_boost_zone_center($PlayerBoostZone), CardBase.CardState.CardState_InBoost)

func _on_opponent_boost_zone_clicked_zone():
	await close_popout()
	show_popout(CardPopoutType.CardPopoutType_BoostOpponent, "THEIR BOOSTS", $AllCards/OpponentBoosts, get_boost_zone_center($OpponentBoostZone), CardBase.CardState.CardState_InBoost)

func _on_popout_close_window():
	await close_popout()

func _on_player_reference_button_pressed():
	await close_popout()
	for card in $AllCards/PlayerAllCopy.get_children():
		if card.card_id < 0:
			continue
		var id = card.card_id - ReferenceScreenIdRangeStart
		var logic_card = game_wrapper.get_card_database().get_card(id)
		var card_str_id = logic_card.definition['id']
		var count = game_wrapper.count_cards_in_deck_and_hand(Enums.PlayerId.PlayerId_Player, card_str_id)
		card.set_remaining_count(count)
	show_popout(CardPopoutType.CardPopoutType_ReferencePlayer, "YOUR DECK REFERENCE (showing remaining card counts in deck+hand)", $AllCards/PlayerAllCopy, OffScreen, CardBase.CardState.CardState_Offscreen, false)

func _on_opponent_reference_button_pressed():
	await close_popout()
	for card in $AllCards/OpponentAllCopy.get_children():
		if card.card_id < 0:
			continue
		var id = card.card_id - ReferenceScreenIdRangeStart
		var logic_card = game_wrapper.get_card_database().get_card(id)
		var card_str_id = logic_card.definition['id']
		var count = game_wrapper.count_cards_in_deck_and_hand(Enums.PlayerId.PlayerId_Opponent, card_str_id)
		card.set_remaining_count(count)
	show_popout(CardPopoutType.CardPopoutType_ReferenceOpponent, "THEIR DECK REFERENCE (showing remaining card counts in deck+hand)", $AllCards/OpponentAllCopy, OffScreen, CardBase.CardState.CardState_Offscreen, false)

func _on_exit_to_menu_pressed():
	game_wrapper.end_game()
	NetworkManager.leave_room()
	returning_from_game.emit()
	queue_free()

func _on_revealed_cards_button_pressed():
	await close_popout()
	show_popout(CardPopoutType.CardPopoutType_RevealedOpponent, "LAST REVEALED CARDS", $AllCards/OpponentRevealed, OffScreen, CardBase.CardState.CardState_Offscreen)

func _on_card_popout_pressed_ok():
	_on_instructions_ok_button_pressed()

func _on_card_popout_pressed_cancel():
	_on_instructions_cancel_button_pressed()


func _on_combat_log_button_pressed():
	$CombatLog.set_text(game_wrapper.get_combat_log())
	$CombatLog.visible = true

func _on_combat_log_close_button_pressed():
	$CombatLog.visible = false


func _on_action_menu_choice_selected(choice_index):
	var action = current_action_menu_choices[choice_index]['action']
	action.call()
