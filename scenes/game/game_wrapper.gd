extends Node

const LocalGame = preload("res://scenes/game/local_game.gd")
const Enums = preload("res://scenes/game/enums.gd")
const CardDatabase = preload("res://scenes/game/card_database.gd")
const DecisionInfo = preload("res://scenes/game/decision_info.gd")

var current_game

func poll_for_events() -> Array:
	return current_game.get_latest_events()

func initialize_local_game(player_deck, opponent_deck):
	current_game = LocalGame.new()
	current_game.initialize_game(player_deck, opponent_deck)
	current_game.draw_starting_hands_and_begin()

func _test_add_to_gauge(amount):
	current_game._test_add_to_gauge(amount)

func _get_player(id):
	if id == Enums.PlayerId.PlayerId_Player:
		return current_game.player
	else:
		return current_game.opponent

func get_game_state() -> Enums.GameState:
	return current_game.game_state

func get_active_player() -> Enums.PlayerId:
	return current_game.active_turn_player

func get_decision_info() -> DecisionInfo:
	return current_game.decision_info

func get_player_name(id):
	return _get_player(id).name

func get_player_life(id):
	return _get_player(id).life

func get_player_location(id):
	return _get_player(id).arena_location

func get_player_deck_definition(id):
	return _get_player(id).deck_def

func get_player_deck_list(id):
	return _get_player(id).deck_list

func get_player_hand_size(id):
	return _get_player(id).hand.size()

func get_player_deck_size(id):
	return _get_player(id).deck.size()

func get_player_discards_size(id):
	return _get_player(id).discards.size()

func get_player_gauge_size(id):
	return _get_player(id).gauge.size()

func get_player_reshuffle_remaining(id):
	return _get_player(id).reshuffle_remaining

func get_player_exceed_cost(id):
	return _get_player(id).exceed_cost

func get_all_non_immediate_continuous_boost_effects(id):
	var game_player = _get_player(id)
	return game_player.get_all_non_immediate_continuous_boost_effects()

func is_card_in_gauge(player_id : Enums.PlayerId, card_id : int):
	var player = _get_player(player_id)
	for card in player.gauge:
		if card.id == card_id:
			return true
	return false

func is_card_in_hand(player_id : Enums.PlayerId, card_id : int):
	var player = _get_player(player_id)
	for card in player.hand:
		if card.id == card_id:
			return true
	return false

func is_card_in_boosts(player_id : Enums.PlayerId, card_id : int):
	var player = _get_player(player_id)
	for card in player.continuous_boosts:
		if card.id == card_id:
			return true
	return false

func get_player_available_force(player_id : Enums.PlayerId):
	return _get_player(player_id).get_available_force()

func get_force_to_move_to(player_id : Enums.PlayerId, location : int):
	return _get_player(player_id).get_force_to_move_to(location)

func other_player(id : Enums.PlayerId) -> Enums.PlayerId:
	if id == Enums.PlayerId.PlayerId_Player:
		return Enums.PlayerId.PlayerId_Opponent
	else:
		return Enums.PlayerId.PlayerId_Player

func get_card_database() -> CardDatabase:
	return current_game.get_card_database()

func can_player_boost(player_id : Enums.PlayerId, card_id : int) -> bool:
	if not is_card_in_hand(player_id, card_id):
		return false
	var card_db = current_game.get_card_database()
	var force_cost = card_db.get_card_boost_force_cost(card_id)
	var boosting_card_force_value = card_db.get_card_force_value(card_id)
	var force_available = get_player_available_force(player_id) - boosting_card_force_value
	if force_cost <= force_available:
		return true
	return false

func can_do_prepare(player : Enums.PlayerId) -> bool:
	var game_player = _get_player(player)
	return current_game.can_do_prepare(game_player)

func can_do_move(player : Enums.PlayerId) -> bool:
	var game_player = _get_player(player)
	return current_game.can_do_move(game_player)

func can_do_change(player : Enums.PlayerId) -> bool:
	var game_player = _get_player(player)
	return current_game.can_do_change(game_player)

func can_do_exceed(player : Enums.PlayerId) -> bool:
	var game_player = _get_player(player)
	return current_game.can_do_exceed(game_player)

func can_do_reshuffle(player : Enums.PlayerId) -> bool:
	var game_player = _get_player(player)
	return current_game.can_do_reshuffle(game_player)

func can_do_boost(player : Enums.PlayerId) -> bool:
	var game_player = _get_player(player)
	return current_game.can_do_boost(game_player)

func can_do_strike(player : Enums.PlayerId) -> bool:
	var game_player = _get_player(player)
	return current_game.can_do_strike(game_player)

func can_move_to(player_id : Enums.PlayerId, location : int) -> bool:
	var game_player = _get_player(player_id)
	return game_player.can_move_to(location)

func submit_prepare(player : Enums.PlayerId) -> bool:
	var game_player = _get_player(player)
	return current_game.do_prepare(game_player)

func submit_reshuffle(player : Enums.PlayerId) -> bool:
	var game_player = _get_player(player)
	return current_game.do_reshuffle(game_player)

func submit_choice(player : Enums.PlayerId, choice_index : int) -> bool:
	var game_player = _get_player(player)
	return current_game.do_choice(game_player, choice_index)

func submit_boost_cancel(player : Enums.PlayerId, gauge_card_ids : Array, doing_cancel : bool) -> bool:
	var game_player = _get_player(player)
	return current_game.do_boost_cancel(game_player, gauge_card_ids, doing_cancel)

func submit_boost_name_card_choice_effect(player : Enums.PlayerId, card_id : int) -> bool:
	var game_player = _get_player(player)
	return current_game.do_boost_name_card_choice_effect(game_player, card_id)

func submit_discard_to_max(player : Enums.PlayerId, card_ids : Array) -> bool:
	var game_player = _get_player(player)
	return current_game.do_discard_to_max(game_player, card_ids)

func submit_card_from_hand_to_gauge(player : Enums.PlayerId, card_id : int) -> bool:
	var game_player = _get_player(player)
	return current_game.do_card_from_hand_to_gauge(game_player, card_id)

func submit_pay_strike_cost(player : Enums.PlayerId, card_ids : Array, wild_strike : bool) -> bool:
	var game_player = _get_player(player)
	return current_game.do_pay_strike_cost(game_player, card_ids, wild_strike)

func submit_exceed(player : Enums.PlayerId, card_ids : Array) -> bool:
	var game_player = _get_player(player)
	return current_game.do_exceed(game_player, card_ids)

func submit_move(player : Enums.PlayerId, card_ids : Array, new_arena_location : int) -> bool:
	var game_player = _get_player(player)
	return current_game.do_move(game_player, card_ids, new_arena_location)

func submit_change(player : Enums.PlayerId, card_ids : Array) -> bool:
	var game_player = _get_player(player)
	return current_game.do_change(game_player, card_ids)

func submit_strike(player : Enums.PlayerId, card_id : int, wild_strike: bool, ex_card_id : int) -> bool:
	var game_player = _get_player(player)
	return current_game.do_strike(game_player, card_id, wild_strike, ex_card_id)

func submit_force_for_armor(player : Enums.PlayerId, card_ids : Array) -> bool:
	var game_player = _get_player(player)
	return current_game.do_force_for_armor(game_player, card_ids)

func submit_mulligan(player : Enums.PlayerId, card_ids : Array) -> bool:
	var game_player = _get_player(player)
	return current_game.do_mulligan(game_player, card_ids)

func submit_boost(player : Enums.PlayerId, card_id : int) -> bool:
	var game_player = _get_player(player)
	return current_game.do_boost(game_player, card_id)
