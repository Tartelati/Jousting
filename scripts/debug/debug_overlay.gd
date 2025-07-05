extends CanvasLayer

var player_index := 1

# Only show in development builds
func _ready():
	# Check if we're running from the editor
	if OS.has_feature("production"):
		$DebugPanel.visible = false
	else:
		$DebugPanel.visible = true
		# Optional: Remove entirely from release builds
		# queue_free()

func set_player_index(idx):
	player_index = idx

func _on_defeat_all_pressed():
	# Find all enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	# --- Two-Pass Approach ---
	# Pass 1: Defeat all enemies
	var defeated_enemies = []
	for enemy in enemies:
		# Check if the instance is still valid before trying to access it
		if not is_instance_valid(enemy):
			continue
			
		if enemy.has_method("defeat"):
			enemy.defeat(player_index)
			# Keep track of enemies that *should* become collectible eggs
			if enemy.has_method("collect_egg"):
				defeated_enemies.append(enemy)
		else: # Fallback if no defeat method
			enemy.queue_free()

	# Pass 2: Collect eggs after a delay
	if defeated_enemies.size() > 0:
		# Small delay to allow state transition (defeat -> egg)
		await get_tree().create_timer(0.1).timeout
		
		for enemy_ref in defeated_enemies:
			# IMPORTANT: Check if the instance is STILL valid after the delay
			if is_instance_valid(enemy_ref):
				# Check if it's actually in the EGG state before collecting
				# Accessing state might require checking if the property exists first if scripts differ
				var can_collect = false
				if enemy_ref.has_meta("current_state"): # Check if state variable exists (more robust)
					# Assuming State enum is accessible or comparing by integer value if needed
					# This might need adjustment based on how State is defined/used in enemy scripts
					# Let's assume State.EGG is universally 2 for simplicity here, adjust if not.
					if enemy_ref.get_meta("current_state") == 2: # Check for State.EGG (assuming value 2)
						can_collect = true
				elif "current_state" in enemy_ref: # Fallback check if it's a direct property
					if enemy_ref.current_state == enemy_ref.State.EGG:
						can_collect = true

				if can_collect and enemy_ref.has_method("collect_egg"):
					enemy_ref.collect_egg(player_index)
			# else: # Optional debug
				# print("DEBUG: Enemy %s was freed or not in EGG state before collect_egg could be called." % enemy_ref.name)

	print("DEBUG: Defeat All Enemies button processed.")


func _on_next_wave_pressed():
	# Try to find the wave manager
	var wave_manager = find_wave_manager()
	
	if wave_manager and wave_manager.has_method("start_wave"):
		# Force the current wave to end
		if wave_manager.wave_in_progress:
			wave_manager.wave_in_progress = false
			wave_manager.enemies_remaining = 0
			# Check if signal exists before emitting
			if wave_manager.has_signal("wave_completed"):
				wave_manager.emit_signal("wave_completed", wave_manager.current_wave)
			
			# Start next wave immediately without the normal delay
			# Check if variable exists before modifying
			if "current_wave" in wave_manager:
				wave_manager.current_wave += 1
				wave_manager.start_wave(wave_manager.current_wave)
				print("DEBUG: Advanced to wave " + str(wave_manager.current_wave) + "!")
			else:
				printerr("DEBUG: WaveManager missing 'current_wave' variable!")
		else:
			# If no wave in progress, just start the next one
			wave_manager.start_wave()
			# Check if variable exists before printing
			if "current_wave" in wave_manager:
				print("DEBUG: Started wave " + str(wave_manager.current_wave) + "!")
			else:
				printerr("DEBUG: WaveManager missing 'current_wave' variable!")
	else:
		print("DEBUG: Couldn't find wave manager or start_wave method!")

# Helper function to find the wave manager in the scene
# Note: This might need adjustment based on actual scene structure
func find_wave_manager():
	# Prioritize searching by group first
	var nodes = get_tree().get_nodes_in_group("wave_manager")
	if nodes.size() > 0:
		return nodes[0]

	# Fallback to searching common paths if group search fails
	var current_scene = get_tree().current_scene
	if not current_scene: return null

	# Check paths relative to the current scene root
	var paths_relative = [
		"Level/WaveManager", # If Level node exists directly under current scene
		"WaveManager"        # If WaveManager is directly under current scene
	]
	for path in paths_relative:
		var node = current_scene.get_node_or_null(path)
		if node: return node

	# Fallback to absolute paths (less reliable with scene changes)
	var paths_absolute = [
		"/root/MainGame/CurrentScene/WaveManager", # Path within main_game.tscn
		"/root/Main/CurrentScene/Level/WaveManager" # Old path, just in case
	]
	for path in paths_absolute:
		var node = get_node_or_null(path)
		if node: return node
		
	printerr("DEBUG: Wave Manager node not found by group or common paths.")
	return null
