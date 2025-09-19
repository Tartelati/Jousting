extends Node

# Test runner specifically for ScoreManager integration tests
# This script can be run from the command line or attached to a scene

func _ready():
	print("Starting ScoreManager Integration Test Runner...")
	run_score_manager_tests()

func run_score_manager_tests():
	"""Run ScoreManager integration tests"""
	
	# Load and run the integration test scene
	var test_scene = preload("res://tests/integration_score_manager_test.tscn")
	var test_instance = test_scene.instantiate()
	
	# Add to scene tree
	add_child(test_instance)
	
	# Wait for tests to complete
	await get_tree().process_frame
	await get_tree().create_timer(2.0).timeout
	
	print("\nScoreManager integration tests completed.")
	
	# Clean up
	test_instance.queue_free()

# Manual test execution function
func execute_manual_tests():
	"""Execute manual tests for ScoreManager functionality"""
	print("\n=== Manual ScoreManager Tests ===")
	
	var score_manager = get_node("/root/ScoreManager")
	if not score_manager:
		print("❌ ScoreManager not found!")
		return
	
	print("✅ ScoreManager found")
	
	# Test 1: Basic score addition
	print("\n--- Test 1: Basic Score Addition ---")
	score_manager.add_score(1, 1000)
	var player_score = score_manager.get_score(1)
	print("Player 1 score after adding 1000: %d" % player_score)
	
	# Test 2: High score submission
	print("\n--- Test 2: High Score Submission ---")
	var submission_result = score_manager.submit_high_score(1, "Manual Test Player")
	print("Submission result: %s" % submission_result)
	
	# Test 3: Formatted high scores
	print("\n--- Test 3: Formatted High Scores ---")
	var formatted_scores = score_manager.get_formatted_high_scores()
	print("Current high scores:")
	for i in range(min(5, formatted_scores.size())):
		var entry = formatted_scores[i]
		print("%d. %s - %s" % [entry.rank, entry.name, entry.formatted_score])
	
	# Test 4: Configuration
	print("\n--- Test 4: Configuration ---")
	print("Max high scores: %d" % score_manager.config.max_high_scores)
	print("Auto save enabled: %s" % score_manager.config.auto_save)
	print("Debug logging: %s" % score_manager.config.debug_logging)
	
	# Test 5: Validation
	print("\n--- Test 5: Name Validation ---")
	var test_names = ["Valid Name", "Invalid@Name#123", "", "VeryLongNameThatExceedsTheMaximumLengthLimit"]
	for name in test_names:
		var sanitized = score_manager.validate_player_name(name)
		print("'%s' -> '%s'" % [name, sanitized])
	
	print("\n=== Manual tests completed ===")

# Function to test error scenarios
func test_error_scenarios():
	"""Test error handling scenarios"""
	print("\n=== Error Scenario Tests ===")
	
	var score_manager = get_node("/root/ScoreManager")
	if not score_manager:
		print("❌ ScoreManager not found!")
		return
	
	# Test invalid score submission
	print("\n--- Testing Invalid Score Submission ---")
	score_manager.scores[99] = -1000  # Invalid negative score
	var invalid_result = score_manager.submit_high_score(99, "Invalid Player")
	print("Invalid score submission result: %s" % invalid_result)
	
	# Test storage error handling
	print("\n--- Testing Storage Error Handling ---")
	var original_path = score_manager.storage.get_save_file_path()
	score_manager.storage.set_save_location("/invalid/path/test.save")
	
	var test_scores = [{"name": "Error Test", "score": 5000}]
	var save_result = score_manager.storage.save_high_scores(test_scores)
	print("Save to invalid path result: %s" % save_result)
	
	# Restore original path
	score_manager.storage.set_save_location(original_path)
	
	print("=== Error scenario tests completed ===")