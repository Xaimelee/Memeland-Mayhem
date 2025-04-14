extends Node

const PORT: int = 8080

@onready var peer = WebSocketMultiplayerPeer.new()

func _ready() -> void:
	## We will need a proper setup where based on game state (i.e going from menu to game)
	## triggers the network to be started
	start_network()

func start_network() -> void:
	var err: Error
	if OS.has_feature("dedicated_server"):
		err = peer.create_server(PORT)
		if err == 0:
			print("Server created")
	else:
		err = peer.create_client("localhost")
		if err == 0:
			multiplayer.connected_to_server.connect(_on_connected_to_server)
			print("Client created")
	if err == 0:
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_connected.connect(_on_peer_disconnected)

func _on_connected_to_server() -> void:
	print("Client Connected")

func _on_peer_connected(id: int) -> void:
	print("Client connected: " + str(id))

func _on_peer_disconnected(id: int) -> void:
	print("Client disconnected: " + str(id))
