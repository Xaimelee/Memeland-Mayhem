extends Node
class_name Inventory

const ITEMS: Dictionary = {
	"boring_rifle": preload("uid://c8vj3yqnvys4p"),
	"cyber_glock": preload("uid://bqnxqvdmyj5xt")
}

# NOTE: This will need to be synced. This is the players equipment and also potentially NPC loot.

signal item_added(item: Item)
signal item_removed(item: Item)

@export var items_parent: Node2D

var items: Array[Item] = [null, null, null, null, null, null, null, null]

func _ready() -> void:
	if is_multiplayer_authority():
		MultiplayerManager.player_connected.connect(_on_player_connected)

@rpc("authority", "call_local")
func create_and_add_item(item_name: String, index: int = -1) -> void:
	if index == -1:
		index = get_free_index()
	if index == -1: return
	item_name = item_name.to_snake_case()  
	if not ITEMS.has(item_name): return
	var item: Item = ITEMS[item_name].instantiate() as Item
	if not item: return
	add_item(item, index)

# Node path must be absolute to root scene for this to work and it assumes the client...
#... already has the item spawned.
@rpc("authority", "call_local")
func add_item_with_path(new_item_path: String, index: int) -> void:
	var new_item: Item = get_tree().root.get_node(new_item_path)
	add_item(new_item, index)

# This can't be directly synced since it relies on a node reference
func add_item(new_item: Item, index: int) -> void:
	if not new_item: return
	items[index] = new_item
	if new_item.get_parent():
		new_item.get_parent().remove_child(new_item)
	if items_parent:
		items_parent.add_child(new_item, true)
	else:
		add_child(new_item, true)
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

func _on_player_connected(id: int):
	for item in items:
		rpc_id(id, "create_and_add_item", item.item_name.to_snake_case())
