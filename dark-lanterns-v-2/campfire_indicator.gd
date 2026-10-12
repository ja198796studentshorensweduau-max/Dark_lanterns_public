
extends Control

@export var campfire: Node2D
@export var player: Node2D
@export var edge_margin: float = 36.0

@onready var arrow: TextureRect = $Arrow


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	arrow.pivot_offset = arrow.size / 2.0

	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(campfire):
		arrow.hide()
		return

	var direction: Vector2 = (
		campfire.global_position - player.global_position
	).normalized()

	if direction.length_squared() < 0.001:
		arrow.hide()
		return

	arrow.show()

	var screen_size: Vector2 = get_viewport_rect().size
	var centre: Vector2 = screen_size / 2.0

	var half_width: float = centre.x - edge_margin
	var half_height: float = centre.y - edge_margin

	var distance_x: float = INF
	var distance_y: float = INF

	if absf(direction.x) > 0.001:
		distance_x = half_width / absf(direction.x)

	if absf(direction.y) > 0.001:
		distance_y = half_height / absf(direction.y)

	var edge_distance: float = minf(distance_x, distance_y)

	var edge_position: Vector2 = centre + direction * edge_distance

	# Keep the arrow centred on the calculated edge position.
	arrow.position = edge_position - arrow.size / 2.0

	# The arrow texture points upwards at zero rotation.
	# Rotate it so its tip points towards the campfire.
	var screen_direction: Vector2 = edge_position - centre
	arrow.rotation = screen_direction.angle()
