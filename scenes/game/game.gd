extends Node3D

func _ready() -> void:
	if not GameSaveSystem.last_loaded_data.is_empty():
		_restore_from_save(GameSaveSystem.last_loaded_data)
		
	# Add pause tracking or any other Game specific initialization here

func _restore_from_save(data: Dictionary) -> void:
	# 1. Restore Camera
	GameSaveSystem.apply_camera_data(self, data)
	
	# 2. Restore Buildings
	var buildings_data = data.get("buildings", [])
	if buildings_data.size() > 0:
		var buildings_parent = get_node_or_null("Buildings")
		if not buildings_parent:
			buildings_parent = Node3D.new()
			buildings_parent.name = "Buildings"
			add_child(buildings_parent)
			
		for b_data in buildings_data:
			var b_type = b_data.get("type", "building_basic")
			var b_pos = b_data.get("position", [0, 0, 0])
			
			var scene_path = "res://scenes/game/buildings/" + b_type + ".tscn"
			if ResourceLoader.exists(scene_path):
				var b_scene = load(scene_path)
				var building = b_scene.instantiate() as Node3D
				building.add_to_group("buildings")
				building.global_position = Vector3(b_pos[0], b_pos[1], b_pos[2])
				building.set_meta("building_type", b_type)
				buildings_parent.add_child(building)
