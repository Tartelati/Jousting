extends Node

var player_scene = preload("res://scenes/entities/player.tscn")
var player_nodes = [] # Store references to player instances

enum GameState {MAIN_MENU, PLAYING, PAUSED, GAME_OVER}

var current_state = GameState.MAIN_MENU
var current_level = null
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

func _input(event):
	if event.is_action_pressed("pause") and current_state == GameState.PLAYING:
		pause_game()
 # Listen for "start_game" to add Player 2
	if event.is_action_pressed("start_game") and current_state == GameState.PLAYING:
		if player_nodes.size() < 2:
			spawn_players(2, Vector2(600, 467)) # Adjust spawn position as needed

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

func spawn_players(player_index: int, position: Vector2):
	if not active_level:
		printerr("No active level to spawn players in!")
		return
	# Prevent duplicate players
	for p in player_nodes:
		if p.player_index == player_index:
			return
	var player = player_scene.instantiate()
	player.get_node("PlayerBody").player_index = player_index
	player.global_position = position
	active_level.add_child(player)
	player_nodes.append(player)

func setup_new_gameplay_scene(main_game_node):
	# This function is called by the main_game scene itself once it's ready.
	
	if not main_game_node:
		printerr("setup_new_gameplay_scene called with null node!")
		return

	print("Main Game Scene reported ready, proceeding with setup.")

	# Reset score and lives
	ScoreManager.reset_score()
	ScoreManager.reset_lives()

	# Find the containers within the provided main_game_node
	var current_scene_container = main_game_node.get_node_or_null("%CurrentScene")
	var ui_container = main_game_node.get_node_or_null("%UI")
	
	if not current_scene_container or not ui_container:
		printerr("Setup: Could not find CurrentScene or UI container nodes in MainGame scene!")
		return

	# Create and add level
	active_level = level_scene.instantiate()
	current_scene_container.add_child(active_level)
	
	# Spawn Player 1 at start
	spawn_players(1, Vector2(200, 467)) # Adjust spawn position as needed
	
	# Create and add HUD
	var hud_instance = hud_scene.instantiate()
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
	
	# Start background music
	SoundManager.play_music("gameplay") # Use autoload directly
	
	current_state = GameState.PLAYING
	print("Setup complete: Game Started Successfully") # Debug print

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
