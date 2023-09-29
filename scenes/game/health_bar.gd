extends Node2D

const MaxHealth = 30
@onready var health = MaxHealth

@onready var health_bar = $BackgroundPanel/Margin/HealthProgressBar

# Called when the node enters the scene tree for the first time.
func _ready():
	set_health(health)
	
func set_health(num):
	health_bar.value = num

