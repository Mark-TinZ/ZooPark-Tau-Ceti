class_name GeneratorManager
extends Node

# Управляет логикой объединения генераторов в сети до 2x2
const GRID_SIZE = 2.0

# Сохраняем генераторы по их 2D сетке (Vector2)
var grid: Dictionary = {} 

func add_generator(pos: Vector3, node: Node3D) -> void:
	var gx = round(pos.x / GRID_SIZE)
	var gz = round(pos.z / GRID_SIZE)
	var grid_pos = Vector2(gx, gz)
	
	grid[grid_pos] = {
		"node": node,
		"group": null
	}
	
	_recalculate_groups(grid_pos)

func _recalculate_groups(start_pos: Vector2) -> void:
	# Простой алгоритм: проверяем квадраты 2x2 вокруг новой точки.
	var offsets_2x2 = [
		[Vector2(0,0), Vector2(1,0), Vector2(0,1), Vector2(1,1)],
		[Vector2(-1,0), Vector2(0,0), Vector2(-1,1), Vector2(0,1)],
		[Vector2(0,-1), Vector2(1,-1), Vector2(0,0), Vector2(1,0)],
		[Vector2(-1,-1), Vector2(0,-1), Vector2(-1,0), Vector2(0,0)]
	]
	
	var best_group = null
	
	# Попытка найти 2x2
	for group_offsets in offsets_2x2:
		var can_form = true
		for offset in group_offsets:
			var check_pos = start_pos + offset
			if not grid.has(check_pos) or grid[check_pos]["group"] != null:
				can_form = false
				break
		
		if can_form:
			best_group = []
			for offset in group_offsets:
				best_group.append(start_pos + offset)
			break
			
	if best_group:
		var group_id = randi()
		for pos in best_group:
			grid[pos]["group"] = group_id
			if grid[pos]["node"].has_method("set_efficiency_bonus"):
				grid[pos]["node"].set_efficiency_bonus(2.0)
		return
		
	# Если 2x2 не найден, ищем 1x2 или 2x1
	var offsets_1x2 = [
		[Vector2(0,0), Vector2(1,0)],
		[Vector2(0,0), Vector2(-1,0)],
		[Vector2(0,0), Vector2(0,1)],
		[Vector2(0,0), Vector2(0,-1)]
	]
	
	for group_offsets in offsets_1x2:
		var can_form = true
		for offset in group_offsets:
			var check_pos = start_pos + offset
			if not grid.has(check_pos) or grid[check_pos]["group"] != null:
				can_form = false
				break
				
		if can_form:
			best_group = []
			for offset in group_offsets:
				best_group.append(start_pos + offset)
			break
			
	if best_group:
		var group_id = randi()
		for pos in best_group:
			grid[pos]["group"] = group_id
			if grid[pos]["node"].has_method("set_efficiency_bonus"):
				grid[pos]["node"].set_efficiency_bonus(1.5)
