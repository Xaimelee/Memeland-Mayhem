class_name PlayerCharacter extends CharacterBody2D

signal health_changed(new_health: float)

@export var max_health: float = 100.0
@export var speed: float = 300.0
@export var acceleration: float = 2000.0
@export var friction: float = 1000.0

var health: float = max_health

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var arm_sprite: Sprite2D = $AnimatedSprite2D/ArmSprite2D
@onready var primary_weapon: Node2D = $AnimatedSprite2D/ArmSprite2D/BoringRifle
@onready var secondary_weapon: Node2D = $AnimatedSprite2D/ArmSprite2D/CyberGlock
@onready var weapon: Node2D = primary_weapon
@onready var camera: Camera2D = $Camera2D

func _physics_process(delta: float) -> void:
	# Handle movement
	var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_direction != Vector2.ZERO:
		# Accelerate when there's input
		velocity = velocity.move_toward(input_direction * speed, acceleration * delta)
		# Play movement animation
		sprite.play("run")
	else:
		# Apply friction when no input
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		# Play idle animation
		sprite.play("idle")
	
	# Apply movement
	move_and_slide()
	
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
	
	# Running backwards
	if (input_direction.x == 1) == sprite.flip_h:
		sprite.speed_scale = -1
	else:
		sprite.speed_scale = 1
	
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
	#else:
		#sprite.play("hit")

func die() -> void:
	sprite.play("die")
	# Wait for animation to finish
	await sprite.animation_finished
	print("dead")
	queue_free()
