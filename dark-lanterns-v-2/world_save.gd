
extends Node

signal save_requested
signal world_loaded

const SAVE_PATH: String = "user://world.save"
const SAVE_VERSION: int = 1

var world_data: Dictionary = {}
var is_loaded: bool = false
var is_dirty: bool = false


func _ready() -> void:
	load_world()


# --------------------------------------------------
# LOADING AND INITIALISING
# --------------------------------------------------

func load_world() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		_create_new_world_data()
		is_loaded = true
		is_dirty = true
		print("WorldSave: Created new world data.")
		world_loaded.emit()
		return false

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)

	if file == null:
		push_error("WorldSave: Could not open save file for reading.")
		return false

	var loaded_data: Variant = file.get_var()
	file.close()

	if not loaded_data is Dictionary:
		push_error("WorldSave: Save file is invalid.")
		return false

	if loaded_data.get("save_version", -1) != SAVE_VERSION:
		push_error("WorldSave: Save version mismatch.")
		return false

	world_data = loaded_data
	_ensure_world_sections()

	is_loaded = true
	is_dirty = false

	print("WorldSave: World loaded successfully.")
	world_loaded.emit()
	return true


func _create_new_world_data() -> void:
	world_data = {
		"save_version": SAVE_VERSION,
		"world_seed": 1111,
		"world_width": 1024,
		"world_height": 1024,
		"pixel_scale": 2,

		"spawn_positions": {
			"player": null,
			"campfire": null
		},

		"tile_types": PackedByteArray(),
		"terrain_png": PackedByteArray(),
		"resources": {},
		"nature": [],
		"nature_generated": false,

		# Arbitrary data submitted by individual scripts.
		"saved_values": {}
	}


func _ensure_world_sections() -> void:
	if not world_data.has("spawn_positions"):
		world_data["spawn_positions"] = {
			"player": null,
			"campfire": null
		}

	if not world_data.has("tiles"):
		world_data["tiles"] = []

	if not world_data.has("resources"):
		world_data["resources"] = {}

	if not world_data.has("world_seed"):
		world_data["world_seed"] = 1111

	if not world_data.has("tile_types"):
		world_data["tile_types"] = PackedByteArray()

	if not world_data.has("terrain_png"):
		world_data["terrain_png"] = PackedByteArray()

	if not world_data.has("nature"):
		world_data["nature"] = []

	if not world_data.has("nature_generated"):
		world_data["nature_generated"] = false

	if not world_data.has("saved_values"):
		world_data["saved_values"] = {}


# --------------------------------------------------
# SAVING TO DISK
# --------------------------------------------------

func save_world() -> bool:
	if not is_loaded:
		push_error("WorldSave: Cannot save before world data is loaded.")
		return false

	# Ask every connected system to submit its latest state.
	save_requested.emit()

	# The signal may have changed the data, so check dirty afterwards.
	if not is_dirty:
		return true

	world_data["save_version"] = SAVE_VERSION

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file == null:
		push_error("WorldSave: Could not open save file for writing.")
		return false

	file.store_var(world_data)
	file.close()

	is_dirty = false
	print("WorldSave: World saved successfully.")
	return true


# --------------------------------------------------
# GENERAL SAVE / LOAD API
# --------------------------------------------------

func save(key: String, value: Variant) -> void:
	if key.is_empty():
		push_warning("WorldSave: Cannot save an empty key.")
		return

	var values: Dictionary = world_data.get("saved_values", {})

	if values.has(key) and values[key] == value:
		return

	values[key] = value
	world_data["saved_values"] = values
	is_dirty = true


func load_value(key: String, default_value: Variant = null) -> Variant:
	var values: Dictionary = world_data.get("saved_values", {})
	return values.get(key, default_value)


func has_saved_value(key: String) -> bool:
	var values: Dictionary = world_data.get("saved_values", {})
	return values.has(key)


func delete_saved_value(key: String) -> void:
	var values: Dictionary = world_data.get("saved_values", {})

	if values.has(key):
		values.erase(key)
		world_data["saved_values"] = values
		is_dirty = true


# --------------------------------------------------
# GENERAL WORLD DATA
# --------------------------------------------------

func get_world_value(key: String, default_value: Variant = null) -> Variant:
	return world_data.get(key, default_value)


func set_world_value(key: String, value: Variant) -> void:
	if world_data.get(key) == value:
		return

	world_data[key] = value
	is_dirty = true


# --------------------------------------------------
# SPAWN POSITIONS
# --------------------------------------------------

func get_spawn_position(spawn_id: String) -> Variant:
	var positions: Dictionary = world_data.get("spawn_positions", {})
	return positions.get(spawn_id)


func set_spawn_position(spawn_id: String, position: Vector2) -> void:
	var positions: Dictionary = world_data.get("spawn_positions", {})

	if positions.get(spawn_id) == position:
		return

	positions[spawn_id] = position
	world_data["spawn_positions"] = positions
	is_dirty = true


# --------------------------------------------------
# TERRAIN / TILE DATA
# --------------------------------------------------

func get_tile_data() -> PackedByteArray:
	var data: Variant = world_data.get("tile_types", PackedByteArray())

	if data is PackedByteArray:
		return data

	return PackedByteArray()


func set_tile_data(tile_data: PackedByteArray) -> void:
	world_data["tile_types"] = tile_data
	is_dirty = true


func get_terrain_png() -> PackedByteArray:
	var data: Variant = world_data.get("terrain_png", PackedByteArray())

	if data is PackedByteArray:
		return data

	return PackedByteArray()


func set_terrain_png(png_data: PackedByteArray) -> void:
	world_data["terrain_png"] = png_data
	is_dirty = true


# --------------------------------------------------
# RESOURCE DATA
# --------------------------------------------------

func get_resource_data() -> Dictionary:
	var data: Variant = world_data.get("resources", {})

	if data is Dictionary:
		return data

	return {}


func set_resource_data(resources: Dictionary) -> void:
	world_data["resources"] = resources
	is_dirty = true


# --------------------------------------------------
# NATURE DATA
# --------------------------------------------------

func get_nature_data() -> Array:
	var data: Variant = world_data.get("nature", [])

	if data is Array:
		return data

	return []


func set_nature_data(data: Array) -> void:
	world_data["nature"] = data
	is_dirty = true


func is_nature_generated() -> bool:
	return world_data.get("nature_generated", false)


func set_nature_generated(value: bool) -> void:
	if world_data.get("nature_generated", false) == value:
		return

	world_data["nature_generated"] = value
	is_dirty = true


# --------------------------------------------------
# TESTING
# --------------------------------------------------

func _test_save_system() -> void:
	set_spawn_position("player", Vector2(100, 200))
	set_spawn_position("campfire", Vector2(300, 400))
	save("test_value", 123)

	if save_world():
		print("Test player spawn: ", get_spawn_position("player"))
		print("Test value: ", load_value("test_value"))
