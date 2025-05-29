extends Node
class_name Inventory

# This var and func are static so its loaded once for the class, rather than multiple times per instance.
#static var item_scenes: Dictionary = {}

# NEW NOTE: This was moved to Globals as I thought static was being weird but it was another issue.
# Will just keep it in the Globals autoload for now, since it guarantees its always loaded before anything...
#... needs the scenes.

# NOTE: This will need to be synced. This is the players equipment and also potentially NPC loot.

signal item_added(item: Item)
signal item_removed(item: Item)
# I thought this would make more sense for visual updating instead of relying on added/removed signals...
#... which don't really work/make sense to use if we're just moving items around local to this inventory.
# Maybe this is unnecessary but I do like making sure signals have clear purposes.
signal index_updated(current_item: Item, index: int)

@export var items_parent: Node2D
@export var slots: int = 6

var items: Array[Item] = []

func _ready() -> void:
	if is_multiplayer_authority():
		MultiplayerManager.player_connected.connect(_on_player_connected)
	for n in slots:
		items.append(null)

@rpc("authority", "call_local")
func create_and_add_item(item_name: String, index: int = -1) -> void:
	if index == -1:
		index = get_free_index()
	if index == -1: return
	item_name = item_name.to_snake_case()  
	if not Globals.item_scenes.has(item_name): return
	var item: Item = Globals.item_scenes[item_name].instantiate() as Item
	if not item: return
	add_item(item, index, true)

# Node path must be absolute to root scene for this to work and it assumes the client...
#... already has the item spawned.
@rpc("authority", "call_local")
func add_item_with_path(new_item_path: String, index: int) -> void:
	var new_item: Item = get_tree().root.get_node(new_item_path)
	add_item(new_item, index)

# This can't be directly synced since it relies on a node reference
func add_item(new_item: Item, index: int, assign_parent: bool = true) -> void:
	if new_item == null: return
	items[index] = new_item
	if assign_parent:
		if new_item.get_parent():
			new_item.get_parent().remove_child(new_item)
		if items_parent:
			items_parent.add_child(new_item, true)
		else:
			add_child(new_item, true)
	new_item.visible = false
	print("Added: " + new_item.item_name)
	item_added.emit(new_item)
	index_updated.emit(new_item, index)

func remove_item(index: int, remove_parent: bool = true) -> void:
	var item: Item = items[index]
	if item == null: return
	items[index] = null
	if remove_parent:
		if items_parent:
			items_parent.remove_child(item)
		elif item.get_parent() == self:
			remove_child(item)
	print("Removed: " + item.item_name)
	item_removed.emit(item)
	# We set to null here so visuals know its now empty
	index_updated.emit(null, index)

func delete_item(index: int) -> void:
	var item: Item = items[index]
	if not item: return
	items[index] = null
	item_removed.emit(item)
	index_updated.emit(item, index)
	item.queue_free()

func move_item(current_index: int, new_index: int) -> void:
	var current_item: Item = get_item_at_index(current_index)
	if not current_item: return
	var item_at_new_slot: Item = get_item_at_index(new_index)
	# Swaps items if there was one in the slot
	items[current_index] = item_at_new_slot
	index_updated.emit(item_at_new_slot, current_index)
	items[new_index] = current_item
	index_updated.emit(current_item, new_index)

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
