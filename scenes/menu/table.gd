class_name Table
extends Control

signal row_button_clicked(row_index : int, button_index : int)
signal title_action_pressed

const Row = preload("res://scenes/menu/row.tscn")
@onready var title_label : Label = $Title/TitleBox/TitleLabel
@onready var title_action_button : Button = $Title/TitleBox/TitleActionButton
@onready var headers : HBoxContainer = $HeaderContainer/Headers
@onready var rows : VBoxContainer = $BodyContainer/ScrollContainer/Rows

# Called when the node enters the scene tree for the first time.
func _ready():
	title_action_button.visible = false
	if not title_action_button.pressed.is_connected(_on_title_action_button_pressed):
		title_action_button.pressed.connect(_on_title_action_button_pressed)

func set_title(title_str : String):
	title_label.text = title_str

# Shows or hides an action button (e.g. a lobby "Refresh") next to the title.
# Pass an empty string to hide it.
func set_title_action(action_text : String):
	if action_text == "":
		title_action_button.visible = false
	else:
		title_action_button.text = action_text
		title_action_button.visible = true

func _on_title_action_button_pressed():
	title_action_pressed.emit()

func set_headers(header_values : Array):
	var count = header_values.size()

	for i in range(headers.get_child_count()):
		var header = headers.get_child(i)
		if i < count and header_values[i]:
			header.visible = true
			header.text = header_values[i]
		else:
			header.visible = false

func set_rows(new_rows : Array, rows_icons : Array):
	# Delete previous rows.
	for n in rows.get_children():
		rows.remove_child(n)
		n.queue_free()

	var row_index = 0
	for row_data in new_rows:
		var new_row_node = Row.instantiate()
		var cols_in_data = row_data.size()
		var total_cols = new_row_node.get_child_count()
		var button_index = 0
		for i in range(total_cols):
			var cell = new_row_node.get_child(i)
			if i < cols_in_data and row_data[i]:
				if cell is HBoxContainer: # Indicates button column
					var button = cell.find_child("RowButton")
					if button:
						button.text = row_data[i]
						button.connect("pressed", func(): _on_row_button_clicked(row_index, button_index))
						button_index += 1
				else:
					var label = cell.find_child("RowLabel")
					var icon = cell.find_child("Icon")
					var icon_path = ""
					if rows_icons and i < rows_icons[row_index].size():
						icon_path = rows_icons[row_index][i]
					if icon_path and ResourceLoader.exists(icon_path, "Texture2D"):
						# This row has a valid icon.
						label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
						icon.visible = true
						icon.texture = load(icon_path)
					else:
						# Missing/invalid icon: clear any stale texture and hide.
						label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
						icon.visible = false
						icon.texture = null
					label.text = row_data[i]
			else:
				cell.visible = false
		row_index += 1
		rows.add_child(new_row_node)

func set_rows_buttons_enabled(rows_buttons_enabled : Array):
	for i in range(rows_buttons_enabled.size()):
		var row = rows.get_child(i)
		var buttons_enabled = rows_buttons_enabled[i]
		var button1 : Button = row.get_child(4).find_child("RowButton")
		var button2 : Button = row.get_child(5).find_child("RowButton")
		button1.disabled = not buttons_enabled.has(0)
		button2.disabled = not buttons_enabled.has(1)

func _on_row_button_clicked(row_index, button_index):
	row_button_clicked.emit(row_index, button_index)
