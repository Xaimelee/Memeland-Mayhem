extends Node

# Server side signals
signal player_connected(id: int)
signal player_disconnected(id: int)

const SERVER_PORT: int = 8080
const PLAYER_SCENE: PackedScene = preload("uid://dxk1jvimm72ti")
const PLAYER_MENU: PackedScene = preload("uid://b4scbqjbo7wtn")

@onready var peer = WebSocketMultiplayerPeer.new()

# So we can set this via a menu button
#localhost
#52.63.141.232
var server_ip: String = "52.63.141.232"
var override_is_local: bool = false
var characters: Node2D
var player_spawn: Node2D
var connected_users: Dictionary = {}
var guest_data: UserData = UserData.new(
	"guest",
	"",
	"Player",
	1,
	[
		{
			"item_name": "boring_rifle",
			"slot": 0
		},
		{
			"item_name": "cyber_glock",
			"slot": 1
		}
	],
	[]
)

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

@rpc("authority", "call_remote")
func request_user_id() -> void:
	if SolanaService.wallet.is_logged_in() and UserManager.user_data:
		rpc_id(1, "send_user_id", UserManager.user_data.user_id)
	else:
		rpc_id(1, "send_user_id")

@rpc("any_peer", "call_remote")
func send_user_id(user_id: String = "guest") -> void:
	# Safeguard
	if not is_server(): return
	var peer_id: int = multiplayer.get_remote_sender_id()
	# This means this user wasn't added to the connected users dictionary when they...
	#... joined and should be made to rejoin.
	if not connected_users.has(peer_id):
		peer.disconnect_peer(peer_id, true)
		return
	var connected_user: ConnectedUser = connected_users[peer_id]
	# This means we already have approved the user id of this user
	if connected_user.status == 1: return
	connected_user.user_id = user_id
	if user_id != "guest":
		var body: String = JSON.stringify({ "userId": "user_id" })
		Api.post_request(1, _on_successful_response, body)
	# Guest setup
	else:
		connected_user.user_data = guest_data
		connected_user.status = 1
		print("Loading peer: " + str(peer_id) + " as guest")
		spawn_player(peer_id, connected_user.user_data)

func spawn_player(peer_id: int, user_data: UserData) -> void:
	player_connected.emit(peer_id)
	var player: PlayerCharacter = PLAYER_SCENE.instantiate()
	characters.add_child(player, true)
	var spawn_position: Vector2 = player_spawn.global_position
	var random_offset: Vector2 = Vector2(randf_range(-5, 5), randf_range(-5, 5))
	player.set_multiplayer_authority(1)
	player.player_input.set_multiplayer_authority(peer_id)
	player.rpc("init_player", peer_id, spawn_position + random_offset)
	for item in user_data.inventory:
		var item_name: String = item["item_name"]
		var slot: int = item["slot"]
		player.inventory.rpc("create_and_add_item", item_name, slot)
	# Testing syntax and flow, this has to be loaded via database at some point
	#player.inventory.rpc("create_and_add_item", "BoringRifle")
	#player.inventory.rpc("create_and_add_item", "CyberGlock")

func _on_successful_response(response: ResponseType) -> void:
	var user_data: UserData = response as UserData
	if not user_data: return
	for peer_id in connected_users.keys():
		var connected_user: ConnectedUser = connected_users[peer_id]
		if connected_user.user_id != user_data.user_id: continue
		# This status means this should've already been done so we assume this is some kind of...
		#.. duplicate call that we shouldn't process.
		if connected_user.status == 1: break
		connected_user.status = 1
		connected_user.user_data = user_data
		print("Loading peer: " + str(peer_id) + " as user")
		spawn_player(peer_id, user_data)
		break

func _on_connected_to_server() -> void:
	print("Client Connected")

func _on_connection_failed() -> void:
	print("Client Failed to Connect")
	# Return to menu if failed to connect
	get_tree().change_scene_to_packed(PLAYER_MENU)

func _on_server_disconnected() -> void:
	print("Client Disconnected from Server")
	# Return to menu if disconnected
	get_tree().change_scene_to_packed(PLAYER_MENU)

## ID of 1 means connection to the server (authority)
func _on_peer_connected(id: int) -> void:
	# We need to request info from the new player (i.e user id, this will need to be more...
	#... secure in future) before we spawn them in and sync them.
	if is_server():
		connected_users[id] = ConnectedUser.new()
		rpc_id(id, "request_user_id")
		# We call this before adding any nodes because this is only really intended...
		# to sync already existing node values to the new player
		#player_connected.emit(id)
		#var player: PlayerCharacter = PLAYER_SCENE.instantiate()
		#characters.add_child(player, true)
		#var spawn_position: Vector2 = player_spawn.global_position
		#var random_offset: Vector2 = Vector2(randf_range(-5, 5), randf_range(-5, 5))
		#player.set_multiplayer_authority(1)
		#player.player_input.set_multiplayer_authority(id)
		#player.rpc("init_player", id, spawn_position + random_offset)
		## Testing syntax and flow, this has to be loaded via database at some point
		#player.inventory.rpc("create_and_add_item", "BoringRifle")
		#player.inventory.rpc("create_and_add_item", "CyberGlock")

	# Need to properly check here if a connection attempt has succeeded or failed
	print("Client connected: " + str(id))

func _on_peer_disconnected(id: int) -> void:
	print("Client disconnected: " + str(id))
	if is_server():
		connected_users.erase(id)
		for character in characters.get_children() as Array[CharacterBody2D]:
			var player: PlayerCharacter = character as PlayerCharacter
			if player is not PlayerCharacter: continue
			if player.id == id:
				player.queue_free()
				break
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
