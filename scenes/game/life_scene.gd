extends Control

@export var flip = false

@onready var health_bar = $HealthBar

func _ready():
	if flip:
		$CardInfoBox.position.y = -$CardInfoBox.size.y * $CardInfoBox.scale.y - 5

func set_life(amount):
	$CardInfoBox/HPLabel.text = str(amount)
	health_bar.set_health(amount)

func set_turn_indicator(show_indicator):
	$TurnIndicator.modulate = Color(1,1,1, 1 if show_indicator else 0)

func set_deck_size(amount):
	$CardInfoBox/DeckLabel.text = str(amount)

func set_discard_size(amount):
	$CardInfoBox/DiscardLabel.text = str(amount)
