extends Menu

const ITEM_DISPLAY_SCENE: PackedScene = preload("uid://bs85sd7odwt6f")
const MAX_INVENTORY = 6
const MAX_STASH = 24
const XP_PER_LEVEL = 100

@onready var user_id_label: Label = %UserId
@onready var name_label_edit: HBoxContainer = %NameLabelEdit
@onready var name_label: Label = %Name
@onready var name_input_save_cancel: HBoxContainer = %NameInputSaveCancel
@onready var name_input_field: InputField = %NameInputField
@onready var level_label: Label = %LevelLabel
@onready var stash_container: GridContainer = %StashContainer
@onready var inventory_container: HBoxContainer = %InventoryContainer
@onready var inventory: Inventory = %Inventory
@onready var stash: Inventory = %Stash
@onready var selected_item_display: ItemDisplay = %SelectedItemDisplay
@onready var xp_label: Label = %XPLabel
@onready var xp_progress_bar: TextureProgressBar = %XPProgressBar

var inventory_displays: Array[ItemDisplay] = []
var stash_displays: Array[ItemDisplay] = []
var selected_item: SelectedItem = null

func _ready() -> void:
	for n in inventory_container.get_child_count():
		var item_display: ItemDisplay = inventory_container.get_child(n)
		if item_display == null: continue
		inventory_displays.append(item_display)
		item_display.clicked.connect(_on_item_display_clicked)
	for n in stash_container.get_child_count():
		var item_display: ItemDisplay = stash_container.get_child(n)
		if item_display == null: continue
		stash_displays.append(item_display)
		item_display.clicked.connect(_on_item_display_clicked)
	# If our mockup UI has less slots than we want then we spawn more here
	for n in MAX_STASH - stash_displays.size():
		var item_display: ItemDisplay = ITEM_DISPLAY_SCENE.instantiate() as ItemDisplay
		stash_container.add_child(item_display)
		stash_displays.append(item_display)
		item_display.clicked.connect(_on_item_display_clicked)
	for n in MAX_INVENTORY - inventory_displays.size():
		var item_display: ItemDisplay = ITEM_DISPLAY_SCENE.instantiate() as ItemDisplay
		inventory_container.add_child(item_display)
		inventory_displays.append(item_display)
		item_display.clicked.connect(_on_item_display_clicked)
	# Avoids us needing to manually make sure the displays update when items get moved around.
	inventory.index_updated.connect(_on_inventory_index_updated)
	stash.index_updated.connect(_on_stash_index_updated)

func _process(delta: float) -> void:
	update_selected_item_display()

func _input(event: InputEvent) -> void:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event: return
	# Cancel current selection
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		selected_item = null

# Overriding
func enabled() -> void: 
	if not UserManager.user_data: return
	var user_data: UserData = UserManager.user_data
	user_id_label.text = SolanaService.wallet.get_shorthand_address()
	name_label.text = user_data.player_name
	#level_label.text = str(user_data.level)
	level_label.text = str(get_level_from_xp(user_data.xp))
	xp_progress_bar.value = get_xp_progress_percent(user_data.xp)
	var next_milestone: int = (get_level_from_xp(user_data.xp) + 1) * XP_PER_LEVEL
	xp_label.text = "%d / %d" % [user_data.xp, next_milestone]
	# We clear these because we assume when enabling that we've fetched new data potentially.
	# NOTE: Right now we don't fetch new data, we will need to actually do so in the future before we finish...
	#... loading the player page.
	for item_display in inventory_displays:
		item_display.set_icon_and_quantity(null, 0)
	for item_display in stash_displays:
		item_display.set_icon_and_quantity(null, 0)
	# Here we update the item displays with the user data inventory and stash data
	for user_item in user_data.inventory:
		var item_name: String = user_item["item_name"]
		var slot: int = user_item["slot"]
		inventory.create_and_add_item(item_name, slot)
		#var item: Item = inventory.get_item_at_index(slot)
		#inventory_displays[slot].set_icon_and_quantity(item.icon, item.stack)
	for user_item in user_data.stash:
		var item_name: String = user_item["item_name"]
		var slot: int = user_item["slot"]
		stash.create_and_add_item(item_name, slot)
		#var item: Item = stash.get_item_at_index(slot)
		#stash_displays[slot].set_icon_and_quantity(item.icon, item.stack)

# Overriding
func disabled() -> void:
	pass

func update_selected_item_display() -> void:
	selected_item_display.visible = selected_item != null
	if not selected_item_display.visible: return
	var mouse_pos: Vector2 = get_global_mouse_position()
	var item_size: Vector2 = selected_item_display.size * 0.5
	selected_item_display.global_position = mouse_pos

func _on_inventory_index_updated(item: Item, index: int) -> void:
	if not item == null:
		inventory_displays[index].set_icon_and_quantity(item.icon, item.stack)
	else:
		inventory_displays[index].set_icon_and_quantity(null, 0)

func _on_stash_index_updated(item: Item, index: int) -> void:
	if not item == null:
		stash_displays[index].set_icon_and_quantity(item.icon, item.stack)
	else:
		stash_displays[index].set_icon_and_quantity(null, 0)

func _on_item_display_clicked(item_display: ItemDisplay) -> void:
	# Naming is alittle confusing but both stash + inventory are of type inventory
	var clicked_inventory: Inventory = inventory if inventory_displays.has(item_display) else stash
	var clicked_index: int = item_display.get_index()
	if selected_item:
		if clicked_inventory == selected_item.inventory:
			# Cancel selection if we click ourself
			if clicked_index == selected_item.index: return
			# Move here
			clicked_inventory.move_item(selected_item.index, clicked_index)
		else:
			# Move item from different inventory, will also swap if valid
			var item_in_slot: Item = clicked_inventory.get_item_at_index(clicked_index)
			clicked_inventory.remove_item(clicked_index)
			selected_item.inventory.remove_item(selected_item.index)
			clicked_inventory.add_item(selected_item.item, clicked_index)
			selected_item.inventory.add_item(item_in_slot, selected_item.index)
			# We reparent here now because the add/remove functions no longer do reparenting.
			if selected_item.item != null:
				selected_item.item.reparent(clicked_inventory)
			if item_in_slot != null:
				item_in_slot.reparent(selected_item.inventory)
		selected_item = null
	else:
		var clicked_item: Item = clicked_inventory.get_item_at_index(clicked_index)
		if not clicked_item: return
		selected_item = SelectedItem.new(
			clicked_item,
			clicked_index,
			clicked_inventory
		)
		selected_item_display.set_icon_and_quantity(clicked_item.icon, clicked_item.stack)

func _on_edit_name_button_pressed() -> void:
	name_label_edit.hide()
	name_input_save_cancel.show()

func _on_save_name_button_pressed() -> void:
	name_label_edit.show()
	name_input_save_cancel.hide()
	if name_input_field.text != "":
		name_label.text = name_input_field.text
		UserManager.user_name = name_label.text

func _on_cancel_name_button_pressed() -> void:
	name_label_edit.show()
	name_input_save_cancel.hide()

func get_level_from_xp(xp: int) -> int:
	return xp / XP_PER_LEVEL

func get_xp_progress_percent(xp: int) -> float:
	return float(xp % XP_PER_LEVEL) / XP_PER_LEVEL * 100.0
