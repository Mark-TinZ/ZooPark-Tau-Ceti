extends MarginContainer

var saves_list_container: VBoxContainer
var creation_panel: VBoxContainer

func _ready() -> void:
	# Даем отступы
	add_theme_constant_override("margin_left", 20)
	add_theme_constant_override("margin_right", 20)
	add_theme_constant_override("margin_top", 20)
	add_theme_constant_override("margin_bottom", 20)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 20)
	add_child(main_vbox)
	
	_build_saves_ui(main_vbox)
	_build_creation_ui(main_vbox)
	
	# По умолчанию показываем список сохранений
	creation_panel.hide()
	
	_load_saves()

func _build_saves_ui(parent: Control) -> void:
	saves_list_container = VBoxContainer.new()
	saves_list_container.add_theme_constant_override("separation", 10)
	
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.add_child(saves_list_container)
	
	var create_btn = Button.new()
	create_btn.text = "Создать новый мир"
	create_btn.pressed.connect(_show_creation_panel)
	
	parent.add_child(scroll)
	parent.add_child(create_btn)

func _build_creation_ui(parent: Control) -> void:
	creation_panel = VBoxContainer.new()
	creation_panel.add_theme_constant_override("separation", 15)
	
	var title = Label.new()
	title.text = "Новая Экспедиция"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Выбор режима
	var mode_hbox = HBoxContainer.new()
	var mode_label = Label.new()
	mode_label.text = "Режим:"
	var mode_opt = OptionButton.new()
	mode_opt.add_item("Сюжетная линия (Сектор 1)")
	mode_opt.add_item("Свободная игра (Песочница)")
	mode_hbox.add_child(mode_label)
	mode_hbox.add_child(mode_opt)
	
	# Слайдер стартового капитала
	var capital_hbox = HBoxContainer.new()
	var capital_label = Label.new()
	capital_label.text = "Стартовый капитал:"
	var capital_slider = HSlider.new()
	capital_slider.custom_minimum_size = Vector2(200, 0)
	capital_slider.max_value = 100000
	capital_slider.step = 1000
	capital_slider.value = 50000
	var capital_val = Label.new()
	capital_val.text = str(capital_slider.value) + " ¤"
	capital_slider.value_changed.connect(func(v): capital_val.text = str(v) + " ¤")
	capital_hbox.add_child(capital_label)
	capital_hbox.add_child(capital_slider)
	capital_hbox.add_child(capital_val)
	
	# Кнопки
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 20)
	
	var back_btn = Button.new()
	back_btn.text = "Отмена"
	back_btn.pressed.connect(_hide_creation_panel)
	
	var start_btn = Button.new()
	start_btn.text = "Начать"
	start_btn.pressed.connect(_start_game)
	
	btn_hbox.add_child(back_btn)
	btn_hbox.add_child(start_btn)
	
	creation_panel.add_child(title)
	creation_panel.add_child(mode_hbox)
	creation_panel.add_child(capital_hbox)
	creation_panel.add_child(btn_hbox)
	
	parent.add_child(creation_panel)

func _load_saves() -> void:
	# Очистка старых данных
	for c in saves_list_container.get_children():
		c.queue_free()
		
	var dir = DirAccess.open("user://saves")
	if not dir:
		DirAccess.make_dir_absolute("user://saves")
		dir = DirAccess.open("user://saves")
		
	var has_saves = false
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with("_meta.tres"):
				_create_save_entry("user://saves/" + file_name)
				has_saves = true
			file_name = dir.get_next()
			
	if not has_saves:
		var lbl = Label.new()
		lbl.text = "Нет сохраненных экспедиций."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		saves_list_container.add_child(lbl)

func _create_save_entry(meta_path: String) -> void:
	# Здесь в будущем будет ResourceLoader.load(meta_path)
	# Пока симулируем чтение
	var save_name = meta_path.get_file().replace("_meta.tres", "")
	
	var btn = Button.new()
	btn.text = save_name + " (Сектор неизвестен)"
	# btn.icon = load("res://assets/ui/save_icon.png") # если есть иконка
	btn.pressed.connect(func(): _load_game(meta_path))
	saves_list_container.add_child(btn)

func _show_creation_panel() -> void:
	saves_list_container.get_parent().hide() # прячем scroll
	saves_list_container.get_parent().get_parent().get_child(1).hide() # прячем create btn
	creation_panel.show()

func _hide_creation_panel() -> void:
	creation_panel.hide()
	saves_list_container.get_parent().show()
	saves_list_container.get_parent().get_parent().get_child(1).show()

func _start_game() -> void:
	# Заглушка, грузим пустую сцену или просто лоадинг скрин
	SceneManager.load_scene_async("res://scenes/game/game.tscn") # TODO: создать саму сцену игры потом

func _load_game(_meta_path: String) -> void:
	# В будущем: чтение меты и передача пути к основному сохранению
	SceneManager.load_scene_async("res://scenes/game/game.tscn")
