extends PanelContainer

@export var label_text : String

signal gauge_clicked()

@onready var gauge_panel = $BackgroundPanel/GaugePanel

const disable_color = Color.DARK_GRAY

func _ready():
	if label_text:
		$BackgroundPanel/GaugePanel/GaugeVBox/GaugeLabel.text = label_text

func set_details(num : int):
	$BackgroundPanel/GaugePanel/GaugeVBox/GaugeAmount.text = str(num)

func get_center_pos() -> Vector2:
	return gauge_panel.global_position + gauge_panel.size/2

func _on_focus_pressed():
	gauge_clicked.emit()

func hidden_sealed():
	$BackgroundPanel/Focus.disabled = true
	$BackgroundPanel.modulate = disable_color
	$BackgroundPanel/Focus.tooltip_text = "This character seals cards face-down."
