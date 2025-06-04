extends Node
class_name ConnectedUser

enum UserStatus { WAITING, PLAYING, DEAD, EXTRACTED }

var user_id: String = ""
var status: UserStatus = 0
var user_data: UserData = null
var user_name: String = "Player"
