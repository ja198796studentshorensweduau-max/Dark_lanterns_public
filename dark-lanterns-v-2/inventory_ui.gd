
extends Control

var inventory_panel: PanelContainer
var item_grid: GridContainer
var status_label: Label




func _ready() -> void:
	# Stretch the root Control across the viewport.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	visible = false
	build_ui()

	Inventory.inventory_changed.connect(_on_inventory_changed)
	refresh_inventory()






func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("inventory"):
		visible = not visible
		print("Inventory visible: ", visible)

		if visible:
			refresh_inventory()
			print("Panel visible: ", inventory_panel.visible)
			print("Panel position: ", inventory_panel.global_position)
			print("Panel size: ", inventory_panel.size)




func build_ui() -> void:
	# Dark background overlay.
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Main inventory panel.
	# Main inventory panel: full-screen.
	inventory_panel = PanelContainer.new()
	inventory_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	inventory_panel.anchor_left = 0.0
	inventory_panel.anchor_top = 0.0
	inventory_panel.anchor_right = 1.0
	inventory_panel.anchor_bottom = 1.0

	inventory_panel.offset_left = 0.0
	inventory_panel.offset_top = 0.0
	inventory_panel.offset_right = 0.0
	inventory_panel.offset_bottom = 0.0

	inventory_panel.position = Vector2.ZERO
	inventory_panel.size = Vector2.ZERO

	inventory_panel.z_index = 1
	add_child(inventory_panel)
	# Padding and vertical layout.
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	inventory_panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	# Header.
	var header := HBoxContainer.new()
	layout.add_child(header)

	var title := Label.new()
	title.text = "INVENTORY"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 26)
	header.add_child(title)

	var close_hint := Label.new()
	close_hint.text = "[ I ] CLOSE"
	close_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(close_hint)

	# Separator.
	var separator := HSeparator.new()
	layout.add_child(separator)

	# Item grid.
	item_grid = GridContainer.new()
	item_grid.columns = 5
	item_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_grid.add_theme_constant_override("h_separation", 8)
	item_grid.add_theme_constant_override("v_separation", 8)
	layout.add_child(item_grid)

	# Empty inventory message.
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.text = "Your inventory is empty."
	layout.add_child(status_label)
	overlay.z_index = 0
	inventory_panel.z_index = 1

func refresh_inventory() -> void:
	if item_grid == null:
		return

	# Remove old item displays.
	for child in item_grid.get_children():
		item_grid.remove_child(child)
		child.queue_free()

	var items: Dictionary = Inventory.items

	status_label.visible = items.is_empty()

	if items.is_empty():
		return

	# Draw one slot for every item in the inventory dictionary.
	for item_id in items:
		var amount: int = int(items[item_id])

		if amount <= 0:
			continue

		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(88, 78)
		item_grid.add_child(slot)

		var slot_layout := VBoxContainer.new()
		slot_layout.add_theme_constant_override("separation", 4)
		slot.add_child(slot_layout)

		var item_name := Label.new()
		item_name.text = str(item_id).replace("_", " ").capitalize()
		item_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item_name.size_flags_vertical = Control.SIZE_EXPAND_FILL
		slot_layout.add_child(item_name)

		var quantity := Label.new()
		quantity.text = "x" + str(amount)
		quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		quantity.add_theme_color_override(
			"font_color",
			Color(1.0, 0.85, 0.4)
		)
		slot_layout.add_child(quantity)


func _on_inventory_changed(
	_item_id: String,
	_new_amount: int
) -> void:
	refresh_inventory()
