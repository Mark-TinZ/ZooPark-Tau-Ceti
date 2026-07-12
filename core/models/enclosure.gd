extends RefCounted
class_name Enclosure

enum Climate { TROPICAL, MODERATE, POLAR, WATER }

var enclosure_name: String = ""
var climate: Climate = Climate.MODERATE
var capacity: int = 5
var dirt_level: float = 0.0
var animals: Array[Animal] = []

func get_build_price() -> int:
	match climate:
		Climate.TROPICAL:
			return 1000 + capacity * 100
		Climate.MODERATE:
			return 1200 + capacity * 100
		Climate.POLAR:
			return 1500 + capacity * 100
		Climate.WATER:
			return 2000 + capacity * 100
	return 0

func get_daily_expense() -> int:
	var base_expense: int = 0
	match climate:
		Climate.TROPICAL:
			base_expense = 50
		Climate.MODERATE:
			base_expense = 60
		Climate.POLAR, Climate.WATER:
			base_expense = 70
			
	return base_expense + capacity * 10
