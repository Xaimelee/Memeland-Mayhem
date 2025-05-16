extends Control

const MAIN_SCENE: PackedScene = preload("uid://c573o225twlil")

@onready var menu_manager: MenuManager = $MenuManager

func _ready() -> void:
	SolanaService.wallet.on_login_finish.connect(_on_login_finished)
	if SolanaService.wallet.is_logged_in():
		menu_manager.change_menu("player")

func _on_successful_response(response: ResponseType) -> void:
	var user_data: UserData = response as UserData
	UserManager.user_data = user_data
	print(user_data.user_id)
	print(user_data.wallet_address)
	menu_manager.change_menu("player")

func _on_login_finished(login_success: bool) -> void:
	if not login_success: return
	if not SolanaService.wallet.is_logged_in(): return
	Api.post_request(0, _on_successful_response)

func _on_play_game_pressed() -> void:
	MultiplayerManager.override_is_local = false
	MultiplayerManager.server_ip = "52.63.141.232"
	get_tree().change_scene_to_packed(MAIN_SCENE)

func _on_play_local_server_pressed() -> void:
	MultiplayerManager.override_is_local = false
	MultiplayerManager.server_ip = "localhost"
	get_tree().change_scene_to_packed(MAIN_SCENE)
