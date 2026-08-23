extends GutTest

const TableScene = preload("res://scenes/menu/table.tscn")

func test_missing_row_icon_is_hidden_without_loading_error():
	var table : Table = TableScene.instantiate()
	add_child_autofree(table)
	await get_tree().process_frame

	table.set_rows(
		[["Player", "Opponent", "Version", "0", "Join", "Observe"]],
		[["res://assets/portraits/does_not_exist.png"]],
	)

	var icon : TextureRect = table.rows.get_child(0).get_child(0).find_child("Icon")
	assert_false(icon.visible)
	assert_null(icon.texture)


func test_title_action_button_visibility_and_signal():
	var table : Table = TableScene.instantiate()
	add_child_autofree(table)
	await get_tree().process_frame

	assert_false(table.title_action_button.visible)

	table.set_title_action("Refresh")
	assert_true(table.title_action_button.visible)
	assert_eq(table.title_action_button.text, "Refresh")

	watch_signals(table)
	table.title_action_button.pressed.emit()
	assert_signal_emitted(table, "title_action_pressed")

	table.set_title_action("")
	assert_false(table.title_action_button.visible)
