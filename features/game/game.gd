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
	var sm = get_node("/root/SettingsManager")
	var env = world_env.environment
	env.glow_enabled = sm.get_bloom_enabled()
	env.adjustment_enabled = true
	env.adjustment_brightness = sm.get_brightness()
	env.ssao_enabled = sm.get_ssao_enabled()
	env.ssr_enabled = sm.get_ssr_enabled()
	
	# Fog setup (exponential standard fog, based on Render Distance)
	var view_dist = 3
	if world_generator:
		view_dist = world_generator.view_distance
		
	var fog_distance = view_dist * 32.0 * 1.0 # view_distance * chunk_size * vertex_spacing
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
