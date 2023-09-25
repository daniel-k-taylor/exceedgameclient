extends Node2D

signal clicked_zone

func _on_focus_pressed():
	clicked_zone.emit()
