extends GutTest

# Regression coverage for characters visually stranding between arena spaces.
#
# Repro that motivated this file: Taokaka at space 6 strikes with Slashy Slashy,
# the opponent at 7 strikes with Grasp. Grasp pushes Taokaka 2 (6 -> 4) and then
# deals damage. The damage reaction (play_hit) used to overwrite the in-flight
# move's target_position with the character's current interpolated position, so
# Taokaka froze partway through the push - visually between 5 and 6 instead of
# landing on 4.

var game_ui : Game

func setup_game_ui(player_id : String = "taokaka", opponent_id : String = "ryu"):
	var game_scene = load("res://scenes/game/game.tscn")
	game_ui = game_scene.instantiate()
	game_ui.set_not_started_directly()
	add_child(game_ui)
	var game_logic = LocalGame.new(game_ui.image_loader)
	game_logic.initialize_game(
		CardDataManager.get_deck_from_str_id(player_id),
		CardDataManager.get_deck_from_str_id(opponent_id),
		"p1",
		"p2",
		Enums.PlayerId.PlayerId_Player,
		randi()
	)
	game_logic.draw_starting_hands_and_begin()
	assert_true(game_logic.do_mulligan(game_logic.player, []))
	assert_true(game_logic.do_mulligan(game_logic.opponent, []))
	game_logic.get_latest_events()
	game_ui.game_wrapper.current_game = game_logic

func before_each():
	setup_game_ui()

func after_each():
	if game_ui:
		game_ui.queue_free()
		game_ui = null

func _arena_square_position(character, arena_location : int) -> Vector2:
	var target_square = game_ui.arena_layout.get_child(arena_location - 1)
	var target_position = target_square.global_position + target_square.size / 2
	var offset_y = game_ui.get_node("ArenaNode/RowButtons").position.y
	target_position.y -= character.get_size().y * character.scale.y / 2 + offset_y + character.vertical_offset
	return target_position

# Runs enough physics frames for any in-flight character animation to finish.
func _run_animation_to_completion(character, step : float = 0.1):
	for _i in range(int(Character.MoveTime / step) + 5):
		character._physics_process(step)

func test_taking_damage_midmove_still_lands_on_the_destination_square():
	var character = game_ui.get_node("PlayerCharacter")
	var start_position = Vector2(600, 300)
	var destination_position = Vector2(200, 300)
	character.snap_to(start_position)

	character.move_to(destination_position, Character.CharacterAnim.CharacterAnim_Pushed)
	# Interrupt a quarter of the way through the push, exactly like a damage
	# event arriving while the push is still animating.
	character._physics_process(Character.MoveTime * 0.25)
	assert_ne(character.position, destination_position, "the push should still be animating")
	character.play_hit()

	_run_animation_to_completion(character)

	assert_eq(character.position, destination_position,
		"a hit during a push must not strand the character between spaces")

func test_being_stunned_midmove_still_lands_on_the_destination_square():
	var character = game_ui.get_node("OpponentCharacter")
	var start_position = Vector2(300, 300)
	var destination_position = Vector2(700, 300)
	character.snap_to(start_position)

	character.move_to(destination_position, Character.CharacterAnim.CharacterAnim_Pulled)
	character._physics_process(Character.MoveTime * 0.5)
	character.play_stunned()

	_run_animation_to_completion(character)

	assert_eq(character.position, destination_position,
		"a stun during a move must not strand the character between spaces")

func test_hit_without_a_move_in_progress_still_plays_the_hit_reaction():
	var character = game_ui.get_node("PlayerCharacter")
	var resting_position = Vector2(600, 300)
	character.snap_to(resting_position)

	character.play_hit()

	assert_eq(character.animation_state, Character.AnimationState.AnimationState_Moving)
	assert_eq(character.target_position, resting_position)
	_run_animation_to_completion(character)
	assert_eq(character.position, resting_position)

func test_a_second_move_during_a_move_lands_on_the_latest_destination():
	var character = game_ui.get_node("PlayerCharacter")
	character.snap_to(Vector2(600, 300))
	var first_destination = Vector2(400, 300)
	var second_destination = Vector2(200, 300)

	character.move_to(first_destination, Character.CharacterAnim.CharacterAnim_Pushed)
	character._physics_process(Character.MoveTime * 0.25)
	character.move_to(second_destination, Character.CharacterAnim.CharacterAnim_Pushed)

	_run_animation_to_completion(character)

	assert_eq(character.position, second_destination)

func test_move_event_caches_the_destination_it_animates_to():
	# The cached location drives arena highlighting and the re-snap that happens
	# after a layout change, so it must match the move being animated even when
	# the game state has already advanced past it.
	game_ui.first_run_done = true
	game_ui.cached_player_location = 6
	var move_event = {
		'event_player': Enums.PlayerId.PlayerId_Player,
		'event_type': Enums.EventType.EventType_Move,
		'number': 4,
		'reason': "push",
		'extra_info': 2,
		'extra_info2': 6,
	}

	game_ui._on_move_event(move_event)

	assert_eq(game_ui.cached_player_location, 4)
	var character = game_ui.get_node("PlayerCharacter")
	var animated_destination = character.target_position
	# A damage reaction arriving mid-push must not change where the push ends.
	character._physics_process(Character.MoveTime * 0.25)
	character.play_hit()
	_run_animation_to_completion(character)
	assert_eq(character.position, animated_destination)
