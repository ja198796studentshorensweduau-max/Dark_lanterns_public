
extends Area2D

@export var starting_speed: float = 18.0
@export var acceleration: float = 30.0
@export var max_speed: float = 65.0

@export var starting_damage: float = 15.0
@export var max_damage: float = 45.0

@export var lifetime: float = 3.0
@export var melt_duration: float = 0.35
@onready var animation = $AnimatedSprite2D
var direction: Vector2 = Vector2.RIGHT
var current_speed: float
var age: float = 0.0
var has_hit: bool = false

@onready var animation_player: AnimationPlayer = (
	get_node_or_null("AnimationPlayer") as AnimationPlayer
)


func _ready() -> void:
	
	current_speed = starting_speed

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	animation.play("accellerate_v1")

func _physics_process(delta: float) -> void:
	if has_hit:
		return

	age += delta

	# Accelerate as the fireball travels.
	current_speed = minf(
		current_speed + acceleration * delta,
		max_speed
	)

	global_position += direction.normalized() * current_speed * delta

	# Damage increases as the fireball speeds up.
	var speed_progress: float = (
		(current_speed - starting_speed)
		/ maxf(max_speed - starting_speed, 1.0)
	)

	speed_progress = clampf(speed_progress, 0.0, 1.0)

	var current_damage: float = lerpf(
		starting_damage,
		max_damage,
		speed_progress
	)

	# Expire after the configured lifetime.
	if age >= lifetime:
		melt_away()


func _on_body_entered(body: Node2D) -> void:
	if has_hit:
		return

	if body.has_method("take_damage"):
		body.take_damage(get_current_damage())

	melt_away()


func _on_area_entered(area: Area2D) -> void:
	if has_hit:
		return

	var target: Node = area

	if not target.has_method("take_damage"):
		target = area.get_parent()

	if target.has_method("take_damage"):
		target.take_damage(get_current_damage())
	elif area.has_method("receive_damage"):
		area.receive_damage(get_current_damage())

	melt_away()


func get_current_damage() -> float:
	var speed_progress: float = (
		(current_speed - starting_speed)
		/ maxf(max_speed - starting_speed, 1.0)
	)

	return lerpf(
		starting_damage,
		max_damage,
		clampf(speed_progress, 0.0, 1.0)
	)


func melt_away() -> void:
	if has_hit:
		return

	has_hit = true

	if animation_player != null and animation_player.has_animation("melt"):
		animation_player.play("melt")
		await animation_player.animation_finished
	else:
		await get_tree().create_timer(melt_duration).timeout

	queue_free()
