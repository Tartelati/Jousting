extends Node

# Signals
signal score_changed(player_index: int, new_score: int)
signal high_score_changed(new_high_score)
signal lives_changed(player_index: int, new_lives: int)
signal bonus_awarded(player_index: int, bonus_amount: int, bonus_type: String, world_position: Vector2)  # NEW with world position

# New signals for enhanced high score system
signal high_score_saved(player_name: String, score: int, rank: int)
signal save_error(error_message: String)
signal personal_best_achieved(player_index: int, previous_best: int)

# Properties
var scores = {}
var lives = {}
var high_scores = [
	{"name": "David Lacassagne", "score": 999_999_999}
]
var max_lives = 5
# Track last score threshold for extra life per player
var last_life_score = {}

# Enhanced high score system components
var storage: HighScoreStorage
var validator: HighScoreValidator
var config: Dictionary = {
	"max_high_scores": 10,
	"save_location": "user://high_scores.save",
	"backup_enabled": true,
	"auto_save": true,
	"validation_strict": false,
	"debug_logging": false
}

# Session tracking
var current_session_id: String
var session_scores: Dictionary = {}  # Track scores achieved this session

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
	initialize_enhanced_system()
	load_high_scores()

func try_submit_high_score(player_score: int, player_name: String) -> bool:
	"""Legacy method for backward compatibility - now uses enhanced system"""
	# Always keep David at the top
	if player_name == "David Lacassagne":
		return false
	
	# Use enhanced submission system if available
	if storage and validator:
		# Find player index (default to 1 for legacy calls)
		var player_index = 1
		for index in scores.keys():
			if scores[index] == player_score:
				player_index = index
				break
		
		var result = submit_high_score(player_index, player_name)
		return result.success
	else:
		# Fallback to legacy behavior
		return _legacy_submit_high_score(player_score, player_name)

func _legacy_submit_high_score(player_score: int, player_name: String) -> bool:
	"""Legacy high score submission logic"""
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
	"""Save high scores using enhanced storage system with fallback"""
	if storage and config.auto_save:
		var result = storage.save_high_scores(high_scores)
		if result != HighScoreStorage.StorageError.SUCCESS:
			handle_save_error(result)
			# Fallback to legacy save
			_save_legacy_high_scores()
	else:
		# Fallback to legacy save
		_save_legacy_high_scores()

func _save_legacy_high_scores():
	"""Save high scores using legacy file system (fallback)"""
	var save_file = FileAccess.open("user://high_scores.save", FileAccess.WRITE)
	if save_file:
		save_file.store_var(high_scores)
		save_file.close()
		if config.debug_logging:
			print("[ScoreManager] Saved high scores using legacy format")

func load_high_scores():
	"""Load high scores using enhanced storage system with fallback to legacy"""
	if storage:
		# Use enhanced storage system
		var loaded_scores = storage.load_high_scores()
		
		if loaded_scores.size() > 0:
			# Validate loaded scores
			var validation_result = validator.validate_high_score_list(loaded_scores)
			
			if validation_result.valid:
				high_scores = validation_result.sanitized_data.scores
				if config.debug_logging:
					print("[ScoreManager] Loaded %d high scores from enhanced storage" % high_scores.size())
			else:
				if config.debug_logging:
					print("[ScoreManager] Loaded scores failed validation, using defaults")
				_initialize_default_high_scores()
		else:
			# Try legacy load as fallback
			_load_legacy_high_scores()
	else:
		# Fallback to legacy loading
		_load_legacy_high_scores()
	
	# Always ensure David is at the top and limit size
	_ensure_david_and_limit()

func _load_legacy_high_scores():
	"""Load high scores using legacy file system (fallback)"""
	if FileAccess.file_exists("user://high_scores.save"):
		var save_file = FileAccess.open("user://high_scores.save", FileAccess.READ)
		if save_file:
			var loaded_data = save_file.get_var()
			save_file.close()
			
			# Handle different legacy formats
			if loaded_data is Array:
				high_scores = loaded_data
			elif loaded_data is Dictionary and loaded_data.has("scores"):
				high_scores = loaded_data.scores
			else:
				_initialize_default_high_scores()
				
			if config.debug_logging:
				print("[ScoreManager] Loaded %d high scores from legacy format" % high_scores.size())
	else:
		_initialize_default_high_scores()

func _initialize_default_high_scores():
	"""Initialize with default high scores"""
	high_scores = [
		{"name": "David Lacassagne", "score": 999_999_999, "date": "2024-01-01", "timestamp": 0, "player_index": 1, "session_id": "default", "version": "1.1.0"}
	]

func _ensure_david_and_limit():
	"""Ensure David is at the top and limit list size"""
	# Always ensure David is at the top
	if not high_scores or high_scores[0].name != "David Lacassagne":
		# Remove any existing David entry
		high_scores = high_scores.filter(func(entry): return entry.name != "David Lacassagne")
		# Add David at the top
		high_scores.insert(0, {"name": "David Lacassagne", "score": 999_999_999, "date": "2024-01-01", "timestamp": 0, "player_index": 1, "session_id": "default", "version": "1.1.0"})
	
	# Limit to configured max
	if high_scores.size() > config.max_high_scores:
		high_scores = high_scores.slice(0, config.max_high_scores)

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

	# Check for automatic high score qualification
	if config.auto_save and is_qualifying_score(scores[player_index]):
		_check_auto_high_score_save(player_index)
	
	update_high_scores(player_index)

func _check_auto_high_score_save(player_index: int):
	"""Check if player's score qualifies for automatic high score save"""
	var current_score = scores[player_index]
	
	# Only auto-save if this is a significant improvement or new qualifying score
	var player_name = "Player %d" % player_index
	var existing_best = _get_player_best_score(player_name)
	
	# Auto-save if no existing score or significant improvement (10% better)
	if existing_best == -1 or current_score > existing_best * 1.1:
		if config.debug_logging:
			print("[ScoreManager] Auto-saving qualifying score for Player %d: %d" % [player_index, current_score])
		
		# This will be handled by the game over screen for name entry
		# Just ensure the score is tracked for potential submission

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
	
	# Only trigger game over if ALL active players have no lives left
	if lives[player_index] <= 0:
		print("[DEBUG] ScoreManager: Player %d has no lives left" % player_index)
		
		# Get all active players from GameManager instead of just lives.keys()
		var game_manager = get_node_or_null("/root/GameManager")
		if not game_manager:
			return
			
		var any_players_alive = false
		for player in game_manager.player_nodes:
			if player and is_instance_valid(player):
				var other_player_index = player.player_index
				if other_player_index != player_index:
					var other_player_lives = get_lives(other_player_index)
					if other_player_lives > 0:
						any_players_alive = true
						print("[DEBUG] ScoreManager: Player %d still has %d lives" % [other_player_index, other_player_lives])
						break

		if not any_players_alive:
			print("[DEBUG] ScoreManager: All players are out of lives, triggering game over")
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

func add_bonus_score(player_index: int, bonus_amount: int, bonus_type: String = "", world_position: Vector2 = Vector2.ZERO):
	scores[player_index] += bonus_amount
	emit_signal("score_changed", player_index, scores[player_index])
	emit_signal("bonus_awarded", player_index, bonus_amount, bonus_type, world_position)
	print("[ScoreManager] Player %d awarded %d bonus points (%s) at %s" % [player_index, bonus_amount, bonus_type, world_position])

func reset_all_players():
	# Reset all existing player data
	for player_index in scores.keys():
		scores[player_index] = 0
		lives[player_index] = 3
		last_life_score[player_index] = 0
		emit_signal("score_changed", player_index, 0)
		emit_signal("lives_changed", player_index, 3)
	
	# Also clear the dictionaries completely for a fresh start
	scores.clear()
	lives.clear()
	last_life_score.clear()
	session_scores.clear()
	
	print("[DEBUG] ScoreManager: All players reset")

# ENHANCED HIGH SCORE SYSTEM METHODS

func initialize_enhanced_system():
	"""Initialize the enhanced high score system with storage and validation"""
	# Generate unique session ID
	current_session_id = _generate_session_id()
	
	# Initialize storage with configuration
	storage = HighScoreStorage.new(config)
	
	# Initialize validator
	validator = HighScoreValidator.new()
	
	if config.debug_logging:
		print("[ScoreManager] Enhanced high score system initialized with session ID: %s" % current_session_id)

func initialize_with_config(new_config: Dictionary):
	"""Initialize system with custom configuration"""
	# Merge with defaults
	for key in new_config:
		config[key] = new_config[key]
	
	# Reinitialize components if they exist
	if storage:
		storage = HighScoreStorage.new(config)

func set_max_high_scores(count: int):
	"""Set maximum number of high scores to maintain"""
	config.max_high_scores = count

func submit_high_score(player_index: int, player_name: String) -> Dictionary:
	"""Submit a high score with enhanced validation and persistence"""
	var player_score = get_score(player_index)
	
	# Validate the submission
	var validation_result = validator.validate_score_submission(player_name, player_score, player_index)
	
	if not validation_result.valid:
		var error_msg = "Invalid high score submission: " + ", ".join(validation_result.errors)
		emit_signal("save_error", error_msg)
		return {
			"success": false,
			"rank": -1,
			"is_personal_best": false,
			"previous_score": 0,
			"message": error_msg
		}
	
	# Use sanitized data
	var sanitized_entry = validation_result.sanitized_data
	sanitized_entry.session_id = current_session_id
	
	# Check if this is a qualifying score
	if not is_qualifying_score(player_score):
		return {
			"success": false,
			"rank": -1,
			"is_personal_best": false,
			"previous_score": 0,
			"message": "Score does not qualify for high score list"
		}
	
	# Check for personal best
	var previous_best = _get_player_best_score(sanitized_entry.name)
	var is_personal_best = previous_best == -1 or player_score > previous_best
	
	# Add to high scores list
	var updated_scores = _add_score_to_list(sanitized_entry)
	var rank = _get_score_rank(player_score, updated_scores)
	
	# Save to storage with error handling
	var save_result = _save_high_scores_with_retry(updated_scores)
	
	if save_result:
		high_scores = updated_scores
		session_scores[player_index] = sanitized_entry
		
		# Emit success signals
		emit_signal("high_score_saved", sanitized_entry.name, player_score, rank)
		if is_personal_best and previous_best != -1:
			emit_signal("personal_best_achieved", player_index, previous_best)
		
		return {
			"success": true,
			"rank": rank,
			"is_personal_best": is_personal_best,
			"previous_score": previous_best,
			"message": "High score saved successfully!"
		}
	else:
		emit_signal("save_error", "Failed to save high score to storage")
		return {
			"success": false,
			"rank": rank,
			"is_personal_best": is_personal_best,
			"previous_score": previous_best,
			"message": "Score qualified but save failed - continuing with in-memory scores"
		}

func get_formatted_high_scores() -> Array[Dictionary]:
	"""Get high scores with enhanced formatting and metadata"""
	var formatted_scores: Array[Dictionary] = []
	
	for i in range(high_scores.size()):
		var entry = high_scores[i]
		var formatted_entry = {
			"rank": i + 1,
			"name": entry.name,
			"score": entry.score,
			"formatted_score": _format_score(entry.score),
			"date": entry.get("date", "Unknown"),
			"is_current_session": _is_current_session_score(entry),
			"player_index": entry.get("player_index", 1)
		}
		formatted_scores.append(formatted_entry)
	
	return formatted_scores

func is_qualifying_score(score: int) -> bool:
	"""Check if a score qualifies for the high score list"""
	if high_scores.size() < config.max_high_scores:
		return true
	
	# Check if score is higher than the lowest high score
	var lowest_score = high_scores[high_scores.size() - 1].score
	return score > lowest_score

func get_player_rank(score: int) -> int:
	"""Get the rank a score would have in the current high score list"""
	return _get_score_rank(score, high_scores)

func validate_player_name(name: String) -> String:
	"""Validate and sanitize player name"""
	return validator.sanitize_player_name(name)

func handle_save_error(error: HighScoreStorage.StorageError):
	"""Handle storage errors with appropriate user feedback"""
	var error_message = ""
	
	match error:
		HighScoreStorage.StorageError.PERMISSION_DENIED:
			error_message = "Cannot save high scores: Permission denied"
		HighScoreStorage.StorageError.DISK_FULL:
			error_message = "Cannot save high scores: Disk full"
		HighScoreStorage.StorageError.CORRUPTION_DETECTED:
			error_message = "High score file corrupted, attempting recovery"
		_:
			error_message = "Failed to save high scores: Unknown error"
	
	emit_signal("save_error", error_message)
	
	if config.debug_logging:
		print("[ScoreManager] Storage error: %s" % error_message)

# PRIVATE HELPER METHODS

func _generate_session_id() -> String:
	"""Generate unique session identifier"""
	var time = Time.get_unix_time_from_system()
	var random = randi()
	return "%d_%d" % [time, random]

func _get_player_best_score(player_name: String) -> int:
	"""Get the best score for a specific player, -1 if not found"""
	for entry in high_scores:
		if entry.name == player_name:
			return entry.score
	return -1

func _add_score_to_list(new_entry: Dictionary) -> Array[Dictionary]:
	"""Add new score entry to high scores list and maintain sorting"""
	var updated_scores = high_scores.duplicate(true)
	
	# Remove existing entry for this player (except David)
	if new_entry.name != "David Lacassagne":
		updated_scores = updated_scores.filter(func(entry): return entry.name != new_entry.name)
	
	# Add new entry
	updated_scores.append(new_entry)
	
	# Sort: David always first, then by score descending
	updated_scores.sort_custom(func(a, b):
		if a.name == "David Lacassagne":
			return true
		if b.name == "David Lacassagne":
			return false
		return a.score > b.score
	)
	
	# Limit to max high scores
	if updated_scores.size() > config.max_high_scores:
		updated_scores = updated_scores.slice(0, config.max_high_scores)
	
	return updated_scores

func _get_score_rank(score: int, score_list: Array[Dictionary]) -> int:
	"""Get the rank of a score in the given list"""
	for i in range(score_list.size()):
		if score_list[i].score <= score:
			return i + 1
	return score_list.size() + 1

func _format_score(score: int) -> String:
	"""Format score with thousands separators"""
	var score_str = str(score)
	var formatted = ""
	var count = 0
	
	for i in range(score_str.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			formatted = "," + formatted
		formatted = score_str[i] + formatted
		count += 1
	
	return formatted

func _is_current_session_score(entry: Dictionary) -> bool:
	"""Check if a score entry is from the current session"""
	return entry.get("session_id", "") == current_session_id

func _save_high_scores_with_retry(scores_to_save: Array[Dictionary]) -> bool:
	"""Save high scores with retry logic and error handling"""
	if not config.auto_save:
		return true  # Skip saving if auto-save is disabled
	
	var max_retries = 3
	var retry_count = 0
	
	while retry_count < max_retries:
		var result = storage.save_high_scores(scores_to_save)
		
		if result == HighScoreStorage.StorageError.SUCCESS:
			return true
		
		# Handle specific errors
		handle_save_error(result)
		
		# Don't retry for certain errors
		if result == HighScoreStorage.StorageError.PERMISSION_DENIED:
			break
		
		retry_count += 1
		
		if config.debug_logging:
			print("[ScoreManager] Save attempt %d failed, retrying..." % retry_count)
	
	# All retries failed
	if config.debug_logging:
		print("[ScoreManager] All save attempts failed, disabling auto-save")
	
	config.auto_save = false
	return false
