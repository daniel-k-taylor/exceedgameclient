extends Node

const LocalGame = preload("res://scenes/game/local_game.gd")
const Enums = preload("res://scenes/game/enums.gd")
const CardDatabase = preload("res://scenes/game/card_database.gd")
const DecisionInfo = preload("res://scenes/game/decision_info.gd")


var local_game : LocalGame

var _player_info
var _opponent_info
var _observer_mode : bool
var _game_message_queue : Array

func get_latest_events() -> Array:
	return local_game.get_latest_events()

func get_combat_log(log_filters) -> String:
	return local_game.get_combat_log(log_filters)

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

func get_striking_card_ids_for_player(player : LocalGame.Player) -> Array:
	return local_game.get_striking_card_ids_for_player(player)

func initialize_game(player_info, opponent_info, starting_player : Enums.PlayerId, seed_value : int, observer_mode : bool, starting_message_queue : Array):
	_game_message_queue = starting_message_queue

	_player_info = player_info
	_opponent_info = opponent_info
	_observer_mode = observer_mode
	local_game = LocalGame.new()
	local_game.initialize_game(player_info['deck'], opponent_info['deck'], player_info['name'], opponent_info['name'], starting_player, seed_value)
	local_game.draw_starting_hands_and_begin()

	NetworkManager.connect("game_message_received", _on_remote_game_message)
	NetworkManager.connect("other_player_quit", _on_remote_player_quit)
	NetworkManager.connect("disconnected_from_server", _on_disconnected)

func _on_remote_game_message(game_message):
	if _observer_mode:
		_game_message_queue.append(game_message)
	else:
		_process_game_message(game_message)

func observer_process_next_message_from_queue():
	if _game_message_queue.size() > 0:
		var message = _game_message_queue[0]
		_game_message_queue.remove_at(0)
		_process_game_message(message)
		return true
	else:
		return false

func _process_game_message(game_message):
	var action_type = game_message['action_type']
	var action_function_name = action_type.replace("action_", "process_")
	var action_function = Callable(self, action_function_name)
	action_function.call(game_message)

func _on_disconnected():
	local_game.do_quit(Enums.PlayerId.PlayerId_Player, Enums.GameOverReason.GameOverReason_Disconnect)

func _on_remote_player_quit(_is_disconnect : bool):
	var reason = Enums.GameOverReason.GameOverReason_Quit
	if _is_disconnect:
		reason = Enums.GameOverReason.GameOverReason_Disconnect
	local_game.do_quit(Enums.PlayerId.PlayerId_Opponent, reason)

func get_game_state() -> Enums.GameState:
	return local_game.get_game_state()

func get_active_player() -> Enums.PlayerId:
	return local_game.get_active_player()

func get_priority_player() -> Enums.PlayerId:
	return local_game.get_priority_player()

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
	var ignore_force_req = false
	return player.can_move_to(location, ignore_force_req)

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
	local_game.do_reshuffle(game_player)

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
	local_game.do_choice(game_player, choice_index)

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
	local_game.do_boost_cancel(game_player, gauge_card_ids, doing_cancel)

func do_boost_name_card_choice_effect(player : LocalGame.Player, card_id : int) -> bool:
	var action_message = {
		'action_type': 'action_boost_name_card_choice_effect',
		'player_id': _get_player_remote_id(player),
		'card_id': card_id,
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_boost_name_card_choice_effect(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var card_id = action_message['card_id']
	local_game.do_boost_name_card_choice_effect(game_player, card_id)

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
	local_game.do_discard_to_max(game_player, card_ids)

func do_card_from_hand_to_gauge(player : LocalGame.Player, card_ids : Array) -> bool:
	var action_message = {
		'action_type': 'action_card_from_hand_to_gauge',
		'player_id': _get_player_remote_id(player),
		'card_ids': card_ids,
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_card_from_hand_to_gauge(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var card_ids = action_message['card_ids']
	local_game.do_card_from_hand_to_gauge(game_player, card_ids)

func do_pay_strike_cost(player : LocalGame.Player, card_ids : Array, wild_strike : bool, discard_ex_first : bool, use_free_force : bool = false) -> bool:
	var action_message = {
		'action_type': 'action_pay_strike_cost',
		'player_id': _get_player_remote_id(player),
		'card_ids': card_ids,
		'wild_strike': wild_strike,
		'discard_ex_first': discard_ex_first,
		'use_free_force': use_free_force
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_pay_strike_cost(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var card_ids = action_message['card_ids']
	var wild_strike = action_message['wild_strike']
	var discard_ex_first = action_message['discard_ex_first']
	var use_free_force = action_message['use_free_force']
	local_game.do_pay_strike_cost(game_player, card_ids, wild_strike, discard_ex_first, use_free_force)

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
	local_game.do_exceed(game_player, card_ids)

func do_move(player : LocalGame.Player, card_ids : Array, new_arena_location : int, use_free_force : bool = false) -> bool:
	var action_message = {
		'action_type': 'action_move',
		'player_id': _get_player_remote_id(player),
		'card_ids': card_ids,
		'new_arena_location': new_arena_location,
		'use_free_force': use_free_force,
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_move(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var card_ids = action_message['card_ids']
	var new_arena_location = action_message['new_arena_location']
	var use_free_force = action_message['use_free_force']
	local_game.do_move(game_player, card_ids, new_arena_location, use_free_force)

func do_change(player : LocalGame.Player, card_ids : Array, treat_ultras_as_single_force : bool, use_free_force : bool = false) -> bool:
	var action_message = {
		'action_type': 'action_change',
		'player_id': _get_player_remote_id(player),
		'card_ids': card_ids,
		'treat_ultras_as_single_force': treat_ultras_as_single_force,
		'use_free_force': use_free_force,
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_change(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var card_ids = action_message['card_ids']
	var treat_ultras_as_single_force = action_message['treat_ultras_as_single_force']
	var use_free_force = action_message['use_free_force']
	local_game.do_change(game_player, card_ids, treat_ultras_as_single_force, use_free_force)

func do_strike(player : LocalGame.Player, card_id : int, wild_strike: bool, ex_card_id : int,
		opponent_sets_first : bool = false) -> bool:
	var action_message = {
		'action_type': 'action_strike',
		'player_id': _get_player_remote_id(player),
		'card_id': card_id,
		'wild_strike': wild_strike,
		'ex_card_id': ex_card_id,
		'opponent_sets_first': opponent_sets_first,
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_strike(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var card_id = action_message['card_id']
	var wild_strike = action_message['wild_strike']
	var ex_card_id = action_message['ex_card_id']
	var opponent_sets_first = action_message['opponent_sets_first']
	local_game.do_strike(game_player, card_id, wild_strike, ex_card_id, opponent_sets_first)

func do_force_for_armor(player : LocalGame.Player, card_ids : Array, use_free_force : bool = false) -> bool:
	var action_message = {
		'action_type': 'action_force_for_armor',
		'player_id': _get_player_remote_id(player),
		'card_ids': card_ids,
		'use_free_force': use_free_force,
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_force_for_armor(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var card_ids = action_message['card_ids']
	var use_free_force = action_message['use_free_force']
	local_game.do_force_for_armor(game_player, card_ids, use_free_force)

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
	local_game.do_mulligan(game_player, card_ids)

func do_boost(player : LocalGame.Player, card_id : int, payment_card_ids = [], use_free_force : bool = false) -> bool:
	var action_message = {
		'action_type': 'action_boost',
		'player_id': _get_player_remote_id(player),
		'card_id': card_id,
		'payment_card_ids': payment_card_ids,
		'use_free_force': use_free_force,
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_boost(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var card_id = action_message['card_id']
	var payment_card_ids = action_message['payment_card_ids']
	var use_free_force = action_message['use_free_force']
	local_game.do_boost(game_player, card_id, payment_card_ids, use_free_force)

func do_choose_from_boosts(player : LocalGame.Player, card_ids : Array) -> bool:
	var action_message = {
		'action_type': 'action_choose_from_boosts',
		'player_id': _get_player_remote_id(player),
		'card_ids': card_ids,
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_choose_from_boosts(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var card_ids = action_message['card_ids']
	local_game.do_choose_from_boosts(game_player, card_ids)

func do_choose_from_discard(player : LocalGame.Player, card_ids : Array) -> bool:
	var action_message = {
		'action_type': 'action_choose_from_discard',
		'player_id': _get_player_remote_id(player),
		'card_ids': card_ids,
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_choose_from_discard(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var card_ids = action_message['card_ids']
	local_game.do_choose_from_discard(game_player, card_ids)

func do_force_for_effect(player : LocalGame.Player, card_ids : Array, treat_ultras_as_single_force : bool, cancel : bool, use_free_force : bool = false) -> bool:
	var action_message = {
		'action_type': 'action_force_for_effect',
		'player_id': _get_player_remote_id(player),
		'card_ids': card_ids,
		'treat_ultras_as_single_force': treat_ultras_as_single_force,
		'cancel': cancel,
		'use_free_force': use_free_force,
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_force_for_effect(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var card_ids = action_message['card_ids']
	var treat_ultras_as_single_force = action_message['treat_ultras_as_single_force']
	var cancel = action_message['cancel']
	var use_free_force = action_message['use_free_force']
	local_game.do_force_for_effect(game_player, card_ids, treat_ultras_as_single_force, cancel, use_free_force)

func do_gauge_for_effect(player : LocalGame.Player, card_ids : Array) -> bool:
	var action_message = {
		'action_type': 'action_gauge_for_effect',
		'player_id': _get_player_remote_id(player),
		'card_ids': card_ids,
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_gauge_for_effect(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var card_ids = action_message['card_ids']
	local_game.do_gauge_for_effect(game_player, card_ids)

func do_choose_to_discard(player : LocalGame.Player, card_ids : Array) -> bool:
	var action_message = {
		'action_type': 'action_choose_to_discard',
		'player_id': _get_player_remote_id(player),
		'card_ids': card_ids,
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_choose_to_discard(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var card_ids = action_message['card_ids']
	local_game.do_choose_to_discard(game_player, card_ids)

func do_character_action(player : LocalGame.Player, card_ids : Array, action_idx : int = 0, use_free_force : bool = false) -> bool:
	var action_message = {
		'action_type': 'action_character_action',
		'player_id': _get_player_remote_id(player),
		'card_ids': card_ids,
		'action_idx': action_idx,
		'use_free_force': use_free_force
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_character_action(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var card_ids = action_message['card_ids']
	var action_idx = action_message['action_idx']
	var use_free_force = action_message['use_free_force']
	local_game.do_character_action(game_player, card_ids, action_idx, use_free_force)

func do_bonus_turn_action(player : LocalGame.Player, action_index : int) -> bool:
	var action_message = {
		'action_type': 'action_bonus_action',
		'player_id': _get_player_remote_id(player),
		'action_index': action_index,
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_bonus_action(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var action_index = action_message['action_index']
	local_game.do_bonus_turn_action(game_player, action_index)

func do_choose_from_topdeck(player : LocalGame.Player, card_id : int, action : String) -> bool:
	var action_message = {
		'action_type': 'action_choose_from_topdeck',
		'player_id': _get_player_remote_id(player),
		'card_id': card_id,
		'action': action,
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_choose_from_topdeck(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var card_id = action_message['card_id']
	var action = action_message['action']
	local_game.do_choose_from_topdeck(game_player, card_id, action)

func do_emote(player : LocalGame.Player, is_image_emote : bool, emote : String):
	var action_message = {
		'action_type': 'action_emote',
		'player_id': _get_player_remote_id(player),
		'is_image_emote': is_image_emote,
		'emote': emote,
	}
	NetworkManager.submit_game_message(action_message)
	return true

func process_emote(action_message) -> void:
	var game_player = _get_player_from_remote_id(action_message['player_id'])
	var is_image_emote = action_message['is_image_emote']
	var emote = action_message['emote']
	local_game.do_emote(game_player, is_image_emote, emote)

func do_match_result(player_clock_remaining, opponent_clock_remaining):
	# Only the winner should be reporting.
	var winning_player_number = _player_info['player_number']
	var p1 = Enums.PlayerId.PlayerId_Player
	var p2 = Enums.PlayerId.PlayerId_Opponent
	var p1clock = player_clock_remaining
	var p2clock = opponent_clock_remaining
	if winning_player_number == 2:
		p1 = Enums.PlayerId.PlayerId_Opponent
		p2 = Enums.PlayerId.PlayerId_Player
		p1clock = opponent_clock_remaining
		p2clock = player_clock_remaining
	var action_message = {
		'action_type': 'match_result',
		'winning_player': winning_player_number,
		'p1life': _get_player(p1).life,
		'p2life': _get_player(p2).life,
		'p1clock': p1clock,
		'p2clock': p2clock,
	}
	NetworkManager.submit_game_message(action_message)
	return true
