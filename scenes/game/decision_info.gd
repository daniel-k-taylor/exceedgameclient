extends Node

const Enums = preload("res://scenes/game/enums.gd")

var player : Enums.PlayerId
var type : Enums.DecisionType
var effect_type
var choice
var choice_card_id : int