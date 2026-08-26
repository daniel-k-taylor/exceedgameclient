# This is an instance of the game.
class_name Game
extends Node2D

signal returning_from_game
signal load_characters_complete

const UseHugeCard = false

const Test_StartWithGauge = false

const CardBaseScene = preload("res://scenes/card/card_base.tscn")
const CardPopoutScene = preload("res://scenes/game/card_popout.tscn")
const CharacterScene = preload("res://scenes/game/character.tscn")
const BackgroundManager = preload("res://globals/game_background_manager.gd")

@onready var player_emote : EmoteDisplay = $PlayerEmote
@onready var opponent_emote : EmoteDisplay = $OpponentEmote

@onready var damage_popup_template = preload("res://scenes/game/damage_popup.tscn")
@onready var arena_layout = $ArenaNode/RowButtons
@onready var arena_graphics = $ArenaNode/RowPlatforms
@onready var friend_track_layer : TextureRect = $FriendTrackLayer
@onready var enemy_track_layer : TextureRect = $EnemyTrackLayer
@onready var background_image : TextureRect = $BackgroundImage

# Extra track overlay layers for wide characters when a non-classic background
# is active. Built lazily in _initialize_track_overlay_layers().
var friend_track_overlay_layers : Array[TextureRect] = []
var enemy_track_overlay_layers : Array[TextureRect] = []
var resolved_arena_style : String = BackgroundManager.DEFAULT_BACKGROUND_ID

@onready var huge_card : Sprite2D = $HugeCard

@onready var emote_dialog : EmoteDialog = $EmoteDialog
@onready var modal_dialog : ModalDialog = $ModalDialog

@onready var save_replay_button = $PlayerZones/SaveReplayButton
@onready var file_dialog = $FileDialog

@onready var slideout_dialog : SlideoutDialog = $SlideoutDialog

# Rotation reflow + runtime health debug overlay nodes (added in game.tscn).
# Fetched defensively so game.gd still works if the nodes are absent.
@onready var rotation_layout_overlay : Control = get_node_or_null("RotationLayoutOverlay")
@onready var runtime_health_debug_panel : Control = get_node_or_null("RuntimeHealthDebugPanel")
@onready var runtime_health_debug_label : Label = get_node_or_null("RuntimeHealthDebugPanel/MarginContainer/RuntimeHealthDebugLabel")
@onready var runtime_health_debug_toggle_button : Button = get_node_or_null("RuntimeHealthDebugToggleButton")

const OffScreen = Vector2(-1000, -1000)
const ChoiceCopyIdRangeStart = 70000
const RevealCopyIdRangestart = 80000
const ReferenceScreenIdRangeStart = 90000
const NoticeOffsetY = 50
# Layout is authored against this fixed base size and scaled to the live viewport.
const BaseViewportSize = Vector2(1280.0, 720.0)

const SlideoutStartPosition = Vector2(1280, 380)

var starting_timer : float = GlobalSettings.DefaultStartingTimer
var player_clock_remaining : float = GlobalSettings.DefaultStartingTimer
var opponent_clock_remaining : float = GlobalSettings.DefaultStartingTimer
var enforce_timer = GlobalSettings.DefaultEnforceTimer
var minimum_time_per_choice = GlobalSettings.DefaultMinimumTimePerChoice
var current_clock_user : Enums.PlayerId = Enums.PlayerId.PlayerId_Unassigned
var new_clock_user_assigned : bool = false
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

# --- Web-runtime health governor tuning (all no-op when not running on web) ---
const WebRuntimeAnimationBacklogThreshold : int = 8
const WebRuntimeAnimationBacklogScale : float = 0.25
const WebRuntimeAnimationMinimumDelay : float = 0.1
const WebRuntimeLoadYieldBatchSize : int = 4
const WebRuntimeArenaVisualYieldFrames : int = 1
const WebRuntimeEventYieldBatchSize : int = 6
const WebRuntimeEventYieldDelay : float = 0.05
const WebRuntimeRotationSettleFrames : int = 2
const WebRuntimeMinimumViewportSize := Vector2(320.0, 240.0)
const WebRuntimeMaximumInvalidViewportRetries : int = 8
const WebRuntimeBacklogThresholdModerate : int = 12
const WebRuntimeBacklogThresholdSevere : int = 24
const WebRuntimeEventBudgetUnlimited : int = -1
const WebRuntimeEventBudgetModerate : int = 8
const WebRuntimeEventBudgetSevere : int = 4
const WebRuntimeSlowFrameWarningDelta : float = 0.05
const WebRuntimeSlowFrameSevereDelta : float = 0.085
const WebRuntimeSlowFrameWarningCount : int = 1
const WebRuntimeSlowFrameSevereCount : int = 3
const WebRuntimeRecoveryStableFrames : int = 45
const ShowRuntimeHealthDebugOverlay : bool = true
const CombatLogVisibleEntryLimit = 500

enum RuntimeBacklogLevel {
	RuntimeBacklogLevel_None,
	RuntimeBacklogLevel_Moderate,
	RuntimeBacklogLevel_Severe,
}

enum RuntimeFramePressureLevel {
	RuntimeFramePressureLevel_None,
	RuntimeFramePressureLevel_Warning,
	RuntimeFramePressureLevel_Severe,
}

enum RuntimeHealthState {
	RuntimeHealthState_Healthy,
	RuntimeHealthState_Warning,
	RuntimeHealthState_Backlogged,
	RuntimeHealthState_Recovery,
}

var remaining_delay = 0
# RESERVED HOOK (a) reconnect restore fast-forward: the reconnect workstream drives
# these two flags. The health governor already consults `restore_fast_forwarding`
# so replay fast-forward stays "Healthy". Left defaulted so game.gd compiles today.
var restore_fast_forward_pending := false
var restore_fast_forwarding := false
var events_to_process = []

# Web-runtime health governor state (all inert off web).
var runtime_health_debug_overlay_enabled : bool = false
var runtime_backlog_level : int = RuntimeBacklogLevel.RuntimeBacklogLevel_None
var runtime_health_state : int = RuntimeHealthState.RuntimeHealthState_Healthy
var runtime_pending_event_pressure_count : int = 0
var runtime_slow_frame_count : int = 0
var runtime_stable_frame_count : int = WebRuntimeRecoveryStableFrames
var runtime_last_frame_delta : float = 0.0
var runtime_event_batch_in_progress : bool = false
var deferred_player_hand_layout : bool = false
var deferred_opponent_hand_layout : bool = false
var deferred_card_count_refresh : bool = false

# Responsive layout + rotation reflow state.
var _viewport_layout_ready : bool = false
var _viewport_layout_generation : int = 0
var _rotation_layout_in_progress : bool = false
var _last_stable_viewport_size : Vector2 = BaseViewportSize
var _responsive_position_nodes : Array = []
var _responsive_anchor_roots : Array = []

var damage_popup_pool:Array[DamagePopup] = []

var insert_ai_pause = false
var popout_instruction_info = null
var ignore_queue_notifications = false

var ChoiceTagRegex = RegEx.new()

var first_run_done = false
var first_run_in_progress = false
var setup_characters_complete = false
var select_card_require_min = 0
var select_card_require_max = 0
var select_card_restriction_ids = []
var select_card_show_restriction_list_ui = false
var select_card_name_card_both_players = false
var select_card_must_be_max_or_min = false
var select_card_require_force = 0
var select_card_up_to_force = 0
var select_card_destination = ""
var select_gauge_require_card_id = ""
var select_gauge_require_card_name = ""
var select_gauge_valid_card_types = []
var select_boost_options = {}
var select_card_name_boost_restriction = ""
var selected_boost_to_pay_for = -1
# Renea: face-up (false) / face-down (true) placement chosen for a continuous
# boost whose cost is still being paid. null means "use the card's default".
var selected_boost_facedown_override = null
var instructions_ok_allowed = false
var instructions_cancel_allowed = false
var instructions_strike_options = {}
var instructions_pay_alternative_life_cost = 0
var instructions_ex_allowed = false
var instructions_ex_required = false
var instructions_face_attack_card = null
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
var can_spend_life_for_force = false
var can_spend_life_for_gauge = false
# Minato "seal cards to pay costs": while true, the number picker seals top
# discards to generate Force / Gauge for the current payment.
var can_seal_for_force = false
var can_seal_for_gauge = false
var current_pay_costs_is_ex = false
var preparing_character_action = false
var prepared_character_action_data = {}
var choice_popout_title = ""

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
	UISubState_SelectCards_ChooseOpponentCardToDiscard,
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
	UISubState_SelectCards_GaugeForBoost
}

var ui_state : UIState = UIState.UIState_Initializing
var ui_sub_state : UISubState = UISubState.UISubState_None

var previous_ui_state : UIState = UIState.UIState_Initializing
var previous_ui_sub_state : UISubState = UISubState.UISubState_None

var game_wrapper : GameWrapper = GameWrapper.new()
var ai_player : AIPlayer
@onready var card_popout_parent : Node2D = $CardPopoutParent
@onready var choice_zone_parent : Node2D = $AllCards/ChoiceZone
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
@onready var boostinfo_dict : Dictionary = {
	Enums.PlayerId.PlayerId_Player: [
		$PlayerZones/BoostInfoContainer/PlayerBoostInfoButton1,
		$PlayerZones/BoostInfoContainer/PlayerBoostInfoButton2
	],
	Enums.PlayerId.PlayerId_Opponent: [
		$OpponentZones/BoostInfoContainer/OpponentBoostInfoButton1,
		$OpponentZones/BoostInfoContainer/OpponentBoostInfoButton2
	]
}
@onready var boostinfo_parent_dict : Dictionary = {
	Enums.PlayerId.PlayerId_Player: $PlayerZones/BoostInfoContainer,
	Enums.PlayerId.PlayerId_Opponent: $OpponentZones/BoostInfoContainer
}

var player_lightningrod_tracking = {}
var opponent_lightningrod_tracking = {}
var player_underboost_tracking = []
var opponent_underboost_tracking = []

var current_instruction_text : String = ""
var current_action_menu_choices : Array = []
var current_effect_choices : Array = []
var current_effect_extra_choice_text : Array = []
var current_topdeck_choosing_player = Enums.PlayerId.PlayerId_Player
var instructions_number_picker_min = -1
var instructions_number_picker_max = -1
var show_thinking_spinner_in : float = 0
const ThinkingSpinnerWaitBeforeShowTime = 1.0
var starting_message = null
var replay_saving_enabled = false
var observer_mode = false
var observer_live = false
var replay_mode = false
var exiting = false

@onready var CenterCardOval = Vector2(get_viewport().content_scale_size) * Vector2(0.5, 1.35)
@onready var HorizontalRadius = get_viewport().content_scale_size.x * 0.55
@onready var VerticalRadius = get_viewport().content_scale_size.y * 0.4

func printlog(text):
	if GlobalSettings.is_logging_enabled():
		print("UI: %s" % text)

# --- Tournelouse transform choices ---
# All of Tournelouse's transform-related decisions are optional and select cards
# from the transform zone rather than the boost zone, so the UI needs to detect
# them to offer a Cancel button and to allow selecting the right cards.

func is_tournelouse_transform_bonus_choice() -> bool:
	if not game_wrapper:
		return false
	var decision_effect = game_wrapper.get_decision_info().effect
	return decision_effect != null and decision_effect.get("effect_type") in [StrikeEffects.SealTransformForPowerup, StrikeEffects.SealTransformForArmorup]

func is_tournelouse_transform_zone_choice() -> bool:
	if not game_wrapper:
		return false
	var decision_effect = game_wrapper.get_decision_info().effect
	return decision_effect != null and (is_tournelouse_transform_bonus_choice() or decision_effect.get("tournelouse_ouroboros") or decision_effect.get("tournelouse_ouroboros_return_transform"))

func is_tournelouse_ouroboros_force_choice() -> bool:
	if not game_wrapper:
		return false
	var decision_effect = game_wrapper.get_decision_info().effect
	return decision_effect != null and decision_effect.get("tournelouse_ouroboros_force")

func is_tournelouse_ouroboros_hand_choice() -> bool:
	if not game_wrapper:
		return false
	var decision_effect = game_wrapper.get_decision_info().effect
	return decision_effect != null and decision_effect.get("tournelouse_ouroboros_select_hand")

func is_tournelouse_ouroboros_transform_return_choice() -> bool:
	if not game_wrapper:
		return false
	var decision_effect = game_wrapper.get_decision_info().effect
	return decision_effect != null and decision_effect.get("tournelouse_ouroboros_return_transform")

func is_tournelouse_ouroboros_legal_hand_transform(card_id : int) -> bool:
	if not game_wrapper:
		return false
	var decision_info = game_wrapper.get_decision_info()
	return decision_info.choice != null and card_id in decision_info.choice

func is_tournelouse_ouroboros_paid_card(card_id : int) -> bool:
	if not game_wrapper:
		return false
	var decision_effect = game_wrapper.get_decision_info().effect
	return decision_effect != null and card_id in decision_effect.get("paid_card_ids", [])

# Bargeist Fang can't be returned when doing so would leave a duplicate of the
# normal card being transformed already in the transform zone.
func is_tournelouse_ouroboros_bargeist_return_blocked(card_id : int) -> bool:
	if not game_wrapper:
		return false
	var decision_effect = game_wrapper.get_decision_info().effect
	if decision_effect == null or not decision_effect.get("tournelouse_ouroboros_return_transform"):
		return false
	if game_wrapper.get_card_database().get_card(card_id).definition.get("id") != "tournelouse_bargeist_fang":
		return false
	var hand_card_id = decision_effect.get("hand_card_id", -1)
	if hand_card_id == -1:
		return false
	var hand_card = game_wrapper.get_card_database().get_card(hand_card_id)
	if hand_card.definition['type'] != "normal":
		return false
	for boost_card in $AllCards/PlayerBoosts.get_children():
		if boost_card.card_id != card_id and game_wrapper.is_card_in_transforms(Enums.PlayerId.PlayerId_Player, boost_card.card_id):
			var transform_card = game_wrapper.get_card_database().get_card(boost_card.card_id)
			if transform_card.definition['display_name'] == hand_card.definition['display_name']:
				return true
	return false

# Called when the node enters the scene tree for the first time.
var started_directly : bool = true
var image_loader : CardImageLoader

func set_not_started_directly():
	started_directly = false

func _ready():
	image_loader = CardImageLoader.new()
	add_child(image_loader)

	resolved_arena_style = BackgroundManager.resolve_background_id(GlobalSettings.ArenaStyle)
	_initialize_track_overlay_layers()

	_initialize_responsive_layout_state()
	if get_viewport():
		get_viewport().size_changed.connect(_on_viewport_size_changed)

	NetworkManager.connect("players_update", _on_players_update)

	if started_directly:
		# Started this scene directly.
		var vs_info = {
			'player_deck': CardDataManager.get_deck_test_deck(),
			'opponent_deck': CardDataManager.get_deck_test_deck(),
			'randomize_first_vs_ai': false
		}
		begin_local_game(vs_info)
		initialization_after_begin_game()

func initialization_after_begin_game():
	if not game_wrapper.is_ai_game():
		$AIMoveButton.visible = false
	else:
		# AI difficulty is a persistent local preference. Default is the fair
		# "rules" policy; "omniscient" is an opt-in cheating (hard) AI that reads
		# hidden information.
		var ai_policy : Node = AIPolicyRules.new()
		if GlobalSettings.AIMode == "omniscient":
			ai_policy = AIPolicyOmniscient.new()
		ai_player = AIPlayer.new(game_wrapper.current_game, game_wrapper.current_game.opponent, ai_policy)

	$PlayerLife.set_life(game_wrapper.get_player_life(Enums.PlayerId.PlayerId_Player))
	$OpponentLife.set_life(game_wrapper.get_player_life(Enums.PlayerId.PlayerId_Opponent))
	game_over_stuff.visible = false
	if not observer_mode:
		$PlayerLife.set_clock(starting_timer)
		$OpponentLife.set_clock(starting_timer)

	player_bonus_panel.visible = false
	opponent_bonus_panel.visible = false
	player_bonus_label.text = ""
	opponent_bonus_label.text = ""

	observer_next_button.visible = observer_mode
	observer_play_to_live_button.visible = observer_mode
	if replay_mode:
		observer_play_to_live_button.visible = false
		observer_next_button.position = observer_play_to_live_button.position

	save_replay_button.visible = false
	file_dialog.visible = false

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
	_viewport_layout_ready = true
	_refresh_viewport_layout_metrics(true)

func _on_players_update(_players, _matches, _queues : Array, newly_available_match : bool):
	if (game_wrapper.is_ai_game() or observer_mode) and newly_available_match:
		# Let the player know there is a match they could join.
		show_match_available_notification()

func show_match_available_notification():
	if not ignore_queue_notifications:
		slideout_dialog.position = SlideoutStartPosition
		slideout_dialog.visible = true
		slideout_dialog.set_fields(
			"A match is available!",
			"Exit to Menu",
			"Ignore",
			"Don't show this again"
		)
		# Start a tween to slide it in to view by moving it left by its width.
		var tween = create_tween()
		tween.tween_property(slideout_dialog, "position", slideout_dialog.position - Vector2(slideout_dialog.size.x, 0), 0.5)
		tween.play()

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
	replay_saving_enabled = false
	player_deck = vs_info['player_deck']
	opponent_deck = vs_info['opponent_deck']
	var randomize_first_player = vs_info['randomize_first_vs_ai']
	game_wrapper.initialize_local_game(player_deck, opponent_deck, randomize_first_player, image_loader)

func begin_remote_game(game_start_message):
	starting_message = game_start_message.duplicate()
	observer_mode = 'observer_mode' in game_start_message and game_start_message['observer_mode']
	replay_mode = 'replay_mode' in game_start_message and game_start_message['replay_mode']
	replay_saving_enabled = true
	# Add a few seconds to starting timers to account for loading screen
	starting_timer = game_start_message['starting_timer'] + 4
	enforce_timer = game_start_message['enforce_timer']
	minimum_time_per_choice = game_start_message['minimum_time_per_choice']
	player_clock_remaining = starting_timer
	opponent_clock_remaining = starting_timer

	var starting_message_queue = []
	restore_fast_forward_pending = false
	restore_fast_forwarding = false
	if observer_mode:
		starting_message_queue = game_start_message['observer_log']
	elif game_start_message.has('restore_log'):
		# Resuming a dropped remote game: replay the server-provided log with
		# zero animation delay, then resume live play.
		starting_message_queue = game_start_message['restore_log']
		restore_fast_forward_pending = true

	var p1deck
	if game_start_message.get('player1_custom_deck'):
		p1deck = game_start_message['player1_custom_deck']
	else:
		p1deck = CardDataManager.get_deck_from_str_id(game_start_message['player1_deck_id'])
	var p2deck
	if game_start_message.get('player2_custom_deck'):
		p2deck = game_start_message['player2_custom_deck']
	else:
		p2deck = CardDataManager.get_deck_from_str_id(game_start_message['player2_deck_id'])

	var player1_info = {
		'name': game_start_message['player1_name'],
		'id': game_start_message['player1_id'],
		'deck_id': game_start_message['player1_deck_id'],
		'deck': p1deck,
		'player_number': 1,
		'custom_deck': game_start_message['player1_custom_deck'],
	}
	var player2_info = {
		'name': game_start_message['player2_name'],
		'id': game_start_message['player2_id'],
		'deck_id': game_start_message['player2_deck_id'],
		'deck': p2deck,
		'player_number': 2,
		'custom_deck': game_start_message['player2_custom_deck'],
	}
	var seed_value = game_start_message['seed_value']
	var starting_player = Enums.PlayerId.PlayerId_Player
	var my_player_info
	var opponent_player_info

	if str(game_start_message['your_player_id']) == str(game_start_message['player1_id']):
		my_player_info = player1_info
		player_deck = player1_info['deck']
		opponent_player_info = player2_info
		opponent_deck = player2_info['deck']
		if str(game_start_message['starting_player_id']) == str(game_start_message['player2_id']):
			starting_player = Enums.PlayerId.PlayerId_Opponent
	else:
		my_player_info = player2_info
		player_deck = player2_info['deck']
		opponent_player_info = player1_info
		opponent_deck = player1_info['deck']
		if str(game_start_message['starting_player_id']) == str(game_start_message['player1_id']):
			starting_player = Enums.PlayerId.PlayerId_Opponent

	player_deck = CardDataManager.convert_floats_to_ints(player_deck)
	opponent_deck = CardDataManager.convert_floats_to_ints(opponent_deck)

	game_wrapper.initialize_remote_game(my_player_info,
		opponent_player_info,
		starting_player,
		seed_value,
		observer_mode,
		replay_mode,
		starting_message_queue,
		image_loader)

func set_player_as_clock_user(player_id : Enums.PlayerId):
	current_clock_user = player_id
	new_clock_user_assigned = true

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
	await $PlayerCharacter.load_character(image_loader, player_deck, player_deck['id'])
	await $OpponentCharacter.load_character(image_loader, opponent_deck, opponent_deck['id'])

	if 'buddy_card' in player_deck:
		player_buddies[0].visible = false
		player_buddies[0].load_character(image_loader, player_deck, player_deck['buddy_card'])
		player_buddies[0].set_buddy_id(player_deck['buddy_card'])
	if 'buddy_card' in opponent_deck:
		opponent_buddies[0].visible = false
		opponent_buddies[0].load_character(image_loader, opponent_deck, opponent_deck['buddy_card'])
		opponent_buddies[0].set_buddy_id(opponent_deck['buddy_card'])
	if 'buddy_cards' in player_deck:
		if 'no_buddy_card_graphics' in player_deck and player_deck['no_buddy_card_graphics']:
			pass
		else:
			for i in range(0, player_deck['buddy_cards'].size()):
				player_buddies[i].visible = false
				player_buddies[i].load_character(image_loader, player_deck, player_deck['buddy_card_graphics_id'][i])
				player_buddies[i].set_buddy_id(player_deck['buddy_cards'][i])
	if 'buddy_cards' in opponent_deck:
		if 'no_buddy_card_graphics' in opponent_deck and opponent_deck['no_buddy_card_graphics']:
			pass
		else:
			for i in range(0, opponent_deck['buddy_cards'].size()):
				opponent_buddies[i].visible = false
				opponent_buddies[i].load_character(image_loader, opponent_deck, opponent_deck['buddy_card_graphics_id'][i])
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

	setup_characters_complete = true

func setup_character_card(character_card, deck, buddy_character_card):
	character_card.set_name_text(deck['display_name'])

	var loaded_character_image = await image_loader.get_card_image(
		deck['image_resources']['character_default']['url'], 0)
	var loaded_exceed_image = await image_loader.get_card_image(
		deck['image_resources']['character_exceeded']['url'], 0)
	character_card.set_image(loaded_character_image, loaded_exceed_image)

	var on_exceed_text = ""
	if 'on_exceed' in deck:
		on_exceed_text = GameStrings.get_on_exceed_text(deck['on_exceed'])
	var effect_text = on_exceed_text + GameStrings.get_effects_text(deck['ability_effects'])
	var exceed_text = GameStrings.get_effects_text(deck['exceed_ability_effects'])
	character_card.set_effect(effect_text, exceed_text)
	character_card.set_cost(deck['exceed_cost'])

	# Setup buddy if they have one.
	var created_buddy_cards = []
	if 'hide_buddy_reference' in deck and deck['hide_buddy_reference']:
		buddy_character_card.visible = false
	elif 'buddy_card' in deck:
		# buddy_exceeds only means the buddy has separate exceeded art. Some
		# buddies (Umina's Dreamlands) are a zone the player uses from turn
		# one, and this card doubles as the button that opens that zone.
		if deck.get('buddy_exceeds') and not deck.get('buddy_visible_before_exceed', false):
			buddy_character_card.visible = false
		else:
			buddy_character_card.visible = true
		buddy_character_card.hide_focus()
		var buddy_card_id = deck['buddy_card']

		var loaded_buddy_image = await image_loader.get_card_image(
			deck['image_resources'][buddy_card_id]['url'], 0)
		var loaded_buddy_exceed_image = loaded_buddy_image
		if 'buddy_exceeds' in deck and deck['buddy_exceeds']:
			loaded_buddy_exceed_image = await image_loader.get_card_image(
				deck['image_resources'][buddy_card_id + '_exceeded']['url'], 0)
		buddy_character_card.set_image(loaded_buddy_image, loaded_buddy_exceed_image)
	elif 'buddy_cards' in deck:
		buddy_character_card.visible = true
		buddy_character_card.hide_focus()
		var default_buddy = deck['buddy_cards'][0]
		if 'buddy_card_graphic_override' in deck:
			default_buddy = deck['buddy_card_graphic_override'][0]
		created_buddy_cards.append(default_buddy)

		var loaded_buddy_image = await image_loader.get_card_image(
			deck['image_resources'][default_buddy]['url'], 0)
		var loaded_buddy_exceed_image = loaded_buddy_image
		if 'buddy_exceeds' in deck and deck['buddy_exceeds']:
			loaded_buddy_exceed_image = await image_loader.get_card_image(
				deck['image_resources'][default_buddy + '_exceeded']['url'], 0)
		buddy_character_card.set_image(loaded_buddy_image, loaded_buddy_exceed_image)

		# Add remaining buddies as extras.
		for i in range(1, deck['buddy_cards'].size()):
			var buddy_id = deck['buddy_cards'][i]
			if 'buddy_card_graphic_override' in deck:
				buddy_id = deck['buddy_card_graphic_override'][i]
			if buddy_id in created_buddy_cards:
				# Skip any that share graphics.
				continue
			created_buddy_cards.append(buddy_id)

			loaded_buddy_image = await image_loader.get_card_image(
				deck['image_resources'][buddy_id]['url'], 0)
			loaded_buddy_exceed_image = loaded_buddy_image
			if 'buddy_exceeds' in deck and deck['buddy_exceeds']:
				loaded_buddy_exceed_image = await image_loader.get_card_image(
					deck['image_resources'][buddy_id + '_exceeded']['url'], 0)
			buddy_character_card.set_extra_image(i, loaded_buddy_image, loaded_buddy_exceed_image)
	else:
		buddy_character_card.visible = false

func finish_initialization():
	opponent_name_label.text = game_wrapper.get_player_name(Enums.PlayerId.PlayerId_Opponent)
	await spawn_all_cards()

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
	await _prepare_initial_arena_visuals()
	update_arena_squares()
	_update_buttons()

	await finish_initialization()
	change_ui_state(UIState.UIState_WaitForGameServer)
	first_run_done = true
	load_characters_complete.emit()

func create_character_reference_card(exceeded : bool, zone, image_resources):
	var image_url = image_resources['character_default']['url']
	if exceeded:
		image_url = image_resources['character_exceeded']['url']
	_create_reference_card(image_url, "Character Card", zone, CardBase.CharacterCardReferenceId)

func create_buddy_reference_card(buddy_id, exceeded : bool, zone, click_buddy_id, image_resources,
		card_name : String = "Extra Card"):
	var image_url = image_resources[buddy_id]['url']
	if exceeded:
		image_url = image_resources[buddy_id + '_exceeded']['url']
	_create_reference_card(image_url, card_name, zone, click_buddy_id)

# Some buddies reuse a single piece of art for their base and exceeded forms
# (Renea's Briefcase, for example). Those are distinct ids pointing at the same
# picture, so listing them by id shows the same card twice. Collapse the list
# down to one entry per distinct artwork.
func _unique_buddy_graphics(buddy_graphic_list, image_resources) -> Array:
	var unique_ids = []
	var seen_urls = []
	for buddy_id in buddy_graphic_list:
		var buddy_graphic = buddy_id
		if buddy_id in image_resources and 'url' in image_resources[buddy_id]:
			buddy_graphic = image_resources[buddy_id]['url']
		if buddy_graphic in seen_urls:
			continue
		seen_urls.append(buddy_graphic)
		unique_ids.append(buddy_id)
	return unique_ids

func _create_reference_card(image_url : String, card_name : String, zone,
		card_id : int):
	var new_card : CardBase = CardBaseScene.instantiate()
	zone.add_child(new_card)

	var url_loaded_image = await image_loader.get_card_image(image_url, 0)

	new_card.initialize_card(
		card_id,
		url_loaded_image,
		"",
		false,
		card_name,
		""
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

func spawn_deck(deck_list,
		deck_card_zone,
		copy_zone,
		buddy_graphic_list,
		buddy_copy_zone,
		allow_click_buddy,
		set_aside_zone,
		is_opponent,
		image_resources,
		buddy_reference_name : String = ""):
	var card_db = game_wrapper.get_card_database()
	var card_back_url = image_resources['cardback']['url']

	for card in deck_list:
		var logic_card : GameCard = card_db.get_card(card.id)

		if logic_card.reference_only:
			continue

		var new_card = await create_card(card.id, logic_card.definition, logic_card.get_image_url_index_data(), card_back_url,
			deck_card_zone, is_opponent, logic_card.definition['display_name'], logic_card.definition['boost']['display_name'])
		if observer_mode and not replay_mode:
			new_card.skip_flip_when_drawing = true
		if logic_card.set_aside:
			reparent_to_zone(new_card, set_aside_zone)
		new_card.set_card_and_focus(OffScreen, 0, null)

	create_character_reference_card(false, copy_zone, image_resources)
	create_character_reference_card(true, copy_zone, image_resources)

	# Characters whose extra-cards popout is redirected to another zone (Renea's
	# Briefcase, Umina's Dreamlands, Eugenia's Wonderland, Djanette's Spell
	# Circle) would otherwise never display their marker card anywhere, because
	# that popout shows the stored cards instead. Put it in the deck reference
	# alongside the character card.
	if buddy_reference_name:
		for buddy_id in _unique_buddy_graphics(buddy_graphic_list, image_resources):
			create_buddy_reference_card(buddy_id, false, copy_zone,
				CardBase.BuddyCardReferenceId, image_resources, buddy_reference_name)

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
		if previous_def_id != logic_card.definition['id'] or logic_card.reference_only:
			var copy_card = await create_card(card.id + ReferenceScreenIdRangeStart, logic_card.definition,
				logic_card.get_image_url_index_data(), card_back_url, copy_zone, is_opponent,
				logic_card.definition['display_name'], logic_card.definition['boost']['display_name'])
			if logic_card.reference_only:
				copy_card.hide_count = true
			copy_card.set_card_and_focus(OffScreen, 0, CardBase.ReferenceCardScale)
			copy_card.resting_scale = CardBase.ReferenceCardScale
			copy_card.change_state(CardBase.CardState.CardState_Offscreen)
			copy_card.flip_card_to_front(true)
			previous_def_id = card.definition['id']

	# Setup buddy if they have one.
	if buddy_graphic_list:
		for buddy_id in _unique_buddy_graphics(buddy_graphic_list, image_resources):
			var buddy_card_id = CardBase.BuddyCardReferenceId
			if allow_click_buddy and buddy_id in buddy_card_id_links:
				buddy_card_id = buddy_card_id_links[buddy_id]
			create_buddy_reference_card(buddy_id, false, buddy_copy_zone, buddy_card_id, image_resources)

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

func spawn_emote(
	player_id : Enums.PlayerId,
	is_image_emote : bool,
	emote : String
):
	if restore_fast_forwarding:
		return
	var emote_display = opponent_emote
	if player_id == Enums.PlayerId.PlayerId_Player:
		emote_display = player_emote
	var pos = get_notice_position(player_id)
	pos.y -= NoticeOffsetY
	if game_wrapper.get_player_location(player_id) > 5:
		pos.x -= 50
	var height = NoticeOffsetY
	emote_display.play_emote(is_image_emote, emote, pos, height)

func spawn_all_cards():
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

	var player_can_click_buddy = player_deck.get("link_extra_cards_to_buddies", false)
	var opponent_can_click_buddy = opponent_deck.get("link_extra_cards_to_buddies", false)

	# Only decks whose buddy popout is redirected elsewhere need their marker
	# card surfaced in the deck reference list.
	var player_buddy_reference_name = ""
	if player_deck.get("buddy_link_to_zone"):
		player_buddy_reference_name = player_deck.get("buddy_display_name", "Extra Card")
	var opponent_buddy_reference_name = ""
	if opponent_deck.get("buddy_link_to_zone"):
		opponent_buddy_reference_name = opponent_deck.get("buddy_display_name", "Extra Card")

	var player_image_resources = player_deck['image_resources']
	var opponent_image_resources = opponent_deck['image_resources']

	await spawn_deck(game_wrapper.get_player_deck_list(Enums.PlayerId.PlayerId_Player), $AllCards/PlayerDeck, $AllCards/PlayerAllCopy,
		player_buddy_graphics, $AllCards/PlayerBuddyCopy, player_can_click_buddy, $AllCards/PlayerSetAside, false, player_image_resources,
		player_buddy_reference_name)
	await spawn_deck(game_wrapper.get_player_deck_list(Enums.PlayerId.PlayerId_Opponent), $AllCards/OpponentDeck, $AllCards/OpponentAllCopy,
		opponent_buddy_graphics, $AllCards/OpponentBuddyCopy, opponent_can_click_buddy, $AllCards/OpponentSetAside, true, opponent_image_resources,
		opponent_buddy_reference_name)

func get_arena_location_button(arena_location):
	var target_square = arena_layout.get_child(arena_location - 1)
	var button = target_square.get_node("Button")
	return button

func move_character_to_arena_square(character,
		arena_location,
		immediate: bool,
		move_anim : Character.CharacterAnim,
		buddy_offset : int = 0
):
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
	_update_runtime_frame_health(delta)
	if not first_run_done:
		if not first_run_in_progress:
			if not setup_characters_complete:
				# Wait for the characters to finish loading.
				return
			first_run_in_progress = true
			await first_run()
		return
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
			var log_text = game_wrapper.get_combat_log(combat_log.get_filters(), combat_log.log_player_color, combat_log.log_opponent_color, combat_log.log_card_color)
			combat_log.set_text(log_text)
		elif ui_state == UIState.UIState_WaitingOnOpponent:
			# Advance the AI game automatically.
			_on_ai_move_button_pressed()

		if events.size() == 0 and observer_live:
			game_wrapper.observer_process_next_message_from_queue()
		elif events.size() == 0 and (restore_fast_forwarding or restore_fast_forward_pending):
			_advance_restore_fast_forward()

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
				set_player_as_clock_user(game_wrapper.get_priority_player())

	if current_clock_user != Enums.PlayerId.PlayerId_Unassigned and ui_state != UIState.UIState_GameOver:
		if events_to_process.size() > 0:
			# Don't count down the clock while there are events to process.
			player_notified_of_clock = false
			return
		elif is_mulligan_done():
			if current_clock_user == Enums.PlayerId.PlayerId_Player:
				player_clock_remaining -= delta
				if new_clock_user_assigned:
					new_clock_user_assigned = false
					if enforce_timer and player_clock_remaining < minimum_time_per_choice:
						player_clock_remaining = minimum_time_per_choice
				if not player_notified_of_clock:
					player_notified_of_clock = true
					if GlobalSettings.GameSoundsEnabled and not observer_mode:
						turnstart_audio.play()
			elif current_clock_user == Enums.PlayerId.PlayerId_Opponent:
				if new_clock_user_assigned:
					new_clock_user_assigned = false
					if enforce_timer and opponent_clock_remaining < minimum_time_per_choice:
						opponent_clock_remaining = minimum_time_per_choice
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
	$PlayerLife.set_clock(player_clock_remaining, enforce_timer and player_clock_remaining <= minimum_time_per_choice)
	$OpponentLife.set_clock(opponent_clock_remaining, enforce_timer and opponent_clock_remaining <= minimum_time_per_choice)
	if enforce_timer and player_clock_remaining <= 0:
		game_wrapper.do_clock_ran_out()

func begin_delay(delay : float, remaining_events : Array):
	if ui_state != UIState.UIState_PlayingAnimation:
		previous_ui_state = ui_state
		previous_ui_sub_state = ui_sub_state
	change_ui_state(UIState.UIState_PlayingAnimation, UISubState.UISubState_None)
	remaining_delay = get_runtime_animation_delay(delay, remaining_events.size(), _is_web_runtime())
	if restore_fast_forwarding:
		# While replaying a reconnect restore log, apply everything with no delay.
		remaining_delay = 0
	events_to_process = remaining_events

# Drains the reconnect restore log one message at a time with zero animation
# delay. Once the log is fully replayed, live play resumes normally.
func _advance_restore_fast_forward():
	if restore_fast_forward_pending:
		restore_fast_forward_pending = false
		restore_fast_forwarding = true
	var processed_something = game_wrapper.observer_process_next_message_from_queue()
	if not processed_something:
		restore_fast_forwarding = false

# --- Web-runtime detection --------------------------------------------------

func _is_web_runtime() -> bool:
	return OS.has_feature("web")

func _is_mobile_web_runtime() -> bool:
	return _is_web_runtime() and (
		OS.has_feature("mobile")
		or OS.has_feature("web_android")
		or OS.has_feature("web_ios")
	)

# --- Web-runtime health governor (pure helpers; safe to unit test) -----------

static func get_runtime_animation_delay(delay : float, pending_event_count : int, web_runtime : bool) -> float:
	if not web_runtime or pending_event_count <= WebRuntimeAnimationBacklogThreshold:
		return delay
	return maxf(WebRuntimeAnimationMinimumDelay, delay * WebRuntimeAnimationBacklogScale)

static func get_runtime_backlog_level(pending_event_count : int, web_runtime : bool) -> int:
	if not web_runtime or pending_event_count < WebRuntimeBacklogThresholdModerate:
		return RuntimeBacklogLevel.RuntimeBacklogLevel_None
	if pending_event_count >= WebRuntimeBacklogThresholdSevere:
		return RuntimeBacklogLevel.RuntimeBacklogLevel_Severe
	return RuntimeBacklogLevel.RuntimeBacklogLevel_Moderate

static func get_runtime_event_budget(pending_event_count : int, web_runtime : bool) -> int:
	match get_runtime_backlog_level(pending_event_count, web_runtime):
		RuntimeBacklogLevel.RuntimeBacklogLevel_Moderate:
			return WebRuntimeEventBudgetModerate
		RuntimeBacklogLevel.RuntimeBacklogLevel_Severe:
			return WebRuntimeEventBudgetSevere
		_:
			return WebRuntimeEventBudgetUnlimited

static func get_runtime_frame_pressure_level(slow_frame_count : int, web_runtime : bool) -> int:
	if not web_runtime:
		return RuntimeFramePressureLevel.RuntimeFramePressureLevel_None
	if slow_frame_count >= WebRuntimeSlowFrameSevereCount:
		return RuntimeFramePressureLevel.RuntimeFramePressureLevel_Severe
	if slow_frame_count >= WebRuntimeSlowFrameWarningCount:
		return RuntimeFramePressureLevel.RuntimeFramePressureLevel_Warning
	return RuntimeFramePressureLevel.RuntimeFramePressureLevel_None

static func get_runtime_backlog_level_name(level : int) -> String:
	match level:
		RuntimeBacklogLevel.RuntimeBacklogLevel_Moderate:
			return "Moderate"
		RuntimeBacklogLevel.RuntimeBacklogLevel_Severe:
			return "Severe"
		_:
			return "None"

static func get_runtime_frame_pressure_level_name(level : int) -> String:
	match level:
		RuntimeFramePressureLevel.RuntimeFramePressureLevel_Warning:
			return "Warning"
		RuntimeFramePressureLevel.RuntimeFramePressureLevel_Severe:
			return "Severe"
		_:
			return "None"

static func get_runtime_health_state_name(state : int) -> String:
	match state:
		RuntimeHealthState.RuntimeHealthState_Warning:
			return "Warning"
		RuntimeHealthState.RuntimeHealthState_Backlogged:
			return "Backlogged"
		RuntimeHealthState.RuntimeHealthState_Recovery:
			return "Recovery"
		_:
			return "Healthy"

static func get_runtime_event_budget_name(budget : int) -> String:
	if budget == WebRuntimeEventBudgetUnlimited:
		return "Unlimited"
	return str(budget)

static func get_runtime_health_debug_color(state : int) -> Color:
	match state:
		RuntimeHealthState.RuntimeHealthState_Warning:
			return Color("ffd54f")
		RuntimeHealthState.RuntimeHealthState_Backlogged:
			return Color("ff8a65")
		RuntimeHealthState.RuntimeHealthState_Recovery:
			return Color("80deea")
		_:
			return Color("c5e1a5")

static func get_runtime_health_state(current_state : int, pending_event_count : int, slow_frame_count : int, stable_frame_count : int, web_runtime : bool) -> int:
	if not web_runtime:
		return RuntimeHealthState.RuntimeHealthState_Healthy
	var backlog_level = get_runtime_backlog_level(pending_event_count, true)
	var frame_pressure_level = get_runtime_frame_pressure_level(slow_frame_count, true)
	var pressure_level = maxi(backlog_level, frame_pressure_level)
	if pressure_level >= RuntimeBacklogLevel.RuntimeBacklogLevel_Severe:
		return RuntimeHealthState.RuntimeHealthState_Backlogged
	if pressure_level >= RuntimeBacklogLevel.RuntimeBacklogLevel_Moderate:
		return RuntimeHealthState.RuntimeHealthState_Warning
	if current_state != RuntimeHealthState.RuntimeHealthState_Healthy:
		if stable_frame_count < WebRuntimeRecoveryStableFrames:
			return RuntimeHealthState.RuntimeHealthState_Recovery
	return RuntimeHealthState.RuntimeHealthState_Healthy

static func get_runtime_event_budget_for_health_state(health_state : int) -> int:
	match health_state:
		RuntimeHealthState.RuntimeHealthState_Backlogged:
			return WebRuntimeEventBudgetSevere
		RuntimeHealthState.RuntimeHealthState_Warning, RuntimeHealthState.RuntimeHealthState_Recovery:
			return WebRuntimeEventBudgetModerate
		_:
			return WebRuntimeEventBudgetUnlimited

static func should_yield_runtime_batch(processed_count : int, batch_size : int, web_runtime : bool) -> bool:
	return web_runtime and batch_size > 0 and processed_count > 0 and processed_count % batch_size == 0

func runtime_yield_for_loading_batch(processed_count : int):
	if should_yield_runtime_batch(processed_count, WebRuntimeLoadYieldBatchSize, _is_web_runtime()):
		await get_tree().process_frame

func _update_runtime_frame_health(delta : float):
	runtime_last_frame_delta = delta
	if not _is_web_runtime() or restore_fast_forwarding:
		runtime_pending_event_pressure_count = 0
		runtime_health_state = RuntimeHealthState.RuntimeHealthState_Healthy
		runtime_slow_frame_count = 0
		runtime_stable_frame_count = WebRuntimeRecoveryStableFrames
		_request_runtime_health_debug_overlay_refresh()
		return
	if delta >= WebRuntimeSlowFrameSevereDelta:
		runtime_slow_frame_count += 2
		runtime_stable_frame_count = 0
	elif delta >= WebRuntimeSlowFrameWarningDelta:
		runtime_slow_frame_count += 1
		runtime_stable_frame_count = 0
	else:
		runtime_slow_frame_count = maxi(0, runtime_slow_frame_count - 1)
		runtime_stable_frame_count += 1
	_update_runtime_health_state(events_to_process.size())

func _update_runtime_health_state(pending_event_count : int):
	runtime_pending_event_pressure_count = pending_event_count
	if restore_fast_forwarding:
		runtime_backlog_level = RuntimeBacklogLevel.RuntimeBacklogLevel_None
		runtime_health_state = RuntimeHealthState.RuntimeHealthState_Healthy
		_request_runtime_health_debug_overlay_refresh()
		return
	runtime_backlog_level = get_runtime_backlog_level(pending_event_count, _is_web_runtime())
	runtime_health_state = get_runtime_health_state(runtime_health_state, pending_event_count, runtime_slow_frame_count, runtime_stable_frame_count, _is_web_runtime())
	_request_runtime_health_debug_overlay_refresh()

func _begin_runtime_event_batch(batch_event_count : int):
	runtime_event_batch_in_progress = true
	_update_runtime_health_state(batch_event_count + events_to_process.size())

func _end_runtime_event_batch():
	_flush_deferred_ui_updates()
	runtime_event_batch_in_progress = false
	_update_runtime_health_state(events_to_process.size())

func _flush_deferred_ui_updates():
	# Placeholder for deferred hand/card-count refreshes coalesced during a backlog.
	# The batching hooks above no-op off web; wire concrete refreshes here as needed.
	deferred_player_hand_layout = false
	deferred_opponent_hand_layout = false
	deferred_card_count_refresh = false

func _should_defer_runtime_ui_refreshes() -> bool:
	return _is_web_runtime() and runtime_event_batch_in_progress and runtime_health_state != RuntimeHealthState.RuntimeHealthState_Healthy

func _should_skip_low_priority_visuals() -> bool:
	return _rotation_layout_in_progress or (_is_web_runtime() and not restore_fast_forwarding and runtime_health_state == RuntimeHealthState.RuntimeHealthState_Backlogged)

func _should_skip_bonus_label_visuals() -> bool:
	return _is_web_runtime() and not restore_fast_forwarding and runtime_health_state != RuntimeHealthState.RuntimeHealthState_Healthy

func _should_show_runtime_health_debug_overlay() -> bool:
	return ShowRuntimeHealthDebugOverlay and _is_web_runtime() and runtime_health_debug_overlay_enabled

func _update_runtime_health_debug_toggle_button():
	if runtime_health_debug_toggle_button == null:
		return
	runtime_health_debug_toggle_button.visible = ShowRuntimeHealthDebugOverlay and _is_web_runtime()
	runtime_health_debug_toggle_button.text = "Hide\nPerf" if runtime_health_debug_overlay_enabled else "Show\nPerf"

func _request_runtime_health_debug_overlay_refresh():
	if not _should_show_runtime_health_debug_overlay():
		return
	_refresh_runtime_health_debug_overlay()

func _refresh_runtime_health_debug_overlay():
	if runtime_health_debug_panel == null or runtime_health_debug_label == null:
		return
	var should_show = _should_show_runtime_health_debug_overlay()
	runtime_health_debug_panel.visible = should_show
	_update_runtime_health_debug_toggle_button()
	if not should_show:
		return
	var frame_pressure_level = get_runtime_frame_pressure_level(runtime_slow_frame_count, true)
	var event_budget = get_runtime_event_budget_for_health_state(runtime_health_state)
	runtime_health_debug_label.modulate = get_runtime_health_debug_color(runtime_health_state)
	runtime_health_debug_label.text = "Runtime Health\nState: %s\nEvent pressure: %s (%d)\nFrame pressure: %s (%.1fms)\nSlow frames: %d\nStable frames: %d/%d\nEvent budget: %s\nBatching: %s\nDeferred queue: %d\nFast-forward: %s" % [
		get_runtime_health_state_name(runtime_health_state),
		get_runtime_backlog_level_name(runtime_backlog_level),
		runtime_pending_event_pressure_count,
		get_runtime_frame_pressure_level_name(frame_pressure_level),
		runtime_last_frame_delta * 1000.0,
		runtime_slow_frame_count,
		runtime_stable_frame_count,
		WebRuntimeRecoveryStableFrames,
		get_runtime_event_budget_name(event_budget),
		"Yes" if runtime_event_batch_in_progress else "No",
		events_to_process.size(),
		"Yes" if restore_fast_forwarding else "No",
	]

func _on_runtime_health_debug_toggle_button_pressed():
	runtime_health_debug_overlay_enabled = not runtime_health_debug_overlay_enabled
	_refresh_runtime_health_debug_overlay()

# --- Responsive layout engine ------------------------------------------------

func _initialize_responsive_layout_state():
	if _responsive_position_nodes.size() > 0 or _responsive_anchor_roots.size() > 0:
		return

	var tracked_node_paths := [
		"ArenaNode", "OpponentLife", "PlayerLife", "PlayerZones", "OpponentZones",
		"PlayerBoostZone", "OpponentBoostZone", "ChoicePopoutShowButton",
		"ObserverNextButton", "ObserverPreviousButton", "ObserverPlayToLive",
		"ExitToMenu", "HugeCard", "EmoteButton",
		"AllCards/PlayerDiscardButton", "AllCards/OpponentDiscardButton",
	]
	for node_path in tracked_node_paths:
		var node = get_node_or_null(node_path)
		if node == null:
			continue
		_responsive_position_nodes.append({
			"node": node,
			"base_position": node.position,
		})

	var anchor_pairs := [
		["PlayerDeck", "PlayerDeck/DeckButton"],
		["OpponentDeck", "OpponentDeck/DeckButton"],
		["PlayerStrike", "PlayerStrike/StrikeZone"],
		["OpponentStrike", "OpponentStrike/StrikeZone"],
		["OpponentHand", "OpponentHand/HandSpawn"],
	]
	for pair in anchor_pairs:
		var root = get_node_or_null(pair[0])
		var anchor = get_node_or_null(pair[1])
		if root == null or anchor == null:
			continue
		_responsive_anchor_roots.append({
			"root": root,
			"base_anchor_position": anchor.position,
		})

func _scale_base_position(base_position : Vector2, viewport_scale : Vector2) -> Vector2:
	return Vector2(base_position.x * viewport_scale.x, base_position.y * viewport_scale.y)

static func get_rotation_safe_position(target_position : Vector2, node_size : Vector2, viewport_size : Vector2) -> Vector2:
	return Vector2(
		clampf(target_position.x, -node_size.x, viewport_size.x),
		clampf(target_position.y, -node_size.y, viewport_size.y))

func _apply_responsive_root_layout(viewport_size : Vector2):
	var viewport_scale = Vector2(
		viewport_size.x / BaseViewportSize.x,
		viewport_size.y / BaseViewportSize.y
	)

	for entry in _responsive_position_nodes:
		var node = entry["node"]
		var scaled_position := _scale_base_position(entry["base_position"], viewport_scale)
		var node_size : Vector2 = node.size if node is Control else Vector2.ZERO
		node.position = get_rotation_safe_position(scaled_position, node_size, viewport_size)

	for entry in _responsive_anchor_roots:
		var root = entry["root"]
		var base_anchor_position : Vector2 = entry["base_anchor_position"]
		var scaled_anchor_position := _scale_base_position(base_anchor_position, viewport_scale) - base_anchor_position
		var root_size : Vector2 = root.size if root is Control else Vector2.ZERO
		root.position = get_rotation_safe_position(scaled_anchor_position, root_size, viewport_size)

	var background_node = get_node_or_null("Background")
	if background_node:
		background_node.size = viewport_size
	var row_buttons = get_node_or_null("ArenaNode/RowButtons")
	if row_buttons:
		row_buttons.size.x = viewport_size.x
	var row_platforms = get_node_or_null("ArenaNode/RowPlatforms")
	if row_platforms:
		row_platforms.custom_minimum_size.x = viewport_size.x
		row_platforms.size.x = viewport_size.x
	var row_lightning = get_node_or_null("ArenaNode/RowLightningInfoButtons")
	if row_lightning:
		row_lightning.custom_minimum_size.x = viewport_size.x
		row_lightning.size.x = viewport_size.x
	var action_container = get_node_or_null("AllCards/ActionContainer")
	if action_container:
		action_container.size.x = viewport_size.x
	if rotation_layout_overlay:
		rotation_layout_overlay.size = viewport_size

func _refresh_world_positions_after_layout():
	if not first_run_done:
		return

	if cached_player_location > 0:
		move_character_to_arena_square($PlayerCharacter, cached_player_location, true, Character.CharacterAnim.CharacterAnim_None)
	if cached_opponent_location > 0:
		move_character_to_arena_square($OpponentCharacter, cached_opponent_location, true, Character.CharacterAnim.CharacterAnim_None)

	var player_logic = game_wrapper.current_game.player if game_wrapper.current_game else null
	var opponent_logic = game_wrapper.current_game.opponent if game_wrapper.current_game else null

	for buddy in player_buddies:
		if buddy.visible and player_logic:
			var buddy_location = player_logic.get_buddy_location(buddy.get_buddy_id())
			if buddy_location != -1:
				move_character_to_arena_square(buddy, buddy_location, true, Character.CharacterAnim.CharacterAnim_None, -1)

	for buddy in opponent_buddies:
		if buddy.visible and opponent_logic:
			var buddy_location = opponent_logic.get_buddy_location(buddy.get_buddy_id())
			if buddy_location != -1:
				move_character_to_arena_square(buddy, buddy_location, true, Character.CharacterAnim.CharacterAnim_None, -1)

	for location in range(1, 10):
		var player_rod = player_lightningrod_tracking.get(location, {}).get("character")
		if player_rod != null:
			move_character_to_arena_square(player_rod, location, true, Character.CharacterAnim.CharacterAnim_None, -1)
		var opponent_rod = opponent_lightningrod_tracking.get(location, {}).get("character")
		if opponent_rod != null:
			move_character_to_arena_square(opponent_rod, location, true, Character.CharacterAnim.CharacterAnim_None, -1)

	update_character_facing()
	update_arena_squares()

func _refresh_viewport_layout_metrics(relayout_hands := false):
	if not is_inside_tree() or get_viewport() == null:
		return

	var viewport_size = Vector2(get_viewport().content_scale_size)
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return

	_apply_responsive_root_layout(viewport_size)

	CenterCardOval = viewport_size * Vector2(0.5, 1.35)
	HorizontalRadius = viewport_size.x * 0.55
	VerticalRadius = viewport_size.y * 0.4

	if not relayout_hands or not _viewport_layout_ready:
		return

	layout_player_hand(true)
	layout_player_hand(false)
	_refresh_world_positions_after_layout()

# --- Rotation reflow pipeline (web only; desktop keeps canvas_items scaling) --

func _on_viewport_size_changed():
	if not _is_web_runtime():
		# Off web, canvas_items stretch already scales the whole scene; leave it be.
		return
	if not _viewport_layout_ready:
		_refresh_viewport_layout_metrics(false)
		return
	_schedule_rotation_layout_refresh()

func _schedule_rotation_layout_refresh():
	_viewport_layout_generation += 1
	var layout_generation := _viewport_layout_generation
	if not _rotation_layout_in_progress:
		_rotation_layout_in_progress = true
		if rotation_layout_overlay:
			rotation_layout_overlay.visible = true
		GlobalSettings.set_web_rotation_render_scale(_is_mobile_web_runtime())
		_begin_rotation_layout_visual_pause()
		_run_rotation_layout_refresh(layout_generation)

static func is_rotation_layout_request_current(request_generation : int, current_generation : int) -> bool:
	return request_generation == current_generation

static func is_rotation_viewport_size_valid(viewport_size : Vector2) -> bool:
	return viewport_size.x >= WebRuntimeMinimumViewportSize.x and viewport_size.y >= WebRuntimeMinimumViewportSize.y

func _begin_rotation_layout_visual_pause():
	$OpponentDeck/ThinkingIndicator.visible = false
	_finish_all_card_animations()
	_finish_all_character_animations()
	for popup in find_children("*", "DamagePopup", true, false):
		popup.pause_for_rotation_layout()
	if player_emote.has_method("pause_for_rotation_layout"):
		player_emote.pause_for_rotation_layout()
	if opponent_emote.has_method("pause_for_rotation_layout"):
		opponent_emote.pause_for_rotation_layout()

func _run_rotation_layout_refresh(layout_generation : int, invalid_viewport_retries := 0):
	for _frame in range(WebRuntimeRotationSettleFrames):
		await get_tree().process_frame
	if not is_rotation_layout_request_current(layout_generation, _viewport_layout_generation):
		_run_rotation_layout_refresh(_viewport_layout_generation)
		return

	var viewport_size := Vector2(get_viewport().content_scale_size)
	if not is_rotation_viewport_size_valid(viewport_size):
		if invalid_viewport_retries >= WebRuntimeMaximumInvalidViewportRetries:
			_apply_responsive_root_layout(_last_stable_viewport_size)
			_finish_rotation_layout_refresh()
			return
		await get_tree().process_frame
		_run_rotation_layout_refresh(_viewport_layout_generation, invalid_viewport_retries + 1)
		return
	await get_tree().process_frame
	if not is_rotation_layout_request_current(layout_generation, _viewport_layout_generation):
		_run_rotation_layout_refresh(_viewport_layout_generation)
		return
	var confirmed_viewport_size := Vector2(get_viewport().content_scale_size)
	if confirmed_viewport_size != viewport_size:
		_run_rotation_layout_refresh(_viewport_layout_generation)
		return
	if not is_rotation_viewport_size_valid(confirmed_viewport_size):
		_finish_rotation_layout_refresh()
		return
	_last_stable_viewport_size = confirmed_viewport_size

	_apply_responsive_root_layout(_last_stable_viewport_size)
	CenterCardOval = _last_stable_viewport_size * Vector2(0.5, 1.35)
	HorizontalRadius = _last_stable_viewport_size.x * 0.55
	VerticalRadius = _last_stable_viewport_size.y * 0.4
	await get_tree().process_frame
	if not is_rotation_layout_request_current(layout_generation, _viewport_layout_generation):
		_run_rotation_layout_refresh(_viewport_layout_generation)
		return

	layout_player_hand(true)
	layout_player_hand(false)
	_finish_all_card_animations()
	await get_tree().process_frame
	if not is_rotation_layout_request_current(layout_generation, _viewport_layout_generation):
		_run_rotation_layout_refresh(_viewport_layout_generation)
		return

	_refresh_world_positions_after_layout()
	_finish_all_character_animations()
	_finish_rotation_layout_refresh()

func _finish_rotation_layout_refresh():
	GlobalSettings.set_web_rotation_render_scale(false)
	if rotation_layout_overlay:
		rotation_layout_overlay.visible = false
	_rotation_layout_in_progress = false

func _finish_all_card_animations():
	for card in find_children("*", "CardBase", true, false):
		card.finish_animation_immediately()

func _finish_all_character_animations():
	$PlayerCharacter.finish_movement()
	$OpponentCharacter.finish_movement()
	for buddy in player_buddies:
		buddy.finish_movement()
	for buddy in opponent_buddies:
		buddy.finish_movement()
	for location in range(1, 10):
		var player_rod = player_lightningrod_tracking.get(location, {}).get("character")
		if player_rod != null:
			player_rod.finish_movement()
		var opponent_rod = opponent_lightningrod_tracking.get(location, {}).get("character")
		if opponent_rod != null:
			opponent_rod.finish_movement()


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

func get_stored_card_position(is_player : bool):
	var stored_zone = player_bonus_panel
	if not is_player:
		stored_zone = opponent_bonus_panel
	return stored_zone.global_position + (stored_zone.size * stored_zone.scale)/2

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

func create_card(id, card_def, image_url_index, cardback_url, parent, is_opponent : bool, card_name, boost_name) -> CardBase:
	var new_card : CardBase = CardBaseScene.instantiate()
	parent.add_child(new_card)
	var strike_cost = card_def['gauge_cost']
	if strike_cost == 0:
		strike_cost = card_def['force_cost']

	var url_loaded_image = null
	if image_url_index:
		url_loaded_image = await image_loader.get_card_image(image_url_index["url"], image_url_index["index"])
	var url_loaded_cardback = null
	if cardback_url:
		url_loaded_cardback = await image_loader.get_card_image(cardback_url, 0)

	new_card.initialize_card(
		id,
		url_loaded_image,
		url_loaded_cardback,
		is_opponent,
		card_name,
		boost_name
	)

	new_card.name = get_card_node_name(id)
	new_card.raised_card.connect(on_card_raised)
	new_card.lowered_card.connect(on_card_lowered)
	new_card.clicked_card.connect(on_card_clicked)
	return new_card

func add_card_to_hand(id : int, is_player : bool) -> CardBase:
	var card = find_card_on_board(id)
	if not is_player:
		if replay_mode and GlobalSettings.ReplayShowOpponentHand:
			pass
		else:
			card.manual_flip_needed = true
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
		if card.saved_hand_index >= parent.get_child_count():
			card.saved_hand_index = parent.get_child_count() - 1
		parent.move_child(card, card.saved_hand_index)
		card.saved_hand_index = -1

func is_card_in_player_reference(reference_cards, card_id):
	for card in reference_cards:
		if card.card_id == card_id:
			return true
	return false

func _should_open_or_refresh_popout(open_popout : bool, popout_type : CardPopoutType) -> bool:
	return open_popout or (card_popout_parent.get_child_count() > 0 and popout_type_showing == popout_type)

func _selection_contains_stored_zone_strike_card() -> bool:
	for selected in selected_cards:
		if game_wrapper.is_card_set_aside(Enums.PlayerId.PlayerId_Player, selected.card_id):
			return true
	return false

func can_select_card(card):
	if observer_mode:
		return false

	if card.card_id in [CardBase.CharacterCardReferenceId, CardBase.BuddyCardReferenceId]:
		return false

	var in_gauge = game_wrapper.is_card_in_gauge(Enums.PlayerId.PlayerId_Player, card.card_id)
	var in_opponent_gauge = game_wrapper.is_card_in_gauge(Enums.PlayerId.PlayerId_Opponent, card.card_id)
	var in_hand = game_wrapper.is_card_in_hand(Enums.PlayerId.PlayerId_Player, card.card_id)
	var in_discard = game_wrapper.is_card_in_discards(Enums.PlayerId.PlayerId_Player, card.card_id)
	var in_sealed = game_wrapper.is_card_in_sealed(Enums.PlayerId.PlayerId_Player, card.card_id)
	var in_set_aside = game_wrapper.is_card_set_aside(Enums.PlayerId.PlayerId_Player, card.card_id)
	var in_overdrive = game_wrapper.is_card_in_overdrive(Enums.PlayerId.PlayerId_Player, card.card_id)
	var in_player_boosts = game_wrapper.is_card_in_boosts(Enums.PlayerId.PlayerId_Player, card.card_id)
	var in_player_transforms = game_wrapper.is_card_in_transforms(Enums.PlayerId.PlayerId_Player, card.card_id)
	var is_sustained = game_wrapper.is_card_sustained(Enums.PlayerId.PlayerId_Player, card.card_id)
	var in_opponent_boosts = game_wrapper.is_card_in_boosts(Enums.PlayerId.PlayerId_Opponent, card.card_id)
	var in_player_reference = is_card_in_player_reference($AllCards/PlayerAllCopy.get_children(), card.card_id)
	var in_opponent_reference = is_card_in_player_reference($AllCards/OpponentAllCopy.get_children(), card.card_id)
	var in_choice_zone = is_card_in_player_reference(choice_zone_parent.get_children(), card.card_id)

	if ui_state == UIState.UIState_PickTurnAction:
		if in_player_boosts:
			var card_db = game_wrapper.get_card_database()
			var logic_card = card_db.get_card(card.card_id)
			if 'must_set_from_boost' in logic_card.definition and logic_card.definition['must_set_from_boost']:
				return true
			if 'may_set_from_boost' in logic_card.definition and logic_card.definition['may_set_from_boost']:
				return true
			return false
		elif in_set_aside:
			if game_wrapper.can_player_boost_from_extra(Enums.PlayerId.PlayerId_Player):
				# Renea: the Briefcase may only be boosted from once per turn, so
				# gray the cards out instead of offering a doomed selection.
				var renea_sa = game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
				if renea_sa.deck_flag("boost_from_stored_zone_grants_action_when_exceeded") and renea_sa.exceeded and renea_sa.renea_boost_from_briefcase_used:
					return false
				return game_wrapper.can_player_boost(Enums.PlayerId.PlayerId_Player, card.card_id, ['extra'], "", true)
			# Lets the player pick the card first and then choose Strike, the
			# same way a card in hand works.
			return game_wrapper.can_strike_with_set_aside_card(Enums.PlayerId.PlayerId_Player, card.card_id)
		return in_hand or in_gauge
	match ui_sub_state:
		UISubState.UISubState_SelectCards_DiscardCards, UISubState.UISubState_SelectCards_DiscardCardsToGauge:
			if select_card_restriction_ids and not card.card_id in select_card_restriction_ids:
				return false
			return in_hand and len(selected_cards) < select_card_require_max
		UISubState.UISubState_SelectCards_DiscardCards_Choose:
			# Tournelouse Ouroboros: only the normals the engine offered may be
			# chosen from hand, and a card already spent as payment can't be reused.
			if is_tournelouse_ouroboros_hand_choice():
				return in_hand and not is_tournelouse_ouroboros_paid_card(card.card_id) and is_tournelouse_ouroboros_legal_hand_transform(card.card_id) and len(selected_cards) < select_card_require_max
			var limitation = game_wrapper.get_decision_info().limitation
			var meets_limitation = true
			var game_card = game_wrapper.get_card_database().get_card(card.card_id)
			var card_type = game_card.definition['type']
			var card_name = game_card.definition['display_name']
			match limitation:
				"can_pay_cost":
					var card_options = game_wrapper.get_player_extra_attack_card_options(Enums.PlayerId.PlayerId_Player)
					meets_limitation = card.card_id in card_options
				"normal":
					meets_limitation = card_type == "normal"
				"ultra":
					meets_limitation = card_type == "ultra"
				"special":
					meets_limitation = card_type == "special"
				"normal/special":
					meets_limitation = card_type in ["normal", "special"]
				"special/ultra":
					meets_limitation = card_type in ["special", "ultra"]
				"from_array":
					var card_ids = game_wrapper.get_decision_info().choice
					meets_limitation = card.card_id in card_ids
				"same-named":
					meets_limitation = true
					for selected_card in selected_cards:
						var compare_card = game_wrapper.get_card_database().get_card(selected_card.card_id)
						if compare_card.definition['display_name'] != card_name:
							meets_limitation = false
							break
				"range_to_opponent":
					meets_limitation = game_wrapper.does_card_contain_range_to_opponent(Enums.PlayerId.PlayerId_Player, card.card_id)
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
			# Tournelouse's transform choices reuse this sub-state but pick from
			# the transform zone, and already-paid cards can't be picked twice.
			if is_tournelouse_transform_zone_choice():
				return in_player_transforms and not is_tournelouse_ouroboros_paid_card(card.card_id) and len(selected_cards) < select_card_require_max
			return in_player_boosts and not is_sustained and len(selected_cards) < select_card_require_max
		UISubState.UISubState_SelectCards_CharacterAction_Force:
			var new_force = game_wrapper.get_card_database().get_card_force_value(card.card_id)
			return (in_gauge or in_hand) and can_selected_cards_pay_force(select_card_require_force, new_force)
		UISubState.UISubState_SelectCards_CharacterAction_Gauge:
			return in_gauge and len(selected_cards) < select_card_require_max
		UISubState.UISubState_SelectCards_ForceForEffect:
			# Tournelouse Ouroboros: paying force from hand would leave no card to
			# transform, so block it when it is the player's last card.
			if is_tournelouse_ouroboros_force_choice() and in_hand and game_wrapper.get_player_hand_size(Enums.PlayerId.PlayerId_Player) <= 1:
				return false
			var force_selected = get_force_in_selected_cards()
			var new_force = game_wrapper.get_card_database().get_card_force_value(card.card_id)
			var total_force = force_selected + new_force
			var within_force_limit = select_card_up_to_force == -1 or total_force <= select_card_up_to_force
			return (in_gauge or in_hand) and (within_force_limit or can_selected_cards_pay_force(select_card_up_to_force, new_force))
		UISubState.UISubState_SelectCards_GaugeForEffect:
			var valid_id = true
			var valid_type = true
			var card_db = game_wrapper.get_card_database()
			var logic_card = card_db.get_card(card.card_id)
			if select_gauge_require_card_id:
				valid_id = logic_card.definition['id'] == select_gauge_require_card_id
			if select_gauge_valid_card_types:
				valid_type = logic_card.definition['type'] in select_gauge_valid_card_types
			return in_gauge and valid_id and valid_type and len(selected_cards) < select_card_require_max
		UISubState.UISubState_SelectCards_Mulligan:
			return in_hand
		UISubState.UISubState_SelectCards_StrikeCard, UISubState.UISubState_SelectCards_StrikeResponseCard, UISubState.UISubState_SelectCards_OpponentSetsFirst_StrikeCard, UISubState.UISubState_SelectCards_OpponentSetsFirst_StrikeResponseCard:
			if in_player_boosts:
				var card_db = game_wrapper.get_card_database()
				var logic_card = card_db.get_card(card.card_id)
				if 'must_set_from_boost' in logic_card.definition and logic_card.definition['must_set_from_boost']:
					return true
				if 'may_set_from_boost' in logic_card.definition and logic_card.definition['may_set_from_boost']:
					return true
				return false
			var can_strike_from_stored_zone = in_set_aside and \
				game_wrapper.can_strike_with_set_aside_card(Enums.PlayerId.PlayerId_Player, card.card_id)
			if can_strike_from_stored_zone:
				# A stored-zone card cannot be EXed, so it is only selectable
				# on its own.
				return len(selected_cards) == 0 or (len(selected_cards) == 1 and selected_cards[0].card_id == card.card_id)
			if _selection_contains_stored_zone_strike_card():
				return false
			return in_hand
		UISubState.UISubState_SelectCards_StrikeCard_FromGauge:
			return in_gauge
		UISubState.UISubState_SelectCards_StrikeCard_FromSealed:
			return in_sealed
		UISubState.UISubState_SelectCards_PlayBoost:
			var select_boost_valid_zones = select_boost_options['valid_zones']
			var select_boost_limitation = select_boost_options['limitation']
			var select_boost_ignore_costs = select_boost_options['ignore_costs']
			var select_boost_amount = select_boost_options['boost_amount']

			var valid_amount = false
			if select_boost_amount <= 1:
				valid_amount = len(selected_cards) == 0
			else:
				valid_amount = len(selected_cards) < select_boost_amount

			var card_db = game_wrapper.get_card_database()
			var logic_card = card_db.get_card(card.card_id)

			var valid_card = false
			# Checks if it's the EX transform action
			if logic_card.definition['boost']['boost_type'] == "transform" and !select_boost_limitation:
				if game_wrapper.can_do_ex_transform(Enums.PlayerId.PlayerId_Player): # checks timing
					valid_card = game_wrapper.can_player_ex_transform(Enums.PlayerId.PlayerId_Player, card.card_id)
			else:
				valid_card = game_wrapper.can_player_boost(Enums.PlayerId.PlayerId_Player, card.card_id, select_boost_valid_zones, select_boost_limitation, select_boost_ignore_costs)
			return valid_amount and valid_card
		UISubState.UISubState_SelectCards_ForceForBoost:
			return (in_gauge or in_hand) and selected_boost_to_pay_for != card.card_id
		UISubState.UISubState_SelectCards_GaugeForBoost:
			return in_gauge and selected_boost_to_pay_for != card.card_id
		UISubState.UISubState_SelectCards_DiscardContinuousBoost:
			var limitation = game_wrapper.get_decision_info().limitation
			if limitation in ["mine", "in_opponent_space"] and in_opponent_boosts:
				return false
			if not in_player_boosts and not in_opponent_boosts:
				return false
			if len(selected_cards) < select_card_require_max:
				var card_db = game_wrapper.get_card_database()
				var logic_card = card_db.get_card(card.card_id)
				if limitation == "in_opponent_space" and select_card_name_boost_restriction:
					if logic_card.definition['boost']['display_name'] != select_card_name_boost_restriction:
						return false
				if 'cannot_discard' in logic_card.definition['boost'] and logic_card.definition['boost']['cannot_discard']:
					return false
				return true
			return false
		UISubState.UISubState_SelectCards_DiscardOpponentGauge:
			var in_correct_gauge = false
			if game_wrapper.get_decision_info().extra_info:
				# discarding from own gauge
				in_correct_gauge = in_gauge
			else:
				# discarding from opponent's gauge
				in_correct_gauge = in_opponent_gauge
			return in_correct_gauge and len(selected_cards) < select_card_require_max
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
			# Umina "Terror Whispers": Shadow Chorus may not enter the Dreamlands.
			if source == "discard" and game_wrapper.get_decision_info().destination == "umina_dreamlands":
				if logic_card.definition.get("id") == "umina_shadow_chorus":
					return false
			var meets_limitation = false
			match limitation:
				"normal":
					meets_limitation = card_type == "normal"
				"special":
					meets_limitation = card_type == "special"
				"ultra":
					meets_limitation = card_type == "ultra"
				"normal/special":
					meets_limitation = card_type in ["normal", "special"]
				"special/ultra":
					meets_limitation = card_type in ["special", "ultra"]
				"continuous":
					meets_limitation = logic_card.definition['boost']['boost_type'] == "continuous"
				"transform":
					meets_limitation = logic_card.definition['boost']['boost_type'] == "transform"
				_:
					meets_limitation = true
			var in_correct_source = false
			match source:
				"discard":
					in_correct_source = in_discard
				"gauge":
					in_correct_source = in_gauge
				"sealed":
					in_correct_source = in_sealed
				"overdrive":
					in_correct_source = in_overdrive
				_:
					in_correct_source = false
			return in_correct_source and len(selected_cards) < select_card_require_max and meets_limitation
		UISubState.UISubState_SelectCards_ChooseFromTopdeck, UISubState.UISubState_SelectCards_ChooseOpponentCardToDiscard:
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

func get_selected_card_ids() -> Array:
	var selected_card_ids : Array = []
	for card in selected_cards:
		if is_instance_valid(card):
			selected_card_ids.append(card.card_id)
	return selected_card_ids

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
		_update_buttons(true)

func _on_card_popout_card_clicked(card_id : int):
	var card = find_card_on_board(card_id)
	if card:
		on_card_clicked(card)

func sort_cards(cards, mix_ultras : bool, speed_only : bool):
	cards.sort_custom(
		# For descending order use > 0
		func(a: Node, b: Node):
			assert(a is CardBase)
			assert(b is CardBase)
			var card_a = a as CardBase
			var card_b = b as CardBase
			var sort_key_a = game_wrapper.get_card_database().get_card_sort_key(card_a.card_id, mix_ultras, speed_only)
			var sort_key_b = game_wrapper.get_card_database().get_card_sort_key(card_b.card_id, mix_ultras, speed_only)
			return sort_key_a < sort_key_b
	)

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
			if replay_mode and GlobalSettings.ReplayShowOpponentHand:
				# Make sure the cards are visible.
				hand_center.y += 85
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

				# Shuffle children in hand_zone if not a replay.
				if not replay_mode:
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
			var text = ""
			if number > 0:
				text += "+"
			notice_text = "%s%s Armor" % [text, number]
		Enums.EventType.EventType_Strike_AttackDoesNotHit:
			notice_text = "Miss!"
		Enums.EventType.EventType_CharacterAction:
			notice_text = "Character Action"
		Enums.EventType.EventType_Strike_Critical:
			notice_text = "%s!" % event['reason']
		Enums.EventType.EventType_Strike_Infuse:
			notice_text = "%s!" % event['reason']
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
			if event['reason'] == "powerup_per_sealed_amount":
				notice_text  = "+1 Power per %s Sealed" % number
			else:
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
		Enums.EventType.EventType_EndOverdrive:
			notice_text = "Overdrive Ends"

	spawn_damage_popup(notice_text, player)
	return SmallNoticeDelay

func _on_say(event):
	var player = event['event_player']
	var text = event['extra_info']
	spawn_emote(player, false, text)
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
	var is_facedown = event["extra_info"]
	if not is_facedown:
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

func _on_transform_added(event):
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
	spawn_damage_popup("+ Transform", player)
	return SmallNoticeDelay

func _on_discard_continuous_boost_begin(event):
	var player = event['event_player']
	var decision_info = game_wrapper.get_decision_info()
	var limitation = decision_info.limitation
	var can_pass = decision_info.can_pass
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		# Show the boost window.
		var instruction_qualifier = "a"
		if limitation in ["mine", "in_opponent_space"] or game_wrapper.get_player_discardable_boost_count(player) == 0:
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
		enable_instructions_ui(instruction_text, true, can_pass, {})
		if limitation == "in_opponent_space":
			select_card_name_boost_restriction = event['extra_info']
			_on_player_boost_zone_clicked_zone()
		elif limitation == "mine" or game_wrapper.get_player_discardable_boost_count(Enums.PlayerId.PlayerId_Opponent) == 0:
			_on_player_boost_zone_clicked_zone()
		else:
			_on_opponent_boost_zone_clicked_zone()
		change_ui_state(UIState.UIState_SelectCards, UISubState.UISubState_SelectCards_DiscardContinuousBoost)
	else:
		ai_discard_continuous_boost(limitation, can_pass, event['extra_info'])

func _on_discard_opponent_gauge(event):
	var player = event['event_player']
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		var opponent_chooses = game_wrapper.get_decision_info().extra_info
		var popout_type = CardPopoutType.CardPopoutType_GaugeOpponent
		var instruction_text = "Discard a card from opponent's gauge."
		if opponent_chooses:
			# This is instead the opponent who must discard from their own gauge.
			# Show the gauge window.
			_on_player_gauge_gauge_clicked()
			popout_type = CardPopoutType.CardPopoutType_GaugePlayer
			instruction_text = "Discard a card from your gauge."
		else:
			# This is the player who may discard from the opponent's gauge.
			# Show the gauge window.
			_on_opponent_gauge_gauge_clicked()
			
		selected_cards = []
		select_card_require_min = 1
		select_card_require_max = 1
		var cancel_allowed = false
		popout_instruction_info = {
			"popout_type": popout_type,
			"instruction_text": instruction_text,
			"ok_text": "OK",
			"cancel_text": "",
			"ok_enabled": true,
			"cancel_visible": false,
		}
		enable_instructions_ui("Select a gauge card to discard.", true, cancel_allowed, {})

		change_ui_state(UIState.UIState_SelectCards, UISubState.UISubState_SelectCards_DiscardOpponentGauge)
	else:
		ai_discard_opponent_gauge()

func _on_name_opponent_card_begin(event):
	var player = event['event_player']
	spawn_damage_popup("Naming Card", player)
	var normal_only = event['event_type'] == Enums.EventType.EventType_ReadingNormal or event['event_type'] == Enums.EventType.EventType_Boost_Sidestep
	var can_name_fake_card = event['event_type'] == Enums.EventType.EventType_Boost_NameCardOpponentDiscards or event['event_type'] == Enums.EventType.EventType_Boost_ZeroVector
	var amount = event.get('number', 1)

	var cancel_text = "Reveal Hand"
	if event['event_type'] == Enums.EventType.EventType_Boost_ZeroVector or amount > 1:
		cancel_text = "Name Nonexistent Card"

	if game_wrapper.get_decision_info().bonus_effect:
		select_card_name_card_both_players = true
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
			"cancel_text": cancel_text,
			"ok_enabled": true,
			"cancel_visible": cancel_allowed,
			"normal_only": normal_only,
		}
		enable_instructions_ui(instruction_text, true, cancel_allowed, {})
		change_ui_state(UIState.UIState_SelectCards, UISubState.UISubState_SelectCards_DiscardFromReference)
		_on_opponent_reference_button_pressed(false, true)
	else:
		ai_name_opponent_card(normal_only, select_card_name_card_both_players)
	return SmallNoticeDelay

func _on_boost_played(event):
	var player = event['event_player']
	var card = find_card_on_board(event['number'])
	var is_transform = event['reason'] == "Transform"
	var is_facedown = event["extra_info"]
	if not is_facedown:
		make_card_revealed(card)
	var target_zone = $PlayerStrike/StrikeZone
	var is_player = player == Enums.PlayerId.PlayerId_Player
	if not is_player:
		target_zone = $OpponentStrike/StrikeZone
	_move_card_to_strike_area(card, target_zone, $AllCards/Striking, is_player, false)

	var boost_text = "Boost!"
	if is_transform:
		boost_text = "Transform!"
	spawn_damage_popup(boost_text, player)
	return BoostDelay

func _on_choose_card_hand_to_gauge(event):
	var player = event['event_player']
	var min_amount = event['number']
	var max_amount = event['extra_info']
	var restricted_to_card_ids = event['extra_info2']

	var decision_info = game_wrapper.get_decision_info()
	select_card_destination = decision_info.destination
	var show_restriction_list_ui = decision_info.effect.get("show_restriction_list_ui", false)
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		if prepared_character_action_data_available('gauge_from_hand'):
			var selected_card_ids = prepared_character_action_data['hand_to_gauge_cards']
			var success = game_wrapper.submit_relocate_card_from_hand(Enums.PlayerId.PlayerId_Player, selected_card_ids)
			if success:
				prepared_character_action_data = {}
				change_ui_state(UIState.UIState_WaitForGameServer)
		else:
			begin_discard_cards_selection(
				min_amount,
				max_amount,
				UISubState.UISubState_SelectCards_DiscardCardsToGauge,
				false,
				restricted_to_card_ids,
				show_restriction_list_ui
			)
	else:
		ai_choose_card_hand_to_gauge(min_amount, max_amount, restricted_to_card_ids)

func _on_choose_from_boosts(event):
	var player = event['event_player']
	select_card_require_min = game_wrapper.get_decision_info().amount_min
	select_card_require_max = game_wrapper.get_decision_info().amount
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		_on_player_boost_zone_clicked_zone()
		selected_cards = []
		var cancel_allowed = false
		# Tournelouse's transform bonus / Ouroboros return are always optional.
		if select_card_require_min == 0 or is_tournelouse_transform_bonus_choice() or is_tournelouse_ouroboros_transform_return_choice():
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
		elif source == "outrun_seal":
			_on_player_discard_button_pressed()
		elif source == "gauge":
			_on_player_gauge_gauge_clicked()
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
		var destination_str = destination
		if destination == "deck_noshuffle":
			destination_str = "top deck"
		var special_from_str = ""
		if source == "gauge":
			special_from_str = " from Gauge"
		var instruction = "Select %s to move to %s%s." % [card_select_count_str, destination_str, special_from_str]
		if destination == "lightningrod_any_space":
			instruction = "Select a card from your discard pile to place as a Lightning Rod."
		var popout_type = CardPopoutType.CardPopoutType_DiscardPlayer
		if source == "sealed":
			popout_type = CardPopoutType.CardPopoutType_SealedPlayer
		elif source == "overdrive":
			popout_type = CardPopoutType.CardPopoutType_OverdrivePlayer
		elif source == "gauge":
			popout_type = CardPopoutType.CardPopoutType_GaugePlayer
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
		begin_choose_from_topdeck(action_choices, look_amount, can_pass, player)
	elif game_wrapper.is_ai_game():
		ai_choose_from_topdeck(action_choices, look_amount, can_pass)

func get_string_for_action_choice(choice):
	match choice:
		"strike":
			return "Strike"
		"strike_after_current":
			return "Strike (after current Boost(s))"
		"boost":
			return "Boost"
		"boost_after_current":
			return "Boost (after current Boost(s))"
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
		"add_to_topdeck_under_2":
			return "Add to deck 3rd from top"
		"discard":
			return "Discard"
	return ""

func begin_choose_from_topdeck(action_choices, look_amount, can_pass, player = Enums.PlayerId.PlayerId_Player):
	current_topdeck_choosing_player = player
	var card_ids = game_wrapper.get_player_top_cards(player, look_amount)
	var card_db = game_wrapper.get_card_database()
	# Eugenia's Wanderlust looks at effectively the whole deck, so sort the
	# revealed cards into deck-reference order and show remaining counts.
	var is_wanderlust_choose = _is_wanderlust_choose_from_topdeck()
	if is_wanderlust_choose:
		var reference_order = _get_deck_reference_order_for_player(player)
		card_ids.sort_custom(func(a, b):
			var card_a = card_db.get_card(a)
			var card_b = card_db.get_card(b)
			var id_a = card_a.definition.get("id", "") if card_a else ""
			var id_b = card_b.definition.get("id", "") if card_b else ""
			var order_a = reference_order.get(id_a, 9999)
			var order_b = reference_order.get(id_b, 9999)
			if order_a == order_b:
				return a < b
			return order_a < order_b
		)
	for card_id in card_ids:
		var card = find_card_on_board(card_id)
		card.flip_card_to_front(true)
		reparent_to_zone(card, choice_zone_parent)
		if is_wanderlust_choose:
			var logic_card = card_db.get_card(card_id)
			if logic_card:
				var card_str_id = logic_card.definition.get("id", "")
				if card_str_id != "":
					card.set_remaining_count(game_wrapper.count_cards_in_deck_and_hand(player, card_str_id))

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
	enable_instructions_ui("Choose a card:", false, cancel_allowed, {})
	choice_popout_title = "TOP OF DECK"
	_on_choice_popout_show_button_pressed()

	change_ui_state(UIState.UIState_SelectCards, UISubState.UISubState_SelectCards_ChooseFromTopdeck)

func _on_choose_opponent_card_to_discard(event):
	var player = event['event_player']
	var decision_info = game_wrapper.get_decision_info()
	var card_ids = decision_info.choice
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		begin_choose_opponent_card_to_discard(card_ids)
	else:
		ai_choose_opponent_card_to_discard(card_ids)

func begin_choose_opponent_card_to_discard(card_ids):
	clear_choice_zone()
	var decision_info = game_wrapper.get_decision_info()
	var card_db = game_wrapper.get_card_database()
	for card_id in card_ids:
		var logic_card : GameCard = card_db.get_card(card_id)
		var copy_card = await create_card(card_id + ChoiceCopyIdRangeStart, logic_card.definition,
			logic_card.get_image_url_index_data(), "", choice_zone_parent, true,
			logic_card.definition['display_name'], logic_card.definition['boost']['display_name'])
		copy_card.set_card_and_focus(OffScreen, 0, CardBase.ReferenceCardScale)
		copy_card.resting_scale = CardBase.ReferenceCardScale
		copy_card.change_state(CardBase.CardState.CardState_Offscreen)
		copy_card.flip_card_to_front(true)

	var confirm_text = "Discard"
	if decision_info.destination == 'gauge':
		confirm_text = "Add to their Gauge"

	selected_cards = []
	select_card_require_min = 1
	select_card_require_max = 1
	popout_instruction_info = {
		"popout_type": CardPopoutType.CardPopoutType_ChoiceZone,
		"instruction_text": "Choose a card:",
		"ok_text": confirm_text,
		"ok2_text": "",
		"cancel_text": "",
		"ok_enabled": true,
		"cancel_visible": false
	}
	enable_instructions_ui("Choose a card:", false, false, {})
	choice_popout_title = "OPPONENT'S CARDS"
	_on_choice_popout_show_button_pressed()

	change_ui_state(UIState.UIState_SelectCards, UISubState.UISubState_SelectCards_ChooseOpponentCardToDiscard)

func _is_wanderlust_choose_from_topdeck() -> bool:
	if game_wrapper == null:
		return false
	var decision_info = game_wrapper.get_decision_info()
	if decision_info == null or decision_info.type != Enums.DecisionType.DecisionType_ChooseFromTopDeck:
		return false
	if decision_info.choice_card_id < 0:
		return false
	var source_card = game_wrapper.get_card_database().get_card(decision_info.choice_card_id)
	if source_card == null:
		return false
	return source_card.definition.get("id", "") == "eugenia_queen_of_hearts"

func _get_deck_reference_order_for_player(player : Enums.PlayerId) -> Dictionary:
	var order_map = {}
	var deck_list = game_wrapper.get_player_deck_list(player)
	var card_db = game_wrapper.get_card_database()
	var order_index = 0
	for card in deck_list:
		var logic_card = card_db.get_card(card.id)
		if logic_card == null:
			continue
		var card_str_id = logic_card.definition.get("id", "")
		if card_str_id != "" and not order_map.has(card_str_id):
			order_map[card_str_id] = order_index
			order_index += 1
	return order_map

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

func _on_add_to_stored(event):
	var player = event['event_player']
	var card = find_card_on_board(event['number'])
	var facedown = event['extra_info']
	# Umina's "The Sleeper Wakes" flips the Dreamlands face-down dynamically, so
	# fall back to the player's current stored-zone config when the event is silent.
	if facedown == null:
		facedown = game_wrapper._get_player(player).is_stored_zone_facedown()
	if not facedown:
		make_card_revealed(card)

	var is_player = player == Enums.PlayerId.PlayerId_Player
	var stored_pos = get_stored_card_position(is_player)
	card.discard_to(stored_pos, CardBase.CardState.CardState_InDeck)
	reparent_to_zone(card, get_set_aside_zone(is_player))
	layout_player_hand(is_player)

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
			$PlayerCharacter.set_exceed(true, image_loader, player_deck, player_deck['exceed_animation'])
			move_character_to_arena_square($PlayerCharacter, game_wrapper.get_player_location(Enums.PlayerId.PlayerId_Player), true, Character.CharacterAnim.CharacterAnim_None)
		else:
			$PlayerCharacter.set_exceed(true)
		player_character_card.exceed(true)
		player_buddy_character_card.exceed(true)
		if player_deck.get('buddy_exceeds'):
			player_buddy_character_card.visible = true
		player_bonus_panel.visible = false

	else:
		if 'exceed_animation' in opponent_deck:
			$OpponentCharacter.set_exceed(true, image_loader, opponent_deck, opponent_deck['exceed_animation'])
			move_character_to_arena_square($OpponentCharacter, game_wrapper.get_player_location(Enums.PlayerId.PlayerId_Opponent), true, Character.CharacterAnim.CharacterAnim_None)
		else:
			$OpponentCharacter.set_exceed(true)
		opponent_character_card.exceed(true)
		opponent_buddy_character_card.exceed(true)
		if opponent_deck.get('buddy_exceeds'):
			opponent_buddy_character_card.visible = true
		opponent_bonus_panel.visible = false

	spawn_damage_popup("Exceed!", player)
	return SmallNoticeDelay

func _on_exceed_revert_event(event):
	var player = event['event_player']
	if player == Enums.PlayerId.PlayerId_Player:
		if 'exceed_animation' in player_deck:
			$PlayerCharacter.set_exceed(true, image_loader, player_deck, player_deck['id'])
			move_character_to_arena_square($PlayerCharacter, game_wrapper.get_player_location(Enums.PlayerId.PlayerId_Player), true, Character.CharacterAnim.CharacterAnim_None)
		else:
			$PlayerCharacter.set_exceed(false)
		player_character_card.exceed(false)
		player_buddy_character_card.exceed(false)
		if player_deck.get('buddy_exceeds') and not player_deck.get('buddy_visible_before_exceed', false):
			player_buddy_character_card.visible = false

	else:
		if 'exceed_animation' in opponent_deck:
			$OpponentCharacter.set_exceed(true, image_loader, opponent_deck, opponent_deck['id'])
			move_character_to_arena_square($OpponentCharacter, game_wrapper.get_player_location(Enums.PlayerId.PlayerId_Opponent), true, Character.CharacterAnim.CharacterAnim_None)
		else:
			$OpponentCharacter.set_exceed(false)
		opponent_character_card.exceed(false)
		opponent_buddy_character_card.exceed(false)
		if opponent_deck.get('buddy_exceeds') and not opponent_deck.get('buddy_visible_before_exceed', false):
			opponent_buddy_character_card.visible = false

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
		character_object.load_character(image_loader, deck_def, deck_def['wide_animation'])

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

	var boost_amount = 1
	if event['number'] > 1:
		boost_amount = event['number']

	spawn_damage_popup("Boost!", player)
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		if prepared_character_action_data_available('boost_from_gauge'):
			var boost_card = prepared_character_action_data['boost_card']
			var boost_force = prepared_character_action_data['boost_force']
			var success = game_wrapper.submit_boost(Enums.PlayerId.PlayerId_Player, boost_card, boost_force, use_free_force, get_spent_life_for_force())
			if success:
				prepared_character_action_data = {}
				change_ui_state(UIState.UIState_WaitForGameServer)
		else:
			begin_boost_choosing(false, valid_zones, limitation, ignore_costs, boost_amount)
	else:
		ai_do_boost(valid_zones, limitation, ignore_costs, boost_amount)
	return SmallNoticeDelay

func _on_force_start_strike(event):
	var player = event['event_player']
	var disable_wild_swing = false
	var disable_ex = false
	var require_ex = false
	if event['extra_info']: #not null
		disable_wild_swing = event['extra_info']
	if event['extra_info2']:
		disable_ex = event['extra_info2']
	var decision_info = game_wrapper.get_decision_info()
	if decision_info.limitation == "EX":
		require_ex = true
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
			begin_strike_choosing(false, false, false, disable_wild_swing, disable_ex, require_ex)
	else:
		ai_forced_strike(disable_wild_swing, disable_ex, require_ex)
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
	if not observer_mode and not replay_mode:
		# Let NetworkManager know the match ended normally so a post-game
		# opponent disconnect does not trigger the reconnect-waiting overlay.
		NetworkManager.set_active_remote_match_finished(true)
	game_over_stuff.visible = true
	save_replay_button.visible = replay_saving_enabled
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
	var allow_fewer = false or event['extra_info']
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
				elif allow_fewer:
					min_amount = 0
				begin_discard_cards_selection(min_amount, max_amount, UISubState.UISubState_SelectCards_DiscardCards_Choose, can_pass)
		else:
			# AI or other player wait
			ai_choose_to_discard(amount, limitation, can_pass, allow_fewer)
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
		set_player_as_clock_user(Enums.PlayerId.PlayerId_Player)

func set_instructions(text):
	current_instruction_text = text

func update_discard_selection_message_choose():
	if is_tournelouse_ouroboros_hand_choice():
		set_instructions("Select a card from your hand to transform.")
		return

	var decision_info = game_wrapper.get_decision_info()
	var destination = decision_info.destination
	if preparing_character_action:
		destination = prepared_character_action_data['destination']
	var num_remaining = select_card_require_min - len(selected_cards)
	if select_card_require_min == 0:
		num_remaining = select_card_require_max - len(selected_cards)
	var bonus = ""
	if decision_info.bonus_effect and not preparing_character_action:
		var effect_text = GameStrings.get_effect_text(decision_info.bonus_effect, false, false, false, "")
		bonus = "\nfor %s" % effect_text
		if 'per_discard' in decision_info.bonus_effect and decision_info.bonus_effect['per_discard']:
			bonus += " for each"
	if destination == "play_attack":
		set_instructions("Select a card from your hand to move to play as an extra attack.")
	else:
		var destination_str = destination
		if destination == "replacement_boost":
			destination_str = game_wrapper.get_replacement_boost_description(Enums.PlayerId.PlayerId_Player)
		var optional_string = ""
		if select_card_require_min == 0:
			optional_string = "up to "
		if decision_info.limitation and not preparing_character_action:
			if decision_info.limitation == "from_array":
				if decision_info.extra_info == "card_names":
					var card_names = []
					for card_id in decision_info.choice:
						card_names.append(game_wrapper.get_card_database().get_card_name(card_id))
					var card_names_str = '/'.join(card_names)
					if card_names.size() > 2:
						card_names_str = ""
						for i in range(card_names.size()):
							card_names_str += card_names[i]
							if i == card_names.size() - 1:
								break
							if i % 2 == 0:
								card_names_str += "/"
							else:
								card_names_str += "\n"
					set_instructions("Select %s%s more card(s) from your hand to move to %s.\nOptions: %s" % [optional_string, num_remaining, destination_str, card_names_str])
				else:
					set_instructions("Select %s%s more card(s) that %s from your hand to move to %s." % [optional_string, num_remaining, decision_info.extra_info, destination_str])
			else:
				var limitation_str = decision_info.limitation
				if decision_info.limitation == "range_to_opponent":
					limitation_str = "matching opponent range"
				set_instructions("Select %s%s more %s card(s) from your hand to move to %s%s." % [optional_string, num_remaining, limitation_str, destination_str, bonus])
		else:
			set_instructions("Select %s%s more card(s) from your hand to move to %s%s." % [optional_string, num_remaining, destination_str, bonus])

func update_discard_selection_message():
	var num_remaining = select_card_require_min - len(selected_cards)
	set_instructions("Select %s more card(s) from your hand to discard." % num_remaining)

func update_sustain_selection_message():
	if select_card_require_min == select_card_require_max:
		var num_remaining = select_card_require_min - len(selected_cards)
		if is_tournelouse_transform_bonus_choice():
			set_instructions("Select %s more card(s) from your transforms to seal." % num_remaining)
		elif is_tournelouse_ouroboros_transform_return_choice():
			set_instructions("Select a transform card to return to your hand.")
		else:
			set_instructions("Select %s more card(s) from your boosts to sustain." % num_remaining)
	else:
		var num_remaining = select_card_require_max - len(selected_cards)
		set_instructions("Select up to %s more card(s) from your boosts to sustain." % [num_remaining])

func update_discard_to_gauge_selection_message():
	var phrase = "put in your gauge"
	match select_card_destination:
		"topdeck":
			phrase = "put on top of your deck"
		"bottomdeck":
			phrase = "put on the bottom of your deck (in selected order)"
		"deck":
			phrase = "put into your deck"
		"stored_cards":
			phrase = "place"
	if preparing_character_action:
		phrase += " for %s" % prepared_character_action_data['action_name']
	if select_card_restriction_ids and select_card_show_restriction_list_ui:
		var cardnames = []
		for card_id in select_card_restriction_ids:
			cardnames.append(game_wrapper.get_card_database().get_card_name(card_id))
		phrase += ".\nOptions: %s" % '/'.join(cardnames)
	if select_card_require_min == select_card_require_max:
		var num_remaining = select_card_require_min - len(selected_cards)
		set_instructions("Select %s more card(s) from your hand to %s." % [num_remaining, phrase])
	else:
		var num_remaining = select_card_require_max - len(selected_cards)
		set_instructions("Select up to %s more card(s) from your hand to %s." % [num_remaining, phrase])

func get_gauge_generated():
	var gauge_from_free_bonus = game_wrapper.get_player_free_gauge(Enums.PlayerId.PlayerId_Player)
	var gauge_generated = min(gauge_from_free_bonus, select_card_require_max)
	gauge_generated += len(selected_cards)
	gauge_generated += get_gauge_from_spent_life()
	if can_seal_for_gauge:
		gauge_generated += int(action_menu.number_panel_current_number / 3.0)
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
		set_instructions("Spend Gauge for +%s Armor each.\n%s\n%sYou will take %s damage." % [force_for_armor_amount, force_generated_str, ignore_armor_str, damage_after_armor])
	else:
		var gauge_from_life = get_gauge_from_spent_life()
		var num_remaining = select_card_require_min - get_gauge_generated()
		var discard_reminder = ""
		if enabled_reminder_text:
			discard_reminder = "\nThe last card selected will be on top of the discard pile."
		var life_info = ""
		if can_spend_life_for_gauge and gauge_from_life > 0:
			life_info = " (%s from spent life)" % gauge_from_life
		set_instructions("Select %s more gauge card(s).%s%s" % [max(0, num_remaining), life_info, discard_reminder])

func update_gauge_for_effect_message():
	var effect_str = ""
	var decision_effect = game_wrapper.get_decision_info().effect
	if preparing_character_action:
		decision_effect = prepared_character_action_data['effect']
	var to_hand = 'spent_cards_to_hand' in decision_effect and decision_effect['spent_cards_to_hand']
	var source_card_name = game_wrapper.get_card_database().get_card_name(game_wrapper.get_decision_info().choice_card_id)
	var gauge_name_str = "gauge"
	if select_gauge_require_card_name:
		gauge_name_str = "copies of %s from gauge" % select_gauge_require_card_name
	elif select_gauge_valid_card_types:
		gauge_name_str = "%s(s) from gauge" % '/'.join(select_gauge_valid_card_types)

	if decision_effect.get('per_gauge_effect'):
		var effect = decision_effect['per_gauge_effect']
		var effect_text = GameStrings.get_effect_text(effect, false, false, false, source_card_name)
		if to_hand:
			effect_str = "Return up to %s %s to your hand for %s per card." % [decision_effect['gauge_max'], gauge_name_str, effect_text]
		else:
			effect_str = "Spend up to %s %s for %s per card." % [decision_effect['gauge_max'], gauge_name_str, effect_text]
	elif decision_effect.get('overall_effect'):
		var effect = decision_effect['overall_effect']
		var effect_text = GameStrings.get_effect_text(effect, false, false, false, source_card_name)
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

	var total_force = game_wrapper.get_player_force_for_cards(Enums.PlayerId.PlayerId_Player, card_ids, reason, treat_ultras_as_single_force, use_free_force)
	total_force += get_force_from_spent_life()
	total_force += get_force_from_sealed()
	return total_force

func get_force_from_sealed() -> int:
	if can_seal_for_force:
		return action_menu.number_panel_current_number
	return 0

func get_force_from_spent_life():
	if can_spend_life_for_force:
		var life_per_force = game_wrapper.get_life_for_force_amount(Enums.PlayerId.PlayerId_Player)
		if life_per_force > 0:
			return action_menu.get_current_number_picker_value() / life_per_force
	return 0

func can_selected_cards_pay_force(force_cost : int, bonus_card_force_value : int = 0):
	# Calculate how much force we actually need from the cards themselves
	var force_needed_from_cards = force_cost
	force_needed_from_cards -= game_wrapper.get_player_force_cost_reduction(Enums.PlayerId.PlayerId_Player)
	if use_free_force:
		force_needed_from_cards -= game_wrapper.get_player_free_force(Enums.PlayerId.PlayerId_Player)
	force_needed_from_cards -= get_spent_life_for_force()
	force_needed_from_cards -= get_force_from_sealed()
	force_needed_from_cards = max(0, force_needed_from_cards)

	# Sum up force from selected cards
	var card_force = 0
	var ultras = 0
	var card_db = game_wrapper.get_card_database()
	for card in selected_cards:
		var value_of_card = card_db.get_card_force_value(card.card_id)
		card_force += value_of_card
		if value_of_card == 2:
			ultras += 1
	if bonus_card_force_value == 2:
		ultras += 1
	card_force += bonus_card_force_value

	# Ultras can count as 1 or 2, so the exact force is in [card_force - ultras, card_force]
	var min_force = card_force - ultras
	for i in range(min_force, card_force + 1):
		if i == force_needed_from_cards:
			return true
	return false


func update_force_generation_message():
	var force_selected = get_force_in_selected_cards()
	var force_from_free_bonus = game_wrapper.get_player_force_cost_reduction(Enums.PlayerId.PlayerId_Player)
	if use_free_force:
		var reason = ""
		if ui_sub_state == UISubState.UISubState_SelectCards_ForceForChange:
			reason = "CHANGE_CARDS"
		force_from_free_bonus += game_wrapper.get_player_free_force(Enums.PlayerId.PlayerId_Player, reason)

	var extra_force_source_strings = []
	if force_from_free_bonus > 0:
		extra_force_source_strings.append("%s from passive bonus" % force_from_free_bonus)
	if can_spend_life_for_force:
		extra_force_source_strings.append("%s from spent life" % get_force_from_spent_life())
	var force_from_free_string = ""
	if len(extra_force_source_strings) > 0:
		force_from_free_string = " (%s)" % ", ".join(extra_force_source_strings)

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
			if preparing_character_action:
				decision_effect = prepared_character_action_data['effect']
			var source_card_name = game_wrapper.get_card_database().get_card_name(game_wrapper.get_decision_info().choice_card_id)
			if decision_effect.get('per_force_effect'):
				var effect = decision_effect['per_force_effect']
				var effect_text = GameStrings.get_effect_text(effect, false, false, false, source_card_name)
				var force_str = "up to %s" % decision_effect['force_max']
				if decision_effect['force_max'] == -1:
					force_str = "any amount of"
				var per_force_str = "force"
				if 'force_effect_interval' in decision_effect:
					per_force_str = "%s force" % decision_effect['force_effect_interval']
				effect_str = "Generate %s force for %s per %s." % [force_str, effect_text, per_force_str]
			elif decision_effect.get('overall_effect'):
				var effect = decision_effect['overall_effect']
				var effect_text = GameStrings.get_effect_text(effect, false, false, false, source_card_name)
				effect_str = "Generate %s force for %s." % [decision_effect['force_max'], effect_text]
			if 'force_discard_reminder' in decision_effect and decision_effect['force_discard_reminder']:
				effect_str += "\nThe last card(s) selected will be on top of the discard pile."
			effect_str += "\n%s" % [force_generated_str]
			set_instructions(effect_str)

func enable_instructions_ui(
	message,
	can_ok,
	can_cancel,
	strike_options = {},
	can_ex : bool = true,
	choices = [],
	show_number_picker : bool = false,
	extra_choice_text = [],
	require_ex = false,
	face_attack_card = null,
	alternative_life_cost : int = 0
	):
	set_instructions(message)
	instructions_ok_allowed = can_ok
	instructions_cancel_allowed = can_cancel
	instructions_strike_options = strike_options
	instructions_pay_alternative_life_cost = alternative_life_cost
	instructions_ex_allowed = can_ex
	instructions_ex_required = require_ex
	current_effect_choices = choices
	current_effect_extra_choice_text = extra_choice_text
	instructions_number_picker_min = -1
	instructions_number_picker_max = -1
	instructions_face_attack_card = face_attack_card
	if show_number_picker:
		instructions_number_picker_min = game_wrapper.get_decision_info().amount_min
		instructions_number_picker_max = game_wrapper.get_decision_info().amount

func begin_discard_cards_selection(
	number_to_discard_min,
	number_to_discard_max,
	next_sub_state,
	can_cancel_always : bool = false,
	restricted_to_card_ids = [],
	show_restriction_list_ui = false
):
	selected_cards = []
	select_card_require_min = number_to_discard_min
	select_card_require_max = number_to_discard_max
	select_card_restriction_ids = restricted_to_card_ids
	select_card_show_restriction_list_ui = show_restriction_list_ui
	var cancel_allowed = number_to_discard_min == 0 or can_cancel_always
	enable_instructions_ui("", true, cancel_allowed)
	change_ui_state(UIState.UIState_SelectCards, next_sub_state)

func begin_generate_force_selection(amount, can_cancel : bool = true, wild_swing_allowed : bool = false, ex_discard_order_checkbox : bool = false, skip_zsolt_popup : bool = false):
	# Show the gauge window.
	_on_player_gauge_gauge_clicked()
	treat_ultras_as_single_force = false
	discard_ex_first_for_strike = true
	var reason = ""
	if ui_sub_state == UISubState.UISubState_SelectCards_ForceForChange:
		reason = "CHANGE_CARDS"
	# Zsolt Battle Instinct: let player choose how much free force to use
	var p = game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
	# During strike resolution, auto-use the pool to avoid await freeze
	# But skip if caller already set free_force (skip_zsolt_popup = true)
	var in_strike = game_wrapper.has_active_strike()
	if p.zsolt_force_pool > 0 and in_strike and not skip_zsolt_popup:
		p.free_force = p.zsolt_force_pool if amount <= 0 else min(p.zsolt_force_pool, amount)
	if p.zsolt_force_pool > 0 and not skip_zsolt_popup and not in_strike:
		p.free_force = 0
		var pool_amount = p.zsolt_force_pool
		current_action_menu_choices = []
		for i in range(pool_amount + 1):
			current_action_menu_choices.append({"action": func(): pass})
		_on_player_gauge_gauge_clicked()
		var options = []
		for i in range(pool_amount + 1):
			options.append({"text": str(i)})
		action_menu.set_choices("Use how much free force?", options, false, -1, -1, false, false, false)
		action_menu.visible = true
		var idx = await action_menu.choice_selected
		close_popout()
		p.free_force = idx
		# Re-clear button choices: callers may have run _update_buttons()
		# while we were awaiting, overwriting our dummy entries.
		current_action_menu_choices = []
		for j in range(pool_amount + 1):
			current_action_menu_choices.append({"action": func(): pass})
	use_free_force = game_wrapper.get_player_free_force(Enums.PlayerId.PlayerId_Player, reason) > 0
	can_spend_life_for_force = game_wrapper.get_life_for_force_amount(Enums.PlayerId.PlayerId_Player) > 0
	can_seal_for_gauge = false
	can_seal_for_force = p.deck_flag("can_seal_discards_for_resources") and not p.exceeded and p.discards.size() > 0
	current_pay_costs_is_ex = ex_discard_order_checkbox
	action_menu.set_force_ultra_toggle(false)
	action_menu.set_discard_ex_first_toggle(true)
	action_menu.set_free_force_toggle(use_free_force)
	selected_cards = []
	select_card_require_force = amount
	var strike_options = {
		"wild_swing_allowed": wild_swing_allowed,
	}
	enable_instructions_ui("", true, can_cancel, strike_options)

	change_ui_state(UIState.UIState_SelectCards)
	update_force_generation_message()

func begin_gauge_selection(
	amount : int,
	wild_swing_allowed : bool,
	sub_state : UISubState,
	enable_reminder : bool = false,
	ex_discard_order_checkbox : bool = false,
	alternative_life_cost : int = 0
	):
	# Show the gauge window.
	_on_player_gauge_gauge_clicked()
	selected_cards = []
	var seal_gauge_p = game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
	can_seal_for_force = false
	var seal_gauge_per = seal_gauge_p.deck_flag("discards_per_gauge_until_exceed", 0)
	can_seal_for_gauge = seal_gauge_p.deck_flag("can_seal_discards_for_resources") and not seal_gauge_p.exceeded \
		and seal_gauge_per > 0 and seal_gauge_p.discards.size() >= seal_gauge_per
	current_pay_costs_is_ex = ex_discard_order_checkbox
	discard_ex_first_for_strike = true
	action_menu.set_discard_ex_first_toggle(true)
	enabled_reminder_text = true if enable_reminder else false
	if amount != -1:
		select_card_require_min = amount
		select_card_require_max = amount
	var cancel_allowed = false
	match sub_state:
		UISubState.UISubState_SelectCards_Exceed, UISubState.UISubState_SelectCards_BoostCancel, UISubState.UISubState_SelectCards_CharacterAction_Gauge, UISubState.UISubState_SelectCards_GaugeForBoost:
			cancel_allowed = true
		UISubState.UISubState_SelectCards_GaugeForEffect:
			cancel_allowed = select_card_require_min == 0 or preparing_character_action
	var strike_options = {
		"wild_swing_allowed": wild_swing_allowed,
	}
	enable_instructions_ui(
		"",
		true,
		cancel_allowed,
		strike_options,
		true,
		[],
		false,
		[],
		false,
		null,
		alternative_life_cost
	)

	change_ui_state(UIState.UIState_SelectCards, sub_state)

func begin_effect_choice(choices, instruction_text : String, extra_choice_text, can_cancel = false):
	enable_instructions_ui(instruction_text, false, can_cancel, {}, false, choices, false, extra_choice_text)
	change_ui_state(UIState.UIState_MakeChoice, UISubState.UISubState_None)

func begin_strike_choosing(
	strike_response : bool,
	cancel_allowed : bool,
	opponent_sets_first : bool = false,
	disable_wild_swing : bool = false,
	disable_ex : bool = false,
	require_ex = false
):
	selected_cards = []
	select_card_require_min = 1
	select_card_require_max = 1
	var can_cancel = cancel_allowed and not strike_response
	var character_action_str = ""
	if preparing_character_action:
		character_action_str = " using %s" % prepared_character_action_data['action_name']
	var attack_string = "a card"
	if require_ex:
		attack_string = "an EX attack"
	var dialogue = "Select %s to strike with%s." % [attack_string, character_action_str]
	var cards_that_will_not_hit = game_wrapper.get_will_not_hit_card_names(Enums.PlayerId.PlayerId_Player)
	if cards_that_will_not_hit.size() > 0:
		for card in cards_that_will_not_hit:
			dialogue += "\n" + card + " will not hit."
	var cards_invalid_during_strike = game_wrapper.get_invalid_card_names(Enums.PlayerId.PlayerId_Player)
	if cards_invalid_during_strike.size() > 0:
		for card in cards_invalid_during_strike:
			dialogue += "\n" + card + " is invalid."
	var plague_knight_discard_names = game_wrapper.get_plague_knight_discard_names(Enums.PlayerId.PlayerId_Opponent)
	if plague_knight_discard_names.size() > 0:
		for card in plague_knight_discard_names:
			dialogue += "\nPlague Knight discarded " + card +"."
	var face_attack_card = game_wrapper.get_face_attack_card(Enums.PlayerId.PlayerId_Player)
	var extra_strike_options_count = game_wrapper.get_player_extra_strike_options_count(Enums.PlayerId.PlayerId_Player)
	var strike_options = {
		"wild_swing_allowed": not disable_wild_swing,
		"extra_strike_options_count": extra_strike_options_count
	}
	enable_instructions_ui(dialogue, true, can_cancel, strike_options, not disable_ex,
		[], false, [], require_ex, face_attack_card)
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

func begin_boost_choosing(can_cancel : bool, valid_zones : Array, limitation : String, ignore_costs : bool, boost_amount : int):
	selected_cards = []
	selected_boost_facedown_override = null
	var count_str = "a"
	var plural = ""
	select_card_require_min = 1
	if boost_amount <= 1:
		select_card_require_max = 1
	else:
		select_card_require_max = boost_amount
		count_str = "up to %s" % boost_amount
		plural = "(s)"
	select_boost_options = {
		"can_cancel": can_cancel,
		"valid_zones": valid_zones,
		"limitation": limitation,
		"ignore_costs": ignore_costs,
		"boost_amount": boost_amount
	}
	var limitation_str = "card%s" % plural
	if limitation and limitation != "transform":
		limitation_str = limitation + " boost%s" % plural
	var character_action_str = ""
	if preparing_character_action:
		character_action_str = " for %s" % prepared_character_action_data['action_name']
	var zone_str = '/'.join(valid_zones)

	var available_boost_actions = []
	if game_wrapper.can_do_boost(Enums.PlayerId.PlayerId_Player):
		available_boost_actions.append("boost")
	if game_wrapper.can_do_ex_transform(Enums.PlayerId.PlayerId_Player):
		available_boost_actions.append("transform")
	var available_boost_action_str = '/'.join(available_boost_actions)
	if limitation == "transform":
		available_boost_action_str = "transform"

	var instructions = "Select %s %s to %s from %s%s." % [count_str, limitation_str, available_boost_action_str, zone_str, character_action_str]
	if 'gauge' in valid_zones:
		_on_player_gauge_gauge_clicked()
	elif 'discard' in valid_zones: # can't open two zones at once
		_on_player_discard_button_pressed()
	elif 'extra' in valid_zones:
		_on_player_buddy_button_pressed(true)
	elif 'deck' in valid_zones:
		var deck_card_ids = game_wrapper.get_player_deck_card_ids_for_boost(Enums.PlayerId.PlayerId_Player, limitation)
		for card_id in deck_card_ids:
			var card = find_card_on_board(card_id)
			if card:
				card.flip_card_to_front(true)
				reparent_to_zone(card, choice_zone_parent)
		choice_popout_title = "DECK"
		_on_choice_popout_show_button_pressed()

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

	# Cache the destination this event animates to, not the player's current
	# logical location: while events are queued the game state has often already
	# moved on, and the cached value is what re-snaps the character after a
	# layout change and what highlights the occupied arena squares.
	if player == Enums.PlayerId.PlayerId_Player:
		move_character_to_arena_square($PlayerCharacter, destination, false,  move_anim)
		cached_player_location = destination
	else:
		move_character_to_arena_square($OpponentCharacter, destination, false, move_anim)
		cached_opponent_location = destination

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
	var copy_card = await create_card(card_id + RevealCopyIdRangestart, logic_card.definition, logic_card.get_image_url_index_data(),
		"", $AllCards/OpponentRevealed, true, logic_card.definition['display_name'], logic_card.definition['boost']['display_name'])
	copy_card.set_card_and_focus(OffScreen, 0, CardBase.ReferenceCardScale)
	copy_card.resting_scale = CardBase.ReferenceCardScale
	copy_card.change_state(CardBase.CardState.CardState_Offscreen)
	copy_card.flip_card_to_front(true)

func _on_reveal_card_from_hand(event):
	var player = event['event_player']
	# Renea: when a face-down boost is revealed, flip its visual face-up. Hand
	# reveals stay hidden in the hand zone because the engine already tracks them
	# as known cards for the public hand display.
	var reveal_card = find_card_on_board(event['number'])
	if reveal_card:
		var parent_zone = reveal_card.get_parent()
		var in_hand_zone = parent_zone == $AllCards/PlayerHand or parent_zone == $AllCards/OpponentHand
		if not in_hand_zone:
			make_card_revealed(reveal_card)
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
		# Pass flag to indicate this is the initiator setting after opponent.
		ai_strike_response(true)

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
	label_text += GameStrings.get_effect_text(effect, false, true, true, "", true)
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

func _on_effect_do_boost(event):
	var player = event['event_player']
	var card_id = event['number']
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		var facedown_override = null
		var placement_choice = await _get_renea_boost_placement_choice(player, card_id)
		if placement_choice == -1:
			return
		if placement_choice >= 0:
			facedown_override = placement_choice == 1
		game_wrapper.submit_boost(player, card_id, [], false, 0, [], facedown_override)
	else:
		ai_effect_do_boost(card_id)

func _on_pay_cost_gauge(event):
	var player = event['event_player']
	var enable_reminder = event['extra_info']
	var is_ex = event['extra_info2']
	var alternative_life_cost = event['extra_info3']
	var gauge_cost = game_wrapper.get_decision_info().cost
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		can_spend_life_for_gauge = game_wrapper.get_life_for_gauge_amount(Enums.PlayerId.PlayerId_Player) > 0
		var wild_swing_allowed = game_wrapper.get_decision_info().type == Enums.DecisionType.DecisionType_PayStrikeCost_CanWild
		begin_gauge_selection(
			gauge_cost,
			wild_swing_allowed,
			UISubState.UISubState_SelectCards_StrikeGauge,
			enable_reminder,
			is_ex,
			alternative_life_cost
		)
	else:
		ai_pay_cost(gauge_cost, false, alternative_life_cost)

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
		if prepared_character_action_data_available("force_for_effect"):
			var card_ids = prepared_character_action_data['force_ids']
			var ultras_as_single = prepared_character_action_data['treat_ultras_as_single_force']
			var success = game_wrapper.submit_force_for_effect(Enums.PlayerId.PlayerId_Player, card_ids, ultras_as_single)
			if success:
				prepared_character_action_data = {}
				change_ui_state(UIState.UIState_WaitForGameServer)
			return

		# Zsolt: auto-use free force up to force_max (no popup during ForceForEffect)
		var p = game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
		if p.zsolt_force_pool > 0:
			p.free_force = min(p.zsolt_force_pool, effect['force_max'])
		change_ui_state(null, UISubState.UISubState_SelectCards_ForceForEffect)
		select_card_up_to_force = effect['force_max']
		var require_max = -1
		if effect.get('overall_effect'):
			require_max = select_card_up_to_force
		var can_cancel = true
		if 'required' in effect and effect['required']:
			can_cancel = false
		# Tournelouse Ouroboros: paying the force is always optional.
		if is_tournelouse_ouroboros_force_choice():
			can_cancel = true
		begin_generate_force_selection(require_max, can_cancel, false, false, true)
	else:
		ai_force_for_effect(effect)

func _on_gauge_for_effect(event):
	var player = event['event_player']
	var effect = game_wrapper.get_decision_info().effect
	if player == Enums.PlayerId.PlayerId_Player and not observer_mode:
		if prepared_character_action_data_available("gauge_for_effect"):
			var card_ids = prepared_character_action_data['gauge_ids']
			var success = game_wrapper.submit_gauge_for_effect(Enums.PlayerId.PlayerId_Player, card_ids)
			if success:
				prepared_character_action_data = {}
				change_ui_state(UIState.UIState_WaitForGameServer)
			return

		select_card_require_min = 0
		if 'required' in effect and effect['required']:
			select_card_require_min = effect['gauge_max']
		select_card_require_max = effect['gauge_max']
		if effect.get('overall_effect'):
			select_card_must_be_max_or_min = true
		else:
			select_card_must_be_max_or_min = false
		if effect.get('allow_partial_gauge_selection', false):
			# Optional effect (e.g. syrus_dredge_fury_keep_choice): any amount in
			# [min_gauge, gauge_max] is a legal selection.
			select_card_must_be_max_or_min = false
			if 'min_gauge' in effect:
				select_card_require_min = effect['min_gauge']
		select_gauge_require_card_id = ""
		select_gauge_require_card_name = ""
		select_gauge_valid_card_types = []
		if 'require_specific_card_id' in effect:
			select_gauge_require_card_id = effect['require_specific_card_id']
			select_gauge_require_card_name = effect['require_specific_card_name']
		if 'valid_card_types' in effect:
			select_gauge_valid_card_types = effect['valid_card_types']
		begin_gauge_selection(-1, false, UISubState.UISubState_SelectCards_GaugeForEffect)
	else:
		ai_gauge_for_effect(effect)

func _on_emote(event):
	if restore_fast_forwarding:
		return
	var player = event['event_player']
	var is_image_emote = event['number']
	var emote = event['reason']
	if GlobalSettings.MuteEmotes:
		return

	spawn_emote(player, is_image_emote, emote)

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
		new_character.load_character(image_loader, {}, "rachel_lightningrod")
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

func setup_underboost_info(player, underboost_tracking, index, boost_card_id):
	underboost_tracking.append({
		"card_ids": [],
		"boost_card": boost_card_id
	})
	var boostinfo = boostinfo_dict[player][index]
	boostinfo.set_visibility(true)
	boostinfo_parent_dict[player].visible = true

func add_underboost_card(underboost_tracking, index, card_id):
	var cards_under_boost = underboost_tracking[index]
	cards_under_boost['card_ids'].append(card_id)

func reset_underboost_info(player, underboost_tracking, index):
	underboost_tracking.remove_at(index)
	var boostinfo = boostinfo_dict[player][index]
	boostinfo.reset()

	if not underboost_tracking:
		boostinfo_parent_dict[player].visible = false

func update_underboost_info(player, underboost_tracking, index):
	var cards_under_boost = underboost_tracking[index]
	var count = len(cards_under_boost['card_ids'])
	var boostinfo = boostinfo_dict[player][index]
	boostinfo.set_number(count)

func _on_place_underboost(event):
	var player = event['event_player']
	var boost_card_id = event['number']
	var new_card_id = event['extra_info']
	var place = event['extra_info2']

	var underboost_tracking = player_underboost_tracking
	if player == Enums.PlayerId.PlayerId_Opponent:
		underboost_tracking = opponent_underboost_tracking
	var index = 0
	for underboost_info in underboost_tracking:
		if underboost_info['boost_card'] == boost_card_id:
			break
		index += 1

	if new_card_id == -1:
		if place:
			# Set up boost info indicator
			setup_underboost_info(player, underboost_tracking, index, boost_card_id)
		else:
			# Remove boost info indicator
			reset_underboost_info(player, underboost_tracking, index)
	else:
		# Add new card under boost
		add_underboost_card(underboost_tracking, index, new_card_id)

		# Move the card to the set aside zone.
		var is_player = player == Enums.PlayerId.PlayerId_Player
		var card = find_card_on_board(new_card_id)
		card.flip_card_to_front(false)
		var deck_position = get_deck_button_position(is_player)
		card.discard_to(deck_position, CardBase.CardState.CardState_InDeck)
		reparent_to_zone(card, get_set_aside_zone(is_player))

		update_underboost_info(player, underboost_tracking, index)
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
			Enums.EventType.EventType_AddToStored:
				_on_add_to_stored(event)
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
			Enums.EventType.EventType_ChooseOpponentCardToDiscard:
				_on_choose_opponent_card_to_discard(event)
			Enums.EventType.EventType_Draw:
				_on_draw_event(event)
			Enums.EventType.EventType_Emote:
				_on_emote(event)
			Enums.EventType.EventType_EffectDoBoost:
				_on_effect_do_boost(event)
			Enums.EventType.EventType_EndOverdrive:
				delay = _stat_notice_event(event)
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
			Enums.EventType.EventType_PlaceCardUnderBoost:
				delay = _on_place_underboost(event)
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
			Enums.EventType.EventType_Say:
				delay = _on_say(event)
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
			Enums.EventType.EventType_MarkInfused:
				_set_card_bonus(event['number'], "critical")
				_add_bonus_label_text(event['event_player'], "[color=sky_blue]Infused![/color]\n")
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
			Enums.EventType.EventType_Strike_Infuse:
				update_boost_summary(Enums.PlayerId.PlayerId_Player, $AllCards/PlayerBoosts, $PlayerBoostZone)
				update_boost_summary(Enums.PlayerId.PlayerId_Opponent, $AllCards/OpponentBoosts, $OpponentBoostZone)
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
			Enums.EventType.EventType_Transform_Added:
				delay = _on_transform_added(event)
			_:
				printlog("ERROR: UNHANDLED EVENT")
				assert(false)

		# If a UI animation needs to play or pause events,
		# break off the remaining events and handle them later.
		if delay != 0:
			var remaining_events = events.slice(event_index + 1)
			begin_delay(delay, remaining_events)
			break


func _update_buttons(no_number_picker_update : bool = false):
	var button_choices = []
	# Update main action selection UI

	if not no_number_picker_update:
		action_menu.number_panel_current_number = 0

	var action_buttons_visible = ui_state == UIState.UIState_PickTurnAction
	if action_buttons_visible:
		player_bonus_panel.visible = false
		opponent_bonus_panel.visible = false
		if len(selected_cards) == 0:
			set_instructions("Choose an action:")
			instructions_ok_allowed = false
			instructions_cancel_allowed = false
			instructions_strike_options = {}
			instructions_pay_alternative_life_cost = 0
			instructions_face_attack_card = null
			button_choices.append({ "text": "Move", "action": _on_move_button_pressed, "disabled": not game_wrapper.can_do_move(Enums.PlayerId.PlayerId_Player) })
			button_choices.append({ "text": "Prepare", "action": _wrap_with_confirmation("Prepare", _on_prepare_button_pressed), "disabled": not game_wrapper.can_do_prepare(Enums.PlayerId.PlayerId_Player) })
			button_choices.append({ "text": "Change Cards", "action": _on_change_button_pressed, "disabled": not game_wrapper.can_do_change(Enums.PlayerId.PlayerId_Player) })
			var exceed_cost = game_wrapper.get_player_exceed_cost(Enums.PlayerId.PlayerId_Player)
			if exceed_cost >= 0 and not game_wrapper.is_player_exceeded(Enums.PlayerId.PlayerId_Player):
				button_choices.append({ "text": "Exceed (%s Gauge)" % exceed_cost, "action": _on_exceed_button_pressed, "disabled": not game_wrapper.can_do_exceed(Enums.PlayerId.PlayerId_Player) })
			if game_wrapper.can_do_reshuffle(Enums.PlayerId.PlayerId_Player):
				button_choices.append({ "text": "Manual Reshuffle", "action": _wrap_with_confirmation("Manual Reshuffle", _on_reshuffle_button_pressed), "disabled": false })
			var ex_transform_available = game_wrapper.can_do_ex_transform(Enums.PlayerId.PlayerId_Player)
			var ex_transform_text = "/Transform" if ex_transform_available else ""
			button_choices.append({ "text": "Boost" + ex_transform_text, "action": _wrap_with_confirmation("Boost", _on_boost_button_pressed), "disabled": not (game_wrapper.can_do_boost(Enums.PlayerId.PlayerId_Player) or ex_transform_available) })
			var turn_strike_action : Callable = _on_strike_button_pressed
			if _should_warn_about_skipping_strike_character_action():
				turn_strike_action = _wrap_with_skipped_character_action_confirmation(_on_strike_button_pressed)
			button_choices.append({ "text": "Strike", "action": turn_strike_action, "disabled": not game_wrapper.can_do_strike(Enums.PlayerId.PlayerId_Player) })
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
			var can_ex_transform = false
			var only_in_hand = true
			var only_in_gauge = true
			var only_in_hand_or_gauge = true
			var only_in_boosts = true
			var only_set_aside = true
			var allow_change_cards = true
			for card in selected_cards:
				var not_hand_or_gauge = false

				if not game_wrapper.is_card_in_hand(Enums.PlayerId.PlayerId_Player, card.card_id):
					only_in_hand = false
				else:
					not_hand_or_gauge = true

				if not game_wrapper.is_card_in_gauge(Enums.PlayerId.PlayerId_Player, card.card_id):
					only_in_gauge = false
				else:
					not_hand_or_gauge = true

				if not_hand_or_gauge:
					only_in_hand_or_gauge = false

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
					var logic_card = card_db.get_card(selected_cards[0].card_id)
					if logic_card.definition["boost"]["boost_type"] == "transform":
						boost_text = "EX Transform"
						can_ex_transform = game_wrapper.can_player_ex_transform(Enums.PlayerId.PlayerId_Player, selected_cards[0].card_id)
					else:
						can_boost = game_wrapper.can_player_boost(Enums.PlayerId.PlayerId_Player, selected_cards[0].card_id, ["hand"], "", false)
				elif len(selected_cards) == 2:
					var card1 = selected_cards[0]
					var card2 = selected_cards[1]
					if card_db.are_same_card(card1.card_id, card2.card_id):
						can_strike = true
						strike_text = "EX Strike"

						var logic_card = card_db.get_card(card1.card_id)
						if logic_card.definition["boost"]["boost_type"] == "transform":
							can_ex_transform = true
							boost_text = "EX Transform"
					elif card_db.get_card(card1.card_id).definition['type'] == "normal" and \
							card_db.get_card(card2.card_id).definition['boost']['boost_type'] == "overload":
						can_strike = true
						strike_text = "EX Strike"
			elif only_in_boosts:
				if len(selected_cards) == 1:
					var logic_card = card_db.get_card(selected_cards[0].card_id)
					var must_set_from_boost = 'must_set_from_boost' in logic_card.definition and logic_card.definition['must_set_from_boost']
					var may_set_from_boost = 'may_set_from_boost' in logic_card.definition and logic_card.definition['may_set_from_boost']
					can_strike = must_set_from_boost or may_set_from_boost
			elif only_set_aside:
				if len(selected_cards) == 1:
					can_strike = game_wrapper.can_strike_with_set_aside_card(
						Enums.PlayerId.PlayerId_Player, selected_cards[0].card_id)
					if game_wrapper.can_player_boost_from_extra(Enums.PlayerId.PlayerId_Player):
						can_boost = game_wrapper.can_player_boost(Enums.PlayerId.PlayerId_Player, selected_cards[0].card_id, ['extra'], "", false)
			elif only_in_gauge:
				if len(selected_cards) == 1 and game_wrapper.can_player_boost_from_gauge(Enums.PlayerId.PlayerId_Player):
					can_boost = game_wrapper.can_player_boost(Enums.PlayerId.PlayerId_Player, selected_cards[0].card_id, ['gauge'], "", false)

			if can_strike:
				card_name = card_db.get_card(selected_cards[0].card_id).definition['display_name']
				strike_text += " (%s)" % card_name
			if can_boost or can_ex_transform:
				var boost_name = card_db.get_card(selected_cards[0].card_id).definition['boost']['display_name']
				boost_text += " (%s)" % boost_name

			set_instructions("Do what with %s?" % card_name)
			instructions_ok_allowed = false
			instructions_cancel_allowed = false
			instructions_strike_options = {}
			instructions_pay_alternative_life_cost = 0
			instructions_face_attack_card = null
			var shortcut_strike_action : Callable = _wrap_with_confirmation(strike_text, _on_shortcut_strike_pressed)
			if _should_warn_about_skipping_strike_character_action():
				shortcut_strike_action = _wrap_with_skipped_character_action_confirmation(_on_shortcut_strike_pressed)
			button_choices.append({ "text": strike_text, "action": shortcut_strike_action, "disabled": not can_strike or not game_wrapper.can_do_strike(Enums.PlayerId.PlayerId_Player) })
			button_choices.append({ "text": boost_text, "action": _wrap_with_confirmation(boost_text, _on_shortcut_boost_pressed),
				"disabled": (not can_boost or not game_wrapper.can_do_boost(Enums.PlayerId.PlayerId_Player)) and (not can_ex_transform or not game_wrapper.can_do_ex_transform(Enums.PlayerId.PlayerId_Player)) })

			# Check for character actions with card-related shortcuts
			for i in range(game_wrapper.get_player_character_action_count(Enums.PlayerId.PlayerId_Player)):
				var char_action = game_wrapper.get_player_character_action(Enums.PlayerId.PlayerId_Player, i)
				var action_has_shortcut = false
				var shortcut_condition_met = false
				var action_name = ""
				var skip_effect_addon = false
				if 'shortcut_effect_type' in char_action:
					var shortcut_effect = game_wrapper.get_player_character_action_shortcut_effect(Enums.PlayerId.PlayerId_Player, i)
					if char_action['shortcut_effect_type'] == "strike":
						action_has_shortcut = true
						action_name = "Strike with "
						shortcut_condition_met = can_strike
					elif char_action['shortcut_effect_type'] == "gauge_from_hand":
						action_has_shortcut = true
						var destination = char_action.get("shortcut_destination_name", "")
						if destination:
							action_name = "Place in %s" % destination
							skip_effect_addon = true
						else:
							action_name = "Move to Gauge for "
						var min_cards = shortcut_effect['min_amount']
						var max_cards = shortcut_effect['max_amount']
						var card_type_limitation = shortcut_effect.get("card_type_limitation", ["normal", "special", "ultra"])
						var valid_card_count = min_cards <= len(selected_cards) and len(selected_cards) <= max_cards
						var valid_card_types = true
						for card in selected_cards:
							var logic_card = card_db.get_card(card.card_id)
							if logic_card.definition['type'] not in card_type_limitation:
								valid_card_types = false
								break
						shortcut_condition_met = valid_card_count and only_in_hand and valid_card_types
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
					elif char_action['shortcut_effect_type'] == "gauge_for_effect":
						action_has_shortcut = true
						action_name = "Spend for "
						var min_cards = 0
						if 'required' in shortcut_effect and shortcut_effect['required']:
							min_cards = shortcut_effect['gauge_max']
						var max_cards = shortcut_effect['gauge_max']
						var valid_card_count = min_cards <= len(selected_cards) and len(selected_cards) <= max_cards
						shortcut_condition_met = valid_card_count and only_in_gauge
					elif char_action['shortcut_effect_type'] == "force_for_effect":
						action_has_shortcut = true
						action_name = "Spend for "
						var required_force = shortcut_effect['force_max']
						shortcut_condition_met = only_in_hand_or_gauge and can_selected_cards_pay_force(required_force)

				if action_has_shortcut:
					var action_possible = game_wrapper.can_do_character_action(Enums.PlayerId.PlayerId_Player, i)
					if not skip_effect_addon:
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
				cancel_text = "Cancel" if is_tournelouse_ouroboros_force_choice() else "Pass"
			UISubState.UISubState_SelectCards_ChooseBoostsToSustain, UISubState.UISubState_SelectCards_ChooseFromTopdeck, UISubState.UISubState_SelectCards_ChooseOpponentCardToDiscard:
				cancel_text = "Cancel" if is_tournelouse_transform_bonus_choice() or is_tournelouse_ouroboros_transform_return_choice() else "Pass"
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
	var show_life_for_force_counter = false
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
				show_life_for_force_counter = true
				update_force_generation_message()
			UISubState.UISubState_SelectCards_ForceForBoost:
				free_force_toggle = game_wrapper.get_player_free_force(Enums.PlayerId.PlayerId_Player) > 0
				show_life_for_force_counter = true
				update_force_generation_message()
			UISubState.UISubState_SelectCards_ForceForChange:
				ultra_force_toggle = true
				free_force_toggle = game_wrapper.get_player_free_force(Enums.PlayerId.PlayerId_Player, "CHANGE_CARDS") > 0
				show_life_for_force_counter = true
				update_force_generation_message()
			UISubState.UISubState_SelectCards_ForceForArmor:
				free_force_toggle = game_wrapper.get_player_free_force(Enums.PlayerId.PlayerId_Player) > 0
				show_life_for_force_counter = true
				update_force_generation_message()
			UISubState.UISubState_SelectCards_ForceForEffect:
				ultra_force_toggle = true
				free_force_toggle = game_wrapper.get_player_free_force(Enums.PlayerId.PlayerId_Player) > 0
				show_life_for_force_counter = true
				if is_tournelouse_ouroboros_force_choice():
					set_instructions("Select a card to pay 1 force.")
				else:
					update_force_generation_message()
			UISubState.UISubState_SelectCards_StrikeForce:
				ex_discard_order_toggle = current_pay_costs_is_ex
				free_force_toggle = game_wrapper.get_player_free_force(Enums.PlayerId.PlayerId_Player) > 0
				show_life_for_force_counter = true
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
			UISubState.UISubState_SelectCards_Exceed, UISubState.UISubState_SelectCards_CharacterAction_Gauge, UISubState.UISubState_SelectCards_GaugeForBoost:
				update_gauge_selection_message()

	# Update arena location selection buttons
	for i in range(1, 10):
		var arena_button = get_arena_location_button(i)
		arena_button.visible = (ui_state == UIState.UIState_SelectArenaLocation and i in arena_locations_clickable)

	# Update boost zones
	update_boost_summary(Enums.PlayerId.PlayerId_Player, $AllCards/PlayerBoosts, $PlayerBoostZone)
	update_boost_summary(Enums.PlayerId.PlayerId_Opponent, $AllCards/OpponentBoosts, $OpponentBoostZone)

	choice_popout_button.visible = ui_sub_state in [UISubState.UISubState_SelectCards_ChooseFromTopdeck, UISubState.UISubState_SelectCards_ChooseOpponentCardToDiscard]

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
			card_text = get_effect_text_with_card_name(choice, card_text)

		var disabled = false
		if "_choice_disabled" in choice and choice["_choice_disabled"]:
			disabled = true

		if "_choice_func" in choice:
			button_choices.append({ "text": card_text, "action": choice["_choice_func"], "disabled": disabled })
		else:
			button_choices.append({ "text": card_text, "action": func(): _on_choice_pressed(choice_value), "disabled": disabled })

	if instructions_cancel_allowed:
		button_choices.append({ "text": cancel_text, "action": _on_instructions_cancel_button_pressed })
	if instructions_strike_options.get("wild_swing_allowed"):
		button_choices.append({ "text": "Wild Swing", "action": _on_wild_swing_button_pressed })
	if instructions_strike_options.get("extra_strike_options_count"):
		for i in range(instructions_strike_options["extra_strike_options_count"]):
			var strike_option = game_wrapper.get_player_extra_strike_option(Enums.PlayerId.PlayerId_Player, i)
			if strike_option:
				var button_text = get_effect_text_with_card_name(strike_option, "", true)
				button_choices.append({ "text": button_text, "action": func(): _on_extra_strike_button_pressed(i) })
	if instructions_pay_alternative_life_cost:
		button_choices.append({ "text": "Pay %s Life" % instructions_pay_alternative_life_cost, "action": _on_pay_alternative_life_cost_button_pressed })
	if ui_state == UIState.UIState_SelectCards and ui_sub_state in [UISubState.UISubState_SelectCards_StrikeCard, UISubState.UISubState_SelectCards_StrikeResponseCard, UISubState.UISubState_SelectCards_OpponentSetsFirst_StrikeCard, UISubState.UISubState_SelectCards_OpponentSetsFirst_StrikeResponseCard]:
		instructions_face_attack_card = game_wrapper.get_face_attack_card(Enums.PlayerId.PlayerId_Player)
	else:
		instructions_face_attack_card = null
	if instructions_face_attack_card:
		var face_card_name = instructions_face_attack_card.definition['display_name']
		button_choices.append({ "text": "Strike with %s" % face_card_name, "action": _on_face_attack_button_pressed })

	if can_spend_life_for_force and show_life_for_force_counter:
		instructions_number_picker_min = 0
		instructions_number_picker_max = game_wrapper.get_player_life(Enums.PlayerId.PlayerId_Player)

	if can_spend_life_for_gauge and ui_sub_state in [UISubState.UISubState_SelectCards_StrikeGauge, UISubState.UISubState_SelectCards_Exceed]:
		instructions_number_picker_min = 0
		instructions_number_picker_max = game_wrapper.get_player_life(Enums.PlayerId.PlayerId_Player)

	# Minato seal-to-pay: the number picker seals top discards. One discard = one
	# Force; three discards = one Gauge (step of 3).
	action_menu.number_picker_step = 1
	if can_seal_for_force and show_life_for_force_counter:
		var seal_force_player = game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
		var force_reduction = game_wrapper.get_player_force_cost_reduction(Enums.PlayerId.PlayerId_Player)
		var force_limit = max(0, select_card_require_force - force_reduction) if select_card_require_force > 0 else 99
		instructions_number_picker_min = 0
		instructions_number_picker_max = mini(seal_force_player.discards.size(), force_limit)
	if can_seal_for_gauge and ui_sub_state in [UISubState.UISubState_SelectCards_StrikeGauge, UISubState.UISubState_SelectCards_GaugeForBoost, UISubState.UISubState_SelectCards_GaugeForEffect, UISubState.UISubState_SelectCards_CharacterAction_Gauge, UISubState.UISubState_SelectCards_BoostCancel, UISubState.UISubState_SelectCards_Exceed]:
		var seal_gauge_player = game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
		var gauge_want = select_card_require_max if select_card_require_max > 0 else 99
		instructions_number_picker_min = 0
		instructions_number_picker_max = mini(seal_gauge_player.discards.size(), gauge_want * 3)
		action_menu.number_picker_step = 3

	# Set the Action Menu state
	var action_menu_hidden = false
	match ui_state:
		UIState.UIState_PlayingAnimation, UIState.UIState_WaitForGameServer, UIState.UIState_GameOver:
			action_menu_hidden = true
		UIState.UIState_WaitingOnOpponent:
			action_menu_hidden = true
	action_menu.visible = not action_menu_hidden and (button_choices.size() > 0 or instructions_visible)
	action_menu_container.visible = action_menu.visible
	action_menu.set_choices(
		current_instruction_text,
		button_choices,
		ultra_force_toggle,
		instructions_number_picker_min,
		instructions_number_picker_max,
		ex_discard_order_toggle,
		free_force_toggle,
		no_number_picker_update
	)
	current_action_menu_choices = button_choices

func get_effect_text_with_card_name(effect, current_text, skip_condition : bool = false):
	var card_name = ""
	var card_text = current_text
	if 'card_name' in effect:
		card_name = effect['card_name']
	card_text += GameStrings.get_effect_text(effect, false, true, skip_condition, card_name)
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
	return card_text

func _choice_text_without_tags(choice_text):
	return ChoiceTagRegex.sub(choice_text, "", true)

func update_boost_summary(player_id, boosts_card_holder, boost_box):
	var card_ids = []
	var card_db = game_wrapper.get_card_database()
	var summary_player = game_wrapper._get_player(player_id)
	for card in boosts_card_holder.get_children():
		card_ids.append(card.card_id)
	var transform_effects = []
	var normal_effects = []
	# Only characters whose face-down boosts delay their effects (Renea) keep
	# those effects secret; for everyone else face-down only hides card identity.
	var hides_facedown_boost_effects = summary_player.deck_flag("facedown_boosts_delay_effects")
	if summary_player.deck_flag("seal_discards_at_turn_start_when_exceeded") and summary_player.exceeded and summary_player.minato_seal_power_bonus > 0:
		normal_effects.append({
			"override_description": "Awakening: gains +%d Power on next attack." % int(summary_player.minato_seal_power_bonus)
		})
	# Tournelouse can stack several copies of the same normal as transforms; show
	# their shared text once with a count instead of repeating it per copy.
	var tournelouse_normal_transform_total = 0
	for card_id in card_ids:
		var card = card_db.get_card(card_id)
		if card.definition['type'] == "normal" and card.definition.has("replaced_boost") and card.definition['boost']['boost_type'] == "transform":
			tournelouse_normal_transform_total += 1
	var tournelouse_normal_transform_count = 0
	for card_id in card_ids:
		var card = card_db.get_card(card_id)
		if game_wrapper.is_card_in_sealed(player_id, card_id):
			# Skip cards that are moving out of the boost area.
			continue
		var add_to_effects = normal_effects
		if card.definition['boost']['boost_type'] == "immediate":
			# Immediate boosts can be here because of facedown,
			# but ignore them as we don't want that text to show.
			continue
		if card.definition['boost']['boost_type'] == "transform":
			add_to_effects = transform_effects

		# Renea: a face-down boost's contents are hidden until she reveals it.
		# Other characters (e.g. Syrus) use face-down purely to hide the card's
		# identity; their boost effects are public and should still be listed.
		if hides_facedown_boost_effects and card.definition['boost'].get("facedown"):
			continue

		var is_tournelouse_normal_transform = card.definition['type'] == "normal" and card.definition.has("replaced_boost") and card.definition['boost']['boost_type'] == "transform"
		if is_tournelouse_normal_transform:
			tournelouse_normal_transform_count += 1

		if 'stop_on_space_effect' in card.definition['boost']:
			var stop_on_space_effect = card.definition['boost']['stop_on_space_effect'].duplicate()
			stop_on_space_effect['timing'] = "on_stop_on_space"
			add_to_effects.append(stop_on_space_effect)
		# Boosts that accumulated a speed counter show it in their effect list.
		if card.get_meta("speedup_counter", 0) != 0:
			add_to_effects.append({
				"effect_type": StrikeEffects.Speedup,
				"amount": int(card.get_meta("speedup_counter"))
			})
		for effect in card.definition['boost']['effects']:
			if effect['timing'] != "now" or effect['effect_type'] in ["force_costs_reduced_passive", "ignore_push_and_pull_passive_bonus", "add_passive", "reduce_opponent_prepare_draw", "generate_free_force", "gauge_costs_reduced_passive"]:
				if effect['timing'] != "discarded":
					if is_tournelouse_normal_transform and tournelouse_normal_transform_count != tournelouse_normal_transform_total:
						continue
					var effect_to_add = effect
					if is_tournelouse_normal_transform:
						effect_to_add = effect.duplicate(true)
						effect_to_add["and"] = {
							"condition": "count_numbers",
							"condition_amount": tournelouse_normal_transform_count,
							"effect_type": StrikeEffects.Nothing
						}
					add_to_effects.append(effect_to_add)

	var boost_summary = ""
	# Renea: show how many hidden boosts are in play without revealing them.
	var renea_facedown_count = 0
	if hides_facedown_boost_effects:
		for card_id in card_ids:
			var renea_fd_card = card_db.get_card(card_id)
			if renea_fd_card and renea_fd_card.definition['boost'].get("facedown"):
				renea_facedown_count += 1
	if renea_facedown_count > 0:
		boost_summary += "[color=gray]? Face-down boost x %d[/color]\n" % renea_facedown_count
	# Head with once-per-game mechanic tracking
	var non_exceed_overdrive_active = game_wrapper.non_exceed_overdrive_active(player_id)
	if non_exceed_overdrive_active:
		boost_summary += "[color=cyan]Overdrive Active![/color]\n"

	var once_per_game_mechanic = game_wrapper.get_once_per_game_mechanic_name(player_id)
	if once_per_game_mechanic:
		var once_per_game_mechanic_available = game_wrapper.get_once_per_game_mechanic_available(player_id)
		if once_per_game_mechanic_available:
			boost_summary += "[color=gold](%s Available!)[/color]\n" % once_per_game_mechanic
		else:
			boost_summary += "[color=gray](%s Used)[/color]\n" % once_per_game_mechanic

	# Infusion
	if game_wrapper.is_player_infused(player_id):
		boost_summary += "[color=sky_blue]Infused![/color]\n"

	# normal effects / transforms

	for effect in normal_effects:
		if 'hide_effect' not in effect or not effect['hide_effect']:
			boost_summary += GameStrings.get_effect_text(effect) + "\n"
	for effect in transform_effects:
		if 'hide_effect' not in effect or not effect['hide_effect']:
			var transform_text = GameStrings.get_effect_text(effect)
			# Umina "Spiraling Descent" does nothing while The Sleeper Wakes has
			# flipped the Dreamlands face-down.
			if effect.get('effect_type', "") == "umina_spiraling_descent":
				if summary_player.umina_dreamlands_facedown:
					transform_text += " [color=gray](Invalid)[/color]"
			boost_summary += "[color=purple][TF][/color] " + transform_text + "\n"

	for card_id in card_ids:
		var card = card_db.get_card(card_id)
		var must_set_from_boost = 'must_set_from_boost' in card.definition and card.definition['must_set_from_boost']
		var may_set_from_boost = 'may_set_from_boost' in card.definition and card.definition['may_set_from_boost']
		if must_set_from_boost or may_set_from_boost:
			var attack_name = card.definition['display_name']
			boost_summary += "[color=green](Can set %s as attack!)[/color]\n" % attack_name
	boost_box.set_text(boost_summary)

func update_arena_squares():
	var arena_style := resolved_arena_style
	var uses_classic_arena := BackgroundManager.uses_classic_arena(arena_style)
	arena_graphics.visible = uses_classic_arena
	background_image.texture = BackgroundManager.get_background_texture(arena_style)
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

	var player_center_width = 0
	if $PlayerCharacter.is_wide:
		player_center_width = game_wrapper.get_player_extra_width(Enums.PlayerId.PlayerId_Player)
	var opponent_center_width = 0
	if $OpponentCharacter.is_wide:
		opponent_center_width = game_wrapper.get_player_extra_width(Enums.PlayerId.PlayerId_Opponent)
	friend_track_layer.texture = null if uses_classic_arena else BackgroundManager.get_arena_texture(
		arena_style, "B", 10 - cached_player_location)
	enemy_track_layer.texture = null if uses_classic_arena else BackgroundManager.get_arena_texture(
		arena_style, "R", 10 - cached_opponent_location)
	_update_track_overlays_for_character(
		friend_track_overlay_layers, arena_style, "B",
		cached_player_location, player_center_width, uses_classic_arena)
	_update_track_overlays_for_character(
		enemy_track_overlay_layers, arena_style, "R",
		cached_opponent_location, opponent_center_width, uses_classic_arena)

func _initialize_track_overlay_layers():
	if not friend_track_overlay_layers.is_empty() or not enemy_track_overlay_layers.is_empty():
		return
	for i in range(2):
		var friend_overlay = _create_track_overlay_layer(friend_track_layer, "FriendTrackLayerExtra%d" % [i + 1])
		add_child(friend_overlay)
		move_child(friend_overlay, friend_track_layer.get_index() + i + 1)
		friend_track_overlay_layers.append(friend_overlay)
	for i in range(2):
		var enemy_overlay = _create_track_overlay_layer(enemy_track_layer, "EnemyTrackLayerExtra%d" % [i + 1])
		add_child(enemy_overlay)
		move_child(enemy_overlay, enemy_track_layer.get_index() + i + 1)
		enemy_track_overlay_layers.append(enemy_overlay)

func _create_track_overlay_layer(template_layer : TextureRect, layer_name : String) -> TextureRect:
	var track_layer := TextureRect.new()
	track_layer.name = layer_name
	track_layer.offset_left = template_layer.offset_left
	track_layer.offset_top = template_layer.offset_top
	track_layer.offset_right = template_layer.offset_right
	track_layer.offset_bottom = template_layer.offset_bottom
	track_layer.mouse_filter = template_layer.mouse_filter
	track_layer.expand_mode = template_layer.expand_mode
	track_layer.stretch_mode = template_layer.stretch_mode
	track_layer.visible = false
	return track_layer

func _clear_track_overlays(layers : Array[TextureRect]):
	for layer in layers:
		layer.texture = null
		layer.visible = false

func _update_track_overlays_for_character(
		layers : Array[TextureRect],
		arena_style : String,
		prefix : String,
		center_location : int,
		extra_width : int,
		uses_classic_arena : bool):
	if uses_classic_arena or extra_width <= 0:
		_clear_track_overlays(layers)
		return
	var overlay_index = 0
	for offset in range(-extra_width, extra_width + 1):
		if offset == 0:
			continue
		if overlay_index >= layers.size():
			break
		var board_location = center_location + offset
		var overlay_texture : Texture2D = null
		if board_location >= 1 and board_location <= 9:
			overlay_texture = BackgroundManager.get_arena_texture(arena_style, prefix, 10 - board_location)
		layers[overlay_index].texture = overlay_texture
		layers[overlay_index].visible = overlay_texture != null
		overlay_index += 1
	for i in range(overlay_index, layers.size()):
		layers[i].texture = null
		layers[i].visible = false

func _prepare_initial_arena_visuals():
	var arena_style := resolved_arena_style
	var uses_classic_arena := BackgroundManager.uses_classic_arena(arena_style)
	arena_graphics.visible = uses_classic_arena
	background_image.texture = BackgroundManager.get_background_texture(arena_style)

	var player_extra_width = 0
	if $PlayerCharacter.is_wide:
		player_extra_width = game_wrapper.get_player_extra_width(Enums.PlayerId.PlayerId_Player)
	var opponent_extra_width = 0
	if $OpponentCharacter.is_wide:
		opponent_extra_width = game_wrapper.get_player_extra_width(Enums.PlayerId.PlayerId_Opponent)

	friend_track_layer.texture = null if uses_classic_arena else BackgroundManager.get_arena_texture(
		arena_style, "B", 10 - cached_player_location)
	enemy_track_layer.texture = null if uses_classic_arena else BackgroundManager.get_arena_texture(
		arena_style, "R", 10 - cached_opponent_location)
	_update_track_overlays_for_character(
		friend_track_overlay_layers, arena_style, "B",
		cached_player_location, player_extra_width, uses_classic_arena)
	_update_track_overlays_for_character(
		enemy_track_overlay_layers, arena_style, "R",
		cached_opponent_location, opponent_extra_width, uses_classic_arena)

func selected_cards_between_min_and_max() -> bool:
	var selected_count = len(selected_cards)
	return selected_count >= select_card_require_min && selected_count <= select_card_require_max

func can_press_ok():
	if observer_mode:
		return false

	if ui_state == UIState.UIState_SelectCards:
		match ui_sub_state:
			UISubState.UISubState_SelectCards_StrikeGauge, UISubState.UISubState_SelectCards_Exceed:
				return get_gauge_generated() >= select_card_require_min and get_gauge_generated() <= select_card_require_max
			UISubState.UISubState_SelectCards_DiscardCards:
				return selected_cards_between_min_and_max()
			UISubState.UISubState_SelectCards_BoostCancel, UISubState.UISubState_SelectCards_DiscardContinuousBoost, UISubState.UISubState_SelectCards_DiscardFromReference:
				return selected_cards_between_min_and_max()
			UISubState.UISubState_SelectCards_ChooseDiscardToDestination, UISubState.UISubState_SelectCards_DiscardCards_Choose, UISubState.UISubState_SelectCards_DiscardOpponentGauge:
				if is_tournelouse_ouroboros_hand_choice() and selected_cards.size() == 1 and is_tournelouse_ouroboros_paid_card(selected_cards[0].card_id):
					return false
				return selected_cards_between_min_and_max()
			UISubState.UISubState_SelectCards_DiscardCardsToGauge, UISubState.UISubState_SelectCards_Mulligan, UISubState.UISubState_SelectCards_CharacterAction_Gauge:
				return selected_cards_between_min_and_max()
			UISubState.UISubState_SelectCards_ChooseBoostsToSustain:
				if is_tournelouse_ouroboros_transform_return_choice() and selected_cards.size() == 1:
					return not is_tournelouse_ouroboros_paid_card(selected_cards[0].card_id) and not is_tournelouse_ouroboros_bargeist_return_blocked(selected_cards[0].card_id)
				return selected_cards_between_min_and_max()
			UISubState.UISubState_SelectCards_ChooseFromTopdeck, UISubState.UISubState_SelectCards_ChooseOpponentCardToDiscard:
				return selected_cards_between_min_and_max()
			UISubState.UISubState_SelectCards_MoveActionGenerateForce, UISubState.UISubState_SelectCards_CharacterAction_Force:
				return can_selected_cards_pay_force(select_card_require_force)
			UISubState.UISubState_SelectCards_ForceForChange:
				var force_selected = get_force_in_selected_cards()
				if use_free_force and game_wrapper.does_free_force_require_card_spent(Enums.PlayerId.PlayerId_Player):
					return force_selected >= 2
				return force_selected >= 1
			UISubState.UISubState_SelectCards_StrikeCard, UISubState.UISubState_SelectCards_StrikeResponseCard, UISubState.UISubState_SelectCards_OpponentSetsFirst_StrikeCard, UISubState.UISubState_SelectCards_OpponentSetsFirst_StrikeResponseCard:
				# As a special exception, allow 2 cards if exactly 2 cards and they're the same card.
				# EX attacks can't be set from boosts, however.
				if len(selected_cards) == 2:
					if not instructions_ex_allowed:
						return false
					# EX strikes cannot be made from the stored zone.
					if _selection_contains_stored_zone_strike_card():
						return false
					if (game_wrapper.is_card_in_boosts(Enums.PlayerId.PlayerId_Player, selected_cards[0].card_id) or
						game_wrapper.is_card_in_boosts(Enums.PlayerId.PlayerId_Player, selected_cards[1].card_id)):
							return false
					var card_db = game_wrapper.get_card_database()
					var card1 = selected_cards[0]
					var card2 = selected_cards[1]
					if card_db.get_card(card1.card_id).definition['type'] == "normal" and \
							card_db.get_card(card2.card_id).definition['boost']['boost_type'] == "overload":
								return true
					return card_db.are_same_card(card1.card_id, card2.card_id)
				elif len(selected_cards) == 1:
					return not instructions_ex_required
				return false
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
				# Tournelouse Ouroboros: exactly one card pays the force, and it
				# must leave at least one other hand card to transform.
				if is_tournelouse_ouroboros_force_choice():
					if force_selected < 1 or selected_cards.size() != 1:
						return false
					var selected_card_id = selected_cards[0].card_id
					if game_wrapper.is_card_in_hand(Enums.PlayerId.PlayerId_Player, selected_card_id) and game_wrapper.get_player_hand_size(Enums.PlayerId.PlayerId_Player) <= 1:
						return false
					var decision_choice = game_wrapper.get_decision_info().choice
					if decision_choice != null:
						for hand_option in decision_choice:
							if hand_option != selected_card_id:
								return true
					return not game_wrapper.is_card_in_hand(Enums.PlayerId.PlayerId_Player, selected_card_id)
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
				return selected_cards_between_min_and_max()
			UISubState.UISubState_SelectCards_ForceForBoost:
				return can_selected_cards_pay_force(select_card_require_force)
			UISubState.UISubState_SelectCards_GaugeForBoost:
				return can_selected_cards_pay_force(select_card_require_max)
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
		enable_instructions_ui(
			"Pick a number from %s-%s to %s" % [str(min_value), str(max_value), decision_info.effect_type],
			true,
			false,
			{},
			false,
			additional_choices,
			true
		)
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

func _wrap_with_confirmation(action_text: String, action: Callable) -> Callable:
	if GlobalSettings.ActionConfirmationEnabled:
		return func(): _show_action_confirmation(action_text, action)
	return action

func _show_action_confirmation(action_text: String, action: Callable) -> void:
	var on_confirm = func(): action.call()
	var on_cancel = func(): _update_buttons()
	var confirm_choices = [
		{ "text": "Confirm", "action": on_confirm },
		{ "text": "Cancel", "action": on_cancel },
	]
	current_action_menu_choices = confirm_choices
	action_menu.set_choices(
		"Are you sure you want to %s?" % action_text,
		confirm_choices,
		false, -1, -1, false, false, false, 2
	)
	action_menu.visible = true

func _should_warn_about_skipping_strike_character_action() -> bool:
	if ui_state != UIState.UIState_PickTurnAction:
		return false
	if game_wrapper.get_active_player() != Enums.PlayerId.PlayerId_Player:
		return false
	var current_player = game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
	if not current_player or not current_player.deck_flag("warn_when_striking_without_character_action"):
		return false
	for i in range(game_wrapper.get_player_character_action_count(Enums.PlayerId.PlayerId_Player)):
		if game_wrapper.can_do_character_action(Enums.PlayerId.PlayerId_Player, i):
			return true
	return false

func _wrap_with_skipped_character_action_confirmation(action: Callable) -> Callable:
	return func(): _show_skipped_character_action_confirmation(action)

func _show_skipped_character_action_confirmation(action: Callable) -> void:
	var on_confirm = func(): action.call()
	var on_cancel = func(): _update_buttons()
	var confirm_choices = [
		{ "text": "Confirm", "action": on_confirm },
		{ "text": "Cancel", "action": on_cancel },
	]
	current_action_menu_choices = confirm_choices
	action_menu.set_choices(
		"Strike without using your character action?",
		confirm_choices,
		false, -1, -1, false, false, false, 2
	)
	action_menu.visible = true

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
	if game_wrapper.can_player_boost_from_extra(Enums.PlayerId.PlayerId_Player):
		# Renea: the Briefcase may only be boosted from once per turn.
		var renea_bp = game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
		if not renea_bp.deck_flag("boost_from_stored_zone_grants_action_when_exceeded") or not renea_bp.exceeded or not renea_bp.renea_boost_from_briefcase_used:
			valid_zones.append('extra')
	if game_wrapper.can_player_boost_from_gauge(Enums.PlayerId.PlayerId_Player):
		valid_zones.append('gauge')
	begin_boost_choosing(true, valid_zones, "", false, 1)

# Renea's non-exceeded ability lets her place any continuous boost face-down
# instead of resolving it now. Returns the chosen index (0 face-up, 1 face-down),
# -1 if the player backed out, or -2 if the choice doesn't apply.
func _show_boost_placement_choice():
	current_action_menu_choices = [
		{"action": func(): pass},
		{"action": func(): pass}
	]
	action_menu.set_choices("Place boost:", [
		{"text": "Face-up (normal)"},
		{"text": "Face-down (hidden)"}
	], false, -1, -1, false, false, true)
	action_menu.visible = true
	var idx = await action_menu.choice_selected
	close_popout()
	return idx

func _get_renea_boost_placement_choice(player_id : Enums.PlayerId, card_id : int) -> int:
	var renea_player = game_wrapper._get_player(player_id)
	if renea_player == null or not renea_player.deck_flag("facedown_boosts_delay_effects") or renea_player.exceeded:
		return -2
	var logic_card = game_wrapper.get_card_database().get_card(card_id)
	if logic_card == null or logic_card.definition['boost']['boost_type'] != "continuous":
		return -2
	return await _show_boost_placement_choice()

func _renea_has_facedown_boosts() -> bool:
	var renea_p = game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
	if renea_p == null or not renea_p.deck_flag("facedown_boosts_delay_effects"):
		return false
	for bc in renea_p.continuous_boosts:
		if bc.definition["boost"].get("facedown"):
			return true
	return false

func _renea_process_facedown_boosts(strike_response : bool = false):
	deselect_all_cards()
	# Sent as its own action in online games so both engines resolve the same
	# face-down effects before the attack card is selected.
	if game_wrapper.submit_renea_pre_strike_reveal(Enums.PlayerId.PlayerId_Player, strike_response):
		change_ui_state(UIState.UIState_WaitForGameServer)

func _on_strike_button_pressed():
	# Minato: "Outrun the Past" (from the Flight transform) triggers before attack
	# selection, letting the player seal a discard to draw a card.
	var minato_p = game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
	if minato_p.deck_flag("can_seal_discards_for_resources") and not minato_p.minato_outrun_triggered_before_strike:
		for minato_tf in minato_p.transforms:
			if minato_tf.definition.get("id") == "minato_flight_13":
				minato_p.minato_outrun_triggered_before_strike = true
				game_wrapper.current_game.handle_strike_effect(-1, {"effect_type": "minato_outrun_the_past", "minato_otp_sealed": 0}, minato_p)
				return
	# Renea reveals her face-down boosts (and resolves their Now effects) before
	# choosing an attack; the strike UI opens once that finishes.
	if _renea_has_facedown_boosts():
		_renea_process_facedown_boosts()
		return
	begin_strike_choosing(false, true)

# Re-opens the correct local interaction UI after a reconnect restore, when the
# game is sitting in a decision but the UI is parked in a wait state.
func _sync_ui_state_after_restore():
	if ui_state == UIState.UIState_GameOver:
		return
	if ui_state in [UIState.UIState_SelectCards, UIState.UIState_MakeChoice, UIState.UIState_SelectArenaLocation]:
		_update_buttons()
		return

	var game_state = game_wrapper.get_game_state()
	if game_state == Enums.GameState.GameState_PickAction:
		if game_wrapper.get_active_player() == Enums.PlayerId.PlayerId_Player and not observer_mode:
			change_ui_state(UIState.UIState_PickTurnAction, UISubState.UISubState_None)
		else:
			change_ui_state(UIState.UIState_WaitingOnOpponent, UISubState.UISubState_None)
		return

	if game_state == Enums.GameState.GameState_PlayerDecision:
		var decision_info = game_wrapper.get_decision_info()
		if decision_info.player == Enums.PlayerId.PlayerId_Player and not observer_mode:
			if _restore_local_player_decision_ui(decision_info):
				return
		else:
			change_ui_state(UIState.UIState_WaitingOnOpponent, UISubState.UISubState_None)
			return

	change_ui_state(UIState.UIState_WaitForGameServer, UISubState.UISubState_None)

# Dispatches to the matching decision handler for the local player. Returns true
# when the decision type is handled. Types not covered here fall back to a wait
# state (the engine re-drives them via events on the next poll).
func _restore_local_player_decision_ui(decision_info) -> bool:
	var event = {"event_player": decision_info.player}
	match decision_info.type:
		Enums.DecisionType.DecisionType_ChooseFromDiscard:
			_on_choose_from_discard(event)
			return true
		Enums.DecisionType.DecisionType_ChooseFromBoosts:
			_on_choose_from_boosts(event)
			return true
		Enums.DecisionType.DecisionType_ChooseFromTopDeck:
			_on_choose_from_topdeck(event)
			return true
		Enums.DecisionType.DecisionType_ForceForEffect:
			_on_force_for_effect(event)
			return true
		Enums.DecisionType.DecisionType_GaugeForEffect:
			_on_gauge_for_effect(event)
			return true
		Enums.DecisionType.DecisionType_ChooseDiscardOpponentGauge:
			_on_discard_opponent_gauge(event)
			return true
		Enums.DecisionType.DecisionType_ChooseArenaLocationForEffect:
			_on_choose_arena_location_for_effect(event)
			return true
	return false

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
					select_card_destination = shortcut_effect.get("destination", "gauge")
					var card_type_limitation = shortcut_effect.get("card_type_limitation", ["normal", "special", "ultra"])
					var restriction_list = game_wrapper.get_player_cards_in_hand_matching_types(
						Enums.PlayerId.PlayerId_Player,
						card_type_limitation
					)
					var restriction_ids = []
					for card in restriction_list:
						restriction_ids.append(card.id)
					begin_discard_cards_selection(
						shortcut_effect['min_amount'],
						shortcut_effect['max_amount'],
						UISubState.UISubState_SelectCards_DiscardCardsToGauge,
						true,
						restriction_ids,
						false
					)
				"choice":
					var instruction_text = "Select an effect for %s:" % prepared_character_action_data['action_name']
					begin_effect_choice(shortcut_effect['choice'], instruction_text, [], true)
				"boost_from_gauge":
					var valid_zones = ['gauge']
					var limitation = ""
					if 'limitation' in shortcut_effect:
						limitation = shortcut_effect['limitation']
					begin_boost_choosing(true, valid_zones, limitation, false, 1)
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
				"move_any_boost":
					var locations = game_wrapper.get_valid_locations_for_buddy_effect(Enums.PlayerId.PlayerId_Player, shortcut_effect)
					prepared_character_action_data['locations'] = locations
					arena_locations_clickable = locations
					var boost_name = shortcut_effect['boost_name']
					var instruction_str = "Select a %s boost to move" % boost_name
					enable_instructions_ui(instruction_str, false, true)
					change_ui_state(UIState.UIState_SelectArenaLocation, UISubState.UISubState_SelectArena_EffectChoice)
				"gauge_for_effect":
					prepared_character_action_data['effect'] = shortcut_effect
					select_card_require_min = 0
					if 'required' in shortcut_effect and shortcut_effect['required']:
						select_card_require_min = shortcut_effect['gauge_max']
					select_card_require_max = shortcut_effect['gauge_max']
					if shortcut_effect.get('overall_effect'):
						select_card_must_be_max_or_min = true
					else:
						select_card_must_be_max_or_min = false
					select_gauge_require_card_id = ""
					select_gauge_require_card_name = ""
					select_gauge_valid_card_types = []
					if 'require_specific_card_id' in shortcut_effect:
						select_gauge_require_card_id = shortcut_effect['require_specific_card_id']
						select_gauge_require_card_name = shortcut_effect['require_specific_card_name']
					if 'valid_card_types' in shortcut_effect:
						select_gauge_valid_card_types = shortcut_effect['valid_card_types']
					begin_gauge_selection(-1, false, UISubState.UISubState_SelectCards_GaugeForEffect)
				"force_for_effect":
					prepared_character_action_data['effect'] = shortcut_effect
					change_ui_state(null, UISubState.UISubState_SelectCards_ForceForEffect)
					select_card_up_to_force = shortcut_effect['force_max']
					if 'per_force_effect' in shortcut_effect and shortcut_effect['per_force_effect']:
						assert(false, "Per-Force effect action shortcuts not supported")
					begin_generate_force_selection(select_card_up_to_force, true)
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
				var gauge_cost = game_wrapper.get_card_database().get_card_boost_gauge_cost(single_card_id)
				var force_cost = game_wrapper.get_card_database().get_card_boost_force_cost(single_card_id)
				if gauge_cost > 0:
					preparing_character_action = true
					selected_boost_to_pay_for = single_card_id
					change_ui_state(null, UISubState.UISubState_SelectCards_GaugeForBoost)
					begin_gauge_selection(gauge_cost, false, UISubState.UISubState_SelectCards_GaugeForBoost)
					_update_buttons()
					return
				# Zsolt Battle Instinct: let player choose how much free force to use
				var zsolt_p = game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
				if zsolt_p.zsolt_force_pool > 0:
					zsolt_p.free_force = 0
					var pool_amount = zsolt_p.zsolt_force_pool
					current_action_menu_choices = []
					for i in range(pool_amount + 1):
						current_action_menu_choices.append({"action": func(): pass})
					var options = []
					for i in range(pool_amount + 1):
						options.append({"text": str(i)})
					action_menu.set_choices("Use how much free force?", options, false, -1, -1, false, false, false)
					action_menu.visible = true
					var idx = await action_menu.choice_selected
					close_popout()
					zsolt_p.free_force = idx
				if force_cost > 0:
					preparing_character_action = true
					selected_boost_to_pay_for = single_card_id
					change_ui_state(null, UISubState.UISubState_SelectCards_ForceForBoost)
					begin_generate_force_selection(force_cost, true, false, false, true)
					_update_buttons()
					return
		"self_discard_choose":
			prepared_character_action_data['discard_ids'] = selections
		"place_buddy_in_any_space", "move_buddy", "place_buddy_at_range", "move_any_boost":
			var location = selections[0]
			var location_options = prepared_character_action_data['locations']
			for i in range(location_options.size()):
				if location_options[i] == location:
					prepared_character_action_data['choice'] = i
					break
			prepared_character_action_data['effect_type'] = 'place_buddy_effect'
		"gauge_for_effect":
			prepared_character_action_data['gauge_ids'] = selections
		"force_for_effect":
			prepared_character_action_data['force_ids'] = selections
			prepared_character_action_data['treat_ultras_as_single_force'] = treat_ultras_as_single_force
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

func _apply_minato_seal_payment() -> int:
	# Seals top discards to generate Force / Gauge for the current payment and
	# returns the amount of local "free gauge" it granted (so the caller can clear
	# it after submitting, since do_gauge_for_effect reads but does not consume it).
	if not can_seal_for_force and not can_seal_for_gauge:
		return 0
	var seal_player = game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
	var using_remote_game = game_wrapper.current_game is RemoteGame
	var is_minato = seal_player.deck_flag("can_seal_discards_for_resources") and not seal_player.exceeded
	var force_sub_states = [
		UISubState.UISubState_SelectCards_ForceForBoost,
		UISubState.UISubState_SelectCards_StrikeForce,
		UISubState.UISubState_SelectCards_ForceForEffect,
		UISubState.UISubState_SelectCards_ForceForChange,
		UISubState.UISubState_SelectCards_ForceForArmor,
		UISubState.UISubState_SelectCards_MoveActionGenerateForce,
		UISubState.UISubState_SelectCards_CharacterAction_Force,
	]
	var gauge_sub_states = [
		UISubState.UISubState_SelectCards_StrikeGauge,
		UISubState.UISubState_SelectCards_GaugeForBoost,
		UISubState.UISubState_SelectCards_GaugeForEffect,
		UISubState.UISubState_SelectCards_CharacterAction_Gauge,
		UISubState.UISubState_SelectCards_BoostCancel,
		UISubState.UISubState_SelectCards_Exceed,
	]
	var minato_sealed_force = 0
	var minato_sealed_gauge = 0
	var local_free_gauge_added = 0
	if can_seal_for_force and is_minato and ui_sub_state in force_sub_states:
		var seal_ct = mini(action_menu.number_panel_current_number, seal_player.discards.size())
		if seal_ct > 0:
			minato_sealed_force = seal_ct
			if not using_remote_game:
				seal_player.seal_top_n_discards(seal_ct)
				seal_player.seal_force_bonus_tmp = minato_sealed_force
	elif can_seal_for_gauge and is_minato and ui_sub_state in gauge_sub_states:
		var seal_ct_gauge = int(action_menu.number_panel_current_number / 3.0) * 3
		if seal_ct_gauge > 0 and seal_player.discards.size() >= seal_ct_gauge:
			minato_sealed_gauge = int(seal_ct_gauge / 3.0)
			if not using_remote_game:
				seal_player.seal_top_n_discards(seal_ct_gauge)
				if not preparing_character_action:
					seal_player.free_gauge += minato_sealed_gauge
					local_free_gauge_added = minato_sealed_gauge
	if using_remote_game and (minato_sealed_force > 0 or minato_sealed_gauge > 0):
		game_wrapper.current_game.set_pending_minato_seal_payment(minato_sealed_force, minato_sealed_gauge)
	can_seal_for_force = false
	can_seal_for_gauge = false
	instructions_number_picker_min = -1
	instructions_number_picker_max = -1
	return local_free_gauge_added

func _on_instructions_ok_button_pressed(index : int):
	if can_press_ok():
		# Minato seal-to-pay: seal top discards to generate Force / Gauge for this
		# payment before submitting. One discard = one Force; three = one Gauge.
		var seal_gauge_granted = _apply_minato_seal_payment()
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

		var spent_life_for_force = get_spent_life_for_force()
		if can_spend_life_for_force:
			instructions_number_picker_min = -1
			instructions_number_picker_max = -1
			can_spend_life_for_force = false

		if can_spend_life_for_gauge:
			instructions_number_picker_min = -1
			instructions_number_picker_max = -1
			can_spend_life_for_gauge = false

		if preparing_character_action:
			finish_preparing_character_action(selected_card_ids)
			return

		match ui_sub_state:
			UISubState.UISubState_SelectCards_BoostCancel:
				success = game_wrapper.submit_boost_cancel(Enums.PlayerId.PlayerId_Player, selected_card_ids, true)
			UISubState.UISubState_SelectCards_ChooseFromTopdeck:
				var action_choices = game_wrapper.get_decision_info().action
				var chosen_action = action_choices[index]
				success = game_wrapper.submit_choose_from_topdeck(current_topdeck_choosing_player, single_card_id, chosen_action)
			UISubState.UISubState_SelectCards_ChooseOpponentCardToDiscard:
				var adjusted_id = single_card_id - ChoiceCopyIdRangeStart
				success = game_wrapper.submit_choose_to_discard(Enums.PlayerId.PlayerId_Player, [adjusted_id])
				clear_choice_zone()
			UISubState.UISubState_SelectCards_ChooseDiscardToDestination:
				success = game_wrapper.submit_choose_from_discard(Enums.PlayerId.PlayerId_Player, selected_card_ids)
			UISubState.UISubState_SelectCards_CharacterAction_Force, UISubState.UISubState_SelectCards_CharacterAction_Gauge:
				success = game_wrapper.submit_character_action(Enums.PlayerId.PlayerId_Player, selected_card_ids, selected_character_action, use_free_force)
			UISubState.UISubState_SelectCards_DiscardContinuousBoost, UISubState.UISubState_SelectCards_DiscardOpponentGauge:
				select_card_name_boost_restriction = ""
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
				success = game_wrapper.submit_relocate_card_from_hand(Enums.PlayerId.PlayerId_Player, selected_card_ids)
			UISubState.UISubState_SelectCards_StrikeForce:
				success = game_wrapper.submit_pay_strike_cost(Enums.PlayerId.PlayerId_Player, selected_card_ids, false, discard_ex_first_for_strike, use_free_force, spent_life_for_force, false)
			UISubState.UISubState_SelectCards_StrikeGauge:
				success = game_wrapper.submit_pay_strike_cost(Enums.PlayerId.PlayerId_Player, selected_card_ids, false, discard_ex_first_for_strike, false, 0, false, get_spent_life_for_gauge())
			UISubState.UISubState_SelectCards_Exceed:
				success = game_wrapper.submit_exceed(Enums.PlayerId.PlayerId_Player, selected_card_ids, get_spent_life_for_gauge())
			UISubState.UISubState_SelectCards_ForceForEffect:
				success = game_wrapper.submit_force_for_effect(Enums.PlayerId.PlayerId_Player, selected_card_ids, treat_ultras_as_single_force, false, use_free_force, spent_life_for_force)
			UISubState.UISubState_SelectCards_GaugeForEffect:
				success = game_wrapper.submit_gauge_for_effect(Enums.PlayerId.PlayerId_Player, selected_card_ids)
			UISubState.UISubState_SelectCards_MoveActionGenerateForce:
				success = game_wrapper.submit_move(Enums.PlayerId.PlayerId_Player, selected_card_ids, selected_arena_location, use_free_force, spent_life_for_force)
			UISubState.UISubState_SelectCards_ForceForChange:
				success = game_wrapper.submit_change(Enums.PlayerId.PlayerId_Player, selected_card_ids, treat_ultras_as_single_force, use_free_force, spent_life_for_force)
			UISubState.UISubState_SelectCards_StrikeCard, UISubState.UISubState_SelectCards_StrikeResponseCard, UISubState.UISubState_SelectCards_StrikeCard_FromGauge, UISubState.UISubState_SelectCards_StrikeCard_FromSealed:
				success = game_wrapper.submit_strike(Enums.PlayerId.PlayerId_Player, single_card_id, false, ex_card_id)
			UISubState.UISubState_SelectCards_OpponentSetsFirst_StrikeCard, UISubState.UISubState_SelectCards_OpponentSetsFirst_StrikeResponseCard:
				success = game_wrapper.submit_strike(Enums.PlayerId.PlayerId_Player, single_card_id, false, ex_card_id, true)
			UISubState.UISubState_SelectCards_ForceForArmor:
				success = game_wrapper.submit_force_for_armor(Enums.PlayerId.PlayerId_Player, selected_card_ids, use_free_force, spent_life_for_force)
			UISubState.UISubState_SelectCards_GaugeForArmor:
				success = game_wrapper.submit_force_for_armor(Enums.PlayerId.PlayerId_Player, selected_card_ids, false, 0)
			UISubState.UISubState_SelectCards_Mulligan:
				success = game_wrapper.submit_mulligan(Enums.PlayerId.PlayerId_Player, selected_card_ids)
			UISubState.UISubState_SelectCards_PlayBoost:
				var logic_card = game_wrapper.get_card_database().get_card(single_card_id)
				var facedown_override = null
				if logic_card.definition['boost']['boost_type'] != "transform":
					var placement_choice = await _get_renea_boost_placement_choice(Enums.PlayerId.PlayerId_Player, single_card_id)
					if placement_choice == -1:
						return
					if placement_choice >= 0:
						facedown_override = placement_choice == 1
				if logic_card.definition['boost']['boost_type'] == "transform":
					var ex_transform_id = -1
					if select_boost_options['limitation'] != "transform": # makes sure it's an EX transform action
						ex_transform_id = game_wrapper.get_ex_transform_copy(Enums.PlayerId.PlayerId_Player, single_card_id)
					success = game_wrapper.submit_boost(Enums.PlayerId.PlayerId_Player, single_card_id, [ex_transform_id], false, spent_life_for_force, [])
				else:
					var gauge_cost = game_wrapper.get_card_database().get_card_boost_gauge_cost(single_card_id)
					var force_cost = game_wrapper.get_card_database().get_card_boost_force_cost(single_card_id)
					if not select_boost_options['ignore_costs'] and gauge_cost > 0:
						assert(select_boost_options['boost_amount'] <= 1, "WARNING: Can't currently handle gauge costs for multiple boosts")
						selected_boost_to_pay_for = single_card_id
						selected_boost_facedown_override = facedown_override
						change_ui_state(null, UISubState.UISubState_SelectCards_GaugeForBoost)
						begin_gauge_selection(gauge_cost, false, UISubState.UISubState_SelectCards_GaugeForBoost)
					elif not select_boost_options['ignore_costs'] and force_cost > 0:
						assert(select_boost_options['boost_amount'] <= 1, "WARNING: Can't currently handle force costs for multiple boosts")
						# Zsolt Battle Instinct: let player choose how much free force to use
						var zsolt_p = game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
						if zsolt_p.zsolt_force_pool > 0:
							zsolt_p.free_force = 0
							var pool_amount = zsolt_p.zsolt_force_pool
							current_action_menu_choices = []
							for i in range(pool_amount + 1):
								current_action_menu_choices.append({"action": func(): pass})
							var options = []
							for i in range(pool_amount + 1):
								options.append({"text": str(i)})
							action_menu.set_choices("Use how much free force?", options, false, -1, -1, false, false, false)
							action_menu.visible = true
							var idx = await action_menu.choice_selected
							close_popout()
							zsolt_p.free_force = idx
						selected_boost_to_pay_for = single_card_id
						selected_boost_facedown_override = facedown_override
						change_ui_state(null, UISubState.UISubState_SelectCards_ForceForBoost)
						begin_generate_force_selection(force_cost, true, false, false, true)
					else:
						var additional_boost_ids = selected_card_ids.slice(1)
						success = game_wrapper.submit_boost(Enums.PlayerId.PlayerId_Player, single_card_id, [], use_free_force, spent_life_for_force, additional_boost_ids, facedown_override)
			UISubState.UISubState_SelectCards_ForceForBoost:
				success = game_wrapper.submit_boost(Enums.PlayerId.PlayerId_Player, selected_boost_to_pay_for, selected_card_ids, use_free_force, spent_life_for_force, [], selected_boost_facedown_override)
			UISubState.UISubState_SelectCards_GaugeForBoost:
				success = game_wrapper.submit_boost(Enums.PlayerId.PlayerId_Player, selected_boost_to_pay_for, selected_card_ids, false, false, [], selected_boost_facedown_override)
			UISubState.UISubState_PickNumberFromRange:
				success = handle_pick_range_ok()

		if success:
			if seal_gauge_granted > 0:
				# do_gauge_for_effect reads free_gauge but does not consume it, so
				# clear the seal-granted portion here to keep the payment one-shot.
				var seal_gauge_player = game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
				seal_gauge_player.free_gauge = max(0, seal_gauge_player.free_gauge - seal_gauge_granted)
			popout_instruction_info = null
			change_ui_state(UIState.UIState_WaitForGameServer)
		else:
			# The action was rejected, so nothing consumed the seal-to-pay amount
			# staged above. Discard it, otherwise it leaks into a later payment as
			# an unearned "passive bonus" of Force / Gauge.
			_discard_staged_minato_seal_payment(seal_gauge_granted)
		_update_buttons()

func _discard_staged_minato_seal_payment(seal_gauge_granted : int) -> void:
	if game_wrapper.current_game is RemoteGame:
		game_wrapper.current_game.clear_pending_minato_seal_payment()
	var seal_player = game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
	seal_player.seal_force_bonus_tmp = 0
	if seal_gauge_granted > 0:
		seal_player.free_gauge = max(0, seal_player.free_gauge - seal_gauge_granted)

func _on_instructions_cancel_button_pressed():
	if observer_mode:
		return
	# Discard any seal-to-pay amount staged by a previous (unsent) submission.
	game_wrapper.clear_pending_minato_seal_payment()

	var success = false

	if can_spend_life_for_force:
		instructions_number_picker_min = -1
		instructions_number_picker_max = -1
		can_spend_life_for_force = false

	if can_spend_life_for_gauge:
		instructions_number_picker_min = -1
		instructions_number_picker_max = -1
		can_spend_life_for_gauge = false

	if can_seal_for_force or can_seal_for_gauge:
		instructions_number_picker_min = -1
		instructions_number_picker_max = -1
		can_seal_for_force = false
		can_seal_for_gauge = false

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
			success = game_wrapper.submit_force_for_armor(Enums.PlayerId.PlayerId_Player, [], false, 0)
		UISubState.UISubState_SelectCards_ForceForEffect:
			deselect_all_cards()
			close_popout()
			success = game_wrapper.submit_force_for_effect(Enums.PlayerId.PlayerId_Player, [], false, true, false)
		UISubState.UISubState_SelectCards_GaugeForArmor:
			deselect_all_cards()
			close_popout()
			success = game_wrapper.submit_force_for_armor(Enums.PlayerId.PlayerId_Player, [], false, 0)
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
			success = game_wrapper.submit_relocate_card_from_hand(Enums.PlayerId.PlayerId_Player, [])
		UISubState.UISubState_SelectCards_ChooseBoostsToSustain:
			deselect_all_cards()
			close_popout()
			if is_tournelouse_ouroboros_transform_return_choice():
				success = game_wrapper.submit_cancel_tournelouse_ouroboros_transform_choice(Enums.PlayerId.PlayerId_Player)
			elif is_tournelouse_transform_bonus_choice():
				success = game_wrapper.submit_cancel_tournelouse_transform_bonus_choice(Enums.PlayerId.PlayerId_Player)
			else:
				success = game_wrapper.submit_choose_from_boosts(Enums.PlayerId.PlayerId_Player, [])
		UISubState.UISubState_SelectCards_ChooseDiscardToDestination:
			deselect_all_cards()
			close_popout()
			success = game_wrapper.submit_choose_from_discard(Enums.PlayerId.PlayerId_Player, [])
		UISubState.UISubState_SelectCards_DiscardContinuousBoost:
			select_card_name_boost_restriction = ""
			deselect_all_cards()
			close_popout()
			success = game_wrapper.submit_boost_name_card_choice_effect(Enums.PlayerId.PlayerId_Player, -1)
		UISubState.UISubState_SelectCards_ChooseFromTopdeck:
			deselect_all_cards()
			close_popout()
			success = game_wrapper.submit_choose_from_topdeck(current_topdeck_choosing_player, -1, "pass")
		UISubState.UISubState_SelectCards_DiscardCards_Choose:
			deselect_all_cards()
			close_popout()
			if is_tournelouse_ouroboros_hand_choice():
				success = game_wrapper.submit_cancel_tournelouse_ouroboros_hand_choice(Enums.PlayerId.PlayerId_Player)
			else:
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
				var boost_amount = select_boost_options["boost_amount"]
				begin_boost_choosing(can_cancel, valid_zones, limitation, ignore_costs, boost_amount)
			else:
				change_ui_state(UIState.UIState_PickTurnAction, UISubState.UISubState_None)
		UISubState.UISubState_SelectCards_GaugeForBoost:
			deselect_all_cards()
			close_popout()
			if select_boost_options:
				var can_cancel = select_boost_options["can_cancel"]
				var valid_zones = select_boost_options["valid_zones"]
				var limitation = select_boost_options["limitation"]
				var ignore_costs = select_boost_options["ignore_costs"]
				var boost_amount = select_boost_options["boost_amount"]
				begin_boost_choosing(can_cancel, valid_zones, limitation, ignore_costs, boost_amount)
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
			success = game_wrapper.submit_pay_strike_cost(Enums.PlayerId.PlayerId_Player, [], true, false, false, 0, false)
		elif ui_sub_state == UISubState.UISubState_SelectCards_StrikeForce:
			close_popout()
			success = game_wrapper.submit_pay_strike_cost(Enums.PlayerId.PlayerId_Player, [], true, false, false, 0, false)
	if success:
		deselect_all_cards()
		change_ui_state(UIState.UIState_WaitForGameServer)
	_update_buttons()

func _on_extra_strike_button_pressed(index : int):
	var success = false
	if ui_state == UIState.UIState_SelectCards:
		if ui_sub_state == UISubState.UISubState_SelectCards_StrikeCard or ui_sub_state == UISubState.UISubState_SelectCards_StrikeResponseCard:
			success = game_wrapper.submit_strike(Enums.PlayerId.PlayerId_Player, -1, true, index)
		elif ui_sub_state == UISubState.UISubState_SelectCards_OpponentSetsFirst_StrikeCard or ui_sub_state == UISubState.UISubState_SelectCards_OpponentSetsFirst_StrikeResponseCard:
			success = game_wrapper.submit_strike(Enums.PlayerId.PlayerId_Player, -1, true, index, true)
	if success:
		deselect_all_cards()
		change_ui_state(UIState.UIState_WaitForGameServer)
	_update_buttons()

func _on_pay_alternative_life_cost_button_pressed():
	var success = false
	if ui_state == UIState.UIState_SelectCards:
		if ui_sub_state == UISubState.UISubState_SelectCards_StrikeGauge:
			close_popout()
			success = game_wrapper.submit_pay_strike_cost(Enums.PlayerId.PlayerId_Player, [], false, false, false, 0, true)

	if success:
		deselect_all_cards()
		change_ui_state(UIState.UIState_WaitForGameServer)
	_update_buttons()

func _on_face_attack_button_pressed():
	var success = false
	if ui_state == UIState.UIState_SelectCards:
		if ui_sub_state == UISubState.UISubState_SelectCards_StrikeCard or ui_sub_state == UISubState.UISubState_SelectCards_StrikeResponseCard:
			success = game_wrapper.submit_strike(Enums.PlayerId.PlayerId_Player, -1, false, -1, false, true)
		elif ui_sub_state == UISubState.UISubState_SelectCards_OpponentSetsFirst_StrikeCard or ui_sub_state == UISubState.UISubState_SelectCards_OpponentSetsFirst_StrikeResponseCard:
			success = game_wrapper.submit_strike(Enums.PlayerId.PlayerId_Player, -1, false, -1, true, true)
	if success:
		deselect_all_cards()
		change_ui_state(UIState.UIState_WaitForGameServer)
	_update_buttons()

func _on_shortcut_strike_pressed():
	# Renea must reveal her face-down boosts before an attack is set; the player
	# re-picks their card once those resolve.
	if _renea_has_facedown_boosts():
		_renea_process_facedown_boosts()
		return
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

	# Renea: the Briefcase may only be boosted from once per turn.
	var renea_p = game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
	if renea_p.deck_flag("boost_from_stored_zone_grants_action_when_exceeded") and renea_p.exceeded and renea_p.renea_boost_from_briefcase_used and renea_p.is_card_in_set_aside(card_id):
		spawn_damage_popup("Briefcase already used this turn!", Enums.PlayerId.PlayerId_Player)
		return

	var success = false

	var logic_card = game_wrapper.get_card_database().get_card(card_id)
	var facedown_override = null
	if logic_card.definition['boost']['boost_type'] != "transform":
		var placement_choice = await _get_renea_boost_placement_choice(Enums.PlayerId.PlayerId_Player, card_id)
		if placement_choice == -1:
			return
		if placement_choice >= 0:
			facedown_override = placement_choice == 1
	if logic_card.definition['boost']['boost_type'] == "transform":
		var ex_transform_id = -1
		if len(selected_cards) > 0:
			ex_transform_id = selected_cards[1]
		else:
			ex_transform_id = game_wrapper.get_ex_transform_copy(Enums.PlayerId.PlayerId_Player, card_id)
		success = game_wrapper.submit_boost(Enums.PlayerId.PlayerId_Player, card_id, [ex_transform_id], false, 0)
	else:
		var gauge_cost = game_wrapper.get_card_database().get_card_boost_gauge_cost(card_id)
		var force_cost = game_wrapper.get_card_database().get_card_boost_force_cost(card_id)
		if gauge_cost > 0:
			selected_boost_to_pay_for = card_id
			selected_boost_facedown_override = facedown_override
			change_ui_state(null, UISubState.UISubState_SelectCards_GaugeForBoost)
			begin_gauge_selection(gauge_cost, false, UISubState.UISubState_SelectCards_GaugeForBoost)
		elif force_cost > 0:
			# Zsolt Battle Instinct: let player choose how much free force to use
			var zsolt_p = game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
			if zsolt_p.zsolt_force_pool > 0:
				zsolt_p.free_force = 0
				var pool_amount = zsolt_p.zsolt_force_pool
				current_action_menu_choices = []
				for i in range(pool_amount + 1):
					current_action_menu_choices.append({"action": func(): pass})
				var options = []
				for i in range(pool_amount + 1):
					options.append({"text": str(i)})
				action_menu.set_choices("Use how much free force?", options, false, -1, -1, false, false, false)
				action_menu.visible = true
				var idx = await action_menu.choice_selected
				close_popout()
				zsolt_p.free_force = idx
			selected_boost_to_pay_for = card_id
			selected_boost_facedown_override = facedown_override
			change_ui_state(null, UISubState.UISubState_SelectCards_ForceForBoost)
			begin_generate_force_selection(force_cost, true, false, false, true)
		else:
			success = game_wrapper.submit_boost(Enums.PlayerId.PlayerId_Player, card_id, [], use_free_force, 0, [], facedown_override)

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
	# Zsolt Battle Instinct: let player choose how much free force to use
	var p = game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
	if p.zsolt_force_pool > 0:
		p.free_force = 0
		var pool_amount = p.zsolt_force_pool
		# Clear old button choices to prevent _on_action_menu_choice_selected
		# from running a stale action when the popup choice is made
		current_action_menu_choices = []
		for i in range(pool_amount + 1):
			current_action_menu_choices.append({"action": func(): pass})
		var options = []
		for i in range(pool_amount + 1):
			options.append({"text": str(i)})
		action_menu.set_choices("Use how much free force?", options, false, -1, -1, false, false, false)
		action_menu.visible = true
		var idx = await action_menu.choice_selected
		close_popout()
		p.free_force = idx

	change_ui_state(null, UISubState.UISubState_SelectCards_ForceForChange)
	select_card_require_force = -1

	treat_ultras_as_single_force = false
	use_free_force = game_wrapper.get_player_free_force(Enums.PlayerId.PlayerId_Player, "CHANGE_CARDS") > 0
	can_spend_life_for_force = game_wrapper.get_life_for_force_amount(Enums.PlayerId.PlayerId_Player) > 0
	can_seal_for_gauge = false
	can_seal_for_force = p.deck_flag("can_seal_discards_for_resources") and not p.exceeded and p.discards.size() > 0
	action_menu.set_force_ultra_toggle(false)
	action_menu.set_free_force_toggle(use_free_force)

	enable_instructions_ui("", true, true, {})
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
	var success = game_wrapper.submit_move(Enums.PlayerId.PlayerId_Opponent, card_ids, location, do_use_free_force, 0)
	if not success:
		printlog("FAILED AI MOVE")
	return success

func ai_handle_change_cards(action : AIPlayer.ChangeCardsAction):
	var card_ids = action.card_ids
	var do_use_free_force = action.use_free_force
	var success = game_wrapper.submit_change(Enums.PlayerId.PlayerId_Opponent, card_ids, false, do_use_free_force, 0)
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
	var additional_boost_ids = action.additional_boost_ids
	var success = game_wrapper.submit_boost(Enums.PlayerId.PlayerId_Opponent, card_id, payment_card_ids, do_use_free_force, 0, additional_boost_ids)
	if not success:
		printlog("FAILED AI BOOST")
	return success

func ai_effect_do_boost(card_id : int):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var success = game_wrapper.submit_boost(Enums.PlayerId.PlayerId_Opponent, card_id, [], false, 0)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI EFFECT CAUSED BOOST")

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
	var success = game_wrapper.submit_character_action(Enums.PlayerId.PlayerId_Opponent, action.card_ids, action.action_idx, action.use_free_force, 0)
	if not success:
		printlog("FAILED AI CHARACTER ACTION")
	return success

func ai_take_turn():
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var success = false
	var turn_action = ai_player.take_turn()
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

func ai_do_boost(valid_zones : Array, limitation : String, ignore_costs : bool = false, boost_amount : int = 1):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var boost_action = ai_player.take_boost(valid_zones, limitation, ignore_costs, boost_amount)
	var success = ai_handle_boost(boost_action)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI DO BOOST")

func ai_pay_cost(cost, is_force_cost : bool, alternative_life_cost : int = 0):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var can_wild = game_wrapper.get_decision_info().type == Enums.DecisionType.DecisionType_PayStrikeCost_CanWild
	var pay_action
	if is_force_cost:
		pay_action = ai_player.pay_strike_force_cost(cost, can_wild, alternative_life_cost)
	else:
		pay_action = ai_player.pay_strike_gauge_cost(cost, can_wild, alternative_life_cost)
	var success = game_wrapper.submit_pay_strike_cost(Enums.PlayerId.PlayerId_Opponent, pay_action.card_ids, pay_action.wild_swing, false, pay_action.use_free_force, 0, false)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI PAY COST")

func ai_effect_choice(_event):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var effect_action = ai_player.pick_effect_choice()
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
	var forceforarmor_action = ai_player.pick_force_for_armor(use_gauge_instead)
	var success = game_wrapper.submit_force_for_armor(Enums.PlayerId.PlayerId_Opponent, forceforarmor_action.card_ids, forceforarmor_action.use_free_force, 0)
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
	var forceforeffect_action = ai_player.pick_force_for_effect(options)
	var success = game_wrapper.submit_force_for_effect(Enums.PlayerId.PlayerId_Opponent, forceforeffect_action.card_ids, false, false, forceforeffect_action.use_free_force)
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
	var require_specific_card_id = effect.get("require_specific_card_id", "")
	var valid_card_types = effect.get("valid_card_types", [])
	var gauge_action = ai_player.pick_gauge_for_effect(options, require_specific_card_id, valid_card_types)
	var success = game_wrapper.submit_gauge_for_effect(Enums.PlayerId.PlayerId_Opponent, gauge_action.card_ids)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI GAUGE FOR EFFECT")

func ai_strike_response(opponent_set_first_flag : bool = false):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var response_action = ai_player.pick_strike_response()
	var success = game_wrapper.submit_strike(
		Enums.PlayerId.PlayerId_Opponent,
		response_action.card_id,
		response_action.wild_swing,
		response_action.ex_card_id,
		opponent_set_first_flag
	)
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
	var discard_action = ai_player.pick_discard_to_max(event['number'])
	var success = game_wrapper.submit_discard_to_max(Enums.PlayerId.PlayerId_Opponent, discard_action.card_ids)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI DISCARD")

func ai_forced_strike(disable_wild_swing : bool = false, disable_ex : bool = false, require_ex : bool = false):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var strike_action = ai_player.pick_strike("", disable_wild_swing, disable_ex, require_ex)
	ai_handle_strike(strike_action)

func ai_strike_from_gauge(source : String):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var strike_action = ai_player.pick_strike(source)
	ai_handle_strike(strike_action)

func ai_boost_cancel_decision(gauge_cost):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var cancel_action = ai_player.pick_cancel(gauge_cost)
	var success = game_wrapper.submit_boost_cancel(Enums.PlayerId.PlayerId_Opponent, cancel_action.card_ids, cancel_action.cancel)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI BOOST CANCEL")

func ai_discard_continuous_boost(limitation, can_pass, boost_name_restriction):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var pick_action = ai_player.pick_discard_continuous(limitation, can_pass, boost_name_restriction)
	var success = game_wrapper.submit_boost_name_card_choice_effect(Enums.PlayerId.PlayerId_Opponent, pick_action.card_id)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI DISCARD CONTINUOUS")

func ai_discard_opponent_gauge():
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var opponent_chooses = game_wrapper.get_decision_info().extra_info
	var pick_action = ai_player.pick_discard_opponent_gauge(opponent_chooses)
	var success = game_wrapper.submit_boost_name_card_choice_effect(Enums.PlayerId.PlayerId_Opponent, pick_action.card_id)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI DISCARD OPPONENT GAUGE")

func ai_name_opponent_card(normal_only : bool, can_use_own_reference : bool):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var pick_action = ai_player.pick_name_opponent_card(normal_only, can_use_own_reference)
	var success = game_wrapper.submit_boost_name_card_choice_effect(Enums.PlayerId.PlayerId_Opponent, pick_action.card_id)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI NAME OPPONENT CARD")

func ai_choose_card_hand_to_gauge(min_amount, max_amount, restricted_to_card_ids):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var cardfromhandtogauge_action = ai_player.pick_card_hand_to_gauge(min_amount, max_amount, restricted_to_card_ids)
	var success = game_wrapper.submit_relocate_card_from_hand(Enums.PlayerId.PlayerId_Opponent, cardfromhandtogauge_action.card_ids)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI CHOOSE CARD HAND TO GAUGE")

func ai_choose_from_boosts(amount : int):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var choose_action = ai_player.pick_choose_from_boosts(amount)
	var success = game_wrapper.submit_choose_from_boosts(Enums.PlayerId.PlayerId_Opponent, choose_action.card_ids)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI CHOOSE FROM BOOSTS")

func ai_choose_from_discard(amount : int):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var discard_action = ai_player.pick_choose_from_discard(amount)
	var success = game_wrapper.submit_choose_from_discard(Enums.PlayerId.PlayerId_Opponent, discard_action.card_ids)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI CHOOSE FROM DISCARD")

func ai_mulligan_decision():
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var mulligan_action = ai_player.pick_mulligan()
	var success = game_wrapper.submit_mulligan(Enums.PlayerId.PlayerId_Opponent, mulligan_action.card_ids)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI MULLIGAN")
	test_init()

func ai_choose_to_discard(amount, limitation, can_pass, allow_fewer):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var discard_action = ai_player.pick_choose_to_discard(amount, limitation, can_pass, allow_fewer)
	var success = game_wrapper.submit_choose_to_discard(Enums.PlayerId.PlayerId_Opponent, discard_action.card_ids)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI CHOOSE TO DISCARD")

func ai_choose_from_topdeck(action_choices : Array, look_amount : int, can_pass : bool):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var choose_topdeck_action = ai_player.pick_choose_from_topdeck(action_choices, look_amount, can_pass)
	var success = game_wrapper.submit_choose_from_topdeck(Enums.PlayerId.PlayerId_Opponent, choose_topdeck_action.card_id, choose_topdeck_action.action)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI CHOOSE FROM TOPDECK")

func ai_choose_opponent_card_to_discard(card_ids : Array):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var discard_action = ai_player.pick_choose_opponent_card_to_discard(card_ids)
	var success = game_wrapper.submit_choose_to_discard(Enums.PlayerId.PlayerId_Opponent, discard_action.card_ids)
	if success:
		change_ui_state(UIState.UIState_WaitForGameServer)
	else:
		print("FAILED AI CHOOSE OPPONENT CARD TO DISCARD")

func ai_choose_arena_location_for_effect(location_choices : Array):
	change_ui_state(UIState.UIState_WaitForGameServer)
	if not game_wrapper.is_ai_game(): return
	var choose_location_action = ai_player.pick_choose_arena_location_for_effect(location_choices)
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
	var choose_action = ai_player.pick_number_from_range_for_effect(choices, effects)
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

func clear_choice_zone():
	while choice_zone_parent.get_child_count() > 0:
		var child = choice_zone_parent.get_child(0)
		choice_zone_parent.remove_child(child)
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

	# Handling filtering for the extra card popout; checks which cards haven't already been played
	var check_player = Enums.PlayerId.PlayerId_Unassigned
	if popout_type == CardPopoutType.CardPopoutType_BuddyPlayer:
		check_player = Enums.PlayerId.PlayerId_Player
		# This is used when showing cards that can be played as boosts
		if extra_only_show_boosts:
			cards = cards.filter(func(card): return game_wrapper.can_player_boost(Enums.PlayerId.PlayerId_Player, card.card_id, ['extra'], "", true))
	elif popout_type == CardPopoutType.CardPopoutType_BuddyOpponent:
		check_player = Enums.PlayerId.PlayerId_Opponent

	if check_player != Enums.PlayerId.PlayerId_Unassigned:
		# If this was set, then the extra card popout is being opened
		# For all buddy cards linked to a specific game card, only include them if they're still
		#  in the set-aside area
		var filtered_cards = []
		for card in cards:
			if card.card_id != CardBase.BuddyCardReferenceId:
				if not game_wrapper.is_card_set_aside(check_player, card.card_id):
					continue
			filtered_cards.append(card)
		cards = filtered_cards

	# Do any sorting of cards for specific zones.
	# Overdrive - speed only sort
	# Sealed - sort but mix ultras/specials
	match popout_type:
		CardPopoutType.CardPopoutType_OverdrivePlayer, CardPopoutType.CardPopoutType_OverdrivePlayer:
			sort_cards(cards, false, true)
		CardPopoutType.CardPopoutType_SealedPlayer, CardPopoutType.CardPopoutType_SealedOpponent:
			sort_cards(cards, true, false)

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
	var topdeck_seen_card_id = game_wrapper.get_player_seen_topdeck(Enums.PlayerId.PlayerId_Player)
	var topdeck_seen_card_name = ""
	if topdeck_seen_card_id != -1:
		topdeck_seen_card_name = game_wrapper.get_card_database().get_card_name(topdeck_seen_card_id)
	for card in $AllCards/PlayerAllCopy.get_children():
		if card.card_id < 0:
			continue
		var id = card.card_id - ReferenceScreenIdRangeStart
		var logic_card = game_wrapper.get_card_database().get_card(id)
		var card_str_id = logic_card.definition['id']
		var card_name = logic_card.definition['display_name']
		var count = game_wrapper.count_cards_in_deck_and_hand(Enums.PlayerId.PlayerId_Player, card_str_id)
		card.set_remaining_count(count)
		if topdeck_seen_card_name and topdeck_seen_card_name == card_name:
			card.update_hand_icons(0, 0, true, false)
		else:
			card.update_hand_icons(0, 0, false, false)
	var reference_title = "YOUR DECK REFERENCE (showing remaining card counts in deck+hand"
	if game_wrapper.is_player_sealed_area_secret(Enums.PlayerId.PlayerId_Player):
		reference_title += "+sealed"
	if game_wrapper.has_facedown_boosts(Enums.PlayerId.PlayerId_Player):
		reference_title += "+facedown"
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
	if game_wrapper.is_player_sealed_area_secret(Enums.PlayerId.PlayerId_Opponent):
		popout_title += "+sealed"
	if game_wrapper.has_facedown_boosts(Enums.PlayerId.PlayerId_Opponent):
		popout_title += "+facedown"
	popout_title += ")"
	show_popout(CardPopoutType.CardPopoutType_ReferenceOpponent, popout_title, $AllCards/OpponentAllCopy, false, hide_reshuffle)

func _on_player_buddy_button_pressed(only_show_boosts = false):
	var card_zone = $AllCards/PlayerBuddyCopy
	var zone_header = "YOUR EXTRA CARDS"
	if player_deck.get("buddy_link_to_zone"):
		match player_deck.get("buddy_link_to_zone"):
			"set_aside":
				card_zone = $AllCards/PlayerSetAside
				var stored_zone_info = player_deck["stored_zone_info"]
				if game_wrapper.is_player_exceeded(Enums.PlayerId.PlayerId_Player):
					stored_zone_info = player_deck["stored_zone_info_exceeded"]
				zone_header = stored_zone_info["name"]
	show_popout(CardPopoutType.CardPopoutType_BuddyPlayer, zone_header, card_zone, true, false, only_show_boosts)

func _on_opponent_buddy_button_pressed():
	var card_zone = $AllCards/OpponentBuddyCopy
	var zone_header = "THEIR EXTRA CARDS"
	if opponent_deck.get("buddy_link_to_zone"):
		match opponent_deck.get("buddy_link_to_zone"):
			"set_aside":
				card_zone = $AllCards/OpponentSetAside
				var stored_zone_info = opponent_deck["stored_zone_info"]
				if game_wrapper.is_player_exceeded(Enums.PlayerId.PlayerId_Player):
					stored_zone_info = opponent_deck["stored_zone_info_exceeded"]
				zone_header = stored_zone_info["name"]
	show_popout(CardPopoutType.CardPopoutType_BuddyOpponent, zone_header, card_zone)

func _on_exit_to_menu_pressed():
	modal_dialog.set_text_fields("Are you sure you want to quit?", "QUIT TO\nMENU", "CANCEL")
	modal_dialog_type = ModalDialogType.ModalDialogType_ExitToMenu

func _quit_to_menu():
	exiting = true
	game_wrapper.end_game()
	NetworkManager.leave_room()
	returning_from_game.emit()
	queue_free()

# Called by main.gd (guarded by has_method) to decide whether losing the server
# connection should interrupt this match. AI games and replay playback are
# driven entirely by this client, so they keep running while offline.
func match_requires_server() -> bool:
	if replay_mode:
		return false
	if game_wrapper == null or game_wrapper.current_game == null:
		return false
	return not game_wrapper.is_ai_game()

# Called by main.gd (guarded by has_method) when a reconnect fails terminally
# or the surviving player cancels the waiting-for-opponent overlay. Tears the
# match down and returns to the main menu.
func abandon_match_after_disconnect():
	if exiting:
		return
	exiting = true
	NetworkManager.set_active_remote_match_finished(true)
	game_wrapper.end_game()
	returning_from_game.emit()
	queue_free()

var resources_released : bool = false

func _exit_tree():
	_release_match_resources()

func _release_match_resources():
	# Frees per-match memory (image loader textures/HTTP) on leaving a game.
	# RESERVED HOOK (c) background system: add
	#   BackgroundManager.clear_match_texture_cache()
	# here once the background/skin workstream lands.
	# RESERVED HOOK (a) reconnect: add NetworkManager reconnect signal disconnects here.
	if resources_released:
		return
	resources_released = true
	BackgroundManager.clear_match_texture_cache()
	if image_loader:
		image_loader.teardown()
		image_loader.queue_free()
		image_loader = null

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
	var log_text = game_wrapper.get_combat_log(combat_log.get_filters(), combat_log.log_player_color, combat_log.log_opponent_color, combat_log.log_card_color)
	combat_log.set_text(log_text)
	combat_log.visible = true

func _on_combat_log_close_button_pressed():
	combat_log.visible = false

func generate_replay_string():
	var messages_list = [starting_message.duplicate()] + game_wrapper.get_message_history()
	var replay_log = {
		'messages': messages_list,
		'version': GlobalSettings.get_client_version(),
		'replay_version': GlobalSettings.ReplayVersion,
	}
	return JSON.stringify(replay_log)

func get_replay_filename():
	var filename = Time.get_datetime_string_from_system(false, true).substr(2, 14).replace(":","h")
	filename = filename + " %s (%s) vs %s (%s).txt" % [
		player_deck["id"],
		game_wrapper.get_player_name(Enums.PlayerId.PlayerId_Player),
		opponent_deck["id"],
		game_wrapper.get_player_name(Enums.PlayerId.PlayerId_Opponent)]
	return filename

func _on_save_replay_button_pressed():
	if OS.has_feature("web"):
		var replay_string = generate_replay_string()
		JavaScriptBridge.download_buffer(replay_string.to_utf8_buffer(), get_replay_filename(), "text/plain")
	else:
		file_dialog.current_file = get_replay_filename()
		file_dialog.visible = true

func _on_file_dialog_file_selected(path):
	var file_access = FileAccess.open(path, FileAccess.WRITE)
	file_access.store_string(generate_replay_string())
	file_access.close()

func _on_action_menu_choice_selected(choice_index):
	var action = current_action_menu_choices[choice_index]['action']
	action.call()

func _on_choice_popout_show_button_pressed():
	show_popout(CardPopoutType.CardPopoutType_ChoiceZone, choice_popout_title, choice_zone_parent)

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
			if replay_mode:
				observer_next_button.text = "GAME OVER"
			else:
				observer_next_button.text = "LIVE"
			observer_live = true
			observer_play_to_live_button.text = "Pause"

func _on_observer_play_to_live_pressed():
	if observer_live:
		observer_next_button.disabled = false
		observer_next_button.text = "Next Event"
		observer_live = false
		observer_play_to_live_button.text = "Go To Live"
	else:
		observer_next_button.disabled = true
		observer_next_button.text = "LIVE"
		observer_live = true
		observer_play_to_live_button.text = "Pause"

func _on_action_menu_number_picker_updated(_new_value: int) -> void:
	if can_spend_life_for_force or can_spend_life_for_gauge:
		_update_buttons(true)

func get_spent_life_for_force() -> int:
	if can_spend_life_for_force:
		return action_menu.number_panel_current_number
	else:
		return 0

func get_spent_life_for_gauge() -> int:
	if can_spend_life_for_gauge:
		return action_menu.number_panel_current_number
	else:
		return 0

func get_gauge_from_spent_life() -> int:
	if can_spend_life_for_gauge:
		var life_per_gauge = game_wrapper.get_life_for_gauge_amount(Enums.PlayerId.PlayerId_Player)
		if life_per_gauge > 0:
			return action_menu.get_current_number_picker_value() / life_per_gauge
	return 0

func _on_slideout_dialog_action_pressed(accept: bool, optional: bool) -> void:
	if accept:
		_quit_to_menu()
	else:
		slideout_dialog.visible = false
		if optional:
			ignore_queue_notifications = true
