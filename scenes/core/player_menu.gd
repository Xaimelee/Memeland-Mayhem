extends Control

@onready var menu_manager: MenuManager = $MenuManager

func _ready() -> void:
	SolanaService.wallet.on_login_finish.connect(_on_login_finished)

func _on_successful_response(response: ResponseType) -> void:
	var user_data: UserData = response as UserData
	print(user_data.user_id)
	print(user_data.wallet_address)
	menu_manager.change_menu("player")

func _on_login_finished(login_success: bool) -> void:
	if not login_success: return
	if not SolanaService.wallet.is_logged_in(): return
	Api.post_request(0, _on_successful_response)
