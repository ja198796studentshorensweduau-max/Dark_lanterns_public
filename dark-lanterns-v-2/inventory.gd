
extends Node

signal inventory_changed(item_id: String, new_amount: int)

var items: Dictionary = {}


func _ready() -> void:
	# Restore inventory from the world save.
	var saved_items: Variant = WorldSave.load_value("inventory", {})

	if saved_items is Dictionary:
		items = saved_items.duplicate()

	# Register to save the inventory when requested.
	if not WorldSave.save_requested.is_connected(_save_inventory):
		WorldSave.save_requested.connect(_save_inventory)

	# Notify any UI listening for inventory changes.
	for item_id in items:
		inventory_changed.emit(item_id, items[item_id])


func _save_inventory() -> void:
	WorldSave.save("inventory", items.duplicate())


func add_item(item_id: String, amount: int = 1) -> void:
	if item_id.is_empty() or amount <= 0:
		return

	items[item_id] = items.get(item_id, 0) + amount
	inventory_changed.emit(item_id, items[item_id])


func get_amount(item_id: String) -> int:
	return items.get(item_id, 0)


func has_item(item_id: String, amount: int = 1) -> bool:
	return get_amount(item_id) >= amount


func remove_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or not has_item(item_id, amount):
		return false

	items[item_id] -= amount

	if items[item_id] <= 0:
		items.erase(item_id)

	inventory_changed.emit(item_id, get_amount(item_id))
	return true
