extends Node2D
class_name Extraction

@onready var area_2d = $Area2D

func _ready() -> void:
	area_2d.monitoring = MultiplayerManager.is_server()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if not MultiplayerManager.is_server(): return
	var player: PlayerCharacter = body as PlayerCharacter
	if player == null: return
	#player.rpc("extract")
	player.toggle_extraction.rpc()

func _on_area_2d_body_exited(body: Node2D) -> void:
	if not MultiplayerManager.is_server(): return
	var player: PlayerCharacter = body as PlayerCharacter
	if player == null: return
	player.toggle_extraction.rpc(false)
