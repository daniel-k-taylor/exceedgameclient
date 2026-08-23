class_name CharSelect
extends Control

signal select_character(char_id)
signal close_character_select

@onready var hover_label : Label = $HoverBox/HBoxContainer/VBoxContainer/Label
@onready var hover_portrait : TextureRect = $HoverBox/HBoxContainer/VBoxContainer/Portrait

@onready var charselect_s1 = $CenterContainer/S1CharacterSelect
@onready var charselect_s2 = $CenterContainer/SCCharacterSelect
@onready var charselect_s3 = $CenterContainer/SFCharacterSelect
@onready var charselect_s4 = $CenterContainer/SKCharacterSelect
@onready var charselect_s5 = $CenterContainer/BBCharacterSelect
@onready var charselect_s6 = $CenterContainer/UNICharacterSelect
@onready var charselect_s7 = $CenterContainer/GGCharacterSelect

@onready var season_button_s1 = $TabSelect/CategoriesHBox/Season1
@onready var season_button_s2 = $TabSelect/CategoriesHBox/Season2
@onready var season_button_s3 = $TabSelect/CategoriesHBox/Season3
@onready var season_button_s4 = $TabSelect/CategoriesHBox/Season4
@onready var season_button_s5 = $TabSelect/CategoriesHBox/Season5
@onready var season_button_s6 = $TabSelect/CategoriesHBox/Season6
@onready var season_button_s7 = $TabSelect/CategoriesHBox/Season7

var default_char_id : String = "random"
var default_skin_index : int = 0

@onready var label_font_normal = 42
@onready var label_font_small = 32
@onready var label_length_threshold = 15

func _ready():
	show_season(charselect_s7, season_button_s7)

func update_hover(char_id, skin_index : int = 0):
	if char_id == "random_s7":
		hover_label.text = "Random (S7)"
		hover_portrait.texture = load("res://assets/portraits/random.png")
	elif char_id == "random_s6":
		hover_label.text = "Random (S6)"
		hover_portrait.texture = load("res://assets/portraits/unilogo.png")
	elif char_id == "random_s5":
		hover_label.text = "Random (S5)"
		hover_portrait.texture = load("res://assets/portraits/blazbluelogo2.png")
	elif char_id == "random_s4":
		hover_label.text = "Random (S4)"
		hover_portrait.texture = load("res://assets/portraits/sklogo.png")
	elif char_id == "random_s3":
		hover_label.text = "Random (S3)"
		hover_portrait.texture = load("res://assets/portraits/sflogo.png")
	elif char_id == "random_s2":
		hover_label.text = "Random (S2)"
		hover_portrait.texture = load("res://assets/portraits/sclogo.png")
	elif char_id == "random_s1":
		hover_label.text = "Random (S1)"
		hover_portrait.texture = load("res://assets/portraits/redhorizon.png")
	elif char_id == "random":
		hover_label.text = "Random (All)"
		hover_portrait.texture = load("res://assets/portraits/exceedrandom.png")
	elif char_id.begins_with("custom"):
		hover_label.text = "Custom"
		hover_portrait.texture = load("res://assets/portraits/exceedrandom.png")
	else:
		var deck = CardDataManager.get_deck_from_str_id(char_id)
		if deck:
			hover_label.text = deck['display_name']
			hover_portrait.texture = _load_hover_portrait(char_id, skin_index)
		else:
			hover_label.text = "Random (All)"
			hover_portrait.texture = load("res://assets/portraits/exceedrandom.png")

	if len(hover_label.text) <= label_length_threshold:
		hover_label.set("theme_override_font_sizes/font_size", label_font_normal)
	else:
		hover_label.set("theme_override_font_sizes/font_size", label_font_small)

# Loads the portrait for a character, honoring the selected skin when the skin
# manager is available. Degrades gracefully to the base character portrait when
# the manager or the skin art is absent.
func _load_hover_portrait(char_id : String, skin_index : int) -> Texture2D:
	var skin_manager = get_node_or_null("/root/CharSkinManager")
	if skin_manager:
		var skin_deck_id = skin_manager.get_skin_deck_id(char_id, skin_index)
		var texture = skin_manager.load_portrait_texture_for_deck_id(skin_deck_id)
		if texture:
			return texture
	var portrait_path = "res://assets/portraits/" + char_id + ".png"
	if ResourceLoader.exists(portrait_path, "Texture2D"):
		return load(portrait_path)
	return load("res://assets/portraits/exceedrandom.png")

func show_char_select(char_id : String, skin_index : int = 0):
	default_char_id = char_id
	var skin_manager = get_node_or_null("/root/CharSkinManager")
	if skin_manager and not skin_manager.is_skin_selection_enabled():
		skin_index = 0
	default_skin_index = skin_index
	update_hover(char_id, skin_index)

func _on_background_button_pressed():
	close_character_select.emit()

func show_season(node, selector_button):
	charselect_s1.visible = false
	charselect_s2.visible = false
	charselect_s3.visible = false
	charselect_s4.visible = false
	charselect_s5.visible = false
	charselect_s6.visible = false
	charselect_s7.visible = false
	node.visible = true

	season_button_s1.set_selected(false)
	season_button_s2.set_selected(false)
	season_button_s3.set_selected(false)
	season_button_s4.set_selected(false)
	season_button_s5.set_selected(false)
	season_button_s6.set_selected(false)
	season_button_s7.set_selected(false)
	selector_button.set_selected(true)

func _on_char_button_on_pressed(character_id : String):
	if character_id.begins_with("season"):
		# Get the int season from the last character of the str.
		match character_id:
			"season1":
				show_season(charselect_s1, season_button_s1)
			"season2":
				show_season(charselect_s2, season_button_s2)
			"season3":
				show_season(charselect_s3, season_button_s3)
			"season4":
				show_season(charselect_s4, season_button_s4)
			"season5":
				show_season(charselect_s5, season_button_s5)
			"season6":
				show_season(charselect_s6, season_button_s6)
			"season7":
				show_season(charselect_s7, season_button_s7)
	else:
		select_character.emit(character_id)

func _on_char_hover(char_id : String, enter : bool):
	if char_id.begins_with("season"):
		return

	if enter:
		update_hover(char_id)
	else:
		update_hover(default_char_id, default_skin_index)
