extends Item
class_name Experience

var amount: int = 1:
	set(value):
		amount = value
		property_sync.sync("amount", amount)

func _ready() -> void:
	super._ready()
	property_sync.add_properties(["amount"])

func drop(_amount: int, _global_position: Vector2) -> void:
	is_dropped = true
	amount = _amount
	global_position = _global_position
	property_sync.sync("global_position", global_position)
