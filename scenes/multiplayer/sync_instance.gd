extends Node
class_name SyncInstance

#NOTE: might need a signal here to get fired to prompt updates to the client but not sure yet

var network_id: int = 0
var network_parent: SyncInstance = null
# SyncInstance will always be a child component of the node we wanted synced
@onready var root: Node = get_parent()

func _ready() -> void:
	#root.name = root.name + str(network_id)
	test_stuff()

func test_stuff() -> void:
	print(root.get_path())
	print(root.scene_file_path)
