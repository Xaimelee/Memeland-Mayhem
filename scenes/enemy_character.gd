class_name EnemyCharacter extends CharacterBody2D

signal enemy_died
signal reached_next_position(enemy: EnemyCharacter)

enum State {IDLE, CHASE, ATTACK, DEAD}

@export var speed: float = 300.0
@export var acceleration: float = 2000.0
@export var friction: float = 1000.0
@export var detection_range: float = 500.0
@export var attack_range: float = 400.0

var target: CharacterBody2D = null
var next_position: Vector2 = position
#var current_state: State = State.IDLE
var ready_to_attack: bool = true
var target_position: Vector2 = Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var arm_sprite: Sprite2D = $AnimatedSprite2D/ArmSprite2D
@onready var weapon: Weapon = $AnimatedSprite2D/ArmSprite2D/UnderTaker
@onready var damage_area: Area2D = $DamageArea2D
@onready var attack_timer: Timer = $AttackTimer
@onready var health: Health = $Health
@onready var enemy_states: StateMachine = $EnemyStates

func _ready() -> void:
	if is_multiplayer_authority():
		MultiplayerManager.player_connected.connect(_on_player_connected)

func _process(delta: float) -> void:
	# We only want to calculate physic interactions on the server so we need to lerp the player movement on clients...
	# so it still feels smooth. This will need testing with latency.
	if not MultiplayerManager.is_server():
		global_position = global_position.lerp(target_position, 30.0 * delta)

func _physics_process(delta: float) -> void:
	if MultiplayerManager.is_server():
		for player in get_tree().get_nodes_in_group("players") as Array[PlayerCharacter]:
			if player.current_state == player.PlayerState.DEAD: continue
			target = player
		rpc("update_target", get_target_path())
	# Probably need to update this later on, enemy and player likely need to inherit from some base class
	if target:
		if target.health:
			if target.health.current_health <= 0:
				target = null
	
	# Update state based on player distance
	if MultiplayerManager.is_server():
		change_state()
	
	# Handle state behavior
	#match current_state:
		#State.IDLE:
			#handle_idle_state(delta)
		#State.CHASE:
			#handle_chase_state(delta)
		#State.ATTACK:
			#handle_attack_state(delta)
		#State.DEAD:
			#return
	if enemy_states.is_state("enemydead"): return
	
	if MultiplayerManager.is_server():
		move_and_slide()
		rpc("update_target_position", global_position)
	
	if not target:
		return
		
	# Flip towards target
	if target.position.x < position.x:
		sprite.flip_h = true
		arm_sprite.flip_v = true
		arm_sprite.position.x = -5
		arm_sprite.position.y = 3
		weapon.flip(true)
	else:
		sprite.flip_h = false
		arm_sprite.flip_v = false
		arm_sprite.position.x = 5
		arm_sprite.position.y = 2
		weapon.flip(false)
	
	# Handle rotation towards target
	arm_sprite.look_at(target.position)

func change_state() -> void:
	if health.current_health <= 0:
		enemy_states.change_state("enemydead")
		#rpc("update_state", State.DEAD)
		return
	if not target:
		enemy_states.change_state("enemyidle")
		#rpc("update_state", State.IDLE)
		return
	var distance_to_player = global_position.distance_to(target.global_position)
	if is_lined_up() and distance_to_player <= attack_range:
		enemy_states.change_state("enemyattack")
		#rpc("update_state", State.ATTACK)
	elif distance_to_player <= detection_range:
		enemy_states.change_state("enemychase")
		#rpc("update_state", State.CHASE)
	else:
		enemy_states.change_state("enemyidle")
		#rpc("update_state", State.IDLE)

func is_lined_up() -> bool:
	weapon.update_line_of_fire()
	return weapon.raycast.is_colliding() and weapon.raycast.get_collider().get_parent() == target

func handle_idle_state(delta: float) -> void:
	# Apply friction to slow down
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	sprite.play("idle")

func handle_chase_state(delta: float) -> void:
	if not target:
		return
	if not next_position:
		emit_signal("reached_next_position", self)
	elif global_position.distance_to(next_position) < 4:
		emit_signal("reached_next_position", self)
	if not next_position:
		return
	var direction = global_position.direction_to(next_position)
	velocity = velocity.move_toward(direction * speed, acceleration * delta)
	sprite.play("run")


func handle_attack_state(delta: float) -> void:
	if not target:
		return
	if not weapon.can_fire:
		return
	if not ready_to_attack:
		return
	if not next_position:
		emit_signal("reached_next_position", self)
	elif global_position.distance_to(next_position) < 4:
		emit_signal("reached_next_position", self)
	if not next_position:
		return
	var direction = global_position.direction_to(next_position)
	velocity = velocity.move_toward(direction * speed, acceleration * delta)
	sprite.play("run")
	shoot()

@rpc("authority", "call_local")
func shoot() -> void:
	if not target: return
	var random_offset_x = randf_range(-32, 32)
	var random_offset_y = randf_range(-32, 32)
	arm_sprite.look_at(target.position + Vector2(random_offset_x, random_offset_y))
	weapon.shoot()
	ready_to_attack = false
	attack_timer.start()
	
	# 1. Arm effect
	var original_position = Vector2(-5, 3) if target.position.x < position.x else Vector2(5, 2)
	arm_sprite.position -= Vector2(cos(arm_sprite.rotation), sin(arm_sprite.rotation)) * 2
	create_tween().tween_property(arm_sprite, "position", original_position, 0.1)
	
	
#func take_damage(amount: float) -> void:
	#health.change_health(-amount)
	#if MultiplayerManager.is_server():
		#rpc("update_health", amount)
	#if current_state == State.DEAD:
		#return
	#health -= amount
	#health = max(0, health)
	#
	#if health <= 0:
		#die()

func die() -> void:
	# Disable collision
	damage_area.collision_layer = 0
	collision_layer = 0
	collision_mask = 0
	
	# Play death animation
	sprite.play("die")
	
	# Remove the weapon holding arm
	# This is now visible instead of queuefree because of sync errors...
	# caused by the auto spawner sync node I think.
	arm_sprite.visible = false
	
	# Emit signal before freeing
	enemy_died.emit()
	
	# Start decay timer
	#decay_timer.start()

# Used to sync current enemies to new players 
@rpc("authority", "call_remote")
func init_enemy(new_position: Vector2, new_target_node_path: String) -> void:
	global_position = new_position
	target_position = new_position
	update_target(new_target_node_path)
	#update_state(new_state)

@rpc("authority", "call_remote")
func update_target_position(new_target_position: Vector2) -> void:
	target_position = new_target_position

@rpc("authority", "call_remote")
func update_target(new_target_node_path: String) -> void:
	if new_target_node_path == "":
		target = null
		return
	target = get_node(new_target_node_path)

#@rpc("authority", "call_local")
#func update_state(new_state: State) -> void:
	## We should check this on server to avoid sending pointless rpcs.
	## It will mean that when enemies are spawned, we need a way to get...
	## updated info ASAP from the server. Might just need our own sync node?
	#if current_state == new_state: return
	#current_state = new_state
	#if current_state == State.DEAD:
		#die()

#@rpc("authority", "call_local")
#func update_health(new_health: float) -> void:
	#health -= new_health
	#health = max(0, health)

func get_target_path() -> String:
	if target == null:
		return ""
	return target.get_path()

func _on_attack_timer_timeout() -> void:
	ready_to_attack = true

# This is so we can sync server state with players who have joined later on
func _on_player_connected(id: int):
	rpc_id(id, "init_enemy", global_position, get_target_path())
