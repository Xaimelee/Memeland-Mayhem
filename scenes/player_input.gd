extends Node
class_name PlayerInput

var player_character: PlayerCharacter
var input_direction: Vector2 = Vector2.ZERO
var mouse_position: Vector2 = Vector2.ZERO
var target_mouse_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	NetworkTime.before_tick_loop.connect(_on_before_tick_loop)

func _on_before_tick_loop() -> void:
	if not is_multiplayer_authority(): return
	input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

func _process(delta: float) -> void:
	if not is_multiplayer_authority():
		mouse_position = mouse_position.lerp(target_mouse_position, 30.0 * delta)
		return
	#mouse_position = player_character.get_global_mouse_position()
	#rpc_id(1, "send_mouse_position", mouse_position)
	rpc("update_mouse_position", player_character.get_global_mouse_position())
#
#@rpc("authority", "call_remote")
#func send_mouse_position(new_mouse_position: Vector2) -> void:
	#rpc("update_mouse_position", new_mouse_position)

@rpc("authority", "call_local")
func update_mouse_position(new_mouse_position: Vector2) -> void:
	# We dont need to update mouse position for the owner, since they sent the mouse position originally
	if is_multiplayer_authority() or MultiplayerManager.is_server():
		mouse_position = new_mouse_position
		target_mouse_position = mouse_position
	else:
		target_mouse_position = new_mouse_position
