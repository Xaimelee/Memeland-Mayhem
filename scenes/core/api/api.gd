extends Node

enum RequestId { TRY_LOGIN, GET_USER, SEND_LOADOUT }

const API_REQUEST = preload("uid://dh6mbxvp4aurg")
const HEADER = [ 
	"Content-Type: application/json"
]
const URL = [
	"https://trylogin-2esjymujsa-uc.a.run.app",
	"https://getuser-2esjymujsa-uc.a.run.app",
	"https://sendloadout-2esjymujsa-uc.a.run.app"
]

#func _ready() -> void:
	## Just trying syntax
	#var user_data: UserData = UserData.new("id", "address")

# Just doing a default body for now for testing purposes
func post_request(request_id: RequestId, callable: Callable, body: String) -> ApiRequest:
	var api_request: ApiRequest = API_REQUEST.instantiate()
	add_child(api_request)
	api_request.request_id = request_id
	# 4 means the connection is one shot and will be removed
	# This is a extra safeguard, the api request will already delete itself when it's done
	api_request.successful_response.connect(callable, 4)
	api_request.request(
		URL[request_id],
		HEADER,
		HTTPClient.Method.METHOD_POST,
		body
	)
	return api_request
