
extends CanvasLayer
class_name CampfireMenu

var campfire: Campfire

var energy_label: Label
var energy_bar: ProgressBar
var wood_label: Label
var add_wood_button: Button
var menu_panel: PanelContainer


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(target_campfire: Campfire) -> void:
	campfire = target_campfire


func _ready() -> void:
	build_ui()

	if campfire:
		if not campfire.energy_changed.is_connected(_on_energy_changed):
			campfire.energy_changed.connect(_on_energy_changed)

	if not Inventory.inventory_changed.is_connected(_on_inventory_changed):
		Inventory.inventory_changed.connect(_on_inventory_changed)

	refresh_ui()


func build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(_on_root_gui_input)
	add_child(root)

	# Main panel.
	menu_panel = PanelContainer.new()
	menu_panel.set_anchors_preset(Control.PRESET_CENTER)
	menu_panel.offset_left = -220
	menu_panel.offset_top = -190
	menu_panel.offset_right = 220
	menu_panel.offset_bottom = 190
	menu_panel.custom_minimum_size = Vector2(440, 380)
	menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#171A20")
	panel_style.border_color = Color("#383D48")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 22
	panel_style.content_margin_right = 22
	panel_style.content_margin_top = 18
	panel_style.content_margin_bottom = 18
	menu_panel.add_theme_stylebox_override("panel", panel_style)

	root.add_child(menu_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	menu_panel.add_child(layout)

	# Header.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	layout.add_child(header)

	var campfire_icon := TextureRect.new()
	campfire_icon.custom_minimum_size = Vector2(76, 76)
	campfire_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	campfire_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	if ResourceLoader.exists("res://Campfire_still_v1.png"):
		campfire_icon.texture = load("res://Campfire_still_v1.png")

	header.add_child(campfire_icon)

	var title_column := VBoxContainer.new()
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_column.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(title_column)

	var title := Label.new()
	title.text = "Campfire"
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color("#F3E5CE"))
	title_column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Your central source of warmth"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color("#A8B0BC"))
	title_column.add_child(subtitle)

	var close_button := Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(36, 36)
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.pressed.connect(close_menu)
	header.add_child(close_button)

	# Separator.
	var separator := HSeparator.new()
	layout.add_child(separator)

	# Energy display.
	var energy_header := HBoxContainer.new()
	layout.add_child(energy_header)

	var energy_title := Label.new()
	energy_title.text = "Fire energy"
	energy_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	energy_title.add_theme_color_override("font_color", Color("#D9DEE7"))
	energy_header.add_child(energy_title)

	energy_label = Label.new()
	energy_label.add_theme_font_size_override("font_size", 20)
	energy_label.add_theme_color_override("font_color", Color("#F3B44B"))
	energy_header.add_child(energy_label)

	energy_bar = ProgressBar.new()
	energy_bar.custom_minimum_size = Vector2(0, 16)
	energy_bar.show_percentage = false

	var bar_background := StyleBoxFlat.new()
	bar_background.bg_color = Color("#353943")
	bar_background.set_corner_radius_all(8)
	energy_bar.add_theme_stylebox_override("background", bar_background)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color("#F3A43B")
	bar_fill.set_corner_radius_all(8)
	energy_bar.add_theme_stylebox_override("fill", bar_fill)

	layout.add_child(energy_bar)

	var drain_label := Label.new()
	drain_label.text = "The fire loses energy over time."
	drain_label.add_theme_font_size_override("font_size", 12)
	drain_label.add_theme_color_override("font_color", Color("#A8B0BC"))
	layout.add_child(drain_label)

	layout.add_child(HSeparator.new())

	# Wood inventory section.
	var wood_section := HBoxContainer.new()
	wood_section.add_theme_constant_override("separation", 12)
	layout.add_child(wood_section)

	var wood_icon := TextureRect.new()
	wood_icon.custom_minimum_size = Vector2(48, 48)
	wood_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wood_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	if ResourceLoader.exists("res://Log_still_v1.png"):
		wood_icon.texture = load("res://Log_still_v1.png")

	wood_section.add_child(wood_icon)

	var wood_info := VBoxContainer.new()
	wood_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wood_info.alignment = BoxContainer.ALIGNMENT_CENTER
	wood_section.add_child(wood_info)

	var wood_title := Label.new()
	wood_title.text = "Wood available"
	wood_title.add_theme_color_override("font_color", Color("#F3E5CE"))
	wood_info.add_child(wood_title)

	wood_label = Label.new()
	wood_label.add_theme_font_size_override("font_size", 13)
	wood_label.add_theme_color_override("font_color", Color("#A8B0BC"))
	wood_info.add_child(wood_label)

	# Main refuelling button.
	add_wood_button = Button.new()
	add_wood_button.text = "ADD WOOD\n+5 ENERGY"
	add_wood_button.custom_minimum_size = Vector2(0, 68)
	add_wood_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_wood_button.add_theme_font_size_override("font_size", 19)

	var button_normal := StyleBoxFlat.new()
	button_normal.bg_color = Color("#B96827")
	button_normal.set_corner_radius_all(9)
	button_normal.content_margin_top = 10
	button_normal.content_margin_bottom = 10
	add_wood_button.add_theme_stylebox_override("normal", button_normal)

	var button_hover := StyleBoxFlat.new()
	button_hover.bg_color = Color("#D17B32")
	button_hover.set_corner_radius_all(9)
	add_wood_button.add_theme_stylebox_override("hover", button_hover)

	var button_pressed := StyleBoxFlat.new()
	button_pressed.bg_color = Color("#914B1D")
	button_pressed.set_corner_radius_all(9)
	add_wood_button.add_theme_stylebox_override("pressed", button_pressed)

	var button_disabled := StyleBoxFlat.new()
	button_disabled.bg_color = Color("#45434A")
	button_disabled.set_corner_radius_all(9)
	add_wood_button.add_theme_stylebox_override("disabled", button_disabled)

	add_wood_button.add_theme_color_override("font_color", Color.WHITE)
	add_wood_button.add_theme_color_override("font_disabled_color", Color("#9999A0"))
	add_wood_button.pressed.connect(_on_add_wood_pressed)
	layout.add_child(add_wood_button)


func refresh_ui() -> void:
	if not is_instance_valid(campfire):
		return

	energy_label.text = "%d / %d" % [
		int(campfire.energy),
		int(campfire.max_energy)
	]

	energy_bar.max_value = maxf(campfire.max_energy, 1.0)
	energy_bar.value = campfire.energy

	var wood_key = get_wood_inventory_key()
	var wood_amount := 0

	if wood_key != null:
		wood_amount = int(Inventory.items[wood_key])

	wood_label.text = "%d in inventory" % wood_amount

	var fire_is_full := campfire.energy >= campfire.max_energy
	var fire_destroyed := campfire.is_destroyed

	add_wood_button.disabled = (
		wood_amount <= 0
		or fire_is_full
		or fire_destroyed
	)

	if fire_destroyed:
		add_wood_button.text = "CAMPFIRE DESTROYED"
	elif fire_is_full:
		add_wood_button.text = "FIRE IS FULL"
	else:
		add_wood_button.text = "ADD WOOD\n+5 ENERGY"


func get_wood_inventory_key() -> Variant:
	for item_id in Inventory.items:
		if str(item_id).to_lower() == "wood":
			return item_id

	return null


func _on_add_wood_pressed() -> void:
	if not is_instance_valid(campfire):
		return

	if campfire.is_destroyed:
		return

	if campfire.energy >= campfire.max_energy:
		refresh_ui()
		return

	var wood_key = get_wood_inventory_key()

	if wood_key == null or int(Inventory.items[wood_key]) <= 0:
		refresh_ui()
		return

	# Consume exactly one wood.
	Inventory.items[wood_key] -= 1

	if Inventory.items[wood_key] <= 0:
		Inventory.items.erase(wood_key)

	Inventory.inventory_changed.emit(
		str(wood_key),
		int(Inventory.items.get(wood_key, 0))
	)

	# Add energy using the Campfire's existing function.
	campfire.add_wood()

	refresh_ui()


func _on_energy_changed(_current: float, _maximum: float) -> void:
	refresh_ui()


func _on_inventory_changed(_item_id: String, _new_amount: int) -> void:
	refresh_ui()


func _on_root_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not menu_panel.get_global_rect().has_point(event.position):
				close_menu()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close_menu()


func close_menu() -> void:
	if get_tree().paused:
		get_tree().paused = false

	queue_free()
