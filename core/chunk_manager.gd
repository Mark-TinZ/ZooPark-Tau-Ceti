extends Node

# ═══════════════════════════════════════════════════════════════
# CHUNK MANAGER — Управление стримингом и сохранением чанков
# Реализует Write-Back Cache и потокобезопасное сохранение
# ═══════════════════════════════════════════════════════════════

const CHUNKS_DIR = "user://saves/%s/chunks/"
const FLUSH_INTERVAL = 5.0 # seconds

var current_slot_name: String = ""
var _flush_timer: Timer
var _flush_thread: Thread
var _thread_semaphore: Semaphore = Semaphore.new()
var _mutex: Mutex = Mutex.new()

var _dirty_queue: Array[ChunkData] = []
var _exit_thread: bool = false

func _ready() -> void:
	_flush_thread = Thread.new()
	_flush_thread.start(_thread_func)
	
	_flush_timer = Timer.new()
	_flush_timer.wait_time = FLUSH_INTERVAL
	_flush_timer.timeout.connect(_on_flush_timeout)
	add_child(_flush_timer)

func start_manager(slot_name: String) -> void:
	current_slot_name = slot_name
	var dir_path = CHUNKS_DIR % slot_name
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	_flush_timer.start()

func stop_manager() -> void:
	_flush_timer.stop()
	# Принудительно сбрасываем всё, что осталось
	_on_flush_timeout()

func queue_chunk_for_save(chunk_data: ChunkData) -> void:
	if not chunk_data:
		return
		
	chunk_data.mutex.lock()
	if chunk_data.is_dirty:
		# Извлекаем копию данных и сбрасываем флаг, пока мы в мьютексе чанка
		var copy := ChunkData.new()
		copy.chunk_pos = chunk_data.chunk_pos
		copy.delta_data = chunk_data.delta_data.duplicate(true)
		chunk_data.is_dirty = false
		
		# Кладем в очередь потокобезопасно
		_mutex.lock()
		_dirty_queue.append(copy)
		_mutex.unlock()
	chunk_data.mutex.unlock()

func _on_flush_timeout() -> void:
	if current_slot_name == "":
		return
	# Будим фоновый поток
	_thread_semaphore.post()

func load_chunk_data(pos: Vector2) -> ChunkData:
	if current_slot_name == "":
		return null
		
	var file_path := (CHUNKS_DIR % current_slot_name) + "chunk_%d_%d.res" % [int(pos.x), int(pos.y)]
	if FileAccess.file_exists(file_path):
		# Пытаемся загрузить бинарный файл
		var res := ResourceLoader.load(file_path, "Resource") as ChunkData
		if res:
			res.chunk_pos = pos
			return res
	return null

func _thread_func() -> void:
	while true:
		_thread_semaphore.wait()
		if _exit_thread:
			break
			
		# Безопасно забираем очередь
		_mutex.lock()
		var queue_copy := _dirty_queue.duplicate()
		_dirty_queue.clear()
		_mutex.unlock()
		
		if queue_copy.size() == 0 or current_slot_name == "":
			continue
			
		var dir_path := CHUNKS_DIR % current_slot_name
		for chunk in queue_copy:
			var file_path := dir_path + "chunk_%d_%d.res" % [int(chunk.chunk_pos.x), int(chunk.chunk_pos.y)]
			
			# Мы сохраняем ТОЛЬКО delta_data, никаких мешей и коллизий
			var res_to_save := ChunkData.new()
			res_to_save.delta_data = chunk.delta_data
			
			var err := ResourceSaver.save(res_to_save, file_path, ResourceSaver.FLAG_COMPRESS)
			if err != OK:
				push_error("ChunkManager: Ошибка сохранения чанка %s" % file_path)

func _exit_tree() -> void:
	_exit_thread = true
	_thread_semaphore.post()
	if _flush_thread.is_started():
		_flush_thread.wait_to_finish()
