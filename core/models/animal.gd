extends RefCounted
class_name Animal

enum Type { CAT, PENGUIN, DOG, BEAR, GIRAFFE, ELEPHANT, FISH }
enum State { HEALTHY, SICK, DEAD }

var animal_name: String = ""
var type: Type = Type.CAT
var age: int = 1
var is_male: bool = true
var state: State = State.HEALTHY
var happiness: float = 100.0

func get_price() -> int:
	match type:
		Type.CAT:
			return 200 + (20 - age) * 30
		Type.PENGUIN:
			return 800 + (20 - age) * 20
		Type.DOG:
			return 250 + (20 - age) * 25
		Type.BEAR:
			return 1500 + (20 - age) * 50
		Type.GIRAFFE:
			return 1200 + (20 - age) * 40
		Type.ELEPHANT, Type.FISH:
			return 2000 + (20 - age) * 60
	return 0
