extends Node

# ═══════════════════════════════════════════════════════════════
# PERFORMANCE MONITOR — Телеметрия производительности
# Autoload: сбор метрик из ядра Godot, CSV-логирование
# ═══════════════════════════════════════════════════════════════

const LOG_DIR = "user://logs/"
const BUFFER_FLUSH_INTERVAL = 600.0  # Сброс буфера на диск каждые 10 минут

# === Метрики генерации чанков ===
var chunk_gen_time_avg_usec: float = 0.0  # Экспоненциальное скользящее среднее (мкс)
var chunk_gen_time_last_usec: float = 0.0
var _chunk_gen_samples: int = 0
const EMA_ALPHA = 0.2  # Коэффициент сглаживания (0.2 = быстрая адаптация)

# === Буфер и файл ===
var _log_buffer: PackedStringArray = []
var _log_file_path: String = ""
var _flush_timer: Timer
var _session_active: bool = false

func _ready() -> void:
	_ensure_log_dir()
	
	_flush_timer = Timer.new()
	_flush_timer.wait_time = BUFFER_FLUSH_INTERVAL
	_flush_timer.one_shot = false
	_flush_timer.timeout.connect(_flush_buffer_to_disk)
	add_child(_flush_timer)

func _ensure_log_dir() -> void:
	if not DirAccess.dir_exists_absolute(LOG_DIR):
		DirAccess.make_dir_recursive_absolute(LOG_DIR)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_flush_buffer_to_disk()

# ========== СТАРТ/СТОП СЕССИИ ==========

func start_session() -> void:
	if _session_active:
		return
	
	var datetime = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	_log_file_path = LOG_DIR + "perf_log_" + datetime + ".csv"
	
	# Записываем заголовок CSV
	_log_buffer.append("timestamp,camera_x,camera_y,camera_z,seed,active_chunks,fps,memory_mb,polygons,draw_calls,objects_in_frame,chunk_gen_avg_ms")
	
	_session_active = true
	_flush_timer.start()

func stop_session() -> void:
	if not _session_active:
		return
	_flush_buffer_to_disk()
	_session_active = false
	_flush_timer.stop()

# ========== СБОР МЕТРИК ==========

func get_metrics() -> Dictionary:
	return {
		"fps": Engine.get_frames_per_second(),
		"frame_time_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"objects_in_frame": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"primitives_in_frame": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"memory_static_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
		"memory_static_mb": snapped(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.01),
		"vram_mb": snapped(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.01),
		"chunk_gen_avg_ms": snapped(chunk_gen_time_avg_usec / 1000.0, 0.01),
		"chunk_gen_last_ms": snapped(chunk_gen_time_last_usec / 1000.0, 0.01),
	}

# ========== ЗАМЕР ГЕНЕРАЦИИ ЧАНКОВ ==========

func report_chunk_gen_time(elapsed_usec: float) -> void:
	chunk_gen_time_last_usec = elapsed_usec
	_chunk_gen_samples += 1
	
	if _chunk_gen_samples == 1:
		chunk_gen_time_avg_usec = elapsed_usec
	else:
		# Экспоненциальное скользящее среднее
		chunk_gen_time_avg_usec = EMA_ALPHA * elapsed_usec + (1.0 - EMA_ALPHA) * chunk_gen_time_avg_usec

# ========== СНАПШОТЫ (F4) ==========

func take_snapshot() -> void:
	if not _session_active:
		start_session()
	
	var metrics = get_metrics()
	
	# Получаем данные камеры и мира
	var cam_pos = Vector3.ZERO
	var world_seed = 0
	var active_chunks = 0
	
	var game = get_tree().current_scene
	if game:
		var camera_pivot = game.get_node_or_null("RTSCameraPivot")
		if camera_pivot:
			cam_pos = camera_pivot.global_position
		
		var generator = game.get_node_or_null("WorldGenerator")
		if generator:
			active_chunks = generator.active_chunks.size()
	
	if is_instance_valid(GameSaveSystem):
		world_seed = GameSaveSystem.current_seed
	
	var timestamp = Time.get_unix_time_from_system()
	
	var line = "%f,%f,%f,%f,%d,%d,%d,%.2f,%d,%d,%d,%.2f" % [
		timestamp,
		cam_pos.x, cam_pos.y, cam_pos.z,
		world_seed,
		active_chunks,
		metrics["fps"],
		metrics["memory_static_mb"],
		int(metrics["primitives_in_frame"]),
		int(metrics["draw_calls"]),
		int(metrics["objects_in_frame"]),
		metrics["chunk_gen_avg_ms"],
	]
	
	_log_buffer.append(line)

# ========== СБРОС БУФЕРА НА ДИСК ==========

func _flush_buffer_to_disk() -> void:
	if _log_buffer.is_empty() or _log_file_path == "":
		return
	
	# Открываем файл на добавление (или создание)
	var file: FileAccess
	if FileAccess.file_exists(_log_file_path):
		file = FileAccess.open(_log_file_path, FileAccess.READ_WRITE)
		if file:
			file.seek_end()
	else:
		file = FileAccess.open(_log_file_path, FileAccess.WRITE)
	
	if not file:
		push_error("PerformanceMonitor: Не удалось открыть лог-файл: " + _log_file_path)
		return
	
	for line in _log_buffer:
		file.store_line(line)
	
	file.close()
	_log_buffer.clear()
