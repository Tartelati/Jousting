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
var enemy_bounder_scene = preload("res://scenes/entities/enemy_bounder.tscn")

# Spawn parameters
var spawn_timer = 0
var is_egg_wave = false # Flag for bonus waves
var spawn_interval = 1.5
var spawn_points = []

func _ready():
# Find all spawn points in the level
	var spawn_points_node = get_parent().get_node_or_null("SpawnPoints") # Use get_node_or_null
	if spawn_points_node:
		for point in spawn_points_node.get_children():
			if point is Marker2D:
				spawn_points.append(point)
	
	# If no spawn points were found, create some default positions
	if spawn_points.size() == 0:
		print("Warning: No spawn points found. Using default positions.")
		# Get viewport size correctly for a Node
		if is_inside_tree():
			var viewport_size = get_viewport().get_visible_rect().size
			# Top spawn positions
			for i in range(5):
				var x_pos = viewport_size.x * (i + 1) / 6
				spawn_points.append(Vector2(x_pos, 50))
			
			# Side spawn positions
			for i in range(3):
				var y_pos = viewport_size.y * (i + 1) / 4
				spawn_points.append(Vector2(50, y_pos))  # Adjusted left side spawn slightly inwards
				spawn_points.append(Vector2(viewport_size.x - 50, y_pos))  # Adjusted right side spawn slightly inwards
		else:
			printerr("WaveManager _ready: Node not in tree, cannot get viewport size for default spawns.")


func _process(delta):
	if wave_in_progress and not is_egg_wave and enemies_remaining > 0: # Only spawn enemies in non-egg waves
		# Handle enemy spawning
		spawn_timer += delta
		if spawn_timer >= spawn_interval:
			spawn_enemy()
			spawn_timer = 0
	
	# Check if wave is complete
	if wave_in_progress:
		var enemies_in_scene = get_tree().get_nodes_in_group("enemies").size()
		if is_egg_wave:
			# Egg wave ends when no collectible eggs AND no enemies (hatched or otherwise) are left
			var eggs_in_scene = get_tree().get_nodes_in_group("enemies").size()
			if eggs_in_scene == 0 and enemies_in_scene == 0:
				print("Egg wave complete condition met.") # DEBUG
				wave_finished()
		else:
			# Normal wave ends when enemies_remaining is 0 AND no enemies are left in the scene
			if enemies_remaining == 0 and enemies_in_scene == 0:
				print("Normal wave complete condition met.") # DEBUG
				wave_finished()


func start_wave(wave_number = -1):
	is_egg_wave = false # Reset flag
	if wave_number > 0:
		current_wave = wave_number
	else:
		current_wave += 1
		
	print("Starting Wave %d" % current_wave) # DEBUG
		
	# --- Platform Management FIRST ---
	# This ensures platforms are set correctly even for egg waves
	_update_platform_states(current_wave)
	# -------------------------
		
	# --- Check for Egg Wave ---
	if current_wave > 0 and current_wave % 5 == 0:
		is_egg_wave = true
		_start_egg_wave()
		# Don't proceed with normal enemy setup for egg waves
		emit_signal("wave_started", current_wave)
		return
	# --------------------------
	
	# --- Normal Enemy Wave Setup ---
	# Calculate number of enemies for this wave
	var num_enemies = enemies_per_wave_base + (current_wave - 1) * enemies_per_wave_increment
	enemies_remaining = num_enemies
	
	# Adjust spawn interval based on wave number (gets faster in later waves)
	spawn_interval = max(0.5, 1.5 - (current_wave - 1) * 0.1)
	
	wave_in_progress = true
	emit_signal("wave_started", current_wave)
	

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


func spawn_enemy():
	if enemies_remaining <= 0 or spawn_points.size() == 0:
		return
	
	# Determine enemy type based on wave number and randomness
	var enemy_type = randi() % 3  # 0 = basic, 1 = hunter, 2 = bounder
	
	# Higher waves have more advanced enemies
	if current_wave < 3:
		enemy_type = 0  # Only basic enemies in first waves
	elif current_wave < 5:
		enemy_type = randi() % 2  # Basic and hunter enemies
	
	var enemy
	match enemy_type:
		0: enemy = enemy_basic_scene.instantiate()
		1: enemy = enemy_hunter_scene.instantiate()
		2: enemy = enemy_bounder_scene.instantiate()
		_:
			printerr("Invalid enemy type in spawn_enemy")
			return # Don't spawn if type is invalid

	# --- Choose a SAFE spawn position ---
	# 1. Filter spawn points to find those not blocked by the player
	var available_spawn_points = []
	for point in spawn_points:
		# Check if it's a Marker2D with the spawn_point script attached
		if point is Marker2D and point.has_method("can_spawn"):
			if point.can_spawn():
				available_spawn_points.append(point)
		# else: # Handle the case where spawn_points might contain Vector2 (fallback logic)
			# For simplicity, assume Vector2 points are always available if used
			# available_spawn_points.append(point) 
			# Note: The Vector2 fallback logic might need review if used alongside Marker2D points.
			# It's better if all spawn points are Marker2D with the script attached.

	# 2. Check if any spawn points are available
	if available_spawn_points.size() == 0:
		# print("WaveManager: No available spawn points (player might be blocking all). Skipping spawn.")
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
	print("[DEBUG] Number of eggs to spawn: %d" % num_eggs_to_spawn) # Ensure we don't exceed the number of available spawn points

	for i in range(num_eggs_to_spawn):
		var random_marker = egg_spawn_markers.pick_random()
		if not random_marker is Marker2D:
			continue # Skip if not a marker

		# Instantiate the enemy_base scene
		var enemy_body = enemy_basic_scene.instantiate()
		if enemy_body:
			enemy_body.global_position = random_marker.global_position # Set position of the egg
			get_parent().add_child(enemy_body) # Add egg to the level
			enemy_body.call_deferred("defeat", false)
			print("[DEBUG] Set enemy state to EGG for: %s" % enemy_body.name)
		else:
			print("[ERROR] Could not set EGG state for: %s" % enemy_body.name)
		#
		print("[DEBUG WaveManager _start_egg_wave] Added egg instance: %s to group 'enemies' at %s" % [enemy_body.name, enemy_body.global_position]) # DEBUG Updated

func wave_finished():
	wave_in_progress = false
	emit_signal("wave_completed", current_wave)
	
	# Add bonus points for completing the wave
	get_node("/root/ScoreManager").add_score(current_wave * 100)
	
	# Start next wave after a delay
	await get_tree().create_timer(3.0).timeout
	start_wave()
