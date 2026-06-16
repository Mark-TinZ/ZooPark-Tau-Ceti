extends Control

@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar
@onready var tooltip_label: Label = $VBoxContainer/TooltipLabel
@onready var spinner: ColorRect = $VBoxContainer/CenterContainer/Spinner

var _target_path: String = ""
var _load_status: int = ResourceLoader.THREAD_LOAD_IN_PROGRESS
var _progress_array: Array = []

var _tooltips = [
	"Совет: Мутация травоядного с хищником в одном вольере приведет к быстрой, но кровавой смерти бюджета.",
	"Совет: TempleOS внимательно следит за вашими расходами. Не разочаровывайте ядро.",
	"Совет: Продажа экзотических видов на черном рынке повышает агрессивность инспекторов.",
	"Совет: Используйте систему климат-контроля, чтобы пингвины не растаяли на экваторе Кехет."
]

func _ready() -> void:
	_target_path = SceneManager.target_path
	if _target_path.is_empty():
		push_error("LoadingScreen: Нет target_path для загрузки.")
		return
		
	# Запуск фоновой загрузки
	ResourceLoader.load_threaded_request(_target_path)
	
	# Выбор случайного совета
	randomize()
	tooltip_label.text = _tooltips[randi() % _tooltips.size()]

func _process(delta: float) -> void:
	# Анимация спиннера
	spinner.rotation += delta * 3.0
	
	if _target_path.is_empty() or _load_status == ResourceLoader.THREAD_LOAD_LOADED:
		return
		
	_load_status = ResourceLoader.load_threaded_get_status(_target_path, _progress_array)
	
	if _progress_array.size() > 0:
		# Плавное заполнение (для красоты)
		progress_bar.value = lerp(progress_bar.value, float(_progress_array[0]), delta * 10.0)
		
	if _load_status == ResourceLoader.THREAD_LOAD_LOADED:
		progress_bar.value = 1.0
		set_process(false)
		
		var packed_scene = ResourceLoader.load_threaded_get(_target_path)
		# Делаем паузу для красивого эффекта загрузки 100%
		await get_tree().create_timer(0.5).timeout
		
		# SceneManager сам не может сделать change_scene_to_packed плавно, так как он
		# делает fade_out. Для асинхронной загрузки мы загрузили ресурс в память.
		# Вызовем fade из SceneManager, а смену сцены тут.
		SceneManager._fade_out()
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_packed(packed_scene)
		SceneManager._fade_in()
		
	elif _load_status == ResourceLoader.THREAD_LOAD_FAILED or _load_status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		push_error("Ошибка загрузки сцены: " + _target_path)
		set_process(false)
