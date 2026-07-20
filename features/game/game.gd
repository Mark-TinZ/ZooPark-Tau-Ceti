extends Node3D

@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var world_generator: WorldGenerator = $WorldGenerator

func _ready() -> void:
	if not GameSaveSystem.last_loaded_data.is_empty():
		_restore_from_save(GameSaveSystem.last_loaded_data)
		
	if has_node("/root/SettingsManager"):
		var sm = get_node("/root/SettingsManager")
		sm.environment_settings_changed.connect(_apply_env_settings)
		_apply_env_settings()

func _apply_env_settings() -> void:
	if not world_env or not world_env.environment:
		return
	var sm: Node = get_node("/root/SettingsManager")
	var env: Environment = world_env.environment
	env.glow_enabled = sm.get_bloom_enabled()
	env.adjustment_enabled = true
	env.adjustment_brightness = sm.get_brightness()
	env.ssao_enabled = sm.get_ssao_enabled()
	env.ssr_enabled = sm.get_ssr_enabled()
	
	# Fog setup (exponential standard fog, based on Render Distance)
	var view_dist := 3
	if world_generator:
		view_dist = world_generator.view_distance
		
	var fog_distance := view_dist * 32.0 * 1.0 # view_distance * chunk_size * vertex_spacing
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	# Tuning density: e^(-density * distance)
	env.fog_density = 1.0 / (fog_distance * 0.8) 
	
	if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
		env.fog_light_color = (env.sky.sky_material as ProceduralSkyMaterial).sky_top_color
	else:
		env.fog_light_color = Color(0.5, 0.6, 0.7)

func _restore_from_save(data: Dictionary) -> void:
	# 1. Restore Camera
	GameSaveSystem.apply_camera_data(self, data)
	# Здания теперь загружаются автоматически через ChunkManager при стриминге чанков

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var placement: Node = get_node_or_null("BuildingPlacementManager")
		if placement and "is_placement_mode" in placement and placement.is_placement_mode:
			return # Если мы строим, выделение не работает
			
		var camera: Camera3D = get_viewport().get_camera_3d()
		if not camera:
			return
			
		var space_state := get_world_3d().direct_space_state
		var cursor_pos := get_viewport().get_mouse_position()
		
		# VirtualCursorUI может использоваться при игре с геймпада
		if has_node("/root/VirtualCursorUI"):
			var virtual_cursor: Node = get_node("/root/VirtualCursorUI")
			if virtual_cursor.visible:
				cursor_pos = virtual_cursor.cursor_pos
				
		var ray_origin := camera.project_ray_origin(cursor_pos)
		var ray_normal := camera.project_ray_normal(cursor_pos)
		var end := ray_origin + ray_normal * 1000.0

		var query := PhysicsRayQueryParameters3D.create(ray_origin, end)
		query.collision_mask = 8 # Слой 4 - Buildings
		
		var result := space_state.intersect_ray(query)
		if result:
			var hit_node: Node = result.collider.get_parent()
			if "enclosure_data" in hit_node and hit_node.enclosure_data != null:
				EconomyManager.active_enclosure = hit_node.enclosure_data
				print("Выделен вольер: ", hit_node.enclosure_data.climate)
			else:
				# Кликнули по зданию, но это не вольер
				EconomyManager.active_enclosure = null
		else:
			# Кликнули в пустоту
			EconomyManager.active_enclosure = null
