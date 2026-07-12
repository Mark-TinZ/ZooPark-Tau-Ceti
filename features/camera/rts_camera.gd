class_name RTSCamera
extends Node3D

# ═══════════════════════════════════════════════════════════════
# GOD-TIER RTS CAMERA — SpringArm3D + Коллизии + Плавный Зум
# Иерархия: RTSCameraPivot / CameraYaw / SpringArm3D / Camera3D
# ═══════════════════════════════════════════════════════════════

# === Экспортируемые параметры ===
@export var move_speed: float = 30.0
@export var edge_pan_speed: float = 20.0
@export var rotation_speed: float = 0.005
@export var edge_margin: float = 20.0

# Зум
@export var min_zoom: float = 0.5
@export var max_zoom: float = 50.0
@export var zoom_step: float = 2.0
@export var zoom_smoothness: float = 8.0

# Адаптивный наклон: при max_zoom камера смотрит круче, при min_zoom — положе
@export var pitch_at_min_zoom: float = -15.0  # Ближний зум: еще более пологий угол
@export var pitch_at_max_zoom: float = -60.0  # Дальний зум: крутой угол (градусы)
@export var pitch_smoothness: float = 5.0

# Высота над ландшафтом
@export var min_height_above_terrain: float = 1.0
@export var height_smoothness: float = 5.0

# === Узлы (устанавливаются в _ready) ===
var _camera_yaw: Node3D
var _spring_arm: SpringArm3D
var _camera: Camera3D

# === Внутреннее состояние ===
var _target_spring_length: float = 20.0
var _target_pitch_deg: float = -45.0
var _world_generator = null
var _is_gamepad_active: bool = false

func _ready() -> void:
	# Находим дочерние узлы
	_camera_yaw = $CameraYaw
	_spring_arm = $CameraYaw/SpringArm3D
	_camera = $CameraYaw/SpringArm3D/Camera3D
	
	# Настройка SpringArm3D для защиты от клиппинга
	var shape = SphereShape3D.new()
	shape.radius = 0.5
	_spring_arm.shape = shape
	_spring_arm.collision_mask = 2 | 4 # Terrain (2) и Buildings (4)
	
	# Инициализация зума
	_target_spring_length = _spring_arm.spring_length
	
	# Установка курсора (в игре он всегда confined)
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	
	# Ищем генератор мира для запроса высоты ландшафта
	await get_tree().process_frame
	_world_generator = _find_world_generator()

func _find_world_generator():
	var game = get_tree().current_scene
	if game:
		var gen = game.get_node_or_null("WorldGenerator")
		if gen:
			return gen
	return null

func _process(delta: float) -> void:
	_handle_movement(delta)
	_handle_rotation(delta)
	_handle_analog_zoom(delta)
	_handle_zoom_interpolation(delta)
	_handle_adaptive_pitch(delta)
	_handle_terrain_height(delta)

# ========== ПЕРЕМЕЩЕНИЕ И EDGE PANNING ==========

func _handle_movement(delta: float) -> void:
	# Получаем вектор ввода от геймпада или клавиатуры
	var input_vec = Input.get_vector("camera_pan_left", "camera_pan_right", "camera_pan_up", "camera_pan_down")
	var input_dir = Vector3(input_vec.x, 0, input_vec.y)
	
	var is_edge_panning = false
	var edge_dir = Vector2.ZERO
	
	# Edge Panning только если геймпад не активен
	if not _is_gamepad_active:
		var vp = get_viewport()
		var mouse_pos = vp.get_mouse_position()
		var vp_size = vp.get_visible_rect().size
		
		if mouse_pos.x < edge_margin: edge_dir.x = -1
		elif mouse_pos.x > vp_size.x - edge_margin: edge_dir.x = 1
		
		if mouse_pos.y < edge_margin: edge_dir.y = -1
		elif mouse_pos.y > vp_size.y - edge_margin: edge_dir.y = 1
		
		if edge_dir != Vector2.ZERO:
			is_edge_panning = true
			input_dir += Vector3(edge_dir.x, 0, edge_dir.y)
	
	if input_dir.length_squared() > 0:
		if input_dir.length() > 1.0:
			input_dir = input_dir.normalized()
			
		# Направление относительно текущего поворота CameraYaw (изометрическая трансформация)
		input_dir = input_dir.rotated(Vector3.UP, _camera_yaw.rotation.y)
		
		var current_speed = edge_pan_speed if is_edge_panning and input_vec.length_squared() == 0 else move_speed
		position += input_dir * current_speed * delta

# ========== ВРАЩЕНИЕ ==========

func _handle_rotation(delta: float) -> void:
	var rot_dir = Input.get_action_strength("camera_rotate_left") - Input.get_action_strength("camera_rotate_right")
	if rot_dir != 0.0:
		_camera_yaw.rotate_y(rot_dir * rotation_speed * delta * 400.0)

# ========== ЗУМ (АНАЛОГОВЫЙ И ДИСКРЕТНЫЙ) ==========

func _unhandled_input(event: InputEvent) -> void:
	# Отслеживаем, чем играет игрок
	if event is InputEventJoypadMotion or event is InputEventJoypadButton:
		if not _is_gamepad_active:
			_is_gamepad_active = true
	elif event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventKey:
		if _is_gamepad_active:
			_is_gamepad_active = false
	
	# Зум колёсиком (дискретный) - ловим в unhandled_input, чтобы не мешать UI
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_target_spring_length = maxf(_target_spring_length - zoom_step, min_zoom)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				_target_spring_length = minf(_target_spring_length + zoom_step, max_zoom)
				get_viewport().set_input_as_handled()
	
	# Вращение камеры (ПКМ + движение мыши)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_camera_yaw.rotate_y(-event.relative.x * rotation_speed)

func _handle_analog_zoom(delta: float) -> void:
	var zoom_dir = Input.get_action_strength("camera_zoom_out") - Input.get_action_strength("camera_zoom_in")
	if zoom_dir != 0.0:
		_target_spring_length = clampf(_target_spring_length + zoom_dir * zoom_step * delta * 20.0, min_zoom, max_zoom)

func _handle_zoom_interpolation(delta: float) -> void:
	_spring_arm.spring_length = lerpf(
		_spring_arm.spring_length,
		_target_spring_length,
		delta * zoom_smoothness
	)

# ========== АДАПТИВНЫЙ НАКЛОН ==========

func _handle_adaptive_pitch(delta: float) -> void:
	var zoom_ratio = inverse_lerp(min_zoom, max_zoom, _spring_arm.spring_length)
	_target_pitch_deg = lerpf(pitch_at_min_zoom, pitch_at_max_zoom, zoom_ratio)
	
	var current_pitch = rad_to_deg(_spring_arm.rotation.x)
	var new_pitch = lerpf(current_pitch, _target_pitch_deg, delta * pitch_smoothness)
	_spring_arm.rotation.x = deg_to_rad(new_pitch)

# ========== ЗАЩИТА ВЫСОТЫ ПИВОТА (ЧЕРЕЗ NOISE) ==========

func _handle_terrain_height(delta: float) -> void:
	if not _world_generator:
		position.y = maxf(position.y, 5.0)
		return
	
	if _world_generator.has_method("get_height_at_pos"):
		var terrain_y = _world_generator.get_height_at_pos(position.x, position.z)
		var target_y = terrain_y + min_height_above_terrain
		
		if position.y < target_y:
			position.y = lerpf(position.y, target_y, delta * height_smoothness)

# ========== УТИЛИТЫ ==========

func get_focus_point() -> Vector3:
	if not _camera: return Vector3.ZERO
	
	var space_state = get_world_3d().direct_space_state
	var center = get_viewport().get_visible_rect().size / 2.0
	var origin = _camera.project_ray_origin(center)
	var normal = _camera.project_ray_normal(center)
	var end = origin + normal * 1000.0
	
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	var result = space_state.intersect_ray(query)
	
	if result: return result.position
	
	if normal.y != 0:
		var t = -origin.y / normal.y
		return origin + normal * t
	return Vector3.ZERO

func get_camera_3d() -> Camera3D:
	return _camera

func get_camera_save_data() -> Dictionary:
	return {
		"pivot_pos": [position.x, position.y, position.z],
		"yaw": _camera_yaw.rotation.y if _camera_yaw else 0.0,
		"spring_length": _target_spring_length
	}

func load_camera_save_data(data: Dictionary) -> void:
	if data.has("pivot_pos"):
		var p = data["pivot_pos"]
		position = Vector3(p[0], p[1], p[2])
	if data.has("yaw") and _camera_yaw:
		_camera_yaw.rotation.y = float(data["yaw"])
	if data.has("spring_length"):
		_target_spring_length = float(data["spring_length"])
		if _spring_arm:
			_spring_arm.spring_length = _target_spring_length
