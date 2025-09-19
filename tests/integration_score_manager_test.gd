extends Node

# Integration test for enhanced ScoreManager functionality
# Tests the integration between ScoreManager, HighScoreStorage, and HighScoreValidator

var score_manager: Node
var test_results: Array[Dictionary] = []
var test_count: int = 0
var passed_count: int = 0

func _ready():
	print("=== ScoreManager Integration Tests ===")
	run_all_tests()
	print_results()

func run_all_tests():
	"""Run all integration tests"""
	test_initialization()
	test_score_submission_workflow()
	test_validation_integration()
	test_storage_integration()
	test_error_handling()
	test_multi_player_scenarios()
	test_configuration_management()
	test_session_tracking()
	test_backward_compatibility()

func test_initialization():
	"""Test enhanced system initialization"""
	print("\n--- Testing System Initialization ---")
	
	# Get ScoreManager instance
	score_manager = get_node("/root/ScoreManager")
	assert_test(score_manager != null, "ScoreManager should be accessible")
	
	# Check if enhanced components are initialized
	assert_test(score_manager.storage != null, "HighScoreStorage should be initialized")
	assert_test(score_manager.validator != null, "HighScoreValidator should be initialized")
	assert_test(score_manager.current_session_id != "", "Session ID should be generated")
	
	# Test configuration
	assert_test(score_manager.config.has("max_high_scores"), "Configuration should have max_high_scores")
	assert_test(score_manager.config.max_high_scores == 10, "Default max_high_scores should be 10")

func test_score_submission_workflow():
	"""Test complete score submission workflow"""
	print("\n--- Testing Score Submission Workflow ---")
	
	# Set up test score
	var test_player_index = 1
	var test_score = 50000
	var test_name = "Test Player"
	
	# Add score to player
	score_manager.scores[test_player_index] = test_score
	
	# Submit high score
	var result = score_manager.submit_high_score(test_player_index, test_name)
	
	assert_test(result is Dictionary, "submit_high_score should return Dictionary")
	assert_test(result.has("success"), "Result should have success field")
	assert_test(result.has("rank"), "Result should have rank field")
	assert_test(result.has("is_personal_best"), "Result should have is_personal_best field")
	
	# Check if score was added to high scores
	var found_score = false
	for entry in score_manager.high_scores:
		if entry.name == test_name and entry.score == test_score:
			found_score = true
			break
	
	assert_test(found_score, "Submitted score should be in high scores list")

func test_validation_integration():
	"""Test integration with HighScoreValidator"""
	print("\n--- Testing Validation Integration ---")
	
	# Test name validation
	var sanitized_name = score_manager.validate_player_name("Test@#$Player123")
	assert_test(sanitized_name == "TestPlayer123", "Name should be sanitized correctly")
	
	# Test empty name handling
	var empty_name = score_manager.validate_player_name("")
	assert_test(empty_name == "Anonymous", "Empty name should default to Anonymous")
	
	# Test score qualification
	var qualifying = score_manager.is_qualifying_score(100000)
	assert_test(qualifying == true, "High score should qualify")
	
	# Test invalid score submission
	var invalid_result = score_manager.submit_high_score(1, "")
	score_manager.scores[1] = -100  # Invalid negative score
	# Note: This test depends on validator rejecting negative scores

func test_storage_integration():
	"""Test integration with HighScoreStorage"""
	print("\n--- Testing Storage Integration ---")
	
	# Test save and load cycle
	var original_scores = score_manager.high_scores.duplicate(true)
	
	# Add a test score
	var test_entry = {
		"name": "Storage Test",
		"score": 75000,
		"date": "2024-01-01",
		"timestamp": Time.get_unix_time_from_system(),
		"player_index": 2,
		"session_id": "test_session",
		"version": "1.0.0"
	}
	
	score_manager.high_scores.append(test_entry)
	
	# Save scores
	score_manager.save_high_scores()
	
	# Clear and reload
	score_manager.high_scores.clear()
	score_manager.load_high_scores()
	
	# Check if test entry was preserved
	var found_test_entry = false
	for entry in score_manager.high_scores:
		if entry.name == "Storage Test" and entry.score == 75000:
			found_test_entry = true
			break
	
	assert_test(found_test_entry, "Test entry should be preserved through save/load cycle")

func test_error_handling():
	"""Test error handling and graceful degradation"""
	print("\n--- Testing Error Handling ---")
	
	# Test with invalid storage path
	var original_config = score_manager.config.duplicate()
	score_manager.config.save_location = "/invalid/path/that/does/not/exist.save"
	score_manager.storage.set_save_location(score_manager.config.save_location)
	
	# Try to save - should handle error gracefully
	var test_scores = [{"name": "Error Test", "score": 1000}]
	var save_result = score_manager.storage.save_high_scores(test_scores)
	
	assert_test(save_result != score_manager.storage.StorageError.SUCCESS, "Invalid path should cause save error")
	
	# Restore original configuration
	score_manager.config = original_config
	score_manager.storage.set_save_location(score_manager.config.save_location)

func test_multi_player_scenarios():
	"""Test multi-player high score scenarios"""
	print("\n--- Testing Multi-Player Scenarios ---")
	
	# Set up multiple players with different scores
	score_manager.scores[1] = 30000
	score_manager.scores[2] = 45000
	score_manager.scores[3] = 25000
	score_manager.scores[4] = 60000
	
	# Submit scores for multiple players
	var results = []
	results.append(score_manager.submit_high_score(1, "Player One"))
	results.append(score_manager.submit_high_score(2, "Player Two"))
	results.append(score_manager.submit_high_score(3, "Player Three"))
	results.append(score_manager.submit_high_score(4, "Player Four"))
	
	# Check that all submissions were processed
	for result in results:
		assert_test(result.success, "Multi-player submission should succeed")
	
	# Check ranking
	var player_four_rank = score_manager.get_player_rank(60000)
	assert_test(player_four_rank <= 2, "Player Four should have high rank (David is #1)")

func test_configuration_management():
	"""Test configuration management"""
	print("\n--- Testing Configuration Management ---")
	
	# Test max high scores setting
	var original_max = score_manager.config.max_high_scores
	score_manager.set_max_high_scores(5)
	assert_test(score_manager.config.max_high_scores == 5, "Max high scores should be updated")
	
	# Test custom configuration
	var custom_config = {
		"max_high_scores": 15,
		"debug_logging": true,
		"auto_save": false
	}
	
	score_manager.initialize_with_config(custom_config)
	assert_test(score_manager.config.max_high_scores == 15, "Custom max_high_scores should be applied")
	assert_test(score_manager.config.debug_logging == true, "Custom debug_logging should be applied")
	assert_test(score_manager.config.auto_save == false, "Custom auto_save should be applied")
	
	# Restore original
	score_manager.config.max_high_scores = original_max

func test_session_tracking():
	"""Test session tracking functionality"""
	print("\n--- Testing Session Tracking ---")
	
	# Check session ID generation
	var session_id = score_manager.current_session_id
	assert_test(session_id != "", "Session ID should be generated")
	assert_test(session_id.contains("_"), "Session ID should contain timestamp and random parts")
	
	# Test session score tracking
	score_manager.scores[1] = 40000
	var result = score_manager.submit_high_score(1, "Session Test")
	
	if result.success:
		assert_test(score_manager.session_scores.has(1), "Session scores should track submitted scores")
		
		# Test formatted scores with session marking
		var formatted_scores = score_manager.get_formatted_high_scores()
		var found_session_score = false
		
		for entry in formatted_scores:
			if entry.name == "Session Test" and entry.is_current_session:
				found_session_score = true
				break
		
		assert_test(found_session_score, "Current session scores should be marked in formatted output")

func test_backward_compatibility():
	"""Test backward compatibility with legacy methods"""
	print("\n--- Testing Backward Compatibility ---")
	
	# Test legacy try_submit_high_score method
	var legacy_result = score_manager.try_submit_high_score(35000, "Legacy Player")
	assert_test(legacy_result is bool, "Legacy method should return boolean")
	
	# Check if score was added
	var found_legacy = false
	for entry in score_manager.high_scores:
		if entry.name == "Legacy Player" and entry.score == 35000:
			found_legacy = true
			break
	
	assert_test(found_legacy, "Legacy submission should work with enhanced system")
	
	# Test that David is still protected
	var david_result = score_manager.try_submit_high_score(999999999, "David Lacassagne")
	assert_test(david_result == false, "David's score should remain protected")

# Test utility functions
func assert_test(condition: bool, description: String):
	"""Assert a test condition and record result"""
	test_count += 1
	var result = {
		"test_number": test_count,
		"description": description,
		"passed": condition
	}
	
	if condition:
		passed_count += 1
		print("✅ Test %d: %s" % [test_count, description])
	else:
		print("❌ Test %d: %s" % [test_count, description])
	
	test_results.append(result)

func print_results():
	"""Print final test results"""
	print("\n=== Test Results ===")
	print("Total Tests: %d" % test_count)
	print("Passed: %d" % passed_count)
	print("Failed: %d" % (test_count - passed_count))
	print("Success Rate: %.1f%%" % (float(passed_count) / float(test_count) * 100.0))
	
	if passed_count == test_count:
		print("🎉 All tests passed!")
	else:
		print("⚠️  Some tests failed. Check implementation.")
		
		# Print failed tests
		print("\nFailed Tests:")
		for result in test_results:
			if not result.passed:
				print("- Test %d: %s" % [result.test_number, result.description])