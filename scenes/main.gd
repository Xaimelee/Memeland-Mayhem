class_name Main extends Node2D

@export var enemy_scenes: Array[PackedScene] = []
@export var spawn_time_min: float = 1.0
@export var spawn_time_max: float = 3.0

@onready var player_character: PlayerCharacter = $PlayerCharacter
@onready var spawn_timer: Timer = $SpawnTimer
@onready var spawn_points: Node2D = $SpawnPoints

func _ready() -> void:
	# Connect player signals
	player_character.weapon_fired.connect(_on_player_weapon_fired)
	
	# Start enemy spawning
	_start_spawning()

func _on_player_weapon_fired(bullet_scene: PackedScene, bullet_position: Vector2, direction: Vector2) -> void:
	# Create bullet instance
	var bullet = bullet_scene.instantiate() as Bullet
	bullet.global_position = bullet_position
	bullet.set_direction(direction)
	
	# Add bullet to scene
	add_child(bullet)

func _start_spawning() -> void:
	spawn_timer.wait_time = randf_range(spawn_time_min, spawn_time_max)
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.start()

func _on_spawn_timer_timeout() -> void:
	# Spawn enemy at random spawn point
	if enemy_scenes.size() > 0 and spawn_points.get_child_count() > 0:
		# Select random enemy and spawn point
		var enemy_scene = enemy_scenes[randi() % enemy_scenes.size()]
		var spawn_point = spawn_points.get_child(randi() % spawn_points.get_child_count())
		
		# Create enemy instance
		var enemy = enemy_scene.instantiate()
		enemy.global_position = spawn_point.global_position
		
		# Add enemy to scene
		add_child(enemy)
	
	# Reset timer with random time
	spawn_timer.wait_time = randf_range(spawn_time_min, spawn_time_max)
	spawn_timer.start()
