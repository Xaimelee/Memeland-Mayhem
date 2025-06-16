extends Item
class_name Experience

var amount: int = 1

# Data for sync instance regsistered is DEPRECATED because I will make a SyncProperty component
#func _on_sync_instance_registered(data: Dictionary) -> void:
	#global_position = data.get("global_position", Vector2.ZERO)
	#amount = data.get("amount", 1)
