extends Node3D

var enclosure_data: Enclosure = null
var visibility_notifier: VisibleOnScreenNotifier3D

func _ready() -> void:
	visibility_notifier = VisibleOnScreenNotifier3D.new()
	visibility_notifier.aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
	add_child(visibility_notifier)
	visibility_notifier.screen_entered.connect(_on_screen_entered)
	visibility_notifier.screen_exited.connect(_on_screen_exited)

func _on_screen_entered() -> void:
	set_process(true)
	set_physics_process(true)
	# TODO: Восстановить анимации и частицы (если есть)

func _on_screen_exited() -> void:
	set_process(false)
	set_physics_process(false)
	# TODO: Отключить анимации и частицы для экономии производительности
