extends Node

const MAIN_SCENE: PackedScene = preload("uid://c573o225twlil")
const PLAYER_MENU: PackedScene = preload("uid://b4scbqjbo7wtn")
const MAIN_MENU: PackedScene = preload("uid://wa40guwp27ql")

signal game_started()
# These are contextual to the player belonging to the client
signal player_spawned(player: PlayerCharacter)
signal player_died(player: PlayerCharacter)

# NOTE: We dynamically populate this dictionary at runtime based on scenes in the runtime items folder.
# The schema is "item_name": PackedScene
var item_scenes: Dictionary = {}

func _ready() -> void:
	load_item_scenes()

func load_item_scenes():
	if item_scenes.is_empty():
		var items_dir_path: String = "res://scenes/items/runtime_items"
		var dir: DirAccess = DirAccess.open(items_dir_path)
		if dir:
			dir.list_dir_begin()
			var file_name: String = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir():
					if file_name.ends_with(".tscn.remap"):
						# Call twice to get rid of both extensions
						var item_name: String = file_name.get_basename().get_basename()
						var real_file_name: String = file_name.get_basename()
						item_scenes[item_name] = load(items_dir_path + "/" + real_file_name)
					elif file_name.ends_with(".tscn"):
						var item_name: String = file_name.get_basename()
						item_scenes[item_name] = load(items_dir_path + "/" + file_name)
				file_name = dir.get_next()
			dir.list_dir_end()
		else:
			print("Could not open directory: ", items_dir_path)

func start_online_game():
	MultiplayerManager.override_is_local = false
	MultiplayerManager.server_ip = "52.63.141.232"
	get_tree().change_scene_to_packed(MAIN_SCENE)

func start_local_game():
	MultiplayerManager.override_is_local = false
	MultiplayerManager.server_ip = "localhost"
	get_tree().change_scene_to_packed(MAIN_SCENE)

func start_offline_game():
	MultiplayerManager.override_is_local = true
	get_tree().change_scene_to_packed(MAIN_SCENE)

func return_to_menu():
	if not MultiplayerManager.is_local():
		get_tree().change_scene_to_packed(PLAYER_MENU)
	else:
		get_tree().change_scene_to_packed(MAIN_MENU)
