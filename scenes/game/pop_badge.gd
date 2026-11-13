extends Control

# Shared by the status badges (ADVANTAGE, DODGE, STUN, and the gem badges): how they appear and
# leave.

# Pops in: grows from nothing with a little bounce while rising into place.
func pop_in(target_pos : Vector2) -> void:
	pivot_offset = size / 2.0
	position = target_pos + Vector2(0, 30)
	scale = Vector2(0.2, 0.2)
	modulate.a = 0.0
	visible = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position", target_pos, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)

func fade_out() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_property(self, "scale", Vector2(0.8, 0.8), 0.3)
	tw.chain().tween_callback(func(): visible = false)
