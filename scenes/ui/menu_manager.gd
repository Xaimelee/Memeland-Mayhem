extends Node
class_name MenuManager

signal menu_changed(prev_menu: Menu, new_menu: Menu)

@export var menu_paths: Array[NodePath]
@export var starting_menu_name: String = "Menu"

var menus: Dictionary = {}
var current_menu: Menu = null:
	get:
		return current_menu
	set(value):
		if current_menu == value: return
		var prev_menu: Menu = current_menu
		if prev_menu:
			prev_menu.disabled()
			prev_menu.visible = false
		current_menu = value
		if current_menu:
			current_menu.visible = true
			current_menu.enabled()
		menu_changed.emit(prev_menu, current_menu)

func _ready() -> void:
	for menu_path in menu_paths:
		var menu: Menu = get_node(menu_path) as Menu
		if not menu: continue
		menus[menu.name] = menu
		menu.visible = false
	if not menus.has(starting_menu_name): return
	current_menu = menus[starting_menu_name]

func change_menu(menu_name: String) -> void:
	if not menus.has(menu_name): return
	current_menu = menus[menu_name]
