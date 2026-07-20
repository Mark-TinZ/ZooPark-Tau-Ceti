class_name ChunkData
extends Resource

var arrays: Array
var collision_faces: PackedVector3Array
var tree_matrices: PackedFloat32Array
var chunk_pos: Vector2

# Thread safety & Write-Back Cache
var is_dirty: bool = false
var mutex: Mutex = Mutex.new()

@export var delta_data: Dictionary = {}

func mark_dirty() -> void:
	mutex.lock()
	is_dirty = true
	mutex.unlock()

func add_building_delta(building_type: String, transform: Transform3D) -> void:
	mutex.lock()
	if not delta_data.has("buildings"):
		delta_data["buildings"] = []
	delta_data["buildings"].append({"type": building_type, "transform": transform})
	is_dirty = true
	mutex.unlock()

func set_height_delta(local_x: int, local_z: int, height: float) -> void:
	mutex.lock()
	if not delta_data.has("heights"):
		delta_data["heights"] = {}
	var key = "%d,%d" % [local_x, local_z]
	delta_data["heights"][key] = height
	is_dirty = true
	mutex.unlock()


func generate(pos: Vector2, noise: FastNoiseLite, humidity_noise: FastNoiseLite, world_seed: int, chunk_size: int = 32, vertex_spacing: float = 1.0, height_multiplier: float = 10.0) -> void:
	chunk_pos = pos
	var vert_count := chunk_size + 1
	var offset_x := pos.x * chunk_size * vertex_spacing
	var offset_z := pos.y * chunk_size * vertex_spacing
	
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + hash(Vector2(pos.x, pos.y))
	
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var collision_vertices := PackedVector3Array()
	collision_vertices.resize(vert_count * vert_count)
	
	var tree_transforms: Array[Transform3D] = []
	
	# Generate vertices
	for z in range(vert_count):
		for x in range(vert_count):
			var i := z * vert_count + x
			var world_x := offset_x + x * vertex_spacing
			var world_z := offset_z + z * vertex_spacing
			
			var y := noise.get_noise_2d(world_x, world_z) * height_multiplier
			var key = "%d,%d" % [x, z]
			if delta_data.has("heights") and delta_data["heights"].has(key):
				y = delta_data["heights"][key]
				
			var hum := humidity_noise.get_noise_2d(world_x, world_z)
			
			var vertex := Vector3(x * vertex_spacing, y, z * vertex_spacing)
			collision_vertices[i] = vertex
			st.set_uv(Vector2(float(x) / chunk_size, float(z) / chunk_size))
			
			# Раскраска вертексов по биомам (по желанию, но пока просто сохраняем влажность)
			# Но мы просто ставим деревья
			if y > 2.0 and y < 8.0 and hum > 0.1:
				if rng.randf() < 0.05: # 5% шанс дерева на вертекс
					var scale_val := rng.randf_range(0.8, 1.5)
					var rot_y := rng.randf_range(0, TAU)
					
					# Transform3D(Basis, Origin)
					var basis := Basis().scaled(Vector3(scale_val, scale_val, scale_val)).rotated(Vector3.UP, rot_y)
					var t := Transform3D(basis, vertex)
					tree_transforms.append(t)
			
			st.add_vertex(vertex)
			
	# Generate indices
	var index_count := chunk_size * chunk_size * 6
	collision_faces.resize(index_count)
	var face_idx := 0
	
	for z in range(chunk_size):
		for x in range(chunk_size):
			var v0 := z * vert_count + x
			var v1 := z * vert_count + (x + 1)
			var v2 := (z + 1) * vert_count + x
			var v3 := (z + 1) * vert_count + (x + 1)
			
			st.add_index(v0)
			st.add_index(v1)
			st.add_index(v2)
			
			collision_faces[face_idx] = collision_vertices[v0]
			collision_faces[face_idx+1] = collision_vertices[v1]
			collision_faces[face_idx+2] = collision_vertices[v2]
			
			st.add_index(v1)
			st.add_index(v3)
			st.add_index(v2)
			
			collision_faces[face_idx+3] = collision_vertices[v1]
			collision_faces[face_idx+4] = collision_vertices[v3]
			collision_faces[face_idx+5] = collision_vertices[v2]
			
			face_idx += 6
			
	st.generate_normals()
	st.generate_tangents()
	arrays = st.commit_to_arrays()

	# Pack tree transforms into 12-float array for MultiMesh
	tree_matrices.resize(tree_transforms.size() * 12)
	var m_idx := 0
	for t in tree_transforms:
		tree_matrices[m_idx] = t.basis.x.x
		tree_matrices[m_idx+1] = t.basis.x.y
		tree_matrices[m_idx+2] = t.basis.x.z
		tree_matrices[m_idx+3] = t.origin.x
		
		tree_matrices[m_idx+4] = t.basis.y.x
		tree_matrices[m_idx+5] = t.basis.y.y
		tree_matrices[m_idx+6] = t.basis.y.z
		tree_matrices[m_idx+7] = t.origin.y
		
		tree_matrices[m_idx+8] = t.basis.z.x
		tree_matrices[m_idx+9] = t.basis.z.y
		tree_matrices[m_idx+10] = t.basis.z.z
		tree_matrices[m_idx+11] = t.origin.z
		
		m_idx += 12

func rebuild_mesh_only(noise: FastNoiseLite, chunk_size: int = 32, vertex_spacing: float = 1.0, height_multiplier: float = 10.0) -> void:
	var vert_count := chunk_size + 1
	var offset_x := chunk_pos.x * chunk_size * vertex_spacing
	var offset_z := chunk_pos.y * chunk_size * vertex_spacing
	
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var col_vertices := PackedVector3Array()
	col_vertices.resize(vert_count * vert_count)
	
	for z in range(vert_count):
		for x in range(vert_count):
			var i := z * vert_count + x
			var world_x := offset_x + x * vertex_spacing
			var world_z := offset_z + z * vertex_spacing
			
			var y := noise.get_noise_2d(world_x, world_z) * height_multiplier
			var key = "%d,%d" % [x, z]
			if delta_data.has("heights") and delta_data["heights"].has(key):
				y = delta_data["heights"][key]
				
			var vertex := Vector3(x * vertex_spacing, y, z * vertex_spacing)
			col_vertices[i] = vertex
			st.set_uv(Vector2(float(x) / chunk_size, float(z) / chunk_size))
			st.add_vertex(vertex)
			
	var index_count := chunk_size * chunk_size * 6
	collision_faces.resize(index_count)
	var face_idx := 0
	
	for z in range(chunk_size):
		for x in range(chunk_size):
			var v0 := z * vert_count + x
			var v1 := z * vert_count + (x + 1)
			var v2 := (z + 1) * vert_count + x
			var v3 := (z + 1) * vert_count + (x + 1)
			
			st.add_index(v0)
			st.add_index(v1)
			st.add_index(v2)
			
			collision_faces[face_idx] = col_vertices[v0]
			collision_faces[face_idx+1] = col_vertices[v1]
			collision_faces[face_idx+2] = col_vertices[v2]
			
			st.add_index(v1)
			st.add_index(v3)
			st.add_index(v2)
			
			collision_faces[face_idx+3] = col_vertices[v1]
			collision_faces[face_idx+4] = col_vertices[v3]
			collision_faces[face_idx+5] = col_vertices[v2]
			
			face_idx += 6
			
	st.generate_normals()
	st.generate_tangents()
	arrays = st.commit_to_arrays()

