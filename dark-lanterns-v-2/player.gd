
extends CharacterBody2D

# ==================================================
# SIGNALS
# ==================================================

signal health_changed(current: float, maximum: float)
signal brightness_changed(current: float, maximum: float)
signal brightness_depleted
signal player_died


# ==================================================
# MOVEMENT SETTINGS
# ==================================================

@export var move_speed: float = 50.0

# Must match pixel_scale in world_generator.gd.
@export var terrain_cell_size: float = 2.0

var terrain_speeds: Dictionary = {
	"grass": 1.0,
	"dirt": 0.9,
	"sand": 0.75,
	"snow": 0.5,
	"ice": 1.5,
	"rock": 0.9,
	"water": 0.0,
	"border": 0.0
}


# ==================================================
# HEALTH AND BRIGHTNESS
# ==================================================

@export var max_health: float = 100.0
@export var max_brightness: float = 100.0

var health: float
var brightness: float
var is_in_darkness: bool = false

@onready var player_light: PointLight2D = $PointLight2D


# ==================================================
# COMBAT SETTINGS
# ==================================================

@export var fireball_scene: PackedScene
@export var attack_cooldown: float = 0.5
@export var fireball_offset: float = 20.0

var can_attack: bool = true


# ==================================================
# RESOURCE COLLECTION
# ==================================================

@export var pickup_range: float = 25.0


# ==================================================
# SCENE REFERENCES
# ==================================================

@onready var animation: AnimatedSprite2D = $AnimatedSprite2D
@onready var spawncontroller = $"../SpawnController"
@onready var world_generator = $".."
@onready var campfire = $"../Campfire"


# ==================================================
# INITIALISATION
# ==================================================

func _ready() -> void:
	await world_generator.ready
	await get_tree().process_frame

	var saved_position: Variant = WorldSave.load_value(
		"player_position",
		null
	)

	if saved_position is Vector2:
		global_position = saved_position
	else:
		find_spawn_point()

	health = float(WorldSave.load_value("player_health", max_health))
	brightness = float(WorldSave.load_value("player_brightness", max_brightness))

	health = clampf(health, 0.0, max_health)
	brightness = clampf(brightness, 0.0, max_brightness)
	is_in_darkness = brightness <= 0.0

	if not WorldSave.save_requested.is_connected(_save_player_data):
		WorldSave.save_requested.connect(_save_player_data)

	animation.play("still_v1")

	health_changed.emit(health, max_health)
	brightness_changed.emit(brightness, max_brightness)

func _save_player_data() -> void:
	WorldSave.save("player_position", global_position)
	WorldSave.save("player_health", health)
	WorldSave.save("player_brightness", brightness)
func find_spawn_point() -> void:
	var saved_spawn: Variant = WorldSave.get_spawn_position("player")

	if saved_spawn is Vector2:
		global_position = saved_spawn
		print("Player: Loaded saved spawn at ", saved_spawn)
		return

	var spawn: Vector2 = spawncontroller.find_spawn_point(
		["grass", "dirt", "rock"],
		2
	)

	if spawn == Vector2.INF:
		push_error("Player: Could not find a valid spawn point.")
		return

	global_position = spawn
	WorldSave.set_spawn_position("player", spawn)

	print("Player: Generated spawn at ", spawn)


# ==================================================
# INPUT HANDLING
# ==================================================

func _unhandled_input(event: InputEvent) -> void:
	# Collect nearby resources.
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		attack()
	if event.is_action_pressed("interact"):
		collect_nearby_items()

	# Attack with the left mouse button.
	


# ==================================================
# RESOURCE COLLECTION
# ==================================================

func collect_nearby_items() -> void:
	var collectables := get_tree().get_nodes_in_group("collectable")

	for node in collectables:
		if not is_instance_valid(node):
			continue

		if global_position.distance_to(node.global_position) > pickup_range:
			continue

		Inventory.add_item(node.item_id, node.amount)
		node.queue_free()


# ==================================================
# PLAYER MOVEMENT
# ==================================================

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector(
		"ui_left",
		"ui_right",
		"ui_up",
		"ui_down"
	)

	if direction == Vector2.ZERO:
		return

	var current_tile := get_tile_at(global_position)

	if current_tile.is_empty():
		return

	var terrain_type: String = current_tile["type"]
	var speed_multiplier: float = terrain_speeds.get(
		terrain_type,
		1.0
	)

	var movement: Vector2 = (
		direction
		* move_speed
		* speed_multiplier
		* delta
	)

	# Check each axis separately to allow coastline sliding.
	var next_position := global_position

	next_position.x += movement.x
	if can_walk_at(next_position):
		global_position.x = next_position.x

	next_position = global_position
	next_position.y += movement.y
	if can_walk_at(next_position):
		global_position.y = next_position.y


func get_tile_at(world_pos: Vector2) -> Dictionary:
	var grid_x: int = floori(
		world_pos.x / terrain_cell_size
	)
	var grid_y: int = floori(
		world_pos.y / terrain_cell_size
	)

	return Tiles.get_tile_at_grid(grid_x, grid_y)


func can_walk_at(world_pos: Vector2) -> bool:
	var tile := get_tile_at(world_pos)

	if tile.is_empty():
		return false

	var terrain_type: String = tile["type"]
	var speed_multiplier: float = terrain_speeds.get(
		terrain_type,
		1.0
	)

	return speed_multiplier > 0.0


# ==================================================
# COMBAT
# ==================================================

func attack() -> void:
	print("attck called")
	if not can_attack:
		return

	if fireball_scene == null:
		push_warning("Assign fireball.tscn to fireball_scene.")
		return

	can_attack = false

	var fireball = fireball_scene.instantiate()
	get_tree().current_scene.add_child(fireball)

	var aim_direction: Vector2 = (
		get_global_mouse_position() - global_position
	).normalized()

	# Prevent a zero direction if the mouse is on the player.
	if aim_direction.is_zero_approx():
		aim_direction = Vector2.RIGHT

	fireball.global_position = (
		global_position + aim_direction * fireball_offset
	)

	fireball.direction = aim_direction
	fireball.rotation = aim_direction.angle() + deg_to_rad(225.0)

	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true


func take_damage(amount: float) -> void:
	if amount <= 0.0 or health <= 0.0:
		return

	# Brightness absorbs damage before health does.
	var absorbed_damage: float = minf(brightness, amount)

	if absorbed_damage > 0.0:
		change_brightness(-absorbed_damage)

	# Any remaining damage hits health.
	var remaining_damage: float = amount - absorbed_damage

	if remaining_damage > 0.0:
		health = clampf(
			health - remaining_damage,
			0.0,
			max_health
		)

		health_changed.emit(health, max_health)

		if health <= 0.0:
			player_died.emit()


# ==================================================
# BRIGHTNESS
# ==================================================

func change_brightness(amount: float) -> void:
	brightness = clampf(
		brightness + amount,
		0.0,
		max_brightness
	)

	brightness_changed.emit(brightness, max_brightness)

	if brightness <= 0.0 and not is_in_darkness:
		is_in_darkness = true
		brightness_depleted.emit()

	elif brightness > 0.0 and is_in_darkness:
		is_in_darkness = false


@warning_ignore("unused_parameter")
func _on_brightness_changed(current: float, maximum: float) -> void:
	player_light.enabled = current > 0.0
