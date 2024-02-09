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

func set_rows(new_rows : Array):
	# Delete previous rows.
	for n in rows.get_children():
		rows.remove_child(n)
		n.queue_free()

	for row_data in new_rows:
		var new_row_node = Row.instantiate()
		var cols_in_data = row_data.size()
		var total_cols = new_row_node.get_child_count()
		var button_index = 0
		for i in range(total_cols):
			var cell = new_row_node.get_child(i)
			if i < cols_in_data and row_data[i]:
				if cell is HBoxContainer:
					var button = cell.find_child("RowButton")
					if button:
						button.text = row_data[i]
						button.connect("pressed", func(): _on_row_button_clicked(i, button_index))
						button_index += 1
				else:
					cell.text = row_data[i]
			else:
				cell.visible = false

		rows.add_child(new_row_node)

func _on_row_button_clicked(row_index, button_index):
	row_button_clicked.emit(row_index, button_index)
