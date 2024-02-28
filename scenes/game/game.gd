extends Node2D

signal returning_from_game

const UseHugeCard = false

const Test_StartWithGauge = false

const CardBaseScene = preload("res://scenes/card/card_base.tscn")
const CardBase = preload("res://scenes/card/card_base.gd")
const Enums = preload("res://scenes/game/enums.gd")
const CardPopout = preload("res://scenes/game/card_popout.gd")
const CardPopoutScene = preload("res://scenes/game/card_popout.tscn")
const GaugePanel = preload("res://scenes/game/gauge_panel.gd")
const CharacterCardBase = preload("res://scenes/card/character_card_base.gd")
const AIPlayer = preload("res://scenes/game/ai_player.gd")
const DamagePopup = preload("res://scenes/game/damage_popup.gd")
const Character = preload("res://scenes/game/character.gd")
const CharacterScene = preload("res://scenes/game/character.tscn")
const GameWrapper = preload("res://scenes/game/game_wrapper.gd")
const GameCard = preload("res://scenes/game/game_card.gd")
const DecisionInfo = preload("res://scenes/game/decision_info.gd")
const ActionMenu = preload("res://scenes/game/action_menu.gd")
const ModalDialog = preload("res://scenes/game/modal_dialog.gd")
const EmoteDialog = preload("res://scenes/game/emote_dialog.gd")
const ArenaSquare = preload("res://scenes/game/arena_square.gd")
const EmoteDisplay = preload("res://scenes/game/emote_display.gd")
const CombatLog = preload("res://scenes/game/combat_log.gd")
const LocationInfoButtonPair = preload("res://scenes/game/location_infobutton_pair.gd")

@onready var player_emote : EmoteDisplay = $PlayerEmote
@onready var opponent_emote : EmoteDisplay = $OpponentEmote

@onready var damage_popup_template = preload("res://scenes/game/damage_popup.tscn")
@onready var arena_layout = $ArenaNode/RowButtons
@onready var arena_graphics = $ArenaNode/RowPlatforms

@onready var huge_card : Sprite2D = $HugeCard

@onready var emote_dialog : EmoteDialog = $EmoteDialog
@onready var modal_dialog : ModalDialog = $ModalDialog

const OffScreen = Vector2(-1000, -1000)
const RevealCopyIdRangestart = 80000
const ReferenceScreenIdRangeStart = 90000
const NoticeOffsetY = 50

const GameTimerLength : float = 15 * 60 + 5 # 15 minutes and 5 buffer seconds
var player_clock_remaining : float = GameTimerLength
var opponent_clock_remaining : float = GameTimerLength
var current_clock_user : Enums.PlayerId = Enums.PlayerId.PlayerId_Unassigned
const GameTimerClockServerDelay : float = 0.2
var clock_delay_remaining : float = -1
var player_notified_of_clock : bool = false

const ChoiceTextLengthSoftCap = 45
const ChoiceTextLengthHardCap = 60
const MaxBonusPanelWidth = 225

const CardPopoutZIndex = 5

const StrikeRevealDelay : float = 2.0
const MoveDelay : float = 1.0
const BoostDelay : float = 2.0
const SmallNoticeDelay : float = 1.0
var remaining_delay = 0
var events_to_process = []

var damage_popup_pool:Array[DamagePopup] = []

var insert_ai_pause = false
var popout_instruction_info = null

var ChoiceTagRegex = RegEx.new()

var first_run_done = false
var select_card_require_min = 0
var select_card_require_max = 0
var select_card_name_card_both_players = false
var select_card_must_be_max_or_min = false
var select_card_require_force = 0
var select_card_up_to_force = 0
var select_card_destination = ""
var select_gauge_require_card_id = ""
var select_gauge_require_card_name = ""
var select_boost_options = {}
var selected_boost_to_pay_for = -1
var instructions_ok_allowed = false
var instructions_cancel_allowed = false
var instructions_wild_swing_allowed = false
var instructions_ex_allowed = false
var selected_cards = []
var enabled_reminder_text = false
var arena_locations_clickable = []
var selected_arena_location = 0
var force_for_armor_incoming_damage = 0
var force_for_armor_ignore_armor = false
var force_for_armor_amount = 2
var popout_exlude_card_ids = []
var selected_character_action = 0
var cached_player_location = 0
var cached_opponent_location = 0
var reference_popout_toggle_enabled = false
var reference_popout_toggle = false
var opponent_cards_before_reshuffle = []
var treat_ultras_as_single_force = false
var discard_ex_first_for_strike = false
var use_free_force = false
var current_pay_costs_is_ex = false
var preparing_character_action = false
var prepared_character_action_data = {}
var player_can_boost_from_extra = false

var player_deck
var opponent_deck

enum ModalDialogType {
	ModalDialogType_None,
	ModalDialogType_ExitToMenu,
	ModalDialogType_CardInform,
}

var modal_dialog_type : ModalDialogType = ModalDialogType.ModalDialogType_None

enum CardPopoutType {
	CardPopoutType_GaugePlayer,
	CardPopoutType_GaugeOpponent,
	CardPopoutType_SealedPlayer,
	CardPopoutType_SealedOpponent,
	CardPopoutType_OverdrivePlayer,
	CardPopoutType_OverdriveOpponent,
	CardPopoutType_DiscardPlayer,
	CardPopoutType_DiscardOpponent,
	CardPopoutType_BoostPlayer,
	CardPopoutType_BoostOpponent,
	CardPopoutType_ReferencePlayer,
	CardPopoutType_ReferenceOpponent,
	CardPopoutType_BuddyPlayer,
	CardPopoutType_BuddyOpponent,
	CardPopoutType_RevealedOpponent,
	CardPopoutType_ChoiceZone,
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
	UISubState_SelectCards_ChooseBoostsToSustain,
	UISubState_SelectCards_ChooseDiscardToDestination,
	UISubState_SelectCards_ChooseFromTopdeck,
	UISubState_SelectCards_DiscardContinuousBoost,
	UISubState_SelectCards_DiscardOpponentGauge,
	UISubState_SelectCards_DiscardFromReference,
	UISubState_SelectCards_MoveActionGenerateForce,
	UISubState_SelectCards_PlayBoost,
	UISubState_SelectCards_DiscardCards,
	UISubState_SelectCards_DiscardCards_Choose,
	UISubState_SelectCards_DiscardCardsToGauge,
	UISubState_SelectCards_ForceForBoost,
	UISubState_SelectCards_ForceForChange,
	UISubState_SelectCards_Exceed, # 16
	UISubState_SelectCards_Mulligan,
	UISubState_SelectCards_StrikeForce,
	UISubState_SelectCards_StrikeGauge,
	UISubState_SelectCards_StrikeCard,
	UISubState_SelectCards_StrikeCard_FromGauge,
	UISubState_SelectCards_StrikeCard_FromSealed,
	UISubState_SelectCards_StrikeResponseCard,
	UISubState_SelectCards_OpponentSetsFirst_StrikeCard,
	UISubState_SelectCards_OpponentSetsFirst_StrikeResponseCard,
	UISubState_SelectCards_ForceForArmor,
	UISubState_SelectCards_ForceForEffect,
	UISubState_SelectCards_GaugeForArmor,
	UISubState_SelectCards_GaugeForEffect,
	UISubState_SelectArena_MoveResponse,
	UISubState_SelectArena_EffectChoice,
	UISubState_PickNumberFromRange,
}

var ui_state : UIState = UIState.UIState_Initializing
var ui_sub_state : UISubState = UISubState.UISubState_None

var previous_ui_state : UIState = UIState.UIState_Initializing
var previous_ui_sub_state : UISubState = UISubState.UISubState_None

var game_wrapper : GameWrapper = GameWrapper.new()
@onready var card_popout_parent : Node2D = $CardPopoutParent
@onready var player_character_card : CharacterCardBase  = $PlayerDeck/PlayerCharacterCard
@onready var player_buddy_character_card : CharacterCardBase  = $PlayerDeck/PlayerBuddyCharacterCard
@onready var opponent_character_card : CharacterCardBase  = $OpponentDeck/OpponentCharacterCard
@onready var opponent_buddy_character_card : CharacterCardBase  = $OpponentDeck/OpponentBuddyCharacterCard
@onready var player_buddies : Array[Character] = [$PlayerBuddy, $PlayerBuddy2, $PlayerBuddy3, $PlayerBuddy4, $PlayerBuddy5, $PlayerBuddy6]
@onready var opponent_buddies : Array[Character] = [$OpponentBuddy, $OpponentBuddy2, $OpponentBuddy3, $OpponentBuddy4, $OpponentBuddy5, $OpponentBuddy6]
@onready var foreground_buddies_parent : Node2D = $ForegroundBuddies
@onready var background_buddies_parent : Node2D = $BackgroundBuddies
@onready var game_over_stuff = $GameOverStuff
@onready var game_over_label = $GameOverStuff/GameOverLabel
@onready var ai_player : AIPlayer = $AIPlayer
@onready var opponent_name_label : Label = $OpponentDeck/OpponentName
@onready var player_bonus_panel = $PlayerStrike/CharBonusPanel
@onready var opponent_bonus_panel = $OpponentStrike/CharBonusPanel
@onready var player_bonus_label = $PlayerStrike/CharBonusPanel/MarginContainer/VBox/AbilityLabel
@onready var opponent_bonus_label = $OpponentStrike/CharBonusPanel/MarginContainer/VBox/AbilityLabel
@onready var action_menu : ActionMenu = $AllCards/ActionContainer/ActionMenu
@onready var action_menu_container : HBoxContainer = $AllCards/ActionContainer
@onready var choice_popout_button : Button = $ChoicePopoutShowButton
@onready var combat_log : CombatLog = $CombatLog
@onready var observer_next_button : Button = $ObserverNextButton
@onready var observer_play_to_live_button : Button = $ObserverPlayToLive
@onready var player_lightningrods : Node2D = $PlayerLightningRods
@onready var opponent_lightningrods : Node2D = $OpponentLightningRods
@onready var turnstart_audio : AudioStreamPlayer = $TurnStartAudio

var player_lightningrod_tracking = {}
var opponent_lightningrod_tracking = {}

var current_instruction_text : String = ""
var current_action_menu_choices : Array = []
var current_effect_choices : Array = []
var current_effect_extra_choice_text : Array = []
var instructions_number_picker_min = -1
var instructions_number_picker_max = -1
var show_thinking_spinner_in : float = 0
const ThinkingSpinnerWaitBeforeShowTime = 1.0
var observer_mode = false
var observer_live = false
var exiting = false

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
			'randomize_first_vs_ai': false
		}
		begin_local_game(vs_info)

	if not game_wrapper.is_ai_game():
		$AIMoveButton.visible = false
		if not observer_mode:
			$PlayerLife.set_clock(GameTimerLength)
			$OpponentLife.set_clock(GameTimerLength)

	$PlayerLife.set_life(game_wrapper.get_player_life(Enums.PlayerId.PlayerId_Player))
	$OpponentLife.set_life(game_wrapper.get_player_life(Enums.PlayerId.PlayerId_Opponent))
	game_over_stuff.visible = false

	player_bonus_panel.visible = false
	opponent_bonus_panel.visible = false
	player_bonus_label.text = ""
	opponent_bonus_label.text = ""

	observer_next_button.visible = observer_mode
	observer_play_to_live_button.visible = observer_mode

	for i in range(1, 10):
		player_lightningrod_tracking[i] = {
			"card_ids": [],
			"character": null,
		}
		opponent_lightningrod_tracking[i] = {
			"card_ids": [],
			"character": null,
		}

	var location_index = 0
	for child in $ArenaNode/RowLightningInfoButtons.get_children():
		if location_index == 0 or location_index == 10:
			# Skip margin containers
			location_index += 1
			continue
		assert(child is LocationInfoButtonPair)
		child.button_pressed.connect(func(player_id): _on_locationinfobuttonpair_pressed(player_id, location_index))
		location_index += 1

	ChoiceTagRegex.compile("\\[.*\\]")

	setup_characters()

func _on_locationinfobuttonpair_pressed(player, location):
	var rod_tracking = player_lightningrod_tracking
	if player == Enums.PlayerId.PlayerId_Opponent:
		rod_tracking = opponent_lightningrod_tracking

	var card_db = game_wrapper.get_card_database()
	var info_str : String = ""
	for card_id in rod_tracking[location]["card_ids"]:
		var card = card_db.get_card(card_id)
		info_str += card.definition['display_name'] + "\n"
	if info_str:
		info_str = info_str.erase(len(info_str)-1)
		modal_dialog.set_text_fields("Lightning Rods:\n%s" % info_str, "", "Close")
		modal_dialog_type = ModalDialogType.ModalDialogType_CardInform

func begin_local_game(vs_info):
	player_deck = vs_info['player_deck']
	opponent_deck = vs_info['opponent_deck']
	var randomize_first_player = vs_info['randomize_first_vs_ai']
	game_wrapper.initialize_local_game(player_deck, opponent_deck, randomize_first_player)

func begin_remote_game(game_start_message):
	observer_mode = 'observer_mode' in game_start_message and game_start_message['observer_mode']
	var starting_message_queue = []
	if observer_mode:
		starting_message_queue = game_start_message['observer_log']

	var player1_info = {
		'name': game_start_message['player1_name'],
		'id': game_start_message['player1_id'],
		'deck_id': game_start_message['player1_deck_id'],
		'deck': CardDefinitions.get_deck_from_str_id(game_start_message['player1_deck_id']),
		'player_number': 1,
	}
	var player2_info = {
		'name': game_start_message['player2_name'],
		'id': game_start_message['player2_id'],
		'deck_id': game_start_message['player2_deck_id'],
		'deck': CardDefinitions.get_deck_from_str_id(game_start_message['player2_deck_id']),
		'player_number': 2,
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

	game_wrapper.initialize_remote_game(my_player_info, opponent_player_info, starting_player, seed_value, observer_mode, starting_message_queue)

func is_player_overdrive_visible(player_id : Enums.PlayerId):
	return game_wrapper.is_player_in_overdrive(player_id)

func add_buddy_to_zone(player : Enums.PlayerId, buddy : Node2D, buddy_id):
	var deck_def = player_deck
	var buddies = player_buddies
	if player == Enums.PlayerId.PlayerId_Opponent:
		deck_def = opponent_deck
		buddies = opponent_buddies
	var buddy_index = 0
	if 'buddy_cards' in deck_def and deck_def['buddy_cards']:
		for i in range(len(deck_def['buddy_cards'])):
			if buddy_id == deck_def['buddy_cards'][i]:
				buddy_index = i
				break
	var is_foreground_buddy = 'buddy_cards_foreground' in deck_def and deck_def['buddy_cards_foreground'][buddy_index]
	var zone = background_buddies_parent
	if is_foreground_buddy:
		zone = foreground_buddies_parent
	buddy.get_parent().remove_child(buddy)
	zone.add_child(buddy)

	# Keep buddies in the specific order in their definition so they layer correctly.
	# For example, Rachel's George is in front of Ivy Blossom.
	var child_index = 0
	var children = zone.get_children()
	for buddy_node in buddies:
		if buddy_node in children:
			zone.move_child(buddy_node, child_index)
			child_index += 1

func setup_characters():
	$PlayerCharacter.load_character(player_deck['id'])
	$OpponentCharacter.load_character(opponent_deck['id'])
	if 'buddy_card' in player_deck:
		player_buddies[0].visible = false
		player_buddies[0].load_character(player_deck['buddy_card'])
		player_buddies[0].set_buddy_id(player_deck['buddy_card'])
	if 'buddy_card' in opponent_deck:
		opponent_buddies[0].visible = false
		opponent_buddies[0].load_character(opponent_deck['buddy_card'])
		opponent_buddies[0].set_buddy_id(opponent_deck['buddy_card'])
	if 'buddy_cards' in player_deck:
		if 'no_buddy_card_graphics' in player_deck and player_deck['no_buddy_card_graphics']:
			pass
		else:
			for i in range(0, player_deck['buddy_cards'].size()):
				player_buddies[i].visible = false
				player_buddies[i].load_character(player_deck['buddy_card_graphics_id'][i])
				player_buddies[i].set_buddy_id(player_deck['buddy_cards'][i])
	if 'buddy_cards' in opponent_deck:
		if 'no_buddy_card_graphics' in opponent_deck and opponent_deck['no_buddy_card_graphics']:
			pass
		else:
			for i in range(0, opponent_deck['buddy_cards'].size()):
				opponent_buddies[i].visible = false
				opponent_buddies[i].load_character(opponent_deck['buddy_card_graphics_id'][i])
				opponent_buddies[i].set_buddy_id(opponent_deck['buddy_cards'][i])
	if player_deck['id'] == opponent_deck['id']:
		$OpponentCharacter.modulate = Color(1, 0.38, 0.55)
		for buddy in opponent_buddies:
			buddy.modulate = Color(1, 0.38, 0.55)
	$PlayerZones/PlayerSealed.visible = 'has_sealed_area' in player_deck and player_deck['has_sealed_area']
	$OpponentZones/OpponentSealed.visible = 'has_sealed_area' in opponent_deck and opponent_deck['has_sealed_area']
	if 'sealed_area_is_secret' in opponent_deck and opponent_deck['sealed_area_is_secret']:
		$OpponentZones/OpponentSealed.hidden_sealed()
	$PlayerZones/PlayerOverdrive.visible = is_player_overdrive_visible(Enums.PlayerId.PlayerId_Player)
	$OpponentZones/OpponentOverdrive.visible = is_player_overdrive_visible(Enums.PlayerId.PlayerId_Opponent)
	setup_character_card(player_character_card, player_deck, player_buddy_character_card)
	setup_character_card(opponent_character_card, opponent_deck, opponent_buddy_character_card)
	player_can_boost_from_extra = 'can_boost_from_extra' in player_deck and player_deck['can_boost_from_extra']

func setup_character_card(character_card, deck, buddy_character_card):
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

	# Setup buddy if they have one.
	var created_buddy_cards = []
	if 'hide_buddy_reference' in deck and deck['hide_buddy_reference']:
		buddy_character_card.visible = false
	elif 'buddy_card' in deck:
		buddy_character_card.visible = true
		buddy_character_card.hide_focus()
		var buddy_path = build_character_path(deck['id'], deck['buddy_card'], false)
		var buddy_exceeded_path = buddy_path
		if 'buddy_exceeds' in deck and deck['buddy_exceeds']:
			buddy_exceeded_path = build_character_path(deck['id'], deck['buddy_card'], true)
		buddy_character_card.set_image(buddy_path, buddy_exceeded_path)
	elif 'buddy_cards' in deck:
		buddy_character_card.visible = true
		buddy_character_card.hide_focus()
		var default_buddy = deck['buddy_cards'][0]
		if 'buddy_card_graphic_override' in deck:
			default_buddy = deck['buddy_card_graphic_override'][0]
		created_buddy_cards.append(default_buddy)
		var buddy_path = build_character_path(deck['id'], default_buddy, false)
		var buddy_exceeded_path = buddy_path
		if 'buddy_exceeds' in deck and deck['buddy_exceeds']:
			buddy_exceeded_path = build_character_path(deck['id'], default_buddy, true)
		buddy_character_card.set_image(buddy_path, buddy_exceeded_path)

		# Add remaining buddies as extras.
		for i in range(1, deck['buddy_cards'].size()):
			var buddy_id = deck['buddy_cards'][i]
			if 'buddy_card_graphic_override' in deck:
				buddy_id = deck['buddy_card_graphic_override'][i]
			if buddy_id in created_buddy_cards:
				# Skip any that share graphics.
				continue
			created_buddy_cards.append(buddy_id)
			buddy_path = build_character_path(deck['id'], buddy_id, false)
			buddy_exceeded_path = buddy_path
			if 'buddy_exceeds' in deck and deck['buddy_exceeds']:
				buddy_exceeded_path = build_character_path(deck['id'], buddy_id, true)
			buddy_character_card.set_extra_image(i, buddy_path, buddy_exceeded_path)
	else:
		buddy_character_card.visible = false

func build_character_path(deck_id, character_id, exceed):
	if exceed:
		return "res://assets/cards/" + deck_id + "/" + character_id + "_exceeded.jpg"
	return "res://assets/cards/" + deck_id + "/" + character_id + ".jpg"

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
	cached_player_location = game_wrapper.get_player_location(Enums.PlayerId.PlayerId_Player)
	cached_opponent_location = game_wrapper.get_player_location(Enums.PlayerId.PlayerId_Opponent)
	update_arena_squares()
	_update_buttons()

	finish_initialization()
	change_ui_state(UIState.UIState_WaitForGameServer)

func create_character_reference_card(path_root : String, exceeded : bool, zone):
	var image_path = path_root + "character_default.jpg"
	if exceeded:
		image_path = path_root + "character_exceeded.jpg"
	_create_reference_card(image_path, "Character Card", zone, CardBase.CharacterCardReferenceId)

func create_buddy_reference_card(path_root : String, buddy_id, exceeded : bool, zone, click_buddy_id):
	var image_path = path_root + buddy_id + ".jpg"
	if exceeded:
		image_path = path_root + buddy_id + "_exceeded.jpg"
	_create_reference_card(image_path, "Extra Card", zone, click_buddy_id)

func _create_reference_card(image_path : String, card_name : String, zone, card_id : int):
	var new_card : CardBase = CardBaseScene.instantiate()
	zone.add_child(new_card)
	new_card.initialize_card(
		card_id,
		image_path,
		image_path,
		false
	)
	new_card.name = card_name
	new_card.raised_card.connect(on_card_raised)
	new_card.lowered_card.connect(on_card_lowered)

	new_card.set_card_and_focus(OffScreen, 0, CardBase.ReferenceCardScale)
	new_card.resting_scale = CardBase.ReferenceCardScale
	new_card.change_state(CardBase.CardState.CardState_Offscreen)
	new_card.flip_card_to_front(true)

	if card_id not in [CardBase.CharacterCardReferenceId, CardBase.BuddyCardReferenceId]:
		new_card.clicked_card.connect(on_card_clicked)

func get_card_root_path(deck_id : String):
	return "res://assets/cards/" + deck_id + "/"

func get_card_image_path(deck_id : String, game_card : GameCard):
	return get_card_root_path(deck_id) + game_card.image

func spawn_deck(deck_id, deck_list, deck_card_zone, copy_zone, buddy_graphic_list, buddy_copy_zone,
		allow_click_buddy, set_aside_zone, card_back_image, is_opponent):
	var card_db = game_wrapper.get_card_database()
	var card_root_path = get_card_root_path(deck_id)
	for card in deck_list:
		var logic_card : GameCard = card_db.get_card(card.id)
		var image_path = get_card_image_path(deck_id, logic_card)
		var new_card = create_card(card.id, logic_card.definition, image_path, card_back_image, deck_card_zone, is_opponent)
		if observer_mode:
			new_card.skip_flip_when_drawing = true
		if logic_card.set_aside:
			reparent_to_zone(new_card, set_aside_zone)
		new_card.set_card_and_focus(OffScreen, 0, null)

	create_character_reference_card(card_root_path, false, copy_zone)
	create_character_reference_card(card_root_path, true, copy_zone)

	var previous_def_id = ""
	var buddy_card_id_links = {}
	for card in deck_list:
		var logic_card : GameCard = card_db.get_card(card.id)

		# Associates clickable buddy cards with deck cards;
		#   only accounts for one copy, ignored if allow_click_buddy is false
		if logic_card.definition['id'] in buddy_graphic_list:
			buddy_card_id_links[logic_card.definition['id']] = card.id

		if logic_card.hide_from_reference:
			continue
		var image_path = card_root_path + logic_card.image
		if previous_def_id != logic_card.definition['id']:
			var copy_card = create_card(card.id + ReferenceScreenIdRangeStart, logic_card.definition, image_path, card_back_image, copy_zone, is_opponent)
			copy_card.set_card_and_focus(OffScreen, 0, CardBase.ReferenceCardScale)
			copy_card.resting_scale = CardBase.ReferenceCardScale
			copy_card.change_state(CardBase.CardState.CardState_Offscreen)
			copy_card.flip_card_to_front(true)
			previous_def_id = card.definition['id']

	# Setup buddy if they have one.
	var created_buddy_cards = []
	if buddy_graphic_list:
		for buddy_id in buddy_graphic_list:
			if buddy_id in created_buddy_cards:
				# Skip any that share graphics.
				continue
			created_buddy_cards.append(buddy_id)
			var buddy_card_id = CardBase.BuddyCardReferenceId
			if allow_click_buddy:
				buddy_card_id = buddy_card_id_links[buddy_id]
			create_buddy_reference_card(card_root_path, buddy_id, false, buddy_copy_zone, buddy_card_id)

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

func spawn_emote(player_id : Enums.PlayerId, is_image_emote : bool, emote : String, emote_display : EmoteDisplay):
	var pos = get_notice_position(player_id)
	pos.y -= NoticeOffsetY
	if game_wrapper.get_player_location(player_id) > 5:
		pos.x -= 50
	var height = NoticeOffsetY
	emote_display.play_emote(is_image_emote, emote, pos, height)

func spawn_all_cards():
	var player_deck_id = player_deck['id']
	var opponent_deck_id = opponent_deck['id']
	var player_cardback = "res://assets/cardbacks/" + player_deck['cardback']
	var opponent_cardback = "res://assets/cardbacks/" + opponent_deck['cardback']

	var player_buddy_graphics = []
	var opponent_buddy_graphics = []
	for deck_graphic_pair in [[player_deck, player_buddy_graphics], [opponent_deck, opponent_buddy_graphics]]:
		var deck = deck_graphic_pair[0]
		var graphic_list = deck_graphic_pair[1]
		if 'hide_buddy_reference' in deck and deck['hide_buddy_reference']:
			continue
		elif 'buddy_card' in deck:
			graphic_list.append(deck['buddy_card'])
			if 'buddy_exceeds' in deck and deck['buddy_exceeds']:
				graphic_list.append(deck['buddy_card'] + "_exceeded")
		elif 'buddy_card_graphic_override' in deck:
			for buddy_card in deck['buddy_card_graphic_override']:
				graphic_list.append(buddy_card)
		elif 'buddy_cards' in deck:
			for buddy_card in deck['buddy_cards']:
				graphic_list.append(buddy_card)
				if 'buddy_exceeds' in deck and deck['buddy_exceeds']:
					graphic_list.append(buddy_card + "_exceeded")

	var player_can_click_buddy = 'can_boost_from_extra' in player_deck and player_deck['can_boost_from_extra']
	var opponent_can_click_buddy = 'can_boost_from_extra' in opponent_deck and opponent_deck['can_boost_from_extra']

	spawn_deck(player_deck_id, game_wrapper.get_player_deck_list(Enums.PlayerId.PlayerId_Player), $AllCards/PlayerDeck, $AllCards/PlayerAllCopy,
		player_buddy_graphics, $AllCards/PlayerBuddyCopy, player_can_click_buddy, $AllCards/PlayerSetAside, player_cardback, false)
	spawn_deck(opponent_deck_id, game_wrapper.get_player_deck_list(Enums.PlayerId.PlayerId_Opponent), $AllCards/OpponentDeck, $AllCards/OpponentAllCopy,
		opponent_buddy_graphics, $AllCards/OpponentBuddyCopy, opponent_can_click_buddy, $AllCards/OpponentSetAside, opponent_cardback, true)

func get_arena_location_button(arena_location):
	var target_square = arena_layout.get_child(arena_location - 1)
	var button = target_square.get_node("Button")
	return button

func move_character_to_arena_square(character, arena_location, immediate: bool, move_anim : Character.CharacterAnim, buddy_offset : int = 0):
	var target_square = arena_layout.get_child(arena_location - 1)
	var target_position = target_square.global_position + target_square.size/2
	var offset_y = $ArenaNode/RowButtons.position.y
	target_position.y -= character.get_size().y * character.scale.y / 2 + offset_y + character.vertical_offset
	if buddy_offset != 0:
		target_position.x += buddy_offset * (character.get_size().x * character.scale.x /4) + character.horizontal_offset_buddy
	if character.use_buddy_extra_offset:
		# Adjust the buddy to account for having multiple of the same buddy.
		target_position.x += buddy_offset * 20
		target_position.y += 15
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

	for buddy in player_buddies:
		if buddy.visible:
			to_left = buddy.position.x < other_character.position.x
			buddy.set_facing(to_left)
	for buddy in opponent_buddies:
		if buddy.visible:
			to_left = buddy.position.x < character.position.x
			buddy.set_facing(to_left)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if exiting:
		return
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
			var log_text = game_wrapper.get_combat_log(combat_log.get_filters(), combat_log.log_player_color, combat_log.log_opponent_color)
			combat_log.set_text(log_text)
		elif ui_state == UIState.UIState_WaitingOnOpponent:
			# Advance the AI game automatically.
			_on_ai_move_button_pressed()

		if events.size() == 0 and observer_live:
			game_wrapper.observer_process_next_message_from_queue()

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

	_process_clock(delta)

func _process_clock(delta):
	if clock_delay_remaining > 0:
		clock_delay_remaining -= delta
		if clock_delay_remaining <= 0:
			# Courtesy delay is over, assign the clock user.
			if current_clock_user == Enums.PlayerId.PlayerId_Unassigned:
				current_clock_user = game_wrapper.get_priority_player()

	if current_clock_user != Enums.PlayerId.PlayerId_Unassigned and ui_state != UIState.UIState_GameOver:
		if events_to_process.size() > 0:
			# Don't count down the clock while there are events to process.
			player_notified_of_clock = false
			return
		elif is_mulligan_done():
			if current_clock_user == Enums.PlayerId.PlayerId_Player:
				player_clock_remaining -= delta
				if not player_notified_of_clock:
					player_notified_of_clock = true
					if GlobalSettings.GameSoundsEnabled and not observer_mode:
						turnstart_audio.play()
			elif current_clock_user == Enums.PlayerId.PlayerId_Opponent:
				opponent_clock_remaining -= delta
				player_notified_of_clock = false
		else:
			# Mulligan is special in that both clocks count
			if not game_wrapper.get_player_mulligan_complete(Enums.PlayerId.PlayerId_Player):
				player_clock_remaining -= delta
			if not game_wrapper.get_player_mulligan_complete(Enums.PlayerId.PlayerId_Opponent):
				opponent_clock_remaining -= delta
		_update_clocks()

func is_mulligan_done():
	return game_wrapper.get_player_mulligan_complete(Enums.PlayerId.PlayerId_Player) and game_wrapper.get_player_mulligan_complete(Enums.PlayerId.PlayerId_Opponent)

func _update_clocks():
	if game_wrapper.is_ai_game(): return
	if observer_mode: return
	$PlayerLife.set_clock(player_clock_remaining)
	$OpponentLife.set_clock(opponent_clock_remaining)

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

func discard_card(card, discard_node, new_parent, is_player : bool, from_top : int):
	var discard_pos = get_discard_location(discard_node)
	# Make sure the card is faceup.
	make_card_revealed(card)
	card.discard_to(discard_pos, CardBase.CardState.CardState_Discarded)
	reparent_to_zone(card, new_parent, from_top)
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

	$PlayerZones/PlayerGauge.set_details($AllCards/PlayerGauge.get_child_count())
	$OpponentZones/OpponentGauge.set_details($AllCards/OpponentGauge.get_child_count())

	$PlayerZones/PlayerSealed.set_details(game_wrapper.get_player_sealed_size(Enums.PlayerId.PlayerId_Player))
	$OpponentZones/OpponentSealed.set_details(game_wrapper.get_player_sealed_size(Enums.PlayerId.PlayerId_Opponent))

	$PlayerZones/PlayerOverdrive.set_details(game_wrapper.get_player_overdrive_size(Enums.PlayerId.PlayerId_Player))
	$OpponentZones/OpponentOverdrive.set_details(game_wrapper.get_player_overdrive_size(Enums.PlayerId.PlayerId_Opponent))

	$PlayerZones/PlayerOverdrive.visible = is_player_overdrive_visible(Enums.PlayerId.PlayerId_Player)
	$OpponentZones/OpponentOverdrive.visible = is_player_overdrive_visible(Enums.PlayerId.PlayerId_Opponent)

func get_card_node_name(id):
	return "Card_" + str(id)

func create_card(id, card_def, image, card_back_image, parent, is_opponent : bool) -> CardBase:
	var new_card : CardBase = CardBaseScene.instantiate()
	parent.add_child(new_card)
	var strike_cost = card_def['gauge_cost']
	if strike_cost == 0:
		strike_cost = card_def['force_cost']
	new_card.initialize_card(
		id,
		image,
		card_back_image,
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
	if observer_mode:
		return false

	var in_gauge = game_wrapper.is_card_in_gauge(Enums.PlayerId.PlayerId_Player, card.card_id)
	var in_opponent_gauge = game_wrapper.is_card_in_gauge(Enums.PlayerId.PlayerId_Opponent, card.card_id)
	var in_hand = game_wrapper.is_card_in_hand(Enums.PlayerId.PlayerId_Player, card.card_id)
	var in_discard = game_wrapper.is_card_in_discards(Enums.PlayerId.PlayerId_Player, card.card_id)
	var in_sealed = game_wrapper.is_card_in_sealed(Enums.PlayerId.PlayerId_Player, card.card_id)
	var in_set_aside = game_wrapper.is_card_set_aside(Enums.PlayerId.PlayerId_Player, card.card_id)
	var in_overdrive = game_wrapper.is_card_in_overdrive(Enums.PlayerId.PlayerId_Player, card.card_id)
	var in_player_boosts = game_wrapper.is_card_in_boosts(Enums.PlayerId.PlayerId_Player, card.card_id)
	var is_sustained = game_wrapper.is_card_sustained(Enums.PlayerId.PlayerId_Player, card.card_id)
	var in_opponent_boosts = game_wrapper.is_card_in_boosts(Enums.PlayerId.PlayerId_Opponent, card.card_id)
	var in_player_reference = is_card_in_player_reference($AllCards/PlayerAllCopy.get_children(), card.card_id)
	var in_opponent_reference = is_card_in_player_reference($AllCards/OpponentAllCopy.get_children(), card.card_id)
	var in_choice_zone = is_card_in_player_reference($AllCards/ChoiceZone.get_children(), card.card_id)

	if ui_state == UIState.UIState_PickTurnAction:
		if in_player_boosts:
			var card_db = game_wrapper.get_card_database()
			var logic_card = card_db.get_card(card.card_id)
			return 'must_set_from_boost' in logic_card.definition and logic_card.definition['must_set_from_boost']
		elif in_set_aside and player_can_boost_from_extra:
			return game_wrapper.can_player_boost(Enums.PlayerId.PlayerId_Player, card.card_id, ['extra'], "", true)
		return in_hand or in_gauge
	match ui_sub_state:
		UISubState.UISubState_SelectCards_DiscardCards, UISubState.UISubState_SelectCards_DiscardCardsToGauge:
			return in_hand and len(selected_cards) < select_card_require_max
		UISubState.UISubState_SelectCards_DiscardCards_Choose:
			var limitation = game_wrapper.get_decision_info().limitation
			var meets_limitation = true
			var card_type = game_wrapper.get_card_database().get_card(card.card_id).definition['type']
			match limitation:
				"normal":
					meets_limitation = card_type == "normal"
				"ultra":
					meets_limitation = card_type == "ultra"
				"special":
					meets_limitation = card_type == "special"
				"special/ultra":
					meets_limitation = card_type in ["special", "ultra"]
				"from_array":
					var card_ids = game_wrapper.get_decision_info().choice
					meets_limitation = card.card_id in card_ids
				_:
					meets_limitation = true
			return in_hand and meets_limitation and len(selected_cards) < select_card_require_max
		UISubState.UISubState_SelectCards_StrikeGauge, UISubState.UISubState_SelectCards_Exceed, UISubState.UISubState_SelectCards_BoostCancel:
			return in_gauge and len(selected_cards) < select_card_require_max
		UISubState.UISubState_SelectCards_MoveActionGenerateForce, UISubState.UISubState_SelectCards_ForceForChange, UISubState.UISubState_SelectCards_ForceForArmor:
			return in_gauge or in_hand
		UISubState.UISubState_SelectCards_GaugeForArmor:
			return in_gauge
		UISubState.UISubState_SelectCards_StrikeForce:
			return in_gauge or in_hand
		UISubState.UISubState_SelectCards_ChooseBoostsToSustain:
			return in_player_boosts and not is_sustained and len(selected_cards) < select_card_require_max
		UISubState.UISubState_SelectCards_CharacterAction_Force:
			var new_force = game_wrapper.get_card_database().get_card_force_value(card.card_id)
			return (in_gauge or in_hand) and can_selected_cards_pay_force(select_card_require_force, new_force)
		UISubState.UISubState_SelectCards_CharacterAction_Gauge:
			return in_gauge and len(selected_cards) < select_card_require_max
		UISubState.UISubState_SelectCards_ForceForEffect:
			var force_selected = get_force_in_selected_cards()
			var new_force = game_wrapper.get_card_database().get_card_force_value(card.card_id)
			var total_force = force_selected + new_force
			var within_force_limit = select_card_up_to_force == -1 or total_force <= select_card_up_to_force
			return (in_gauge or in_hand) and (within_force_limit or can_selected_cards_pay_force(select_card_up_to_force, new_force))
		UISubState.UISubState_SelectCards_GaugeForEffect:
			var valid_id = true
			if select_gauge_require_card_id:
				var card_db = game_wrapper.get_card_database()
				var logic_card = card_db.get_card(card.card_id)
				valid_id = logic_card.definition['id'] == select_gauge_require_card_id
			return in_gauge and valid_id and len(selected_cards) < select_card_require_max
		UISubState.UISubState_SelectCards_StrikeCard, UISubState.UISubState_SelectCards_StrikeResponseCard, UISubState.UISubState_SelectCards_OpponentSetsFirst_StrikeCard, UISubState.UISubState_SelectCards_OpponentSetsFirst_StrikeResponseCard, UISubState.UISubState_SelectCards_Mulligan:
			if in_player_boosts:
				var card_db = game_wrapper.get_card_database()
				var logic_card = card_db.get_card(card.card_id)
				return 'must_set_from_boost' in logic_card.definition and logic_card.definition['must_set_from_boost']
			return in_hand
		UISubState.UISubState_SelectCards_StrikeCard_FromGauge:
			return in_gauge
		UISubState.UISubState_SelectCards_StrikeCard_FromSealed:
			return in_sealed
		UISubState.UISubState_SelectCards_PlayBoost:
			var select_boost_valid_zones = select_boost_options['valid_zones']
			var select_boost_limitation = select_boost_options['limitation']
			var select_boost_ignore_costs = select_boost_options['ignore_costs']
			var valid_card = game_wrapper.can_player_boost(Enums.PlayerId.PlayerId_Player, card.card_id, select_boost_valid_zones, select_boost_limitation, select_boost_ignore_costs)
			return len(selected_cards) == 0 and valid_card
		UISubState.UISubState_SelectCards_ForceForBoost:
			return (in_gauge or in_hand) and selected_boost_to_pay_for != card.card_id
		UISubState.UISubState_SelectCards_DiscardContinuousBoost:
			if (in_player_boosts or (not game_wrapper.get_decision_info().limitation and in_opponent_boosts)) and len(selected_cards) < select_card_require_max:
				var card_db = game_wrapper.get_card_database()
				var logic_card = card_db.get_card(card.card_id)
				if 'cannot_discard' in logic_card.definition['boost'] and logic_card.definition['boost']['cannot_discard']:
					return false
				return true
			return false
		UISubState.UISubState_SelectCards_DiscardOpponentGauge:
			return in_opponent_gauge and len(selected_cards) < select_card_require_max
		UISubState.UISubState_SelectCards_DiscardFromReference:
			var in_appropriate_reference = in_opponent_reference
			if select_card_name_card_both_players:
				in_appropriate_reference = in_opponent_reference or in_player_reference
			return in_appropriate_reference and len(selected_cards) < select_card_require_max
		UISubState.UISubState_SelectCards_ChooseDiscardToDestination:
			var card_db = game_wrapper.get_card_database()
			var logic_card = card_db.get_card(card.card_id)
			var card_type = logic_card.definition['type']
			var limitation = game_wrapper.get_decision_info().limitation
			var source = game_wrapper.get_decision_info().source
			var meets_limitation = false
			match limitation:
				"normal":
					meets_limitation = card_type == "normal"
				"special":
					meets_limitation = card_type == "special"
				"ultra":
					meets_limitation = card_type == "ultra"
				"special/ultra":
					meets_limitation = card_type in ["special", "ultra"]
				"continuous":
					meets_limitation = logic_card.definition['boost']['boost_type'] == "continuous"
				_:
					meets_limitation = true
			var in_correct_source = false
			match source:
				"discard":
					in_correct_source = in_discard
				"sealed":
					in_correct_source = in_sealed
				"overdrive":
					in_correct_source = in_overdrive
				_:
					in_correct_source = false
			return in_correct_source and len(selected_cards) < select_card_require_max and meets_limitation
		UISubState.UISubState_SelectCards_ChooseFromTopdeck:
			return in_choice_zone and len(selected_cards) < select_card_require_max

func deselect_all_cards():
	for card in selected_cards:
		modify_card_selection(card, false)
	selected_cards = []

func modify_card_selection(card, selected):
	card.set_selected(selected)
	if card_popout_parent.get_child_count() > 0:
		var popout = card_popout_parent.get_child(0)
		popout.modify_card_selection(card.card_id, selected)

func on_card_clicked(card : CardBase):
	if observer_mode:
		return

	# If in selection mode, select/deselect card.
	# Otherwise, if picking turn action, toggle quick action selection.
	if ui_state == UIState.UIState_SelectCards or ui_state == UIState.UIState_PickTurnAction:
		var index = -1
		for i in range(len(selected_cards)):
			if selected_cards[i].card_id == card.card_id:
				index = i
				break

		if index == -1:
			# Selected, add to cards.
			if can_select_card(card):
				selected_cards.append(card)
				modify_card_selection(card, true)
		else:
			# Deselect
			selected_cards.remove_at(index)
			modify_card_selection(card, false)
		_update_buttons()

func _on_card_popout_card_clicked(card_id : int):
	var card = find_card_on_board(card_id)
	if card:
		on_card_clicked(card)

func sort_player_hand(hand_zone):
	# Only intended to be called for the player, not opponent.
	var sorted_nodes = hand_zone.get_children()
	sorted_nodes.sort_custom(
		# For descending order use > 0
		func(a: Node, b: Node):
			assert(a is CardBase)
			assert(b is CardBase)
			var card_a = a as CardBase
			var card_b = b as CardBase
			var sort_key_a = game_wrapper.get_card_database().get_card_sort_key(card_a.card_id)
			var sort_key_b = game_wrapper.get_card_database().get_card_sort_key(card_b.card_id)
			return sort_key_a < sort_key_b
	)

	for node in hand_zone.get_children():
		hand_zone.remove_child(node)

	for node in sorted_nodes:
		hand_zone.add_child(node)

func layout_player_hand(is_player : bool):
	var hand_zone = get_hand_zone(is_player)
	var num_cards = len(hand_zone.get_children())
	if num_cards > 0:
		if is_player:
			update_eyes_on_hand_icons()
			if num_cards == 1:
				var card : CardBase = hand_zone.get_child(0)
				var angle = deg_to_rad(90)
				var ovalAngleVector = Vector2(HorizontalRadius * cos(angle), -VerticalRadius * sin(angle))
				var dst_pos = CenterCardOval + ovalAngleVector
				card.set_resting_position(dst_pos, 0)
			else:
				sort_player_hand(hand_zone)
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

func update_eyes_on_hand_icons():
	if observer_mode:
		return
	var public_hand_info = game_wrapper.get_player_public_hand_info(Enums.PlayerId.PlayerId_Player)
	var all_player_cards = get_all_player_cards()
	for card in all_player_cards:
		# These are cards in hand, so the ids are correct.
		var id = card.card_id
		var logic_card = game_wrapper.get_card_database().get_card(id)
		var card_str_id = logic_card.definition['id']
		var known_count = 0
		var questionable_count = 0
		var on_topdeck = false
		# Only update shows the icons on the cards in hand.
		if game_wrapper.is_card_in_hand(Enums.PlayerId.PlayerId_Player, id):
			if card_str_id in public_hand_info['known']:
				known_count = public_hand_info['known'][card_str_id]
			if card_str_id in public_hand_info['questionable']:
				questionable_count = public_hand_info['questionable'][card_str_id]
			on_topdeck = card_str_id == public_hand_info['topdeck']
		card.update_hand_icons(known_count, questionable_count, on_topdeck, true)

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
		Enums.EventType.EventType_BlockMovement:
			notice_text = "Movement Blocked!"
		Enums.EventType.EventType_Strike_ArmorUp:
			notice_text = "+%d Armor" % number
		Enums.EventType.EventType_Strike_AttackDoesNotHit:
			notice_text = "Miss!"
		Enums.EventType.EventType_CharacterAction:
			notice_text = "Character Action"
		Enums.EventType.EventType_Strike_Critical:
			notice_text = "Critical!"
		Enums.EventType.EventType_Strike_DodgeAttacks:
			notice_text = "Dodge Attacks!"
		Enums.EventType.EventType_Strike_DodgeAttacksAtRange:
			if number == event['extra_info']:
				notice_text = "Dodge at range %s" % number
			else:
				notice_text = "Dodge at range %s-%s" % [number, event['extra_info']]
			if event['extra_info2']:
				notice_text += " from %s" % event['extra_info2']
		Enums.EventType.EventType_Strike_DodgeFromOppositeBuddy:
			notice_text = "Dodge from behind %s" % [event['extra_info']]
		Enums.EventType.EventType_Strike_ExUp:
			notice_text = "EX Strike!"
		Enums.EventType.EventType_Strike_GainAdvantage:
			notice_text = "+Advantage!"
		Enums.EventType.EventType_Strike_GuardUp:
			var text = ""
			if number > 0:
				text += "+"
			notice_text = "%s%s Guard" % [text, number]
		Enums.EventType.EventType_Strike_IgnoredPushPull:
			notice_text = "Unmoved!"
		Enums.EventType.EventType_Strike_Miss:
			notice_text = "Miss!"
		Enums.EventType.EventType_Strike_OpponentCantMovePast:
			var movement_text = "Advance"
			if event['extra_info']:
				movement_text = "Movement through %s" % event['extra_info']
			notice_text = "Blocking %s!" % movement_text
		Enums.EventType.EventType_Strike_PowerUp:
			var text = ""
			if number > 0:
				text += "+"
			notice_text = "%s%s Power" % [text, number]
		Enums.EventType.EventType_Strike_RandomGaugeStrike:
			notice_text = "Strike From Gauge!"
		Enums.EventType.EventType_Strike_RangeUp:
			var number2 = event['extra_info']
			var firstplus = ""
			if number >= 0:
				firstplus = "+"
			var secondplus = ""
			if number2 >= 0:
				secondplus = "+"
			if number == number2:
				notice_text = "%s%s Range" % [firstplus, number]
			else:
				notice_text = "%s%s - %s%s Range" % [firstplus, number, secondplus, number2]
		Enums.EventType.EventType_Strike_SetX:
			notice_text = "X is %s" % number
		Enums.EventType.EventType_Strike_SpeedUp:
			var text = ""
			if number > 0:
				text += "+"
			notice_text = "%s%s Speed" % [text, number]
		Enums.EventType.EventType_Strike_Stun:
			notice_text = "Stunned!"
		Enums.EventType.EventType_Strike_Stun_Immunity:
			notice_text = "Stun Immune!"
		Enums.EventType.EventType_SustainBoost:
			notice_text = "Sustain Boost"
		Enums.EventType.EventType_Strike_WildStrike:
			notice_text = "Wild Swing!"
		Enums.EventType.EventType_SwapSealedAndDeck:
			notice_text = "Swap Sealed and Deck"

	spawn_damage_popup(notice_text, player)
	return SmallNoticeDelay

func _set_card_bonus(card_id, bonus, value=true):
	var card = find_card_on_board(card_id)
	match bonus:
		"ex":
			card.set_ex(value)
		"wild":
			card.set_wild(value)
		"critical":
			card.set_crit(value)
		_:
			assert(false, "Set card bonus for unknown effect")

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

func _on_end_of_strike():
	player_bonus_panel.visible = false
	opponent_bonus_panel.visible = false
	for zone in $AllCards.get_children():
		if zone is Node2D:
			for card in zone.get_children():
				card.set_backlight_visible(false)
				card.set_stun(false)
				card.clear_bonuses()

func _on_advance_turn():
	var active_player : Enums.PlayerId = game_wrapper.get_active_player()
	var is_local_player_active = active_player == Enums.PlayerId.PlayerId_Player
	$PlayerLife.set_turn_indicator(is_local_player_active)
	$OpponentLife.set_turn_indicator(not is_local_player_active)

	if is_local_player_active and not observer_mode:
		change_ui_state(UIState.UIState_PickTurnAction, UISubState.UISubState_None)
		deselect_all_cards()
		close_popout()
	else:
		change_ui_state(UIState.UIState_WaitingOnOpponent, UISubState.UISubState_None)

	player_bonus_panel.visible = false
	opponent_bonus_panel.visible = false
	prepared_character_action_data = {}

	spawn_damage_popup("Ready!", active_player)
	return SmallNoticeDelay

func _on_post_boost_action(event):
	var player = event['event_player']
	spawn_damage_popup("Bonus Action", player)
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		change_ui_state(UIState.UIState_PickTurnAction, UISubState.UISubState_None)
		deselect_all_cards()
		close_popout()
	else:
		ai_take_turn()
	return SmallNoticeDelay

func _on_boost_cancel_decision(event):
	var player = event['event_player']
	var gauge_cost = event['number']
	spawn_damage_popup("Cancel?", player)
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
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
	make_card_revealed(card)
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
	var decision_info = game_wrapper.get_decision_info()
	var limitation = decision_info.limitation
	var can_pass = decision_info.can_pass
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		# Show the boost window.
		var instruction_qualifier = "a"
		if limitation == "mine" or game_wrapper.get_player_discardable_boost_count(player) == 0:
			instruction_qualifier = "your"
		selected_cards = []
		select_card_require_min = 1
		select_card_require_max = 1
		var action_word = ""
		var extra_info = ""
		match decision_info.destination:
			"owner_hand":
				action_word = "Return"
				extra_info = " to its owner's hand."
			_:
				action_word = "Discard"
		var instruction_text = "%s %s continuous boost%s." % [action_word, instruction_qualifier, extra_info]
		popout_instruction_info = {
			"popout_type": CardPopoutType.CardPopoutType_BoostOpponent,
			"instruction_text": instruction_text,
			"ok_text": "OK",
			"cancel_text": "Pass",
			"ok_enabled": true,
			"cancel_visible": can_pass,
		}
		enable_instructions_ui(instruction_text, true, can_pass, false)
		if limitation == "mine" or game_wrapper.get_player_discardable_boost_count(Enums.PlayerId.PlayerId_Opponent) == 0:
			_on_player_boost_zone_clicked_zone()
		else:
			_on_opponent_boost_zone_clicked_zone()
		change_ui_state(UIState.UIState_SelectCards, UISubState.UISubState_SelectCards_DiscardContinuousBoost)
	else:
		ai_discard_continuous_boost(limitation, can_pass)

func _on_discard_opponent_gauge(event):
	var player = event['event_player']
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		# Show the gauge window.
		_on_opponent_gauge_gauge_clicked()
		selected_cards = []
		select_card_require_min = 1
		select_card_require_max = 1
		var cancel_allowed = false
		popout_instruction_info = {
			"popout_type": CardPopoutType.CardPopoutType_GaugeOpponent,
			"instruction_text": "Discard a card from opponent's gauge.",
			"ok_text": "OK",
			"cancel_text": "",
			"ok_enabled": true,
			"cancel_visible": false,
		}
		enable_instructions_ui("Select a gauge card to discard.", true, cancel_allowed, false)

		change_ui_state(UIState.UIState_SelectCards, UISubState.UISubState_SelectCards_DiscardOpponentGauge)
	else:
		ai_discard_opponent_gauge()

func _on_name_opponent_card_begin(event):
	var player = event['event_player']
	spawn_damage_popup("Naming Card", player)
	var normal_only = event['event_type'] == Enums.EventType.EventType_ReadingNormal or event['event_type'] == Enums.EventType.EventType_Boost_Sidestep
	var can_name_fake_card = event['event_type'] == Enums.EventType.EventType_Boost_NameCardOpponentDiscards
	if game_wrapper.get_decision_info().bonus_effect:
		select_card_name_card_both_players = game_wrapper.get_decision_info().bonus_effect
	else:
		select_card_name_card_both_players = false
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		var instruction_text = "Name an opponent card."
		if select_card_name_card_both_players:
			instruction_text = "Name a card."

		selected_cards = []
		select_card_require_min = 1
		select_card_require_max = 1
		var cancel_allowed = can_name_fake_card
		popout_instruction_info = {
			"popout_type": CardPopoutType.CardPopoutType_ReferenceOpponent,
			"instruction_text": instruction_text,
			"ok_text": "OK",
			"cancel_text": "Reveal Hand",
			"ok_enabled": true,
			"cancel_visible": cancel_allowed,
			"normal_only": normal_only,
		}
		enable_instructions_ui("Name opponent card.", true, cancel_allowed, false)
		change_ui_state(UIState.UIState_SelectCards, UISubState.UISubState_SelectCards_DiscardFromReference)
		_on_opponent_reference_button_pressed(false, true)
	else:
		ai_name_opponent_card(normal_only, select_card_name_card_both_players)
	return SmallNoticeDelay

func _on_boost_played(event):
	var player = event['event_player']
	var card = find_card_on_board(event['number'])
	make_card_revealed(card)
	var target_zone = $PlayerStrike/StrikeZone
	var is_player = player == Enums.PlayerId.PlayerId_Player
	if not is_player:
		target_zone = $OpponentStrike/StrikeZone
	_move_card_to_strike_area(card, target_zone, $AllCards/Striking, is_player, false)
	spawn_damage_popup("Boost!", player)
	return BoostDelay

func _on_choose_card_hand_to_gauge(event):
	var player = event['event_player']
	var min_amount = event['number']
	var max_amount = event['extra_info']
	select_card_destination = game_wrapper.get_decision_info().destination
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		if prepared_character_action_data_available('gauge_from_hand'):
			var selected_card_ids = prepared_character_action_data['hand_to_gauge_cards']
			var success = game_wrapper.submit_card_from_hand_to_gauge(Enums.PlayerId.PlayerId_Player, selected_card_ids)
			if success:
				prepared_character_action_data = {}
				change_ui_state(UIState.UIState_WaitForGameServer)
		else:
			begin_discard_cards_selection(min_amount, max_amount, UISubState.UISubState_SelectCards_DiscardCardsToGauge, false)
	else:
		ai_choose_card_hand_to_gauge(min_amount, max_amount)

func _on_choose_from_boosts(event):
	var player = event['event_player']
	select_card_require_min = game_wrapper.get_decision_info().amount_min
	select_card_require_max = game_wrapper.get_decision_info().amount
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		_on_player_boost_zone_clicked_zone()
		selected_cards = []
		var cancel_allowed = false
		if select_card_require_min == 0:
			cancel_allowed = true
		enable_instructions_ui("", true, cancel_allowed)
		change_ui_state(UIState.UIState_SelectCards, UISubState.UISubState_SelectCards_ChooseBoostsToSustain)
	else:
		ai_choose_from_boosts(select_card_require_max)

func _on_choose_from_discard(event):
	var player = event['event_player']
	var limitation = game_wrapper.get_decision_info().limitation
	var destination = game_wrapper.get_decision_info().destination
	var source = game_wrapper.get_decision_info().source
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		# Show the correct popout window.
		if source == "discard":
			_on_player_discard_button_pressed()
		elif source == "sealed":
			_on_player_sealed_clicked()
		elif source == "overdrive":
			_on_player_overdrive_gauge_clicked()
		selected_cards = []
		select_card_require_min = game_wrapper.get_decision_info().amount_min
		select_card_require_max = game_wrapper.get_decision_info().amount
		if limitation:
			limitation = limitation + " "
		var card_select_count_str = "1 %scard" % limitation
		if select_card_require_min == select_card_require_max and select_card_require_min > 1:
			card_select_count_str = "%s %scards" % [select_card_require_min, limitation]
		elif select_card_require_max > 1:
			card_select_count_str = "%s-%s %scards" % [select_card_require_min, select_card_require_max, limitation]
		var instruction = "Select %s to move to %s." % [card_select_count_str, destination]
		if destination == "lightningrod_any_space":
			instruction = "Select a card from your discard pile to place as a Lightning Rod."
		var popout_type = CardPopoutType.CardPopoutType_DiscardPlayer
		if source == "sealed":
			popout_type = CardPopoutType.CardPopoutType_SealedPlayer
		elif source == "overdrive":
			popout_type = CardPopoutType.CardPopoutType_OverdrivePlayer
		var action = game_wrapper.get_decision_info().action
		if action and action == "overdrive_action":
			# Special text instruction fo rthe overdrive effect.
			instruction = "Overdrive Effect:\nSelect a card from your Overdrive to discard."
		popout_instruction_info = {
			"popout_type": popout_type,
			"instruction_text": instruction,
			"ok_text": "OK",
			"cancel_text": "",
			"ok_enabled": true,
			"cancel_visible": false,
		}
		var cancel_allowed = false
		if select_card_require_min == 0:
			cancel_allowed = true

		enable_instructions_ui(instruction, true, cancel_allowed)
		change_ui_state(UIState.UIState_SelectCards, UISubState.UISubState_SelectCards_ChooseDiscardToDestination)
	else:
		ai_choose_from_discard(game_wrapper.get_decision_info().amount)

func _on_choose_from_topdeck(event):
	var player = event['event_player']
	var decision_info = game_wrapper.get_decision_info()
	var action_choices = decision_info.action
	var can_pass = decision_info.can_pass
	var look_amount = decision_info.amount
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		begin_choose_from_topdeck(action_choices, look_amount, can_pass)
	else:
		ai_choose_from_topdeck(action_choices, look_amount, can_pass)

func get_string_for_action_choice(choice):
	match choice:
		"strike":
			return "Strike"
		"boost":
			return "Boost"
		"add_to_hand":
			return "Add to Hand"
		"add_to_gauge":
			return "Add to Gauge"
		"add_to_sealed":
			return "Add to Sealed"
		"add_to_overdrive":
			return "Add to Overdrive"
		"add_to_topdeck_under":
			return "Add to deck 2nd from top"
		"return_to_topdeck":
			return "Return to top of deck"
	return ""

func begin_choose_from_topdeck(action_choices, look_amount, can_pass):

	var card_ids = game_wrapper.get_player_top_cards(Enums.PlayerId.PlayerId_Player, look_amount)
	for card_id in card_ids:
		var card = find_card_on_board(card_id)
		card.flip_card_to_front(true)
		reparent_to_zone(card, $AllCards/ChoiceZone)

	var button1 = get_string_for_action_choice(action_choices[0])
	var button2 = ""
	if action_choices.size() > 1:
		button2 = get_string_for_action_choice(action_choices[1])

	selected_cards = []
	select_card_require_min = 1
	select_card_require_max = 1
	var cancel_allowed = can_pass
	popout_instruction_info = {
		"popout_type": CardPopoutType.CardPopoutType_ChoiceZone,
		"instruction_text": "Choose a card:",
		"ok_text": button1,
		"ok2_text": button2,
		"cancel_text": "Pass",
		"ok_enabled": true,
		"cancel_visible": can_pass,
	}
	enable_instructions_ui("Choose a card:", false, cancel_allowed, false)
	_on_choice_popout_show_button_pressed()

	change_ui_state(UIState.UIState_SelectCards, UISubState.UISubState_SelectCards_ChooseFromTopdeck)

func _on_discard_event(event):
	var player = event['event_player']
	var discard_id = event['number']
	var from_top = event['extra_info']
	var card = find_card_on_board(discard_id)
	if player == Enums.PlayerId.PlayerId_Player:
		discard_card(card, $PlayerDeck/Discard, $AllCards/PlayerDiscards, true, from_top)
	else:
		discard_card(card, $OpponentDeck/Discard, $AllCards/OpponentDiscards, false, from_top)
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

func get_all_player_cards() -> Array:
	var found_cards = []
	found_cards += $AllCards/PlayerBoosts.get_children()
	found_cards += $AllCards/PlayerDeck.get_children()
	found_cards += $AllCards/PlayerDiscards.get_children()
	found_cards += $AllCards/PlayerGauge.get_children()
	found_cards += $AllCards/PlayerHand.get_children()
	found_cards += $AllCards/PlayerOverdrive.get_children()
	found_cards += $AllCards/PlayerSealed.get_children()
	found_cards += $AllCards/Striking.get_children()
	return found_cards

func reparent_to_zone(card, zone, from_top : int = 0):
	card.get_parent().remove_child(card)
	zone.add_child(card)
	if from_top > 0:
		# Use negative because this is from the end.
		# Add 1 since -1 would just be on the end where it already is.
		from_top += 1
		zone.move_child(card, -from_top)

func _on_add_to_gauge(event):
	var player = event['event_player']
	var card = find_card_on_board(event['number'])
	make_card_revealed(card)
	var gauge_panel = $PlayerZones/PlayerGauge
	var gauge_card_loc = $AllCards/PlayerGauge
	if player == Enums.PlayerId.PlayerId_Opponent:
		gauge_panel = $OpponentZones/OpponentGauge
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

func _on_add_to_sealed(event):
	var player = event['event_player']
	var card = find_card_on_board(event['number'])
	var sealed_panel = $PlayerZones/PlayerSealed
	var sealed_card_loc = $AllCards/PlayerSealed
	var keep_hidden = false
	var is_zone_secret = game_wrapper.is_player_sealed_area_secret(player)
	if player == Enums.PlayerId.PlayerId_Opponent:
		sealed_panel = $OpponentZones/OpponentSealed
		sealed_card_loc = $AllCards/OpponentSealed
		keep_hidden = game_wrapper.is_player_sealed_area_secret(player)

	if observer_mode:
		keep_hidden = is_zone_secret

	card.flip_card_to_front(not keep_hidden)
	var pos = sealed_panel.get_center_pos()
	var is_player = player == Enums.PlayerId.PlayerId_Player
	if card.get_parent() == $AllCards/PlayerDeck or card.get_parent() == $AllCards/OpponentDeck:
		card.set_card_and_focus(get_deck_button_position(is_player), null, null)
	card.discard_to(pos, CardBase.CardState.CardState_InGauge)
	reparent_to_zone(card, sealed_card_loc)
	layout_player_hand(is_player)

	var display_popup = true
	if 'extra_info' in event:
		display_popup = event['extra_info']
	if display_popup:
		spawn_damage_popup("+ Sealed", player)
		return SmallNoticeDelay
	return 0

func _on_add_to_overdrive(event):
	var player = event['event_player']
	var card = find_card_on_board(event['number'])
	make_card_revealed(card)
	var overdrive_panel = $PlayerZones/PlayerOverdrive
	var overdrive_card_loc = $AllCards/PlayerOverdrive
	if player == Enums.PlayerId.PlayerId_Opponent:
		overdrive_panel = $OpponentZones/OpponentOverdrive
		overdrive_card_loc = $AllCards/OpponentOverdrive

	var pos = overdrive_panel.get_center_pos()
	var is_player = player == Enums.PlayerId.PlayerId_Player
	if card.get_parent() == $AllCards/PlayerDeck or card.get_parent() == $AllCards/OpponentDeck:
		card.set_card_and_focus(get_deck_button_position(is_player), null, null)
	card.discard_to(pos, CardBase.CardState.CardState_InGauge)
	reparent_to_zone(card, overdrive_card_loc)
	layout_player_hand(is_player)
	spawn_damage_popup("+ Overdrive", player)
	return SmallNoticeDelay

func get_deck_zone(is_player : bool):
	if is_player:
		return $AllCards/PlayerDeck
	else:
		return $AllCards/OpponentDeck

func get_set_aside_zone(is_player : bool):
	if is_player:
		return $AllCards/PlayerSetAside
	else:
		return $AllCards/OpponentSetAside

func _on_add_to_deck(event):
	var player = event['event_player']
	var is_player = player == Enums.PlayerId.PlayerId_Player
	var card = find_card_on_board(event['number'])
	card.flip_card_to_front(false)
	var deck_position = get_deck_button_position(is_player)
	card.discard_to(deck_position, CardBase.CardState.CardState_InDeck)
	reparent_to_zone(card, get_deck_zone(is_player))
	layout_player_hand(is_player)

func _on_set_card_aside(event):
	var player = event['event_player']
	var is_player = player == Enums.PlayerId.PlayerId_Player
	var card = find_card_on_board(event['number'])
	var deck_position = get_deck_button_position(is_player)
	card.discard_to(deck_position, CardBase.CardState.CardState_InDeck)
	reparent_to_zone(card, get_set_aside_zone(is_player))
	layout_player_hand(is_player)

func _on_add_to_hand(event):
	var player = event['event_player']
	var is_player = player == Enums.PlayerId.PlayerId_Player
	var card = find_card_on_board(event['number'])
	card.reset()
	var reveal = is_player
	if observer_mode:
		reveal = false
	card.flip_card_to_front(reveal)
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
		if 'exceed_animation' in player_deck:
			$PlayerCharacter.set_exceed(true, player_deck['exceed_animation'])
			move_character_to_arena_square($PlayerCharacter, game_wrapper.get_player_location(Enums.PlayerId.PlayerId_Player), true, Character.CharacterAnim.CharacterAnim_None)
		else:
			$PlayerCharacter.set_exceed(true)
		player_character_card.exceed(true)
		player_buddy_character_card.exceed(true)

	else:
		if 'exceed_animation' in opponent_deck:
			$OpponentCharacter.set_exceed(true, opponent_deck['exceed_animation'])
			move_character_to_arena_square($OpponentCharacter, game_wrapper.get_player_location(Enums.PlayerId.PlayerId_Opponent), true, Character.CharacterAnim.CharacterAnim_None)
		else:
			$OpponentCharacter.set_exceed(true)
		opponent_character_card.exceed(true)
		opponent_buddy_character_card.exceed(true)

	spawn_damage_popup("Exceed!", player)
	return SmallNoticeDelay

func _on_exceed_revert_event(event):
	var player = event['event_player']
	if player == Enums.PlayerId.PlayerId_Player:
		if 'exceed_animation' in player_deck:
			$PlayerCharacter.set_exceed(true, player_deck['id'])
			move_character_to_arena_square($PlayerCharacter, game_wrapper.get_player_location(Enums.PlayerId.PlayerId_Player), true, Character.CharacterAnim.CharacterAnim_None)
		else:
			$PlayerCharacter.set_exceed(false)
		player_character_card.exceed(false)
		player_buddy_character_card.exceed(false)

	else:
		if 'exceed_animation' in opponent_deck:
			$OpponentCharacter.set_exceed(true, opponent_deck['id'])
			move_character_to_arena_square($OpponentCharacter, game_wrapper.get_player_location(Enums.PlayerId.PlayerId_Opponent), true, Character.CharacterAnim.CharacterAnim_None)
		else:
			$OpponentCharacter.set_exceed(false)
		opponent_character_card.exceed(false)
		opponent_buddy_character_card.exceed(false)

	spawn_damage_popup("Revert!", player)
	return SmallNoticeDelay

func _on_become_wide(event):
	var player = event['event_player']
	var character_object
	var deck_def
	if player == Enums.PlayerId.PlayerId_Player:
		character_object = $PlayerCharacter
		deck_def = player_deck
	else:
		character_object = $OpponentCharacter
		deck_def = opponent_deck

	character_object.is_wide = true
	if 'wide_animation' in deck_def:
		character_object.load_character(deck_def['wide_animation'])

		var parent = character_object.get_parent()
		var target_idx = parent.get_children().find($WideCharacterMarker)
		assert(target_idx != -1)
		parent.move_child(character_object, target_idx)

		move_character_to_arena_square(character_object, game_wrapper.get_player_location(player), true, Character.CharacterAnim.CharacterAnim_None)
		update_arena_squares()

	var popup_text = "Expand"
	if event['extra_info']:
		popup_text = event['extra_info']
	spawn_damage_popup("%s!" % popup_text, player)
	return SmallNoticeDelay

func _on_force_start_boost(event):
	var player = event['event_player']
	var valid_zones = event['extra_info']
	var limitation = event['extra_info2']
	var ignore_costs = event['extra_info3'] or false

	spawn_damage_popup("Boost!", player)
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		if prepared_character_action_data_available('boost_from_gauge'):
			var boost_card = prepared_character_action_data['boost_card']
			var boost_force = prepared_character_action_data['boost_force']
			var success = game_wrapper.submit_boost(Enums.PlayerId.PlayerId_Player, boost_card, boost_force, use_free_force)
			if success:
				prepared_character_action_data = {}
				change_ui_state(UIState.UIState_WaitForGameServer)
		else:
			begin_boost_choosing(false, valid_zones, limitation, ignore_costs)
	else:
		ai_do_boost(valid_zones, limitation, ignore_costs)
	return SmallNoticeDelay

func _on_force_start_strike(event):
	var player = event['event_player']
	var disable_wild_swing = false
	var disable_ex = false
	if event['extra_info']: #not null
		disable_wild_swing = event['extra_info']
	if event['extra_info2']:
		disable_ex = event['extra_info2']
	spawn_damage_popup("Strike!", player)
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		if prepared_character_action_data_available('strike'):
			var success = false
			if 'wild_swing' in prepared_character_action_data and prepared_character_action_data['wild_swing']:
				success = game_wrapper.submit_strike(Enums.PlayerId.PlayerId_Player, -1, true, -1)
			else:
				var card_id = prepared_character_action_data['card_id']
				var ex_card_id = prepared_character_action_data['ex_card_id']
				success = game_wrapper.submit_strike(Enums.PlayerId.PlayerId_Player, card_id, false, ex_card_id)
			if success:
				prepared_character_action_data = {}
				change_ui_state(UIState.UIState_WaitForGameServer)
		else:
			begin_strike_choosing(false, false, false, disable_wild_swing, disable_ex)
	else:
		ai_forced_strike(disable_wild_swing, disable_ex)
	return SmallNoticeDelay

func _on_strike_from_gauge(event):
	var player = event['event_player']
	spawn_damage_popup("Strike!", player)

	var decision_info = game_wrapper.get_decision_info()
	var source = decision_info.source
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		begin_gauge_strike_choosing(false, false, source)
	else:
		ai_strike_from_gauge(source)
	return SmallNoticeDelay

func _on_strike_opponent_sets_first(event):
	var player = event['event_player']
	spawn_damage_popup("Strike!", player)
	if not observer_mode:
		game_wrapper.submit_strike(player, -1, false, -1, true)
	return SmallNoticeDelay

func _on_strike_opponent_sets_first_defender_set(event):
	var player = event['event_player']
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		begin_strike_choosing(false, false, true)
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
		if not observer_mode:
			game_wrapper.submit_match_result(player_clock_remaining, opponent_clock_remaining)

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
	if active_player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		begin_discard_cards_selection(event['number'], event['number'],UISubState.UISubState_SelectCards_DiscardCards)
	else:
		# AI or other player wait
		ai_discard(event)

func _on_choose_to_discard(event, informative_only : bool):
	var player = event['event_player']
	var amount = event['number']
	var decision_info = game_wrapper.get_decision_info()
	var can_pass = decision_info.can_pass
	if informative_only or not can_pass:
		if not decision_info.destination in ["reveal", "sealed", "opponent_overdrive", "lightningrod_any_space"]:
			var amount_string = "Forced Discard %s" % str(amount)
			if amount == -1:
				amount_string = "Discard Cards"
			spawn_damage_popup(amount_string, player)
	if not informative_only:
		var limitation = decision_info.limitation
		if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
			if prepared_character_action_data_available("self_discard_choose"):
				var discard_ids = prepared_character_action_data['discard_ids']
				var success = game_wrapper.submit_choose_to_discard(Enums.PlayerId.PlayerId_Player, discard_ids)
				if success:
					prepared_character_action_data = {}
					change_ui_state(UIState.UIState_WaitForGameServer)
			else:
				var min_amount = amount
				var max_amount = amount
				if amount == -1:
					min_amount = 0
					max_amount = game_wrapper.get_player_hand_size(player)
				begin_discard_cards_selection(min_amount, max_amount, UISubState.UISubState_SelectCards_DiscardCards_Choose, can_pass)
		else:
			# AI or other player wait
			ai_choose_to_discard(amount, limitation, can_pass)
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

	if new_state == UIState.UIState_WaitingOnOpponent or new_state == UIState.UIState_WaitForGameServer:
		show_thinking_spinner_in = -1
		current_clock_user = Enums.PlayerId.PlayerId_Unassigned
		clock_delay_remaining = GameTimerClockServerDelay
	elif new_state == UIState.UIState_PlayingAnimation:
		current_clock_user = Enums.PlayerId.PlayerId_Unassigned
		clock_delay_remaining = GameTimerClockServerDelay
	else:
		current_clock_user = Enums.PlayerId.PlayerId_Player

func set_instructions(text):
	current_instruction_text = text

func update_discard_selection_message_choose():
	var decision_info = game_wrapper.get_decision_info()
	var destination = decision_info.destination
	if preparing_character_action:
		destination = prepared_character_action_data['destination']
	var num_remaining = select_card_require_min - len(selected_cards)
	if select_card_require_min == 0:
		num_remaining = select_card_require_max - len(selected_cards)
	var bonus = ""
	if decision_info.bonus_effect and not preparing_character_action:
		var effect_text = CardDefinitions.get_effect_text(decision_info.bonus_effect, false, false, false, "")
		bonus = "\nfor %s" % effect_text
	if destination == "play_attack":
		set_instructions("Select a card from your hand to move to play as an extra attack.")
	else:
		var optional_string = ""
		if select_card_require_min == 0:
			optional_string = "up to "
		if decision_info.limitation and not preparing_character_action:
			if decision_info.limitation == "from_array":
				set_instructions("Select %s%s more card(s) that %s from your hand to move to %s." % [optional_string, num_remaining, decision_info.extra_info, destination])
			else:
				set_instructions("Select %s%s more %s card(s) from your hand to move to %s%s." % [optional_string, num_remaining, decision_info.limitation, destination, bonus])
		else:
			set_instructions("Select %s%s more card(s) from your hand to move to %s%s." % [optional_string, num_remaining, destination, bonus])

func update_discard_selection_message():
	var num_remaining = select_card_require_min - len(selected_cards)
	set_instructions("Select %s more card(s) from your hand to discard." % num_remaining)

func update_sustain_selection_message():
	if select_card_require_min == select_card_require_max:
		var num_remaining = select_card_require_min - len(selected_cards)
		set_instructions("Select %s more card(s) from your boosts to sustain." % num_remaining)
	else:
		var num_remaining = select_card_require_max - len(selected_cards)
		set_instructions("Select up to %s more card(s) from your boosts to sustain." % [num_remaining])

func update_discard_to_gauge_selection_message():
	var phrase = "in your gauge"
	if select_card_destination == "topdeck":
		phrase = "on top of your deck"
	if select_card_destination == "deck":
		phrase = "into your deck"
	if preparing_character_action:
		phrase += " for %s" % prepared_character_action_data['action_name']
	if select_card_require_min == select_card_require_max:
		var num_remaining = select_card_require_min - len(selected_cards)
		set_instructions("Select %s more card(s) from your hand to put %s." % [num_remaining, phrase])
	else:
		var num_remaining = select_card_require_max - len(selected_cards)
		set_instructions("Select up to %s more card(s) from your hand to put %s." % [num_remaining, phrase])

func get_gauge_generated():
	var gauge_from_free_bonus = game_wrapper.get_player_free_gauge(Enums.PlayerId.PlayerId_Player)
	var gauge_generated = min(gauge_from_free_bonus, select_card_require_max)
	gauge_generated += len(selected_cards)
	return gauge_generated

func update_gauge_selection_message():
	if ui_sub_state == UISubState.UISubState_SelectCards_GaugeForArmor:
		var gauge_generated = get_gauge_generated()
		var force_generated_str = "%s gauge selected." % [gauge_generated]
		var damage_after_armor = max(0, force_for_armor_incoming_damage - force_for_armor_amount * gauge_generated)
		var ignore_armor_str = ""
		if force_for_armor_ignore_armor:
			damage_after_armor = force_for_armor_incoming_damage
			ignore_armor_str = "Armor Ignored! "
		set_instructions("Spend Gauge to generate force for +%s Armor each.\n%s\n%sYou will take %s damage." % [force_for_armor_amount, force_generated_str, ignore_armor_str, damage_after_armor])
	else:
		var num_remaining = select_card_require_min - get_gauge_generated()
		var discard_reminder = ""
		if enabled_reminder_text:
			discard_reminder = "\nThe last card selected will be on top of the discard pile."
		set_instructions("Select %s more gauge card(s).%s" % [num_remaining, discard_reminder])

func update_gauge_for_effect_message():
	var effect_str = ""
	var decision_effect = game_wrapper.get_decision_info().effect
	var to_hand = 'spent_cards_to_hand' in decision_effect and decision_effect['spent_cards_to_hand']
	var source_card_name = game_wrapper.get_card_database().get_card_name(game_wrapper.get_decision_info().choice_card_id)
	var gauge_name_str = "gauge"
	if select_gauge_require_card_name:
		gauge_name_str = "copies of %s from gauge" % select_gauge_require_card_name
	if decision_effect['per_gauge_effect']:
		var effect = decision_effect['per_gauge_effect']
		var effect_text = CardDefinitions.get_effect_text(effect, false, false, false, source_card_name)
		if to_hand:
			effect_str = "Return up to %s %s to your hand for %s per card." % [decision_effect['gauge_max'], gauge_name_str, effect_text]
		else:
			effect_str = "Spend up to %s %s for %s per card." % [decision_effect['gauge_max'], gauge_name_str, effect_text]
	elif decision_effect['overall_effect']:
		var effect = decision_effect['overall_effect']
		var effect_text = CardDefinitions.get_effect_text(effect, false, false, false, source_card_name)
		if to_hand:
			if effect_text:
				effect_str = "Return %s %s to your hand for %s." % [decision_effect['gauge_max'], gauge_name_str, effect_text]
			else:
				effect_str = "Return %s %s to your hand." % [decision_effect['gauge_max'], gauge_name_str]
		else:
			effect_str = "Spend %s %s for %s." % [decision_effect['gauge_max'], gauge_name_str, effect_text]
	var passive_bonus = get_gauge_generated() - len(selected_cards)
	if passive_bonus > 0:
		effect_str += "\n%s gauge from passive bonus." % passive_bonus
	effect_str += "\n%s gauge generated." % [get_gauge_generated()]
	# Strip tags that currently aren't supported.
	effect_str = effect_str.replace("[b]", "").replace("[/b]", "")
	set_instructions(effect_str)

func update_gauge_selection_for_cancel_message():
	var num_remaining = select_card_require_min - get_gauge_generated()
	set_instructions("Select %s gauge card to use Cancel." % num_remaining)

func get_force_in_selected_cards():
	var card_ids = []
	for card in selected_cards:
		card_ids.append(card.card_id)
	var reason = ""
	if ui_sub_state == UISubState.UISubState_SelectCards_ForceForChange:
		reason = "CHANGE_CARDS"
	return game_wrapper.get_player_force_for_cards(Enums.PlayerId.PlayerId_Player, card_ids, reason, treat_ultras_as_single_force, use_free_force)

func can_selected_cards_pay_force(force_cost : int, bonus_card_force_value : int = 0):
	var max_force_selected = game_wrapper.get_player_force_cost_reduction(Enums.PlayerId.PlayerId_Player)
	if use_free_force:
		max_force_selected += game_wrapper.get_player_free_force(Enums.PlayerId.PlayerId_Player)
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
	var force_from_free_bonus = game_wrapper.get_player_force_cost_reduction(Enums.PlayerId.PlayerId_Player)
	if use_free_force:
		force_from_free_bonus += game_wrapper.get_player_free_force(Enums.PlayerId.PlayerId_Player)
	var force_from_free_string = ""
	if force_from_free_bonus > 0:
		force_from_free_string = " (%s from passive bonus)" % force_from_free_bonus
	var force_generated_str = "%s force generated%s." % [force_selected, force_from_free_string]
	match ui_sub_state:
		UISubState.UISubState_SelectCards_MoveActionGenerateForce, UISubState.UISubState_SelectCards_CharacterAction_Force:
			set_instructions("Select cards to generate %s force.\n%s" % [select_card_require_force, force_generated_str])
		UISubState.UISubState_SelectCards_ForceForBoost:
			set_instructions("Select cards to generate %s force to pay for this boost.\n%s" % [select_card_require_force, force_generated_str])
		UISubState.UISubState_SelectCards_ForceForChange:
			set_instructions("Select cards to generate force to draw new cards.\n%s" % [force_generated_str])
		UISubState.UISubState_SelectCards_ForceForArmor:
			var damage_after_armor = max(0, force_for_armor_incoming_damage - force_for_armor_amount * force_selected)
			var ignore_armor_str = ""
			if force_for_armor_ignore_armor:
				damage_after_armor = force_for_armor_incoming_damage
				ignore_armor_str = "Armor Ignored! "
			set_instructions("Select cards to generate force for +%s Armor each.\n%s\n%sYou will take %s damage." % [force_for_armor_amount, force_generated_str, ignore_armor_str, damage_after_armor])
		UISubState.UISubState_SelectCards_StrikeForce:
			set_instructions("Select cards to generate %s force for this strike.\n%s" % [select_card_require_force, force_generated_str])
		UISubState.UISubState_SelectCards_ForceForEffect:
			var effect_str = ""
			var decision_effect = game_wrapper.get_decision_info().effect
			var source_card_name = game_wrapper.get_card_database().get_card_name(game_wrapper.get_decision_info().choice_card_id)
			if decision_effect['per_force_effect']:
				var effect = decision_effect['per_force_effect']
				var effect_text = CardDefinitions.get_effect_text(effect, false, false, false, source_card_name)
				var force_str = "up to %s" % decision_effect['force_max']
				if decision_effect['force_max'] == -1:
					force_str = "any amount of"
				var per_force_str = "force"
				if 'force_effect_interval' in decision_effect:
					per_force_str = "%s force" % decision_effect['force_effect_interval']
				effect_str = "Generate %s force for %s per %s." % [force_str, effect_text, per_force_str]
			elif decision_effect['overall_effect']:
				var effect = decision_effect['overall_effect']
				var effect_text = CardDefinitions.get_effect_text(effect, false, false, false, source_card_name)
				effect_str = "Generate %s force for %s." % [decision_effect['force_max'], effect_text]
			if 'force_discard_reminder' in decision_effect and decision_effect['force_discard_reminder']:
				effect_str += "\nThe last card(s) selected will be on top of the discard pile."
			effect_str += "\n%s" % [force_generated_str]
			set_instructions(effect_str)

func enable_instructions_ui(message, can_ok, can_cancel, can_wild_swing : bool = false, can_ex : bool = true, choices = [], show_number_picker : bool  = false, extra_choice_text = []):
	set_instructions(message)
	instructions_ok_allowed = can_ok
	instructions_cancel_allowed = can_cancel
	instructions_wild_swing_allowed = can_wild_swing
	instructions_ex_allowed = can_ex
	current_effect_choices = choices
	current_effect_extra_choice_text = extra_choice_text
	instructions_number_picker_min = -1
	instructions_number_picker_max = -1
	if show_number_picker:
		instructions_number_picker_min = game_wrapper.get_decision_info().amount_min
		instructions_number_picker_max = game_wrapper.get_decision_info().amount

func begin_discard_cards_selection(number_to_discard_min, number_to_discard_max, next_sub_state, can_cancel_always : bool = false):
	selected_cards = []
	select_card_require_min = number_to_discard_min
	select_card_require_max = number_to_discard_max
	var cancel_allowed = number_to_discard_min == 0 or can_cancel_always
	enable_instructions_ui("", true, cancel_allowed)
	change_ui_state(UIState.UIState_SelectCards, next_sub_state)

func begin_generate_force_selection(amount, can_cancel : bool = true, wild_swing_allowed : bool = false, ex_discard_order_checkbox : bool = false):
	# Show the gauge window.
	_on_player_gauge_gauge_clicked()
	treat_ultras_as_single_force = false
	discard_ex_first_for_strike = true
	use_free_force = game_wrapper.get_player_free_force(Enums.PlayerId.PlayerId_Player) > 0
	current_pay_costs_is_ex = ex_discard_order_checkbox
	action_menu.set_force_ultra_toggle(false)
	action_menu.set_discard_ex_first_toggle(true)
	action_menu.set_free_force_toggle(use_free_force)

	selected_cards = []
	select_card_require_force = amount
	enable_instructions_ui("", true, can_cancel, wild_swing_allowed)

	change_ui_state(UIState.UIState_SelectCards)

func begin_gauge_selection(amount : int, wild_swing_allowed : bool, sub_state : UISubState, enable_reminder : bool = false, ex_discard_order_checkbox : bool = false):
	# Show the gauge window.
	_on_player_gauge_gauge_clicked()
	selected_cards = []
	current_pay_costs_is_ex = ex_discard_order_checkbox
	discard_ex_first_for_strike = true
	action_menu.set_discard_ex_first_toggle(true)
	enabled_reminder_text = true if enable_reminder else false
	if amount != -1:
		select_card_require_min = amount
		select_card_require_max = amount
	var cancel_allowed = false
	match sub_state:
		UISubState.UISubState_SelectCards_Exceed, UISubState.UISubState_SelectCards_BoostCancel, UISubState.UISubState_SelectCards_CharacterAction_Gauge:
			cancel_allowed = true
		UISubState.UISubState_SelectCards_GaugeForEffect:
			cancel_allowed = select_card_require_min == 0
	enable_instructions_ui("", true, cancel_allowed, wild_swing_allowed)

	change_ui_state(UIState.UIState_SelectCards, sub_state)

func begin_effect_choice(choices, instruction_text : String, extra_choice_text, can_cancel = false):
	enable_instructions_ui(instruction_text, false, can_cancel, false, false, choices, false, extra_choice_text)
	change_ui_state(UIState.UIState_MakeChoice, UISubState.UISubState_None)

func begin_strike_choosing(strike_response : bool, cancel_allowed : bool,
		opponent_sets_first : bool = false, disable_wild_swing : bool = false, disable_ex : bool = false):
	selected_cards = []
	select_card_require_min = 1
	select_card_require_max = 1
	var can_cancel = cancel_allowed and not strike_response
	var character_action_str = ""
	if preparing_character_action:
		character_action_str = " using %s" % prepared_character_action_data['action_name']
	var dialogue = "Select a card to strike with%s." % character_action_str
	var cards_that_will_not_hit = game_wrapper.get_will_not_hit_card_names(Enums.PlayerId.PlayerId_Player)
	if cards_that_will_not_hit.size() > 0:
		for card in cards_that_will_not_hit:
			dialogue += "\n" + card + " will not hit."
	var plague_knight_discard_names = game_wrapper.get_plague_knight_discard_names(Enums.PlayerId.PlayerId_Opponent)
	if plague_knight_discard_names.size() > 0:
		for card in plague_knight_discard_names:
			dialogue += "\nPlague Knight discarded " + card +"."
	enable_instructions_ui(dialogue, true, can_cancel, not disable_wild_swing, not disable_ex)
	var new_sub_state
	if strike_response:
		if opponent_sets_first:
			new_sub_state = UISubState.UISubState_SelectCards_OpponentSetsFirst_StrikeResponseCard
		else:
			new_sub_state = UISubState.UISubState_SelectCards_StrikeResponseCard
	else:
		if opponent_sets_first:
			new_sub_state = UISubState.UISubState_SelectCards_OpponentSetsFirst_StrikeCard
		else:
			new_sub_state = UISubState.UISubState_SelectCards_StrikeCard
	change_ui_state(UIState.UIState_SelectCards, new_sub_state)

func begin_gauge_strike_choosing(strike_response : bool, cancel_allowed : bool, source : String):
	# Show the correct window.
	if source == "gauge":
		_on_player_gauge_gauge_clicked()
	elif source == "sealed":
		_on_player_sealed_clicked()

	selected_cards = []
	select_card_require_min = 1
	select_card_require_max = 1
	var can_cancel = cancel_allowed and not strike_response
	enable_instructions_ui("Select a card from %s to strike with." % source, true, can_cancel)
	var new_sub_state
	if strike_response:
		# Is there any character that does this? will need new sub-state if so
		assert(false)
	else:
		if source == "gauge":
			new_sub_state = UISubState.UISubState_SelectCards_StrikeCard_FromGauge
		elif source == "sealed":
			new_sub_state = UISubState.UISubState_SelectCards_StrikeCard_FromSealed
	change_ui_state(UIState.UIState_SelectCards, new_sub_state)

func begin_boost_choosing(can_cancel : bool, valid_zones : Array, limitation : String, ignore_costs : bool):
	selected_cards = []
	select_card_require_min = 1
	select_card_require_max = 1
	select_boost_options = {
		"can_cancel": can_cancel,
		"valid_zones": valid_zones,
		"limitation": limitation,
		"ignore_costs": ignore_costs
	}
	var limitation_str = "card"
	if limitation:
		limitation_str = limitation + " boost"
	var character_action_str = ""
	if preparing_character_action:
		character_action_str = " for %s" % prepared_character_action_data['action_name']
	var zone_str = '/'.join(valid_zones)
	var instructions = "Select a %s to boost from %s%s." % [limitation_str, zone_str, character_action_str]
	if 'gauge' in valid_zones:
		_on_player_gauge_gauge_clicked()
	elif 'discard' in valid_zones: # can't open two zones at once
		_on_player_discard_button_pressed()
	elif 'extra' in valid_zones:
		_on_player_buddy_button_pressed(true)

	enable_instructions_ui(instructions, true, can_cancel)
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
		cached_player_location = game_wrapper.get_player_location(Enums.PlayerId.PlayerId_Player)
	else:
		move_character_to_arena_square($OpponentCharacter, destination, false, move_anim)
		cached_opponent_location = game_wrapper.get_player_location(Enums.PlayerId.PlayerId_Opponent)

	update_arena_squares()
	return MoveDelay

func _on_mulligan_decision(event):
	var player = event['event_player']
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
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
			card.flip_card_to_front(false)
			card.reset(OffScreen)
	else:
		var cards = $AllCards/OpponentDiscards.get_children()
		for card in cards:
			card.get_parent().remove_child(card)
			$AllCards/OpponentDeck.add_child(card)
			card.flip_card_to_front(false)
			card.reset(OffScreen)
		# Show opponent's reshuffle cards
		reference_popout_toggle_enabled = true
		opponent_cards_before_reshuffle = event['extra_info']
	close_popout()
	update_card_counts()
	return SmallNoticeDelay

func _on_shuffle_deck(event):
	var player = event['event_player']
	if player == Enums.PlayerId.PlayerId_Player:
		update_eyes_on_hand_icons()

func _on_reshuffle_discard_in_place(event):
	var player = event['event_player']
	var card_parent
	if player == Enums.PlayerId.PlayerId_Player:
		card_parent = $AllCards/PlayerDiscards
	else:
		card_parent = $AllCards/OpponentDiscards
	var cards = card_parent.get_children()
	var new_order = {}

	for card in cards:
		var card_index = game_wrapper.get_card_index_in_discards(player, card.card_id)
		new_order[card_index] = card
	for i in range(len(new_order)):
		card_parent.move_child(new_order[i], i)

func _on_reshuffle_deck_mulligan(_event):
	#printlog("UI: TODO: In place reshuffle deck. No cards actually move though.")
	pass

func reset_revealed_cards():
	var current_children = $AllCards/OpponentRevealed.get_children()
	for i in range(len(current_children)-1, -1, -1):
		var card = current_children[i]
		card.get_parent().remove_child(card)
		card.queue_free()

func add_revealed_card(card_id : int):
	var card_db = game_wrapper.get_card_database()
	var logic_card : GameCard = card_db.get_card(card_id)
	var card_image = get_card_image_path(opponent_deck['id'], logic_card)
	var copy_card = create_card(card_id + RevealCopyIdRangestart, logic_card.definition, card_image, "", $AllCards/OpponentRevealed, true)
	copy_card.set_card_and_focus(OffScreen, 0, CardBase.ReferenceCardScale)
	copy_card.resting_scale = CardBase.ReferenceCardScale
	copy_card.change_state(CardBase.CardState.CardState_Offscreen)
	copy_card.flip_card_to_front(true)

func _on_reveal_card_from_hand(event):
	var player = event['event_player']
	spawn_damage_popup("Card Revealed!", player)
	if player == Enums.PlayerId.PlayerId_Player:
		update_eyes_on_hand_icons()
	return SmallNoticeDelay

func _on_reveal_hand(event):
	var player = event['event_player']
	spawn_damage_popup("Hand Revealed!", player)
	if player == Enums.PlayerId.PlayerId_Player:
		update_eyes_on_hand_icons()
	return SmallNoticeDelay

func _on_reveal_random_gauge(event):
	var player = event['event_player']
	spawn_damage_popup("Random Gauge Card!", player)

	return SmallNoticeDelay

func _on_reveal_topdeck(event):
	var player = event['event_player']
	spawn_damage_popup("Top Deck Revealed!", player)
	if player == Enums.PlayerId.PlayerId_Player:
		update_eyes_on_hand_icons()
	return SmallNoticeDelay

func _move_card_to_strike_area(card, strike_area, new_parent, is_player : bool, is_ex : bool):
	if card.state == CardBase.CardState.CardState_InStrike:
		return

	card.set_position_if_at_position(OffScreen, get_deck_button_position(is_player))
	var pos = strike_area.global_position + strike_area.size * strike_area.scale /2
	if is_ex:
		pos.x += CardBase.get_hand_card_size().x
	card.discard_to(pos, CardBase.CardState.CardState_InStrike)
	card.get_parent().remove_child(card)
	new_parent.add_child(card)
	layout_player_hand(is_player)

func _on_strike_started(event, is_ex : bool, is_wild : bool = false):
	var player = event['event_player']
	var card = find_card_on_board(event['number'])
	var immediate_reveal_event = false
	match event['event_type']:
		Enums.EventType.EventType_Strike_PayCost_Unable:
			immediate_reveal_event = true
	var reveal_immediately = immediate_reveal_event or event['extra_info'] == true
	if reveal_immediately:
		make_card_revealed(card)

	var is_ex_strike = 'extra_info2' in event and event['extra_info2']
	if is_ex_strike:
		_set_card_bonus(event['number'], "ex")
	if is_wild:
		_set_card_bonus(event['number'], "wild")

	if player == Enums.PlayerId.PlayerId_Player:
		_move_card_to_strike_area(card, $PlayerStrike/StrikeZone, $AllCards/Striking, true, is_ex)
	else:
		# Opponent started strike, player has to respond.
		_move_card_to_strike_area(card, $OpponentStrike/StrikeZone, $AllCards/Striking, false, is_ex)

func _on_strike_started_extra_attack(event):
	var player = event['event_player']
	var card = find_card_on_board(event['number'])
	# Immediately reveal it.
	make_card_revealed(card)
	if player == Enums.PlayerId.PlayerId_Player:
		_move_card_to_strike_area(card, $PlayerStrike/StrikeZone, $AllCards/Striking, true, false)
	else:
		_move_card_to_strike_area(card, $OpponentStrike/StrikeZone, $AllCards/Striking, false, false)


func _on_strike_do_response_now(event):
	var player = event['event_player']
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		begin_strike_choosing(true, false)
	else:
		ai_strike_response()

func _on_strike_opponent_sets_first_initiator_set(event):
	var player = event['event_player']
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		begin_strike_choosing(true, false, true)
	else:
		ai_strike_response()

func make_card_revealed(card):
	card.flip_card_to_front(true)

	# Update hand icons for cards owned by the player.
	var logic_card = game_wrapper.get_card_database().get_card(card.card_id)
	var owner_player = logic_card.owner_id
	if owner_player == Enums.PlayerId.PlayerId_Player:
		update_eyes_on_hand_icons()

func _on_strike_reveal(_event):
	var strike_cards = $AllCards/Striking.get_children()
	for card in strike_cards:
		make_card_revealed(card)
	return StrikeRevealDelay

func _on_strike_reveal_one_player(event):
	var player = event['event_player']
	spawn_damage_popup("Strike Face-Up!", player)
	# Reveal it for both players because it could be my wild swing.
	var strike_cards = $AllCards/Striking.get_children()
	for card in strike_cards:
		if game_wrapper.does_card_belong_to_player(player, card.card_id):
			make_card_revealed(card)
	return SmallNoticeDelay

func _on_strike_card_activation(event):
	var strike_cards = $AllCards/Striking.get_children()
	var card_id = event['number']
	for card in strike_cards:
		card.set_backlight_visible(card.card_id == card_id)
	return SmallNoticeDelay

func _on_strike_character_effect(event):
	var player = event['event_player']
	var effect = event['extra_info']
	var label_text : String = ""
	label_text += CardDefinitions.get_effect_text(effect, false, true, true, "", true)
	_add_bonus_label_text(player, label_text)

func _add_bonus_label_text(player, new_text : String):
	var bonus_panel = player_bonus_panel
	var bonus_label = player_bonus_label
	if player == Enums.PlayerId.PlayerId_Opponent:
		bonus_panel = opponent_bonus_panel
		bonus_label = opponent_bonus_label

	if not bonus_panel.visible:
		bonus_panel.visible = true
		bonus_label.text = ""

	for line in new_text.split("\n", false):
		bonus_label.text += "* "
		for word in line.split(" ", false):
			bonus_label.text += word + " "
			if bonus_label.get_content_width() > MaxBonusPanelWidth:
				# Undo and put it on a new line
				bonus_label.text = bonus_label.text.trim_suffix(word + " ")
				bonus_label.text += "\n    " + word + " "
		bonus_label.text += "\n"

func _on_effect_choice(event):
	var player = event['event_player']
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		if prepared_character_action_data_available("choice"):
			var choice = prepared_character_action_data['choice']
			var success = game_wrapper.submit_choice(Enums.PlayerId.PlayerId_Player, choice)
			if success:
				prepared_character_action_data = {}
				change_ui_state(UIState.UIState_WaitForGameServer)
			return

		var instruction_text = "Select an effect:"
		var extra_choice_text = []

		if event['reason'] == "EffectOrder":
			instruction_text = "Select which effect to resolve first:"

			var decision_info = game_wrapper.get_decision_info()
			var choices = decision_info.choice
			var effect_met_flags = decision_info.limitation
			assert(len(choices) == len(effect_met_flags))
			for effect_met in effect_met_flags:
				if effect_met:
					extra_choice_text.append("")
				else:
					extra_choice_text.append("[color=red][lb]FAIL[rb][/color] ")

		if event['reason'] == "Duplicate":
			instruction_text = "Select which effect to copy:"
		if event['reason'] == "Reading":
			instruction_text = "You must strike with %s." % event['extra_info']
		begin_effect_choice(game_wrapper.get_decision_info().choice, instruction_text, extra_choice_text, false)
	else:
		ai_effect_choice(event)

func _on_effect_do_strike(event):
	var player = event['event_player']
	var strike_info = event['extra_info']
	var card_id = strike_info['card_id']
	var wild_swing = strike_info['wild_swing']
	var ex_card_id = strike_info['ex_card_id']
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		game_wrapper.submit_strike(player, card_id, wild_swing, ex_card_id)
	else:
		ai_strike_effect_do_strike(card_id, wild_swing, ex_card_id)

func _on_pay_cost_gauge(event):
	var player = event['event_player']
	var enable_reminder = event['extra_info']
	var is_ex = event['extra_info2']
	var gauge_cost = game_wrapper.get_decision_info().cost
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		var wild_swing_allowed = game_wrapper.get_decision_info().type == Enums.DecisionType.DecisionType_PayStrikeCost_CanWild
		begin_gauge_selection(gauge_cost, wild_swing_allowed, UISubState.UISubState_SelectCards_StrikeGauge, enable_reminder, is_ex)
	else:
		ai_pay_cost(gauge_cost, false)

func _on_pay_cost_force(event):
	var player = event['event_player']
	var force_cost = game_wrapper.get_decision_info().cost
	var is_ex = event['extra_info2']
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		var can_cancel = false
		var wild_swing_allowed = game_wrapper.get_decision_info().type == Enums.DecisionType.DecisionType_PayStrikeCost_CanWild
		change_ui_state(null, UISubState.UISubState_SelectCards_StrikeForce)
		begin_generate_force_selection(force_cost, can_cancel, wild_swing_allowed, is_ex)
	else:
		ai_pay_cost(force_cost, true)

func _on_pay_cost_failed(event):
	# Do the wild swing deal.
	return _on_strike_started(event, false)

func _on_force_for_armor(event):
	var player = event['event_player']
	var use_gauge_instead = game_wrapper.get_decision_info().limitation == "gauge"
	force_for_armor_incoming_damage = event['number']
	force_for_armor_ignore_armor = event['extra_info']
	force_for_armor_amount = game_wrapper.get_decision_info().amount
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		if use_gauge_instead:
			begin_gauge_selection(-1, false, UISubState.UISubState_SelectCards_GaugeForArmor)
		else:
			change_ui_state(null, UISubState.UISubState_SelectCards_ForceForArmor)
			begin_generate_force_selection(-1)
	else:
		ai_force_for_armor(event)

func _on_force_for_effect(event):
	var player = event['event_player']
	var effect = game_wrapper.get_decision_info().effect
	if player == Enums.PlayerId.PlayerId_Player  and not observer_mode:
		change_ui_state(null, UISubState.UISubState_SelectCards_ForceForEffect)
		select_card_up_to_force = effect['force_max']
		var require_max = -1
		if effect['overall_effect']:
			require_max = select_card_up_to_force
		var can_cancel = true
		if 'required' in effect and effect['required']:
			can_cancel = false
		begin_generate_force_selection(require_max, can_cancel)
	else:
		ai_force_for_effect(effect)

func _on_gauge_for_effect(event):
	var player = event['event_player']
	var effect = game_wrapper.get_decision_info().effect
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		select_card_require_min = 0
		if 'required' in effect and effect['required']:
			select_card_require_min = effect['gauge_max']
		select_card_require_max = effect['gauge_max']
		if effect['overall_effect']:
			select_card_must_be_max_or_min = true
		else:
			select_card_must_be_max_or_min = false
		select_gauge_require_card_id = ""
		select_gauge_require_card_name = ""
		if 'require_specific_card_id' in effect:
			select_gauge_require_card_id = effect['require_specific_card_id']
			select_gauge_require_card_name = effect['require_specific_card_name']
		begin_gauge_selection(-1, false, UISubState.UISubState_SelectCards_GaugeForEffect)
	else:
		ai_gauge_for_effect(effect)

func _on_emote(event):
	var player = event['event_player']
	var is_image_emote = event['number']
	var emote = event['reason']
	if GlobalSettings.MuteEmotes:
		return

	if player == Enums.PlayerId.PlayerId_Player:
		spawn_emote(player, is_image_emote, emote, player_emote)
	else:
		spawn_emote(player, is_image_emote, emote, opponent_emote)

func _on_damage(event):
	var player = event['event_player']
	var life = event['extra_info']
	var reason = event['reason']
	var play_animation = true
	if reason == "spend":
		play_animation = false
	var damage_taken = event['number']
	if player == Enums.PlayerId.PlayerId_Player:
		$PlayerLife.set_life(life)
		if play_animation:
			$PlayerCharacter.play_hit()
	else:
		$OpponentLife.set_life(life)
		if play_animation:
			$OpponentCharacter.play_hit()
	spawn_damage_popup("%s Damage" % str(damage_taken), player)
	return SmallNoticeDelay

func _on_gain_life(event):
	var player = event['event_player']
	var life = event['extra_info']
	var life_gained = event['number']
	if player == Enums.PlayerId.PlayerId_Player:
		$PlayerLife.set_life(life)
	else:
		$OpponentLife.set_life(life)
	spawn_damage_popup("+%d Life" % life_gained, player)
	return SmallNoticeDelay

func _get_buddy_from_id(player_id : Enums.PlayerId, buddy_id : String):
	if player_id == Enums.PlayerId.PlayerId_Player:
		for buddy in player_buddies:
			if buddy.get_buddy_id() == buddy_id:
				return buddy
	else:
		for buddy in opponent_buddies:
			if buddy.get_buddy_id() == buddy_id:
				return buddy
	assert(false)
	return null

func _on_place_buddy(event):
	var player = event['event_player']
	var buddy_location = event['number']
	var buddy_id = event['extra_info']
	var silent = event['extra_info2']
	var extra_offset = event['extra_info3']
	var extra_description = event['reason']

	var action_text = "Place"
	if buddy_location == -1:
		action_text = "Remove"

	var buddy = _get_buddy_from_id(player, buddy_id)
	add_buddy_to_zone(player, buddy, buddy_id)
	buddy.set_buddy_extra_offset(extra_offset)
	if buddy_location == -1:
		buddy.visible = false
	else:
		var immediate = not buddy.visible
		buddy.visible = true
		move_character_to_arena_square(buddy, buddy_location, immediate, Character.CharacterAnim.CharacterAnim_WalkForward, -1)

	if not silent:
		if extra_description:
			spawn_damage_popup(extra_description, player)
		else:
			spawn_damage_popup("%s %s" % [action_text, game_wrapper.get_buddy_name(player, buddy_id)], player)
		return SmallNoticeDelay
	return 0

func add_lightning_rod(rod_parent, rod_tracking, location, card_id):
	var rods_at_location = rod_tracking[location]
	if len(rods_at_location['card_ids']) == 0:
		# Create a new character for this and add it to rod_parent.
		var new_character = CharacterScene.instantiate()
		rod_parent.add_child(new_character)
		new_character.load_character("rachel_lightningrod")
		rods_at_location['character'] = new_character
		var immediate = true
		move_character_to_arena_square(new_character, location, immediate, Character.CharacterAnim.CharacterAnim_WalkForward, -1)
	rods_at_location['card_ids'].append(card_id)

func remove_lightning_rod(rod_parent, rod_tracking, location, card_id):
	var rods_at_location = rod_tracking[location]
	rods_at_location['card_ids'].erase(card_id)
	if len(rods_at_location['card_ids']) == 0:
		rod_parent.remove_child(rods_at_location['character'])
		rods_at_location['character'].queue_free()
		rods_at_location['character'] = null

func update_lightningrod_info(player, rod_tracking, location):
	var rods_at_location = rod_tracking[location]
	var count =len(rods_at_location['card_ids'])
	var pair = $ArenaNode/RowLightningInfoButtons.get_child(location)
	pair.set_number(player, count)
	# Iterate through all locations for both players
	# and update the count of lightning rods at each location.
	pass

func _on_place_lightningrod(event):
	var player = event['event_player']
	var card_id = event['number']
	var location = event['extra_info']
	var place = event['extra_info2']

	var rod_parent = player_lightningrods
	var rod_tracking = player_lightningrod_tracking
	if player == Enums.PlayerId.PlayerId_Opponent:
		rod_parent = opponent_lightningrods
		rod_tracking = opponent_lightningrod_tracking

	# Add or remove the rod as appropriate.
	if place:
		add_lightning_rod(rod_parent, rod_tracking, location, card_id)

		# Move the card to the set aside zone.
		var is_player = player == Enums.PlayerId.PlayerId_Player
		var card = find_card_on_board(card_id)
		var deck_position = get_deck_button_position(is_player)
		card.discard_to(deck_position, CardBase.CardState.CardState_InDeck)
		reparent_to_zone(card, get_set_aside_zone(is_player))
	else:
		remove_lightning_rod(rod_parent, rod_tracking, location, card_id)
	update_lightningrod_info(player, rod_tracking, location)
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
			Enums.EventType.EventType_AddToOverdrive:
				delay = _on_add_to_overdrive(event)
			Enums.EventType.EventType_AdvanceTurn:
				delay = _on_advance_turn()
			Enums.EventType.EventType_BecomeWide:
				delay = _on_become_wide(event)
			Enums.EventType.EventType_BlockMovement:
				delay = _stat_notice_event(event)
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
			Enums.EventType.EventType_Boost_DiscardOpponentGauge:
				_on_discard_opponent_gauge(event)
			Enums.EventType.EventType_Boost_NameCardOpponentDiscards:
				delay = _on_name_opponent_card_begin(event)
			Enums.EventType.EventType_Boost_Sidestep:
				delay = _on_name_opponent_card_begin(event)
			Enums.EventType.EventType_Boost_ZeroVector:
				delay = _on_name_opponent_card_begin(event)
			Enums.EventType.EventType_Boost_Played:
				delay = _on_boost_played(event)
			Enums.EventType.EventType_CardFromHandToGauge_Choice:
				_on_choose_card_hand_to_gauge(event)
			Enums.EventType.EventType_ChangeCards:
				delay = _on_change_cards(event)
			Enums.EventType.EventType_CharacterAction:
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_ChooseArenaLocationForEffect:
				_on_choose_arena_location_for_effect(event)
			Enums.EventType.EventType_ChooseFromBoosts:
				_on_choose_from_boosts(event)
			Enums.EventType.EventType_ChooseFromDiscard:
				_on_choose_from_discard(event)
			Enums.EventType.EventType_ChooseFromTopDeck:
				_on_choose_from_topdeck(event)
			Enums.EventType.EventType_Draw:
				_on_draw_event(event)
			Enums.EventType.EventType_Emote:
				_on_emote(event)
			Enums.EventType.EventType_Exceed:
				delay = _on_exceed_event(event)
			Enums.EventType.EventType_ExceedRevert:
				delay = _on_exceed_revert_event(event)
			Enums.EventType.EventType_ForceStartBoost:
				delay = _on_force_start_boost(event)
			Enums.EventType.EventType_ForceStartStrike:
				delay = _on_force_start_strike(event)
			Enums.EventType.EventType_ForceForEffect:
				_on_force_for_effect(event)
			Enums.EventType.EventType_GaugeForEffect:
				_on_gauge_for_effect(event)
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
			Enums.EventType.EventType_PlaceBuddy:
				delay = _on_place_buddy(event)
			Enums.EventType.EventType_PlaceLightningRod:
				delay = _on_place_lightningrod(event)
			Enums.EventType.EventType_PickNumberFromRange:
				_on_pick_number_from_range(event)
			Enums.EventType.EventType_SwapSealedAndDeck:
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_Prepare:
				delay = _on_prepare(event)
			Enums.EventType.EventType_ReadingNormal:
				delay = _on_name_opponent_card_begin(event)
			Enums.EventType.EventType_ReshuffleDeck:
				_on_shuffle_deck(event)
			Enums.EventType.EventType_ReshuffleDiscard:
				delay = _on_reshuffle_discard(event)
			Enums.EventType.EventType_ReshuffleDiscardInPlace:
				_on_reshuffle_discard_in_place(event)
			Enums.EventType.EventType_ReshuffleDeck_Mulligan:
				_on_reshuffle_deck_mulligan(event)
			Enums.EventType.EventType_RevealCard:
				delay = _on_reveal_card_from_hand(event)
			Enums.EventType.EventType_RevealHand:
				delay = _on_reveal_hand(event)
			Enums.EventType.EventType_RevealStrike_OnePlayer:
				delay = _on_strike_reveal_one_player(event)
			Enums.EventType.EventType_RevealRandomGauge:
				delay = _on_reveal_random_gauge(event)
			Enums.EventType.EventType_RevealTopDeck:
				delay = _on_reveal_topdeck(event)
			Enums.EventType.EventType_Seal:
				delay = _on_add_to_sealed(event)
			Enums.EventType.EventType_SetCardAside:
				_on_set_card_aside(event)
			Enums.EventType.EventType_Strike_ArmorUp:
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_Strike_AttackDoesNotHit:
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_Strike_CardActivation:
				delay = _on_strike_card_activation(event)
			Enums.EventType.EventType_Strike_CharacterEffect:
				_on_strike_character_effect(event)
			Enums.EventType.EventType_Strike_ChooseToDiscard:
				delay = _on_choose_to_discard(event, false)
			Enums.EventType.EventType_Strike_ChooseToDiscard_Info:
				delay = _on_choose_to_discard(event, true)
			Enums.EventType.EventType_Strike_Cleanup:
				_on_end_of_strike()
			Enums.EventType.EventType_Strike_Critical:
				_set_card_bonus(event['number'], "critical")
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_Strike_DodgeAttacks, Enums.EventType.EventType_Strike_DodgeAttacksAtRange, Enums.EventType.EventType_Strike_DodgeFromOppositeBuddy:
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_Strike_DoResponseNow:
				_on_strike_do_response_now(event)
			Enums.EventType.EventType_Strike_EffectChoice:
				_on_effect_choice(event)
			Enums.EventType.EventType_Strike_EffectDoStrike:
				_on_effect_do_strike(event)
			Enums.EventType.EventType_Strike_ExUp:
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_Strike_ForceForArmor:
				_on_force_for_armor(event)
			Enums.EventType.EventType_Strike_GainAdvantage:
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_Strike_GainLife:
				delay = _on_gain_life(event)
			Enums.EventType.EventType_Strike_GuardUp:
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_Strike_IgnoredPushPull:
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_Strike_Miss:
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_Strike_OpponentCantMovePast:
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_Strike_FromGauge:
				delay = _on_strike_from_gauge(event)
			Enums.EventType.EventType_Strike_OpponentSetsFirst:
				delay = _on_strike_opponent_sets_first(event)
			Enums.EventType.EventType_Strike_OpponentSetsFirst_DefenderSet:
				_on_strike_opponent_sets_first_defender_set(event)
			Enums.EventType.EventType_Strike_OpponentSetsFirst_InitiatorSet:
				_on_strike_opponent_sets_first_initiator_set(event)
			Enums.EventType.EventType_Strike_PayCost_Gauge:
				_on_pay_cost_gauge(event)
			Enums.EventType.EventType_Strike_PayCost_Force:
				_on_pay_cost_force(event)
			Enums.EventType.EventType_Strike_PayCost_Unable:
				_on_pay_cost_failed(event)
			Enums.EventType.EventType_Strike_PowerUp:
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_Strike_RandomGaugeStrike:
				_on_strike_started(event, false)
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_Strike_RangeUp:
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_Strike_Response:
				_on_strike_started(event, false)
			Enums.EventType.EventType_Strike_Response_Ex:
				_on_strike_started(event, true)
			Enums.EventType.EventType_Strike_Reveal:
				delay = _on_strike_reveal(event)
			Enums.EventType.EventType_Strike_SetX:
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_Strike_SpeedUp:
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_Strike_Started:
				_on_strike_started(event, false)
			Enums.EventType.EventType_Strike_Started_Ex:
				_on_strike_started(event, true)
			Enums.EventType.EventType_Strike_Started_ExtraAttack:
				_on_strike_started_extra_attack(event)
			Enums.EventType.EventType_Strike_Stun:
				delay = _on_stunned(event)
			Enums.EventType.EventType_Strike_Stun_Immunity:
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_SustainBoost:
				delay = _stat_notice_event(event)
			Enums.EventType.EventType_Strike_TookDamage:
				delay = _on_damage(event)
			Enums.EventType.EventType_Strike_WildStrike:
				_on_strike_started(event, false, true)
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
		player_bonus_panel.visible = false
		opponent_bonus_panel.visible = false
		if len(selected_cards) == 0:
			set_instructions("Choose an action:")
			instructions_ok_allowed = false
			instructions_cancel_allowed = false
			instructions_wild_swing_allowed = false
			button_choices.append({ "text": "Prepare", "action": _on_prepare_button_pressed, "disabled": not game_wrapper.can_do_prepare(Enums.PlayerId.PlayerId_Player) })
			button_choices.append({ "text": "Move", "action": _on_move_button_pressed, "disabled": not game_wrapper.can_do_move(Enums.PlayerId.PlayerId_Player) })
			button_choices.append({ "text": "Change Cards", "action": _on_change_button_pressed, "disabled": not game_wrapper.can_do_change(Enums.PlayerId.PlayerId_Player) })
			var exceed_cost = game_wrapper.get_player_exceed_cost(Enums.PlayerId.PlayerId_Player)
			if exceed_cost >= 0 and not game_wrapper.is_player_exceeded(Enums.PlayerId.PlayerId_Player):
				button_choices.append({ "text": "Exceed (%s Gauge)" % exceed_cost, "action": _on_exceed_button_pressed, "disabled": not game_wrapper.can_do_exceed(Enums.PlayerId.PlayerId_Player) })
			if game_wrapper.can_do_reshuffle(Enums.PlayerId.PlayerId_Player):
				button_choices.append({ "text": "Manual Reshuffle", "action": _on_reshuffle_button_pressed, "disabled": false })
			button_choices.append({ "text": "Boost", "action": _on_boost_button_pressed, "disabled": not game_wrapper.can_do_boost(Enums.PlayerId.PlayerId_Player) })
			button_choices.append({ "text": "Strike", "action": _on_strike_button_pressed, "disabled": not game_wrapper.can_do_strike(Enums.PlayerId.PlayerId_Player) })
			for i in range(game_wrapper.get_player_character_action_count(Enums.PlayerId.PlayerId_Player)):
				var char_action = game_wrapper.get_player_character_action(Enums.PlayerId.PlayerId_Player, i)
				var action_possible = game_wrapper.can_do_character_action(Enums.PlayerId.PlayerId_Player, i)
				var action_name = "Character Action"
				if 'action_name' in char_action:
					action_name = char_action['action_name']
				var force_cost = char_action['force_cost']
				var gauge_cost = char_action['gauge_cost']
				var additional_text = ""
				if force_cost > 0:
					additional_text += " (%s Force)" % force_cost
				if gauge_cost > 0:
					additional_text += " (%s Gauge)" % gauge_cost
				button_choices.append({ "text": "%s%s" % [action_name, additional_text], "action": func(): _on_character_action_pressed(i), "disabled": not action_possible })
			var bonus_available_actions = game_wrapper.get_bonus_actions(Enums.PlayerId.PlayerId_Player)
			for i in range(bonus_available_actions.size()):
				var bonus_action = bonus_available_actions[i]
				var action_text = bonus_action['text']
				var bonus_index = i
				button_choices.append({ "text": action_text, "action": func(): _on_bonus_action_pressed(bonus_index), "disabled": false })
		else:
			var card_db = game_wrapper.get_card_database()
			var card_name = "these cards"
			var strike_text = "Strike"
			var boost_text = "Boost"
			var can_strike = false
			var can_boost = false
			var only_in_hand = true
			var only_in_boosts = true
			var only_set_aside = true
			var allow_change_cards = true
			for card in selected_cards:
				if not game_wrapper.is_card_in_hand(Enums.PlayerId.PlayerId_Player, card.card_id):
					only_in_hand = false

				if not game_wrapper.is_card_set_aside(Enums.PlayerId.PlayerId_Player, card.card_id):
					only_set_aside = false
				else:
					allow_change_cards = false

				if not game_wrapper.is_card_in_boosts(Enums.PlayerId.PlayerId_Player, card.card_id):
					only_in_boosts = false
				else:
					allow_change_cards = false
			if only_in_hand:
				if len(selected_cards) == 1:
					can_strike = true
					can_boost = true
				elif len(selected_cards) == 2:
					var card1 = selected_cards[0]
					var card2 = selected_cards[1]
					if card_db.are_same_card(card1.card_id, card2.card_id):
						can_strike = true
						strike_text = "EX Strike"
			elif only_in_boosts:
				if len(selected_cards) == 1:
					var logic_card = card_db.get_card(selected_cards[0].card_id)
					can_strike = 'must_set_from_boost' in logic_card.definition and logic_card.definition['must_set_from_boost']
			elif only_set_aside:
				if len(selected_cards) == 1 and player_can_boost_from_extra:
					can_boost = game_wrapper.can_player_boost(Enums.PlayerId.PlayerId_Player, selected_cards[0].card_id, ['extra'], "", false)

			if can_strike:
				card_name = card_db.get_card(selected_cards[0].card_id).definition['display_name']
				strike_text += " (%s)" % card_name
			if can_boost:
				var boost_name = card_db.get_card(selected_cards[0].card_id).definition['boost']['display_name']
				boost_text += " (%s)" % boost_name

			set_instructions("Do what with %s?" % card_name)
			instructions_ok_allowed = false
			instructions_cancel_allowed = false
			instructions_wild_swing_allowed = false
			button_choices.append({ "text": strike_text, "action": _on_shortcut_strike_pressed, "disabled": not can_strike or not game_wrapper.can_do_strike(Enums.PlayerId.PlayerId_Player) })
			button_choices.append({ "text": boost_text, "action": _on_shortcut_boost_pressed, "disabled": not can_boost or not game_wrapper.can_do_boost(Enums.PlayerId.PlayerId_Player) })

			# Check for character actions with card-related shortcuts
			for i in range(game_wrapper.get_player_character_action_count(Enums.PlayerId.PlayerId_Player)):
				var char_action = game_wrapper.get_player_character_action(Enums.PlayerId.PlayerId_Player, i)
				var action_has_shortcut = false
				var shortcut_condition_met = false
				var action_name = ""
				if 'shortcut_effect_type' in char_action:
					var shortcut_effect = game_wrapper.get_player_character_action_shortcut_effect(Enums.PlayerId.PlayerId_Player, i)
					if char_action['shortcut_effect_type'] == "strike":
						action_has_shortcut = true
						action_name = "Strike with "
						shortcut_condition_met = can_strike
					elif char_action['shortcut_effect_type'] == "gauge_from_hand":
						action_has_shortcut = true
						action_name = "Move to Gauge for "
						var min_cards = shortcut_effect['min_amount']
						var max_cards = shortcut_effect['max_amount']
						var valid_card_count = min_cards <= len(selected_cards) and len(selected_cards) <= max_cards
						shortcut_condition_met = valid_card_count and only_in_hand
					elif char_action['shortcut_effect_type'] == "self_discard_choose":
						action_has_shortcut = true
						action_name = "Discard for "
						var min_cards = shortcut_effect['amount']
						var max_cards = shortcut_effect['amount']
						if shortcut_effect['amount'] == -1:
							min_cards = 0
							max_cards = game_wrapper.get_player_hand_size(Enums.PlayerId.PlayerId_Player)
						var valid_card_count = min_cards <= len(selected_cards) and len(selected_cards) <= max_cards
						shortcut_condition_met = valid_card_count and only_in_hand
					elif char_action['shortcut_effect_type'] == "boost_from_gauge":
						action_has_shortcut = true
						action_name = "Boost with "
						if len(selected_cards) == 1:
							var valid_zones = ['gauge']
							var limitation = ""
							if 'limitation' in shortcut_effect:
								limitation = shortcut_effect['limitation']
							shortcut_condition_met = game_wrapper.can_player_boost(Enums.PlayerId.PlayerId_Player, selected_cards[0].card_id, valid_zones, limitation, false)

				if action_has_shortcut:
					var action_possible = game_wrapper.can_do_character_action(Enums.PlayerId.PlayerId_Player, i)
					if 'action_name' in char_action:
						action_name += char_action['action_name']
					else:
						action_name += "Character Action"
					var force_cost = char_action['force_cost']
					var gauge_cost = char_action['gauge_cost']
					# NOTE: at the moment shortcuts aren't used for any effects with a cost, may not behave properly otherwise
					assert(force_cost == 0 and gauge_cost == 0)
					button_choices.append({ "text": action_name, "action": func(): _on_shortcut_character_action_pressed(i), "disabled": not action_possible or not shortcut_condition_met })

			button_choices.append({ "text": "Change Cards", "action": _on_shortcut_change_pressed, "disabled": not game_wrapper.can_do_change(Enums.PlayerId.PlayerId_Player) or not allow_change_cards })
			button_choices.append({ "text": "Deselect card(s)", "action": _on_shortcut_cancel_pressed, "disabled": false })

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
		button_choices.append({ "text": "OK", "action": func(): _on_instructions_ok_button_pressed(0), "disabled": not can_press_ok() })

	var cancel_text = "Cancel"
	if not preparing_character_action:
		match ui_sub_state:
			UISubState.UISubState_SelectCards_BoostCancel, UISubState.UISubState_SelectCards_Mulligan, UISubState.UISubState_SelectCards_ForceForEffect, UISubState.UISubState_SelectCards_DiscardCardsToGauge, UISubState.UISubState_SelectCards_ChooseDiscardToDestination:
				cancel_text = "Pass"
			UISubState.UISubState_SelectCards_ChooseBoostsToSustain, UISubState.UISubState_SelectCards_ChooseFromTopdeck:
				cancel_text = "Pass"
			UISubState.UISubState_SelectArena_EffectChoice:
				cancel_text = "Pass"
			UISubState.UISubState_SelectCards_GaugeForEffect:
				cancel_text = "Pass"
			_:
				cancel_text = "Cancel"

	# Update instructions message
	var ultra_force_toggle = false
	var ex_discard_order_toggle = false
	var free_force_toggle = false
	if ui_state == UIState.UIState_SelectCards:
		match ui_sub_state:
			UISubState.UISubState_SelectCards_DiscardCards:
				update_discard_selection_message()
			UISubState.UISubState_SelectCards_DiscardCards_Choose:
				update_discard_selection_message_choose()
			UISubState.UISubState_SelectCards_ChooseBoostsToSustain:
				update_sustain_selection_message()
			UISubState.UISubState_SelectCards_DiscardCardsToGauge:
				update_discard_to_gauge_selection_message()
			UISubState.UISubState_SelectCards_MoveActionGenerateForce, UISubState.UISubState_SelectCards_CharacterAction_Force:
				free_force_toggle = game_wrapper.get_player_free_force(Enums.PlayerId.PlayerId_Player) > 0
				update_force_generation_message()
			UISubState.UISubState_SelectCards_ForceForBoost:
				free_force_toggle = game_wrapper.get_player_free_force(Enums.PlayerId.PlayerId_Player) > 0
				update_force_generation_message()
			UISubState.UISubState_SelectCards_ForceForChange:
				ultra_force_toggle = true
				free_force_toggle = game_wrapper.get_player_free_force(Enums.PlayerId.PlayerId_Player) > 0
				update_force_generation_message()
			UISubState.UISubState_SelectCards_ForceForArmor:
				free_force_toggle = game_wrapper.get_player_free_force(Enums.PlayerId.PlayerId_Player) > 0
				update_force_generation_message()
			UISubState.UISubState_SelectCards_ForceForEffect:
				ultra_force_toggle = true
				free_force_toggle = game_wrapper.get_player_free_force(Enums.PlayerId.PlayerId_Player) > 0
				update_force_generation_message()
			UISubState.UISubState_SelectCards_StrikeForce:
				ex_discard_order_toggle = current_pay_costs_is_ex
				free_force_toggle = game_wrapper.get_player_free_force(Enums.PlayerId.PlayerId_Player) > 0
				update_force_generation_message()
			UISubState.UISubState_SelectCards_GaugeForArmor:
				update_gauge_selection_message()
			UISubState.UISubState_SelectCards_StrikeGauge:
				ex_discard_order_toggle = current_pay_costs_is_ex
				update_gauge_selection_message()
			UISubState.UISubState_SelectCards_GaugeForEffect:
				update_gauge_for_effect_message()
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

	choice_popout_button.visible = ui_sub_state == UISubState.UISubState_SelectCards_ChooseFromTopdeck

	for i in range(current_effect_choices.size()):
		var choice = current_effect_choices[i]
		var card_text = ""
		if current_effect_extra_choice_text:
			card_text = current_effect_extra_choice_text[i]

		var choice_value = i
		if "_choice_value" in choice:
			choice_value = choice["_choice_value"]
		if "_choice_text" in choice:
			card_text += choice["_choice_text"]
		else:
			var card_name = ""
			if 'card_name' in choice:
				card_name = choice['card_name']
			card_text += CardDefinitions.get_effect_text(choice, false, true, false, card_name)
			if len(_choice_text_without_tags(card_text)) > ChoiceTextLengthSoftCap:
				var real_break_idx = 0
				var visible_break_idx = 0
				var in_tag = false
				while visible_break_idx < ChoiceTextLengthSoftCap-1:
					if in_tag:
						if card_text[real_break_idx] == ']':
							in_tag = false
					else:
						if card_text[real_break_idx] == '[':
							in_tag = true
						else:
							visible_break_idx += 1
					real_break_idx += 1

				while real_break_idx < len(card_text)-1 and card_text[real_break_idx] != " ":
					if in_tag:
						if card_text[real_break_idx] == ']':
							in_tag = false
					else:
						if card_text[real_break_idx] == '[':
							in_tag = true
						else:
							visible_break_idx += 1
					real_break_idx += 1
					if visible_break_idx >= ChoiceTextLengthHardCap:
						break
				if real_break_idx < len(card_text) - 1:
					if card_text[real_break_idx] == " ":
						card_text = card_text.substr(0, real_break_idx) + "\n" + card_text.substr(real_break_idx+1)
					else:
						card_text = card_text.substr(0, real_break_idx) + "-\n" + card_text.substr(real_break_idx)

		var disabled = false
		if "_choice_disabled" in choice and choice["_choice_disabled"]:
			disabled = true

		if "_choice_func" in choice:
			button_choices.append({ "text": card_text, "action": choice["_choice_func"], "disabled": disabled })
		else:
			button_choices.append({ "text": card_text, "action": func(): _on_choice_pressed(choice_value), "disabled": disabled })

	if instructions_cancel_allowed:
		button_choices.append({ "text": cancel_text, "action": _on_instructions_cancel_button_pressed })
	if instructions_wild_swing_allowed:
		button_choices.append({ "text": "Wild Swing", "action": _on_wild_swing_button_pressed })

	# Set the Action Menu state
	var action_menu_hidden = false
	match ui_state:
		UIState.UIState_PlayingAnimation, UIState.UIState_WaitForGameServer, UIState.UIState_GameOver:
			action_menu_hidden = true
		UIState.UIState_WaitingOnOpponent:
			action_menu_hidden = true
	action_menu.visible = not action_menu_hidden and (button_choices.size() > 0 or instructions_visible)
	action_menu_container.visible = action_menu.visible
	action_menu.set_choices(current_instruction_text, button_choices, ultra_force_toggle, instructions_number_picker_min, instructions_number_picker_max, ex_discard_order_toggle, free_force_toggle)
	current_action_menu_choices = button_choices

func _choice_text_without_tags(choice_text):
	return ChoiceTagRegex.sub(choice_text, "", true)

func update_boost_summary(boosts_card_holder, boost_box):
	var card_ids = []
	var card_db = game_wrapper.get_card_database()
	for card in boosts_card_holder.get_children():
		card_ids.append(card.card_id)
	var effects = []
	for card_id in card_ids:
		var card = card_db.get_card(card_id)
		for effect in card.definition['boost']['effects']:
			if effect['timing'] != "now" or effect['effect_type'] in ["force_costs_reduced_passive", "ignore_push_and_pull_passive_bonus"]:
				if effect['timing'] != "discarded":
					effects.append(effect)
	var boost_summary = ""
	for effect in effects:
		boost_summary += CardDefinitions.get_effect_text(effect) + "\n"

	for card_id in card_ids:
		var card = card_db.get_card(card_id)
		if 'must_set_from_boost' in card.definition and card.definition['must_set_from_boost']:
			var attack_name = card.definition['display_name']
			boost_summary += "[color=green](Can set %s as attack!)[/color]\n" % attack_name
	boost_box.set_text(boost_summary)

func update_arena_squares():
	for i in range(1, 10):
		var square : ArenaSquare = arena_graphics.get_child(i - 1)
		var player_extra_width = 0
		if $PlayerCharacter.is_wide:
			player_extra_width = game_wrapper.get_player_extra_width(Enums.PlayerId.PlayerId_Player)
		var opponent_extra_width = 0
		if $OpponentCharacter.is_wide:
			opponent_extra_width = game_wrapper.get_player_extra_width(Enums.PlayerId.PlayerId_Opponent)
		if i >= cached_player_location - player_extra_width and i <= cached_player_location + player_extra_width:
			square.set_self_occupied()
		elif i >= cached_opponent_location - opponent_extra_width and i <= cached_opponent_location + opponent_extra_width:
			square.set_enemy_occupied()
		else:
			square.set_empty()

func selected_cards_between_min_and_max() -> bool:
	var selected_count = len(selected_cards)
	return selected_count >= select_card_require_min && selected_count <= select_card_require_max

func can_press_ok():
	if observer_mode:
		return false

	if ui_state == UIState.UIState_SelectCards:
		match ui_sub_state:
			UISubState.UISubState_SelectCards_StrikeGauge:
				return get_gauge_generated() >= select_card_require_min and get_gauge_generated() <= select_card_require_max
			UISubState.UISubState_SelectCards_DiscardCards, UISubState.UISubState_SelectCards_Exceed:
				return selected_cards_between_min_and_max()
			UISubState.UISubState_SelectCards_BoostCancel, UISubState.UISubState_SelectCards_DiscardContinuousBoost, UISubState.UISubState_SelectCards_DiscardFromReference:
				return selected_cards_between_min_and_max()
			UISubState.UISubState_SelectCards_ChooseDiscardToDestination, UISubState.UISubState_SelectCards_DiscardCards_Choose, UISubState.UISubState_SelectCards_DiscardOpponentGauge:
				return selected_cards_between_min_and_max()
			UISubState.UISubState_SelectCards_DiscardCardsToGauge, UISubState.UISubState_SelectCards_Mulligan, UISubState.UISubState_SelectCards_CharacterAction_Gauge:
				return selected_cards_between_min_and_max()
			UISubState.UISubState_SelectCards_ChooseBoostsToSustain:
				return selected_cards_between_min_and_max()
			UISubState.UISubState_SelectCards_ChooseFromTopdeck:
				return selected_cards_between_min_and_max()
			UISubState.UISubState_SelectCards_MoveActionGenerateForce, UISubState.UISubState_SelectCards_CharacterAction_Force:
				return can_selected_cards_pay_force(select_card_require_force)
			UISubState.UISubState_SelectCards_ForceForChange:
				var force_selected = get_force_in_selected_cards()
				return force_selected >= 1
			UISubState.UISubState_SelectCards_StrikeCard, UISubState.UISubState_SelectCards_StrikeResponseCard, UISubState.UISubState_SelectCards_OpponentSetsFirst_StrikeCard, UISubState.UISubState_SelectCards_OpponentSetsFirst_StrikeResponseCard:
				# As a special exception, allow 2 cards if exactly 2 cards and they're the same card.
				# EX attacks can't be set from boosts, however.
				if len(selected_cards) == 2:
					if (game_wrapper.is_card_in_boosts(Enums.PlayerId.PlayerId_Player, selected_cards[0].card_id) or
						game_wrapper.is_card_in_boosts(Enums.PlayerId.PlayerId_Player, selected_cards[1].card_id)):
							return false
					var card_db = game_wrapper.get_card_database()
					var card1 = selected_cards[0]
					var card2 = selected_cards[1]
					return card_db.are_same_card(card1.card_id, card2.card_id) and instructions_ex_allowed
				return len(selected_cards) == 1
			UISubState.UISubState_SelectCards_StrikeForce:
				return can_selected_cards_pay_force(select_card_require_force)
			UISubState.UISubState_SelectCards_StrikeCard_FromGauge:
				# This one doesn't allow EX strikes
				return len(selected_cards) == 1
			UISubState.UISubState_SelectCards_StrikeCard_FromSealed:
				# same
				return len(selected_cards) == 1
			UISubState.UISubState_SelectCards_ForceForArmor, UISubState.UISubState_SelectCards_GaugeForArmor:
				return true
			UISubState.UISubState_SelectCards_ForceForEffect:
				var force_selected = get_force_in_selected_cards()
				if select_card_require_force == -1:
					var within_force_limit = select_card_up_to_force == -1 or force_selected <= select_card_up_to_force
					return within_force_limit or can_selected_cards_pay_force(select_card_up_to_force)
				return can_selected_cards_pay_force(select_card_require_force)
			UISubState.UISubState_SelectCards_GaugeForEffect:
				if select_card_must_be_max_or_min:
					if instructions_cancel_allowed and len(selected_cards) == 0:
						return false
					return get_gauge_generated() == select_card_require_min or get_gauge_generated() == select_card_require_max
				else:
					return get_gauge_generated() >= select_card_require_min and get_gauge_generated() <= select_card_require_max
			UISubState.UISubState_SelectCards_PlayBoost:
				return len(selected_cards) == 1
			UISubState.UISubState_SelectCards_ForceForBoost:
				return can_selected_cards_pay_force(select_card_require_force)
	else: # Some other non-select cards state.
		match ui_sub_state:
			UISubState.UISubState_PickNumberFromRange:
				return true
	return false

func begin_select_arena_location(valid_moves):
	arena_locations_clickable = valid_moves
	enable_instructions_ui("Select a location", false, true)
	change_ui_state(UIState.UIState_SelectArenaLocation, UISubState.UISubState_SelectCards_MoveActionGenerateForce)

func _on_choose_arena_location_for_effect(event):
	var player = event['event_player']
	var decision_info = game_wrapper.get_decision_info()
	var effect_type = decision_info.effect_type
	var can_pass = decision_info.limitation[0] == 0
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		if prepared_character_action_data_available("place_buddy_effect"):
			var choice = prepared_character_action_data['choice']
			var success = game_wrapper.submit_choice(Enums.PlayerId.PlayerId_Player, choice)
			if success:
				prepared_character_action_data = {}
				change_ui_state(UIState.UIState_WaitForGameServer)
			return

		arena_locations_clickable = decision_info.limitation
		var instruction_str = "Select a location"
		match effect_type:
			"place_boost_in_space":
				var boost_name = decision_info.source
				instruction_str = "Select a location to place %s" % boost_name
			"place_buddy_into_space":
				var buddy_name = decision_info.source
				instruction_str = "Select a location to place %s" % buddy_name
			"place_lightningrod":
				instruction_str = "Select a location to place the Lightning Rod"
			"place_next_buddy":
				var must_remove = decision_info.extra_info
				var buddy_name = decision_info.source
				if must_remove:
					instruction_str = "Select which %s to move" % buddy_name
				else:
					instruction_str = "Place %s or select one to move" % buddy_name
			"move_to_space":
				var extra_info = decision_info.extra_info
				if extra_info:
					extra_info = "\n" + extra_info
				instruction_str = "Select a location to move to%s" % extra_info
			"remove_buddy_near_opponent":
				var buddy_name = decision_info.source
				instruction_str = "Select %s to remove" % buddy_name
		enable_instructions_ui(instruction_str, false, can_pass)
		change_ui_state(UIState.UIState_SelectArenaLocation, UISubState.UISubState_SelectArena_EffectChoice)
	else:
		ai_choose_arena_location_for_effect(decision_info.limitation)

func _on_pick_number_from_range(event):
	var player = event['event_player']
	var decision_info = game_wrapper.get_decision_info()
	var min_value = decision_info.amount_min
	var max_value = decision_info.amount
	var additional_choices = []
	if decision_info.valid_zones:
		# Extra options outside of the number picker.
		# Add these as extra choice buttons.
		for i in range(decision_info.valid_zones.size()):
			var extra_choice = decision_info.valid_zones[i]
			additional_choices.append({
				"_choice_value": i + max_value + 1,
				"_choice_text": extra_choice,
			})

	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		enable_instructions_ui("Pick a number from %s-%s to %s" % [str(min_value), str(max_value), decision_info.effect_type], true, false, false, false, additional_choices, true)
		change_ui_state(UIState.UIState_MakeChoice, UISubState.UISubState_PickNumberFromRange)
	else:
		ai_pick_number_from_range(decision_info.limitation, decision_info.choice)

func handle_pick_range_ok():
	var decision_info = game_wrapper.get_decision_info()
	var choice_index = 0
	var chosen_number = action_menu.get_current_number_picker_value()
	for i in range(decision_info.limitation.size()):
		if decision_info.limitation[i] == chosen_number:
			choice_index = i
			break

	_on_choice_pressed(choice_index)

	# Return false, _on_choice_pressed handles UI state.
	return false

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
	var valid_zones = ['hand']
	if player_can_boost_from_extra:
		valid_zones.append('extra')
	begin_boost_choosing(true, valid_zones, "", false)

func _on_strike_button_pressed():
	begin_strike_choosing(false, true)

func _on_bonus_action_pressed(index : int):
	game_wrapper.submit_bonus_turn_action(Enums.PlayerId.PlayerId_Player, index)
	change_ui_state(UIState.UIState_WaitForGameServer)
	_update_buttons()

func _on_character_action_pressed(action_idx : int = 0):
	var character_action = game_wrapper.get_player_character_action(Enums.PlayerId.PlayerId_Player, action_idx)
	if not character_action:
		assert(false, "Character action button should not be visible")
		return

	var force_cost = character_action['force_cost']
	var gauge_cost = character_action['gauge_cost']
	selected_character_action = action_idx
	if force_cost > 0:
		change_ui_state(null, UISubState.UISubState_SelectCards_CharacterAction_Force)
		begin_generate_force_selection(force_cost)
	elif gauge_cost > 0:
		begin_gauge_selection(gauge_cost, false, UISubState.UISubState_SelectCards_CharacterAction_Gauge)
	else:
		var shortcut_effect = game_wrapper.get_player_character_action_shortcut_effect(Enums.PlayerId.PlayerId_Player, action_idx)
		if shortcut_effect:
			preparing_character_action = true
			prepared_character_action_data = {
				'effect_type': shortcut_effect['effect_type'],
				'action_idx': action_idx,
				'action_name': "Character Action"
			}
			if 'action_name' in character_action:
				prepared_character_action_data['action_name'] = character_action['action_name']

			match shortcut_effect['effect_type']:
				"strike":
					_on_strike_button_pressed()
				"gauge_from_hand":
					select_card_destination = "gauge"
					begin_discard_cards_selection(shortcut_effect['min_amount'], shortcut_effect['max_amount'], UISubState.UISubState_SelectCards_DiscardCardsToGauge, true)
				"choice":
					var instruction_text = "Select an effect for %s:" % prepared_character_action_data['action_name']
					begin_effect_choice(shortcut_effect['choice'], instruction_text, [], true)
				"boost_from_gauge":
					var valid_zones = ['gauge']
					var limitation = ""
					if 'limitation' in shortcut_effect:
						limitation = shortcut_effect['limitation']
					begin_boost_choosing(true, valid_zones, limitation, false)
				"self_discard_choose":
					prepared_character_action_data['destination'] = "discard"
					var min_amount = shortcut_effect['amount']
					var max_amount = shortcut_effect['amount']
					if shortcut_effect['amount'] == -1:
						min_amount = 0
						max_amount = game_wrapper.get_player_hand_size(Enums.PlayerId.PlayerId_Player)
					begin_discard_cards_selection(min_amount, max_amount, UISubState.UISubState_SelectCards_DiscardCards_Choose, true)
				"place_buddy_in_any_space", "move_buddy", "place_buddy_at_range":
					var locations = game_wrapper.get_valid_locations_for_buddy_effect(Enums.PlayerId.PlayerId_Player, shortcut_effect)
					prepared_character_action_data['locations'] = locations
					arena_locations_clickable = locations
					var buddy_name = shortcut_effect['buddy_name']
					var instruction_str = "Select a location to place %s" % buddy_name
					enable_instructions_ui(instruction_str, false, true)
					change_ui_state(UIState.UIState_SelectArenaLocation, UISubState.UISubState_SelectArena_EffectChoice)
				_:
					assert(false, "Unexpected shortcut character action type")
					return
		else:
			complete_character_action_pressed(action_idx)

func finish_preparing_character_action(selections):
	var single_card_id = -1
	var ex_card_id = -1
	if len(selections) == 1:
		single_card_id = selections[0]
	if len(selections) == 2:
		single_card_id = selections[0]
		ex_card_id = selections[1]

	match prepared_character_action_data['effect_type']:
		"strike":
			prepared_character_action_data['card_id'] = single_card_id
			prepared_character_action_data['ex_card_id'] = ex_card_id
		"gauge_from_hand":
			prepared_character_action_data['hand_to_gauge_cards'] = selections
		"choice":
			prepared_character_action_data['choice'] = selections[0]
		"boost_from_gauge":
			if 'boost_card' in prepared_character_action_data and prepared_character_action_data['boost_card']:
				# Returning after paying force cost
				prepared_character_action_data['boost_force'] = selections
			else:
				prepared_character_action_data['boost_card'] = single_card_id
				prepared_character_action_data['boost_force'] = []
				var force_cost = game_wrapper.get_card_database().get_card_boost_force_cost(single_card_id)
				if force_cost > 0:
					selected_boost_to_pay_for = single_card_id
					change_ui_state(null, UISubState.UISubState_SelectCards_ForceForBoost)
					begin_generate_force_selection(force_cost)
					_update_buttons()
					return
		"self_discard_choose":
			prepared_character_action_data['discard_ids'] = selections
		"place_buddy_in_any_space", "move_buddy", "place_buddy_at_range":
			var location = selections[0]
			var location_options = prepared_character_action_data['locations']
			for i in range(location_options.size()):
				if location_options[i] == location:
					prepared_character_action_data['choice'] = i
					break
			prepared_character_action_data['effect_type'] = 'place_buddy_effect'
		_:
			assert(false, "Unexpected prepared character action type")
			return

	complete_character_action_pressed(prepared_character_action_data['action_idx'])

func complete_character_action_pressed(action_idx : int = 0):
	preparing_character_action = false
	var success = game_wrapper.submit_character_action(Enums.PlayerId.PlayerId_Player, [], action_idx, use_free_force)
	if success:
		popout_instruction_info = null
		change_ui_state(UIState.UIState_WaitForGameServer)
	_update_buttons()

func prepared_character_action_data_available(effect_type):
	return prepared_character_action_data and prepared_character_action_data['effect_type'] == effect_type and not preparing_character_action

func _on_choice_pressed(choice):
	# Make sure to unset these so the UI goes away.
	current_effect_choices = []
	current_effect_extra_choice_text = []
	instructions_number_picker_min = -1
	instructions_number_picker_max = -1

	if preparing_character_action:
		finish_preparing_character_action([choice])
	else:
		var success = game_wrapper.submit_choice(Enums.PlayerId.PlayerId_Player, choice)
		if success:
			change_ui_state(UIState.UIState_WaitForGameServer)
	_update_buttons()

func _on_instructions_ok_button_pressed(index : int):
	if can_press_ok():
		var selected_card_ids : Array = []
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

		if preparing_character_action:
			finish_preparing_character_action(selected_card_ids)
			return

		match ui_sub_state:
			UISubState.UISubState_SelectCards_BoostCancel:
				success = game_wrapper.submit_boost_cancel(Enums.PlayerId.PlayerId_Player, selected_card_ids, true)
			UISubState.UISubState_SelectCards_ChooseFromTopdeck:
				var action_choices = game_wrapper.get_decision_info().action
				var chosen_action = action_choices[index]
				success = game_wrapper.submit_choose_from_topdeck(Enums.PlayerId.PlayerId_Player, single_card_id, chosen_action)
			UISubState.UISubState_SelectCards_ChooseDiscardToDestination:
				success = game_wrapper.submit_choose_from_discard(Enums.PlayerId.PlayerId_Player, selected_card_ids)
			UISubState.UISubState_SelectCards_CharacterAction_Force, UISubState.UISubState_SelectCards_CharacterAction_Gauge:
				success = game_wrapper.submit_character_action(Enums.PlayerId.PlayerId_Player, selected_card_ids, selected_character_action, use_free_force)
			UISubState.UISubState_SelectCards_DiscardContinuousBoost, UISubState.UISubState_SelectCards_DiscardOpponentGauge:
				success = game_wrapper.submit_boost_name_card_choice_effect(Enums.PlayerId.PlayerId_Player, single_card_id)
			UISubState.UISubState_SelectCards_DiscardFromReference:
				success = game_wrapper.submit_boost_name_card_choice_effect(Enums.PlayerId.PlayerId_Player, single_card_id - ReferenceScreenIdRangeStart)
			UISubState.UISubState_SelectCards_DiscardCards:
				success = game_wrapper.submit_discard_to_max(Enums.PlayerId.PlayerId_Player, selected_card_ids)
			UISubState.UISubState_SelectCards_DiscardCards_Choose:
				success = game_wrapper.submit_choose_to_discard(Enums.PlayerId.PlayerId_Player, selected_card_ids)
			UISubState.UISubState_SelectCards_ChooseBoostsToSustain:
				success = game_wrapper.submit_choose_from_boosts(Enums.PlayerId.PlayerId_Player, selected_card_ids)
			UISubState.UISubState_SelectCards_DiscardCardsToGauge:
				success = game_wrapper.submit_card_from_hand_to_gauge(Enums.PlayerId.PlayerId_Player, selected_card_ids)
			UISubState.UISubState_SelectCards_StrikeGauge, UISubState.UISubState_SelectCards_StrikeForce:
				success = game_wrapper.submit_pay_strike_cost(Enums.PlayerId.PlayerId_Player, selected_card_ids, false, discard_ex_first_for_strike, use_free_force)
			UISubState.UISubState_SelectCards_Exceed:
				success = game_wrapper.submit_exceed(Enums.PlayerId.PlayerId_Player, selected_card_ids)
			UISubState.UISubState_SelectCards_ForceForEffect:
				success = game_wrapper.submit_force_for_effect(Enums.PlayerId.PlayerId_Player, selected_card_ids, treat_ultras_as_single_force, use_free_force)
			UISubState.UISubState_SelectCards_GaugeForEffect:
				success = game_wrapper.submit_gauge_for_effect(Enums.PlayerId.PlayerId_Player, selected_card_ids)
			UISubState.UISubState_SelectCards_MoveActionGenerateForce:
				success = game_wrapper.submit_move(Enums.PlayerId.PlayerId_Player, selected_card_ids, selected_arena_location, use_free_force)
			UISubState.UISubState_SelectCards_ForceForChange:
				success = game_wrapper.submit_change(Enums.PlayerId.PlayerId_Player, selected_card_ids, treat_ultras_as_single_force, use_free_force)
			UISubState.UISubState_SelectCards_StrikeCard, UISubState.UISubState_SelectCards_StrikeResponseCard, UISubState.UISubState_SelectCards_StrikeCard_FromGauge, UISubState.UISubState_SelectCards_StrikeCard_FromSealed:
				success = game_wrapper.submit_strike(Enums.PlayerId.PlayerId_Player, single_card_id, false, ex_card_id)
			UISubState.UISubState_SelectCards_OpponentSetsFirst_StrikeCard, UISubState.UISubState_SelectCards_OpponentSetsFirst_StrikeResponseCard:
				success = game_wrapper.submit_strike(Enums.PlayerId.PlayerId_Player, single_card_id, false, ex_card_id, true)
			UISubState.UISubState_SelectCards_ForceForArmor:
				success = game_wrapper.submit_force_for_armor(Enums.PlayerId.PlayerId_Player, selected_card_ids, use_free_force)
			UISubState.UISubState_SelectCards_GaugeForArmor:
				success = game_wrapper.submit_force_for_armor(Enums.PlayerId.PlayerId_Player, selected_card_ids, false)
			UISubState.UISubState_SelectCards_Mulligan:
				success = game_wrapper.submit_mulligan(Enums.PlayerId.PlayerId_Player, selected_card_ids)
			UISubState.UISubState_SelectCards_PlayBoost:
				var force_cost = game_wrapper.get_card_database().get_card_boost_force_cost(single_card_id)
				if not select_boost_options['ignore_costs'] and force_cost > 0:
					selected_boost_to_pay_for = single_card_id
					change_ui_state(null, UISubState.UISubState_SelectCards_ForceForBoost)
					begin_generate_force_selection(force_cost)
				else:
					success = game_wrapper.submit_boost(Enums.PlayerId.PlayerId_Player, single_card_id, [], use_free_force)
			UISubState.UISubState_SelectCards_ForceForBoost:
				success = game_wrapper.submit_boost(Enums.PlayerId.PlayerId_Player, selected_boost_to_pay_for, selected_card_ids, use_free_force)
			UISubState.UISubState_PickNumberFromRange:
				success = handle_pick_range_ok()

		if success:
			popout_instruction_info = null
			change_ui_state(UIState.UIState_WaitForGameServer)
		_update_buttons()

func _on_instructions_cancel_button_pressed():
	if observer_mode:
		return

	var success = false

	if preparing_character_action:
		deselect_all_cards()
		close_popout()
		preparing_character_action = false
		prepared_character_action_data = {}
		current_effect_choices = []
		current_effect_extra_choice_text = []
		instructions_number_picker_min = -1
		instructions_number_picker_max = -1
		change_ui_state(UIState.UIState_PickTurnAction, UISubState.UISubState_None)
		_update_buttons()
		return

	match ui_sub_state:
		UISubState.UISubState_SelectCards_ForceForArmor:
			deselect_all_cards()
			close_popout()
			success = game_wrapper.submit_force_for_armor(Enums.PlayerId.PlayerId_Player, [], false)
		UISubState.UISubState_SelectCards_ForceForEffect:
			deselect_all_cards()
			close_popout()
			success = game_wrapper.submit_force_for_effect(Enums.PlayerId.PlayerId_Player, [], false, true, false)
		UISubState.UISubState_SelectCards_GaugeForArmor:
			deselect_all_cards()
			close_popout()
			success = game_wrapper.submit_force_for_armor(Enums.PlayerId.PlayerId_Player, [], false)
		UISubState.UISubState_SelectCards_GaugeForEffect:
			deselect_all_cards()
			close_popout()
			success = game_wrapper.submit_gauge_for_effect(Enums.PlayerId.PlayerId_Player, [])
		UISubState.UISubState_SelectCards_Mulligan:
			deselect_all_cards()
			close_popout()
			success = game_wrapper.submit_mulligan(Enums.PlayerId.PlayerId_Player, [])
		UISubState.UISubState_SelectCards_DiscardCardsToGauge:
			deselect_all_cards()
			close_popout()
			success = game_wrapper.submit_card_from_hand_to_gauge(Enums.PlayerId.PlayerId_Player, [])
		UISubState.UISubState_SelectCards_ChooseBoostsToSustain:
			deselect_all_cards()
			close_popout()
			success = game_wrapper.submit_choose_from_boosts(Enums.PlayerId.PlayerId_Player, [])
		UISubState.UISubState_SelectCards_ChooseDiscardToDestination:
			deselect_all_cards()
			close_popout()
			success = game_wrapper.submit_choose_from_discard(Enums.PlayerId.PlayerId_Player, [])
		UISubState.UISubState_SelectCards_DiscardContinuousBoost:
			deselect_all_cards()
			close_popout()
			success = game_wrapper.submit_boost_name_card_choice_effect(Enums.PlayerId.PlayerId_Player, -1)
		UISubState.UISubState_SelectCards_ChooseFromTopdeck:
			deselect_all_cards()
			close_popout()
			success = game_wrapper.submit_choose_from_topdeck(Enums.PlayerId.PlayerId_Player, -1, "pass")
		UISubState.UISubState_SelectCards_DiscardCards_Choose:
			deselect_all_cards()
			close_popout()
			success = game_wrapper.submit_choose_to_discard(Enums.PlayerId.PlayerId_Player, [])
		UISubState.UISubState_SelectCards_DiscardFromReference:
			deselect_all_cards()
			close_popout()
			success = game_wrapper.submit_boost_name_card_choice_effect(Enums.PlayerId.PlayerId_Player, -1)
		UISubState.UISubState_SelectCards_ForceForBoost:
			deselect_all_cards()
			close_popout()
			if select_boost_options:
				var can_cancel = select_boost_options["can_cancel"]
				var valid_zones = select_boost_options["valid_zones"]
				var limitation = select_boost_options["limitation"]
				var ignore_costs = select_boost_options["ignore_costs"]
				begin_boost_choosing(can_cancel, valid_zones, limitation, ignore_costs)
			else:
				change_ui_state(UIState.UIState_PickTurnAction, UISubState.UISubState_None)
		_:
			match ui_state:
				UIState.UIState_SelectArenaLocation:
					if instructions_cancel_allowed:
						if ui_sub_state == UISubState.UISubState_SelectArena_EffectChoice:
							success = game_wrapper.submit_choice(Enums.PlayerId.PlayerId_Player, 0)
						else:
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
		if preparing_character_action:
			prepared_character_action_data['wild_swing'] = true
			complete_character_action_pressed(prepared_character_action_data['action_idx'])
			deselect_all_cards()
			_update_buttons()
			return

		if ui_sub_state == UISubState.UISubState_SelectCards_StrikeCard or ui_sub_state == UISubState.UISubState_SelectCards_StrikeResponseCard:
			success = game_wrapper.submit_strike(Enums.PlayerId.PlayerId_Player, -1, true, -1)
		elif ui_sub_state == UISubState.UISubState_SelectCards_OpponentSetsFirst_StrikeCard or ui_sub_state == UISubState.UISubState_SelectCards_OpponentSetsFirst_StrikeResponseCard:
			success = game_wrapper.submit_strike(Enums.PlayerId.PlayerId_Player, -1, true, -1, true)
		elif ui_sub_state == UISubState.UISubState_SelectCards_StrikeGauge:
			close_popout()
			success = game_wrapper.submit_pay_strike_cost(Enums.PlayerId.PlayerId_Player, [], true, false, false)
		elif ui_sub_state == UISubState.UISubState_SelectCards_StrikeForce:
			close_popout()
			success = game_wrapper.submit_pay_strike_cost(Enums.PlayerId.PlayerId_Player, [], true, false, use_free_force)
	if success:
		deselect_all_cards()
		change_ui_state(UIState.UIState_WaitForGameServer)
	_update_buttons()

func _on_shortcut_strike_pressed():
	var selected_card_ids : Array = []
	for card in selected_cards:
		selected_card_ids.append(card.card_id)
	deselect_all_cards()

	var success = false
	if len(selected_card_ids) == 1:
		success = game_wrapper.submit_strike(Enums.PlayerId.PlayerId_Player, selected_card_ids[0], false, -1)
	elif len(selected_card_ids) == 2:
		success = game_wrapper.submit_strike(Enums.PlayerId.PlayerId_Player, selected_card_ids[0], false, selected_card_ids[1])
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	_update_buttons()

func _on_shortcut_boost_pressed():
	var card_id : int = selected_cards[0].card_id
	deselect_all_cards()

	var success = false
	var force_cost = game_wrapper.get_card_database().get_card_boost_force_cost(card_id)
	if force_cost > 0:
		select_boost_options = {}
		selected_boost_to_pay_for = card_id
		change_ui_state(null, UISubState.UISubState_SelectCards_ForceForBoost)
		begin_generate_force_selection(force_cost)
	else:
		success = game_wrapper.submit_boost(Enums.PlayerId.PlayerId_Player, card_id, [], use_free_force)

	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	_update_buttons()

func _on_shortcut_character_action_pressed(action_idx : int = 0):
	var selected_card_ids : Array = []
	for card in selected_cards:
		selected_card_ids.append(card.card_id)
	deselect_all_cards()

	var shortcut_effect = game_wrapper.get_player_character_action_shortcut_effect(Enums.PlayerId.PlayerId_Player, action_idx)
	prepared_character_action_data = {
		'effect_type': shortcut_effect['effect_type'],
		'action_idx': action_idx,
	}
	finish_preparing_character_action(selected_card_ids)

func _on_shortcut_change_pressed():
	change_ui_state(null, UISubState.UISubState_SelectCards_ForceForChange)
	select_card_require_force = -1
	enable_instructions_ui("", true, true, false)
	change_ui_state(UIState.UIState_SelectCards)

func _on_shortcut_cancel_pressed():
	deselect_all_cards()
	_update_buttons()

func _on_arena_location_pressed(location):
	selected_arena_location = location
	if ui_state == UIState.UIState_SelectArenaLocation:
		if ui_sub_state == UISubState.UISubState_SelectCards_MoveActionGenerateForce:
			begin_generate_force_selection(game_wrapper.get_force_to_move_to(Enums.PlayerId.PlayerId_Player, location))
		elif ui_sub_state == UISubState.UISubState_SelectArena_EffectChoice:
			if preparing_character_action:
				finish_preparing_character_action([location])
				return
			var decision_info = game_wrapper.get_decision_info()
			var choice_index = 0
			for i in range(decision_info.limitation.size()):
				if decision_info.limitation[i] == location:
					choice_index = i
					break
			_on_choice_pressed(choice_index)

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
	var do_use_free_force = action.use_free_force
	var success = game_wrapper.submit_move(Enums.PlayerId.PlayerId_Opponent, card_ids, location, do_use_free_force)
	if not success:
		printlog("FAILED AI MOVE")
	return success

func ai_handle_change_cards(action : AIPlayer.ChangeCardsAction):
	var card_ids = action.card_ids
	var do_use_free_force = action.use_free_force
	var success = game_wrapper.submit_change(Enums.PlayerId.PlayerId_Opponent, card_ids, false, do_use_free_force)
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
	var payment_card_ids = action.payment_card_ids
	var do_use_free_force = action.use_free_force
	var success = game_wrapper.submit_boost(Enums.PlayerId.PlayerId_Opponent, card_id, payment_card_ids, do_use_free_force)
	if not success:
		printlog("FAILED AI BOOST")
	return success

func ai_handle_strike(action : AIPlayer.StrikeAction):
	var card_id = action.card_id
	var ex_card_id = action.ex_card_id
	var wild_swing = action.wild_swing
	#var opponent_sets_first = action.opponent_strikes_first
	var success = game_wrapper.submit_strike(Enums.PlayerId.PlayerId_Opponent, card_id, wild_swing, ex_card_id)
	if not success:
		printlog("FAILED AI STRIKE")
	return success

func ai_handle_character_action(action : AIPlayer.CharacterActionAction):
	var success = game_wrapper.submit_character_action(Enums.PlayerId.PlayerId_Opponent, action.card_ids, action.action_idx, action.use_free_force)
	if not success:
		printlog("FAILED AI CHARACTER ACTION")
	return success

func ai_take_turn():
	change_ui_state(UIState.UIState_WaitForGameServer)
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

func ai_do_boost(valid_zones : Array, limitation : String, ignore_costs : bool = false):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var boost_action = ai_player.take_boost(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent, valid_zones, limitation, ignore_costs)
	var success = ai_handle_boost(boost_action)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI DO BOOST")

func ai_pay_cost(cost, is_force_cost : bool):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var can_wild = game_wrapper.get_decision_info().type == Enums.DecisionType.DecisionType_PayStrikeCost_CanWild
	var pay_action
	if is_force_cost:
		pay_action = ai_player.pay_strike_force_cost(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent, cost, can_wild)
	else:
		pay_action = ai_player.pay_strike_gauge_cost(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent, cost, can_wild)
	var success = game_wrapper.submit_pay_strike_cost(Enums.PlayerId.PlayerId_Opponent, pay_action.card_ids, pay_action.wild_swing, false, pay_action.use_free_force)
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
	var decision_info = game_wrapper.get_decision_info()
	var use_gauge_instead = decision_info.limitation == "gauge"
	var forceforarmor_action = ai_player.pick_force_for_armor(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent, use_gauge_instead)
	var success = game_wrapper.submit_force_for_armor(Enums.PlayerId.PlayerId_Opponent, forceforarmor_action.card_ids, forceforarmor_action.use_free_force)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI FORCE FOR ARMOR")

func ai_force_for_effect(effect):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var options = []
	if effect['per_force_effect'] != null:
		for i in range(effect['force_max'] + 1):
			options.append(i)
	else:
		var required = 'required' in effect and effect['required']
		if not required:
			options.append(0)
		options.append(effect['force_max'])
	var forceforeffect_action = ai_player.pick_force_for_effect(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent, options)
	var success = game_wrapper.submit_force_for_effect(Enums.PlayerId.PlayerId_Opponent, forceforeffect_action.card_ids, false, forceforeffect_action.use_free_force)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI FORCE FOR EFFECT")

func ai_gauge_for_effect(effect):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var options = []
	if effect['per_gauge_effect'] != null:
		for i in range(effect['gauge_max'] + 1):
			options.append(i)
	else:
		if not 'required' in effect or not effect['required']:
			options.append(0)
		options.append(effect['gauge_max'])
	var gauge_action = ai_player.pick_gauge_for_effect(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent, options)
	var success = game_wrapper.submit_gauge_for_effect(Enums.PlayerId.PlayerId_Opponent, gauge_action.card_ids)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI GAUGE FOR EFFECT")

func ai_strike_response():
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var response_action = ai_player.pick_strike_response(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent)
	var success = game_wrapper.submit_strike(Enums.PlayerId.PlayerId_Opponent, response_action.card_id, response_action.wild_swing, response_action.ex_card_id)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI STRIKE RESPONSE")

func ai_strike_effect_do_strike(card_id : int, wild_swing : bool, ex_card_id : int):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var success = game_wrapper.submit_strike(Enums.PlayerId.PlayerId_Opponent, card_id, wild_swing, ex_card_id)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI EFFECT CAUSED STRIKE")

func ai_discard(event):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var discard_action = ai_player.pick_discard_to_max(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent, event['number'])
	var success = game_wrapper.submit_discard_to_max(Enums.PlayerId.PlayerId_Opponent, discard_action.card_ids)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI DISCARD")

func ai_forced_strike(disable_wild_swing : bool = false, disable_ex : bool = false):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var strike_action = ai_player.pick_strike(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent, "", disable_wild_swing, disable_ex)
	ai_handle_strike(strike_action)

func ai_strike_from_gauge(source : String):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var strike_action = ai_player.pick_strike(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent, source)
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

func ai_discard_continuous_boost(limitation, can_pass):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var pick_action = ai_player.pick_discard_continuous(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent,limitation, can_pass)
	var success = game_wrapper.submit_boost_name_card_choice_effect(Enums.PlayerId.PlayerId_Opponent, pick_action.card_id)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI DISCARD CONTINUOUS")

func ai_discard_opponent_gauge():
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var pick_action = ai_player.pick_discard_opponent_gauge(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent)
	var success = game_wrapper.submit_boost_name_card_choice_effect(Enums.PlayerId.PlayerId_Opponent, pick_action.card_id)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI DISCARD OPPONENT GAUGE")

func ai_name_opponent_card(normal_only : bool, can_use_own_reference : bool):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var pick_action = ai_player.pick_name_opponent_card(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent, normal_only, can_use_own_reference)
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

func ai_choose_from_boosts(amount : int):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var choose_action = ai_player.pick_choose_from_boosts(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent, amount)
	var success = game_wrapper.submit_choose_from_boosts(Enums.PlayerId.PlayerId_Opponent, choose_action.card_ids)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI CHOOSE FROM BOOSTS")

func ai_choose_from_discard(amount : int):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var discard_action = ai_player.pick_choose_from_discard(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent, amount)
	var success = game_wrapper.submit_choose_from_discard(Enums.PlayerId.PlayerId_Opponent, discard_action.card_ids)
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

func ai_choose_to_discard(amount, limitation, can_pass):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var discard_action = ai_player.pick_choose_to_discard(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent, amount, limitation, can_pass)
	var success = game_wrapper.submit_choose_to_discard(Enums.PlayerId.PlayerId_Opponent, discard_action.card_ids)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI CHOOSE TO DISCARD")

func ai_choose_from_topdeck(action_choices : Array, look_amount : int, can_pass : bool):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var choose_topdeck_action = ai_player.pick_choose_from_topdeck(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent, action_choices, look_amount, can_pass)
	var success = game_wrapper.submit_choose_from_topdeck(Enums.PlayerId.PlayerId_Opponent, choose_topdeck_action.card_id, choose_topdeck_action.action)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI CHOOSE FROM TOPDECK")

func ai_choose_arena_location_for_effect(location_choices : Array):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var choose_location_action = ai_player.pick_choose_arena_location_for_effect(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent, location_choices)
	var chosen_location = choose_location_action.location
	var choice_index = 0
	for i in range(len(location_choices)):
		if location_choices[i] == chosen_location:
			choice_index = i
			break
	var success = game_wrapper.submit_choice(Enums.PlayerId.PlayerId_Opponent, choice_index)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI CHOOSE ARENA LOCATION FOR EFFECT")

func ai_pick_number_from_range(choices : Array, effects : Array):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var choose_action = ai_player.pick_number_from_range_for_effect(game_wrapper.current_game, Enums.PlayerId.PlayerId_Opponent, choices, effects)
	var chosen_number = choose_action.number
	var choice_index = 0
	for i in range(len(choices)):
		if choices[i] == chosen_number:
			choice_index = i
			break

	var success = game_wrapper.submit_choice(Enums.PlayerId.PlayerId_Opponent, choice_index)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI CHOOSE NUMBER FROM RANGE")

# Popout Functions
func card_in_selected_cards(card):
	for selected_card in selected_cards:
		if selected_card.card_id == card.card_id:
			return true
	return false

func _update_popout_cards(cards_in_popout : Array, filtering_allowed : bool = false, show_amount : bool = true):
	var card_popout = card_popout_parent.get_child(0)
	if show_amount:
		card_popout.set_amount(str(len(cards_in_popout)))
	else:
		card_popout.set_amount("")

	var cards = []
	for card in cards_in_popout:
		if filtering_allowed and popout_show_normal_only() and not game_wrapper.get_card_database().is_normal_card(card.card_id - ReferenceScreenIdRangeStart):
			continue
		cards.append(card)

	card_popout.show_cards(cards)
	for card in selected_cards:
		card_popout.modify_card_selection(card.card_id, true)

func close_popout():
	while card_popout_parent.get_child_count() > 0:
		var child = card_popout_parent.get_child(0)
		card_popout_parent.remove_child(child)
		child.queue_free()

func update_popout_instructions():
	if card_popout_parent.get_child_count() == 0:
		return
	var popout = card_popout_parent.get_child(0)
	if popout_instruction_info and popout_type_showing == popout_instruction_info['popout_type']:
		popout.set_instructions(popout_instruction_info)
	else:
		popout.set_instructions(null)

func popout_show_normal_only() -> bool:
	if popout_instruction_info and 'normal_only' in popout_instruction_info:
		return popout_instruction_info['normal_only']
	return false

func show_popout(popout_type : CardPopoutType, popout_title : String, card_node,
		show_amount : bool = true, force_hide_reshuffle = false, extra_only_show_boosts = false):
	close_popout()

	var card_popout = CardPopoutScene.instantiate()
	card_popout_parent.add_child(card_popout)
	card_popout.close_window.connect(_on_popout_close_window)
	card_popout.pressed_ok.connect(_on_card_popout_pressed_ok)
	card_popout.pressed_cancel.connect(_on_card_popout_pressed_cancel)
	card_popout.pressed_toggle.connect(_on_card_popout_pressed_toggle)
	card_popout.card_clicked.connect(_on_card_popout_card_clicked)

	popout_type_showing = popout_type

	var toggle_text = ""
	var toggle_visible = false
	if popout_type == CardPopoutType.CardPopoutType_ReferenceOpponent and not force_hide_reshuffle:
		toggle_visible = true
		if reference_popout_toggle_enabled:
			if reference_popout_toggle:
				toggle_text = "Show current cards"
			else:
				toggle_text = "Show cards before reshuffle"
	card_popout.set_reference_toggle(toggle_text, toggle_visible)

	update_popout_instructions()
	card_popout.set_title(popout_title)
	var cards = card_node.get_children()

	var check_player = Enums.PlayerId.PlayerId_Unassigned
	if popout_type == CardPopoutType.CardPopoutType_BuddyPlayer:
		check_player = Enums.PlayerId.PlayerId_Player
		if extra_only_show_boosts:
			cards = cards.filter(func(card): return game_wrapper.can_player_boost(Enums.PlayerId.PlayerId_Player, card.card_id, ['extra'], "", true))
	elif popout_type == CardPopoutType.CardPopoutType_BuddyOpponent:
		check_player = Enums.PlayerId.PlayerId_Opponent
	if check_player != Enums.PlayerId.PlayerId_Unassigned:
		var filtered_cards = []
		for card in cards:
			if card.card_id != CardBase.BuddyCardReferenceId:
				if not game_wrapper.is_card_set_aside(check_player, card.card_id):
					continue
			filtered_cards.append(card)
		cards = filtered_cards

	var filtering_allowed = popout_type == CardPopoutType.CardPopoutType_ReferenceOpponent
	_update_popout_cards(cards, filtering_allowed, show_amount)

func get_boost_zone_center(zone):
	var pos = zone.global_position + CardBase.get_hand_card_size() / 2
	pos.x += CardBase.get_hand_card_size().x / 2
	return pos

func _on_player_gauge_gauge_clicked():
	show_popout(CardPopoutType.CardPopoutType_GaugePlayer, "YOUR GAUGE", $AllCards/PlayerGauge)

func _on_opponent_gauge_gauge_clicked():
	show_popout(CardPopoutType.CardPopoutType_GaugeOpponent, "THEIR GAUGE", $AllCards/OpponentGauge)

func _on_player_sealed_clicked():
	show_popout(CardPopoutType.CardPopoutType_SealedPlayer, "YOUR SEALED AREA", $AllCards/PlayerSealed)

func _on_opponent_sealed_clicked():
	show_popout(CardPopoutType.CardPopoutType_SealedOpponent, "THEIR SEALED AREA", $AllCards/OpponentSealed)

func _on_player_overdrive_gauge_clicked():
	show_popout(CardPopoutType.CardPopoutType_OverdrivePlayer, "YOUR OVERDRIVE", $AllCards/PlayerOverdrive)

func _on_opponent_overdrive_gauge_clicked():
	show_popout(CardPopoutType.CardPopoutType_OverdriveOpponent, "THEIR OVERDRIVE", $AllCards/OpponentOverdrive)

func _on_player_discard_button_pressed():
	show_popout(CardPopoutType.CardPopoutType_DiscardPlayer, "YOUR DISCARDS", $AllCards/PlayerDiscards)

func _on_opponent_discard_button_pressed():
	show_popout(CardPopoutType.CardPopoutType_DiscardOpponent, "THEIR DISCARD", $AllCards/OpponentDiscards)

func _on_player_boost_zone_clicked_zone():
	var sustained_card_ids = game_wrapper.get_player_sustained_boosts(Enums.PlayerId.PlayerId_Player)
	for card in $AllCards/PlayerBoosts.get_children():
		if card.card_id in sustained_card_ids:
			card.set_label("Sustained")
		else:
			card.clear_label()
	show_popout(CardPopoutType.CardPopoutType_BoostPlayer, "YOUR BOOSTS", $AllCards/PlayerBoosts)

func _on_opponent_boost_zone_clicked_zone():
	show_popout(CardPopoutType.CardPopoutType_BoostOpponent, "THEIR BOOSTS", $AllCards/OpponentBoosts)

func _on_popout_close_window():
	close_popout()

func _on_player_reference_button_pressed():
	for card in $AllCards/PlayerAllCopy.get_children():
		if card.card_id < 0:
			continue
		var id = card.card_id - ReferenceScreenIdRangeStart
		var logic_card = game_wrapper.get_card_database().get_card(id)
		var card_str_id = logic_card.definition['id']
		var count = game_wrapper.count_cards_in_deck_and_hand(Enums.PlayerId.PlayerId_Player, card_str_id)
		card.set_remaining_count(count)
	var reference_title = "YOUR DECK REFERENCE (showing remaining card counts in deck+hand"
	if game_wrapper.is_player_sealed_area_secret(Enums.PlayerId.PlayerId_Player):
		reference_title += "+sealed"
	reference_title += ")"
	show_popout(CardPopoutType.CardPopoutType_ReferencePlayer, reference_title, $AllCards/PlayerAllCopy, false)

func _on_opponent_reference_button_pressed(switch_toggle : bool = false, hide_reshuffle : bool = false):
	if switch_toggle:
		reference_popout_toggle = not reference_popout_toggle
	else:
		reference_popout_toggle = false

	var public_hand_info = game_wrapper.get_player_public_hand_info(Enums.PlayerId.PlayerId_Opponent)

	for card in $AllCards/OpponentAllCopy.get_children():
		if card.card_id < 0:
			continue
		var id = card.card_id - ReferenceScreenIdRangeStart
		var logic_card = game_wrapper.get_card_database().get_card(id)
		var card_str_id = logic_card.definition['id']
		var count = 0
		var hide_icons = false
		if reference_popout_toggle:
			hide_icons = true
			count = game_wrapper.count_cards_in_deck_and_hand(Enums.PlayerId.PlayerId_Opponent, card_str_id, opponent_cards_before_reshuffle)
		else:
			count = game_wrapper.count_cards_in_deck_and_hand(Enums.PlayerId.PlayerId_Opponent, card_str_id)
		card.set_remaining_count(count)
		var known_count = 0
		var questionable_count = 0
		var on_topdeck = false
		if not hide_icons:
			if card_str_id in public_hand_info['known']:
				known_count = public_hand_info['known'][card_str_id]
			if card_str_id in public_hand_info['questionable']:
				questionable_count = public_hand_info['questionable'][card_str_id]
			on_topdeck = card_str_id == public_hand_info['topdeck']
		card.update_hand_icons(known_count, questionable_count, on_topdeck, false)
	var popout_title = "THEIR DECK REFERENCE (showing remaining card counts in deck+hand"
	if reference_popout_toggle:
		popout_title = "THEIR CARDS BEFORE RESHUFFLE (remained in deck+hand"
	if game_wrapper.is_player_sealed_area_secret(Enums.PlayerId.PlayerId_Player):
		popout_title += "+sealed"
	popout_title += ")"
	show_popout(CardPopoutType.CardPopoutType_ReferenceOpponent, popout_title, $AllCards/OpponentAllCopy, false, hide_reshuffle)

func _on_player_buddy_button_pressed(only_show_boosts = false):
	show_popout(CardPopoutType.CardPopoutType_BuddyPlayer, "YOUR EXTRA CARDS", $AllCards/PlayerBuddyCopy, true, false, only_show_boosts)

func _on_opponent_buddy_button_pressed():
	show_popout(CardPopoutType.CardPopoutType_BuddyOpponent, "THEIR EXTRA CARDS", $AllCards/OpponentBuddyCopy)

func _on_exit_to_menu_pressed():
	modal_dialog.set_text_fields("Are you sure you want to quit?", "QUIT TO\nMENU", "CANCEL")
	modal_dialog_type = ModalDialogType.ModalDialogType_ExitToMenu

func _quit_to_menu():
	exiting = true
	game_wrapper.end_game()
	NetworkManager.leave_room()
	returning_from_game.emit()
	queue_free()

func _on_revealed_cards_button_pressed():
	reset_revealed_cards()
	var public_hand_info = game_wrapper.get_player_public_hand_info(Enums.PlayerId.PlayerId_Opponent)
	var card_ids = []
	for card_str_id in public_hand_info['all']:
		# Find a card id that matches this card definition str.
		# It doesn't matter which one for the purposes of this UI.
		for card in $AllCards/OpponentAllCopy.get_children():
			if card.card_id < 0:
				continue
			var id = card.card_id - ReferenceScreenIdRangeStart
			var logic_card = game_wrapper.get_card_database().get_card(id)
			if logic_card.definition['id'] == card_str_id:
				card_ids.append(id)
				break

	# Create cards for all of these and add them to the OpponentRevealed node.
	for card_id in card_ids:
		add_revealed_card(card_id)

	# Update the hand icons for all cards here.
	for card in $AllCards/OpponentRevealed.get_children():
		var id = card.card_id - RevealCopyIdRangestart
		var logic_card = game_wrapper.get_card_database().get_card(id)
		var card_str_id = logic_card.definition['id']
		var known_count = 0
		var questionable_count = 0
		var on_topdeck = false
		if card_str_id in public_hand_info['known']:
			known_count = public_hand_info['known'][card_str_id]
		if card_str_id in public_hand_info['questionable']:
			questionable_count = public_hand_info['questionable'][card_str_id]
		on_topdeck = card_str_id == public_hand_info['topdeck']
		card.update_hand_icons(known_count, questionable_count, on_topdeck, false)

	show_popout(CardPopoutType.CardPopoutType_RevealedOpponent, "KNOWN CARDS", $AllCards/OpponentRevealed)

func _on_card_popout_pressed_ok(index):
	_on_instructions_ok_button_pressed(index)

func _on_card_popout_pressed_cancel():
	_on_instructions_cancel_button_pressed()

func _on_card_popout_pressed_toggle():
	_on_opponent_reference_button_pressed(true)


func _on_combat_log_button_pressed():
	var log_text = game_wrapper.get_combat_log(combat_log.get_filters(), combat_log.log_player_color, combat_log.log_opponent_color)
	combat_log.set_text(log_text)
	combat_log.visible = true

func _on_combat_log_close_button_pressed():
	combat_log.visible = false


func _on_action_menu_choice_selected(choice_index):
	var action = current_action_menu_choices[choice_index]['action']
	action.call()

func _on_choice_popout_show_button_pressed():
	show_popout(CardPopoutType.CardPopoutType_ChoiceZone, "TOP OF DECK", $AllCards/ChoiceZone)

func _on_modal_dialog_accept_button_pressed():
	match modal_dialog_type:
		ModalDialogType.ModalDialogType_ExitToMenu:
			_quit_to_menu()

func _on_emote_button_pressed():
	emote_dialog.visible = true

func _on_emote_dialog_close_button_pressed():
	emote_dialog.visible = false

func _on_emote_dialog_emote_selected(is_image_emote : bool, emote : String):
	if observer_mode:
		return
	emote_dialog.visible = false
	game_wrapper.submit_emote(Enums.PlayerId.PlayerId_Player, is_image_emote, emote)

func _on_action_menu_ultra_force_toggled(new_value):
	treat_ultras_as_single_force = new_value
	_update_buttons()

func _on_action_menu_discard_ex_first_toggled(new_value):
	discard_ex_first_for_strike = new_value
	_update_buttons()

func _on_action_menu_free_force_toggled(new_value):
	use_free_force = new_value
	_update_buttons()

func _on_observer_next_button_pressed():
	if ui_state == UIState.UIState_WaitForGameServer or ui_state == UIState.UIState_WaitingOnOpponent:
		var processed_something = game_wrapper.observer_process_next_message_from_queue()
		if not processed_something:
			# Caught up to live play.
			observer_next_button.disabled = true
			observer_next_button.text = "LIVE"
			observer_live = true

func _on_observer_play_to_live_pressed():
	observer_next_button.disabled = true
	observer_next_button.text = "LIVE"
	observer_live = true
	observer_play_to_live_button.visible = false
