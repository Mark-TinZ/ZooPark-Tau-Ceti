extends Node

# ═══════════════════════════════════════════════════════════════
# GAME SAVE SYSTEM — Управление игровыми сохранениями
# Autoload: множественные слоты, метаданные, автосохранение
# ═══════════════════════════════════════════════════════════════

const SAVES_DIR = "user://saves/"
const AUTOSAVE_INTERVAL_SEC = 600.0  # Автосохранение каждые 10 минут
const SAVE_VERSION = 1

# === Сигналы ===
signal save_completed(success: bool, slot_name: String)
signal load_completed(success: bool, data: Dictionary)

# === Текущее состояние мира (устанавливается перед загрузкой game.tscn) ===
var use_random_seed: bool = true
var current_seed: int = 0
var current_game_mode: int = 0       # 0 = Сюжет, 1 = Песочница
var current_capital: float = 50000.0
var current_slot_name: String = ""    # Имя текущего слота (для автосохранения)

var last_loaded_data: Dictionary = {}

# === Таймер автосохранения ===
var _autosave_timer: Timer
var _is_in_game: bool = false

func _ready() -> void:
	_ensure_saves_dir()
	
	# Создаём таймер автосохранения
	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = AUTOSAVE_INTERVAL_SEC
	_autosave_timer.one_shot = false
	_autosave_timer.timeout.connect(_on_autosave_timeout)
	add_child(_autosave_timer)

func _ensure_saves_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		DirAccess.make_dir_recursive_absolute(SAVES_DIR)

# ========== УПРАВЛЕНИЕ АВТОСОХРАНЕНИЕМ ==========

func start_autosave() -> void:
	_is_in_game = true
	_autosave_timer.start()

func stop_autosave() -> void:
	_is_in_game = false
	_autosave_timer.stop()

func _on_autosave_timeout() -> void:
	if _is_in_game and current_slot_name != "":
		save_game("autosave_" + current_slot_name)

# ========== СОХРАНЕНИЕ ==========

func save_game(slot_name: String) -> void:
	# Собираем данные из текущей сцены
	var game_node = get_tree().current_scene
	if not game_node:
		save_completed.emit(false, slot_name)
		return
		
	# Форсируем сохранение активных чанков в ChunkManager перед записью меты
	var world_gen: Node = game_node.get_node_or_null("WorldGenerator")
	if world_gen and world_gen.has_method("force_save_all_active_chunks"):
		world_gen.force_save_all_active_chunks()
		
	var save_data = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"unix_time": Time.get_unix_time_from_system(),
		"seed": current_seed,
		"use_random_seed": use_random_seed,
		"game_mode": current_game_mode,
		"capital": current_capital,
		"camera": _collect_camera_data(game_node),
		"play_time_seconds": 0,  # TODO: Считать время игры
	}
	
	# Запись в файл (в основном потоке — данные маленькие)
	var dir_path = SAVES_DIR + slot_name + "/"
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
		
	var file_path = dir_path + "meta.dat"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("GameSaveSystem: Не удалось открыть файл для записи: " + file_path)
		save_completed.emit(false, slot_name)
		return
	
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	
	current_slot_name = slot_name
	
	# Форсируем сброс чанков на диск
	if has_node("/root/ChunkManager"):
		get_node("/root/ChunkManager")._on_flush_timeout()
		
	save_completed.emit(true, slot_name)

func _collect_camera_data(game_node: Node) -> Dictionary:
	var camera_pivot = game_node.get_node_or_null("RTSCameraPivot")
	if camera_pivot and camera_pivot.has_method("get_camera_save_data"):
		return camera_pivot.get_camera_save_data()
	return {}
# Устаревшие методы _write_meta удалены, т.к. meta.dat содержит всё необходимое

# ========== ЗАГРУЗКА ==========

func load_game(slot_name: String) -> Dictionary:
	var file_path = SAVES_DIR + slot_name + "/meta.dat"
	
	if not FileAccess.file_exists(file_path):
		push_error("GameSaveSystem: Файл сохранения не найден: " + file_path)
		load_completed.emit(false, {})
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("GameSaveSystem: Не удалось открыть файл: " + file_path)
		load_completed.emit(false, {})
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var err = json.parse(json_text)
	if err != OK:
		push_error("GameSaveSystem: Ошибка парсинга JSON: " + json.get_error_message())
		load_completed.emit(false, {})
		return {}
	
	var data = json.data as Dictionary
	
	# Восстанавливаем текущее состояние
	current_seed = int(data.get("seed", 0))
	use_random_seed = data.get("use_random_seed", true)
	current_game_mode = int(data.get("game_mode", 0))
	current_capital = float(data.get("capital", 50000.0))
	current_slot_name = slot_name
	
	last_loaded_data = data
	
	if has_node("/root/ChunkManager"):
		get_node("/root/ChunkManager").start_manager(slot_name)
	
	load_completed.emit(true, data)
	return data

func apply_camera_data(game_node: Node, data: Dictionary) -> void:
	var cam_data = data.get("camera", {})
	if cam_data.is_empty():
		return
	
	var camera_pivot = game_node.get_node_or_null("RTSCameraPivot")
	if camera_pivot and camera_pivot.has_method("load_camera_save_data"):
		camera_pivot.load_camera_save_data(cam_data)

# ========== СПИСОК СОХРАНЕНИЙ ==========

func list_saves() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	
	var dir = DirAccess.open(SAVES_DIR)
	if not dir:
		return saves
	
	dir.list_dir_begin()
	var slot_dir = dir.get_next()
	while slot_dir != "":
		if dir.current_is_dir() and slot_dir != "." and slot_dir != "..":
			var meta_path = SAVES_DIR + slot_dir + "/meta.dat"
			if FileAccess.file_exists(meta_path):
				var meta = _read_meta(meta_path)
				if not meta.is_empty():
					meta["slot_name"] = slot_dir # Убедимся что имя слота совпадает с папкой
					saves.append(meta)
		slot_dir = dir.get_next()
	
	# Сортируем по дате (новые сверху)
	saves.sort_custom(func(a, b): return a.get("unix_time", 0) > b.get("unix_time", 0))
	return saves

func _read_meta(meta_path: String) -> Dictionary:
	var file = FileAccess.open(meta_path, FileAccess.READ)
	if not file:
		return {}
	
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	
	if err != OK:
		return {}
	return json.data as Dictionary

# ========== УДАЛЕНИЕ ==========

func delete_save(slot_name: String) -> void:
	var slot_dir = SAVES_DIR + slot_name
	_remove_dir_recursive(slot_dir)

func _remove_dir_recursive(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name != "." and file_name != "..":
				if dir.current_is_dir():
					_remove_dir_recursive(path + "/" + file_name)
				else:
					dir.remove(file_name)
			file_name = dir.get_next()
		DirAccess.remove_absolute(path)

# ========== УТИЛИТЫ ==========

func has_save(slot_name: String) -> bool:
	return FileAccess.file_exists(SAVES_DIR + slot_name + "/meta.dat")

func get_effective_seed() -> int:
	if use_random_seed:
		current_seed = randi()
		use_random_seed = false  # После генерации сид зафиксирован
	return current_seed
