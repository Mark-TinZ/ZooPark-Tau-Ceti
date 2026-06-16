extends Node

# ═══════════════════════════════════════════════════════════════
# SCENE MANAGER — Оркестратор переходов
# Autoload: управляет плавными переходами и асинхронной загрузкой
# ═══════════════════════════════════════════════════════════════

var _transition_layer: CanvasLayer
var _color_rect: ColorRect
var target_path: String = "" # Используется экраном загрузки

func _ready() -> void:
	# Создаем CanvasLayer с максимальным Z-index, чтобы перекрывать весь UI
	_transition_layer = CanvasLayer.new()
	_transition_layer.layer = 128
	add_child(_transition_layer)
	
	_color_rect = ColorRect.new()
	_color_rect.color = Color.BLACK
	_color_rect.modulate.a = 0.0 # Полностью прозрачный
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transition_layer.add_child(_color_rect)

# Плавный переход к новой сцене
func goto_scene(path: String) -> void:
	_fade_out()
	await get_tree().create_timer(0.5).timeout # Ждем завершения фейда
	
	get_tree().change_scene_to_file(path)
	
	_fade_in()

# Запуск асинхронной загрузки тяжелой сцены
func load_scene_async(path: String) -> void:
	target_path = path
	goto_scene("res://scenes/loading/loading_screen.tscn")

# Плавное затемнение
func _fade_out() -> void:
	_color_rect.mouse_filter = Control.MOUSE_FILTER_STOP # Блокируем клики во время перехода
	var tween = create_tween()
	tween.tween_property(_color_rect, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# Плавное осветление
func _fade_in() -> void:
	var tween = create_tween()
	tween.tween_property(_color_rect, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func(): _color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE)
