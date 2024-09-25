class_name BoostZone
extends Node2D

signal clicked_zone

func _on_focus_pressed():
	clicked_zone.emit()

func set_text(text):
	$OuterMargin/BoostPanel/InnerMargin/BoostVBox/BoostEffects.text = text
