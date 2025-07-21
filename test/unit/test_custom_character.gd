extends ExceedGutTest

func who_am_i():
	var character_identity = {
		"id": "test_custom",
		"season": 1,
		"display_name": "Custom character element tester",
		"set_starting_face_attack": true,
		"starting_face_attack_id": "standard_normal_dive",
		"exceed_cost": 2,
		"ability_effects": [],
		"exceed_ability_effects": [],
		"image_resources": {
			"character_default": {
				"url": "https://i.imgur.com/crrqVvH.jpeg",
				"multiple_cards": false
			},
			"character_exceeded": {
				"url": "https://i.imgur.com/rfrBEIx.jpeg",
				"multiple_cards": false
			},
			"cardback": {
				"url": "https://i.imgur.com/s6wpKBq.jpeg",
				"multiple_cards": false
			},
			"specials": {
				"url": "https://i.imgur.com/TTbuUIL.jpeg",
				"multiple_cards": true
			},
			"normals": {
				"url": "https://i.imgur.com/tXuqP40.jpeg",
				"multiple_cards": true
			}
		},
		"cards": [
			{
				"set_aside": true,
				"hide_from_reference": true,
				"definition_id": "standard_normal_dive",
				"image_name": "normals",
				"image_index": 3
			},
			{
				"definition_id": "standard_normal_grasp",
				"image_name": "normals",
				"image_index": 0
			},
			{
				"definition_id": "standard_normal_grasp",
				"image_name": "normals",
				"image_index": 0
			},
			{
				"definition_id": "standard_normal_cross",
				"image_name": "normals",
				"image_index": 1
			},
			{
				"definition_id": "standard_normal_cross",
				"image_name": "normals",
				"image_index": 1
			},
			{
				"definition_id": "standard_normal_assault",
				"image_name": "normals",
				"image_index": 2
			},
			{
				"definition_id": "standard_normal_assault",
				"image_name": "normals",
				"image_index": 2
			},
			{
				"definition_id": "standard_normal_dive",
				"image_name": "normals",
				"image_index": 3
			},
			{
				"definition_id": "standard_normal_dive",
				"image_name": "normals",
				"image_index": 3
			},
			{
				"definition_id": "standard_normal_spike",
				"image_name": "normals",
				"image_index": 4
			},
			{
				"definition_id": "standard_normal_spike",
				"image_name": "normals",
				"image_index": 4
			},
			{
				"definition_id": "standard_normal_sweep",
				"image_name": "normals",
				"image_index": 5
			},
			{
				"definition_id": "standard_normal_sweep",
				"image_name": "normals",
				"image_index": 5
			},
			{
				"definition_id": "standard_normal_focus",
				"image_name": "normals",
				"image_index": 6
			},
			{
				"definition_id": "standard_normal_focus",
				"image_name": "normals",
				"image_index": 6
			},
			{
				"definition_id": "standard_normal_block",
				"image_name": "normals",
				"image_index": 7
			},
			{
				"definition_id": "standard_normal_block",
				"image_name": "normals",
				"image_index": 7
			}
		]
	}
	return character_identity

##
## Tests start here
##

# Testing a character being loaded with a face-attack set.
func test_set_starting_face_attack():
	position_players(player1, 3, player2, 7)
	player1.discard_hand()
	player2.discard_hand()

	execute_strike(player1, player2, -1, "standard_normal_grasp", false, false,
		[], [], false, "", "", true, false) # Player 1 strikes with face attack

	validate_positions(player1, 6, player2, 7)
	validate_life(player1, 30, player2, 25)
