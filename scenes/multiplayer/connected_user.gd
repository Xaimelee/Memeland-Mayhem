extends Node
class_name ConnectedUser

enum UserStatus { WAITING, PLAYING }

var user_id: String = ""
var status: UserStatus = 0
var user_data: UserData = null
