extends ResponseType
class_name PlayflowServerData

var host: String = ""
var port: int = 0

func _init(_host: String, _port: int) -> void:
	host = _host
	port = _port
