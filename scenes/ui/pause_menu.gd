extends Control

# ═══════════════════════════════════════════════════════════════
# PAUSE MENU — Внутриигровое меню паузы
# Process Mode: PROCESS_MODE_ALWAYS (работает при get_tree().paused)
# ═══════════════════════════════════════════════════════════════

@onready var resume_btn: Button = %ResumeButton
@onready var settings_btn: Button = %SettingsButton
@onready var main_menu_btn: Button = %MainMenuButton
@onready var title_label: Label = %TitleLabel
@onready var buttons_container: VBoxContainer = %ButtonsContainer

var _settings_instance: Node = null
var _is_saving: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	resume_btn.pressed.connect(_on_resume)
	settings_btn.pressed.connect(_on_settings)
	main_menu_btn.pressed.connect(_on_main_menu)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _is_saving:
			return  # Не позволяем закрыть во время сохранения
		
		if _settings_instance and is_instance_valid(_settings_instance):
			# Если открыты настройки — закрываем их
			_settings_instance.queue_free()
			_settings_instance = null
			get_viewport().set_input_as_handled()
			return
		
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _toggle_pause() -> void:
	var is_paused = get_tree().paused
	if is_paused:
		_unpause()
	else:
		_pause()

func _pause() -> void:
	get_tree().paused = true
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _unpause() -> void:
	get_tree().paused = false
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)

# ========== КНОПКИ ==========

func _on_resume() -> void:
	_unpause()

func _on_settings() -> void:
	if _settings_instance and is_instance_valid(_settings_instance):
		return  # Настройки уже открыты
	
	var settings_scene = load("res://scenes/settings_menu/settings_menu.tscn")
	if settings_scene:
		_settings_instance = settings_scene.instantiate()
		_settings_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_settings_instance)

func _on_main_menu() -> void:
	if _is_saving:
		return
	
	# Асинхронное сохранение с UI-фидбеком
	if GameSaveSystem.current_slot_name != "":
		_start_saving()
	else:
		_exit_to_menu()

func _start_saving() -> void:
	_is_saving = true
	
	# Блокируем кнопки и показываем "Сохранение..."
	main_menu_btn.text = "KEY_SAVING"
	main_menu_btn.disabled = true
	resume_btn.disabled = true
	settings_btn.disabled = true
	
	# Подключаемся к сигналу завершения
	GameSaveSystem.save_completed.connect(_on_save_finished, CONNECT_ONE_SHOT)
	GameSaveSystem.save_game(GameSaveSystem.current_slot_name)

func _on_save_finished(success: bool, _slot_name: String) -> void:
	_is_saving = false
	
	if not success:
		push_warning("PauseMenu: Сохранение не удалось, но выходим в меню")
	
	_exit_to_menu()

func _exit_to_menu() -> void:
	GameSaveSystem.stop_autosave()
	PerformanceMonitor.stop_session()
	
	get_tree().paused = false
	SceneManager.goto_scene("res://scenes/main_menu/main_menu.tscn")
