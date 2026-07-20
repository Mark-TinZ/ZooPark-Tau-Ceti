extends Node3D

@export var boid_count: int = 150
@export var spawn_radius: float = 15.0

func _ready() -> void:
	var boid_scene := load("res://features/ai/boids/boid.tscn") as PackedScene
	if not boid_scene:
		return
		
	# Создание Boids
	for i in range(boid_count):
		var boid := boid_scene.instantiate() as Node3D
		add_child(boid)
		
		# Спавн в случайной позиции внутри радиуса
		var r := randf_range(0.0, spawn_radius)
		var angle := randf_range(0.0, TAU)
		boid.global_transform.origin = Vector3(cos(angle) * r, 0.5, sin(angle) * r)

var _time_passed: float = 0.0
var _last_print: int = 0

func _process(delta: float) -> void:
	_time_passed += delta
	var current_sec := int(_time_passed * 2) # Print twice a second
	if current_sec > _last_print:
		_last_print = current_sec
		print("Time: %.1f | FPS: %d | Boids: %d" % [_time_passed, Engine.get_frames_per_second(), boid_count])
		
	if _time_passed > 3.0:
		print("Test finished successfully.")
		get_tree().quit()
