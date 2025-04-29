extends Control

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

func _ready() -> void:
	if MultiplayerManager.is_local() or MultiplayerManager.is_server():
		get_tree().change_scene_to_packed(MAIN_SCENE)

func _on_main_server_button_pressed() -> void:
	MultiplayerManager.override_is_local = false
	MultiplayerManager.server_ip = "52.63.141.232"
	get_tree().change_scene_to_packed(MAIN_SCENE)


func _on_local_host_button_pressed() -> void:
	MultiplayerManager.override_is_local = false
	MultiplayerManager.server_ip = "localhost"
	get_tree().change_scene_to_packed(MAIN_SCENE)


func _on_local_button_pressed() -> void:
	MultiplayerManager.override_is_local = true
	get_tree().change_scene_to_packed(MAIN_SCENE)
