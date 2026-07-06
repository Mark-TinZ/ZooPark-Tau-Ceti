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
		
	var mouse_pos = viewport.get_mouse_position()
	var origin = camera.project_ray_origin(mouse_pos)
	var normal = camera.project_ray_normal(mouse_pos)
	var end = origin + normal * 1000.0
	
	var query = PhysicsRayQueryParameters3D.create(origin, end)
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
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_valid_placement and hologram and hologram.visible:
			print("Здание построено на: ", current_grid_pos)
			var building_scene = load("res://features/buildings/building_basic.tscn")
			if building_scene:
				var building = building_scene.instantiate() as Node3D
				building.add_to_group("buildings")
				
				# Get or create Buildings node to keep scene tree clean
				var buildings_parent = get_tree().current_scene.get_node_or_null("Buildings")
				if not buildings_parent:
					buildings_parent = Node3D.new()
					buildings_parent.name = "Buildings"
					get_tree().current_scene.add_child(buildings_parent)
					
				buildings_parent.add_child(building)
				building.global_position = current_grid_pos
				# Store type for save system
				building.set_meta("building_type", "building_basic")
