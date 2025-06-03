extends Control

signal restart
signal main_menu

@onready var score_label = $VBoxContainer/ScoreLabel
@onready var high_score_label = $VBoxContainer/HighScoreLabel


func _ready():
	# Set score values
	var score_manager = get_node("/root/ScoreManager")
	var final_score = 0
	for s in score_manager.scores.values():
		if s > final_score:
			final_score = s
	
	var qualifies = false
	if score_manager.high_scores.size() < 10:
		qualifies = true
	else:
		for i in range(1, score_manager.high_scores.size()): # skip David at 0
			if final_score > score_manager.high_scores[i].score:
				qualifies = true
				break
				
	if qualifies:
		$VBoxContainer/NameEntry.show()
		$VBoxContainer/SubmitNameButton.show()
		$VBoxContainer/SubmitNameButton.connect("pressed", _on_submit_name_pressed)
	
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

func _on_submit_name_pressed(final_score):
	var player_name = $VBoxContainer/NameEntry.text.strip_edges()
	if player_name == "":
		player_name = "Anonymous"
	var score_manager = get_node("/root/ScoreManager")
	score_manager.try_submit_high_score(final_score, player_name)
	$VBoxContainer/NameEntry.hide()
	$VBoxContainer/SubmitNameButton.hide()
	# Optionally, refresh the high score display here
