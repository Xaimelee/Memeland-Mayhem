class_name EnemyCharacter extends CharacterBody2D

signal enemy_died
signal reached_next_position

enum State {IDLE, CHASE, DEAD}

@export var max_health: float = 100.0
@export var speed: float = 300.0
@export var acceleration: float = 2000.0
@export var friction: float = 1000.0
@export var detection_range: float = 500.0

var health: float = max_health
var target: CharacterBody2D = null
var next_position: Vector2 = position
var current_state: State = State.IDLE

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var arm_sprite: Sprite2D = $AnimatedSprite2D/ArmSprite2D
#@onready var primary_weapon: Node2D = $AnimatedSprite2D/ArmSprite2D/BoringRifle
#@onready var secondary_weapon: Node2D = $AnimatedSprite2D/ArmSprite2D/CyberGlock
#@onready var weapon: Node2D = primary_weapon
@onready var damage_area: Area2D = $DamageArea2D

func _physics_process(delta: float) -> void:
	target = get_tree().get_nodes_in_group("players")[0]
	
	# Update state based on player distance
	update_state()
	
	# Handle state behavior
	match current_state:
		State.IDLE:
			handle_idle_state(delta)
		State.CHASE:
			handle_chase_state(delta)
		State.DEAD:
			return
	
	move_and_slide()

func update_state() -> void:
	if health <= 0:
		current_state = State.DEAD
		return
	var distance_to_player = global_position.distance_to(target.global_position)
	if distance_to_player <= detection_range:
		current_state = State.CHASE
	else:
		current_state = State.IDLE

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

func take_damage(amount: float) -> void:
	if current_state == State.DEAD:
		return
	health -= amount
	health = max(0, health)
	
	if health <= 0:
		die()
	#else:
		#animation_player.play("hit")

func die() -> void:
	# Disable collision
	damage_area.collision_layer = 0
	collision_layer = 0
	collision_mask = 0
	
	# Play death animation
	sprite.play("die")
	
	# Remove the weapon holding arm
	arm_sprite.queue_free()
	
	# Emit signal before freeing
	enemy_died.emit()
	
	# Start decay timer
	#decay_timer.start()


func _on_timer_timeout() -> void:
	# Remove from scene
	queue_free()
