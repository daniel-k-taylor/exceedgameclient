extends Control


func set_life(amount):
	$LifeHBox/Amount.text = str(amount)

func set_turn_indicator(show):
	$LifeHBox/TurnIndicator.modulate = Color(1,1,1, 1 if show else 0)
