class_name RTSCamera
extends Node3D

# ═══════════════════════════════════════════════════════════════
# GOD-TIER RTS CAMERA — SpringArm3D + Коллизии + Плавный Зум
# Иерархия: RTSCameraPivot / CameraYaw / SpringArm3D / Camera3D
# ═══════════════════════════════════════════════════════════════

# === Экспортируемые параметры ===
@export var move_speed: float = 30.0
@export var rotation_speed: float = 0.005

# Зум
@export var min_zoom: float = 5.0
@export var max_zoom: float = 50.0
@export var zoom_step: float = 2.0
@export var zoom_smoothness: float = 8.0

# Адаптивный наклон: при max_zoom камера смотрит круче, при min_zoom — положе
@export var pitch_at_min_zoom: float = -30.0  # Ближний зум: пологий угол (градусы)
@export var pitch_at_max_zoom: float = -60.0  # Дальний зум: крутой угол (градусы)
@export var pitch_smoothness: float = 5.0

# Высота над ландшафтом
@export var min_height_above_terrain: float = 3.0
@export var height_smoothness: float = 5.0

# === Узлы (устанавливаются в _ready) ===
var _camera_yaw: Node3D
var _spring_arm: SpringArm3D
var _camera: Camera3D

# === Внутреннее состояние ===
var _target_spring_length: float = 20.0
var _target_pitch_deg: float = -45.0
var _world_generator: WorldGenerator = null

func _ready() -> void:
	# Находим дочерние узлы
	_camera_yaw = $CameraYaw
	_spring_arm = $CameraYaw/SpringArm3D
	_camera = $CameraYaw/SpringArm3D/Camera3D
	
	# Инициализация зума
	_target_spring_length = _spring_arm.spring_length
	
	# Установка курсора
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	
	# Ищем генератор мира для запроса высоты ландшафта
	await get_tree().process_frame
	_world_generator = _find_world_generator()

func _find_world_generator() -> WorldGenerator:
	var game = get_tree().current_scene
	if game:
		var gen = game.get_node_or_null("WorldGenerator")
		if gen is WorldGenerator:
			return gen
	return null

func _process(delta: float) -> void:
	_handle_movement(delta)
	_handle_zoom_interpolation(delta)
	_handle_adaptive_pitch(delta)
	_handle_terrain_height(delta)

# ========== ПЕРЕМЕЩЕНИЕ (WASD) ==========

func _handle_movement(delta: float) -> void:
	var input_dir = Vector3.ZERO
	
	if Input.is_physical_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		input_dir.z -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		input_dir.z += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		input_dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		input_dir.x += 1
	
	if input_dir.length_squared() > 0:
		# Направление относительно текущего поворота CameraYaw
		input_dir = input_dir.normalized().rotated(Vector3.UP, _camera_yaw.rotation.y)
		position += input_dir * move_speed * delta

# ========== ЗУМ (КОЛЁСИКО МЫШИ) ==========

func _input(event: InputEvent) -> void:
	# Зум колёсиком
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

func _handle_zoom_interpolation(delta: float) -> void:
	# Плавная интерполяция spring_length
	_spring_arm.spring_length = lerpf(
		_spring_arm.spring_length,
		_target_spring_length,
		delta * zoom_smoothness
	)

# ========== АДАПТИВНЫЙ НАКЛОН ==========

func _handle_adaptive_pitch(delta: float) -> void:
	# Линейная интерполяция pitch в зависимости от текущего зума
	var zoom_ratio = inverse_lerp(min_zoom, max_zoom, _spring_arm.spring_length)
	_target_pitch_deg = lerpf(pitch_at_min_zoom, pitch_at_max_zoom, zoom_ratio)
	
	# Плавно интерполируем rotation.x SpringArm3D
	var current_pitch = rad_to_deg(_spring_arm.rotation.x)
	var new_pitch = lerpf(current_pitch, _target_pitch_deg, delta * pitch_smoothness)
	_spring_arm.rotation.x = deg_to_rad(new_pitch)

# ========== ЗАЩИТА ВЫСОТЫ ПИВОТА (ЧЕРЕЗ NOISE) ==========

func _handle_terrain_height(delta: float) -> void:
	if not _world_generator:
		# Фоллбэк без генератора: жёсткое ограничение
		position.y = maxf(position.y, 5.0)
		return
	
	# Запрашиваем высоту ландшафта напрямую у FastNoiseLite (без физики!)
	var terrain_y = _world_generator.get_height_at_pos(position.x, position.z)
	var target_y = terrain_y + min_height_above_terrain
	
	# Поднимаем пивот только если он ниже минимума (не мешаем если выше)
	if position.y < target_y:
		position.y = lerpf(position.y, target_y, delta * height_smoothness)

# ========== УТИЛИТЫ ==========

func get_focus_point() -> Vector3:
	if not _camera:
		return Vector3.ZERO
	
	var space_state = get_world_3d().direct_space_state
	var center = get_viewport().get_visible_rect().size / 2.0
	var origin = _camera.project_ray_origin(center)
	var normal = _camera.project_ray_normal(center)
	var end = origin + normal * 1000.0
	
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	var result = space_state.intersect_ray(query)
	
	if result:
		return result.position
	
	# Фоллбэк: пересечение с плоскостью Y=0
	if normal.y != 0:
		var t = -origin.y / normal.y
		return origin + normal * t
	return Vector3.ZERO

func get_camera_3d() -> Camera3D:
	return _camera
