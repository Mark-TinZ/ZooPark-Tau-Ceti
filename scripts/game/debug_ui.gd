extends PanelContainer

# ═══════════════════════════════════════════════════════════════
# DEBUG UI v2 — Расширенная телеметрия производительности
# Категории: Рендер, Память, Мир | Цветовая индикация | F4 снапшот
# ═══════════════════════════════════════════════════════════════

# === Узлы секции РЕНДЕР ===
@onready var fps_label: Label = %FPSLabel
@onready var draw_calls_label: Label = %DrawCallsLabel
@onready var polygons_label: Label = %PolygonsLabel
@onready var objects_label: Label = %ObjectsLabel

# === Узлы секции ПАМЯТЬ ===
@onready var memory_label: Label = %MemoryLabel

# === Узлы секции МИР ===
@onready var camera_pos_label: Label = %CameraPosLabel
@onready var chunk_label: Label = %ChunkLabel
@onready var seed_label: Label = %SeedLabel
@onready var chunk_gen_label: Label = %ChunkGenLabel

# === Ссылки на игровые узлы ===
var _camera: Node = null
var _generator: Node = null

# Цвета индикации
const COLOR_GOOD = Color(0, 1, 0.5)      # Зелёный
const COLOR_WARNING = Color(1, 0.8, 0)    # Жёлтый
const COLOR_DANGER = Color(1, 0.2, 0.2)   # Красный
const COLOR_DEFAULT = Color(0.88, 0.91, 0.96)  # Стандартный текст

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Отложенный поиск узлов (после полной инициализации сцены)
	await get_tree().process_frame
	_camera = get_node_or_null("/root/Game/RTSCameraPivot")
	_generator = get_node_or_null("/root/Game/WorldGenerator")

func _process(_delta: float) -> void:
	if not visible:
		return
	
	var metrics = PerformanceMonitor.get_metrics()
	
	_update_render_section(metrics)
	_update_memory_section(metrics)
	_update_world_section(metrics)

func _update_render_section(metrics: Dictionary) -> void:
	# FPS
	var fps = int(metrics["fps"])
	fps_label.text = "FPS: %d" % fps
	if fps >= 60:
		fps_label.add_theme_color_override("font_color", COLOR_GOOD)
	elif fps >= 30:
		fps_label.add_theme_color_override("font_color", COLOR_WARNING)
	else:
		fps_label.add_theme_color_override("font_color", COLOR_DANGER)
	
	# Draw Calls
	var draw_calls = int(metrics["draw_calls"])
	draw_calls_label.text = "Draw Calls: %d" % draw_calls
	if draw_calls > 2000:
		draw_calls_label.add_theme_color_override("font_color", COLOR_DANGER)
	elif draw_calls > 1000:
		draw_calls_label.add_theme_color_override("font_color", COLOR_WARNING)
	else:
		draw_calls_label.add_theme_color_override("font_color", COLOR_DEFAULT)
	
	# Полигоны
	var polys = int(metrics["primitives_in_frame"])
	polygons_label.text = "Полигоны: %s" % _format_number(polys)
	
	# Объекты
	var objects = int(metrics["objects_in_frame"])
	objects_label.text = "Объекты: %d" % objects

func _update_memory_section(metrics: Dictionary) -> void:
	var mem_mb = metrics["memory_static_mb"]
	memory_label.text = "RAM: %.1f MB" % mem_mb
	if mem_mb > 1024:
		memory_label.add_theme_color_override("font_color", COLOR_DANGER)
	elif mem_mb > 512:
		memory_label.add_theme_color_override("font_color", COLOR_WARNING)
	else:
		memory_label.add_theme_color_override("font_color", COLOR_DEFAULT)

func _update_world_section(metrics: Dictionary) -> void:
	# Позиция камеры
	var cam_pos = _camera.global_position if _camera else Vector3.ZERO
	camera_pos_label.text = "Камера: X:%.1f Y:%.1f Z:%.1f" % [cam_pos.x, cam_pos.y, cam_pos.z]
	
	# Текущий чанк
	var current_chunk = _generator.current_player_chunk if _generator else Vector2.ZERO
	var active_count = _generator.active_chunks.size() if _generator else 0
	chunk_label.text = "Чанк: %s (активных: %d)" % [str(current_chunk), active_count]
	
	# Сид
	seed_label.text = "Сид: %d" % GameSaveSystem.current_seed
	
	# Время генерации чанков
	var gen_avg = metrics["chunk_gen_avg_ms"]
	var gen_last = metrics["chunk_gen_last_ms"]
	chunk_gen_label.text = "Генерация: %.1f ms (среднее: %.1f ms)" % [gen_last, gen_avg]
	if gen_avg > 16.0:  # > 1 кадр при 60 FPS
		chunk_gen_label.add_theme_color_override("font_color", COLOR_DANGER)
	elif gen_avg > 8.0:
		chunk_gen_label.add_theme_color_override("font_color", COLOR_WARNING)
	else:
		chunk_gen_label.add_theme_color_override("font_color", COLOR_DEFAULT)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F3:
				visible = !visible
				get_viewport().set_input_as_handled()
			KEY_F4:
				PerformanceMonitor.take_snapshot()
				# Визуальный фидбек
				_flash_snapshot_indicator()
				get_viewport().set_input_as_handled()

func _flash_snapshot_indicator() -> void:
	# Кратковременное мигание для обратной связи
	var original_self_modulate = self_modulate
	self_modulate = Color(0, 1, 0.5, 1)
	var tween = create_tween()
	tween.tween_property(self, "self_modulate", original_self_modulate, 0.3)

func _format_number(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (n / 1000000.0)
	elif n >= 1000:
		return "%.1fK" % (n / 1000.0)
	return str(n)
