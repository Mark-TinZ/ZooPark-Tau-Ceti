extends Node

const SAVE_PATH = "user://settings.cfg"
var config = ConfigFile.new()

# Дефолтные настройки
var settings = {
	"language": "en",
	"fullscreen": false,
	"volume": 0.8
}

func _ready():
	load_settings()

func apply_settings():
	# 1. Применяем язык
	TranslationServer.set_locale(settings["language"])
	
	# 2. Применяем полноэкранный режим
	if settings["fullscreen"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		
	# 3. Применяем громкость (для этого у нас должен быть настроен AudioServer, сделаем чуть позже)
	var bus_index = AudioServer.get_bus_index("Master")
	if bus_index != -1:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(settings["volume"]))

func save_settings():
	for key in settings.keys():
		config.set_value("video_audio", key, settings[key])
	config.save(SAVE_PATH)

func load_settings():
	var err = config.load(SAVE_PATH)
	if err == OK:
		for key in settings.keys():
			settings[key] = config.get_value("video_audio", key, settings[key])
	apply_settings()
