
extends CanvasLayer

@export var player_path: NodePath

@onready var health_label: Label = $MarginContainer/VBoxContainer/HealthLabel
@onready var health_bar: TextureProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var brightness_label: Label = $MarginContainer/VBoxContainer/BrightnessLabel
@onready var brightness_bar: TextureProgressBar = $MarginContainer/VBoxContainer/BrightnessBar

var player: Node


func _ready() -> void:
	player = get_node(player_path)

	player.health_changed.connect(_on_health_changed)
	player.brightness_changed.connect(_on_brightness_changed)

	_on_health_changed(player.health, player.max_health)
	_on_brightness_changed(player.brightness, player.max_brightness)


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "HEALTH  %d / %d" % [
		roundi(current), roundi(maximum)
	]


func _on_brightness_changed(current: float, maximum: float) -> void:
	brightness_bar.max_value = maximum
	brightness_bar.value = current
	brightness_label.text = "BRIGHTNESS  %d / %d" % [
		roundi(current), roundi(maximum)
	]
