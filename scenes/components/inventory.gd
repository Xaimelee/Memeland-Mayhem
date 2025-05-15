extends Node
class_name Inventory

# NOTE: This will need to be synced. This is the players equipment and also potentially NPC loot.

signal item_added(item: Item)
signal item_removed(item: Item)

@export var items_parent: Node2D

var items: Array[Item] = [null, null, null, null, null, null, null, null]

func create_and_add_item(item_name: String) -> void:
	var index: int = get_free_index()
	if index == -1: return
	var item: Item = Globals.create_and_get_item(item_name)
	add_item(item, index)

func add_item(new_item: Item, index: int) -> void:
	if not new_item: return
	items[index] = new_item
	items_parent.add_child(new_item, true)
	new_item.visible = false
	item_added.emit(new_item)

func get_item_at_index(index: int) -> Item:
	if index < 0 or index > items.size(): return null
	return items[index]

func get_free_index() -> int:
	for item in items:
		if not item:
			return items.find(item)
	# No slots available
	return -1
