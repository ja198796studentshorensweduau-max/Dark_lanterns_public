extends Node2D
class_name Campfire

signal energy_changed(current: float, maximum: float)
signal campfire_destroyed
signal campfire_depleted
@export_group("Interaction")
@export var click_radius: float = 24.0

@export var click_area: Area2D
var campfire_menu: CampfireMenu
@export_group("Energy")
@export var max_energy: float = 1000.0
@export var starting_energy: float = 1000.0
@export var passive_drain_per_second: float = 2.0
@export var brightness_energy_cost: float = 10.0
@export var energy_per_wood: float = 5.0

@export_group("Brightness")
@export var brightness_per_tick: float = 10.0
@export var restoration_interval: float = 3.0

@export_group("Combat")
@export var max_health: float = 200.0
@export var enemy_damage_per_second: float = 10.0
@export var enemy_damage_interval: float = 1.0

@onready var spawncontroller = $"../SpawnController"
@onready var effect_area = $EffectArea
@onready var world_generator = $".."
@onready var animation = $AnimatedSprite2D

var energy: float
var health: float

var restoration_timer: float = 0.0
var damage_timer: float = 0.0
var is_destroyed: bool = false
var was_depleted: bool = false


func _ready() -> void:
	setup_click_area()

	await world_generator.ready
	await get_tree().process_frame

	get_spawn()

	energy = clampf(starting_energy, 0.0, max_energy)
	health = max_health
	was_depleted = energy <= 0.0

	energy_changed.emit(energy, max_energy)

	if was_depleted:
		animation.play("Out")
	else:
		animation.play("Lit")

func setup_click_area() -> void:
	click_area = Area2D.new()
	click_area.name = "ClickArea"
	click_area.input_pickable = true
	add_child(click_area)

	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = click_radius
	collision.shape = circle

	click_area.add_child(collision)

	click_area.input_event.connect(_on_campfire_input_event)


func _on_campfire_input_event(
	_viewport: Node,
	event: InputEvent,
	_shape_idx: int
) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			open_campfire_menu()
			get_viewport().set_input_as_handled()


func open_campfire_menu() -> void:
	if is_destroyed:
		return

	if is_instance_valid(campfire_menu):
		return

	campfire_menu = CampfireMenu.new()
	campfire_menu.setup(self)

	get_tree().root.add_child(campfire_menu)

	# Stop gameplay while the menu is open.
	get_tree().paused = true
func get_spawn() -> void:
	var saved_spawn: Variant = WorldSave.get_spawn_position("campfire")

	if saved_spawn is Vector2:
		global_position = saved_spawn
		print("Campfire: Loaded saved spawn at ", saved_spawn)
		return

	var spawn: Vector2 = spawncontroller.find_spawn_point(
		["grass", "dirt"],
		3
	)

	if spawn == Vector2.INF:
		push_error("Campfire: Could not find a valid spawn point.")
		return

	global_position = spawn
	WorldSave.set_spawn_position("campfire", spawn)

	if not WorldSave.save_world():
		push_error("Campfire: Failed to save spawn position.")

	print("Campfire: Generated and saved spawn at ", spawn)


func _process(delta: float) -> void:
	if is_destroyed:
		return

	# An extinguished campfire does nothing until refuelled.
	if energy <= 0.0:
		animation.play("Out")
		return

	# Consume energy over time.
	consume_energy(passive_drain_per_second * delta)

	# Stop immediately if the drain extinguished the fire.
	if energy <= 0.0:
		animation.play("Out")
		return

	animation.play("Lit")

	# Restore nearby players at fixed intervals.
	restoration_timer += delta

	if restoration_timer >= restoration_interval:
		restoration_timer -= restoration_interval
		restore_nearby_players()

	if energy <= 0.0:
		animation.play("Out")
		return

	# Damage nearby enemies at fixed intervals.
	damage_timer += delta

	if damage_timer >= enemy_damage_interval:
		damage_timer -= enemy_damage_interval
		damage_nearby_enemies()


func restore_nearby_players() -> void:
	if energy < brightness_energy_cost:
		return

	var players = effect_area.get_overlapping_bodies()

	for body in players:
		if body.is_in_group("player"):
			if body.has_method("change_brightness"):
				consume_energy(brightness_energy_cost)

				if energy <= 0.0:
					animation.play("Out")
					return

				body.change_brightness(brightness_per_tick)
				return


func damage_nearby_enemies() -> void:
	if energy <= 0.0 or is_destroyed:
		return

	var enemies = effect_area.get_overlapping_bodies()

	for enemy in enemies:
		if enemy.is_in_group("enemies"):
			if enemy.has_method("take_damage"):
				enemy.take_damage(
					enemy_damage_per_second * enemy_damage_interval
				)


func consume_energy(amount: float) -> void:
	if amount <= 0.0 or energy <= 0.0:
		return

	var previous_energy := energy
	energy = maxf(energy - amount, 0.0)

	if energy != previous_energy:
		energy_changed.emit(energy, max_energy)

	if energy <= 0.0 and not was_depleted:
		was_depleted = true
		animation.play("Out")
		campfire_depleted.emit()


func add_wood() -> void:
	if is_destroyed:
		return

	var previous_energy := energy
	energy = minf(energy + energy_per_wood, max_energy)

	if energy > 0.0:
		was_depleted = false
		animation.play("Lit")

	if energy != previous_energy:
		energy_changed.emit(energy, max_energy)


func take_damage(amount: float) -> void:
	if is_destroyed or amount <= 0.0:
		return

	health = maxf(health - amount, 0.0)

	if health <= 0.0:
		is_destroyed = true
		campfire_destroyed.emit()
		animation.play("Out")


func get_energy_ratio() -> float:
	if max_energy <= 0.0:
		return 0.0

	return energy / max_energy
