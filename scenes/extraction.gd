extends Node2D
class_name Extraction

@onready var area_2d = $Area2D

func _ready() -> void:
	area_2d.monitoring = is_multiplayer_authority()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if not is_multiplayer_authority(): return
	var player: PlayerCharacter = body as PlayerCharacter
	if player == null: return
	player.rpc("extract")
