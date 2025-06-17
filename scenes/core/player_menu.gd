extends Control

const MAIN_SCENE: PackedScene = preload("uid://c573o225twlil")

@onready var menu_manager: MenuManager = $MenuManager
@onready var inventory: Inventory = %Inventory
@onready var stash: Inventory = %Stash
@onready var loading_label: Label = %LoadingLabel
@onready var play_guest_button: Button = %PlayGuest

# TEST
var localhost: bool = false

func _ready() -> void:
	SolanaService.wallet.on_login_success.connect(_on_login_success)
	SolanaService.wallet.on_login_begin.connect(_on_login_begin)
	# We will need to fetch updated user data anyways, so player menu should have a state for "loading/waiting"...
	#... until new data has been fetched.
	# 29/05/2025 NOTE: Below should work for now
	if SolanaService.wallet.is_logged_in():
		var body: String = JSON.stringify({"walletAddress": SolanaService.wallet.get_pubkey().to_string()})
		Api.post_request(0, _on_successful_response, body)
		menu_manager.change_menu("Loading")
		loading_label.text = "Loading User Data"
		#menu_manager.change_menu("Player")
	elif not OS.has_feature("editor"):
		menu_manager.change_menu("Login")
	

func _on_successful_response(response: ResponseType) -> void:
	var user_data: UserData = response as UserData
	UserManager.user_data = user_data
	#print(user_data.user_id)
	#print(user_data.wallet_address)
	# We force a 2 second (+3 second on server) wait to give time for player to have most up to date info after matches.
	# Otherwise we'll have to do a last updated time check when server fetches data...
	#... so if user not updated recently we'd poll until we get updated version. 
	await get_tree().create_timer(2).timeout
	menu_manager.change_menu("Player")

func _on_successful_response_loadout(response: ResponseType) -> void:
	if response:
		# We force a 5 second wait to give time for server to have most up to date info.
		# Otherwise we'll have to do a last updated time check when server fetches data...
		#... so if user not updated recently we'd poll until we get updated version. 
		await get_tree().create_timer(5).timeout
		if localhost:
			Globals.start_local_game()
		else:
			Globals.start_online_game()
	# Failed to send loadout
	else:
		menu_manager.change_menu("Player")

func _on_login_begin() -> void:
	play_guest_button.disabled = true

func _on_login_success() -> void:
	play_guest_button.disabled = false
	if not SolanaService.wallet.is_logged_in(): return
	var body: String = JSON.stringify({"walletAddress": SolanaService.wallet.get_pubkey().to_string()})
	Api.post_request(0, _on_successful_response, body)
	menu_manager.change_menu("Loading")
	loading_label.text = "Loading User Data"

func _on_play_game_pressed() -> void:
	# NOTE: We go back to load menu here and wait for successful api before we join.
	# If we don't wait then user might get outdated inventory loadout when joining...
	#... and their new loadout wouldn't have saved.
	var data = {
		"walletAddress": UserManager.user_data.wallet_address,
		"inventory": [],
		"stash": [],
		"playerName": UserManager.user_name
	}
	for n in inventory.items.size():
		var item: Item = inventory.get_item_at_index(n)
		if item:
			data["inventory"].append({ "item_name": item.item_name.to_snake_case(), "slot": n})
	for n in stash.items.size():
		var item: Item = stash.get_item_at_index(n)
		if item:
			data["stash"].append({ "item_name": item.item_name.to_snake_case(), "slot": n})
	var json_body = JSON.stringify(data)
	Api.post_request(2, _on_successful_response_loadout, json_body)
	menu_manager.change_menu("Loading")
	loading_label.text = "Saving User Data"
	#MultiplayerManager.server_ip = "52.63.141.232"
	#get_tree().change_scene_to_packed(MAIN_SCENE)

func _on_play_local_server_pressed() -> void:
	# Temp so I can quickly test backend stuff
	localhost = true
	_on_play_game_pressed()
	#Globals.start_local_game()

func _on_play_offline_pressed() -> void:
	Globals.start_offline_game()

func _on_play_as_guest_pressed() -> void:
	UserManager.user_data = MultiplayerManager.guest_data
	Globals.start_online_game()
