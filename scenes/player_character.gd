class_name PlayerCharacter extends CharacterBody2D

signal health_changed(new_health: float)

@export var max_health: float = 100.0
@export var speed: float = 300.0
@export var acceleration: float = 2000.0
@export var friction: float = 1000.0
@export var id: int = 1

var health: float = max_health
var input_direction: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var arm_sprite: Sprite2D = $AnimatedSprite2D/ArmSprite2D
@onready var primary_weapon: Node2D = $AnimatedSprite2D/ArmSprite2D/BoringRifle
@onready var secondary_weapon: Node2D = $AnimatedSprite2D/ArmSprite2D/CyberGlock
@onready var weapon: Node2D = primary_weapon
@onready var damage_area: Area2D = $DamageArea2D
@onready var camera: Camera2D = $Camera2D

func _process(delta: float) -> void:
	# We only want to calculate physic interactions on the server so we need to lerp the player movement on clients...
	# so it still feels smooth. This will need testing with latency.
	if not MultiplayerManager.is_server():
		global_position = global_position.lerp(target_position, 30.0 * delta)

func _physics_process(delta: float) -> void:
	if !has_ownership(): 
		# This may not be entirely efficient but its an easy way to do this...
		# because we don't currently have a pre game state and have a player...
		# already in the map for easy testing
		camera.enabled = false
	if health <= 0: return
	
	# Handle movement
	if has_ownership():
		input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		rpc("update_input_direction", input_direction)
	
	if input_direction != Vector2.ZERO:
		# Accelerate when there's input
		if MultiplayerManager.is_server():
			velocity = velocity.move_toward(input_direction * speed, acceleration * delta)
		# Play movement animation
		sprite.play("run")
	else:
		# Apply friction when no input
		if MultiplayerManager.is_server():
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		# Play idle animation
		sprite.play("idle")

	if MultiplayerManager.is_server():
		rpc("update_velocity", velocity)
	# Apply movement
	if MultiplayerManager.is_server():
		move_and_slide()
		rpc("update_target_position", global_position)
	
	if !has_ownership(): return
	
	# Flip towards mouse
	if get_global_mouse_position().x < position.x:
		sprite.flip_h = true
		arm_sprite.flip_v = true
		arm_sprite.position.x = -5
		arm_sprite.position.y = 3
		weapon.flip(true)
	else:
		sprite.flip_h = false
		arm_sprite.flip_v = false
		arm_sprite.position.x = 5
		arm_sprite.position.y = 2
		weapon.flip(false)
	
	# Handle rotation towards mouse
	arm_sprite.look_at(get_global_mouse_position())
	
	# Handle shooting
	var shooting = false
	if Input.is_action_pressed("shoot_primary") and primary_weapon.can_fire:
		weapon = primary_weapon
		secondary_weapon.visible = false
		shooting = true
	elif Input.is_action_pressed("shoot_secondary") and secondary_weapon.can_fire:
		weapon = secondary_weapon
		primary_weapon.visible = false
		shooting = true
	if shooting:
		weapon.visible = true
		shoot()
	
func shoot() -> void:
	weapon.shoot()
	
	# 1. Arm effect
	var original_position = Vector2(-5, 3) if get_global_mouse_position().x < position.x else Vector2(5, 2)
	arm_sprite.position -= Vector2(cos(arm_sprite.rotation), sin(arm_sprite.rotation)) * 2
	create_tween().tween_property(arm_sprite, "position", original_position, 0.1)
	
	# 2. Camera shake effect (subtle)
	camera.offset = Vector2(randf_range(-2, 2), -2)
	create_tween().tween_property(camera, "offset", Vector2.ZERO, 0.1)


func take_damage(amount: float) -> void:
	health -= amount
	health = max(0, health)
	health_changed.emit(health)
	
	if health <= 0:
		die()

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

@rpc("any_peer", "call_local")
func update_input_direction(new_input_direction: Vector2) -> void:
	input_direction = new_input_direction

@rpc("authority", "call_local")
func update_velocity(new_velocity: Vector2) -> void:
	velocity = new_velocity

@rpc("authority", "call_remote")
func update_target_position(new_target_position: Vector2) -> void:
	target_position = new_target_position

@rpc("authority", "call_local")
func init_player(new_id: int, spawn_position: Vector2) -> void:
	id = new_id
	target_position = spawn_position
	global_position = spawn_position

func has_ownership() -> bool:
	return id == multiplayer.get_unique_id()
