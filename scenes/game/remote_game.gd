extends Node

const LocalGame = preload("res://scenes/game/local_game.gd")
const Enums = preload("res://scenes/game/enums.gd")
const CardDatabase = preload("res://scenes/game/card_database.gd")
const DecisionInfo = preload("res://scenes/game/decision_info.gd")


var local_game : LocalGame

var _player_info
var _opponent_info

func get_latest_events() -> Array:
	return local_game.get_latest_events()

func _get_player(id):
	return local_game._get_player(id)

func _get_player_remote_id(player : LocalGame.Player) -> int:
	if player.my_id == Enums.PlayerId.PlayerId_Player:
		return _player_info['id']
	else:
		return _opponent_info['id']

func _get_player_from_remote_id(remote_id : int):
	if remote_id == _player_info['id']:
		return _get_player(Enums.PlayerId.PlayerId_Player)
	else:
		return _get_player(Enums.PlayerId.PlayerId_Opponent)

func initialize_game(player_info, opponent_info, starting_player : Enums.PlayerId, seed_value : int):

	NetworkManager.connect("game_message_received", _on_remote_game_message)
	NetworkManager.connect("other_player_quit", _on_remote_player_quit)

	_player_info = player_info
	_opponent_info = opponent_info
	local_game = LocalGame.new()
	local_game.initialize_game(player_info['deck'], opponent_info['deck'], player_info['name'], opponent_info['name'], starting_player, seed_value)
	local_game.draw_starting_hands_and_begin()

func _on_remote_game_message(game_message):
	var action_type = game_message['action_type']
	var action_function_name = action_type.replace("action_", "process_")
	var action_function = Callable(self, action_function_name)
	action_function.call(game_message)

func _on_remote_player_quit(_is_disconnect : bool):
	var reason = Enums.GameOverReason.GameOverReason_Quit
	if _is_disconnect:
		reason = Enums.GameOverReason.GameOverReason_Disconnect
	local_game.do_quit(Enums.PlayerId.PlayerId_Opponent, reason)

func get_game_state() -> Enums.GameState:
	return local_game.get_game_state()

func get_active_player() -> Enums.PlayerId:
	return local_game.get_active_player()

func get_decision_info() -> DecisionInfo:
	return local_game.get_decision_info()

func get_card_database() -> CardDatabase:
	return local_game.get_card_database()

func can_do_prepare(player : LocalGame.Player) -> bool:
	return local_game.can_do_prepare(player)

func can_do_move(player : LocalGame.Player) -> bool:
	return local_game.can_do_move(player)

func can_do_change(player : LocalGame.Player) -> bool:
	return local_game.can_do_change(player)

func can_do_exceed(player : LocalGame.Player) -> bool:
	return local_game.can_do_exceed(player)

func can_do_reshuffle(player : LocalGame.Player) -> bool:
	return local_game.can_do_reshuffle(player)

func can_do_boost(player : LocalGame.Player) -> bool:
	return local_game.can_do_boost(player)

func can_do_strike(player : LocalGame.Player) -> bool:
	return local_game.can_do_strike(player)

func can_move_to(player : LocalGame.Player, location : int) -> bool:
	return player.can_move_to(location)

### Action Functions ###

func do_prepare(player : LocalGame.Player) -> bool:
	var action_message = {
		'action_type': 'action_prepare',
		'player_id': _get_player_remote_id(player),
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_prepare(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	local_game.do_prepare(game_player)

func do_reshuffle(player : LocalGame.Player) -> bool:
	var action_message = {
		'action_type': 'action_reshuffle',
		'player_id': _get_player_remote_id(player),
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_reshuffle(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	return local_game.do_reshuffle(game_player)

func do_choice(player : LocalGame.Player, choice_index : int) -> bool:
	var action_message = {
		'action_type': 'action_choice',
		'player_id': _get_player_remote_id(player),
		'choice_index': choice_index,
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_choice(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var choice_index = action_message['choice_index']
	return local_game.do_choice(game_player, choice_index)

func do_boost_cancel(player : LocalGame.Player, gauge_card_ids : Array, doing_cancel : bool) -> bool:
	var action_message = {
		'action_type': 'action_boost_cancel',
		'player_id': _get_player_remote_id(player),
		'gauge_card_ids': gauge_card_ids,
		'doing_cancel': doing_cancel,
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_boost_cancel(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var gauge_card_ids = action_message['gauge_card_ids']
	var doing_cancel = action_message['doing_cancel']
	return local_game.do_boost_cancel(game_player, gauge_card_ids, doing_cancel)

func do_boost_name_card_choice_effect(player : LocalGame.Player, card_id : int) -> bool:
	var action_message = {
		'action_type': 'action_boost_name_card_choice_effect',
		'player_id': _get_player_remote_id(player),
		'card_id': card_id,
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_boost_name_card_choice_effect(action_message) -> bool:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var card_id = action_message['card_id']
	return local_game.do_boost_name_card_choice_effect(game_player, card_id)

func do_discard_to_max(player : LocalGame.Player, card_ids : Array) -> bool:
	var action_message = {
		'action_type': 'action_discard_to_max',
		'player_id': _get_player_remote_id(player),
		'card_ids': card_ids,
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_discard_to_max(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var card_ids = action_message['card_ids']
	return local_game.do_discard_to_max(game_player, card_ids)

func do_card_from_hand_to_gauge(player : LocalGame.Player, card_id : int) -> bool:
	var action_message = {
		'action_type': 'action_card_from_hand_to_gauge',
		'player_id': _get_player_remote_id(player),
		'card_id': card_id,
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_card_from_hand_to_gauge(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var card_id = action_message['card_id']
	return local_game.do_card_from_hand_to_gauge(game_player, card_id)

func do_pay_strike_cost(player : LocalGame.Player, card_ids : Array, wild_strike : bool) -> bool:
	var action_message = {
		'action_type': 'action_pay_strike_cost',
		'player_id': _get_player_remote_id(player),
		'card_ids': card_ids,
		'wild_strike': wild_strike,
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_pay_strike_cost(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var card_ids = action_message['card_ids']
	var wild_strike = action_message['wild_strike']
	return local_game.do_pay_strike_cost(game_player, card_ids, wild_strike)

func do_exceed(player : LocalGame.Player, card_ids : Array) -> bool:
	var action_message = {
		'action_type': 'action_exceed',
		'player_id': _get_player_remote_id(player),
		'card_ids': card_ids,
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_exceed(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var card_ids = action_message['card_ids']
	return local_game.do_exceed(game_player, card_ids)

func do_move(player : LocalGame.Player, card_ids : Array, new_arena_location : int) -> bool:
	var action_message = {
		'action_type': 'action_move',
		'player_id': _get_player_remote_id(player),
		'card_ids': card_ids,
		'new_arena_location': new_arena_location,
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_move(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var card_ids = action_message['card_ids']
	var new_arena_location = action_message['new_arena_location']
	return local_game.do_move(game_player, card_ids, new_arena_location)

func do_change(player : LocalGame.Player, card_ids : Array) -> bool:
	var action_message = {
		'action_type': 'action_change',
		'player_id': _get_player_remote_id(player),
		'card_ids': card_ids,
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_change(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var card_ids = action_message['card_ids']
	return local_game.do_change(game_player, card_ids)

func do_strike(player : LocalGame.Player, card_id : int, wild_strike: bool, ex_card_id : int) -> bool:
	var action_message = {
		'action_type': 'action_strike',
		'player_id': _get_player_remote_id(player),
		'card_id': card_id,
		'wild_strike': wild_strike,
		'ex_card_id': ex_card_id,
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_strike(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var card_id = action_message['card_id']
	var wild_strike = action_message['wild_strike']
	var ex_card_id = action_message['ex_card_id']
	return local_game.do_strike(game_player, card_id, wild_strike, ex_card_id)

func do_force_for_armor(player : LocalGame.Player, card_ids : Array) -> bool:
	var action_message = {
		'action_type': 'action_force_for_armor',
		'player_id': _get_player_remote_id(player),
		'card_ids': card_ids,
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_force_for_armor(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var card_ids = action_message['card_ids']
	return local_game.do_force_for_armor(game_player, card_ids)

func do_mulligan(player : LocalGame.Player, card_ids : Array) -> bool:
	var action_message = {
		'action_type': 'action_mulligan',
		'player_id': _get_player_remote_id(player),
		'card_ids': card_ids,
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_mulligan(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var card_ids = action_message['card_ids']
	return local_game.do_mulligan(game_player, card_ids)

func do_boost(player : LocalGame.Player, card_id : int) -> bool:
	var action_message = {
		'action_type': 'action_boost',
		'player_id': _get_player_remote_id(player),
		'card_id': card_id,
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_boost(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var card_id = action_message['card_id']
	return local_game.do_boost(game_player, card_id)
