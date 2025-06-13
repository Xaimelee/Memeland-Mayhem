extends Node
class_name SyncInstance

#NOTE: might need a signal here to get fired to prompt updates to the client but not sure yet
signal registered(data: Dictionary)

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
		queue_free()
	#print("ready")
	#root.name = root.name + str(network_id)
	#test_stuff()

func test_stuff() -> void:
	print(root.get_path())
	print(root.scene_file_path)
