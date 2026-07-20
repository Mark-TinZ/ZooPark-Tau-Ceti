extends Node

# Dictionary[String, Array[Node]]
var _pools: Dictionary = {}

func get_instance(scene: PackedScene) -> Node:
	var path := scene.resource_path
	if not _pools.has(path):
		_pools[path] = []
		
	var pool: Array = _pools[path]
	for i in range(pool.size() - 1, -1, -1):
		var obj: Variant = pool[i]
		if is_instance_valid(obj):
			var node := obj as Node
			if not node.is_inside_tree():
				return node
		else:
			pool.remove_at(i)
			
	var new_node := scene.instantiate()
	pool.append(new_node)
	return new_node

func release_instance(node: Node) -> void:
	if is_instance_valid(node) and node.get_parent():
		node.get_parent().remove_child(node)
