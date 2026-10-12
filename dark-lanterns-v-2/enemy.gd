
extends CharacterBody2D

@export_group("Detection")
@export var detection_range: float = 100.0
@export var attack_range: float = 16.0
@export var lose_sight_timeout: float = 5.0
@export_flags_2d_physics var sight_collision_mask: int = 1

@export_group("Movement")
@export var move_speed: float = 40.0
@export var search_radius: float = 24.0

@export_group("Combat")
@export var max_health: float = 20.0
@export var attack_damage: float = 15.0

@onready var animation_manager = $AnimatedSprite2D
@onready var state_manager = $Node

var health: float
var player: Node2D
var last_seen_position: Vector2
var lost_sight_time: float = 0.0
var search_target: Vector2
var has_search_target: bool = false
var is_dead: bool = false


func _ready() -> void:
	health = max_health
	add_to_group("enemies")

	# Spawn animation must finish before the enemy becomes active.
	animation_manager.play_action("spawn")
	await animation_manager.animation_finished

	if is_dead:
		return

	state_manager.transition_to(state_manager.State.IDLE)
	animation_manager.play_action("at_rest")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	player = get_tree().get_first_node_in_group("player") as Node2D

	match state_manager.current_state:
		state_manager.State.IDLE:
			process_idle()

		state_manager.State.PURSUING:
			process_pursuing(delta)

		state_manager.State.SEARCHING:
			process_searching(delta)

		state_manager.State.ATTACKING:
			process_attacking()

	# Movement is handled by CharacterBody2D.
	move_and_slide()


func process_idle() -> void:
	velocity = Vector2.ZERO

	if not animation_manager.is_playing():
		animation_manager.play_action("at_rest")

	if not is_instance_valid(player):
		return

	if global_position.distance_to(player.global_position) <= detection_range:
		if can_see_player():
			last_seen_position = player.global_position
			lost_sight_time = 0.0
			state_manager.transition_to(state_manager.State.PURSUING)


func process_pursuing(delta: float) -> void:
	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		state_manager.transition_to(state_manager.State.IDLE)
		animation_manager.play_action("at_rest")
		return

	if can_see_player():
		last_seen_position = player.global_position
		lost_sight_time = 0.0

		var distance := global_position.distance_to(
			player.global_position
		)

		if distance <= attack_range:
			velocity = Vector2.ZERO
			state_manager.transition_to(state_manager.State.ATTACKING)
			start_attack()
			return

		move_towards(player.global_position)
	else:
		lost_sight_time += delta
		move_towards(last_seen_position)

		if global_position.distance_to(last_seen_position) <= 4.0:
			state_manager.transition_to(state_manager.State.SEARCHING)
			has_search_target = false

		if lost_sight_time >= lose_sight_timeout:
			return_to_idle()


func process_searching(delta: float) -> void:
	if is_instance_valid(player) and can_see_player():
		last_seen_position = player.global_position
		lost_sight_time = 0.0
		state_manager.transition_to(state_manager.State.PURSUING)
		return

	lost_sight_time += delta

	if lost_sight_time >= lose_sight_timeout:
		return_to_idle()
		return

	if not has_search_target:
		var offset := Vector2(
			randf_range(-search_radius, search_radius),
			randf_range(-search_radius, search_radius)
		)

		search_target = last_seen_position + offset
		has_search_target = true

	if global_position.distance_to(search_target) <= 4.0:
		has_search_target = false
		velocity = Vector2.ZERO
	else:
		move_towards(search_target)


func process_attacking() -> void:
	velocity = Vector2.ZERO

	# Wait until the directional attack animation has finished.
	if animation_manager.is_playing():
		return

	# Damage only if the player is still close and visible.
	if is_instance_valid(player):
		var distance := global_position.distance_to(
			player.global_position
		)

		if distance <= attack_range and can_see_player():
			if player.has_method("take_damage"):
				player.take_damage(attack_damage)

			# Repeat the attack if the player stayed in range.
			start_attack()
			return

	# The player dodged or escaped. Resume pursuit.
	if is_instance_valid(player):
		state_manager.transition_to(state_manager.State.PURSUING)
	else:
		return_to_idle()


func start_attack() -> void:
	if not is_instance_valid(player):
		return_to_idle()
		return

	var direction := (
		player.global_position - global_position
	).normalized()

	animation_manager.play_attack(direction)


func move_towards(target_position: Vector2) -> void:
	var direction := global_position.direction_to(target_position)
	velocity = direction * move_speed


func can_see_player() -> bool:
	if not is_instance_valid(player):
		return false

	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		player.global_position
	)

	query.collision_mask = sight_collision_mask
	query.exclude = [get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var result := get_world_2d().direct_space_state.intersect_ray(query)

	if result.is_empty():
		return false

	return result.get("collider") == player


func return_to_idle() -> void:
	lost_sight_time = 0.0
	has_search_target = false
	velocity = Vector2.ZERO

	state_manager.transition_to(state_manager.State.IDLE)
	animation_manager.play_action("at_rest")


func take_damage(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return

	health = clampf(health - amount, 0.0, max_health)

	if health <= 0.0:
		die()


func die() -> void:
	if is_dead:
		return

	is_dead = true
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0

	state_manager.transition_to(state_manager.State.DYING)
	animation_manager.play_action("despawn")

	await animation_manager.animation_finished
	queue_free()
