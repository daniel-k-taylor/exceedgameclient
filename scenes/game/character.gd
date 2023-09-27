extends AnimatedSprite2D


# Called when the node enters the scene tree for the first time.
func _ready():
	play("idle")

func set_facing(to_left):
	flip_h = to_left
