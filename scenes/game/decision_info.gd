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
var allow_gauge : bool
var strike_after : bool
var action
var can_pass : bool
var bonus_effect
var source
