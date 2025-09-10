class_name HighScoreStorage
extends RefCounted

# Configuration
var save_file_path: String = "user://high_scores.save"
var backup_file_path: String = "user://high_scores.backup"
var backup_enabled: bool = true
var debug_logging: bool = false

# File format version for migration support
const CURRENT_VERSION = "1.0"
const FILE_MAGIC_HEADER = "HSCORE"

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
		"scores": scores,
		"checksum": _calculate_checksum(scores)
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
	
	# Check if save file exists
	if not FileAccess.file_exists(save_file_path):
		if debug_logging:
			print("[HighScoreStorage] Save file not found, returning empty array")
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
func migrate_old_format(old_data: Dictionary) -> Array[Dictionary]:
	"""Convert old save format to new format"""
	# Handle legacy format (simple array of dictionaries)
	if old_data.has("scores"):
		return old_data.scores
	
	# If old_data is just an array, assume it's the scores directly
	if old_data is Array:
		return old_data
	
	# Unknown format
	return []

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

# Private helper methods
func _load_from_file(file_path: String) -> Array[Dictionary]:
	"""Load and validate data from a specific file"""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return null
	
	var data = file.get_var()
	file.close()
	
	# Handle different data formats
	if data is Array:
		# Legacy format - direct array of scores
		if debug_logging:
			print("[HighScoreStorage] Loading legacy format")
		return data
	
	if not (data is Dictionary):
		if debug_logging:
			print("[HighScoreStorage] Invalid data format")
		return null
	
	# New format with metadata
	if data.has("magic") and data.magic == FILE_MAGIC_HEADER:
		# Verify integrity
		if not verify_file_integrity(file_path):
			if debug_logging:
				print("[HighScoreStorage] File integrity check failed")
			return null
		
		return data.scores
	
	# Try to migrate old format
	var migrated = migrate_old_format(data)
	if migrated.size() > 0:
		if debug_logging:
			print("[HighScoreStorage] Migrated old format")
		return migrated
	
	return null

func _calculate_checksum(scores: Array[Dictionary]) -> String:
	"""Calculate a simple checksum for data integrity"""
	var content = ""
	for score in scores:
		if score.has("name") and score.has("score"):
			content += str(score.name) + str(score.score)
	
	return content.md5_text()

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