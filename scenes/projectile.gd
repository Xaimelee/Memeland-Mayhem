class_name Projectile extends Sprite2D

var target: CharacterBody2D = null
var speed: int = 2500

func _process(delta):
	if not target:
		return
	
	# Calculate new position
	global_position += global_position.direction_to(target.global_position) * speed * delta
	
	# Update rotation to face movement direction
	look_at(target.global_position)
	
	# Check if we've reached the target
	if global_position.distance_to(target.global_position) < 1.5  * speed * delta:
		hide()
		target = null
