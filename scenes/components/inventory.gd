extends Node
class_name Inventory

# NOTE: We dynamically populate this dictionary at runtime based on scenes in the runtime items folder.
# The schema is "item_name": PackedScene
# This var and func are static so its loaded once for the class, rather than multiple times per instance.
static var item_scenes: Dictionary = {}

# NOTE: This will need to be synced. This is the players equipment and also potentially NPC loot.

signal item_added(item: Item, index: int)
signal item_removed(item: Item, index: int)

@export var items_parent: Node2D

var items: Array[Item] = [null, null, null, null, null, null, null, null]

func _ready() -> void:
	Inventory.load_items()
	if is_multiplayer_authority():
		MultiplayerManager.player_connected.connect(_on_player_connected)

@rpc("authority", "call_local")
func create_and_add_item(item_name: String, index: int = -1) -> void:
	if index == -1:
		index = get_free_index()
	if index == -1: return
	item_name = item_name.to_snake_case()  
	if not item_scenes.has(item_name): return
	var item: Item = item_scenes[item_name].instantiate() as Item
	if not item: return
	if item.get_parent():
		item.get_parent().remove_child(item)
	if items_parent:
		items_parent.add_child(item, true)
	else:
		add_child(item, true)
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
	new_item.visible = false
	item_added.emit(new_item)

func remove_item(index: int) -> void:
	var item: Item = items[index]
	if not item: return
	items[index] = null
	if items_parent:
		items_parent.remove_child(item)
	else:
		remove_child(item)
	item_removed.emit(item, index)

func delete_item(index: int) -> void:
	var item: Item = items[index]
	if not item: return
	items[index] = null
	item_removed.emit(item, index)
	item.queue_free()

func move_item(current_index: int, new_index: int) -> void:
	var current_item: Item = get_item_at_index(current_index)
	if not current_item: return
	var item_at_new_slot: Item = get_item_at_index(new_index)
	# Swaps items if there was one in the slot
	items[current_index] = item_at_new_slot
	item_added.emit(item_at_new_slot, current_index)
	items[new_index] = current_item
	item_added.emit(current_item, new_index)

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

static func load_items():
	if item_scenes.is_empty():
		var items_dir_path: String = "res://scenes/items/runtime_items"
		var dir: DirAccess = DirAccess.open(items_dir_path)
		if dir:
			dir.list_dir_begin()
			var file_name: String = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir():
					if file_name.ends_with(".tscn.remap"):
						# Call twice to get rid of both extensions
						var item_name: String = file_name.get_basename().get_basename()
						var real_file_name: String = file_name.get_basename()
						item_scenes[item_name] = load(items_dir_path + "/" + real_file_name)
				file_name = dir.get_next()
			dir.list_dir_end()
		else:
			print("Could not open directory: ", items_dir_path)
