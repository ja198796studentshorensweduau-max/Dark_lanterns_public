
extends CanvasLayer
class_name PauseMenu

@export_file("*.tscn") var title_scene_path: String = ""

const BG := Color("#202120")
const BUTTON := Color("#343633")
const BUTTON_HOVER := Color("#41433E")
const TEXT := Color("#D4D4CC")
const MUTED := Color("#92948C")

var overlay: ColorRect
var menu_panel: PanelContainer
var status_label: Label

var is_open := false
var is_transitioning := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	build_ui()


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	if event is InputEventKey and event.echo:
		return

	if is_transitioning:
		return

	if is_open:
		resume_game()
	else:
		open_menu()

	get_viewport().set_input_as_handled()


func build_ui() -> void:
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	menu_panel = PanelContainer.new()
	menu_panel.set_anchors_preset(Control.PRESET_CENTER)
	menu_panel.offset_left = -170
	menu_panel.offset_top = -155
	menu_panel.offset_right = 170
	menu_panel.offset_bottom = 155
	menu_panel.custom_minimum_size = Vector2(340, 310)
	menu_panel.modulate.a = 0.0

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = BG
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(24)
	menu_panel.add_theme_stylebox_override("panel", panel_style)
	overlay.add_child(menu_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	menu_panel.add_child(layout)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", TEXT)
	layout.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	layout.add_child(spacer)

	var resume_button := make_button("RESUME")
	resume_button.pressed.connect(resume_game)
	layout.add_child(resume_button)

	var save_button := make_button("SAVE GAME")
	save_button.pressed.connect(save_game)
	layout.add_child(save_button)

	var quit_button := make_button("QUIT TO TITLE")
	quit_button.pressed.connect(quit_to_title)
	layout.add_child(quit_button)

	status_label = Label.new()
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", MUTED)
	layout.add_child(status_label)

	overlay.visible = false


func make_button(button_text: String) -> Button:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(0, 42)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_pressed_color", TEXT)
	button.add_theme_color_override("font_disabled_color", MUTED)

	var normal := StyleBoxFlat.new()
	normal.bg_color = BUTTON
	normal.set_corner_radius_all(5)
	normal.set_content_margin_all(8)
	button.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = BUTTON_HOVER
	hover.set_corner_radius_all(5)
	hover.set_content_margin_all(8)
	button.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = BG
	pressed.set_corner_radius_all(5)
	pressed.set_content_margin_all(8)
	button.add_theme_stylebox_override("pressed", pressed)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = BUTTON
	disabled.set_corner_radius_all(5)
	disabled.set_content_margin_all(8)
	button.add_theme_stylebox_override("disabled", disabled)

	return button


func open_menu() -> void:
	if is_open or is_transitioning:
		return

	is_open = true
	is_transitioning = true
	status_label.text = ""

	overlay.visible = true
	overlay.color.a = 0.0
	menu_panel.modulate.a = 0.0

	get_tree().paused = true

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)

	tween.tween_property(overlay, "color:a", 0.65, 0.2)
	tween.tween_property(menu_panel, "modulate:a", 1.0, 0.2)

	tween.set_parallel(false)
	tween.tween_callback(func(): is_transitioning = false)


func resume_game() -> void:
	if not is_open or is_transitioning:
		return

	is_transitioning = true

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)

	tween.tween_property(overlay, "color:a", 0.0, 0.18)
	tween.tween_property(menu_panel, "modulate:a", 0.0, 0.18)

	tween.set_parallel(false)
	tween.tween_callback(finish_resume)


func finish_resume() -> void:
	overlay.visible = false
	is_open = false
	is_transitioning = false
	get_tree().paused = false


func save_game() -> void:
	if WorldSave.save_world():
		status_label.text = "Game saved."
	else:
		status_label.text = "Save failed."


func quit_to_title() -> void:
	if title_scene_path.is_empty():
		status_label.text = "Title scene not set."
		return

	if not ResourceLoader.exists(title_scene_path):
		status_label.text = "Title scene not found."
		return

	is_transitioning = true

	if not WorldSave.save_world():
		status_label.text = "Save failed."
		is_transitioning = false
		return

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(overlay, "color:a", 1.0, 0.2)

	tween.tween_callback(func():
		get_tree().paused = false
		get_tree().change_scene_to_file(title_scene_path)
	)
