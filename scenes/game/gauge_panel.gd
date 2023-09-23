extends Node2D

signal gauge_clicked()

func set_details(num : int):
	$GaugePanel/GaugeVBox/GaugeAmount.text = str(num)

func get_center_pos() -> Vector2:
	return $GaugePanel.global_position + $GaugePanel.size/2

func _on_focus_pressed():
	gauge_clicked.emit()
