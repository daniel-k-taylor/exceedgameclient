extends CenterContainer

signal join_match_pressed(row_index : int)
signal observe_match_pressed(row_index : int)


const Table = preload("res://scenes/menu/table.gd")

@onready var table : Table = $PanelContainer/Margin/Table

enum ShowListState {
	ShowListState_None,
	ShowListState_Players,
	ShowListState_Matches,
}

var show_list_state : ShowListState = ShowListState.ShowListState_None

func _ready():
	NetworkManager.connect("players_update", _on_players_update)

func _on_players_update(_players, _matches, _match_available):
	if visible:
		match show_list_state:
			ShowListState.ShowListState_Players:
				update_players()
			ShowListState.ShowListState_Matches:
				update_matches()

func update_players():
	var players = NetworkManager.get_player_list()
	var rows = []
	var rows_buttons_enabled = []
	for player in players:
		var row = [player["player_name"], player["player_version"], player["room_name"]]
		rows.append(row)
		rows_buttons_enabled.append([])
	var list_data = {
		"title": "Players",
		"headers": ["Name", "Version", "Match"],
		"rows": rows,
		"rows_icons": [],
		"rows_buttons_enabled": rows_buttons_enabled,
	}
	update_table(list_data)

func update_matches():
	var matches = NetworkManager.get_match_list()
	var rows = []
	var rows_buttons_enabled = []
	var rows_icons = []
	for game_match in matches:
		var buttons_enabled = []
		var joinable_str = "<FULL>"
		var observable_str = "<NOT STARTED>"
		if game_match["joinable"]:
			joinable_str = "Join"
			buttons_enabled.append(0)
		if game_match["observable"]:
			observable_str = "Observe"
			buttons_enabled.append(1)
		var row = [game_match["host"], game_match["opponent"], game_match["version"], str(game_match["observer_count"]), joinable_str, observable_str]
		rows.append(row)
		rows_buttons_enabled.append(buttons_enabled)

		var row_icons = []
		if game_match["observable"]:
			if game_match["host_deck_icon"]:
				row_icons.append(game_match["host_deck_icon"])
			if game_match["opponent_deck_icon"]:
				row_icons.append(game_match["opponent_deck_icon"])
		rows_icons.append(row_icons)

	var list_data = {
		"title": "Matches",
		"headers": ["Host", "Opponent", "Version", "Observers", "Join", "Observe"],
		"rows": rows,
		"rows_icons": rows_icons,
		"rows_buttons_enabled": rows_buttons_enabled,
	}
	update_table(list_data)

func update_table(data : Dictionary):
	table.set_title(data['title'])
	table.set_headers(data['headers'])
	table.set_rows(data['rows'], data['rows_icons'])
	table.set_rows_buttons_enabled(data['rows_buttons_enabled'])

func show_player_list():
	show_list_state = ShowListState.ShowListState_Players
	update_players()
	visible = true

func show_match_list():
	show_list_state = ShowListState.ShowListState_Matches
	update_matches()
	visible = true

func _on_table_row_button_clicked(row_index, button_index):
	visible = false
	match show_list_state:
		ShowListState.ShowListState_Players:
			pass
		ShowListState.ShowListState_Matches:
			match button_index:
				0:
					join_match_pressed.emit(row_index)
				1:
					observe_match_pressed.emit(row_index)

func _on_close_outer_click_pressed():
	visible = false
	show_list_state = ShowListState.ShowListState_None
