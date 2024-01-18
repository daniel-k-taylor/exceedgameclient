extends CenterContainer

@onready var empty_square : TextureRect = $Normal
@onready var self_square : TextureRect = $Friend
@onready var enemy_square : TextureRect = $Enemy

func set_empty():
	empty_square.visible = true
	self_square.visible = false
	enemy_square.visible = false
	
func set_self_occupied():
	empty_square.visible = false
	self_square.visible = true
	enemy_square.visible = false
	
func set_enemy_occupied():
	empty_square.visible = false
	self_square.visible = false
	enemy_square.visible = true
