class_name ChunkData
extends RefCounted

var arrays: Array
var collision_faces: PackedVector3Array
var chunk_pos: Vector2

func generate(pos: Vector2, noise: FastNoiseLite, chunk_size: int = 32, vertex_spacing: float = 1.0, height_multiplier: float = 10.0) -> void:
	chunk_pos = pos
	var vert_count = chunk_size + 1
	var offset_x = pos.x * chunk_size * vertex_spacing
	var offset_z = pos.y * chunk_size * vertex_spacing
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var collision_vertices = PackedVector3Array()
	collision_vertices.resize(vert_count * vert_count)
	
	# Generate vertices
	for z in range(vert_count):
		for x in range(vert_count):
			var i = z * vert_count + x
			var world_x = offset_x + x * vertex_spacing
			var world_z = offset_z + z * vertex_spacing
			
			var y = noise.get_noise_2d(world_x, world_z) * height_multiplier
			
			var vertex = Vector3(x * vertex_spacing, y, z * vertex_spacing)
			collision_vertices[i] = vertex
			st.set_uv(Vector2(float(x) / chunk_size, float(z) / chunk_size))
			st.add_vertex(vertex)
			
	# Generate indices
	var index_count = chunk_size * chunk_size * 6
	collision_faces.resize(index_count)
	var face_idx = 0
	
	for z in range(chunk_size):
		for x in range(chunk_size):
			var v0 = z * vert_count + x
			var v1 = z * vert_count + (x + 1)
			var v2 = (z + 1) * vert_count + x
			var v3 = (z + 1) * vert_count + (x + 1)
			
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
