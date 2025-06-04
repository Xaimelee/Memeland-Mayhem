extends Node2D
class_name Item

# NOTE: I don't know if this is the best solution but I wanted to try and avoid redundant...
#... duplicate scenes in the file system. Weapon inherits from this and the UI will just make
#... "UIItem" nodes to show the name, icon, etc.

## Names should probably be unique
@export var item_name: String = "Name"
# This will need to be synced
@export var stack: int = 1
@export var icon: Texture2D
@export var max_stack: int = 1

var pickup_area: Area2D
var is_dropped: bool = false

func _ready() -> void:
	if is_multiplayer_authority():
		MultiplayerManager.player_connected.connect(_on_player_connected)
	pickup_area = get_node_or_null("PickupArea")

@rpc("authority", "call_remote")
func set_is_dropped(_is_dropped: bool) -> void:
	is_dropped = _is_dropped
	if pickup_area != null:
		pickup_area.monitorable = is_dropped

func _on_player_connected(id: int):
	rpc_id(id, "set_is_dropped", is_dropped)

@rpc("authority", "call_local")
func despawn():
	queue_free()
