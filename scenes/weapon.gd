extends Node2D
class_name Weapon

@export var damage: float = 10.0
@export var max_shoot_distance: float = 1000.0
@export var projectile_speed: float = 5000.0

var can_fire: bool = true
# Fire height is required to avoid horizontally shot bullets stuck in the wall,
# while the player is right in front of the wall.
var fire_height: Vector2 = Vector2(0, 12.0)  
var current_tween: Tween

@onready var weapon_sprite: Sprite2D = $WeaponsSprite2D
@onready var weapon_muzzle: Marker2D = $WeaponsSprite2D/WeaponMuzzle
@onready var raycast: RayCast2D = $WeaponsSprite2D/WeaponMuzzle/RayCast2D
@onready var fire_timer: Timer = $FireTimer
@onready var muzzle_flash: CPUParticles2D = $WeaponsSprite2D/WeaponMuzzle/MuzzleFlash
@onready var impact_particles: CPUParticles2D = $ImpactParticles
@onready var projectile: Sprite2D = $WeaponsSprite2D/WeaponMuzzle/BulletSprite2D

func flip(to_flip) -> void:
	if to_flip:
		weapon_sprite.flip_v = true
		weapon_sprite.position.y = 1
		weapon_muzzle.position.y = 2
	else:
		weapon_sprite.flip_v = false
		weapon_sprite.position.y = 0
		weapon_muzzle.position.y =  -2

func shoot() -> void:
	can_fire = false
	fire_timer.start()
	update_line_of_fire()
	handle_hit()

func update_line_of_fire() -> void:
	# Set raycast position and direction with fire_height offset
	raycast.global_position = weapon_muzzle.global_position + fire_height
	raycast.target_position = Vector2(max_shoot_distance, 0)
	raycast.force_raycast_update()

func handle_hit() -> void:
	# Variables for beam effect
	var hit_something = false
	
	# Get direction to target from the muzzle position
	var direction = Vector2(cos(get_parent().rotation), sin(get_parent().rotation))
	var collision_point = weapon_muzzle.global_position + direction * max_shoot_distance
	
	# Check if raycast hit something
	if raycast.is_colliding():
		collision_point = raycast.get_collision_point() - fire_height
		var collider = raycast.get_collider()
		hit_something = true
		
		# Apply damage if hit an enemy
		if collider.get_parent().has_method("take_damage"):
			collider.get_parent().take_damage(damage)
	
	# Show visual effects
	create_shot_effects(weapon_muzzle.global_position, collision_point, hit_something)

func create_shot_effects(muzzle_pos: Vector2, impact_pos: Vector2, hit_something: bool) -> void:
	# 1. Muzzle flash effect
	muzzle_flash.restart()
	muzzle_flash.emitting = true
	
	# 2. Bullet effect
	animate_projectile(muzzle_pos, impact_pos, hit_something)

func animate_projectile(start_pos: Vector2, end_pos: Vector2, hit_something: bool) -> void:
	# Cancel any existing tween
	if current_tween and current_tween.is_valid():
		current_tween.kill()
	
	# Set up projectile
	projectile.global_position = start_pos
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
			impact_particles.restart()
			impact_particles.emitting = true
	)

func _on_fire_timer_timeout() -> void:
	can_fire = true
