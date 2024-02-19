extends Control

@export var flip = false

@onready var health_bar = $HealthBar
@onready var clock : Label = $Clock

func _ready():
	$Clock.visible = false
	if flip:
		$CardInfoBox.position.y = -$CardInfoBox.size.y * $CardInfoBox.scale.y - 5

func set_life(amount):
	$CardInfoBox/HPLabel.text = str(amount)
	health_bar.set_health(amount)

func set_clock(seconds : int):
	$Clock.visible = true
	var minutes = seconds / 60.0
	var seconds_display = fmod(seconds, 60)
	var mmss_string : String = "%02d:%02d" % [minutes, seconds_display]
	clock.text = mmss_string
	

func set_turn_indicator(show_indicator):
	$TurnIndicator.modulate = Color(1,1,1, 1 if show_indicator else 0)

func set_deck_size(amount):
	$CardInfoBox/DeckLabel.text = str(amount)

func set_discard_size(amount, reshuffles_remaining : int):
	$CardInfoBox/DiscardLabel.text = str(amount)
	$CardInfoBox/DiscardIcon.visible = reshuffles_remaining > 0
	$CardInfoBox/DiscardXIcon.visible = reshuffles_remaining <= 0

