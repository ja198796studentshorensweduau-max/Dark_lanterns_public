
extends Node

# Every tile is stored by its unique grid reference.
# Example: "AB26" -> tile information.
var tiles: Dictionary = {}


func _ready() -> void:
	# Restore saved tile data.
	var saved_tiles: Variant = WorldSave.load_value("tiles", {})

	if saved_tiles is Dictionary and not saved_tiles.is_empty():
		tiles = saved_tiles.duplicate(true)

	# Save the current tile dictionary when requested.
	if not WorldSave.save_requested.is_connected(_save_tiles):
		WorldSave.save_requested.connect(_save_tiles)


func _save_tiles() -> void:
	WorldSave.save("tiles", tiles.duplicate(true))


func clear_tiles() -> void:
	tiles.clear()


func make_grid_reference(x: int, y: int) -> String:
	# Convert zero-based X into spreadsheet-style letters:
	# 0 = A, 25 = Z, 26 = AA, 27 = AB.
	var column_number: int = x + 1
	var column_name: String = ""

	while column_number > 0:
		var remainder: int = (column_number - 1) % 26
		column_name = String.chr(65 + remainder) + column_name
		column_number = int((column_number - 1) / 26)

	# Rows start at 1, not 0.
	return column_name + str(y + 1)


func set_tile_type_at_grid(
	x: int,
	y: int,
	tile_type: String
) -> bool:
	var reference: String = make_grid_reference(x, y)

	if not tiles.has(reference):
		return false

	tiles[reference]["type"] = tile_type

	# Update the saved terrain byte array as well.
	var index: int = y * int(WorldSave.get_world_value("world_width", 1024)) + x
	var tile_data: PackedByteArray = WorldSave.get_tile_data()

	if index >= 0 and index < tile_data.size():
		var tile_id: int = -1

		match tile_type.to_lower():
			"water": tile_id = 0
			"sand": tile_id = 1
			"grass": tile_id = 2
			"dirt": tile_id = 3
			"rock": tile_id = 4
			"snow": tile_id = 5
			"ice": tile_id = 6
			"border": tile_id = 7

		if tile_id != -1:
			tile_data[index] = tile_id
			WorldSave.set_tile_data(tile_data)

	return true


func register_tile(
	x: int,
	y: int,
	world_position: Vector2,
	tile_type: String
) -> void:
	var reference: String = make_grid_reference(x, y)

	tiles[reference] = {
		"world_position": world_position,
		"grid_reference": reference,
		"type": tile_type
	}


func get_tile_by_ref(reference: String) -> Dictionary:
	return tiles.get(reference.to_upper(), {})


func get_tile_at_grid(x: int, y: int) -> Dictionary:
	var reference: String = make_grid_reference(x, y)
	return get_tile_by_ref(reference)
