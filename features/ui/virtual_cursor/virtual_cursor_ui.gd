extends CanvasLayer

var cursor_pos: Vector2 = Vector2.ZERO
var cursor_speed: float = 1200.0
var _is_gamepad_active: bool = false
var _cursor_control: Control

func _ready() -> void:
	layer = 128
	
	_cursor_control = Control.new()
	_cursor_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_cursor_control)
	
	_cursor_control.draw.connect(_on_draw_cursor)
	
	var vp = get_viewport()
	if vp:
		cursor_pos = vp.get_visible_rect().size / 2.0
		
	_ensure_joypad_ui_inputs()

func _ensure_joypad_ui_inputs() -> void:
	# Надежно добавляем кнопки геймпада в системные действия, если их там нет
	var ui_actions = {
		"ui_accept": JOY_BUTTON_A,
		"ui_cancel": JOY_BUTTON_B,
		"ui_left": JOY_BUTTON_DPAD_LEFT,
		"ui_right": JOY_BUTTON_DPAD_RIGHT,
		"ui_up": JOY_BUTTON_DPAD_UP,
		"ui_down": JOY_BUTTON_DPAD_DOWN
	}
	
	for action in ui_actions:
		if not InputMap.has_action(action): continue
		var has_joy = false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				has_joy = true
				break
		if not has_joy:
			var joy_btn = InputEventJoypadButton.new()
			joy_btn.button_index = ui_actions[action]
			InputMap.action_add_event(action, joy_btn)
			print("VirtualCursorUI: Added joypad fallback for ", action)

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion or event is InputEventJoypadButton:
		if not _is_gamepad_active:
			_is_gamepad_active = true
			_cursor_control.queue_redraw()
	elif event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventKey:
		if _is_gamepad_active:
			_is_gamepad_active = false
			_cursor_control.queue_redraw()
			
	if event is InputEventMouseMotion and not _is_gamepad_active:
		cursor_pos = event.position

func _process(delta: float) -> void:
	if _is_gamepad_active:
		var input_vec = Input.get_vector("cursor_move_left", "cursor_move_right", "cursor_move_up", "cursor_move_down")
		if input_vec.length_squared() > 0:
			cursor_pos += input_vec * cursor_speed * delta
			
			var vp_size = get_viewport().get_visible_rect().size
			cursor_pos.x = clampf(cursor_pos.x, 0, vp_size.x)
			cursor_pos.y = clampf(cursor_pos.y, 0, vp_size.y)
			
			_cursor_control.queue_redraw()

func is_gamepad_active() -> bool:
	return _is_gamepad_active

# Этот метод вызывает `placement_system.gd`, когда хочет использовать курсор
var _is_building_mode := false
func set_building_mode(active: bool) -> void:
	_is_building_mode = active
	_cursor_control.queue_redraw()

func _on_draw_cursor() -> void:
	if not _is_gamepad_active:
		return
		
	# Скрываем прицел в системных менюшках
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.name in ["MainMenu", "SplashScreen"]:
		return
		
	var center = cursor_pos
	var color = Color(1, 1, 1, 0.9)
	var radius = 8.0
	var line_width = 2.0
	
	_cursor_control.draw_arc(center, radius, 0, TAU, 32, color, line_width)
	_cursor_control.draw_line(center - Vector2(radius + 6, 0), center - Vector2(radius - 2, 0), color, line_width)
	_cursor_control.draw_line(center + Vector2(radius - 2, 0), center + Vector2(radius + 6, 0), color, line_width)
	_cursor_control.draw_line(center - Vector2(0, radius + 6), center - Vector2(0, radius - 2), color, line_width)
	_cursor_control.draw_line(center + Vector2(0, radius - 2), center + Vector2(0, radius + 6), color, line_width)
	_cursor_control.draw_circle(center, 1.5, color)
