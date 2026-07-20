class_name PathBuilder
extends Node

const GRID_SIZE = 2.0

# Хранит все проложенные пути по координатам сетки
var paths: Dictionary = {}

func build_path(pos: Vector3, world_generator: Node3D) -> void:
	var gx = round(pos.x / GRID_SIZE)
	var gz = round(pos.z / GRID_SIZE)
	var grid_pos = Vector2(gx, gz)
	
	if paths.has(grid_pos):
		return # Дорожка уже есть
		
	# 1. Запрашиваем/Определяем Чанк
	var c_x := floorf(pos.x / (world_generator.chunk_size * world_generator.vertex_spacing))
	var c_z := floorf(pos.z / (world_generator.chunk_size * world_generator.vertex_spacing))
	var chunk_pos2d = Vector2(c_x, c_z)
	
	if world_generator.active_chunks.has(chunk_pos2d):
		var chunk = world_generator.active_chunks[chunk_pos2d]
		if chunk.chunk_data:
			# Записываем команду на выравнивание ландшафта (Терраформинг)
			if not chunk.chunk_data.delta_data.has("flatten"):
				chunk.chunk_data.delta_data["flatten"] = []
				
			var target_height = pos.y
			chunk.chunk_data.delta_data["flatten"].append({
				"pos": pos,
				"height": target_height
			})
			chunk.chunk_data.mark_dirty()
			
			# TODO: Чтобы терраформинг применился мгновенно, требуется обновить массив вертексов 
			# `chunk.chunk_data.arrays` и вызвать `chunk.set_data(...)`.
			
			# 2. Обновляем визуальные модели дорожек (Straight, Corner, T-Junc, Cross)
			paths[grid_pos] = { "node": null, "chunk": chunk, "pos": pos }
			_update_path_meshes(grid_pos)
			_update_neighbors(grid_pos)

func _update_neighbors(grid_pos: Vector2) -> void:
	var dirs = [Vector2(0,1), Vector2(0,-1), Vector2(1,0), Vector2(-1,0)]
	for d in dirs:
		var n = grid_pos + d
		if paths.has(n):
			_update_path_meshes(n)

func _update_path_meshes(grid_pos: Vector2) -> void:
	if not paths.has(grid_pos): return
	var p_data = paths[grid_pos]
	
	var has_n = paths.has(grid_pos + Vector2(0, -1))
	var has_s = paths.has(grid_pos + Vector2(0, 1))
	var has_e = paths.has(grid_pos + Vector2(1, 0))
	var has_w = paths.has(grid_pos + Vector2(-1, 0))
	
	var connections = int(has_n) + int(has_s) + int(has_e) + int(has_w)
	var model_path = "res://assets/models/paths/path_straight.glb"
	var rotation_y = 0.0
	
	# Простейший выбор тайла на основе связей (Auto-tiling)
	if connections == 0 or connections == 1:
		model_path = "res://assets/models/paths/path_straight.glb"
		if has_e or has_w: rotation_y = PI/2
	elif connections == 2:
		if (has_n and has_s) or (has_e and has_w):
			model_path = "res://assets/models/paths/path_straight.glb"
			if has_e or has_w: rotation_y = PI/2
		else:
			model_path = "res://assets/models/paths/path_corner.glb"
			if has_n and has_e: rotation_y = PI
			elif has_n and has_w: rotation_y = -PI/2
			elif has_s and has_w: rotation_y = 0
			elif has_s and has_e: rotation_y = PI/2
	elif connections == 3:
		model_path = "res://assets/models/paths/path_t_junction.glb"
		if not has_n: rotation_y = 0
		elif not has_s: rotation_y = PI
		elif not has_e: rotation_y = PI/2
		elif not has_w: rotation_y = -PI/2
	elif connections == 4:
		model_path = "res://assets/models/paths/path_cross.glb"
		
	# Заменяем старую модель
	if p_data["node"]:
		p_data["node"].queue_free()
		
	var scene = load(model_path)
	if scene:
		var node = scene.instantiate() as Node3D
		p_data["chunk"].add_child(node)
		node.global_position = p_data["pos"]
		node.rotation.y = rotation_y
		p_data["node"] = node
