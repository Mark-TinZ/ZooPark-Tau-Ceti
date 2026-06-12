extends Control

# Ссылки на элементы UI (Используем уникальные имена или точные пути)
@onready var language_button: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Game/MarginContainer/VBoxContainer/HBoxContainer/LanguageButton
@onready var scale_button: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Game/MarginContainer/VBoxContainer/HBoxContainer2/ScaleButton
@onready var subtitles_check: CheckBox = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Game/MarginContainer/VBoxContainer/HBoxContainer3/SubtitlesCheck

@onready var master_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Audio/MarginContainer/VBoxContainer/HBoxContainer/MasterSlider
@onready var music_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Audio/MarginContainer/VBoxContainer/HBoxContainer2/MusicSlider
@onready var sfx_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Audio/MarginContainer/VBoxContainer/HBoxContainer3/SfxSlider
@onready var voice_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Audio/MarginContainer/VBoxContainer/HBoxContainer4/VoiceSlider
@onready var ui_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Audio/MarginContainer/VBoxContainer/HBoxContainer5/UISlider

@onready var resolution_button: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Graphics/MarginContainer/VBoxContainer/HBoxContainer/ResolutionButton
@onready var display_mode_button: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Graphics/MarginContainer/VBoxContainer/HBoxContainer2/DisplayModeButton
@onready var bloom_check: CheckBox = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Graphics/MarginContainer/VBoxContainer/HBoxContainer3/BloomCheck
@onready var brightness_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Graphics/MarginContainer/VBoxContainer/HBoxContainer4/BrightnessSlider

@onready var back_button: Button = $PanelContainer/MarginContainer/Button

# Массив поддерживаемых разрешений экрана (добавили 2K и 4K)
const RESOLUTIONS = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]

func _ready() -> void:
	setup_ui_elements()
	load_current_values_into_ui()
	connect_ui_signals()
	back_button.text = "KEY_SETTINGS_EXIT" # Применяем локализацию для кнопки выхода из настроек
	back_button.grab_focus() # Для управления стрелочками/геймпадом

func setup_ui_elements():
	# Настраиваем выпадающий список языков
	language_button.clear()
	language_button.add_item("Русский", 0)
	language_button.add_item("English", 1)
	
	# Настраиваем выпадающий список режимов экрана
	display_mode_button.clear()
	display_mode_button.add_item("KEY_WINDOWED", 0)
	display_mode_button.add_item("KEY_FULLSCREEN", 1)

	# Настраиваем масштабирование интерфейса
	scale_button.clear()
	scale_button.add_item("100%", 0)
	scale_button.add_item("125%", 1)
	scale_button.add_item("150%", 2)

	# Настраиваем разрешения
	resolution_button.clear()
	for res in RESOLUTIONS:
		resolution_button.add_item(str(res.x) + "x" + str(res.y))

func load_current_values_into_ui():
	var cfg = SaveManager.settings
	
	# === Вкладка ИГРА ===
	language_button.selected = 0 if cfg["game"]["language"] == "ru" else 1
	subtitles_check.button_pressed = cfg["game"]["subtitles"]
	scale_button.selected = cfg["game"]["ui_scale"]
	
	# === Вкладка ЗВУК ===
	# Используем set_value_no_signal, чтобы изменение значения из кода
	# не вызывало сигнал value_changed (предотвращает ложные срабатывания)
	master_slider.set_value_no_signal(cfg["audio"]["master"])
	music_slider.set_value_no_signal(cfg["audio"]["music"])
	sfx_slider.set_value_no_signal(cfg["audio"]["sfx"])
	voice_slider.set_value_no_signal(cfg["audio"]["voice"])
	ui_slider.set_value_no_signal(cfg["audio"]["ui"])
	
	# === Вкладка ГРАФИКА ===
	resolution_button.selected = cfg["graphics"]["resolution"]
	display_mode_button.selected = cfg["graphics"]["display_mode"]
	bloom_check.button_pressed = cfg["graphics"]["bloom"]
	brightness_slider.set_value_no_signal(cfg["graphics"]["brightness"])

func connect_ui_signals():
	# Подключаем изменения игровых настроек
	language_button.item_selected.connect(_on_language_selected)
	subtitles_check.toggled.connect(func(toggled): SaveManager.settings["game"]["subtitles"] = toggled)
	scale_button.item_selected.connect(func(idx): 
		SaveManager.settings["game"]["ui_scale"] = idx
		SaveManager.apply_settings()
	)
	
	# Подключаем звук (работает в реальном времени при перемещении ползунка)
	master_slider.value_changed.connect(func(val): _change_audio_val("master", val))
	music_slider.value_changed.connect(func(val): _change_audio_val("music", val))
	sfx_slider.value_changed.connect(func(val): _change_audio_val("sfx", val))
	voice_slider.value_changed.connect(func(val): _change_audio_val("voice", val))
	ui_slider.value_changed.connect(func(val): _change_audio_val("ui", val))
	
	# Подключаем графику
	resolution_button.item_selected.connect(func(idx):
		SaveManager.settings["graphics"]["resolution"] = idx
		SaveManager.apply_settings()
	)
	display_mode_button.item_selected.connect(func(idx): 
		SaveManager.settings["graphics"]["display_mode"] = idx
		SaveManager.apply_settings()
	)
	bloom_check.toggled.connect(func(toggled): SaveManager.settings["graphics"]["bloom"] = toggled)
	brightness_slider.value_changed.connect(func(val): SaveManager.settings["graphics"]["brightness"] = val)

	# Кнопка закрытия меню настроек
	back_button.pressed.connect(_on_back_pressed)

func _change_audio_val(bus_name: String, value: float):
	# Защита от ложных срабатываний: если значение не изменилось или отличается 
	# на микроскопическую долю из-за изменения размера окна, мы игнорируем это.
	# Это решает баг, когда громкость менялась сама при растягивании UI.
	if abs(SaveManager.settings["audio"][bus_name] - value) < 0.01:
		return 
		
	SaveManager.settings["audio"][bus_name] = value
	SaveManager.apply_settings()

func _on_language_selected(index: int):
	SaveManager.settings["game"]["language"] = "ru" if index == 0 else "en"
	SaveManager.apply_settings()

func _on_back_pressed():
	SaveManager.save_settings() # Жестко сохраняем всё на диск при выходе из меню
	queue_free() # Закрываем сцену настроек
