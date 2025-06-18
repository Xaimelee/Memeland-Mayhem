extends Node2D
class_name Item

# NOTE: I don't know if this is the best solution but I wanted to try and avoid redundant...
#... duplicate scenes in the file system. Weapon inherits from this and the UI will just make
#... "UIItem" nodes to show the name, icon, etc.
	
## Names should probably be unique
@export var item_name: String = "Name"
# This will need to be synced later on when I add support for stacks in inventory
@export var stack: int = 1
	#set(value):
		#stack = value
		#property_sync.sync("stack", value)
@export var icon: Texture2D
@export var max_stack: int = 1

var pickup_area: Area2D = null
var is_dropped: bool = false:
	set(value):
		is_dropped = value
		if pickup_area != null:
			pickup_area.monitorable = is_dropped
		# This isn't called to be synced when changed for now because inventory functions of add item/drop item handle this.
		#property_sync.sync("is_dropped", is_dropped)
var despawn_time_passed: float = 0.0
var despawn_timer_duration: float = 300

@onready var property_sync: PropertySync = $PropertySync

func _ready() -> void:
	property_sync.add_properties([
		"stack",
		"is_dropped",
		"global_position"
	])
	pickup_area = get_node_or_null("PickupArea")
	if pickup_area != null:
		pickup_area.monitorable = is_dropped

func _process(delta: float) -> void:
	update_despawn_timer(delta)

func update_despawn_timer(delta: float) -> void:
	if not MultiplayerManager.is_server(): return
	if is_dropped:
		despawn_time_passed += delta
		if despawn_time_passed > despawn_timer_duration:
			queue_free()

func override_global_position(new_global_position: Vector2) -> void:
	global_position = new_global_position
	property_sync.sync("global_position", global_position)
