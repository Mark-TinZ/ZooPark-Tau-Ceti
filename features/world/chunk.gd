class_name Chunk
extends StaticBody3D

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var chunk_pos: Vector2
var is_active: bool = false
var chunk_data: ChunkData
var trees_3d_multimesh: MultiMeshInstance3D
var trees_2d_multimesh: MultiMeshInstance3D

# Custom material, normally passed from a global resource or world generator
var terrain_material: StandardMaterial3D

func _ready() -> void:
	# Ensure the node has a blank ArrayMesh so we can reuse it
	if not mesh_instance.mesh:
		mesh_instance.mesh = ArrayMesh.new()
		
	trees_3d_multimesh = MultiMeshInstance3D.new()
	trees_3d_multimesh.visibility_range_end = 60.0
	trees_3d_multimesh.visibility_range_end_margin = 10.0
	trees_3d_multimesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(trees_3d_multimesh)
	
	trees_2d_multimesh = MultiMeshInstance3D.new()
	trees_2d_multimesh.visibility_range_begin = 60.0
	trees_2d_multimesh.visibility_range_begin_margin = 10.0
	trees_2d_multimesh.visibility_range_end = 150.0
	trees_2d_multimesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	trees_2d_multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trees_2d_multimesh)

func set_data(data: ChunkData, material: Material = null) -> void:
	chunk_pos = data.chunk_pos
	chunk_data = data
	if material:
		terrain_material = material as StandardMaterial3D
	
	var array_mesh := mesh_instance.mesh as ArrayMesh
	array_mesh.clear_surfaces()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data.arrays)
	
	if terrain_material:
		array_mesh.surface_set_material(0, terrain_material)
		
	# 2. Update collision shape using the optimized faces from background thread
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(data.collision_faces)
	collision_shape.shape = shape
	
	# 2.5 Update Occluder
	if data.arrays.size() > Mesh.ARRAY_VERTEX and data.arrays[Mesh.ARRAY_VERTEX] != null:
		var occluder := ArrayOccluder3D.new()
		var vertices := data.arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var indices := (data.arrays[Mesh.ARRAY_INDEX] as PackedInt32Array) if data.arrays.size() > Mesh.ARRAY_INDEX and data.arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		
		if indices.is_empty() and vertices.size() > 0:
			indices = PackedInt32Array()
			for i in range(vertices.size()):
				indices.push_back(i)
				
		if vertices.size() >= 3 and indices.size() >= 3:
			occluder.set_arrays(vertices, indices)
			var occluder_node := $OccluderInstance3D as OccluderInstance3D if has_node("OccluderInstance3D") else null
			if occluder_node:
				occluder_node.occluder = occluder
	
	
	# 3. Clear old buildings from pooled chunk
	for child in get_children():
		if child.is_in_group("buildings"):
			ObjectPool.release_instance(child)
			
	# 4. Spawn buildings from delta
	if data.delta_data.has("buildings"):
		var b_scene := load("res://features/buildings/building_basic.tscn") as PackedScene
		if b_scene:
			for b_data: Dictionary in data.delta_data["buildings"]:
				var b := ObjectPool.get_instance(b_scene) as Node3D
				add_child(b)
				b.add_to_group("buildings")
				if b_data.has("transform"):
					b.global_transform = b_data["transform"]
				elif b_data.has("pos"):
					var p: Array = b_data["pos"]
					b.global_position = Vector3(p[0], p[1], p[2])
				
	# 5. Set up MultiMesh for trees (3D and 2D impostors)
	var tree_count := data.tree_matrices.size() / 12
	if tree_count > 0:
		# --- 3D Trees ---
		var mm_3d := MultiMesh.new()
		mm_3d.transform_format = MultiMesh.TRANSFORM_3D
		mm_3d.instance_count = tree_count
		mm_3d.buffer = data.tree_matrices
		
		var tree_mesh := CylinderMesh.new()
		tree_mesh.top_radius = 0.0
		tree_mesh.bottom_radius = 0.5
		tree_mesh.height = 4.0
		tree_mesh.radial_segments = 6 # В 10 раз меньше полигонов!
		tree_mesh.rings = 1
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.5, 0.1)
		tree_mesh.material = mat
		
		mm_3d.mesh = tree_mesh
		trees_3d_multimesh.multimesh = mm_3d
		trees_3d_multimesh.show()
		
		# --- 2D Impostors ---
		var mm_2d := MultiMesh.new()
		mm_2d.transform_format = MultiMesh.TRANSFORM_3D
		mm_2d.instance_count = tree_count
		mm_2d.buffer = data.tree_matrices
		
		var quad := QuadMesh.new()
		quad.size = Vector2(2, 4)
		var mat_2d := StandardMaterial3D.new()
		mat_2d.albedo_color = Color(0.1, 0.5, 0.1)
		mat_2d.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		mat_2d.billboard_keep_scale = true
		mat_2d.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat_2d.alpha_scissor_threshold = 0.5
		quad.material = mat_2d
		
		mm_2d.mesh = quad
		trees_2d_multimesh.multimesh = mm_2d
		trees_2d_multimesh.show()
	else:
		if trees_3d_multimesh.multimesh:
			trees_3d_multimesh.multimesh.instance_count = 0
		if trees_2d_multimesh.multimesh:
			trees_2d_multimesh.multimesh.instance_count = 0
		trees_3d_multimesh.hide()
		trees_2d_multimesh.hide()
	
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

func set_shadows_enabled(enabled: bool) -> void:
	if trees_3d_multimesh:
		trees_3d_multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func update_mesh_and_collision() -> void:
	if not chunk_data:
		return
		
	var array_mesh := mesh_instance.mesh as ArrayMesh
	array_mesh.clear_surfaces()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, chunk_data.arrays)
	
	if terrain_material:
		array_mesh.surface_set_material(0, terrain_material)
		
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(chunk_data.collision_faces)
	collision_shape.shape = shape
	
	if chunk_data.arrays.size() > Mesh.ARRAY_VERTEX and chunk_data.arrays[Mesh.ARRAY_VERTEX] != null:
		var occluder := ArrayOccluder3D.new()
		var vertices := chunk_data.arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var indices := (chunk_data.arrays[Mesh.ARRAY_INDEX] as PackedInt32Array) if chunk_data.arrays.size() > Mesh.ARRAY_INDEX and chunk_data.arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		
		if indices.is_empty() and vertices.size() > 0:
			indices = PackedInt32Array()
			for i in range(vertices.size()):
				indices.push_back(i)
				
		if vertices.size() >= 3 and indices.size() >= 3:
			occluder.set_arrays(vertices, indices)
			var occluder_node := $OccluderInstance3D as OccluderInstance3D if has_node("OccluderInstance3D") else null
			if occluder_node:
				occluder_node.occluder = occluder
