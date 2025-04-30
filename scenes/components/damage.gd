extends Node
class_name Damage

signal damage_taken(amount: float)

var health: Health

func _ready() -> void:
	health = get_parent().get_node_or_null("Health")

@rpc("authority", "call_local")
func receive_damage(amount: float) -> void:
	damage_taken.emit(amount)
	# This is a client side setting of health which should be fine in this case since...
	# receiving damage has already been synced across all clients. There isn't much point...
	# to doing another rpc in health after this is already called.
	if health:
		# Same as doing health.set_health(health.current_health - amount)
		health.current_health -= amount
