extends Node2D

signal pressed

@onready var fancy_card = $MainPanelContainer/FancyCard
@onready var fancy_exceed_card = $MainPanelContainer/FancyExceedCard
@onready var main_container = $MainPanelContainer/MainContainer
@onready var exceed_cost_panel = $ExceedCostPanel
@onready var extra_cards = $ExtraCards

enum CardState {
	CardState_Unfocused,
	CardState_Focusing,
	CardState_Unfocusing,
}

var card_state : CardState = CardState.CardState_Unfocused
var unfocused_pos
var unfocused_scale
@export var anchor_top : bool = true
var focus_scale

const FOCUS_SCALE_FACTOR = 4

var start_pos
var target_pos
var start_scale
var target_scale
var animation_time = 2
var animation_length

var extra_cards_to_show_on_focus = 0

const FOCUS_ANIMATION_LENGTH = 0.2

func _ready():
	unfocused_pos = position
	unfocused_scale = scale
	target_pos = position
	target_scale = scale
	focus_scale = scale * FOCUS_SCALE_FACTOR

func hide_focus():
	$MainPanelContainer/Focus.texture_pressed = null
	$MainPanelContainer/Focus.texture_hover = null
	$MainPanelContainer/Focus.tooltip_text = ""

func exceed(is_exceed : bool):
	#$MainPanelContainer/MainContainer/VerticalLayout/ImageMarginContainer/ImageHBox/CharacterImage.visible = not is_exceed
	#$MainPanelContainer/MainContainer/VerticalLayout/ImageMarginContainer/ImageHBox/CharacterExceedImage.visible = is_exceed
	#$MainPanelContainer/BackgroundContainer/ExceedBackground.visible = is_exceed
	#$MainPanelContainer/MainContainer/VerticalLayout/TextMarginContainer/TextPanelBacking/TextVLayout/BufferPanelNormal.visible = not is_exceed
	#$MainPanelContainer/MainContainer/VerticalLayout/TextMarginContainer/TextPanelBacking/TextVLayout/BufferPanelExceed.visible = is_exceed
	#$MainPanelContainer/MainContainer/VerticalLayout/TextMarginContainer/TextPanelBacking/TextVLayout/EffectLabel.visible = not is_exceed
	#$MainPanelContainer/MainContainer/VerticalLayout/TextMarginContainer/TextPanelBacking/TextVLayout/EffectLabelExceed.visible = is_exceed
	#exceed_cost_panel.visible = not is_exceed
	fancy_card.visible = not is_exceed
	fancy_exceed_card.visible = is_exceed

func set_image(image_path, exceed_image_path):
	#$MainPanelContainer/MainContainer/VerticalLayout/ImageMarginContainer/ImageHBox/CharacterImage.texture = load(image_path)
	#$MainPanelContainer/MainContainer/VerticalLayout/ImageMarginContainer/ImageHBox/CharacterExceedImage.texture = load(exceed_image_path)
	fancy_card.texture = load(image_path)
	fancy_exceed_card.texture = load(exceed_image_path)
	main_container.visible = false
	fancy_card.visible = true
	fancy_exceed_card.visible = false
	exceed_cost_panel.visible = false

func set_extra_image(index, image_path, exceed_image_path):
	extra_cards_to_show_on_focus = max(extra_cards_to_show_on_focus, index)
	var child = extra_cards.get_child(index)
	child.texture = load(image_path)
	child.texture = load(exceed_image_path)

	focus_scale = unfocused_scale * FOCUS_SCALE_FACTOR * 0.8

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

func clamp_to_screen(pos : Vector2, size: Vector2) -> Vector2:
	var screen_size = get_viewport().content_scale_size
	var new_pos = pos
	if new_pos.x < 0:
		new_pos.x = 0
	if new_pos.x + size.x > screen_size.x:
		new_pos.x = screen_size.x - size.x
	if new_pos.y < 0:
		new_pos.y = 0
	if new_pos.y + size.y > screen_size.y:
		new_pos.y = screen_size.y - size.y
	return new_pos

func focus():

	start_pos = position
	start_scale = scale
	target_scale = focus_scale
	var size_at_scale = $MainPanelContainer.size * focus_scale
	target_pos = unfocused_pos
	if extra_cards_to_show_on_focus:
		target_pos.x -= 150

	target_pos = clamp_to_screen(target_pos, size_at_scale)

	animation_time = 0
	animation_length = FOCUS_ANIMATION_LENGTH

	z_index = 10

	if extra_cards_to_show_on_focus:
		for i in range(1, extra_cards_to_show_on_focus + 1):
			var child = extra_cards.get_child(i)
			child.visible = true

func unfocus():
	start_pos = position
	start_scale = scale

	target_pos = unfocused_pos
	target_scale = unfocused_scale

	animation_time = 0
	animation_length = FOCUS_ANIMATION_LENGTH

	z_index = 0

	if extra_cards_to_show_on_focus:
		for i in range(1, extra_cards_to_show_on_focus + 1):
			var child = extra_cards.get_child(i)
			child.visible = false

func _on_focus_mouse_entered():
	focus()


func _on_focus_mouse_exited():
	unfocus()


func _on_focus_pressed():
	pressed.emit()
