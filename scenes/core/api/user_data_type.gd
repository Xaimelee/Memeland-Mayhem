extends ResponseType
class_name UserData

var user_id: String = ""
var wallet_address: String = ""
var player_name: String = "Player"
var level: int = 0
var inventory: Array = []
var stash: Array = []

func _init(_user_id: String, _wallet_address: String) -> void:
	user_id = _user_id
	wallet_address = _wallet_address
