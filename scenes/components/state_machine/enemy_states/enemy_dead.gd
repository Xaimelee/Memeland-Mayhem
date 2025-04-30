extends State
class_name EnemyDead

@export var enemy: EnemyCharacter

func enter() -> void:
	enemy.die()
