extends PanelContainer


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func _set_numbers(amount_min, amount_max):
	if amount_min == amount_max:
		$StatVBox/StatNumbersHBox/MinNum.text = str(amount_min)
		$StatVBox/StatNumbersHBox/Dash.visible = false
		$StatVBox/StatNumbersHBox/MaxNum.visible = false
	else:
		$StatVBox/StatNumbersHBox/MinNum.text = str(amount_min)
		$StatVBox/StatNumbersHBox/MaxNum.text = str(amount_max)
		$StatVBox/StatNumbersHBox/Dash.visible = true
		$StatVBox/StatNumbersHBox/MaxNum.visible = true
		

func set_stats(stat_name, amount_min, amount_max, hidable=false):
	_set_numbers(amount_min, amount_max)
	$StatVBox/StatName.text = stat_name
	
	if hidable and str(amount_min) == '0' and str(amount_max) == '0':
		_set_show(false)
	else:
		_set_show(true)
	
func _set_show(set_show):
	var alpha = 1 if set_show else 0
	self.modulate = Color(1, 1, 1, alpha)
