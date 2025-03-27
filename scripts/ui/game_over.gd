extends Control

signal restart
signal main_menu

@onready var score_label = $VBoxContainer/ScoreLabel
@onready var high_score_label = $VBoxContainer/HighScoreLabel

func _ready():
	# Set score values
	var score_manager = get_node("/root/ScoreManager")
	score_label.text = "Final Score: " + str(score_manager.score)
	high_score_label.text = "High Score: " + str(score_manager.high_score)
	
	# Connect button signals
	$VBoxContainer/RestartButton.connect("pressed", _on_restart_pressed)
	$VBoxContainer/MainMenuButton.connect("pressed", _on_main_menu_pressed)
	
	# Play game over music
	get_node("/root/SoundManager").play_music("game_over")
	
	# Animate the game over screen
	modulate = Color(1, 1, 1, 0)  # Start transparent
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 1.0)

func _on_restart_pressed():
	emit_signal("restart")

func _on_main_menu_pressed():
	emit_signal("main_menu")
