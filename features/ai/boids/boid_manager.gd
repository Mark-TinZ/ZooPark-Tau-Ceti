extends Node


# Хранилище всех активных агентов
var boids: Array[Node3D] = []

func register_boid(b: Node3D) -> void:
	if not boids.has(b):
		boids.append(b)

func unregister_boid(b: Node3D) -> void:
	var idx := boids.find(b)
	if idx != -1:
		boids.remove_at(idx)

# Возвращает соседей в радиусе (используя квадрат дистанции для скорости)
# TODO (Spatial Partitioning): В будущем переписать на Grid (Dict[Vector3i, Array[Node3D]]), 
# чтобы избежать прохода по ВСЕМ агентам (O(N^2)).
func get_neighbors(boid: Node3D, radius_squared: float) -> Array[Node3D]:
	var neighbors: Array[Node3D] = []
	var b_pos := boid.global_transform.origin
	
	for other in boids:
		if other == boid:
			continue
		var dist_sq := b_pos.distance_squared_to(other.global_transform.origin)
		if dist_sq < radius_squared:
			neighbors.append(other)
			
	return neighbors
