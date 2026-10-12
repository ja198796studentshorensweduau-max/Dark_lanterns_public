
extends Node2D

const TILE_SIZE: float = 2.0
const VALIDATION_DELAY: float = 1.0

const PENDING_COLOR := Color(0.65, 0.65, 0.65, 0.55)
const VALID_COLOR := Color(0.55, 1.0, 0.65, 0.85)
const INVALID_COLOR := Color(1.0, 0.2, 0.2, 0.45)

var sprite: Sprite2D
var recipe: Dictionary = {}

var validation_timer: float = 0.0
var is_valid: bool = false
var has_validated: bool = false
var placement_finished: bool = false
var is_cancelled: bool = false

# 0 = horizontal, 1 = vertical
var orientation: int = 0

# Stores the recipe and transform for permanent buildings.
var placed_structures: Array[Dictionary] = []


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.centered = true
	sprite.z_index = 100
	add_child(sprite)

	z_index = 100

	set_process(true)
	set_process_input(true)

	if not WorldSave.save_requested.is_connected(_save_structures):
		WorldSave.save_requested.connect(_save_structures)

	# Wait for WorldSave and the world to initialise.
	await get_tree().process_frame
	await get_tree().process_frame

	_load_structures()


func setup(new_recipe: Dictionary) -> void:
	recipe = new_recipe.duplicate(true)
	orientation = 0

	validation_timer = 0.0
	is_valid = false
	has_validated = false
	placement_finished = false
	is_cancelled = false

	update_preview_texture()
	update_preview_color()


func _process(delta: float) -> void:
	if placement_finished or is_cancelled or recipe.is_empty():
		return

	var mouse_position := get_global_mouse_position()

	global_position = Vector2(
		floor(mouse_position.x / TILE_SIZE) * TILE_SIZE + TILE_SIZE / 2.0,
		floor(mouse_position.y / TILE_SIZE) * TILE_SIZE + TILE_SIZE / 2.0
	)

	if not has_validated:
		validation_timer += delta

		if validation_timer >= VALIDATION_DELAY:
			is_valid = validate_placement()
			has_validated = true
			update_preview_color()

	if Input.is_action_just_pressed("build_confirm"):
		if has_validated and is_valid:
			place_building()


func _input(event: InputEvent) -> void:
	if placement_finished or is_cancelled or recipe.is_empty():
		return

	# Escape cancels the preview without placing anything.
	if event.is_action_pressed("ui_cancel"):
		is_cancelled = true
		queue_free()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("rotate_building"):
		orientation = 1 - orientation
		update_preview_texture()
		reset_validation()
		get_viewport().set_input_as_handled()


func update_preview_texture() -> void:
	if recipe.is_empty() or sprite == null:
		return

	var texture_key: String = (
		"vertical_texture" if orientation == 1 else "texture"
	)

	var texture_path: String = str(
		recipe.get(texture_key, recipe.get("texture", ""))
	)

	if texture_path.is_empty():
		push_error("[Build] No texture specified for recipe.")
		return

	var texture := load(texture_path) as Texture2D

	if texture == null:
		push_error("[Build] Failed to load texture: " + texture_path)
		return

	sprite.texture = texture

	var dimensions: Vector2i = get_footprint_dimensions()
	var target_size := Vector2(dimensions) * TILE_SIZE

	sprite.scale = Vector2(
		target_size.x / texture.get_width(),
		target_size.y / texture.get_height()
	)


func get_footprint_dimensions() -> Vector2i:
	var dimensions: Vector2i = recipe.get(
		"dimensions",
		Vector2i(1, 1)
	)

	if orientation == 1:
		return Vector2i(dimensions.y, dimensions.x)

	return dimensions


func get_footprint_start() -> Vector2i:
	var dimensions := get_footprint_dimensions()

	var centre_x := int(floor(global_position.x / TILE_SIZE))
	var centre_y := int(floor(global_position.y / TILE_SIZE))

	return Vector2i(
		centre_x - int(dimensions.x / 2),
		centre_y - int(dimensions.y / 2)
	)


func validate_placement() -> bool:
	if recipe.is_empty():
		return false

	var dimensions := get_footprint_dimensions()
	var start := get_footprint_start()
	var allowed_tiles: Array = recipe.get("allowed_tiles", [])

	for x in range(dimensions.x):
		for y in range(dimensions.y):
			var tile_data = Tiles.get_tile_at_grid(
				start.x + x,
				start.y + y
			)

			if tile_data == null or tile_data.is_empty():
				return false

			var tile_type: String = str(
				tile_data.get("type", "")
			).to_lower()

			if not allowed_tiles.map(
				func(tile): return str(tile).to_lower()
			).has(tile_type):
				return false

	return can_afford()


func can_afford() -> bool:
	var cost: Dictionary = recipe.get("cost", {})

	for item_id in cost:
		var required_amount: int = int(cost[item_id])
		var current_amount: int = 0

		for inventory_item in Inventory.items:
			if str(inventory_item).to_lower() == str(item_id).to_lower():
				current_amount = int(Inventory.items[inventory_item])
				break

		if current_amount < required_amount:
			return false

	return true


func update_preview_color() -> void:
	if sprite == null:
		return

	if not has_validated:
		sprite.modulate = PENDING_COLOR
	elif is_valid:
		sprite.modulate = VALID_COLOR
	else:
		sprite.modulate = INVALID_COLOR


func reset_validation() -> void:
	validation_timer = 0.0
	has_validated = false
	is_valid = false
	update_preview_color()


func place_building() -> void:
	if placement_finished or is_cancelled or not has_validated or not is_valid:
		return

	if not can_afford():
		reset_validation()
		return

	var dimensions := get_footprint_dimensions()
	var start := get_footprint_start()
	var transformed_tile: String = str(
		recipe.get("transform_tile", "")
	)

	# Transform the tiles underneath the building.
	for x in range(dimensions.x):
		for y in range(dimensions.y):
			Tiles.set_tile_type_at_grid(
				start.x + x,
				start.y + y,
				transformed_tile
			)

	# Deduct the recipe costs.
	var cost: Dictionary = recipe.get("cost", {})

	for item_id in cost:
		var required_amount: int = int(cost[item_id])
		var inventory_key = null

		for inventory_item in Inventory.items:
			if str(inventory_item).to_lower() == str(item_id).to_lower():
				inventory_key = inventory_item
				break

		if inventory_key != null:
			Inventory.items[inventory_key] -= required_amount

			if Inventory.items[inventory_key] <= 0:
				Inventory.items.erase(inventory_key)

			Inventory.inventory_changed.emit(
				str(inventory_key),
				int(Inventory.items.get(inventory_key, 0))
			)

	# Record the permanent structure.
	placed_structures.append({
		"position": global_position,
		"orientation": orientation,
		"recipe": recipe.duplicate(true)
	})

	# Leave the sprite in the world.
	placement_finished = true
	sprite.modulate = Color.WHITE

	z_index = 5
	sprite.z_index = 5
	sprite.z_as_relative = false

	set_process(false)
	set_process_input(false)


# --------------------------------------------------
# SAVING
# --------------------------------------------------

func _save_structures() -> void:
	# A preview is not a placed structure.
	WorldSave.save("built_structures", placed_structures.duplicate(true))


# --------------------------------------------------
# LOADING
# --------------------------------------------------

func _load_structures() -> void:
	var saved: Variant = WorldSave.load_value("built_structures", [])

	if not saved is Array:
		return

	for data in saved:
		if not data is Dictionary:
			continue

		var saved_position: Variant = data.get("position", null)
		var saved_recipe: Variant = data.get("recipe", {})
		var saved_orientation: int = int(data.get("orientation", 0))

		if not saved_position is Vector2 or not saved_recipe is Dictionary:
			continue

		_create_saved_structure(
			saved_position,
			saved_recipe,
			saved_orientation
		)


func _create_saved_structure(
	saved_position: Vector2,
	saved_recipe: Dictionary,
	saved_orientation: int
) -> void:
	# Each permanent structure gets its own instance of this script.
	var building := Node2D.new()
	building.set_script(get_script())
	get_parent().add_child(building)

	# Initialise it as a permanent building, not a mouse-following preview.
	building.setup(saved_recipe)
	building.orientation = saved_orientation
	building.global_position = saved_position
	building.placement_finished = true

	building.set_process(false)
	building.set_process_input(false)

	building.update_preview_texture()
	building.sprite.modulate = Color.WHITE
	building.sprite.z_index = 5
	building.sprite.z_as_relative = false
	building.z_index = 5

	# Copy saved structures into the instance so it can participate in saving.
	building.placed_structures = []
	building.add_to_group("placed_buildings")
