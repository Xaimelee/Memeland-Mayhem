extends Item
class_name Weapon

@export var damage: float = 10.0
@export var max_shoot_distance: float = 1000.0
@export var projectile_texture: Texture2D
@export var impact_particles_lifetime: float = 0.5

var can_fire: bool = true
# Fire height is required to avoid horizontally shot bullets stuck in the wall,
# while the player is right in front of the wall.
var fire_height: Vector2 = Vector2(0, 12.0)  

@onready var weapon_sprite: Sprite2D = $WeaponsSprite2D
@onready var weapon_muzzle: Marker2D = $WeaponsSprite2D/WeaponMuzzle
@onready var raycast: RayCast2D = $WeaponsSprite2D/WeaponMuzzle/RayCast2D
@onready var fire_timer: Timer = $FireTimer
@onready var muzzle_flash: CPUParticles2D = $WeaponsSprite2D/WeaponMuzzle/MuzzleFlash

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
	# Get direction to target from the muzzle position
	var direction = Vector2(cos(get_parent().rotation), sin(get_parent().rotation))
	var collision_point = weapon_muzzle.global_position + direction * max_shoot_distance
	var collider: Node = null
	
	# Check if raycast hit something
	if raycast.is_colliding():
		collision_point = raycast.get_collision_point() - fire_height
		collider = raycast.get_collider().get_parent()
		if not collider: return
		# Apply damage if hit an enemy
		var _damage: Damage = collider.get_node_or_null("Damage")
		if MultiplayerManager.is_server() and _damage:
			# I made this change because we might want to introduce extra things...
			# which can take damage - like environment pieces and it feels more convienent...
			# to just have a separate script to handle taking "damage". I have also synced this...
			# separately from just reducing health because we might need effects to happen which...
			# are not reliant on health being reduced. This is why there is now a signal for when...
			# damage is taken.
			_damage.rpc("receive_damage", damage)
		#if collider.has_method("take_damage") and MultiplayerManager.is_server():
			#collider.take_damage(damage)
	
	# 1. Muzzle flash effect
	muzzle_flash.restart()
	muzzle_flash.emitting = true
	
	# 2. Bullet effect
	var projectile = Projectile.new()
	projectile.texture = projectile_texture
	projectile.global_position = weapon_muzzle.global_position
	projectile.target_position = collision_point
	projectile.impact_particles_lifetime = impact_particles_lifetime
	if collider and collider is CharacterBody2D:
		projectile.target = collider
	if get_tree() == null: return
	get_tree().root.add_child(projectile)


func _on_fire_timer_timeout() -> void:
	can_fire = true
