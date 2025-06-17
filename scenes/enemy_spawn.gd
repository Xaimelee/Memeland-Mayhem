extends Area2D
class_name EnemySpawn

signal enemy_spawned(enemy: EnemyCharacter)

@export var enemy_scene: PackedScene
@export var max_spawn_positions: int = 5
@export var max_enemies: int = 5

var spawn_positions: Array[Vector2] = []
var main: Main
var enemies: Array[EnemyCharacter]

# Should only be called on server, client doesn't need to care about this
func setup(_main: Main) -> void:
	main = _main
	for n in max_spawn_positions:
		var random_position: Vector2 = get_random_position()
		var point_id: int = main.position_to_point_id(random_position)
		if point_id == -1: continue
		var spawn_position: Vector2 = main.wall_layer.map_to_local(main.astar.get_point_position(point_id))
		#spawn_position = to_global(spawn_position)
		# This does mean potentially we might end up with less spawn positions due to rng
		if spawn_positions.has(spawn_position): continue
		spawn_positions.append(spawn_position)
	var available_spawns: Array[Vector2] = spawn_positions.duplicate()
	for n in max_enemies:
		var enemy: EnemyCharacter = MultiplayerSync.create_and_spawn_node(enemy_scene, main.get_node("Characters"))
		var spawn_position: Vector2 = available_spawns.pick_random()
		available_spawns.erase(spawn_position)
		enemy.teleport_position.rpc(spawn_position)
		enemies.append(enemy)
		# To connect the next position signal to main
		enemy_spawned.emit(enemy)
		enemy.enemy_respawned.connect(_on_enemy_respawned)

func get_random_position() -> Vector2:
	var shape_node := get_node("CollisionShape2D") as CollisionShape2D
	var shape := shape_node.shape as RectangleShape2D
	var half_extents = shape.size / 2.0
	var local_x = randf_range(-half_extents.x, half_extents.x)
	var local_y = randf_range(-half_extents.y, half_extents.y)
	var local_pos = Vector2(local_x, local_y)
	return to_global(local_pos)

func _on_enemy_respawned(enemy: EnemyCharacter) -> void:
	enemy.respawn(spawn_positions.pick_random())
