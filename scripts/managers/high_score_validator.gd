class_name HighScoreValidator
extends RefCounted

# Constants for validation
const MAX_PLAYER_NAME_LENGTH = 20
const MIN_SCORE = 0
const MAX_REASONABLE_SCORE = 99_999_999
const ALLOWED_NAME_PATTERN = "[^a-zA-Z0-9 ]"  # Pattern to remove invalid characters

# Validation result structure
class ValidationResult:
	var valid: bool = false
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var sanitized_data: Dictionary = {}
	
	func _init(is_valid: bool = false):
		valid = is_valid

# Score validation methods
func is_valid_score(score: int) -> bool:
	"""Check if a score is within valid range"""
	return score >= MIN_SCORE and score <= MAX_REASONABLE_SCORE

func is_reasonable_score(score: int, game_duration: float = 0.0) -> bool:
	"""Check if a score is reasonable given game context"""
	if not is_valid_score(score):
		return false
	
	# If game duration is provided, check for impossibly high scores
	if game_duration > 0.0:
		# Assume maximum possible points per second (very generous estimate)
		var max_points_per_second = 10000
		var theoretical_max = game_duration * max_points_per_second
		if score > theoretical_max:
			return false
	
	return true

func sanitize_player_name(name: String) -> String:
	"""Clean and format player name according to requirements"""
	if name.is_empty():
		return "Anonymous"
	
	# Remove invalid characters (keep only alphanumeric and spaces)
	var regex = RegEx.new()
	regex.compile(ALLOWED_NAME_PATTERN)
	var sanitized = regex.sub(name, "", true)
	
	# Trim whitespace
	sanitized = sanitized.strip_edges()
	
	# If empty after sanitization, use default
	if sanitized.is_empty():
		return "Anonymous"
	
	# Truncate to maximum length
	if sanitized.length() > MAX_PLAYER_NAME_LENGTH:
		sanitized = sanitized.substr(0, MAX_PLAYER_NAME_LENGTH)
	
	# Ensure it's not just spaces
	if sanitized.strip_edges().is_empty():
		return "Anonymous"
	
	return sanitized

# Data integrity validation
func validate_high_score_entry(entry: Dictionary) -> ValidationResult:
	"""Validate a single high score entry"""
	var result = ValidationResult.new()
	var sanitized = entry.duplicate()
	
	# Check required fields
	if not entry.has("name"):
		result.errors.append("Missing required field: name")
	else:
		var original_name = str(entry.name)
		sanitized.name = sanitize_player_name(original_name)
		if sanitized.name != original_name:
			result.warnings.append("Player name was sanitized from '%s' to '%s'" % [original_name, sanitized.name])
	
	if not entry.has("score"):
		result.errors.append("Missing required field: score")
	else:
		var score = entry.score
		if not (score is int):
			# Try to convert to int
			if score is String and score.is_valid_int():
				sanitized.score = score.to_int()
				result.warnings.append("Score converted from string to integer")
			else:
				result.errors.append("Score must be an integer")
		else:
			if not is_valid_score(score):
				if score < MIN_SCORE:
					result.errors.append("Score cannot be negative")
				else:
					result.errors.append("Score exceeds maximum reasonable value")
	
	# Validate optional fields
	if entry.has("date"):
		if not _is_valid_date_string(str(entry.date)):
			result.warnings.append("Invalid date format, will use current date")
			sanitized.date = Time.get_date_string_from_system()
	else:
		sanitized.date = Time.get_date_string_from_system()
	
	if entry.has("timestamp"):
		if not (entry.timestamp is int) or entry.timestamp < 0:
			result.warnings.append("Invalid timestamp, will use current time")
			sanitized.timestamp = Time.get_unix_time_from_system()
	else:
		sanitized.timestamp = Time.get_unix_time_from_system()
	
	# Set player_index if missing
	if not entry.has("player_index"):
		sanitized.player_index = 1
		result.warnings.append("Missing player_index, defaulting to 1")
	
	# Set session_id if missing
	if not entry.has("session_id"):
		sanitized.session_id = _generate_session_id()
		result.warnings.append("Missing session_id, generated new one")
	
	# Set version if missing
	if not entry.has("version"):
		sanitized.version = "1.1.0"
		result.warnings.append("Missing version, defaulting to 1.1.0")
	else:
		# Validate version format
		if not _is_valid_version_string(str(entry.version)):
			result.warnings.append("Invalid version format, keeping as-is for migration tracking")
	
	# Handle migration-related fields
	if entry.has("migration_source"):
		sanitized.migration_source = str(entry.migration_source)
	
	if entry.has("migration_timestamp"):
		if not (entry.migration_timestamp is int) or entry.migration_timestamp < 0:
			result.warnings.append("Invalid migration timestamp")
		else:
			sanitized.migration_timestamp = entry.migration_timestamp
	
	result.sanitized_data = sanitized
	result.valid = result.errors.is_empty()
	
	return result

func validate_high_score_list(scores: Array[Dictionary]) -> ValidationResult:
	"""Validate an entire high score list"""
	var result = ValidationResult.new(true)
	var sanitized_scores: Array[Dictionary] = []
	
	for i in range(scores.size()):
		var entry_result = validate_high_score_entry(scores[i])
		
		if entry_result.valid:
			sanitized_scores.append(entry_result.sanitized_data)
		else:
			result.valid = false
			for error in entry_result.errors:
				result.errors.append("Entry %d: %s" % [i, error])
		
		# Collect warnings
		for warning in entry_result.warnings:
			result.warnings.append("Entry %d: %s" % [i, warning])
	
	# Check for duplicate entries (same name and score)
	var seen_entries = {}
	var filtered_scores: Array[Dictionary] = []
	
	for entry in sanitized_scores:
		var key = "%s_%d" % [entry.name, entry.score]
		if key in seen_entries:
			result.warnings.append("Duplicate entry removed: %s with score %d" % [entry.name, entry.score])
		else:
			seen_entries[key] = true
			filtered_scores.append(entry)
	
	result.sanitized_data = {"scores": filtered_scores}
	
	return result

# Private helper methods
func _is_valid_date_string(date_str: String) -> bool:
	"""Check if date string is in valid ISO format (YYYY-MM-DD)"""
	var regex = RegEx.new()
	regex.compile("^\\d{4}-\\d{2}-\\d{2}$")
	return regex.search(date_str) != null

func _is_valid_version_string(version_str: String) -> bool:
	"""Check if version string is in valid format (X.Y.Z or migration format)"""
	# Allow standard version format (X.Y.Z)
	var version_regex = RegEx.new()
	version_regex.compile("^\\d+\\.\\d+(\\.\\d+)?$")
	if version_regex.search(version_str) != null:
		return true
	
	# Allow migration format (migrated_from_X)
	var migration_regex = RegEx.new()
	migration_regex.compile("^migrated_from_")
	if migration_regex.search(version_str) != null:
		return true
	
	return false

func _generate_session_id() -> String:
	"""Generate a unique session identifier"""
	var time = Time.get_unix_time_from_system()
	var random = randi()
	return "%d_%d" % [time, random]

# Utility methods for common validation scenarios
func validate_score_submission(player_name: String, score: int, player_index: int = 1) -> ValidationResult:
	"""Validate a new score submission"""
	var entry = {
		"name": player_name,
		"score": score,
		"player_index": player_index,
		"date": Time.get_date_string_from_system(),
		"timestamp": Time.get_unix_time_from_system(),
		"session_id": _generate_session_id(),
		"version": "1.1.0"
	}
	
	return validate_high_score_entry(entry)

# Migration-specific validation methods
func validate_migrated_entry(entry: Dictionary, source_version: String) -> ValidationResult:
	"""Validate an entry that has been migrated from an older version"""
	var result = validate_high_score_entry(entry)
	
	# Add migration-specific validation
	if not entry.has("migration_source"):
		result.sanitized_data.migration_source = source_version
		result.warnings.append("Added migration source: %s" % source_version)
	
	if not entry.has("migration_timestamp"):
		result.sanitized_data.migration_timestamp = Time.get_unix_time_from_system()
		result.warnings.append("Added migration timestamp")
	
	# Update version to indicate migration
	if not result.sanitized_data.version.begins_with("migrated_from_"):
		result.sanitized_data.version = "migrated_from_%s" % source_version
	
	return result

func validate_migration_compatibility(old_version: String, new_version: String) -> bool:
	"""Check if migration from old version to new version is supported"""
	# Define supported migration paths
	var supported_migrations = {
		"legacy": ["1.0", "1.1"],
		"1.0": ["1.1"],
		"1.1": []  # Current version, no migration needed
	}
	
	if not supported_migrations.has(old_version):
		return false
	
	return new_version in supported_migrations[old_version]

func is_score_improvement(new_score: int, existing_scores: Array[Dictionary], player_name: String) -> bool:
	"""Check if the new score is an improvement over existing scores for the same player"""
	for entry in existing_scores:
		if entry.name == player_name:
			return new_score > entry.score
	return true  # No existing score, so any score is an improvement