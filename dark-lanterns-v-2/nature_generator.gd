
extends Node

@export_group("Player")
@export var player: Node2D
@export var load_radius: float = 200.0
@export var update_interval: float = 0.25

@export_group("Trees")
@export var tree_scene: PackedScene
@export var tree_count: int = 500
@export var tree_terrain: Array[String] = ["grass", "dirt"]
@export var tree_spacing: float = 100.0

@export_group("Azuras")
@export var azura_scene: PackedScene
@export var azura_count: int = 250
@export var azura_terrain: Array[String] = ["grass"]
@export var azura_spacing: float = 50.0

@export_group("General")
@export var max_attempts_per_object: int = 100

const SPATIAL_CELL_SIZE: float = 64.0
const RECORD_CELL_SIZE: float = 256.0

var rng := RandomNumberGenerator.new()

# All saved objects, including currently unloaded ones.
var nature_records: Array = []

# Only instantiated objects.
var spawned_objects: Dictionary = {}

# Used when generating placements and enforcing spacing.
var placement_grid: Dictionary = {}

# Spatial index for finding saved objects near the player.
var record_grid: Dictionary = {}

var update_timer: float = 0.0
var is_initialised: bool = false
var is_cleaning: bool = false


func _ready() -> void:
	rng.randomize()

	# Allow world generation to register terrain first.
	await get_tree().process_frame

	if not is_inside_tree():
		return

	if Tiles.tiles.is_empty():
		push_error("NatureSpawner: Terrain has not been registered.")
		return

	if player == null or not is_instance_valid(player):
		push_error("NatureSpawner: Assign the player in the Inspector.")
		return

	if WorldSave.is_nature_generated():
		restore_nature()
	else:
		generate_nature()

	is_initialised = true
	update_loaded_objects()


func _process(delta: float) -> void:
	if not is_initialised:
		return

	if player == null or not is_instance_valid(player):
		return

	update_timer += delta

	if update_timer >= update_interval:
		update_timer = 0.0
		update_loaded_objects()


# --------------------------------------------------
# GENERATION
# --------------------------------------------------

func generate_nature() -> void:
	nature_records.clear()
	spawned_objects.clear()
	placement_grid.clear()
	record_grid.clear()

	spawn_category(
		"tree",
		tree_scene,
		tree_count,
		tree_terrain,
		tree_spacing
	)

	spawn_category(
		"azura",
		azura_scene,
		azura_count,
		azura_terrain,
		azura_spacing
	)

	rebuild_record_grid()

	WorldSave.set_nature_data(nature_records)
	WorldSave.set_nature_generated(true)

	if not WorldSave.save_world():
		push_error("NatureSpawner: Failed to save generated nature.")

	print(
		"NatureSpawner: Generated ",
		nature_records.size(),
		" nature records."
	)


func spawn_category(
	id: String,
	scene: PackedScene,
	count: int,
	allowed_terrain: Array[String],
	min_spacing: float
) -> void:
	if scene == null:
		push_warning("NatureSpawner: No scene assigned for " + id)
		return

	var placed: int = 0

	for i in range(maxi(0, count)):
		var pos: Variant = find_spawn_position(
			allowed_terrain,
			min_spacing
		)

		if pos == null:
			push_warning(
				"NatureSpawner: Could not place all " + id + " objects."
			)
			break

		var record: Dictionary = {
			"id": id,
			"instance_id": id + "_" + str(i),
			"position": pos,
			"rotation": 0.0
		}

		nature_records.append(record)
		placed += 1

	print("NatureSpawner: Placed ", placed, " ", id, " objects.")


func find_spawn_position(
	allowed_terrain: Array[String],
	min_spacing: float
) -> Variant:
	var world_width: int = int(
		WorldSave.get_world_value("world_width", 1024)
	)
	var world_height: int = int(
		WorldSave.get_world_value("world_height", 1024)
	)

	for attempt in range(max_attempts_per_object):
		var x: int = rng.randi_range(0, world_width - 1)
		var y: int = rng.randi_range(0, world_height - 1)

		var tile: Dictionary = Tiles.get_tile_at_grid(x, y)

		if tile.is_empty():
			continue

		if not allowed_terrain.has(str(tile.get("type", ""))):
			continue

		var position: Vector2 = tile["world_position"]

		if not has_spacing(position, min_spacing):
			continue

		add_to_placement_grid(position)
		return position

	return null


# --------------------------------------------------
# RESTORE
# --------------------------------------------------

func restore_nature() -> void:
	nature_records = WorldSave.get_nature_data()

	spawned_objects.clear()
	placement_grid.clear()
	record_grid.clear()

	# Remove malformed records and duplicate instance IDs.
	var valid_records: Array = []
	var seen_ids: Dictionary = {}

	for record in nature_records:
		if not record is Dictionary:
			continue

		var instance_id: String = str(
			record.get("instance_id", "")
		)
		var position: Variant = record.get("position")
		var id: String = str(record.get("id", ""))

		if instance_id.is_empty():
			continue

		if seen_ids.has(instance_id):
			push_warning(
				"NatureSpawner: Ignoring duplicate record " + instance_id
			)
			continue

		if not position is Vector2:
			push_warning(
				"NatureSpawner: Invalid position for " + instance_id
			)
			continue

		if id != "tree" and id != "azura":
			push_warning(
				"NatureSpawner: Ignoring unknown nature type " + id
			)
			continue

		seen_ids[instance_id] = true
		valid_records.append(record)
		add_to_placement_grid(position)

	nature_records = valid_records

	rebuild_record_grid()

	print(
		"NatureSpawner: Restored ",
		nature_records.size(),
		" nature records."
	)


# --------------------------------------------------
# SPATIAL INDEX
# --------------------------------------------------

func rebuild_record_grid() -> void:
	record_grid.clear()

	for record in nature_records:
		if not record is Dictionary:
			continue

		var position: Variant = record.get("position")

		if not position is Vector2:
			continue

		var cell: Vector2i = get_record_cell(position)

		if not record_grid.has(cell):
			record_grid[cell] = []

		record_grid[cell].append(record)


# --------------------------------------------------
# LOADING AND UNLOADING
# --------------------------------------------------

func update_loaded_objects() -> void:
	if not is_instance_valid(player):
		return

	# Clean up references to nodes that have already been deleted.
	clean_invalid_spawned_objects()

	var player_position: Vector2 = player.global_position
	var radius_squared: float = load_radius * load_radius

	var nearby_records: Dictionary = {}

	var player_cell: Vector2i = get_record_cell(player_position)
	var cell_radius: int = ceili(
		load_radius / RECORD_CELL_SIZE
	) + 1

	# Search only nearby spatial cells.
	for cy in range(
		player_cell.y - cell_radius,
		player_cell.y + cell_radius + 1
	):
		for cx in range(
			player_cell.x - cell_radius,
			player_cell.x + cell_radius + 1
		):
			var cell: Vector2i = Vector2i(cx, cy)
			var records: Array = record_grid.get(cell, [])

			for record in records:
				if not record is Dictionary:
					continue

				var position: Variant = record.get("position")

				if not position is Vector2:
					continue

				if player_position.distance_squared_to(position) > radius_squared:
					continue

				var instance_id: String = str(
					record.get("instance_id", "")
				)

				if instance_id.is_empty():
					continue

				nearby_records[instance_id] = record

	# Spawn nearby records that are not loaded.
	for instance_id in nearby_records:
		if not spawned_objects.has(instance_id):
			spawn_record(nearby_records[instance_id])

	# Unload distant objects without deleting saved records.
	var loaded_ids: Array = spawned_objects.keys()

	for instance_id in loaded_ids:
		if nearby_records.has(instance_id):
			continue

		var object: Variant = spawned_objects.get(instance_id)

		if not is_instance_valid(object):
			spawned_objects.erase(instance_id)
			remove_nature_record(str(instance_id))
			continue

		if object.is_queued_for_deletion():
			spawned_objects.erase(instance_id)
			continue

		# Mark the deletion as temporary before queue_free().
		object.set_meta("nature_unloading", true)

		spawned_objects.erase(instance_id)
		object.queue_free()


func spawn_record(record: Dictionary) -> void:
	var id: String = str(record.get("id", ""))
	var instance_id: String = str(record.get("instance_id", ""))

	if instance_id.is_empty():
		return

	if spawned_objects.has(instance_id):
		var existing: Variant = spawned_objects[instance_id]

		if is_instance_valid(existing):
			return

		spawned_objects.erase(instance_id)

	var scene: PackedScene

	match id:
		"tree":
			scene = tree_scene
		"azura":
			scene = azura_scene
		_:
			push_warning("NatureSpawner: Unknown nature type: " + id)
			return

	if scene == null:
		push_warning("NatureSpawner: No scene assigned for " + id)
		return

	var position: Variant = record.get("position")

	if not position is Vector2:
		push_warning(
			"NatureSpawner: Invalid position for " + instance_id
		)
		return

	var instance: Node = scene.instantiate()

	if not instance is Node2D:
		push_warning(
			"NatureSpawner: Nature scenes need a Node2D root."
		)
		instance.free()
		return

	var object: Node2D = instance as Node2D

	# Listen for the node leaving the scene tree.
	object.tree_exiting.connect(
		_on_spawned_object_tree_exiting.bind(instance_id, object)
	)

	add_child(object)

	object.global_position = position
	object.rotation = float(record.get("rotation", 0.0))

	spawned_objects[instance_id] = object


# --------------------------------------------------
# DELETION AND CLEANUP
# --------------------------------------------------

func _on_spawned_object_tree_exiting(
	instance_id: String,
	object: Node2D
) -> void:
	# The spawner intentionally unloaded this object.
	# Keep its saved record so it can be spawned again.
	if is_instance_valid(object):
		if object.has_meta("nature_unloading"):
			if bool(object.get_meta("nature_unloading")):
				return

	# An externally deleted object should not respawn.
	if spawned_objects.get(instance_id) == object:
		spawned_objects.erase(instance_id)

	remove_nature_record(instance_id)


func clean_invalid_spawned_objects() -> void:
	if is_cleaning:
		return

	is_cleaning = true

	var loaded_ids: Array = spawned_objects.keys()

	for instance_id in loaded_ids:
		var object: Variant = spawned_objects.get(instance_id)

		if not is_instance_valid(object):
			spawned_objects.erase(instance_id)
			remove_nature_record(str(instance_id))
			continue

		if object.is_queued_for_deletion():
			spawned_objects.erase(instance_id)

			var unloading: bool = (
				object.has_meta("nature_unloading")
				and bool(object.get_meta("nature_unloading"))
			)

			if not unloading:
				remove_nature_record(str(instance_id))

	is_cleaning = false



func remove_nature_record(instance_id: String) -> void:
	var removed: bool = false

	for i in range(nature_records.size() - 1, -1, -1):
		var record: Variant = nature_records[i]

		if not record is Dictionary:
			continue

		if str(record.get("instance_id", "")) == instance_id:
			nature_records.remove_at(i)
			removed = true

	if not removed:
		return

	rebuild_record_grid()

	# Update the data in memory, but don't write the entire world to disk.
	WorldSave.set_nature_data(nature_records)

	print("NatureSpawner: Removed ", instance_id)



# Call this from a tree/Azura script if it is destroyed without queue_free().
func permanently_remove_object(instance_id: String) -> void:
	var object: Variant = spawned_objects.get(instance_id)

	if is_instance_valid(object):
		if object.has_meta("nature_unloading"):
			object.remove_meta("nature_unloading")

		spawned_objects.erase(instance_id)
		object.queue_free()

	remove_nature_record(instance_id)


# --------------------------------------------------
# SPACING
# --------------------------------------------------

func has_spacing(position: Vector2, spacing: float) -> bool:
	if spacing <= 0.0:
		return true

	var cell: Vector2i = get_placement_cell(position)
	var radius: int = ceili(spacing / SPATIAL_CELL_SIZE)

	for cy in range(cell.y - radius, cell.y + radius + 1):
		for cx in range(cell.x - radius, cell.x + radius + 1):
			var key: Vector2i = Vector2i(cx, cy)
			var positions: Array = placement_grid.get(key, [])

			for other_position in positions:
				if position.distance_to(other_position) < spacing:
					return false

	return true


func add_to_placement_grid(position: Vector2) -> void:
	var key: Vector2i = get_placement_cell(position)

	if not placement_grid.has(key):
		placement_grid[key] = []

	placement_grid[key].append(position)


func get_placement_cell(position: Vector2) -> Vector2i:
	return Vector2i(
		floori(position.x / SPATIAL_CELL_SIZE),
		floori(position.y / SPATIAL_CELL_SIZE)
	)


func get_record_cell(position: Vector2) -> Vector2i:
	return Vector2i(
		floori(position.x / RECORD_CELL_SIZE),
		floori(position.y / RECORD_CELL_SIZE)
	)
