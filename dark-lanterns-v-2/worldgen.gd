
extends Node2D

@export var world_width: int = 1024
@export var world_height: int = 1024
@export var pixel_scale: int = 2
@export var world_seed: int = 1

@export var border_width: int = 40
@export var border_colour: Color = Color("#10131a")

enum Terrain { WATER, SAND, GRASS, DIRT, ROCK, SNOW, ICE }

var elevation_noise := FastNoiseLite.new()
var temperature_noise := FastNoiseLite.new()
var moisture_noise := FastNoiseLite.new()
var detail_noise := FastNoiseLite.new()
var border_noise := FastNoiseLite.new()

var world_image: Image
var world_texture: ImageTexture
var world_sprite: Sprite2D
var tile_types: PackedByteArray = PackedByteArray()

const TILE_NAMES: PackedStringArray = [
	"water",
	"sand",
	"grass",
	"dirt",
	"rock",
	"snow",
	"ice",
	"border"
]

const BORDER_TILE_ID: int = 7

func _ready() -> void:
	generate_world()


func configure_noise(
	noise: FastNoiseLite,
	seed_offset: int,
	frequency: float
) -> void:
	noise.seed = world_seed + seed_offset
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.5
	noise.fractal_lacunarity = 2.0

func generate_world() -> void:
	var start_time: int = Time.get_ticks_msec()

	if load_saved_world():
		print(
			"World loaded from save in ",
			Time.get_ticks_msec() - start_time,
			" ms"
		)
		return

	generate_new_world()

	print(
		"World generated in ",
		Time.get_ticks_msec() - start_time,
		" ms"
	)
func load_saved_world() -> bool:
	var saved_width: int = WorldSave.get_world_value(
		"world_width", -1
	)
	var saved_height: int = WorldSave.get_world_value(
		"world_height", -1
	)
	var saved_scale: int = WorldSave.get_world_value(
		"pixel_scale", -1
	)

	if saved_width != world_width:
		return false

	if saved_height != world_height:
		return false

	if saved_scale != pixel_scale:
		return false

	var saved_tiles: PackedByteArray = WorldSave.get_tile_data()
	var expected_size: int = world_width * world_height

	if saved_tiles.size() != expected_size:
		return false

	var png_data: PackedByteArray = WorldSave.get_terrain_png()

	if png_data.is_empty():
		return false

	var cached_image: Image = Image.new()
	var error: Error = cached_image.load_png_from_buffer(png_data)

	if error != OK:
		push_warning("WorldGenerator: Cached terrain image is invalid.")
		return false

	if cached_image.get_width() != world_width:
		return false

	if cached_image.get_height() != world_height:
		return false

	# Restore the authoritative tile data.
	tile_types = saved_tiles
	Tiles.clear_tiles()

	for y in range(world_height):
		for x in range(world_width):
			var index: int = y * world_width + x
			var tile_id: int = int(tile_types[index])

			if tile_id < 0 or tile_id >= TILE_NAMES.size():
				push_warning("WorldGenerator: Invalid saved tile ID.")
				Tiles.clear_tiles()
				return false

			var tile_position := Vector2(
				(x + 0.5) * pixel_scale,
				(y + 0.5) * pixel_scale
			)

			Tiles.register_tile(
				x,
				y,
				tile_position,
				TILE_NAMES[tile_id]
			)

	world_image = cached_image
	apply_world_image()

	print("WorldGenerator: Restored ", expected_size, " tiles.")
	return true
func apply_world_image() -> void:
	world_texture = ImageTexture.create_from_image(world_image)

	if world_sprite == null:
		world_sprite = Sprite2D.new()
		world_sprite.name = "Terrain"
		world_sprite.centered = false
		world_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(world_sprite)

	world_sprite.texture = world_texture
	world_sprite.scale = Vector2(pixel_scale, pixel_scale)
	world_sprite.position = Vector2.ZERO
	world_sprite.z_index = -1
	
func generate_new_world() -> void:
	configure_noise(elevation_noise, 0, 0.0025)
	configure_noise(temperature_noise, 1000, 0.0015)
	configure_noise(moisture_noise, 2000, 0.003)
	configure_noise(detail_noise, 3000, 0.025)
	configure_noise(border_noise, 4000, 0.02)

	# Remove data from the previous generation.
	Tiles.clear_tiles()

	world_image = Image.create(
		world_width,
		world_height,
		false,
		Image.FORMAT_RGBA8
	)
	tile_types.resize(world_width * world_height)
	for y in range(world_height):
		for x in range(world_width):
			var elevation: float = elevation_noise.get_noise_2d(x, y)
			var temperature: float = temperature_noise.get_noise_2d(x, y)
			var moisture: float = moisture_noise.get_noise_2d(x, y)
			var detail: float = detail_noise.get_noise_2d(x, y)

			temperature -= maxf(elevation - 0.25, 0.0) * 1.2

			var terrain: Terrain = choose_terrain(
				elevation,
				temperature,
				moisture
			)

			var colour: Color = terrain_colour(terrain, detail)

			var edge_distance: float = minf(
				minf(float(x), float(y)),
				minf(
					float(world_width - 1 - x),
					float(world_height - 1 - y)
				)
			)

			var boundary: float = (
				float(border_width)
				+ border_noise.get_noise_2d(x, y) * 12.0
			)

			var tile_type: String = terrain_name(terrain)

			if edge_distance < boundary:
				colour = border_colour
				tile_type = "border"

			# Centre of this tile in Godot world coordinates.
			var tile_position := Vector2(
				(x + 0.5) * pixel_scale,
				(y + 0.5) * pixel_scale
			)

			# Save its position, reference and terrain type.
# Save the tile in the runtime dictionary.
			Tiles.register_tile(
				x,
				y,
				tile_position,
				tile_type
			)

			# Save its terrain type as a compact number.
			var tile_id: int = int(terrain)

			if tile_type == "border":
				tile_id = BORDER_TILE_ID

			tile_types[y * world_width + x] = tile_id

			# Save its colour in the terrain image.
			world_image.set_pixel(x, y, colour)


	# Display the generated terrain.
	apply_world_image()

	# Store world settings.
	WorldSave.set_world_value("world_width", world_width)
	WorldSave.set_world_value("world_height", world_height)
	WorldSave.set_world_value("pixel_scale", pixel_scale)
	WorldSave.set_world_value("world_seed", world_seed)

	# Store the terrain data and visual image.
	WorldSave.set_tile_data(tile_types)
	WorldSave.set_terrain_png(world_image.save_png_to_buffer())

	# Write the world save to disk.
	if not WorldSave.save_world():
		push_error("WorldGenerator: Failed to save generated world.")

	print("World generation finished. Registered tiles: ", Tiles.tiles.size())

func update_terrain_pixel(
	x: int,
	y: int,
	tile_type: String
) -> void:
	if world_image == null:
		return

	var terrain: Terrain

	match tile_type.to_lower():
		"water": terrain = Terrain.WATER
		"sand": terrain = Terrain.SAND
		"grass": terrain = Terrain.GRASS
		"dirt": terrain = Terrain.DIRT
		"rock": terrain = Terrain.ROCK
		"snow": terrain = Terrain.SNOW
		"ice": terrain = Terrain.ICE
		_:
			world_image.set_pixel(x, y, border_colour)
			apply_world_image()
			WorldSave.set_terrain_png(world_image.save_png_to_buffer())
			return

	var colour: Color = terrain_colour(terrain, 0.0)
	world_image.set_pixel(x, y, colour)

	apply_world_image()
	WorldSave.set_terrain_png(world_image.save_png_to_buffer())
func choose_terrain(
	elevation: float,
	temperature: float,
	moisture: float
) -> Terrain:
	if elevation < -0.24:
		return Terrain.WATER

	if elevation < -0.16:
		return Terrain.WATER

	if elevation < -0.08:
		return Terrain.SAND

	if elevation > 0.58:
		if temperature < 0.15:
			return Terrain.SNOW
		return Terrain.ROCK

	if temperature < -0.38:
		if elevation > 0.20:
			return Terrain.ICE
		return Terrain.SNOW

	if temperature > 0.20 and moisture < -0.20:
		return Terrain.SAND

	if elevation > 0.38:
		return Terrain.ROCK

	if moisture < -0.40:
		return Terrain.DIRT

	return Terrain.GRASS


func terrain_name(terrain: Terrain) -> String:
	match terrain:
		Terrain.WATER:
			return "water"
		Terrain.SAND:
			return "sand"
		Terrain.GRASS:
			return "grass"
		Terrain.DIRT:
			return "dirt"
		Terrain.ROCK:
			return "rock"
		Terrain.SNOW:
			return "snow"
		Terrain.ICE:
			return "ice"
		_:
			return "unknown"


func terrain_colour(terrain: Terrain, detail: float) -> Color:
	var variation: float = detail * 0.10
	var base_colour: Color

	match terrain:
		Terrain.WATER:
			base_colour = Color("#286b9b")
		Terrain.SAND:
			base_colour = Color("#d8bd78")
		Terrain.GRASS:
			base_colour = Color("#5c963f")
		Terrain.DIRT:
			base_colour = Color("#896344")
		Terrain.ROCK:
			base_colour = Color("#777b80")
		Terrain.SNOW:
			base_colour = Color("#e5edf0")
		Terrain.ICE:
			base_colour = Color("#8dcbd8")
		_:
			base_colour = Color.MAGENTA

	return Color(
		clampf(base_colour.r + variation, 0.0, 1.0),
		clampf(base_colour.g + variation, 0.0, 1.0),
		clampf(base_colour.b + variation, 0.0, 1.0),
		1.0
	)


func regenerate() -> void:
	generate_world()
