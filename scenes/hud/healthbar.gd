extends Control
class_name Healthbar

@export var health: Health
@export var colour: StyleBoxFlat

@onready var progress_bar: ProgressBar = $MarginContainer/ProgressBar

func _ready() -> void:
	if not health: return
	progress_bar.max_value = health.max_health
	progress_bar.value = health.current_health
	health.health_changed.connect(_on_health_health_changed)

func _on_health_health_changed(current_health: float) -> void:
	progress_bar.value = current_health
	visible = progress_bar.value > 0
