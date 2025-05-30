extends Control
class_name GameUI

@onready var message: Control = %Message
@onready var message_label: Label = %MessageLabel
@onready var player_ui: Control = %PlayerUI

var player: PlayerCharacter = null

func _ready() -> void:
	Globals.game_started.connect(_on_game_started)
	Globals.player_spawned.connect(_on_player_spawned)
	Globals.player_died.connect(_on_player_died)

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

func _on_player_spawned(_player: PlayerCharacter) -> void:
	player = _player
	hide_message()

func _on_player_died(_player: PlayerCharacter) -> void:
	show_message("You were killed. Returning to menu...")
