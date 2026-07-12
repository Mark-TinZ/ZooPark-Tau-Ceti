extends RefCounted
class_name Worker

enum Role { VET, CLEANER, FOODMAN }

var worker_name: String = ""
var role: Role = Role.CLEANER
var is_working: bool = false

func get_daily_salary() -> int:
	match role:
		Role.VET:
			return 500
		Role.CLEANER:
			return 300
		Role.FOODMAN:
			return 200
	return 0
