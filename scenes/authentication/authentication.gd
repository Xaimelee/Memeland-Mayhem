extends Node

#const HEADERS : PackedStringArray = [
	#"Content-Type: application/json",
	#"Accept: application/json",
#]

@onready 
var status_label := $Status
@onready
var wallet_adapter_ui : WalletAdapterUI = $WalletAdapterUI

func _ready() -> void:
	wallet_adapter_ui.visible = false
	#SolanaService.wallet.on_login_success.connect(_on_login_succeeded)
	#SolanaService.wallet.on_login_fail.connect(_on_login_failed)
	SolanaService.wallet.on_login_begin.connect(pop_adapter)
	SolanaService.wallet.on_login_finish.connect(confirm_login)
	wallet_adapter_ui.on_provider_selected.connect(process_adapter_result)
	wallet_adapter_ui.on_adapter_cancel.connect(cancel_login)
	#Firebase.Auth.login_succeeded.connect(_on_login_succeeded)
	#Firebase.Auth.login_failed.connect(_on_login_failed)
	#var provider: AuthProvider = Firebase.Auth.get_GoogleProvider()
	#var token = Firebase.Auth.get_token_from_url(provider)
	#if token != null:
		#print(Firebase.Auth.auth.local_id)
		#print("here")
		#_send_request_for_access_token(token)
		#var task = Firebase.Functions.execute("verifyIdToken", HTTPClient.METHOD_GET, {}, { "id_token": token })
		#var result_dict = await task.function_executed
		#print(result_dict)
		#Firebase.Auth.login_with_oauth(token, provider)

#func _send_request_for_access_token(oauth_token: String) -> void:
	#var url = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=AIzaSyCSNPAg2X0dIiUNJ8W3K5kAirGSu2RSwhw"
	#var request_body = {
		#"postBody": "id_token=" + oauth_token + "&providerId=google.com",
		#"requestUri": "http://localhost",
		#"returnSecureToken": true
	#}
	#var http_request = HTTPRequest.new()
	#add_child(http_request)
	#http_request.request_completed.connect(self._on_request_completed)
	#var headers = ["Content-Type: application/json"]
	#var body = JSON.stringify(request_body)
	#var error = http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	#if error != OK:
		#print("Error sending request:", error)
#
#func _send_access_request(token: String) -> void:
	#print(token)
	#var url = "https://us-central1-memeland-mayhem-6e7a7.cloudfunctions.net/verifyIdToken"
	#var body = JSON.stringify({ "id_token": token })
	#var request = HTTPRequest.new()
	#add_child(request)
	#var error = request.request(url, HEADERS, HTTPClient.METHOD_POST, body)
	#if error != OK:
		#print("Error sending request:", error)
#
#func _on_request_completed(result, response_code, headers, body) -> void:
	#var json = JSON.new()
	#json.parse(body.get_string_from_utf8())
	#var response = json.get_data()
	#print(response)

func _on_login_button_pressed() -> void:
	SolanaService.wallet.try_login()
	#var provider: AuthProvider = Firebase.Auth.get_GoogleProvider()
	#This needs to eventually be the site where the game will be hosted
	#If we hosted on multiple sites then we'd need to somehow know on a per build basis
	#Where the build is being hosted to have the correct address
	#Firebase.Auth.set_redirect_uri("http://localhost:8060/tmp_js_export.html")
	#Firebase.Auth.get_auth_with_redirect(provider)

func _on_login_succeeded(auth_result) -> void:
	status_label.text = "Status: Logged In"
	print("Succeeded")
	
func _on_login_failed(code, message) -> void:
	status_label.text = "Status: Failed"
	print("Failed")

func pop_adapter()-> void:
	wallet_adapter_ui.visible = true
	wallet_adapter_ui.setup(SolanaService.wallet.wallet_adapter.get_available_wallets())
	
func process_adapter_result(provider_id:int) -> void:
	SolanaService.wallet.login_adapter(provider_id)

func cancel_login()-> void:
	wallet_adapter_ui.visible = false
	
func confirm_login(login_success:bool) -> void:
	wallet_adapter_ui.visible = false
	if SolanaService.wallet.is_logged_in():
		SolanaService.transaction_manager.sign_message()
