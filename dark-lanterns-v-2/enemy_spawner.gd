extends Node

@export var enemy_scene: PackedScene
@export var player: Node2D
@export var spawn_radius: float = 500.0

# Optional: prevent enemies spawning practically on top of the player.
@export var minimum_spawn_distance: float = 100.0

func _ready() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D

	if enemy_scene == null:
		enemy_scene = preload("res://enemy.tscn")


func spawn_enemy() -> void:
	if player == null:
		push_warning("EnemySpawner: Player not found!")
		return

	if enemy_scene == null:
		push_warning("EnemySpawner: Enemy scene not assigned!")
		return

	var enemy := enemy_scene.instantiate() as Node2D
	if enemy == null:
		push_warning("EnemySpawner: Enemy root must inherit Node2D.")
		return

	var spawn_offset := Vector2.ZERO

	# Try to find a position within the allowed radius.
	for attempt in range(30):
		var angle := randf_range(0.0, TAU)
		var distance := randf_range(
			minimum_spawn_distance,
			spawn_radius
		)

		spawn_offset = Vector2.RIGHT.rotated(angle) * distance
		break

	enemy.global_position = player.global_position + spawn_offset
	get_tree().current_scene.add_child(enemy)


func _on_wave_manager_spawn_enemy_requested() -> void:
	spawn_enemy() # Replace with function body.
