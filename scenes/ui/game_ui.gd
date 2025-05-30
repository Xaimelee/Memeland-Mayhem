extends Control
class_name GameUI

@onready var message: Control = %Message
@onready var message_label: Label = %MessageLabel
@onready var player_ui: Control = %PlayerUI
@onready var inventory_container = %InventoryContainer

var player: PlayerCharacter = null
var item_displays: Array[ItemDisplay] = []
var current_selection: int = 0

func _ready() -> void:
	Globals.game_started.connect(_on_game_started)
	Globals.player_spawned.connect(_on_player_spawned)
	Globals.player_died.connect(_on_player_died)
	Globals.player_extracted.connect(_on_player_extracted)
	for child in inventory_container.get_children():
		var item_display: ItemDisplay = child as ItemDisplay
		if item_display == null: continue
		item_displays.append(item_display)
		item_display.set_icon_and_quantity(null, 0)

func _process(delta: float) -> void:
	player_ui.visible = player != null

func show_message(text: String) -> void:
	message.visible = true
	message_label.text = text

func hide_message() -> void:
	message.visible = false

func _on_game_started() -> void:
	if player == null:
		show_message("Waiting for server...")

func _on_index_updated(item: Item, index: int) -> void:
	if not item == null:
		item_displays[index].set_icon_and_quantity(item.icon, item.stack)
	else:
		item_displays[index].set_icon_and_quantity(null, 0)

func _on_equipment_slot_changed(slot: int) -> void:
	item_displays[current_selection].selected.visible = false
	current_selection = slot
	item_displays[current_selection].selected.visible = true

func _on_player_spawned(_player: PlayerCharacter) -> void:
	player = _player
	for n in player.inventory.slots:
		var item: Item = player.inventory.get_item_at_index(n)
		if not item == null:
			item_displays[n].set_icon_and_quantity(item.icon, item.stack)
		else:
			item_displays[n].set_icon_and_quantity(null, 0)
	player.equipment_slot_changed.connect(_on_equipment_slot_changed)
	player.inventory.index_updated.connect(_on_index_updated)
	hide_message()

func _on_player_died(_player: PlayerCharacter) -> void:
	show_message("You were killed. Returning to menu...")

func _on_player_extracted(_player: PlayerCharacter) -> void:
	show_message("You have extracted! Returning to menu...")
