extends Control

# Флаг загрузки
var _loading_ui := false

# ========== УЗЛЫ UI (ЧЕРЕЗ SCENE UNIQUE NAMES) ==========
# Для подключения этих узлов в редакторе нажми на узел ПКМ -> "Access as Unique Name" (Уникальное имя)

# Game
@onready var language_button: OptionButton = %LanguageButton
@onready var scale_button: OptionButton = %ScaleButton
@onready var subtitles_check: CheckBox = %SubtitlesCheck

# Audio
@onready var master_slider: HSlider = %MasterSlider
@onready var master_pct: Label = %MasterPct
@onready var music_slider: HSlider = %MusicSlider
@onready var music_pct: Label = %MusicPct
@onready var sfx_slider: HSlider = %SfxSlider
@onready var sfx_pct: Label = %SfxPct
@onready var voice_slider: HSlider = %VoiceSlider
@onready var voice_pct: Label = %VoicePct
@onready var ui_slider: HSlider = %UiSlider
@onready var ui_pct: Label = %UiPct

# Graphics
@onready var resolution_button: OptionButton = %ResolutionButton
@onready var display_mode_button: OptionButton = %DisplayModeButton
@onready var vsync_button: OptionButton = %VsyncButton
@onready var max_fps_button: OptionButton = %MaxFpsButton
@onready var msaa_button: OptionButton = %MsaaButton
@onready var fxaa_check: CheckBox = %FxaaCheck
@onready var taa_check: CheckBox = %TaaCheck
@onready var shadow_quality_button: OptionButton = %ShadowQualityButton
@onready var bloom_check: CheckBox = %BloomCheck
@onready var ssao_check: CheckBox = %SsaoCheck
@onready var ssr_check: CheckBox = %SsrCheck

@onready var render_scale_slider: HSlider = %RenderScaleSlider
@onready var render_scale_pct: Label = %RenderScalePct

@onready var fsr_sharpness_slider: HSlider = %FsrSharpnessSlider
@onready var fsr_sharpness_pct: Label = %FsrSharpnessPct

@onready var brightness_slider: HSlider = %BrightnessSlider
@onready var brightness_pct: Label = %BrightnessPct

# Controls (Remapping)
@onready var controls_grid: GridContainer = %ControlsGrid

@onready var back_button: Button = %BackButton

# Remapping State
var is_remapping := false
var action_to_remap := ""
var button_to_remap: Button = null

func _ready() -> void:
	_load_values_into_ui()
	_connect_signals()
	_setup_controls_tab()
	
	if back_button:
		back_button.grab_focus()

# ═══════════════════════════════════════════════════════════════
#  УПРАВЛЕНИЕ (REMAPPING)
# ═══════════════════════════════════════════════════════════════

func _setup_controls_tab():
	# Очищаем дефолтные узлы в сетке
	for child in controls_grid.get_children():
		child.queue_free()
		
	var actions = [
		{"action": "camera_pan_up", "label": "KEY_CONTROLS_MOVE_UP"},
		{"action": "camera_pan_down", "label": "KEY_CONTROLS_MOVE_DOWN"},
		{"action": "camera_pan_left", "label": "KEY_CONTROLS_MOVE_LEFT"},
		{"action": "camera_pan_right", "label": "KEY_CONTROLS_MOVE_RIGHT"},
		{"action": "camera_rotate_left", "label": "KEY_CONTROLS_ROTATE_LEFT"},
		{"action": "camera_rotate_right", "label": "KEY_CONTROLS_ROTATE_RIGHT"},
		{"action": "ui_accept", "label": "KEY_CONTROLS_PLACE"},
		{"action": "ui_pause", "label": "KEY_CONTROLS_PAUSE"}
	]
	
	for item in actions:
		var lbl = Label.new()
		lbl.text = item["label"]
		lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		controls_grid.add_child(lbl)
		
		var btn = Button.new()
		btn.text = _get_action_string(item["action"])
		btn.custom_minimum_size = Vector2(200, 40)
		btn.pressed.connect(func(): _start_remap(item["action"], btn))
		controls_grid.add_child(btn)

func _get_action_string(action: String) -> String:
	var events = InputMap.action_get_events(action)
	if events.size() > 0:
		return events[0].as_text()
	return "Unassigned"

func _start_remap(action: String, btn: Button):
	is_remapping = true
	action_to_remap = action
	button_to_remap = btn
	btn.text = "Press any key..."
	btn.release_focus()

func _input(event: InputEvent) -> void:
	if is_remapping:
		# Блокируем клики по UI
		get_viewport().set_input_as_handled()
		
		# Фильтрация: ТОЛЬКО клавиатура и кнопки геймпада (никаких осей и мыши)
		if event is InputEventKey or event is InputEventJoypadButton:
			if event.is_pressed() and not event.is_echo():
				# Отмена при нажатии ESC (для клавы) или B/Circle (для пада - обычно index 1)
				if (event is InputEventKey and event.keycode == KEY_ESCAPE) or \
				   (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B):
					is_remapping = false
					button_to_remap.text = _get_action_string(action_to_remap)
					return
					
				# Переназначаем клавишу
				InputMap.action_erase_events(action_to_remap)
				InputMap.action_add_event(action_to_remap, event)
				
				# Обновляем UI и сохраняем
				is_remapping = false
				button_to_remap.text = _get_action_string(action_to_remap)
				SettingsManager.save_keybindings()
		return
	
	# Нормальная обработка ESC
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_pause"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()

# ═══════════════════════════════════════════════════════════════
#  ЗАПОЛНЕНИЕ ЗНАЧЕНИЙ
# ═══════════════════════════════════════════════════════════════

func _load_values_into_ui():
	_loading_ui = true
	var cfg = SettingsManager.settings
	
	# === ИГРА ===
	_populate_language_button()
	language_button.selected = 0 if cfg["game"]["language"] == "ru" else 1
	
	_populate_scale_button()
	scale_button.selected = clampi(cfg["game"]["ui_scale"], 0, SettingsManager.UI_SCALES.size() - 1)
	
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
	resolution_button.selected = clampi(cfg["graphics"]["resolution"], 0, SettingsManager.RESOLUTIONS.size() - 1)
	
	_populate_display_mode_button()
	display_mode_button.selected = clampi(cfg["graphics"]["display_mode"], 0, 2)
	
	_populate_vsync_button()
	vsync_button.selected = clampi(cfg["graphics"]["vsync"], 0, 2)
	
	_populate_max_fps_button()
	max_fps_button.selected = clampi(cfg["graphics"]["max_fps"], 0, SettingsManager.FPS_LIMITS.size() - 1)
	
	_populate_msaa_button()
	msaa_button.selected = clampi(cfg["graphics"]["msaa"], 0, 3)
	
	fxaa_check.button_pressed = cfg["graphics"]["fxaa"]
	taa_check.button_pressed = cfg["graphics"]["taa"]
	
	_populate_shadow_quality_button()
	shadow_quality_button.selected = clampi(cfg["graphics"]["shadow_quality"], 0, 4)
	
	bloom_check.button_pressed = cfg["graphics"]["bloom"]
	ssao_check.button_pressed = cfg["graphics"]["ssao"]
	ssr_check.button_pressed = cfg["graphics"]["ssr"]
	
	var rscale = cfg["graphics"].get("render_scale", 1.0)
	render_scale_slider.set_value_no_signal(rscale)
	_update_pct_label(render_scale_pct, rscale)
	
	var fsharp = cfg["graphics"].get("fsr_sharpness", 0.2)
	fsr_sharpness_slider.set_value_no_signal(fsharp)
	_update_pct_label(fsr_sharpness_pct, fsharp / 2.0) # От 0 до 2.0
	
	brightness_slider.set_value_no_signal(cfg["graphics"]["brightness"])
	_update_brightness_label(cfg["graphics"]["brightness"])
	
	_loading_ui = false

# ========== ПОПУЛЯЦИЯ ДРОПДАУНОВ ==========

func _populate_language_button():
	language_button.clear()
	language_button.add_item("Русский", 0)
	language_button.add_item("English", 1)

func _populate_scale_button():
	scale_button.clear()
	for i in SettingsManager.UI_SCALES.size():
		scale_button.add_item(str(int(SettingsManager.UI_SCALES[i] * 100)) + "%", i)

func _populate_resolution_button():
	resolution_button.clear()
	for i in SettingsManager.RESOLUTIONS.size():
		var res = SettingsManager.RESOLUTIONS[i]
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
	for i in SettingsManager.FPS_LIMITS.size():
		var fps = SettingsManager.FPS_LIMITS[i]
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
#  СИГНАЛЫ
# ═══════════════════════════════════════════════════════════════

func _connect_signals():
	language_button.item_selected.connect(_on_language_changed)
	scale_button.item_selected.connect(_on_scale_changed)
	subtitles_check.toggled.connect(_on_subtitles_toggled)
	
	master_slider.value_changed.connect(func(val): _on_audio_changed("master", val, master_pct))
	music_slider.value_changed.connect(func(val): _on_audio_changed("music", val, music_pct))
	sfx_slider.value_changed.connect(func(val): _on_audio_changed("sfx", val, sfx_pct))
	voice_slider.value_changed.connect(func(val): _on_audio_changed("voice", val, voice_pct))
	ui_slider.value_changed.connect(func(val): _on_audio_changed("ui", val, ui_pct))
	
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
	
	render_scale_slider.value_changed.connect(_on_render_scale_changed)
	fsr_sharpness_slider.value_changed.connect(_on_fsr_sharpness_changed)
	brightness_slider.value_changed.connect(_on_brightness_changed)
	
	back_button.pressed.connect(_on_back_pressed)

# --- ИГРА ---
func _on_language_changed(idx: int):
	if _loading_ui: return
	SettingsManager.settings["game"]["language"] = "ru" if idx == 0 else "en"
	SettingsManager.apply_settings()

func _on_scale_changed(idx: int):
	if _loading_ui: return
	SettingsManager.settings["game"]["ui_scale"] = idx
	SettingsManager.apply_settings()
	_load_values_into_ui()

func _on_subtitles_toggled(toggled: bool):
	if _loading_ui: return
	SettingsManager.settings["game"]["subtitles"] = toggled

# --- ЗВУК ---
func _on_audio_changed(bus_key: String, value: float, pct_label: Label):
	if _loading_ui: return
	SettingsManager.settings["audio"][bus_key] = value
	_update_pct_label(pct_label, value)
	SettingsManager.apply_settings()

# --- ГРАФИКА ---
func _on_resolution_changed(idx: int):
	if _loading_ui: return
	SettingsManager.settings["graphics"]["resolution"] = idx
	SettingsManager.apply_settings()
	_load_values_into_ui()

func _on_display_mode_changed(idx: int):
	if _loading_ui: return
	SettingsManager.settings["graphics"]["display_mode"] = idx
	SettingsManager.apply_settings()
	_load_values_into_ui()

func _on_vsync_changed(idx: int):
	if _loading_ui: return
	SettingsManager.settings["graphics"]["vsync"] = idx
	SettingsManager.apply_settings()

func _on_max_fps_changed(idx: int):
	if _loading_ui: return
	SettingsManager.settings["graphics"]["max_fps"] = idx
	SettingsManager.apply_settings()

func _on_msaa_changed(idx: int):
	if _loading_ui: return
	SettingsManager.settings["graphics"]["msaa"] = idx
	SettingsManager.apply_settings()

func _on_fxaa_toggled(toggled: bool):
	if _loading_ui: return
	SettingsManager.settings["graphics"]["fxaa"] = toggled
	SettingsManager.apply_settings()

func _on_taa_toggled(toggled: bool):
	if _loading_ui: return
	SettingsManager.settings["graphics"]["taa"] = toggled
	SettingsManager.apply_settings()

func _on_shadow_quality_changed(idx: int):
	if _loading_ui: return
	SettingsManager.settings["graphics"]["shadow_quality"] = idx
	SettingsManager.apply_settings()

func _on_bloom_toggled(toggled: bool):
	if _loading_ui: return
	SettingsManager.settings["graphics"]["bloom"] = toggled
	SettingsManager.apply_settings()

func _on_ssao_toggled(toggled: bool):
	if _loading_ui: return
	SettingsManager.settings["graphics"]["ssao"] = toggled
	SettingsManager.apply_settings()

func _on_ssr_toggled(toggled: bool):
	if _loading_ui: return
	SettingsManager.settings["graphics"]["ssr"] = toggled
	SettingsManager.apply_settings()

func _on_render_scale_changed(val: float):
	if _loading_ui: return
	SettingsManager.settings["graphics"]["render_scale"] = val
	_update_pct_label(render_scale_pct, val)
	SettingsManager.apply_settings()

func _on_fsr_sharpness_changed(val: float):
	if _loading_ui: return
	SettingsManager.settings["graphics"]["fsr_sharpness"] = val
	_update_pct_label(fsr_sharpness_pct, val / 2.0)
	SettingsManager.apply_settings()

func _on_brightness_changed(val: float):
	if _loading_ui: return
	SettingsManager.settings["graphics"]["brightness"] = val
	_update_brightness_label(val)
	SettingsManager.apply_settings()

# --- ЗАКРЫТИЕ ---
func _on_back_pressed():
	SettingsManager.save_settings()
	queue_free()

# ═══════════════════════════════════════════════════════════════
#  УТИЛИТЫ
# ═══════════════════════════════════════════════════════════════

func _update_pct_label(label: Label, value: float):
	label.text = str(int(value * 100)) + "%"

func _update_brightness_label(value: float):
	brightness_pct.text = str(int(value * 100)) + "%"
