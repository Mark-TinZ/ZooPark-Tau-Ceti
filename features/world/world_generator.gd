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
	
	# Получаем сид из GameSaveSystem (с флагом use_random_seed)
	noise.seed = GameSaveSystem.get_effective_seed()
	
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.005 # Плавные холмы
	
	terrain_material = StandardMaterial3D.new()
	terrain_material.albedo_color = Color(0.2, 0.4, 0.2) # Темно-зеленый цвет
	
	if not chunk_scene:
		chunk_scene = load("res://features/world/chunk.tscn")
		
	# Запуск профилирования и автосохранения
	PerformanceMonitor.start_session()
	GameSaveSystem.start_autosave()
		
	# Принудительная первая генерация вокруг стартовой точки
	_update_chunks(Vector2.ZERO)

func _process(_delta: float) -> void:
	# 1. Определение фокуса камеры и обновление сетки чанков
	if camera:
		var focus_pos = camera.get_focus_point()
		var p_chunk = Vector2(
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

func _update_chunks(center_chunk: Vector2) -> void:
	var required_chunks = {}
	for x in range(-view_distance, view_distance + 1):
		for y in range(-view_distance, view_distance + 1):
			var pos = center_chunk + Vector2(x, y)
			required_chunks[pos] = true
			
	# 1. Выгрузка чанков (прячем в пул), которые вышли за радиус
	var keys_to_remove = []
	for pos in active_chunks.keys():
		if not required_chunks.has(pos):
			var chunk = active_chunks[pos]
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
	var max_threads = max(1, OS.get_processor_count() - 1)
	
	while chunks_to_generate.size() > 0 and active_tasks.size() < max_threads:
		var pos = chunks_to_generate.pop_front()
		var task_id = WorkerThreadPool.add_task(_generate_chunk_thread.bind(pos), true)
		active_tasks[task_id] = pos

func _generate_chunk_thread(pos: Vector2) -> void:
	# Замер времени генерации
	var start_usec = Time.get_ticks_usec()
	
	var data = ChunkData.new()
	data.generate(pos, noise, chunk_size, vertex_spacing, height_multiplier)
	
	var elapsed_usec = Time.get_ticks_usec() - start_usec
	
	# Безопасно уведомляем главный поток через deferred call
	call_deferred("_on_chunk_generated", data, pos, elapsed_usec)

func _on_chunk_generated(data: ChunkData, pos: Vector2, elapsed_usec: float) -> void:
	# Отправляем метрику в профилировщик
	PerformanceMonitor.report_chunk_gen_time(elapsed_usec)
	
	# Очистка задачи
	var keys_to_remove = []
	for t_id in active_tasks.keys():
		if active_tasks[t_id] == pos:
			keys_to_remove.append(t_id)
			WorkerThreadPool.wait_for_task_completion(t_id) # Обязательная очистка handle'а потока
			
	for t_id in keys_to_remove:
		active_tasks.erase(t_id)
		
	ready_chunks_queue.append(data)

func _assemble_ready_chunks() -> void:
	var limit = 2 # Собираем не более 2 чанков за кадр
	var processed = 0
	
	while ready_chunks_queue.size() > 0 and processed < limit:
		var data = ready_chunks_queue.pop_front()
		
		# Если игрок уже убежал, пропускаем сборку
		var dist_x = abs(data.chunk_pos.x - current_player_chunk.x)
		var dist_y = abs(data.chunk_pos.y - current_player_chunk.y)
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
		
	var offset_x = data.chunk_pos.x * chunk_size * vertex_spacing
	var offset_z = data.chunk_pos.y * chunk_size * vertex_spacing
	chunk.global_position = Vector3(offset_x, 0, offset_z)
	
	# Передача данных вызовет безопасную пересборку ArrayMesh и коллизии внутри класса Chunk
	chunk.set_data(data, terrain_material)
	active_chunks[data.chunk_pos] = chunk

# ========== ЗАПРОС ВЫСОТЫ ЛАНДШАФТА (для камеры) ==========

func get_height_at_pos(world_x: float, world_z: float) -> float:
	# Запрашиваем высоту напрямую у FastNoiseLite (без физики!)
	# Это та же формула, что и в ChunkData.generate()
	return noise.get_noise_2d(world_x, world_z) * height_multiplier
