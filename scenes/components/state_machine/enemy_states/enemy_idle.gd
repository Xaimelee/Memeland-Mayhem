extends State
class_name EnemyIdle

@export var enemy: EnemyCharacter

func enter() -> void:
	enemy.sprite.play("idle")

func process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	enemy.velocity = enemy.velocity.move_toward(Vector2.ZERO, enemy.friction * delta)
