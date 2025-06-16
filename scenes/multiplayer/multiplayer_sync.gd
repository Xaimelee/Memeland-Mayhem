extends Node

signal player_synced(id: int)

const MAX_SNAPSHOT_BATCH_SIZE: int = 30

# Only relevant for the server and these should always be unique
# This is not related to peer (player) ids
var next_network_id: int = 0 
var reusable_network_ids: Array[int] = []

# This is very important to remember, if any synced node needs to be deleted, we use the function...
#... in this script to ensure both client and server keep their dictionaries in sync.
var id_to_sync_instances: Dictionary = {}
var root_to_sync_instances: Dictionary = {}

# Spawn and despawn queues are for spawns and despawns sent by server while we are busy processing the snapshot. We will process these later.
# NOTE: This isnt added yet gonna test without it first
var sync_queue: Array[Variant] = []

var snapshot_queue: Array[Dictionary] = []
var is_processing_snapshot: bool = true

func _ready() -> void:
	Globals.scene_changed.connect(_on_scene_changed)
	#get_tree().node_removed.connect(_on_node_removed)

func _on_scene_changed(scene: String) -> void:
	id_to_sync_instances.clear()
	root_to_sync_instances.clear()
	sync_queue.clear()
	snapshot_queue.clear()
	is_processing_snapshot = false

# This fires when reparenting which is fucking stupid
#func _on_node_removed(node: Node) -> void:
	#var sync_instance: SyncInstance = root_to_sync_instances.get(node)
	#if sync_instance == null: return
	#if sync_instance.is_inside_tree(): return
	#print("Cleared: " + sync_instance.root.name)
	#root_to_sync_instances.erase(sync_instance.root)
	#id_to_sync_instances.erase(sync_instance.network_id)

# These are new connections to the server
func create_and_send_snapshot(peer_id: int) -> void:
	var all_instances: Array = root_to_sync_instances.values()
	var current_batch: Array[Dictionary] = []
	for i in range(all_instances.size()):
		var sync_instance: SyncInstance = all_instances[i]
		var network_id: int = sync_instance.network_id
		var network_parent_id: int = -1 if sync_instance.network_parent == null else sync_instance.network_parent.network_id
		var scene_path: String = sync_instance.root.scene_file_path
		var parent: Node = sync_instance.root.get_parent()
		var parent_path: String = "" if parent == null else parent.get_path()
		current_batch.append({
			"network_id": network_id,
			"network_parent_id": network_parent_id,
			"scene_path": scene_path,
			"parent_path": parent_path
		})
		# If batch is full or it's the last instance, send it
		var is_last_instance: bool = (i == all_instances.size() - 1)
		if current_batch.size() >= MAX_SNAPSHOT_BATCH_SIZE or is_last_instance:
			send_snapshot_batch.rpc_id(peer_id, current_batch.duplicate(), is_last_instance)
			current_batch.clear()

@rpc("authority", "call_remote")
func send_snapshot_batch(snapshot_batch: Array[Dictionary], is_last_batch: bool = false) -> void:
	is_processing_snapshot = true
	for instance_values in snapshot_batch:
		if not try_create_instance_from_values(instance_values):
			snapshot_queue.append(instance_values)
		else:
			try_clear_pending_queue()
	if is_last_batch:
		is_processing_snapshot = false
		# I did it like this so if the server tries to rpc a new connecting user before they have synced their snapshot, it would rpc error and then they wouldn't spawn the node.
		# Which would then require needing a solution to perioidcally check network ids to make sure client isnt missing any. We may still need to do that but this should hopefully...
		#... avoid it happening because the user was still joining/syncing.
		for queued_sync in sync_queue:
			var sync_despawn: SyncDespawn = queued_sync as SyncDespawn
			if sync_despawn != null:
				despawn_node(sync_despawn.network_id)
				continue
			var sync_spawn: SyncSpawn = queued_sync as SyncSpawn
			if sync_spawn != null:
				setup_node(sync_spawn.network_id, sync_spawn.node, sync_spawn.parent, sync_spawn.network_parent)
				continue
		sync_queue.clear()
		send_snapshot_processed.rpc_id(1, multiplayer.get_unique_id())

@rpc("any_peer", "call_remote")
func send_snapshot_processed(id: int) -> void:
	player_synced.emit(id)

func try_clear_pending_queue() -> void:
	var has_spawned: bool = true
	while has_spawned:
		has_spawned = false
		for i in range(snapshot_queue.size() - 1, -1, -1):
			if try_create_instance_from_values(snapshot_queue[i]):
				snapshot_queue.remove_at(i)
				has_spawned = true
			else:
				has_spawned = false

func try_create_instance_from_values(instance_values: Dictionary) -> bool:
	var network_id: int = instance_values["network_id"]
	var network_parent_id: int = instance_values["network_parent_id"]
	if network_parent_id != -1 and not id_to_sync_instances.has(network_parent_id): return false
	var scene_path: String = instance_values["scene_path"]
	var parent_path: String = instance_values["parent_path"]
	spawn_node(network_id, scene_path, parent_path, network_parent_id, false)
	return true

#create node, will check child for synced node component
func create_and_spawn_node(node_scene: PackedScene, parent: Node = null) -> Node:
	var node: Node = node_scene.instantiate()
	# Here we are checking for a node higher in the chain which is also synced.
	# We need this info for later when sending snapshots to new players to ensure.
	# Dependencies are loaded in the correct order otherwise paths could get invalidated.
	var network_parent: SyncInstance = find_parent_sync_instance(parent)
	if network_parent != null and not id_to_sync_instances.has(network_parent.network_id):
		node.queue_free()
		printerr("Tried to spawn a synced node but the found network parent does not exist in the dictionary. I could just add it but this is likely an issue with setup needing addressing")
		return
	var id: int = get_next_network_id()
	setup_node(id, node, parent, network_parent)
	var parent_path = "" if parent == null else parent.get_path()
	var parent_network_id = -1 if network_parent == null else network_parent.network_id
	spawn_node.rpc(id, node.scene_file_path, parent_path, parent_network_id)
	return node

func setup_node(network_id: int, node: Node, parent: Node = null, network_parent: SyncInstance = null) -> void:
	var sync_instance: SyncInstance = null
	for child in node.get_children():
		if child is SyncInstance:
			sync_instance = child
			break;
	# This function is contextual to the node needing to be synced and as such must have a sync instance as a child node.
	if sync_instance == null:
		node.queue_free()
		printerr("Tried to spawn a synced node that doesn't have a sync instance node as child.")
		return
	#print("called: " + str(sync_instance.is_registered))
	sync_instance.is_registered = true
	# This ensures unique naming for both client and server
	node.name = node.name + "_ID" + str(network_id)
	if parent != null:
		parent.add_child(node)
	sync_instance.network_id = network_id
	# Incase the @onready hasn't triggered yet
	sync_instance.root = node
	sync_instance.network_parent = network_parent
	# 2 dictionaries here incase later we need support for both methods of accessing a sync instance.
	# This is likely only relevant for server but since we have id mapping, we can validate if sync instances are where they should be...
	#... and if clients are missing any sync instances compared to the server. If so, we could add a way to try and resync players. 
	id_to_sync_instances[network_id] = sync_instance
	root_to_sync_instances[node] = sync_instance
	sync_instance.registered.emit()
	print("Spawned: " + node.name)

func register_sync_instance(sync_instance: SyncInstance) -> void:
	sync_instance.is_registered = true
	var id: int = get_next_network_id()
	sync_instance.network_id = id
	sync_instance.root.name = sync_instance.root.name.rstrip("0123456789") + "_ID" + str(id)
	sync_instance.network_parent = find_parent_sync_instance(sync_instance.root.get_parent())
	id_to_sync_instances[sync_instance.network_id] = sync_instance
	root_to_sync_instances[sync_instance.root] = sync_instance
	print("Registered: " + sync_instance.root.name)

func unregister_sync_instance(sync_instance: SyncInstance) -> void:
	id_to_sync_instances.erase(sync_instance.network_id)
	root_to_sync_instances.erase(sync_instance.root)
	reusable_network_ids.append(sync_instance.network_id)

#spawn node for clients
@rpc("authority", "call_remote")
func spawn_node(network_id: int, scene_path: String, parent_path: String = "", parent_network_id: int = -1, check_if_processing: bool = true) -> void:
	# In future we should cache all possible load paths for client and server so we don't need to load
	var node: Node = load(scene_path).instantiate()
	var parent: Node = get_tree().root.get_node_or_null(parent_path)
	var network_parent: SyncInstance = id_to_sync_instances.get(parent_network_id)
	if network_parent == null and parent_network_id != -1:
		printerr("Spawned: " + node.name + " and parent network id of: " + str(parent_network_id) + " could not be found on client.")
	if is_processing_snapshot and check_if_processing:
		sync_queue.append(SyncSpawn.new(network_id, node, parent, network_parent))
		return
	setup_node(network_id, node, parent, network_parent)

# DEPRECATED
func delete_and_despawn_node(node: Node) -> void:
	var sync_instance: SyncInstance = root_to_sync_instances.get(node)
	if sync_instance == null: 
		printerr("Tried to despawn: " + node.name + "but dictionary doesn't have sync instance mapped to the node.")
		return
	despawn_node.rpc(sync_instance.network_id)

@rpc("authority", "call_local")
func despawn_node(network_id: int) -> void:
	var sync_instance: SyncInstance = id_to_sync_instances.get(network_id)
	if sync_instance == null: 
		printerr("Tried to despawn using id: " + str(network_id) + "but dictionary doesn't have sync instance mapped to the id.")
		return
	if is_processing_snapshot:
		sync_queue.append(SyncDespawn.new(network_id))
		return
	print("Despawned: " + sync_instance.root.name)
	unregister_sync_instance(sync_instance)
	if not MultiplayerManager.is_server():
		sync_instance.root.queue_free()

func change_parent_and_sync(root_node: Node, new_parent: Node) -> void:
	var sync_instance: SyncInstance = root_to_sync_instances.get(root_node)
	if sync_instance == null: return
	root_node.reparent(new_parent)
	# This can be null so remember that
	var network_parent: SyncInstance = find_parent_sync_instance(new_parent)
	sync_instance.network_parent = network_parent
	var network_parent_id: int = -1 if network_parent == null else network_parent.network_id
	change_parent.rpc(sync_instance.network_id, new_parent.get_path(), network_parent_id)

@rpc("authority", "call_remote")
func change_parent(network_id: int, parent_path: String, parent_network_id: int):
	var parent: Node = get_tree().root.get_node_or_null(parent_path)
	if parent == null: return
	var sync_instance: SyncInstance = id_to_sync_instances.get(network_id)
	if sync_instance == null: return
	sync_instance.root.reparent(parent)
	sync_instance.network_parent = id_to_sync_instances.get(parent_network_id)

func find_parent_sync_instance(starting_node: Node) -> SyncInstance:
	var current_node = starting_node
	while current_node != null:
		current_node = current_node.get_parent()
		if current_node != null:
			for child in current_node.get_children():
				if child is SyncInstance:
					return child
	return null

func get_next_network_id() -> int:
	if not reusable_network_ids.is_empty():
		return reusable_network_ids.pop_back()
	var id: int = next_network_id
	next_network_id += 1
	return id
