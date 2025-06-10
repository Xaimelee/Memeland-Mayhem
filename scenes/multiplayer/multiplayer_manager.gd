extends Node

# Server side signals
signal player_connected(id: int)
signal player_disconnected(id: int)

const SERVER_PORT: int = 8080
const PLAYER_SCENE: PackedScene = preload("uid://dxk1jvimm72ti")

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
	[],
	0
)

func _ready() -> void:
	 #Should allow for local menu testing
	if OS.has_feature("editor"):
		UserManager.user_data = guest_data
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func start_network() -> void:
	if not is_local():
		var player = get_tree().get_nodes_in_group("players")[0]
		if player != null:
			player.free()
	# Atm we assume start_network is always called by main after its loaded
	characters = get_node("/root/Main/Characters")
	player_spawn = get_node("/root/Main/PlayerSpawnPoint")
	var err: Error
	#multiplayer.peer_connected.connect(_on_peer_connected)
	#multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if is_server():
		err = peer.create_server(SERVER_PORT)
		if err == 0:
			multiplayer.multiplayer_peer = peer
			print("Server created")
	else:
		# NOTE: We need a way to easily change what ip is used. For testing, I will still use EC2 since it's probably quicker and ip never changes.
		err = peer.create_client("ws://" + server_ip + ":" + str(SERVER_PORT))
		if err == 0:
			#multiplayer.connected_to_server.connect(_on_connected_to_server)
			#multiplayer.connection_failed.connect(_on_connection_failed)
			#multiplayer.server_disconnected.connect(_on_server_disconnected)
			multiplayer.multiplayer_peer = peer
			print("Client Created")

@rpc("authority", "call_remote")
func request_user_id() -> void:
	if SolanaService.wallet.is_logged_in() and UserManager.user_data:
		# This isn't secure, we will also need to require some unique session token from them logging in...
		#... to make sure that even if user ids are leaked, people can't just log in as other users.
		rpc_id(1, "send_user_id", UserManager.user_data.user_id, UserManager.user_name)
	else:
		rpc_id(1, "send_user_id")

@rpc("any_peer", "call_remote")
func send_user_id(user_id: String = "guest", user_name: String = "Player") -> void:
	# Safeguard
	if not is_server(): return
	var peer_id: int = multiplayer.get_remote_sender_id()
	# This means this user wasn't added to the connected users dictionary when they...
	#... joined and should be made to rejoin.
	if not connected_users.has(peer_id):
		disconnect_user(peer_id)
		return
	var connected_user: ConnectedUser = connected_users[peer_id]
	# This means we already have approved the user id of this user
	if connected_user.status == 1: return
	connected_user.user_id = user_id
	connected_user.user_name = user_name
	# Gonna try and send snapshot here:
	MultiplayerSync.create_and_send_snapshot(peer_id)
	if not user_id.contains("guest"):
		var body: String = JSON.stringify({ "userId": user_id })
		Api.post_request(1, _on_successful_response, body)
	# Guest setup
	else:
		connected_user.user_data = guest_data
		connected_user.status = 1
		print("Loading peer: " + str(peer_id) + " as guest")
		spawn_player(peer_id, connected_user)

func spawn_player(peer_id: int, connected_user: ConnectedUser) -> void:
	#In future we should probably check if snapshot is done being processed
	player_connected.emit(peer_id)
	var player: PlayerCharacter = MultiplayerSync.create_and_spawn_node(PLAYER_SCENE, characters) as PlayerCharacter
	#var player: PlayerCharacter = PLAYER_SCENE.instantiate()
	#characters.add_child(player, true)
	var spawn_position: Vector2 = player_spawn.global_position
	var random_offset: Vector2 = Vector2(randf_range(-5, 5), randf_range(-5, 5))
	player.set_multiplayer_authority(1)
	player.player_input.set_multiplayer_authority(peer_id)
	player.rpc("init_player", peer_id, spawn_position + random_offset, connected_user.user_name)
	for item in connected_user.user_data.inventory:
		var item_name: String = item["item_name"]
		var slot: int = item["slot"]
		player.inventory.rpc("create_and_add_item", item_name, slot)
	# Testing syntax and flow, this has to be loaded via database at some point
	#player.inventory.rpc("create_and_add_item", "BoringRifle")
	#player.inventory.rpc("create_and_add_item", "CyberGlock")

func disconnect_user(peer_id: int) -> void:
	peer.disconnect_peer(peer_id)
	connected_users.erase(peer_id)

func player_extracted(player: PlayerCharacter) -> void:
	if is_local(): 
		Globals.return_to_menu()
		return
	# If the server somehow owns a player and it extracts, we probably shouldn't run this
	if player.id == 1: return
	if connected_users.has(player.id):
		var user: ConnectedUser = connected_users[player.id]
		user.status = 3
		if not user.user_id.contains("guest"):
			# Update inventory
			save_loadout(player, user)
			await get_tree().create_timer(3).timeout
			print(str(player.id) + ": Updated Inventory after Extraction")
	disconnect_user(player.id)

# We wipe inventory in backend here and disconnect user
func player_died(player: PlayerCharacter) -> void:
	# No real reason to run this logic if it's local/offline testing
	if is_local(): 
		Globals.return_to_menu()
		return
	# If the server somehow owns a player and it dies, we probably shouldn't run this
	if player.id == 1: return
	if connected_users.has(player.id):
		var user: ConnectedUser = connected_users[player.id]
		user.status = 2
		if not user.user_id.contains("guest"):
			# Wipe inventory
			# We'll wait 3 seconds just to give the api time to run, which wipes their loadout
			# or we use api request response, provided we can match up to dead player id
			wipe_loadout(user)
			await get_tree().create_timer(3).timeout
			print(str(player.id) + ": Wiped Inventory after Death")
	disconnect_user(player.id)

func wipe_loadout(user: ConnectedUser) -> void:
	var data = {
		"walletAddress": user.user_data.wallet_address,
		"inventory": [],
		"xp": user.user_data.xp
	}
	var json_body = JSON.stringify(data)
	Api.post_request(3, _on_successful_response_loadout, json_body)

func save_loadout(player: PlayerCharacter, user: ConnectedUser) -> void:
	var data = {
		"walletAddress": user.user_data.wallet_address,
		"inventory": [],
		"xp": user.user_data.xp + player.current_additive_xp
	}
	# We have to make sure either inventory is saved and sent when player dies OR this is called before...
	# items drop on ground on the server
	for n in player.inventory.items.size():
		var item: Item = player.inventory.get_item_at_index(n)
		if item:
			data["inventory"].append({ "item_name": item.item_name.to_snake_case(), "slot": n})
	var json_body = JSON.stringify(data)
	Api.post_request(3, _on_successful_response_loadout, json_body)

# Do disconnects or whatever after this response is called in future, for now we just use 3 second timer
func _on_successful_response_loadout(response: ResponseType) -> void:
	if response != null:
		print("Successful Update of Inventory")
	else:
		print("Error Updating Inventory")

# NOTE: Lets change the response type to wrap user data response type with the peer id its intended for.
# or we have apirequest send itself so we can have a local dictionary here to match requests to peer ids
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
		spawn_player(peer_id, connected_user)
		break

func _on_connected_to_server() -> void:
	print("Client Connected")

func _on_connection_failed() -> void:
	print("Client Failed to Connect")
	# Return to menu if failed to connect
	Globals.return_to_menu()

func _on_server_disconnected() -> void:
	print("Client Disconnected from Server")
	# Return to menu if disconnected
	Globals.return_to_menu()

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
		var was_killed: bool = false
		var player: PlayerCharacter = get_player_by_id(id)
		if connected_users.has(id):
			var user: ConnectedUser = connected_users[id]
			# Disconnected while playing
			was_killed = user.status == 2
			if user.status == 1 and not user.user_id.contains("guest"):
				print(str(user.user_id) + ": Wiped Inventory after Disconnect")
				# Wipe inventory
				wipe_loadout(user)
		connected_users.erase(id)
		# We will always delete for now until I add logic to deactivate stuff reliant on peer being connected
		#if not was_killed:
		if player != null:
			MultiplayerSync.delete_and_despawn_node(player)
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

func get_player_by_id(peer_id: int) -> PlayerCharacter:
	for character in characters.get_children() as Array[CharacterBody2D]:
		var player: PlayerCharacter = character as PlayerCharacter
		if player is not PlayerCharacter: continue
		if player.id == peer_id:
			return player
	return null
