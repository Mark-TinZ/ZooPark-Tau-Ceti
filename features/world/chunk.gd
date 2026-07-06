class_name Chunk
extends StaticBody3D

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var chunk_pos: Vector2
var is_active: bool = false
var chunk_data: ChunkData
var multimesh_instance: MultiMeshInstance3D

# Custom material, normally passed from a global resource or world generator
var terrain_material: StandardMaterial3D

func _ready() -> void:
	# Ensure the node has a blank ArrayMesh so we can reuse it
	if not mesh_instance.mesh:
		mesh_instance.mesh = ArrayMesh.new()
		
	multimesh_instance = MultiMeshInstance3D.new()
	add_child(multimesh_instance)

func set_data(data: ChunkData, material: Material = null) -> void:
	chunk_pos = data.chunk_pos
	chunk_data = data
	
	var array_mesh = mesh_instance.mesh as ArrayMesh
	array_mesh.clear_surfaces()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data.arrays)
	
	if material:
		array_mesh.surface_set_material(0, material)
		
	# 2. Update collision shape using the optimized faces from background thread
	var shape = ConcavePolygonShape3D.new()
	shape.set_faces(data.collision_faces)
	collision_shape.shape = shape
	
	# 3. Clear old buildings from pooled chunk
	for child in get_children():
		if child.is_in_group("buildings"):
			child.queue_free()
			
	# 4. Spawn buildings from delta
	if data.delta_data.has("buildings"):
		var b_scene = load("res://features/buildings/building_basic.tscn")
		if b_scene:
			for b_data in data.delta_data["buildings"]:
				var b = b_scene.instantiate() as Node3D
				add_child(b)
				b.add_to_group("buildings")
				var p = b_data["pos"]
				b.global_position = Vector3(p[0], p[1], p[2])
				
	# 5. Set up MultiMesh for trees
	var tree_count = data.tree_matrices.size() / 12
	if tree_count > 0:
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.instance_count = tree_count
		mm.buffer = data.tree_matrices
		
		var tree_mesh = CylinderMesh.new()
		tree_mesh.top_radius = 0.0
		tree_mesh.bottom_radius = 0.5
		tree_mesh.height = 4.0
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.5, 0.1)
		tree_mesh.material = mat
		
		mm.mesh = tree_mesh
		multimesh_instance.multimesh = mm
		multimesh_instance.show()
	else:
		if multimesh_instance.multimesh:
			multimesh_instance.multimesh.instance_count = 0
		multimesh_instance.hide()
	
	_enable()

func hide_and_disable() -> void:
	# Important: disable physics first before moving/pooling to prevent BVH recalculation lag
	collision_shape.disabled = true
	visible = false
	is_active = false

func _enable() -> void:
	# After moving and setting data, enable visibility and physics
	visible = true
	collision_shape.disabled = false
	is_active = true
