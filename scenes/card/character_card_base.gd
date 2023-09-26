extends Node2D

const PathPrefix = "res://assets/character_images/"

func exceed(is_exceed : bool):
	$MainPanelContainer/MainContainer/VerticalLayout/ImageMarginContainer/ImageHBox/CharacterImage.visible = not is_exceed
	$MainPanelContainer/MainContainer/VerticalLayout/ImageMarginContainer/ImageHBox/CharacterExceedImage.visible = is_exceed
	$MainPanelContainer/BackgroundContainer/ExceedBackground.visible = is_exceed
	$MainPanelContainer/MainContainer/VerticalLayout/TextMarginContainer/TextPanelBacking/TextVLayout/BufferPanelNormal.visible = not is_exceed
	$MainPanelContainer/MainContainer/VerticalLayout/TextMarginContainer/TextPanelBacking/TextVLayout/BufferPanelExceed.visible = is_exceed
	$MainPanelContainer/MainContainer/VerticalLayout/TextMarginContainer/TextPanelBacking/TextVLayout/EffectLabel.visible = not is_exceed
	$MainPanelContainer/MainContainer/VerticalLayout/TextMarginContainer/TextPanelBacking/TextVLayout/EffectLabelExceed.visible = is_exceed

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
