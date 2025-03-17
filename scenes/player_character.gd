class_name PlayerCharacter extends CharacterBody2D

signal health_changed(new_health: float)
signal weapon_fired(position: Vector2, direction: Vector2)

@export var max_health: float = 100.0
@export var speed: float = 300.0
@export var acceleration: float = 2000.0
@export var friction: float = 1000.0
@export var fire_rate: float = 0.2
@export var damage: float = 10.0
@export var max_shoot_distance: float = 1000.0
@export var projectile_speed: float = 1500.0

var health: float = max_health
var can_fire: bool = true
var fire_height: Vector2 = Vector2(0, 12.0)
var current_tween: Tween

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var arm_sprite: Sprite2D = $AnimatedSprite2D/ArmSprite2D
@onready var weapon_sprite: Sprite2D = $AnimatedSprite2D/ArmSprite2D/WeaponsSprite2D
@onready var weapon_muzzle: Marker2D = $AnimatedSprite2D/ArmSprite2D/WeaponsSprite2D/WeaponMuzzle
@onready var camera: Camera2D = $Camera2D
@onready var raycast: RayCast2D = $RayCast2D
@onready var fire_timer: Timer = $FireTimer
@onready var muzzle_flash: CPUParticles2D = $MuzzleFlash
@onready var impact_particles: CPUParticles2D = $ImpactParticles
@onready var projectile: Sprite2D = $BulletSprite2D

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
		weapon_sprite.flip_v = true
		weapon_sprite.position.y = 1
		weapon_muzzle.position.y = 2
	else:
		sprite.flip_h = false
		arm_sprite.flip_v = false
		arm_sprite.position.x = 5
		arm_sprite.position.y = 2
		weapon_sprite.flip_v = false
		weapon_sprite.position.y = 0
		weapon_muzzle.position.y = -2
	
	# Running backwards
	if (input_direction.x == 1) == sprite.flip_h:
		sprite.speed_scale = -1
	else:
		sprite.speed_scale = 1
	
	# Handle rotation towards mouse
	arm_sprite.look_at(get_global_mouse_position())
	
	# Handle shooting
	if Input.is_action_pressed("shoot") and can_fire:
		shoot()

func shoot() -> void:
	can_fire = false
	fire_timer.start()
	
	# Get the global position of the weapon muzzle
	var muzzle_global_pos = weapon_muzzle.global_position
	
	# Get direction to mouse from the muzzle position
	var direction = Vector2(cos(arm_sprite.rotation), sin(arm_sprite.rotation))
	
	# Set raycast position and direction with fire_height offset
	raycast.global_position = muzzle_global_pos + fire_height
	raycast.target_position = direction * max_shoot_distance
	raycast.force_raycast_update()
	
	# Variables for beam effect
	var hit_something = false
	var collision_point = muzzle_global_pos + direction * max_shoot_distance
	
	# Check if raycast hit something
	if raycast.is_colliding():
		collision_point = raycast.get_collision_point() - fire_height
		var collider = raycast.get_collider()
		hit_something = true
		
		# Apply damage if hit an enemy
		if collider.has_method("take_damage"):
			collider.take_damage(damage)
	
	# Show visual effects
	create_shot_effects(muzzle_global_pos, collision_point, direction, hit_something)

func create_shot_effects(muzzle_pos: Vector2, impact_pos: Vector2, direction: Vector2, hit_something: bool) -> void:
	# 1. Muzzle flash effect
	muzzle_flash.global_position = muzzle_pos
	muzzle_flash.rotation = direction.angle()
	muzzle_flash.restart()
	muzzle_flash.emitting = true
	
	# 2. Bullet effect
	animate_projectile(muzzle_pos, impact_pos, direction, hit_something)
	
	# 3. Impact effect (if hit something)
	if hit_something:
		impact_particles.global_position = impact_pos
		impact_particles.rotation = (direction * -1).angle()  # Particles emit opposite to beam direction
		impact_particles.restart()
		impact_particles.emitting = true
	
	# 4. Camera shake effect (subtle)
	camera.offset = Vector2(randf_range(-2, 2), -2)
	create_tween().tween_property(camera, "offset", Vector2.ZERO, 0.1)
	
	# 5. Emit signal for other effects (like sound)
	weapon_fired.emit(muzzle_pos, direction)

func animate_projectile(start_pos: Vector2, end_pos: Vector2, direction: Vector2, hit_something: bool) -> void:
	# Cancel any existing tween
	if current_tween and current_tween.is_valid():
		current_tween.kill()
	
	# Set up projectile
	projectile.global_position = start_pos
	projectile.rotation = direction.angle()
	projectile.visible = true
	
	# Calculate travel time based on distance and speed
	var distance = start_pos.distance_to(end_pos)
	var travel_time = distance / projectile_speed
	
	# Create new tween
	current_tween = create_tween()
	current_tween.tween_property(projectile, "global_position", end_pos, travel_time)
	
	# When tween completes, show impact effect and hide projectile
	current_tween.tween_callback(func():
		projectile.visible = false
		
		if hit_something:
			impact_particles.global_position = end_pos
			impact_particles.rotation = (direction * -1).angle()
			impact_particles.restart()
			impact_particles.emitting = true
	)

func take_damage(amount: float) -> void:
	health -= amount
	health = max(0, health)
	health_changed.emit(health)
	print(amount)
	
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

func _on_fire_timer_timeout() -> void:
	can_fire = true
