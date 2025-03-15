class_name Bullet extends Area2D

@export var speed: float = 750.0
@export var damage: float = 10.0
@export var lifetime: float = 2.0

var direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Set up lifetime timer
	var timer = get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)
	
	# Connect signals
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	# Move in the set direction
	position += direction * speed * delta

func set_direction(new_direction: Vector2) -> void:
	direction = new_direction
	rotation = direction.angle()

func _on_body_entered(body: Node2D) -> void:
	# Check if we hit an enemy or other damageable object
	if body.has_method("take_damage"):
		body.take_damage(damage)
	
	# Destroy the bullet
	queue_free()
