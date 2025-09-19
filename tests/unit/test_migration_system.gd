extends "res://tests/test_storage_runner.gd"

# Test class for Migration System
class_name TestMigrationSystem

var storage: HighScoreStorage
var validator: HighScoreValidator
var test_save_path: String = "user://test_migration.save"
var test_backup_path: String = "user://test_migration.backup"

func _ready():
	test_name = "Migration System Tests"

func setup():
	"""Setup before each test"""
	cleanup_test_files()
	
	var config = {
		"save_location": test_save_path,
		"backup_enabled": true,
		"debug_logging": true
	}
	storage = HighScoreStorage.new(config)
	validator = HighScoreValidator.new()

func cleanup():
	"""Cleanup after each test"""
	cleanup_test_files()

func cleanup_test_files():
	"""Remove all test files including migration backups"""
	var files_to_remove = [
		test_save_path,
		test_backup_path,
		"user://test_migration_pre_migration_legacy.backup",
		"user://test_migration_pre_migration_1.0.backup",
		"user://test_migration_pre_migration_unknown.backup"
	]
	
	for file_path in files_to_remove:
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)

func run_tests():
	"""Run all migration tests"""
	print("\n=== Running Migration System Tests ===")
	
	# Version detection tests
	test_version_detection_current()
	test_version_detection_v1_0()
	test_version_detection_legacy_array()
	test_version_detection_legacy_dict()
	test_version_detection_unknown()
	
	# Migration tests
	test_migration_from_legacy_array()
	test_migration_from_legacy_dict()
	test_migration_from_v1_0()
	test_migration_backup_creation()
	test_migration_with_save()
	
	# Save file location discovery tests
	test_save_file_location_discovery()
	test_save_file_recovery_from_alternate_location()
	
	# Version compatibility tests
	test_version_compatibility_validation()
	test_migration_history_tracking()
	
	# Error handling tests
	test_migration_failure_handling()
	test_corrupted_migration_backup()
	
	print("=== Migration System Tests Complete ===\n")

# Version detection tests
func test_version_detection_current():
	"""Test detection of current version format"""
	setup()
	
	var current_data = {
		"version": "1.1",
		"magic": "HSCORE",
		"scores": []
	}
	
	var detected = storage._detect_file_version(current_data)
	assert_equal(detected, "1.1", "Should detect current version")
	
	cleanup()

func test_version_detection_v1_0():
	"""Test detection of v1.0 format"""
	setup()
	
	var v1_0_data = {
		"magic": "HSCORE",
		"timestamp": 1234567890,
		"scores": [],
		"checksum": "abc123"
	}
	
	var detected = storage._detect_file_version(v1_0_data)
	assert_equal(detected, "1.0", "Should detect v1.0 format")
	
	cleanup()

func test_version_detection_legacy_array():
	"""Test detection of legacy array format"""
	setup()
	
	var legacy_array = [
		{"name": "Player1", "score": 1000},
		{"name": "Player2", "score": 800}
	]
	
	var detected = storage._detect_file_version(legacy_array)
	assert_equal(detected, "legacy", "Should detect legacy array format")
	
	cleanup()

func test_version_detection_legacy_dict():
	"""Test detection of legacy dictionary format"""
	setup()
	
	var legacy_dict = {
		"scores": [
			{"name": "Player1", "score": 1000},
			{"name": "Player2", "score": 800}
		]
	}
	
	var detected = storage._detect_file_version(legacy_dict)
	assert_equal(detected, "legacy", "Should detect legacy dictionary format")
	
	cleanup()

func test_version_detection_unknown():
	"""Test detection of unknown format"""
	setup()
	
	var unknown_data = {
		"some_field": "some_value",
		"other_data": 123
	}
	
	var detected = storage._detect_file_version(unknown_data)
	assert_equal(detected, "unknown", "Should detect unknown format")
	
	cleanup()

# Migration tests
func test_migration_from_legacy_array():
	"""Test migration from legacy array format"""
	setup()
	
	var legacy_scores = [
		{"name": "LegacyPlayer1", "score": 15000},
		{"name": "LegacyPlayer2", "score": 12000}
	]
	
	var migrated = storage.migrate_old_format(legacy_scores)
	
	assert_equal(migrated.size(), 2, "Should migrate both scores")
	assert_equal(migrated[0].name, "LegacyPlayer1", "Should preserve player name")
	assert_equal(migrated[0].score, 15000, "Should preserve score")
	assert_true(migrated[0].has("date"), "Should add date field")
	assert_true(migrated[0].has("timestamp"), "Should add timestamp field")
	assert_true(migrated[0].has("session_id"), "Should add session_id field")
	assert_equal(migrated[0].version, "migrated_from_legacy", "Should mark as migrated")
	
	cleanup()

func test_migration_from_legacy_dict():
	"""Test migration from legacy dictionary format"""
	setup()
	
	var legacy_data = {
		"scores": [
			{"name": "DictPlayer1", "score": 8000},
			{"name": "DictPlayer2", "score": 6000}
		]
	}
	
	var migrated = storage.migrate_old_format(legacy_data)
	
	assert_equal(migrated.size(), 2, "Should migrate both scores")
	assert_equal(migrated[0].name, "DictPlayer1", "Should preserve player name")
	assert_equal(migrated[1].score, 6000, "Should preserve second score")
	assert_equal(migrated[0].session_id, "legacy_migration", "Should use legacy migration session ID")
	
	cleanup()

func test_migration_from_v1_0():
	"""Test migration from v1.0 format"""
	setup()
	
	var v1_0_data = {
		"magic": "HSCORE",
		"timestamp": 1234567890,
		"scores": [
			{"name": "V1Player", "score": 5000, "date": "2024-01-01"}
		],
		"checksum": "test123"
	}
	
	var migrated = storage.migrate_old_format(v1_0_data)
	
	assert_equal(migrated.size(), 1, "Should migrate one score")
	assert_equal(migrated[0].name, "V1Player", "Should preserve player name")
	assert_equal(migrated[0].score, 5000, "Should preserve score")
	assert_equal(migrated[0].version, "migrated_from_1.0", "Should mark as migrated from v1.0")
	assert_true(migrated[0].has("migration_source"), "Should add migration source")
	
	cleanup()

func test_migration_backup_creation():
	"""Test that migration creates backup of original data"""
	setup()
	
	var legacy_data = [{"name": "BackupTest", "score": 3000}]
	
	# Create a file with legacy data
	var file = FileAccess.open(test_save_path, FileAccess.WRITE)
	file.store_var(legacy_data)
	file.close()
	
	# Load should trigger migration and backup creation
	var loaded_scores = storage.load_high_scores()
	
	assert_equal(loaded_scores.size(), 1, "Should load migrated score")
	
	# Check that migration backup was created
	var backup_path = test_save_path.get_basename() + "_pre_migration_legacy.backup"
	assert_true(FileAccess.file_exists(backup_path), "Should create migration backup")
	
	# Verify backup contains original data
	var backup_file = FileAccess.open(backup_path, FileAccess.READ)
	var backup_data = backup_file.get_var()
	backup_file.close()
	
	assert_true(backup_data.has("original_data"), "Backup should contain original data")
	assert_equal(backup_data.detected_version, "legacy", "Backup should record detected version")
	
	cleanup()

func test_migration_with_save():
	"""Test that migrated data is automatically saved in new format"""
	setup()
	
	var legacy_data = [{"name": "SaveTest", "score": 7500}]
	
	# Create legacy file
	var file = FileAccess.open(test_save_path, FileAccess.WRITE)
	file.store_var(legacy_data)
	file.close()
	
	# Load should migrate and save
	var loaded_scores = storage.load_high_scores()
	
	# Verify file was updated to new format
	file = FileAccess.open(test_save_path, FileAccess.READ)
	var saved_data = file.get_var()
	file.close()
	
	assert_true(saved_data.has("version"), "Saved file should have version")
	assert_equal(saved_data.version, "1.1", "Should save in current version")
	assert_true(saved_data.has("magic"), "Should have magic header")
	assert_equal(saved_data.magic, "HSCORE", "Should have correct magic header")
	
	cleanup()

# Save file location discovery tests
func test_save_file_location_discovery():
	"""Test finding save files in common locations"""
	setup()
	
	# Create a save file in an alternate location
	var alt_path = "user://saves/high_scores.save"
	var alt_dir = alt_path.get_base_dir()
	
	# Create directory if it doesn't exist
	if not DirAccess.dir_exists_absolute(alt_dir):
		DirAccess.create_dir_recursive_absolute(alt_dir)
	
	var test_scores = [{"name": "AltLocation", "score": 4000}]
	var file = FileAccess.open(alt_path, FileAccess.WRITE)
	file.store_var(test_scores)
	file.close()
	
	# Test discovery
	var found_path = storage.find_save_file_in_common_locations()
	assert_equal(found_path, alt_path, "Should find file in alternate location")
	
	# Cleanup alternate location
	if FileAccess.file_exists(alt_path):
		DirAccess.remove_absolute(alt_path)
	if DirAccess.dir_exists_absolute(alt_dir):
		DirAccess.remove_absolute(alt_dir)
	
	cleanup()

func test_save_file_recovery_from_alternate_location():
	"""Test recovery of save file from alternate location"""
	setup()
	
	# Create save file in alternate location
	var alt_path = "user://data/high_scores.save"
	var alt_dir = alt_path.get_base_dir()
	
	if not DirAccess.dir_exists_absolute(alt_dir):
		DirAccess.create_dir_recursive_absolute(alt_dir)
	
	var test_scores = [{"name": "RecoveryTest", "score": 9500}]
	var file = FileAccess.open(alt_path, FileAccess.WRITE)
	file.store_var(test_scores)
	file.close()
	
	# Attempt recovery
	var recovered_scores = storage.attempt_save_file_recovery()
	
	assert_equal(recovered_scores.size(), 1, "Should recover one score")
	assert_equal(recovered_scores[0].name, "RecoveryTest", "Should recover correct data")
	
	# Cleanup
	if FileAccess.file_exists(alt_path):
		DirAccess.remove_absolute(alt_path)
	if DirAccess.dir_exists_absolute(alt_dir):
		DirAccess.remove_absolute(alt_dir)
	
	cleanup()

# Version compatibility tests
func test_version_compatibility_validation():
	"""Test version compatibility validation"""
	setup()
	
	# Test supported migrations
	assert_true(validator.validate_migration_compatibility("legacy", "1.1"), "Should support legacy to 1.1")
	assert_true(validator.validate_migration_compatibility("1.0", "1.1"), "Should support 1.0 to 1.1")
	
	# Test unsupported migrations
	assert_false(validator.validate_migration_compatibility("1.1", "1.0"), "Should not support downgrade")
	assert_false(validator.validate_migration_compatibility("unknown", "1.1"), "Should not support unknown version")
	
	cleanup()

func test_migration_history_tracking():
	"""Test that migration history is properly tracked"""
	setup()
	
	var legacy_scores = [
		{"name": "HistoryTest1", "score": 2000},
		{"name": "HistoryTest2", "score": 1500}
	]
	
	# Migrate scores
	var migrated = storage.migrate_old_format(legacy_scores)
	
	# Save migrated scores
	storage.save_high_scores(migrated)
	
	# Load and check migration history
	var file = FileAccess.open(test_save_path, FileAccess.READ)
	var saved_data = file.get_var()
	file.close()
	
	assert_true(saved_data.has("format_info"), "Should have format info")
	assert_true(saved_data.format_info.has("migration_history"), "Should track migration history")
	
	var migration_history = saved_data.format_info.migration_history
	assert_true("legacy" in migration_history, "Should record legacy migration")
	
	cleanup()

# Error handling tests
func test_migration_failure_handling():
	"""Test handling of migration failures"""
	setup()
	
	# Create invalid data that should fail migration
	var invalid_data = {
		"completely_invalid": true,
		"no_scores": "anywhere"
	}
	
	var migrated = storage.migrate_old_format(invalid_data)
	assert_equal(migrated.size(), 0, "Should return empty array for invalid data")
	
	cleanup()

func test_corrupted_migration_backup():
	"""Test handling of corrupted migration backup"""
	setup()
	
	# Create a corrupted migration backup
	var backup_path = test_save_path.get_basename() + "_pre_migration_legacy.backup"
	var file = FileAccess.open(backup_path, FileAccess.WRITE)
	file.store_string("corrupted backup data")
	file.close()
	
	# This should not crash the system
	var legacy_data = [{"name": "CorruptBackupTest", "score": 1000}]
	var migrated = storage.migrate_old_format(legacy_data)
	
	assert_equal(migrated.size(), 1, "Should still migrate despite corrupted backup")
	
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