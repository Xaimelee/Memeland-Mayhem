extends Node
class_name MenuManager

signal menu_changed(prev_menu: Control, new_menu: Control)

@export var menu_paths: Array[NodePath]
@export var starting_menu_name: String = "Menu"

var menus: Dictionary = {}
var current_menu: Control = null:
	get:
		return current_menu
	set(value):
		if current_menu == value: return
		var prev_menu: Control = current_menu
		if prev_menu:
			prev_menu.visible = false
		current_menu = value
		if current_menu:
			current_menu.visible = true
		menu_changed.emit(prev_menu, current_menu)

func _ready() -> void:
	for menu_path in menu_paths:
		var node: Control = get_node(menu_path)
		menus[node.name.to_lower()] = node
		node.visible = false
	if not menus.has(starting_menu_name.to_lower()): return
	current_menu = menus[starting_menu_name.to_lower()]

func change_menu(menu_name: String) -> void:
	if not menus.has(menu_name.to_lower()): return
	current_menu = menus[menu_name.to_lower()]
