extends Node

# Integration test for HighScoreStorage
# This test can be run by attaching it to a node in a scene and running the scene

var storage: HighScoreStorage
var test_results: Array[String] = []
var tests_passed = 0
var tests_failed = 0

func _ready():
	print("=== HighScoreStorage Integration Test ===")
	run_integration_tests()
	print_results()

func run_integration_tests():
	"""Run comprehensive integration tests for HighScoreStorage"""
	
	# Test 1: Basic save and load functionality
	test_basic_save_load()
	
	# Test 2: Backup and recovery
	test_backup_recovery()
	
	# Test 3: File corruption handling
	test_corruption_handling()
	
	# Test 4: Configuration options
	test_configuration()
	
	# Test 5: Error scenarios
	test_error_scenarios()

func test_basic_save_load():
	"""Test basic save and load operations"""
	print("\n--- Test 1: Basic Save/Load ---")
	
	# Initialize storage
	var config = {
		"save_location": "user://test_integration.save",
		"backup_enabled": true,
		"debug_logging": true
	}
	storage = HighScoreStorage.new(config)
	
	# Clean up any existing test files
	cleanup_test_files()
	
	# Create test data
	var test_scores: Array[Dictionary] = [
		{
			"name": "IntegrationTest1",
			"score": 15000,
			"date": "2024-01-01",
			"timestamp": 1704067200,
			"player_index": 1,
			"session_id": "integration_test_1",
			"version": "1.0.0"
		},
		{
			"name": "IntegrationTest2", 
			"score": 12000,
			"date": "2024-01-02",
			"timestamp": 1704153600,
			"player_index": 2,
			"session_id": "integration_test_2",
			"version": "1.0.0"
		}
	]
	
	# Test save
	var save_result = storage.save_high_scores(test_scores)
	assert_equal(save_result, HighScoreStorage.StorageError.SUCCESS, "Save should succeed")
	
	# Test load
	var loaded_scores = storage.load_high_scores()
	assert_equal(loaded_scores.size(), 2, "Should load 2 scores")
	assert_equal(loaded_scores[0].name, "IntegrationTest1", "First score name should match")
	assert_equal(loaded_scores[1].score, 12000, "Second score value should match")
	
	# Verify file exists
	assert_true(FileAccess.file_exists("user://test_integration.save"), "Save file should exist")

func test_backup_recovery():
	"""Test backup creation and recovery"""
	print("\n--- Test 2: Backup/Recovery ---")
	
	var test_scores: Array[Dictionary] = [
		{
			"name": "BackupTest",
			"score": 20000,
			"date": "2024-01-03",
			"timestamp": 1704240000,
			"player_index": 1,
			"session_id": "backup_test",
			"version": "1.0.0"
		}
	]
	
	# Save and create backup
	storage.save_high_scores(test_scores)
	var backup_result = storage.backup_high_scores()
	assert_equal(backup_result, HighScoreStorage.StorageError.SUCCESS, "Backup should succeed")
	
	# Verify backup file exists
	assert_true(FileAccess.file_exists("user://test_integration.backup"), "Backup file should exist")
	
	# Delete main file and restore from backup
	DirAccess.remove_absolute("user://test_integration.save")
	var restored_scores = storage.restore_from_backup()
	assert_equal(restored_scores.size(), 1, "Should restore 1 score")
	assert_equal(restored_scores[0].name, "BackupTest", "Restored score should match")

func test_corruption_handling():
	"""Test handling of corrupted files"""
	print("\n--- Test 3: Corruption Handling ---")
	
	# Create a corrupted file
	var file = FileAccess.open("user://test_integration.save", FileAccess.WRITE)
	file.store_string("This is corrupted data, not a valid save file")
	file.close()
	
	# Verify corruption is detected
	assert_false(storage.verify_file_integrity("user://test_integration.save"), "Should detect corruption")
	
	# Loading corrupted file should return empty array
	var loaded_scores = storage.load_high_scores()
	assert_equal(loaded_scores.size(), 0, "Should return empty array for corrupted file")

func test_configuration():
	"""Test different configuration options"""
	print("\n--- Test 4: Configuration ---")
	
	# Test custom save location
	var custom_config = {
		"save_location": "user://custom_test.save",
		"backup_enabled": false,
		"debug_logging": false
	}
	var custom_storage = HighScoreStorage.new(custom_config)
	
	var test_scores: Array[Dictionary] = [
		{
			"name": "CustomTest",
			"score": 5000,
			"date": "2024-01-04",
			"timestamp": 1704326400,
			"player_index": 1,
			"session_id": "custom_test",
			"version": "1.0.0"
		}
	]
	
	custom_storage.save_high_scores(test_scores)
	assert_true(FileAccess.file_exists("user://custom_test.save"), "Should save to custom location")
	
	var loaded_scores = custom_storage.load_high_scores()
	assert_equal(loaded_scores.size(), 1, "Should load from custom location")
	assert_equal(loaded_scores[0].name, "CustomTest", "Should preserve data in custom location")
	
	# Cleanup custom file
	DirAccess.remove_absolute("user://custom_test.save")

func test_error_scenarios():
	"""Test various error scenarios"""
	print("\n--- Test 5: Error Scenarios ---")
	
	# Test loading non-existent file
	cleanup_test_files()
	var loaded_scores = storage.load_high_scores()
	assert_equal(loaded_scores.size(), 0, "Should return empty array for non-existent file")
	
	# Test backup of non-existent file
	var backup_result = storage.backup_high_scores()
	assert_equal(backup_result, HighScoreStorage.StorageError.FILE_NOT_FOUND, "Should return FILE_NOT_FOUND for non-existent file")

func cleanup_test_files():
	"""Clean up test files"""
	var files_to_remove = [
		"user://test_integration.save",
		"user://test_integration.backup",
		"user://custom_test.save"
	]
	
	for file_path in files_to_remove:
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)

func assert_equal(actual, expected, message: String):
	"""Assert that two values are equal"""
	if actual == expected:
		test_results.append("✓ PASS: " + message)
		tests_passed += 1
	else:
		test_results.append("✗ FAIL: " + message + " (Expected: " + str(expected) + ", Got: " + str(actual) + ")")
		tests_failed += 1

func assert_true(condition: bool, message: String):
	"""Assert that condition is true"""
	if condition:
		test_results.append("✓ PASS: " + message)
		tests_passed += 1
	else:
		test_results.append("✗ FAIL: " + message + " (Expected: true, Got: false)")
		tests_failed += 1

func assert_false(condition: bool, message: String):
	"""Assert that condition is false"""
	if not condition:
		test_results.append("✓ PASS: " + message)
		tests_passed += 1
	else:
		test_results.append("✗ FAIL: " + message + " (Expected: false, Got: true)")
		tests_failed += 1

func print_results():
	"""Print test results"""
	print("\n" + "="*60)
	print("INTEGRATION TEST RESULTS")
	print("="*60)
	
	for result in test_results:
		print(result)
	
	print("\n" + "="*60)
	print("SUMMARY:")
	print("Tests Passed: %d" % tests_passed)
	print("Tests Failed: %d" % tests_failed)
	print("Total Tests: %d" % (tests_passed + tests_failed))
	
	var pass_rate = 0.0
	if (tests_passed + tests_failed) > 0:
		pass_rate = float(tests_passed) / float(tests_passed + tests_failed) * 100.0
	
	print("Pass Rate: %.1f%%" % pass_rate)
	
	if tests_failed == 0:
		print("🎉 ALL INTEGRATION TESTS PASSED!")
	else:
		print("❌ %d INTEGRATION TESTS FAILED" % tests_failed)
	
	print("="*60)
	
	# Clean up after all tests
	cleanup_test_files()