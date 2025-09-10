extends GutTest

# Test class for HighScoreValidator
var validator: HighScoreValidator

func before_each():
	validator = HighScoreValidator.new()

func after_each():
	validator = null

# Test score validation
func test_is_valid_score_with_valid_scores():
	assert_true(validator.is_valid_score(0), "Zero should be valid")
	assert_true(validator.is_valid_score(1000), "Normal score should be valid")
	assert_true(validator.is_valid_score(99_999_999), "Maximum score should be valid")

func test_is_valid_score_with_invalid_scores():
	assert_false(validator.is_valid_score(-1), "Negative score should be invalid")
	assert_false(validator.is_valid_score(-1000), "Large negative score should be invalid")
	assert_false(validator.is_valid_score(100_000_000), "Score above maximum should be invalid")

func test_is_reasonable_score_without_duration():
	assert_true(validator.is_reasonable_score(1000), "Normal score should be reasonable")
	assert_false(validator.is_reasonable_score(-1), "Negative score should not be reasonable")
	assert_false(validator.is_reasonable_score(100_000_000), "Excessive score should not be reasonable")

func test_is_reasonable_score_with_duration():
	# 60 seconds game, max 10000 points per second = 600000 max theoretical
	assert_true(validator.is_reasonable_score(500000, 60.0), "Score within theoretical limit should be reasonable")
	assert_false(validator.is_reasonable_score(700000, 60.0), "Score above theoretical limit should not be reasonable")

# Test name sanitization
func test_sanitize_player_name_normal_names():
	assert_eq(validator.sanitize_player_name("John"), "John", "Normal name should remain unchanged")
	assert_eq(validator.sanitize_player_name("Player 1"), "Player 1", "Name with space should remain unchanged")
	assert_eq(validator.sanitize_player_name("ABC123"), "ABC123", "Alphanumeric name should remain unchanged")

func test_sanitize_player_name_empty_and_whitespace():
	assert_eq(validator.sanitize_player_name(""), "Anonymous", "Empty name should become Anonymous")
	assert_eq(validator.sanitize_player_name("   "), "Anonymous", "Whitespace-only name should become Anonymous")
	assert_eq(validator.sanitize_player_name("\t\n"), "Anonymous", "Tab/newline name should become Anonymous")

func test_sanitize_player_name_invalid_characters():
	assert_eq(validator.sanitize_player_name("John@Doe"), "JohnDoe", "Special characters should be removed")
	assert_eq(validator.sanitize_player_name("Player#1!"), "Player1", "Multiple special characters should be removed")
	assert_eq(validator.sanitize_player_name("Test$%^&*()"), "Test", "All special characters should be removed")

func test_sanitize_player_name_length_truncation():
	var long_name = "ThisIsAVeryLongPlayerNameThatExceedsTheMaximumLength"
	var result = validator.sanitize_player_name(long_name)
	assert_eq(result.length(), 20, "Name should be truncated to 20 characters")
	assert_eq(result, "ThisIsAVeryLongPlaye", "Name should be truncated correctly")

func test_sanitize_player_name_edge_cases():
	assert_eq(validator.sanitize_player_name("@#$%"), "Anonymous", "Name with only special characters should become Anonymous")
	assert_eq(validator.sanitize_player_name("   John   "), "John", "Name with leading/trailing spaces should be trimmed")

# Test high score entry validation
func test_validate_high_score_entry_valid_entry():
	var entry = {
		"name": "TestPlayer",
		"score": 1000,
		"date": "2024-01-01",
		"timestamp": 1704067200,
		"player_index": 1,
		"session_id": "test_session",
		"version": "1.0.0"
	}
	
	var result = validator.validate_high_score_entry(entry)
	assert_true(result.valid, "Valid entry should pass validation")
	assert_eq(result.errors.size(), 0, "Valid entry should have no errors")

func test_validate_high_score_entry_missing_required_fields():
	var entry = {}
	
	var result = validator.validate_high_score_entry(entry)
	assert_false(result.valid, "Entry missing required fields should be invalid")
	assert_true(result.errors.has("Missing required field: name"), "Should report missing name")
	assert_true(result.errors.has("Missing required field: score"), "Should report missing score")

func test_validate_high_score_entry_invalid_score_types():
	var entry = {
		"name": "TestPlayer",
		"score": "not_a_number"
	}
	
	var result = validator.validate_high_score_entry(entry)
	assert_false(result.valid, "Entry with invalid score type should be invalid")
	assert_true(result.errors.has("Score must be an integer"), "Should report invalid score type")

func test_validate_high_score_entry_string_score_conversion():
	var entry = {
		"name": "TestPlayer",
		"score": "1000"
	}
	
	var result = validator.validate_high_score_entry(entry)
	assert_true(result.valid, "Entry with string score should be valid after conversion")
	assert_eq(result.sanitized_data.score, 1000, "String score should be converted to integer")
	assert_true(result.warnings.has("Score converted from string to integer"), "Should warn about conversion")

func test_validate_high_score_entry_name_sanitization():
	var entry = {
		"name": "Test@Player!",
		"score": 1000
	}
	
	var result = validator.validate_high_score_entry(entry)
	assert_true(result.valid, "Entry should be valid after name sanitization")
	assert_eq(result.sanitized_data.name, "TestPlayer", "Name should be sanitized")
	assert_true(result.warnings.size() > 0, "Should have warnings about name sanitization")

func test_validate_high_score_entry_adds_missing_optional_fields():
	var entry = {
		"name": "TestPlayer",
		"score": 1000
	}
	
	var result = validator.validate_high_score_entry(entry)
	assert_true(result.valid, "Entry should be valid")
	assert_true(result.sanitized_data.has("date"), "Should add missing date")
	assert_true(result.sanitized_data.has("timestamp"), "Should add missing timestamp")
	assert_true(result.sanitized_data.has("player_index"), "Should add missing player_index")
	assert_true(result.sanitized_data.has("session_id"), "Should add missing session_id")
	assert_true(result.sanitized_data.has("version"), "Should add missing version")

# Test high score list validation
func test_validate_high_score_list_valid_list():
	var scores = [
		{"name": "Player1", "score": 1000},
		{"name": "Player2", "score": 2000}
	]
	
	var result = validator.validate_high_score_list(scores)
	assert_true(result.valid, "Valid score list should pass validation")
	assert_eq(result.sanitized_data.scores.size(), 2, "Should have 2 sanitized entries")

func test_validate_high_score_list_with_invalid_entries():
	var scores = [
		{"name": "Player1", "score": 1000},
		{"name": "Player2"},  # Missing score
		{"score": 3000}       # Missing name
	]
	
	var result = validator.validate_high_score_list(scores)
	assert_false(result.valid, "List with invalid entries should be invalid")
	assert_true(result.errors.size() > 0, "Should have errors for invalid entries")

func test_validate_high_score_list_removes_duplicates():
	var scores = [
		{"name": "Player1", "score": 1000},
		{"name": "Player1", "score": 1000},  # Duplicate
		{"name": "Player2", "score": 2000}
	]
	
	var result = validator.validate_high_score_list(scores)
	assert_true(result.valid, "List should be valid after removing duplicates")
	assert_eq(result.sanitized_data.scores.size(), 2, "Should have 2 entries after removing duplicate")
	assert_true(result.warnings.size() > 0, "Should warn about duplicate removal")

# Test score submission validation
func test_validate_score_submission_valid():
	var result = validator.validate_score_submission("TestPlayer", 1000, 1)
	assert_true(result.valid, "Valid score submission should pass")
	assert_eq(result.sanitized_data.name, "TestPlayer", "Name should be preserved")
	assert_eq(result.sanitized_data.score, 1000, "Score should be preserved")
	assert_eq(result.sanitized_data.player_index, 1, "Player index should be preserved")

func test_validate_score_submission_with_sanitization():
	var result = validator.validate_score_submission("Test@Player!", 1000, 1)
	assert_true(result.valid, "Score submission should be valid after sanitization")
	assert_eq(result.sanitized_data.name, "TestPlayer", "Name should be sanitized")

# Test score improvement checking
func test_is_score_improvement_new_player():
	var existing_scores = [
		{"name": "Player1", "score": 1000}
	]
	
	var result = validator.is_score_improvement(500, existing_scores, "Player2")
	assert_true(result, "New player should always be an improvement")

func test_is_score_improvement_existing_player_better():
	var existing_scores = [
		{"name": "Player1", "score": 1000}
	]
	
	var result = validator.is_score_improvement(1500, existing_scores, "Player1")
	assert_true(result, "Higher score should be an improvement")

func test_is_score_improvement_existing_player_worse():
	var existing_scores = [
		{"name": "Player1", "score": 1000}
	]
	
	var result = validator.is_score_improvement(500, existing_scores, "Player1")
	assert_false(result, "Lower score should not be an improvement")

# Test edge cases and error conditions
func test_negative_scores():
	assert_false(validator.is_valid_score(-1), "Negative scores should be invalid")
	assert_false(validator.is_reasonable_score(-100, 60.0), "Negative scores should not be reasonable")

func test_extremely_high_scores():
	assert_false(validator.is_valid_score(999_999_999), "Extremely high scores should be invalid")
	assert_false(validator.is_reasonable_score(999_999_999, 1.0), "Extremely high scores should not be reasonable")

func test_empty_score_list():
	var result = validator.validate_high_score_list([])
	assert_true(result.valid, "Empty score list should be valid")
	assert_eq(result.sanitized_data.scores.size(), 0, "Empty list should remain empty")

func test_malformed_date_handling():
	var entry = {
		"name": "TestPlayer",
		"score": 1000,
		"date": "invalid-date"
	}
	
	var result = validator.validate_high_score_entry(entry)
	assert_true(result.valid, "Entry with invalid date should still be valid")
	assert_true(result.warnings.size() > 0, "Should warn about invalid date")
	assert_true(result.sanitized_data.date != "invalid-date", "Should replace invalid date")

func test_malformed_timestamp_handling():
	var entry = {
		"name": "TestPlayer",
		"score": 1000,
		"timestamp": "not-a-timestamp"
	}
	
	var result = validator.validate_high_score_entry(entry)
	assert_true(result.valid, "Entry with invalid timestamp should still be valid")
	assert_true(result.warnings.size() > 0, "Should warn about invalid timestamp")
	assert_true(result.sanitized_data.timestamp is int, "Should replace with valid timestamp")