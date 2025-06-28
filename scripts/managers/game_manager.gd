extends Node

var player_scene = preload("res://scenes/entities/player.tscn")
var player_nodes = [] # Store references to player instances

enum GameState {MAIN_MENU, PLAYING, PAUSED, GAME_OVER}

var current_state = GameState.MAIN_MENU
var current_level = null
var hud_instance = null
var main_menu_scene = preload("res://scenes/ui/main_menu.tscn")
var game_over_scene = preload("res://scenes/ui/game_over.tscn")
var main_game_scene = preload("res://scenes/main_game.tscn") # Added
var level_scene = preload("res://scenes/levels/level_base.tscn")
var hud_scene = preload("res://scenes/ui/hud.tscn")
var debug_overlay_scene = preload("res://scenes/debug/debug_overlay.tscn")

# References to active scenes/nodes
var active_ui = null # Can likely be removed if UI is always child of current scene
var active_level = null

func _ready():
	# Don't show main menu automatically here. 
	# The scene defined in project settings (opening_cinematic.tscn) will load first.
	
	# Connect to input events for pause
	process_mode = Node.PROCESS_MODE_ALWAYS  # Ensure this node processes even when game is paused
	# Add debug overlay if we're in development mode
	if OS.has_feature("editor") or OS.is_debug_build():
		var debug_overlay = debug_overlay_scene.instantiate()
		add_child(debug_overlay)

func assign_player_inputs(num_players: int) -> Array:
	var joypads = Input.get_connected_joypads()
	var devices = []
	
	print("[DEBUG] GameManager: Assigning inputs for %d players, %d controllers available" % [num_players, joypads.size()])
	print("[DEBUG] GameManager: Connected joypads: ", joypads)
	
	# Assign devices: -1 for keyboard, 0+ for controllers
	if num_players == 1:
		# Single player: prefer first controller if available, fallback to keyboard
		if joypads.size() > 0:
			devices.append(0)  # First controller (device ID 0)
			print("[DEBUG] GameManager: Single player - assigned controller 0")
		else:
			devices.append(-1)  # Keyboard
			print("[DEBUG] GameManager: Single player - assigned keyboard")
	else:
		# Multi-player: assign controllers sequentially, keyboard as fallback
		for i in range(num_players):
			print("[DEBUG] GameManager: Processing player %d" % [i + 1])
			if i < joypads.size():
				devices.append(i)  # Player 1 gets controller 0, Player 2 gets controller 1, etc.
				print("[DEBUG] GameManager: Player %d assigned controller %d" % [i + 1, i])
			else:
				devices.append(-1)  # Fallback to keyboard if no more controllers
				print("[DEBUG] GameManager: Player %d assigned keyboard (fallback)" % [i + 1])
	
	print("[DEBUG] GameManager: Final device assignments: ", devices)
	return devices

# Get list of devices currently assigned to players
func get_assigned_devices() -> Array:
	var assigned = []
	for player in player_nodes:
		if player and is_instance_valid(player):
			assigned.append(player.device)
	return assigned



func _input(event):
	if event.is_action_pressed("pause") and current_state == GameState.PLAYING:
		pause_game()

# Handle dynamic player joining during gameplay
func _process(_delta):
	if current_state == GameState.PLAYING and player_nodes.size() < 4:
		# Check all connected controllers for START button press
		var joypads = Input.get_connected_joypads()
		
		# Add periodic debug output every 2 seconds to show system status
		if Engine.get_process_frames() % 120 == 0:  # Every 2 seconds at 60fps
			var assigned_devices = get_assigned_devices()
			print("[DEBUG] GameManager: Active players: %d, Connected joypads: %s" % [player_nodes.size(), joypads])
			print("[DEBUG] GameManager: Game state: %s, Can join: %s" % [GameState.keys()[current_state], current_state == GameState.PLAYING and player_nodes.size() < 4])
			print("[DEBUG] GameManager: Player details:")
			for i in range(player_nodes.size()):
				var p = player_nodes[i]
				if p and is_instance_valid(p):
					print("  - Player%d: device=%d, position=%s" % [p.player_index, p.device, p.global_position])
				else:
					print("  - Player slot %d: invalid/null" % [i + 1])
			print("[DEBUG] GameManager: Assigned devices: ", assigned_devices)
		
		for controller_id in joypads:
			# Additional debug: Check if MultiplayerInput detects the button press
			if MultiplayerInput and MultiplayerInput.is_action_just_pressed(controller_id, "start_game"):
				var assigned_devices = get_assigned_devices()
				var new_player_index = player_nodes.size() + 1
				print("[DEBUG] GameManager: Controller %d pressed START. Currently assigned devices: " % controller_id, assigned_devices)
				print("[DEBUG] GameManager: Current player_nodes.size()=%d, calculated new_player_index=%d" % [player_nodes.size(), new_player_index])
				
				# Only allow joining if this controller isn't already assigned
				if not controller_id in assigned_devices:
					print("[DEBUG] GameManager: Adding new player %d with controller %d" % [new_player_index, controller_id])
					spawn_single_player_with_device(new_player_index, controller_id)
				else:
					print("[DEBUG] GameManager: Controller %d already assigned to a player" % controller_id)
			
			# Additional debug: Test if regular Input detects the button press
			if Input.is_action_just_pressed("start_game"):
				print("[DEBUG] GameManager: Regular Input detected START press (could be any device)")
				
				# Try to determine which controller it was by checking device-specific actions
				var device_action_name = ""
				if MultiplayerInput:
					device_action_name = MultiplayerInput.get_action_name(controller_id, "start_game")
				if device_action_name != "" and Input.is_action_just_pressed(device_action_name):
					print("[DEBUG] GameManager: Device-specific action '%s' confirmed for controller %d" % [device_action_name, controller_id])

func show_main_menu():
	# Clear any existing UI
	if active_ui != null:
		active_ui.queue_free()
	
	# Clear any existing level
	if active_level != null:
		active_level.queue_free()
		active_level = null
		
	# Ensure the game is unpaused when returning to the main menu
	if get_tree().paused:
		get_tree().paused = false
	
	# Change the entire scene to the main menu scene
	var error = get_tree().change_scene_to_packed(main_menu_scene)
	if error != OK:
		printerr("Failed to change scene to Main Menu: ", error)
		return # Stop if changing scene failed
	
	# Note: Connecting signals like "start_game" needs to happen *in the main menu script itself* 
	# now, as this GameManager instance doesn't directly hold the instantiated menu UI anymore 
	# after the scene change. We assume the main_menu.tscn's script handles its own button connections.
	# If the main menu script relied on the GameManager connecting its signals, that logic needs adjustment.
	# For now, we just handle the scene change.
	
	current_state = GameState.MAIN_MENU

func start_game():
	# Initiate the scene change to the main gameplay scene.
	# The main_game scene's script will call back to setup_new_gameplay_scene once it's ready.
	var error = get_tree().change_scene_to_packed(main_game_scene)
	if error != OK:
		printerr("Failed to initiate change scene to Main Game Scene: ", error)
		# Optionally handle the error, e.g., go back to main menu
		# show_main_menu() 
		return

func spawn_players(num_players: int, spawn_positions: Array = []):
	if not active_level:
		printerr("No active level to spawn players in!")
		return

	# Default spawn positions if none provided
	var default_positions = [
		Vector2(200, 467),   # Player 1
		Vector2(500, 467),   # Player 2
		Vector2(400, 467),   # Player 3
		Vector2(300, 467)    # Player 4
	]
	
	var positions = spawn_positions if spawn_positions.size() >= num_players else default_positions
	var input_devices = assign_player_inputs(num_players)

	# Clear existing players to avoid duplicates
	for player in player_nodes:
		if player and is_instance_valid(player):
			player.queue_free()
	player_nodes.clear()

	# Spawn the requested number of players
	for i in range(num_players):
		var player_index = i + 1
		var player = player_scene.instantiate()
		player.player_index = player_index
		player.global_position = positions[i]
		player.setup_device(input_devices[i])
		active_level.add_child(player)
		player_nodes.append(player)
		
		if hud_instance:
			hud_instance.show_player_hud(player_index)
		
		print("[DEBUG] GameManager: Spawned Player%d at %s with device %d" % [player_index, positions[i], input_devices[i]])

# Helper function to spawn a single additional player (for dynamic player joining)
func spawn_single_player(player_index: int, position: Vector2 = Vector2.ZERO):
	if not active_level:
		printerr("No active level to spawn player in!")
		return
	
	# Check if player already exists
	for p in player_nodes:
		if p.player_index == player_index:
			print("[DEBUG] GameManager: Player%d already exists, skipping spawn" % player_index)
			return
	
	# Calculate total players after adding this one
	var total_players = max(player_nodes.size() + 1, player_index)
	var input_devices = assign_player_inputs(total_players)
	
	# CRITICAL: Update existing players with new device assignments
	for i in range(player_nodes.size()):
		if i < input_devices.size():
			var existing_player = player_nodes[i]
			var new_device = input_devices[i]
			print("[DEBUG] GameManager: Updating Player%d device from %d to %d" % [existing_player.player_index, existing_player.device, new_device])
			existing_player.setup_device(new_device)
	
	# Use default position if none provided
	var spawn_position = position
	if spawn_position == Vector2.ZERO:
		var default_positions = [Vector2(200, 467), Vector2(600, 467), Vector2(400, 467), Vector2(800, 467)]
		spawn_position = default_positions[player_index - 1] if player_index <= 4 else Vector2(400, 467)
	
	var player = player_scene.instantiate()
	player.player_index = player_index
	player.global_position = spawn_position
	player.setup_device(input_devices[player_index - 1])
	active_level.add_child(player)
	player_nodes.append(player)
	
	if hud_instance:
		hud_instance.show_player_hud(player_index)
	
	print("[DEBUG] GameManager: Spawned Player%d at %s with device %d" % [player_index, spawn_position, input_devices[player_index - 1]])

# Helper function to spawn a player with a specific device (controller-initiated joining)
func spawn_single_player_with_device(player_index: int, device_id: int, position: Vector2 = Vector2.ZERO):
	if not active_level:
		printerr("No active level to spawn player in!")
		return
	
	# Check if player already exists
	for p in player_nodes:
		if p.player_index == player_index:
			print("[DEBUG] GameManager: Player%d already exists, skipping spawn" % player_index)
			return
	
	# Check if device is already assigned
	var assigned_devices = get_assigned_devices()
	if device_id in assigned_devices:
		print("[DEBUG] GameManager: Device %d already assigned, cannot spawn player" % device_id)
		return
	
	# Use default position if none provided
	var spawn_position = position
	if spawn_position == Vector2.ZERO:
		var default_positions = [Vector2(200, 467), Vector2(600, 467), Vector2(400, 467), Vector2(800, 467)]
		spawn_position = default_positions[player_index - 1] if player_index <= 4 else Vector2(400, 467)
	
	var player = player_scene.instantiate()
	player.player_index = player_index
	player.global_position = spawn_position
	player.setup_device(device_id)  # Use the specific controller that joined
	active_level.add_child(player)
	player_nodes.append(player)
	
	if hud_instance:
		hud_instance.show_player_hud(player_index)
	
	print("[DEBUG] GameManager: Spawned Player%d at %s with device %d (controller-initiated)" % [player_index, spawn_position, device_id])

func setup_new_gameplay_scene(player_index: int, main_game_node):
	# This function is called by the main_game scene itself once it's ready.
	
	if not main_game_node:
		printerr("setup_new_gameplay_scene called with null node!")
		return

	print("Main Game Scene reported ready, proceeding with setup.")

	# Reset ALL players' scores and lives
	ScoreManager.reset_all_players()
	
	# Clear existing players to prevent duplicates
	for player in player_nodes:
		if player and is_instance_valid(player):
			player.queue_free()
	player_nodes.clear()

	# Find the containers within the provided main_game_node
	var current_scene_container = main_game_node.get_node_or_null("%CurrentScene")
	var ui_container = main_game_node.get_node_or_null("%UI")
	
	if not current_scene_container or not ui_container:
		printerr("Setup: Could not find CurrentScene or UI container nodes in MainGame scene!")
		return

	# Create and add level
	active_level = level_scene.instantiate()
	current_scene_container.add_child(active_level)
	
	# Debug the MultiplayerInput system
	debug_multiplayer_input()
	
	# Spawn Player 1 at start
	spawn_players(1) # Spawn single player with default position
	
	# Create and add HUD
	hud_instance = hud_scene.instantiate()
	ui_container.add_child(hud_instance)
	
	# Find WaveManager within the newly added level
	var wave_manager = active_level.get_node_or_null("WaveManager")
	
	# Pass WaveManager reference to HUD
	if hud_instance.has_method("setup_wave_manager_connection"):
		hud_instance.setup_wave_manager_connection(wave_manager)
	else:
		printerr("Setup: HUD instance does not have setup_wave_manager_connection method!")
		
	# Start first wave
	if wave_manager:
		wave_manager.start_wave(1)
	else:
		printerr("Setup: WaveManager node not found in the loaded level scene!")
	
	if wave_manager and hud_instance: 
		wave_manager.connect("wave_started", Callable(hud_instance, "_on_wave_started"))
	
	# Start background music
	SoundManager.play_music("gameplay") # Use autoload directly
	
	current_state = GameState.PLAYING
	print("Setup complete: Game Started Successfully") # Debug print
	
	# Note: Do NOT clear player_nodes here - we need to track the spawned players for dynamic joining
	# player_nodes already contains the correctly spawned players from spawn_players(1)

func pause_game():
	if current_state == GameState.PLAYING:
		get_tree().paused = true
		current_state = GameState.PAUSED
		
		# Show pause menu - Add it to the UI container of the current scene
		var ui_container = get_tree().current_scene.get_node_or_null("%UI")
		if ui_container:
			var pause_menu = load("res://scenes/ui/pause_menu.tscn").instantiate()
			ui_container.add_child(pause_menu)
			# Connect signals directly here or ensure pause_menu script handles them
			pause_menu.connect("resume", resume_game)
			pause_menu.connect("quit", show_main_menu)
		else:
			printerr("Could not find UI container to add Pause Menu!")
	elif current_state == GameState.PAUSED:
		resume_game()

func resume_game():
	if current_state == GameState.PAUSED:
		# Remove pause menu - Find it within the current scene's UI container
		var ui_container = get_tree().current_scene.get_node_or_null("%UI")
		if ui_container:
			var pause_menu = ui_container.get_node_or_null("PauseMenu") # Assuming node name is PauseMenu
			if pause_menu:
				pause_menu.queue_free()
		else:
			printerr("Could not find UI container to remove Pause Menu!")
		
		get_tree().paused = false
		current_state = GameState.PLAYING

func game_over():
	current_state = GameState.GAME_OVER
	
	# Stop background music
	SoundManager.stop_music() # Use autoload directly
	
	# Play game over sound
	SoundManager.play_sfx("game_over") # Use autoload directly
	
	# Show game over screen - Add it to the UI container of the current scene
	var ui_container = get_tree().current_scene.get_node_or_null("%UI")
	if ui_container:
		# Clear previous UI if any (like HUD)
		for child in ui_container.get_children():
			child.queue_free()
			
		var game_over_instance = game_over_scene.instantiate()
		ui_container.add_child(game_over_instance)
		# Connect signals (assuming game_over script handles this or connect here)
		game_over_instance.connect("restart", start_game)
		game_over_instance.connect("main_menu", show_main_menu)
		# active_ui = game_over_instance # Store reference if needed
	else:
		printerr("Could not find UI container to add Game Over screen!")
	
	# Keep level visible in background but disable processing
	if active_level != null:
		active_level.process_mode = Node.PROCESS_MODE_DISABLED

# Debug function to test MultiplayerInput system
func debug_multiplayer_input():
	print("[DEBUG] === MultiplayerInput System Test ===")
	print("[DEBUG] MultiplayerInput available: ", MultiplayerInput != null)
	
	if MultiplayerInput:
		print("[DEBUG] Core actions: ", MultiplayerInput.core_actions)
		var joypads = Input.get_connected_joypads()
		print("[DEBUG] Connected joypads: ", joypads)
		
		for controller_id in joypads:
			print("[DEBUG] Controller %d device actions: " % controller_id)
			if MultiplayerInput.device_actions.has(controller_id):
				var actions = MultiplayerInput.device_actions[controller_id]
				for action_name in actions:
					print("  - %s -> %s" % [action_name, actions[action_name]])
			else:
				print("  - No actions found for controller %d" % controller_id)
		
		# Test if start_game action exists
		if "start_game" in MultiplayerInput.core_actions:
			print("[DEBUG] start_game is a core action")
		else:
			print("[DEBUG] WARNING: start_game is NOT a core action")
	
	print("[DEBUG] === End Test ===")
