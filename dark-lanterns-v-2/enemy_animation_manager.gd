
extends AnimatedSprite2D


func play_action(animation_name: String) -> void:
	if sprite_frames == null:
		push_warning("Enemy has no SpriteFrames resource.")
		return

	if not sprite_frames.has_animation(animation_name):
		push_warning("Missing enemy animation: " + animation_name)
		return

	play(animation_name)


func play_attack(direction: Vector2) -> void:
	var animation_name: String

	if absf(direction.x) > absf(direction.y):
		if direction.x >= 0.0:
			animation_name = "attack_east"
		else:
			animation_name = "attack_west"
	else:
		if direction.y >= 0.0:
			animation_name = "attack_south"
		else:
			animation_name = "attack_north"

	play_action(animation_name)


func is_action_finished() -> bool:
	return not is_playing()
