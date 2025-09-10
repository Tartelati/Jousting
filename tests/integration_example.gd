extends Node

# Integration example showing how HighScoreValidator works with ScoreManager
# This demonstrates the validator functionality without requiring a full test framework

var validator: HighScoreValidator

func _ready():
	print("HighScoreValidator Integration Example")
	print("=====================================")
	
	validator = HighScoreValidator.new()
	
	# Test all major functionality
	test_score_validation()
	test_name_sanitization()
	test_entry_validation()
	test_score_submission()
	test_score_improvement()
	test_list_validation()
	test_edge_cases()
	
	print("\n🎉 Integration example completed!")

func test_score_validation():
	print("\n--- Score Validation Tests ---")
	
	# Valid scores
	print("✓ Valid score 1000: ", validator.is_valid_score(1000))
	print("✓ Valid score 0: ", validator.is_valid_score(0))
	print("✓ Valid max score: ", validator.is_valid_score(99_999_999))
	
	# Invalid scores
	print("✓ Invalid negative score: ", not validator.is_valid_score(-1))
	print("✓ Invalid excessive score: ", not validator.is_valid_score(100_000_000))
	
	# Reasonable scores with duration
	print("✓ Reasonable score with duration: ", validator.is_reasonable_score(500000, 60.0))
	print("✓ Unreasonable score with duration: ", not validator.is_reasonable_score(700000, 60.0))

func test_name_sanitization():
	print("\n--- Name Sanitization Tests ---")
	
	# Normal names
	var name1 = validator.sanitize_player_name("John")
	print("✓ Normal name 'John': ", name1 == "John")
	
	var name2 = validator.sanitize_player_name("Player 1")
	print("✓ Name with space 'Player 1': ", name2 == "Player 1")
	
	# Empty names
	var name3 = validator.sanitize_player_name("")
	print("✓ Empty name becomes 'Anonymous': ", name3 == "Anonymous")
	
	var name4 = validator.sanitize_player_name("   ")
	print("✓ Whitespace name becomes 'Anonymous': ", name4 == "Anonymous")
	
	# Invalid characters
	var name5 = validator.sanitize_player_name("John@Doe")
	print("✓ Remove special chars 'John@Doe' -> 'JohnDoe': ", name5 == "JohnDoe")
	
	var name6 = validator.sanitize_player_name("Player#1!")
	print("✓ Remove multiple special chars: ", name6 == "Player1")
	
	# Length truncation
	var long_name = "ThisIsAVeryLongPlayerNameThatExceedsTheMaximumLength"
	var name7 = validator.sanitize_player_name(long_name)
	print("✓ Truncate long name to 20 chars: ", name7.length() == 20)
	print("  Truncated name: ", name7)

func test_entry_validation():
	print("\n--- Entry Validation Tests ---")
	
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
	
	var result1 = validator.validate_high_score_entry(valid_entry)
	print("✓ Valid entry passes validation: ", result1.valid)
	print("  Errors: ", result1.errors.size())
	print("  Warnings: ", result1.warnings.size())
	
	# Invalid entry (missing required fields)
	var invalid_entry = {}
	var result2 = validator.validate_high_score_entry(invalid_entry)
	print("✓ Invalid entry fails validation: ", not result2.valid)
	print("  Errors: ", result2.errors.size())
	
	# Entry with string score (should convert)
	var string_score_entry = {
		"name": "TestPlayer",
		"score": "1000"
	}
	var result3 = validator.validate_high_score_entry(string_score_entry)
	print("✓ String score converts to int: ", result3.valid)
	print("  Converted score: ", result3.sanitized_data.score)
	print("  Warnings: ", result3.warnings.size())
	
	# Entry with dirty name (should sanitize)
	var dirty_name_entry = {
		"name": "Test@Player!",
		"score": 1000
	}
	var result4 = validator.validate_high_score_entry(dirty_name_entry)
	print("✓ Dirty name gets sanitized: ", result4.valid)
	print("  Sanitized name: ", result4.sanitized_data.name)

func test_score_submission():
	print("\n--- Score Submission Tests ---")
	
	# Valid submission
	var result1 = validator.validate_score_submission("TestPlayer", 1000, 1)
	print("✓ Valid submission: ", result1.valid)
	print("  Player name: ", result1.sanitized_data.name)
	print("  Score: ", result1.sanitized_data.score)
	print("  Player index: ", result1.sanitized_data.player_index)
	
	# Submission with name sanitization
	var result2 = validator.validate_score_submission("Test@Player!", 1500, 2)
	print("✓ Submission with sanitization: ", result2.valid)
	print("  Sanitized name: ", result2.sanitized_data.name)
	print("  Warnings: ", result2.warnings.size())

func test_score_improvement():
	print("\n--- Score Improvement Tests ---")
	
	var existing_scores = [
		{"name": "Player1", "score": 1000},
		{"name": "Player2", "score": 2000}
	]
	
	# New player (always improvement)
	var improvement1 = validator.is_score_improvement(500, existing_scores, "Player3")
	print("✓ New player is improvement: ", improvement1)
	
	# Existing player with better score
	var improvement2 = validator.is_score_improvement(1500, existing_scores, "Player1")
	print("✓ Better score is improvement: ", improvement2)
	
	# Existing player with worse score
	var improvement3 = validator.is_score_improvement(500, existing_scores, "Player1")
	print("✓ Worse score is not improvement: ", not improvement3)

func test_list_validation():
	print("\n--- List Validation Tests ---")
	
	# Valid list
	var valid_list = [
		{"name": "Player1", "score": 1000},
		{"name": "Player2", "score": 2000}
	]
	
	var result1 = validator.validate_high_score_list(valid_list)
	print("✓ Valid list passes: ", result1.valid)
	print("  Sanitized entries: ", result1.sanitized_data.scores.size())
	
	# List with invalid entries
	var invalid_list = [
		{"name": "Player1", "score": 1000},
		{"name": "Player2"},  # Missing score
		{"score": 3000}       # Missing name
	]
	
	var result2 = validator.validate_high_score_list(invalid_list)
	print("✓ Invalid list fails: ", not result2.valid)
	print("  Errors: ", result2.errors.size())
	
	# List with duplicates
	var duplicate_list = [
		{"name": "Player1", "score": 1000},
		{"name": "Player1", "score": 1000},  # Duplicate
		{"name": "Player2", "score": 2000}
	]
	
	var result3 = validator.validate_high_score_list(duplicate_list)
	print("✓ Duplicates removed: ", result3.valid)
	print("  Final entries: ", result3.sanitized_data.scores.size())
	print("  Warnings: ", result3.warnings.size())

func test_edge_cases():
	print("\n--- Edge Case Tests ---")
	
	# Empty list
	var result1 = validator.validate_high_score_list([])
	print("✓ Empty list is valid: ", result1.valid)
	print("  Empty list size: ", result1.sanitized_data.scores.size())
	
	# Malformed date
	var bad_date_entry = {
		"name": "TestPlayer",
		"score": 1000,
		"date": "invalid-date"
	}
	
	var result2 = validator.validate_high_score_entry(bad_date_entry)
	print("✓ Bad date handled gracefully: ", result2.valid)
	print("  Warnings about date: ", result2.warnings.size() > 0)
	
	# Malformed timestamp
	var bad_timestamp_entry = {
		"name": "TestPlayer",
		"score": 1000,
		"timestamp": "not-a-timestamp"
	}
	
	var result3 = validator.validate_high_score_entry(bad_timestamp_entry)
	print("✓ Bad timestamp handled gracefully: ", result3.valid)
	print("  Warnings about timestamp: ", result3.warnings.size() > 0)
	
	# Extreme scores
	print("✓ Negative score invalid: ", not validator.is_valid_score(-1))
	print("✓ Extreme high score invalid: ", not validator.is_valid_score(999_999_999))
	
	# Special characters only name
	var special_name = validator.sanitize_player_name("@#$%^&*()")
	print("✓ Special chars only becomes Anonymous: ", special_name == "Anonymous")