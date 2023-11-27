extends Node

var id
var definition
var image
var owner_id
var set_aside
var hide_from_reference

func _init(card_id, card_def, card_image, owning_player_id):
	id = card_id
	definition = card_def
	image = card_image
	owner_id = owning_player_id
	set_aside = false
	hide_from_reference = false