extends Node
class_name StateMachine

signal state_changed(old_state: State, new_state: State)

@export var starting_state: State
# I've added this so we can use this for client side and visual state machines which...
# don't necessarily need to be mp synced by the server
@export var sync_state_changes: bool = true

var current_state: State:
	set(value):
		# If there is a current state, run exit logic
		if current_state:
			current_state.exit()
			current_state.is_active = false
		current_state = value
		# If new state is not null, run enter logic
		if current_state:
			current_state.enter()
			current_state.is_active = true
var states: Dictionary = {}

func _ready() -> void:
	if starting_state:
		call_deferred("_set_starting_state", starting_state)
		#current_state = starting_state
	elif get_child_count() > 0:
		#current_state = get_child(0)
		call_deferred("_set_starting_state", get_child(0))
	# We can assume there are no states are manage
	else:
		return

	for state: State in get_children():
		states[state.name.to_lower()] = state

	if MultiplayerManager.is_server() and sync_state_changes:
		MultiplayerSync.player_synced.connect(_on_player_synced)

func _process(delta: float) -> void:
	if not current_state: return
	current_state.process(delta)

func _physics_process(delta: float) -> void:
	if not current_state: return
	current_state.physics_process(delta)

# We use this helper method because if any states rely on parent variables...
# it will error because children ready get called before the parent
func _set_starting_state(state: State) -> void:
	current_state = state

# For now changing of states is not auto delegated to the states themselves.
# This is because if you translate the enemy logic into delegated state logic to switch...
# states then we'd have pretty bloated state scripts checking different conditions.
# it's much less code to just have the enemy script still decide when to change states.
func change_state(new_state_name: String) -> void:
	if not MultiplayerManager.is_server() and sync_state_changes: return
	var new_state: State = states[new_state_name.to_lower()]
	if not new_state: 
		print(new_state_name + " is not a valid state name.")
		return
	if new_state == current_state: return
	current_state = new_state
	if MultiplayerManager.is_server() and sync_state_changes:
		rpc("update_state", new_state_name.to_lower())

@rpc("authority", "call_remote")
func update_state(new_state_name: String) -> void:
	# Maybe also add a check here for if new state is same as current on client?
	current_state = states[new_state_name.to_lower()]

func is_state(state_name: String) -> bool:
	if not current_state: return false
	return current_state.name.to_lower() == state_name.to_lower()

# This is so we can sync server state with players who have joined later on
func _on_player_synced(id: int):
	if not current_state: return
	rpc_id(id, "update_state", current_state.name.to_lower())
