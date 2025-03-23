class_name Projectile extends Sprite2D

var target: CharacterBody2D = null
var target_position: Vector2 = Vector2()
var speed: int = 2000
var impact_particles_scene: PackedScene = preload("res://scenes/impact_particles.tscn")
var impact_particles_lifetime: float = 0.5

func _process(delta):
	# If the target is moving, update the position
	if target:
		target_position = target.global_position
	
	# Calculate new position
	global_position += global_position.direction_to(target_position) * speed * delta
	
	# Update rotation to face movement direction
	look_at(target_position)
	
	# If target is not reached, skip
	if global_position.distance_to(target_position) > 1.5  * speed * delta:
		return
	
	# Show impact
	var impact_particles = impact_particles_scene.instantiate()
	impact_particles.global_position = target_position
	impact_particles.emitting = true
	impact_particles.lifetime = impact_particles_lifetime
	get_tree().root.add_child(impact_particles)
	
	# Remove
	queue_free()
