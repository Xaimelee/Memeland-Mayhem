extends Node
class_name SyncSpawn

var network_id: int
var node: Node
var parent: Node
var network_parent: SyncInstance

func _init(_network_id: int, _node: Node, _parent: Node, _network_parent: SyncInstance) -> void:
	network_id = _network_id
	node = _node
	parent = _parent
	network_parent = _network_parent
