class_name Main extends Node2D

var astar: AStar2D = AStar2D.new()
var walkable_positions: Array[Vector2i] = []
var mission_area: Rect2i = Rect2i(200, 0, 100, 100)

@onready var wall_layer: TileMapLayer = $Map/Walls
@onready var floor2_later: TileMapLayer = $Map/Floor2

func _ready() -> void:
	MultiplayerManager.start_network()
	init_astar()
	# Might need to be before start network not 100%
	Globals.game_started.emit()
	# Client doesn't need enemy spawns to be setup
	if MultiplayerManager.is_server():
		var enemy_spawns: Array[Node] = get_tree().get_nodes_in_group("enemy_spawns")
		for node in enemy_spawns:
			var enemy_spawn: EnemySpawn = node as EnemySpawn
			enemy_spawn.enemy_spawned.connect(_on_enemy_spawned)
			enemy_spawn.setup(self)
		var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
		for node in enemies:
			var enemy: EnemyCharacter = node as EnemyCharacter
			_on_enemy_spawned(enemy)

func init_astar() -> void:
	# for testing
	mission_area = floor2_later.get_used_rect()
	for x in range(mission_area.size.x):
		for y in range(mission_area.size.y):
			var map_position = Vector2i(x + mission_area.position.x, y + mission_area.position.y)
			var data = wall_layer.get_cell_tile_data(map_position)
			if not data or not data.get_collision_polygons_count(0):
				var point_id = x * mission_area.size.x + y
				walkable_positions.append(map_position)
				astar.add_point(point_id, map_position)
				
				# Up-Left
				if astar.has_point(point_id - mission_area.size.x - 1):
					astar.connect_points(point_id, point_id - mission_area.size.x - 1, 1.4)
				
				# Up-Right
				if astar.has_point(point_id - mission_area.size.x + 1):
					astar.connect_points(point_id, point_id - mission_area.size.x + 1, 1.4)
				
				# Up
				if astar.has_point(point_id - mission_area.size.x):
					astar.connect_points(point_id, point_id - mission_area.size.x, 1)
				
				# Left
				if astar.has_point(point_id - 1):
					astar.connect_points(point_id, point_id - 1, 1)

func _on_enemy_character_reached_next_position(enemy: EnemyCharacter) -> void:
	var point_id = position_to_point_id(enemy.position)
	if point_id == -1:
		return
	var target_point_id = astar.get_point_ids().get(randi() % astar.get_point_count())
	#if enemy.current_state == enemy.State.CHASE:
	if enemy.enemy_states.is_state("enemychase") and enemy.target:
		target_point_id = position_to_point_id(enemy.target.position)
	if target_point_id == -1:
		return
	var path: PackedVector2Array = astar.get_point_path(point_id, target_point_id)
	if path.size() < 2:
		return
	var next_map_position = astar.get_point_path(point_id, target_point_id)[1]
	enemy.next_position = wall_layer.map_to_local(next_map_position)

func _on_enemy_spawned(enemy: EnemyCharacter) -> void:
	if not enemy.reached_next_position.is_connected(_on_enemy_character_reached_next_position):
		enemy.reached_next_position.connect(_on_enemy_character_reached_next_position)

func position_to_point_id(from_position: Vector2) -> int:
	var map_position = wall_layer.local_to_map(from_position)
	var mission_area_position = map_position - mission_area.position
	var point_id = mission_area_position.x * mission_area.size.x + mission_area_position.y
	if astar.has_point(point_id):
		return point_id
	return -1
