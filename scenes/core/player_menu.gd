extends Control

func _ready() -> void:
	Api.post_request(0, _on_successful_response)

func _on_successful_response(response: ResponseType) -> void:
	var user_data: UserData = response as UserData
	print(user_data.user_id)
	print(user_data.wallet_address)
