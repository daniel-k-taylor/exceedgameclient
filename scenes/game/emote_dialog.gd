extends CenterContainer

signal emote_selected(is_image_emote : bool, emote : String)
signal close_button_pressed

@onready var toggle_mute_button : Button = $PanelContainer/OuterMargin/VerticalLayout/HeaderButtons/ToggleMuteButton
@onready var image_buttons = $PanelContainer/OuterMargin/VerticalLayout/ImageButtons
@onready var text_buttons = $PanelContainer/OuterMargin/VerticalLayout/TextButtons

const EmoteIconScene = preload("res://scenes/game/emote_icon.tscn")
const EmoteIcon = preload("res://scenes/game/emote_icon.gd")
const emotes_path = "res://assets/icons/emotes"

const emote_text_strings = [
	"Good Luck, Have Fun!",
	"Nice!",
	"OH NO!",
	"Good Game",
]

func _ready():
	_update_mute_button_text()
	_load_emotes()

func _load_emotes():
	var emote_files = DirAccess.get_files_at(emotes_path)
	for emote_file in emote_files:
		if emote_file[0] == "_" or not emote_file.ends_with(".import"):
			continue
		emote_file = emote_file.replace(".import", "")
		var emote_path = emotes_path + "/" + emote_file
		var new_icon : EmoteIcon = EmoteIconScene.instantiate()
		var success = new_icon.set_image(emote_path)
		if success:
			image_buttons.add_child(new_icon)
			new_icon.pressed.connect(_on_emote_pressed)

	for emote_text in emote_text_strings:
		var new_text_button = Button.new()
		text_buttons.add_child(new_text_button)
		new_text_button.text = emote_text
		new_text_button.pressed.connect(func(): _on_text_emote_pressed(emote_text))

func _update_mute_button_text():
	if GlobalSettings.MuteEmotes:
		toggle_mute_button.text = "UNMUTE"
	else:
		toggle_mute_button.text = "MUTE"

func _on_close_button_pressed():
	close_button_pressed.emit()

func _on_toggle_mute_button_pressed():
	GlobalSettings.MuteEmotes = not GlobalSettings.MuteEmotes
	_update_mute_button_text()

func _on_emote_pressed(emote_path : String):
	emote_selected.emit(true, emote_path)

func _on_text_emote_pressed(text_str : String):
	emote_selected.emit(false, text_str)
