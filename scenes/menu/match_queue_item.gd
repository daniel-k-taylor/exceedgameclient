class_name MatchQueueItem
extends MarginContainer

signal on_join_queue(id)

@onready var queue_label = $QueueVBox/QueueLabel
@onready var join_button = $QueueVBox/JoinButton
@onready var play_button = $QueueVBox/PlayContainer/PlayButton
@onready var play_container = $QueueVBox/PlayContainer

var	queue_id : String
var _queue_name : String

func initialize_queue(id : String, queue_name : String, match_available : bool):
	queue_id = id
	_queue_name = queue_name
	queue_label.text = queue_name
	
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

func _on_join_button_pressed() -> void:
	on_join_queue.emit(queue_id)

func _on_play_button_pressed() -> void:
	on_join_queue.emit(queue_id)
