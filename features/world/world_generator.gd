class_name WorldGenerator
extends Node3D

# ═══════════════════════════════════════════════════════════════
# WORLD GENERATOR — Процедурная генерация мира по чанкам
# Многопоточная генерация + пул чанков + замер производительности
# ═══════════════════════════════════════════════════════════════

@export var chunk_scene: PackedScene
@export var view_distance: int = 3
@export var chunk_size: int = 32
@export var vertex_spacing: float = 1.0
@export var height_multiplier: float = 10.0

var noise: FastNoiseLite
var humidity_noise: FastNoiseLite
var world_seed: int

var active_chunks: Dictionary = {} # Vector2 -> Chunk
var inactive_chunks: Array[Chunk] = []

var chunks_to_generate: Array[Vector2] = []
var ready_chunks_queue: Array[ChunkData] = []
var active_tasks: Dictionary = {} # task_id -> Vector2

@export var camera: RTSCamera
var current_player_chunk: Vector2 = Vector2.INF

var terrain_material: StandardMaterial3D

func _ready() -> void:
	noise = FastNoiseLite.new()
	humidity_noise = FastNoiseLite.new()
	
	# Получаем сид из GameSaveSystem (с флагом use_random_seed)
	world_seed = GameSaveSystem.get_effective_seed()
	noise.seed = world_seed
	humidity_noise.seed = world_seed + 12345
	
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.005 # Плавные холмы
	
	humidity_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	humidity_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	humidity_noise.frequency = 0.005
	
	terrain_material = StandardMaterial3D.new()
	terrain_material.albedo_color = Color(0.2, 0.4, 0.2) # Темно-зеленый цвет
	
	if not chunk_scene:
		chunk_scene = load("res://features/world/chunk.tscn")
		
	# Запуск профилирования и автосохранения
	PerformanceMonitor.start_session()
	GameSaveSystem.start_autosave()
		
	# Принудительная первая генерация вокруг стартовой точки
	_update_chunks(Vector2.ZERO)
	
	# Подписываемся на изменение настроек графики для обновления теней
	if SettingsManager.environment_settings_changed.get_connections().is_empty():
		SettingsManager.environment_settings_changed.connect(_on_environment_settings_changed)
	else:
		if not SettingsManager.environment_settings_changed.is_connected(_on_environment_settings_changed):
			SettingsManager.environment_settings_changed.connect(_on_environment_settings_changed)

func _process(_delta: float) -> void:
	# 1. Определение фокуса камеры и обновление сетки чанков
	if camera:
		var focus_pos := camera.get_focus_point()
		var p_chunk := Vector2(
			floor(focus_pos.x / (chunk_size * vertex_spacing)),
			floor(focus_pos.z / (chunk_size * vertex_spacing))
		)
		if p_chunk != current_player_chunk:
			current_player_chunk = p_chunk
			_update_chunks(current_player_chunk)
			
	# 2. Отправка задач в фоновый поток
	_dispatch_tasks()
	
	# 3. Троттлинг сборки (чтобы избежать фризов, собираем по 1-2 чанка за кадр)
	_assemble_ready_chunks()
	
	# TODO (AI/Boids): В будущем, когда появятся толпы посетителей и животных, 
	# здесь (или в отдельном AIManager) нужно реализовать группировку запросов NavigationServer (Boids/Flow Fields)
	# и снизить частоту расчетов пути (Pathfinding) для оптимизации.

func _update_chunks(center_chunk: Vector2) -> void:
	var required_chunks: Dictionary = {}
	for x in range(-view_distance, view_distance + 1):
		for y in range(-view_distance, view_distance + 1):
			var pos := center_chunk + Vector2(x, y)
			required_chunks[pos] = true
			
	# 1. Выгрузка чанков (прячем в пул), которые вышли за радиус
	var keys_to_remove: Array = []
	for pos in active_chunks.keys():
		if not required_chunks.has(pos):
			var chunk: Chunk = active_chunks[pos]
			if chunk.chunk_data and has_node("/root/ChunkManager"):
				get_node("/root/ChunkManager").queue_chunk_for_save(chunk.chunk_data)
			chunk.hide_and_disable()
			inactive_chunks.append(chunk)
			keys_to_remove.append(pos)
			
	for pos in keys_to_remove:
		active_chunks.erase(pos)
		
	# 2. Добавление недостающих чанков в очередь
	for pos in required_chunks.keys():
		if not active_chunks.has(pos) and not chunks_to_generate.has(pos) and not _is_task_running(pos):
			chunks_to_generate.append(pos)

func _is_task_running(pos: Vector2) -> bool:
	for task_pos in active_tasks.values():
		if task_pos == pos:
			return true
	return false

func _dispatch_tasks() -> void:
	# Не перегружаем потоки - оставляем 1 ядро свободным
	var max_threads := maxi(1, OS.get_processor_count() - 1)
	
	while chunks_to_generate.size() > 0 and active_tasks.size() < max_threads:
		var pos: Vector2 = chunks_to_generate.pop_front()
		
		# Пытаемся загрузить дельту с диска перед генерацией
		var saved_delta: Dictionary = {}
		if has_node("/root/ChunkManager"):
			var saved_data: ChunkData = get_node("/root/ChunkManager").load_chunk_data(pos)
			if saved_data:
				saved_delta = saved_data.delta_data
				
		var task_id := WorkerThreadPool.add_task(_generate_chunk_thread.bind(pos, saved_delta), true)
		active_tasks[task_id] = pos

func _generate_chunk_thread(pos: Vector2, saved_delta: Dictionary) -> void:
	# Замер времени генерации
	var start_usec := Time.get_ticks_usec()
	
	var data := ChunkData.new()
	if not saved_delta.is_empty():
		data.delta_data = saved_delta
		
	data.generate(pos, noise, humidity_noise, world_seed, chunk_size, vertex_spacing, height_multiplier)
	
	var elapsed_usec := Time.get_ticks_usec() - start_usec
	
	# Безопасно уведомляем главный поток через deferred call
	call_deferred("_on_chunk_generated", data, pos, elapsed_usec)

func _on_chunk_generated(data: ChunkData, pos: Vector2, elapsed_usec: float) -> void:
	# Отправляем метрику в профилировщик
	PerformanceMonitor.report_chunk_gen_time(elapsed_usec)
	
	# Очистка задачи
	var keys_to_remove: Array = []
	for t_id in active_tasks.keys():
		if active_tasks[t_id] == pos:
			keys_to_remove.append(t_id)
			WorkerThreadPool.wait_for_task_completion(t_id) # Обязательная очистка handle'а потока
			
	for t_id in keys_to_remove:
		active_tasks.erase(t_id)
		
	ready_chunks_queue.append(data)

func _assemble_ready_chunks() -> void:
	var limit := 2 # Собираем не более 2 чанков за кадр
	var processed := 0
	
	while ready_chunks_queue.size() > 0 and processed < limit:
		var data: ChunkData = ready_chunks_queue.pop_front()
		
		# Если игрок уже убежал, пропускаем сборку
		var dist_x := absf(data.chunk_pos.x - current_player_chunk.x)
		var dist_y := absf(data.chunk_pos.y - current_player_chunk.y)
		if dist_x > view_distance or dist_y > view_distance:
			continue
			
		_instantiate_chunk(data)
		processed += 1

func _instantiate_chunk(data: ChunkData) -> void:
	var chunk: Chunk
	if inactive_chunks.size() > 0:
		chunk = inactive_chunks.pop_back()
	else:
		chunk = chunk_scene.instantiate() as Chunk
		add_child(chunk)
		
	var offset_x := data.chunk_pos.x * chunk_size * vertex_spacing
	var offset_z := data.chunk_pos.y * chunk_size * vertex_spacing
	chunk.global_position = Vector3(offset_x, 0, offset_z)
	
	# Передача данных вызовет безопасную пересборку ArrayMesh и коллизии внутри класса Chunk
	chunk.set_data(data, terrain_material)
	active_chunks[data.chunk_pos] = chunk
	
	# Применяем текущие настройки теней к новому чанку
	var shadow_quality: int = SettingsManager.settings["graphics"]["shadow_quality"]
	chunk.set_shadows_enabled(shadow_quality > 1)

# ========== ЗАПРОС ВЫСОТЫ ЛАНДШАФТА (для камеры) ==========

func get_height_at_pos(world_x: float, world_z: float) -> float:
	# Запрашиваем высоту напрямую у FastNoiseLite (без физики!)
	# Это та же формула, что и в ChunkData.generate()
	return noise.get_noise_2d(world_x, world_z) * height_multiplier

# ========== СОХРАНЕНИЕ ==========

func force_save_all_active_chunks() -> void:
	if has_node("/root/ChunkManager"):
		var manager: Node = get_node("/root/ChunkManager")
		for chunk in active_chunks.values():
			if is_instance_valid(chunk) and chunk.chunk_data:
				manager.queue_chunk_for_save(chunk.chunk_data)

# ========== ВЗАИМОДЕЙСТВИЕ СО ЗДАНИЯМИ ==========

func add_building_to_chunk(transform: Transform3D, building_type: String, enclosure_data: Enclosure = null) -> void:
	var global_pos := transform.origin
	var c_x := floorf(global_pos.x / (chunk_size * vertex_spacing))
	var c_z := floorf(global_pos.z / (chunk_size * vertex_spacing))
	var pos2d := Vector2(c_x, c_z)
	
	if active_chunks.has(pos2d):
		var chunk: Chunk = active_chunks[pos2d]
		if chunk.chunk_data:
			chunk.chunk_data.add_building_delta(building_type, transform)
			
			# Сразу спавним в мире, чтобы игрок видел
			var b_scene := load("res://features/buildings/building_basic.tscn") as PackedScene
			if b_scene:
				var b := ObjectPool.get_instance(b_scene) as Node3D
				chunk.add_child(b)
				b.add_to_group("buildings")
				b.global_transform = transform
				
				# Если передан Enclosure, привязываем его к скрипту building_node
				if enclosure_data and "enclosure_data" in b:
					b.enclosure_data = enclosure_data

func _on_environment_settings_changed() -> void:
	# 0=Off, 1=Low, 2=Medium, 3=High, 4=Ultra
	# Отключаем тени деревьев на Low и Medium
	var shadow_quality: int = SettingsManager.settings["graphics"]["shadow_quality"]
	var shadows_enabled := shadow_quality > 1
	
	for chunk in active_chunks.values():
		if is_instance_valid(chunk):
			chunk.set_shadows_enabled(shadows_enabled)

# ========== TERRAFORMING ==========
func apply_terraform(global_pos: Vector3, radius: float, target_height: float, operation: String = "flatten") -> void:
	var min_x = global_pos.x - radius
	var max_x = global_pos.x + radius
	var min_z = global_pos.z - radius
	var max_z = global_pos.z + radius
	
	var affected_chunks: Dictionary = {}
	var step = vertex_spacing
	
	var x = floor(min_x / step) * step
	while x <= max_x + step:
		var z = floor(min_z / step) * step
		while z <= max_z + step:
			var d_sq = (x - global_pos.x) * (x - global_pos.x) + (z - global_pos.z) * (z - global_pos.z)
			if d_sq <= radius * radius:
				var c_x = floor(x / (chunk_size * step))
				var c_z = floor(z / (chunk_size * step))
				
				var possible_chunks = [Vector2(c_x, c_z)]
				
				var is_edge_x = abs(x - c_x * chunk_size * step) < 0.01
				var is_edge_z = abs(z - c_z * chunk_size * step) < 0.01
				
				if is_edge_x: possible_chunks.append(Vector2(c_x - 1, c_z))
				if is_edge_z: possible_chunks.append(Vector2(c_x, c_z - 1))
				if is_edge_x and is_edge_z: possible_chunks.append(Vector2(c_x - 1, c_z - 1))
					
				for cp in possible_chunks:
					var local_x = int(round((x - cp.x * chunk_size * step) / step))
					var local_z = int(round((z - cp.y * chunk_size * step) / step))
					
					if active_chunks.has(cp):
						var chunk: Chunk = active_chunks[cp]
						if chunk.chunk_data:
							var final_height = target_height
							if operation == "raise":
								var key = "%d,%d" % [local_x, local_z]
								var current_h = chunk.chunk_data.delta_data.get("heights", {}).get(key, noise.get_noise_2d(x, z) * height_multiplier)
								final_height = current_h + target_height
							elif operation == "lower":
								var key = "%d,%d" % [local_x, local_z]
								var current_h = chunk.chunk_data.delta_data.get("heights", {}).get(key, noise.get_noise_2d(x, z) * height_multiplier)
								final_height = current_h - target_height
								
							chunk.chunk_data.set_height_delta(local_x, local_z, final_height)
							affected_chunks[chunk] = true
			z += step
		x += step

	for chunk in affected_chunks.keys():
		if is_instance_valid(chunk) and chunk.chunk_data:
			chunk.chunk_data.rebuild_mesh_only(noise, chunk_size, vertex_spacing, height_multiplier)
			chunk.update_mesh_and_collision()

