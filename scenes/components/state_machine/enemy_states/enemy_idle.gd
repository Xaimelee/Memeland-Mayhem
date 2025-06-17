extends State
class_name EnemyIdle

@export var enemy: EnemyCharacter

func enter() -> void:
	enemy.sprite.play("idle")
	# Logic below is relevant for when enemy respawns to reset changes from when they died
	enemy.damage_area.collision_layer = 1
	enemy.collision_layer = 1
	enemy.collision_mask = 1
	enemy.arm_sprite.visible = true
	if enemy.inventory.items[0] != null:
		enemy.weapon = enemy.inventory.items[0]
		enemy.weapon.visible = true

func process(delta: float) -> void:
	if not MultiplayerManager.is_server(): return
	enemy.velocity = enemy.velocity.move_toward(Vector2.ZERO, enemy.friction * delta)
