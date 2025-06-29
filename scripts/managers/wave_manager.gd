extends Node

signal wave_started(wave_number)
signal wave_completed(wave_number)

# Wave configuration
var current_wave = 0
var enemies_per_wave_base = 3
var enemies_per_wave_increment = 2
var enemies_remaining = 0
var wave_in_progress = false

# Enemy scenes
var enemy_basic_scene = preload("res://scenes/entities/enemy_base.tscn")
var enemy_hunter_scene = preload("res://scenes/entities/enemy_hunter.tscn")
var shadowlord_scene = preload("res://scenes/entities/shadowlord.tscn")
var spawn_manager = preload("res://scripts/managers/spawn_manager.gd")

# Spawn parameters
var spawn_timer = 0
var is_egg_wave = false # Flag for bonus waves
var spawn_interval = 1.5
var spawn_points = []

func _ready():
# Find all spawn points in the level
	spawn_points.clear()
	var parent = get_parent()
	if parent:
		_find_spawn_points_recursive(parent)
		
func _find_spawn_points_recursive(node):
	for child in node.get_children():
		if child.is_in_group("SpawnPoints"):
			spawn_points.append(child)
		_find_spawn_points_recursive(child)

func _process(delta):
	if wave_in_progress and not is_egg_wave and enemies_remaining > 0:
		# Handle enemy spawning
		spawn_timer += delta
		if spawn_timer >= spawn_interval:
			spawn_enemy()
			spawn_timer = 0
	
	# Check if wave is complete
	if wave_in_progress:
		var enemies_in_scene = get_tree().get_nodes_in_group("enemies").size()
		if is_egg_wave:
			# FIX 2: Egg wave ends when no enemies are left in the scene (they get removed when collected)
			print("[DEBUG] Egg wave check - enemies in scene: %d" % enemies_in_scene)
			if enemies_in_scene == 0:
				print("Egg wave complete - all eggs collected or hatched!")
				wave_finished()
		else:
			# Normal wave ends when enemies_remaining is 0 AND no enemies are left in the scene
			if enemies_remaining == 0 and enemies_in_scene == 0:
				print("Normal wave complete condition met.")
				wave_finished()


func start_wave(wave_number = -1):
	is_egg_wave = false # Reset flag
	if wave_number > 0:
		current_wave = wave_number
	else:
		current_wave += 1
	
	print("Starting Wave %d" % current_wave) # DEBUG
	
	# --- Platform Management FIRST ---
	_update_platform_states(current_wave)
	# -------------------------
	
	# --- Check for Egg Wave ---
	if current_wave > 0 and current_wave % 5 == 0:
		is_egg_wave = true
		_start_egg_wave()
		emit_signal("wave_started", current_wave)
		return
	# --------------------------
	
	# --- Normal Enemy Wave Setup ---
	var num_enemies = enemies_per_wave_base + (current_wave - 1) * enemies_per_wave_increment
	enemies_remaining = num_enemies
	spawn_interval = max(0.5, 1.5 - (current_wave - 1) * 0.1)

	# Build spawn list for SpawnManager
	var spawn_list = []
	for i in range(num_enemies):
		var enemy_type = randi() % 3
		if current_wave < 3:
			enemy_type = 0
		elif current_wave < 5:
			enemy_type = randi() % 2
		var scene = enemy_basic_scene
		if enemy_type == 1:
			scene = enemy_hunter_scene
		elif enemy_type == 2:
			scene = shadowlord_scene
		spawn_list.append({"scene": scene, "data": {}})

	# Use autoloaded SpawnManager directly
	if SpawnManager:
		if not wave_in_progress:
			wave_in_progress = true
			emit_signal("wave_started", current_wave)
		SpawnManager.queue_spawn_batch(spawn_list)
	else:
		printerr("WaveManager: SpawnManager autoload not found!")

	# No longer wait for all spawns to complete before starting wave
	

func _update_platform_states(wave_num):
	# --- DEBUG: Check Parent ---
	var parent_node = get_parent()
	if not parent_node:
		printerr("WaveManager: Cannot update platforms, parent is null!")
		return
	print("[DEBUG Platform Update] WaveManager parent: %s" % parent_node.name)
	# ---------------------------

	var platforms_node = parent_node.get_node_or_null("Platforms")
	if not platforms_node:
		printerr("WaveManager: 'Platforms' node not found under parent %s!" % parent_node.name)
		return

	var reset_all = (wave_num > 0 and wave_num % 5 == 0)

	for p in platforms_node.get_children():
		# Ensure 'p' itself is a valid node before proceeding
		if not is_instance_valid(p):
			continue
			
		# Assuming platform structure is StaticBody2D -> Sprite2D, CollisionPolygon2D/CollisionShape2D
		if not p is StaticBody2D:
			continue

		# Find Sprite and Collision nodes more robustly
		var sprite_node = null
		var collision_shape_node = null # Can be Polygon or Shape

		for child in p.get_children():
			if child is Sprite2D and not sprite_node: # Find first Sprite2D
				sprite_node = child
			elif child is CollisionPolygon2D and not collision_shape_node: # Find first CollisionPolygon2D
				collision_shape_node = child
			elif child is CollisionShape2D and not collision_shape_node: # Fallback to CollisionShape2D
				collision_shape_node = child
			# Break early if both found
			if sprite_node and collision_shape_node:
				break
		
		# Check if BOTH nodes were found
		if not is_instance_valid(sprite_node):
			continue
		if not is_instance_valid(collision_shape_node):
			continue

		# --- Determine Target State ---
		var target_enabled = true # Default state for platforms 1, 3, 5 etc.
		if reset_all:
			target_enabled = true # Enable all on reset waves
		else:
			# Apply specific disabling logic for non-reset waves
			if p.name == "platform1" and wave_num >= 3:
				target_enabled = false
			elif p.name == "platform2" and wave_num >= 4:
				target_enabled = false
		# -----------------------------
				
		# --- Apply State ---
		# Apply visibility to the StaticBody itself (or sprite if preferred )
		if p.visible != target_enabled:
			p.visible = target_enabled
			
		# Apply collision state (disabled = true means NO collision)
		if collision_shape_node.disabled == target_enabled:
			collision_shape_node.disabled = not target_enabled

		# NEW: Disable spawn points when platform is disabled
		_update_platform_spawn_points(p, target_enabled)

# NEW: Helper function to manage spawn points on platforms
func _update_platform_spawn_points(platform_node: StaticBody2D, enabled: bool):
	# Find spawn points by their specific names based on platform
	var spawn_point_name = ""
	match platform_node.name:
		"platform1":
			spawn_point_name = "SpawnPoint4"
		"platform3": 
			spawn_point_name = "SpawnPoint1"
		"platform4":
			spawn_point_name = "SpawnPoint3"
		"GroundBase":
			spawn_point_name = "SpawnPoint2"
		_:
			return # No spawn points on this platform
	
	var spawn_point = platform_node.get_node_or_null(spawn_point_name)
	if spawn_point and spawn_point is Marker2D:
		# Disable/enable the spawn point by setting its process mode
		if enabled:
			spawn_point.process_mode = Node.PROCESS_MODE_INHERIT
			print("[DEBUG] Enabled spawn point: %s on platform: %s" % [spawn_point_name, platform_node.name])
		else:
			spawn_point.process_mode = Node.PROCESS_MODE_DISABLED
			print("[DEBUG] Disabled spawn point: %s on platform: %s" % [spawn_point_name, platform_node.name])

func spawn_enemy():
	if enemies_remaining <= 0 or spawn_points.size() == 0:
		return
	
	# Determine enemy type based on wave number and randomness
	var enemy_type = randi() % 3  # 0 = basic, 1 = hunter, 2 = shadow_lord
	
	# Higher waves have more advanced enemies
	if current_wave < 3:
		enemy_type = 0  # Only basic enemies in first waves
	elif current_wave < 5:
		enemy_type = randi() % 2  # Basic and hunter enemies
	
	var enemy
	match enemy_type:
		0: enemy = enemy_basic_scene.instantiate()
		1: enemy = enemy_hunter_scene.instantiate()
		2: enemy = shadowlord_scene.instantiate()
		_:
			printerr("Invalid enemy type in spawn_enemy")
			return # Don't spawn if type is invalid

	# --- Choose a SAFE spawn position ---
	# 1. Filter spawn points to find those not blocked by the player
	var available_spawn_points = []
	for point in spawn_points:
		# Check if it's a Marker2D with the spawn_point script attached
		if point is Marker2D and point.has_method("can_spawn"):
			# NEW: Also check if the spawn point is enabled (not disabled by platform management)
			if point.process_mode != Node.PROCESS_MODE_DISABLED and point.can_spawn():
				available_spawn_points.append(point)


	# 2. Check if any spawn points are available
	if available_spawn_points.size() == 0:
		print("[DEBUG] No available spawn points (all disabled or blocked)")
		return # Skip spawning this cycle

	# 3. Choose a random spawn point from the *available* ones
	var spawn_index = randi() % available_spawn_points.size()
	var spawn_point = available_spawn_points[spawn_index]
	
	# Set enemy position (assuming chosen point is Marker2D now)
	enemy.global_position = spawn_point.global_position
	
	# Add enemy to the scene (WaveManager's parent is the level)
	get_parent().add_child(enemy)
	enemies_remaining -= 1

func _start_egg_wave():
	print("Starting Egg Wave: %d" % current_wave)
	wave_in_progress = true
	enemies_remaining = 0 # No enemies to spawn directly

	var egg_spawns_node = get_parent().get_node_or_null("EggSpawnPoints")
	if not egg_spawns_node:
		printerr("WaveManager: EggSpawnPoints node not found in parent! Cannot spawn eggs.")
		return
		
	var egg_spawn_markers = egg_spawns_node.get_children()
	if egg_spawn_markers.size() == 0:
		printerr("WaveManager: No Marker2D children found under EggSpawnPoints!")
		return

	var num_eggs_to_spawn = randi_range(15, 25)
	print("[DEBUG] Number of eggs to spawn: %d" % num_eggs_to_spawn)

	for i in range(num_eggs_to_spawn):
		var random_marker = egg_spawn_markers.pick_random()
		if not random_marker is Marker2D:
			continue # Skip if not a marker

		# Instantiate the enemy_base scene
		var enemy_body = enemy_basic_scene.instantiate()
		if enemy_body:
			enemy_body.global_position = random_marker.global_position
			get_parent().add_child(enemy_body)
			
			# FIX 1: Properly call defeat with a valid player_index and no score award
			enemy_body.call_deferred("defeat", 1, false, Vector2.ZERO)
			
			print("[DEBUG] Set enemy state to EGG for: %s" % enemy_body.name)
		else:
			print("[ERROR] Could not create enemy body")

	print("[DEBUG WaveManager _start_egg_wave] Spawned %d eggs for wave %d" % [num_eggs_to_spawn, current_wave])

func wave_finished():
	wave_in_progress = false
	emit_signal("wave_completed", current_wave)
	
	# Start next wave after a delay
	await get_tree().create_timer(3.0).timeout
	start_wave()
