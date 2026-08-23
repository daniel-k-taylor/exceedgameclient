class_name MatchQueueItem
extends MarginContainer

# Throttle for the "a match is available" notification so joining/leaving a
# queue repeatedly does not spam the alert. Static so it is shared across all
# queue items.
const QUEUE_NOTIFY_COOLDOWN_SECONDS := 120
static var _last_queue_notify_unix_time : int = -999999

signal on_join_queue(id)

@onready var queue_label = $QueueVBox/QueueLabel
@onready var join_button = $QueueVBox/JoinButton
@onready var play_button = $QueueVBox/PlayContainer/PlayButton
@onready var play_container = $QueueVBox/PlayContainer
@onready var waiting_character_label = $QueueVBox/WaitingCharacterLabel

var	queue_id : String
var _queue_name : String

# Resolves the display name of the character currently waiting in a queue using
# our own deck definitions (English display names only).
static func get_waiting_character_display(queue_info : Dictionary) -> String:
	return _resolve_waiting_character_name(_get_waiting_character_value(queue_info))

func initialize_queue(id : String, queue_name : String, match_available : bool, waiting_character = null):
	queue_id = id
	_queue_name = queue_name
	queue_label.text = queue_name
	_set_waiting_character(waiting_character)

	set_match_available(match_available)

func set_enabled(enable : bool):
	join_button.disabled = not enable
	play_button.disabled = not enable

func get_match_available() -> bool:
	return play_button.visible

func set_match_available(match_available : bool):
	join_button.visible = not match_available
	play_button.visible = match_available
	play_container.visible = match_available
	waiting_character_label.visible = match_available and waiting_character_label.text != ""

func _set_waiting_character(waiting_character) -> void:
	var display_name = _resolve_waiting_character_name(waiting_character)
	if display_name == "":
		waiting_character_label.text = ""
	else:
		waiting_character_label.text = "Waiting: %s" % display_name

static func _get_waiting_character_value(queue_info : Dictionary):
	for key in ["waiting_character", "waiting_deck", "waiting_deck_id"]:
		if not queue_info.has(key):
			continue
		var value = queue_info[key]
		if value == null:
			continue
		if str(value).strip_edges() != "":
			return value
	return null

static func _resolve_waiting_character_name(waiting_character) -> String:
	if waiting_character == null:
		return ""

	var raw_name = str(waiting_character).strip_edges()
	if raw_name == "":
		return ""

	# Deck ids may arrive as "random_s3#ryu"; the part after '#' is the actual
	# picked deck. A bare "random_s3" (unresolved random) has no character yet.
	var normalized_deck_id = raw_name
	var split_index = normalized_deck_id.find("#")
	if split_index != -1:
		normalized_deck_id = normalized_deck_id.substr(split_index + 1)
	elif normalized_deck_id.begins_with("random"):
		return "Random"

	if CardDataManager.decks.has(normalized_deck_id):
		var deck = CardDataManager.get_deck(normalized_deck_id)
		if deck:
			return deck.get("display_name", raw_name)

	return raw_name

# Returns true (and starts the cooldown) when a match-available notification is
# allowed. Callers gate their alert sound/message on this.
static func can_send_queue_notification() -> bool:
	var now_unix = int(Time.get_unix_time_from_system())
	if now_unix - _last_queue_notify_unix_time < QUEUE_NOTIFY_COOLDOWN_SECONDS:
		return false
	_last_queue_notify_unix_time = now_unix
	return true

func _on_join_button_pressed() -> void:
	on_join_queue.emit(queue_id)

func _on_play_button_pressed() -> void:
	on_join_queue.emit(queue_id)
