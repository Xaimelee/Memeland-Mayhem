extends Node

enum RequestId { TRY_LOGIN, GET_USER, SEND_LOADOUT, UPDATE_LOADOUT, GET_SERVER_IP }

const API_REQUEST = preload("uid://dh6mbxvp4aurg")
const HEADER = [ 
	"Content-Type: application/json"
]
const URL = [
	"https://trylogin-2esjymujsa-uc.a.run.app",
	"https://getuser-2esjymujsa-uc.a.run.app",
	"https://sendloadout-2esjymujsa-uc.a.run.app",
	"https://updateloadout-2esjymujsa-uc.a.run.app",
	"https://api.computeflow.cloud/v2/servers/?include_launching=true"
]

# Just doing a default body for now for testing purposes
func post_request(request_id: RequestId, callable: Callable, body: String, header: Array = []) -> ApiRequest:
	var api_request: ApiRequest = API_REQUEST.instantiate()
	add_child(api_request)
	api_request.request_id = request_id
	# 4 means the connection is one shot and will be removed
	# This is a extra safeguard, the api request will already delete itself when it's done
	api_request.successful_response.connect(callable, 4)
	var headers: Array = HEADER
	headers.append_array(header)
	api_request.request(
		URL[request_id],
		headers,
		HTTPClient.Method.METHOD_POST,
		body
	)
	return api_request

func get_request(request_id: RequestId, callable: Callable, body: String, header: Array = []) -> ApiRequest:
	var api_request: ApiRequest = API_REQUEST.instantiate()
	add_child(api_request)
	api_request.request_id = request_id
	# 4 means the connection is one shot and will be removed
	# This is a extra safeguard, the api request will already delete itself when it's done
	api_request.successful_response.connect(callable, 4)
	var headers: Array = HEADER.duplicate()
	headers.append_array(header)
	print(headers)
	api_request.request(
		URL[request_id],
		headers,
		HTTPClient.Method.METHOD_GET,
		body
	)
	return api_request
