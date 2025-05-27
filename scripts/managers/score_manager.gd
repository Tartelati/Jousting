extends Node

# Signals
signal score_changed(player_index, new_score)
signal high_score_changed(new_high_score)
signal lives_changed(player_index, new_lives)

# Properties
var scores = {}
var lives = {}
var high_score = 0
var max_lives = 5

# Points values for different actions
var points = {
	"enemy_basic": 100,
	"enemy_hunter": 200,
	"shadow_lord": 150,
	"pterodactyl": 1000,
	"egg_collect": 50,
	"wave_complete": 100
}

func _ready():
	load_high_score()

func add_score(player_index: int, points_to_add: int):
	if not scores.has(player_index):
		scores[player_index] = 0
	if not lives.has(player_index):
		lives[player_index] = 3
	scores[player_index] += points_to_add
	emit_signal("score_changed", player_index, scores[player_index])

	# Check for high score
	if scores[player_index] > high_score:
		high_score = scores[player_index]
		emit_signal("high_score_changed", high_score)
		save_high_score()

	# Award extra life every 10,000 points
	if int(scores[player_index] / 10000) > int((scores[player_index] - points_to_add) / 10000):
		gain_life(player_index)

func reset_score(player_index: int):
	scores[player_index] = 0
	emit_signal("score_changed", player_index, 0)

func lose_life(player_index: int):
	if not lives.has(player_index):
		lives[player_index] = 3
	lives[player_index] -= 1
	emit_signal("lives_changed", player_index, lives[player_index])
	if lives[player_index] <= 0:
		var game_manager = get_node_or_null("/root/GameManager")
		if game_manager:
			game_manager.game_over()

func gain_life(player_index: int):
	if not lives.has(player_index):
		lives[player_index] = 3
	if lives[player_index] < max_lives:
		lives[player_index] += 1
		emit_signal("lives_changed", player_index, lives[player_index])

func reset_lives(player_index: int):
	lives[player_index] = 3
	emit_signal("lives_changed", player_index, 3)

func get_score(player_index: int) -> int:
	return scores.get(player_index, 0)

func get_lives(player_index: int) -> int:
	return lives.get(player_index, 3)

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
