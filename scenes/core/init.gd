extends Node

# Gamescene
const MAIN_SCENE: PackedScene = preload("uid://c573o225twlil")
const MAIN_MENU: PackedScene = preload("uid://wa40guwp27ql")
const PLAYER_MENU: PackedScene = preload("uid://b4scbqjbo7wtn")

func _ready() -> void:
	# Server just needs to load into the game scene. 
	if MultiplayerManager.is_local() or MultiplayerManager.is_server():
		get_tree().change_scene_to_packed(MAIN_SCENE)
		Globals.scene_changed.emit("Main")
	# We force guest login if not on web build since connecting to wallet can...
	#... only happen on the web build.
	elif OS.get_name() != "Web":
		get_tree().change_scene_to_packed(MAIN_MENU)
		Globals.scene_changed.emit("Main Menu")
	else:
		# Login and player menu (inventory, stash, leveling).
		get_tree().change_scene_to_packed(PLAYER_MENU)
		Globals.scene_changed.emit("Player Menu")
	
