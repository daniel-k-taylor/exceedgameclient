extends Node2D
var game : Node2D

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_main_menu_start_game():
	$MainMenu.queue_free()
	game = load("res://scenes/game/game.tscn").instantiate()
	add_child(game)
