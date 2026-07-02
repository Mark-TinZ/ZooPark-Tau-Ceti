extends MarginContainer

# ═══════════════════════════════════════════════════════════════
# WORLD CREATION MENU — Создание нового мира + Список сохранений
# С полем ввода сида и контролем параметров генерации
# ═══════════════════════════════════════════════════════════════

@onready var saves_list_container: VBoxContainer = %SavesListContainer
@onready var creation_panel: VBoxContainer = %CreationPanel
@onready var saves_scroll: ScrollContainer = %SavesScroll
@onready var create_btn: Button = %CreateButton

@onready var mode_opt: OptionButton = %ModeOption
@onready var capital_slider: HSlider = %CapitalSlider
@onready var capital_val: Label = %CapitalVal
@onready var seed_input: LineEdit = %SeedInput
@onready var random_seed_btn: Button = %RandomSeedButton
@onready var start_btn: Button = %StartButton
@onready var back_btn: Button = %BackButton

func _ready() -> void:
	create_btn.pressed.connect(_show_creation_panel)
	back_btn.pressed.connect(_hide_creation_panel)
	start_btn.pressed.connect(_start_game)
	capital_slider.value_changed.connect(_on_capital_changed)
	random_seed_btn.pressed.connect(_on_random_seed)
	
	creation_panel.hide()
	
	_load_saves()

func _on_capital_changed(v: float) -> void:
	capital_val.text = str(v) + " ¤"

func _on_random_seed() -> void:
	var random_val = randi()
	seed_input.text = str(random_val)

# ========== ЗАГРУЗКА СПИСКА СОХРАНЕНИЙ ==========

func _load_saves() -> void:
	# Очистка старых данных
	for c in saves_list_container.get_children():
		c.queue_free()
	
	var saves = GameSaveSystem.list_saves()
	
	if saves.is_empty():
		var lbl = Label.new()
		lbl.text = "KEY_NO_SAVES_FOUND"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		saves_list_container.add_child(lbl)
		return
	
	for meta in saves:
		_create_save_entry(meta)

func _create_save_entry(meta: Dictionary) -> void:
	var slot_name = meta.get("slot_name", "unknown")
	var timestamp = meta.get("timestamp", "?")
	var game_mode = meta.get("game_mode", 0)
	var world_seed = meta.get("seed", 0)
	
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var info_label = Label.new()
	info_label.text = "%s | %s | Сид: %d" % [slot_name, timestamp, world_seed]
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_label)
	
	var load_btn = Button.new()
	load_btn.text = "KEY_LOAD"
	load_btn.custom_minimum_size = Vector2(120, 0)
	load_btn.pressed.connect(func(): _load_game(slot_name))
	hbox.add_child(load_btn)
	
	var delete_btn = Button.new()
	delete_btn.text = "KEY_DELETE"
	delete_btn.custom_minimum_size = Vector2(100, 0)
	delete_btn.pressed.connect(func():
		GameSaveSystem.delete_save(slot_name)
		_load_saves()
	)
	hbox.add_child(delete_btn)
	
	saves_list_container.add_child(hbox)

# ========== ПАНЕЛЬ СОЗДАНИЯ ==========

func _show_creation_panel() -> void:
	saves_scroll.hide()
	create_btn.hide()
	creation_panel.show()

func _hide_creation_panel() -> void:
	creation_panel.hide()
	saves_scroll.show()
	create_btn.show()

# ========== СТАРТ ИГРЫ ==========

func _start_game() -> void:
	# Обработка сида: разделяем данные и флаг состояния
	var seed_text = seed_input.text.strip_edges()
	
	if seed_text.is_empty():
		# Пустое поле = случайный сид
		GameSaveSystem.use_random_seed = true
	else:
		GameSaveSystem.use_random_seed = false
		if seed_text.is_valid_int():
			GameSaveSystem.current_seed = seed_text.to_int()
		else:
			# Хешируем текстовый сид
			GameSaveSystem.current_seed = seed_text.hash()
	
	# Устанавливаем остальные параметры
	GameSaveSystem.current_game_mode = mode_opt.selected
	GameSaveSystem.current_capital = capital_slider.value
	
	# Генерируем имя слота из текущей даты
	var datetime = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	GameSaveSystem.current_slot_name = "world_" + datetime
	GameSaveSystem.last_loaded_data = {} # Clear loaded data when creating new game
	
	SceneManager.load_scene_async("res://scenes/game/game.tscn")

func _load_game(slot_name: String) -> void:
	GameSaveSystem.load_game(slot_name)
	SceneManager.load_scene_async("res://scenes/game/game.tscn")
