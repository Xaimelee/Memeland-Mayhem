class_name PlayerCharacter extends CharacterBody2D

signal health_changed(new_health: float)
signal equipment_slot_changed(slot: int)

enum PlayerState {ALIVE, DEAD, EXTRACT}
enum ArmState {LEFT, RIGHT}
enum EquipmentSlot {ONE, TWO, THREE, FOUR, FIVE, SIX}

@export var speed: float = 300.0
@export var acceleration: float = 2000.0
@export var friction: float = 1000.0
@export var id: int = 1
@export var player_input: PlayerInput
@export var not_owned_healthbar_style: StyleBoxFlat

var target_position: Vector2 = Vector2.ZERO
var current_arm_state: ArmState = ArmState.LEFT
var current_state: PlayerState = PlayerState.ALIVE
var current_equipment_slot: EquipmentSlot = EquipmentSlot.ONE
var nearby_items: Array[Item] = []
#var equipment: Array[Weapon] = [null, null, null, null]

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var arm_sprite: Sprite2D = $AnimatedSprite2D/ArmSprite2D
#@onready var primary_weapon: Node2D = $AnimatedSprite2D/ArmSprite2D/BoringRifle
#@onready var secondary_weapon: Node2D = $AnimatedSprite2D/ArmSprite2D/CyberGlock
@onready var weapon: Weapon = null
@onready var damage_area: Area2D = $DamageArea2D
@onready var camera: Camera2D = $Camera2D
@onready var rollback_synchronizer: RollbackSynchronizer = $RollbackSynchronizer
@onready var health: Health = $Health
@onready var healthbar: Healthbar = $Healthbar
@onready var player_name: Label = $PlayerName
@onready var inventory: Inventory = $Inventory

func _ready() -> void:
	#equipment[0] = primary_weapon
	#equipment[1] = secondary_weapon
	player_input.player_character = self
	if is_multiplayer_authority():
		MultiplayerManager.player_connected.connect(_on_player_connected)
	# Hack for having weapons spawned in when local testing. Will need a better way in future.
	# NOTE: In future should just be running the init player function, which would load guest data for items
	# We can also add support in future for loading items that are children of inventory node at runtime
	if MultiplayerManager.is_local():
		Globals.player_spawned.emit(self)
		inventory.create_and_add_item("boring_rifle")
		inventory.create_and_add_item("cyber_glock")
		# TEST
		#inventory.rpc("drop_item", 0)

# Using Netfox to implement CSP movement
func _rollback_tick(delta, tick, is_fresh) -> void:
	if current_state == PlayerState.DEAD: return
	if current_state == PlayerState.EXTRACT: return
	# We do this because other clients just get synced the global transform
	if not has_ownership() and not MultiplayerManager.is_server(): return
	if current_state == PlayerState.DEAD: return
	if player_input.input_direction != Vector2.ZERO:
		velocity = velocity.move_toward(player_input.input_direction * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor

func _physics_process(delta: float) -> void:
	if !has_ownership(): 
		# This may not be entirely efficient but its an easy way to do this...
		# because we don't currently have a pre game state and have a player...
		# already in the map for easy testing
		camera.enabled = false
	if current_state == PlayerState.DEAD or current_state == PlayerState.EXTRACT : return

	# Probably replace with some synced bool if moving which can be client authority if...
	# it is purely for visuals
	if player_input.input_direction != Vector2.ZERO:
		# Play movement animation
		sprite.play("run")
	else:
		# Play idle animation
		sprite.play("idle")

	#if MultiplayerManager.is_server():
		#rpc("update_target_position", global_position)

	# Flip towards mouse
	if current_arm_state == ArmState.LEFT and player_input.mouse_position.x >= position.x:
		change_arm_state(ArmState.RIGHT)
	elif current_arm_state == ArmState.RIGHT and player_input.mouse_position.x < position.x:
		change_arm_state(ArmState.LEFT)

	# Handle rotation towards mouse
	arm_sprite.look_at(player_input.mouse_position)

	if not has_ownership(): return
	# REMOVE LATER AFTER TESTING DEATH WIPES
	#if Input.is_action_just_pressed("ui_filedialog_refresh"):
		#rpc("test_extract")
	if Input.is_action_just_pressed("ui_graph_delete"):
		rpc("change_state", PlayerState.DEAD)
	# END OF TEST
	if Input.is_action_just_pressed("drop"):
		rpc("send_drop_item", current_equipment_slot)
	elif Input.is_action_just_pressed("pickup") and not nearby_items.is_empty() and not inventory.get_free_index() == -1:
		nearby_items.sort_custom(sort_by_distance)
		var item: Item = nearby_items[0]
		var item_path: String = item.get_path()
		rpc_id(1, "send_pickup_item", item_path)
		
	# Equipment swapping
	for i in inventory.slots:
		var action_name: String = "equipment_{0}".format([i + 1])
		if Input.is_action_just_pressed(action_name):
			#var slot: EquipmentSlot = EquipmentSlot.values()[i]
			#if not inventory.items[slot]: return
			change_equipment_slot(i)
			rpc_id(1, "send_equipment_slot", current_equipment_slot)
			break;
	# Handle shooting
	var shooting = false
	if not weapon: return
	shooting = Input.is_action_pressed("shoot_primary") and weapon.can_fire
	if shooting:
		# We run this locally so the player has instant visual feedback that they're shooting and hitting.
		# This should be an acceptable hack unless someone has super high latency.
		shoot()
		# This check isn't super necessary but it prevents errors in console when doing local testing.
		if not is_multiplayer_authority():
			rpc_id(1, "send_shoot")
	
func shoot() -> void:
	weapon.shoot()
	
	# 1. Arm effect
	var original_position = Vector2(-5, 3) if player_input.mouse_position.x < position.x else Vector2(5, 2)
	arm_sprite.position -= Vector2(cos(arm_sprite.rotation), sin(arm_sprite.rotation)) * 2
	create_tween().tween_property(arm_sprite, "position", original_position, 0.1)
	
	# 2. Camera shake effect (subtle)
	camera.offset = Vector2(randf_range(-2, 2), -2)
	create_tween().tween_property(camera, "offset", Vector2.ZERO, 0.1)


#func take_damage(amount: float) -> void:
	#health.change_health(-amount)
	#if MultiplayerManager.is_server():
		#health.rpc("update_health", amount)

func die() -> void:
	# Disable collision
	damage_area.collision_layer = 0
	collision_layer = 0
	collision_mask = 0
	
	# Play death animation
	sprite.play("die")
	
	# Remove the weapon holding arm
	arm_sprite.queue_free()
	
	if has_ownership():
		# Sucks to be you :)
		Globals.player_died.emit(self)

	if MultiplayerManager.is_server():
		MultiplayerManager.player_died(self)

	# Emit signal before freeing
	#enemy_died.emit()
	
	# Start decay timer
	#decay_timer.start()

@rpc("authority", "call_local")
func extract() -> void:
	if has_ownership():
		Globals.player_extracted.emit(self)
	change_state(PlayerState.EXTRACT)
	if not is_multiplayer_authority(): return
	MultiplayerManager.player_extracted(self)

# TESTING REMOVE LATER
@rpc("any_peer", "call_local")
func change_state(new_state: PlayerState) -> void:
	# Bandaid fix for now to make sure if a player is extracted that they can't get killed
	# In future we should probably immediately delete player or smthing
	if new_state == PlayerState.DEAD and current_state == PlayerState.EXTRACT: return
	current_state = new_state
	match current_state:
		PlayerState.DEAD:
			player_name.visible = false
			die()
		PlayerState.EXTRACT:
			damage_area.collision_layer = 0
			collision_layer = 0
			collision_mask = 0
		_:
			player_name.visible = true
			return

func change_arm_state(new_arm_state: ArmState) -> void:
	current_arm_state = new_arm_state
	match current_arm_state:
		ArmState.LEFT:
			sprite.flip_h = true
			arm_sprite.flip_v = true
			arm_sprite.position.x = -5
			arm_sprite.position.y = 3
			if weapon:
				weapon.flip(true)
		_:
			sprite.flip_h = false
			arm_sprite.flip_v = false
			arm_sprite.position.x = 5
			arm_sprite.position.y = 2
			if weapon:
				weapon.flip(false)

func change_equipment_slot(equipment_slot: EquipmentSlot) -> void:
	current_equipment_slot = equipment_slot
	equipment_slot_changed.emit(current_equipment_slot)
	if weapon:
		weapon.visible = false
	var new_weapon: Weapon = inventory.items[equipment_slot] as Weapon
	if not new_weapon: return
	weapon = new_weapon
	weapon.visible = true

# Fix this later to respect client-server authority, likely need to be done in the weapon script?
@rpc("any_peer", "call_remote")
func send_shoot() -> void:
	if not validate_user_rpc("Possible shoot manipulation"): return
	rpc("update_shoot")

@rpc("any_peer", "call_remote")
func send_mouse_position(new_mouse_position: Vector2) -> void:
	if not validate_user_rpc("Possible mouse position manipulation"): return
	rpc("update_mouse_position", new_mouse_position)

@rpc("any_peer", "call_local")
func send_equipment_slot(new_equipment_slot: EquipmentSlot) -> void:
	if not validate_user_rpc("Possible equipment slot manipulation"): return
	rpc("update_equipment_slot", new_equipment_slot)

@rpc("any_peer", "call_local")
func send_drop_item(index: EquipmentSlot) -> void:
	if not validate_user_rpc("Possible drop item manipulation"): return
	inventory.rpc("drop_item", index)

@rpc("any_peer", "call_local")
func send_pickup_item(item_node_path: String) -> void:
	if not validate_user_rpc("Possible pick up item manipulation"): return
	var item: Item = get_tree().root.get_node_or_null(item_node_path)
	if item == null: 
		print("Tried to pickup item with invalid path on server")
		return
	var index: int = inventory.get_free_index()
	if index == -1:
		print("Tried to pickup item with no inventory space")
		return
	inventory.rpc("add_item_with_path", item_node_path, index)

@rpc("authority", "call_local")
func update_shoot() -> void:
	# We locally show shoot visuals as soon as the request is sent to the server
	if has_ownership(): return
	shoot()

@rpc("authority", "call_local")
func update_equipment_slot(new_equipment_slot: EquipmentSlot) -> void:
	# We locally show the weapon swap right away for the owner to prevent it feeling delayed
	if has_ownership(): return
	change_equipment_slot(new_equipment_slot)

#@rpc("authority", "call_local")
#func update_health(new_health: float) -> void:
	#health -= new_health
	#health = max(0, health)
	#health_changed.emit(health)
	#if health <= 0:
		#change_state(State.DEAD)

#@rpc("authority", "call_remote")
#func update_target_position(new_target_position: Vector2) -> void:
	## We just update target position on clients
	#target_position = new_target_position

@rpc("authority", "call_local")
func init_player(new_id: int, spawn_position: Vector2) -> void:
	id = new_id
	target_position = spawn_position
	global_position = spawn_position
	player_input.set_multiplayer_authority(new_id)
	rollback_synchronizer.process_settings()
	if has_ownership():
		Globals.player_spawned.emit(self)
	if not has_ownership() and healthbar:
		healthbar.progress_bar.add_theme_stylebox_override("fill", not_owned_healthbar_style)

func validate_user_rpc(error_message: String) -> bool:
	# Incase someone tries to change from rpc_id to rpc, we make sure that if somehow this is ran...
	# on local clients that it will get ignored.
	if not MultiplayerManager.is_server(): return false
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != id: 
		print(error_message)
		return false
	return true

func has_ownership() -> bool:
	return id == multiplayer.get_unique_id()

func sort_by_distance(a: Node2D, b: Node2D) -> bool:
	var dist_a = global_position.distance_to(a.global_position)
	var dist_b = global_position.distance_to(b.global_position)
	return dist_a < dist_b

func _on_health_health_changed(health: float) -> void:
	if health <= 0:
		change_state(PlayerState.DEAD)

# This is so we can sync server state with players who have joined later on
# This might not be needed if we stop using the Godot spawner sync node
func _on_player_connected(peer_id: int):
	rpc_id(peer_id, "init_player", id, global_position)
	rpc_id(peer_id, "update_equipment_slot", current_equipment_slot)

func _on_inventory_item_added(item: Item) -> void:
	# This makes the weapon visible if item was added to currently selected slot
	if inventory.items.find(item) == current_equipment_slot:
		change_equipment_slot(current_equipment_slot)

func _on_inventory_item_removed(item: Item) -> void:
	if weapon == item:
		weapon = null

func _on_detect_area_2d_area_entered(area: Area2D) -> void:
	print("Enter")
	var item: Item = area.get_parent() as Item
	if item == null: return
	nearby_items.append(item)

func _on_detect_area_2d_area_exited(area: Area2D) -> void:
	print("Exit")
	var item: Item = area.get_parent() as Item
	if item == null: return
	nearby_items.erase(item)
