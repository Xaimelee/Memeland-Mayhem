extends Node

const SERVER_PORT: int = 8080
#localhost
#ec2-3-107-84-157.ap-southeast-2.compute.amazonaws.com
#52.63.141.232
const SERVER_IP: String = "52.63.141.232"
const PLAYER_SCENE: PackedScene = preload("res://scenes/player_character.tscn")

@onready var characters: Node2D = get_node("/root/Main/Characters")
@onready var player_spawn: Node2D = get_node("/root/Main/PlayerSpawnPoint")
@onready var peer = WebSocketMultiplayerPeer.new()

func _ready() -> void:
	# We will need a proper setup where based on game state (i.e going from menu to game)
	# Simplier than needing to spawn a player in for local testing.
	if not is_local():
		var player = get_tree().get_nodes_in_group("players")[0]
		if player != null:
			player.free()
	# triggers the network to be started
	start_network()

func start_network() -> void:
	var err: Error
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if is_server():
		err = peer.create_server(SERVER_PORT)
		if err == 0:
			multiplayer.multiplayer_peer = peer
			print("Server created")
	else:
		err = peer.create_client("ws://" + SERVER_IP + ":" + str(SERVER_PORT))
		if err == 0:
			multiplayer.connected_to_server.connect(_on_connected_to_server)
			multiplayer.connection_failed.connect(_on_connection_failed)
			multiplayer.server_disconnected.connect(_on_server_disconnected)
			multiplayer.multiplayer_peer = peer
			print("Client Created")

func _on_connected_to_server() -> void:
	print("Client Connected")

func _on_connection_failed() -> void:
	print("Client Failed to Connect")

func _on_server_disconnected() -> void:
	print("Client Disconnected from Server")

## ID of 1 means connection to the server (authority)
func _on_peer_connected(id: int) -> void:
	if is_server():
		for child in characters.get_children():
			var player: PlayerCharacter = child
			if player is not PlayerCharacter: continue
			player.rpc_id(id, "init_player", player.id, player.global_position)
		var player: PlayerCharacter = PLAYER_SCENE.instantiate()
		characters.add_child(player, true)
		var spawn_position: Vector2 = player_spawn.global_position
		var random_offset: Vector2 = Vector2(randf_range(-5, 5), randf_range(-5, 5))
		player.set_multiplayer_authority(1)
		player.player_input.set_multiplayer_authority(id)
		player.rpc("init_player", id, spawn_position + random_offset)
		
	## Need to properly check here if a connection attempt has succeeded or failed
	print("Client connected: " + str(id))

func _on_peer_disconnected(id: int) -> void:
	print("Client disconnected: " + str(id))
	for character in characters.get_children() as Array[CharacterBody2D]:
		var player: PlayerCharacter = character as PlayerCharacter
		if player is not PlayerCharacter: continue
		if player.id == id:
			player.queue_free()

func is_server() -> bool:
	if OS.has_feature("dedicated_server") and multiplayer.is_server(): return true
	if is_local(): return true
	return false

func is_local() -> bool:
	for arg in OS.get_cmdline_args():
		if arg.contains("local"):
			return true
	return false;
