extends Control

signal row_button_clicked(row_index : int, button_index : int)

const Row = preload("res://scenes/menu/row.tscn")
@onready var title_label : Label = $Title/TitleBox/TitleLabel
@onready var headers : HBoxContainer = $HeaderContainer/Headers
@onready var rows : VBoxContainer = $BodyContainer/ScrollContainer/Rows

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func set_title(title_str : String):
	title_label.text = title_str

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
					if rows_icons and i < rows_icons[row_index].size() and rows_icons[row_index][i]:
						# This row has an icon.
						label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
						icon.visible = true
						icon.texture = load(rows_icons[row_index][i])
					else:
						label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
						icon.visible = false
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
