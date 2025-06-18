extends Node2D
class_name DropPositions

var rays: Array[RayCast2D] = []
var last_ray_used: RayCast2D

func _ready() -> void:
	for node in get_children():
		rays.append(node as RayCast2D)

func get_item_drop_position() -> Vector2:
	var available_rays: Array[RayCast2D] = rays.duplicate()
	available_rays.erase(last_ray_used)
	var ray: RayCast2D = rays.pick_random()
	last_ray_used = ray
	return ray.get_collision_point() if ray.is_colliding() else ray.to_global(ray.target_position)
