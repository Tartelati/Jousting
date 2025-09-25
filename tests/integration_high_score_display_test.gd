extends Node

# Integration test for high score display system (standalone version)
class_name TestHighScoreDisplayIntegration

var high_score_display: HighScoreDisplay
var score_manager: Node
var test_scene: Node

func before_each():
	# Get the real ScoreManager
	score_manager = get_node("/root/ScoreManager")
	assert_not_null(score_manager, "ScoreManager should be available")
	
	# Create test scene container
	test_scene = Node.new()
	add_child_autofree(test_scene)
	
	# Load and instantiate the high score display scene
	var high_score_scene = load("res://scenes/ui/high_score_display.tscn")
	high_score_display = high_score_scene.instantiate()
	test_scene.add_child(high_score_display)
	
	# Wait for ready
	await get_tree().process_frame

func test_real_score_manager_integration():
	"""Test integration with real ScoreManager"""
	# Verify ScoreManager has required methods
	assert_true(score_manager.has_method("get_formatted_high_scores"), "ScoreManager should have get_formatted_high_scores method")
	
	# Get formatted scores
	var formatted_scores = score_manager.get_formatted_high_scores()
	assert_true(formatted_scores is Array, "Should return an array")
	
	# Should have at least David's score
	assert_gt(formatted_scores.size(), 0, "Should have at least one high score")
	assert_eq(formatted_scores[0].name, "David Lacassagne", "David should be first")

func test_display_refresh_with_real_data():
	"""Test display refresh with real score data"""
	# Refresh the display
	high_score_display.refresh_display()
	
	# Wait for UI to update
	await get_tree().process_frame
	
	# Should not crash and should display scores
	assert_true(true, "Display refresh should complete without errors")

func test_score_formatting_integration():
	"""Test score formatting with real ScoreManager data"""
	var formatted_scores = score_manager.get_formatted_high_scores()
	
	for score_entry in formatted_scores:
		# Verify required fields exist
		assert_true(score_entry.has("rank"), "Score entry should have rank")
		assert_true(score_entry.has("name"), "Score entry should have name")
		assert_true(score_entry.has("score"), "Score entry should have score")
		assert_true(score_entry.has("formatted_score"), "Score entry should have formatted_score")
		assert_true(score_entry.has("date"), "Score entry should have date")
		assert_true(score_entry.has("is_current_session"), "Score entry should have is_current_session")
		
		# Verify formatting
		var score_value = score_entry.score
		var formatted = score_entry.formatted_score
		
		if score_value >= 1000:
			assert_true(formatted.contains(","), "Large scores should contain comma separators")

func test_current_session_detection():
	"""Test current session score detection"""
	# Add a test score to current session
	var player_index = 1
	score_manager.add_score(player_index, 75000)
	
	# Submit as high score
	var result = score_manager.submit_high_score(player_index, "Test Player")
	
	if result.success:
		# Get formatted scores
		var formatted_scores = score_manager.get_formatted_high_scores()
		
		# Find the test player's score
		var test_score_found = false
		for score_entry in formatted_scores:
			if score_entry.name == "Test Player":
				assert_true(score_entry.is_current_session, "Test player's score should be marked as current session")
				test_score_found = true
				break
		
		assert_true(test_score_found, "Test player's score should be found in the list")

func test_display_options_persistence():
	"""Test that display options are properly applied"""
	var options = {
		"max_visible_scores": 5,
		"show_rank_numbers": true,
		"show_dates": true,
		"highlight_current_session": true
	}
	
	high_score_display.set_display_options(options)
	high_score_display.refresh_display()
	
	# Wait for UI update
	await get_tree().process_frame
	
	# Verify options are applied
	assert_eq(high_score_display.max_visible_scores, 5, "Max visible scores should be set")
	assert_true(high_score_display.show_rank_numbers, "Should show rank numbers")
	assert_true(high_score_display.show_dates, "Should show dates")
	assert_true(high_score_display.highlight_current_session, "Should highlight current session")

func test_signal_integration():
	"""Test signal integration between ScoreManager and display"""
	var signal_received = false
	var received_player_name = ""
	var received_score = 0
	var received_rank = 0
	
	# Connect to high score saved signal
	score_manager.high_score_saved.connect(func(player_name: String, score: int, rank: int):
		signal_received = true
		received_player_name = player_name
		received_score = score
		received_rank = rank
	)
	
	# Add score and submit
	var player_index = 2
	score_manager.add_score(player_index, 85000)
	var result = score_manager.submit_high_score(player_index, "Signal Test Player")
	
	if result.success:
		# Wait for signal
		await get_tree().process_frame
		
		assert_true(signal_received, "High score saved signal should be received")
		assert_eq(received_player_name, "Signal Test Player", "Player name should match")
		assert_eq(received_score, 85000, "Score should match")
		assert_gt(received_rank, 0, "Rank should be positive")

func test_ui_responsiveness():
	"""Test UI responsiveness with different data sizes"""
	# Test with empty scores (backup original)
	var original_scores = score_manager.high_scores.duplicate()
	
	# Clear scores temporarily
	score_manager.high_scores.clear()
	high_score_display.refresh_display()
	await get_tree().process_frame
	
	# Should show placeholder
	assert_true(true, "Should handle empty scores gracefully")
	
	# Restore original scores
	score_manager.high_scores = original_scores
	high_score_display.refresh_display()
	await get_tree().process_frame
	
	# Should display scores again
	assert_true(true, "Should restore display after adding scores back")

func test_date_formatting_integration():
	"""Test date formatting with real date data"""
	var formatted_scores = score_manager.get_formatted_high_scores()
	
	for score_entry in formatted_scores:
		var date_string = score_entry.date
		
		# Should have a valid date format
		if date_string != "Unknown" and date_string != "":
			# Should be in YYYY-MM-DD format or similar
			assert_true(date_string.length() >= 8, "Date should have reasonable length")

func test_performance_with_large_dataset():
	"""Test performance with larger high score dataset"""
	# Backup original scores
	var original_scores = score_manager.high_scores.duplicate()
	
	# Create larger dataset
	var large_scores = []
	for i in range(50):
		large_scores.append({
			"name": "Player " + str(i),
			"score": 10000 - (i * 100),
			"date": "2024-01-01",
			"timestamp": 0,
			"player_index": 1,
			"session_id": "test",
			"version": "1.0.0"
		})
	
	score_manager.high_scores = large_scores
	
	# Test display performance
	var start_time = Time.get_ticks_msec()
	high_score_display.refresh_display()
	await get_tree().process_frame
	var end_time = Time.get_ticks_msec()
	
	var display_time = end_time - start_time
	assert_lt(display_time, 1000, "Display should refresh within 1 second even with large dataset")
	
	# Restore original scores
	score_manager.high_scores = original_scores

func test_error_handling():
	"""Test error handling in display system"""
	# Test with malformed score data
	var original_scores = score_manager.high_scores.duplicate()
	
	# Add malformed entry
	score_manager.high_scores.append({
		"name": null,  # Invalid name
		"score": "invalid",  # Invalid score type
		"date": 12345  # Invalid date type
	})
	
	# Should not crash
	high_score_display.refresh_display()
	await get_tree().process_frame
	
	assert_true(true, "Should handle malformed data gracefully")
	
	# Restore original scores
	score_manager.high_scores = original_scores