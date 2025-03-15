extends Node

@onready 
var status_label := $Status

func _ready() -> void:
	Firebase.Auth.login_succeeded.connect(_on_login_succeeded)
	Firebase.Auth.login_failed.connect(_on_login_failed)
	var provider: AuthProvider = Firebase.Auth.get_GoogleProvider()
	var token = Firebase.Auth.get_token_from_url(provider)
	if token != null:
		Firebase.Auth.login_with_oauth(token, provider)
		print(token)

func _on_login_button_pressed() -> void:
	var provider: AuthProvider = Firebase.Auth.get_GoogleProvider()
	#This needs to eventually be the site where the game will be hosted
	#If we hosted on multiple sites then we'd need to somehow know on a per build basis
	#Where the build is being hosted to have the correct address
	#Firebase.Auth.set_redirect_uri("http://localhost:8060/tmp_js_export.html")
	Firebase.Auth.get_auth_with_redirect(provider)

func _on_login_succeeded(auth_result) -> void:
	status_label.text = "Status: Logged In"
	print("Succeeded")
	
func _on_login_failed(code, message) -> void:
	status_label.text = "Status: Failed"
	print("Failed")
