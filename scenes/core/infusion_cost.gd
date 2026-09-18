class_name InfusionCost

var gauge_spent : int
var life_spent : int
var free_infuse : bool

func _init(gauge_card, life_paid = 0, infused_for_free = false):
	gauge_spent = gauge_card
	life_spent = life_paid
	free_infuse = infused_for_free

static func deserialize(json):
	return InfusionCost.new(json['gauge_spent'], json['life_spent'], json['free_infuse'])

func paid_from_life():
	return life_spent > 0

func serialize():
	return {
		"gauge_spent": gauge_spent,
		"life_spent": life_spent,
		"free_infuse": free_infuse
	}
