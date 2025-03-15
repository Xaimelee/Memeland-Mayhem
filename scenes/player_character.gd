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

# Visual effect settings
@export var beam_color: Color = Color(0.9, 0.6, 0.1, 0.8)
@export var beam_width: float = 3.0
@export var beam_fade_time: float = 0.1
@export var muzzle_flash_scale: float = 0.5
@export var impact_effect_scale: float = 0.7

var health: float = max_health
var can_fire: bool = true
var current_beam_alpha: float = 0.0
var fire_height: Vector2 = Vector2(0, 12.0)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var arm_sprite: Sprite2D = $AnimatedSprite2D/ArmSprite2D
@onready var weapon_sprite: Sprite2D = $AnimatedSprite2D/ArmSprite2D/WeaponsSprite2D
@onready var weapon_muzzle: Marker2D = $AnimatedSprite2D/ArmSprite2D/WeaponsSprite2D/WeaponMuzzle
@onready var camera: Camera2D = $Camera2D
@onready var raycast: RayCast2D = $RayCast2D
@onready var line: Line2D = $Line2D
@onready var fire_timer: Timer = $FireTimer
@onready var bullet_effect_timer: Timer = $BulletEffectTimer

# New visual effect nodes
@onready var muzzle_flash: CPUParticles2D = $MuzzleFlash
@onready var beam_particles: CPUParticles2D = $BeamParticles
@onready var impact_particles: CPUParticles2D = $ImpactParticles

func _ready() -> void:
	# Initialize visual effects
	line.default_color = beam_color
	line.width = beam_width
	line.visible = false
	
	# Set up muzzle flash
	muzzle_flash.emitting = false
	muzzle_flash.modulate = beam_color
	muzzle_flash.scale = Vector2(muzzle_flash_scale, muzzle_flash_scale)
	
	# Set up beam particles
	beam_particles.emitting = false
	beam_particles.modulate = beam_color
	
	# Set up impact particles
	impact_particles.emitting = false
	impact_particles.scale = Vector2(impact_effect_scale, impact_effect_scale)
	
	# Make sure bullet effect timer is properly set up
	bullet_effect_timer.wait_time = beam_fade_time
	if not bullet_effect_timer.timeout.is_connected(_on_bullet_effect_timer_timeout):
		bullet_effect_timer.timeout.connect(_on_bullet_effect_timer_timeout)

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
	
	# Fade out beam effect
	if line.visible and current_beam_alpha > 0:
		current_beam_alpha = max(0, current_beam_alpha - delta * (1.0 / beam_fade_time))
		var color = beam_color
		color.a = current_beam_alpha
		line.default_color = color

func shoot() -> void:
	can_fire = false
	fire_timer.start()
	
	# Get the global position of the weapon muzzle
	var muzzle_global_pos = weapon_muzzle.global_position
	
	# Get direction to mouse from the muzzle position
	#var direction = (get_global_mouse_position() - muzzle_global_pos).normalized()
	var direction = Vector2(cos(arm_sprite.rotation), sin(arm_sprite.rotation))
	
	# Set raycast position and direction with fire_height offset
	raycast.global_position = muzzle_global_pos + fire_height
	raycast.target_position = direction * max_shoot_distance
	raycast.force_raycast_update()
	
	# Convert muzzle position to line's local space
	var muzzle_local_pos = line.to_local(muzzle_global_pos)
	
	# Variables for beam effect
	var beam_length = max_shoot_distance
	var hit_something = false
	var collision_point = muzzle_global_pos + direction * max_shoot_distance
	
	# Check if raycast hit something
	if raycast.is_colliding():
		collision_point = raycast.get_collision_point() - fire_height
		var collider = raycast.get_collider()
		hit_something = true
		
		# Calculate beam length
		beam_length = muzzle_global_pos.distance_to(collision_point)
		
		# Convert collision point to line's local space
		var collision_local_pos = line.to_local(collision_point)
		
		# Set line points for visual effect
		line.points[0] = muzzle_local_pos
		line.points[1] = collision_local_pos
		
		# Apply damage if hit an enemy
		if collider.has_method("take_damage"):
			collider.take_damage(damage)
	else:
		# Calculate end point if nothing was hit
		var end_point = muzzle_global_pos + direction * max_shoot_distance
		var end_local_pos = line.to_local(end_point)
		
		# Set line to max distance if nothing was hit
		line.points[0] = muzzle_local_pos
		line.points[1] = end_local_pos
	
	# Show visual effects
	create_shot_effects(muzzle_global_pos, collision_point, direction, beam_length, hit_something)
	
	# Reset beam alpha for fade effect
	current_beam_alpha = 0.5
	var color = beam_color
	color.a = current_beam_alpha
	line.default_color = color
	
	# Show line effect
	line.visible = true
	bullet_effect_timer.start()

func create_shot_effects(muzzle_pos: Vector2, impact_pos: Vector2, direction: Vector2, beam_length: float, hit_something: bool) -> void:
	# 1. Muzzle flash effect
	muzzle_flash.global_position = muzzle_pos
	muzzle_flash.rotation = direction.angle()
	muzzle_flash.restart()
	muzzle_flash.emitting = true
	
	# 2. Beam particles effect
	beam_particles.global_position = muzzle_pos
	beam_particles.rotation = direction.angle()
	beam_particles.emission_rect_extents.x = beam_length * 0.5
	beam_particles.position.x = beam_length * 0.5
	beam_particles.amount = int(beam_length / 10.0)  # Adjust particle density based on beam length
	beam_particles.restart()
	beam_particles.emitting = true
	
	# 3. Impact effect (if hit something)
	if hit_something:
		impact_particles.global_position = impact_pos
		impact_particles.rotation = (direction * -1).angle()  # Particles emit opposite to beam direction
		impact_particles.restart()
		impact_particles.emitting = true
	
	# 4. Camera shake effect (subtle)
	camera.offset = Vector2(randf_range(-2, 2), randf_range(-2, 2))
	create_tween().tween_property(camera, "offset", Vector2.ZERO, 0.1)
	
	# 5. Emit signal for other effects (like sound)
	weapon_fired.emit(muzzle_pos, direction)

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

func _on_bullet_effect_timer_timeout() -> void:
	# Hide line effect
	line.visible = false
	beam_particles.emitting = false
