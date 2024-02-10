extends Node

const Enums = preload("res://scenes/game/enums.gd")

var player : Enums.PlayerId
var type : Enums.DecisionType
var effect_type
var effect
var choice
var choice_card_id : int
var limitation
var destination
var amount : int
var amount_min : int
var cost : int
var valid_zones : Array
var strike_after : bool
var action
var can_pass : bool
var bonus_effect
var source
var ignore_costs : bool
var extra_info

func clear():
	player = Enums.PlayerId.PlayerId_Unassigned
	type = Enums.DecisionType.DecisionType_None
	effect_type = null
	effect = null
	choice = null
	choice_card_id = -1
	limitation = null
	destination = null
	amount = -1
	amount_min = 999
	cost = -1
	valid_zones = []
	strike_after = false
	action = null
	can_pass = false
	bonus_effect = null
	source = null
	ignore_costs = false
	extra_info = null