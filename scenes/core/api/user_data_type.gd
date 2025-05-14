extends ResponseType
class_name UserData

var user_id: String = ""
var wallet_address: String = ""

func _init(_user_id, _wallet_address) -> void:
	user_id = _user_id
	wallet_address = _wallet_address
