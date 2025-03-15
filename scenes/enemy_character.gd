class_name EnemyCharacter extends CharacterBody2D

signal enemy_died

@export var max_health: float = 50.0
@export var score_value: int = 10

var health: float = max_health

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var arm_sprite: Sprite2D = $AnimatedSprite2D/ArmSprite2D
@onready var decay_timer: Timer = $Timer

func _ready() -> void:
	# Start idle animation
	sprite.play("idle")

func take_damage(amount: float) -> void:
	health -= amount
	health = max(0, health)
	
	if health <= 0:
		die()
	#else:
		#animation_player.play("hit")

func die() -> void:
	# Disable collision
	collision_layer = 0
	collision_mask = 0
	
	# Play death animation
	sprite.play("die")
	
	# Remove the weapon holding arm
	arm_sprite.queue_free()
	
	# Emit signal before freeing
	enemy_died.emit()
	
	# Start decay timer
	decay_timer.start()


func _on_timer_timeout() -> void:
	# Remove from scene
	queue_free()
