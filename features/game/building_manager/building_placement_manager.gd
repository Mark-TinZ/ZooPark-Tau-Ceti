class_name BuildingPlacementManager
extends Node3D

@export var camera: Camera3D
@export var grid_size: float = 2.0
@export var placement_mask: int = 1 # Terrain mask
@export var check_mask: int = 2 # Buildings mask

var is_placement_mode: bool = false
var hologram: Node3D
var current_grid_pos: Vector3 = Vector3.ZERO
var current_rotation: float = 0.0

var current_item_scene_path: String = ""
var current_item_data: Dictionary = {}

var mat_valid: StandardMaterial3D
var mat_invalid: StandardMaterial3D

func _ready() -> void:
	mat_valid = StandardMaterial3D.new()
	mat_valid.albedo_color = Color(0, 1, 0, 0.5)
	mat_valid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	mat_invalid = StandardMaterial3D.new()
	mat_invalid.albedo_color = Color(1, 0, 0, 0.5)
	mat_invalid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func start_placement(scene_path: String, item_data: Dictionary = {}) -> void:
	current_item_scene_path = scene_path
	current_item_data = item_data
	is_placement_mode = true
	current_rotation = 0.0
	
	if hologram:
		hologram.queue_free()
		hologram = null
		
	var scene = load(scene_path) as PackedScene
	if scene:
		hologram = scene.instantiate() as Node3D
		add_child(hologram)
		_disable_collision_recursive(hologram)
		_set_materials_recursive(hologram, mat_valid)
		hologram.hide()

func cancel_placement() -> void:
	is_placement_mode = false
	current_item_scene_path = ""
	current_item_data = {}
	if hologram:
		hologram.queue_free()
		hologram = null

func _disable_collision_recursive(node: Node) -> void:
	if node is CollisionShape3D or node is CollisionPolygon3D:
		node.disabled = true
	if node is StaticBody3D or node is RigidBody3D or node is Area3D:
		node.collision_layer = 0
		node.collision_mask = 0
	for child in node.get_children():
		_disable_collision_recursive(child)

func _set_materials_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_set_materials_recursive(child, mat)

func _process(_delta: float) -> void:
	if not is_placement_mode or not camera or not hologram:
		return
		
	var space_state = get_world_3d().direct_space_state
	var viewport = get_viewport()
	if not viewport:
		return
		
	var cursor_pos = viewport.get_mouse_position()
	# Optional: use VirtualCursorUI if present
	var v_cursor = get_tree().root.get_node_or_null("VirtualCursorUI")
	if v_cursor and "cursor_pos" in v_cursor:
		cursor_pos = v_cursor.cursor_pos
			
	var ray_origin = camera.project_ray_origin(cursor_pos)
	var ray_normal = camera.project_ray_normal(cursor_pos)
		
	var end = ray_origin + ray_normal * 1000.0

	var query = PhysicsRayQueryParameters3D.create(ray_origin, end)
	query.collision_mask = placement_mask
	
	var result = space_state.intersect_ray(query)
	
	if result:
		hologram.show()
		var pos = result.position
		
		# Snap to grid
		current_grid_pos.x = round(pos.x / grid_size) * grid_size
		current_grid_pos.y = pos.y
		current_grid_pos.z = round(pos.z / grid_size) * grid_size
		
		hologram.global_position = current_grid_pos
		hologram.rotation.y = current_rotation
		
		var valid = _check_placement_valid(current_grid_pos)
		if valid:
			_set_materials_recursive(hologram, mat_valid)
		else:
			_set_materials_recursive(hologram, mat_invalid)
	else:
		hologram.hide()

func _check_placement_valid(pos: Vector3) -> bool:
	var space_state = get_world_3d().direct_space_state
	var shape = BoxShape3D.new()
	shape.size = Vector3(grid_size * 0.9, 2.0, grid_size * 0.9)
	
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis().rotated(Vector3.UP, current_rotation), pos + Vector3(0, 1.0, 0))
	query.collision_mask = check_mask 
	
	var intersects = space_state.intersect_shape(query)
	return intersects.size() == 0

func _unhandled_input(event: InputEvent) -> void:
	if not is_placement_mode:
		return
		
	if event.is_action_pressed("ui_cancel"):
		cancel_placement()
		get_viewport().set_input_as_handled()
		return
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			current_rotation += PI / 2.0
			get_viewport().set_input_as_handled()
			return

	var place_pressed = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		place_pressed = true
	elif event.is_action_pressed("ui_accept"):
		place_pressed = true
		
	if place_pressed:
		if hologram and hologram.visible and _check_placement_valid(current_grid_pos):
			_place_building()
			cancel_placement()
		get_viewport().set_input_as_handled()

func _place_building() -> void:
	var scene = load(current_item_scene_path) as PackedScene
	if not scene:
		return
		
	var inst = scene.instantiate() as Node3D
	get_tree().current_scene.add_child(inst)
	inst.global_position = current_grid_pos
	inst.rotation.y = current_rotation
	
	# Attempt to spend money if EconomyManager exists
	var price = current_item_data.get("price", 0)
	if price > 0 and get_tree().root.has_node("EconomyManager"):
		var econ = get_tree().root.get_node("EconomyManager")
		if econ.has_method("spend_money"):
			econ.spend_money(price)
