extends Control

const MAIN_SCENE: PackedScene = preload("uid://c573o225twlil")

@onready var menu_manager: MenuManager = $MenuManager
@onready var inventory: Inventory = %Inventory
@onready var stash: Inventory = %Stash

func _ready() -> void:
	SolanaService.wallet.on_login_finish.connect(_on_login_finished)
	# We will need to fetch updated user data anyways, so player menu should have a state for "loading/waiting"...
	#... until new data has been fetched.
	# 29/05/2025 NOTE: Below should work for now
	if SolanaService.wallet.is_logged_in():
		Api.post_request(0, _on_successful_response)
		menu_manager.change_menu("Loading")
		#menu_manager.change_menu("Player")
	elif not OS.has_feature("editor"):
		menu_manager.change_menu("Login")

func _on_successful_response(response: ResponseType) -> void:
	var user_data: UserData = response as UserData
	UserManager.user_data = user_data
	print(user_data.user_id)
	print(user_data.wallet_address)
	menu_manager.change_menu("Player")

func _on_successful_response_loadout(response: ResponseType) -> void:
	if response:
		MultiplayerManager.server_ip = "52.63.141.232"
		get_tree().change_scene_to_packed(MAIN_SCENE)
	# Failed to send loadout
	else:
		menu_manager.change_menu("Player")

func _on_login_finished(login_success: bool) -> void:
	if not login_success: return
	if not SolanaService.wallet.is_logged_in(): return
	Api.post_request(0, _on_successful_response)
	menu_manager.change_menu("Loading")

func _on_play_game_pressed() -> void:
	MultiplayerManager.override_is_local = false
	# NOTE: We go back to load menu here and wait for successful api before we join.
	# If we don't wait then user might get outdated inventory loadout when joining...
	#... and their new loadout wouldn't have saved.
	var data = {
		"walletAddress": UserManager.user_data.wallet_address,
		"inventory": [],
		"stash": []
	}
	for n in inventory.items.size():
		var item: Item = inventory.get_item_at_index(n)
		if item:
			data["inventory"].append({ "item_name": item.name.to_snake_case(), "slot": n})
	for n in stash.items.size():
		var item: Item = stash.get_item_at_index(n)
		if item:
			data["stash"].append({ "item_name": item.name.to_snake_case(), "slot": n})
	var json_body = JSON.stringify(data)
	Api.post_request(2, _on_successful_response_loadout, json_body)
	menu_manager.change_menu("Loading")
	#MultiplayerManager.server_ip = "52.63.141.232"
	#get_tree().change_scene_to_packed(MAIN_SCENE)

func _on_play_local_server_pressed() -> void:
	MultiplayerManager.override_is_local = false
	MultiplayerManager.server_ip = "localhost"
	get_tree().change_scene_to_packed(MAIN_SCENE)
