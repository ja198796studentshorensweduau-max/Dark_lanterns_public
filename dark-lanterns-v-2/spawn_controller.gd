
extends Node
class_name SpawnCreator

@export var max_search_attempts: int = 5000
@export var tile_size: int = 2


# Returns a world position, or Vector2.INF if no valid spawn exists.
func find_spawn_point(allowed_terrain: Array, radius: int = 1) -> Vector2:
	if Tiles.tiles.is_empty():
		push_warning("SpawnCreator: No tiles registered!")
		return Vector2.INF

	var candidates: Array = Tiles.tiles.values()
	candidates.shuffle()

	var attempts := 0

	for tile in candidates:
		if attempts >= max_search_attempts:
			break

		attempts += 1

		if is_valid_spawn_point(tile, allowed_terrain, radius):
			var grid_reference: String = tile.get("grid_reference", "")
			var grid := _get_grid_coordinates(grid_reference)

			if grid.is_empty():
				continue

			# Convert grid coordinates into world coordinates.
			return Vector2(
				grid.x * tile_size,
				grid.y * tile_size
			)

	push_warning("SpawnCreator: No valid spawn point found!")
	return Vector2.INF


# Checks the centre tile and every tile in its square neighbourhood.
func is_valid_spawn_point(
	tile: Dictionary,
	allowed_terrain: Array,
	radius: int = 1
) -> bool:
	if not allowed_terrain.has(tile.get("type", "")):
		return false

	var grid_reference: String = tile.get("grid_reference", "")
	if grid_reference.is_empty():
		return false

	var centre_grid := _get_grid_coordinates(grid_reference)
	if centre_grid.is_empty():
		return false

	for y_offset in range(-radius, radius + 1):
		for x_offset in range(-radius, radius + 1):
			var neighbour_ref: String = Tiles.make_grid_reference(
				centre_grid.x + x_offset,
				centre_grid.y + y_offset
			)

			var neighbour: Dictionary = Tiles.get_tile_by_ref(neighbour_ref)

			if neighbour.is_empty():
				return false

			if not allowed_terrain.has(neighbour.get("type", "")):
				return false

	return true


# Converts references such as A1, A2, B1 and AB26 to grid coordinates.
# A1 = (0, 0), A2 = (1, 0), B1 = (0, 1).
func _get_grid_coordinates(reference: String) -> Dictionary:
	var column_text := ""
	var row_text := ""

	for character in reference:
		if character.is_valid_int():
			row_text += character
		else:
			column_text += character

	if column_text.is_empty() or row_text.is_empty():
		return {}

	var x := 0

	for character in column_text:
		x = x * 26 + character.unicode_at(0) - 64

	return {
		"x": x - 1,
		"y": int(row_text) - 1
	}
