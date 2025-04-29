extends Node
class_name PlayerInput

var player_character: PlayerCharacter
var client_tick: int = 0
var previous_direction: Vector2 = Vector2.ZERO
var input_direction: Vector2 = Vector2.ZERO
var server_tick: int = 0
var last_input_tick_duration: int = 0
var input_history: Array[Dictionary] = []

func _process(delta: float) -> void:
	# Should just run for client who owns this player input
	if not is_multiplayer_authority(): return
	if player_character.is_correcting: return
	var prev_input_direction: Vector2 = input_direction
	input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_direction != prev_input_direction:
		rpc_id(1, "send_input_direction", input_direction, client_tick)

func _physics_process(delta: float) -> void:
	if MultiplayerManager.is_server():
		server_tick += 1
	if not is_multiplayer_authority(): return
	client_tick += 1
	if player_character.is_correcting: return
	input_history.push_front({ "input": input_direction, "tick": client_tick})
	client_tick += 1
	if input_history.size() > 200:
		input_history.pop_back()

func get_input_history(tick: int) -> Dictionary:
	for input_dictionary in input_history:
		if input_dictionary.get("tick") != tick: continue
		return input_dictionary
	return {}

@rpc("authority", "call_remote")
func send_input_direction(new_input_direction: Vector2, new_tick: int) -> void:
	#if not validate_user_rpc("Possible input manipulation"): return
	last_input_tick_duration = new_tick - client_tick
	previous_direction = input_direction
	input_direction = new_input_direction
	client_tick = new_tick
