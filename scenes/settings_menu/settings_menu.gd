extends Control

# ═══════════════════════════════════════════════════════════════
# МЕНЮ НАСТРОЕК — Полный rebuild с динамическим UI
# Исправлены баги слайдеров, добавлены god-tier настройки
# ═══════════════════════════════════════════════════════════════

# Флаг загрузки — блокирует обработку сигналов при программной установке значений.
# Это ПОЛНОСТЬЮ решает баг, когда слайдеры громкости/яркости менялись
# при изменении разрешения или масштабирования.
var _loading_ui := false

# ========== ССЫЛКИ НА UI ЭЛЕМЕНТЫ ==========
# Game
var language_button: OptionButton
var scale_button: OptionButton
var subtitles_check: CheckBox

# Audio (слайдер + лейбл процентов)
var master_slider: HSlider
var music_slider: HSlider
var sfx_slider: HSlider
var voice_slider: HSlider
var ui_slider: HSlider
var master_pct: Label
var music_pct: Label
var sfx_pct: Label
var voice_pct: Label
var ui_pct: Label

# Graphics
var resolution_button: OptionButton
var display_mode_button: OptionButton
var vsync_button: OptionButton
var max_fps_button: OptionButton
var msaa_button: OptionButton
var fxaa_check: CheckBox
var taa_check: CheckBox
var shadow_quality_button: OptionButton
var bloom_check: CheckBox
var ssao_check: CheckBox
var ssr_check: CheckBox
var brightness_slider: HSlider
var brightness_pct: Label

var back_button: Button

func _ready() -> void:
	_build_ui()
	_load_values_into_ui()
	_connect_signals()

# ═══════════════════════════════════════════════════════════════
#  ПОСТРОЕНИЕ UI
# ═══════════════════════════════════════════════════════════════

func _build_ui():
	# Полупрозрачный тёмный оверлей на фон
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	
	# Центральная панель настроек
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(750, 550)
	center.add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	
	# Заголовок
	var title = Label.new()
	title.text = "KEY_SETTINGS_TITLE"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("#00d4ff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Разделитель
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	# TabContainer
	var tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(tab_container)
	
	# === ВКЛАДКА: ИГРА ===
	var game_tab = _create_tab_content()
	game_tab.name = "Game" # Localization key
	tab_container.add_child(game_tab)
	var game_vbox = game_tab.get_child(0).get_child(0) # ScrollContainer → VBoxContainer
	
	language_button = _add_option_row(game_vbox, "KEY_LANGUAGE")
	scale_button = _add_option_row(game_vbox, "KEY_UI_SCALE")
	subtitles_check = _add_check_row(game_vbox, "KEY_SUBTITLES")
	
	# === ВКЛАДКА: ЗВУК ===
	var audio_tab = _create_tab_content()
	audio_tab.name = "Audio"
	tab_container.add_child(audio_tab)
	var audio_vbox = audio_tab.get_child(0).get_child(0)
	
	var master_row = _add_slider_row(audio_vbox, "KEY_AUDIO_MASTER", 0.0, 1.0, 0.05)
	master_slider = master_row[0]
	master_pct = master_row[1]
	
	var music_row = _add_slider_row(audio_vbox, "KEY_AUDIO_MUSIC", 0.0, 1.0, 0.05)
	music_slider = music_row[0]
	music_pct = music_row[1]
	
	var sfx_row = _add_slider_row(audio_vbox, "KEY_AUDIO_SFX", 0.0, 1.0, 0.05)
	sfx_slider = sfx_row[0]
	sfx_pct = sfx_row[1]
	
	var voice_row = _add_slider_row(audio_vbox, "KEY_AUDIO_VOICE", 0.0, 1.0, 0.05)
	voice_slider = voice_row[0]
	voice_pct = voice_row[1]
	
	var ui_row = _add_slider_row(audio_vbox, "KEY_AUDIO_UI", 0.0, 1.0, 0.05)
	ui_slider = ui_row[0]
	ui_pct = ui_row[1]
	
	# === ВКЛАДКА: ГРАФИКА ===
	var gfx_tab = _create_tab_content()
	gfx_tab.name = "Graphics"
	tab_container.add_child(gfx_tab)
	var gfx_vbox = gfx_tab.get_child(0).get_child(0)
	
	resolution_button = _add_option_row(gfx_vbox, "KEY_GRAPHICS_RESOLUTION")
	display_mode_button = _add_option_row(gfx_vbox, "KEY_GRAPHICS_DISPLAYMODE")
	vsync_button = _add_option_row(gfx_vbox, "KEY_VSYNC")
	max_fps_button = _add_option_row(gfx_vbox, "KEY_MAX_FPS")
	
	# Подзаголовок "Сглаживание"
	_add_section_label(gfx_vbox, "KEY_AA_SECTION")
	msaa_button = _add_option_row(gfx_vbox, "KEY_MSAA")
	fxaa_check = _add_check_row(gfx_vbox, "KEY_FXAA")
	taa_check = _add_check_row(gfx_vbox, "KEY_TAA")
	
	# Подзаголовок "Качество"
	_add_section_label(gfx_vbox, "KEY_QUALITY_SECTION")
	shadow_quality_button = _add_option_row(gfx_vbox, "KEY_SHADOW_QUALITY")
	bloom_check = _add_check_row(gfx_vbox, "KEY_GRAPHICS_BLOOM")
	ssao_check = _add_check_row(gfx_vbox, "KEY_SSAO")
	ssr_check = _add_check_row(gfx_vbox, "KEY_SSR")
	
	var bright_row = _add_slider_row(gfx_vbox, "KEY_GRAPHICS_BRIGHTNESS", 0.5, 1.5, 0.05)
	brightness_slider = bright_row[0]
	brightness_pct = bright_row[1]
	
	# Активируем первую вкладку
	tab_container.current_tab = 0
	
	# Кнопка "Закрыть настройки"
	var button_row = HBoxContainer.new()
	vbox.add_child(button_row)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.add_child(spacer)
	
	back_button = Button.new()
	back_button.text = "KEY_SETTINGS_EXIT"
	back_button.custom_minimum_size = Vector2(200, 40)
	button_row.add_child(back_button)
	
	back_button.grab_focus()

# ========== ПОМОЩНИКИ СОЗДАНИЯ UI СТРОК ==========

func _create_tab_content() -> MarginContainer:
	"""Создаёт стандартную обёртку для содержимого вкладки: Margin → Scroll → VBox"""
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)
	
	return margin

func _add_option_row(parent: VBoxContainer, label_key: String) -> OptionButton:
	"""Строка: Label + OptionButton"""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	parent.add_child(hbox)
	
	var label = Label.new()
	label.text = label_key
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_stretch_ratio = 1.0
	hbox.add_child(label)
	
	var option = OptionButton.new()
	option.custom_minimum_size = Vector2(250, 0)
	option.size_flags_horizontal = Control.SIZE_SHRINK_END
	hbox.add_child(option)
	
	return option

func _add_slider_row(parent: VBoxContainer, label_key: String, 
	min_val: float, max_val: float, step_val: float) -> Array:
	"""Строка: Label + HSlider + Label (процент). Возвращает [slider, pct_label]"""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	parent.add_child(hbox)
	
	var label = Label.new()
	label.text = label_key
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_stretch_ratio = 1.0
	hbox.add_child(label)
	
	var slider = HSlider.new()
	slider.custom_minimum_size = Vector2(250, 24)
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step_val
	slider.value = max_val
	hbox.add_child(slider)
	
	var pct = Label.new()
	pct.text = "100%"
	pct.custom_minimum_size = Vector2(50, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.add_theme_color_override("font_color", Color("#00d4ff"))
	hbox.add_child(pct)
	
	return [slider, pct]

func _add_check_row(parent: VBoxContainer, label_key: String) -> CheckBox:
	"""Строка: Label + CheckBox"""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	parent.add_child(hbox)
	
	var label = Label.new()
	label.text = label_key
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_stretch_ratio = 1.0
	hbox.add_child(label)
	
	var check = CheckBox.new()
	check.size_flags_horizontal = Control.SIZE_SHRINK_END
	hbox.add_child(check)
	
	return check

func _add_section_label(parent: VBoxContainer, text_key: String):
	"""Подзаголовок секции внутри вкладки"""
	var sep = HSeparator.new()
	parent.add_child(sep)
	
	var label = Label.new()
	label.text = text_key
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("#7c3aed"))
	parent.add_child(label)

# ═══════════════════════════════════════════════════════════════
#  ЗАПОЛНЕНИЕ ЭЛЕМЕНТОВ ИЗ КОНФИГА
# ═══════════════════════════════════════════════════════════════

func _load_values_into_ui():
	_loading_ui = true
	var cfg = SaveManager.settings
	
	# === ИГРА ===
	_populate_language_button()
	language_button.selected = 0 if cfg["game"]["language"] == "ru" else 1
	
	_populate_scale_button()
	scale_button.selected = clampi(cfg["game"]["ui_scale"], 0, SaveManager.UI_SCALES.size() - 1)
	
	subtitles_check.button_pressed = cfg["game"]["subtitles"]
	
	# === ЗВУК ===
	master_slider.set_value_no_signal(cfg["audio"]["master"])
	music_slider.set_value_no_signal(cfg["audio"]["music"])
	sfx_slider.set_value_no_signal(cfg["audio"]["sfx"])
	voice_slider.set_value_no_signal(cfg["audio"]["voice"])
	ui_slider.set_value_no_signal(cfg["audio"]["ui"])
	
	_update_pct_label(master_pct, cfg["audio"]["master"])
	_update_pct_label(music_pct, cfg["audio"]["music"])
	_update_pct_label(sfx_pct, cfg["audio"]["sfx"])
	_update_pct_label(voice_pct, cfg["audio"]["voice"])
	_update_pct_label(ui_pct, cfg["audio"]["ui"])
	
	# === ГРАФИКА ===
	_populate_resolution_button()
	resolution_button.selected = clampi(cfg["graphics"]["resolution"], 0, SaveManager.RESOLUTIONS.size() - 1)
	
	_populate_display_mode_button()
	display_mode_button.selected = clampi(cfg["graphics"]["display_mode"], 0, 2)
	
	_populate_vsync_button()
	vsync_button.selected = clampi(cfg["graphics"]["vsync"], 0, 2)
	
	_populate_max_fps_button()
	max_fps_button.selected = clampi(cfg["graphics"]["max_fps"], 0, SaveManager.FPS_LIMITS.size() - 1)
	
	_populate_msaa_button()
	msaa_button.selected = clampi(cfg["graphics"]["msaa"], 0, 3)
	
	fxaa_check.button_pressed = cfg["graphics"]["fxaa"]
	taa_check.button_pressed = cfg["graphics"]["taa"]
	
	_populate_shadow_quality_button()
	shadow_quality_button.selected = clampi(cfg["graphics"]["shadow_quality"], 0, 4)
	
	bloom_check.button_pressed = cfg["graphics"]["bloom"]
	ssao_check.button_pressed = cfg["graphics"]["ssao"]
	ssr_check.button_pressed = cfg["graphics"]["ssr"]
	
	brightness_slider.set_value_no_signal(cfg["graphics"]["brightness"])
	_update_brightness_label(cfg["graphics"]["brightness"])
	
	# Готово — разрешаем обработку сигналов
	_loading_ui = false

# ========== ЗАПОЛНЕНИЕ DROPDOWN СПИСКОВ ==========

func _populate_language_button():
	language_button.clear()
	language_button.add_item("Русский", 0)
	language_button.add_item("English", 1)

func _populate_scale_button():
	scale_button.clear()
	for i in SaveManager.UI_SCALES.size():
		scale_button.add_item(str(int(SaveManager.UI_SCALES[i] * 100)) + "%", i)

func _populate_resolution_button():
	resolution_button.clear()
	for i in SaveManager.RESOLUTIONS.size():
		var res = SaveManager.RESOLUTIONS[i]
		resolution_button.add_item(str(res.x) + " × " + str(res.y), i)

func _populate_display_mode_button():
	display_mode_button.clear()
	display_mode_button.add_item("KEY_WINDOWED", 0)
	display_mode_button.add_item("KEY_FULLSCREEN", 1)
	display_mode_button.add_item("KEY_BORDERLESS", 2)

func _populate_vsync_button():
	vsync_button.clear()
	vsync_button.add_item("KEY_OFF", 0)
	vsync_button.add_item("KEY_ON", 1)
	vsync_button.add_item("KEY_ADAPTIVE", 2)

func _populate_max_fps_button():
	max_fps_button.clear()
	for i in SaveManager.FPS_LIMITS.size():
		var fps = SaveManager.FPS_LIMITS[i]
		if fps == 0:
			max_fps_button.add_item("KEY_UNLIMITED", i)
		else:
			max_fps_button.add_item(str(fps) + " FPS", i)

func _populate_msaa_button():
	msaa_button.clear()
	msaa_button.add_item("KEY_OFF", 0)
	msaa_button.add_item("2×", 1)
	msaa_button.add_item("4×", 2)
	msaa_button.add_item("8×", 3)

func _populate_shadow_quality_button():
	shadow_quality_button.clear()
	shadow_quality_button.add_item("KEY_OFF", 0)
	shadow_quality_button.add_item("KEY_LOW", 1)
	shadow_quality_button.add_item("KEY_MEDIUM", 2)
	shadow_quality_button.add_item("KEY_HIGH", 3)
	shadow_quality_button.add_item("KEY_ULTRA", 4)

# ═══════════════════════════════════════════════════════════════
#  ПОДКЛЮЧЕНИЕ СИГНАЛОВ
# ═══════════════════════════════════════════════════════════════

func _connect_signals():
	# === ИГРА ===
	language_button.item_selected.connect(_on_language_changed)
	scale_button.item_selected.connect(_on_scale_changed)
	subtitles_check.toggled.connect(_on_subtitles_toggled)
	
	# === ЗВУК ===
	master_slider.value_changed.connect(func(val): _on_audio_changed("master", val, master_pct))
	music_slider.value_changed.connect(func(val): _on_audio_changed("music", val, music_pct))
	sfx_slider.value_changed.connect(func(val): _on_audio_changed("sfx", val, sfx_pct))
	voice_slider.value_changed.connect(func(val): _on_audio_changed("voice", val, voice_pct))
	ui_slider.value_changed.connect(func(val): _on_audio_changed("ui", val, ui_pct))
	
	# === ГРАФИКА ===
	resolution_button.item_selected.connect(_on_resolution_changed)
	display_mode_button.item_selected.connect(_on_display_mode_changed)
	vsync_button.item_selected.connect(_on_vsync_changed)
	max_fps_button.item_selected.connect(_on_max_fps_changed)
	msaa_button.item_selected.connect(_on_msaa_changed)
	fxaa_check.toggled.connect(_on_fxaa_toggled)
	taa_check.toggled.connect(_on_taa_toggled)
	shadow_quality_button.item_selected.connect(_on_shadow_quality_changed)
	bloom_check.toggled.connect(_on_bloom_toggled)
	ssao_check.toggled.connect(_on_ssao_toggled)
	ssr_check.toggled.connect(_on_ssr_toggled)
	brightness_slider.value_changed.connect(_on_brightness_changed)
	
	# Кнопка закрытия
	back_button.pressed.connect(_on_back_pressed)

# ═══════════════════════════════════════════════════════════════
#  ОБРАБОТЧИКИ СИГНАЛОВ
# ═══════════════════════════════════════════════════════════════

# --- ИГРА ---
func _on_language_changed(idx: int):
	if _loading_ui: return
	SaveManager.settings["game"]["language"] = "ru" if idx == 0 else "en"
	SaveManager.apply_settings()

func _on_scale_changed(idx: int):
	if _loading_ui: return
	SaveManager.settings["game"]["ui_scale"] = idx
	# После смены масштаба перезагружаем значения UI, чтобы слайдеры не сбились
	SaveManager.apply_settings()
	_load_values_into_ui()

func _on_subtitles_toggled(toggled: bool):
	if _loading_ui: return
	SaveManager.settings["game"]["subtitles"] = toggled

# --- ЗВУК ---
func _on_audio_changed(bus_key: String, value: float, pct_label: Label):
	if _loading_ui: return
	SaveManager.settings["audio"][bus_key] = value
	_update_pct_label(pct_label, value)
	SaveManager.apply_settings()

# --- ГРАФИКА ---
func _on_resolution_changed(idx: int):
	if _loading_ui: return
	SaveManager.settings["graphics"]["resolution"] = idx
	SaveManager.apply_settings()
	_load_values_into_ui()

func _on_display_mode_changed(idx: int):
	if _loading_ui: return
	SaveManager.settings["graphics"]["display_mode"] = idx
	SaveManager.apply_settings()
	_load_values_into_ui()

func _on_vsync_changed(idx: int):
	if _loading_ui: return
	SaveManager.settings["graphics"]["vsync"] = idx
	SaveManager.apply_settings()

func _on_max_fps_changed(idx: int):
	if _loading_ui: return
	SaveManager.settings["graphics"]["max_fps"] = idx
	SaveManager.apply_settings()

func _on_msaa_changed(idx: int):
	if _loading_ui: return
	SaveManager.settings["graphics"]["msaa"] = idx
	SaveManager.apply_settings()

func _on_fxaa_toggled(toggled: bool):
	if _loading_ui: return
	SaveManager.settings["graphics"]["fxaa"] = toggled
	SaveManager.apply_settings()

func _on_taa_toggled(toggled: bool):
	if _loading_ui: return
	SaveManager.settings["graphics"]["taa"] = toggled
	SaveManager.apply_settings()

func _on_shadow_quality_changed(idx: int):
	if _loading_ui: return
	SaveManager.settings["graphics"]["shadow_quality"] = idx
	SaveManager.apply_settings()

func _on_bloom_toggled(toggled: bool):
	if _loading_ui: return
	SaveManager.settings["graphics"]["bloom"] = toggled
	SaveManager.apply_settings()

func _on_ssao_toggled(toggled: bool):
	if _loading_ui: return
	SaveManager.settings["graphics"]["ssao"] = toggled
	SaveManager.apply_settings()

func _on_ssr_toggled(toggled: bool):
	if _loading_ui: return
	SaveManager.settings["graphics"]["ssr"] = toggled
	SaveManager.apply_settings()

func _on_brightness_changed(val: float):
	if _loading_ui: return
	SaveManager.settings["graphics"]["brightness"] = val
	_update_brightness_label(val)
	SaveManager.apply_settings()

# --- ЗАКРЫТИЕ ---
func _on_back_pressed():
	SaveManager.save_settings()
	queue_free()

# ═══════════════════════════════════════════════════════════════
#  УТИЛИТЫ
# ═══════════════════════════════════════════════════════════════

func _update_pct_label(label: Label, value: float):
	label.text = str(int(value * 100)) + "%"

func _update_brightness_label(value: float):
	brightness_pct.text = str(int(value * 100)) + "%"

# Обработка ESC для закрытия настроек
func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
