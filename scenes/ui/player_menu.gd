extends Menu

const ITEM_DISPLAY_SCENE: PackedScene = preload("uid://bs85sd7odwt6f")
const MAX_INVENTORY = 6
const MAX_STASH = 24

@onready var user_id_label: Label = %UserId
@onready var name_label: Label = %Name
@onready var level_label: Label = %Level
@onready var stash_container: GridContainer = %StashContainer
@onready var inventory_container: HBoxContainer = %InventoryContainer
@onready var inventory: Inventory = %Inventory
@onready var stash: Inventory = %Stash
var inventory_displays: Array[ItemDisplay] = []
var stash_displays: Array[ItemDisplay] = []

func _ready() -> void:
	for n in inventory_container.get_child_count():
		var item_display: ItemDisplay = inventory_container.get_child(n)
		if item_display == null: continue
		inventory_displays.append(item_display)
	for n in stash_container.get_child_count():
		var item_display: ItemDisplay = stash_container.get_child(n)
		if item_display == null: continue
		stash_displays.append(item_display)
	#If our mockup UI has less slots than we want then we spawn more here
	for n in MAX_STASH - stash_displays.size():
		var item_display: ItemDisplay = ITEM_DISPLAY_SCENE.instantiate() as ItemDisplay
		stash_container.add_child(item_display)
		stash_displays.append(item_display)
	for n in MAX_INVENTORY - inventory_displays.size():
		var item_display: ItemDisplay = ITEM_DISPLAY_SCENE.instantiate() as ItemDisplay
		inventory_container.add_child(item_display)
		inventory_displays.append(item_display)

# Overriding
func enabled() -> void: 
	if not UserManager.user_data: return
	var user_data: UserData = UserManager.user_data
	user_id_label.text = user_data.user_id
	name_label.text = user_data.player_name
	level_label.text = str(user_data.level)
	# We clear these because we assume when enabling that we've fetched new data potentially.
	# NOTE: Right now we don't fetch new data, we will need to actually do so in the future before we finish...
	#... loading the player page.
	for child in inventory_container.get_children():
		var item_display: ItemDisplay = child as ItemDisplay
		if not item_display: continue
		item_display.set_icon_and_quantity(null, 0)
	for child in stash_container.get_children():
		var item_display: ItemDisplay = child as ItemDisplay
		if not item_display: continue
		item_display.set_icon_and_quantity(null, 0)
	# Here we update the item displays with the user data inventory and stash data
	for user_item in user_data.inventory:
		var item_name: String = user_item["item_name"]
		var slot: int = user_item["slot"]
		inventory.create_and_add_item(item_name, slot)
		var item: Item = inventory.get_item_at_index(slot)
		inventory_displays[slot].set_icon_and_quantity(item.icon, item.stack)
	for user_item in user_data.stash:
		var item_name: String = user_item["item_name"]
		var slot: int = user_item["slot"]
		stash.create_and_add_item(item_name, slot)
		var item: Item = stash.get_item_at_index(slot)
		stash_displays[slot].set_icon_and_quantity(item.icon, item.stack)

# Overriding
func disabled() -> void:
	pass
