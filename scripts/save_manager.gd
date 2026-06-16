extends Node

const SAVE_PATH = "user://settings.cfg"
var config = ConfigFile.new()

# Сигнал для настроек, зависящих от WorldEnvironment (bloom, brightness, ssao, ssr)
# Игровые сцены должны подключаться к этому сигналу
signal environment_settings_changed

# Флаг предотвращения повторного применения настроек
var _applying := false

# Массив поддерживаемых разрешений (HD → 4K)
const RESOLUTIONS = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]

# Маппинг масштабов UI
const UI_SCALES = [1.0, 1.25, 1.5, 1.75, 2.0]

# Маппинг FPS лимитов (0 = без ограничений)
const FPS_LIMITS = [0, 30, 60, 120, 144, 240]

# Жёсткий маппинг имён настроек аудио → имена бассов в AudioServer
const AUDIO_BUS_MAP = {
	"master": "Master",
	"music": "Music",
	"sfx": "Sfx",
	"voice": "Voice",
	"ui": "Ui"
}

# === GOD TIER НАСТРОЙКИ ===
var settings = {
	"game": {
		"language": "en",
		"ui_scale": 0,        # Индекс в UI_SCALES (0=100%)
		"subtitles": true
	},
	"audio": {
		"master": 0.8,
		"music": 0.7,
		"sfx": 1.0,
		"voice": 0.9,
		"ui": 0.8
	},
	"graphics": {
		"display_mode": 0,    # 0=Оконный, 1=Полноэкранный, 2=Оконный без рамки
		"resolution": 2,      # Индекс в RESOLUTIONS (по умолчанию 1920x1080)
		"vsync": 1,           # 0=Off, 1=On, 2=Adaptive
		"max_fps": 0,         # Индекс в FPS_LIMITS (0=Unlimited)
		"msaa": 0,            # 0=Off, 1=2x, 2=4x, 3=8x
		"fxaa": false,
		"taa": false,
		"shadow_quality": 2,  # 0=Off, 1=Low, 2=Medium, 3=High, 4=Ultra
		"bloom": true,
		"brightness": 1.0,
		"ssao": false,
		"ssr": false
	}
}

func _ready():
	load_settings()

func apply_settings():
	if _applying:
		return
	_applying = true
	
	_apply_game_settings()
	_apply_audio_settings()
	_apply_graphics_settings()
	
	_applying = false

# ========== ИГРОВЫЕ НАСТРОЙКИ ==========
func _apply_game_settings():
	# Язык
	TranslationServer.set_locale(settings["game"]["language"])
	
	# Масштабирование UI
	var scale_idx = clampi(settings["game"]["ui_scale"], 0, UI_SCALES.size() - 1)
	get_window().content_scale_factor = UI_SCALES[scale_idx]

# ========== АУДИО ==========
func _apply_audio_settings():
	for setting_key in AUDIO_BUS_MAP.keys():
		var bus_name = AUDIO_BUS_MAP[setting_key]
		var bus_idx = AudioServer.get_bus_index(bus_name)
		if bus_idx != -1:
			var volume_linear: float = settings["audio"][setting_key]
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(volume_linear))
			AudioServer.set_bus_mute(bus_idx, volume_linear <= 0.001)

# ========== ГРАФИКА ==========
func _apply_graphics_settings():
	_apply_display_mode()
	_apply_vsync()
	_apply_fps_limit()
	_apply_antialiasing()
	_apply_shadow_quality()
	
	# Настройки, зависящие от WorldEnvironment, передаём через сигнал
	environment_settings_changed.emit()

func _apply_display_mode():
	var mode = settings["graphics"]["display_mode"]
	var res_idx = clampi(settings["graphics"]["resolution"], 0, RESOLUTIONS.size() - 1)
	var target_res = RESOLUTIONS[res_idx]
	
	match mode:
		0: # Оконный
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			# Устанавливаем размер окна
			DisplayServer.window_set_size(target_res)
			# Центрируем окно
			_center_window(target_res)
		
		1: # Полноэкранный (Exclusive)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		
		2: # Оконный без рамки (Borderless Windowed)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			var screen_size = DisplayServer.screen_get_size()
			DisplayServer.window_set_size(screen_size)
			DisplayServer.window_set_position(Vector2i.ZERO)

func _center_window(window_size: Vector2i):
	var screen_size = DisplayServer.screen_get_size()
	if window_size.x <= screen_size.x and window_size.y <= screen_size.y:
		var pos_x: int = (screen_size.x - window_size.x) / 2
		var pos_y: int = (screen_size.y - window_size.y) / 2
		DisplayServer.window_set_position(Vector2i(pos_x, pos_y))

func _apply_vsync():
	var vsync_mode = settings["graphics"]["vsync"]
	match vsync_mode:
		0: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		1: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		2: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ADAPTIVE)

func _apply_fps_limit():
	var fps_idx = clampi(settings["graphics"]["max_fps"], 0, FPS_LIMITS.size() - 1)
	Engine.max_fps = FPS_LIMITS[fps_idx]

func _apply_antialiasing():
	var viewport = get_viewport()
	if not viewport:
		return
	
	# MSAA 3D
	var msaa_val = settings["graphics"]["msaa"]
	match msaa_val:
		0: viewport.msaa_3d = Viewport.MSAA_DISABLED
		1: viewport.msaa_3d = Viewport.MSAA_2X
		2: viewport.msaa_3d = Viewport.MSAA_4X
		3: viewport.msaa_3d = Viewport.MSAA_8X
	
	# FXAA (Screen-Space AA)
	if settings["graphics"]["fxaa"]:
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	else:
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	
	# TAA
	viewport.use_taa = settings["graphics"]["taa"]

func _apply_shadow_quality():
	# Качество теней через RenderingServer
	var quality = settings["graphics"]["shadow_quality"]
	match quality:
		0: # Off
			RenderingServer.directional_shadow_atlas_set_size(512, false)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
		1: # Low
			RenderingServer.directional_shadow_atlas_set_size(1024, false)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW)
		2: # Medium
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
		3: # High
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
		4: # Ultra
			RenderingServer.directional_shadow_atlas_set_size(8192, true)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)

# ========== УТИЛИТЫ ДЛЯ ПОЛУЧЕНИЯ ТЕКУЩИХ ЗНАЧЕНИЙ ==========

func get_bloom_enabled() -> bool:
	return settings["graphics"]["bloom"]

func get_brightness() -> float:
	return settings["graphics"]["brightness"]

func get_ssao_enabled() -> bool:
	return settings["graphics"]["ssao"]

func get_ssr_enabled() -> bool:
	return settings["graphics"]["ssr"]

# ========== СОХРАНЕНИЕ / ЗАГРУЗКА ==========

func save_settings():
	for section in settings.keys():
		for key in settings[section].keys():
			config.set_value(section, key, settings[section][key])
	config.save(SAVE_PATH)

func load_settings():
	var err = config.load(SAVE_PATH)
	if err == OK:
		for section in settings.keys():
			if config.has_section(section):
				for key in settings[section].keys():
					var loaded_val = config.get_value(section, key, settings[section][key])
					# Проверка типа: если тип загруженного значения не совпадает
					# с типом по умолчанию, используем значение по умолчанию
					if typeof(loaded_val) == typeof(settings[section][key]):
						settings[section][key] = loaded_val
	apply_settings()
