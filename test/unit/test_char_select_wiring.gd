extends GutTest

# Every character button in char_select.tscn must have both of its signals wired
# to the CharSelect script. These connections live only in the .tscn, so adding a
# character node without the matching [connection] entries produces a button that
# silently does nothing: hovering leaves the preview on the previously selected
# character and clicking never selects anyone.

var char_select : CharSelect

func before_each():
	char_select = load("res://scenes/menu/char_select.tscn").instantiate()
	add_child_autofree(char_select)

func _all_char_buttons() -> Array:
	var found = []
	_collect_char_buttons(char_select, found)
	return found

func _collect_char_buttons(node : Node, out : Array) -> void:
	if node is CharSelectButton:
		out.append(node)
	for child in node.get_children():
		_collect_char_buttons(child, out)

func _button_for(char_id : String) -> CharSelectButton:
	for button in _all_char_buttons():
		if button.char_id == char_id:
			return button
	return null

func test_every_char_button_is_connected():
	var buttons = _all_char_buttons()
	assert_gt(buttons.size(), 100, "expected the full roster of character buttons")

	var unwired_hover = []
	var unwired_pressed = []
	for button in buttons:
		if not button.on_hover.is_connected(char_select._on_char_hover):
			unwired_hover.append("%s (%s)" % [button.name, button.char_id])
		if not button.on_pressed.is_connected(char_select._on_char_button_on_pressed):
			unwired_pressed.append("%s (%s)" % [button.name, button.char_id])

	assert_eq(unwired_hover, [], "buttons missing an on_hover connection")
	assert_eq(unwired_pressed, [], "buttons missing an on_pressed connection")

func test_every_char_button_has_a_unique_id():
	var seen = {}
	var duplicates = []
	for button in _all_char_buttons():
		assert_ne(button.char_id, "", "%s has no char_id" % button.name)
		if button.char_id in seen:
			duplicates.append(button.char_id)
		seen[button.char_id] = true
	assert_eq(duplicates, [], "char_ids appear on more than one button")

func test_every_non_random_button_maps_to_a_real_deck():
	var unknown = []
	for button in _all_char_buttons():
		var char_id = button.char_id
		if char_id.begins_with("random") or char_id.begins_with("custom") or char_id.begins_with("season"):
			continue
		if not CardDataManager.get_deck_from_str_id(char_id):
			unknown.append(char_id)
	assert_eq(unknown, [], "buttons pointing at decks that do not exist")

func test_ported_characters_are_present_and_selectable():
	var ported = ["meilien", "ulrik", "luciya", "minato", "pooky", "renea",
		"syrus", "tournelouse", "umina", "shovelknight"]

	var selected = []
	char_select.select_character.connect(func(id): selected.append(id))
	char_select.show_char_select("solbadguy")

	for char_id in ported:
		var button = _button_for(char_id)
		assert_not_null(button, "no character button for %s" % char_id)
		if button == null:
			continue

		var deck = CardDataManager.get_deck_from_str_id(char_id)
		assert_not_null(deck, "no deck for %s" % char_id)
		if deck == null:
			continue

		# Hovering shows that character rather than the current selection.
		button.on_hover.emit(char_id, true)
		assert_eq(char_select.hover_label.text, deck['display_name'],
			"hovering %s should show its own name" % char_id)
		assert_not_null(char_select.hover_portrait.texture, "%s has no hover portrait" % char_id)
		if char_select.hover_portrait.texture != null:
			assert_true(char_select.hover_portrait.texture.resource_path.ends_with("/%s.png" % char_id),
				"%s hovered with portrait %s" % [char_id, char_select.hover_portrait.texture.resource_path])

		# Unhovering falls back to the currently selected character.
		button.on_hover.emit(char_id, false)
		assert_eq(char_select.hover_label.text, "Sol Badguy",
			"unhovering %s should restore the selected character" % char_id)

		# Clicking actually selects the character.
		selected.clear()
		button.on_pressed.emit(char_id)
		assert_eq(selected, [char_id], "clicking %s should select it" % char_id)

func test_season_buttons_switch_tabs():
	var season_tabs = {
		"season1": "charselect_s1",
		"season2": "charselect_s2",
		"season7": "charselect_s7",
	}
	for season_id in season_tabs:
		var button = _button_for(season_id)
		assert_not_null(button, "no tab button for %s" % season_id)
		if button == null:
			continue
		button.on_pressed.emit(season_id)
		assert_true(char_select.get(season_tabs[season_id]).visible,
			"%s should reveal its character grid" % season_id)
