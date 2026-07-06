extends Control

const SETTINGS_MENU_SCENE = preload("res://features/ui/settings_menu/settings_menu.tscn")

@onready var button_start: Button = $MarginContainer/VBoxContainer/MainMenuButtonStart
@onready var button_settings: Button = $MarginContainer/VBoxContainer/MainMenuButtonSettings
@onready var button_exit: Button = $MarginContainer/VBoxContainer/MainMenuButtonExit
@onready var exit_confirmation: ConfirmationDialog = $ExitConfirmationDialog

@onready var main_buttons: MarginContainer = $MarginContainer
@onready var play_panel: Control = $PlayPanel
@onready var button_back: Button = $PlayPanel/CenterContainer/PanelContainer/VBoxContainer/BackButton

func _ready() -> void:
	# Даем фокус первой кнопке при старте
	button_start.grab_focus()
	
	# Подключаем сигналы кнопок кодом (это чище, чем через интерфейс)
	button_start.pressed.connect(_on_start_pressed)
	button_settings.pressed.connect(_on_settings_pressed)
	button_exit.pressed.connect(_on_exit_pressed)
	button_back.pressed.connect(_on_back_pressed)
	
	# Подключаем сигнал подтверждения выхода
	exit_confirmation.confirmed.connect(_on_exit_confirmed)

func _on_start_pressed() -> void:
	play_panel.show()
	# TODO: grab focus on the first item in PlayPanel

func _on_back_pressed() -> void:
	play_panel.hide()
	button_start.grab_focus()

func _on_settings_pressed() -> void:
	print("Открытие настроек...")
	var settings_menu = SETTINGS_MENU_SCENE.instantiate()
	add_child(settings_menu)
	
	# Когда меню настроек закроется (удалится из дерева сцен),
	# возвращаем фокус обратно на кнопку "Настройки"
	settings_menu.tree_exited.connect(func(): button_settings.grab_focus())

func _on_exit_pressed() -> void:
	# Вместо резкого выхода показываем наше красивое диалоговое окно
	exit_confirmation.popup_centered()

func _on_exit_confirmed() -> void:
	# Этот код выполнится, только если игрок нажал "ОК" в окне подтверждения
	get_tree().quit()
