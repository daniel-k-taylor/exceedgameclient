class_name GameCard
extends Node

var id
var definition
var owner_id
var set_aside
var hide_from_reference
var reference_only
var image_atlas = {}
var image_index = 0

func _init(card_id, card_def, owning_player_id, card_image_atlas = {}, card_image_index = 0):
	id = card_id
	definition = card_def.duplicate(true)
	owner_id = owning_player_id
	set_aside = false
	hide_from_reference = false
	reference_only = false

	image_atlas = card_image_atlas
	image_index = card_image_index

func _to_string():
	return '%s (%s)' % [definition.id, id]

func get_image_url_index_data():
	if image_atlas:
		return {
			"url": image_atlas["url"],
			"index": image_index
		}
	return {}
