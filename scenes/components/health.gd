extends Node
class_name Health

signal health_changed(current_health: float)

@export var max_health: float = 100.0

var current_health: float = max_health:
	get:
		return current_health
	set(value):
		var prev_health = current_health
		current_health = value
		current_health = max(0, current_health)
		if prev_health != current_health:
			health_changed.emit(current_health)

func _ready() -> void:
	if not is_multiplayer_authority(): return
	MultiplayerManager.player_connected.connect(_on_player_connected)

func change_health(new_health: float, should_replace: bool = false) -> void:
	# This might be better than checking if is server? since authority id will always be 1
	if not is_multiplayer_authority(): return
	var prev_health = current_health
	if should_replace:
		current_health = new_health
	else:
		current_health += new_health
	if prev_health != current_health:
		rpc("set_health", new_health)

#@rpc("authority", "call_local")
#func update_health(new_health: float) -> void:
	#current_health += new_health

@rpc("authority", "call_remote")
func set_health(new_health: float) -> void:
	current_health = new_health

# This is so we can sync server state with players who have joined later on
func _on_player_connected(id: int):
	rpc_id(id, "set_health", current_health)
