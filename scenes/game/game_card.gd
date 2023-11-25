extends Node

var id
var definition
var image
var owner_id

func _init(card_id, card_def, card_image, owning_player_id):
	id = card_id
	definition = card_def
	image = card_image
	owner_id = owning_player_id