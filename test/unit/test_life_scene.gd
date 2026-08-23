extends GutTest

const LifeSceneResource = preload("res://scenes/game/life_scene.tscn")

func test_finish_animation_immediately_settles_health_bar():
	var life_scene : LifeScene = LifeSceneResource.instantiate()
	add_child_autofree(life_scene)
	await get_tree().process_frame

	life_scene.set_life(12)
	assert_eq(life_scene.health_bar.animation_state, HealthBar.AnimationState.AnimationState_Paused)

	life_scene.finish_animation_immediately()

	assert_eq(life_scene.health_bar.animation_state, HealthBar.AnimationState.AnimationState_None)
	assert_eq(life_scene.health_bar.lost_bar.value, life_scene.health_bar.health_bar.value)
