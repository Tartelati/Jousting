extends Node

# Signals
signal score_changed(new_score)
signal high_score_changed(new_high_score)
signal lives_changed(new_lives)

# Properties
var score = 0
var high_score = 0
var lives = 3
var max_lives = 5

# Points values for different actions
var points = {
	"enemy_basic": 100,
	"enemy_hunter": 200,
	"enemy_bounder": 150,
	"pterodactyl": 1000,
	"egg_collect": 50,
	"wave_complete": 100  # Per wave number (wave 3 = 300 points)
}

func _ready():
	# Load high score from save file if it exists
	load_high_score()

func add_score(points_to_add):
	score += points_to_add
	emit_signal("score_changed", score)
	
	# Check for high score
	if score > high_score:
		high_score = score
		emit_signal("high_score_changed", high_score)
		save_high_score()
	
	# Award extra life every 10,000 points
	if int(score / 10000) > int((score - points_to_add) / 10000):
		gain_life()

func reset_score():
	score = 0
	emit_signal("score_changed", score)

func lose_life():
	lives -= 1
	emit_signal("lives_changed", lives)
	
	# Check for game over
	if lives <= 0:
		# Get reference to GameManager and call game_over
		var game_manager = get_node_or_null("/root/GameManager")
		if game_manager:
			game_manager.game_over()

func gain_life():
	if lives < max_lives:
		lives += 1
		emit_signal("lives_changed", lives)

func reset_lives():
	lives = 3
	emit_signal("lives_changed", lives)

func save_high_score():
	var save_file = FileAccess.open("user://high_score.save", FileAccess.WRITE)
	if save_file:
		save_file.store_var(high_score)

func load_high_score():
	if FileAccess.file_exists("user://high_score.save"):
		var save_file = FileAccess.open("user://high_score.save", FileAccess.READ)
		if save_file:
			high_score = save_file.get_var()
			emit_signal("high_score_changed", high_score)
