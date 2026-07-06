class_name Chunk
extends StaticBody3D

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var chunk_pos: Vector2
var is_active: bool = false

# Custom material, normally passed from a global resource or world generator
var terrain_material: StandardMaterial3D

func _ready() -> void:
	# Ensure the node has a blank ArrayMesh so we can reuse it
	if not mesh_instance.mesh:
		mesh_instance.mesh = ArrayMesh.new()

func set_data(data: ChunkData, material: Material = null) -> void:
	chunk_pos = data.chunk_pos
	
	var array_mesh = mesh_instance.mesh as ArrayMesh
	array_mesh.clear_surfaces()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data.arrays)
	
	if material:
		array_mesh.surface_set_material(0, material)
		
	# 2. Update collision shape using the optimized faces from background thread
	var shape = ConcavePolygonShape3D.new()
	shape.set_faces(data.collision_faces)
	collision_shape.shape = shape
	
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
