extends Node2D
class_name Item

# NOTE: I don't know if this is the best solution but I wanted to try and avoid redundant...
#... duplicate scenes in the file system. Weapon inherits from this and the UI will just make
#... "UIItem" nodes to show the name, icon, etc.

## Names should probably be unique
@export var item_name: String = "Name"
# This will need to be synced
@export var stack: int = 1
@export var icon: Texture2D
@export var max_stack: int = 1
