extends ResponseType
class_name UserData

var user_id: String = ""
var wallet_address: String = ""
var player_name: String = "Player"
var level: int = 1
var inventory: Array = []
var stash: Array = []
var xp: int = 0

func _init(_user_id: String, _wallet_address: String, _player_name: String, _level: int, _inventory: Array, _stash: Array, _xp: int) -> void:
	user_id = _user_id
	wallet_address = _wallet_address
	player_name = _player_name
	level = _level
	inventory = _inventory
	stash = _stash
	xp = _xp
