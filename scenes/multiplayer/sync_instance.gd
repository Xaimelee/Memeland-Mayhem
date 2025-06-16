extends Node
class_name SyncInstance

# Useful if we need specific logic to run when we know the root is now synced across network and fully spawned in
signal registered()

var network_id: int = 0
var network_parent: SyncInstance = null
var is_registered: bool = false
# SyncInstance will always be a child component of the node we wanted synced
@onready var root: Node = get_parent()

func _ready() -> void:
	if not is_registered and MultiplayerManager.is_server():
		#incase onready hasnt fired
		root = get_parent()
		MultiplayerSync.register_sync_instance(self)
	# If this is true, we assume the client has a sync instance not spawned via the server
	elif not is_registered and not MultiplayerManager.is_server():
		root = get_parent()
		if root != null:
			root.queue_free()
		else:
			queue_free()
	#print("ready")
	#root.name = root.name + str(network_id)

func _notification(what: int) -> void:
	if not what == NOTIFICATION_PREDELETE: return
	if not MultiplayerManager.is_server(): return
	if not is_registered: return
	MultiplayerSync.despawn_node.rpc(network_id)
