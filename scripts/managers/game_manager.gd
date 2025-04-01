extends Node

enum GameState {MAIN_MENU, PLAYING, PAUSED, GAME_OVER}

var current_state = GameState.MAIN_MENU
var current_level = null
var main_menu_scene = preload("res://scenes/ui/main_menu.tscn")
var game_over_scene = preload("res://scenes/ui/game_over.tscn")
var level_scene = preload("res://scenes/levels/level_base.tscn")
var hud_scene = preload("res://scenes/ui/hud.tscn")
var debug_overlay_scene = preload("res://scenes/debug/debug_overlay.tscn")

# References to active scenes
var active_ui = null
var active_level = null

func _ready():
	# Start with main menu
	show_main_menu()
	
	# Connect to input events for pause
	process_mode = Node.PROCESS_MODE_ALWAYS  # Ensure this node processes even when game is paused
	# Add debug overlay if we're in development mode
	if OS.has_feature("editor") or OS.is_debug_build():
		var debug_overlay = debug_overlay_scene.instantiate()
		add_child(debug_overlay)

func _input(event):
	if event.is_action_pressed("pause") and current_state == GameState.PLAYING:
		pause_game()

func show_main_menu():
	# Clear any existing UI
	if active_ui != null:
		active_ui.queue_free()
	
	# Clear any existing level
	if active_level != null:
		active_level.queue_free()
		active_level = null
	
	# Show main menu
	active_ui = main_menu_scene.instantiate()
	get_node("/root/Main/UI").add_child(active_ui)
	
	# Connect signals
	active_ui.connect("start_game", start_game)
	
	current_state = GameState.MAIN_MENU

func start_game():
	# Clear main menu
	if active_ui != null:
		active_ui.queue_free()
	
	# Reset score and lives
	get_node("/root/ScoreManager").reset_score()
	get_node("/root/ScoreManager").reset_lives()
	
	# Create level
	active_level = level_scene.instantiate()
	get_node("/root/Main/CurrentScene").add_child(active_level)
	
	# Create HUD
	active_ui = hud_scene.instantiate()
	get_node("/root/Main/UI").add_child(active_ui)
	
	# Start first wave
	active_level.get_node("WaveManager").start_wave(1)
	
	# Start background music
	get_node("/root/SoundManager").play_music("gameplay")
	
	current_state = GameState.PLAYING

func pause_game():
	if current_state == GameState.PLAYING:
		get_tree().paused = true
		current_state = GameState.PAUSED
		
		# Show pause menu
		var pause_menu = load("res://scenes/ui/pause_menu.tscn").instantiate()
		get_node("/root/Main/UI").add_child(pause_menu)
		pause_menu.connect("resume", resume_game)
		pause_menu.connect("quit", show_main_menu)
	elif current_state == GameState.PAUSED:
		resume_game()

func resume_game():
	if current_state == GameState.PAUSED:
		# Remove pause menu
		var pause_menu = get_node("/root/Main/UI").get_node("PauseMenu")
		if pause_menu:
			pause_menu.queue_free()
		
		get_tree().paused = false
		current_state = GameState.PLAYING

func game_over():
	current_state = GameState.GAME_OVER
	
	# Stop background music
	get_node("/root/SoundManager").stop_music()
	
	# Play game over sound
	get_node("/root/SoundManager").play_sfx("game_over")
	
	# Show game over screen
	if active_ui != null:
		active_ui.queue_free()
	
	active_ui = game_over_scene.instantiate()
	get_node("/root/Main/UI").add_child(active_ui)
	
	# Connect signals
	active_ui.connect("restart", start_game)
	active_ui.connect("main_menu", show_main_menu)
	
	# Keep level visible in background but disable processing
	if active_level != null:
		active_level.process_mode = Node.PROCESS_MODE_DISABLED
