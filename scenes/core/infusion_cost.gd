class_name InfusionCost

var gauge_spent : int
var life_spent : int
var free_infuse : bool

func _init(gauge_card, life_paid = 0, infused_for_free = false):
	gauge_spent = gauge_card
	life_spent = life_paid
	free_infuse = infused_for_free

func paid_from_life():
	return life_spent > 0
