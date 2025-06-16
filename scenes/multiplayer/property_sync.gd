extends Node
class_name PropertySync

@onready var root: Node = get_parent()

# FOR TESTING, I will add a global debug class for extra logging based on if running in debug mode or not
var extra_logs: bool = false
# NOTE: This can only sync values which can be serialized over the network. Nodes, resources, anything derived from an object can't be.
# This array is just for when new players have joined/synced and need current values from properties.
var synced_properties: Array[String] = []

func _ready() -> void:
	if MultiplayerManager.is_server():
		MultiplayerSync.player_synced.connect(_on_player_synced)

# It wouldn't matter if the client populated this list but just for consistency
func add_properties(properties: Array[String]) -> void:
	if not MultiplayerManager.is_server(): return
	synced_properties.append_array(properties)

func sync(property_name: String, value: Variant) -> void:
	if not MultiplayerManager.is_server(): return
	if is_invalid_type(property_name, value): return
	if extra_logs:
		print("Sending: " + property_name + " with value of " + str(value))
	sync_property.rpc(property_name, value)

func sync_all() -> void:
	if not MultiplayerManager.is_server(): return
	var properties_and_values: Dictionary = get_properties_and_values()
	if properties_and_values.is_empty(): return
	if extra_logs:
		for key in properties_and_values:
			print("Sending: " + key + " with value of " + str(properties_and_values.get(key)))
	sync_properties.rpc(properties_and_values)

@rpc("authority", "call_remote")
func sync_property(property_name: String, value: Variant) -> void:
	if extra_logs:
		print("Received: " + property_name + " with value of " + str(value))
	root.set(property_name, value)

@rpc("authority", "call_remote")
func sync_properties(properties: Dictionary) -> void:
	for key in properties:
		sync_property(key, properties.get(key))

func _on_player_synced(id: int) -> void:
	var properties_and_values: Dictionary = get_properties_and_values()
	if properties_and_values.is_empty(): return
	if extra_logs:
		for key in properties_and_values:
			print("Sending: " + key + " with value of " + str(properties_and_values.get(key)))
	sync_properties.rpc_id(id, properties_and_values)

func is_invalid_type(property_name: String, value: Variant) -> bool:
	if typeof(value) in [TYPE_OBJECT, TYPE_CALLABLE]:
		push_warning("Cannot sync '%s': value type %s is not supported. Root node: %s" % [property_name, typeof(value), root])
		return true
	return false

func get_properties_and_values() -> Dictionary:
	var properties: Dictionary = {}
	for property_name in synced_properties:
		var value: Variant = root.get(property_name)
		if is_invalid_type(property_name, value): continue
		properties.set(property_name, value)
	return properties
