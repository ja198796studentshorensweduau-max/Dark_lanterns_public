
extends Node

signal spawn_enemy_requested
@onready var hud = $"../HUD"
@onready var wave_title: Label = $CanvasLayer/WaveTitle
@onready var canvas_modulate: CanvasModulate = (
	get_tree().current_scene.get_node("DarknessOverlay")
)
@export var normal_speed_multiplier: float = 1.0
@export var darkness_speed_multiplier: float = 1.5

var current_speed_multiplier: float = 1.0
@export var peace_duration: float = 30.0
@export var wave_duration: float = 45.0

@export var peace_spawn_interval: float = 5.0
@export var wave_spawn_interval: float = 0.5

@export var fade_duration: float = 2.0
@export var title_typing_duration: float = 2.0

# White = normal lighting; near-black = wave darkness.
@export var normal_color: Color = Color.WHITE
@export var wave_color: Color = Color(0.015, 0.015, 0.025)

var current_wave: int = 0
var is_wave_active: bool = false

var phase_timer: float = 0.0
var spawn_timer: float = 0.0

var transition_tween: Tween


func _ready() -> void:
	canvas_modulate.color = normal_color
	wave_title.visible = false
	wave_title.visible_characters = 0


func _process(delta: float) -> void:
	phase_timer += delta
	spawn_timer += delta

	var spawn_interval := (
		wave_spawn_interval if is_wave_active
		else peace_spawn_interval
	)

	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		spawn_enemy_requested.emit()

	if not is_wave_active and phase_timer >= peace_duration:
		start_wave()
	elif is_wave_active and phase_timer >= wave_duration:
		end_wave()


func start_wave() -> void:
	is_wave_active = true
	current_wave += 1
	phase_timer = 0.0
	spawn_timer = 0.0

	show_wave_title()
	fade_to_color(wave_color)


func end_wave() -> void:
	is_wave_active = false
	phase_timer = 0.0
	spawn_timer = 0.0

	fade_to_color(normal_color)
	wave_title.visible = false



func show_wave_title() -> void:
	hud.visible = false
	wave_title.text = "WAVE " + number_to_words(current_wave)
	wave_title.visible = true
	wave_title.visible_characters = 0

	var title_tween := create_tween()

	# Type out the title.
	title_tween.tween_property(
		wave_title,
		"visible_characters",
		wave_title.text.length(),
		title_typing_duration
	)

	# Keep the completed title visible for one second.
	title_tween.tween_interval(1.0)

	# Hide the title and show the HUD after the tween finishes.
	title_tween.tween_callback(func():
		wave_title.visible = false
		hud.visible = true
	)

func fade_to_color(target_color: Color) -> void:
	if transition_tween and transition_tween.is_running():
		transition_tween.kill()

	transition_tween = create_tween()
	transition_tween.tween_property(
		canvas_modulate,
		"color",
		target_color,
		fade_duration
	)


func number_to_words(number: int) -> String:
	var words := [
		"ZERO", "ONE", "TWO", "THREE", "FOUR",
		"FIVE", "SIX", "SEVEN", "EIGHT", "NINE",
		"TEN", "ELEVEN", "TWELVE", "THIRTEEN",
		"FOURTEEN", "FIFTEEN", "SIXTEEN",
		"SEVENTEEN", "EIGHTEEN", "NINETEEN", "TWENTY"
	]

	if number < words.size():
		return words[number]

	return str(number)



func on_brightness_restored() -> void:
	current_speed_multiplier = normal_speed_multiplier
	

@warning_ignore("unused_parameter")
func _on_character_body_2d_brightness_changed(current: float, maximum: float) -> void:
	if current > 0:
		on_brightness_restored()# Replace with function body.


func _on_character_body_2d_brightness_depleted() -> void:
	current_speed_multiplier = darkness_speed_multiplier # Replace with function body.
