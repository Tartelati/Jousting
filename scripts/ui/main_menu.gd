extends Control

signal start_game
signal show_options
signal quit_game

func _ready():
	# Connect button signals
	$VBoxContainer/StartGameButton.connect("pressed", _on_start_game_pressed)
	$VBoxContainer/OptionsButton.connect("pressed", _on_options_pressed)
	$VBoxContainer/QuitButton.connect("pressed", _on_quit_pressed)
	
	# Start background music
	get_node("/root/SoundManager").play_music("menu")

func _on_start_game_pressed():
	# Stop the music when starting the game
	get_node("/root/SoundManager").stop_music()
	# Call GameManager directly instead of emitting a signal
	GameManager.start_game() 
	# emit_signal("start_game") # No longer needed

func _on_options_pressed():
	emit_signal("show_options")
	
	# Create and show options menu
	var options_menu = load("res://scenes/ui/options_menu.tscn").instantiate()
	add_child(options_menu)
	options_menu.connect("closed", func(): options_menu.queue_free())

func _on_quit_pressed():
	emit_signal("quit_game")
	get_tree().quit()
