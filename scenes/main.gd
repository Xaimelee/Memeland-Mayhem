class_name Main extends Node2D

var astar: AStar2D = AStar2D.new()
var mission_area: Rect2i = Rect2i(200, 0, 100, 100)

@onready var wall_layer: TileMapLayer = $Map/Walls

func _ready() -> void:
	MultiplayerManager.start_network()
	init_astar()
	Globals.game_started.emit()

func init_astar() -> void:
	for x in range(mission_area.size.x):
		for y in range(mission_area.size.y):
			var map_position = Vector2i(x + mission_area.position.x, y + mission_area.position.y)
			var data = wall_layer.get_cell_tile_data(map_position)
			if not data or not data.get_collision_polygons_count(0):
				var point_id = x * mission_area.size.x + y
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

func position_to_point_id(from_position: Vector2) -> int:
	var map_position = wall_layer.local_to_map(from_position)
	var mission_area_position = map_position - mission_area.position
	var point_id = mission_area_position.x * mission_area.size.x + mission_area_position.y
	if astar.has_point(point_id):
		return point_id
	return -1
