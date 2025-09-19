extends Node

# Manual test for enhanced ScoreManager functionality
# Run this script to test the ScoreManager enhancements

func _ready():
	print("=== Manual ScoreManager Enhancement Test ===")
	test_enhanced_score_manager()

func test_enhanced_score_manager():
	"""Test the enhanced ScoreManager functionality"""
	
	# Get ScoreManager instance
	var score_manager = get_node("/root/ScoreManager")
	if not score_manager:
		print("❌ ScoreManager not found!")
		return
	
	print("✅ ScoreManager found")
	
	# Test 1: Check if enhanced components are initialized
	print("\n--- Test 1: Enhanced System Initialization ---")
	print("Storage initialized: %s" % (score_manager.storage != null))
	print("Validator initialized: %s" % (score_manager.validator != null))
	print("Session ID generated: %s" % (score_manager.current_session_id != ""))
	print("Configuration loaded: %s" % (score_manager.config.size() > 0))
	
	# Test 2: Name validation
	print("\n--- Test 2: Name Validation ---")
	var test_names = ["Valid Name", "Invalid@Name#", "", "TooLongNameThatExceedsLimit"]
	for name in test_names:
		var sanitized = score_manager.validate_player_name(name)
		print("'%s' -> '%s'" % [name, sanitized])
	
	# Test 3: Score qualification
	print("\n--- Test 3: Score Qualification ---")
	var test_scores = [100, 1000, 10000, 100000, 1000000]
	for score in test_scores:
		var qualifies = score_manager.is_qualifying_score(score)
		print("Score %d qualifies: %s" % [score, qualifies])
	
	# Test 4: Enhanced score submission
	print("\n--- Test 4: Enhanced Score Submission ---")
	
	# Set up a test player score
	score_manager.scores[1] = 50000
	
	# Submit high score using enhanced method
	var result = score_manager.submit_high_score(1, "Test Player")
	print("Submission result: %s" % result)
	
	if result.success:
		print("✅ Enhanced submission successful!")
		print("  - Rank: %d" % result.rank)
		print("  - Personal best: %s" % result.is_personal_best)
		print("  - Message: %s" % result.message)
	else:
		print("❌ Enhanced submission failed: %s" % result.message)
	
	# Test 5: Formatted high scores
	print("\n--- Test 5: Formatted High Scores ---")
	var formatted_scores = score_manager.get_formatted_high_scores()
	print("Current high scores (formatted):")
	
	for i in range(min(5, formatted_scores.size())):
		var entry = formatted_scores[i]
		var session_marker = " (Current Session)" if entry.is_current_session else ""
		print("  %d. %s - %s%s" % [entry.rank, entry.name, entry.formatted_score, session_marker])
	
	# Test 6: Configuration management
	print("\n--- Test 6: Configuration Management ---")
	print("Max high scores: %d" % score_manager.config.max_high_scores)
	print("Auto save: %s" % score_manager.config.auto_save)
	print("Debug logging: %s" % score_manager.config.debug_logging)
	
	# Test changing configuration
	var original_max = score_manager.config.max_high_scores
	score_manager.set_max_high_scores(15)
	print("Max high scores after change: %d" % score_manager.config.max_high_scores)
	score_manager.set_max_high_scores(original_max)  # Restore
	
	# Test 7: Backward compatibility
	print("\n--- Test 7: Backward Compatibility ---")
	var legacy_result = score_manager.try_submit_high_score(25000, "Legacy Player")
	print("Legacy submission result: %s" % legacy_result)
	
	# Test 8: Error handling
	print("\n--- Test 8: Error Handling ---")
	
	# Test invalid score (negative)
	score_manager.scores[99] = -1000
	var invalid_result = score_manager.submit_high_score(99, "Invalid Player")
	print("Invalid score submission: %s" % invalid_result.success)
	if not invalid_result.success:
		print("  Error message: %s" % invalid_result.message)
	
	print("\n=== Manual test completed ===")
	print("Enhanced ScoreManager functionality verified!")

# Test signal connections
func _on_high_score_saved(player_name: String, score: int, rank: int):
	print("🎉 High score saved signal: %s scored %d (rank %d)" % [player_name, score, rank])

func _on_save_error(error_message: String):
	print("⚠️ Save error signal: %s" % error_message)

func _on_personal_best_achieved(player_index: int, previous_best: int):
	print("🏆 Personal best achieved signal: Player %d beat previous best of %d" % [player_index, previous_best])

func connect_signals():
	"""Connect to ScoreManager signals for testing"""
	var score_manager = get_node("/root/ScoreManager")
	if score_manager:
		score_manager.connect("high_score_saved", _on_high_score_saved)
		score_manager.connect("save_error", _on_save_error)
		score_manager.connect("personal_best_achieved", _on_personal_best_achieved)
		print("✅ Signals connected for testing")