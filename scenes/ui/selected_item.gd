extends Node
class_name SelectedItem

var item: Item
var index: int
var inventory: Inventory

func _init(_item: Item, _index: int, _inventory: Inventory) -> void:
	item = _item
	index = _index
	inventory = _inventory
