extends Node

# Server side signals
signal player_connected(id: int)
signal player_disconnected(id: int)

const SERVER_PORT: int = 8080
const PLAYER_SCENE: PackedScene = preload("res://scenes/player_character.tscn")
const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/main_menu.tscn")

@onready var peer = WebSocketMultiplayerPeer.new()

# So we can set this via a menu button
#localhost
#52.63.141.232
var server_ip: String = "52.63.141.232"
var override_is_local: bool = false
var characters: Node2D
var player_spawn: Node2D

func start_network() -> void:
	if not is_local():
		var player = get_tree().get_nodes_in_group("players")[0]
		if player != null:
			player.free()
	# Atm we assume start_network is always called by main after its loaded
	characters = get_node("/root/Main/Characters")
	player_spawn = get_node("/root/Main/PlayerSpawnPoint")
	var err: Error
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if is_server():
		err = peer.create_server(SERVER_PORT)
		if err == 0:
			multiplayer.multiplayer_peer = peer
			print("Server created")
	else:
		err = peer.create_client("ws://" + server_ip + ":" + str(SERVER_PORT))
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
	# Return to menu if failed to connect
	get_tree().change_scene_to_packed(MAIN_MENU_SCENE)

func _on_server_disconnected() -> void:
	print("Client Disconnected from Server")
	# Return to menu if disconnected
	get_tree().change_scene_to_packed(MAIN_MENU_SCENE)

## ID of 1 means connection to the server (authority)
func _on_peer_connected(id: int) -> void:
	if is_server():
		# We call this before adding any nodes because this is only really intended...
		# to sync already existing node values to the new player
		player_connected.emit(id)
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
	if is_server():
		for character in characters.get_children() as Array[CharacterBody2D]:
			var player: PlayerCharacter = character as PlayerCharacter
			if player is not PlayerCharacter: continue
			if player.id == id:
				player.queue_free()
		player_disconnected.emit(id)

func is_server() -> bool:
	if OS.has_feature("dedicated_server") and multiplayer.is_server(): return true
	if is_local(): return true
	return false

func is_local() -> bool:
	if override_is_local:
		return true
	for arg in OS.get_cmdline_args():
		if arg.contains("local"):
			return true
	return false;
