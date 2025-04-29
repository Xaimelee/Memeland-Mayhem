class_name PlayerCharacter extends CharacterBody2D

signal health_changed(new_health: float)

enum State {ALIVE, DEAD}
enum ArmState {LEFT, RIGHT}
enum WeaponState {PRIMARY, SECONDARY}

@export var max_health: float = 100.0
@export var speed: float = 300.0
@export var acceleration: float = 2000.0
@export var friction: float = 1000.0
@export var id: int = 1
@export var player_input: PlayerInput

var health: float = max_health
var input_direction: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var mouse_position: Vector2 = Vector2.ZERO
var current_arm_state: ArmState = ArmState.LEFT
var current_state: State = State.ALIVE
var current_weapon_state: WeaponState = WeaponState.PRIMARY
var movement_history: Array[Dictionary] = []

# CSP
const CORRECTION_THRESHOLD: float = 10
var is_correcting: bool = false
# For server
var recent_input_direction: Vector2 = Vector2.ZERO
var recent_tick = 0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var arm_sprite: Sprite2D = $AnimatedSprite2D/ArmSprite2D
@onready var primary_weapon: Node2D = $AnimatedSprite2D/ArmSprite2D/BoringRifle
@onready var secondary_weapon: Node2D = $AnimatedSprite2D/ArmSprite2D/CyberGlock
@onready var weapon: Weapon = primary_weapon
@onready var damage_area: Area2D = $DamageArea2D
@onready var camera: Camera2D = $Camera2D
@onready var rollback_synchronizer: RollbackSynchronizer = $RollbackSynchronizer

func _ready() -> void:
	player_input.player_character = self

func _process(delta: float) -> void:
	return
	# We only want to calculate physic interactions on the server so we need to lerp the player movement on clients...
	# so it still feels smooth. This will need testing with latency.
	#var lerp_movement: bool = false
	#if not MultiplayerManager.is_server() and not has_ownership():
		#lerp_movement = true
	##elif has_ownership() and is_correcting:
		##global_position = global_position.lerp(target_position, 5.0 * delta)
	##elif has_ownership() and not is_correcting and player_input.input_direction == Vector2.ZERO:
		##global_position = global_position.lerp(target_position, 10.0 * delta)
	#if lerp_movement:
		#global_position = global_position.lerp(target_position, 30.0 * delta)

func _rollback_tick(delta, tick, is_fresh) -> void:
	if player_input.input_direction != Vector2.ZERO:
		# Accelerate when there's input
		#if MultiplayerManager.is_server() or has_ownership():
		velocity = velocity.move_toward(player_input.input_direction * speed, acceleration * delta)
		# Play movement animation
		#sprite.play("run")
	else:
		# Apply friction when no input
		#if MultiplayerManager.is_server() or has_ownership():
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	#if MultiplayerManager.is_server() or has_ownership():
	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor

func _physics_process(delta: float) -> void:
	if !has_ownership(): 
		# This may not be entirely efficient but its an easy way to do this...
		# because we don't currently have a pre game state and have a player...
		# already in the map for easy testing
		camera.enabled = false
	if current_state == State.DEAD: return
	
	# Handle movement
	#if has_ownership():
	#	input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	#	rpc_id(1, "send_input_direction", input_direction)
	#if player_input.input_direction != Vector2.ZERO:
		## Accelerate when there's input
		#if MultiplayerManager.is_server() or has_ownership():
			#velocity = velocity.move_toward(player_input.input_direction * speed, acceleration * delta)
		## Play movement animation
		##sprite.play("run")
	#else:
		## Apply friction when no input
		#if MultiplayerManager.is_server() or has_ownership():
			#velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		# Play idle animation
		#sprite.play("idle")

	# Probably replace with some synced bool if moving which can be client authority if...
	# it is purely for visuals
	if player_input.input_direction != Vector2.ZERO:
		# Play movement animation
		sprite.play("run")
	else:
		# Play idle animation
		sprite.play("idle")

	# Apply movement
	#if MultiplayerManager.is_server() or has_ownership():
		#move_and_slide()

	if MultiplayerManager.is_server():
		rpc("update_target_position", global_position)

	# Flip towards mouse
	if current_arm_state == ArmState.LEFT and mouse_position.x >= position.x:
		change_arm_state(ArmState.RIGHT)
	elif current_arm_state == ArmState.RIGHT and mouse_position.x < position.x:
		change_arm_state(ArmState.LEFT)

	# Handle rotation towards mouse
	arm_sprite.look_at(mouse_position)

	if not has_ownership(): return
	#if not is_correcting:
		#movement_history.push_front({ "position": global_position, "tick": player_input.current_tick})
		#if movement_history.size() > 200:
			#movement_history.pop_back()
	#else:
		#global_position = global_position.lerp(target_position, 5.0 * delta)
	# Move this to player input probably
	mouse_position = get_global_mouse_position()
	rpc_id(1, "send_mouse_position", mouse_position)

	# Handle shooting
	var shooting = false
	if Input.is_action_pressed("shoot_primary") and primary_weapon.can_fire:
		shooting = true
		change_weapon_state(WeaponState.PRIMARY)
		rpc_id(1, "send_weapon_state", current_weapon_state)
	elif Input.is_action_pressed("shoot_secondary") and secondary_weapon.can_fire:
		shooting = true
		change_weapon_state(WeaponState.SECONDARY)
		rpc_id(1, "send_weapon_state", current_weapon_state)
	if shooting:
		# We call shoot right away so it feels responsive to the client
		# This may result in "ghost" hits for high latency users
		shoot()
		rpc_id(1, "send_shoot")
	
func shoot() -> void:
	weapon.shoot()
	
	# 1. Arm effect
	var original_position = Vector2(-5, 3) if mouse_position.x < position.x else Vector2(5, 2)
	arm_sprite.position -= Vector2(cos(arm_sprite.rotation), sin(arm_sprite.rotation)) * 2
	create_tween().tween_property(arm_sprite, "position", original_position, 0.1)
	
	# 2. Camera shake effect (subtle)
	camera.offset = Vector2(randf_range(-2, 2), -2)
	create_tween().tween_property(camera, "offset", Vector2.ZERO, 0.1)


func take_damage(amount: float) -> void:
	if MultiplayerManager.is_server():
		rpc("update_health", amount)
	#health -= amount
	#health = max(0, health)
	#health_changed.emit(health)
	#
	#if health <= 0:
		#die()

func die() -> void:
	# Disable collision
	damage_area.collision_layer = 0
	collision_layer = 0
	collision_mask = 0
	
	# Play death animation
	sprite.play("die")
	
	# Remove the weapon holding arm
	arm_sprite.queue_free()
	
	# Emit signal before freeing
	#enemy_died.emit()
	
	# Start decay timer
	#decay_timer.start()

func change_state(new_state: State) -> void:
	current_state = new_state
	match current_state:
		State.DEAD:
			die()
		_:
			return

func change_arm_state(new_arm_state: ArmState) -> void:
	current_arm_state = new_arm_state
	match current_arm_state:
		ArmState.LEFT:
			sprite.flip_h = true
			arm_sprite.flip_v = true
			arm_sprite.position.x = -5
			arm_sprite.position.y = 3
			weapon.flip(true)
		_:
			sprite.flip_h = false
			arm_sprite.flip_v = false
			arm_sprite.position.x = 5
			arm_sprite.position.y = 2
			weapon.flip(false)

func change_weapon_state(new_weapon_state: WeaponState) -> void:
	if new_weapon_state == WeaponState.PRIMARY:
		weapon = primary_weapon
		secondary_weapon.visible = false
		current_weapon_state = WeaponState.PRIMARY
	else:
		weapon = secondary_weapon
		primary_weapon.visible = false
		current_weapon_state = WeaponState.SECONDARY
	weapon.visible = true

# Fix this later to respect client-server authority, likely need to be done in the weapon script?
@rpc("any_peer", "call_remote")
func send_shoot() -> void:
	if not validate_user_rpc("Possible shoot manipulation"): return
	rpc("update_shoot")

@rpc("any_peer", "call_remote")
func send_mouse_position(new_mouse_position: Vector2) -> void:
	if not validate_user_rpc("Possible mouse position manipulation"): return
	rpc("update_mouse_position", new_mouse_position)

@rpc("any_peer", "call_local")
func send_input_direction(new_input_direction: Vector2) -> void:
	if not validate_user_rpc("Possible input manipulation"): return
	input_direction = new_input_direction

@rpc("any_peer", "call_local")
func send_weapon_state(new_weapon_state: WeaponState) -> void:
	if not validate_user_rpc("Possible weapon state manipulation"): return
	rpc("update_weapon_state", new_weapon_state)

@rpc("authority", "call_local")
func update_shoot() -> void:
	# We locally show shoot visuals as soon as the request is sent to the server
	if has_ownership(): return
	shoot()

@rpc("authority", "call_local")
func update_weapon_state(new_weapon_state: WeaponState) -> void:
	# We locally show the weapon swap right away for the owner to prevent it feeling delayed
	if has_ownership(): return
	change_weapon_state(new_weapon_state)

@rpc("authority", "call_local")
func update_health(new_health: float) -> void:
	health -= new_health
	health = max(0, health)
	health_changed.emit(health)
	if health <= 0:
		change_state(State.DEAD)

@rpc("authority", "call_local")
func update_mouse_position(new_mouse_position: Vector2) -> void:
	# We dont need to update mouse position for the owner, since they sent the mouse position originally
	if has_ownership(): return
	mouse_position = new_mouse_position

@rpc("authority", "call_remote")
func update_target_position(new_target_position: Vector2) -> void:
	# We just update target position on clients
	target_position = new_target_position
	return
	#if not has_ownership(): return
	#var previous_movement = get_movement_history(tick)
	#var previous_position: Vector2 = Vector2.ZERO
	#if previous_movement.is_empty():
		#previous_position = target_position
	#else:
		#previous_position = previous_movement.get("position")
	#var distance: float = previous_position.distance_to(target_position)
	#if distance > CORRECTION_THRESHOLD:
		#is_correcting = true
	#else:
		#is_correcting = false

@rpc("authority", "call_local")
func init_player(new_id: int, spawn_position: Vector2) -> void:
	id = new_id
	target_position = spawn_position
	global_position = spawn_position
	player_input.set_multiplayer_authority(new_id)
	rollback_synchronizer.process_settings()

func get_movement_history(tick: int) -> Dictionary:
	for movement_dictionary in movement_history:
		if movement_dictionary.get("tick") != tick: continue
		return movement_dictionary
	return {}

func validate_user_rpc(error_message: String) -> bool:
	# Incase someone tries to change from rpc_id to rpc, we make sure that if somehow this is ran...
	# on local clients that it will get ignored.
	if not MultiplayerManager.is_server(): return false
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != id: 
		print(error_message)
		return false
	return true

func has_ownership() -> bool:
	return id == multiplayer.get_unique_id()
