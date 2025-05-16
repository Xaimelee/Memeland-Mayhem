extends Control
class_name ItemDisplay

@onready var item_icon: TextureRect = $MarginContainer/ItemIcon
@onready var item_stack_text: Label = $MarginContainer/ItemStack

func init(_icon: Texture2D, _stack: int) -> void:
	item_icon.texture = _icon
	item_stack_text.text = str(_stack)
