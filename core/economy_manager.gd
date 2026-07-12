extends Node

signal money_changed(new_amount: int)
signal day_changed(new_day: int)
signal staff_changed(total_count: int)
signal active_enclosure_changed(enclosure: Enclosure)

var money: int = 10000
var day: int = 1
var food_stock: int = 0
var popularity: int = 0

var animals: Array[Animal] = []
var workers: Array[Worker] = []
var enclosures: Array[Enclosure] = []

var active_enclosure: Enclosure = null:
	set(value):
		active_enclosure = value
		active_enclosure_changed.emit(active_enclosure)

func _ready() -> void:
	pass

func spend_money(amount: int) -> bool:
	if money >= amount:
		money -= amount
		money_changed.emit(money)
		return true
	return false

func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)

func advance_day() -> void:
	day += 1
	day_changed.emit(day)
