extends Node

const SAVE_PATH = "user://settings.cfg"
var config = ConfigFile.new()

# Все настройки в одном месте (God Tier структура)
var settings = {
	"game": {
		"language": "en",
		"ui_scale": 1,
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
		"display_mode": 0, # 0 - Оконный, 1 - Полноэкранный
		"resolution": 0,   # Индекс в списке разрешений
		"bloom": true,
		"brightness": 1.0
	}
}

func _ready():
	load_settings()

func apply_settings():
	# --- 1. ПРИМЕНЕНИЕ ИГРОВЫХ НАСТРОЕК ---
	TranslationServer.set_locale(settings["game"]["language"])
	
	var scales = [1.0, 1.25, 1.5]
	var scale_idx = settings["game"]["ui_scale"]
	if scale_idx >= 0 and scale_idx < scales.size():
		get_window().content_scale_factor = scales[scale_idx]

	# --- 2. ПРИМЕНЕНИЕ ЗВУКА ---
	for bus_name in settings["audio"].keys():
		var bus_idx = AudioServer.get_bus_index(bus_name.capitalize())
		if bus_idx != -1:
			var volume_linear = settings["audio"][bus_name]
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(volume_linear))
			AudioServer.set_bus_mute(bus_idx, volume_linear <= 0.001)

	# --- 3. ПРИМЕНЕНИЕ ГРАФИКИ ---
	if settings["graphics"]["display_mode"] == 1:
		# Полноэкранный режим
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		# Оконный режим
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		
		# Применяем разрешение окна (массив должен совпадать с тем, что в settings_menu.gd)
		var resolutions = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
		var res_idx = settings["graphics"]["resolution"]
		if res_idx >= 0 and res_idx < resolutions.size():
			var res = resolutions[res_idx]
			DisplayServer.window_set_size(res)
			
			# Центрируем окно, чтобы оно не уезжало за границы экрана
			var screen_size = DisplayServer.screen_get_size()
			if res.x < screen_size.x and res.y < screen_size.y:
				var window_pos = (screen_size - res) / 2
				DisplayServer.window_set_position(window_pos)
		
	# Блум и Яркость обычно управляются через узел WorldEnvironment в игровых сценах.
	# Наш менеджер просто хранит эти переменные, а сцены будут брать их отсюда.

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
					settings[section][key] = config.get_value(section, key, settings[section][key])
	apply_settings()
