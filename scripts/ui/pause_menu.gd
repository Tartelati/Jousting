extends Control

signal resume
signal options
signal quit

func _ready():
	# Connect button signals
	$VBoxContainer/ResumeButton.connect("pressed", _on_resume_pressed)
	$VBoxContainer/OptionsButton.connect("pressed", _on_options_pressed)
	$VBoxContainer/QuitButton.connect("pressed", _on_quit_pressed)

func _on_resume_pressed():
	emit_signal("resume")

func _on_options_pressed():
	emit_signal("options")
	
	# Create and show options menu
	var options_menu = load("res://scenes/ui/options_menu.tscn").instantiate()
	add_child(options_menu)
	options_menu.connect("closed", func(): options_menu.queue_free())

func _on_quit_pressed():
	emit_signal("quit")
