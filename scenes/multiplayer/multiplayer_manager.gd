extends Node

const SERVER_PORT: int = 8080
const SERVER_IP: String = "localhost"

@onready var peer = WebSocketMultiplayerPeer.new()

func _ready() -> void:
	## We will need a proper setup where based on game state (i.e going from menu to game)
	## triggers the network to be started
	start_network()

func start_network() -> void:
	var err: Error
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if OS.has_feature("dedicated_server"):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
		err = peer.create_server(SERVER_PORT)
		if err == 0:
			multiplayer.multiplayer_peer = peer
			print("Server created")
	else:
		err = peer.create_client("ws://" + SERVER_IP + ":" + str(SERVER_PORT))
		if err == 0:
			multiplayer.multiplayer_peer = peer
			print("Client created")

func _on_connected_to_server() -> void:
	print("Client Connected")

## ID of 1 means connection to the server (authority)
func _on_peer_connected(id: int) -> void:
	## Need to properly check here if a connection attempt has succeeded or failed
	print("Client connected: " + str(id))

func _on_peer_disconnected(id: int) -> void:
	print("Client disconnected: " + str(id))
