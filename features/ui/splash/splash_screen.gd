extends Control

@onready var temple_os_text: RichTextLabel = $BootConsole/HolyCLog
@onready var godot_logo: VBoxContainer = $PresentationLayer/GameLogo

var _is_skipping = false

# Звуковые плееры
var beep_player: AudioStreamPlayer
var hdd_player: AudioStreamPlayer

# Массив строк, имитирующих загрузку TempleOS и компиляцию HolyC кода
var boot_logs: Array[String] = [
	"TempleOS V5.03 Kernel Initializing...",
	"Detected 64-bit AMD64 Processor | Cores: 8",
	"Allocating 512MB RAM for Adam Task...",
	"Mounting Drive C: (RedSea File System)... SUCCESS",
	"",
	"// --- COMPILING HOLYC KERNEL MODULE: sort.hc ---",
	"U0 BubbleSort(I64 *data, I64 size) {",
	"  I64 i, j, temp;",
	"  For (i = 0; i < size - 1; i++) {",
	"    For (j = 0; j < size - i - 1; j++) {",
	"      If (data[j] > data[j + 1]) {",
	"        temp = data[j];",
	"        data[j] = data[j + 1];",
	"        data[j + 1] = temp;",
	"      }",
	"    }",
	"  }",
	"}",
	"",
	"U0 Main() {",
	"  I64 i; I64 nums[5] = {64, 34, 25, 12, 22};",
	"  BubbleSort(nums, 5);",
	"  For (i = 0; i < 5; i++) DocPrint(\"%d \", nums[i]);",
	"}",
	"// --- COMPILATION SUCCESSFUL (0.0023s) ---",
	"",
	"Loading Compiler Core... OK",
	"Loading Font: Standard 8x8... OK",
	"Initing HolyC Graphics Environment...",
	"God's Oracle Online. Entropy Gathered.",
	"TEMPLEOS BOOT SEQUENCE COMPLETE. LAUNCHING USER SPACE..."
]

func _ready() -> void:
	temple_os_text.text = ""
	temple_os_text.visible = true
	godot_logo.visible = false
	godot_logo.modulate.a = 0.0
	
	_setup_audio()
	_play_sequence()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_skip()
	elif event is InputEventMouseButton and event.pressed:
		_skip()

func _skip() -> void:
	if _is_skipping:
		return
	_is_skipping = true
	SceneManager.goto_scene("res://features/ui/main_menu/main_menu.tscn")

func _setup_audio() -> void:
	# Бип BIOS
	beep_player = AudioStreamPlayer.new()
	beep_player.stream = _create_beep_wav()
	add_child(beep_player)
	
	# Треск жесткого диска
	hdd_player = AudioStreamPlayer.new()
	hdd_player.stream = _create_hdd_wav()
	add_child(hdd_player)

func _create_beep_wav() -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.stereo = false
	var length = int(44100 * 0.1) # 100ms
	var data = PackedByteArray()
	data.resize(length * 2)
	for i in range(length):
		var time = float(i) / 44100.0
		# 1000 Hz sine wave + немного гармоник для ретро-звучания
		var value = sin(time * 1000.0 * TAU) * 0.8 + sin(time * 2000.0 * TAU) * 0.2
		var int_val = int(value * 32767.0 * 0.15)
		data.encode_s16(i * 2, int_val)
	wav.data = data
	return wav

func _create_hdd_wav() -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.stereo = false
	var length = int(44100 * 0.03) # 30ms короткий треск
	var data = PackedByteArray()
	data.resize(length * 2)
	for i in range(length):
		# Белый шум
		var value = (randf() * 2.0 - 1.0)
		var int_val = int(value * 32767.0 * 0.05)
		data.encode_s16(i * 2, int_val)
	wav.data = data
	return wav

func _play_sequence() -> void:
	# Писк BIOS при старте
	beep_player.play()
	
	# 1. Построчный вывод логов загрузки
	for line in boot_logs:
		if _is_skipping: return
		
		# Экранируем скобки, чтобы предотвратить баги BBCode для кода вроде data[j]
		var processed_line = line.replace("[", "[lb]")
		
		# Подкрашиваем ключевые слова
		processed_line = processed_line.replace("SUCCESSFUL", "[color=#00ff00]SUCCESSFUL[/color]")
		processed_line = processed_line.replace("SUCCESS", "[color=#00ff00]SUCCESS[/color]")
		processed_line = processed_line.replace("OK", "[color=#00ff00]OK[/color]")
		processed_line = processed_line.replace("COMPILING", "[color=#ffff00]COMPILING[/color]")
		processed_line = processed_line.replace("ERROR", "[color=#ff0000]ERROR[/color]")
		
		temple_os_text.append_text(processed_line + "\n")
		
		# Треск жесткого диска при выводе каждой строчки (кроме пустых)
		if line != "":
			hdd_player.pitch_scale = randf_range(0.9, 1.1)
			hdd_player.play()
		
		# Имитируем разную скорость: код пишется быстро, системные паузы — дольше
		var delay = randf_range(0.08, 0.15)
		if "COMPILING" in line:
			delay = 1.4 # Зависание на начале компиляции
		elif "SUCCESSFUL" in line:
			delay = 1.3 # Пауза после успеха
		elif line == "":
			delay = 0.5 # Небольшой пропуск на пустых строках
		elif line.begins_with("  "):
			delay = randf_range(0.02, 0.06) # Быстрый вывод кода
			
		await get_tree().create_timer(delay).timeout

	# Небольшая пауза в конце загрузки экрана
	await get_tree().create_timer(1.6).timeout
	if _is_skipping: return
	
	temple_os_text.visible = false
	
	# Еще один короткий писк перед логотипом
	beep_player.pitch_scale = 1.2
	beep_player.play()
	
	# 2. Fade in Godot Logo
	godot_logo.visible = true
	var logo_tween_in = create_tween()
	logo_tween_in.tween_property(godot_logo, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	await logo_tween_in.finished
	if _is_skipping: return
	
	await get_tree().create_timer(1.5).timeout
	if _is_skipping: return
	
	# 3. Fade out Godot Logo
	var logo_tween_out = create_tween()
	logo_tween_out.tween_property(godot_logo, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	await logo_tween_out.finished
	if _is_skipping: return
	
	# Переход к главному меню
	SceneManager.goto_scene("res://features/ui/main_menu/main_menu.tscn")
