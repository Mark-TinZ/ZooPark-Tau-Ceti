extends Node3D
class_name Boid

@export var max_speed: float = 10.0
@export var acceleration: float = 15.0
@export var sight_radius: float = 15.0
@export var separation_weight: float = 2.0
@export var alignment_weight: float = 1.0
@export var cohesion_weight: float = 1.0
@export var obstacle_avoid_weight: float = 5.0

var velocity: Vector3 = Vector3.ZERO
var _manager: Node = null
var _raycast: RayCast3D
var _avoid_vector: Vector3 = Vector3.ZERO

func _ready() -> void:
	# Случайный поворот и скорость при старте
	var angle := randf_range(0.0, TAU)
	var dir := Vector3(cos(angle), 0, sin(angle))
	velocity = dir * max_speed
	global_transform.basis = Basis.looking_at(velocity.normalized(), Vector3.UP)
	
	if has_node("/root/BoidManager"):
		_manager = get_node("/root/BoidManager")
		_manager.register_boid(self)
	
	# Настройка луча для избегания стен
	_raycast = RayCast3D.new()
	# Длина луча зависит от радиуса обзора, направлен вперед (-Z)
	_raycast.target_position = Vector3(0, 0, -sight_radius * 0.5)
	_raycast.collision_mask = 1 | 8 # Проверка земли/препятствий (1) и зданий (8)
	_raycast.enabled = false # Отключаем автоматический update каждый кадр для оптимизации
	add_child(_raycast)

func _exit_tree() -> void:
	if _manager:
		_manager.unregister_boid(self)

func _physics_process(delta: float) -> void:
	if not _manager:
		return
		
	var pos := global_transform.origin
	var neighbors: Array = _manager.get_neighbors(self, sight_radius * sight_radius)
	
	var separation := Vector3.ZERO
	var alignment := Vector3.ZERO
	var cohesion := Vector3.ZERO
	
	if neighbors.size() > 0:
		var center_of_mass := Vector3.ZERO
		var avg_velocity := Vector3.ZERO
		
		for n in neighbors:
			var n_pos: Vector3 = n.global_transform.origin
			var dist_sq := pos.distance_squared_to(n_pos)
			
			# 1. Separation (отталкивание от близких соседей)
			if dist_sq > 0.001:
				var diff: Vector3 = pos - n_pos
				# Чем ближе, тем сильнее вектор отталкивания
				separation += diff.normalized() / dist_sq
				
			# 2. Alignment (выравнивание направления по соседям)
			avg_velocity += n.velocity
			
			# 3. Cohesion (стремление в центр массы соседей)
			center_of_mass += n_pos
			
		var count := float(neighbors.size())
		
		separation = separation.normalized()
		
		avg_velocity /= count
		alignment = avg_velocity.normalized()
		
		center_of_mass /= count
		var to_center := center_of_mass - pos
		cohesion = to_center.normalized()
	
	# 4. Obstacle Avoidance (избегание препятствий с троттлингом)
	# Выполняем дорогой raycast только 1 раз в 5 кадров. Смещение по get_instance_id() 
	# гарантирует, что не все boids будут делать raycast в одном и том же кадре.
	if (Engine.get_physics_frames() + get_instance_id()) % 5 == 0:
		_raycast.force_raycast_update()
		if _raycast.is_colliding():
			var normal := _raycast.get_collision_normal()
			# Отражаемся от нормали препятствия
			_avoid_vector = normal
		else:
			_avoid_vector = Vector3.ZERO
			
	var avoidance := _avoid_vector
	
	# Суммируем вектора правил
	var steer := (separation * separation_weight) + (alignment * alignment_weight) + (cohesion * cohesion_weight) + (avoidance * obstacle_avoid_weight)
	
	# Держим движение в плоскости XZ
	steer.y = 0.0
	
	if steer != Vector3.ZERO:
		steer = steer.normalized()
		
	# Обновление скорости (плавный переход от текущей к целевой)
	var target_vel := (velocity.normalized() + steer * 0.1).normalized() * max_speed
	velocity = velocity.move_toward(target_vel, acceleration * delta)
	velocity.y = 0.0
	
	# Применение движения
	pos += velocity * delta
	global_transform.origin = pos
	
	# Плавный поворот в сторону движения (без физики)
	if velocity.length_squared() > 0.01:
		var forward := velocity.normalized()
		var target_basis := Basis.looking_at(forward, Vector3.UP, true)
		global_transform.basis = global_transform.basis.slerp(target_basis, 10.0 * delta)
