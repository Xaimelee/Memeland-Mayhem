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
		print(data)
		var user_data: UserData = UserData.new(
			data["userId"] as String, 
			data["walletAddress"] as String, 
			data["playerName"] as String,
			data["level"] as int,
			data["inventory"] as Array[Dictionary],
			data["stash"] as Array[Dictionary]
		)
		print(user_data)
		successful_response.emit(user_data)
	queue_free()
