extends Node

# Simple test runner for HighScoreValidator
# This can be run from the Godot editor or command line

var validator: HighScoreValidator
var tests_passed = 0
var tests_failed = 0
var test_results = []

func _ready():
	print("Starting HighScoreValidator Tests...")
	validator = HighScoreValidator.new()
	
	run_all_tests()
	print_results()

func run_all_tests():
	# Score validation tests
	test_is_valid_score()
	test_is_reasonable_score()
	
	# Name sanitization tests
	test_sanitize_player_name()
	
	# Entry validation tests
	test_validate_high_score_entry()
	
	# List validation tests
	test_validate_high_score_list()
	
	# Score submission tests
	test_validate_score_submission()
	
	# Score improvement tests
	test_is_score_improvement()
	
	# Edge case tests
	test_edge_cases()

# Test helper functions
func assert_true(condition: bool, message: String):
	if condition:
		tests_passed += 1
		test_results.append("✓ PASS: " + message)
	else:
		tests_failed += 1
		test_results.append("✗ FAIL: " + message)

func assert_false(condition: bool, message: String):
	assert_true(not condition, message)

func assert_eq(actual, expected, message: String):
	if actual == expected:
		tests_passed += 1
		test_results.append("✓ PASS: " + message)
	else:
		tests_failed += 1
		test_results.append("✗ FAIL: " + message + " (expected: " + str(expected) + ", got: " + str(actual) + ")")

# Test implementations
func test_is_valid_score():
	print("\n--- Testing is_valid_score ---")
	
	assert_true(validator.is_valid_score(0), "Zero should be valid")
	assert_true(validator.is_valid_score(1000), "Normal score should be valid")
	assert_true(validator.is_valid_score(99_999_999), "Maximum score should be valid")
	assert_false(validator.is_valid_score(-1), "Negative score should be invalid")
	assert_false(validator.is_valid_score(100_000_000), "Score above maximum should be invalid")

func test_is_reasonable_score():
	print("\n--- Testing is_reasonable_score ---")
	
	assert_true(validator.is_reasonable_score(1000), "Normal score should be reasonable")
	assert_false(validator.is_reasonable_score(-1), "Negative score should not be reasonable")
	assert_false(validator.is_reasonable_score(100_000_000), "Excessive score should not be reasonable")
	
	# Test with duration
	assert_true(validator.is_reasonable_score(500000, 60.0), "Score within theoretical limit should be reasonable")
	assert_false(validator.is_reasonable_score(700000, 60.0), "Score above theoretical limit should not be reasonable")

func test_sanitize_player_name():
	print("\n--- Testing sanitize_player_name ---")
	
	# Normal names
	assert_eq(validator.sanitize_player_name("John"), "John", "Normal name should remain unchanged")
	assert_eq(validator.sanitize_player_name("Player 1"), "Player 1", "Name with space should remain unchanged")
	assert_eq(validator.sanitize_player_name("ABC123"), "ABC123", "Alphanumeric name should remain unchanged")
	
	# Empty and whitespace
	assert_eq(validator.sanitize_player_name(""), "Anonymous", "Empty name should become Anonymous")
	assert_eq(validator.sanitize_player_name("   "), "Anonymous", "Whitespace-only name should become Anonymous")
	
	# Invalid characters
	assert_eq(validator.sanitize_player_name("John@Doe"), "JohnDoe", "Special characters should be removed")
	assert_eq(validator.sanitize_player_name("Player#1!"), "Player1", "Multiple special characters should be removed")
	
	# Length truncation
	var long_name = "ThisIsAVeryLongPlayerNameThatExceedsTheMaximumLength"
	var result = validator.sanitize_player_name(long_name)
	assert_eq(result.length(), 20, "Name should be truncated to 20 characters")
	assert_eq(result, "ThisIsAVeryLongPlaye", "Name should be truncated correctly")
	
	# Edge cases
	assert_eq(validator.sanitize_player_name("@#$%"), "Anonymous", "Name with only special characters should become Anonymous")
	assert_eq(validator.sanitize_player_name("   John   "), "John", "Name with leading/trailing spaces should be trimmed")

func test_validate_high_score_entry():
	print("\n--- Testing validate_high_score_entry ---")
	
	# Valid entry
	var valid_entry = {
		"name": "TestPlayer",
		"score": 1000,
		"date": "2024-01-01",
		"timestamp": 1704067200,
		"player_index": 1,
		"session_id": "test_session",
		"version": "1.0.0"
	}
	
	var result = validator.validate_high_score_entry(valid_entry)
	assert_true(result.valid, "Valid entry should pass validation")
	assert_eq(result.errors.size(), 0, "Valid entry should have no errors")
	
	# Missing required fields
	var invalid_entry = {}
	result = validator.validate_high_score_entry(invalid_entry)
	assert_false(result.valid, "Entry missing required fields should be invalid")
	assert_true(result.errors.size() > 0, "Should have errors for missing fields")
	
	# String score conversion
	var string_score_entry = {
		"name": "TestPlayer",
		"score": "1000"
	}
	result = validator.validate_high_score_entry(string_score_entry)
	assert_true(result.valid, "Entry with string score should be valid after conversion")
	assert_eq(result.sanitized_data.score, 1000, "String score should be converted to integer")
	
	# Name sanitization
	var dirty_name_entry = {
		"name": "Test@Player!",
		"score": 1000
	}
	result = validator.validate_high_score_entry(dirty_name_entry)
	assert_true(result.valid, "Entry should be valid after name sanitization")
	assert_eq(result.sanitized_data.name, "TestPlayer", "Name should be sanitized")

func test_validate_high_score_list():
	print("\n--- Testing validate_high_score_list ---")
	
	# Valid list
	var valid_scores = [
		{"name": "Player1", "score": 1000},
		{"name": "Player2", "score": 2000}
	]
	
	var result = validator.validate_high_score_list(valid_scores)
	assert_true(result.valid, "Valid score list should pass validation")
	assert_eq(result.sanitized_data.scores.size(), 2, "Should have 2 sanitized entries")
	
	# List with invalid entries
	var invalid_scores = [
		{"name": "Player1", "score": 1000},
		{"name": "Player2"},  # Missing score
		{"score": 3000}       # Missing name
	]
	
	result = validator.validate_high_score_list(invalid_scores)
	assert_false(result.valid, "List with invalid entries should be invalid")
	assert_true(result.errors.size() > 0, "Should have errors for invalid entries")
	
	# Duplicate removal
	var duplicate_scores = [
		{"name": "Player1", "score": 1000},
		{"name": "Player1", "score": 1000},  # Duplicate
		{"name": "Player2", "score": 2000}
	]
	
	result = validator.validate_high_score_list(duplicate_scores)
	assert_true(result.valid, "List should be valid after removing duplicates")
	assert_eq(result.sanitized_data.scores.size(), 2, "Should have 2 entries after removing duplicate")

func test_validate_score_submission():
	print("\n--- Testing validate_score_submission ---")
	
	var result = validator.validate_score_submission("TestPlayer", 1000, 1)
	assert_true(result.valid, "Valid score submission should pass")
	assert_eq(result.sanitized_data.name, "TestPlayer", "Name should be preserved")
	assert_eq(result.sanitized_data.score, 1000, "Score should be preserved")
	assert_eq(result.sanitized_data.player_index, 1, "Player index should be preserved")
	
	# Test with sanitization
	result = validator.validate_score_submission("Test@Player!", 1000, 1)
	assert_true(result.valid, "Score submission should be valid after sanitization")
	assert_eq(result.sanitized_data.name, "TestPlayer", "Name should be sanitized")

func test_is_score_improvement():
	print("\n--- Testing is_score_improvement ---")
	
	var existing_scores = [
		{"name": "Player1", "score": 1000}
	]
	
	# New player
	var result = validator.is_score_improvement(500, existing_scores, "Player2")
	assert_true(result, "New player should always be an improvement")
	
	# Existing player with better score
	result = validator.is_score_improvement(1500, existing_scores, "Player1")
	assert_true(result, "Higher score should be an improvement")
	
	# Existing player with worse score
	result = validator.is_score_improvement(500, existing_scores, "Player1")
	assert_false(result, "Lower score should not be an improvement")

func test_edge_cases():
	print("\n--- Testing edge cases ---")
	
	# Negative scores
	assert_false(validator.is_valid_score(-1), "Negative scores should be invalid")
	assert_false(validator.is_reasonable_score(-100, 60.0), "Negative scores should not be reasonable")
	
	# Extremely high scores
	assert_false(validator.is_valid_score(999_999_999), "Extremely high scores should be invalid")
	
	# Empty score list
	var result = validator.validate_high_score_list([])
	assert_true(result.valid, "Empty score list should be valid")
	assert_eq(result.sanitized_data.scores.size(), 0, "Empty list should remain empty")
	
	# Malformed date handling
	var entry_bad_date = {
		"name": "TestPlayer",
		"score": 1000,
		"date": "invalid-date"
	}
	
	result = validator.validate_high_score_entry(entry_bad_date)
	assert_true(result.valid, "Entry with invalid date should still be valid")
	assert_true(result.warnings.size() > 0, "Should warn about invalid date")

func print_results():
	print("\n" + "="*50)
	print("TEST RESULTS")
	print("="*50)
	
	for result_line in test_results:
		print(result_line)
	
	print("\n" + "="*50)
	print("SUMMARY:")
	print("Tests Passed: %d" % tests_passed)
	print("Tests Failed: %d" % tests_failed)
	print("Total Tests: %d" % (tests_passed + tests_failed))
	
	if tests_failed == 0:
		print("🎉 ALL TESTS PASSED!")
	else:
		print("❌ %d TESTS FAILED" % tests_failed)
	
	print("="*50)