extends "res://tests/test_storage_runner.gd"

# Test class for HighScoreStorage
class_name TestHighScoreStorage

var storage: HighScoreStorage
var test_save_path: String = "user://test_high_scores.save"
var test_backup_path: String = "user://test_high_scores.backup"

func _ready():
	test_name = "HighScoreStorage Tests"

func setup():
	"""Setup before each test"""
	# Clean up any existing test files
	cleanup_test_files()
	
	# Create storage instance with test configuration
	var config = {
		"save_location": test_save_path,
		"backup_enabled": true,
		"debug_logging": true
	}
	storage = HighScoreStorage.new(config)

func cleanup():
	"""Cleanup after each test"""
	cleanup_test_files()

func cleanup_test_files():
	"""Remove test files"""
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(test_save_path)
	if FileAccess.file_exists(test_backup_path):
		DirAccess.remove_absolute(test_backup_path)

func run_tests():
	"""Run all storage tests"""
	print("\n=== Running HighScoreStorage Tests ===")
	
	# Basic functionality tests
	test_save_and_load_empty_scores()
	test_save_and_load_single_score()
	test_save_and_load_multiple_scores()
	
	# File integrity tests
	test_file_integrity_verification()
	test_corrupted_file_handling()
	test_checksum_validation()
	
	# Backup and recovery tests
	test_backup_creation()
	test_backup_recovery()
	test_recovery_from_corrupted_main_file()
	
	# Configuration tests
	test_custom_save_location()
	test_backup_disable()
	
	# Error handling tests
	test_nonexistent_file_load()
	test_invalid_file_format()
	
	# Migration tests
	test_legacy_format_migration()
	test_version_detection()
	test_migration_backup_creation()
	test_save_file_location_discovery()
	
	print("=== HighScoreStorage Tests Complete ===\n")

# Basic functionality tests
func test_save_and_load_empty_scores():
	"""Test saving and loading empty score array"""
	setup()
	
	var empty_scores: Array[Dictionary] = []
	var save_result = storage.save_high_scores(empty_scores)
	assert_equal(save_result, HighScoreStorage.StorageError.SUCCESS, "Should save empty scores successfully")
	
	var loaded_scores = storage.load_high_scores()
	assert_equal(loaded_scores.size(), 0, "Should load empty array")
	
	cleanup()

func test_save_and_load_single_score():
	"""Test saving and loading a single score"""
	setup()
	
	var test_scores: Array[Dictionary] = [
		{
			"name": "TestPlayer",
			"score": 12345,
			"date": "2024-01-01",
			"timestamp": 1704067200,
			"player_index": 1,
			"session_id": "test_session",
			"version": "1.0.0"
		}
	]
	
	var save_result = storage.save_high_scores(test_scores)
	assert_equal(save_result, HighScoreStorage.StorageError.SUCCESS, "Should save single score successfully")
	
	var loaded_scores = storage.load_high_scores()
	assert_equal(loaded_scores.size(), 1, "Should load one score")
	assert_equal(loaded_scores[0].name, "TestPlayer", "Should preserve player name")
	assert_equal(loaded_scores[0].score, 12345, "Should preserve score value")
	
	cleanup()

func test_save_and_load_multiple_scores():
	"""Test saving and loading multiple scores"""
	setup()
	
	var test_scores: Array[Dictionary] = [
		{"name": "Player1", "score": 10000, "date": "2024-01-01", "timestamp": 1704067200, "player_index": 1, "session_id": "session1", "version": "1.0.0"},
		{"name": "Player2", "score": 8000, "date": "2024-01-02", "timestamp": 1704153600, "player_index": 2, "session_id": "session2", "version": "1.0.0"},
		{"name": "Player3", "score": 6000, "date": "2024-01-03", "timestamp": 1704240000, "player_index": 1, "session_id": "session3", "version": "1.0.0"}
	]
	
	var save_result = storage.save_high_scores(test_scores)
	assert_equal(save_result, HighScoreStorage.StorageError.SUCCESS, "Should save multiple scores successfully")
	
	var loaded_scores = storage.load_high_scores()
	assert_equal(loaded_scores.size(), 3, "Should load all three scores")
	assert_equal(loaded_scores[0].name, "Player1", "Should preserve first player name")
	assert_equal(loaded_scores[1].score, 8000, "Should preserve second player score")
	
	cleanup()

# File integrity tests
func test_file_integrity_verification():
	"""Test file integrity verification"""
	setup()
	
	var test_scores: Array[Dictionary] = [
		{"name": "TestPlayer", "score": 5000, "date": "2024-01-01", "timestamp": 1704067200, "player_index": 1, "session_id": "test", "version": "1.0.0"}
	]
	
	storage.save_high_scores(test_scores)
	
	# Verify integrity of valid file
	assert_true(storage.verify_file_integrity(test_save_path), "Should verify valid file as intact")
	
	# Verify non-existent file
	assert_false(storage.verify_file_integrity("user://nonexistent.save"), "Should detect non-existent file")
	
	cleanup()

func test_corrupted_file_handling():
	"""Test handling of corrupted save files"""
	setup()
	
	# Create a corrupted file
	var file = FileAccess.open(test_save_path, FileAccess.WRITE)
	file.store_string("This is not valid save data")
	file.close()
	
	# Verify corruption is detected
	assert_false(storage.verify_file_integrity(test_save_path), "Should detect corrupted file")
	
	# Loading should return empty array
	var loaded_scores = storage.load_high_scores()
	assert_equal(loaded_scores.size(), 0, "Should return empty array for corrupted file")
	
	cleanup()

func test_checksum_validation():
	"""Test checksum validation for data integrity"""
	setup()
	
	var test_scores: Array[Dictionary] = [
		{"name": "TestPlayer", "score": 5000, "date": "2024-01-01", "timestamp": 1704067200, "player_index": 1, "session_id": "test", "version": "1.0.0"}
	]
	
	storage.save_high_scores(test_scores)
	
	# Manually corrupt the checksum in the file
	var file = FileAccess.open(test_save_path, FileAccess.READ)
	var data = file.get_var()
	file.close()
	
	data.checksum = "invalid_checksum"
	
	file = FileAccess.open(test_save_path, FileAccess.WRITE)
	file.store_var(data)
	file.close()
	
	# Verify corruption is detected
	assert_false(storage.verify_file_integrity(test_save_path), "Should detect checksum mismatch")
	
	cleanup()

# Backup and recovery tests
func test_backup_creation():
	"""Test backup file creation"""
	setup()
	
	var test_scores: Array[Dictionary] = [
		{"name": "TestPlayer", "score": 5000, "date": "2024-01-01", "timestamp": 1704067200, "player_index": 1, "session_id": "test", "version": "1.0.0"}
	]
	
	# Save initial scores
	storage.save_high_scores(test_scores)
	assert_true(FileAccess.file_exists(test_save_path), "Main save file should exist")
	
	# Create backup
	var backup_result = storage.backup_high_scores()
	assert_equal(backup_result, HighScoreStorage.StorageError.SUCCESS, "Backup should succeed")
	assert_true(FileAccess.file_exists(test_backup_path), "Backup file should exist")
	
	cleanup()

func test_backup_recovery():
	"""Test recovery from backup file"""
	setup()
	
	var test_scores: Array[Dictionary] = [
		{"name": "BackupTest", "score": 7500, "date": "2024-01-01", "timestamp": 1704067200, "player_index": 1, "session_id": "backup", "version": "1.0.0"}
	]
	
	# Save and backup
	storage.save_high_scores(test_scores)
	storage.backup_high_scores()
	
	# Delete main file
	DirAccess.remove_absolute(test_save_path)
	assert_false(FileAccess.file_exists(test_save_path), "Main file should be deleted")
	
	# Restore from backup
	var restored_scores = storage.restore_from_backup()
	assert_equal(restored_scores.size(), 1, "Should restore one score")
	assert_equal(restored_scores[0].name, "BackupTest", "Should restore correct data")
	assert_true(FileAccess.file_exists(test_save_path), "Main file should be recreated")
	
	cleanup()

func test_recovery_from_corrupted_main_file():
	"""Test automatic recovery when main file is corrupted but backup is valid"""
	setup()
	
	var test_scores: Array[Dictionary] = [
		{"name": "RecoveryTest", "score": 9000, "date": "2024-01-01", "timestamp": 1704067200, "player_index": 1, "session_id": "recovery", "version": "1.0.0"}
	]
	
	# Save and backup
	storage.save_high_scores(test_scores)
	storage.backup_high_scores()
	
	# Corrupt main file
	var file = FileAccess.open(test_save_path, FileAccess.WRITE)
	file.store_string("corrupted data")
	file.close()
	
	# Load should automatically recover from backup
	var loaded_scores = storage.load_high_scores()
	assert_equal(loaded_scores.size(), 1, "Should recover one score from backup")
	assert_equal(loaded_scores[0].name, "RecoveryTest", "Should recover correct data")
	
	cleanup()

# Configuration tests
func test_custom_save_location():
	"""Test custom save file location"""
	cleanup_test_files()
	
	var custom_path = "user://custom_scores.save"
	var config = {
		"save_location": custom_path,
		"backup_enabled": false
	}
	var custom_storage = HighScoreStorage.new(config)
	
	var test_scores: Array[Dictionary] = [
		{"name": "CustomPath", "score": 3000, "date": "2024-01-01", "timestamp": 1704067200, "player_index": 1, "session_id": "custom", "version": "1.0.0"}
	]
	
	custom_storage.save_high_scores(test_scores)
	assert_true(FileAccess.file_exists(custom_path), "Should save to custom location")
	
	var loaded_scores = custom_storage.load_high_scores()
	assert_equal(loaded_scores.size(), 1, "Should load from custom location")
	
	# Cleanup custom file
	if FileAccess.file_exists(custom_path):
		DirAccess.remove_absolute(custom_path)

func test_backup_disable():
	"""Test disabling backup functionality"""
	cleanup_test_files()
	
	var config = {
		"save_location": test_save_path,
		"backup_enabled": false
	}
	var no_backup_storage = HighScoreStorage.new(config)
	
	var test_scores: Array[Dictionary] = [
		{"name": "NoBackup", "score": 4000, "date": "2024-01-01", "timestamp": 1704067200, "player_index": 1, "session_id": "nobackup", "version": "1.0.0"}
	]
	
	no_backup_storage.save_high_scores(test_scores)
	assert_true(FileAccess.file_exists(test_save_path), "Should save main file")
	assert_false(FileAccess.file_exists(test_backup_path), "Should not create backup file")
	
	cleanup_test_files()

# Error handling tests
func test_nonexistent_file_load():
	"""Test loading from non-existent file"""
	setup()
	
	# Ensure no save file exists
	assert_false(FileAccess.file_exists(test_save_path), "Save file should not exist")
	
	var loaded_scores = storage.load_high_scores()
	assert_equal(loaded_scores.size(), 0, "Should return empty array for non-existent file")
	
	cleanup()

func test_invalid_file_format():
	"""Test handling of invalid file formats"""
	setup()
	
	# Create file with invalid format
	var file = FileAccess.open(test_save_path, FileAccess.WRITE)
	file.store_var({"invalid": "format", "no_scores": true})
	file.close()
	
	var loaded_scores = storage.load_high_scores()
	assert_equal(loaded_scores.size(), 0, "Should return empty array for invalid format")
	
	cleanup()

# Migration tests
func test_legacy_format_migration():
	"""Test migration from legacy save format"""
	setup()
	
	# Create legacy format file (direct array)
	var legacy_scores = [
		{"name": "LegacyPlayer", "score": 15000},
		{"name": "OldFormat", "score": 12000}
	]
	
	var file = FileAccess.open(test_save_path, FileAccess.WRITE)
	file.store_var(legacy_scores)
	file.close()
	
	# Load should migrate automatically
	var loaded_scores = storage.load_high_scores()
	assert_equal(loaded_scores.size(), 2, "Should migrate legacy scores")
	assert_equal(loaded_scores[0].name, "LegacyPlayer", "Should preserve legacy data")
	assert_equal(loaded_scores[1].score, 12000, "Should preserve legacy scores")
	
	# Verify enhanced fields were added
	assert_true(loaded_scores[0].has("date"), "Should add date field during migration")
	assert_true(loaded_scores[0].has("timestamp"), "Should add timestamp field during migration")
	assert_true(loaded_scores[0].has("version"), "Should add version field during migration")
	
	cleanup()

func test_version_detection():
	"""Test version detection for different file formats"""
	setup()
	
	# Test current version detection
	var current_data = {"version": "1.1", "magic": "HSCORE", "scores": []}
	var detected = storage._detect_file_version(current_data)
	assert_equal(detected, "1.1", "Should detect current version")
	
	# Test v1.0 detection
	var v1_0_data = {"magic": "HSCORE", "timestamp": 123, "scores": []}
	detected = storage._detect_file_version(v1_0_data)
	assert_equal(detected, "1.0", "Should detect v1.0 format")
	
	# Test legacy detection
	var legacy_array = [{"name": "Test", "score": 100}]
	detected = storage._detect_file_version(legacy_array)
	assert_equal(detected, "legacy", "Should detect legacy array format")
	
	cleanup()

func test_migration_backup_creation():
	"""Test that migration creates backup files"""
	setup()
	
	# Create legacy file
	var legacy_data = [{"name": "BackupTest", "score": 5000}]
	var file = FileAccess.open(test_save_path, FileAccess.WRITE)
	file.store_var(legacy_data)
	file.close()
	
	# Load should create migration backup
	var loaded_scores = storage.load_high_scores()
	
	# Check backup was created
	var backup_path = test_save_path.get_basename() + "_pre_migration_legacy.backup"
	assert_true(FileAccess.file_exists(backup_path), "Should create migration backup")
	
	# Cleanup backup
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	
	cleanup()

func test_save_file_location_discovery():
	"""Test finding save files in alternate locations"""
	setup()
	
	# Test with no files
	var found_path = storage.find_save_file_in_common_locations()
	assert_equal(found_path, "", "Should return empty string when no files found")
	
	# Create file in alternate location
	var alt_path = "user://highscores.save"
	var test_data = [{"name": "AltTest", "score": 3000}]
	var file = FileAccess.open(alt_path, FileAccess.WRITE)
	file.store_var(test_data)
	file.close()
	
	# Should find the alternate file
	found_path = storage.find_save_file_in_common_locations()
	assert_equal(found_path, alt_path, "Should find file in alternate location")
	
	# Cleanup alternate file
	if FileAccess.file_exists(alt_path):
		DirAccess.remove_absolute(alt_path)
	
	cleanup()

# Helper assertion methods
func assert_equal(actual, expected, message: String):
	if actual == expected:
		print("✓ PASS: %s" % message)
		tests_passed += 1
	else:
		print("✗ FAIL: %s (Expected: %s, Got: %s)" % [message, expected, actual])
		tests_failed += 1
	tests_total += 1

func assert_true(condition: bool, message: String):
	if condition:
		print("✓ PASS: %s" % message)
		tests_passed += 1
	else:
		print("✗ FAIL: %s (Expected: true, Got: false)" % message)
		tests_failed += 1
	tests_total += 1

func assert_false(condition: bool, message: String):
	if not condition:
		print("✓ PASS: %s" % message)
		tests_passed += 1
	else:
		print("✗ FAIL: %s (Expected: false, Got: true)" % message)
		tests_failed += 1
	tests_total += 1