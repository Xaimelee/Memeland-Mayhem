class_name PlayerCharacter extends CharacterBody2D

signal health_changed(new_health: float)
signal weapon_fired(bullet_scene: PackedScene, position: Vector2, direction: Vector2)

@export var max_health: float = 100.0
@export var speed: float = 300.0
@export var acceleration: float = 2000.0
@export var friction: float = 1000.0
@export var bullet_scene: PackedScene
@export var fire_rate: float = 0.2

var health: float = max_health
var can_fire: bool = true
var fire_timer: Timer

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var weapon_muzzle: Marker2D = $WeaponMuzzle
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	# Initialize fire timer
	fire_timer = Timer.new()
	fire_timer.wait_time = fire_rate
	fire_timer.one_shot = true
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	add_child(fire_timer)

func _physics_process(delta: float) -> void:
	# Handle movement
	var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_direction != Vector2.ZERO:
		# Accelerate when there's input
		velocity = velocity.move_toward(input_direction * speed, acceleration * delta)
		# Play movement animation
		sprite.play("run")
	else:
		# Apply friction when no input
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		# Play idle animation
		sprite.play("idle")
	
	# Apply movement
	move_and_slide()
	
	# Handle rotation towards mouse
	look_at(get_global_mouse_position())
	
	# Handle shooting
	if Input.is_action_pressed("shoot") and can_fire:
		shoot()

func shoot() -> void:
	can_fire = false
	fire_timer.start()
	
	# Get direction to mouse
	var direction = (get_global_mouse_position() - global_position).normalized()
	
	# Emit signal for bullet creation
	weapon_fired.emit(bullet_scene, weapon_muzzle.global_position, direction)
	
	# Play shooting animation/effects
	#sprite.play("shoot")

func take_damage(amount: float) -> void:
	health -= amount
	health = max(0, health)
	health_changed.emit(health)
	
	if health <= 0:
		die()
	#else:
		#sprite.play("hit")

func die() -> void:
	#sprite.play("death")
	# Wait for animation to finish
	await sprite.animation_finished
	queue_free()

func _on_fire_timer_timeout() -> void:
	can_fire = true
