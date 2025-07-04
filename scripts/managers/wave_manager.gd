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
	# --- NEW: Lava Management ---
	_update_lava_state(current_wave)
	# --------------------------------
	
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
		var collision_nodes = []  # ← Changed to array to hold ALL collision shapes

		for child in p.get_children():
			if child is Sprite2D and not sprite_node:
				sprite_node = child
			elif child is CollisionPolygon2D or child is CollisionShape2D:
				collision_nodes.append(child)  # ← Add ALL collision shapes

		
		# Check if BOTH nodes were found
		if not is_instance_valid(sprite_node):
			continue
		if collision_nodes.size() == 0:
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
			elif p.name == "BurnableBridge":
				# NEW: More complex burnable bridge logic
				# Disappears on wave 3, then randomly after wave 5 resets
				if wave_num == 3:
					target_enabled = false
				elif wave_num > 5 and wave_num % 5 != 0:  # Not on reset waves
					# Random chance to disappear on non-reset waves after wave 5
					var random_disappear_chance = 0.3  # 30% chance
					if randf() < random_disappear_chance:
						target_enabled = false
						print("[DEBUG] BurnableBridge randomly disappearing on wave %d" % wave_num)


		# -----------------------------
				
		# --- Apply State with Animation ---
		if p.visible != target_enabled:
			if target_enabled:
				# Platform reappearing (instant for now)
				_show_platform_instantly(p, collision_nodes)
			else:
				# Platform disappearing (animated)
				_hide_platform_animated(p, collision_nodes)

		# NEW: Disable spawn points when platform is disabled
		_update_platform_spawn_points(p, target_enabled)

# NEW: Lava management system
func _update_lava_state(wave_num):
	var parent_node = get_parent()
	if not parent_node:
		return
		
	var lava_node = parent_node.get_node_or_null("Lava")
	if not lava_node:
		print("[WARNING] Lava node not found!")
		return
	
	print("[DEBUG] Updating lava for wave %d" % wave_num)
	
	# Reset all on wave 5, 10, 15, etc.
	var reset_all = (wave_num > 0 and wave_num % 5 == 0)
	
	if reset_all:
		print("[DEBUG] Reset wave - hiding lava")
		_hide_lava_instantly(lava_node)
	elif wave_num == 1:
		print("[DEBUG] Wave 1 - hiding lava")
		_hide_lava_instantly(lava_node)
	elif wave_num == 2:
		print("[DEBUG] Wave 2 - rising lava")
		_show_lava_rising(lava_node)
	# For wave 3+, lava stays visible (no changes needed)

# NEW: Hide lava instantly
func _hide_lava_instantly(lava_node: Area2D):
	print("[DEBUG] Hiding lava instantly")
	
	# Disable lava collision immediately
	var collision_shape = lava_node.get_node_or_null("CollisionShape2D")
	if collision_shape:
		collision_shape.disabled = true
	
	# Hide lava sprite
	var sprite = lava_node.get_node_or_null("Sprite2D")
	if sprite:
		sprite.visible = false
		sprite.position.y = 400  # Reset to bottom position for next rise

# NEW: Show lava with rising animation
func _show_lava_rising(lava_node: Area2D):
	print("[DEBUG] Starting lava rise animation")
	
	var sprite = lava_node.get_node_or_null("Sprite2D")
	var collision_shape = lava_node.get_node_or_null("CollisionShape2D")
	
	if not sprite or not collision_shape:
		print("[ERROR] Lava sprite or collision not found!")
		return
	
	# Start from bottom of screen
	sprite.visible = true
	sprite.position.y = 400  # Bottom position
	
	# Create rising animation
	var tween = create_tween()
	
	# Rise up to final position over 3 seconds
	var final_y_position = 281  # From scene file
	tween.tween_property(sprite, "position:y", final_y_position, 3.0)
	
	# Enable collision when animation is halfway done
	await get_tree().create_timer(1.5).timeout
	collision_shape.disabled = false
	print("[DEBUG] Lava collision enabled")
	
	await tween.finished
	print("[DEBUG] Lava rise animation complete")

# Add missing shake function for platform animation
func _shake_platform(platform: StaticBody2D, shake_value: float):
	if not platform:
		return
		
	# Create small random shake
	var shake_intensity = 3.0 * shake_value
	var random_offset = Vector2(
		randf_range(-shake_intensity, shake_intensity),
		randf_range(-shake_intensity, shake_intensity)
	)
	
	# Apply shake offset to original position
	# Note: You might need to store original_position as a class variable
	platform.position += random_offset

# SIMPLIFIED: Animated platform hiding (no shake)
func _hide_platform_animated(platform: StaticBody2D, collision_nodes: Array):
	print("[DEBUG] Animating platform %s disappearance" % platform.name)
	
	# Disable collision IMMEDIATELY so players can't stand on invisible platforms
	for collision_node in collision_nodes:
		collision_node.disabled = true
		print("[DEBUG] Platform %s: Disabled collision %s" % [platform.name, collision_node.name])
	
	# Store original position for restoration later
	var original_position = platform.position
	
	# Create tween for the animation
	var tween = create_tween()
	tween.set_parallel(true)  # Allow multiple animations simultaneously
	
	# Animation 1: Move platform downward
	var target_position = original_position + Vector2(0, 100)  # Move down 100 pixels
	tween.tween_property(platform, "position", target_position, 1.5)
	
	# Animation 2: Fade out platform
	tween.tween_property(platform, "modulate", Color(1, 1, 1, 0), 1.5)
	
	# Animation 3: Scale down slightly for extra effect
	tween.tween_property(platform, "scale", Vector2(0.8, 0.8), 1.5)
	
	# After animation completes, hide the platform completely
	await tween.finished
	platform.visible = false
	platform.position = original_position  # Reset position for potential reappearance
	platform.scale = Vector2(1, 1)  # Reset scale
	platform.modulate = Color(1, 1, 1, 1)  # Reset alpha
	print("[DEBUG] Platform %s animation complete - now hidden" % platform.name)

# NEW: Instant platform showing (for reset waves)
func _show_platform_instantly(platform: StaticBody2D, collision_nodes: Array):
	print("[DEBUG] Showing platform %s instantly" % platform.name)
	
	# Make visible immediately
	platform.visible = true
	platform.modulate = Color(1, 1, 1, 1)  # Full opacity
	platform.scale = Vector2(1, 1)  # Normal scale
	
	# Re-enable collision
	for collision_node in collision_nodes:
		collision_node.disabled = false
		print("[DEBUG] Platform %s: Enabled collision %s" % [platform.name, collision_node.name])

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
			enemy_body.call_deferred("spawn_as_egg")
			
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
