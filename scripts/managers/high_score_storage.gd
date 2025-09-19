class_name HighScoreStorage
extends RefCounted

# Configuration
var save_file_path: String = "user://high_scores.save"
var backup_file_path: String = "user://high_scores.backup"
var backup_enabled: bool = true
var debug_logging: bool = false

# File format version for migration support
const CURRENT_VERSION = "1.1"
const FILE_MAGIC_HEADER = "HSCORE"

# Version history for migration
const VERSION_HISTORY = {
	"legacy": "Pre-1.0 format (direct array or simple dictionary)",
	"1.0": "Initial structured format with metadata",
	"1.1": "Enhanced format with version tracking and migration support"
}

# Migration paths - defines how to migrate from old versions to new
const MIGRATION_PATHS = {
	"legacy": "_migrate_from_legacy",
	"1.0": "_migrate_from_v1_0"
}

# Error handling
enum StorageError {
	SUCCESS,
	FILE_NOT_FOUND,
	PERMISSION_DENIED,
	DISK_FULL,
	CORRUPTION_DETECTED,
	INVALID_FORMAT,
	BACKUP_FAILED,
	UNKNOWN_ERROR
}

# Initialize with configuration
func _init(config: Dictionary = {}):
	if config.has("save_location"):
		save_file_path = config.save_location
	if config.has("backup_enabled"):
		backup_enabled = config.backup_enabled
	if config.has("debug_logging"):
		debug_logging = config.debug_logging
	
	# Generate backup path from save path
	backup_file_path = save_file_path.get_basename() + ".backup"

# Core save operation
func save_high_scores(scores: Array[Dictionary]) -> StorageError:
	"""Save high scores to file with backup and integrity checking"""
	if debug_logging:
		print("[HighScoreStorage] Attempting to save %d high scores" % scores.size())
	
	# Create backup before saving if enabled
	if backup_enabled and FileAccess.file_exists(save_file_path):
		var backup_result = backup_high_scores()
		if backup_result != StorageError.SUCCESS:
			if debug_logging:
				print("[HighScoreStorage] Warning: Backup failed, continuing with save")
	
	# Prepare data structure with metadata
	var save_data = {
		"version": CURRENT_VERSION,
		"magic": FILE_MAGIC_HEADER,
		"timestamp": Time.get_unix_time_from_system(),
		"save_date": Time.get_date_string_from_system(),
		"scores": scores,
		"checksum": _calculate_checksum(scores),
		"format_info": {
			"created_with_version": CURRENT_VERSION,
			"migration_history": _get_migration_history_from_scores(scores)
		}
	}
	
	# Attempt to save
	var file = FileAccess.open(save_file_path, FileAccess.WRITE)
	if not file:
		var error = FileAccess.get_open_error()
		if debug_logging:
			print("[HighScoreStorage] Failed to open save file: %s" % error)
		return _map_file_error(error)
	
	# Write data
	file.store_var(save_data)
	file.close()
	
	# Verify the save was successful
	if not verify_file_integrity(save_file_path):
		if debug_logging:
			print("[HighScoreStorage] Save verification failed")
		return StorageError.CORRUPTION_DETECTED
	
	if debug_logging:
		print("[HighScoreStorage] Successfully saved high scores")
	
	return StorageError.SUCCESS

# Core load operation
func load_high_scores() -> Array[Dictionary]:
	"""Load high scores from file with corruption detection and recovery"""
	if debug_logging:
		print("[HighScoreStorage] Attempting to load high scores")
	
	# Check if save file exists at configured location
	if not FileAccess.file_exists(save_file_path):
		if debug_logging:
			print("[HighScoreStorage] Save file not found at %s, attempting recovery" % save_file_path)
		
		# Try to find save file in common locations (requirement 6.4)
		var recovered_scores = attempt_save_file_recovery()
		if recovered_scores.size() > 0:
			if debug_logging:
				print("[HighScoreStorage] Successfully recovered %d scores from alternate location" % recovered_scores.size())
			return recovered_scores
		
		if debug_logging:
			print("[HighScoreStorage] No save file found in any location, returning empty array")
		return []
	
	# Try to load from main file
	var scores = _load_from_file(save_file_path)
	if scores != null:
		if debug_logging:
			print("[HighScoreStorage] Successfully loaded %d high scores" % scores.size())
		return scores
	
	# Main file failed, try backup if available
	if backup_enabled and FileAccess.file_exists(backup_file_path):
		if debug_logging:
			print("[HighScoreStorage] Main file corrupted, attempting backup recovery")
		scores = _load_from_file(backup_file_path)
		if scores != null:
			# Restore from backup
			save_high_scores(scores)
			if debug_logging:
				print("[HighScoreStorage] Successfully recovered from backup")
			return scores
	
	# Try recovery from common locations as last resort
	if debug_logging:
		print("[HighScoreStorage] Backup recovery failed, attempting location recovery")
	
	var recovered_scores = attempt_save_file_recovery()
	if recovered_scores.size() > 0:
		if debug_logging:
			print("[HighScoreStorage] Successfully recovered %d scores from alternate location" % recovered_scores.size())
		return recovered_scores
	
	if debug_logging:
		print("[HighScoreStorage] All recovery attempts failed, returning empty array")
	return []

# Backup operations
func backup_high_scores() -> StorageError:
	"""Create a backup of the current high scores file"""
	if not FileAccess.file_exists(save_file_path):
		return StorageError.FILE_NOT_FOUND
	
	# Copy main file to backup location
	var error = DirAccess.copy_absolute(save_file_path, backup_file_path)
	if error != OK:
		if debug_logging:
			print("[HighScoreStorage] Backup failed with error: %s" % error)
		return StorageError.BACKUP_FAILED
	
	if debug_logging:
		print("[HighScoreStorage] Backup created successfully")
	return StorageError.SUCCESS

func restore_from_backup() -> Array[Dictionary]:
	"""Restore high scores from backup file"""
	if not FileAccess.file_exists(backup_file_path):
		if debug_logging:
			print("[HighScoreStorage] No backup file found")
		return []
	
	var scores = _load_from_file(backup_file_path)
	if scores != null:
		# Save restored data as main file
		save_high_scores(scores)
		if debug_logging:
			print("[HighScoreStorage] Successfully restored from backup")
		return scores
	
	if debug_logging:
		print("[HighScoreStorage] Backup file is also corrupted")
	return []

# File integrity verification
func verify_file_integrity(file_path: String) -> bool:
	"""Verify that a save file is not corrupted"""
	if not FileAccess.file_exists(file_path):
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return false
	
	var data = file.get_var()
	file.close()
	
	# Check if data is valid dictionary
	if not (data is Dictionary):
		return false
	
	# Check required fields
	if not data.has("magic") or data.magic != FILE_MAGIC_HEADER:
		return false
	
	if not data.has("version") or not data.has("scores") or not data.has("checksum"):
		return false
	
	# Verify checksum
	var expected_checksum = _calculate_checksum(data.scores)
	if data.checksum != expected_checksum:
		if debug_logging:
			print("[HighScoreStorage] Checksum mismatch: expected %s, got %s" % [expected_checksum, data.checksum])
		return false
	
	return true

# Migration support
func migrate_old_format(old_data) -> Array[Dictionary]:
	"""Convert old save format to new format with comprehensive version detection"""
	if debug_logging:
		print("[HighScoreStorage] Starting migration process")
	
	var detected_version = _detect_file_version(old_data)
	if debug_logging:
		print("[HighScoreStorage] Detected version: %s" % detected_version)
	
	# If already current version, no migration needed
	if detected_version == CURRENT_VERSION:
		if old_data is Dictionary and old_data.has("scores"):
			return old_data.scores
		return []
	
	# Apply migration path
	if MIGRATION_PATHS.has(detected_version):
		var migration_method = MIGRATION_PATHS[detected_version]
		var migrated_scores = call(migration_method, old_data)
		
		if debug_logging:
			print("[HighScoreStorage] Migration completed: %d scores migrated" % migrated_scores.size())
		
		return migrated_scores
	
	# Unknown version - try best effort migration
	if debug_logging:
		print("[HighScoreStorage] Unknown version, attempting best-effort migration")
	
	return _migrate_unknown_format(old_data)

func _detect_file_version(data) -> String:
	"""Detect the version of save file data"""
	# Check for current format with version field
	if data is Dictionary:
		if data.has("version"):
			return data.version
		
		# Check for v1.0 format (has magic header but no explicit version)
		if data.has("magic") and data.magic == FILE_MAGIC_HEADER:
			return "1.0"
		
		# Check for simple dictionary format with scores
		if data.has("scores") and data.scores is Array:
			return "legacy"
	
	# Check for direct array format (very old legacy)
	if data is Array:
		return "legacy"
	
	# Unknown format
	return "unknown"

func _migrate_from_legacy(old_data) -> Array[Dictionary]:
	"""Migrate from legacy format (pre-1.0)"""
	var scores: Array[Dictionary] = []
	
	# Handle direct array format
	if old_data is Array:
		scores = old_data
	# Handle dictionary with scores array
	elif old_data is Dictionary and old_data.has("scores"):
		scores = old_data.scores
	else:
		return []
	
	# Enhance legacy entries with new required fields
	var enhanced_scores: Array[Dictionary] = []
	var current_time = Time.get_unix_time_from_system()
	var current_date = Time.get_date_string_from_system()
	
	for i in range(scores.size()):
		var entry = scores[i]
		if not (entry is Dictionary):
			continue
		
		var enhanced_entry = {
			"name": entry.get("name", "Unknown"),
			"score": entry.get("score", 0),
			"date": entry.get("date", current_date),
			"timestamp": entry.get("timestamp", current_time - (scores.size() - i) * 3600), # Spread timestamps
			"player_index": entry.get("player_index", 1),
			"session_id": entry.get("session_id", "legacy_migration"),
			"version": "migrated_from_legacy"
		}
		
		enhanced_scores.append(enhanced_entry)
	
	if debug_logging:
		print("[HighScoreStorage] Migrated %d legacy entries" % enhanced_scores.size())
	
	return enhanced_scores

func _migrate_from_v1_0(old_data: Dictionary) -> Array[Dictionary]:
	"""Migrate from version 1.0 to current version"""
	if not old_data.has("scores"):
		return []
	
	var scores = old_data.scores
	var enhanced_scores: Array[Dictionary] = []
	
	# V1.0 to V1.1 migration - add any missing fields
	for entry in scores:
		if not (entry is Dictionary):
			continue
		
		var enhanced_entry = entry.duplicate()
		
		# Ensure all required fields exist
		if not enhanced_entry.has("version"):
			enhanced_entry.version = "migrated_from_1.0"
		
		if not enhanced_entry.has("session_id"):
			enhanced_entry.session_id = "v1_0_migration"
		
		# Add any new fields introduced in v1.1
		if not enhanced_entry.has("migration_source"):
			enhanced_entry.migration_source = "1.0"
		
		enhanced_scores.append(enhanced_entry)
	
	if debug_logging:
		print("[HighScoreStorage] Migrated %d v1.0 entries" % enhanced_scores.size())
	
	return enhanced_scores

func _migrate_unknown_format(data) -> Array[Dictionary]:
	"""Best-effort migration for unknown formats"""
	if debug_logging:
		print("[HighScoreStorage] Attempting best-effort migration for unknown format")
	
	# Try to extract anything that looks like score data
	var scores: Array[Dictionary] = []
	
	if data is Array:
		# Assume it's a direct array of scores
		for item in data:
			if item is Dictionary and item.has("name") and item.has("score"):
				scores.append(item)
	elif data is Dictionary:
		# Look for score-like data in various places
		if data.has("scores") and data.scores is Array:
			scores = data.scores
		elif data.has("high_scores") and data.high_scores is Array:
			scores = data.high_scores
		elif data.has("leaderboard") and data.leaderboard is Array:
			scores = data.leaderboard
	
	# Apply legacy migration to whatever we found
	return _migrate_from_legacy(scores)

func create_migration_backup(original_data, detected_version: String) -> bool:
	"""Create a backup of original data before migration"""
	var backup_path = save_file_path.get_basename() + "_pre_migration_" + detected_version + ".backup"
	
	var file = FileAccess.open(backup_path, FileAccess.WRITE)
	if not file:
		if debug_logging:
			print("[HighScoreStorage] Failed to create migration backup")
		return false
	
	file.store_var({
		"original_data": original_data,
		"detected_version": detected_version,
		"migration_timestamp": Time.get_unix_time_from_system(),
		"migration_date": Time.get_date_string_from_system()
	})
	file.close()
	
	if debug_logging:
		print("[HighScoreStorage] Created migration backup: %s" % backup_path)
	
	return true

func get_migration_info() -> Dictionary:
	"""Get information about available migrations and version history"""
	return {
		"current_version": CURRENT_VERSION,
		"version_history": VERSION_HISTORY,
		"supported_migrations": MIGRATION_PATHS.keys()
	}

# Configuration methods
func set_save_location(path: String):
	"""Set custom save file location"""
	save_file_path = path
	backup_file_path = path.get_basename() + ".backup"

func set_backup_enabled(enabled: bool):
	"""Enable or disable backup functionality"""
	backup_enabled = enabled

func get_save_file_path() -> String:
	"""Get current save file path"""
	return save_file_path

func get_backup_file_path() -> String:
	"""Get current backup file path"""
	return backup_file_path

# Methods for handling save file location discovery (requirement 6.4)
func find_save_file_in_common_locations() -> String:
	"""Attempt to locate save file in common locations"""
	var common_paths = [
		save_file_path,  # Current configured path
		"user://high_scores.save",  # Default path
		"user://saves/high_scores.save",  # Common saves subdirectory
		"user://data/high_scores.save",  # Common data subdirectory
		"user://game_data/high_scores.save",  # Alternative data directory
		"user://highscores.save",  # Alternative naming
		"user://scores.save"  # Short naming
	]
	
	for path in common_paths:
		if FileAccess.file_exists(path):
			if debug_logging:
				print("[HighScoreStorage] Found save file at: %s" % path)
			return path
	
	if debug_logging:
		print("[HighScoreStorage] No save file found in common locations")
	
	return ""

func attempt_save_file_recovery() -> Array[Dictionary]:
	"""Attempt to recover save file from common locations"""
	var found_path = find_save_file_in_common_locations()
	
	if found_path == "":
		return []
	
	# If found path is different from current, update configuration
	if found_path != save_file_path:
		if debug_logging:
			print("[HighScoreStorage] Updating save path from %s to %s" % [save_file_path, found_path])
		set_save_location(found_path)
	
	# Load from found location
	return _load_from_file(found_path)

# Private helper methods
func _load_from_file(file_path: String) -> Array[Dictionary]:
	"""Load and validate data from a specific file with enhanced migration support"""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return null
	
	var data = file.get_var()
	file.close()
	
	# Detect version and handle accordingly
	var detected_version = _detect_file_version(data)
	
	if debug_logging:
		print("[HighScoreStorage] Loading file with detected version: %s" % detected_version)
	
	# Handle current version format
	if detected_version == CURRENT_VERSION:
		if data is Dictionary and data.has("magic") and data.magic == FILE_MAGIC_HEADER:
			# Verify integrity for current version
			if not verify_file_integrity(file_path):
				if debug_logging:
					print("[HighScoreStorage] Current version file integrity check failed")
				return null
			return data.scores
		else:
			if debug_logging:
				print("[HighScoreStorage] Current version file has invalid structure")
			return null
	
	# Handle older versions that need migration
	if detected_version != "unknown":
		# Create backup before migration (requirement 6.3)
		create_migration_backup(data, detected_version)
		
		# Perform migration
		var migrated_scores = migrate_old_format(data)
		
		if migrated_scores.size() > 0:
			# Save migrated data in new format
			var save_result = save_high_scores(migrated_scores)
			if save_result == StorageError.SUCCESS:
				if debug_logging:
					print("[HighScoreStorage] Successfully migrated and saved %d scores from version %s" % [migrated_scores.size(), detected_version])
			else:
				if debug_logging:
					print("[HighScoreStorage] Migration successful but save failed - continuing with migrated data")
			
			return migrated_scores
		else:
			if debug_logging:
				print("[HighScoreStorage] Migration returned no scores")
			return null
	
	# Unknown format - log and return null
	if debug_logging:
		print("[HighScoreStorage] Unknown file format, cannot load")
	
	return null

func _calculate_checksum(scores: Array[Dictionary]) -> String:
	"""Calculate a simple checksum for data integrity"""
	var content = ""
	for score in scores:
		if score.has("name") and score.has("score"):
			content += str(score.name) + str(score.score)
	
	return content.md5_text()

func _get_migration_history_from_scores(scores: Array[Dictionary]) -> Array[String]:
	"""Extract migration history from score entries"""
	var migration_sources = []
	
	for score in scores:
		if score.has("migration_source") and not migration_sources.has(score.migration_source):
			migration_sources.append(score.migration_source)
		elif score.has("version") and score.version.begins_with("migrated_from_"):
			var source = score.version.replace("migrated_from_", "")
			if not migration_sources.has(source):
				migration_sources.append(source)
	
	return migration_sources

func _map_file_error(godot_error: Error) -> StorageError:
	"""Map Godot file errors to our storage errors"""
	match godot_error:
		ERR_FILE_NOT_FOUND:
			return StorageError.FILE_NOT_FOUND
		ERR_FILE_CANT_WRITE, ERR_FILE_NO_PERMISSION:
			return StorageError.PERMISSION_DENIED
		ERR_OUT_OF_MEMORY, ERR_FILE_CANT_OPEN:
			return StorageError.DISK_FULL
		_:
			return StorageError.UNKNOWN_ERROR