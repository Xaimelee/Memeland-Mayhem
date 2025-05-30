extends Control

func _on_main_server_button_pressed() -> void:
	Globals.start_online_game()

func _on_local_host_button_pressed() -> void:
	Globals.start_local_game()

func _on_local_button_pressed() -> void:
	Globals.start_offline_game()
