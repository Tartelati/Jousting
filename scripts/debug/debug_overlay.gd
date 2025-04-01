extends CanvasLayer

# Only show in development builds
func _ready():
	# Check if we're running from the editor
	if OS.has_feature("editor") or OS.is_debug_build():
		$DebugPanel.visible = true
	else:
		$DebugPanel.visible = false
		# Optional: Remove entirely from release builds
		# queue_free()

func _on_defeat_all_pressed():
	# Find all enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	# Handle each enemy based on its state
	for enemy in enemies:
		if enemy.has_method("defeat"):
			# First convert to egg state
			enemy.defeat()
			
			# If it has a collect_egg method, call it immediately
			if enemy.has_method("collect_egg"):
				# Small delay to ensure state transition completes
				await get_tree().create_timer(0.1).timeout
				enemy.collect_egg()
		else:
			# Fallback for any enemies without the expected methods
			enemy.queue_free()
	
	print("DEBUG: Defeated and collected all enemies!")

func _on_next_wave_pressed():
	# Try to find the wave manager
	var wave_manager = find_wave_manager()
	
	if wave_manager and wave_manager.has_method("start_wave"):
		# Force the current wave to end
		if wave_manager.wave_in_progress:
			wave_manager.wave_in_progress = false
			wave_manager.enemies_remaining = 0
			wave_manager.emit_signal("wave_completed", wave_manager.current_wave)
			
			# Start next wave immediately without the normal delay
			wave_manager.current_wave += 1
			wave_manager.start_wave(wave_manager.current_wave)
			print("DEBUG: Advanced to wave " + str(wave_manager.current_wave) + "!")
		else:
			# If no wave in progress, just start the next one
			wave_manager.start_wave()
			print("DEBUG: Started wave " + str(wave_manager.current_wave) + "!")
	else:
		print("DEBUG: Couldn't find wave manager!")

# Helper function to find the wave manager in the scene
func find_wave_manager():
	# Try different paths to find the wave manager
	var paths = [
		"/root/Main/CurrentScene/Level/WaveManager",
		"/root/Main/CurrentScene/WaveManager",
		"/root/Level/WaveManager"
	]
	
	for path in paths:
		var node = get_node_or_null(path)
		if node:
			return node
			
	# If not found by path, search all nodes
	var nodes = get_tree().get_nodes_in_group("wave_manager")
	if nodes.size() > 0:
		return nodes[0]
		
	return null
