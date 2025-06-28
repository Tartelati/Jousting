extends Node

# Signals
signal score_changed(player_index: int, new_score: int)
signal high_score_changed(new_high_score)
signal lives_changed(player_index: int, new_lives: int)
signal bonus_awarded(player_index: int, bonus_amount: int, bonus_type: String)  # NEW

# Properties
var scores = {}
var lives = {}
var high_scores = [
	{"name": "David Lacassagne", "score": 999_999_999}
]
var max_lives = 5
# Track last score threshold for extra life per player
var last_life_score = {}

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
	load_high_scores()

func try_submit_high_score(player_score: int, player_name: String) -> bool:
	# Always keep David at the top
	if player_name == "David Lacassagne":
		return false

	# Add new score and sort
	high_scores.append({"name": player_name, "score": player_score})

	# Sort: David always first, then by score descending
	high_scores.sort_custom(func(a, b):
		if a.name == "David Lacassagne":
			return true
		if b.name == "David Lacassagne":
			return false
		return a.score > b.score
	)

	# Limit to top 10
	if high_scores.size() > 10:
		high_scores = high_scores.slice(0, 10)

	save_high_scores()
	return true

func save_high_scores():
	var save_file = FileAccess.open("user://high_scores.save", FileAccess.WRITE)
	if save_file:
		save_file.store_var(high_scores)

func load_high_scores():
	if FileAccess.file_exists("user://high_scores.save"):
		var save_file = FileAccess.open("user://high_scores.save", FileAccess.READ)
		if save_file:
			high_scores = save_file.get_var()
	# Always ensure David is at the top
	if not high_scores or high_scores[0].name != "David Lacassagne":
		high_scores.insert(0, {"name": "David Lacassagne", "score": 999_999_999})
	# Limit to 10
	if high_scores.size() > 10:
		high_scores = high_scores.slice(0, 10)

func add_score(player_index: int, points_to_add: int):
	if not scores.has(player_index):
		scores[player_index] = 0
	if not lives.has(player_index):
		lives[player_index] = 3
	if not last_life_score.has(player_index):
		last_life_score[player_index] = 0

	scores[player_index] += points_to_add
	emit_signal("score_changed", player_index, scores[player_index])

	# Award extra life every 1000 points, up to max_lives
	var prev_threshold = last_life_score[player_index]
	var new_threshold = int(scores[player_index] / 1000)
	if new_threshold > int(prev_threshold / 1000):
		if lives[player_index] < max_lives:
			lives[player_index] += 1
			emit_signal("lives_changed", player_index, lives[player_index])
		last_life_score[player_index] = new_threshold * 1000

	update_high_scores(player_index)

func update_high_scores(player_index):
	var player_score = scores[player_index]
	var player_name = "Player %d" % player_index

	# Remove any existing entry for this player (except David)
	high_scores = high_scores.filter(func(entry): return entry.name != player_name)

	# Add this player's score if it's not the joke entry
	if player_name != "David Lacassagne":
		high_scores.append({"name": player_name, "score": player_score})

	# Sort descending, keep David at the top
	high_scores.sort_custom(func(a, b):
		if a.name == "David Lacassagne":
			return true
		if b.name == "David Lacassagne":
			return false
		return a.score > b.score
	)

	# Limit to top 5 (including David)
	if high_scores.size() > 5:
		high_scores = high_scores.slice(0, 5)

func reset_score(player_index: int):
	scores[player_index] = 0
	emit_signal("score_changed", player_index, 0)

func lose_life(player_index: int):
	if not lives.has(player_index):
		lives[player_index] = 3
	lives[player_index] -= 1
	emit_signal("lives_changed", player_index, lives[player_index])	   
	
	# Only trigger game over if ALL players have no lives left
	if lives[player_index] <= 0:
		print("[DEBUG] ScoreManager: Player %d has no lives left" % player_index)
		# Check if any other players still have lives
		var any_players_alive = false
		for other_player_index in lives.keys():
			if other_player_index != player_index and lives[other_player_index] > 0:
				any_players_alive = true
				print("[DEBUG] ScoreManager: Player %d still has %d lives" % [other_player_index, lives[other_player_index]])
				break

		if not any_players_alive:
			print("[DEBUG] ScoreManager: All players are out of lives, triggering game over")
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

func add_bonus_score(player_index: int, bonus_amount: int, bonus_type: String = ""):
	scores[player_index] += bonus_amount
	emit_signal("score_changed", player_index, scores[player_index])
	emit_signal("bonus_awarded", player_index, bonus_amount, bonus_type)
	print("[ScoreManager] Player %d awarded %d bonus points (%s)" % [player_index, bonus_amount, bonus_type])
