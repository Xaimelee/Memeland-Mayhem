extends State
class_name EnemyAttack

@export var enemy: EnemyCharacter

func enter() -> void:
	enemy.sprite.play("run")

func process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	if not enemy.target: return
	if not enemy.weapon.can_fire: return
	if not enemy.ready_to_attack: return
	if not enemy.next_position:
		enemy.emit_signal("reached_next_position", enemy)
	elif enemy.global_position.distance_to(enemy.next_position) < 4:
		enemy.emit_signal("reached_next_position", enemy)
	if not enemy.next_position: return
	var direction = enemy.global_position.direction_to(enemy.next_position)
	enemy.velocity = enemy.velocity.move_toward(direction * enemy.speed, enemy.acceleration * delta)
	enemy.rpc("shoot")
