extends Control

@onready var temple_os_text: Label = $CenterContainer/TempleOSText
@onready var godot_logo: VBoxContainer = $CenterContainer/GodotLogo

var full_text: String = "TempleOS KERNEL INITIALIZED... SYSTEM BOOT..."
var _is_skipping = false

func _ready() -> void:
	temple_os_text.text = ""
	temple_os_text.visible = true
	godot_logo.visible = false
	godot_logo.modulate.a = 0.0
	
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
	SceneManager.goto_scene("res://scenes/main_menu/main_menu.tscn")

func _play_sequence() -> void:
	# 1. Печатающийся текст TempleOS (2 секунды)
	var type_tween = create_tween()
	# Используем visible_ratio от 0 до 1
	temple_os_text.visible_ratio = 0.0
	temple_os_text.text = full_text
	type_tween.tween_property(temple_os_text, "visible_ratio", 1.0, 1.5)
	
	await type_tween.finished
	if _is_skipping: return
	
	await get_tree().create_timer(0.5).timeout # Ждем полсекунды
	if _is_skipping: return
	
	temple_os_text.visible = false
	
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
	SceneManager.goto_scene("res://scenes/main_menu/main_menu.tscn")
