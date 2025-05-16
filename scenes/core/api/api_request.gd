extends HTTPRequest
class_name ApiRequest

signal successful_response(response: ResponseType)

# This determines what type of response to return when completed
var request_id: Api.RequestId

func get_http_data(body: PackedByteArray) -> Variant:
	var json: JSON = JSON.new()
	var err: Error = json.parse(body.get_string_from_utf8())
	if err != OK: return null
	return json.data

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	print(str(response_code) + " code on request completed.")
	if request_id == 0 or request_id == 1:
		var data: Dictionary = get_http_data(body)["userData"]
		var user_data: UserData = UserData.new(
			data["userId"], 
			data["walletAddress"], 
			data["playerName"],
			data["level"],
			data["inventory"],
			data["stash"]
		)
		successful_response.emit(user_data)
	queue_free()
