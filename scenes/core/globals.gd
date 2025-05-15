extends Node

const ITEMS: Dictionary = {
	"BoringRifle": preload("uid://c8vj3yqnvys4p"),
	"CyberGlock": preload("uid://bqnxqvdmyj5xt")
}

## This function doesn't add the new item as child so don't forget to do that.
func create_and_get_item(item_name: String) -> Item:
	if not ITEMS.has(item_name): return null
	var item: Item = ITEMS[item_name].instantiate() as Item
	return item
