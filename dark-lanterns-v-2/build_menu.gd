
extends Control

var background: ColorRect
var build_panel: PanelContainer
var recipe_grid: GridContainer
var close_button: Button

var selected_recipe: String = ""

const BUILDING_PREVIEW_SCRIPT = preload("res://Building_preview.gd")
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	build_ui()

	close_button.pressed.connect(_on_close_pressed)

	# Refresh when inventory quantities change.
	Inventory.inventory_changed.connect(_on_inventory_changed)

	refresh_recipes()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("build_menu"):
		visible = not visible

		if visible:
			refresh_recipes()


func build_ui() -> void:
	background = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0, 0, 0, 0.65)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)

	build_panel = PanelContainer.new()
	build_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	build_panel.position = Vector2(-300, -225)
	build_panel.size = Vector2(600, 450)
	add_child(build_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	build_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "Build"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	header.add_child(title)

	close_button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(40, 36)
	header.add_child(close_button)

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	recipe_grid = GridContainer.new()
	recipe_grid.columns = 2
	recipe_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_grid.add_theme_constant_override("h_separation", 10)
	recipe_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(recipe_grid)


func refresh_recipes() -> void:
	for child in recipe_grid.get_children():
		recipe_grid.remove_child(child)
		child.queue_free()

	for recipe_id in Recipes.RECIPES:
		var recipe: Dictionary = Recipes.RECIPES[recipe_id]
		var affordable := can_afford(recipe)

		# Card button.
		var card := Button.new()
		card.custom_minimum_size = Vector2(250, 110)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.clip_contents = true

		# Horizontal layout inside the button.
		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(row)

		# Building image.
		var texture_rect := TextureRect.new()
		texture_rect.custom_minimum_size = Vector2(82, 82)
		texture_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var texture_path: String = recipe["texture"]
		var texture: Texture2D = load(texture_path) as Texture2D

		if texture != null:
			texture_rect.texture = texture
		else:
			push_warning("Could not load building texture: " + texture_path)

		row.add_child(texture_rect)

		# Building details.
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		details.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(details)

		var name_label := Label.new()
		name_label.text = recipe["name"]
		name_label.add_theme_font_size_override("font_size", 17)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.add_child(name_label)

		var cost_label := Label.new()
		cost_label.text = "Cost: " + get_cost_text(recipe)
		cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.add_child(cost_label)

		# Dim the entire card when unaffordable.
		card.modulate = (
			Color.WHITE
			if affordable
			else Color(0.4, 0.4, 0.4, 0.75)
		)

		print(
			recipe_id,
			" | Cost: ", get_cost_text(recipe),
			" | Inventory: ", Inventory.items,
			" | Affordable: ", affordable
		)

		card.modulate = Color.WHITE if affordable else Color(0.4, 0.4, 0.4, 0.75)

		# Keep clickable while we test placement selection.
		card.disabled = false
		

		card.pressed.connect(
			_on_recipe_pressed.bind(recipe_id)
		)

		recipe_grid.add_child(card)


func can_afford(recipe: Dictionary) -> bool:
	for item_id in recipe["cost"]:
		var required: int = recipe["cost"][item_id]
		var owned: int = Inventory.items.get(item_id, 0)

		if owned < required:
			return false

	return true


func get_cost_text(recipe: Dictionary) -> String:
	var parts := PackedStringArray()

	for item_id in recipe["cost"]:
		parts.append(
			str(recipe["cost"][item_id])
			+ " "
			+ item_id.capitalize()
		)

	return ", ".join(parts)


func _on_recipe_pressed(recipe_id: String) -> void:
	selected_recipe = recipe_id

	var recipe: Dictionary = Recipes.RECIPES[recipe_id]

	# Close the build menu.
	visible = false

	# Remove any previous preview.
	var old_preview := get_tree().current_scene.get_node_or_null(
        "BuildingPreview"
	)

	if old_preview != null:
		old_preview.queue_free()

	# Create the new preview in the game world.
	var preview := Node2D.new()
	preview.name = "BuildingPreview"
	preview.set_script(BUILDING_PREVIEW_SCRIPT)

	get_tree().current_scene.add_child(preview)
	preview.setup(recipe)

	print("Previewing building: ", recipe["name"])

	# Placement preview comes next.


func _on_close_pressed() -> void:
	visible = false
	selected_recipe = ""


func _on_inventory_changed(_item_id: String, _new_amount: int) -> void:
	if is_instance_valid(recipe_grid):
		refresh_recipes()
