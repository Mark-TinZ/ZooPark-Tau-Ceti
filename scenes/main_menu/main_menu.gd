extends Control

@onready var button_start: Button = $MarginContainer/VBoxContainer/MainMenuButtonStart
@onready var button_settings: Button = $MarginContainer/VBoxContainer/MainMenuButtonSettings
@onready var button_exit: Button = $MarginContainer/VBoxContainer/MainMenuButtonExit
@onready var exit_confirmation: ConfirmationDialog = $ExitConfirmationDialog

func _ready() -> void:
	# Даем фокус первой кнопке при старте
	button_start.grab_focus()
	
	# Подключаем сигналы кнопок кодом (это чище, чем через интерфейс)
	button_start.pressed.connect(_on_start_pressed)
	button_settings.pressed.connect(_on_settings_pressed)
	button_exit.pressed.connect(_on_exit_pressed)
	
	# Подключаем сигнал подтверждения выхода
	exit_confirmation.confirmed.connect(_on_exit_confirmed)

func _on_start_pressed() -> void:
	print("Запуск игры...")
	# Здесь будет смена сцены: GetTree().ChangeSceneToFile("res://scenes/game.tscn")

func _on_settings_pressed() -> void:
	print("Открытие настроек...")
	# Пока у нас нет отдельного меню настроек, просто сменим язык для теста God Tier локализации!
	if SaveManager.settings["language"] == "ru":
		SaveManager.settings["language"] = "en"
	else:
		SaveManager.settings["language"] = "ru"
	
	SaveManager.apply_settings()
	SaveManager.save_settings()

func _on_exit_pressed() -> void:
	# Вместо резкого выхода показываем наше красивое диалоговое окно
	exit_confirmation.popup_centered()

func _on_exit_confirmed() -> void:
	# Этот код выполнится, только если игрок нажал "ОК" в окне подтверждения
	get_tree().quit()
