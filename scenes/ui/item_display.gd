@tool
extends Control
class_name ItemDisplay

@onready var icon: TextureRect = $Icon
@onready var quantity_label: Label = $QuantityContainer/QuantityLabel

@export var item: ItemDisplay.Item = Item.NONE: set = _set_item
@export var quantity: int = 0: set = _set_quantity

enum Item {
	NONE, 
	BORING_RIFLE,
	CYBER_GLOCK,
}

var _ITEM_NAMES: Array = [
	null,
	"boring-rifle",
	"cyber-glock",
]

func _ready() -> void:
	_set_item(item)
	_set_quantity(quantity)

# NOTE: I've added this back because we are generating an inventory based on...
#... the backend and when we make the item objects, we know the quantity and icon...
#... to use already so it nullifies needing the local item enum for display logic.
#... Basically this overrides the local display logic.
func set_icon_and_quantity(_icon: Texture2D, _quantity: int) -> void:
	icon.texture = _icon
	quantity_label.text = str(_quantity) if _quantity > 1 else ""

func _set_item(new_item: ItemDisplay.Item) -> void:
	item = new_item
	if item == Item.NONE:
		quantity = 0
		icon.texture = null
		return
	if quantity == 0:
		quantity = 1
	if icon == null:
		return
	icon.texture = load("res://assets/" + _ITEM_NAMES[item] + "-icon.png")

func _set_quantity(new_quantity: int) -> void:
	if item == Item.NONE:
		new_quantity = 0
	elif new_quantity < 1:
		new_quantity = 1
	quantity = new_quantity
	if quantity_label == null:
		return
	quantity_label.text = str(quantity) if quantity > 1 else ""
