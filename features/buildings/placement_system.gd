class_name PlacementSystem
extends Node3D

@export var camera: Camera3D
@export var grid_size: float = 2.0
@export var max_slope_degrees: float = 15.0

var hologram: MeshInstance3D
var is_valid_placement: bool = false
var current_grid_pos: Vector3 = Vector3.ZERO

var mat_valid: StandardMaterial3D
var mat_invalid: StandardMaterial3D

var last_input_was_gamepad: bool = false

func _ready() -> void:
	mat_valid = StandardMaterial3D.new()
	mat_valid.albedo_color = Color(0, 1, 0, 0.5)
	mat_valid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	mat_invalid = StandardMaterial3D.new()
	mat_invalid.albedo_color = Color(1, 0, 0, 0.5)
	mat_invalid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var holo_scene = load("res://features/buildings/building_hologram.tscn")
	if holo_scene:
		hologram = holo_scene.instantiate() as MeshInstance3D
		add_child(hologram)

func _process(_delta: float) -> void:
	if not camera or not hologram:
		return
		
	var space_state = get_world_3d().direct_space_state
	var viewport = get_viewport()
	if not viewport:
		return
		
	var ray_origin = Vector3.ZERO
	var ray_normal = Vector3.ZERO
	
	if last_input_was_gamepad:
		var center = viewport.get_visible_rect().size / 2.0
		ray_origin = camera.project_ray_origin(center)
		ray_normal = camera.project_ray_normal(center)
	else:
		var mouse_pos = viewport.get_mouse_position()
		ray_origin = camera.project_ray_origin(mouse_pos)
		ray_normal = camera.project_ray_normal(mouse_pos)
		
	var end = ray_origin + ray_normal * 1000.0
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, end)
	var result = space_state.intersect_ray(query)
	
	if result:
		hologram.show()
		var pos = result.position
		var surf_normal = result.normal
		
		# Snap to grid
		current_grid_pos.x = round(pos.x / grid_size) * grid_size
		current_grid_pos.y = pos.y + 1.0 # Поднимаем на половину высоты бокса
		current_grid_pos.z = round(pos.z / grid_size) * grid_size
		
		hologram.global_position = current_grid_pos
		
		# Определение наклона
		var slope_angle = rad_to_deg(acos(surf_normal.dot(Vector3.UP)))
		
		is_valid_placement = slope_angle <= max_slope_degrees
		
		if is_valid_placement:
			hologram.material_override = mat_valid
		else:
			hologram.material_override = mat_invalid
	else:
		hologram.hide()

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion or event is InputEventJoypadButton:
		last_input_was_gamepad = true
	elif event is InputEventMouseMotion or event is InputEventMouseButton:
		last_input_was_gamepad = false
		
	var place_pressed = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		place_pressed = true
	elif event.is_action_pressed("ui_accept"):
		place_pressed = true
		
	if place_pressed:
		if is_valid_placement and hologram and hologram.visible:
			print("Здание построено на: ", current_grid_pos)
			
			var world_gen = get_tree().current_scene.get_node_or_null("WorldGenerator")
			if world_gen and world_gen.has_method("add_building_to_chunk"):
				world_gen.add_building_to_chunk(current_grid_pos, "building_basic")
			else:
				push_error("PlacementSystem: WorldGenerator не найден!")
