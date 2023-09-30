extends Node2D

const PathPrefix = "res://assets/character_images/"

enum CardState {
	CardState_Unfocused,
	CardState_Focusing,
	CardState_Unfocusing,
}

var card_state : CardState = CardState.CardState_Unfocused
var unfocused_pos
var unfocused_scale
@export var anchor_top : bool = true
var focus_scale = Vector2(1.2, 1.2)

var start_pos
var target_pos
var start_scale
var target_scale
var animation_time = 2
var animation_length

const FOCUS_ANIMATION_LENGTH = 0.2

func _ready():
	unfocused_pos = position
	unfocused_scale = scale
	target_pos = position
	target_scale = scale

func exceed(is_exceed : bool):
	$MainPanelContainer/MainContainer/VerticalLayout/ImageMarginContainer/ImageHBox/CharacterImage.visible = not is_exceed
	$MainPanelContainer/MainContainer/VerticalLayout/ImageMarginContainer/ImageHBox/CharacterExceedImage.visible = is_exceed
	$MainPanelContainer/BackgroundContainer/ExceedBackground.visible = is_exceed
	$MainPanelContainer/MainContainer/VerticalLayout/TextMarginContainer/TextPanelBacking/TextVLayout/BufferPanelNormal.visible = not is_exceed
	$MainPanelContainer/MainContainer/VerticalLayout/TextMarginContainer/TextPanelBacking/TextVLayout/BufferPanelExceed.visible = is_exceed
	$MainPanelContainer/MainContainer/VerticalLayout/TextMarginContainer/TextPanelBacking/TextVLayout/EffectLabel.visible = not is_exceed
	$MainPanelContainer/MainContainer/VerticalLayout/TextMarginContainer/TextPanelBacking/TextVLayout/EffectLabelExceed.visible = is_exceed
	$ExceedCostPanel.visible = not is_exceed

func set_image(image_name, exceed_image_name):
	var image_path = PathPrefix + image_name
	var exceed_image_path = PathPrefix + exceed_image_name
	$MainPanelContainer/MainContainer/VerticalLayout/ImageMarginContainer/ImageHBox/CharacterImage.texture = load(image_path)
	$MainPanelContainer/MainContainer/VerticalLayout/ImageMarginContainer/ImageHBox/CharacterExceedImage.texture = load(exceed_image_path)
	
func set_name_text(name_text):
	$MainPanelContainer/MainContainer/VerticalLayout/TextMarginContainer/TextPanelBacking/TextVLayout/CharacterNameLabel.text = name_text

func set_cost(cost):
	$ExceedCostPanel/CostMargin/ExceedCostLabel.text = str(cost)

func set_effect(effect_text, exceed_effect_text):
	var effect_str = "[center]%s[/center]" % effect_text
	var exceed_str = "[center]%s[/center]" % exceed_effect_text
	$MainPanelContainer/MainContainer/VerticalLayout/TextMarginContainer/TextPanelBacking/TextVLayout/EffectLabel.text = effect_str
	$MainPanelContainer/MainContainer/VerticalLayout/TextMarginContainer/TextPanelBacking/TextVLayout/EffectLabelExceed.text = exceed_str

func _physics_process(delta):
	if animation_time <= 1:
		position = start_pos.lerp(target_pos, animation_time)
		scale = start_scale.lerp(target_scale, animation_time)
		animation_time += delta / animation_length
	else:
		position = target_pos
		scale = target_scale

func focus():

	start_pos = position
	start_scale = scale
	target_pos = unfocused_pos - $MainPanelContainer.size * target_scale
	if anchor_top:
		target_pos.y += $MainPanelContainer.size.y * target_scale.y
	else:
		target_pos.y -= $MainPanelContainer.size.y * target_scale.y
	
	target_scale = focus_scale
	animation_time = 0
	animation_length = FOCUS_ANIMATION_LENGTH

	z_index = 10

func unfocus():
	start_pos = position
	start_scale = scale
	
	target_pos = unfocused_pos
	target_scale = unfocused_scale

	animation_time = 0
	animation_length = FOCUS_ANIMATION_LENGTH

	z_index = 0

func _on_focus_mouse_entered():
	focus()


func _on_focus_mouse_exited():
	unfocus()
