class_name EnemyCharacter extends CharacterBody2D

signal enemy_died
signal reached_next_position

enum State {IDLE, CHASE, ATTACK, DEAD}

@export var max_health: float = 100.0
@export var speed: float = 300.0
@export var acceleration: float = 2000.0
@export var friction: float = 1000.0
@export var detection_range: float = 500.0

var health: float = max_health
var target: CharacterBody2D = null
var next_position: Vector2 = position
var current_state: State = State.IDLE
var ready_to_attack: bool = true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var arm_sprite: Sprite2D = $AnimatedSprite2D/ArmSprite2D
@onready var primary_weapon: Node2D = $AnimatedSprite2D/ArmSprite2D/BoringRifle
@onready var secondary_weapon: Node2D = $AnimatedSprite2D/ArmSprite2D/CyberGlock
@onready var weapon: Node2D = secondary_weapon
@onready var damage_area: Area2D = $DamageArea2D
@onready var attack_timer: Timer = $AttackTimer


func _physics_process(delta: float) -> void:
	target = get_tree().get_nodes_in_group("players")[0]
	if target.health <= 0:
		target = null
	
	# Update state based on player distance
	update_state()
	
	# Handle state behavior
	match current_state:
		State.IDLE:
			handle_idle_state(delta)
		State.CHASE:
			handle_chase_state(delta)
		State.ATTACK:
			handle_attack_state(delta)
		State.DEAD:
			return
	
	move_and_slide()
	
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

func update_state() -> void:
	if health <= 0:
		current_state = State.DEAD
		return
	if not target:
		current_state = State.IDLE
		return
	var distance_to_player = global_position.distance_to(target.global_position)
	if is_lined_up() and distance_to_player <= weapon.max_shoot_distance:
		current_state = State.ATTACK
	elif distance_to_player <= detection_range:
		current_state = State.CHASE
	else:
		current_state = State.IDLE
		
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
	
func shoot() -> void:
	weapon.shoot()
	ready_to_attack = false
	attack_timer.start()
	
	# 1. Arm effect
	var original_position = Vector2(-5, 3) if target.position.x < position.x else Vector2(5, 2)
	arm_sprite.position -= Vector2(cos(arm_sprite.rotation), sin(arm_sprite.rotation)) * 2
	create_tween().tween_property(arm_sprite, "position", original_position, 0.1)
	
	
func take_damage(amount: float) -> void:
	if current_state == State.DEAD:
		return
	health -= amount
	health = max(0, health)
	
	if health <= 0:
		die()

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

func _on_attack_timer_timeout() -> void:
	ready_to_attack = true
